!===============================================================================
! config.f90 — Runtime configuration (time scale, pause, focus, HUD)
!===============================================================================
module config_mod
    use, intrinsic :: iso_fortran_env, only: real64
    use constants, only: SEC_PER_DAY, SEC_PER_YEAR
    implicit none
    private

    public :: sim_config_t, config_init, config_set_time_scale

    ! Time scale bounds (simulated seconds per real second)
    real(real64), parameter, public :: TIME_SCALE_MIN = 1.0_real64              ! 1 s/s
    real(real64), parameter, public :: TIME_SCALE_MAX = 10.0_real64 * SEC_PER_YEAR  ! 10 years/s
    real(real64), parameter, public :: TIME_SCALE_DEFAULT = SEC_PER_DAY          ! 1 day/s

    ! Body focus indices: 0=Sun, 1=Mercury, ..., 8=Neptune
    integer, parameter, public :: FOCUS_NONE = -1

    ! Phase 6 HDR/bloom defaults
    real, parameter, public :: BLOOM_THRESHOLD_DEFAULT = 1.0
    real, parameter, public :: BLOOM_INTENSITY_DEFAULT = 0.85
    real, parameter, public :: EXPOSURE_DEFAULT        = 1.0
    real, parameter, public :: EXPOSURE_MIN            = 0.05
    real, parameter, public :: EXPOSURE_MAX            = 8.0
    real, parameter, public :: SUN_EMISSIVE_MUL_DEFAULT = 3.5
    integer, parameter, public :: BLOOM_MIPS_DEFAULT   = 5

    type, public :: sim_config_t
        real(real64) :: time_scale   = TIME_SCALE_DEFAULT
        logical      :: paused       = .false.
        integer      :: focus_index   = 0          ! 0=Sun
        logical      :: hud_visible  = .true.
        logical      :: trails_visible = .true.
        integer      :: trail_length  = 4096

        ! HDR / bloom tunables
        logical :: bloom_on         = .true.
        real    :: bloom_threshold  = BLOOM_THRESHOLD_DEFAULT
        real    :: bloom_intensity  = BLOOM_INTENSITY_DEFAULT
        integer :: bloom_mips       = BLOOM_MIPS_DEFAULT
        real    :: exposure         = EXPOSURE_DEFAULT
        real    :: sun_emissive_mul = SUN_EMISSIVE_MUL_DEFAULT

        character(len=32) :: focus_names(9) = [ &
            "Sun       ", "Mercury   ", "Venus     ", "Earth     ", &
            "Mars      ", "Jupiter   ", "Saturn    ", "Uranus    ", "Neptune   "]
    end type sim_config_t

contains

    subroutine config_init(cfg)
        type(sim_config_t), intent(out) :: cfg
        cfg%time_scale   = TIME_SCALE_DEFAULT
        cfg%paused       = .false.
        cfg%focus_index   = 0
        cfg%hud_visible  = .true.
    end subroutine config_init

    subroutine config_set_time_scale(cfg, new_scale)
        type(sim_config_t), intent(inout) :: cfg
        real(real64), intent(in) :: new_scale
        if (new_scale >= TIME_SCALE_MIN .and. new_scale <= TIME_SCALE_MAX) then
            cfg%time_scale = new_scale
        end if
    end subroutine config_set_time_scale

end module config_mod
