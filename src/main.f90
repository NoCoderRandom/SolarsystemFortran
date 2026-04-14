!===============================================================================
! main.f90 — Entry point: init physics + renderer, fixed-timestep main loop
!
! Time scale: 1 simulated day per real second (configurable via
! TIME_SCALE parameter). Uses accumulator pattern to decouple physics
! dt from rendering framerate, with interpolation for smooth motion.
!
! Caps physics steps per frame to 8 to avoid spiral-of-death.
!===============================================================================
program solarsim
    use, intrinsic :: iso_c_binding, only: c_float, c_double, c_int
    use, intrinsic :: iso_fortran_env, only: real32, real64
    use logging, only: log_init, log_shutdown, log_msg, &
                       LOG_DEBUG, LOG_INFO, LOG_ERROR
    use window,  only: window_open, window_close, &
                       window_should_close, window_swap_buffers, &
                       window_clear, window_poll_events, window_get_time
    use vector3d, only: vec3, operator(*), operator(+)
    use body_mod, only: body_t
    use ephemerides, only: load_solar_system
    use integrator, only: velocity_verlet_t, compute_all_accelerations
    use simulation, only: simulation_t
    use renderer, only: renderer_t, renderer_init, renderer_render, &
                        renderer_shutdown
    implicit none

    !-----------------------------------------------------------------------
    ! Time configuration
    !-----------------------------------------------------------------------
    ! Simulated seconds per real second. 1.0 = 1 day/sec, 10.0 = 10 days/sec
    real(real64), parameter :: TIME_SCALE = 1.0_real64

    ! Physics timestep: 1 hour = 3600 s (same as test_physics)
    real(real64), parameter :: PHYSICS_DT = 3600.0_real64

    ! Max physics steps per frame (prevent spiral-of-death)
    integer, parameter :: MAX_STEPS_PER_FRAME = 8

    !-----------------------------------------------------------------------
    ! State
    !-----------------------------------------------------------------------
    type(simulation_t)  :: sim
    type(renderer_t)    :: renderer
    type(velocity_verlet_t) :: verlet
    real(real64)        :: accumulator
    real(real64)        :: sim_time, last_frame_time, frame_dt
    real(real64)        :: alpha  ! interpolation factor (0..1)
    integer             :: frame_count, fps, step_count
    logical             :: running
    integer             :: win_w, win_h

    ! Interpolation buffers
    type(body_t), allocatable :: bodies_prev(:)
    type(body_t), allocatable :: bodies_interp(:)

    call log_init(LOG_DEBUG)
    call log_msg(LOG_INFO, "=== Solar System Simulation ===")
    call log_msg(LOG_INFO, "Phase 3: Minimal instanced sphere rendering")

    !-----------------------------------------------------------------------
    ! Open window
    !-----------------------------------------------------------------------
    if (.not. window_open("Solar System", 1600, 900)) then
        call log_msg(LOG_ERROR, "Failed to open window — aborting")
        call log_shutdown()
        stop 1
    end if

    win_w = 1600
    win_h = 900

    !-----------------------------------------------------------------------
    ! Load physics
    !-----------------------------------------------------------------------
    call load_solar_system(sim%bodies)
    verlet%softening = 1.0e6_real64
    call sim%set_integrator(verlet)
    call log_msg(LOG_INFO, "Physics: " // trim(itoa(sim%n_bodies())) // " bodies loaded")

    !-----------------------------------------------------------------------
    ! Init renderer
    !-----------------------------------------------------------------------
    call renderer_init(renderer, win_w, win_h)

    ! Allocate interpolation buffers
    allocate(bodies_prev(sim%n_bodies()))
    allocate(bodies_interp(sim%n_bodies()))
    bodies_prev = sim%bodies

    !-----------------------------------------------------------------------
    ! Main loop — fixed timestep with accumulator
    !-----------------------------------------------------------------------
    running = .true.
    accumulator = 0.0_real64
    sim_time = 0.0_real64
    frame_count = 0
    fps = 0
    last_frame_time = window_get_time()

    call log_msg(LOG_INFO, "Entering main loop (time scale = " // &
                 trim(fmt_real(TIME_SCALE)) // " sim-sec/real-sec)")

    do while (running)
        ! Poll events
        call window_poll_events()
        if (window_should_close()) then
            running = .false.
            cycle
        end if

        ! Frame timing
        frame_dt = window_get_time() - last_frame_time
        last_frame_time = window_get_time()

        ! Clamp frame_dt to avoid huge jumps (e.g. breakpoint, debugger)
        if (frame_dt > 0.25_real64) frame_dt = 0.25_real64

        ! Accumulate simulated time
        accumulator = accumulator + frame_dt * TIME_SCALE

        ! Fixed-timestep physics (capped)
        step_count = 0
        do while (accumulator >= PHYSICS_DT .and. step_count < MAX_STEPS_PER_FRAME)
            ! Save current state for interpolation
            bodies_prev = sim%bodies

            ! Advance physics
            call sim%step(PHYSICS_DT)
            sim_time = sim_time + PHYSICS_DT
            accumulator = accumulator - PHYSICS_DT
            step_count = step_count + 1
        end do

        ! Interpolation factor: how far between prev and current
        if (step_count > 0 .or. sim_time > 0.0_real64) then
            alpha = accumulator / PHYSICS_DT
            if (alpha > 1.0_real64) alpha = 1.0_real64
            if (alpha < 0.0_real64) alpha = 0.0_real64
            call interpolate_bodies(bodies_interp, bodies_prev, sim%bodies, alpha)
        else
            bodies_interp = sim%bodies
        end if

        ! Clear
        call window_clear()

        ! Render
        call renderer_render(renderer, bodies_interp)

        ! Swap
        call window_swap_buffers()

        ! FPS counter
        frame_count = frame_count + 1
        if (window_get_time() - (last_frame_time - frame_dt) >= 1.0_real64) then
            fps = int(frame_count / max(window_get_time() - (last_frame_time - frame_dt), 0.01_real64))
            call log_msg(LOG_INFO, "FPS: " // trim(itoa(fps)) // &
                         "  physics steps/frame: " // trim(itoa(step_count)))
            frame_count = 0
        end if
    end do

    !-----------------------------------------------------------------------
    ! Clean shutdown
    !-----------------------------------------------------------------------
    call log_msg(LOG_INFO, "Shutting down...")
    call renderer_shutdown(renderer)
    call sim%shutdown()
    if (allocated(bodies_prev)) deallocate(bodies_prev)
    if (allocated(bodies_interp)) deallocate(bodies_interp)
    call window_close()
    call log_shutdown()

contains

    !=====================================================================
    ! Interpolate body positions between prev and curr states
    !=====================================================================
    subroutine interpolate_bodies(out, prev, curr, alpha)
        type(body_t), intent(out) :: out(:)
        type(body_t), intent(in) :: prev(:), curr(:)
        real(real64), intent(in) :: alpha
        integer :: i, n
        n = min(size(out), size(prev), size(curr))
        do i = 1, n
            out(i)%name = curr(i)%name
            out(i)%mass = curr(i)%mass
            out(i)%radius = curr(i)%radius
            out(i)%color = curr(i)%color
            ! Interpolate position and velocity
            out(i)%position = prev(i)%position * (1.0_real64 - alpha) + &
                              curr(i)%position * alpha
            out(i)%velocity = prev(i)%velocity * (1.0_real64 - alpha) + &
                              curr(i)%velocity * alpha
            out(i)%acceleration = curr(i)%acceleration
        end do
    end subroutine interpolate_bodies

    ! Integer-to-string helper
    pure function itoa(i) result(s)
        integer, intent(in) :: i
        character(len=12) :: s
        write(s, "(I0)") i
    end function itoa

    ! Real-to-string helper
    pure function fmt_real(v) result(s)
        real(real64), intent(in) :: v
        character(len=24) :: s
        write(s, "(F0.1)") v
    end function fmt_real

end program solarsim
