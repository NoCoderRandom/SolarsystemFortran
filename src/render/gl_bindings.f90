!===============================================================================
! gl_bindings.f90 — Thin Fortran-to-C interop for GLFW + GLAD (Phase 1 set)
!
! Extend this module incrementally in later phases. Keep all C interop
! isolated here — no GLFW/GL calls should appear outside this module.
!===============================================================================
module gl_bindings
    use, intrinsic :: iso_c_binding, only: c_int, c_double, c_float, c_ptr, c_funptr, c_char, c_null_ptr, c_null_funptr, c_funloc
    implicit none
    private

    !-----------------------------------------------------------------------
    ! Public API — everything the rest of the program needs
    !-----------------------------------------------------------------------
    public :: &
        ! GLFW lifecycle
        glfw_init, glfw_terminate, &
        ! Window
        glfw_window_hint, glfw_create_window, glfw_destroy_window, &
        glfw_make_context_current, glfw_swap_buffers, &
        glfw_window_should_close, glfw_get_time, &
        glfw_get_framebuffer_size, &
        ! Events
        glfw_poll_events, &
        ! Callbacks
        glfw_set_key_callback, &
        glfw_set_framebuffer_size_callback, &
        ! GLAD
        glad_load_gl, &
        ! GL functions
        gl_clear_color, gl_clear, gl_viewport, &
        ! Callback interface types
        glfw_key_cb_t, glfw_fb_size_cb_t, &
        ! Constants
        GLFW_COLOR_BUFFER_BIT, GLFW_DEPTH_BUFFER_BIT, &
        GLFW_KEY_ESCAPE, GLFW_PRESS, GLFW_RELEASE, GLFW_REPEAT, &
        GLFW_CONTEXT_VERSION_MAJOR, GLFW_CONTEXT_VERSION_MINOR, &
        GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE, &
        GLFW_OPENGL_FORWARD_COMPAT

    !-----------------------------------------------------------------------
    ! GLFW constants (subset — extend as needed)
    !-----------------------------------------------------------------------
    integer(c_int), parameter :: GLFW_KEY_ESCAPE          = 256_c_int + 44
    integer(c_int), parameter :: GLFW_PRESS               = 1
    integer(c_int), parameter :: GLFW_RELEASE             = 0
    integer(c_int), parameter :: GLFW_REPEAT              = 1

    integer(c_int), parameter :: GLFW_CONTEXT_VERSION_MAJOR = 131075_c_int
    integer(c_int), parameter :: GLFW_CONTEXT_VERSION_MINOR = 131076_c_int
    integer(c_int), parameter :: GLFW_OPENGL_PROFILE        = 131078_c_int
    integer(c_int), parameter :: GLFW_OPENGL_CORE_PROFILE   = 204801_c_int
    integer(c_int), parameter :: GLFW_OPENGL_FORWARD_COMPAT = 1

    integer(c_int), parameter :: GLFW_COLOR_BUFFER_BIT  = 16384       ! 0x00004000
    integer(c_int), parameter :: GLFW_DEPTH_BUFFER_BIT  = 256         ! 0x00000100

    ! Opaque GLFWwindow handle
    type, public :: GLFWwindow
        type(c_ptr) :: ptr = c_null_ptr
    end type GLFWwindow

    !-----------------------------------------------------------------------
    ! Callback procedure types (C-interoperable)
    !-----------------------------------------------------------------------
    abstract interface
        subroutine glfw_key_cb_t(window, key, scancode, action, mods) &
                bind(c)
            import :: c_ptr, c_int
            type(c_ptr), value, intent(in) :: window
            integer(c_int), value, intent(in) :: key, scancode, action, mods
        end subroutine glfw_key_cb_t

        subroutine glfw_fb_size_cb_t(window, width, height) &
                bind(c)
            import :: c_ptr, c_int
            type(c_ptr), value, intent(in) :: window
            integer(c_int), value, intent(in) :: width, height
        end subroutine glfw_fb_size_cb_t
    end interface

contains

    !=====================================================================
    ! GLFW lifecycle
    !=====================================================================
    function glfw_init() result(success)
        logical :: success
        integer(c_int) :: rc

        interface
            pure function glfwInit() result(rc) bind(c, name="glfwInit")
                import :: c_int
                integer(c_int) :: rc
            end function glfwInit
        end interface

        rc = glfwInit()
        success = (rc /= 0_c_int)
    end function glfw_init

    subroutine glfw_terminate()
        interface
            pure subroutine glfwTerminate() bind(c, name="glfwTerminate")
            end subroutine glfwTerminate
        end interface

        call glfwTerminate()
    end subroutine glfw_terminate

    !=====================================================================
    ! Window hints
    !=====================================================================
    subroutine glfw_window_hint(hint, value)
        integer(c_int), intent(in) :: hint, value

        interface
            pure subroutine glfwWindowHint(hint, value) &
                    bind(c, name="glfwWindowHint")
                import :: c_int
                integer(c_int), value, intent(in) :: hint, value
            end subroutine glfwWindowHint
        end interface

        call glfwWindowHint(hint, value)
    end subroutine glfw_window_hint

    !=====================================================================
    ! Create / destroy window
    !=====================================================================
    function glfw_create_window(width, height, title) result(win)
        integer(c_int), intent(in) :: width, height
        character(len=*), intent(in) :: title
        type(GLFWwindow) :: win

        interface
            function glfwCreateWindow(w, h, t, m, s) result(ptr) &
                    bind(c, name="glfwCreateWindow")
                import :: c_int, c_ptr, c_char
                integer(c_int), value, intent(in) :: w, h
                character(kind=c_char), intent(in) :: t(*)
                type(c_ptr), value, intent(in) :: m, s
                type(c_ptr) :: ptr
            end function glfwCreateWindow
        end interface

        character(len=len(title)+1) :: c_title
        integer :: i

        ! Fortran string -> null-terminated C string
        c_title = ""
        do i = 1, len(title)
            c_title(i:i) = title(i:i)
        end do

        win%ptr = glfwCreateWindow(width, height, c_title, &
                                   c_null_ptr, c_null_ptr)
    end function glfw_create_window

    subroutine glfw_destroy_window(window)
        type(GLFWwindow), intent(inout) :: window

        interface
            pure subroutine glfwDestroyWindow(w) bind(c, name="glfwDestroyWindow")
                import :: c_ptr
                type(c_ptr), value, intent(in) :: w
            end subroutine glfwDestroyWindow
        end interface

        call glfwDestroyWindow(window%ptr)
        window%ptr = c_null_ptr
    end subroutine glfw_destroy_window

    !=====================================================================
    ! Context
    !=====================================================================
    subroutine glfw_make_context_current(window)
        type(GLFWwindow), intent(in) :: window

        interface
            pure subroutine glfwMakeContextCurrent(w) bind(c, name="glfwMakeContextCurrent")
                import :: c_ptr
                type(c_ptr), value, intent(in) :: w
            end subroutine glfwMakeContextCurrent
        end interface

        call glfwMakeContextCurrent(window%ptr)
    end subroutine glfw_make_context_current

    subroutine glfw_swap_buffers(window)
        type(GLFWwindow), intent(in) :: window

        interface
            pure subroutine glfwSwapBuffers(w) bind(c, name="glfwSwapBuffers")
                import :: c_ptr
                type(c_ptr), value, intent(in) :: w
            end subroutine glfwSwapBuffers
        end interface

        call glfwSwapBuffers(window%ptr)
    end subroutine glfw_swap_buffers

    !=====================================================================
    ! Window state
    !=====================================================================
    function glfw_window_should_close(window) result(should_close)
        type(GLFWwindow), intent(in) :: window
        logical :: should_close
        integer(c_int) :: rc

        interface
            pure function glfwWindowShouldClose(w) result(rc) &
                    bind(c, name="glfwWindowShouldClose")
                import :: c_ptr, c_int
                type(c_ptr), value, intent(in) :: w
                integer(c_int) :: rc
            end function glfwWindowShouldClose
        end interface

        rc = glfwWindowShouldClose(window%ptr)
        should_close = (rc /= 0_c_int)
    end function glfw_window_should_close

    !=====================================================================
    ! Timing
    !=====================================================================
    function glfw_get_time() result(t)
        real(c_double) :: t

        interface
            pure function glfwGetTime() result(t) bind(c, name="glfwGetTime")
                import :: c_double
                real(c_double) :: t
            end function glfwGetTime
        end interface

        t = glfwGetTime()
    end function glfw_get_time

    !=====================================================================
    ! Framebuffer size
    !=====================================================================
    subroutine glfw_get_framebuffer_size(window, width, height)
        type(GLFWwindow), intent(in) :: window
        integer(c_int), intent(out) :: width, height

        interface
            pure subroutine glfwGetFramebufferSize(w, ww, wh) &
                    bind(c, name="glfwGetFramebufferSize")
                import :: c_ptr, c_int
                type(c_ptr), value, intent(in) :: w
                integer(c_int), intent(out) :: ww, wh
            end subroutine glfwGetFramebufferSize
        end interface

        call glfwGetFramebufferSize(window%ptr, width, height)
    end subroutine glfw_get_framebuffer_size

    !=====================================================================
    ! Event polling
    !=====================================================================
    subroutine glfw_poll_events()
        interface
            pure subroutine glfwPollEvents() bind(c, name="glfwPollEvents")
            end subroutine glfwPollEvents
        end interface

        call glfwPollEvents()
    end subroutine glfw_poll_events

    !=====================================================================
    ! Callbacks — simple versions without returning previous callback
    !=====================================================================
    subroutine glfw_set_key_callback(window, cb)
        type(GLFWwindow), intent(in) :: window
        procedure(glfw_key_cb_t) :: cb
        type(c_funptr) :: prev_cb

        interface
            function glfwSetKeyCallback(w, cb) result(prev) &
                    bind(c, name="glfwSetKeyCallback")
                import :: c_ptr, c_funptr
                type(c_ptr), value, intent(in) :: w
                type(c_funptr), value, intent(in) :: cb
                type(c_funptr) :: prev
            end function glfwSetKeyCallback
        end interface

        prev_cb = glfwSetKeyCallback(window%ptr, c_funloc(cb))
    end subroutine glfw_set_key_callback

    subroutine glfw_set_framebuffer_size_callback(window, cb)
        type(GLFWwindow), intent(in) :: window
        procedure(glfw_fb_size_cb_t) :: cb
        type(c_funptr) :: prev_cb

        interface
            function glfwSetFramebufferSizeCallback(w, cb) result(prev) &
                    bind(c, name="glfwSetFramebufferSizeCallback")
                import :: c_ptr, c_funptr
                type(c_ptr), value, intent(in) :: w
                type(c_funptr), value, intent(in) :: cb
                type(c_funptr) :: prev
            end function glfwSetFramebufferSizeCallback
        end interface

        prev_cb = glfwSetFramebufferSizeCallback(window%ptr, c_funloc(cb))
    end subroutine glfw_set_framebuffer_size_callback

    !=====================================================================
    ! GLAD loader
    !=====================================================================
    function glad_load_gl() result(loaded)
        logical :: loaded
        integer(c_int) :: rc

        interface
            pure function gladLoadGL() result(rc) bind(c, name="gladLoadGL")
                import :: c_int
                integer(c_int) :: rc
            end function gladLoadGL
        end interface

        rc = gladLoadGL()
        loaded = (rc /= 0_c_int)
    end function glad_load_gl

    !=====================================================================
    ! OpenGL functions (wrapped to hide glad_ prefix)
    !=====================================================================
    subroutine gl_clear_color(r, g, b, a)
        real(c_float), intent(in) :: r, g, b, a

        interface
            pure subroutine ss_glClearColor(r, g, b, a) bind(c, name="ss_glClearColor")
                import :: c_float
                real(c_float), value, intent(in) :: r, g, b, a
            end subroutine ss_glClearColor
        end interface

        call ss_glClearColor(r, g, b, a)
    end subroutine gl_clear_color

    subroutine gl_clear(mask)
        integer(c_int), intent(in) :: mask

        interface
            pure subroutine ss_glClear(mask) bind(c, name="ss_glClear")
                import :: c_int
                integer(c_int), value, intent(in) :: mask
            end subroutine ss_glClear
        end interface

        call ss_glClear(mask)
    end subroutine gl_clear

    subroutine gl_viewport(x, y, w, h)
        integer(c_int), intent(in) :: x, y, w, h

        interface
            pure subroutine ss_glViewport(x, y, w, h) bind(c, name="ss_glViewport")
                import :: c_int
                integer(c_int), value, intent(in) :: x, y, w, h
            end subroutine ss_glViewport
        end interface

        call ss_glViewport(x, y, w, h)
    end subroutine gl_viewport

end module gl_bindings
