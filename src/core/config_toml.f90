!===============================================================================
! config_toml.f90 — Minimal TOML reader/writer for config.toml.
!
! Parses a strict subset of TOML: [section] headers, key = value lines where
! value is one of: integer, float, bool, "quoted string". Comments start with
! '#' and run to end of line. This is intentionally small — the full toml-f
! library would be overkill for the flat key=value configuration we carry.
!===============================================================================
module config_toml_mod
    use, intrinsic :: iso_fortran_env, only: real64
    use config_mod, only: sim_config_t, config_set_speed_preset, &
                          config_set_time_scale, config_speed_label
    use logging, only: log_msg, LOG_INFO, LOG_WARN, LOG_ERROR
    implicit none
    private

    public :: config_toml_load, config_toml_write_default, config_toml_log

contains

    !---------------------------------------------------------------
    ! Load config.toml from `path`. If absent, write a default and
    ! continue with defaults. Unknown keys are ignored with a warning.
    !---------------------------------------------------------------
    subroutine config_toml_load(cfg, path)
        type(sim_config_t), intent(inout) :: cfg
        character(len=*), intent(in) :: path

        integer :: unit, iostat, line_no
        character(len=512) :: line, section, key, value
        logical :: have_section

        open(newunit=unit, file=path, status="old", action="read", &
             form="formatted", iostat=iostat)
        if (iostat /= 0) then
            call log_msg(LOG_INFO, "config.toml not found — writing default at " // trim(path))
            call config_toml_write_default(cfg, path)
            return
        end if

        call log_msg(LOG_INFO, "Loading config: " // trim(path))
        section = ""
        have_section = .false.
        line_no = 0
        do
            read(unit, "(A)", iostat=iostat) line
            if (iostat /= 0) exit
            line_no = line_no + 1
            call strip_comment_and_trim(line)
            if (len_trim(line) == 0) cycle

            if (line(1:1) == "[") then
                call parse_section(line, section)
                have_section = .true.
                cycle
            end if

            if (.not. have_section) cycle
            call parse_key_value(line, key, value)
            if (len_trim(key) == 0) cycle

            call apply_pair(cfg, trim(section), trim(key), trim(value), line_no)
        end do
        close(unit)
    end subroutine config_toml_load

    !---------------------------------------------------------------
    ! Write a default config.toml at `path`. Values mirror the current
    ! cfg, so the file reflects whatever defaults the build was shipped
    ! with.
    !---------------------------------------------------------------
    subroutine config_toml_write_default(cfg, path)
        type(sim_config_t), intent(in) :: cfg
        character(len=*), intent(in) :: path
        integer :: unit, iostat

        open(newunit=unit, file=path, status="replace", action="write", &
             form="formatted", iostat=iostat)
        if (iostat /= 0) then
            call log_msg(LOG_ERROR, "config.toml: cannot create " // trim(path))
            return
        end if

        write(unit, '(A)') "# Solar System Simulation — runtime configuration"
        write(unit, '(A)') "# Edit and restart to apply."
        write(unit, '(A)') ""
        write(unit, '(A)') "[window]"
        write(unit, '(A,I0)') "width  = ", cfg%window_width
        write(unit, '(A,I0)') "height = ", cfg%window_height
        write(unit, '(A,L1)') "vsync  = ", cfg%vsync
        write(unit, '(A)') ""
        write(unit, '(A)') "[simulation]"
        write(unit, '(A,I0)')   "speed_preset   = ", cfg%speed_preset
        write(unit, '(A,F0.1)') "time_scale     = ", cfg%time_scale
        write(unit, '(A,I0)')   "trail_length   = ", cfg%trail_length
        write(unit, '(A,L1)')   "trails_visible = ", cfg%trails_visible
        write(unit, '(A,L1)')   "hud_visible    = ", cfg%hud_visible
        write(unit, '(A,I0)')   "focus_index    = ", cfg%focus_index
        write(unit, '(A)') ""
        write(unit, '(A)') "[camera]"
        write(unit, '(A,F0.3)') "azimuth   = ", cfg%camera_azimuth
        write(unit, '(A,F0.3)') "elevation = ", cfg%camera_elevation
        write(unit, '(A,F0.3)') "log_dist  = ", cfg%camera_log_dist
        write(unit, '(A)') ""
        write(unit, '(A)') "[bloom]"
        write(unit, '(A,L1)')   "on        = ", cfg%bloom_on
        write(unit, '(A,F0.3)') "threshold = ", cfg%bloom_threshold
        write(unit, '(A,F0.3)') "intensity = ", cfg%bloom_intensity
        write(unit, '(A,I0)')   "mips      = ", cfg%bloom_mips
        write(unit, '(A)') ""
        write(unit, '(A)') "[tonemap]"
        write(unit, '(A,F0.3)') "exposure         = ", cfg%exposure
        write(unit, '(A,F0.3)') "sun_emissive_mul = ", cfg%sun_emissive_mul
        write(unit, '(A)') ""
        write(unit, '(A)') "[starfield]"
        write(unit, '(A,I0)')   "count     = ", cfg%starfield_count
        write(unit, '(A,F0.3)') "intensity = ", cfg%starfield_intensity
        write(unit, '(A)') ""
        write(unit, '(A)') "[asteroids]"
        write(unit, '(A,I0)')   "count = ", cfg%asteroid_count
        write(unit, '(A,F0.3)') "a_min = ", cfg%asteroid_a_min
        write(unit, '(A,F0.3)') "a_max = ", cfg%asteroid_a_max
        write(unit, '(A)') ""
        write(unit, '(A)') "[textures]"
        write(unit, '(A,L1)') "earth_night    = ", cfg%load_earth_night
        write(unit, '(A,L1)') "earth_normal   = ", cfg%load_earth_normal
        write(unit, '(A,L1)') "earth_specular = ", cfg%load_earth_specular
        write(unit, '(A,L1)') "saturn_rings   = ", cfg%load_saturn_rings
        close(unit)
    end subroutine config_toml_write_default

    !---------------------------------------------------------------
    ! Log the effective configuration (post-load). Short form.
    !---------------------------------------------------------------
    subroutine config_toml_log(cfg)
        type(sim_config_t), intent(in) :: cfg
        character(len=96) :: buf
        call log_msg(LOG_INFO, "=== Effective config ===")
        write(buf, '(A,I0,A,I0,A,L1)') "window: ", cfg%window_width, "x", &
            cfg%window_height, " vsync=", cfg%vsync
        call log_msg(LOG_INFO, trim(buf))
        write(buf, '(A,A,A,I0)') "sim: speed=", trim(config_speed_label(cfg)), &
            " trail=", cfg%trail_length
        call log_msg(LOG_INFO, trim(buf))
        write(buf, '(A,L1,A,F0.2,A,F0.2,A,I0)') "bloom: on=", cfg%bloom_on, &
            " thr=", cfg%bloom_threshold, " int=", cfg%bloom_intensity, &
            " mips=", cfg%bloom_mips
        call log_msg(LOG_INFO, trim(buf))
        write(buf, '(A,F0.2,A,F0.2)') "tonemap: exposure=", cfg%exposure, &
            " sun_mul=", cfg%sun_emissive_mul
        call log_msg(LOG_INFO, trim(buf))
        write(buf, '(A,I0,A,I0)') "starfield=", cfg%starfield_count, &
            " asteroids=", cfg%asteroid_count
        call log_msg(LOG_INFO, trim(buf))
    end subroutine config_toml_log

    !---------------------------------------------------------------
    ! Internal helpers
    !---------------------------------------------------------------

    subroutine strip_comment_and_trim(s)
        character(len=*), intent(inout) :: s
        integer :: i, hash_pos
        logical :: in_quote
        in_quote = .false.
        hash_pos = 0
        do i = 1, len(s)
            if (s(i:i) == '"') in_quote = .not. in_quote
            if (s(i:i) == "#" .and. .not. in_quote) then
                hash_pos = i
                exit
            end if
        end do
        if (hash_pos > 0) s(hash_pos:) = ""
        s = adjustl(s)
    end subroutine strip_comment_and_trim

    subroutine parse_section(line, section)
        character(len=*), intent(in) :: line
        character(len=*), intent(out) :: section
        integer :: rbr
        rbr = index(line, "]")
        if (rbr > 2) then
            section = adjustl(line(2:rbr-1))
        else
            section = ""
        end if
    end subroutine parse_section

    subroutine parse_key_value(line, key, value)
        character(len=*), intent(in) :: line
        character(len=*), intent(out) :: key, value
        integer :: eq
        eq = index(line, "=")
        if (eq < 2) then
            key = ""
            value = ""
            return
        end if
        key = adjustl(line(1:eq-1))
        value = adjustl(line(eq+1:))
        ! Trim trailing whitespace on both
        key   = trim(key)
        value = trim(value)
    end subroutine parse_key_value

    subroutine apply_pair(cfg, section, key, value, line_no)
        type(sim_config_t), intent(inout) :: cfg
        character(len=*), intent(in) :: section, key, value
        integer, intent(in) :: line_no
        logical :: handled
        integer :: iostat
        character(len=96) :: warn

        handled = .false.
        select case (section)
        case ("window")
            select case (key)
            case ("width");  read(value, *, iostat=iostat) cfg%window_width;  handled = .true.
            case ("height"); read(value, *, iostat=iostat) cfg%window_height; handled = .true.
            case ("vsync");  cfg%vsync = parse_bool(value);                   handled = .true.
            end select
        case ("simulation")
            select case (key)
            case ("speed_preset")
                read(value, *, iostat=iostat) cfg%speed_preset
                if (iostat == 0) call config_set_speed_preset(cfg, cfg%speed_preset)
                handled = .true.
            case ("time_scale")
                read(value, *, iostat=iostat) cfg%time_scale
                if (iostat == 0) call config_set_time_scale(cfg, cfg%time_scale)
                handled = .true.
            case ("trail_length");   read(value, *, iostat=iostat) cfg%trail_length;   handled = .true.
            case ("trails_visible"); cfg%trails_visible = parse_bool(value);           handled = .true.
            case ("hud_visible");    cfg%hud_visible    = parse_bool(value);           handled = .true.
            case ("focus_index");    read(value, *, iostat=iostat) cfg%focus_index;    handled = .true.
            end select
        case ("camera")
            select case (key)
            case ("azimuth");   read(value, *, iostat=iostat) cfg%camera_azimuth;   handled = .true.
            case ("elevation"); read(value, *, iostat=iostat) cfg%camera_elevation; handled = .true.
            case ("log_dist");  read(value, *, iostat=iostat) cfg%camera_log_dist;  handled = .true.
            end select
        case ("bloom")
            select case (key)
            case ("on");        cfg%bloom_on = parse_bool(value);                      handled = .true.
            case ("threshold"); read(value, *, iostat=iostat) cfg%bloom_threshold;    handled = .true.
            case ("intensity"); read(value, *, iostat=iostat) cfg%bloom_intensity;    handled = .true.
            case ("mips");      read(value, *, iostat=iostat) cfg%bloom_mips;         handled = .true.
            end select
        case ("tonemap")
            select case (key)
            case ("exposure");         read(value, *, iostat=iostat) cfg%exposure;         handled = .true.
            case ("sun_emissive_mul"); read(value, *, iostat=iostat) cfg%sun_emissive_mul; handled = .true.
            end select
        case ("starfield")
            select case (key)
            case ("count");     read(value, *, iostat=iostat) cfg%starfield_count;     handled = .true.
            case ("intensity"); read(value, *, iostat=iostat) cfg%starfield_intensity; handled = .true.
            end select
        case ("asteroids")
            select case (key)
            case ("count"); read(value, *, iostat=iostat) cfg%asteroid_count; handled = .true.
            case ("a_min"); read(value, *, iostat=iostat) cfg%asteroid_a_min; handled = .true.
            case ("a_max"); read(value, *, iostat=iostat) cfg%asteroid_a_max; handled = .true.
            end select
        case ("textures")
            select case (key)
            case ("earth_night");    cfg%load_earth_night    = parse_bool(value); handled = .true.
            case ("earth_normal");   cfg%load_earth_normal   = parse_bool(value); handled = .true.
            case ("earth_specular"); cfg%load_earth_specular = parse_bool(value); handled = .true.
            case ("saturn_rings");   cfg%load_saturn_rings   = parse_bool(value); handled = .true.
            end select
        end select

        if (.not. handled) then
            write(warn, '(A,I0,A)') "config.toml: unknown [", line_no, "] " // &
                trim(section) // "." // trim(key)
            call log_msg(LOG_WARN, trim(warn))
        end if
    end subroutine apply_pair

    pure function parse_bool(v) result(b)
        character(len=*), intent(in) :: v
        logical :: b
        character(len=8) :: lo
        integer :: i
        lo = ""
        do i = 1, min(len_trim(v), 8)
            lo(i:i) = lower(v(i:i))
        end do
        select case (trim(lo))
        case ("true", "t", "yes", "on", "1"); b = .true.
        case default; b = .false.
        end select
    end function parse_bool

    pure function lower(c) result(lc)
        character(len=1), intent(in) :: c
        character(len=1) :: lc
        integer :: ic
        ic = iachar(c)
        if (ic >= iachar("A") .and. ic <= iachar("Z")) then
            lc = achar(ic + 32)
        else
            lc = c
        end if
    end function lower

end module config_toml_mod
