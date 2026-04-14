!===============================================================================
! camera.f90 — Interactive orbit camera with smooth focus transitions
!
! State: focus point (AU), azimuth, elevation, log-scaled distance
! Controls:
!   LMB drag  → rotate azimuth/elevation
!   RMB drag  → pan focus in camera-local XY plane
!   Scroll    → zoom (adjust log-distance)
!   R key     → reset to default view
!   0..8 keys → smooth focus transition to body
!===============================================================================
module camera_mod
    use, intrinsic :: iso_c_binding, only: c_float, c_double
    use mat4_math, only: mat4, mat4_perspective, mat4_look_at, mat4_to_array
    use vector3d, only: vec3, operator(+), operator(-), operator(*)
    implicit none
    private

    public :: camera_t, camera_init, camera_update, camera_get_view, camera_get_projection
    public :: camera_reset, camera_set_focus, camera_handle_input
    public :: CAM_FOVY_DEG, CAM_NEAR, CAM_FAR

    real(c_float), parameter :: CAM_FOVY_DEG = 60.0_c_float
    real(c_float), parameter :: CAM_NEAR     =  0.01_c_float
    real(c_float), parameter :: CAM_FAR      = 500.0_c_float

    ! Default orbit parameters
    real(c_float), parameter :: DEFAULT_AZIMUTH  = 0.0_c_float       ! radians
    real(c_float), parameter :: DEFAULT_ELEVATION = 0.8_c_float      ! ~46° above ecliptic
    real(c_float), parameter :: DEFAULT_LOG_DIST  = 1.778_c_float    ! log10(60 AU) ≈ 1.778
    real(c_float), parameter :: ELEVATION_MIN = 0.01_c_float         ! Avoid gimbal lock at poles
    real(c_float), parameter :: ELEVATION_MAX = 3.14_c_float - 0.01_c_float
    real(c_float), parameter :: LOG_DIST_MIN = -1.0_c_float          ! 0.1 AU (close to planets)
    real(c_float), parameter :: LOG_DIST_MAX = 2.5_c_float           ! ~316 AU (far beyond Neptune)

    type, public :: camera_t
        ! Orbit parameters
        real(c_float) :: azimuth   = DEFAULT_AZIMUTH      ! radians
        real(c_float) :: elevation = DEFAULT_ELEVATION     ! radians
        real(c_float) :: log_dist  = DEFAULT_LOG_DIST      ! log10 of distance in AU

        ! Focus point (in AU world units)
        real(c_float) :: focus(3) = [0.0_c_float, 0.0_c_float, 0.0_c_float]

        ! Smooth focus transition
        real(c_float) :: focus_target(3) = [0.0_c_float, 0.0_c_float, 0.0_c_float]
        real(c_float) :: focus_start(3)  = [0.0_c_float, 0.0_c_float, 0.0_c_float]
        real(c_float) :: focus_progress  = 1.0_c_float  ! 1.0 = at target, 0.0 = just started
        real(c_float) :: focus_duration  = 0.5_c_float  ! seconds for transition

        ! Projection
        real(c_float) :: fovy_rad  = 0.0_c_float
        real(c_float) :: aspect    = 0.0_c_float

        ! Computed eye position (derived each frame)
        real(c_float) :: eye(3) = 0.0_c_float
    end type camera_t

    ! Sensitivity constants
    real(c_float), parameter :: ROTATE_SENS = 0.005_c_float   ! rad/pixel
    real(c_float), parameter :: PAN_SENS    = 0.01_c_float    ! AU/pixel
    real(c_float), parameter :: ZOOM_SENS   = 0.05_c_float    ! log-distance/scroll-unit

contains

    subroutine camera_init(cam, width, height)
        type(camera_t), intent(out) :: cam
        integer, intent(in) :: width, height

        cam%azimuth   = DEFAULT_AZIMUTH
        cam%elevation = DEFAULT_ELEVATION
        cam%log_dist  = DEFAULT_LOG_DIST
        cam%focus     = [0.0_c_float, 0.0_c_float, 0.0_c_float]
        cam%focus_target = cam%focus
        cam%focus_start  = cam%focus
        cam%focus_progress = 1.0_c_float
        cam%fovy_rad = CAM_FOVY_DEG * 3.14159265358979323846_c_float / 180.0_c_float
        cam%aspect   = real(width, c_float) / real(height, c_float)

        call camera_compute_eye(cam)
    end subroutine camera_init

    subroutine camera_update(cam, dt)
        type(camera_t), intent(inout) :: cam
        real(c_float), intent(in) :: dt
        real(c_float) :: t, ease

        ! Smooth focus transition: lerp with easing
        if (cam%focus_progress < 1.0_c_float) then
            cam%focus_progress = cam%focus_progress + dt / cam%focus_duration
            if (cam%focus_progress >= 1.0_c_float) then
                cam%focus_progress = 1.0_c_float
                cam%focus = cam%focus_target
            else
                ! Ease-in-out cubic
                t = cam%focus_progress
                ease = t * t * (3.0_c_float - 2.0_c_float * t)
                cam%focus = cam%focus_start + (cam%focus_target - cam%focus_start) * ease
            end if
        end if

        call camera_compute_eye(cam)
    end subroutine camera_update

    subroutine camera_compute_eye(cam)
        type(camera_t), intent(inout) :: cam
        real(c_float) :: dist, cos_el, sin_el, cos_az, sin_az

        dist = 10.0_c_float ** cam%log_dist
        cos_el = cos(cam%elevation)
        sin_el = sin(cam%elevation)
        cos_az = cos(cam%azimuth)
        sin_az = sin(cam%azimuth)

        ! Camera position relative to focus
        cam%eye(1) = cam%focus(1) + dist * cos_el * sin_az
        cam%eye(2) = cam%focus(2) + dist * sin_el
        cam%eye(3) = cam%focus(3) + dist * cos_el * cos_az
    end subroutine camera_compute_eye

    subroutine camera_reset(cam)
        type(camera_t), intent(inout) :: cam
        cam%azimuth   = DEFAULT_AZIMUTH
        cam%elevation = DEFAULT_ELEVATION
        cam%log_dist  = DEFAULT_LOG_DIST
        cam%focus_start  = cam%focus
        cam%focus_target = [0.0_c_float, 0.0_c_float, 0.0_c_float]
        cam%focus_progress = 0.0_c_float
    end subroutine camera_reset

    subroutine camera_set_focus(cam, new_focus)
        type(camera_t), intent(inout) :: cam
        real(c_float), intent(in) :: new_focus(3)
        cam%focus_start  = cam%focus
        cam%focus_target = new_focus
        cam%focus_progress = 0.0_c_float
    end subroutine camera_set_focus

    subroutine camera_handle_input(cam, mouse_dx, mouse_dy, scroll, &
                                   lmb, rmb, dt)
        type(camera_t), intent(inout) :: cam
        real(c_float), intent(in) :: mouse_dx, mouse_dy, scroll, dt
        logical, intent(in) :: lmb, rmb
        real(c_float) :: dist, pan_x, pan_y, right(3), up(3)
        real(c_float) :: unused_dt
        unused_dt = dt  ! Reserved for future use (time-based sensitivity)

        if (lmb) then
            ! Rotate: azimuth += dx, elevation -= dy
            cam%azimuth   = cam%azimuth   - mouse_dx * ROTATE_SENS
            cam%elevation = cam%elevation + mouse_dy * ROTATE_SENS
            ! Clamp elevation
            if (cam%elevation < ELEVATION_MIN) cam%elevation = ELEVATION_MIN
            if (cam%elevation > ELEVATION_MAX) cam%elevation = ELEVATION_MAX
        end if

        if (rmb) then
            ! Pan: move focus in camera-local XY plane
            dist = 10.0_c_float ** cam%log_dist
            call camera_get_right(cam, right)
            call camera_get_up(cam, up)
            pan_x = -mouse_dx * PAN_SENS * (dist / 60.0_c_float)
            pan_y =  mouse_dy * PAN_SENS * (dist / 60.0_c_float)
            cam%focus       = cam%focus       + right * pan_x
            cam%focus_target = cam%focus_target + right * pan_x
            cam%focus       = cam%focus       + up * pan_y
            cam%focus_target = cam%focus_target + up * pan_y
            cam%focus_progress = 1.0_c_float  ! Cancel smooth transition
        end if

        if (abs(scroll) > 0.0_c_float) then
            cam%log_dist = cam%log_dist - scroll * ZOOM_SENS
            if (cam%log_dist < LOG_DIST_MIN) cam%log_dist = LOG_DIST_MIN
            if (cam%log_dist > LOG_DIST_MAX) cam%log_dist = LOG_DIST_MAX
        end if
    end subroutine camera_handle_input

    function camera_get_view(cam) result(m)
        type(camera_t), intent(in) :: cam
        type(mat4) :: mv
        real(c_float) :: m(16)
        real(c_float) :: target(3)
        target = cam%focus
        mv = mat4_look_at(cam%eye, target, [0.0_c_float, 1.0_c_float, 0.0_c_float])
        m = mat4_to_array(mv)
    end function camera_get_view

    function camera_get_projection(cam) result(m)
        type(camera_t), intent(in) :: cam
        type(mat4) :: mp
        real(c_float) :: m(16)
        mp = mat4_perspective(cam%fovy_rad, cam%aspect, CAM_NEAR, CAM_FAR)
        m = mat4_to_array(mp)
    end function camera_get_projection

    ! Get camera right vector (in world space)
    pure subroutine camera_get_right(cam, right)
        type(camera_t), intent(in) :: cam
        real(c_float), intent(out) :: right(3)
        real(c_float) :: cos_az, sin_az
        cos_az = cos(cam%azimuth)
        sin_az = sin(cam%azimuth)
        right(1) =  cos_az
        right(2) =  0.0_c_float
        right(3) = -sin_az
    end subroutine camera_get_right

    pure subroutine camera_get_up(cam, up)
        type(camera_t), intent(in) :: cam
        real(c_float), intent(out) :: up(3)
        real(c_float) :: cos_el, sin_el, cos_az, sin_az
        cos_el = cos(cam%elevation)
        sin_el = sin(cam%elevation)
        cos_az = cos(cam%azimuth)
        sin_az = sin(cam%azimuth)
        up(1) = -sin_el * sin_az
        up(2) =  cos_el
        up(3) = -sin_el * cos_az
    end subroutine camera_get_up

end module camera_mod
