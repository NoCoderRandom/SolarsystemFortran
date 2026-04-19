!===============================================================================
! main.f90 — Solar System Simulation
!
! Phase 7: Textured planets with Lambert + Blinn-Phong shading, normal maps,
!   Earth night lights / ocean specular, atmospheric rim, Saturn rings,
!   HDR bloom pipeline, orbit camera, HUD.
!===============================================================================
program solarsim
    use, intrinsic :: iso_c_binding, only: c_float, c_double, c_int
    use, intrinsic :: iso_fortran_env, only: real32, real64
    use logging, only: log_init, log_shutdown, log_msg, &
                       LOG_DEBUG, LOG_INFO, LOG_ERROR
    use window,  only: window_open, window_close, &
                       window_should_close, window_swap_buffers, &
                       window_clear, window_poll_events, window_get_time, &
                       window_get_size, window_set_vsync
    use input_mod, only: input_state_t, input_init, input_update, input_shutdown, &
                         input_key_callback, input_mouse_button_callback, &
                         input_cursor_pos_callback, input_scroll_callback, &
                         KEY_SPACE, KEY_0, KEY_EQUALS, KEY_MINUS, KEY_PLUS, &
                         KEY_R, KEY_H, KEY_T, KEY_B, KEY_LBRACKET, KEY_RBRACKET, &
                         KEY_ESCAPE, &
                         KEY_F2, KEY_F12
    use config_mod, only: sim_config_t, config_init, config_set_speed_preset, &
                         config_step_speed_preset, config_speed_label, &
                         SPEED_PRESET_COUNT, EXPOSURE_MIN, EXPOSURE_MAX
    use config_toml_mod, only: config_toml_load, config_toml_log, config_toml_write_default
    use perf_mod, only: perf_tic, perf_toc, perf_report
    use post_mod, only: post_t, post_init, post_shutdown, post_resize, &
                        post_begin_scene, post_end_scene, post_apply_bloom_and_tonemap
    use sun_mod, only: sun_t, sun_init, sun_shutdown, sun_render
    use gl_bindings, only: gl_read_pixels_rgb, ss_write_png_c
    use vector3d, only: vec3, operator(*), operator(+)
    use body_mod, only: body_t
    use ephemerides, only: load_solar_system
    use integrator, only: velocity_verlet_t
    use simulation, only: simulation_t
    use renderer, only: renderer_t, renderer_init, renderer_render, renderer_shutdown, &
                        renderer_set_material, renderer_set_rings
    use texture_mod, only: texture_load
    use material_mod, only: material_t, MATERIAL_GENERIC, MATERIAL_EARTH, &
                            MATERIAL_GAS_GIANT
    use rings_mod, only: rings_t, rings_init, rings_destroy
    use camera_mod, only: camera_t, camera_init, camera_update, camera_get_view, &
                          camera_get_projection, camera_reset, camera_set_focus, &
                          camera_handle_input
    use demo_mod, only: demo_state_t, demo_overlay_t, demo_init, demo_start, demo_apply, &
                        demo_advance, demo_name, demo_slug, demo_is_showcase, &
                        DEMO_CAPTURE_FPS, DEMO_COUNT, MAX_DEMO_BODIES, DEMO_ID_SHOWCASE
    use date_utils, only: sim_date_t, j2000_to_date
    use constants, only: AU
    use hud_text, only: hud_text_t, hud_text_init, hud_text_shutdown, &
                        hud_text_clear, hud_text_draw, hud_text_render
    use trails_mod, only: trails_t, trails_init, trails_shutdown, trails_clear, &
                          trails_push_body, trails_render, trails_set_visibility, &
                          trails_set_body_color
    use starfield_mod, only: starfield_t, starfield_init, starfield_shutdown, &
                             starfield_render
    use asteroids_mod, only: asteroids_t, asteroids_init, asteroids_shutdown, &
                             asteroids_render
    use display_scale, only: K_LOG
    use menu_mod, only: menu_t, menu_item_t, menu_init, menu_shutdown, &
                         menu_update, menu_render, menu_mouse_captured, &
                         menu_pop_action, menu_add_dropdown, menu_add_item, &
                         menu_set_toggle, menu_set_slider, menu_set_label, &
                         menu_get_toggle, menu_get_slider, &
                         ITEM_TOGGLE, ITEM_BUTTON, ITEM_SLIDER, ITEM_SEPARATOR, ITEM_LABEL, &
                         MENU_BAR_H
    implicit none

    !-- Menu field / action enum --------------------------------------
    !   Field IDs (toggle or slider targets) — keep below 100
    integer, parameter :: FIELD_HUD            = 1
    integer, parameter :: FIELD_TRAILS         = 2
    integer, parameter :: FIELD_BLOOM          = 3
    integer, parameter :: FIELD_VSYNC          = 4
    integer, parameter :: FIELD_PAUSED         = 5
    integer, parameter :: FIELD_LOG_SCALE      = 6
    integer, parameter :: FIELD_EXPOSURE       = 10
    integer, parameter :: FIELD_BLOOM_INT      = 11
    integer, parameter :: FIELD_SPEED_LABEL    = 12
    integer, parameter :: FIELD_SPEED_PRESET   = 13
    !   Action IDs (button targets) — 100+
    integer, parameter :: ACTION_SCREENSHOT    = 100
    integer, parameter :: ACTION_SCREENSHOT_TS = 101
    integer, parameter :: ACTION_QUIT          = 102
    integer, parameter :: ACTION_DEMO_BASE     = 103
    integer, parameter :: ACTION_DEMO_RECORD_BASE = ACTION_DEMO_BASE + DEMO_COUNT
    integer, parameter :: ACTION_CAMERA_RESET  = 110
    integer, parameter :: ACTION_FOCUS_BASE    = 120   ! 120..128 for Sun..Neptune
    integer, parameter :: ACTION_SPEED_SLOWER  = 130
    integer, parameter :: ACTION_SPEED_FASTER  = 131

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
    type(rings_t), target :: rings
    type(starfield_t)   :: sky
    type(asteroids_t)   :: belt
    type(menu_t)        :: menu
    type(demo_state_t)  :: demo
    type(demo_overlay_t):: demo_overlay
    real(real64)        :: accumulator, sim_time, last_frame_time, frame_dt
    real(real64)        :: alpha, fps_smooth
    integer             :: frame_count, step_count
    logical             :: running, auto_screenshot, config_dirty
    character(len=64)   :: arg1
    character(len=256)  :: arg2
    character(len=128)  :: screenshot_path = "../screenshots/phase8_overview.png"
    character(len=256)  :: demo_frame_dir = "screenshots/demo_frames"
    character(len=256)  :: demo_video_path = ""
    integer             :: screenshot_focus = -1
    integer             :: win_w, win_h
    real(real64)        :: au_val
    logical             :: demo_finished
    logical             :: demo_encode_video = .false.
    logical             :: saved_hud_visible, saved_trails_visible, saved_bloom_on
    logical             :: saved_distance_log_scale, saved_paused, saved_vsync
    integer             :: saved_speed_preset

    type(body_t), allocatable :: bodies_prev(:), bodies_interp(:), scene_bodies(:)

    call log_init(LOG_DEBUG)
    call log_msg(LOG_INFO, "=== Solar System Simulation ===")
    call log_msg(LOG_INFO, "Phase 8: Starfield, asteroids, config, polish")

    !-----------------------------------------------------------------------
    ! Config first — window size / bloom / etc. come from config.toml.
    !-----------------------------------------------------------------------
    call config_init(cfg)
    call config_toml_load(cfg, "config.toml")
    call config_toml_log(cfg)

    !-----------------------------------------------------------------------
    ! Open window
    !-----------------------------------------------------------------------
    if (.not. window_open("Solar System", cfg%window_width, cfg%window_height)) then
        call log_msg(LOG_ERROR, "Failed to open window — aborting")
        call log_shutdown()
        stop 1
    end if
    call window_set_vsync(cfg%vsync)
    win_w = cfg%window_width; win_h = cfg%window_height

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
    call renderer_init(renderer, win_w, win_h, sim%n_bodies() + MAX_DEMO_BODIES)
    call load_materials()
    au_val = AU
    call trails_init(trails, sim%n_bodies(), cfg%trail_length)
    call set_trail_colors()
    call seed_trails()
    call camera_init(cam, win_w, win_h)
    cam%azimuth   = real(cfg%camera_azimuth,   c_float)
    cam%elevation = real(cfg%camera_elevation, c_float)
    cam%log_dist  = real(cfg%camera_log_dist,  c_float)
    call hud_text_init(hud)
    call build_menu()
    call input_init(inp)
    call register_input_callbacks()
    call demo_init(demo)
    call post_init(post, win_w, win_h, cfg%bloom_mips)
    call sun_init(sun)
    call starfield_init(sky, cfg%starfield_count)
    call asteroids_init(belt, cfg%asteroid_count, &
                        cfg%asteroid_a_min, cfg%asteroid_a_max)

    allocate(bodies_prev(sim%n_bodies()))
    allocate(bodies_interp(sim%n_bodies()))
    allocate(scene_bodies(sim%n_bodies() + MAX_DEMO_BODIES))
    bodies_prev = sim%bodies
    bodies_interp = sim%bodies
    scene_bodies(1:sim%n_bodies()) = sim%bodies

    !-----------------------------------------------------------------------
    ! Main loop
    !-----------------------------------------------------------------------
    running = .true.
    auto_screenshot = .false.
    config_dirty = .false.
    if (command_argument_count() >= 1) then
        call get_command_argument(1, arg1)
        if (trim(arg1) == "--screenshot") auto_screenshot = .true.
        if (trim(arg1) == "--screenshot-earth") then
            auto_screenshot = .true.
            screenshot_path = "../screenshots/phase8_earth.png"
            screenshot_focus = 3
            cfg%trails_visible = .false.
            cam%log_dist = -0.30_c_float   ! ~0.5 AU
            call focus_on_body(3)
        end if
        if (trim(arg1) == "--screenshot-earth-night") then
            auto_screenshot = .true.
            screenshot_path = "../screenshots/phase8_earth_night.png"
            screenshot_focus = -3          ! magic: negative = night-side framing
            cfg%trails_visible = .false.
            ! Tune the HDR pipeline so faint city lights survive tonemap.
            cfg%bloom_on       = .false.
            cfg%exposure       = 1.0
            cam%log_dist = -0.30_c_float
            call focus_on_body(3)
            call aim_camera_at_body(3, night_side=.true.)
        end if
        if (trim(arg1) == "--screenshot-saturn") then
            auto_screenshot = .true.
            screenshot_path = "../screenshots/phase8_saturn.png"
            screenshot_focus = 6
            cfg%trails_visible = .false.
            cam%log_dist = 0.30_c_float    ! ~2 AU
            call focus_on_body(6)
        end if
        if (trim(arg1) == "--screenshot") then
            screenshot_path = "../screenshots/phase8_overview.png"
        end if
        if (trim(arg1) == "--demo") then
            call start_demo_mode(DEMO_ID_SHOWCASE, .false., .true.)
        end if
        if (trim(arg1) == "--demo-record") then
            if (command_argument_count() >= 2) then
                call get_command_argument(2, arg2)
                if (len_trim(arg2) > 0) demo_frame_dir = trim(arg2)
            end if
            call start_demo_mode(DEMO_ID_SHOWCASE, .true., .true.)
        end if
    end if
    if (screenshot_focus >= 0 .or. screenshot_focus < -1) then
        ! Park the camera there — flush the smooth transition.
        cam%focus = cam%focus_target
        cam%focus_progress = 1.0_c_float
        cfg%hud_visible = .false.
    end if
    ! Overview screenshot — also hide HUD + menu so the hero image stays clean.
    if (auto_screenshot) cfg%hud_visible = .false.
    accumulator = 0.0_real64
    sim_time = 0.0_real64
    frame_count = 0
    fps_smooth = 60.0
    last_frame_time = window_get_time()

    call log_msg(LOG_INFO, "Controls: 0-8 focus, SPACE pause, +/- speed, R reset, H HUD")
    call log_msg(LOG_INFO, "         T trails, B bloom, [/] exposure, F2 screenshot")

    do while (running)
        call window_poll_events()
        call input_update(inp)
        if (window_should_close()) then
            running = .false.
            cycle
        end if

        ! Frame timing
        if (demo%active .and. demo%capture_frames) then
            frame_dt = 1.0_real64 / real(DEMO_CAPTURE_FPS, real64)
            last_frame_time = window_get_time()
        else
            frame_dt = window_get_time() - last_frame_time
            last_frame_time = window_get_time()
            if (frame_dt > 0.25_real64) frame_dt = 0.25_real64
            if (frame_dt < 0.001_real64) frame_dt = 0.001_real64
        end if

        ! Smooth FPS
        fps_smooth = fps_smooth * 0.95_real64 + (1.0_real64 / frame_dt) * 0.05_real64

        !-------------------------------------------------------------------
        ! Handle input
        !-------------------------------------------------------------------
        call handle_input()

        !-------------------------------------------------------------------
        ! Physics step (only if not paused)
        !-------------------------------------------------------------------
        call perf_tic("physics")
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
        call perf_toc("physics")

        ! Push current positions to trail ring buffer (every frame)
        call perf_tic("trails_push")
        call push_trails()
        call perf_toc("trails_push")

        !-------------------------------------------------------------------
        ! Update menu (before camera so the menu can consume the mouse)
        !-------------------------------------------------------------------
        call sync_menu_from_cfg()
        call menu_update(menu, &
                         real(inp%mouse_x, c_float), real(inp%mouse_y, c_float), &
                         inp%mouse_just_pressed%left, &
                         inp%mouse_just_released%left, &
                         inp%mouse%left)
        call dispatch_menu_action()

        !-------------------------------------------------------------------
        ! Update camera
        !-------------------------------------------------------------------
        if (demo%active) then
            call demo_apply(demo, cam, bodies_interp, cfg%focus_index, demo_overlay)
        else
            demo_overlay%count = 0
        end if
        call camera_update(cam, real(frame_dt, c_float))
        if ((.not. demo%active) .and. .not. menu_mouse_captured(menu, &
                  real(inp%mouse_x, c_float), real(inp%mouse_y, c_float))) then
            call camera_handle_input(cam, real(inp%mouse_dx, c_float), &
                                     real(inp%mouse_dy, c_float), &
                                     real(inp%scroll_dy, c_float), &
                                     inp%mouse%left, inp%mouse%right, &
                                     real(frame_dt, c_float))
        end if

        !-------------------------------------------------------------------
        ! Render — HDR scene into post FBO, then bloom + tonemap to screen
        !-------------------------------------------------------------------
        call maybe_resize_targets()

        call perf_tic("scene_render")
        ! Clear the HDR scene target to linear black — the gamma-encoded
        ! dark-blue used in Phase 1 would get lifted to gray by the ACES +
        ! sRGB tonemap. Let the starfield + bloom provide all non-black pixels.
        call post_begin_scene(post, 0.0_c_float, 0.0_c_float, 0.0_c_float)

        ! Starfield first — depth write off, so everything else occludes it.
        call perf_tic("starfield")
        call starfield_render(sky, cam, real(window_get_time(), c_float), &
                              real(cfg%starfield_intensity, c_float))
        call perf_toc("starfield")

        call compose_scene_bodies()
        renderer%camera = cam
        block
            real(c_float) :: sun_pos(3)
            sun_pos(1) = real(bodies_interp(1)%position%x / au_val, c_float)
            sun_pos(2) = real(bodies_interp(1)%position%y / au_val, c_float)
            sun_pos(3) = real(bodies_interp(1)%position%z / au_val, c_float)
            call perf_tic("planets")
            call renderer_render(renderer, scene_bodies(1:sim%n_bodies() + demo_overlay%count), sun_pos, &
                                 cfg%distance_log_scale)
            call perf_toc("planets")
            call perf_tic("asteroids")
            call asteroids_render(belt, cam, sun_pos, sim_time, &
                                  cfg%distance_log_scale, K_LOG)
            call perf_toc("asteroids")
        end block
        if (screenshot_focus == -1) then
            ! Only render the huge procedural Sun for the default overview.
            ! Close-up day shots (>= 0) and night-side shots (< -1) skip it.
            call sun_render(sun, bodies_interp(1), cam, &
                            real(window_get_time(), c_float), &
                            real(cfg%sun_emissive_mul, c_float))
        end if
        if (cfg%trails_visible) then
            call perf_tic("trails_draw")
            block
                real(c_float) :: sun_pos_trails(3)
                sun_pos_trails(1) = real(bodies_interp(1)%position%x / au_val, c_float)
                sun_pos_trails(2) = real(bodies_interp(1)%position%y / au_val, c_float)
                sun_pos_trails(3) = real(bodies_interp(1)%position%z / au_val, c_float)
                call trails_render(trails, cam, cfg%distance_log_scale, &
                                   sun_pos_trails, K_LOG)
            end block
            call perf_toc("trails_draw")
        end if
        call post_end_scene(post)
        call perf_toc("scene_render")

        call perf_tic("bloom_tonemap")
        call post_apply_bloom_and_tonemap(post, cfg%bloom_on, &
            real(cfg%bloom_threshold, c_float), &
            real(cfg%bloom_intensity, c_float), &
            real(cfg%exposure, c_float))
        call perf_toc("bloom_tonemap")

        !-------------------------------------------------------------------
        ! HUD and menu drawn over tonemapped output in SDR. Menu always
        ! visible; HUD lines depend on cfg%hud_visible.
        !-------------------------------------------------------------------
        call render_hud_and_menu()

        if (inp%key_just_pressed(KEY_F12)) then
            call take_screenshot()
        end if
        if (inp%key_just_pressed(KEY_F2)) then
            call take_screenshot_timestamped()
        end if
        if (demo%active .and. demo%capture_frames) then
            call take_demo_capture_frame()
        end if

        frame_count = frame_count + 1
        ! Only Earth uses the sun-perpendicular "vertical terminator" framing;
        ! other planets look nicer with the default orbit camera (above-ecliptic
        ! 3/4 view so e.g. Saturn's rings are visible).
        if (auto_screenshot .and. screenshot_focus == 3) then
            call aim_camera_at_body(screenshot_focus, night_side=.false.)
        end if
        if (auto_screenshot .and. screenshot_focus == -3) then
            call aim_camera_at_body(-screenshot_focus, night_side=.true.)
        end if
        if (auto_screenshot .and. frame_count == 180) then
            call take_screenshot()
            running = .false.
        end if
        call demo_advance(demo, real(frame_dt, c_float), demo_finished)
        if (demo_finished) then
            if (demo_encode_video) call encode_demo_video()
            if (.not. demo%quit_on_finish) call finish_demo_mode()
        end if
        if (demo_finished .and. demo%quit_on_finish) running = .false.

        call window_swap_buffers()
    end do

    !-----------------------------------------------------------------------
    ! Clean shutdown
    !-----------------------------------------------------------------------
    if (config_dirty) call persist_runtime_config()
    call log_msg(LOG_INFO, "Shutting down...")
    call perf_report()
    call asteroids_shutdown(belt)
    call starfield_shutdown(sky)
    call rings_destroy(rings)
    call sun_shutdown(sun)
    call post_shutdown(post)
    call menu_shutdown(menu)
    call hud_text_shutdown(hud)
    call input_shutdown()
    call renderer_shutdown(renderer)
    call sim%shutdown()
    if (allocated(bodies_prev)) deallocate(bodies_prev)
    if (allocated(bodies_interp)) deallocate(bodies_interp)
    if (allocated(scene_bodies)) deallocate(scene_bodies)
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

        if (demo%active) then
            if (inp%key_just_pressed(KEY_ESCAPE)) then
                demo%active = .false.
                if (demo_encode_video) call encode_demo_video()
                call finish_demo_mode()
                call log_msg(LOG_INFO, "Demo cancelled")
            end if
            return
        end if

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

        ! Speed presets: + or = (faster), - (slower)
        if (inp%key_just_pressed(KEY_EQUALS) .or. inp%key_just_pressed(KEY_PLUS)) then
            call step_speed_preset(1)
        end if
        if (inp%key_just_pressed(KEY_MINUS)) then
            call step_speed_preset(-1)
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

    subroutine set_speed_preset(new_idx)
        integer, intent(in) :: new_idx
        integer :: old_idx

        old_idx = cfg%speed_preset
        call config_set_speed_preset(cfg, new_idx)
        if (cfg%speed_preset /= old_idx) then
            config_dirty = .true.
            call persist_runtime_config()
            call log_msg(LOG_INFO, "Speed: " // trim(config_speed_label(cfg)))
        end if
    end subroutine set_speed_preset

    subroutine step_speed_preset(delta)
        integer, intent(in) :: delta
        integer :: old_idx

        old_idx = cfg%speed_preset
        call config_step_speed_preset(cfg, delta)
        if (cfg%speed_preset /= old_idx) then
            config_dirty = .true.
            call persist_runtime_config()
            call log_msg(LOG_INFO, "Speed: " // trim(config_speed_label(cfg)))
        end if
    end subroutine step_speed_preset

    subroutine persist_runtime_config()
        call config_toml_write_default(cfg, "config.toml")
        config_dirty = .false.
    end subroutine persist_runtime_config

    subroutine start_demo_mode(demo_id, capture_frames, quit_on_finish)
        integer, intent(in) :: demo_id
        logical, intent(in) :: capture_frames, quit_on_finish

        call save_demo_runtime_state()
        call demo_start(demo, demo_id, capture_frames, quit_on_finish)
        cfg%hud_visible = .false.
        cfg%trails_visible = .false.
        cfg%bloom_on = .true.
        if (demo_is_showcase(demo_id)) then
            cfg%paused = .false.
            cfg%distance_log_scale = .true.
            call config_set_speed_preset(cfg, SPEED_PRESET_COUNT)
        else
            cfg%paused = .true.
            cfg%distance_log_scale = .false.
        end if
        if (capture_frames) call window_set_vsync(.false.)
        call log_msg(LOG_INFO, "Demo started: " // trim(demo_name(demo_id)))
    end subroutine start_demo_mode

    subroutine save_demo_runtime_state()
        saved_hud_visible = cfg%hud_visible
        saved_trails_visible = cfg%trails_visible
        saved_bloom_on = cfg%bloom_on
        saved_distance_log_scale = cfg%distance_log_scale
        saved_paused = cfg%paused
        saved_vsync = cfg%vsync
        saved_speed_preset = cfg%speed_preset
    end subroutine save_demo_runtime_state

    subroutine finish_demo_mode()
        cfg%hud_visible = saved_hud_visible
        cfg%trails_visible = saved_trails_visible
        cfg%bloom_on = saved_bloom_on
        cfg%distance_log_scale = saved_distance_log_scale
        cfg%paused = saved_paused
        call config_set_speed_preset(cfg, saved_speed_preset)
        cfg%vsync = saved_vsync
        call window_set_vsync(saved_vsync)
        demo_encode_video = .false.
        demo_video_path = ""
        demo_frame_dir = "screenshots/demo_frames"
        demo_overlay%count = 0
    end subroutine finish_demo_mode

    subroutine start_demo_recording(demo_id)
        integer, intent(in) :: demo_id
        integer :: dt(8)

        call date_and_time(values=dt)
        write(demo_frame_dir, "('screenshots/demo_frames_',A,'_',I4.4,I2.2,I2.2,'_',I2.2,I2.2,I2.2)") &
            trim(demo_slug(demo_id)), dt(1), dt(2), dt(3), dt(5), dt(6), dt(7)
        write(demo_video_path, "('screenshots/',A,'_',I4.4,I2.2,I2.2,'_',I2.2,I2.2,I2.2,'.mp4')") &
            trim(demo_slug(demo_id)), dt(1), dt(2), dt(3), dt(5), dt(6), dt(7)
        call ensure_directory(trim(demo_frame_dir))
        call ensure_directory("screenshots")
        demo_encode_video = .true.
        call start_demo_mode(demo_id, .true., .false.)
    end subroutine start_demo_recording

    subroutine encode_demo_video()
        integer :: rc
        character(len=1024) :: cmd

        if (.not. demo_encode_video) return
        if (.not. command_exists("ffmpeg")) then
            call log_msg(LOG_ERROR, "Recording failed: ffmpeg not found")
            return
        end if

        write(cmd, "(A)") "ffmpeg -y -framerate 30 -i '" // trim(demo_frame_dir) // &
            "/frame_%05d.png' -c:v libx265 -preset medium -crf 24 -pix_fmt yuv420p " // &
            "-tag:v hvc1 -movflags +faststart '" // trim(demo_video_path) // "'"
        call execute_command_line(trim(cmd), wait=.true., exitstat=rc)
        if (rc == 0) then
            call log_msg(LOG_INFO, "Demo video: " // trim(demo_video_path))
            call delete_directory(trim(demo_frame_dir))
        else
            call log_msg(LOG_ERROR, "ffmpeg encode failed for " // trim(demo_video_path))
        end if
    end subroutine encode_demo_video

    subroutine compose_scene_bodies()
        integer :: i, n

        n = sim%n_bodies()
        scene_bodies(1:n) = bodies_interp
        do i = 1, demo_overlay%count
            scene_bodies(n + i) = demo_overlay%bodies(i)
        end do
    end subroutine compose_scene_bodies

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
    ! Render HUD overlay + top-bar menu. The menu always shows; the HUD
    ! lines (FPS, date, etc.) gate on cfg%hud_visible. HUD text sits
    ! below the menu bar so it doesn't clip under open panels.
    !=====================================================================
    subroutine render_hud_and_menu()
        type(sim_date_t) :: sim_date
        character(len=32) :: ts_str, fps_str, focus_str, pause_str
        real(c_float) :: y0

        call hud_text_clear(hud)

        if (cfg%hud_visible) then
            y0 = MENU_BAR_H + 8.0_c_float

            ! FPS
            write(fps_str, "(A,F6.1)") "FPS: ", fps_smooth
            call hud_text_draw(hud, 10.0_c_float, y0, trim(fps_str), &
                               1.0_c_float, 1.0_c_float, 1.0_c_float)

            ! Simulated date
            call j2000_to_date(sim_time, sim_date)
            write(ts_str, "(I4.4,'-',I2.2,'-',I2.2,' ',I2.2,':',I2.2,':',I2.2)") &
                sim_date%year, sim_date%month, sim_date%day, &
                sim_date%hour, sim_date%minute, int(sim_date%second)
            call hud_text_draw(hud, 10.0_c_float, y0 + 15.0_c_float, &
                               "Date: " // trim(ts_str), &
                               1.0_c_float, 1.0_c_float, 1.0_c_float)

            ! Time scale
            ts_str = config_speed_label(cfg)
            call hud_text_draw(hud, 10.0_c_float, y0 + 30.0_c_float, &
                               "Speed: " // trim(ts_str), &
                               1.0_c_float, 1.0_c_float, 1.0_c_float)

            ! Focus
            focus_str = "Focus: " // trim(cfg%focus_names(cfg%focus_index+1))
            call hud_text_draw(hud, 10.0_c_float, y0 + 45.0_c_float, focus_str, &
                               1.0_c_float, 1.0_c_float, 1.0_c_float)

            ! Paused indicator
            if (cfg%paused) then
                pause_str = "[PAUSED]"
                call hud_text_draw(hud, 10.0_c_float, y0 + 60.0_c_float, pause_str, &
                                   1.0_c_float, 0.3_c_float, 0.3_c_float)
            end if

            ! Exposure / bloom readout
            if (cfg%bloom_on) then
                write(ts_str, "(A,F4.2)") "Exposure: ", cfg%exposure
                call hud_text_draw(hud, 10.0_c_float, y0 + 75.0_c_float, trim(ts_str), &
                                   1.0_c_float, 1.0_c_float, 0.6_c_float)
            else
                call hud_text_draw(hud, 10.0_c_float, y0 + 75.0_c_float, "Bloom: OFF", &
                                   0.7_c_float, 0.7_c_float, 0.7_c_float)
            end if
        end if

        ! Keep the top menu available during normal interaction even when the
        ! user hides the stats/readout HUD. Auto-screenshots and demos still
        ! suppress the menu for a clean frame.
        if ((.not. auto_screenshot) .and. (.not. demo%active)) then
            call menu_render(menu, hud, win_w)
        end if

        call hud_text_render(hud, win_w, win_h)
    end subroutine render_hud_and_menu

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
    ! Place the orbit camera on a chosen side of body `idx` (0-based index
    ! where 0=Sun, 3=Earth, …), pointing at it with a small elevation bias.
    !
    ! night_side = .false. → camera on the sunward side (sees lit face).
    ! night_side = .true.  → camera on the anti-sun side (sees dark face,
    !                         with Earth's night-lights texture visible).
    !=====================================================================
    subroutine aim_camera_at_body(idx, night_side)
        integer, intent(in) :: idx
        logical, intent(in) :: night_side
        real(c_float) :: p(3), s(3), sun_dir(3), dlen, dist
        real(c_float) :: view_up(3), forward(3), eye_dir(3)
        integer :: body_idx
        au_val = AU
        body_idx = idx + 1
        p(1) = real(sim%bodies(body_idx)%position%x / au_val, c_float)
        p(2) = real(sim%bodies(body_idx)%position%y / au_val, c_float)
        p(3) = real(sim%bodies(body_idx)%position%z / au_val, c_float)
        s(1) = real(sim%bodies(1)%position%x / au_val, c_float)
        s(2) = real(sim%bodies(1)%position%y / au_val, c_float)
        s(3) = real(sim%bodies(1)%position%z / au_val, c_float)

        cam%focus = p
        cam%focus_target = p
        cam%focus_progress = 1.0_c_float

        if (.not. night_side) then
            ! Day shot — camera on sun side, view_up aligned with ecliptic
            ! north (+Z) so Earth's tilted model renders with north up and
            ! the terminator runs vertically (day half on right of frame).
            sun_dir = s - p
            dlen = sqrt(sun_dir(1)**2 + sun_dir(2)**2 + sun_dir(3)**2)
            if (dlen < 1.0e-6_c_float) return
            sun_dir = sun_dir / dlen
            view_up = [0.0_c_float, 0.0_c_float, 1.0_c_float]
            forward(1) = view_up(2)*sun_dir(3) - view_up(3)*sun_dir(2)
            forward(2) = view_up(3)*sun_dir(1) - view_up(1)*sun_dir(3)
            forward(3) = view_up(1)*sun_dir(2) - view_up(2)*sun_dir(1)
            dlen = sqrt(forward(1)**2 + forward(2)**2 + forward(3)**2)
            if (dlen < 1.0e-6_c_float) return
            forward = -forward / dlen     ! flip so sun is to the LEFT
            eye_dir = -forward
            dist = 10.0_c_float ** cam%log_dist
            cam%eye = p + dist * eye_dir
            cam%view_up = view_up
            cam%eye_override = .true.
            return
        end if

        ! Night shot — place camera so the sun-to-planet line lies along
        ! the camera's RIGHT axis. That gives a vertical terminator (day
        ! half on one side, night half on the other) instead of the
        ! top-lit / bottom-dark look the ecliptic-up camera produces when
        ! Earth sits near +Y at J2000.
        sun_dir = s - p                                  ! planet → sun
        dlen = sqrt(sun_dir(1)**2 + sun_dir(2)**2 + sun_dir(3)**2)
        if (dlen < 1.0e-6_c_float) return
        sun_dir = sun_dir / dlen

        ! view_up = world +Z — perpendicular to the ecliptic, and therefore
        ! perpendicular to sun_dir (which lies in the ecliptic for planets
        ! with small z). Gives ecliptic-north as the camera's up.
        view_up = [0.0_c_float, 0.0_c_float, 1.0_c_float]

        ! forward = cross(view_up, sun_dir) puts sun_dir along +right, so
        ! the lit half is on the right of frame and the night half on the
        ! left — the classic "half Earth" pose.
        forward(1) = view_up(2)*sun_dir(3) - view_up(3)*sun_dir(2)
        forward(2) = view_up(3)*sun_dir(1) - view_up(1)*sun_dir(3)
        forward(3) = view_up(1)*sun_dir(2) - view_up(2)*sun_dir(1)
        dlen = sqrt(forward(1)**2 + forward(2)**2 + forward(3)**2)
        if (dlen < 1.0e-6_c_float) return
        forward = forward / dlen

        eye_dir = -forward
        dist = 10.0_c_float ** cam%log_dist
        cam%eye = p + dist * eye_dir
        cam%view_up = view_up
        cam%eye_override = .true.
    end subroutine aim_camera_at_body

    !=====================================================================
    ! F12 — read back default framebuffer and write screenshots/phase6.png
    !=====================================================================
    subroutine take_screenshot()
        call write_png_capture(trim(screenshot_path), log_result=.true.)
    end subroutine take_screenshot

    !=====================================================================
    ! F2 — timestamped PNG of the tonemapped backbuffer into screenshots/.
    !=====================================================================
    subroutine take_screenshot_timestamped()
        integer :: dt(8)
        character(len=160) :: path

        call date_and_time(values=dt)
        write(path, "('screenshots/solarsim_',I4.4,I2.2,I2.2,'_',I2.2,I2.2,I2.2,'.png')") &
            dt(1), dt(2), dt(3), dt(5), dt(6), dt(7)
        call write_png_capture(trim(path), log_result=.true.)
    end subroutine take_screenshot_timestamped

    subroutine take_demo_capture_frame()
        character(len=320) :: path

        write(path, "(A,'/frame_',I5.5,'.png')") trim(demo_frame_dir), demo%frame_index + 1
        call write_png_capture(trim(path), log_result=.false.)
    end subroutine take_demo_capture_frame

    subroutine write_png_capture(path, log_result)
        use, intrinsic :: iso_c_binding, only: c_loc, c_signed_char
        character(len=*), intent(in) :: path
        logical, intent(in) :: log_result
        integer(c_int) :: w, h, rc
        integer(c_signed_char), allocatable, target :: pixels(:)

        w = int(win_w, c_int)
        h = int(win_h, c_int)
        allocate(pixels(3 * w * h))
        call gl_read_pixels_rgb(0_c_int, 0_c_int, w, h, c_loc(pixels(1)))

        rc = ss_write_png_c(trim(path) // char(0), w, h, c_loc(pixels(1)))
        if (log_result) then
            if (rc == 1_c_int) then
                call log_msg(LOG_INFO, "Screenshot: " // trim(path))
            else
                call log_msg(LOG_ERROR, "Screenshot failed: " // trim(path))
            end if
        else if (rc /= 1_c_int) then
            call log_msg(LOG_ERROR, "Demo frame write failed: " // trim(path))
        end if
        deallocate(pixels)
    end subroutine write_png_capture

    !=====================================================================
    ! Load planet textures and build materials.
    ! Body indices: 1=Sun, 2=Mercury, 3=Venus, 4=Earth, 5=Mars,
    !               6=Jupiter, 7=Saturn, 8=Uranus, 9=Neptune.
    !=====================================================================
    subroutine load_materials()
        type(material_t) :: m
        type(material_t) :: blank

        ! Mercury (generic, rocky — normal map absent, low spec)
        m = blank
        m%kind = MATERIAL_GENERIC
        m%shininess = 8.0_c_float
        m%spec_scale = 0.02_c_float
        call texture_load(m%albedo, "assets/planets/2k_mercury.jpg")
        call renderer_set_material(renderer, 2, m)

        m = blank
        ! Venus (thick atmosphere — strong warm rim, no normal)
        m%kind = MATERIAL_GAS_GIANT
        m%shininess = 4.0_c_float
        m%spec_scale = 0.0_c_float
        m%rim_power = 3.0_c_float
        m%rim_color = [0.95_c_float, 0.75_c_float, 0.45_c_float]
        call texture_load(m%albedo, "assets/planets/2k_venus_atmosphere.jpg")
        call renderer_set_material(renderer, 3, m)

        m = blank
        ! Earth (day, night, ocean spec, normal, rim)
        ! rim_power=6 gives a tight cyan halo; at rim_power=3 the glow
        ! swallowed the disc (see phase7_earth.png and early phase8 shots).
        m%kind = MATERIAL_EARTH
        m%shininess = 48.0_c_float
        m%spec_scale = 0.35_c_float
        m%rim_power = 6.0_c_float
        m%rim_color = [0.18_c_float, 0.30_c_float, 0.55_c_float]
        call texture_load(m%albedo,   "assets/planets/2k_earth_daymap.jpg")
        if (cfg%load_earth_normal) then
            call texture_load(m%normal, "assets/planets/2k_earth_normal_map.png", srgb=.false.)
        end if
        if (cfg%load_earth_night) then
            call texture_load(m%night, "assets/planets/2k_earth_nightmap.jpg")
        end if
        if (cfg%load_earth_specular) then
            call texture_load(m%specular, "assets/planets/2k_earth_specular_map.png", srgb=.false.)
        else
            m%spec_scale = 0.0_c_float
        end if
        call texture_load(m%clouds, "assets/planets/2k_earth_clouds.jpg")
        call renderer_set_material(renderer, 4, m)

        m = blank
        ! Mars
        m%kind = MATERIAL_GENERIC
        m%shininess = 12.0_c_float
        m%spec_scale = 0.03_c_float
        call texture_load(m%albedo, "assets/planets/2k_mars.jpg")
        call renderer_set_material(renderer, 5, m)

        m = blank
        ! Jupiter (gas giant with subtle rim)
        m%kind = MATERIAL_GAS_GIANT
        m%shininess = 4.0_c_float
        m%spec_scale = 0.0_c_float
        m%rim_power = 4.0_c_float
        m%rim_color = [0.9_c_float, 0.75_c_float, 0.55_c_float]
        call texture_load(m%albedo, "assets/planets/2k_jupiter.jpg")
        call renderer_set_material(renderer, 6, m)

        m = blank
        ! Saturn
        m%kind = MATERIAL_GAS_GIANT
        m%rim_power = 4.0_c_float
        m%rim_color = [0.95_c_float, 0.85_c_float, 0.60_c_float]
        call texture_load(m%albedo, "assets/planets/2k_saturn.jpg")
        call renderer_set_material(renderer, 7, m)

        m = blank
        ! Uranus
        m%kind = MATERIAL_GAS_GIANT
        m%rim_power = 3.5_c_float
        m%rim_color = [0.55_c_float, 0.85_c_float, 0.95_c_float]
        call texture_load(m%albedo, "assets/planets/2k_uranus.jpg")
        call renderer_set_material(renderer, 8, m)

        m = blank
        ! Neptune
        m%kind = MATERIAL_GAS_GIANT
        m%rim_power = 3.5_c_float
        m%rim_color = [0.35_c_float, 0.55_c_float, 0.95_c_float]
        call texture_load(m%albedo, "assets/planets/2k_neptune.jpg")
        call renderer_set_material(renderer, 9, m)

        if (size(renderer%materials) >= 13) then
            m = blank
            m%kind = MATERIAL_GENERIC
            m%shininess = 24.0_c_float
            m%spec_scale = 0.04_c_float
            call texture_load(m%albedo, "assets/planets/2k_mercury.jpg")
            call renderer_set_material(renderer, 10, m)

            m = blank
            m%kind = MATERIAL_GENERIC
            m%shininess = 18.0_c_float
            m%spec_scale = 0.02_c_float
            call texture_load(m%albedo, "assets/planets/2k_venus_surface.jpg")
            call renderer_set_material(renderer, 11, m)

            m = blank
            m%kind = MATERIAL_GENERIC
            m%shininess = 16.0_c_float
            m%spec_scale = 0.03_c_float
            call texture_load(m%albedo, "assets/planets/2k_mars.jpg")
            call renderer_set_material(renderer, 12, m)

            m = blank
            m%kind = MATERIAL_GAS_GIANT
            m%shininess = 8.0_c_float
            m%spec_scale = 0.0_c_float
            m%rim_power = 3.0_c_float
            m%rim_color = [0.85_c_float, 0.65_c_float, 0.45_c_float]
            call texture_load(m%albedo, "assets/planets/2k_jupiter.jpg")
            call renderer_set_material(renderer, 13, m)
        end if

        ! Saturn's rings
        if (cfg%load_saturn_rings) then
            call rings_init(rings, "assets/planets/2k_saturn_ring_alpha.png", &
                            1.25_c_float, 2.20_c_float, 128)
            call renderer_set_rings(renderer, rings, 7)
        end if
    end subroutine load_materials

    pure function itoa(i) result(s)
        integer, intent(in) :: i
        character(len=12) :: s
        write(s, "(I0)") i
    end function itoa

    !=====================================================================
    ! Populate the top-bar menu. Four drop-downs: File, View, Camera,
    ! Render. Field and action enum values come from the top of this
    ! program unit; menu_mod dispatches them back to us via
    ! menu_pop_action.
    !=====================================================================
    subroutine build_menu()
        integer :: d_file, d_view, d_camera, d_render, d_demos, i
        type(menu_item_t) :: it

        call menu_init(menu, 5)

        !-- File -----------------------------------------------------
        call menu_add_dropdown(menu, "File", 5, d_file)
        it%kind = ITEM_BUTTON; it%label = "Screenshot (F12)"
        it%action_id = ACTION_SCREENSHOT
        call menu_add_item(menu, d_file, it)
        it%kind = ITEM_BUTTON; it%label = "Save Timestamped (F2)"
        it%action_id = ACTION_SCREENSHOT_TS
        call menu_add_item(menu, d_file, it)
        it%kind = ITEM_SEPARATOR; it%label = ""; it%action_id = 0
        call menu_add_item(menu, d_file, it)
        it%kind = ITEM_BUTTON; it%label = "Quit"
        it%action_id = ACTION_QUIT
        call menu_add_item(menu, d_file, it)

        !-- Demos ----------------------------------------------------
        call menu_add_dropdown(menu, "Demos", 2 * DEMO_COUNT + (DEMO_COUNT - 1), d_demos)
        do i = 1, DEMO_COUNT
            it = blank_item()
            it%kind = ITEM_BUTTON
            it%label = trim(demo_name(i))
            it%action_id = ACTION_DEMO_BASE + (i - 1)
            call menu_add_item(menu, d_demos, it)

            it = blank_item()
            it%kind = ITEM_BUTTON
            it%label = "Record " // trim(demo_name(i))
            it%action_id = ACTION_DEMO_RECORD_BASE + (i - 1)
            call menu_add_item(menu, d_demos, it)

            if (i < DEMO_COUNT) then
                it = blank_item()
                it%kind = ITEM_SEPARATOR
                call menu_add_item(menu, d_demos, it)
            end if
        end do

        !-- View -----------------------------------------------------
        call menu_add_dropdown(menu, "View", 7, d_view)
        it = blank_item()
        it%kind = ITEM_TOGGLE; it%label = "Show Stats"
        it%field_id = FIELD_HUD; it%bool_value = cfg%hud_visible
        call menu_add_item(menu, d_view, it)
        it%label = "Show Orbit Trails"
        it%field_id = FIELD_TRAILS; it%bool_value = cfg%trails_visible
        call menu_add_item(menu, d_view, it)
        it%label = "Bloom"
        it%field_id = FIELD_BLOOM; it%bool_value = cfg%bloom_on
        call menu_add_item(menu, d_view, it)
        it%label = "V-Sync"
        it%field_id = FIELD_VSYNC; it%bool_value = cfg%vsync
        call menu_add_item(menu, d_view, it)
        it%label = "Pause Simulation"
        it%field_id = FIELD_PAUSED; it%bool_value = cfg%paused
        call menu_add_item(menu, d_view, it)
        it%label = "Log-Scale Distances"
        it%field_id = FIELD_LOG_SCALE; it%bool_value = cfg%distance_log_scale
        call menu_add_item(menu, d_view, it)

        !-- Camera ---------------------------------------------------
        call menu_add_dropdown(menu, "Camera", 12, d_camera)
        do i = 0, 8
            it = blank_item()
            it%kind = ITEM_BUTTON
            it%label = "Focus: " // trim(cfg%focus_names(i+1))
            it%action_id = ACTION_FOCUS_BASE + i
            call menu_add_item(menu, d_camera, it)
        end do
        it = blank_item(); it%kind = ITEM_SEPARATOR
        call menu_add_item(menu, d_camera, it)
        it = blank_item()
        it%kind = ITEM_BUTTON; it%label = "Reset View"
        it%action_id = ACTION_CAMERA_RESET
        call menu_add_item(menu, d_camera, it)

        !-- Render ---------------------------------------------------
        call menu_add_dropdown(menu, "Render", 6, d_render)
        it = blank_item()
        it%kind = ITEM_SLIDER; it%label = "Exposure"
        it%field_id = FIELD_EXPOSURE
        it%slider_min = real(EXPOSURE_MIN, c_float)
        it%slider_max = real(EXPOSURE_MAX, c_float)
        it%value = real(cfg%exposure, c_float)
        call menu_add_item(menu, d_render, it)
        it = blank_item()
        it%kind = ITEM_SLIDER; it%label = "Bloom Amount"
        it%field_id = FIELD_BLOOM_INT
        it%slider_min = 0.0_c_float
        it%slider_max = 2.0_c_float
        it%value = real(cfg%bloom_intensity, c_float)
        call menu_add_item(menu, d_render, it)
        it = blank_item()
        it%kind = ITEM_LABEL; it%label = "Speed: " // trim(config_speed_label(cfg))
        it%field_id = FIELD_SPEED_LABEL
        call menu_add_item(menu, d_render, it)
        it = blank_item()
        it%kind = ITEM_BUTTON; it%label = "Slower (-)"
        it%action_id = ACTION_SPEED_SLOWER
        call menu_add_item(menu, d_render, it)
        it = blank_item()
        it%kind = ITEM_BUTTON; it%label = "Faster (+)"
        it%action_id = ACTION_SPEED_FASTER
        call menu_add_item(menu, d_render, it)
        it = blank_item()
        it%kind = ITEM_SLIDER; it%label = "Speed Preset"
        it%field_id = FIELD_SPEED_PRESET
        it%slider_min = 1.0_c_float
        it%slider_max = real(SPEED_PRESET_COUNT, c_float)
        it%value = real(cfg%speed_preset, c_float)
        call menu_add_item(menu, d_render, it)
    end subroutine build_menu

    pure function blank_item() result(it)
        type(menu_item_t) :: it
        it%kind       = 0
        it%label      = ""
        it%field_id   = 0
        it%action_id  = 0
        it%value      = 0.0_c_float
        it%bool_value = .false.
        it%slider_min = 0.0_c_float
        it%slider_max = 1.0_c_float
        it%is_log     = .false.
    end function blank_item

    !=====================================================================
    ! Sync cfg → menu so keyboard shortcuts (SPACE, H, B, T, +/-)
    ! keep the menu's displayed state in sync.
    !=====================================================================
    subroutine sync_menu_from_cfg()
        call menu_set_toggle(menu, FIELD_HUD,    cfg%hud_visible)
        call menu_set_toggle(menu, FIELD_TRAILS, cfg%trails_visible)
        call menu_set_toggle(menu, FIELD_BLOOM,  cfg%bloom_on)
        call menu_set_toggle(menu, FIELD_VSYNC,  cfg%vsync)
        call menu_set_toggle(menu, FIELD_PAUSED, cfg%paused)
        call menu_set_toggle(menu, FIELD_LOG_SCALE, cfg%distance_log_scale)
        call menu_set_slider(menu, FIELD_EXPOSURE,      real(cfg%exposure,        c_float))
        call menu_set_slider(menu, FIELD_BLOOM_INT,     real(cfg%bloom_intensity, c_float))
        call menu_set_label(menu, FIELD_SPEED_LABEL, "Speed: " // trim(config_speed_label(cfg)))
        call menu_set_slider(menu, FIELD_SPEED_PRESET, real(cfg%speed_preset, c_float))
    end subroutine sync_menu_from_cfg

    !=====================================================================
    ! Pull a fresh event code off the menu and mutate cfg / app state.
    !=====================================================================
    subroutine dispatch_menu_action()
        integer :: act
        real(c_float) :: v
        logical :: b
        integer :: speed_idx
        act = menu_pop_action(menu)
        if (act == 0) return

        if (act < 0) then
            ! Toggle events — menu flipped the bool and sent -field_id
            select case (-act)
            case (FIELD_HUD)
                cfg%hud_visible = menu_get_toggle(menu, FIELD_HUD)
            case (FIELD_TRAILS)
                cfg%trails_visible = menu_get_toggle(menu, FIELD_TRAILS)
            case (FIELD_BLOOM)
                cfg%bloom_on = menu_get_toggle(menu, FIELD_BLOOM)
            case (FIELD_VSYNC)
                b = menu_get_toggle(menu, FIELD_VSYNC)
                cfg%vsync = b
                call window_set_vsync(b)
            case (FIELD_PAUSED)
                cfg%paused = menu_get_toggle(menu, FIELD_PAUSED)
            case (FIELD_LOG_SCALE)
                cfg%distance_log_scale = menu_get_toggle(menu, FIELD_LOG_SCALE)
            end select
            return
        end if

        if (act < 100) then
            ! Slider events
            select case (act)
            case (FIELD_EXPOSURE)
                cfg%exposure = menu_get_slider(menu, FIELD_EXPOSURE)
            case (FIELD_BLOOM_INT)
                cfg%bloom_intensity = menu_get_slider(menu, FIELD_BLOOM_INT)
            case (FIELD_SPEED_PRESET)
                v = menu_get_slider(menu, FIELD_SPEED_PRESET)
                speed_idx = nint(v)
                call set_speed_preset(speed_idx)
            end select
            return
        end if

        ! Buttons (action_id >= 100)
        select case (act)
        case (ACTION_SCREENSHOT)
            call take_screenshot_timestamped()
        case (ACTION_SCREENSHOT_TS)
            call take_screenshot_timestamped()
        case (ACTION_QUIT)
            running = .false.
        case (ACTION_CAMERA_RESET)
            call camera_reset(cam)
        case (ACTION_SPEED_SLOWER)
            call step_speed_preset(-1)
        case (ACTION_SPEED_FASTER)
            call step_speed_preset(1)
        case default
            if (act >= ACTION_DEMO_BASE .and. act < ACTION_DEMO_BASE + DEMO_COUNT) then
                call start_demo_mode(act - ACTION_DEMO_BASE + 1, .false., .false.)
                return
            end if
            if (act >= ACTION_DEMO_RECORD_BASE .and. act < ACTION_DEMO_RECORD_BASE + DEMO_COUNT) then
                call start_demo_recording(act - ACTION_DEMO_RECORD_BASE + 1)
                return
            end if
            if (act >= ACTION_FOCUS_BASE .and. act <= ACTION_FOCUS_BASE + 8) then
                cfg%focus_index = act - ACTION_FOCUS_BASE
                call focus_on_body(cfg%focus_index)
            end if
        end select
    end subroutine dispatch_menu_action

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

    subroutine ensure_directory(path)
        character(len=*), intent(in) :: path
        integer :: rc
        character(len=512) :: cmd

        write(cmd, "(A)") "mkdir -p '" // trim(path) // "'"
        call execute_command_line(trim(cmd), wait=.true., exitstat=rc)
    end subroutine ensure_directory

    subroutine delete_directory(path)
        character(len=*), intent(in) :: path
        integer :: rc
        character(len=512) :: cmd

        write(cmd, "(A)") "rm -rf '" // trim(path) // "'"
        call execute_command_line(trim(cmd), wait=.true., exitstat=rc)
    end subroutine delete_directory

    logical function command_exists(name)
        character(len=*), intent(in) :: name
        integer :: rc
        character(len=512) :: cmd

        write(cmd, "(A)") "command -v '" // trim(name) // "' >/dev/null 2>&1"
        call execute_command_line(trim(cmd), wait=.true., exitstat=rc)
        command_exists = (rc == 0)
    end function command_exists

end program solarsim
