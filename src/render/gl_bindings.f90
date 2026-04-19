!===============================================================================
! gl_bindings.f90 — Fortran-to-C interop for GLFW + GLAD (OpenGL 4.1 Core)
!
! Phase 6: upgraded from 3.3 to 4.1 Core to gain access to the features we
! need for HDR + bloom (RGBA16F color attachments and the full explicit
! sRGB/FBO pipeline). 4.1 keeps us well under 4.3+ which would mandate a
! newer driver floor than we want for WSL2.
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
    integer(c_int), parameter :: GLFW_KEY_ESCAPE          = 256_c_int
    integer(c_int), parameter :: GLFW_PRESS               = 1
    integer(c_int), parameter :: GLFW_RELEASE             = 0
    integer(c_int), parameter :: GLFW_REPEAT              = 1
    ! GLFW hint IDs (from glfw3.h) — previous phases used the wrong numeric
    ! values by accident; they're corrected here so that 4.1 is actually
    ! requested rather than silently falling through to the driver default.
    integer(c_int), parameter :: GLFW_CONTEXT_VERSION_MAJOR = int(z'00022002', c_int)
    integer(c_int), parameter :: GLFW_CONTEXT_VERSION_MINOR = int(z'00022003', c_int)
    integer(c_int), parameter :: GLFW_OPENGL_FORWARD_COMPAT = int(z'00022006', c_int)
    integer(c_int), parameter :: GLFW_OPENGL_PROFILE        = int(z'00022008', c_int)
    integer(c_int), parameter :: GLFW_OPENGL_CORE_PROFILE   = int(z'00032001', c_int)
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
    integer(c_int), parameter :: GL_LINE_STRIP             = int(z'0003', c_int)
    integer(c_int), parameter :: GL_POINTS                 = int(z'0000', c_int)
    integer(c_int), parameter :: GL_PROGRAM_POINT_SIZE     = int(z'8642', c_int)
    integer(c_int), parameter :: GL_BLEND                  = int(z'0BE2', c_int)
    integer(c_int), parameter :: GL_LINE                   = int(z'1B01', c_int)
    integer(c_int), parameter :: GL_SRC_ALPHA              = int(z'0302', c_int)
    integer(c_int), parameter :: GL_ONE                    = int(z'0001', c_int)
    integer(c_int), parameter :: GL_ONE_MINUS_SRC_ALPHA    = int(z'0303', c_int)
    integer(c_int), parameter :: GL_ZERO                   = int(z'0000', c_int)

    ! FBO / texture / renderbuffer constants
    integer(c_int), parameter :: GL_FRAMEBUFFER            = int(z'8D40', c_int)
    integer(c_int), parameter :: GL_RENDERBUFFER           = int(z'8D41', c_int)
    integer(c_int), parameter :: GL_COLOR_ATTACHMENT0      = int(z'8CE0', c_int)
    integer(c_int), parameter :: GL_DEPTH_ATTACHMENT       = int(z'8D00', c_int)
    integer(c_int), parameter :: GL_DEPTH_COMPONENT24      = int(z'81A6', c_int)
    integer(c_int), parameter :: GL_FRAMEBUFFER_COMPLETE   = int(z'8CD5', c_int)
    integer(c_int), parameter :: GL_TEXTURE_2D             = int(z'0DE1', c_int)
    integer(c_int), parameter :: GL_TEXTURE_MIN_FILTER     = int(z'2801', c_int)
    integer(c_int), parameter :: GL_TEXTURE_MAG_FILTER     = int(z'2800', c_int)
    integer(c_int), parameter :: GL_TEXTURE_WRAP_S         = int(z'2802', c_int)
    integer(c_int), parameter :: GL_TEXTURE_WRAP_T         = int(z'2803', c_int)
    integer(c_int), parameter :: GL_LINEAR                 = int(z'2601', c_int)
    integer(c_int), parameter :: GL_NEAREST                = int(z'2600', c_int)
    integer(c_int), parameter :: GL_CLAMP_TO_EDGE          = int(z'812F', c_int)
    integer(c_int), parameter :: GL_TEXTURE0               = int(z'84C0', c_int)
    integer(c_int), parameter :: GL_TEXTURE1               = int(z'84C1', c_int)
    integer(c_int), parameter :: GL_TEXTURE2               = int(z'84C2', c_int)
    integer(c_int), parameter :: GL_TEXTURE3               = int(z'84C3', c_int)
    integer(c_int), parameter :: GL_TEXTURE4               = int(z'84C4', c_int)
    integer(c_int), parameter :: GL_TEXTURE5               = int(z'84C5', c_int)
    integer(c_int), parameter :: GL_TEXTURE6               = int(z'84C6', c_int)
    integer(c_int), parameter :: GL_TEXTURE7               = int(z'84C7', c_int)
    integer(c_int), parameter :: GL_REPEAT                 = int(z'2901', c_int)
    integer(c_int), parameter :: GL_LINEAR_MIPMAP_LINEAR   = int(z'2703', c_int)
    integer(c_int), parameter :: GL_SRGB8                  = int(z'8C41', c_int)
    integer(c_int), parameter :: GL_SRGB8_ALPHA8           = int(z'8C43', c_int)
    integer(c_int), parameter :: GL_TEXTURE_MAX_ANISOTROPY = int(z'84FE', c_int)
    integer(c_int), parameter :: GL_MAX_TEXTURE_MAX_ANISO  = int(z'84FF', c_int)
    integer(c_int), parameter :: GL_RGBA                   = int(z'1908', c_int)
    integer(c_int), parameter :: GL_RGB                    = int(z'1907', c_int)
    integer(c_int), parameter :: GL_RGBA16F                = int(z'881A', c_int)
    integer(c_int), parameter :: GL_UNSIGNED_BYTE          = int(z'1401', c_int)
    integer(c_int), parameter :: GL_VENDOR                 = int(z'1F00', c_int)
    integer(c_int), parameter :: GL_RENDERER               = int(z'1F01', c_int)
    integer(c_int), parameter :: GL_VERSION                = int(z'1F02', c_int)

    !-----------------------------------------------------------------------
    ! Public API
    !-----------------------------------------------------------------------
    public :: &
        ! GLFW
        glfw_init, glfw_terminate, glfw_window_hint, glfw_create_window, &
        glfw_destroy_window, glfw_make_context_current, glfw_swap_buffers, &
        glfw_swap_interval, &
        glfw_window_should_close, glfw_get_time, glfw_get_framebuffer_size, &
        glfw_poll_events, glfw_set_key_callback, &
        glfw_set_framebuffer_size_callback, glfw_set_mouse_button_callback, &
        glfw_set_cursor_pos_callback, glfw_set_scroll_callback, &
        ! GLAD
        glad_load_gl, gl_get_string, &
        GL_VENDOR, GL_RENDERER, GL_VERSION, &
        ! GL state
        gl_enable, gl_disable, gl_set_cull_face, gl_set_front_face, &
        gl_clear_color, gl_clear, gl_viewport, &
        gl_line_width, gl_depth_mask, gl_blend_func, &
        ! Buffers
        gl_gen_buffers, gl_bind_buffer, gl_buffer_data, gl_buffer_subdata, gl_delete_buffers, &
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
        gl_uniform2f, gl_uniform1f, gl_uniform1i, &
        ! Draw
        gl_draw_elements_instanced, gl_draw_arrays, gl_get_error, &
        ! Textures
        gl_gen_textures, gl_bind_texture, gl_delete_textures, &
        gl_tex_image_2d, gl_tex_image_2d_null, gl_tex_parameteri, &
        gl_active_texture, &
        ! Framebuffers / renderbuffers
        gl_gen_framebuffers, gl_bind_framebuffer, gl_delete_framebuffers, &
        gl_framebuffer_texture_2d, gl_check_framebuffer_status, &
        gl_gen_renderbuffers, gl_bind_renderbuffer, gl_delete_renderbuffers, &
        gl_renderbuffer_storage, gl_framebuffer_renderbuffer, &
        ! Readback
        gl_read_pixels_rgb, &
        ! PNG writer
        ss_write_png_c, &
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
        GL_UNSIGNED_INT, GL_LINE_STRIP, GL_POINTS, GL_PROGRAM_POINT_SIZE, GL_BLEND, &
        GL_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA, GL_ZERO, &
        GL_FRAMEBUFFER, GL_RENDERBUFFER, &
        GL_COLOR_ATTACHMENT0, GL_DEPTH_ATTACHMENT, &
        GL_DEPTH_COMPONENT24, GL_FRAMEBUFFER_COMPLETE, &
        GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_TEXTURE_MAG_FILTER, &
        GL_TEXTURE_WRAP_S, GL_TEXTURE_WRAP_T, GL_LINEAR, GL_NEAREST, &
        GL_CLAMP_TO_EDGE, GL_TEXTURE0, GL_TEXTURE1, GL_TEXTURE2, &
        GL_TEXTURE3, GL_TEXTURE4, GL_TEXTURE5, GL_TEXTURE6, GL_TEXTURE7, &
        GL_REPEAT, GL_LINEAR_MIPMAP_LINEAR, GL_SRGB8, GL_SRGB8_ALPHA8, &
        GL_TEXTURE_MAX_ANISOTROPY, GL_MAX_TEXTURE_MAX_ANISO, &
        GL_RGBA, GL_RGB, GL_RGBA16F, GL_UNSIGNED_BYTE, &
        gl_generate_mipmap, gl_get_float, &
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

    subroutine glfw_swap_interval(interval)
        integer, intent(in) :: interval
        interface
            pure subroutine glfwSwapInterval(i) bind(c, name="glfwSwapInterval")
                import :: c_int
                integer(c_int), value, intent(in) :: i
            end subroutine glfwSwapInterval
        end interface
        call glfwSwapInterval(int(interval, c_int))
    end subroutine glfw_swap_interval

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

    !---------------------------------------------------------------
    ! Fetch glGetString(name) into a fixed-size buffer and return it
    ! trimmed. `name` is the GL enum (e.g. GL_RENDERER, GL_VERSION).
    !---------------------------------------------------------------
    function gl_get_string(name) result(s)
        integer(c_int), intent(in) :: name
        character(len=255) :: s
        character(kind=c_char), target :: buf(256)
        integer(c_int) :: n
        integer :: i
        interface
            function ss_glGetStringCopy(name_i, out, max_len) result(n_i) &
                    bind(c, name="ss_glGetStringCopy")
                import :: c_int, c_ptr
                integer(c_int), value, intent(in) :: name_i, max_len
                type(c_ptr), value, intent(in) :: out
                integer(c_int) :: n_i
            end function ss_glGetStringCopy
        end interface
        n = ss_glGetStringCopy(name, c_loc(buf(1)), 256_c_int)
        s = ""
        do i = 1, min(n, len(s))
            s(i:i) = buf(i)
        end do
    end function gl_get_string

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

    subroutine gl_line_width(w)
        real(c_float), intent(in) :: w
        interface
            pure subroutine ss_glLineWidth(w) bind(c, name="ss_glLineWidth")
                import :: c_float
                real(c_float), value, intent(in) :: w
            end subroutine ss_glLineWidth
        end interface
        call ss_glLineWidth(w)
    end subroutine gl_line_width

    subroutine gl_depth_mask(flag)
        logical, intent(in) :: flag
        integer(c_int) :: f
        interface
            pure subroutine ss_glDepthMask(f) bind(c, name="ss_glDepthMask")
                import :: c_int
                integer(c_int), value, intent(in) :: f
            end subroutine ss_glDepthMask
        end interface
        f = 0_c_int
        if (flag) f = 1_c_int
        call ss_glDepthMask(f)
    end subroutine gl_depth_mask

    subroutine gl_blend_func(sfactor, dfactor)
        integer(c_int), intent(in) :: sfactor, dfactor
        interface
            pure subroutine ss_glBlendFunc(s, d) bind(c, name="ss_glBlendFunc")
                import :: c_int
                integer(c_int), value, intent(in) :: s, d
            end subroutine ss_glBlendFunc
        end interface
        call ss_glBlendFunc(sfactor, dfactor)
    end subroutine gl_blend_func

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

    subroutine gl_buffer_subdata(target, offset, size, data)
        integer(c_int), intent(in) :: target
        integer(c_int), intent(in) :: offset
        integer(c_int), intent(in) :: size
        type(c_ptr), intent(in), value :: data
        interface
            pure subroutine ss_glBufferSubData(target, offset, size, data) &
                    bind(c, name="ss_glBufferSubData")
                import :: c_int, c_ptr
                integer(c_int), value, intent(in) :: target, offset, size
                type(c_ptr), value, intent(in) :: data
            end subroutine ss_glBufferSubData
        end interface
        call ss_glBufferSubData(target, offset, size, data)
    end subroutine gl_buffer_subdata

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
        do i = 1, len(name)
            c_name(i:i) = name(i:i)
        end do
        c_name(len(name)+1:len(name)+1) = c_null_char
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

    function gl_get_error() result(err)
        integer(c_int) :: err
        interface
            function ss_glGetError() result(e) bind(c, name="ss_glGetError")
                import :: c_int
                integer(c_int) :: e
            end function ss_glGetError
        end interface
        err = ss_glGetError()
    end function gl_get_error

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

    subroutine gl_uniform2f(location, v0, v1)
        integer(c_int), intent(in) :: location
        real(c_float), intent(in) :: v0, v1
        interface
            pure subroutine ss_glUniform2f(location, v0, v1) bind(c, name="ss_glUniform2f")
                import :: c_int, c_float
                integer(c_int), value, intent(in) :: location
                real(c_float), value, intent(in) :: v0, v1
            end subroutine ss_glUniform2f
        end interface
        call ss_glUniform2f(location, v0, v1)
    end subroutine gl_uniform2f

    !=====================================================================
    ! Textures
    !=====================================================================
    subroutine gl_gen_textures(n, out)
        integer(c_int), intent(in) :: n
        integer(c_int), intent(out) :: out(*)
        interface
            pure subroutine ss_glGenTextures(n, out) bind(c, name="ss_glGenTextures")
                import :: c_int
                integer(c_int), value, intent(in) :: n
                integer(c_int), intent(out) :: out(*)
            end subroutine ss_glGenTextures
        end interface
        call ss_glGenTextures(n, out)
    end subroutine gl_gen_textures

    subroutine gl_bind_texture(target, tex)
        integer(c_int), intent(in) :: target, tex
        interface
            pure subroutine ss_glBindTexture(t, x) bind(c, name="ss_glBindTexture")
                import :: c_int
                integer(c_int), value, intent(in) :: t, x
            end subroutine ss_glBindTexture
        end interface
        call ss_glBindTexture(target, tex)
    end subroutine gl_bind_texture

    subroutine gl_delete_textures(n, tex)
        integer(c_int), intent(in) :: n
        integer(c_int), intent(in) :: tex(*)
        interface
            pure subroutine ss_glDeleteTextures(n, t) bind(c, name="ss_glDeleteTextures")
                import :: c_int
                integer(c_int), value, intent(in) :: n
                integer(c_int), intent(in) :: t(*)
            end subroutine ss_glDeleteTextures
        end interface
        call ss_glDeleteTextures(n, tex)
    end subroutine gl_delete_textures

    subroutine gl_tex_image_2d(target, level, internal_format, w, h, border, fmt, type, data)
        integer(c_int), intent(in) :: target, level, internal_format, w, h, border, fmt, type
        type(c_ptr), intent(in), value :: data
        interface
            pure subroutine ss_glTexImage2D(target, level, internalFormat, w, h, border, fmt, type, px) &
                    bind(c, name="ss_glTexImage2D")
                import :: c_int, c_ptr
                integer(c_int), value, intent(in) :: target, level, internalFormat, w, h, border, fmt, type
                type(c_ptr), value, intent(in) :: px
            end subroutine ss_glTexImage2D
        end interface
        call ss_glTexImage2D(target, level, internal_format, w, h, border, fmt, type, data)
    end subroutine gl_tex_image_2d

    subroutine gl_tex_image_2d_null(target, level, internal_format, w, h, fmt, type)
        integer(c_int), intent(in) :: target, level, internal_format, w, h, fmt, type
        call gl_tex_image_2d(target, level, internal_format, w, h, 0_c_int, fmt, type, c_null_ptr)
    end subroutine gl_tex_image_2d_null

    subroutine gl_tex_parameteri(target, pname, param)
        integer(c_int), intent(in) :: target, pname, param
        interface
            pure subroutine ss_glTexParameteri(t, p, v) bind(c, name="ss_glTexParameteri")
                import :: c_int
                integer(c_int), value, intent(in) :: t, p, v
            end subroutine ss_glTexParameteri
        end interface
        call ss_glTexParameteri(target, pname, param)
    end subroutine gl_tex_parameteri

    subroutine gl_active_texture(unit)
        integer(c_int), intent(in) :: unit
        interface
            pure subroutine ss_glActiveTexture(u) bind(c, name="ss_glActiveTexture")
                import :: c_int
                integer(c_int), value, intent(in) :: u
            end subroutine ss_glActiveTexture
        end interface
        call ss_glActiveTexture(unit)
    end subroutine gl_active_texture

    subroutine gl_generate_mipmap(target)
        integer(c_int), intent(in) :: target
        interface
            pure subroutine ss_glGenerateMipmap(t) bind(c, name="ss_glGenerateMipmap")
                import :: c_int
                integer(c_int), value, intent(in) :: t
            end subroutine ss_glGenerateMipmap
        end interface
        call ss_glGenerateMipmap(target)
    end subroutine gl_generate_mipmap

    subroutine gl_get_float(pname, out)
        integer(c_int), intent(in) :: pname
        real(c_float), intent(out) :: out
        interface
            pure subroutine ss_glGetFloatv(p, v) bind(c, name="ss_glGetFloatv")
                import :: c_int, c_float
                integer(c_int), value, intent(in) :: p
                real(c_float), intent(out) :: v
            end subroutine ss_glGetFloatv
        end interface
        call ss_glGetFloatv(pname, out)
    end subroutine gl_get_float

    !=====================================================================
    ! Framebuffers / renderbuffers
    !=====================================================================
    subroutine gl_gen_framebuffers(n, out)
        integer(c_int), intent(in) :: n
        integer(c_int), intent(out) :: out(*)
        interface
            pure subroutine ss_glGenFramebuffers(n, out) bind(c, name="ss_glGenFramebuffers")
                import :: c_int
                integer(c_int), value, intent(in) :: n
                integer(c_int), intent(out) :: out(*)
            end subroutine ss_glGenFramebuffers
        end interface
        call ss_glGenFramebuffers(n, out)
    end subroutine gl_gen_framebuffers

    subroutine gl_bind_framebuffer(target, fb)
        integer(c_int), intent(in) :: target, fb
        interface
            pure subroutine ss_glBindFramebuffer(t, f) bind(c, name="ss_glBindFramebuffer")
                import :: c_int
                integer(c_int), value, intent(in) :: t, f
            end subroutine ss_glBindFramebuffer
        end interface
        call ss_glBindFramebuffer(target, fb)
    end subroutine gl_bind_framebuffer

    subroutine gl_delete_framebuffers(n, fb)
        integer(c_int), intent(in) :: n
        integer(c_int), intent(in) :: fb(*)
        interface
            pure subroutine ss_glDeleteFramebuffers(n, f) bind(c, name="ss_glDeleteFramebuffers")
                import :: c_int
                integer(c_int), value, intent(in) :: n
                integer(c_int), intent(in) :: f(*)
            end subroutine ss_glDeleteFramebuffers
        end interface
        call ss_glDeleteFramebuffers(n, fb)
    end subroutine gl_delete_framebuffers

    subroutine gl_framebuffer_texture_2d(target, attach, textarget, tex, level)
        integer(c_int), intent(in) :: target, attach, textarget, tex, level
        interface
            pure subroutine ss_glFramebufferTexture2D(t, a, tt, x, l) &
                    bind(c, name="ss_glFramebufferTexture2D")
                import :: c_int
                integer(c_int), value, intent(in) :: t, a, tt, x, l
            end subroutine ss_glFramebufferTexture2D
        end interface
        call ss_glFramebufferTexture2D(target, attach, textarget, tex, level)
    end subroutine gl_framebuffer_texture_2d

    function gl_check_framebuffer_status(target) result(status)
        integer(c_int), intent(in) :: target
        integer(c_int) :: status
        interface
            pure function ss_glCheckFramebufferStatus(t) result(s) &
                    bind(c, name="ss_glCheckFramebufferStatus")
                import :: c_int
                integer(c_int), value, intent(in) :: t
                integer(c_int) :: s
            end function ss_glCheckFramebufferStatus
        end interface
        status = ss_glCheckFramebufferStatus(target)
    end function gl_check_framebuffer_status

    subroutine gl_gen_renderbuffers(n, out)
        integer(c_int), intent(in) :: n
        integer(c_int), intent(out) :: out(*)
        interface
            pure subroutine ss_glGenRenderbuffers(n, out) bind(c, name="ss_glGenRenderbuffers")
                import :: c_int
                integer(c_int), value, intent(in) :: n
                integer(c_int), intent(out) :: out(*)
            end subroutine ss_glGenRenderbuffers
        end interface
        call ss_glGenRenderbuffers(n, out)
    end subroutine gl_gen_renderbuffers

    subroutine gl_bind_renderbuffer(target, rb)
        integer(c_int), intent(in) :: target, rb
        interface
            pure subroutine ss_glBindRenderbuffer(t, r) bind(c, name="ss_glBindRenderbuffer")
                import :: c_int
                integer(c_int), value, intent(in) :: t, r
            end subroutine ss_glBindRenderbuffer
        end interface
        call ss_glBindRenderbuffer(target, rb)
    end subroutine gl_bind_renderbuffer

    subroutine gl_delete_renderbuffers(n, rb)
        integer(c_int), intent(in) :: n
        integer(c_int), intent(in) :: rb(*)
        interface
            pure subroutine ss_glDeleteRenderbuffers(n, r) bind(c, name="ss_glDeleteRenderbuffers")
                import :: c_int
                integer(c_int), value, intent(in) :: n
                integer(c_int), intent(in) :: r(*)
            end subroutine ss_glDeleteRenderbuffers
        end interface
        call ss_glDeleteRenderbuffers(n, rb)
    end subroutine gl_delete_renderbuffers

    subroutine gl_renderbuffer_storage(target, internal_format, w, h)
        integer(c_int), intent(in) :: target, internal_format, w, h
        interface
            pure subroutine ss_glRenderbufferStorage(t, f, ww, hh) &
                    bind(c, name="ss_glRenderbufferStorage")
                import :: c_int
                integer(c_int), value, intent(in) :: t, f, ww, hh
            end subroutine ss_glRenderbufferStorage
        end interface
        call ss_glRenderbufferStorage(target, internal_format, w, h)
    end subroutine gl_renderbuffer_storage

    subroutine gl_framebuffer_renderbuffer(target, attach, rbtarget, rb)
        integer(c_int), intent(in) :: target, attach, rbtarget, rb
        interface
            pure subroutine ss_glFramebufferRenderbuffer(t, a, rt, r) &
                    bind(c, name="ss_glFramebufferRenderbuffer")
                import :: c_int
                integer(c_int), value, intent(in) :: t, a, rt, r
            end subroutine ss_glFramebufferRenderbuffer
        end interface
        call ss_glFramebufferRenderbuffer(target, attach, rbtarget, rb)
    end subroutine gl_framebuffer_renderbuffer

    subroutine gl_read_pixels_rgb(x, y, w, h, data)
        integer(c_int), intent(in) :: x, y, w, h
        type(c_ptr), intent(in), value :: data
        interface
            pure subroutine ss_glReadPixels(x, y, w, h, fmt, type, px) &
                    bind(c, name="ss_glReadPixels")
                import :: c_int, c_ptr
                integer(c_int), value, intent(in) :: x, y, w, h, fmt, type
                type(c_ptr), value, intent(in) :: px
            end subroutine ss_glReadPixels
        end interface
        call ss_glReadPixels(x, y, w, h, GL_RGB, GL_UNSIGNED_BYTE, data)
    end subroutine gl_read_pixels_rgb

    function ss_write_png_c(path, w, h, data) result(rc)
        character(len=*), intent(in) :: path
        integer(c_int), intent(in) :: w, h
        type(c_ptr), intent(in), value :: data
        integer(c_int) :: rc
        character(kind=c_char, len=len(path)+1) :: c_path
        integer :: i
        interface
            function ss_write_png(path, w, h, rgb) result(rc) bind(c, name="ss_write_png")
                import :: c_int, c_char, c_ptr
                character(kind=c_char), intent(in) :: path(*)
                integer(c_int), value, intent(in) :: w, h
                type(c_ptr), value, intent(in) :: rgb
                integer(c_int) :: rc
            end function ss_write_png
        end interface
        c_path = ""
        do i = 1, len(path)
            c_path(i:i) = path(i:i)
        end do
        c_path(len(path)+1:len(path)+1) = c_null_char
        rc = ss_write_png(c_path, w, h, data)
    end function ss_write_png_c

end module gl_bindings
