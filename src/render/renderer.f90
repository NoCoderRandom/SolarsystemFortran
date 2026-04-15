!===============================================================================
! renderer.f90 — Instanced sphere rendering for solar system bodies
!
! Scaling:
!   World units = AU (positions / AU)
!   Visual radius = k * log(1 + R / R_earth) for planets
!   Sun gets a fixed larger visual radius
!===============================================================================
module renderer
    use, intrinsic :: iso_c_binding, only: c_float, c_int, c_null_ptr, c_loc, c_intptr_t, c_ptr
    use, intrinsic :: iso_fortran_env, only: real32, real64
    use gl_bindings, only: &
        gl_bind_vertex_array, gl_use_program, &
        gl_bind_buffer, gl_buffer_data, &
        gl_enable, gl_disable, &
        gl_gen_buffers, gl_delete_buffers, &
        gl_set_cull_face, gl_set_front_face, &
        gl_draw_elements_instanced, &
        gl_enable_vertex_attrib_array, gl_vertex_attrib_pointer, &
        gl_vertex_attrib_divisor, gl_vertex_attrib_pointer_offset, &
        GL_ARRAY_BUFFER, GL_DYNAMIC_DRAW, GL_TRIANGLES, GL_FLOAT, &
        GL_FALSE, GL_DEPTH_TEST, GL_CULL_FACE, GL_BACK, GL_CCW, &
        GL_UNSIGNED_INT, GLuint_t
    use mesh_mod, only: mesh_t, mesh_create_sphere, mesh_destroy
    use shader_mod, only: shader_program_t, shader_load, shader_use, &
                          shader_destroy, set_uniform_mat4
    use camera_mod, only: camera_t, camera_init, camera_get_view, camera_get_projection
    use body_mod, only: body_t
    use mat4_math, only: mat4, mat4_translate, mat4_scale_xyz, mat4_to_array
    use logging, only: log_msg, LOG_INFO, LOG_ERROR
    use vector3d, only: norm
    use constants, only: AU
    implicit none
    private

    public :: renderer_t, renderer_init, renderer_render, renderer_shutdown

    ! Visual radius constants
    real(c_float), parameter :: VISUAL_K_PLANET = 0.25_c_float
    real(real64), parameter  :: R_EARTH = 6371000.0_real64
    real(c_float), parameter :: SUN_VISUAL_RADIUS = 1.2_c_float

    ! Instance layout: 16 (model matrix) + 3 (color) + 1 (padding) = 20 floats
    integer, parameter :: FLOATS_PER_INSTANCE = 20
    integer, parameter :: BYTES_PER_INSTANCE  = FLOATS_PER_INSTANCE * 4

    type, public :: renderer_t
        type(mesh_t)            :: sphere_mesh
        type(shader_program_t)  :: body_shader
        type(camera_t)          :: camera
        logical                 :: initialized = .false.
        integer(c_int)          :: instance_vbo = 0_c_int
        integer                 :: n_max_instances = 0
    end type renderer_t

    ! Module-private instance buffer with TARGET for c_loc
    real(c_float), allocatable, target, save :: g_instance_data(:)

contains

    subroutine renderer_init(renderer, win_width, win_height)
        type(renderer_t), intent(out) :: renderer
        integer, intent(in) :: win_width, win_height

        call mesh_create_sphere(renderer%sphere_mesh, 16, 24)

        renderer%body_shader = shader_load("shaders/body.vert", "shaders/body.frag")
        if (.not. renderer%body_shader%valid) then
            call log_msg(LOG_ERROR, "Renderer: failed to load body shader")
            return
        end if

        call camera_init(renderer%camera, win_width, win_height)

        allocate(g_instance_data(FLOATS_PER_INSTANCE * 32))
        renderer%instance_vbo = 0_c_int
        renderer%initialized = .true.
        call log_msg(LOG_INFO, "Renderer initialized")
    end subroutine renderer_init

    subroutine renderer_render(renderer, bodies)
        type(renderer_t), intent(inout) :: renderer
        type(body_t), intent(in) :: bodies(:)

        integer :: n_bodies, n_inst, i
        real(c_float) :: pos_au(3), radius_vis, model_arr(16)
        type(mat4) :: model, trans, scale_m
        real(real64) :: r_meters
        integer(c_int) :: buf_arr(1)
        real(c_float) :: view_arr(16), proj_arr(16)

        if (.not. renderer%initialized) return

        n_bodies = size(bodies)
        if (n_bodies == 0) return

        ! Build instance data — skip the Sun (sun_mod draws it separately
        ! with the procedural shader + corona billboard).
        n_inst = 0
        do i = 1, n_bodies
            if (trim(bodies(i)%name) == "Sun") cycle

            pos_au(1) = real(bodies(i)%position%x / AU, c_float)
            pos_au(2) = real(bodies(i)%position%y / AU, c_float)
            pos_au(3) = real(bodies(i)%position%z / AU, c_float)

            r_meters = bodies(i)%radius
            radius_vis = real(VISUAL_K_PLANET * &
                log(1.0_real64 + r_meters / R_EARTH), c_float)

            trans = mat4_translate(pos_au(1), pos_au(2), pos_au(3))
            scale_m = mat4_scale_xyz(radius_vis, radius_vis, radius_vis)
            model = mat4_mul_mat4(trans, scale_m)
            model_arr = mat4_to_array(model)

            n_inst = n_inst + 1
            call write_instance(g_instance_data, n_inst, model_arr, &
                                bodies(i)%color(1), bodies(i)%color(2), &
                                bodies(i)%color(3))
        end do

        if (n_inst == 0) return

        ! Upload instance buffer
        call gl_bind_vertex_array(renderer%sphere_mesh%vao)

        if (renderer%instance_vbo /= 0_c_int) then
            buf_arr(1) = renderer%instance_vbo
            call gl_delete_buffers(1, buf_arr)
        end if
        call gl_gen_buffers(1, buf_arr)
        renderer%instance_vbo = buf_arr(1)
        call gl_bind_buffer(GL_ARRAY_BUFFER, renderer%instance_vbo)
        call gl_buffer_data(GL_ARRAY_BUFFER, &
                            int(FLOATS_PER_INSTANCE * 4 * n_inst, c_int), &
                            c_loc(g_instance_data(1)), GL_DYNAMIC_DRAW)

        ! Set up instanced vertex attributes (using offset version)
        call gl_enable_vertex_attrib_array(2)
        call gl_vertex_attrib_pointer_offset(2, 4, GL_FLOAT, .false., &
                                      BYTES_PER_INSTANCE, 0)
        call gl_vertex_attrib_divisor(2, 1)

        call gl_enable_vertex_attrib_array(3)
        call gl_vertex_attrib_pointer_offset(3, 4, GL_FLOAT, .false., &
                                      BYTES_PER_INSTANCE, 16)
        call gl_vertex_attrib_divisor(3, 1)

        call gl_enable_vertex_attrib_array(4)
        call gl_vertex_attrib_pointer_offset(4, 4, GL_FLOAT, .false., &
                                      BYTES_PER_INSTANCE, 32)
        call gl_vertex_attrib_divisor(4, 1)

        call gl_enable_vertex_attrib_array(5)
        call gl_vertex_attrib_pointer_offset(5, 4, GL_FLOAT, .false., &
                                      BYTES_PER_INSTANCE, 48)
        call gl_vertex_attrib_divisor(5, 1)

        call gl_enable_vertex_attrib_array(6)
        call gl_vertex_attrib_pointer_offset(6, 3, GL_FLOAT, .false., &
                                      BYTES_PER_INSTANCE, 64)
        call gl_vertex_attrib_divisor(6, 1)

        ! Use shader
        call shader_use(renderer%body_shader)
        view_arr = camera_get_view(renderer%camera)
        proj_arr = camera_get_projection(renderer%camera)
        call set_uniform_mat4(renderer%body_shader, "u_view", view_arr)
        call set_uniform_mat4(renderer%body_shader, "u_proj", proj_arr)

        call gl_enable(GL_DEPTH_TEST)
        call gl_enable(GL_CULL_FACE)
        call gl_set_cull_face(GL_BACK)
        call gl_set_front_face(GL_CCW)

        call gl_draw_elements_instanced(GL_TRIANGLES, &
                                        renderer%sphere_mesh%n_idx, &
                                        GL_UNSIGNED_INT, &
                                        c_null_ptr, int(n_inst, c_int))

        call gl_bind_vertex_array(0_c_int)
    end subroutine renderer_render

    subroutine renderer_shutdown(renderer)
        type(renderer_t), intent(inout) :: renderer
        if (.not. renderer%initialized) return
        call mesh_destroy(renderer%sphere_mesh)
        call shader_destroy(renderer%body_shader)
        if (allocated(g_instance_data)) deallocate(g_instance_data)
        if (renderer%instance_vbo /= 0_c_int) call gl_delete_buffers(1, [renderer%instance_vbo])
        renderer%initialized = .false.
    end subroutine renderer_shutdown

    !=====================================================================
    ! Matrix multiply: result = a * b (column-major mat4)
    !=====================================================================
    pure function mat4_mul_mat4(a, b) result(r)
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
    end function mat4_mul_mat4

    subroutine write_instance(data, idx, model, r, g, b)
        real(c_float), intent(out) :: data(:)
        integer, intent(in) :: idx
        real(c_float), intent(in) :: model(16), r, g, b
        integer :: base, k
        base = (idx - 1) * FLOATS_PER_INSTANCE + 1
        do k = 1, 16
            data(base + k - 1) = model(k)
        end do
        data(base + 16) = r
        data(base + 17) = g
        data(base + 18) = b
        data(base + 19) = 0.0_c_float
    end subroutine write_instance

end module renderer
