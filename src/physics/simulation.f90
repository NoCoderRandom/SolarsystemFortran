!===============================================================================
! simulation.f90 — High-level simulation controller
!
! Owns the body array, the integrator, and exposes:
!   step(dt)            — advance by dt seconds
!   kinetic_energy()    — total KE = 0.5*sum(m*v^2)
!   potential_energy()  — total PE with softening
!   angular_momentum()  — total L = sum(m * r x v)
!   shutdown()          — deallocate
!===============================================================================
module simulation
    use, intrinsic :: iso_fortran_env, only: real64
    use vector3d, only: vec3, zero_vec3, norm, dot, cross, norm_squared, &
                        operator(-), operator(*), operator(+)
    use body_mod, only: body_t
    use integrator, only: integrator_t, velocity_verlet_t, &
                          compute_all_accelerations
    use constants, only: G_SI, DEFAULT_SOFTENING
    implicit none
    private

    public :: simulation_t

    !-----------------------------------------------------------------------
    ! Simulation state
    !-----------------------------------------------------------------------
    type, public :: simulation_t
        type(body_t), allocatable        :: bodies(:)
        class(integrator_t), allocatable :: integrator
        real(real64)                     :: softening = DEFAULT_SOFTENING
    contains
        procedure :: init              => sim_init
        procedure :: set_integrator    => sim_set_integrator
        procedure :: step              => sim_step
        procedure :: kinetic_energy    => sim_kinetic_energy
        procedure :: potential_energy  => sim_potential_energy
        procedure :: angular_momentum  => sim_angular_momentum
        procedure :: n_bodies          => sim_n_bodies
        procedure :: shutdown          => sim_shutdown
        procedure :: get_body_by_name  => sim_get_body_by_name
    end type simulation_t

contains

    !=====================================================================
    ! sim_init — allocate bodies and set up default Velocity Verlet
    !=====================================================================
    subroutine sim_init(this, bodies_in)
        class(simulation_t), intent(inout) :: this
        type(body_t), intent(in) :: bodies_in(:)

        integer :: n

        n = size(bodies_in)
        if (allocated(this%bodies)) deallocate(this%bodies)
        allocate(this%bodies(n), source=bodies_in)

        ! Default integrator: Velocity Verlet
        if (allocated(this%integrator)) deallocate(this%integrator)
        block
            type(velocity_verlet_t) :: vv
            vv%softening = this%softening
            allocate(this%integrator, source=vv)
        end block

        ! Compute initial accelerations
        call compute_initial_gravity(this)
    end subroutine sim_init

    !=====================================================================
    ! sim_set_integrator — replace the integrator (polymorphic)
    !=====================================================================
    subroutine sim_set_integrator(this, integ)
        class(simulation_t), intent(inout) :: this
        class(integrator_t), intent(in)    :: integ

        if (allocated(this%integrator)) deallocate(this%integrator)
        allocate(this%integrator, source=integ)
        this%softening = integ%softening

        ! Recompute accelerations with new softening
        call compute_initial_gravity(this)
    end subroutine sim_set_integrator

    !=====================================================================
    ! sim_step — advance simulation by dt seconds
    !=====================================================================
    subroutine sim_step(this, dt)
        class(simulation_t), intent(inout) :: this
        real(real64), intent(in)           :: dt

        call this%integrator%step(this%bodies, dt)
    end subroutine sim_step

    !=====================================================================
    ! sim_kinetic_energy — KE = 0.5 * sum(m_i * |v_i|^2)
    !=====================================================================
    function sim_kinetic_energy(this) result(ke)
        class(simulation_t), intent(in) :: this
        real(real64) :: ke
        integer :: i, n

        n = this%n_bodies()
        ke = 0.0_real64
        do i = 1, n
            ke = ke + 0.5_real64 * this%bodies(i)%mass * &
                 norm_squared(this%bodies(i)%velocity)
        end do
    end function sim_kinetic_energy

    !=====================================================================
    ! sim_potential_energy — PE = -0.5 * sum_pairs(G*m_i*m_j / sqrt(r2+eps^2))
    !=====================================================================
    function sim_potential_energy(this) result(pe)
        class(simulation_t), intent(in) :: this
        real(real64) :: pe
        integer :: i, j, n
        real(real64) :: r2, eps2, sep
        type(vec3) :: r_ij

        n = this%n_bodies()
        pe = 0.0_real64
        eps2 = this%softening * this%softening

        do i = 1, n - 1
            do j = i + 1, n
                r_ij = this%bodies(i)%position - this%bodies(j)%position
                r2 = norm_squared(r_ij) + eps2
                sep = sqrt(r2)
                pe = pe - G_SI * this%bodies(i)%mass * &
                     this%bodies(j)%mass / sep
            end do
        end do
    end function sim_potential_energy

    !=====================================================================
    ! sim_angular_momentum — L = sum(m_i * r_i x v_i)
    !=====================================================================
    function sim_angular_momentum(this) result(L)
        class(simulation_t), intent(in) :: this
        type(vec3) :: L
        integer :: i, n

        n = this%n_bodies()
        L = zero_vec3
        do i = 1, n
            L = L + this%bodies(i)%mass * &
                cross(this%bodies(i)%position, this%bodies(i)%velocity)
        end do
    end function sim_angular_momentum

    !=====================================================================
    ! sim_n_bodies — number of bodies
    !=====================================================================
    pure function sim_n_bodies(this) result(n)
        class(simulation_t), intent(in) :: this
        integer :: n
        if (allocated(this%bodies)) then
            n = size(this%bodies)
        else
            n = 0
        end if
    end function sim_n_bodies

    !=====================================================================
    ! sim_shutdown — deallocate
    !=====================================================================
    subroutine sim_shutdown(this)
        class(simulation_t), intent(inout) :: this
        if (allocated(this%bodies)) deallocate(this%bodies)
        if (allocated(this%integrator)) deallocate(this%integrator)
    end subroutine sim_shutdown

    !=====================================================================
    ! sim_get_body_by_name — find body index by name
    !=====================================================================
    function sim_get_body_by_name(this, name) result(idx)
        class(simulation_t), intent(in) :: this
        character(len=*), intent(in) :: name
        integer :: idx
        integer :: i, n

        n = this%n_bodies()
        idx = 0
        do i = 1, n
            if (trim(this%bodies(i)%name) == trim(name)) then
                idx = i
                return
            end if
        end do
    end function sim_get_body_by_name

    !=====================================================================
    ! Private helper: compute initial gravity
    !=====================================================================
    subroutine compute_initial_gravity(this)
        class(simulation_t), intent(inout) :: this

        call compute_all_accelerations(this%bodies, this%softening)
    end subroutine compute_initial_gravity

end module simulation
