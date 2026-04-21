module spacecraft_mod
    use, intrinsic :: iso_fortran_env, only: real64
    use config_mod, only: sim_config_t
    use, intrinsic :: iso_c_binding, only: c_float
    use body_mod, only: body_t
    use logging, only: log_msg, LOG_INFO
    use spacecraft_types_mod, only: spacecraft_definition_t, spacecraft_instance_t
    use spacecraft_catalog_mod, only: spacecraft_catalog_entry_t, &
                                      spacecraft_catalog_default, SPACECRAFT_CATALOG_COUNT
    use spacecraft_renderer_mod, only: spacecraft_renderer_t, &
                                       spacecraft_renderer_init, &
                                       spacecraft_renderer_set_model, &
                                       spacecraft_renderer_clear_model, &
                                       spacecraft_renderer_render, &
                                       spacecraft_renderer_shutdown
    use camera_mod, only: camera_t
    implicit none
    private

    public :: spacecraft_system_t
    public :: spacecraft_system_init, spacecraft_system_sync_config
    public :: spacecraft_system_update, spacecraft_system_render
    public :: spacecraft_system_shutdown, spacecraft_system_select
    public :: spacecraft_selected_name, spacecraft_selected_id
    public :: spacecraft_count, spacecraft_name_at
    public :: spacecraft_franchise_at
    public :: spacecraft_selected_available
    public :: spacecraft_select_next, spacecraft_select_prev
    public :: spacecraft_spawn_selected, spacecraft_reset_selected
    public :: spacecraft_despawn_selected, spacecraft_selected_spawned
    public :: spacecraft_selected_position_au, spacecraft_selected_has_target
    public :: spacecraft_control_selected, spacecraft_toggle_auto_stabilize_selected
    public :: spacecraft_look_selected
    public :: spacecraft_selected_speed_au, spacecraft_selected_auto_stabilize
    public :: spacecraft_selected_orientation
    public :: spacecraft_selected_follow_tuning
    public :: spacecraft_set_spawn_preset_selected, spacecraft_selected_spawn_preset

    type, public :: spacecraft_system_t
        logical :: enabled = .false.
        logical :: initialized = .false.
        integer :: selected_index = 0
        type(spacecraft_renderer_t) :: renderer
        type(spacecraft_instance_t), allocatable :: craft(:)
    end type spacecraft_system_t

contains

    subroutine spacecraft_system_init(sys, cfg)
        type(spacecraft_system_t), intent(out) :: sys
        type(sim_config_t), intent(in) :: cfg

        call spacecraft_renderer_init(sys%renderer)
        call seed_framework_catalog(sys)
        sys%enabled = cfg%spacecraft_enabled
        sys%selected_index = 0
        sys%initialized = .true.
        if (allocated(sys%craft) .and. size(sys%craft) > 0) &
            sys%selected_index = selected_index_from_cfg(sys, cfg)
        call apply_cfg_defaults(sys, cfg)
        call activate_selected_if_enabled(sys)
        call sync_selected_model(sys)

        if (sys%enabled) then
            call log_msg(LOG_INFO, "Spacecraft system enabled")
        else
            call log_msg(LOG_INFO, "Spacecraft system available but disabled")
        end if
    end subroutine spacecraft_system_init

    subroutine spacecraft_system_sync_config(sys, cfg)
        type(spacecraft_system_t), intent(inout) :: sys
        type(sim_config_t), intent(in) :: cfg
        logical :: was_enabled

        if (.not. sys%initialized) return
        was_enabled = sys%enabled
        sys%enabled = cfg%spacecraft_enabled
        call apply_cfg_defaults(sys, cfg)
        if (sys%enabled .neqv. was_enabled) then
            if (sys%enabled) call activate_selected_if_enabled(sys)
            call sync_selected_model(sys)
        end if
    end subroutine spacecraft_system_sync_config

    subroutine spacecraft_system_update(sys, dt, sim_time, bodies)
        type(spacecraft_system_t), intent(inout) :: sys
        real(real64), intent(in) :: dt, sim_time
        type(body_t), intent(in) :: bodies(:)
        integer :: i

        if (.not. sys%initialized) return
        if (.not. sys%enabled) return

        if (dt < 0.0_real64 .or. sim_time < 0.0_real64) return
        do i = 1, size(sys%craft)
            call update_spacecraft_anchor(sys%craft(i), bodies, real(dt, c_float))
        end do
    end subroutine spacecraft_system_update

    subroutine spacecraft_system_render(sys, cam, light_pos)
        type(spacecraft_system_t), intent(inout) :: sys
        type(camera_t), intent(in) :: cam
        real(c_float), intent(in) :: light_pos(3)

        if (.not. sys%initialized) return
        if (.not. sys%enabled) return
        if (sys%selected_index < 1 .or. sys%selected_index > size(sys%craft)) return
        if (.not. sys%craft(sys%selected_index)%active) return
        call spacecraft_renderer_render(sys%renderer, cam, light_pos, &
                                        sys%craft(sys%selected_index)%world_pos_au, &
                                        sys%craft(sys%selected_index)%def%visual_scale, &
                                        sys%craft(sys%selected_index)%def%model_pitch, &
                                        sys%craft(sys%selected_index)%def%model_yaw)
    end subroutine spacecraft_system_render

    subroutine spacecraft_system_shutdown(sys)
        type(spacecraft_system_t), intent(inout) :: sys

        if (.not. sys%initialized) return
        if (allocated(sys%craft)) deallocate(sys%craft)
        call spacecraft_renderer_shutdown(sys%renderer)
        sys%selected_index = 0
        sys%enabled = .false.
        sys%initialized = .false.
    end subroutine spacecraft_system_shutdown

    subroutine spacecraft_system_select(sys, idx)
        type(spacecraft_system_t), intent(inout) :: sys
        integer, intent(in) :: idx

        if (.not. sys%initialized) return
        if (.not. allocated(sys%craft)) then
            sys%selected_index = 0
            return
        end if

        if (idx < 1 .or. idx > size(sys%craft)) then
            sys%selected_index = 0
            call spacecraft_renderer_clear_model(sys%renderer)
        else
            sys%selected_index = idx
            call sync_selected_model(sys)
            if (.not. sys%craft(idx)%active .and. sys%enabled) then
                sys%craft(idx)%active = .true.
            end if
        end if
    end subroutine spacecraft_system_select

    function spacecraft_selected_name(sys) result(name)
        type(spacecraft_system_t), intent(in) :: sys
        character(len=64) :: name

        name = ""
        if (.not. allocated(sys%craft)) return
        if (sys%selected_index < 1 .or. sys%selected_index > size(sys%craft)) return
        name = sys%craft(sys%selected_index)%def%display_name
    end function spacecraft_selected_name

    function spacecraft_selected_id(sys) result(id)
        type(spacecraft_system_t), intent(in) :: sys
        character(len=64) :: id

        id = ""
        if (.not. allocated(sys%craft)) return
        if (sys%selected_index < 1 .or. sys%selected_index > size(sys%craft)) return
        id = sys%craft(sys%selected_index)%def%id
    end function spacecraft_selected_id

    logical function spacecraft_selected_available(sys) result(v)
        type(spacecraft_system_t), intent(in) :: sys

        v = .false.
        if (.not. allocated(sys%craft)) return
        if (sys%selected_index < 1 .or. sys%selected_index > size(sys%craft)) return
        v = .true.
    end function spacecraft_selected_available

    integer function spacecraft_count(sys) result(n)
        type(spacecraft_system_t), intent(in) :: sys
        n = 0
        if (allocated(sys%craft)) n = size(sys%craft)
    end function spacecraft_count

    function spacecraft_name_at(sys, idx) result(name)
        type(spacecraft_system_t), intent(in) :: sys
        integer, intent(in) :: idx
        character(len=64) :: name

        name = ""
        if (.not. allocated(sys%craft)) return
        if (idx < 1 .or. idx > size(sys%craft)) return
        name = sys%craft(idx)%def%display_name
    end function spacecraft_name_at

    function spacecraft_franchise_at(sys, idx) result(name)
        type(spacecraft_system_t), intent(in) :: sys
        integer, intent(in) :: idx
        character(len=32) :: name

        name = ""
        if (.not. allocated(sys%craft)) return
        if (idx < 1 .or. idx > size(sys%craft)) return
        name = sys%craft(idx)%def%franchise
    end function spacecraft_franchise_at

    subroutine spacecraft_spawn_selected(sys, focus_index)
        type(spacecraft_system_t), intent(inout) :: sys
        integer, intent(in), optional :: focus_index
        if (.not. allocated(sys%craft)) return
        if (sys%selected_index < 1 .or. sys%selected_index > size(sys%craft)) return
        sys%craft(sys%selected_index)%active = .true.
        sys%craft(sys%selected_index)%parent_body_index = parent_index_for_preset( &
            sys%craft(sys%selected_index)%def%spawn_preset, focus_index)
        sys%craft(sys%selected_index)%pending_anchor_reset = .true.
    end subroutine spacecraft_spawn_selected

    subroutine spacecraft_select_next(sys)
        type(spacecraft_system_t), intent(inout) :: sys
        integer :: next_idx

        if (.not. allocated(sys%craft)) return
        if (size(sys%craft) == 0) return
        next_idx = sys%selected_index + 1
        if (next_idx > size(sys%craft) .or. next_idx < 1) next_idx = 1
        call spacecraft_system_select(sys, next_idx)
    end subroutine spacecraft_select_next

    subroutine spacecraft_select_prev(sys)
        type(spacecraft_system_t), intent(inout) :: sys
        integer :: prev_idx

        if (.not. allocated(sys%craft)) return
        if (size(sys%craft) == 0) return
        prev_idx = sys%selected_index - 1
        if (prev_idx < 1 .or. prev_idx > size(sys%craft)) prev_idx = size(sys%craft)
        call spacecraft_system_select(sys, prev_idx)
    end subroutine spacecraft_select_prev

    subroutine spacecraft_reset_selected(sys, focus_index)
        type(spacecraft_system_t), intent(inout) :: sys
        integer, intent(in), optional :: focus_index
        if (.not. allocated(sys%craft)) return
        if (sys%selected_index < 1 .or. sys%selected_index > size(sys%craft)) return
        sys%craft(sys%selected_index)%active = .true.
        sys%craft(sys%selected_index)%velocity_au = 0.0_c_float
        sys%craft(sys%selected_index)%yaw = 0.0_c_float
        sys%craft(sys%selected_index)%pitch = 0.0_c_float
        sys%craft(sys%selected_index)%roll = 0.0_c_float
        sys%craft(sys%selected_index)%yaw_rate = 0.0_c_float
        sys%craft(sys%selected_index)%pitch_rate = 0.0_c_float
        sys%craft(sys%selected_index)%roll_rate = 0.0_c_float
        sys%craft(sys%selected_index)%parent_body_index = parent_index_for_preset( &
            sys%craft(sys%selected_index)%def%spawn_preset, focus_index)
        sys%craft(sys%selected_index)%pending_anchor_reset = .true.
    end subroutine spacecraft_reset_selected

    subroutine spacecraft_despawn_selected(sys)
        type(spacecraft_system_t), intent(inout) :: sys
        if (.not. allocated(sys%craft)) return
        if (sys%selected_index < 1 .or. sys%selected_index > size(sys%craft)) return
        sys%craft(sys%selected_index)%active = .false.
    end subroutine spacecraft_despawn_selected

    logical function spacecraft_selected_spawned(sys) result(v)
        type(spacecraft_system_t), intent(in) :: sys
        v = .false.
        if (.not. allocated(sys%craft)) return
        if (sys%selected_index < 1 .or. sys%selected_index > size(sys%craft)) return
        v = sys%craft(sys%selected_index)%active
    end function spacecraft_selected_spawned

    logical function spacecraft_selected_has_target(sys) result(v)
        type(spacecraft_system_t), intent(in) :: sys
        v = .false.
        if (.not. allocated(sys%craft)) return
        if (sys%selected_index < 1 .or. sys%selected_index > size(sys%craft)) return
        v = sys%craft(sys%selected_index)%active
    end function spacecraft_selected_has_target

    function spacecraft_selected_position_au(sys) result(pos)
        type(spacecraft_system_t), intent(in) :: sys
        real(c_float) :: pos(3)
        pos = 0.0_c_float
        if (.not. allocated(sys%craft)) return
        if (sys%selected_index < 1 .or. sys%selected_index > size(sys%craft)) return
        pos = sys%craft(sys%selected_index)%world_pos_au
    end function spacecraft_selected_position_au

    subroutine spacecraft_selected_orientation(sys, yaw, pitch, roll)
        type(spacecraft_system_t), intent(in) :: sys
        real(c_float), intent(out) :: yaw, pitch, roll

        yaw = 0.0_c_float
        pitch = 0.0_c_float
        roll = 0.0_c_float
        if (.not. allocated(sys%craft)) return
        if (sys%selected_index < 1 .or. sys%selected_index > size(sys%craft)) return
        yaw = sys%craft(sys%selected_index)%yaw
        pitch = sys%craft(sys%selected_index)%pitch
        roll = sys%craft(sys%selected_index)%roll
    end subroutine spacecraft_selected_orientation

    subroutine spacecraft_selected_follow_tuning(sys, follow_distance, follow_height)
        type(spacecraft_system_t), intent(in) :: sys
        real(c_float), intent(out) :: follow_distance, follow_height

        follow_distance = 0.18_c_float
        follow_height = 0.05_c_float
        if (.not. allocated(sys%craft)) return
        if (sys%selected_index < 1 .or. sys%selected_index > size(sys%craft)) return
        follow_distance = sys%craft(sys%selected_index)%def%follow_distance
        follow_height = sys%craft(sys%selected_index)%def%follow_height
    end subroutine spacecraft_selected_follow_tuning

    real(c_float) function spacecraft_selected_speed_au(sys) result(v)
        type(spacecraft_system_t), intent(in) :: sys
        v = 0.0_c_float
        if (.not. allocated(sys%craft)) return
        if (sys%selected_index < 1 .or. sys%selected_index > size(sys%craft)) return
        v = sqrt(dot_product(sys%craft(sys%selected_index)%velocity_au, &
                             sys%craft(sys%selected_index)%velocity_au))
    end function spacecraft_selected_speed_au

    logical function spacecraft_selected_auto_stabilize(sys) result(v)
        type(spacecraft_system_t), intent(in) :: sys
        v = .false.
        if (.not. allocated(sys%craft)) return
        if (sys%selected_index < 1 .or. sys%selected_index > size(sys%craft)) return
        v = sys%craft(sys%selected_index)%auto_stabilize
    end function spacecraft_selected_auto_stabilize

    function spacecraft_selected_spawn_preset(sys) result(name)
        type(spacecraft_system_t), intent(in) :: sys
        character(len=32) :: name

        name = ""
        if (.not. allocated(sys%craft)) return
        if (sys%selected_index < 1 .or. sys%selected_index > size(sys%craft)) return
        name = sys%craft(sys%selected_index)%def%spawn_preset
    end function spacecraft_selected_spawn_preset

    subroutine spacecraft_set_spawn_preset_selected(sys, spawn_preset)
        type(spacecraft_system_t), intent(inout) :: sys
        character(len=*), intent(in) :: spawn_preset

        if (.not. allocated(sys%craft)) return
        if (sys%selected_index < 1 .or. sys%selected_index > size(sys%craft)) return
        sys%craft(sys%selected_index)%def%spawn_preset = normalized_spawn_preset(spawn_preset)
        sys%craft(sys%selected_index)%parent_body_index = parent_index_for_preset( &
            sys%craft(sys%selected_index)%def%spawn_preset)
        sys%craft(sys%selected_index)%pending_anchor_reset = .true.
    end subroutine spacecraft_set_spawn_preset_selected

    subroutine spacecraft_toggle_auto_stabilize_selected(sys)
        type(spacecraft_system_t), intent(inout) :: sys
        if (.not. allocated(sys%craft)) return
        if (sys%selected_index < 1 .or. sys%selected_index > size(sys%craft)) return
        sys%craft(sys%selected_index)%auto_stabilize = .not. &
            sys%craft(sys%selected_index)%auto_stabilize
    end subroutine spacecraft_toggle_auto_stabilize_selected

    subroutine spacecraft_control_selected(sys, dt, thrust_axis, yaw_axis, pitch_axis, roll_axis)
        type(spacecraft_system_t), intent(inout) :: sys
        real(c_float), intent(in) :: dt
        real(c_float), intent(in) :: thrust_axis, yaw_axis, pitch_axis, roll_axis
        real(c_float), parameter :: THRUST_ACCEL = 0.250_c_float
        real(c_float), parameter :: MAX_SPEED = 0.180_c_float
        real(c_float), parameter :: ANG_ACCEL = 1.5_c_float
        real(c_float), parameter :: ANG_DAMP = 3.5_c_float
        real(c_float) :: fwd(3), speed, ang_alpha

        if (.not. allocated(sys%craft)) return
        if (sys%selected_index < 1 .or. sys%selected_index > size(sys%craft)) return
        if (.not. sys%craft(sys%selected_index)%active) return

        sys%craft(sys%selected_index)%yaw_rate = sys%craft(sys%selected_index)%yaw_rate + yaw_axis * ANG_ACCEL * dt
        sys%craft(sys%selected_index)%pitch_rate = sys%craft(sys%selected_index)%pitch_rate + pitch_axis * ANG_ACCEL * dt
        sys%craft(sys%selected_index)%roll_rate = sys%craft(sys%selected_index)%roll_rate + roll_axis * ANG_ACCEL * dt

        if (sys%craft(sys%selected_index)%auto_stabilize) then
            ang_alpha = max(0.0_c_float, 1.0_c_float - ANG_DAMP * dt)
            if (abs(yaw_axis) < 1.0e-5_c_float) &
                sys%craft(sys%selected_index)%yaw_rate = sys%craft(sys%selected_index)%yaw_rate * ang_alpha
            if (abs(pitch_axis) < 1.0e-5_c_float) &
                sys%craft(sys%selected_index)%pitch_rate = sys%craft(sys%selected_index)%pitch_rate * ang_alpha
            if (abs(roll_axis) < 1.0e-5_c_float) &
                sys%craft(sys%selected_index)%roll_rate = sys%craft(sys%selected_index)%roll_rate * ang_alpha
        end if

        sys%craft(sys%selected_index)%yaw = sys%craft(sys%selected_index)%yaw + &
                                            sys%craft(sys%selected_index)%yaw_rate * dt
        sys%craft(sys%selected_index)%pitch = min(max(sys%craft(sys%selected_index)%pitch + &
            sys%craft(sys%selected_index)%pitch_rate * dt, -1.35_c_float), 1.35_c_float)
        sys%craft(sys%selected_index)%roll = sys%craft(sys%selected_index)%roll + &
                                             sys%craft(sys%selected_index)%roll_rate * dt

        call spacecraft_forward_vector(sys%craft(sys%selected_index)%yaw, &
                                       sys%craft(sys%selected_index)%pitch, fwd)
        sys%craft(sys%selected_index)%velocity_au = sys%craft(sys%selected_index)%velocity_au + &
                                                    fwd * (thrust_axis * THRUST_ACCEL * dt)
        speed = sqrt(dot_product(sys%craft(sys%selected_index)%velocity_au, &
                                 sys%craft(sys%selected_index)%velocity_au))
        if (speed > MAX_SPEED) then
            sys%craft(sys%selected_index)%velocity_au = sys%craft(sys%selected_index)%velocity_au * &
                                                        (MAX_SPEED / speed)
        end if
    end subroutine spacecraft_control_selected

    subroutine spacecraft_look_selected(sys, yaw_delta, pitch_delta)
        type(spacecraft_system_t), intent(inout) :: sys
        real(c_float), intent(in) :: yaw_delta, pitch_delta

        if (.not. allocated(sys%craft)) return
        if (sys%selected_index < 1 .or. sys%selected_index > size(sys%craft)) return
        if (.not. sys%craft(sys%selected_index)%active) return

        sys%craft(sys%selected_index)%yaw = sys%craft(sys%selected_index)%yaw + yaw_delta
        sys%craft(sys%selected_index)%pitch = min(max(sys%craft(sys%selected_index)%pitch + &
            pitch_delta, -1.35_c_float), 1.35_c_float)
    end subroutine spacecraft_look_selected

    subroutine seed_framework_catalog(sys)
        type(spacecraft_system_t), intent(inout) :: sys
        type(spacecraft_catalog_entry_t) :: entries(SPACECRAFT_CATALOG_COUNT)
        integer :: i

        call spacecraft_catalog_default(entries)
        allocate(sys%craft(size(entries)))
        do i = 1, size(entries)
            sys%craft(i)%def%id = entries(i)%id
            sys%craft(i)%def%display_name = entries(i)%display_name
            sys%craft(i)%def%franchise = entries(i)%franchise
            sys%craft(i)%def%category = entries(i)%category
            sys%craft(i)%def%model_path = entries(i)%model_path
            sys%craft(i)%def%license_path = entries(i)%license_path
            sys%craft(i)%def%spawn_preset = entries(i)%spawn_preset
            sys%craft(i)%def%visual_scale = entries(i)%visual_scale
            sys%craft(i)%def%follow_distance = entries(i)%follow_distance
            sys%craft(i)%def%follow_height = entries(i)%follow_height
            sys%craft(i)%def%model_pitch = entries(i)%model_pitch
            sys%craft(i)%def%model_yaw = entries(i)%model_yaw
            sys%craft(i)%local_offset_au = default_offset_for_index(i)
            sys%craft(i)%parent_body_index = parent_index_for_preset(entries(i)%spawn_preset)
        end do
    end subroutine seed_framework_catalog

    subroutine update_spacecraft_anchor(craft, bodies, dt)
        type(spacecraft_instance_t), intent(inout) :: craft
        type(body_t), intent(in) :: bodies(:)
        real(c_float), intent(in) :: dt
        integer :: idx

        if (.not. craft%active) return
        idx = min(max(craft%parent_body_index, 1), size(bodies))
        if (craft%pending_anchor_reset) then
            craft%world_pos_au(1) = real(bodies(idx)%position%x, c_float) / 1.495978707e11_c_float + craft%local_offset_au(1)
            craft%world_pos_au(2) = real(bodies(idx)%position%y, c_float) / 1.495978707e11_c_float + craft%local_offset_au(2)
            craft%world_pos_au(3) = real(bodies(idx)%position%z, c_float) / 1.495978707e11_c_float + craft%local_offset_au(3)
            craft%pending_anchor_reset = .false.
        else
            craft%world_pos_au = craft%world_pos_au + craft%velocity_au * max(dt, 1.0e-4_c_float)
        end if
    end subroutine update_spacecraft_anchor

    integer function parent_index_for_preset(spawn_preset, focus_index) result(idx)
        character(len=*), intent(in) :: spawn_preset
        integer, intent(in), optional :: focus_index

        select case (trim(normalized_spawn_preset(spawn_preset)))
        case ("sun")
            idx = 1
        case ("focus")
            idx = 4
            if (present(focus_index)) idx = min(max(focus_index + 1, 1), 9)
        case ("earth")
            idx = 4
        case default
            idx = 4
        end select
    end function parent_index_for_preset

    function default_offset_for_index(i) result(offset)
        integer, intent(in) :: i
        real(c_float) :: offset(3)

        offset = [0.120_c_float + 0.020_c_float * real(mod(i - 1, 3), c_float), &
                  0.015_c_float * real(mod(i, 2), c_float), &
                  0.060_c_float * real(mod(i - 1, 2), c_float)]
    end function default_offset_for_index

    subroutine spacecraft_forward_vector(yaw, pitch, fwd)
        real(c_float), intent(in) :: yaw, pitch
        real(c_float), intent(out) :: fwd(3)

        fwd(1) = cos(pitch) * sin(yaw)
        fwd(2) = sin(pitch)
        fwd(3) = cos(pitch) * cos(yaw)
    end subroutine spacecraft_forward_vector

    subroutine apply_cfg_defaults(sys, cfg)
        type(spacecraft_system_t), intent(inout) :: sys
        type(sim_config_t), intent(in) :: cfg
        integer :: i
        character(len=32) :: desired_spawn
        if (.not. allocated(sys%craft)) return
        do i = 1, size(sys%craft)
            sys%craft(i)%auto_stabilize = cfg%spacecraft_auto_stabilize
        end do
        if (sys%selected_index >= 1 .and. sys%selected_index <= size(sys%craft)) then
            desired_spawn = normalized_spawn_preset(cfg%spacecraft_spawn_preset)
            if (trim(sys%craft(sys%selected_index)%def%spawn_preset) /= trim(desired_spawn)) then
                call spacecraft_set_spawn_preset_selected(sys, desired_spawn)
            end if
        end if
    end subroutine apply_cfg_defaults

    subroutine activate_selected_if_enabled(sys)
        type(spacecraft_system_t), intent(inout) :: sys

        if (.not. sys%enabled) return
        if (.not. allocated(sys%craft)) return
        if (sys%selected_index < 1 .or. sys%selected_index > size(sys%craft)) return
        if (.not. sys%craft(sys%selected_index)%active) then
            sys%craft(sys%selected_index)%active = .true.
            sys%craft(sys%selected_index)%pending_anchor_reset = .true.
        end if
    end subroutine activate_selected_if_enabled

    subroutine sync_selected_model(sys)
        type(spacecraft_system_t), intent(inout) :: sys

        if (.not. sys%initialized) return
        if (.not. sys%enabled) then
            call spacecraft_renderer_clear_model(sys%renderer)
            return
        end if
        if (.not. allocated(sys%craft)) then
            call spacecraft_renderer_clear_model(sys%renderer)
            return
        end if
        if (sys%selected_index < 1 .or. sys%selected_index > size(sys%craft)) then
            call spacecraft_renderer_clear_model(sys%renderer)
            return
        end if

        call spacecraft_renderer_set_model(sys%renderer, sys%craft(sys%selected_index)%def%model_path)
    end subroutine sync_selected_model

    integer function selected_index_from_cfg(sys, cfg) result(idx)
        type(spacecraft_system_t), intent(in) :: sys
        type(sim_config_t), intent(in) :: cfg
        integer :: i

        idx = 1
        if (.not. allocated(sys%craft)) then
            idx = 0
            return
        end if
        do i = 1, size(sys%craft)
            if (trim(sys%craft(i)%def%id) == trim(cfg%spacecraft_default_id)) then
                idx = i
                return
            end if
        end do
    end function selected_index_from_cfg

    function normalized_spawn_preset(spawn_preset) result(name)
        character(len=*), intent(in) :: spawn_preset
        character(len=32) :: name

        select case (trim(spawn_preset))
        case ("sun")
            name = "sun"
        case ("focus")
            name = "focus"
        case default
            name = "earth"
        end select
    end function normalized_spawn_preset

end module spacecraft_mod
