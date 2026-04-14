!===============================================================================
! date_utils.f90 — J2000 epoch + seconds → Gregorian calendar date
!
! Simple iterative approach: count days from J2000, handle leap years
! by checking each year. This is O(years) but for solar system sims
! we won't go millions of years forward.
!===============================================================================
module date_utils
    use, intrinsic :: iso_fortran_env, only: real64
    implicit none
    private

    public :: sim_date_t, j2000_to_date

    type, public :: sim_date_t
        integer :: year  = 2000
        integer :: month = 1
        integer :: day   = 1
        integer :: hour  = 12
        integer :: minute = 0
        real(real64) :: second = 0.0_real64
    end type sim_date_t

    integer, parameter :: days_in_month(12) = [31, 28, 31, 30, 31, 30, &
                                                31, 31, 30, 31, 30, 31]

contains

    pure logical function is_leap_year(y) result(r)
        integer, intent(in) :: y
        r = (mod(y, 4) == 0 .and. mod(y, 100) /= 0) .or. mod(y, 400) == 0
    end function is_leap_year

    pure function days_in_year(y) result(d)
        integer, intent(in) :: y
        integer :: d
        if (is_leap_year(y)) then
            d = 366
        else
            d = 365
        end if
    end function days_in_year

    pure subroutine j2000_to_date(sim_seconds, result_date)
        real(real64), intent(in) :: sim_seconds
        type(sim_date_t), intent(out) :: result_date

        integer :: total_days, remaining, y, m, dim
        real(real64) :: frac

        ! J2000.0 = 2000-01-01 12:00:00
        total_days = int(sim_seconds / 86400.0_real64)
        frac = (sim_seconds / 86400.0_real64) - real(total_days, real64)

        ! Start from 2000-01-01
        y = 2000
        remaining = total_days

        ! Advance years
        do while (remaining >= days_in_year(y))
            remaining = remaining - days_in_year(y)
            y = y + 1
        end do

        ! Handle fractional day (J2000 starts at noon = 0.5 day offset)
        frac = frac + 0.5_real64
        if (frac >= 1.0_real64) then
            frac = frac - 1.0_real64
            remaining = remaining + 1
        end if

        result_date%year = y

        ! Handle February days for leap year
        if (is_leap_year(y)) then
            dim = 29
        else
            dim = 28
        end if

        ! Advance months
        m = 1
        do while (m <= 12)
            if (m == 2) then
                if (remaining >= dim) then
                    remaining = remaining - dim
                    m = m + 1
                else
                    exit
                end if
            else
                if (remaining >= days_in_month(m)) then
                    remaining = remaining - days_in_month(m)
                    m = m + 1
                else
                    exit
                end if
            end if
        end do

        result_date%month = m
        result_date%day = remaining + 1

        ! Time of day
        result_date%hour = int(frac * 24.0_real64)
        result_date%minute = int((frac * 24.0_real64 - real(result_date%hour, real64)) * 60.0_real64)
        result_date%second = ((frac * 24.0_real64 - real(result_date%hour, real64)) * 60.0_real64 - &
                              real(result_date%minute, real64)) * 60.0_real64
    end subroutine j2000_to_date

end module date_utils
