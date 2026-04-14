!===============================================================================
! integrator.f90 — Abstract integrator interface + Velocity Verlet
!
! Design: the integrator encapsulates the time-stepping algorithm.
! Adding RK4, leapfrog, or symplectic methods later requires only a new
! type extending integrator_t — callers never change.
!
! Gravity computation lives here so the integrator is self-contained.
! The O(n^2) force loop uses `do concurrent` for potential parallelism.
!===============================================================================
module integrator
    use, intrinsic :: iso_fortran_env, only: real64
    use vector3d, only: vec3, zero_vec3, norm_squared, &
                        operator(-), operator(+), operator(*)
    use body_mod, only: body_t
    use constants, only: G_SI
    implicit none
    private

    public :: integrator_t, velocity_verlet_t
    public :: compute_all_accelerations

    !-----------------------------------------------------------------------
    ! Abstract integrator base type
    !-----------------------------------------------------------------------
    type, abstract, public :: integrator_t
        real(real64) :: softening = 1.0e6_real64  ! m
    contains
        procedure(step_iface), deferred :: step
    end type integrator_t

    !-----------------------------------------------------------------------
    ! Concrete Velocity Verlet (leapfrog in position-velocity form)
    !-----------------------------------------------------------------------
    type, extends(integrator_t), public :: velocity_verlet_t
    contains
        procedure :: step => verlet_step
    end type velocity_verlet_t

    !-----------------------------------------------------------------------
    ! Abstract interface for the step method
    !-----------------------------------------------------------------------
    abstract interface
        subroutine step_iface(this, bodies, dt)
            import :: integrator_t, body_t, real64
            class(integrator_t), intent(inout) :: this
            type(body_t), intent(inout) :: bodies(:)
            real(real64), intent(in) :: dt
        end subroutine step_iface
    end interface

contains

    !=====================================================================
    ! Velocity Verlet step
    !
    ! 1. x(t+dt) = x(t) + v(t)*dt + 0.5*a(t)*dt^2
    ! 2. a(t+dt) = F(x(t+dt)) / m     (recompute gravity)
    ! 3. v(t+dt) = v(t) + 0.5*(a(t)+a(t+dt))*dt
    !
    ! This is a symplectic (time-reversible) integrator that conserves
    ! energy and angular momentum to O(dt^2) per step, O(1) over long
    ! times (bounded oscillation, no secular drift).
    !=====================================================================
    subroutine verlet_step(this, bodies, dt)
        class(velocity_verlet_t), intent(inout) :: this
        type(body_t), intent(inout) :: bodies(:)
        real(real64), intent(in) :: dt

        type(vec3), allocatable :: acc_old(:)
        integer :: n, i
        real(real64) :: dt2_half

        n = size(bodies)
        allocate(acc_old(n))

        ! Save current accelerations
        do i = 1, n
            acc_old(i) = bodies(i)%acceleration
        end do

        ! Stage 1: Update positions
        !   x(t+dt) = x(t) + v(t)*dt + 0.5*a(t)*dt^2
        dt2_half = 0.5_real64 * dt * dt
        do i = 1, n
            bodies(i)%position = bodies(i)%position + &
                bodies(i)%velocity * dt + acc_old(i) * dt2_half
        end do

        ! Stage 2: Recompute accelerations from new positions
        call compute_all_accelerations(bodies, this%softening)

        ! Stage 3: Update velocities
        !   v(t+dt) = v(t) + 0.5*(a(t)+a(t+dt))*dt
        do i = 1, n
            bodies(i)%velocity = bodies(i)%velocity + &
                0.5_real64 * (acc_old(i) + bodies(i)%acceleration) * dt
        end do

        deallocate(acc_old)
    end subroutine verlet_step

    !=====================================================================
    ! Compute gravitational accelerations for all bodies
    !
    ! Newtonian pairwise force with softening:
    !   a_i = -G * sum_{j≠i} m_j * r_ij / (|r_ij|^2 + eps^2)^(3/2)
    !
    ! Uses `do concurrent` on the outer loop — each iteration computes
    ! one body's acceleration independently by calling a pure function.
    ! This is O(n^2) but clean, parallelizable, and correct.
    !=====================================================================
    subroutine compute_all_accelerations(bodies, softening)
        type(body_t), intent(inout) :: bodies(:)
        real(real64), intent(in) :: softening

        integer :: n, i

        n = size(bodies)
        do concurrent (i = 1:n)
            bodies(i)%acceleration = &
                compute_body_acceleration(i, bodies, softening)
        end do
    end subroutine compute_all_accelerations

    !=====================================================================
    ! Pure function: gravitational acceleration on body i from all others
    !=====================================================================
    pure function compute_body_acceleration(i, bodies, softening) &
            result(acc)
        integer, intent(in) :: i
        type(body_t), intent(in) :: bodies(:)
        real(real64), intent(in) :: softening
        type(vec3) :: acc

        integer :: j, n
        real(real64) :: r2, eps2, inv_r3, coeff
        type(vec3) :: r_ij

        n = size(bodies)
        acc = zero_vec3
        eps2 = softening * softening

        do j = 1, n
            if (i /= j) then
                r_ij = bodies(i)%position - bodies(j)%position
                r2 = norm_squared(r_ij) + eps2
                inv_r3 = 1.0_real64 / (r2 * sqrt(r2))
                coeff = G_SI * bodies(j)%mass * inv_r3
                acc = acc - r_ij * coeff
            end if
        end do
    end function compute_body_acceleration

end module integrator
