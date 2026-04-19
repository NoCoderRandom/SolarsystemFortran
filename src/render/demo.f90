!===============================================================================
! demo.f90 — Automated demo director for preview + recording
!
! The demo system can drive the original showcase camera as well as synthetic
! "demon" actors that are rendered as extra bodies on top of the solar system.
!===============================================================================
module demo_mod
    use, intrinsic :: iso_c_binding, only: c_float
    use body_mod, only: body_t
    use camera_mod, only: camera_t
    use constants, only: AU, PI
    use vector3d, only: vec3, zero_vec3
    implicit none
    private

    public :: demo_state_t, demo_overlay_t, demo_init, demo_start, demo_apply
    public :: demo_advance, demo_name, demo_slug, demo_is_showcase
    public :: DEMO_DURATION_SECONDS, DEMO_CAPTURE_FPS, DEMO_COUNT
    public :: DEMO_ID_SHOWCASE, DEMO_ID_EARTH_ORBIT_AAMON
    public :: DEMO_ID_EARTH_ORBIT_BARBATOS, DEMO_ID_EARTH_ORBIT_CROCELL
    public :: DEMO_ID_EARTH_ORBIT_DANTALION, DEMO_ID_EARTH_MARS_FIGURE_EIGHT
    public :: DEMO_ID_EARTH_MARS_TRIP, DEMO_ID_MARS_ORBIT_SURVEY, DEMO_ID_INNER_WORLDS_TOUR
    public :: MAX_DEMO_BODIES

    real(c_float), parameter :: DEMO_DURATION_SECONDS = 40.0_c_float
    integer, parameter :: DEMO_CAPTURE_FPS = 30
    integer, parameter :: DEMO_SHOT_COUNT = 9
    integer, parameter :: DEMO_COUNT = 9
    integer, parameter :: MAX_DEMO_BODIES = 4

    integer, parameter :: BODY_SUN = 0
    integer, parameter :: BODY_MERCURY = 1
    integer, parameter :: BODY_VENUS = 2
    integer, parameter :: BODY_EARTH = 3
    integer, parameter :: BODY_MARS = 4

    integer, parameter :: DEMO_ID_SHOWCASE = 1
    integer, parameter :: DEMO_ID_EARTH_ORBIT_AAMON = 2
    integer, parameter :: DEMO_ID_EARTH_ORBIT_BARBATOS = 3
    integer, parameter :: DEMO_ID_EARTH_ORBIT_CROCELL = 4
    integer, parameter :: DEMO_ID_EARTH_ORBIT_DANTALION = 5
    integer, parameter :: DEMO_ID_EARTH_MARS_FIGURE_EIGHT = 6
    integer, parameter :: DEMO_ID_EARTH_MARS_TRIP = 7
    integer, parameter :: DEMO_ID_MARS_ORBIT_SURVEY = 8
    integer, parameter :: DEMO_ID_INNER_WORLDS_TOUR = 9

    type :: demo_shot_t
        integer       :: focus_index = 0
        real(c_float) :: azimuth = 0.0_c_float
        real(c_float) :: elevation = 0.8_c_float
        real(c_float) :: log_dist = 1.0_c_float
        real(c_float) :: orbit_span = 0.0_c_float
    end type demo_shot_t

    type, public :: demo_state_t
        logical :: active = .false.
        logical :: capture_frames = .false.
        logical :: quit_on_finish = .false.
        integer :: demo_id = DEMO_ID_SHOWCASE
        real(c_float) :: timeline = 0.0_c_float
        real(c_float) :: duration = DEMO_DURATION_SECONDS
        integer :: frame_index = 0
        integer :: total_frames = int(DEMO_DURATION_SECONDS * real(DEMO_CAPTURE_FPS, c_float))
    end type demo_state_t

    type, public :: demo_overlay_t
        integer :: count = 0
        type(body_t) :: bodies(MAX_DEMO_BODIES)
    end type demo_overlay_t

    type(demo_shot_t), parameter :: SHOTS(DEMO_SHOT_COUNT) = [ &
        demo_shot_t(0,  0.20_c_float, 0.80_c_float, 1.85_c_float, 0.60_c_float), &
        demo_shot_t(1, -0.25_c_float, 0.44_c_float, 0.18_c_float, 0.55_c_float), &
        demo_shot_t(2,  0.55_c_float, 0.52_c_float, 0.22_c_float, 0.45_c_float), &
        demo_shot_t(3, -0.60_c_float, 0.72_c_float, -0.28_c_float, 0.55_c_float), &
        demo_shot_t(4,  0.95_c_float, 0.62_c_float, -0.10_c_float, 0.45_c_float), &
        demo_shot_t(5,  1.85_c_float, 0.66_c_float, 0.30_c_float, 0.35_c_float), &
        demo_shot_t(6,  2.35_c_float, 0.74_c_float, 0.22_c_float, 0.45_c_float), &
        demo_shot_t(7,  2.85_c_float, 0.62_c_float, 0.18_c_float, 0.30_c_float), &
        demo_shot_t(8,  3.25_c_float, 0.64_c_float, 0.16_c_float, 0.25_c_float)  &
    ]

    character(len=24), parameter :: DEMO_NAMES(DEMO_COUNT) = [ &
        "Existing Demo           ", &
        "Earth Orbit: Aamon      ", &
        "Earth Orbit: Barbatos   ", &
        "Earth Orbit: Crocell    ", &
        "Earth Orbit: Dantalion  ", &
        "Earth <-> Mars Figure-8 ", &
        "Earth -> Mars Trip      ", &
        "Mars Orbit Survey       ", &
        "Inner Worlds Tour       " ]

    character(len=24), parameter :: DEMO_SLUGS(DEMO_COUNT) = [ &
        "existing_demo           ", &
        "earth_orbit_aamon       ", &
        "earth_orbit_barbatos    ", &
        "earth_orbit_crocell     ", &
        "earth_orbit_dantalion   ", &
        "earth_mars_figure8      ", &
        "earth_mars_trip         ", &
        "mars_orbit_survey       ", &
        "inner_worlds_tour       " ]

contains

    subroutine demo_init(state)
        type(demo_state_t), intent(out) :: state
        state%active = .false.
        state%capture_frames = .false.
        state%quit_on_finish = .false.
        state%demo_id = DEMO_ID_SHOWCASE
        state%timeline = 0.0_c_float
        state%duration = demo_duration_for(DEMO_ID_SHOWCASE)
        state%frame_index = 0
        state%total_frames = int(state%duration * real(DEMO_CAPTURE_FPS, c_float))
    end subroutine demo_init

    subroutine demo_start(state, demo_id, capture_frames, quit_on_finish)
        type(demo_state_t), intent(inout) :: state
        integer, intent(in) :: demo_id
        logical, intent(in) :: capture_frames, quit_on_finish
        state%active = .true.
        state%capture_frames = capture_frames
        state%quit_on_finish = quit_on_finish
        state%demo_id = clamp_demo_id(demo_id)
        state%timeline = 0.0_c_float
        state%duration = demo_duration_for(state%demo_id)
        state%frame_index = 0
        state%total_frames = int(state%duration * real(DEMO_CAPTURE_FPS, c_float))
    end subroutine demo_start

    subroutine demo_apply(state, cam, bodies, focus_index, overlay)
        type(demo_state_t), intent(in) :: state
        type(camera_t), intent(inout) :: cam
        type(body_t), intent(in) :: bodies(:)
        integer, intent(out) :: focus_index
        type(demo_overlay_t), intent(out) :: overlay

        call clear_overlay(overlay)
        if (.not. state%active) then
            focus_index = 0
            return
        end if

        select case (state%demo_id)
        case (DEMO_ID_SHOWCASE)
            call apply_showcase(state, cam, bodies, focus_index)
        case (DEMO_ID_EARTH_ORBIT_AAMON, DEMO_ID_EARTH_ORBIT_BARBATOS, &
              DEMO_ID_EARTH_ORBIT_CROCELL, DEMO_ID_EARTH_ORBIT_DANTALION)
            call apply_earth_orbit_group(state, cam, bodies, focus_index, overlay)
        case (DEMO_ID_EARTH_MARS_FIGURE_EIGHT)
            call apply_earth_mars_figure_eight(state, cam, bodies, focus_index, overlay)
        case (DEMO_ID_EARTH_MARS_TRIP)
            call apply_earth_mars_trip(state, cam, bodies, focus_index, overlay)
        case (DEMO_ID_MARS_ORBIT_SURVEY)
            call apply_mars_orbit_survey(state, cam, bodies, focus_index, overlay)
        case (DEMO_ID_INNER_WORLDS_TOUR)
            call apply_inner_worlds_tour(state, cam, bodies, focus_index, overlay)
        case default
            call apply_showcase(state, cam, bodies, focus_index)
        end select
    end subroutine demo_apply

    subroutine demo_advance(state, frame_dt, finished)
        type(demo_state_t), intent(inout) :: state
        real(c_float), intent(in) :: frame_dt
        logical, intent(out) :: finished

        finished = .false.
        if (.not. state%active) return

        state%frame_index = state%frame_index + 1
        state%timeline = state%timeline + frame_dt
        if (state%capture_frames) then
            if (state%frame_index >= state%total_frames) finished = .true.
        else
            if (state%timeline >= state%duration) finished = .true.
        end if
        if (finished) state%active = .false.
    end subroutine demo_advance

    pure function demo_name(demo_id) result(name)
        integer, intent(in) :: demo_id
        character(len=24) :: name
        name = DEMO_NAMES(clamp_demo_id(demo_id))
    end function demo_name

    pure function demo_slug(demo_id) result(slug)
        integer, intent(in) :: demo_id
        character(len=24) :: slug
        slug = DEMO_SLUGS(clamp_demo_id(demo_id))
    end function demo_slug

    pure logical function demo_is_showcase(demo_id)
        integer, intent(in) :: demo_id
        demo_is_showcase = clamp_demo_id(demo_id) == DEMO_ID_SHOWCASE
    end function demo_is_showcase

    subroutine apply_showcase(state, cam, bodies, focus_index)
        type(demo_state_t), intent(in) :: state
        type(camera_t), intent(inout) :: cam
        type(body_t), intent(in) :: bodies(:)
        integer, intent(out) :: focus_index
        real(c_float) :: shot_len, t, shot_phase, blend, focus_a(3), focus_b(3)
        integer :: ia, ib

        shot_len = state%duration / real(DEMO_SHOT_COUNT, c_float)
        t = min(state%timeline, max(state%duration - 1.0e-5_c_float, 0.0_c_float))
        ia = min(int(t / shot_len) + 1, DEMO_SHOT_COUNT)
        ib = min(ia + 1, DEMO_SHOT_COUNT)
        shot_phase = (t - real(ia - 1, c_float) * shot_len) / shot_len
        blend = smoothstep(max((shot_phase - 0.72_c_float) / 0.28_c_float, 0.0_c_float))

        focus_a = body_position_au(bodies, SHOTS(ia)%focus_index)
        focus_b = body_position_au(bodies, SHOTS(ib)%focus_index)
        call set_camera_focus(cam, lerp3(focus_a, focus_b, blend))
        cam%azimuth = mix(SHOTS(ia)%azimuth + SHOTS(ia)%orbit_span * shot_phase, &
                          SHOTS(ib)%azimuth, blend)
        cam%elevation = mix(SHOTS(ia)%elevation, SHOTS(ib)%elevation, blend)
        cam%log_dist = mix(SHOTS(ia)%log_dist, SHOTS(ib)%log_dist, blend)
        cam%view_up = [0.0_c_float, 1.0_c_float, 0.0_c_float]
        cam%eye_override = .false.
        focus_index = SHOTS(ia)%focus_index
    end subroutine apply_showcase

    subroutine apply_earth_orbit_group(state, cam, bodies, focus_index, overlay)
        type(demo_state_t), intent(in) :: state
        type(camera_t), intent(inout) :: cam
        type(body_t), intent(in) :: bodies(:)
        integer, intent(out) :: focus_index
        type(demo_overlay_t), intent(out) :: overlay
        real(c_float) :: earth(3), sun(3), t, phase
        real(c_float) :: axis_x(3), axis_y(3), axis_z(3)
        real(c_float) :: focus_pos(3), eye_pos(3), look_ahead(3)
        real(c_float) :: orbit_radius, lateral_amp, vertical_amp
        integer :: selected

        earth = body_position_au(bodies, BODY_EARTH)
        sun = body_position_au(bodies, BODY_SUN)
        t = wrapped_phase(state)
        selected = state%demo_id - DEMO_ID_EARTH_ORBIT_AAMON + 1

        call clear_overlay(overlay)

        axis_x = earth - sun
        if (norm3(axis_x) < 1.0e-5_c_float) axis_x = [1.0_c_float, 0.0_c_float, 0.0_c_float]
        call normalize3(axis_x)
        axis_z = [0.0_c_float, 0.0_c_float, 1.0_c_float]
        axis_y = cross3(axis_z, axis_x)
        if (norm3(axis_y) < 1.0e-5_c_float) axis_y = [0.0_c_float, 1.0_c_float, 0.0_c_float]
        call normalize3(axis_y)

        select case (selected)
        case (1)
            phase = t
            orbit_radius = 0.18_c_float
            lateral_amp = 0.03_c_float
            vertical_amp = 0.015_c_float
        case (2)
            phase = modulo(1.35_c_float * t + 0.17_c_float, 1.0_c_float)
            orbit_radius = 0.23_c_float
            lateral_amp = 0.06_c_float
            vertical_amp = 0.022_c_float
        case (3)
            phase = modulo(0.82_c_float * t + 0.31_c_float, 1.0_c_float)
            orbit_radius = 0.28_c_float
            lateral_amp = 0.04_c_float
            vertical_amp = 0.030_c_float
        case default
            phase = modulo(1.12_c_float * t + 0.52_c_float, 1.0_c_float)
            orbit_radius = 0.34_c_float
            lateral_amp = 0.08_c_float
            vertical_amp = 0.040_c_float
        end select

        eye_pos = earth_camera_path(earth, axis_x, axis_y, axis_z, orbit_radius, lateral_amp, vertical_amp, phase)
        look_ahead = earth_camera_path(earth, axis_x, axis_y, axis_z, &
                                       orbit_radius, lateral_amp, vertical_amp, &
                                       modulo(phase + 0.025_c_float, 1.0_c_float))
        focus_pos = lerp3(earth, look_ahead, 0.25_c_float)
        call set_camera_focus(cam, focus_pos)
        cam%eye = eye_pos
        cam%view_up = axis_z
        cam%eye_override = .true.
        focus_index = BODY_EARTH
    end subroutine apply_earth_orbit_group

    subroutine apply_earth_mars_figure_eight(state, cam, bodies, focus_index, overlay)
        type(demo_state_t), intent(in) :: state
        type(camera_t), intent(inout) :: cam
        type(body_t), intent(in) :: bodies(:)
        integer, intent(out) :: focus_index
        type(demo_overlay_t), intent(out) :: overlay
        real(c_float) :: earth(3), mars(3), center(3), t
        real(c_float) :: axis_x(3), axis_y(3), axis_z(3), d
        real(c_float) :: path_now(3), path_ahead(3), look_target(3), guide_target(3)
        real(c_float) :: earth_pull, mars_pull, pull_mix, de, dm

        earth = body_position_au(bodies, BODY_EARTH)
        mars = body_position_au(bodies, BODY_MARS)
        center = 0.5_c_float * (earth + mars)
        axis_x = mars - earth
        d = norm3(axis_x)
        if (d < 1.0e-5_c_float) axis_x = [1.0_c_float, 0.0_c_float, 0.0_c_float]
        call normalize3(axis_x)
        axis_z = [0.0_c_float, 0.0_c_float, 1.0_c_float]
        axis_y = cross3(axis_x, axis_z)
        if (norm3(axis_y) < 1.0e-5_c_float) axis_y = [0.0_c_float, 1.0_c_float, 0.0_c_float]
        call normalize3(axis_y)

        t = wrapped_phase(state)
        path_now = figure_eight_camera_pos(center, axis_x, axis_y, axis_z, d, t)
        path_ahead = figure_eight_camera_pos(center, axis_x, axis_y, axis_z, d, &
                                             modulo(t + 0.03_c_float, 1.0_c_float))

        call clear_overlay(overlay)
        call set_camera_focus(cam, center)
        de = norm3(path_now - earth)
        dm = norm3(path_now - mars)
        earth_pull = smoothstep(clamp01(1.0_c_float - de / max(0.45_c_float * d, 1.0e-5_c_float)))
        mars_pull = smoothstep(clamp01(1.0_c_float - dm / max(0.45_c_float * d, 1.0e-5_c_float)))

        guide_target = lerp3(center, path_ahead, 0.22_c_float)
        if (earth_pull >= mars_pull) then
            pull_mix = 0.85_c_float * earth_pull
            look_target = lerp3(guide_target, earth, pull_mix)
        else
            pull_mix = 0.85_c_float * mars_pull
            look_target = lerp3(guide_target, mars, pull_mix)
        end if

        cam%focus = look_target
        cam%focus_target = look_target
        cam%focus_start = look_target
        cam%focus_progress = 1.0_c_float
        cam%eye = path_now
        cam%view_up = axis_z
        cam%eye_override = .true.
        focus_index = BODY_EARTH
    end subroutine apply_earth_mars_figure_eight

    subroutine apply_earth_mars_trip(state, cam, bodies, focus_index, overlay)
        type(demo_state_t), intent(in) :: state
        type(camera_t), intent(inout) :: cam
        type(body_t), intent(in) :: bodies(:)
        integer, intent(out) :: focus_index
        type(demo_overlay_t), intent(out) :: overlay
        real(c_float) :: earth(3), mars(3), center(3), t, trip_t
        real(c_float) :: axis_x(3), axis_y(3), axis_z(3), span
        real(c_float) :: eye_pos(3), look_target(3), offset_side, offset_up

        earth = body_position_au(bodies, BODY_EARTH)
        mars = body_position_au(bodies, BODY_MARS)
        center = 0.5_c_float * (earth + mars)
        axis_x = mars - earth
        span = norm3(axis_x)
        if (span < 1.0e-5_c_float) axis_x = [1.0_c_float, 0.0_c_float, 0.0_c_float]
        call normalize3(axis_x)
        axis_z = [0.0_c_float, 0.0_c_float, 1.0_c_float]
        axis_y = cross3(axis_x, axis_z)
        if (norm3(axis_y) < 1.0e-5_c_float) axis_y = [0.0_c_float, 1.0_c_float, 0.0_c_float]
        call normalize3(axis_y)

        t = wrapped_phase(state)
        trip_t = smoothstep(t)
        offset_side = 0.10_c_float * span * sin(real(PI, c_float) * trip_t)
        offset_up = 0.05_c_float * span * sin(real(PI, c_float) * trip_t)
        eye_pos = lerp3(earth - 0.10_c_float * span * axis_x + 0.03_c_float * span * axis_y, &
                        mars + 0.12_c_float * span * axis_x - 0.02_c_float * span * axis_y, &
                        trip_t) + offset_side * axis_y + offset_up * axis_z

        if (trip_t < 0.22_c_float) then
            look_target = lerp3(earth, center, trip_t / 0.22_c_float)
        else if (trip_t > 0.76_c_float) then
            look_target = lerp3(center, mars, (trip_t - 0.76_c_float) / 0.24_c_float)
        else
            look_target = lerp3(center, mars, 0.20_c_float * smoothstep((trip_t - 0.22_c_float) / 0.54_c_float))
        end if

        call clear_overlay(overlay)
        call set_camera_focus(cam, look_target)
        cam%eye = eye_pos
        cam%view_up = axis_z
        cam%eye_override = .true.
        focus_index = BODY_MARS
    end subroutine apply_earth_mars_trip

    subroutine apply_mars_orbit_survey(state, cam, bodies, focus_index, overlay)
        type(demo_state_t), intent(in) :: state
        type(camera_t), intent(inout) :: cam
        type(body_t), intent(in) :: bodies(:)
        integer, intent(out) :: focus_index
        type(demo_overlay_t), intent(out) :: overlay
        real(c_float) :: sun(3), mars(3), t
        real(c_float) :: axis_x(3), axis_y(3), axis_z(3)
        real(c_float) :: eye_pos(3), look_target(3), orbit_radius

        sun = body_position_au(bodies, BODY_SUN)
        mars = body_position_au(bodies, BODY_MARS)
        axis_x = mars - sun
        if (norm3(axis_x) < 1.0e-5_c_float) axis_x = [1.0_c_float, 0.0_c_float, 0.0_c_float]
        call normalize3(axis_x)
        axis_z = [0.0_c_float, 0.0_c_float, 1.0_c_float]
        axis_y = cross3(axis_z, axis_x)
        if (norm3(axis_y) < 1.0e-5_c_float) axis_y = [0.0_c_float, 1.0_c_float, 0.0_c_float]
        call normalize3(axis_y)

        t = wrapped_phase(state)
        orbit_radius = 0.22_c_float + 0.04_c_float * sin(TWO_PI() * t)
        eye_pos = mars + orbit_radius * cos(TWO_PI() * t) * axis_x + &
                  (orbit_radius + 0.03_c_float * sin(2.0_c_float * TWO_PI() * t)) * sin(TWO_PI() * t) * axis_y + &
                  0.04_c_float * sin(2.0_c_float * TWO_PI() * t) * axis_z
        look_target = lerp3(mars, sun, 0.04_c_float)

        call clear_overlay(overlay)
        call set_camera_focus(cam, look_target)
        cam%eye = eye_pos
        cam%view_up = axis_z
        cam%eye_override = .true.
        focus_index = BODY_MARS
    end subroutine apply_mars_orbit_survey

    subroutine apply_inner_worlds_tour(state, cam, bodies, focus_index, overlay)
        type(demo_state_t), intent(in) :: state
        type(camera_t), intent(inout) :: cam
        type(body_t), intent(in) :: bodies(:)
        integer, intent(out) :: focus_index
        type(demo_overlay_t), intent(out) :: overlay
        real(c_float) :: t, phase_t
        real(c_float) :: sun(3), mercury(3), venus(3), earth(3), mars(3)
        real(c_float) :: from_body(3), to_body(3), axis_x(3), axis_y(3), axis_z(3), span
        real(c_float) :: eye_pos(3), look_target(3)
        integer :: segment

        sun = body_position_au(bodies, BODY_SUN)
        mercury = body_position_au(bodies, BODY_MERCURY)
        venus = body_position_au(bodies, BODY_VENUS)
        earth = body_position_au(bodies, BODY_EARTH)
        mars = body_position_au(bodies, BODY_MARS)

        t = wrapped_phase(state)
        segment = min(int(4.0_c_float * t), 3)
        phase_t = smoothstep(modulo(4.0_c_float * t, 1.0_c_float))

        select case (segment)
        case (0)
            from_body = mercury
            to_body = venus
            focus_index = BODY_VENUS
        case (1)
            from_body = venus
            to_body = earth
            focus_index = BODY_EARTH
        case (2)
            from_body = earth
            to_body = mars
            focus_index = BODY_MARS
        case default
            from_body = mars
            to_body = mercury
            focus_index = BODY_MERCURY
        end select

        axis_x = to_body - from_body
        span = norm3(axis_x)
        if (span < 1.0e-5_c_float) axis_x = [1.0_c_float, 0.0_c_float, 0.0_c_float]
        call normalize3(axis_x)
        axis_z = [0.0_c_float, 0.0_c_float, 1.0_c_float]
        axis_y = cross3(axis_x, axis_z)
        if (norm3(axis_y) < 1.0e-5_c_float) axis_y = [0.0_c_float, 1.0_c_float, 0.0_c_float]
        call normalize3(axis_y)

        eye_pos = lerp3(from_body, to_body, phase_t) - 0.14_c_float * span * axis_x + &
                  0.08_c_float * span * sin(real(PI, c_float) * phase_t) * axis_y + &
                  0.05_c_float * span * sin(real(PI, c_float) * phase_t) * axis_z
        look_target = lerp3(lerp3(from_body, sun, 0.06_c_float), to_body, 0.35_c_float + 0.55_c_float * phase_t)

        call clear_overlay(overlay)
        call set_camera_focus(cam, look_target)
        cam%eye = eye_pos
        cam%view_up = axis_z
        cam%eye_override = .true.
    end subroutine apply_inner_worlds_tour

    subroutine clear_overlay(overlay)
        type(demo_overlay_t), intent(out) :: overlay
        integer :: i

        overlay%count = 0
        do i = 1, MAX_DEMO_BODIES
            overlay%bodies(i)%name = ""
            overlay%bodies(i)%mass = 0.0d0
            overlay%bodies(i)%radius = 0.0d0
            overlay%bodies(i)%position = zero_vec3
            overlay%bodies(i)%velocity = zero_vec3
            overlay%bodies(i)%acceleration = zero_vec3
            overlay%bodies(i)%color = [1.0, 1.0, 1.0]
        end do
    end subroutine clear_overlay

    subroutine set_camera_focus(cam, focus)
        type(camera_t), intent(inout) :: cam
        real(c_float), intent(in) :: focus(3)
        cam%focus = focus
        cam%focus_target = focus
        cam%focus_start = focus
        cam%focus_progress = 1.0_c_float
    end subroutine set_camera_focus

    pure function body_position_au(bodies, focus_index) result(pos)
        type(body_t), intent(in) :: bodies(:)
        integer, intent(in) :: focus_index
        real(c_float) :: pos(3)
        integer :: body_idx

        body_idx = min(max(focus_index + 1, 1), size(bodies))
        pos(1) = real(bodies(body_idx)%position%x / AU, c_float)
        pos(2) = real(bodies(body_idx)%position%y / AU, c_float)
        pos(3) = real(bodies(body_idx)%position%z / AU, c_float)
    end function body_position_au

    pure function earth_camera_path(earth, axis_x, axis_y, axis_z, orbit_radius, lateral_amp, vertical_amp, t) result(pos)
        real(c_float), intent(in) :: earth(3), axis_x(3), axis_y(3), axis_z(3)
        real(c_float), intent(in) :: orbit_radius, lateral_amp, vertical_amp, t
        real(c_float) :: pos(3), theta

        theta = TWO_PI() * t
        pos = earth + orbit_radius * cos(theta) * axis_x + &
              (orbit_radius + lateral_amp * sin(2.0_c_float * theta)) * sin(theta) * axis_y + &
              vertical_amp * sin(2.0_c_float * theta) * axis_z
    end function earth_camera_path

    pure function figure_eight_camera_pos(center, axis_x, axis_y, axis_z, span, t) result(pos)
        real(c_float), intent(in) :: center(3), axis_x(3), axis_y(3), axis_z(3), span, t
        real(c_float) :: pos(3), theta

        theta = TWO_PI() * t
        pos = center + 0.52_c_float * span * sin(theta) * axis_x + &
              0.30_c_float * span * sin(theta) * cos(theta) * axis_y + &
              0.08_c_float * span * (0.5_c_float + 0.5_c_float * cos(theta)) * axis_z
    end function figure_eight_camera_pos

    pure function wrapped_phase(state) result(t)
        type(demo_state_t), intent(in) :: state
        real(c_float) :: t
        if (state%duration <= 0.0_c_float) then
            t = 0.0_c_float
        else
            t = modulo(state%timeline / state%duration, 1.0_c_float)
        end if
    end function wrapped_phase

    pure function clamp_demo_id(demo_id) result(clamped)
        integer, intent(in) :: demo_id
        integer :: clamped
        clamped = min(max(demo_id, 1), DEMO_COUNT)
    end function clamp_demo_id

    pure function demo_duration_for(demo_id) result(duration)
        integer, intent(in) :: demo_id
        real(c_float) :: duration

        select case (clamp_demo_id(demo_id))
        case (DEMO_ID_SHOWCASE)
            duration = 40.0_c_float
        case (DEMO_ID_EARTH_ORBIT_AAMON, DEMO_ID_EARTH_ORBIT_BARBATOS, &
              DEMO_ID_EARTH_ORBIT_CROCELL, DEMO_ID_EARTH_ORBIT_DANTALION, &
              DEMO_ID_EARTH_MARS_FIGURE_EIGHT)
            duration = 40.0_c_float
        case (DEMO_ID_EARTH_MARS_TRIP)
            duration = 90.0_c_float
        case (DEMO_ID_MARS_ORBIT_SURVEY)
            duration = 60.0_c_float
        case (DEMO_ID_INNER_WORLDS_TOUR)
            duration = 75.0_c_float
        case default
            duration = DEMO_DURATION_SECONDS
        end select
    end function demo_duration_for

    pure function mix(a, b, t) result(v)
        real(c_float), intent(in) :: a, b, t
        real(c_float) :: v
        v = a + (b - a) * t
    end function mix

    pure function lerp3(a, b, t) result(v)
        real(c_float), intent(in) :: a(3), b(3), t
        real(c_float) :: v(3)
        v = a + (b - a) * t
    end function lerp3

    pure function smoothstep(x) result(y)
        real(c_float), intent(in) :: x
        real(c_float) :: y, xc
        xc = min(max(x, 0.0_c_float), 1.0_c_float)
        y = xc * xc * (3.0_c_float - 2.0_c_float * xc)
    end function smoothstep

    pure function clamp01(x) result(y)
        real(c_float), intent(in) :: x
        real(c_float) :: y
        y = min(max(x, 0.0_c_float), 1.0_c_float)
    end function clamp01

    pure function norm3(v) result(n)
        real(c_float), intent(in) :: v(3)
        real(c_float) :: n
        n = sqrt(sum(v * v))
    end function norm3

    pure function cross3(a, b) result(c)
        real(c_float), intent(in) :: a(3), b(3)
        real(c_float) :: c(3)
        c = [a(2) * b(3) - a(3) * b(2), &
             a(3) * b(1) - a(1) * b(3), &
             a(1) * b(2) - a(2) * b(1)]
    end function cross3

    subroutine normalize3(v)
        real(c_float), intent(inout) :: v(3)
        real(c_float) :: n
        n = norm3(v)
        if (n > 1.0e-6_c_float) v = v / n
    end subroutine normalize3

    pure function TWO_PI() result(v)
        real(c_float) :: v
        v = 2.0_c_float * real(PI, c_float)
    end function TWO_PI

end module demo_mod
