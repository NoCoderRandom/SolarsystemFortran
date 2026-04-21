module spacecraft_renderer_mod
    use, intrinsic :: iso_c_binding, only: c_float, c_int, c_null_ptr
    use logging, only: log_msg, LOG_INFO, LOG_WARN, LOG_ERROR
    use shader_mod, only: shader_program_t, shader_load, shader_use, shader_destroy, &
                          set_uniform_mat4, set_uniform_vec3, set_uniform_int
    use camera_mod, only: camera_t, camera_get_view, camera_get_projection
    use mat4_math, only: mat4, mat4_translate, mat4_scale_xyz, mat4_rotate_x, &
                         mat4_rotate_y, mat4_to_array
    use gl_bindings, only: gl_bind_vertex_array, gl_draw_elements_instanced, &
                           GL_TRIANGLES, GL_UNSIGNED_INT, GL_TEXTURE0, GL_TEXTURE1
    use spacecraft_assets_mod, only: spacecraft_model_t, spacecraft_model_load_obj, &
                                     spacecraft_model_destroy
    use texture_mod, only: texture_bind
    implicit none
    private

    public :: spacecraft_renderer_t, spacecraft_renderer_init, &
              spacecraft_renderer_set_model, spacecraft_renderer_clear_model, &
              spacecraft_renderer_render, &
              spacecraft_renderer_shutdown

    type, public :: spacecraft_renderer_t
        logical :: initialized = .false.
        type(shader_program_t) :: shader
        type(spacecraft_model_t) :: model
    end type spacecraft_renderer_t

contains

    subroutine spacecraft_renderer_init(renderer)
        type(spacecraft_renderer_t), intent(out) :: renderer

        renderer%shader = shader_load("shaders/spacecraft.vert", "shaders/spacecraft.frag")
        if (.not. renderer%shader%valid) then
            call log_msg(LOG_ERROR, "Spacecraft renderer: failed to load shader")
            return
        end if

        renderer%initialized = .true.
        call log_msg(LOG_INFO, "Spacecraft renderer initialized")
    end subroutine spacecraft_renderer_init

    subroutine spacecraft_renderer_set_model(renderer, model_path)
        type(spacecraft_renderer_t), intent(inout) :: renderer
        character(len=*), intent(in) :: model_path
        logical :: exists

        if (.not. renderer%initialized) return
        if (renderer%model%loaded) then
            if (trim(renderer%model%source_path) == trim(model_path)) return
        end if
        call spacecraft_model_destroy(renderer%model)

        inquire(file=trim(model_path), exist=exists)
        if (.not. exists) then
            call log_msg(LOG_WARN, "Spacecraft model not found: " // trim(model_path))
            return
        end if

        call spacecraft_model_load_obj(renderer%model, trim(model_path))
        if (.not. renderer%model%loaded) then
            call log_msg(LOG_WARN, "Spacecraft renderer could not load model: " // trim(model_path))
        end if
    end subroutine spacecraft_renderer_set_model

    subroutine spacecraft_renderer_clear_model(renderer)
        type(spacecraft_renderer_t), intent(inout) :: renderer

        if (.not. renderer%initialized) return
        call spacecraft_model_destroy(renderer%model)
    end subroutine spacecraft_renderer_clear_model

    subroutine spacecraft_renderer_render(renderer, cam, light_pos, model_pos, visual_scale, &
                                          model_pitch, model_yaw)
        type(spacecraft_renderer_t), intent(inout) :: renderer
        type(camera_t), intent(in) :: cam
        real(c_float), intent(in) :: light_pos(3)
        real(c_float), intent(in) :: model_pos(3)
        real(c_float), intent(in) :: visual_scale
        real(c_float), intent(in) :: model_pitch
        real(c_float), intent(in) :: model_yaw
        real(c_float) :: view_arr(16), proj_arr(16), model_arr(16)
        type(mat4) :: model
        real(c_float), parameter :: BASE_SCALE = 0.12_c_float
        real(c_float) :: draw_scale
        integer :: i

        if (.not. renderer%initialized) return
        if (.not. renderer%model%loaded) return
        if (.not. allocated(renderer%model%submeshes)) return

        call shader_use(renderer%shader)
        view_arr = camera_get_view(cam)
        proj_arr = camera_get_projection(cam)
        draw_scale = BASE_SCALE * max(visual_scale, 0.05_c_float)
        model = mat4_translate(model_pos(1), model_pos(2), model_pos(3))
        model = mat4_mul_mat4(model, mat4_mul_mat4(mat4_rotate_y(model_yaw), &
                                                   mat4_mul_mat4(mat4_rotate_x(model_pitch), &
                                                                 mat4_scale_xyz(draw_scale, draw_scale, draw_scale))))
        model_arr = mat4_to_array(model)

        call set_uniform_mat4(renderer%shader, "u_model", model_arr)
        call set_uniform_mat4(renderer%shader, "u_view", view_arr)
        call set_uniform_mat4(renderer%shader, "u_proj", proj_arr)
        call set_uniform_vec3(renderer%shader, "u_light_pos", light_pos(1), light_pos(2), light_pos(3))
        call set_uniform_vec3(renderer%shader, "u_cam_pos", cam%eye(1), cam%eye(2), cam%eye(3))
        do i = 1, size(renderer%model%submeshes)
            if (.not. renderer%model%submeshes(i)%mesh%valid) cycle

            call set_uniform_vec3(renderer%shader, "u_tint", &
                                  renderer%model%submeshes(i)%material%tint(1), &
                                  renderer%model%submeshes(i)%material%tint(2), &
                                  renderer%model%submeshes(i)%material%tint(3))
            call set_uniform_int(renderer%shader, "u_has_diffuse", &
                                 merge(1_c_int, 0_c_int, &
                                       renderer%model%submeshes(i)%material%has_diffuse_texture))
            call set_uniform_int(renderer%shader, "u_has_normal_map", &
                                 merge(1_c_int, 0_c_int, &
                                       renderer%model%submeshes(i)%material%has_normal_texture))

            if (renderer%model%submeshes(i)%material%has_diffuse_texture) then
                call texture_bind(renderer%model%submeshes(i)%material%diffuse, GL_TEXTURE0)
            end if
            if (renderer%model%submeshes(i)%material%has_normal_texture) then
                call texture_bind(renderer%model%submeshes(i)%material%normal, GL_TEXTURE1)
            end if

            call gl_bind_vertex_array(renderer%model%submeshes(i)%mesh%vao)
            call gl_draw_elements_instanced(GL_TRIANGLES, renderer%model%submeshes(i)%mesh%n_idx, &
                                            GL_UNSIGNED_INT, c_null_ptr, 1_c_int)
        end do
        call gl_bind_vertex_array(0_c_int)
    end subroutine spacecraft_renderer_render

    subroutine spacecraft_renderer_shutdown(renderer)
        type(spacecraft_renderer_t), intent(inout) :: renderer
        call spacecraft_model_destroy(renderer%model)
        call shader_destroy(renderer%shader)
        renderer%initialized = .false.
    end subroutine spacecraft_renderer_shutdown

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

end module spacecraft_renderer_mod
