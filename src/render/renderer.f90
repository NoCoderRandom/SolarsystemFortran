!===============================================================================
! renderer.f90 — Lit, textured planet rendering (Phase 7)
!
! One draw call per planet. Each planet carries a material_t owned by the
! renderer (index-parallel with the bodies array; slot 1 = Sun is ignored).
!
! Scaling:
!   World units = AU (positions / AU)
!   Visual radius = k * log(1 + R / R_earth) for planets
!===============================================================================
module renderer
    use, intrinsic :: iso_c_binding, only: c_float, c_int, c_null_ptr, c_loc
    use, intrinsic :: iso_fortran_env, only: real64
    use gl_bindings, only: &
        gl_bind_vertex_array, gl_draw_elements_instanced, &
        gl_enable, gl_disable, gl_set_cull_face, gl_set_front_face, &
        GL_TRIANGLES, GL_UNSIGNED_INT, &
        GL_DEPTH_TEST, GL_CULL_FACE, GL_BACK, GL_CCW, &
        GL_TEXTURE0, GL_TEXTURE1, GL_TEXTURE2, GL_TEXTURE3, GL_TEXTURE4
    use mesh_mod, only: mesh_t, mesh_create_sphere, mesh_destroy
    use shader_mod, only: shader_program_t, shader_load, shader_use, &
                          shader_destroy, set_uniform_mat4, set_uniform_vec3, &
                          set_uniform_float, set_uniform_int
    use camera_mod, only: camera_t, camera_init, camera_get_view, &
                          camera_get_projection
    use body_mod, only: body_t
    use mat4_math, only: mat4, mat4_translate, mat4_scale_xyz, mat4_rotate_x, &
                         mat4_to_array
    use texture_mod, only: texture_t, texture_bind
    use material_mod, only: material_t, material_destroy, &
                            MATERIAL_GENERIC, MATERIAL_EARTH, MATERIAL_GAS_GIANT, &
                            MATERIAL_SATURN_RINGS
    use rings_mod, only: rings_t, rings_render
    use logging, only: log_msg, LOG_INFO, LOG_ERROR
    use constants, only: AU
    implicit none
    private

    public :: renderer_t, renderer_init, renderer_render, renderer_shutdown, &
              renderer_set_material, renderer_set_rings, renderer_visual_radius

    real(c_float), parameter :: VISUAL_K_PLANET = 0.25_c_float
    real(real64), parameter  :: R_EARTH = 6371000.0_real64

    type, public :: renderer_t
        type(mesh_t)            :: sphere_mesh
        type(shader_program_t)  :: planet_shader
        type(camera_t)          :: camera
        type(material_t), allocatable :: materials(:)   ! 1..n_bodies
        type(rings_t), pointer  :: rings => null()
        integer                 :: saturn_index = 0
        logical                 :: initialized = .false.
    end type renderer_t

contains

    subroutine renderer_init(renderer, win_width, win_height, n_bodies)
        type(renderer_t), intent(out) :: renderer
        integer, intent(in) :: win_width, win_height, n_bodies

        call mesh_create_sphere(renderer%sphere_mesh, 48, 72)

        renderer%planet_shader = shader_load("shaders/planet.vert", "shaders/planet.frag")
        if (.not. renderer%planet_shader%valid) then
            call log_msg(LOG_ERROR, "Renderer: failed to load planet shader")
            return
        end if

        call camera_init(renderer%camera, win_width, win_height)
        allocate(renderer%materials(n_bodies))
        renderer%initialized = .true.
        call log_msg(LOG_INFO, "Renderer initialized (phase 7)")
    end subroutine renderer_init

    subroutine renderer_set_material(renderer, body_idx, mat)
        type(renderer_t), intent(inout) :: renderer
        integer, intent(in) :: body_idx
        type(material_t), intent(in) :: mat
        renderer%materials(body_idx) = mat
    end subroutine renderer_set_material

    subroutine renderer_set_rings(renderer, rings, saturn_idx)
        type(renderer_t), intent(inout) :: renderer
        type(rings_t), target, intent(in) :: rings
        integer, intent(in) :: saturn_idx
        renderer%rings => rings
        renderer%saturn_index = saturn_idx
    end subroutine renderer_set_rings

    pure function renderer_visual_radius(r_meters) result(rv)
        real(real64), intent(in) :: r_meters
        real(c_float) :: rv
        rv = real(VISUAL_K_PLANET * log(1.0_real64 + r_meters / R_EARTH), c_float)
    end function renderer_visual_radius

    subroutine renderer_render(renderer, bodies, sun_pos)
        type(renderer_t), intent(inout) :: renderer
        type(body_t), intent(in) :: bodies(:)
        real(c_float), intent(in) :: sun_pos(3)

        integer :: i, n_bodies
        real(c_float) :: pos_au(3), radius_vis, model_arr(16)
        real(c_float) :: view_arr(16), proj_arr(16), eye(3)
        real(c_float) :: half_pi
        type(mat4) :: model, trans, scale_m, axis_tilt
        half_pi = 1.5707963267948966_c_float

        if (.not. renderer%initialized) return
        n_bodies = size(bodies)
        if (n_bodies == 0) return

        call shader_use(renderer%planet_shader)
        view_arr = camera_get_view(renderer%camera)
        proj_arr = camera_get_projection(renderer%camera)
        eye = renderer%camera%eye
        call set_uniform_mat4(renderer%planet_shader, "u_view", view_arr)
        call set_uniform_mat4(renderer%planet_shader, "u_proj", proj_arr)
        call set_uniform_vec3(renderer%planet_shader, "u_cam_pos", &
                              eye(1), eye(2), eye(3))
        call set_uniform_vec3(renderer%planet_shader, "u_light_pos", &
                              sun_pos(1), sun_pos(2), sun_pos(3))
        call set_uniform_vec3(renderer%planet_shader, "u_light_color", &
                              1.0_c_float, 0.97_c_float, 0.90_c_float)
        call set_uniform_float(renderer%planet_shader, "u_ambient", 0.04_c_float)
        call set_uniform_int(renderer%planet_shader, "u_albedo", 0_c_int)
        call set_uniform_int(renderer%planet_shader, "u_normal", 1_c_int)
        call set_uniform_int(renderer%planet_shader, "u_night",  2_c_int)
        call set_uniform_int(renderer%planet_shader, "u_specular", 3_c_int)
        call set_uniform_int(renderer%planet_shader, "u_clouds", 4_c_int)

        call gl_enable(GL_DEPTH_TEST)
        call gl_enable(GL_CULL_FACE)
        call gl_set_cull_face(GL_BACK)
        call gl_set_front_face(GL_CCW)
        call gl_bind_vertex_array(renderer%sphere_mesh%vao)

        do i = 1, n_bodies
            if (trim(bodies(i)%name) == "Sun") cycle
            if (.not. renderer%materials(i)%albedo%valid) cycle

            pos_au(1) = real(bodies(i)%position%x / AU, c_float)
            pos_au(2) = real(bodies(i)%position%y / AU, c_float)
            pos_au(3) = real(bodies(i)%position%z / AU, c_float)
            radius_vis = renderer_visual_radius(bodies(i)%radius)

            trans = mat4_translate(pos_au(1), pos_au(2), pos_au(3))
            scale_m = mat4_scale_xyz(radius_vis, radius_vis, radius_vis)
            ! The sphere mesh samples v=0 at mesh +Y, but stb_image loads
            ! with vertical flip, so Earth's SOUTH pole lands at mesh +Y
            ! and NORTH at mesh -Y. Rotate -90° around X maps -Y → +Z so
            ! Earth's north pole aligns with ecliptic-north (+Z) and view_up=+Z
            ! renders the planet with north genuinely at the top.
            if (renderer%materials(i)%kind == MATERIAL_EARTH) then
                axis_tilt = mat4_rotate_x(-half_pi)
                model = mat4_mul_mat4(trans, mat4_mul_mat4(axis_tilt, scale_m))
            else
                model = mat4_mul_mat4(trans, scale_m)
            end if
            model_arr = mat4_to_array(model)

            call set_uniform_mat4(renderer%planet_shader, "u_model", model_arr)
            if (renderer%materials(i)%albedo%valid) then
                call set_uniform_vec3(renderer%planet_shader, "u_tint", &
                                      1.0_c_float, 1.0_c_float, 1.0_c_float)
            else
                call set_uniform_vec3(renderer%planet_shader, "u_tint", &
                                      bodies(i)%color(1), bodies(i)%color(2), &
                                      bodies(i)%color(3))
            end if
            call bind_material(renderer%materials(i))
            call set_uniform_int(renderer%planet_shader, "u_material_kind", &
                                 int(renderer%materials(i)%kind, c_int))
            call set_uniform_int(renderer%planet_shader, "u_has_normal_map", &
                                 merge(1_c_int, 0_c_int, renderer%materials(i)%normal%valid))
            call set_uniform_int(renderer%planet_shader, "u_has_clouds", &
                                 merge(1_c_int, 0_c_int, renderer%materials(i)%clouds%valid))
            call set_uniform_float(renderer%planet_shader, "u_shininess", &
                                   renderer%materials(i)%shininess)
            call set_uniform_float(renderer%planet_shader, "u_spec_scale", &
                                   renderer%materials(i)%spec_scale)
            call set_uniform_float(renderer%planet_shader, "u_rim_power", &
                                   renderer%materials(i)%rim_power)
            call set_uniform_vec3(renderer%planet_shader, "u_rim_color", &
                                  renderer%materials(i)%rim_color(1), &
                                  renderer%materials(i)%rim_color(2), &
                                  renderer%materials(i)%rim_color(3))

            call gl_draw_elements_instanced(GL_TRIANGLES, &
                                            renderer%sphere_mesh%n_idx, &
                                            GL_UNSIGNED_INT, &
                                            c_null_ptr, 1_c_int)
        end do

        call gl_bind_vertex_array(0_c_int)

        ! Render Saturn's rings (if attached) on top of the planet pass
        if (associated(renderer%rings) .and. renderer%saturn_index > 0 .and. &
            renderer%saturn_index <= n_bodies) then
            block
                integer :: s
                real(c_float) :: saturn_pos(3), sat_rad
                type(mat4) :: ring_model
                s = renderer%saturn_index
                saturn_pos(1) = real(bodies(s)%position%x / AU, c_float)
                saturn_pos(2) = real(bodies(s)%position%y / AU, c_float)
                saturn_pos(3) = real(bodies(s)%position%z / AU, c_float)
                sat_rad = renderer_visual_radius(bodies(s)%radius)
                ring_model = mat4_translate(saturn_pos(1), saturn_pos(2), saturn_pos(3))
                ! Rings already generated in planet-radius units; scale to sat_rad.
                ring_model = mat4_mul_mat4(ring_model, &
                    mat4_scale_xyz(sat_rad, sat_rad, sat_rad))
                call rings_render(renderer%rings, ring_model, view_arr, proj_arr, &
                                  sun_pos, saturn_pos, sat_rad)
            end block
        end if
    end subroutine renderer_render

    subroutine renderer_shutdown(renderer)
        type(renderer_t), intent(inout) :: renderer
        integer :: i
        if (.not. renderer%initialized) return
        if (allocated(renderer%materials)) then
            do i = 1, size(renderer%materials)
                call material_destroy(renderer%materials(i))
            end do
            deallocate(renderer%materials)
        end if
        call mesh_destroy(renderer%sphere_mesh)
        call shader_destroy(renderer%planet_shader)
        renderer%initialized = .false.
    end subroutine renderer_shutdown

    !-------------------------------------------------------------------
    ! Bind the material's textures to units 0..3 (albedo, normal, night, spec).
    ! Units without a valid texture keep whatever was bound last — the
    ! shader gates sampling behind uniform flags so this is harmless.
    !-------------------------------------------------------------------
    subroutine bind_material(mat)
        type(material_t), intent(in) :: mat
        call texture_bind(mat%albedo, GL_TEXTURE0)
        if (mat%normal%valid)   call texture_bind(mat%normal,   GL_TEXTURE1)
        if (mat%night%valid)    call texture_bind(mat%night,    GL_TEXTURE2)
        if (mat%specular%valid) call texture_bind(mat%specular, GL_TEXTURE3)
        if (mat%clouds%valid)   call texture_bind(mat%clouds,   GL_TEXTURE4)
    end subroutine bind_material

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

end module renderer
