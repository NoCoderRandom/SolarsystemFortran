!===============================================================================
! camera.f90 — Fixed camera above the ecliptic, perspective projection
!
! Phase 3: non-interactive camera positioned to frame Neptune's orbit.
! The ecliptic is the X-Z plane (Y = 0). Camera is placed at +Y looking
! toward the origin.
!
! Neptune's semi-major axis ≈ 30 AU, so we position the camera at
! ~60 AU above the ecliptic to frame the entire system with margin.
!===============================================================================
module camera_mod
    use, intrinsic :: iso_c_binding, only: c_float
    use mat4_math, only: mat4, mat4_perspective, mat4_look_at, &
                    mat4_to_array
    implicit none
    private

    public :: camera_t, camera_init, camera_get_view, camera_get_projection

    !-----------------------------------------------------------------------
    ! Fixed camera
    !-----------------------------------------------------------------------
    type, public :: camera_t
        real(c_float) :: eye(3)        = 0.0_c_float
        real(c_float) :: target(3)     = 0.0_c_float
        real(c_float) :: up(3)         = 0.0_c_float
        real(c_float) :: fovy_rad      = 0.0_c_float
        real(c_float) :: aspect        = 0.0_c_float
        real(c_float) :: znear         = 0.0_c_float
        real(c_float) :: zfar          = 0.0_c_float
    end type camera_t

    ! Default: 60 AU above ecliptic, 60° FOV, near=0.01, far=200 (all in AU units)
    real(c_float), parameter :: CAM_DISTANCE = 60.0_c_float
    real(c_float), parameter :: CAM_FOVY_DEG = 60.0_c_float
    real(c_float), parameter :: CAM_NEAR     =  0.01_c_float
    real(c_float), parameter :: CAM_FAR      = 200.0_c_float
    real(c_float), parameter, private :: DEG2RAD = 3.14159265358979323846_c_float / 180.0_c_float

contains

    !=====================================================================
    ! camera_init — set up fixed camera parameters
    !=====================================================================
    subroutine camera_init(cam, width, height)
        type(camera_t), intent(out) :: cam
        integer, intent(in) :: width, height
        real(c_float) :: fovy

        fovy = CAM_FOVY_DEG * DEG2RAD

        cam%eye    = [0.0_c_float, CAM_DISTANCE, 0.0_c_float]
        cam%target = [0.0_c_float, 0.0_c_float, 0.0_c_float]
        cam%up     = [0.0_c_float, 0.0_c_float, 1.0_c_float]
        cam%fovy_rad = fovy
        cam%aspect   = real(width, c_float) / real(height, c_float)
        cam%znear    = CAM_NEAR
        cam%zfar     = CAM_FAR
    end subroutine camera_init

    !=====================================================================
    ! camera_get_view — return view matrix (column-major array)
    !=====================================================================
    function camera_get_view(cam) result(m)
        type(camera_t), intent(in) :: cam
        type(mat4) :: mv
        real(c_float) :: m(16)
        mv = mat4_look_at(cam%eye, cam%target, cam%up)
        m = mat4_to_array(mv)
    end function camera_get_view

    !=====================================================================
    ! camera_get_projection — return projection matrix (column-major array)
    !=====================================================================
    function camera_get_projection(cam) result(m)
        type(camera_t), intent(in) :: cam
        type(mat4) :: mp
        real(c_float) :: m(16)
        mp = mat4_perspective(cam%fovy_rad, cam%aspect, cam%znear, cam%zfar)
        m = mat4_to_array(mp)
    end function camera_get_projection

end module camera_mod
