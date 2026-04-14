!===============================================================================
! test_date_utils.f90 — Unit test for J2000 → Gregorian date conversion
!===============================================================================
program test_date_utils
    use, intrinsic :: iso_fortran_env, only: real64, output_unit
    use date_utils, only: sim_date_t, j2000_to_date
    use constants, only: SEC_PER_DAY
    implicit none

    type(sim_date_t) :: d
    integer :: errors

    errors = 0

    call print_sep()
    call log("=== Date Utils Test ===")

    ! Test 1: J2000 epoch (0 seconds) → 2000-01-01 12:00:00
    call j2000_to_date(0.0_real64, d)
    call check("J2000 epoch", d%year == 2000 .and. d%month == 1 .and. d%day == 1 .and. &
               d%hour == 12, d)
    if (d%year /= 2000 .or. d%month /= 1 .or. d%day /= 1 .or. d%hour /= 12) errors = errors + 1

    ! Test 2: 1 day later → 2000-01-02 12:00:00
    call j2000_to_date(SEC_PER_DAY, d)
    call check("J2000 + 1 day", d%year == 2000 .and. d%month == 1 .and. d%day == 2 .and. &
               d%hour == 12, d)
    if (d%year /= 2000 .or. d%month /= 1 .or. d%day /= 2 .or. d%hour /= 12) errors = errors + 1

    ! Test 3: Leap year 2000 (divisible by 400 → IS a leap year)
    ! 2000-02-29 should exist
    ! Days from 2000-01-01 to 2000-02-29 = 31 (Jan) + 28 = 59 days
    call j2000_to_date(59.0_real64 * SEC_PER_DAY, d)
    call check("2000-02-29 (leap year)", d%year == 2000 .and. d%month == 2 .and. d%day == 29, d)
    if (d%year /= 2000 .or. d%month /= 2 .or. d%day /= 29) errors = errors + 1

    ! Test 4: Non-leap year 2001: 2001-03-01 should be 425 days from J2000
    ! 2000 is leap (366 days), so 2000-01-01 to 2001-01-01 = 366 days
    ! 2001-01-01 to 2001-03-01 = 31 + 28 = 59 days → total 425
    call j2000_to_date(425.0_real64 * SEC_PER_DAY, d)
    call check("2001-03-01 (non-leap)", d%year == 2001 .and. d%month == 3 .and. d%day == 1, d)
    if (d%year /= 2001 .or. d%month /= 3 .or. d%day /= 1) errors = errors + 1

    ! Test 5: 2100 is NOT a leap year (divisible by 100 but not 400)
    ! 2000-01-01 to 2100-01-01 = 36525 days (25 leap years: 2000, 2004, ..., 2096)
    ! 2100-01-01 to 2100-03-01 = 31 + 28 = 59 → total 36584
    call j2000_to_date(36584.0_real64 * SEC_PER_DAY, d)
    call check("2100-03-01 (non-leap century)", d%year == 2100 .and. d%month == 3 .and. d%day == 1, d)
    if (d%year /= 2100 .or. d%month /= 3 .or. d%day /= 1) errors = errors + 1

    ! Test 6: Year 2000 is leap, 2000-03-01 = 60 days after Jan 1
    call j2000_to_date(60.0_real64 * SEC_PER_DAY, d)
    call check("2000-03-01", d%year == 2000 .and. d%month == 3 .and. d%day == 1, d)
    if (d%year /= 2000 .or. d%month /= 3 .or. d%day /= 1) errors = errors + 1

    call print_sep()
    if (errors == 0) then
        call log("ALL TESTS PASSED (6/6)")
    else
        call log("FAILURES: " // itoa(errors))
    end if
    call print_sep()

contains

    subroutine check(name, passed, date)
        character(len=*), intent(in) :: name
        logical, intent(in) :: passed
        type(sim_date_t), intent(in) :: date
        if (passed) then
            call log("  PASS: " // trim(name) // " → " // fmt_date(date))
        else
            call log("  FAIL: " // trim(name) // " → expected different date, got " // fmt_date(date))
        end if
    end subroutine check

    pure function fmt_date(dt) result(s)
        type(sim_date_t), intent(in) :: dt
        character(len=32) :: s
        write(s, "(I4.4,'-',I2.2,'-',I2.2,' ',I2.2,':',I2.2,':',I2.2)") &
            dt%year, dt%month, dt%day, dt%hour, dt%minute, int(dt%second)
    end function fmt_date

    pure function itoa(i) result(s)
        integer, intent(in) :: i
        character(len=12) :: s
        write(s, "(I0)") i
    end function itoa

    subroutine log(msg)
        character(len=*), intent(in) :: msg
        write(output_unit, "(A)") trim(msg)
        flush(unit=output_unit)
    end subroutine log

    subroutine print_sep()
        write(output_unit, "(A)") "============================================================"
        flush(unit=output_unit)
    end subroutine print_sep

end program test_date_utils
