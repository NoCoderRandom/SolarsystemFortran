program test_spacecraft_controls
    use, intrinsic :: iso_c_binding, only: c_float
    use config_mod, only: sim_config_t
    use spacecraft_mod, only: spacecraft_system_t, spacecraft_control_selected, &
                              spacecraft_system_sync_config
    implicit none

    type(spacecraft_system_t) :: sys
    type(sim_config_t) :: cfg

    call test_thrust_accumulates_velocity()
    call test_sync_config_does_not_rearm_anchor_every_frame()
    call test_sync_config_does_not_respawn_despawned_ship()
    print *, "test_spacecraft_controls: OK"

contains

    subroutine test_thrust_accumulates_velocity()
        sys%initialized = .true.
        allocate(sys%craft(1))
        sys%selected_index = 1
        sys%craft(1)%active = .true.

        call spacecraft_control_selected(sys, 0.5_c_float, 1.0_c_float, 0.0_c_float, 0.0_c_float, 0.0_c_float)

        call assert_true(any(abs(sys%craft(1)%velocity_au) > 1.0e-6_c_float), &
                         "thrust should change spacecraft velocity")
        deallocate(sys%craft)
    end subroutine test_thrust_accumulates_velocity

    subroutine test_sync_config_does_not_rearm_anchor_every_frame()
        cfg%spacecraft_enabled = .true.
        cfg%spacecraft_auto_stabilize = .true.
        cfg%spacecraft_spawn_preset = "earth"

        sys%initialized = .true.
        sys%enabled = .true.
        allocate(sys%craft(1))
        sys%selected_index = 1
        sys%craft(1)%active = .true.
        sys%craft(1)%pending_anchor_reset = .false.
        sys%craft(1)%def%spawn_preset = "earth"

        call spacecraft_system_sync_config(sys, cfg)
        call assert_false(sys%craft(1)%pending_anchor_reset, &
                          "config sync should not force anchor reset on an already-active craft")

        deallocate(sys%craft)
    end subroutine test_sync_config_does_not_rearm_anchor_every_frame

    subroutine test_sync_config_does_not_respawn_despawned_ship()
        cfg%spacecraft_enabled = .true.
        cfg%spacecraft_auto_stabilize = .true.
        cfg%spacecraft_spawn_preset = "earth"

        sys%initialized = .true.
        sys%enabled = .true.
        allocate(sys%craft(1))
        sys%selected_index = 1
        sys%craft(1)%active = .false.
        sys%craft(1)%pending_anchor_reset = .false.
        sys%craft(1)%def%spawn_preset = "earth"

        call spacecraft_system_sync_config(sys, cfg)
        call assert_false(sys%craft(1)%active, &
                          "config sync should not respawn a ship the user despawned")
        call assert_false(sys%craft(1)%pending_anchor_reset, &
                          "config sync should not queue anchor reset for a despawned ship")

        deallocate(sys%craft)
    end subroutine test_sync_config_does_not_respawn_despawned_ship

    subroutine assert_true(condition, message)
        logical, intent(in) :: condition
        character(len=*), intent(in) :: message

        if (.not. condition) then
            print *, "FAIL:", trim(message)
            stop 1
        end if
    end subroutine assert_true

    subroutine assert_false(condition, message)
        logical, intent(in) :: condition
        character(len=*), intent(in) :: message

        call assert_true(.not. condition, message)
    end subroutine assert_false

end program test_spacecraft_controls
