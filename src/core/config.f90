!===============================================================================
! config.f90 — Runtime configuration (time scale, pause, focus, HUD, etc.)
!
! The sim_config_t struct is the single source of truth for all tunables.
! Defaults live here; config_toml can override them from config.toml at startup.
!===============================================================================
module config_mod
    use, intrinsic :: iso_fortran_env, only: real64
    implicit none
    private

    public :: sim_config_t, config_init, config_set_time_scale
    public :: config_set_speed_preset, config_step_speed_preset, &
              config_nearest_speed_preset, config_speed_label, &
              config_normalize_spacecraft_camera_mode
    public :: SPACECRAFT_CAMERA_SYSTEM, SPACECRAFT_CAMERA_FOLLOW

    ! Time scale bounds (simulated seconds per real second)
    integer, parameter, public :: SPEED_PRESET_COUNT = 16
    real(real64), parameter, public :: TIME_SCALE_PRESETS(SPEED_PRESET_COUNT) = [ &
        1.0_real64,      2.0_real64,      5.0_real64,      10.0_real64, &
        20.0_real64,     50.0_real64,     100.0_real64,    200.0_real64, &
        500.0_real64,    1000.0_real64,   2000.0_real64,   5000.0_real64, &
        10000.0_real64,  20000.0_real64,  50000.0_real64,  100000.0_real64 ]
    integer, parameter, public :: SPEED_PRESET_DEFAULT = 13
    real(real64), parameter, public :: TIME_SCALE_MIN     = TIME_SCALE_PRESETS(1)
    real(real64), parameter, public :: TIME_SCALE_MAX     = TIME_SCALE_PRESETS(SPEED_PRESET_COUNT)
    real(real64), parameter, public :: TIME_SCALE_DEFAULT = TIME_SCALE_PRESETS(SPEED_PRESET_DEFAULT)

    ! Body focus indices: 0=Sun, 1=Mercury, ..., 8=Neptune
    integer, parameter, public :: FOCUS_NONE = -1
    integer, parameter :: SPACECRAFT_CAMERA_SYSTEM = 0
    integer, parameter :: SPACECRAFT_CAMERA_FOLLOW = 1

    ! HDR/bloom defaults
    real, parameter, public :: BLOOM_THRESHOLD_DEFAULT = 1.0
    real, parameter, public :: BLOOM_INTENSITY_DEFAULT = 0.85
    real, parameter, public :: EXPOSURE_DEFAULT        = 1.0
    real, parameter, public :: EXPOSURE_MIN            = 0.05
    real, parameter, public :: EXPOSURE_MAX            = 8.0
    real, parameter, public :: SUN_EMISSIVE_MUL_DEFAULT = 3.5
    integer, parameter, public :: BLOOM_MIPS_DEFAULT   = 5

    type, public :: sim_config_t
        ! Window
        integer :: window_width  = 1600
        integer :: window_height = 900
        logical :: vsync         = .true.

        ! Simulation
        integer      :: speed_preset   = SPEED_PRESET_DEFAULT
        real(real64) :: time_scale     = TIME_SCALE_DEFAULT
        logical      :: paused         = .false.
        integer      :: focus_index    = 0
        logical      :: hud_visible    = .true.
        logical      :: trails_visible = .true.
        integer      :: trail_length   = 4096

        ! Log-compress rendered radial distances around the Sun so the
        ! inner planets get breathing room vs. textbook-style spacing.
        ! Physics is untouched; pure render-time remap.
        logical      :: distance_log_scale = .false.

        ! Camera defaults
        real :: camera_azimuth   = 0.0       ! radians
        real :: camera_elevation = 0.8       ! radians
        real :: camera_log_dist  = 1.778     ! log10(AU)

        ! HDR / bloom / tonemap
        logical :: bloom_on         = .true.
        real    :: bloom_threshold  = BLOOM_THRESHOLD_DEFAULT
        real    :: bloom_intensity  = BLOOM_INTENSITY_DEFAULT
        integer :: bloom_mips       = BLOOM_MIPS_DEFAULT
        real    :: exposure         = EXPOSURE_DEFAULT
        real    :: sun_emissive_mul = SUN_EMISSIVE_MUL_DEFAULT

        ! Starfield
        integer :: starfield_count = 8000
        real    :: starfield_intensity = 1.0

        ! Asteroid belt — 3 000 reads as a dense belt without dominating
        ! close-up frames. Bump in config.toml if you want more.
        integer :: asteroid_count = 3000
        real    :: asteroid_a_min = 2.2     ! AU
        real    :: asteroid_a_max = 3.3     ! AU

        ! Optional texture toggles — disabling falls back to un-normal/un-night/etc.
        logical :: load_earth_night     = .true.
        logical :: load_earth_normal    = .true.
        logical :: load_earth_specular  = .true.
        logical :: load_saturn_rings    = .true.

        ! Spacecraft framework — disabled by default until feature phases land.
        logical :: spacecraft_enabled = .false.
        integer :: spacecraft_camera_mode = SPACECRAFT_CAMERA_SYSTEM
        logical :: spacecraft_auto_stabilize = .true.
        character(len=64) :: spacecraft_default_id = "voyager1"
        character(len=32) :: spacecraft_spawn_preset = "earth"

        character(len=32) :: focus_names(9) = [ &
            "Sun       ", "Mercury   ", "Venus     ", "Earth     ", &
            "Mars      ", "Jupiter   ", "Saturn    ", "Uranus    ", "Neptune   "]
    end type sim_config_t

contains

    subroutine config_init(cfg)
        type(sim_config_t), intent(out) :: cfg
        ! All defaults are applied by the type's component initializers.
        ! Left as a seam where load-from-file will later clobber individual fields.
        call config_set_speed_preset(cfg, SPEED_PRESET_DEFAULT)
    end subroutine config_init

    subroutine config_set_time_scale(cfg, new_scale)
        type(sim_config_t), intent(inout) :: cfg
        real(real64), intent(in) :: new_scale
        call config_set_speed_preset(cfg, config_nearest_speed_preset(new_scale))
    end subroutine config_set_time_scale

    subroutine config_set_speed_preset(cfg, preset_idx)
        type(sim_config_t), intent(inout) :: cfg
        integer, intent(in) :: preset_idx
        integer :: idx

        idx = min(max(preset_idx, 1), SPEED_PRESET_COUNT)
        cfg%speed_preset = idx
        cfg%time_scale = TIME_SCALE_PRESETS(idx)
    end subroutine config_set_speed_preset

    subroutine config_step_speed_preset(cfg, delta)
        type(sim_config_t), intent(inout) :: cfg
        integer, intent(in) :: delta

        call config_set_speed_preset(cfg, cfg%speed_preset + delta)
    end subroutine config_step_speed_preset

    integer function config_nearest_speed_preset(new_scale) result(idx)
        real(real64), intent(in) :: new_scale
        real(real64) :: best_diff, diff
        integer :: i

        idx = 1
        best_diff = huge(1.0_real64)
        do i = 1, SPEED_PRESET_COUNT
            diff = abs(TIME_SCALE_PRESETS(i) - new_scale)
            if (diff < best_diff) then
                best_diff = diff
                idx = i
            end if
        end do
    end function config_nearest_speed_preset

    function config_speed_label(cfg) result(label)
        type(sim_config_t), intent(in) :: cfg
        character(len=32) :: label
        integer :: multiplier

        multiplier = nint(cfg%time_scale)
        write(label, "(I0,'x real time')") multiplier
    end function config_speed_label

    integer function config_normalize_spacecraft_camera_mode(mode) result(normalized)
        integer, intent(in) :: mode

        select case (mode)
        case (SPACECRAFT_CAMERA_SYSTEM, SPACECRAFT_CAMERA_FOLLOW)
            normalized = mode
        case default
            normalized = SPACECRAFT_CAMERA_SYSTEM
        end select
    end function config_normalize_spacecraft_camera_mode

end module config_mod
