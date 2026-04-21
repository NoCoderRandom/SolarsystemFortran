module spacecraft_camera_mod
    use, intrinsic :: iso_c_binding, only: c_float
    use camera_mod, only: camera_t, camera_follow_focus, camera_sync_orbit_from_eye
    implicit none
    private

    public :: spacecraft_camera_state_t
    public :: spacecraft_camera_init, spacecraft_camera_selection_changed
    public :: spacecraft_camera_toggle_inspect, spacecraft_camera_handle_mouse
    public :: spacecraft_camera_apply, spacecraft_camera_exit
    public :: spacecraft_camera_inspect_enabled

    real(c_float), parameter :: PI = 3.14159265358979323846_c_float
    real(c_float), parameter :: HALF_PI = 1.5707963267948966_c_float
    real(c_float), parameter :: LOOK_SENS = 0.0030_c_float
    real(c_float), parameter :: ORBIT_SENS = 0.0020_c_float
    real(c_float), parameter :: ZOOM_SENS = 0.06_c_float
    real(c_float), parameter :: ELEV_MIN = -1.45_c_float
    real(c_float), parameter :: ELEV_MAX =  1.45_c_float
    real(c_float), parameter :: FOLLOW_ZOOM_MIN = -0.60_c_float
    real(c_float), parameter :: FOLLOW_ZOOM_MAX =  0.85_c_float
    real(c_float), parameter :: INSPECT_LOG_MIN = -1.70_c_float
    real(c_float), parameter :: INSPECT_LOG_MAX =  0.10_c_float

    type, public :: spacecraft_camera_state_t
        logical :: follow_active = .false.
        logical :: inspect_mode = .false.
        logical :: inspect_seeded = .false.
        real(c_float) :: follow_zoom_log = 0.0_c_float
        real(c_float) :: inspect_azimuth = 0.8_c_float
        real(c_float) :: inspect_elevation = 0.35_c_float
        real(c_float) :: inspect_log_dist = -0.85_c_float
    end type spacecraft_camera_state_t

contains

    subroutine spacecraft_camera_init(state)
        type(spacecraft_camera_state_t), intent(out) :: state

        state%follow_active = .false.
        state%inspect_mode = .false.
        state%inspect_seeded = .false.
        state%follow_zoom_log = 0.0_c_float
        state%inspect_azimuth = 0.8_c_float
        state%inspect_elevation = 0.35_c_float
        state%inspect_log_dist = -0.85_c_float
    end subroutine spacecraft_camera_init

    subroutine spacecraft_camera_selection_changed(state)
        type(spacecraft_camera_state_t), intent(inout) :: state

        state%inspect_mode = .false.
        state%inspect_seeded = .false.
        state%follow_zoom_log = 0.0_c_float
    end subroutine spacecraft_camera_selection_changed

    subroutine spacecraft_camera_toggle_inspect(state)
        type(spacecraft_camera_state_t), intent(inout) :: state

        state%inspect_mode = .not. state%inspect_mode
        if (.not. state%inspect_mode) state%inspect_seeded = .false.
    end subroutine spacecraft_camera_toggle_inspect

    logical function spacecraft_camera_inspect_enabled(state) result(enabled)
        type(spacecraft_camera_state_t), intent(in) :: state

        enabled = state%inspect_mode
    end function spacecraft_camera_inspect_enabled

    subroutine spacecraft_camera_handle_mouse(state, mouse_dx, mouse_dy, scroll, lmb, mmb, &
                                              yaw_delta, pitch_delta)
        type(spacecraft_camera_state_t), intent(inout) :: state
        real(c_float), intent(in) :: mouse_dx, mouse_dy, scroll
        logical, intent(in) :: lmb, mmb
        real(c_float), intent(out) :: yaw_delta, pitch_delta

        yaw_delta = 0.0_c_float
        pitch_delta = 0.0_c_float

        if (state%inspect_mode) then
            if (lmb .or. mmb) then
                state%inspect_azimuth = state%inspect_azimuth - mouse_dx * ORBIT_SENS
                state%inspect_elevation = max(ELEV_MIN, min(ELEV_MAX, &
                    state%inspect_elevation + mouse_dy * ORBIT_SENS))
                call wrap_angle(state%inspect_azimuth)
            end if
            if (abs(scroll) > 0.0_c_float) then
                state%inspect_log_dist = max(INSPECT_LOG_MIN, min(INSPECT_LOG_MAX, &
                    state%inspect_log_dist - scroll * ZOOM_SENS))
            end if
        else
            if (lmb .or. mmb) then
                yaw_delta = -mouse_dx * LOOK_SENS
                pitch_delta = mouse_dy * LOOK_SENS
            end if
            if (abs(scroll) > 0.0_c_float) then
                state%follow_zoom_log = max(FOLLOW_ZOOM_MIN, min(FOLLOW_ZOOM_MAX, &
                    state%follow_zoom_log - scroll * ZOOM_SENS))
            end if
        end if
    end subroutine spacecraft_camera_handle_mouse

    subroutine spacecraft_camera_apply(state, cam, target, ship_yaw, ship_pitch, base_dist, &
                                       height, dt)
        type(spacecraft_camera_state_t), intent(inout) :: state
        type(camera_t), intent(inout) :: cam
        real(c_float), intent(in) :: target(3)
        real(c_float), intent(in) :: ship_yaw, ship_pitch
        real(c_float), intent(in) :: base_dist, height, dt
        real(c_float) :: back(3), up_offset(3), orbit(3), dist

        call camera_follow_focus(cam, target, dt, 10.0_c_float)
        cam%eye_override = .true.
        cam%view_up = [0.0_c_float, 1.0_c_float, 0.0_c_float]

        if (state%inspect_mode) then
            if (.not. state%inspect_seeded) then
                state%inspect_log_dist = log10(max(base_dist * 0.8_c_float, 0.03_c_float))
                state%inspect_log_dist = max(INSPECT_LOG_MIN, min(INSPECT_LOG_MAX, state%inspect_log_dist))
                state%inspect_seeded = .true.
            end if
            dist = 10.0_c_float ** state%inspect_log_dist
            orbit(1) = dist * cos(state%inspect_elevation) * sin(state%inspect_azimuth)
            orbit(2) = dist * sin(state%inspect_elevation)
            orbit(3) = dist * cos(state%inspect_elevation) * cos(state%inspect_azimuth)
            cam%eye = target + orbit
        else
            dist = max(base_dist * (10.0_c_float ** state%follow_zoom_log), 0.02_c_float)
            back(1) = -cos(ship_pitch) * sin(ship_yaw)
            back(2) = -sin(ship_pitch)
            back(3) = -cos(ship_pitch) * cos(ship_yaw)
            up_offset = [0.0_c_float, height, 0.0_c_float]
            cam%eye = target + back * dist + up_offset
        end if

        state%follow_active = .true.
    end subroutine spacecraft_camera_apply

    subroutine spacecraft_camera_exit(state, cam)
        type(spacecraft_camera_state_t), intent(inout) :: state
        type(camera_t), intent(inout) :: cam

        if (.not. state%follow_active) return
        call camera_sync_orbit_from_eye(cam)
        cam%eye_override = .false.
        cam%view_up = [0.0_c_float, 1.0_c_float, 0.0_c_float]
        state%follow_active = .false.
        state%inspect_mode = .false.
        state%inspect_seeded = .false.
    end subroutine spacecraft_camera_exit

    subroutine wrap_angle(angle)
        real(c_float), intent(inout) :: angle

        do while (angle > PI)
            angle = angle - 2.0_c_float * PI
        end do
        do while (angle < -PI)
            angle = angle + 2.0_c_float * PI
        end do
    end subroutine wrap_angle

end module spacecraft_camera_mod
