!===============================================================================
! constants.f90 — Physical and astronomical constants (SI units)
!===============================================================================
module constants
    use, intrinsic :: iso_fortran_env, only: real64, real32
    implicit none
    private

    !-----------------------------------------------------------------------
    ! Working-precision kind parameters (re-exported for convenience)
    !-----------------------------------------------------------------------
    integer, parameter, public :: wp = real64

    !-----------------------------------------------------------------------
    ! Physical constants
    !-----------------------------------------------------------------------
    ! Gravitational constant, CODATA 2018: 6.67430(15)e-11 m^3 kg^-1 s^-2
    real(wp), parameter, public :: G_SI = 6.67430e-11_wp

    ! Astronomical unit, IAU 2012 resolution B2 (exact): 149597870700 m
    real(wp), parameter, public :: AU = 149597870700.0_wp

    ! Solar mass (kg), IAU 2015 nominal solar mass parameter
    real(wp), parameter, public :: M_SUN = 1.98847e30_wp

    ! Pi
    real(wp), parameter, public :: PI = 3.14159265358979323846_wp

    !-----------------------------------------------------------------------
    ! Time conversions
    !-----------------------------------------------------------------------
    real(wp), parameter, public :: SEC_PER_DAY   = 86400.0_wp
    real(wp), parameter, public :: DAYS_PER_YEAR = 365.25_wp
    real(wp), parameter, public :: SEC_PER_YEAR  = SEC_PER_DAY * DAYS_PER_YEAR

    !-----------------------------------------------------------------------
    ! J2000.0 epoch — Julian Date 2451545.0 (2000-01-01 12:00 TT)
    !-----------------------------------------------------------------------
    real(wp), parameter, public :: J2000_JD = 2451545.0_wp

    !-----------------------------------------------------------------------
    ! Numerical parameters
    !-----------------------------------------------------------------------
    ! Default softening length (m) — prevents singularities at small r_ij
    real(wp), parameter, public :: DEFAULT_SOFTENING = 1.0e6_wp

end module constants
