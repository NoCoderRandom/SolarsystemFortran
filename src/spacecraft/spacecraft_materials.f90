module spacecraft_materials_mod
    use, intrinsic :: iso_c_binding, only: c_float
    use texture_mod, only: texture_t, texture_load, texture_destroy
    use logging, only: log_msg, LOG_INFO, LOG_WARN
    implicit none
    private

    public :: spacecraft_material_t
    public :: spacecraft_material_load, spacecraft_material_destroy

    integer, parameter :: MAX_TEXTURE_CACHE = 512

    type :: cached_texture_t
        character(len=256) :: path = ""
        type(texture_t) :: tex
        integer :: refcount = 0
    end type cached_texture_t

    type, public :: spacecraft_material_t
        character(len=64)  :: name = ""
        character(len=256) :: diffuse_path = ""
        character(len=256) :: normal_path = ""
        type(texture_t) :: diffuse
        type(texture_t) :: normal
        logical :: has_diffuse_texture = .false.
        logical :: has_normal_texture = .false.
        real(c_float) :: tint(3) = [1.0_c_float, 1.0_c_float, 1.0_c_float]
    end type spacecraft_material_t

    type(cached_texture_t), save :: texture_cache(MAX_TEXTURE_CACHE)

contains

    subroutine spacecraft_material_load(mat)
        type(spacecraft_material_t), intent(inout) :: mat
        logical :: exists

        if (len_trim(mat%diffuse_path) > 0) then
            inquire(file=trim(mat%diffuse_path), exist=exists)
            if (exists) then
                call acquire_texture(trim(mat%diffuse_path), .true., mat%diffuse)
                mat%has_diffuse_texture = mat%diffuse%valid
            else
                call log_msg(LOG_WARN, "Spacecraft material diffuse missing: " // &
                             trim(mat%diffuse_path))
            end if
        end if

        if (len_trim(mat%normal_path) > 0) then
            inquire(file=trim(mat%normal_path), exist=exists)
            if (exists) then
                call acquire_texture(trim(mat%normal_path), .false., mat%normal)
                mat%has_normal_texture = mat%normal%valid
            else
                call log_msg(LOG_INFO, "Spacecraft material normal map absent: " // &
                             trim(mat%normal_path))
            end if
        end if
    end subroutine spacecraft_material_load

    subroutine spacecraft_material_destroy(mat)
        type(spacecraft_material_t), intent(inout) :: mat
        call release_texture(mat%diffuse)
        call release_texture(mat%normal)
        mat%has_diffuse_texture = .false.
        mat%has_normal_texture = .false.
    end subroutine spacecraft_material_destroy

    subroutine acquire_texture(path, srgb, tex)
        character(len=*), intent(in) :: path
        logical, intent(in) :: srgb
        type(texture_t), intent(out) :: tex
        integer :: i, empty_idx

        tex%id = 0
        tex%width = 0
        tex%height = 0
        tex%valid = .false.
        empty_idx = 0

        do i = 1, MAX_TEXTURE_CACHE
            if (texture_cache(i)%refcount > 0 .and. trim(texture_cache(i)%path) == trim(path)) then
                texture_cache(i)%refcount = texture_cache(i)%refcount + 1
                tex = texture_cache(i)%tex
                return
            end if
            if (empty_idx == 0 .and. texture_cache(i)%refcount == 0) empty_idx = i
        end do

        if (empty_idx == 0) then
            call texture_load(tex, trim(path), srgb=srgb)
            return
        end if

        call texture_load(texture_cache(empty_idx)%tex, trim(path), srgb=srgb)
        if (.not. texture_cache(empty_idx)%tex%valid) then
            tex = texture_cache(empty_idx)%tex
            return
        end if

        texture_cache(empty_idx)%path = trim(path)
        texture_cache(empty_idx)%refcount = 1
        tex = texture_cache(empty_idx)%tex
    end subroutine acquire_texture

    subroutine release_texture(tex)
        type(texture_t), intent(inout) :: tex
        integer :: i

        if (.not. tex%valid) return
        do i = 1, MAX_TEXTURE_CACHE
            if (texture_cache(i)%refcount > 0 .and. texture_cache(i)%tex%id == tex%id) then
                texture_cache(i)%refcount = texture_cache(i)%refcount - 1
                if (texture_cache(i)%refcount <= 0) then
                    call texture_destroy(texture_cache(i)%tex)
                    texture_cache(i)%path = ""
                    texture_cache(i)%refcount = 0
                end if
                tex%id = 0
                tex%width = 0
                tex%height = 0
                tex%valid = .false.
                return
            end if
        end do

        call texture_destroy(tex)
    end subroutine release_texture

end module spacecraft_materials_mod
