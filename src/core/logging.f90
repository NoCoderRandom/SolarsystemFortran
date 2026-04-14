!===============================================================================
! logging.f90 — Colored, timestamped logging with DEBUG/INFO/WARN/ERROR levels
!===============================================================================
module logging
    use, intrinsic :: iso_fortran_env, only: output_unit
    implicit none
    private

    public :: log_level_t
    public :: log_init, log_shutdown, log_msg
    public :: LOG_DEBUG, LOG_INFO, LOG_WARN, LOG_ERROR

    !-----------------------------------------------------------------------
    ! Log severity levels
    !-----------------------------------------------------------------------
    integer, parameter :: LOG_DEBUG = 0
    integer, parameter :: LOG_INFO  = 1
    integer, parameter :: LOG_WARN  = 2
    integer, parameter :: LOG_ERROR = 3

    type, public :: log_level_t
        integer :: threshold = LOG_INFO  ! minimum level to display
    end type log_level_t

    ! Module-private state
    type(log_level_t), save :: log_state
    logical, save          :: log_initialized = .false.

    ! ANSI color codes
    character(len=*), parameter :: COLOR_RESET  = char(27) // "[0m"
    character(len=*), parameter :: COLOR_DEBUG  = char(27) // "[36m"  ! cyan
    character(len=*), parameter :: COLOR_INFO   = char(27) // "[32m"  ! green
    character(len=*), parameter :: COLOR_WARN   = char(27) // "[33m"  ! yellow
    character(len=*), parameter :: COLOR_ERROR  = char(27) // "[31m"  ! red
    character(len=*), parameter :: COLOR_LEVEL  = char(27) // "[1m"   ! bold

contains

    !=====================================================================
    ! log_init — set the minimum log level (default: INFO)
    !=====================================================================
    subroutine log_init(threshold)
        integer, intent(in), optional :: threshold
        integer :: lvl

        if (present(threshold)) then
            lvl = threshold
        else
            lvl = LOG_INFO
        end if

        log_state%threshold = lvl
        log_initialized = .true.

        call log_msg(LOG_INFO, "Logging initialized (threshold=" // &
                     level_name(lvl) // ")")
    end subroutine log_init

    !=====================================================================
    ! log_shutdown — clean up (currently a no-op, reserved for future use)
    !=====================================================================
    subroutine log_shutdown()
        if (.not. log_initialized) return
        call log_msg(LOG_INFO, "Logging shut down")
        log_initialized = .false.
    end subroutine log_shutdown

    !=====================================================================
    ! log_msg — emit a log line if level >= threshold
    !=====================================================================
    subroutine log_msg(level, message)
        integer, intent(in) :: level
        character(len=*), intent(in) :: message
        character(len=32) :: ts
        character(len=8)  :: lvl_str

        if (.not. log_initialized) return
        if (level < log_state%threshold) return

        ts = get_timestamp()
        lvl_str = level_name(level)

        ! Build the colored output line:
        !   [TIMESTAMP] [BOLD LEVEL] message
        if (level == LOG_DEBUG) then
            write(*, "(A)", advance="no") COLOR_RESET // COLOR_DEBUG
        else if (level == LOG_INFO) then
            write(*, "(A)", advance="no") COLOR_RESET // COLOR_INFO
        else if (level == LOG_WARN) then
            write(*, "(A)", advance="no") COLOR_RESET // COLOR_WARN
        else if (level == LOG_ERROR) then
            write(*, "(A)", advance="no") COLOR_RESET // COLOR_ERROR
        end if

        write(*, "(A)", advance="no") "[" // ts // "] "
        write(*, "(A)", advance="no") COLOR_LEVEL // "[" // lvl_str // "]"
        write(*, "(A)", advance="no") COLOR_RESET // " " // message // new_line("A")

        ! Flush so output is visible in real-time
        flush(unit=output_unit)
    end subroutine log_msg

    !=====================================================================
    ! level_name — human-readable level string
    !=====================================================================
    pure function level_name(level) result(name)
        integer, intent(in) :: level
        character(len=8) :: name

        select case (level)
        case (LOG_DEBUG); name = "DEBUG"
        case (LOG_INFO);  name = "INFO"
        case (LOG_WARN);  name = "WARN"
        case (LOG_ERROR); name = "ERROR"
        case default;     name = "UNKNOWN"
        end select
    end function level_name

    !=====================================================================
    ! get_timestamp — ISO 8601 wall-clock timestamp (UTC)
    !=====================================================================
    function get_timestamp() result(ts)
        character(len=32) :: ts
        integer :: values(8)
        character(len=10) :: date_str
        character(len=8)  :: time_str

        call date_and_time(date=date_str, time=time_str, values=values)

        ! Format: YYYY-MM-DDTHH:MM:SS.sss
        write(ts, "(I4.4,'-',I2.2,'-',I2.2,'T',I2.2,':',I2.2,':',I2.2,'.',I3.3)") &
            values(1), values(2), values(3), &
            values(5), values(6), values(7), values(8)
    end function get_timestamp

end module logging
