!===============================================================================
! display_scale.f90 — Optional log-scale remap for rendered positions
!
! When the user enables "log-scale distances", the solar-system is visually
! rescaled so the outer planets get compressed and the inner planets get
! breathing room (classic textbook layout). Physics is untouched — this is a
! pure render-time remap applied radially around the Sun:
!
!   new_r = K_LOG * log10(1 + r_au)
!
! At r=0.39 (Mercury) → 1.43 AU; at r=5.2 (Jupiter) → 7.92 AU; at r=30
! (Neptune) → 14.9 AU. Directions are preserved so orbits stay circular/
! elliptical, just squished.
!
! Planets / Sun / rings get the remap CPU-side (one translate per body).
! Trails and asteroids compute positions GPU-side, so they get a matching
! remap in their vertex shaders via uniforms.
!===============================================================================
module display_scale
    use, intrinsic :: iso_c_binding, only: c_float
    implicit none
    private

    public :: K_LOG, remap_distance

    real(c_float), parameter :: K_LOG = 10.0_c_float

contains

    !---------------------------------------------------------------
    ! Remap pos around center using log radial compression. When
    ! enabled is .false., returns pos unchanged so callers can always
    ! route through this function.
    !---------------------------------------------------------------
    pure function remap_distance(pos, center, enabled) result(pp)
        real(c_float), intent(in) :: pos(3), center(3)
        logical,       intent(in) :: enabled
        real(c_float) :: pp(3), d(3), r, new_r

        if (.not. enabled) then
            pp = pos
            return
        end if
        d = pos - center
        r = sqrt(d(1)**2 + d(2)**2 + d(3)**2)
        if (r < 1.0e-6_c_float) then
            pp = pos
            return
        end if
        new_r = K_LOG * log10(1.0_c_float + r)
        pp = center + d * (new_r / r)
    end function remap_distance

end module display_scale
