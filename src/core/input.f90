!===============================================================================
! input.f90 — Centralized GLFW keyboard and mouse input state
!
! Captures all input via GLFW callbacks, exposes a snapshot struct queried
! each frame by the main loop and camera.
!===============================================================================
module input_mod
    use, intrinsic :: iso_c_binding, only: c_int, c_double, c_ptr, c_null_ptr, c_associated
    use logging, only: log_msg, LOG_DEBUG
    implicit none
    private

    public :: input_state_t, input_init, input_update, input_shutdown
    public :: mouse_button_t
    public :: input_key_callback, input_mouse_button_callback, &
              input_cursor_pos_callback, input_scroll_callback

    !-----------------------------------------------------------------------
    ! Key identifiers we care about (subset — extend as needed)
    !-----------------------------------------------------------------------
    integer, parameter, public :: KEY_SPACE   = 32
    integer, parameter, public :: KEY_0       = 48
    integer, parameter, public :: KEY_1       = 49
    integer, parameter, public :: KEY_2       = 50
    integer, parameter, public :: KEY_3       = 51
    integer, parameter, public :: KEY_4       = 52
    integer, parameter, public :: KEY_5       = 53
    integer, parameter, public :: KEY_6       = 54
    integer, parameter, public :: KEY_7       = 55
    integer, parameter, public :: KEY_8       = 56
    integer, parameter, public :: KEY_EQUALS  = 61   ! '='
    integer, parameter, public :: KEY_MINUS   = 45   ! '-'
    integer, parameter, public :: KEY_PLUS    = 61   ! same as '=' (non-shifted)
    integer, parameter, public :: KEY_R       = 82
    integer, parameter, public :: KEY_H       = 72
    integer, parameter, public :: KEY_T       = 84
    integer, parameter, public :: KEY_LSHIFT  = 340
    integer, parameter, public :: KEY_RSHIFT  = 344
    integer, parameter, public :: KEY_ESCAPE  = 256 + 44  ! GLFW_KEY_ESCAPE
    integer, parameter, public :: KEY_TILDE   = 96  ! '`' / '~'
    integer, parameter, public :: KEY_B        = 66
    integer, parameter, public :: KEY_LBRACKET = 91
    integer, parameter, public :: KEY_RBRACKET = 93
    integer, parameter, public :: KEY_F2       = 291
    integer, parameter, public :: KEY_F12      = 301

    ! Mouse buttons
    integer, parameter, public :: MOUSE_LEFT  = 0
    integer, parameter, public :: MOUSE_RIGHT = 1
    integer, parameter, public :: MOUSE_MIDDLE = 2

    type, public :: mouse_button_t
        logical :: left   = .false.
        logical :: right  = .false.
        logical :: middle = .false.
    end type mouse_button_t

    type, public :: input_state_t
        logical :: key_pressed(0:350) = .false.
        logical :: key_held(0:350) = .false.
        logical :: key_just_pressed(0:350) = .false.
        logical :: key_just_released(0:350) = .false.
        type(mouse_button_t) :: mouse
        type(mouse_button_t) :: mouse_just_pressed
        type(mouse_button_t) :: mouse_just_released
        double precision :: mouse_x = 0.0
        double precision :: mouse_y = 0.0
        double precision :: mouse_dx = 0.0
        double precision :: mouse_dy = 0.0
        double precision :: scroll_dy = 0.0
        logical :: initialized = .false.
    end type input_state_t

    ! Module-private state for callback access
    type(input_state_t), save :: g_input

contains

    subroutine input_init(state)
        type(input_state_t), intent(out) :: state
        state%key_pressed = .false.
        state%key_held = .false.
        state%key_just_pressed = .false.
        state%key_just_released = .false.
        state%mouse%left = .false.
        state%mouse%right = .false.
        state%mouse%middle = .false.
        state%mouse_just_pressed%left = .false.
        state%mouse_just_pressed%right = .false.
        state%mouse_just_pressed%middle = .false.
        state%mouse_just_released%left = .false.
        state%mouse_just_released%right = .false.
        state%mouse_just_released%middle = .false.
        state%mouse_x = 0.0
        state%mouse_y = 0.0
        state%mouse_dx = 0.0
        state%mouse_dy = 0.0
        state%scroll_dy = 0.0
        state%initialized = .true.
        g_input = state
    end subroutine input_init

    subroutine input_update(state)
        type(input_state_t), intent(inout) :: state
        integer :: i

        ! Update key held states
        do i = 0, 350
            if (state%key_just_pressed(i)) state%key_held(i) = .true.
            if (state%key_just_released(i)) state%key_held(i) = .false.
            state%key_just_pressed(i) = .false.
            state%key_just_released(i) = .false.
        end do

        ! Clear mouse just events and scroll
        state%mouse_just_pressed%left = .false.
        state%mouse_just_pressed%right = .false.
        state%mouse_just_pressed%middle = .false.
        state%mouse_just_released%left = .false.
        state%mouse_just_released%right = .false.
        state%mouse_just_released%middle = .false.
        state%mouse_dx = 0.0
        state%mouse_dy = 0.0
        state%scroll_dy = 0.0

        g_input = state
    end subroutine input_update

    subroutine input_shutdown()
        g_input%initialized = .false.
    end subroutine input_shutdown

    !=====================================================================
    ! GLFW callbacks — register these with the window
    !=====================================================================
    subroutine input_key_callback(window, key, scancode, action, mods) bind(c)
        type(c_ptr), value, intent(in) :: window
        integer(c_int), value, intent(in) :: key, scancode, action, mods
        integer :: unused
        unused = int(scancode) + int(mods)

        if (.not. c_associated(window)) return

        select case (action)
        case (1_c_int)  ! GLFW_PRESS
            if (key >= 0 .and. key < 351) then
                g_input%key_held(key) = .true.
                g_input%key_pressed(key) = .true.
                g_input%key_just_pressed(key) = .true.
            end if
        case (0_c_int)  ! GLFW_RELEASE
            if (key >= 0 .and. key < 351) then
                g_input%key_held(key) = .false.
                g_input%key_pressed(key) = .false.
                g_input%key_just_released(key) = .true.
            end if
        case default
            return
        end select
    end subroutine input_key_callback

    subroutine input_mouse_button_callback(window, button, action, mods) bind(c)
        type(c_ptr), value, intent(in) :: window
        integer(c_int), value, intent(in) :: button, action, mods
        integer :: unused
        unused = int(mods)

        if (.not. c_associated(window)) return

        select case (action)
        case (1_c_int)  ! PRESS
            select case (button)
            case (MOUSE_LEFT);   g_input%mouse%left = .true.; g_input%mouse_just_pressed%left = .true.
            case (MOUSE_RIGHT);  g_input%mouse%right = .true.; g_input%mouse_just_pressed%right = .true.
            case (MOUSE_MIDDLE); g_input%mouse%middle = .true.; g_input%mouse_just_pressed%middle = .true.
            end select
        case (0_c_int)  ! RELEASE
            select case (button)
            case (MOUSE_LEFT);   g_input%mouse%left = .false.; g_input%mouse_just_released%left = .true.
            case (MOUSE_RIGHT);  g_input%mouse%right = .false.; g_input%mouse_just_released%right = .true.
            case (MOUSE_MIDDLE); g_input%mouse%middle = .false.; g_input%mouse_just_released%middle = .true.
            end select
        case default
            return
        end select
    end subroutine input_mouse_button_callback

    subroutine input_cursor_pos_callback(window, xpos, ypos) bind(c)
        type(c_ptr), value, intent(in) :: window
        real(c_double), value, intent(in) :: xpos, ypos

        if (.not. c_associated(window)) return

        g_input%mouse_dx = xpos - g_input%mouse_x
        g_input%mouse_dy = ypos - g_input%mouse_y
        g_input%mouse_x = xpos
        g_input%mouse_y = ypos
    end subroutine input_cursor_pos_callback

    subroutine input_scroll_callback(window, xoffset, yoffset) bind(c)
        type(c_ptr), value, intent(in) :: window
        real(c_double), value, intent(in) :: xoffset, yoffset
        real(c_double) :: unused
        if (.not. c_associated(window)) return
        unused = xoffset
        g_input%scroll_dy = g_input%scroll_dy + yoffset
    end subroutine input_scroll_callback

end module input_mod
