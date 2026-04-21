module spacecraft_catalog_mod
    use, intrinsic :: iso_fortran_env, only: real32
    implicit none
    private

    public :: spacecraft_catalog_entry_t
    public :: SPACECRAFT_CATALOG_COUNT
    public :: spacecraft_catalog_init_entry, spacecraft_catalog_default

    integer, parameter :: SPACECRAFT_CATALOG_COUNT = 3

    type, public :: spacecraft_catalog_entry_t
        character(len=64)  :: id = ""
        character(len=64)  :: display_name = ""
        character(len=32)  :: franchise = ""
        character(len=16)  :: category = ""
        character(len=256) :: model_path = ""
        character(len=256) :: license_path = ""
        character(len=32)  :: spawn_preset = ""
        real(real32) :: visual_scale = 1.0_real32
        real(real32) :: follow_distance = 0.18_real32
        real(real32) :: follow_height = 0.05_real32
        real(real32) :: model_pitch = 0.0_real32
        real(real32) :: model_yaw = 0.6_real32
    end type spacecraft_catalog_entry_t

contains

    subroutine spacecraft_catalog_init_entry(entry, id, display_name, franchise, &
                                             category, model_path, license_path, &
                                             spawn_preset, visual_scale, follow_distance, &
                                             follow_height, model_pitch, model_yaw)
        type(spacecraft_catalog_entry_t), intent(out) :: entry
        character(len=*), intent(in) :: id, display_name, franchise
        character(len=*), intent(in) :: category, model_path, license_path, spawn_preset
        real(real32), intent(in) :: visual_scale, follow_distance, follow_height
        real(real32), intent(in) :: model_pitch, model_yaw

        entry%id = id
        entry%display_name = display_name
        entry%franchise = franchise
        entry%category = category
        entry%model_path = model_path
        entry%license_path = license_path
        entry%spawn_preset = spawn_preset
        entry%visual_scale = visual_scale
        entry%follow_distance = follow_distance
        entry%follow_height = follow_height
        entry%model_pitch = model_pitch
        entry%model_yaw = model_yaw
    end subroutine spacecraft_catalog_init_entry

    subroutine spacecraft_catalog_default(entries)
        type(spacecraft_catalog_entry_t), intent(out) :: entries(SPACECRAFT_CATALOG_COUNT)

        call spacecraft_catalog_init_entry(entries(1), "voyager1", "Voyager 1", "NASA", &
                                           "probe", "assets/spacecraft/imported/real/voyager1/model.obj", &
                                           "assets/spacecraft/imported/real/voyager1/README.md", &
                                           "earth", 1.15_real32, 0.22_real32, 0.06_real32, &
                                           0.0_real32, 0.6_real32)
        call spacecraft_catalog_init_entry(entries(2), "voyager_ncc_74656", "USS Voyager", &
                                           "Star Trek", "starship", &
                                           "assets/spacecraft/imported/trek/voyager_ncc_74656/model.obj", &
                                           "assets/spacecraft/imported/trek/voyager_ncc_74656/README.md", &
                                           "earth", 2.20_real32, 0.18_real32, 0.04_real32, &
                                           -1.570796_real32, 0.6_real32)
        call spacecraft_catalog_init_entry(entries(3), "enterprise_ncc_1701", &
                                           "USS Enterprise NCC-1701", "Star Trek", "starship", &
                                           "assets/spacecraft/imported/trek/enterprise_ncc_1701/model.obj", &
                                           "assets/spacecraft/imported/trek/enterprise_ncc_1701/README.md", &
                                           "earth", 2.00_real32, 0.18_real32, 0.04_real32, &
                                           -1.570796_real32, 0.6_real32)
    end subroutine spacecraft_catalog_default

end module spacecraft_catalog_mod
