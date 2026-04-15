!===============================================================================
! framebuffer.f90 — Framebuffer + texture helper
!
! Wraps a single colour-attachment FBO backed by a 2D texture, with an
! optional depth renderbuffer. Internal format and filtering are configurable
! so the same type can host the scene HDR target, half-res bright pass, blur
! ping-pong targets, and the combined bloom result.
!===============================================================================
module framebuffer_mod
    use, intrinsic :: iso_c_binding, only: c_int, c_float, c_null_ptr
    use gl_bindings, only: &
        gl_gen_framebuffers, gl_bind_framebuffer, gl_delete_framebuffers, &
        gl_framebuffer_texture_2d, gl_check_framebuffer_status, &
        gl_gen_renderbuffers, gl_bind_renderbuffer, gl_delete_renderbuffers, &
        gl_renderbuffer_storage, gl_framebuffer_renderbuffer, &
        gl_gen_textures, gl_bind_texture, gl_delete_textures, &
        gl_tex_image_2d_null, gl_tex_parameteri, &
        gl_viewport, &
        GL_FRAMEBUFFER, GL_RENDERBUFFER, GL_COLOR_ATTACHMENT0, &
        GL_DEPTH_ATTACHMENT, GL_DEPTH_COMPONENT24, GL_FRAMEBUFFER_COMPLETE, &
        GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_TEXTURE_MAG_FILTER, &
        GL_TEXTURE_WRAP_S, GL_TEXTURE_WRAP_T, GL_LINEAR, GL_CLAMP_TO_EDGE, &
        GL_RGBA, GL_RGBA16F, GL_FLOAT
    use logging, only: log_msg, LOG_ERROR, LOG_DEBUG
    implicit none
    private

    public :: framebuffer_t, framebuffer_create, framebuffer_destroy, &
              framebuffer_bind, framebuffer_unbind, framebuffer_resize

    type :: framebuffer_t
        integer(c_int) :: fbo = 0_c_int
        integer(c_int) :: color_tex = 0_c_int
        integer(c_int) :: depth_rbo = 0_c_int
        integer        :: width = 0
        integer        :: height = 0
        integer(c_int) :: internal_format = GL_RGBA16F
        logical        :: has_depth = .false.
    end type framebuffer_t

contains

    subroutine framebuffer_create(fb, w, h, internal_format, has_depth)
        type(framebuffer_t), intent(out) :: fb
        integer, intent(in) :: w, h
        integer(c_int), intent(in) :: internal_format
        logical, intent(in) :: has_depth

        integer(c_int) :: arr(1), status

        fb%width = w
        fb%height = h
        fb%internal_format = internal_format
        fb%has_depth = has_depth

        call gl_gen_framebuffers(1, arr);  fb%fbo = arr(1)
        call gl_gen_textures(1, arr);      fb%color_tex = arr(1)

        call gl_bind_texture(GL_TEXTURE_2D, fb%color_tex)
        call gl_tex_image_2d_null(GL_TEXTURE_2D, 0_c_int, internal_format, &
                                  int(w, c_int), int(h, c_int), GL_RGBA, GL_FLOAT)
        call gl_tex_parameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
        call gl_tex_parameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
        call gl_tex_parameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
        call gl_tex_parameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)

        call gl_bind_framebuffer(GL_FRAMEBUFFER, fb%fbo)
        call gl_framebuffer_texture_2d(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, &
                                       GL_TEXTURE_2D, fb%color_tex, 0_c_int)

        if (has_depth) then
            call gl_gen_renderbuffers(1, arr);  fb%depth_rbo = arr(1)
            call gl_bind_renderbuffer(GL_RENDERBUFFER, fb%depth_rbo)
            call gl_renderbuffer_storage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, &
                                         int(w, c_int), int(h, c_int))
            call gl_framebuffer_renderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, &
                                             GL_RENDERBUFFER, fb%depth_rbo)
        end if

        status = gl_check_framebuffer_status(GL_FRAMEBUFFER)
        if (status /= GL_FRAMEBUFFER_COMPLETE) then
            call log_msg(LOG_ERROR, "Framebuffer incomplete")
        else
            call log_msg(LOG_DEBUG, "Framebuffer created")
        end if

        call gl_bind_framebuffer(GL_FRAMEBUFFER, 0_c_int)
        call gl_bind_texture(GL_TEXTURE_2D, 0_c_int)
    end subroutine framebuffer_create

    subroutine framebuffer_destroy(fb)
        type(framebuffer_t), intent(inout) :: fb
        integer(c_int) :: arr(1)
        if (fb%fbo /= 0) then
            arr(1) = fb%fbo; call gl_delete_framebuffers(1, arr); fb%fbo = 0_c_int
        end if
        if (fb%color_tex /= 0) then
            arr(1) = fb%color_tex; call gl_delete_textures(1, arr); fb%color_tex = 0_c_int
        end if
        if (fb%depth_rbo /= 0) then
            arr(1) = fb%depth_rbo; call gl_delete_renderbuffers(1, arr); fb%depth_rbo = 0_c_int
        end if
        fb%width = 0; fb%height = 0
    end subroutine framebuffer_destroy

    subroutine framebuffer_bind(fb)
        type(framebuffer_t), intent(in) :: fb
        call gl_bind_framebuffer(GL_FRAMEBUFFER, fb%fbo)
        call gl_viewport(0_c_int, 0_c_int, int(fb%width, c_int), int(fb%height, c_int))
    end subroutine framebuffer_bind

    subroutine framebuffer_unbind()
        call gl_bind_framebuffer(GL_FRAMEBUFFER, 0_c_int)
    end subroutine framebuffer_unbind

    subroutine framebuffer_resize(fb, w, h)
        type(framebuffer_t), intent(inout) :: fb
        integer, intent(in) :: w, h
        integer(c_int) :: ifmt
        logical :: depth
        if (fb%width == w .and. fb%height == h) return
        ifmt = fb%internal_format
        depth = fb%has_depth
        call framebuffer_destroy(fb)
        call framebuffer_create(fb, w, h, ifmt, depth)
    end subroutine framebuffer_resize

end module framebuffer_mod
