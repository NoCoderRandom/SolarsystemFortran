!===============================================================================
! gl_bindings.f90 — Fortran-to-C interop for GLFW + GLAD (Phase 3 extended)
!===============================================================================
module gl_bindings
    use, intrinsic :: iso_c_binding, only: c_int, c_double, c_float, c_ptr, &
        c_funptr, c_char, c_null_ptr, c_null_funptr, c_funloc, c_null_char, &
        c_associated, c_loc
    use, intrinsic :: iso_c_binding, only: c_int32_t
    implicit none
    private

    !-----------------------------------------------------------------------
    ! GLFW constants
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
    integer(c_int), parameter :: GLFW_COLOR_BUFFER_BIT  = 16384
    integer(c_int), parameter :: GLFW_DEPTH_BUFFER_BIT  = 256

    !-----------------------------------------------------------------------
    ! GL constants
    !-----------------------------------------------------------------------
    integer(c_int), parameter :: GL_ARRAY_BUFFER           = int(z'8892', c_int)
    integer(c_int), parameter :: GL_ELEMENT_ARRAY_BUFFER   = int(z'8893', c_int)
    integer(c_int), parameter :: GL_STATIC_DRAW            = int(z'88E4', c_int)
    integer(c_int), parameter :: GL_DYNAMIC_DRAW           = int(z'88E8', c_int)
    integer(c_int), parameter :: GL_STREAM_DRAW            = int(z'88E0', c_int)
    integer(c_int), parameter :: GL_FLOAT                  = int(z'1406', c_int)
    integer(c_int), parameter :: GL_FALSE                  = 0
    integer(c_int), parameter :: GL_TRUE                   = 1
    integer(c_int), parameter :: GL_TRIANGLES              = int(z'0004', c_int)
    integer(c_int), parameter :: GL_VERTEX_SHADER          = int(z'8B31', c_int)
    integer(c_int), parameter :: GL_FRAGMENT_SHADER        = int(z'8B30', c_int)
    integer(c_int), parameter :: GL_COMPILE_STATUS         = int(z'8B81', c_int)
    integer(c_int), parameter :: GL_LINK_STATUS            = int(z'8B82', c_int)
    integer(c_int), parameter :: GL_INFO_LOG_LENGTH        = int(z'8B84', c_int)
    integer(c_int), parameter :: GL_DEPTH_TEST             = int(z'0B71', c_int)
    integer(c_int), parameter :: GL_CULL_FACE              = int(z'0B44', c_int)
    integer(c_int), parameter :: GL_BACK                   = int(z'0405', c_int)
    integer(c_int), parameter :: GL_CCW                    = int(z'0900', c_int)
    integer(c_int), parameter :: GL_FRONT_FACE             = int(z'0B46', c_int)
    integer, parameter :: GL_UNSIGNED_INT = int(z'1405', c_int)

    !-----------------------------------------------------------------------
    ! Public API
    !-----------------------------------------------------------------------
    public :: &
        ! GLFW
        glfw_init, glfw_terminate, glfw_window_hint, glfw_create_window, &
        glfw_destroy_window, glfw_make_context_current, glfw_swap_buffers, &
        glfw_window_should_close, glfw_get_time, glfw_get_framebuffer_size, &
        glfw_poll_events, glfw_set_key_callback, &
        glfw_set_framebuffer_size_callback, glfw_set_mouse_button_callback, &
        glfw_set_cursor_pos_callback, glfw_set_scroll_callback, &
        ! GLAD
        glad_load_gl, &
        ! GL state
        gl_enable, gl_disable, gl_set_cull_face, gl_set_front_face, &
        gl_clear_color, gl_clear, gl_viewport, &
        ! Buffers
        gl_gen_buffers, gl_bind_buffer, gl_buffer_data, gl_delete_buffers, &
        ! VAOs
        gl_gen_vertex_arrays, gl_bind_vertex_array, gl_delete_vertex_arrays, &
        ! Attributes
        gl_enable_vertex_attrib_array, gl_vertex_attrib_pointer, &
        gl_vertex_attrib_divisor, gl_vertex_attrib_pointer_offset, &
        ! Shaders / programs
        gl_create_shader, gl_shader_source, gl_compile_shader, &
        gl_get_shader_info_log, gl_delete_shader, &
        gl_create_program, gl_attach_shader, gl_link_program, &
        gl_get_program_info_log, gl_delete_program, gl_use_program, &
        ! Uniforms
        gl_get_uniform_location, gl_uniform_matrix4fv, gl_uniform3f, &
        gl_uniform1f, gl_uniform1i, &
        ! Draw
        gl_draw_elements_instanced, gl_draw_arrays, &
        ! Callback types
        glfw_key_cb_t, glfw_fb_size_cb_t, &
        ! Constants
        GLFW_COLOR_BUFFER_BIT, GLFW_DEPTH_BUFFER_BIT, &
        GLFW_KEY_ESCAPE, GLFW_PRESS, GLFW_RELEASE, GLFW_REPEAT, &
        GLFW_CONTEXT_VERSION_MAJOR, GLFW_CONTEXT_VERSION_MINOR, &
        GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE, &
        GLFW_OPENGL_FORWARD_COMPAT, &
        GL_ARRAY_BUFFER, GL_ELEMENT_ARRAY_BUFFER, &
        GL_STATIC_DRAW, GL_DYNAMIC_DRAW, GL_STREAM_DRAW, &
        GL_FLOAT, GL_FALSE, GL_TRUE, GL_TRIANGLES, &
        GL_VERTEX_SHADER, GL_FRAGMENT_SHADER, &
        GL_COMPILE_STATUS, GL_LINK_STATUS, GL_INFO_LOG_LENGTH, &
        GL_DEPTH_TEST, GL_CULL_FACE, GL_BACK, GL_CCW, GL_FRONT_FACE, &
        GL_UNSIGNED_INT, &
        GLuint_t

    !-----------------------------------------------------------------------
    ! Types
    !-----------------------------------------------------------------------
    integer, parameter :: GLuint_t = c_int32_t

    type, public :: GLFWwindow
        type(c_ptr) :: ptr = c_null_ptr
    end type GLFWwindow

    abstract interface
        subroutine glfw_key_cb_t(window, key, scancode, action, mods) bind(c)
            import :: c_ptr, c_int
            type(c_ptr), value, intent(in) :: window
            integer(c_int), value, intent(in) :: key, scancode, action, mods
        end subroutine glfw_key_cb_t

        subroutine glfw_fb_size_cb_t(window, width, height) bind(c)
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

    subroutine glfw_window_hint(hint, value)
        integer(c_int), intent(in) :: hint, value
        interface
            pure subroutine glfwWindowHint(hint, value) bind(c, name="glfwWindowHint")
                import :: c_int
                integer(c_int), value, intent(in) :: hint, value
            end subroutine glfwWindowHint
        end interface
        call glfwWindowHint(hint, value)
    end subroutine glfw_window_hint

    function glfw_create_window(width, height, title) result(win)
        integer(c_int), intent(in) :: width, height
        character(len=*), intent(in) :: title
        type(GLFWwindow) :: win
        interface
            function glfwCreateWindow(w, h, t, m, s) result(ptr) bind(c, name="glfwCreateWindow")
                import :: c_int, c_ptr, c_char
                integer(c_int), value, intent(in) :: w, h
                character(kind=c_char), intent(in) :: t(*)
                type(c_ptr), value, intent(in) :: m, s
                type(c_ptr) :: ptr
            end function glfwCreateWindow
        end interface
        character(len=len(title)+1) :: c_title
        integer :: i
        c_title = ""
        do i = 1, len(title)
            c_title(i:i) = title(i:i)
        end do
        win%ptr = glfwCreateWindow(width, height, c_title, c_null_ptr, c_null_ptr)
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

    function glfw_window_should_close(window) result(should_close)
        type(GLFWwindow), intent(in) :: window
        logical :: should_close
        integer(c_int) :: rc
        interface
            pure function glfwWindowShouldClose(w) result(rc) bind(c, name="glfwWindowShouldClose")
                import :: c_ptr, c_int
                type(c_ptr), value, intent(in) :: w
                integer(c_int) :: rc
            end function glfwWindowShouldClose
        end interface
        rc = glfwWindowShouldClose(window%ptr)
        should_close = (rc /= 0_c_int)
    end function glfw_window_should_close

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

    subroutine glfw_get_framebuffer_size(window, width, height)
        type(GLFWwindow), intent(in) :: window
        integer(c_int), intent(out) :: width, height
        interface
            pure subroutine glfwGetFramebufferSize(w, ww, wh) bind(c, name="glfwGetFramebufferSize")
                import :: c_ptr, c_int
                type(c_ptr), value, intent(in) :: w
                integer(c_int), intent(out) :: ww, wh
            end subroutine glfwGetFramebufferSize
        end interface
        call glfwGetFramebufferSize(window%ptr, width, height)
    end subroutine glfw_get_framebuffer_size

    subroutine glfw_poll_events()
        interface
            pure subroutine glfwPollEvents() bind(c, name="glfwPollEvents")
            end subroutine glfwPollEvents
        end interface
        call glfwPollEvents()
    end subroutine glfw_poll_events

    subroutine glfw_set_key_callback(window, cb)
        type(GLFWwindow), intent(in) :: window
        procedure(glfw_key_cb_t) :: cb
        type(c_funptr) :: prev_cb
        interface
            function glfwSetKeyCallback(w, cb) result(prev) bind(c, name="glfwSetKeyCallback")
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

    subroutine glfw_set_mouse_button_callback(window, cb)
        type(GLFWwindow), intent(in) :: window
        interface
            subroutine glfw_mouse_button_cb_t(w, button, action, mods) bind(c)
                import :: c_ptr, c_int
                type(c_ptr), value, intent(in) :: w
                integer(c_int), value, intent(in) :: button, action, mods
            end subroutine glfw_mouse_button_cb_t
        end interface
        procedure(glfw_mouse_button_cb_t) :: cb
        type(c_funptr) :: prev_cb
        interface
            function glfwSetMouseButtonCallback(w, cb) result(prev) &
                    bind(c, name="glfwSetMouseButtonCallback")
                import :: c_ptr, c_funptr
                type(c_ptr), value, intent(in) :: w
                type(c_funptr), value, intent(in) :: cb
                type(c_funptr) :: prev
            end function glfwSetMouseButtonCallback
        end interface
        prev_cb = glfwSetMouseButtonCallback(window%ptr, c_funloc(cb))
    end subroutine glfw_set_mouse_button_callback

    subroutine glfw_set_cursor_pos_callback(window, cb)
        type(GLFWwindow), intent(in) :: window
        interface
            subroutine glfw_cursor_pos_cb_t(w, xpos, ypos) bind(c)
                import :: c_ptr, c_double
                type(c_ptr), value, intent(in) :: w
                real(c_double), value, intent(in) :: xpos, ypos
            end subroutine glfw_cursor_pos_cb_t
        end interface
        procedure(glfw_cursor_pos_cb_t) :: cb
        type(c_funptr) :: prev_cb
        interface
            function glfwSetCursorPosCallback(w, cb) result(prev) &
                    bind(c, name="glfwSetCursorPosCallback")
                import :: c_ptr, c_funptr
                type(c_ptr), value, intent(in) :: w
                type(c_funptr), value, intent(in) :: cb
                type(c_funptr) :: prev
            end function glfwSetCursorPosCallback
        end interface
        prev_cb = glfwSetCursorPosCallback(window%ptr, c_funloc(cb))
    end subroutine glfw_set_cursor_pos_callback

    subroutine glfw_set_scroll_callback(window, cb)
        type(GLFWwindow), intent(in) :: window
        interface
            subroutine glfw_scroll_cb_t(w, xoffset, yoffset) bind(c)
                import :: c_ptr, c_double
                type(c_ptr), value, intent(in) :: w
                real(c_double), value, intent(in) :: xoffset, yoffset
            end subroutine glfw_scroll_cb_t
        end interface
        procedure(glfw_scroll_cb_t) :: cb
        type(c_funptr) :: prev_cb
        interface
            function glfwSetScrollCallback(w, cb) result(prev) &
                    bind(c, name="glfwSetScrollCallback")
                import :: c_ptr, c_funptr
                type(c_ptr), value, intent(in) :: w
                type(c_funptr), value, intent(in) :: cb
                type(c_funptr) :: prev
            end function glfwSetScrollCallback
        end interface
        prev_cb = glfwSetScrollCallback(window%ptr, c_funloc(cb))
    end subroutine glfw_set_scroll_callback

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
        loaded = (rc > 0_c_int)
    end function glad_load_gl

    !=====================================================================
    ! OpenGL state
    !=====================================================================
    subroutine gl_enable(cap)
        integer(c_int), intent(in) :: cap
        interface
            pure subroutine ss_glEnable(cap) bind(c, name="ss_glEnable")
                import :: c_int
                integer(c_int), value, intent(in) :: cap
            end subroutine ss_glEnable
        end interface
        call ss_glEnable(cap)
    end subroutine gl_enable

    subroutine gl_disable(cap)
        integer(c_int), intent(in) :: cap
        interface
            pure subroutine ss_glDisable(cap) bind(c, name="ss_glDisable")
                import :: c_int
                integer(c_int), value, intent(in) :: cap
            end subroutine ss_glDisable
        end interface
        call ss_glDisable(cap)
    end subroutine gl_disable

    subroutine gl_set_cull_face(mode)
        integer(c_int), intent(in) :: mode
        interface
            pure subroutine ss_glCullFace(mode) bind(c, name="ss_glCullFace")
                import :: c_int
                integer(c_int), value, intent(in) :: mode
            end subroutine ss_glCullFace
        end interface
        call ss_glCullFace(mode)
    end subroutine gl_set_cull_face

    subroutine gl_set_front_face(mode)
        integer(c_int), intent(in) :: mode
        interface
            pure subroutine ss_glFrontFace(mode) bind(c, name="ss_glFrontFace")
                import :: c_int
                integer(c_int), value, intent(in) :: mode
            end subroutine ss_glFrontFace
        end interface
        call ss_glFrontFace(mode)
    end subroutine gl_set_front_face

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

    !=====================================================================
    ! Buffers
    !=====================================================================
    subroutine gl_gen_buffers(n, out)
        integer(c_int), intent(in) :: n
        integer(c_int), intent(out) :: out(*)
        interface
            pure subroutine ss_glGenBuffers(n, out) bind(c, name="ss_glGenBuffers")
                import :: c_int
                integer(c_int), value, intent(in) :: n
                integer(c_int), intent(out) :: out(*)
            end subroutine ss_glGenBuffers
        end interface
        call ss_glGenBuffers(n, out)
    end subroutine gl_gen_buffers

    subroutine gl_bind_buffer(target, buffer)
        integer(c_int), intent(in) :: target, buffer
        interface
            pure subroutine ss_glBindBuffer(target, buffer) bind(c, name="ss_glBindBuffer")
                import :: c_int
                integer(c_int), value, intent(in) :: target, buffer
            end subroutine ss_glBindBuffer
        end interface
        call ss_glBindBuffer(target, buffer)
    end subroutine gl_bind_buffer

    subroutine gl_buffer_data(target, size, data, usage)
        integer(c_int), intent(in) :: target
        integer(c_int), intent(in) :: size    ! GLsizeiptr (ptrdiff_t)
        type(c_ptr), intent(in), value :: data
        integer(c_int), intent(in) :: usage
        interface
            pure subroutine ss_glBufferData(target, size, data, usage) &
                    bind(c, name="ss_glBufferData")
                import :: c_int, c_ptr
                integer(c_int), value, intent(in) :: target
                integer(c_int), value, intent(in) :: size
                type(c_ptr), value, intent(in) :: data
                integer(c_int), value, intent(in) :: usage
            end subroutine ss_glBufferData
        end interface
        call ss_glBufferData(target, size, data, usage)
    end subroutine gl_buffer_data

    subroutine gl_delete_buffers(n, buffers)
        integer(c_int), intent(in) :: n
        integer(c_int), intent(in) :: buffers(*)
        interface
            pure subroutine ss_glDeleteBuffers(n, buffers) bind(c, name="ss_glDeleteBuffers")
                import :: c_int
                integer(c_int), value, intent(in) :: n
                integer(c_int), intent(in) :: buffers(*)
            end subroutine ss_glDeleteBuffers
        end interface
        call ss_glDeleteBuffers(n, buffers)
    end subroutine gl_delete_buffers

    !=====================================================================
    ! VAOs
    !=====================================================================
    subroutine gl_gen_vertex_arrays(n, out)
        integer(c_int), intent(in) :: n
        integer(c_int), intent(out) :: out(*)
        interface
            pure subroutine ss_glGenVertexArrays(n, out) bind(c, name="ss_glGenVertexArrays")
                import :: c_int
                integer(c_int), value, intent(in) :: n
                integer(c_int), intent(out) :: out(*)
            end subroutine ss_glGenVertexArrays
        end interface
        call ss_glGenVertexArrays(n, out)
    end subroutine gl_gen_vertex_arrays

    subroutine gl_bind_vertex_array(array)
        integer(c_int), intent(in) :: array
        interface
            pure subroutine ss_glBindVertexArray(array) bind(c, name="ss_glBindVertexArray")
                import :: c_int
                integer(c_int), value, intent(in) :: array
            end subroutine ss_glBindVertexArray
        end interface
        call ss_glBindVertexArray(array)
    end subroutine gl_bind_vertex_array

    subroutine gl_delete_vertex_arrays(n, arrays)
        integer(c_int), intent(in) :: n
        integer(c_int), intent(in) :: arrays(*)
        interface
            pure subroutine ss_glDeleteVertexArrays(n, arrays) bind(c, name="ss_glDeleteVertexArrays")
                import :: c_int
                integer(c_int), value, intent(in) :: n
                integer(c_int), intent(in) :: arrays(*)
            end subroutine ss_glDeleteVertexArrays
        end interface
        call ss_glDeleteVertexArrays(n, arrays)
    end subroutine gl_delete_vertex_arrays

    !=====================================================================
    ! Vertex attributes
    !=====================================================================
    subroutine gl_enable_vertex_attrib_array(index)
        integer(c_int), intent(in) :: index
        interface
            pure subroutine ss_glEnableVertexAttribArray(index) &
                    bind(c, name="ss_glEnableVertexAttribArray")
                import :: c_int
                integer(c_int), value, intent(in) :: index
            end subroutine ss_glEnableVertexAttribArray
        end interface
        call ss_glEnableVertexAttribArray(index)
    end subroutine gl_enable_vertex_attrib_array

    subroutine gl_vertex_attrib_pointer(index, size, type, normalized, stride, pointer)
        integer(c_int), intent(in) :: index, size, type
        logical, intent(in) :: normalized
        integer(c_int), intent(in) :: stride
        type(c_ptr), intent(in), value :: pointer
        integer(c_int) :: norm_i
        interface
            pure subroutine ss_glVertexAttribPointer(index, size, type, &
                    normalized_i, stride, pointer) bind(c, name="ss_glVertexAttribPointer")
                import :: c_int, c_ptr
                integer(c_int), value, intent(in) :: index, size, type, normalized_i, stride
                type(c_ptr), value, intent(in) :: pointer
            end subroutine ss_glVertexAttribPointer
        end interface
        norm_i = 0_c_int
        if (normalized) norm_i = 1_c_int
        call ss_glVertexAttribPointer(index, size, type, norm_i, stride, pointer)
    end subroutine gl_vertex_attrib_pointer

    subroutine gl_vertex_attrib_divisor(index, divisor)
        integer(c_int), intent(in) :: index, divisor
        interface
            pure subroutine ss_glVertexAttribDivisor(index, divisor) &
                    bind(c, name="ss_glVertexAttribDivisor")
                import :: c_int
                integer(c_int), value, intent(in) :: index, divisor
            end subroutine ss_glVertexAttribDivisor
        end interface
        call ss_glVertexAttribDivisor(index, divisor)
    end subroutine gl_vertex_attrib_divisor

    !=====================================================================
    ! Vertex attribute with byte offset (integer offset, no c_ptr needed)
    !=====================================================================
    subroutine gl_vertex_attrib_pointer_offset(index, size, type, &
                                                normalized, stride, byte_offset)
        integer(c_int), intent(in) :: index, size, type
        logical, intent(in) :: normalized
        integer(c_int), intent(in) :: stride
        integer, intent(in) :: byte_offset
        integer(c_int) :: norm_i
        interface
            pure subroutine ss_glVertexAttribPointer(idx, sz, tp, &
                    norm_i, stride, offset) &
                    bind(c, name="ss_glVertexAttribPointer")
                import :: c_int
                integer(c_int), value, intent(in) :: idx, sz, tp, norm_i, stride
                integer(c_int), value, intent(in) :: offset
            end subroutine ss_glVertexAttribPointer
        end interface
        norm_i = 0_c_int
        if (normalized) norm_i = 1_c_int
        call ss_glVertexAttribPointer(index, size, type, norm_i, stride, &
                                      int(byte_offset, c_int))
    end subroutine gl_vertex_attrib_pointer_offset

    !=====================================================================
    ! Shader compilation
    !=====================================================================
    function gl_create_shader(stype) result(id)
        integer(c_int), intent(in) :: stype
        integer(c_int) :: id
        interface
            pure function ss_glCreateShader(stype) result(id) &
                    bind(c, name="ss_glCreateShader")
                import :: c_int
                integer(c_int), value, intent(in) :: stype
                integer(c_int) :: id
            end function ss_glCreateShader
        end interface
        id = ss_glCreateShader(stype)
    end function gl_create_shader

    subroutine gl_shader_source(shader, source)
        integer(c_int), intent(in) :: shader
        character(len=*), intent(in) :: source
        integer(c_int), target :: length
        character(kind=c_char, len=len(source)), target :: c_source
        integer :: i
        interface
            pure subroutine ss_glShaderSourceStr(shd, src, len) &
                    bind(c, name="ss_glShaderSourceStr")
                import :: c_int, c_char
                integer(c_int), value, intent(in) :: shd
                character(kind=c_char), intent(in) :: src(*)
                integer(c_int), value, intent(in) :: len
            end subroutine ss_glShaderSourceStr
        end interface
        ! Copy Fortran string to C-compatible buffer
        do i = 1, len(source)
            c_source(i:i) = source(i:i)
        end do
        length = int(len_trim(source), c_int)
        call ss_glShaderSourceStr(shader, c_source, length)
    end subroutine gl_shader_source

    subroutine gl_compile_shader(shader)
        integer(c_int), intent(in) :: shader
        interface
            pure subroutine ss_glCompileShader(shader) bind(c, name="ss_glCompileShader")
                import :: c_int
                integer(c_int), value, intent(in) :: shader
            end subroutine ss_glCompileShader
        end interface
        call ss_glCompileShader(shader)
    end subroutine gl_compile_shader

    subroutine gl_get_shader_info_log(shader, log)
        integer(c_int), intent(in) :: shader
        character(len=*), intent(out) :: log
        integer(c_int) :: length
        interface
            pure subroutine ss_glGetShaderInfoLog(shader, bufSize, length, infoLog) &
                    bind(c, name="ss_glGetShaderInfoLog")
                import :: c_int, c_char
                integer(c_int), value, intent(in) :: shader, bufSize
                integer(c_int), intent(out) :: length
                character(kind=c_char), intent(out) :: infoLog(*)
            end subroutine ss_glGetShaderInfoLog
        end interface
        call ss_glGetShaderInfoLog(shader, len(log), length, log)
    end subroutine gl_get_shader_info_log

    subroutine gl_delete_shader(shader)
        integer(c_int), intent(in) :: shader
        interface
            pure subroutine ss_glDeleteShader(shader) bind(c, name="ss_glDeleteShader")
                import :: c_int
                integer(c_int), value, intent(in) :: shader
            end subroutine ss_glDeleteShader
        end interface
        call ss_glDeleteShader(shader)
    end subroutine gl_delete_shader

    !=====================================================================
    ! Program
    !=====================================================================
    function gl_create_program() result(id)
        integer(c_int) :: id
        interface
            pure function ss_glCreateProgram() result(id) &
                    bind(c, name="ss_glCreateProgram")
                import :: c_int
                integer(c_int) :: id
            end function ss_glCreateProgram
        end interface
        id = ss_glCreateProgram()
    end function gl_create_program

    subroutine gl_attach_shader(program, shader)
        integer(c_int), intent(in) :: program, shader
        interface
            pure subroutine ss_glAttachShader(program, shader) &
                    bind(c, name="ss_glAttachShader")
                import :: c_int
                integer(c_int), value, intent(in) :: program, shader
            end subroutine ss_glAttachShader
        end interface
        call ss_glAttachShader(program, shader)
    end subroutine gl_attach_shader

    subroutine gl_link_program(program)
        integer(c_int), intent(in) :: program
        interface
            pure subroutine ss_glLinkProgram(program) bind(c, name="ss_glLinkProgram")
                import :: c_int
                integer(c_int), value, intent(in) :: program
            end subroutine ss_glLinkProgram
        end interface
        call ss_glLinkProgram(program)
    end subroutine gl_link_program

    subroutine gl_get_program_info_log(program, log)
        integer(c_int), intent(in) :: program
        character(len=*), intent(out) :: log
        integer(c_int) :: length
        interface
            pure subroutine ss_glGetProgramInfoLog(prog, bufSize, length, infoLog) &
                    bind(c, name="ss_glGetProgramInfoLog")
                import :: c_int, c_char
                integer(c_int), value, intent(in) :: prog, bufSize
                integer(c_int), intent(out) :: length
                character(kind=c_char), intent(out) :: infoLog(*)
            end subroutine ss_glGetProgramInfoLog
        end interface
        call ss_glGetProgramInfoLog(program, int(len(log), c_int), length, log)
    end subroutine gl_get_program_info_log

    subroutine gl_delete_program(program)
        integer(c_int), intent(in) :: program
        interface
            pure subroutine ss_glDeleteProgram(program) bind(c, name="ss_glDeleteProgram")
                import :: c_int
                integer(c_int), value, intent(in) :: program
            end subroutine ss_glDeleteProgram
        end interface
        call ss_glDeleteProgram(program)
    end subroutine gl_delete_program

    subroutine gl_use_program(program)
        integer(c_int), intent(in) :: program
        interface
            pure subroutine ss_glUseProgram(program) bind(c, name="ss_glUseProgram")
                import :: c_int
                integer(c_int), value, intent(in) :: program
            end subroutine ss_glUseProgram
        end interface
        call ss_glUseProgram(program)
    end subroutine gl_use_program

    !=====================================================================
    ! Uniforms
    !=====================================================================
    function gl_get_uniform_location(program, name) result(loc)
        integer(c_int), intent(in) :: program
        character(len=*), intent(in) :: name
        integer(c_int) :: loc
        character(len=len(name)+1) :: c_name
        integer :: i
        interface
            pure function ss_glGetUniformLocation(prog, nm) result(rloc) &
                    bind(c, name="ss_glGetUniformLocation")
                import :: c_int, c_char
                integer(c_int), value, intent(in) :: prog
                character(kind=c_char), intent(in) :: nm(*)
                integer(c_int) :: rloc
            end function ss_glGetUniformLocation
        end interface
        c_name = ""
        do i = 1, len(name)
            c_name(i:i) = name(i:i)
        end do
        loc = ss_glGetUniformLocation(program, c_name)
    end function gl_get_uniform_location

    subroutine gl_uniform_matrix4fv(location, count, transpose, value)
        integer(c_int), intent(in) :: location, count
        logical, intent(in) :: transpose
        real(c_float), intent(in) :: value(*)
        integer(c_int) :: tr
        interface
            pure subroutine ss_glUniformMatrix4fv(loc, cnt, tr, val) &
                    bind(c, name="ss_glUniformMatrix4fv")
                import :: c_int, c_float
                integer(c_int), value, intent(in) :: loc, cnt, tr
                real(c_float), intent(in) :: val(*)
            end subroutine ss_glUniformMatrix4fv
        end interface
        tr = 0_c_int
        if (transpose) tr = 1_c_int
        call ss_glUniformMatrix4fv(location, count, tr, value)
    end subroutine gl_uniform_matrix4fv

    subroutine gl_uniform3f(location, v0, v1, v2)
        integer(c_int), intent(in) :: location
        real(c_float), intent(in) :: v0, v1, v2
        interface
            pure subroutine ss_glUniform3f(location, v0, v1, v2) &
                    bind(c, name="ss_glUniform3f")
                import :: c_int, c_float
                integer(c_int), value, intent(in) :: location
                real(c_float), value, intent(in) :: v0, v1, v2
            end subroutine ss_glUniform3f
        end interface
        call ss_glUniform3f(location, v0, v1, v2)
    end subroutine gl_uniform3f

    subroutine gl_uniform1f(location, v0)
        integer(c_int), intent(in) :: location
        real(c_float), intent(in) :: v0
        interface
            pure subroutine ss_glUniform1f(location, v0) bind(c, name="ss_glUniform1f")
                import :: c_int, c_float
                integer(c_int), value, intent(in) :: location
                real(c_float), value, intent(in) :: v0
            end subroutine ss_glUniform1f
        end interface
        call ss_glUniform1f(location, v0)
    end subroutine gl_uniform1f

    subroutine gl_uniform1i(location, v0)
        integer(c_int), intent(in) :: location, v0
        interface
            pure subroutine ss_glUniform1i(location, v0) bind(c, name="ss_glUniform1i")
                import :: c_int
                integer(c_int), value, intent(in) :: location, v0
            end subroutine ss_glUniform1i
        end interface
        call ss_glUniform1i(location, v0)
    end subroutine gl_uniform1i

    !=====================================================================
    ! Draw
    !=====================================================================
    subroutine gl_draw_elements_instanced(mode, count, type, indices, instancecount)
        integer(c_int), intent(in) :: mode, count, type, instancecount
        type(c_ptr), intent(in), value :: indices
        interface
            pure subroutine ss_glDrawElementsInstanced(mode, count, type, indices, instancecount) &
                    bind(c, name="ss_glDrawElementsInstanced")
                import :: c_int, c_ptr
                integer(c_int), value, intent(in) :: mode, count, type, instancecount
                type(c_ptr), value, intent(in) :: indices
            end subroutine ss_glDrawElementsInstanced
        end interface
        call ss_glDrawElementsInstanced(mode, count, type, indices, instancecount)
    end subroutine gl_draw_elements_instanced

    subroutine gl_draw_arrays(mode, first, count)
        integer(c_int), intent(in) :: mode, first, count
        interface
            pure subroutine ss_glDrawArrays(mode, first, count) bind(c, name="ss_glDrawArrays")
                import :: c_int
                integer(c_int), value, intent(in) :: mode, first, count
            end subroutine ss_glDrawArrays
        end interface
        call ss_glDrawArrays(mode, first, count)
    end subroutine gl_draw_arrays

end module gl_bindings
