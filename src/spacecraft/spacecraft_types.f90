module spacecraft_types_mod
    use, intrinsic :: iso_c_binding, only: c_float
    use spacecraft_catalog_mod, only: spacecraft_catalog_entry_t
    implicit none
    private

    public :: spacecraft_definition_t, spacecraft_instance_t

    type, public :: spacecraft_definition_t
        character(len=64) :: id = ""
        character(len=64) :: display_name = ""
        character(len=32) :: franchise = ""
        character(len=16) :: category = ""
        character(len=256) :: model_path = ""
        character(len=256) :: license_path = ""
        character(len=32) :: spawn_preset = ""
        real(c_float) :: visual_scale = 1.0_c_float
        real(c_float) :: follow_distance = 0.18_c_float
        real(c_float) :: follow_height = 0.05_c_float
        real(c_float) :: model_pitch = 0.0_c_float
        real(c_float) :: model_yaw = 0.6_c_float
    end type spacecraft_definition_t

    type, public :: spacecraft_instance_t
        type(spacecraft_definition_t) :: def
        logical :: active = .false.
        integer :: parent_body_index = 4
        real(c_float) :: local_offset_au(3) = [0.025_c_float, 0.0_c_float, 0.0_c_float]
        real(c_float) :: world_pos_au(3) = [0.0_c_float, 0.0_c_float, 0.0_c_float]
        real(c_float) :: velocity_au(3) = [0.0_c_float, 0.0_c_float, 0.0_c_float]
        real(c_float) :: yaw = 0.0_c_float
        real(c_float) :: pitch = 0.0_c_float
        real(c_float) :: roll = 0.0_c_float
        real(c_float) :: yaw_rate = 0.0_c_float
        real(c_float) :: pitch_rate = 0.0_c_float
        real(c_float) :: roll_rate = 0.0_c_float
        logical :: auto_stabilize = .true.
        logical :: pending_anchor_reset = .true.
        logical :: demo_override = .false.
        real(c_float) :: demo_world_pos_au(3) = [0.0_c_float, 0.0_c_float, 0.0_c_float]
        real(c_float) :: demo_yaw = 0.0_c_float
        real(c_float) :: demo_pitch = 0.0_c_float
        real(c_float) :: demo_roll = 0.0_c_float
        real(c_float) :: demo_scale_mul = 1.0_c_float
    end type spacecraft_instance_t

end module spacecraft_types_mod
