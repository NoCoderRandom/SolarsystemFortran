!===============================================================================
! texture.f90 — 2D texture loading via stb_image
!
! Provides a thin type that wraps an OpenGL texture ID plus metadata, and
! a texture_load() routine that reads a file with stb_image, uploads it
! as sRGB8_ALPHA8 (if srgb=true) or RGBA8 (otherwise), generates mipmaps,
! and configures anisotropic filtering + repeat wrapping.
!===============================================================================
module texture_mod
    use, intrinsic :: iso_c_binding, only: c_int, c_char, c_ptr, c_null_char, &
                                           c_null_ptr, c_float, c_associated
    use gl_bindings, only: &
        gl_gen_textures, gl_bind_texture, gl_delete_textures, &
        gl_tex_image_2d, gl_tex_parameteri, gl_active_texture, &
        gl_generate_mipmap, gl_get_float, &
        GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_TEXTURE_MAG_FILTER, &
        GL_TEXTURE_WRAP_S, GL_TEXTURE_WRAP_T, &
        GL_LINEAR, GL_LINEAR_MIPMAP_LINEAR, GL_REPEAT, GL_CLAMP_TO_EDGE, &
        GL_RGBA, GL_SRGB8_ALPHA8, GL_UNSIGNED_BYTE, &
        GL_TEXTURE_MAX_ANISOTROPY, GL_MAX_TEXTURE_MAX_ANISO
    use logging, only: log_msg, LOG_INFO, LOG_ERROR
    implicit none
    private

    public :: texture_t, texture_load, texture_bind, texture_destroy

    type :: texture_t
        integer(c_int) :: id     = 0_c_int
        integer        :: width  = 0
        integer        :: height = 0
        logical        :: valid  = .false.
    end type texture_t

    interface
        function ss_load_image(path, w, h, ch, pixels, flip) bind(c, name="ss_load_image")
            import :: c_int, c_char, c_ptr
            character(kind=c_char), intent(in) :: path(*)
            integer(c_int), intent(out) :: w, h, ch
            type(c_ptr), intent(out)    :: pixels
            integer(c_int), value, intent(in) :: flip
            integer(c_int) :: ss_load_image
        end function ss_load_image

        subroutine ss_free_image(pixels) bind(c, name="ss_free_image")
            import :: c_ptr
            type(c_ptr), value, intent(in) :: pixels
        end subroutine ss_free_image
    end interface

contains

    subroutine texture_load(tex, path, srgb, clamp)
        type(texture_t), intent(out) :: tex
        character(len=*), intent(in) :: path
        logical, intent(in), optional :: srgb, clamp

        character(kind=c_char), allocatable :: cpath(:)
        integer(c_int) :: w, h, ch, rc
        integer(c_int) :: internal_fmt, wrap_mode
        integer(c_int) :: ids(1)
        type(c_ptr) :: pixels
        real(c_float) :: max_aniso
        logical :: is_srgb, do_clamp
        integer :: i

        is_srgb = .true.
        if (present(srgb)) is_srgb = srgb
        do_clamp = .false.
        if (present(clamp)) do_clamp = clamp

        allocate(cpath(len_trim(path) + 1))
        do i = 1, len_trim(path)
            cpath(i) = path(i:i)
        end do
        cpath(len_trim(path) + 1) = c_null_char

        rc = ss_load_image(cpath, w, h, ch, pixels, 1_c_int)
        deallocate(cpath)
        if (rc == 0_c_int .or. .not. c_associated(pixels)) then
            call log_msg(LOG_ERROR, "texture_load: failed to load " // trim(path))
            tex%valid = .false.
            return
        end if

        if (is_srgb) then
            internal_fmt = GL_SRGB8_ALPHA8
        else
            internal_fmt = int(GL_RGBA, c_int)
        end if

        if (do_clamp) then
            wrap_mode = GL_CLAMP_TO_EDGE
        else
            wrap_mode = GL_REPEAT
        end if

        call gl_gen_textures(1_c_int, ids)
        tex%id = ids(1)
        tex%width = int(w)
        tex%height = int(h)

        call gl_bind_texture(GL_TEXTURE_2D, tex%id)
        call gl_tex_image_2d(GL_TEXTURE_2D, 0_c_int, internal_fmt, w, h, &
                             0_c_int, int(GL_RGBA, c_int), &
                             int(GL_UNSIGNED_BYTE, c_int), pixels)
        call ss_free_image(pixels)

        call gl_generate_mipmap(GL_TEXTURE_2D)
        call gl_tex_parameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR)
        call gl_tex_parameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
        call gl_tex_parameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, wrap_mode)
        call gl_tex_parameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, wrap_mode)

        call gl_get_float(GL_MAX_TEXTURE_MAX_ANISO, max_aniso)
        if (max_aniso > 1.0_c_float) then
            if (max_aniso > 16.0_c_float) max_aniso = 16.0_c_float
            call gl_tex_parameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_ANISOTROPY, &
                                   int(max_aniso, c_int))
        end if

        call gl_bind_texture(GL_TEXTURE_2D, 0_c_int)

        tex%valid = .true.
        call log_msg(LOG_INFO, "texture_load: " // trim(path))
    end subroutine texture_load

    subroutine texture_bind(tex, unit)
        type(texture_t), intent(in) :: tex
        integer(c_int), intent(in) :: unit
        call gl_active_texture(unit)
        call gl_bind_texture(GL_TEXTURE_2D, tex%id)
    end subroutine texture_bind

    subroutine texture_destroy(tex)
        type(texture_t), intent(inout) :: tex
        integer(c_int) :: ids(1)
        if (tex%id /= 0_c_int) then
            ids(1) = tex%id
            call gl_delete_textures(1_c_int, ids)
        end if
        tex%id = 0_c_int
        tex%valid = .false.
    end subroutine texture_destroy

end module texture_mod
