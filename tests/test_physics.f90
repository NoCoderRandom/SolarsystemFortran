!===============================================================================
! test_physics.f90 — Standalone physics verification test
!
! Loads the 9-body solar system, advances 1 Earth year with dt=3600 s,
! and prints:
!   1. Table of final body positions (AU) and speeds (km/s)
!   2. Energy drift % and angular-momentum drift %
!   3. Earth's orbital period error vs 365.25 days
!===============================================================================
program test_physics
    use, intrinsic :: iso_fortran_env, only: real64, output_unit
    use integrator, only: velocity_verlet_t
    use constants, only: AU, SEC_PER_DAY, DAYS_PER_YEAR, PI, DEFAULT_SOFTENING
    use vector3d, only: vec3, norm
    use body_mod, only: body_t
    use ephemerides, only: load_solar_system
    use simulation, only: simulation_t
    use logging, only: log_init, log_shutdown, log_msg, &
                       LOG_INFO, LOG_DEBUG
    implicit none

    type(simulation_t)      :: sim
    type(velocity_verlet_t) :: verlet
    real(real64)            :: dt, t, t_end
    real(real64)            :: ke_0, pe_0, e_0
    real(real64)            :: ke_f, pe_f, e_f
    type(vec3)              :: L_0, L_f
    real(real64)            :: e_drift, L_drift
    real(real64)            :: theta_0, theta_prev, theta_curr, d_theta
    real(real64)            :: total_angle, T_sim, period_error_days
    integer                 :: step_count
    integer                 :: earth_idx, n
    integer                 :: i

    !-----------------------------------------------------------------------
    ! Initialize logging at DEBUG level for full output
    !-----------------------------------------------------------------------
    call log_init(LOG_DEBUG)
    call log_msg(LOG_INFO, "=== Phase 2 Physics Test ===")

    !-----------------------------------------------------------------------
    ! Load the 9-body solar system
    !-----------------------------------------------------------------------
    call load_solar_system(sim%bodies)

    ! Configure Velocity Verlet integrator
    verlet%softening = DEFAULT_SOFTENING
    call sim%set_integrator(verlet)

    n = sim%n_bodies()
    earth_idx = sim%get_body_by_name("Earth")
    if (earth_idx == 0) then
        call log_msg(LOG_INFO, "ERROR: Earth not found in body list")
        call log_shutdown()
        stop 1
    end if

    !-----------------------------------------------------------------------
    ! Record initial state
    !-----------------------------------------------------------------------
    ke_0 = sim%kinetic_energy()
    pe_0 = sim%potential_energy()
    e_0 = ke_0 + pe_0
    L_0 = sim%angular_momentum()

    ! Initial Earth angle for period tracking
    theta_0 = atan2(sim%bodies(earth_idx)%position%y, &
                    sim%bodies(earth_idx)%position%x)
    theta_prev = theta_0
    total_angle = 0.0_real64

    call log_msg(LOG_INFO, "Initial total energy:  " // &
                 fmt_sci(e_0) // " J")
    call log_msg(LOG_INFO, "Initial |L|:           " // &
                 fmt_sci(norm(L_0)) // " kg m^2/s")
    call log_msg(LOG_INFO, "Initial KE:            " // &
                 fmt_sci(ke_0) // " J")
    call log_msg(LOG_INFO, "Initial PE:            " // &
                 fmt_sci(pe_0) // " J")

    !-----------------------------------------------------------------------
    ! Advance for 1 Earth year with dt = 3600 s (1 hour)
    !-----------------------------------------------------------------------
    dt = 3600.0_real64
    t_end = DAYS_PER_YEAR * SEC_PER_DAY
    t = 0.0_real64
    step_count = 0

    call log_msg(LOG_INFO, "Integrating for " // fmt_f1(t_end / SEC_PER_DAY) // &
                 " days with dt = " // fmt_f0(dt) // " s (" // &
                 fmt_i0(int(t_end / dt)) // " steps)...")

    do while (t < t_end)
        call sim%step(dt)
        t = t + dt
        step_count = step_count + 1

        ! Track cumulative Earth angular displacement for period computation
        theta_curr = atan2(sim%bodies(earth_idx)%position%y, &
                           sim%bodies(earth_idx)%position%x)
        d_theta = theta_curr - theta_prev
        ! Handle branch cut at +/- pi
        if (d_theta >  PI) d_theta = d_theta - 2.0_real64 * PI
        if (d_theta < -PI) d_theta = d_theta + 2.0_real64 * PI
        total_angle = total_angle + d_theta
        theta_prev = theta_curr
    end do

    !-----------------------------------------------------------------------
    ! Record final state
    !-----------------------------------------------------------------------
    ke_f = sim%kinetic_energy()
    pe_f = sim%potential_energy()
    e_f = ke_f + pe_f
    L_f = sim%angular_momentum()

    !-----------------------------------------------------------------------
    ! Compute conservation diagnostics
    !-----------------------------------------------------------------------
    e_drift = 100.0_real64 * (e_f - e_0) / abs(e_0)
    L_drift = 100.0_real64 * (norm(L_f) - norm(L_0)) / norm(L_0)

    ! Earth orbital period from angular displacement
    ! Over 1 year, Earth should sweep 2*pi radians.
    ! T_simulated = t_actual * 2*pi / |total_angle|
    if (abs(total_angle) > 1.0e-10_real64) then
        T_sim = t * 2.0_real64 * PI / abs(total_angle)
        period_error_days = T_sim / SEC_PER_DAY - DAYS_PER_YEAR
    else
        T_sim = 0.0_real64
        period_error_days = 0.0_real64
    end if

    !-----------------------------------------------------------------------
    ! Print results
    !-----------------------------------------------------------------------
    call print_separator()
    call log_msg(LOG_INFO, "Solar System State After " // &
                 fmt_f3(t / SEC_PER_DAY) // " Days")
    call print_separator()

    ! Header
    write(output_unit, "(A)") &
        " Body          |  x (AU)    |  y (AU)    |  z (AU)    | Speed (km/s)"
    write(output_unit, "(A)") &
        " --------------|------------|------------|------------|-------------"

    do i = 1, n
        write(output_unit, "(A15, '|', F12.6, '|', F12.6, '|', F12.6, '|', F13.3)") &
            trim(sim%bodies(i)%name), &
            sim%bodies(i)%position%x / AU, &
            sim%bodies(i)%position%y / AU, &
            sim%bodies(i)%position%z / AU, &
            norm(sim%bodies(i)%velocity) / 1000.0_real64
    end do

    call print_separator()
    call log_msg(LOG_INFO, "Energy drift:             " // &
                 trim(adjustl(fmt_drift(e_drift))) // " %")
    call log_msg(LOG_INFO, "Angular momentum drift:   " // &
                 trim(adjustl(fmt_drift(L_drift))) // " %")
    call log_msg(LOG_INFO, "Earth orbital period:     " // &
                 fmt_f3(T_sim / SEC_PER_DAY) // " days" // &
                 "  (error: " // fmt_f3(period_error_days) // " days)")
    call print_separator()

    !-----------------------------------------------------------------------
    ! Pass/fail criteria
    !-----------------------------------------------------------------------
    call log_msg(LOG_INFO, "=== Verification Criteria ===")
    if (abs(e_drift) < 0.1_real64) then
        call log_msg(LOG_INFO, "  Energy drift       < 0.1%    PASS (" // &
                     trim(adjustl(fmt_drift(e_drift))) // "%)")
    else
        call log_msg(LOG_INFO, "  Energy drift       < 0.1%    FAIL (" // &
                     trim(adjustl(fmt_drift(e_drift))) // "%)")
    end if

    if (abs(L_drift) < 0.01_real64) then
        call log_msg(LOG_INFO, "  L drift            < 0.01%   PASS (" // &
                     trim(adjustl(fmt_drift(L_drift))) // "%)")
    else
        call log_msg(LOG_INFO, "  L drift            < 0.01%   FAIL (" // &
                     trim(adjustl(fmt_drift(L_drift))) // "%)")
    end if

    if (abs(period_error_days) < 1.0_real64) then
        call log_msg(LOG_INFO, "  Earth period error < 1 day   PASS (" // &
                     fmt_f3(period_error_days) // " days)")
    else
        call log_msg(LOG_INFO, "  Earth period error < 1 day   FAIL (" // &
                     fmt_f3(period_error_days) // " days)")
    end if
    call print_separator()

    !-----------------------------------------------------------------------
    ! Cleanup
    !-----------------------------------------------------------------------
    call sim%shutdown()
    call log_shutdown()

contains

    !-----------------------------------------------------------------------
    ! Formatting helpers
    !=====================================================================
    pure function fmt_sci(v) result(s)
        real(real64), intent(in) :: v
        character(len=24) :: s
        write(s, "(1PE14.6)") v
    end function fmt_sci

    pure function fmt_f0(v) result(s)
        real(real64), intent(in) :: v
        character(len=24) :: s
        write(s, "(F0.0)") v
    end function fmt_f0

    pure function fmt_f1(v) result(s)
        real(real64), intent(in) :: v
        character(len=24) :: s
        write(s, "(F0.1)") v
    end function fmt_f1

    pure function fmt_f3(v) result(s)
        real(real64), intent(in) :: v
        character(len=24) :: s
        write(s, "(F0.3)") v
    end function fmt_f3

    pure function fmt_drift(v) result(s)
        ! Scientific notation for very small drift percentages
        real(real64), intent(in) :: v
        character(len=24) :: s
        if (abs(v) > 0.001_real64) then
            write(s, "(F10.6)") v
        else
            write(s, "(1PE14.6)") v
        end if
    end function fmt_drift

    pure function fmt_i0(v) result(s)
        integer, intent(in) :: v
        character(len=24) :: s
        write(s, "(I0)") v
    end function fmt_i0

    subroutine print_separator()
        write(output_unit, "(A)") "============================================================"
        flush(unit=output_unit)
    end subroutine print_separator

end program test_physics
