!===============================================================================
! main.f90 — Solar System Simulation with orbit camera and HUD
!
! Phase 4 additions:
!   - Interactive orbit camera (LMB rotate, RMB pan, scroll zoom)
!   - Keybindings: 0-8 focus bodies, SPACE pause, +/- time scale, R reset, H HUD
!   - Simulated date display in HUD
!   - HUD text overlay (FPS, date, time scale, focus, pause)
!===============================================================================
program solarsim
    use, intrinsic :: iso_c_binding, only: c_float, c_double, c_int
    use, intrinsic :: iso_fortran_env, only: real32, real64
    use logging, only: log_init, log_shutdown, log_msg, &
                       LOG_DEBUG, LOG_INFO, LOG_ERROR
    use window,  only: window_open, window_close, &
                       window_should_close, window_swap_buffers, &
                       window_clear, window_poll_events, window_get_time, &
                       window_get_size
    use input_mod, only: input_state_t, input_init, input_update, input_shutdown, &
                         input_key_callback, input_mouse_button_callback, &
                         input_cursor_pos_callback, input_scroll_callback, &
                         KEY_SPACE, KEY_0, KEY_EQUALS, KEY_MINUS, KEY_PLUS, &
                         KEY_R, KEY_H, KEY_T, KEY_B, KEY_LBRACKET, KEY_RBRACKET, &
                         KEY_F12
    use config_mod, only: sim_config_t, config_init, config_set_time_scale, &
                         EXPOSURE_MIN, EXPOSURE_MAX
    use post_mod, only: post_t, post_init, post_shutdown, post_resize, &
                        post_begin_scene, post_end_scene, post_apply_bloom_and_tonemap
    use sun_mod, only: sun_t, sun_init, sun_shutdown, sun_render
    use gl_bindings, only: gl_read_pixels_rgb, ss_write_png_c
    use vector3d, only: vec3, operator(*), operator(+)
    use body_mod, only: body_t
    use ephemerides, only: load_solar_system
    use integrator, only: velocity_verlet_t
    use simulation, only: simulation_t
    use renderer, only: renderer_t, renderer_init, renderer_render, renderer_shutdown
    use camera_mod, only: camera_t, camera_init, camera_update, camera_get_view, &
                          camera_get_projection, camera_reset, camera_set_focus, &
                          camera_handle_input
    use date_utils, only: sim_date_t, j2000_to_date
    use constants, only: AU
    use hud_text, only: hud_text_t, hud_text_init, hud_text_shutdown, &
                        hud_text_clear, hud_text_draw, hud_text_render
    use trails_mod, only: trails_t, trails_init, trails_shutdown, trails_clear, &
                          trails_push_body, trails_render, trails_set_visibility, &
                          trails_set_body_color
    implicit none

    ! Physics timestep: 1 hour = 3600 s
    real(real64), parameter :: PHYSICS_DT = 3600.0_real64
    integer, parameter :: MAX_STEPS_PER_FRAME = 8

    !-----------------------------------------------------------------------
    ! State
    !-----------------------------------------------------------------------
    type(simulation_t)  :: sim
    type(renderer_t)    :: renderer
    type(camera_t)      :: cam
    type(hud_text_t)    :: hud
    type(trails_t)      :: trails
    type(sim_config_t)  :: cfg
    type(input_state_t) :: inp
    type(velocity_verlet_t) :: verlet
    type(post_t)        :: post
    type(sun_t)         :: sun
    real(real64)        :: accumulator, sim_time, last_frame_time, frame_dt
    real(real64)        :: alpha, fps_smooth
    integer             :: frame_count, step_count
    logical             :: running, auto_screenshot
    character(len=32)   :: arg1
    integer             :: win_w, win_h
    real(real64)        :: au_val

    type(body_t), allocatable :: bodies_prev(:), bodies_interp(:)

    call log_init(LOG_DEBUG)
    call log_msg(LOG_INFO, "=== Solar System Simulation ===")
    call log_msg(LOG_INFO, "Phase 4: Orbit camera, input, HUD")

    !-----------------------------------------------------------------------
    ! Open window
    !-----------------------------------------------------------------------
    if (.not. window_open("Solar System", 1600, 900)) then
        call log_msg(LOG_ERROR, "Failed to open window — aborting")
        call log_shutdown()
        stop 1
    end if
    win_w = 1600; win_h = 900

    !-----------------------------------------------------------------------
    ! Load physics
    !-----------------------------------------------------------------------
    call load_solar_system(sim%bodies)
    verlet%softening = 1.0e6_real64
    call sim%set_integrator(verlet)
    call log_msg(LOG_INFO, "Physics: " // trim(itoa(sim%n_bodies())) // " bodies loaded")

    !-----------------------------------------------------------------------
    ! Init renderer, camera, HUD, input, config
    !-----------------------------------------------------------------------
    call renderer_init(renderer, win_w, win_h)
    call config_init(cfg)
    au_val = AU
    call trails_init(trails, sim%n_bodies(), cfg%trail_length)
    call set_trail_colors()
    call seed_trails()
    call camera_init(cam, win_w, win_h)
    call hud_text_init(hud)
    call input_init(inp)
    call register_input_callbacks()
    call post_init(post, win_w, win_h, cfg%bloom_mips)
    call sun_init(sun)

    allocate(bodies_prev(sim%n_bodies()))
    allocate(bodies_interp(sim%n_bodies()))
    bodies_prev = sim%bodies
    bodies_interp = sim%bodies

    !-----------------------------------------------------------------------
    ! Main loop
    !-----------------------------------------------------------------------
    running = .true.
    auto_screenshot = .false.
    if (command_argument_count() >= 1) then
        call get_command_argument(1, arg1)
        if (trim(arg1) == "--screenshot") auto_screenshot = .true.
    end if
    accumulator = 0.0_real64
    sim_time = 0.0_real64
    frame_count = 0
    fps_smooth = 60.0
    last_frame_time = window_get_time()

    call log_msg(LOG_INFO, "Controls: 0-8 focus, SPACE pause, +/- time, R reset, H HUD")

    do while (running)
        call input_update(inp)
        call window_poll_events()
        if (window_should_close()) then
            running = .false.
            cycle
        end if

        ! Frame timing
        frame_dt = window_get_time() - last_frame_time
        last_frame_time = window_get_time()
        if (frame_dt > 0.25_real64) frame_dt = 0.25_real64
        if (frame_dt < 0.001_real64) frame_dt = 0.001_real64

        ! Smooth FPS
        fps_smooth = fps_smooth * 0.95_real64 + (1.0_real64 / frame_dt) * 0.05_real64

        !-------------------------------------------------------------------
        ! Handle input
        !-------------------------------------------------------------------
        call handle_input()

        !-------------------------------------------------------------------
        ! Physics step (only if not paused)
        !-------------------------------------------------------------------
        if (.not. cfg%paused) then
            accumulator = accumulator + frame_dt * cfg%time_scale
            step_count = 0
            do while (accumulator >= PHYSICS_DT .and. step_count < MAX_STEPS_PER_FRAME)
                bodies_prev = sim%bodies
                call sim%step(PHYSICS_DT)
                sim_time = sim_time + PHYSICS_DT
                accumulator = accumulator - PHYSICS_DT
                step_count = step_count + 1
            end do

            alpha = accumulator / PHYSICS_DT
            if (alpha > 1.0_real64) alpha = 1.0_real64
            if (alpha < 0.0_real64) alpha = 0.0_real64
            call interpolate_bodies(bodies_interp, bodies_prev, sim%bodies, alpha)
        end if

        ! Push current positions to trail ring buffer (every frame)
        call push_trails()

        !-------------------------------------------------------------------
        ! Update camera
        !-------------------------------------------------------------------
        call camera_update(cam, real(frame_dt, c_float))
        call camera_handle_input(cam, real(inp%mouse_dx, c_float), &
                                 real(inp%mouse_dy, c_float), &
                                 real(inp%scroll_dy, c_float), &
                                 inp%mouse%left, inp%mouse%right, &
                                 real(frame_dt, c_float))

        !-------------------------------------------------------------------
        ! Render — HDR scene into post FBO, then bloom + tonemap to screen
        !-------------------------------------------------------------------
        call maybe_resize_targets()

        call post_begin_scene(post, 5.0_c_float / 255.0_c_float, &
                              7.0_c_float / 255.0_c_float, &
                              13.0_c_float / 255.0_c_float)
        renderer%camera = cam
        call renderer_render(renderer, bodies_interp)
        call sun_render(sun, bodies_interp(1), cam, &
                        real(window_get_time(), c_float), &
                        real(cfg%sun_emissive_mul, c_float))
        if (cfg%trails_visible) then
            call trails_render(trails, cam)
        end if
        call post_end_scene(post)

        call post_apply_bloom_and_tonemap(post, cfg%bloom_on, &
            real(cfg%bloom_threshold, c_float), &
            real(cfg%bloom_intensity, c_float), &
            real(cfg%exposure, c_float))

        !-------------------------------------------------------------------
        ! HUD drawn over tonemapped output in SDR
        !-------------------------------------------------------------------
        if (cfg%hud_visible) then
            call render_hud()
        end if

        if (inp%key_just_pressed(KEY_F12)) then
            call take_screenshot()
        end if

        frame_count = frame_count + 1
        if (auto_screenshot .and. frame_count == 180) then
            call take_screenshot()
            running = .false.
        end if

        call window_swap_buffers()
    end do

    !-----------------------------------------------------------------------
    ! Clean shutdown
    !-----------------------------------------------------------------------
    call log_msg(LOG_INFO, "Shutting down...")
    call sun_shutdown(sun)
    call post_shutdown(post)
    call hud_text_shutdown(hud)
    call input_shutdown()
    call renderer_shutdown(renderer)
    call sim%shutdown()
    if (allocated(bodies_prev)) deallocate(bodies_prev)
    if (allocated(bodies_interp)) deallocate(bodies_interp)
    call window_close()
    call log_shutdown()

contains

    !=====================================================================
    ! Register GLFW input callbacks
    !=====================================================================
    subroutine register_input_callbacks()
        use window, only: window_get_glfw_window, window_set_key_callback, &
                          window_set_mouse_button_callback, &
                          window_set_cursor_pos_callback, window_set_scroll_callback
        call window_set_key_callback(input_key_callback)
        call window_set_mouse_button_callback(input_mouse_button_callback)
        call window_set_cursor_pos_callback(input_cursor_pos_callback)
        call window_set_scroll_callback(input_scroll_callback)
    end subroutine register_input_callbacks

    !=====================================================================
    ! Handle key input this frame
    !=====================================================================
    subroutine handle_input()
        integer :: i

        ! Focus keys: 0-8
        do i = 0, 8
            if (inp%key_just_pressed(KEY_0 + i)) then
                cfg%focus_index = i
                call focus_on_body(i)
                call log_msg(LOG_INFO, "Focus: " // trim(cfg%focus_names(i+1)))
            end if
        end do

        ! Pause
        if (inp%key_just_pressed(KEY_SPACE)) then
            cfg%paused = .not. cfg%paused
            if (cfg%paused) then
                call log_msg(LOG_INFO, "Simulation PAUSED")
            else
                call log_msg(LOG_INFO, "Simulation RESUMED")
            end if
        end if

        ! Time scale: + or = (increase), - (decrease)
        if (inp%key_just_pressed(KEY_EQUALS) .or. inp%key_just_pressed(KEY_PLUS)) then
            call config_set_time_scale(cfg, cfg%time_scale * 2.0_real64)
        end if
        if (inp%key_just_pressed(KEY_MINUS)) then
            call config_set_time_scale(cfg, cfg%time_scale / 2.0_real64)
        end if

        ! Reset camera
        if (inp%key_just_pressed(KEY_R)) then
            call camera_reset(cam)
        end if

        ! Toggle HUD
        if (inp%key_just_pressed(KEY_H)) then
            cfg%hud_visible = .not. cfg%hud_visible
        end if

        ! Bloom toggle
        if (inp%key_just_pressed(KEY_B)) then
            cfg%bloom_on = .not. cfg%bloom_on
            if (cfg%bloom_on) then
                call log_msg(LOG_INFO, "Bloom ON")
            else
                call log_msg(LOG_INFO, "Bloom OFF")
            end if
        end if

        ! Exposure: [ decreases, ] increases (geometric)
        if (inp%key_just_pressed(KEY_LBRACKET)) then
            cfg%exposure = max(cfg%exposure / 1.2, EXPOSURE_MIN)
        end if
        if (inp%key_just_pressed(KEY_RBRACKET)) then
            cfg%exposure = min(cfg%exposure * 1.2, EXPOSURE_MAX)
        end if

        ! Toggle trails (T, Shift+T = clear)
        if (inp%key_just_pressed(KEY_T)) then
            if (inp%key_held(340) .or. inp%key_held(344)) then
                call trails_clear(trails)
                call seed_trails()
                call log_msg(LOG_INFO, "Trails cleared")
            else
                cfg%trails_visible = .not. cfg%trails_visible
                if (cfg%trails_visible) then
                    call log_msg(LOG_INFO, "Trails ON")
                else
                    call log_msg(LOG_INFO, "Trails OFF")
                end if
            end if
        end if
    end subroutine handle_input

    !=====================================================================
    ! Focus camera on a body
    !=====================================================================
    subroutine focus_on_body(idx)
        integer, intent(in) :: idx
        real(c_float) :: pos_au(3)

        au_val = AU
        pos_au(1) = real(sim%bodies(idx+1)%position%x / au_val, c_float)
        pos_au(2) = real(sim%bodies(idx+1)%position%y / au_val, c_float)
        pos_au(3) = real(sim%bodies(idx+1)%position%z / au_val, c_float)
        call camera_set_focus(cam, pos_au)
    end subroutine focus_on_body

    !=====================================================================
    ! Render HUD overlay
    !=====================================================================
    subroutine render_hud()
        type(sim_date_t) :: sim_date
        real(real64) :: time_scale_days
        character(len=32) :: ts_str, fps_str, focus_str, pause_str

        call hud_text_clear(hud)

        ! FPS
        write(fps_str, "(A,F6.1)") "FPS: ", fps_smooth
        call hud_text_draw(hud, 10.0_c_float, 10.0_c_float, trim(fps_str), &
                           1.0_c_float, 1.0_c_float, 1.0_c_float)

        ! Simulated date
        call j2000_to_date(sim_time, sim_date)
        write(ts_str, "(I4.4,'-',I2.2,'-',I2.2,' ',I2.2,':',I2.2,':',I2.2)") &
            sim_date%year, sim_date%month, sim_date%day, &
            sim_date%hour, sim_date%minute, int(sim_date%second)
        call hud_text_draw(hud, 10.0_c_float, 25.0_c_float, "Date: " // trim(ts_str), &
                           1.0_c_float, 1.0_c_float, 1.0_c_float)

        ! Time scale
        time_scale_days = cfg%time_scale / 86400.0_real64
        if (time_scale_days < 1.0_real64) then
            write(ts_str, "(F0.1,' s/s')") cfg%time_scale
        else if (time_scale_days < 365.25_real64) then
            write(ts_str, "(F0.1,' day/s')") time_scale_days
        else
            write(ts_str, "(F0.1,' yr/s')") time_scale_days / 365.25_real64
        end if
        call hud_text_draw(hud, 10.0_c_float, 40.0_c_float, "Time: " // trim(ts_str), &
                           1.0_c_float, 1.0_c_float, 1.0_c_float)

        ! Focus
        focus_str = "Focus: " // trim(cfg%focus_names(cfg%focus_index+1))
        call hud_text_draw(hud, 10.0_c_float, 55.0_c_float, focus_str, &
                           1.0_c_float, 1.0_c_float, 1.0_c_float)

        ! Paused indicator
        if (cfg%paused) then
            pause_str = "[PAUSED]"
            call hud_text_draw(hud, 10.0_c_float, 70.0_c_float, pause_str, &
                               1.0_c_float, 0.3_c_float, 0.3_c_float)
        end if

        ! Exposure (only shown when bloom is on)
        if (cfg%bloom_on) then
            write(ts_str, "(A,F4.2)") "Exposure: ", cfg%exposure
            call hud_text_draw(hud, 10.0_c_float, 85.0_c_float, trim(ts_str), &
                               1.0_c_float, 1.0_c_float, 0.6_c_float)
        else
            call hud_text_draw(hud, 10.0_c_float, 85.0_c_float, "Bloom: OFF", &
                               0.7_c_float, 0.7_c_float, 0.7_c_float)
        end if

        call hud_text_render(hud)
    end subroutine render_hud

    !=====================================================================
    ! Interpolate body positions
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
            out(i)%position = prev(i)%position * (1.0_real64 - alpha) + &
                              curr(i)%position * alpha
            out(i)%velocity = prev(i)%velocity * (1.0_real64 - alpha) + &
                              curr(i)%velocity * alpha
            out(i)%acceleration = curr(i)%acceleration
        end do
    end subroutine interpolate_bodies

    !=====================================================================
    ! Refresh HDR/bloom framebuffers when the window size changes
    !=====================================================================
    subroutine maybe_resize_targets()
        integer :: w, h
        call window_get_size(w, h)
        if (w /= win_w .or. h /= win_h) then
            win_w = w
            win_h = h
            call post_resize(post, win_w, win_h)
        end if
    end subroutine maybe_resize_targets

    !=====================================================================
    ! F12 — read back default framebuffer and write screenshots/phase6.png
    !=====================================================================
    subroutine take_screenshot()
        use, intrinsic :: iso_c_binding, only: c_loc, c_signed_char
        integer(c_int) :: w, h, rc
        integer(c_signed_char), allocatable, target :: pixels(:)

        w = int(win_w, c_int)
        h = int(win_h, c_int)
        allocate(pixels(3 * w * h))
        call gl_read_pixels_rgb(0_c_int, 0_c_int, w, h, c_loc(pixels(1)))

        rc = ss_write_png_c("screenshots/phase6.png", w, h, c_loc(pixels(1)))
        if (rc == 1_c_int) then
            call log_msg(LOG_INFO, "Screenshot: screenshots/phase6.png")
        else
            call log_msg(LOG_ERROR, "Screenshot failed")
        end if
        deallocate(pixels)
    end subroutine take_screenshot

    pure function itoa(i) result(s)
        integer, intent(in) :: i
        character(len=12) :: s
        write(s, "(I0)") i
    end function itoa

    !=====================================================================
    ! Seed trail buffers with current body positions
    !=====================================================================
    subroutine seed_trails()
        ! Push the initial position once so the first rendered segment goes
        ! from the seed point to the next simulated position, not from origin.
        integer :: i
        real(c_float) :: pos_au(3)
        do i = 1, sim%n_bodies()
            pos_au(1) = real(sim%bodies(i)%position%x / au_val, c_float)
            pos_au(2) = real(sim%bodies(i)%position%y / au_val, c_float)
            pos_au(3) = real(sim%bodies(i)%position%z / au_val, c_float)
            call trails_push_body(trails, i, pos_au)
        end do
    end subroutine seed_trails

    subroutine set_trail_colors()
        integer :: i
        do i = 1, sim%n_bodies()
            call trails_set_body_color(trails, i, &
                sim%bodies(i)%color(1), sim%bodies(i)%color(2), &
                sim%bodies(i)%color(3))
        end do
    end subroutine set_trail_colors

    !=====================================================================
    ! Push current interpolated body positions to trail ring buffer
    !=====================================================================
    subroutine push_trails()
        integer :: i
        real(c_float) :: pos_au(3)
        do i = 1, sim%n_bodies()
            pos_au(1) = real(bodies_interp(i)%position%x / au_val, c_float)
            pos_au(2) = real(bodies_interp(i)%position%y / au_val, c_float)
            pos_au(3) = real(bodies_interp(i)%position%z / au_val, c_float)
            call trails_push_body(trails, i, pos_au)
        end do
    end subroutine push_trails

end program solarsim
