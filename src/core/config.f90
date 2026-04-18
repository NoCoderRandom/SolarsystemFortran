!===============================================================================
! config.f90 — Runtime configuration (time scale, pause, focus, HUD, etc.)
!
! The sim_config_t struct is the single source of truth for all tunables.
! Defaults live here; config_toml can override them from config.toml at startup.
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
        real(real64) :: time_scale     = TIME_SCALE_DEFAULT
        logical      :: paused         = .false.
        integer      :: focus_index    = 0
        logical      :: hud_visible    = .true.
        logical      :: trails_visible = .true.
        integer      :: trail_length   = 4096

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

        character(len=32) :: focus_names(9) = [ &
            "Sun       ", "Mercury   ", "Venus     ", "Earth     ", &
            "Mars      ", "Jupiter   ", "Saturn    ", "Uranus    ", "Neptune   "]
    end type sim_config_t

contains

    subroutine config_init(cfg)
        type(sim_config_t), intent(out) :: cfg
        ! All defaults are applied by the type's component initializers.
        ! Left as a seam where load-from-file will later clobber individual fields.
        cfg%time_scale = TIME_SCALE_DEFAULT
    end subroutine config_init

    subroutine config_set_time_scale(cfg, new_scale)
        type(sim_config_t), intent(inout) :: cfg
        real(real64), intent(in) :: new_scale
        if (new_scale >= TIME_SCALE_MIN .and. new_scale <= TIME_SCALE_MAX) then
            cfg%time_scale = new_scale
        end if
    end subroutine config_set_time_scale

end module config_mod
