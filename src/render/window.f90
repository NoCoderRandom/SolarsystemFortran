!===============================================================================
! window.f90 — Window management (1600x900, OpenGL 3.3 Core, ESC close)
!===============================================================================
module window
    use, intrinsic :: iso_c_binding, only: c_int, c_ptr, c_null_ptr, c_double, c_float, c_associated
    use gl_bindings, only: GLFWwindow, &
        glfw_init, glfw_terminate, glfw_window_hint, glfw_create_window, &
        glfw_destroy_window, glfw_make_context_current, glfw_swap_buffers, &
        glfw_window_should_close, glfw_poll_events, glfw_get_time, &
        glfw_get_framebuffer_size, &
        glfw_set_key_callback, glfw_set_framebuffer_size_callback, &
        glfw_key_cb_t, glfw_fb_size_cb_t, &
        glad_load_gl, gl_clear_color, gl_clear, gl_viewport, &
        GLFW_CONTEXT_VERSION_MAJOR, GLFW_CONTEXT_VERSION_MINOR, &
        GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE, &
        GLFW_KEY_ESCAPE, GLFW_PRESS, &
        GLFW_COLOR_BUFFER_BIT, GLFW_DEPTH_BUFFER_BIT
    use logging, only: log_msg, LOG_INFO, LOG_WARN, LOG_ERROR, LOG_DEBUG
    implicit none
    private

    public :: WindowHandle, window_open, window_close, &
              window_should_close, window_swap_buffers, &
              window_clear, window_poll_events, window_get_time

    !-----------------------------------------------------------------------
    ! Opaque window handle for the rest of the program
    !-----------------------------------------------------------------------
    type, public :: WindowHandle
        type(GLFWwindow) :: glfw_win
        integer :: width  = 0
        integer :: height = 0
    end type WindowHandle

    ! Module-private state for callback access
    type(GLFWwindow), save :: g_window

contains

    !=====================================================================
    ! window_open — create a 1600x900 OpenGL 3.3 Core window
    !=====================================================================
    function window_open(title, width, height) result(ok)
        character(len=*), intent(in) :: title
        integer, intent(in), optional :: width, height
        logical :: ok
        integer :: w, h
        logical :: gl_ok

        w = 1600
        h = 900
        if (present(width))  w = width
        if (present(height)) h = height

        ! Initialize GLFW
        if (.not. glfw_init()) then
            call log_msg(LOG_ERROR, "Failed to initialize GLFW")
            ok = .false.
            return
        end if
        call log_msg(LOG_INFO, "GLFW initialized")

        ! Request OpenGL 3.3 Core Profile
        call glfw_window_hint(GLFW_CONTEXT_VERSION_MAJOR, 3)
        call glfw_window_hint(GLFW_CONTEXT_VERSION_MINOR, 3)
        call glfw_window_hint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE)

        ! Create window
        g_window = glfw_create_window(w, h, title)
        if (.not. c_associated(g_window%ptr)) then
            call log_msg(LOG_ERROR, "Failed to create GLFW window")
            call glfw_terminate()
            ok = .false.
            return
        end if
        call log_msg(LOG_INFO, "Window created: " // trim(title) // &
                     " (" // trim(itoa(w)) // "x" // trim(itoa(h)) // ")")

        ! Make context current
        call glfw_make_context_current(g_window)

        ! Load GL functions via GLAD
        gl_ok = glad_load_gl()
        if (.not. gl_ok) then
            call log_msg(LOG_ERROR, "Failed to load GL functions via GLAD")
            call glfw_destroy_window(g_window)
            call glfw_terminate()
            ok = .false.
            return
        end if
        call log_msg(LOG_INFO, "GLAD loaded OpenGL 3.3 functions")

        ! Set callbacks
        call glfw_set_key_callback(g_window, key_callback)
        call glfw_set_framebuffer_size_callback(g_window, fb_size_callback)

        ! Initialize framebuffer size
        call update_fb_size()

        ! Set clear color: #05070d → (5/255, 7/255, 13/255, 1.0)
        call gl_clear_color(5.0_c_float / 255.0_c_float, &
                            7.0_c_float / 255.0_c_float, &
                            13.0_c_float / 255.0_c_float, &
                            1.0_c_float)

        ok = .true.
    end function window_open

    !=====================================================================
    ! window_close — shut down window and GLFW
    !=====================================================================
    subroutine window_close()
        call glfw_destroy_window(g_window)
        call glfw_terminate()
        call log_msg(LOG_INFO, "Window closed, GLFW terminated")
    end subroutine window_close

    !=====================================================================
    ! window_should_close — check if the window wants to close
    !=====================================================================
    function window_should_close() result(close)
        logical :: close
        close = glfw_window_should_close(g_window)
    end function window_should_close

    !=====================================================================
    ! window_swap_buffers — swap front/back buffers
    !=====================================================================
    subroutine window_swap_buffers()
        call glfw_swap_buffers(g_window)
    end subroutine window_swap_buffers

    !=====================================================================
    ! window_clear — clear color + depth buffers
    !=====================================================================
    subroutine window_clear()
        call gl_clear(ior(GLFW_COLOR_BUFFER_BIT, GLFW_DEPTH_BUFFER_BIT))
    end subroutine window_clear

    !=====================================================================
    ! window_poll_events — pump GLFW events
    !=====================================================================
    subroutine window_poll_events()
        call glfw_poll_events()
    end subroutine window_poll_events

    !=====================================================================
    ! window_get_time — elapsed seconds since GLFW init
    !=====================================================================
    function window_get_time() result(t)
        real(c_double) :: t
        t = glfw_get_time()
    end function window_get_time

    !=====================================================================
    ! CALLBACKS (C-interoperable — must be module-level, bind(c))
    !=====================================================================
    subroutine key_callback(c_window, key, scancode, action, mods) &
            bind(c)
        type(c_ptr), value, intent(in) :: c_window
        integer(c_int), value, intent(in) :: key, scancode, action, mods
        integer :: unused_suppress

        ! Suppress unused-parameter warnings (c_window, scancode, mods required by C interface)
        unused_suppress = int(scancode) + int(mods)
        if (.not. c_associated(c_window)) return

        ! Close on ESC key press
        if (key == GLFW_KEY_ESCAPE .and. action == GLFW_PRESS) then
            call log_msg(LOG_INFO, "ESC pressed — closing window")
            call set_window_close_flag(c_window)
        end if
    end subroutine key_callback

    subroutine fb_size_callback(c_window, width, height) &
            bind(c)
        type(c_ptr), value, intent(in) :: c_window
        integer(c_int), value, intent(in) :: width, height

        ! Suppress unused-parameter warning (c_window required by C interface)
        if (.not. c_associated(c_window)) return

        ! Update the viewport
        call gl_viewport(0_c_int, 0_c_int, width, height)
        call log_msg(LOG_DEBUG, "Framebuffer resized: " // &
                     trim(itoa(int(width))) // "x" // trim(itoa(int(height))))
    end subroutine fb_size_callback

    !=====================================================================
    ! Helpers
    !=====================================================================
    subroutine update_fb_size()
        integer(c_int) :: w, h
        call glfw_get_framebuffer_size(g_window, w, h)
        call log_msg(LOG_DEBUG, "Framebuffer size: " // &
                     trim(itoa(int(w))) // "x" // trim(itoa(int(h))))
    end subroutine update_fb_size

    subroutine set_window_close_flag(c_window)
        type(c_ptr), value, intent(in) :: c_window

        interface
            pure subroutine glfwSetWindowShouldClose(w, flag) &
                    bind(c, name="glfwSetWindowShouldClose")
                import :: c_ptr, c_int
                type(c_ptr), value, intent(in) :: w
                integer(c_int), value, intent(in) :: flag
            end subroutine glfwSetWindowShouldClose
        end interface

        call glfwSetWindowShouldClose(c_window, 1_c_int)
    end subroutine set_window_close_flag

    ! Integer-to-string helper (pure, no I/O)
    pure function itoa(i) result(s)
        integer, intent(in) :: i
        character(len=12) :: s
        write(s, "(I0)") i
    end function itoa

end module window
