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
    public :: demo_advance, demo_name, demo_slug, demo_is_showcase, demo_resolve_id
    public :: DEMO_DURATION_SECONDS, DEMO_CAPTURE_FPS, DEMO_COUNT
    public :: DEMO_ID_SHOWCASE, DEMO_ID_EARTH_ORBIT_AAMON
    public :: DEMO_ID_EARTH_ORBIT_BARBATOS, DEMO_ID_EARTH_ORBIT_CROCELL
    public :: DEMO_ID_EARTH_ORBIT_DANTALION, DEMO_ID_EARTH_MARS_FIGURE_EIGHT
    public :: DEMO_ID_EARTH_MARS_TRIP, DEMO_ID_MARS_ORBIT_SURVEY, DEMO_ID_INNER_WORLDS_TOUR
    public :: DEMO_ID_EARTH_CONVOY, DEMO_ID_VOYAGER_SURVEY, DEMO_ID_ENTERPRISE_BLUE
    public :: DEMO_ID_MARS_CONVOY, DEMO_ID_INNER_WORLDS_SPRINT, DEMO_ID_SOLAR_CROWN
    public :: DEMO_ID_VOYAGER_JOURNEY
    public :: MAX_DEMO_BODIES, MAX_DEMO_SHIPS

    real(c_float), parameter :: DEMO_DURATION_SECONDS = 40.0_c_float
    integer, parameter :: DEMO_CAPTURE_FPS = 30
    integer, parameter :: DEMO_SHOT_COUNT = 9
    integer, parameter :: DEMO_COUNT = 16
    integer, parameter :: MAX_DEMO_BODIES = 4
    integer, parameter :: MAX_DEMO_SHIPS = 4

    integer, parameter :: BODY_SUN = 0
    integer, parameter :: BODY_MERCURY = 1
    integer, parameter :: BODY_VENUS = 2
    integer, parameter :: BODY_EARTH = 3
    integer, parameter :: BODY_MARS = 4
    integer, parameter :: BODY_JUPITER = 5
    integer, parameter :: BODY_SATURN = 6
    integer, parameter :: SHIP_VOYAGER1 = 1
    integer, parameter :: SHIP_VOYAGER_NCC = 2
    integer, parameter :: SHIP_ENTERPRISE = 3

    integer, parameter :: DEMO_ID_SHOWCASE = 1
    integer, parameter :: DEMO_ID_EARTH_ORBIT_AAMON = 2
    integer, parameter :: DEMO_ID_EARTH_ORBIT_BARBATOS = 3
    integer, parameter :: DEMO_ID_EARTH_ORBIT_CROCELL = 4
    integer, parameter :: DEMO_ID_EARTH_ORBIT_DANTALION = 5
    integer, parameter :: DEMO_ID_EARTH_MARS_FIGURE_EIGHT = 6
    integer, parameter :: DEMO_ID_EARTH_MARS_TRIP = 7
    integer, parameter :: DEMO_ID_MARS_ORBIT_SURVEY = 8
    integer, parameter :: DEMO_ID_INNER_WORLDS_TOUR = 9
    integer, parameter :: DEMO_ID_EARTH_CONVOY = 10
    integer, parameter :: DEMO_ID_VOYAGER_SURVEY = 11
    integer, parameter :: DEMO_ID_ENTERPRISE_BLUE = 12
    integer, parameter :: DEMO_ID_MARS_CONVOY = 13
    integer, parameter :: DEMO_ID_INNER_WORLDS_SPRINT = 14
    integer, parameter :: DEMO_ID_SOLAR_CROWN = 15
    integer, parameter :: DEMO_ID_VOYAGER_JOURNEY = 16

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

    type :: demo_ship_pose_t
        integer :: craft_index = 0
        real(c_float) :: world_pos_au(3) = 0.0_c_float
        real(c_float) :: yaw = 0.0_c_float
        real(c_float) :: pitch = 0.0_c_float
        real(c_float) :: roll = 0.0_c_float
        real(c_float) :: scale_mul = 1.0_c_float
    end type demo_ship_pose_t

    type, public :: demo_overlay_t
        integer :: count = 0
        type(body_t) :: bodies(MAX_DEMO_BODIES)
        integer :: ship_count = 0
        type(demo_ship_pose_t) :: ships(MAX_DEMO_SHIPS)
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

    character(len=32), parameter :: DEMO_NAMES(DEMO_COUNT) = [ character(len=32) :: &
        "Existing Demo", &
        "Earth Orbit: Aamon", &
        "Earth Orbit: Barbatos", &
        "Earth Orbit: Crocell", &
        "Earth Orbit: Dantalion", &
        "Earth <-> Mars Figure-8", &
        "Earth -> Mars Trip", &
        "Mars Orbit Survey", &
        "Inner Worlds Tour", &
        "Cinematic: Earth Convoy", &
        "Cinematic: Voyager Survey", &
        "Cinematic: Enterprise Blue", &
        "Cinematic: Mars Convoy", &
        "Cinematic: Inner Worlds Sprint", &
        "Cinematic: Solar Crown", &
        "Cinematic: Voyager Journey" ]

    character(len=32), parameter :: DEMO_SLUGS(DEMO_COUNT) = [ character(len=32) :: &
        "existing_demo", &
        "earth_orbit_aamon", &
        "earth_orbit_barbatos", &
        "earth_orbit_crocell", &
        "earth_orbit_dantalion", &
        "earth_mars_figure8", &
        "earth_mars_trip", &
        "mars_orbit_survey", &
        "inner_worlds_tour", &
        "earth_convoy", &
        "voyager_survey", &
        "enterprise_blue", &
        "mars_convoy", &
        "inner_worlds_sprint", &
        "solar_crown", &
        "voyager_journey" ]

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
        case (DEMO_ID_EARTH_CONVOY)
            call apply_earth_convoy(state, cam, bodies, focus_index, overlay)
        case (DEMO_ID_VOYAGER_SURVEY)
            call apply_voyager_survey(state, cam, bodies, focus_index, overlay)
        case (DEMO_ID_ENTERPRISE_BLUE)
            call apply_enterprise_blue(state, cam, bodies, focus_index, overlay)
        case (DEMO_ID_MARS_CONVOY)
            call apply_mars_convoy(state, cam, bodies, focus_index, overlay)
        case (DEMO_ID_INNER_WORLDS_SPRINT)
            call apply_inner_worlds_sprint(state, cam, bodies, focus_index, overlay)
        case (DEMO_ID_SOLAR_CROWN)
            call apply_solar_crown(state, cam, bodies, focus_index, overlay)
        case (DEMO_ID_VOYAGER_JOURNEY)
            call apply_voyager_journey(state, cam, bodies, focus_index, overlay)
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
        character(len=32) :: name
        name = DEMO_NAMES(clamp_demo_id(demo_id))
    end function demo_name

    pure function demo_slug(demo_id) result(slug)
        integer, intent(in) :: demo_id
        character(len=32) :: slug
        slug = DEMO_SLUGS(clamp_demo_id(demo_id))
    end function demo_slug

    pure logical function demo_is_showcase(demo_id)
        integer, intent(in) :: demo_id
        demo_is_showcase = clamp_demo_id(demo_id) == DEMO_ID_SHOWCASE
    end function demo_is_showcase

    integer function demo_resolve_id(spec) result(demo_id)
        character(len=*), intent(in) :: spec
        integer :: i, ios, parsed
        character(len=64) :: folded

        demo_id = DEMO_ID_SHOWCASE
        folded = to_lower_ascii(adjustl(trim(spec)))
        read(folded, *, iostat=ios) parsed
        if (ios == 0) then
            demo_id = clamp_demo_id(parsed)
            return
        end if

        do i = 1, DEMO_COUNT
            if (trim(folded) == trim(to_lower_ascii(DEMO_SLUGS(i)))) then
                demo_id = i
                return
            end if
        end do
        do i = 1, DEMO_COUNT
            if (trim(folded) == trim(to_lower_ascii(DEMO_NAMES(i)))) then
                demo_id = i
                return
            end if
        end do
    end function demo_resolve_id

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

    subroutine apply_earth_convoy(state, cam, bodies, focus_index, overlay)
        type(demo_state_t), intent(in) :: state
        type(camera_t), intent(inout) :: cam
        type(body_t), intent(in) :: bodies(:)
        integer, intent(out) :: focus_index
        type(demo_overlay_t), intent(inout) :: overlay
        real(c_float) :: earth(3), sun(3), axis_x(3), axis_y(3), axis_z(3)
        real(c_float) :: lead(3), lead_next(3), wing1(3), wing1_next(3), wing2(3), wing2_next(3)
        real(c_float) :: forward(3), eye_pos(3), look_target(3), t

        earth = body_position_au(bodies, BODY_EARTH)
        sun = body_position_au(bodies, BODY_SUN)
        call basis_from_reference(earth, sun, axis_x, axis_y, axis_z)
        t = wrapped_phase(state)

        lead = orbit_path(earth, axis_x, axis_y, axis_z, 0.115_c_float, 0.055_c_float, 0.018_c_float, t + 0.08_c_float)
        lead_next = orbit_path(earth, axis_x, axis_y, axis_z, 0.115_c_float, 0.055_c_float, 0.018_c_float, t + 0.09_c_float)
        wing1 = orbit_path(earth, axis_x, axis_y, axis_z, 0.132_c_float, 0.048_c_float, 0.014_c_float, t - 0.10_c_float)
        wing1_next = orbit_path(earth, axis_x, axis_y, axis_z, 0.132_c_float, 0.048_c_float, 0.014_c_float, t - 0.09_c_float)
        wing2 = orbit_path(earth, axis_x, axis_y, axis_z, 0.148_c_float, 0.064_c_float, 0.016_c_float, t + 0.22_c_float)
        wing2_next = orbit_path(earth, axis_x, axis_y, axis_z, 0.148_c_float, 0.064_c_float, 0.016_c_float, t + 0.23_c_float)

        forward = direction_from_points(lead, lead_next, axis_y)
        eye_pos = lead - 0.020_c_float * forward - 0.018_c_float * axis_y + 0.010_c_float * axis_z + &
                  0.006_c_float * sin(TWO_PI() * t) * axis_x
        look_target = lerp3(lead, earth, 0.18_c_float)

        call set_camera_focus(cam, look_target)
        cam%eye = eye_pos
        cam%view_up = axis_z
        cam%eye_override = .true.
        focus_index = BODY_EARTH

        call stage_ship_from_path(overlay, SHIP_VOYAGER1, lead, lead_next, 0.0015_c_float, 0.00_c_float)
        call stage_ship_from_path(overlay, SHIP_VOYAGER_NCC, wing1, wing1_next, 0.0012_c_float, -0.08_c_float)
        call stage_ship_from_path(overlay, SHIP_ENTERPRISE, wing2, wing2_next, 0.0010_c_float, 0.06_c_float)
    end subroutine apply_earth_convoy

    subroutine apply_voyager_survey(state, cam, bodies, focus_index, overlay)
        type(demo_state_t), intent(in) :: state
        type(camera_t), intent(inout) :: cam
        type(body_t), intent(in) :: bodies(:)
        integer, intent(out) :: focus_index
        type(demo_overlay_t), intent(inout) :: overlay
        real(c_float) :: earth(3), sun(3), axis_x(3), axis_y(3), axis_z(3)
        real(c_float) :: ship(3), ship_next(3), eye_pos(3), look_target(3), ship_dir(3), orbit_t

        earth = body_position_au(bodies, BODY_EARTH)
        sun = body_position_au(bodies, BODY_SUN)
        call basis_from_reference(earth, sun, axis_x, axis_y, axis_z)
        orbit_t = wrapped_phase(state)

        ship = earth + 0.082_c_float * axis_x + 0.030_c_float * sin(TWO_PI() * orbit_t) * axis_y + &
               0.012_c_float * sin(2.0_c_float * TWO_PI() * orbit_t) * axis_z
        ship_next = earth + 0.082_c_float * axis_x + 0.030_c_float * sin(TWO_PI() * (orbit_t + 0.01_c_float)) * axis_y + &
                    0.012_c_float * sin(2.0_c_float * TWO_PI() * (orbit_t + 0.01_c_float)) * axis_z
        ship_dir = direction_from_points(ship, ship_next, axis_x)

        eye_pos = ship - 0.010_c_float * ship_dir + &
                  0.016_c_float * cos(TWO_PI() * 0.62_c_float * orbit_t + 0.65_c_float) * axis_y + &
                  0.011_c_float * sin(TWO_PI() * 0.62_c_float * orbit_t + 0.65_c_float) * axis_z
        look_target = lerp3(ship, earth, 0.10_c_float)

        call set_camera_focus(cam, look_target)
        cam%eye = eye_pos
        cam%view_up = axis_z
        cam%eye_override = .true.
        focus_index = BODY_EARTH

        call stage_ship_from_path(overlay, SHIP_VOYAGER1, ship, ship_next, 0.0014_c_float, 0.03_c_float)
    end subroutine apply_voyager_survey

    subroutine apply_voyager_journey(state, cam, bodies, focus_index, overlay)
        type(demo_state_t), intent(in) :: state
        type(camera_t), intent(inout) :: cam
        type(body_t), intent(in) :: bodies(:)
        integer, intent(out) :: focus_index
        type(demo_overlay_t), intent(inout) :: overlay
        real(c_float) :: earth(3), jupiter(3), saturn(3), sun(3)
        real(c_float) :: voyage_x(3), voyage_y(3), voyage_z(3)
        real(c_float) :: ship(3), ship_next(3), eye_pos(3), look_target(3), ship_dir(3)
        real(c_float) :: depart_axis(3), arc_t, t, seg_t

        sun = body_position_au(bodies, BODY_SUN)
        earth = body_position_au(bodies, BODY_EARTH)
        jupiter = body_position_au(bodies, BODY_JUPITER)
        saturn = body_position_au(bodies, BODY_SATURN)
        t = wrapped_phase(state)

        depart_axis = jupiter - earth
        if (norm3(depart_axis) < 1.0e-5_c_float) depart_axis = earth - sun
        call basis_from_reference(earth + depart_axis, earth, voyage_x, voyage_y, voyage_z)

        if (t < 0.26_c_float) then
            seg_t = smoothstep(t / 0.26_c_float)
            ship = earth + mix(0.08_c_float, 0.58_c_float, seg_t) * voyage_x + &
                   0.08_c_float * sin(real(PI, c_float) * seg_t) * voyage_y + &
                   0.03_c_float * sin(real(PI, c_float) * seg_t) * voyage_z
            ship_next = earth + mix(0.08_c_float, 0.58_c_float, min(seg_t + 0.03_c_float, 1.0_c_float)) * voyage_x + &
                        0.08_c_float * sin(real(PI, c_float) * min(seg_t + 0.03_c_float, 1.0_c_float)) * voyage_y + &
                        0.03_c_float * sin(real(PI, c_float) * min(seg_t + 0.03_c_float, 1.0_c_float)) * voyage_z
            ship_dir = direction_from_points(ship, ship_next, voyage_x)
            eye_pos = ship - 0.012_c_float * ship_dir - 0.020_c_float * voyage_y + 0.010_c_float * voyage_z
            look_target = lerp3(ship, earth, 0.06_c_float)
            focus_index = BODY_EARTH
        else if (t < 0.52_c_float) then
            seg_t = smoothstep((t - 0.26_c_float) / 0.26_c_float)
            call basis_from_reference(jupiter, sun, voyage_x, voyage_y, voyage_z)
            arc_t = 0.60_c_float + 0.24_c_float * seg_t
            ship = orbit_path(jupiter, voyage_x, voyage_y, voyage_z, 0.45_c_float, 0.30_c_float, 0.08_c_float, arc_t)
            ship_next = orbit_path(jupiter, voyage_x, voyage_y, voyage_z, 0.45_c_float, 0.30_c_float, 0.08_c_float, &
                                   min(arc_t + 0.012_c_float, 1.0_c_float))
            ship_dir = direction_from_points(ship, ship_next, voyage_y)
            eye_pos = ship - 0.014_c_float * ship_dir - 0.026_c_float * voyage_y + 0.012_c_float * voyage_z
            look_target = lerp3(ship, jupiter, 0.10_c_float)
            focus_index = BODY_JUPITER
        else if (t < 0.78_c_float) then
            seg_t = smoothstep((t - 0.52_c_float) / 0.26_c_float)
            call basis_from_reference(saturn, sun, voyage_x, voyage_y, voyage_z)
            arc_t = 0.18_c_float + 0.22_c_float * seg_t
            ship = orbit_path(saturn, voyage_x, voyage_y, voyage_z, 0.68_c_float, 0.44_c_float, 0.10_c_float, arc_t)
            ship_next = orbit_path(saturn, voyage_x, voyage_y, voyage_z, 0.68_c_float, 0.44_c_float, 0.10_c_float, &
                                   min(arc_t + 0.010_c_float, 1.0_c_float))
            ship_dir = direction_from_points(ship, ship_next, voyage_y)
            eye_pos = ship - 0.015_c_float * ship_dir - 0.028_c_float * voyage_y + 0.014_c_float * voyage_z
            look_target = lerp3(ship, saturn, 0.12_c_float)
            focus_index = BODY_SATURN
        else
            seg_t = smoothstep((t - 0.78_c_float) / 0.22_c_float)
            call basis_from_reference(saturn, sun, voyage_x, voyage_y, voyage_z)
            ship = saturn + mix(1.2_c_float, 132.0_c_float, seg_t) * voyage_x + &
                   mix(0.1_c_float, 10.0_c_float, seg_t) * voyage_y + &
                   mix(0.1_c_float, 18.0_c_float, seg_t) * voyage_z
            ship_next = saturn + mix(1.2_c_float, 132.0_c_float, min(seg_t + 0.02_c_float, 1.0_c_float)) * voyage_x + &
                        mix(0.1_c_float, 10.0_c_float, min(seg_t + 0.02_c_float, 1.0_c_float)) * voyage_y + &
                        mix(0.1_c_float, 18.0_c_float, min(seg_t + 0.02_c_float, 1.0_c_float)) * voyage_z
            ship_dir = direction_from_points(ship, ship_next, voyage_x)
            eye_pos = ship - 0.016_c_float * ship_dir - 0.024_c_float * voyage_y + 0.013_c_float * voyage_z
            look_target = ship + 0.018_c_float * ship_dir
            focus_index = BODY_SUN
        end if

        call set_camera_focus(cam, look_target)
        cam%eye = eye_pos
        cam%view_up = voyage_z
        cam%eye_override = .true.

        call stage_ship_from_path(overlay, SHIP_VOYAGER1, ship, ship_next, 0.0018_c_float, 0.02_c_float)
    end subroutine apply_voyager_journey

    subroutine apply_enterprise_blue(state, cam, bodies, focus_index, overlay)
        type(demo_state_t), intent(in) :: state
        type(camera_t), intent(inout) :: cam
        type(body_t), intent(in) :: bodies(:)
        integer, intent(out) :: focus_index
        type(demo_overlay_t), intent(inout) :: overlay
        real(c_float) :: earth(3), sun(3), axis_x(3), axis_y(3), axis_z(3)
        real(c_float) :: ship(3), ship_next(3), eye_pos(3), look_target(3), ship_dir(3), t

        earth = body_position_au(bodies, BODY_EARTH)
        sun = body_position_au(bodies, BODY_SUN)
        call basis_from_reference(earth, sun, axis_x, axis_y, axis_z)
        t = wrapped_phase(state)

        ship = earth + 0.030_c_float * axis_x + 0.022_c_float * cos(TWO_PI() * t + 0.35_c_float) * axis_y + &
               0.010_c_float * sin(TWO_PI() * t + 0.35_c_float) * axis_z
        ship_next = earth + 0.030_c_float * axis_x + 0.022_c_float * cos(TWO_PI() * (t + 0.01_c_float) + 0.35_c_float) * axis_y + &
                    0.010_c_float * sin(TWO_PI() * (t + 0.01_c_float) + 0.35_c_float) * axis_z
        ship_dir = direction_from_points(ship, ship_next, axis_y)

        eye_pos = ship - 0.008_c_float * ship_dir + 0.004_c_float * axis_x + &
                  0.015_c_float * cos(TWO_PI() * 0.78_c_float * t + 0.8_c_float) * axis_y + &
                  0.011_c_float * sin(TWO_PI() * 0.78_c_float * t + 0.8_c_float) * axis_z
        look_target = lerp3(ship, earth, 0.16_c_float)

        call set_camera_focus(cam, look_target)
        cam%eye = eye_pos
        cam%view_up = axis_z
        cam%eye_override = .true.
        focus_index = BODY_EARTH

        call stage_ship_from_path(overlay, SHIP_ENTERPRISE, ship, ship_next, 0.0009_c_float, -0.04_c_float)
    end subroutine apply_enterprise_blue

    subroutine apply_mars_convoy(state, cam, bodies, focus_index, overlay)
        type(demo_state_t), intent(in) :: state
        type(camera_t), intent(inout) :: cam
        type(body_t), intent(in) :: bodies(:)
        integer, intent(out) :: focus_index
        type(demo_overlay_t), intent(inout) :: overlay
        real(c_float) :: mars(3), sun(3), axis_x(3), axis_y(3), axis_z(3)
        real(c_float) :: lead(3), lead_next(3), wing1(3), wing1_next(3), wing2(3), wing2_next(3)
        real(c_float) :: eye_pos(3), look_target(3), t

        mars = body_position_au(bodies, BODY_MARS)
        sun = body_position_au(bodies, BODY_SUN)
        call basis_from_reference(mars, sun, axis_x, axis_y, axis_z)
        t = wrapped_phase(state)

        lead = mars + 0.040_c_float * axis_x + (0.090_c_float * (t - 0.5_c_float)) * axis_y + &
               0.015_c_float * sin(TWO_PI() * t) * axis_z
        lead_next = mars + 0.040_c_float * axis_x + (0.090_c_float * (t - 0.49_c_float)) * axis_y + &
                    0.015_c_float * sin(TWO_PI() * (t + 0.01_c_float)) * axis_z
        wing1 = lead - 0.018_c_float * axis_y + 0.008_c_float * axis_z
        wing1_next = lead_next - 0.018_c_float * axis_y + 0.008_c_float * axis_z
        wing2 = lead + 0.024_c_float * axis_y - 0.006_c_float * axis_z
        wing2_next = lead_next + 0.024_c_float * axis_y - 0.006_c_float * axis_z

        eye_pos = mars + 0.078_c_float * axis_x - 0.032_c_float * axis_y + 0.020_c_float * axis_z + &
                  0.010_c_float * sin(TWO_PI() * t) * axis_y
        look_target = lerp3(lead, mars, 0.30_c_float)

        call set_camera_focus(cam, look_target)
        cam%eye = eye_pos
        cam%view_up = axis_z
        cam%eye_override = .true.
        focus_index = BODY_MARS

        call stage_ship_from_path(overlay, SHIP_VOYAGER_NCC, lead, lead_next, 0.0010_c_float, 0.02_c_float)
        call stage_ship_from_path(overlay, SHIP_VOYAGER1, wing1, wing1_next, 0.0014_c_float, -0.03_c_float)
        call stage_ship_from_path(overlay, SHIP_ENTERPRISE, wing2, wing2_next, 0.0009_c_float, 0.04_c_float)
    end subroutine apply_mars_convoy

    subroutine apply_inner_worlds_sprint(state, cam, bodies, focus_index, overlay)
        type(demo_state_t), intent(in) :: state
        type(camera_t), intent(inout) :: cam
        type(body_t), intent(in) :: bodies(:)
        integer, intent(out) :: focus_index
        type(demo_overlay_t), intent(inout) :: overlay
        real(c_float) :: venus(3), earth(3), mars(3), from_body(3), to_body(3), sun(3)
        real(c_float) :: axis_x(3), axis_y(3), axis_z(3), span, t, seg_t
        real(c_float) :: center(3), lead(3), lead_next(3), wing1(3), wing1_next(3), wing2(3), wing2_next(3)
        real(c_float) :: eye_pos(3), look_target(3)
        integer :: segment

        sun = body_position_au(bodies, BODY_SUN)
        venus = body_position_au(bodies, BODY_VENUS)
        earth = body_position_au(bodies, BODY_EARTH)
        mars = body_position_au(bodies, BODY_MARS)
        t = wrapped_phase(state)
        segment = min(int(3.0_c_float * t), 2)
        seg_t = smoothstep(modulo(3.0_c_float * t, 1.0_c_float))

        select case (segment)
        case (0)
            from_body = venus
            to_body = earth
            focus_index = BODY_EARTH
        case (1)
            from_body = earth
            to_body = mars
            focus_index = BODY_MARS
        case default
            from_body = mars
            to_body = venus
            focus_index = BODY_VENUS
        end select

        axis_x = to_body - from_body
        span = max(norm3(axis_x), 1.0e-4_c_float)
        call normalize3(axis_x)
        axis_z = [0.0_c_float, 0.0_c_float, 1.0_c_float]
        axis_y = cross3(axis_x, axis_z)
        if (norm3(axis_y) < 1.0e-5_c_float) axis_y = [0.0_c_float, 1.0_c_float, 0.0_c_float]
        call normalize3(axis_y)

        center = lerp3(from_body, to_body, seg_t) + 0.050_c_float * span * sin(real(PI, c_float) * seg_t) * axis_y + &
                 0.020_c_float * span * sin(2.0_c_float * TWO_PI() * seg_t) * axis_z
        lead = center + 0.010_c_float * axis_y
        lead_next = lerp3(from_body, to_body, min(seg_t + 0.02_c_float, 1.0_c_float)) + &
                    0.050_c_float * span * sin(real(PI, c_float) * min(seg_t + 0.02_c_float, 1.0_c_float)) * axis_y + &
                    0.020_c_float * span * sin(2.0_c_float * TWO_PI() * min(seg_t + 0.02_c_float, 1.0_c_float)) * axis_z + &
                    0.010_c_float * axis_y
        wing1 = center - 0.014_c_float * axis_y + 0.006_c_float * axis_z
        wing1_next = lead_next - 0.024_c_float * axis_y + 0.006_c_float * axis_z
        wing2 = center + 0.020_c_float * axis_y - 0.004_c_float * axis_z
        wing2_next = lead_next + 0.010_c_float * axis_y - 0.004_c_float * axis_z

        eye_pos = center - 0.18_c_float * span * axis_x + 0.06_c_float * span * sin(real(PI, c_float) * seg_t) * axis_y + &
                  0.04_c_float * span * sin(real(PI, c_float) * seg_t) * axis_z
        look_target = lerp3(center, lerp3(to_body, sun, 0.06_c_float), 0.30_c_float)

        call set_camera_focus(cam, look_target)
        cam%eye = eye_pos
        cam%view_up = axis_z
        cam%eye_override = .true.

        call stage_ship_from_path(overlay, SHIP_ENTERPRISE, lead, lead_next, 0.0009_c_float, -0.02_c_float)
        call stage_ship_from_path(overlay, SHIP_VOYAGER_NCC, wing1, wing1_next, 0.0010_c_float, 0.04_c_float)
        call stage_ship_from_path(overlay, SHIP_VOYAGER1, wing2, wing2_next, 0.0014_c_float, -0.03_c_float)
    end subroutine apply_inner_worlds_sprint

    subroutine apply_solar_crown(state, cam, bodies, focus_index, overlay)
        type(demo_state_t), intent(in) :: state
        type(camera_t), intent(inout) :: cam
        type(body_t), intent(in) :: bodies(:)
        integer, intent(out) :: focus_index
        type(demo_overlay_t), intent(inout) :: overlay
        real(c_float) :: sun(3), venus(3), axis_x(3), axis_y(3), axis_z(3)
        real(c_float) :: center(3), center_next(3), lead(3), lead_next(3), wing1(3), wing1_next(3), wing2(3), wing2_next(3)
        real(c_float) :: eye_pos(3), look_target(3), center_dir(3), t

        sun = body_position_au(bodies, BODY_SUN)
        venus = body_position_au(bodies, BODY_VENUS)
        call basis_from_reference(venus, sun, axis_x, axis_y, axis_z)
        t = wrapped_phase(state)

        center = lerp3(sun, venus, 0.42_c_float) + &
                 0.030_c_float * cos(TWO_PI() * t + 0.2_c_float) * axis_y + &
                 0.014_c_float * sin(2.0_c_float * TWO_PI() * t) * axis_z - &
                 0.015_c_float * sin(TWO_PI() * t + 0.2_c_float) * axis_x
        center_next = lerp3(sun, venus, 0.42_c_float) + &
                      0.030_c_float * cos(TWO_PI() * (t + 0.01_c_float) + 0.2_c_float) * axis_y + &
                      0.014_c_float * sin(2.0_c_float * TWO_PI() * (t + 0.01_c_float)) * axis_z - &
                      0.015_c_float * sin(TWO_PI() * (t + 0.01_c_float) + 0.2_c_float) * axis_x
        center_dir = direction_from_points(center, center_next, axis_y)

        lead = center + 0.014_c_float * axis_y
        lead_next = center_next + 0.014_c_float * axis_y
        wing1 = center - 0.018_c_float * axis_y + 0.007_c_float * axis_z
        wing1_next = center_next - 0.018_c_float * axis_y + 0.007_c_float * axis_z
        wing2 = center + 0.022_c_float * axis_y - 0.010_c_float * axis_z
        wing2_next = center_next + 0.022_c_float * axis_y - 0.010_c_float * axis_z

        eye_pos = center - 0.070_c_float * center_dir + 0.024_c_float * axis_z + &
                  0.050_c_float * axis_y + 0.010_c_float * axis_x
        look_target = lerp3(center, venus, 0.55_c_float)

        call set_camera_focus(cam, look_target)
        cam%eye = eye_pos
        cam%view_up = axis_z
        cam%eye_override = .true.
        focus_index = BODY_VENUS

        call stage_ship_from_path(overlay, SHIP_ENTERPRISE, lead, lead_next, 0.0010_c_float, 0.00_c_float)
        call stage_ship_from_path(overlay, SHIP_VOYAGER_NCC, wing1, wing1_next, 0.0011_c_float, 0.03_c_float)
        call stage_ship_from_path(overlay, SHIP_VOYAGER1, wing2, wing2_next, 0.0016_c_float, -0.05_c_float)
    end subroutine apply_solar_crown

    subroutine clear_overlay(overlay)
        type(demo_overlay_t), intent(out) :: overlay
        integer :: i

        overlay%count = 0
        overlay%ship_count = 0
        do i = 1, MAX_DEMO_BODIES
            overlay%bodies(i)%name = ""
            overlay%bodies(i)%mass = 0.0d0
            overlay%bodies(i)%radius = 0.0d0
            overlay%bodies(i)%position = zero_vec3
            overlay%bodies(i)%velocity = zero_vec3
            overlay%bodies(i)%acceleration = zero_vec3
            overlay%bodies(i)%color = [1.0, 1.0, 1.0]
        end do
        do i = 1, MAX_DEMO_SHIPS
            overlay%ships(i)%craft_index = 0
            overlay%ships(i)%world_pos_au = 0.0_c_float
            overlay%ships(i)%yaw = 0.0_c_float
            overlay%ships(i)%pitch = 0.0_c_float
            overlay%ships(i)%roll = 0.0_c_float
            overlay%ships(i)%scale_mul = 1.0_c_float
        end do
    end subroutine clear_overlay

    subroutine stage_ship_from_path(overlay, craft_index, world_pos_au, next_pos_au, scale_mul, roll_hint)
        type(demo_overlay_t), intent(inout) :: overlay
        integer, intent(in) :: craft_index
        real(c_float), intent(in) :: world_pos_au(3), next_pos_au(3)
        real(c_float), intent(in) :: scale_mul, roll_hint
        real(c_float) :: direction(3), yaw, pitch

        direction = direction_from_points(world_pos_au, next_pos_au, [0.0_c_float, 0.0_c_float, 1.0_c_float])
        call direction_to_angles(direction, yaw, pitch)
        call stage_ship(overlay, craft_index, world_pos_au, yaw, pitch, roll_hint, scale_mul)
    end subroutine stage_ship_from_path

    subroutine stage_ship(overlay, craft_index, world_pos_au, yaw, pitch, roll, scale_mul)
        type(demo_overlay_t), intent(inout) :: overlay
        integer, intent(in) :: craft_index
        real(c_float), intent(in) :: world_pos_au(3)
        real(c_float), intent(in) :: yaw, pitch, roll, scale_mul
        integer :: slot

        if (overlay%ship_count >= MAX_DEMO_SHIPS) return
        slot = overlay%ship_count + 1
        overlay%ship_count = slot
        overlay%ships(slot)%craft_index = craft_index
        overlay%ships(slot)%world_pos_au = world_pos_au
        overlay%ships(slot)%yaw = yaw
        overlay%ships(slot)%pitch = pitch
        overlay%ships(slot)%roll = roll
        overlay%ships(slot)%scale_mul = scale_mul
    end subroutine stage_ship

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
        case (DEMO_ID_EARTH_CONVOY, DEMO_ID_VOYAGER_SURVEY, DEMO_ID_ENTERPRISE_BLUE, &
              DEMO_ID_MARS_CONVOY, DEMO_ID_INNER_WORLDS_SPRINT, DEMO_ID_SOLAR_CROWN)
            duration = 30.0_c_float
        case (DEMO_ID_VOYAGER_JOURNEY)
            duration = 48.0_c_float
        case default
            duration = DEMO_DURATION_SECONDS
        end select
    end function demo_duration_for

    subroutine basis_from_reference(center, reference, axis_x, axis_y, axis_z)
        real(c_float), intent(in) :: center(3), reference(3)
        real(c_float), intent(out) :: axis_x(3), axis_y(3), axis_z(3)

        axis_x = center - reference
        if (norm3(axis_x) < 1.0e-5_c_float) axis_x = [1.0_c_float, 0.0_c_float, 0.0_c_float]
        call normalize3(axis_x)
        axis_z = [0.0_c_float, 0.0_c_float, 1.0_c_float]
        axis_y = cross3(axis_z, axis_x)
        if (norm3(axis_y) < 1.0e-5_c_float) axis_y = [0.0_c_float, 1.0_c_float, 0.0_c_float]
        call normalize3(axis_y)
    end subroutine basis_from_reference

    pure function orbit_path(center, axis_x, axis_y, axis_z, radius_x, radius_y, vertical_amp, t) result(pos)
        real(c_float), intent(in) :: center(3), axis_x(3), axis_y(3), axis_z(3)
        real(c_float), intent(in) :: radius_x, radius_y, vertical_amp, t
        real(c_float) :: pos(3), theta

        theta = TWO_PI() * t
        pos = center + radius_x * cos(theta) * axis_x + radius_y * sin(theta) * axis_y + &
              vertical_amp * sin(2.0_c_float * theta) * axis_z
    end function orbit_path

    pure function direction_from_points(a, b, fallback) result(direction)
        real(c_float), intent(in) :: a(3), b(3), fallback(3)
        real(c_float) :: direction(3)

        direction = b - a
        if (norm3(direction) < 1.0e-5_c_float) direction = fallback
        call normalize3(direction)
    end function direction_from_points

    subroutine direction_to_angles(direction, yaw, pitch)
        real(c_float), intent(in) :: direction(3)
        real(c_float), intent(out) :: yaw, pitch
        real(c_float) :: flat

        yaw = atan2(direction(1), direction(3))
        flat = sqrt(direction(1) * direction(1) + direction(3) * direction(3))
        pitch = atan2(direction(2), max(flat, 1.0e-6_c_float))
    end subroutine direction_to_angles

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

    pure subroutine normalize3(v)
        real(c_float), intent(inout) :: v(3)
        real(c_float) :: n
        n = norm3(v)
        if (n > 1.0e-6_c_float) v = v / n
    end subroutine normalize3

    pure function TWO_PI() result(v)
        real(c_float) :: v
        v = 2.0_c_float * real(PI, c_float)
    end function TWO_PI

    pure function to_lower_ascii(text) result(folded)
        character(len=*), intent(in) :: text
        character(len=len(text)) :: folded
        integer :: i, code

        folded = text
        do i = 1, len(text)
            code = iachar(text(i:i))
            if (code >= iachar('A') .and. code <= iachar('Z')) then
                folded(i:i) = achar(code + 32)
            else
                folded(i:i) = text(i:i)
            end if
        end do
    end function to_lower_ascii

end module demo_mod
