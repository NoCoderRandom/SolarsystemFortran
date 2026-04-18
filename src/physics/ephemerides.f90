!===============================================================================
! ephemerides.f90 — J2000.0 initial conditions for Sun + 8 planets
!
! Source: "Astronomical Algorithms", Jean Meeus, 2nd ed. (1998),
!         Chapter 31, Table 31.A — mean orbital elements for J2000.0
!         (complemented by JPL fact-sheet masses/radii).
!
! Each planet is initialised from its full Keplerian element set at J2000:
!   a   — semi-major axis [AU]
!   e   — eccentricity
!   i   — inclination to the ecliptic [deg]
!   Ω   — longitude of ascending node [deg]
!   ϖ   — longitude of perihelion [deg]          (ω = ϖ − Ω)
!   L   — mean longitude [deg]                   (M₀ = L − ϖ)
!
! From these we solve Kepler's equation (M = E − e·sin E) for the eccentric
! anomaly E via Newton–Raphson, compute perifocal position/velocity, and
! rotate perifocal → ecliptic by R_z(Ω) · R_x(i) · R_z(ω). The Sun's
! velocity is then adjusted so total linear momentum is zero (barycentric
! correction).
!
! The net effect vs. the earlier circular-orbit simplification: real
! eccentricities (Mercury 0.206, Mars 0.093) produce visibly elliptical
! trails, and non-zero inclinations spread the ecliptic so Mercury/Venus
! no longer sit exactly in Earth's plane.
!===============================================================================
module ephemerides
    use, intrinsic :: iso_fortran_env, only: real64, real32
    use vector3d, only: vec3, zero_vec3
    use body_mod, only: body_t
    use constants, only: AU, G_SI, M_SUN, PI
    implicit none
    private

    public :: load_solar_system

    real(real64), parameter :: DEG2RAD = PI / 180.0_real64

contains

    !=====================================================================
    ! load_solar_system — allocate and fill 9-body solar system
    !=====================================================================
    subroutine load_solar_system(bodies)
        type(body_t), allocatable, intent(out) :: bodies(:)

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

        ! J2000.0 mean orbital elements (Meeus Table 31.A).
        ! Slot 1 (Sun) is unused — Sun stays at the origin and its velocity
        ! is set later from the total-momentum constraint.
        real(real64), parameter :: a_au(9) = [ &
            0.0_real64,         &  ! Sun
            0.38709927_real64,  &  ! Mercury
            0.72333566_real64,  &  ! Venus
            1.00000261_real64,  &  ! Earth
            1.52371034_real64,  &  ! Mars
            5.20288700_real64,  &  ! Jupiter
            9.53667594_real64,  &  ! Saturn
           19.18916464_real64,  &  ! Uranus
           30.06992276_real64]     ! Neptune

        real(real64), parameter :: e_orb(9) = [ &
            0.0_real64,         &  ! Sun
            0.20563593_real64,  &  ! Mercury
            0.00677672_real64,  &  ! Venus
            0.01671123_real64,  &  ! Earth
            0.09339410_real64,  &  ! Mars
            0.04838624_real64,  &  ! Jupiter
            0.05386179_real64,  &  ! Saturn
            0.04725744_real64,  &  ! Uranus
            0.00859048_real64]     ! Neptune

        real(real64), parameter :: inc_deg(9) = [ &
            0.0_real64,         &  ! Sun
            7.00497902_real64,  &  ! Mercury
            3.39467605_real64,  &  ! Venus
           -0.00001531_real64,  &  ! Earth (≈0 — ecliptic is its reference)
            1.84969142_real64,  &  ! Mars
            1.30439695_real64,  &  ! Jupiter
            2.48599187_real64,  &  ! Saturn
            0.77263783_real64,  &  ! Uranus
            1.77004347_real64]     ! Neptune

        real(real64), parameter :: node_deg(9) = [ &
            0.0_real64,          &  ! Sun
           48.33076593_real64,   &  ! Mercury
           76.67984255_real64,   &  ! Venus
            0.0_real64,          &  ! Earth (convention: Ω undefined at i=0)
           49.55953891_real64,   &  ! Mars
          100.47390909_real64,   &  ! Jupiter
          113.66242448_real64,   &  ! Saturn
           74.01692503_real64,   &  ! Uranus
          131.78422574_real64]      ! Neptune

        ! Longitude of perihelion ϖ = Ω + ω
        real(real64), parameter :: peri_deg(9) = [ &
            0.0_real64,          &  ! Sun
           77.45779628_real64,   &  ! Mercury
          131.60246718_real64,   &  ! Venus
          102.93768193_real64,   &  ! Earth
          -23.94362959_real64,   &  ! Mars
           14.72847983_real64,   &  ! Jupiter
           92.59887831_real64,   &  ! Saturn
          170.95427630_real64,   &  ! Uranus
           44.96476227_real64]      ! Neptune

        ! Mean longitude at J2000 epoch, L = Ω + ω + M
        real(real64), parameter :: L_deg(9) = [ &
            0.0_real64,         &  ! Sun
          252.25032350_real64,  &  ! Mercury
          181.97909950_real64,  &  ! Venus
          100.46457166_real64,  &  ! Earth
           -4.55343205_real64,  &  ! Mars  (= 355.446...)
           34.39644051_real64,  &  ! Jupiter
           49.95424423_real64,  &  ! Saturn
          313.23810451_real64,  &  ! Uranus
         -55.12002969_real64]      ! Neptune (= 304.880...)

        real(real32), parameter :: body_colors(3, 9) = reshape([ &
            1.0_real32, 0.9_real32, 0.1_real32, &  ! Sun
            0.7_real32, 0.7_real32, 0.7_real32, &  ! Mercury
            0.9_real32, 0.8_real32, 0.6_real32, &  ! Venus
            0.2_real32, 0.4_real32, 0.8_real32, &  ! Earth
            0.8_real32, 0.3_real32, 0.2_real32, &  ! Mars
            0.8_real32, 0.7_real32, 0.5_real32, &  ! Jupiter
            0.9_real32, 0.8_real32, 0.6_real32, &  ! Saturn
            0.6_real32, 0.8_real32, 0.9_real32, &  ! Uranus
            0.3_real32, 0.4_real32, 0.8_real32], & ! Neptune
            [3, 9])

        integer :: i, n
        real(real64) :: a_m, e, M0, E_anom, inc, Om, om_arg
        real(real64) :: cosE, sinE, sqrt_1me2, r_sep
        real(real64) :: xp, yp, vxp, vyp, n_mean, factor
        real(real64) :: pos_xyz(3), vel_xyz(3)
        real(real64) :: px_mom, py_mom, pz_mom

        n = 9
        allocate(bodies(n))

        do i = 1, n
            bodies(i)%name         = names(i)
            bodies(i)%mass         = body_masses(i)
            bodies(i)%radius       = body_radii(i)
            bodies(i)%position     = zero_vec3
            bodies(i)%velocity     = zero_vec3
            bodies(i)%acceleration = zero_vec3
            bodies(i)%color        = body_colors(:, i)
        end do

        px_mom = 0.0_real64
        py_mom = 0.0_real64
        pz_mom = 0.0_real64

        do i = 2, n
            a_m    = a_au(i) * AU
            e      = e_orb(i)
            inc    = inc_deg(i)  * DEG2RAD
            Om     = node_deg(i) * DEG2RAD
            om_arg = (peri_deg(i) - node_deg(i)) * DEG2RAD          ! ω = ϖ − Ω
            M0     = wrap_rad((L_deg(i) - peri_deg(i)) * DEG2RAD)   ! M = L − ϖ

            E_anom = solve_kepler(M0, e)

            cosE      = cos(E_anom)
            sinE      = sin(E_anom)
            sqrt_1me2 = sqrt(max(0.0_real64, 1.0_real64 - e*e))
            r_sep     = a_m * (1.0_real64 - e*cosE)
            n_mean    = sqrt(G_SI * M_SUN / a_m**3)
            factor    = a_m * a_m * n_mean / r_sep

            ! Perifocal frame: x along periapsis, y along semi-latus rectum
            xp  = a_m * (cosE - e)
            yp  = a_m * sqrt_1me2 * sinE
            vxp = -factor * sinE
            vyp =  factor * sqrt_1me2 * cosE

            call perifocal_to_ecliptic([xp,  yp,  0.0_real64], Om, inc, om_arg, pos_xyz)
            call perifocal_to_ecliptic([vxp, vyp, 0.0_real64], Om, inc, om_arg, vel_xyz)

            bodies(i)%position = vec3(pos_xyz(1), pos_xyz(2), pos_xyz(3))
            bodies(i)%velocity = vec3(vel_xyz(1), vel_xyz(2), vel_xyz(3))

            px_mom = px_mom + body_masses(i) * vel_xyz(1)
            py_mom = py_mom + body_masses(i) * vel_xyz(2)
            pz_mom = pz_mom + body_masses(i) * vel_xyz(3)
        end do

        ! Zero total linear momentum by shifting the Sun's velocity.
        bodies(1)%velocity = vec3( &
            -px_mom / body_masses(1), &
            -py_mom / body_masses(1), &
            -pz_mom / body_masses(1))

    end subroutine load_solar_system

    !---------------------------------------------------------------------
    ! Newton–Raphson solver for Kepler's equation  M = E − e·sin E.
    ! Converges to double precision within ~8 iterations for e < 0.3.
    !---------------------------------------------------------------------
    pure function solve_kepler(M, ecc) result(E_out)
        real(real64), intent(in) :: M, ecc
        real(real64) :: E_out, delta
        integer :: it

        E_out = M + ecc * sin(M)   ! warm-start: first-order expansion
        do it = 1, 20
            delta = (E_out - ecc*sin(E_out) - M) / &
                    (1.0_real64 - ecc*cos(E_out))
            E_out = E_out - delta
            if (abs(delta) < 1.0e-14_real64) exit
        end do
    end function solve_kepler

    !---------------------------------------------------------------------
    ! Rotate a perifocal-frame vector (x pointing at periapsis, z along
    ! orbital angular momentum) into ecliptic coordinates:
    !     R_z(Ω) · R_x(i) · R_z(ω) · v_perifocal
    !---------------------------------------------------------------------
    pure subroutine perifocal_to_ecliptic(v_peri, Om, inc, om_arg, v_out)
        real(real64), intent(in)  :: v_peri(3), Om, inc, om_arg
        real(real64), intent(out) :: v_out(3)

        real(real64) :: cw, sw, ci, si, cn, sn
        real(real64) :: x1, y1, y2, z2

        cw = cos(om_arg); sw = sin(om_arg)
        ci = cos(inc);    si = sin(inc)
        cn = cos(Om);     sn = sin(Om)

        x1 = cw * v_peri(1) - sw * v_peri(2)
        y1 = sw * v_peri(1) + cw * v_peri(2)

        y2 = ci * y1
        z2 = si * y1

        v_out(1) = cn * x1 - sn * y2
        v_out(2) = sn * x1 + cn * y2
        v_out(3) = z2
    end subroutine perifocal_to_ecliptic

    !---------------------------------------------------------------------
    ! Wrap an angle to (−π, π] for numerical conditioning of the Kepler
    ! solver. Meeus's L and ϖ are given in [0°, 360°), so their difference
    ! can fall outside that interval.
    !---------------------------------------------------------------------
    pure function wrap_rad(x) result(y)
        real(real64), intent(in) :: x
        real(real64) :: y
        real(real64), parameter :: TWO_PI = 2.0_real64 * PI
        y = x - TWO_PI * floor((x + PI) / TWO_PI)
    end function wrap_rad

end module ephemerides
