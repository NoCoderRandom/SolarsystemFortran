!===============================================================================
! main.f90 — Entry point: init logging, open window, main loop with FPS
!===============================================================================
program solarsim
    use logging, only: log_init, log_shutdown, log_msg, &
                       LOG_DEBUG, LOG_INFO, LOG_ERROR
    use window,  only: window_open, window_close, &
                       window_should_close, window_swap_buffers, &
                       window_clear, window_poll_events, window_get_time
    use, intrinsic :: iso_c_binding, only: c_double
    implicit none

    logical            :: running
    real(c_double)     :: t_now, t_last_fps
    integer            :: frame_count, fps

    !-----------------------------------------------------------------------
    ! Initialize logging
    !-----------------------------------------------------------------------
    call log_init(LOG_DEBUG)
    call log_msg(LOG_INFO, "=== Solar System Simulation ===")
    call log_msg(LOG_INFO, "Phase 1: Foundation and build system")

    !-----------------------------------------------------------------------
    ! Open window (1600x900, OpenGL 3.3 Core)
    !-----------------------------------------------------------------------
    if (.not. window_open("Solar System", 1600, 900)) then
        call log_msg(LOG_ERROR, "Failed to open window — aborting")
        call log_shutdown()
        stop 1
    end if

    !-----------------------------------------------------------------------
    ! Main loop
    !-----------------------------------------------------------------------
    running = .true.
    frame_count = 0
    fps = 0
    t_last_fps = window_get_time()

    call log_msg(LOG_INFO, "Entering main loop...")

    do while (running)
        ! Poll events (handles ESC, window-close button)
        call window_poll_events()

        ! Check if we should exit
        if (window_should_close()) then
            running = .false.
            cycle
        end if

        ! Clear to #05070d
        call window_clear()

        ! Swap buffers
        call window_swap_buffers()

        ! FPS counter
        frame_count = frame_count + 1
        t_now = window_get_time()
        if (t_now - t_last_fps >= 1.0_c_double) then
            fps = int(frame_count / (t_now - t_last_fps))
            call log_msg(LOG_INFO, "FPS: " // trim(itoa(fps)) // &
                         "  (frames: " // trim(itoa(frame_count)) // ")")
            frame_count = 0
            t_last_fps = t_now
        end if
    end do

    !-----------------------------------------------------------------------
    ! Clean shutdown
    !-----------------------------------------------------------------------
    call log_msg(LOG_INFO, "Shutting down...")
    call window_close()
    call log_shutdown()

contains

    ! Integer-to-string helper
    pure function itoa(i) result(s)
        integer, intent(in) :: i
        character(len=12) :: s
        write(s, "(I0)") i
    end function itoa

end program solarsim
