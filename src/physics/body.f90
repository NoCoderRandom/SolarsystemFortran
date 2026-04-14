!===============================================================================
! body.f90 — Celestial body derived type (SI units throughout)
!===============================================================================
module body_mod
    use, intrinsic :: iso_fortran_env, only: real64, real32
    use vector3d, only: vec3, zero_vec3
    implicit none
    private

    public :: body_t

    !-----------------------------------------------------------------------
    ! Single celestial body (planet, moon, Sun, etc.)
    !
    ! All quantities in SI units:
    !   mass   — kg
    !   radius — m
    !   position, velocity, acceleration — m, m/s, m/s^2
    !   color  — RGB in [0, 1] for later rendering
    !-----------------------------------------------------------------------
    type, public :: body_t
        character(len=32) :: name = ""
        real(real64)      :: mass = 0.0_real64       ! kg
        real(real64)      :: radius = 0.0_real64      ! m
        type(vec3)        :: position = zero_vec3     ! m  (heliocentric)
        type(vec3)        :: velocity = zero_vec3     ! m/s
        type(vec3)        :: acceleration = zero_vec3 ! m/s^2
        real(real32)      :: color(3) = [0.0_real32, 0.0_real32, 0.0_real32] ! RGB
    end type body_t

end module body_mod
