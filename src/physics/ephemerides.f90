!===============================================================================
! ephemerides.f90 — J2000.0 initial conditions for Sun + 8 planets
!
! Source: "Astronomical Algorithms", Jean Meeus, 2nd ed. (1998),
!         Chapter 31, Table 31.A — mean orbital elements for J2000.0.
!
! Positions are computed from mean longitude L assuming circular orbits
! in the ecliptic plane:
!   r = (a*cos(L), a*sin(L), 0)       [AU]
!   v = (-v_circ*sin(L), v_circ*cos(L), 0)  [m/s]
!
! The Sun's velocity is set to conserve total linear momentum
! (barycentric correction).
!===============================================================================
module ephemerides
    use, intrinsic :: iso_fortran_env, only: real64, real32
    use vector3d, only: vec3, zero_vec3
    use body_mod, only: body_t
    use constants, only: AU, G_SI, M_SUN, PI
    implicit none
    private

    public :: load_solar_system

contains

    !=====================================================================
    ! load_solar_system — allocate and fill 9-body solar system
    !=====================================================================
    subroutine load_solar_system(bodies)
        type(body_t), allocatable, intent(out) :: bodies(:)

        ! Orbital data: name, mass(kg), radius(m), a(AU), L(deg at J2000)
        ! Source: Meeus 2nd ed. Table 31.A + NASA fact sheets for masses/radii
        character(len=32), parameter :: names(9) = [ &
            "Sun                             ", &
            "Mercury                         ", &
            "Venus                           ", &
            "Earth                           ", &
            "Mars                            ", &
            "Jupiter                         ", &
            "Saturn                          ", &
            "Uranus                          ", &
            "Neptune                         "]

        real(real64), parameter :: body_masses(9) = [ &
            1.98847e30_real64,  &  ! Sun
            3.3011e23_real64,   &  ! Mercury
            4.8675e24_real64,   &  ! Venus
            5.9722e24_real64,   &  ! Earth
            6.4171e23_real64,   &  ! Mars
            1.89813e27_real64,  &  ! Jupiter
            5.6834e26_real64,   &  ! Saturn
            8.6810e25_real64,   &  ! Uranus
            1.02413e26_real64]     ! Neptune

        real(real64), parameter :: body_radii(9) = [ &
            6.957e8_real64,   &  ! Sun
            2.4397e6_real64,  &  ! Mercury
            6.0518e6_real64,  &  ! Venus
            6.371e6_real64,   &  ! Earth
            3.3895e6_real64,  &  ! Mars
            6.9911e7_real64,  &  ! Jupiter
            5.8232e7_real64,  &  ! Saturn
            2.5362e7_real64,  &  ! Uranus
            2.4622e7_real64]     ! Neptune

        ! Semi-major axis (AU) and mean longitude at J2000.0 (degrees)
        ! From Meeus Table 31.A (elements for J2000.0)
        real(real64), parameter :: a_au(9) = [ &
            0.0_real64,        &  ! Sun (reference point)
            0.38709927_real64, &  ! Mercury
            0.72333566_real64, &  ! Venus
            1.00000261_real64, &  ! Earth
            1.52371034_real64, &  ! Mars
            5.20288700_real64, &  ! Jupiter
            9.53667594_real64, &  ! Saturn
            19.18916464_real64,&  ! Uranus
            30.06992276_real64]   ! Neptune

        real(real64), parameter :: L_deg(9) = [ &
            0.0_real64,         &  ! Sun
            252.25032350_real64,&  ! Mercury
            181.97909950_real64,&  ! Venus
            100.46457166_real64,&  ! Earth
            355.43299958_real64,&  ! Mars
            34.35148321_real64, &  ! Jupiter
            49.94432219_real64, &  ! Saturn
            313.23810451_real64,&  ! Uranus
            304.88003809_real64]   ! Neptune

        ! RGB colors (0..1) for later rendering
        real(real32), parameter :: body_colors(9, 3) = reshape([ &
            1.0_real32, 0.9_real32, 0.1_real32, &  ! Sun (yellow)
            0.7_real32, 0.7_real32, 0.7_real32, &  ! Mercury (gray)
            0.9_real32, 0.8_real32, 0.6_real32, &  ! Venus (tan)
            0.2_real32, 0.4_real32, 0.8_real32, &  ! Earth (blue)
            0.8_real32, 0.3_real32, 0.2_real32, &  ! Mars (red)
            0.8_real32, 0.7_real32, 0.5_real32, &  ! Jupiter (orange)
            0.9_real32, 0.8_real32, 0.6_real32, &  ! Saturn (tan)
            0.6_real32, 0.8_real32, 0.9_real32, &  ! Uranus (cyan)
            0.3_real32, 0.4_real32, 0.8_real32], &  ! Neptune (blue)
            [9, 3])

        integer :: i, n
        real(real64) :: L_rad, a_m, v_circ, theta_sin, theta_cos
        real(real64) :: px_mom, py_mom  ! total planet momentum

        n = 9
        allocate(bodies(n))

        ! Initialize all bodies
        do i = 1, n
            bodies(i)%name = names(i)
            bodies(i)%mass = body_masses(i)
            bodies(i)%radius = body_radii(i)
            bodies(i)%position = zero_vec3
            bodies(i)%velocity = zero_vec3
            bodies(i)%acceleration = zero_vec3
            bodies(i)%color = body_colors(i, :)
        end do

        ! Set positions and velocities for planets (i >= 2)
        px_mom = 0.0_real64
        py_mom = 0.0_real64

        do i = 2, n
            L_rad = L_deg(i) * PI / 180.0_real64
            a_m = a_au(i) * AU
            v_circ = sqrt(G_SI * M_SUN / a_m)

            theta_cos = cos(L_rad)
            theta_sin = sin(L_rad)

            ! Position (meters)
            bodies(i)%position = vec3( &
                a_m * theta_cos, &
                a_m * theta_sin, &
                0.0_real64)

            ! Velocity (m/s) — tangential, counterclockwise
            bodies(i)%velocity = vec3( &
                -v_circ * theta_sin, &
                 v_circ * theta_cos, &
                 0.0_real64)

            ! Accumulate planet momentum for barycenter correction
            px_mom = px_mom + body_masses(i) * bodies(i)%velocity%x
            py_mom = py_mom + body_masses(i) * bodies(i)%velocity%y
        end do

        ! Set Sun velocity to cancel total planet momentum
        bodies(1)%velocity = vec3( &
            -px_mom / body_masses(1), &
            -py_mom / body_masses(1), &
             0.0_real64)

    end subroutine load_solar_system

end module ephemerides
