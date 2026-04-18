!===============================================================================
! perf.f90 — Lightweight CPU timers for per-frame rendering/simulation sections.
!
! Stats are kept per named slot. Each slot records sample count, summed time,
! and running min/max; the shutdown report prints averages and peak.
!===============================================================================
module perf_mod
    use, intrinsic :: iso_fortran_env, only: real64, int64
    use logging, only: log_msg, LOG_INFO
    implicit none
    private

    public :: perf_slot_t, perf_tic, perf_toc, perf_report, perf_reset

    ! Keep the slot count small — named slots allocated at startup.
    integer, parameter, public :: PERF_MAX_SLOTS = 16

    type :: perf_slot_t
        character(len=32) :: name = ""
        integer(int64)    :: start_tick = 0
        integer(int64)    :: samples = 0
        real(real64)      :: sum_ms = 0.0_real64
        real(real64)      :: max_ms = 0.0_real64
    end type perf_slot_t

    type(perf_slot_t), save :: slots(PERF_MAX_SLOTS)
    integer, save :: n_slots = 0

contains

    ! Start timing a named slot. First call for a name allocates the slot.
    subroutine perf_tic(name)
        character(len=*), intent(in) :: name
        integer :: idx
        integer(int64) :: tick
        call get_or_create_slot(name, idx)
        call system_clock(count=tick)
        slots(idx)%start_tick = tick
    end subroutine perf_tic

    ! Stop timing; adds elapsed ms to the running sum.
    subroutine perf_toc(name)
        character(len=*), intent(in) :: name
        integer :: idx
        integer(int64) :: tick, rate
        real(real64) :: dt_ms
        call get_or_create_slot(name, idx)
        call system_clock(count=tick, count_rate=rate)
        if (rate == 0) return
        dt_ms = real(tick - slots(idx)%start_tick, real64) * 1000.0_real64 / real(rate, real64)
        slots(idx)%samples = slots(idx)%samples + 1_int64
        slots(idx)%sum_ms  = slots(idx)%sum_ms + dt_ms
        if (dt_ms > slots(idx)%max_ms) slots(idx)%max_ms = dt_ms
    end subroutine perf_toc

    subroutine perf_reset()
        integer :: i
        do i = 1, n_slots
            slots(i)%samples = 0_int64
            slots(i)%sum_ms = 0.0_real64
            slots(i)%max_ms = 0.0_real64
        end do
    end subroutine perf_reset

    ! Print all slots with average and peak ms.
    subroutine perf_report()
        integer :: i
        character(len=96) :: buf
        real(real64) :: avg_ms
        if (n_slots == 0) return
        call log_msg(LOG_INFO, "=== Performance report (averages per frame) ===")
        do i = 1, n_slots
            if (slots(i)%samples == 0) cycle
            avg_ms = slots(i)%sum_ms / real(slots(i)%samples, real64)
            write(buf, '(A,T22,A,F7.3,A,F7.3,A,I0,A)') &
                trim(slots(i)%name), "avg=", avg_ms, " ms  peak=", &
                slots(i)%max_ms, " ms  n=", slots(i)%samples, ""
            call log_msg(LOG_INFO, trim(buf))
        end do
    end subroutine perf_report

    subroutine get_or_create_slot(name, idx)
        character(len=*), intent(in) :: name
        integer, intent(out) :: idx
        integer :: i
        do i = 1, n_slots
            if (trim(slots(i)%name) == trim(name)) then
                idx = i
                return
            end if
        end do
        if (n_slots >= PERF_MAX_SLOTS) then
            idx = 1
            return
        end if
        n_slots = n_slots + 1
        slots(n_slots)%name = name
        idx = n_slots
    end subroutine get_or_create_slot

end module perf_mod
