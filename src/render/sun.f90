!===============================================================================
! sun.f90 — Procedural Sun (boiling surface) + billboard corona
!
! The Sun is rendered separately from the flat-shaded instanced body pass
! so it can:
!   - use its own shader pair for procedural fbm + domain warp
!   - emit HDR colour (values > 1.0) so bloom picks it up
!   - have a screen-aligned corona quad added on top with additive blending
!
! World-space position is pulled from bodies(1) every frame and scaled into
! AU like the other bodies.
!===============================================================================
module sun_mod
    use, intrinsic :: iso_c_binding, only: c_float, c_int, c_null_ptr, c_loc
    use, intrinsic :: iso_fortran_env, only: real64
    use gl_bindings, only: &
        gl_use_program, gl_bind_vertex_array, gl_bind_buffer, &
        gl_gen_buffers, gl_gen_vertex_arrays, gl_delete_buffers, &
        gl_delete_vertex_arrays, gl_buffer_data, &
        gl_enable_vertex_attrib_array, gl_vertex_attrib_pointer_offset, &
        gl_draw_elements_instanced, gl_draw_arrays, &
        gl_enable, gl_disable, gl_depth_mask, gl_blend_func, &
        gl_set_cull_face, gl_set_front_face, &
        GL_ARRAY_BUFFER, GL_STATIC_DRAW, GL_FLOAT, GL_TRIANGLES, &
        GL_DEPTH_TEST, GL_CULL_FACE, GL_BACK, GL_CCW, GL_BLEND, &
        GL_SRC_ALPHA, GL_ONE, GL_UNSIGNED_INT
    use shader_mod, only: shader_program_t, shader_load, shader_use, &
                          shader_destroy, set_uniform_mat4, set_uniform_vec3, &
                          set_uniform_float
    use camera_mod, only: camera_t, camera_get_view, camera_get_projection
    use mesh_mod, only: mesh_t, mesh_create_sphere, mesh_destroy
    use mat4_math, only: mat4, mat4_translate, mat4_scale_xyz, mat4_to_array
    use body_mod, only: body_t
    use constants, only: AU
    use logging, only: log_msg, LOG_INFO, LOG_ERROR
    implicit none
    private

    public :: sun_t, sun_init, sun_shutdown, sun_render

    ! Visual radius in AU. With elliptical orbits, Mercury's perihelion sits
    ! at 0.307 AU from the Sun centre. Mercury's body (visual radius ~0.016 AU
    ! under the planet formula) has its near edge at ~0.291 AU at perihelion,
    ! so the Sun sphere + additive corona billboard together must fit inside
    ! that envelope — otherwise Mercury visibly clips the Sun's glow when it
    ! swings closest. Keep the explicit corona restrained and let HDR bloom
    ! provide most of the apparent glare.
    real(c_float), parameter :: SUN_VISUAL_RADIUS  = 0.20_c_float
    real(c_float), parameter :: CORONA_SCALE       = 1.12_c_float

    type :: sun_t
        type(mesh_t)           :: sphere
        type(shader_program_t) :: sun_shader
        type(shader_program_t) :: corona_shader
        integer(c_int)         :: corona_vao = 0_c_int
        integer(c_int)         :: corona_vbo = 0_c_int
        logical                :: initialized = .false.
    end type sun_t

contains

    subroutine sun_init(sun)
        type(sun_t), intent(out) :: sun
        integer(c_int) :: arr(1)
        real(c_float), target :: quad(12)

        call mesh_create_sphere(sun%sphere, 32, 48)

        sun%sun_shader = shader_load("shaders/sun.vert", "shaders/sun.frag")
        if (.not. sun%sun_shader%valid) then
            call log_msg(LOG_ERROR, "sun: failed to load sun shader")
            return
        end if

        sun%corona_shader = shader_load("shaders/corona.vert", "shaders/corona.frag")
        if (.not. sun%corona_shader%valid) then
            call log_msg(LOG_ERROR, "sun: failed to load corona shader")
            return
        end if

        ! A unit quad in clip-local XY (two triangles, 6 verts of vec2)
        quad = [ -1.0_c_float, -1.0_c_float,  1.0_c_float, -1.0_c_float, &
                  1.0_c_float,  1.0_c_float, -1.0_c_float, -1.0_c_float, &
                  1.0_c_float,  1.0_c_float, -1.0_c_float,  1.0_c_float ]
        call gl_gen_vertex_arrays(1, arr); sun%corona_vao = arr(1)
        call gl_gen_buffers(1, arr);       sun%corona_vbo = arr(1)
        call gl_bind_vertex_array(sun%corona_vao)
        call gl_bind_buffer(GL_ARRAY_BUFFER, sun%corona_vbo)
        call gl_buffer_data(GL_ARRAY_BUFFER, int(12 * 4, c_int), &
                            c_loc(quad(1)), GL_STATIC_DRAW)
        call gl_enable_vertex_attrib_array(0)
        call gl_vertex_attrib_pointer_offset(0, 2, GL_FLOAT, .false., &
                                             int(2 * 4, c_int), 0)
        call gl_bind_vertex_array(0_c_int)

        sun%initialized = .true.
        call log_msg(LOG_INFO, "Sun renderer initialized")
    end subroutine sun_init

    subroutine sun_shutdown(sun)
        type(sun_t), intent(inout) :: sun
        integer(c_int) :: arr(1)
        if (.not. sun%initialized) return
        call mesh_destroy(sun%sphere)
        call shader_destroy(sun%sun_shader)
        call shader_destroy(sun%corona_shader)
        if (sun%corona_vbo /= 0) then
            arr(1) = sun%corona_vbo; call gl_delete_buffers(1, arr)
        end if
        if (sun%corona_vao /= 0) then
            arr(1) = sun%corona_vao; call gl_delete_vertex_arrays(1, arr)
        end if
        sun%initialized = .false.
    end subroutine sun_shutdown

    subroutine sun_render(sun, sun_body, cam, t_sec, emissive_mul)
        type(sun_t), intent(inout) :: sun
        type(body_t), intent(in) :: sun_body
        type(camera_t), intent(in) :: cam
        real(c_float), intent(in) :: t_sec, emissive_mul

        real(c_float) :: view_arr(16), proj_arr(16), model_arr(16)
        real(c_float) :: pos_au(3)
        type(mat4)    :: model, trans, scl

        if (.not. sun%initialized) return

        pos_au(1) = real(sun_body%position%x / AU, c_float)
        pos_au(2) = real(sun_body%position%y / AU, c_float)
        pos_au(3) = real(sun_body%position%z / AU, c_float)

        view_arr = camera_get_view(cam)
        proj_arr = camera_get_projection(cam)

        !---------------------------------------------------------------
        ! Pass 1: opaque procedural sphere
        !---------------------------------------------------------------
        trans = mat4_translate(pos_au(1), pos_au(2), pos_au(3))
        scl   = mat4_scale_xyz(SUN_VISUAL_RADIUS, SUN_VISUAL_RADIUS, SUN_VISUAL_RADIUS)
        model = mat4_mul(trans, scl)
        model_arr = mat4_to_array(model)

        call shader_use(sun%sun_shader)
        call set_uniform_mat4(sun%sun_shader, "u_view", view_arr)
        call set_uniform_mat4(sun%sun_shader, "u_proj", proj_arr)
        call set_uniform_mat4(sun%sun_shader, "u_model", model_arr)
        call set_uniform_float(sun%sun_shader, "u_time", t_sec)
        call set_uniform_float(sun%sun_shader, "u_emissive_mul", emissive_mul)
        call set_uniform_vec3(sun%sun_shader, "u_eye", cam%eye(1), cam%eye(2), cam%eye(3))

        call gl_enable(GL_DEPTH_TEST)
        call gl_enable(GL_CULL_FACE)
        call gl_set_cull_face(GL_BACK)
        call gl_set_front_face(GL_CCW)
        call gl_bind_vertex_array(sun%sphere%vao)
        call gl_draw_elements_instanced(GL_TRIANGLES, sun%sphere%n_idx, &
                                        GL_UNSIGNED_INT, c_null_ptr, 1_c_int)

        !---------------------------------------------------------------
        ! Pass 2: additive billboard corona
        !---------------------------------------------------------------
        call shader_use(sun%corona_shader)
        call set_uniform_mat4(sun%corona_shader, "u_view", view_arr)
        call set_uniform_mat4(sun%corona_shader, "u_proj", proj_arr)
        call set_uniform_vec3(sun%corona_shader, "u_center", &
                              pos_au(1), pos_au(2), pos_au(3))
        call set_uniform_float(sun%corona_shader, "u_radius", &
                               SUN_VISUAL_RADIUS * CORONA_SCALE)
        call set_uniform_float(sun%corona_shader, "u_disc_ratio", &
                               1.0_c_float / CORONA_SCALE)
        call set_uniform_float(sun%corona_shader, "u_emissive_mul", emissive_mul)

        call gl_enable(GL_BLEND)
        call gl_blend_func(GL_SRC_ALPHA, GL_ONE)
        call gl_depth_mask(.false.)
        call gl_disable(GL_CULL_FACE)
        call gl_bind_vertex_array(sun%corona_vao)
        call gl_draw_arrays(GL_TRIANGLES, 0_c_int, 6_c_int)
        call gl_bind_vertex_array(0_c_int)

        call gl_depth_mask(.true.)
        call gl_disable(GL_BLEND)
    end subroutine sun_render

    pure function mat4_mul(a, b) result(r)
        type(mat4), intent(in) :: a, b
        type(mat4) :: r
        integer :: i, j, k
        real(c_float) :: s
        do j = 1, 4
            do i = 1, 4
                s = 0.0_c_float
                do k = 1, 4
                    s = s + a%m(i, k) * b%m(k, j)
                end do
                r%m(i, j) = s
            end do
        end do
    end function mat4_mul

end module sun_mod
