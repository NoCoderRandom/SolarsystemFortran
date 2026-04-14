!===============================================================================
! hud_text.f90 — Minimal HUD text renderer (colored quads in screen space)
!===============================================================================
module hud_text
    use, intrinsic :: iso_c_binding, only: c_float, c_int, c_null_ptr, c_loc, c_ptr
    use gl_bindings, only: &
        gl_use_program, gl_draw_arrays, &
        GL_ARRAY_BUFFER, GL_DYNAMIC_DRAW, GL_FLOAT, GL_TRIANGLES, GL_TRUE
    use shader_mod, only: shader_program_t, shader_load, shader_use, shader_destroy
    implicit none
    private

    public :: hud_text_t, hud_text_init, hud_text_shutdown, hud_text_clear
    public :: hud_text_render, hud_text_draw

    integer, parameter :: FLOATS_PER_VERT = 5  ! x, y, r, g, b
    integer, parameter :: MAX_VERTS = 10000
    integer, parameter :: VERTS_PER_CHAR = 6

    type, public :: hud_text_t
        type(shader_program_t) :: shader
        integer(c_int) :: vao = 0_c_int
        integer(c_int) :: vbo = 0_c_int
        integer :: n_verts = 0
        logical :: initialized = .false.
    end type hud_text_t

    ! Module-private vertex buffer (TARGET for c_loc)
    real(c_float), allocatable, target, save :: g_verts(:)

contains

    subroutine hud_text_init(hud)
        type(hud_text_t), intent(out) :: hud

        hud%shader = shader_load("shaders/hud.vert", "shaders/hud.frag")
        if (.not. hud%shader%valid) return

        allocate(g_verts(FLOATS_PER_VERT * MAX_VERTS))
        hud%n_verts = 0
        hud%initialized = .true.
    end subroutine hud_text_init

    subroutine hud_text_shutdown(hud)
        type(hud_text_t), intent(inout) :: hud
        if (.not. hud%initialized) return
        call shader_destroy(hud%shader)
        if (allocated(g_verts)) deallocate(g_verts)
        hud%initialized = .false.
    end subroutine hud_text_shutdown

    subroutine hud_text_clear(hud)
        type(hud_text_t), intent(inout) :: hud
        hud%n_verts = 0
    end subroutine hud_text_clear

    subroutine hud_text_draw(hud, x, y, text, r, g, b)
        type(hud_text_t), intent(inout) :: hud
        real(c_float), intent(in) :: x, y, r, g, b
        character(len=*), intent(in) :: text
        integer :: i, base
        real(c_float) :: cx
        real(c_float), parameter :: CHAR_W = 6.0_c_float
        real(c_float), parameter :: CHAR_H = 9.0_c_float

        if (.not. hud%initialized) return

        cx = x
        do i = 1, len_trim(text)
            if (hud%n_verts + VERTS_PER_CHAR > MAX_VERTS) return
            base = hud%n_verts * FLOATS_PER_VERT + 1
            call add_rect(base, cx, y, CHAR_W, CHAR_H, r, g, b)
            hud%n_verts = hud%n_verts + VERTS_PER_CHAR
            cx = cx + CHAR_W
        end do
    end subroutine hud_text_draw

    subroutine hud_text_render(hud)
        type(hud_text_t), intent(inout) :: hud
        integer(c_int) :: buf_arr(1)

        if (hud%n_verts == 0) return

        call shader_use(hud%shader)

        ! Create VAO + VBO
        call gl_gen_vertex_arrays_local(1, buf_arr)
        hud%vao = buf_arr(1)
        call gl_bind_vertex_array(hud%vao)
        call gl_gen_buffers_local(1, buf_arr)
        hud%vbo = buf_arr(1)
        call gl_bind_buffer(GL_ARRAY_BUFFER, hud%vbo)
        call gl_buffer_data_local(GL_ARRAY_BUFFER, &
                            int(5_c_int * 4_c_int * hud%n_verts, c_int), &
                            c_loc(g_verts(1)), GL_DYNAMIC_DRAW)

        ! Attribute 0: position (x, y) — 2 floats, stride 20, offset 0
        call gl_enable_vertex_attrib_array_local(0)
        call gl_vertex_attrib_pointer_offset_local(0, 2, GL_FLOAT, .false., 20, 0)

        ! Attribute 1: color (r, g, b) — 3 floats, stride 20, offset 8
        call gl_enable_vertex_attrib_array_local(1)
        call gl_vertex_attrib_pointer_offset_local(1, 3, GL_FLOAT, .false., 20, 8)

        call gl_draw_arrays(GL_TRIANGLES, 0, int(hud%n_verts, c_int))

        ! Cleanup
        call gl_delete_vertex_arrays_local(1, buf_arr)
        call gl_delete_buffers_local(1, buf_arr)
        hud%vao = 0_c_int
        hud%vbo = 0_c_int
    end subroutine hud_text_render

    !=====================================================================
    ! Internal helpers
    !=====================================================================

    subroutine add_rect(base, x, y, w, h, r, g, b)
        integer, intent(in) :: base
        real(c_float), intent(in) :: x, y, w, h, r, g, b
        integer :: i

        i = base;      g_verts(i) = x;       g_verts(i+1) = y;        g_verts(i+2) = r; g_verts(i+3) = g; g_verts(i+4) = b
        i = base + 5;  g_verts(i) = x + w;    g_verts(i+1) = y;        g_verts(i+2) = r; g_verts(i+3) = g; g_verts(i+4) = b
        i = base + 10; g_verts(i) = x;        g_verts(i+1) = y + h;    g_verts(i+2) = r; g_verts(i+3) = g; g_verts(i+4) = b
        i = base + 15; g_verts(i) = x + w;    g_verts(i+1) = y;        g_verts(i+2) = r; g_verts(i+3) = g; g_verts(i+4) = b
        i = base + 20; g_verts(i) = x + w;    g_verts(i+1) = y + h;    g_verts(i+2) = r; g_verts(i+3) = g; g_verts(i+4) = b
        i = base + 25; g_verts(i) = x;        g_verts(i+1) = y + h;    g_verts(i+2) = r; g_verts(i+3) = g; g_verts(i+4) = b
    end subroutine add_rect

    !=====================================================================
    ! Local GL wrappers (avoid interface conflicts with gl_bindings)
    !=====================================================================
    subroutine gl_gen_vertex_arrays_local(n, out)
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
    end subroutine gl_gen_vertex_arrays_local

    subroutine gl_bind_vertex_array(array)
        integer(c_int), intent(in) :: array
        interface
            pure subroutine ss_glBindVertexArray(a) bind(c, name="ss_glBindVertexArray")
                import :: c_int
                integer(c_int), value, intent(in) :: a
            end subroutine ss_glBindVertexArray
        end interface
        call ss_glBindVertexArray(array)
    end subroutine gl_bind_vertex_array

    subroutine gl_delete_vertex_arrays_local(n, arr)
        integer(c_int), intent(in) :: n
        integer(c_int), intent(in) :: arr(*)
        interface
            pure subroutine ss_glDeleteVertexArrays(n, a) bind(c, name="ss_glDeleteVertexArrays")
                import :: c_int
                integer(c_int), value, intent(in) :: n
                integer(c_int), intent(in) :: a(*)
            end subroutine ss_glDeleteVertexArrays
        end interface
        call ss_glDeleteVertexArrays(n, arr)
    end subroutine gl_delete_vertex_arrays_local

    subroutine gl_gen_buffers_local(n, out)
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
    end subroutine gl_gen_buffers_local

    subroutine gl_bind_buffer(target, buf)
        integer(c_int), intent(in) :: target, buf
        interface
            pure subroutine ss_glBindBuffer(t, b) bind(c, name="ss_glBindBuffer")
                import :: c_int
                integer(c_int), value, intent(in) :: t, b
            end subroutine ss_glBindBuffer
        end interface
        call ss_glBindBuffer(target, buf)
    end subroutine gl_bind_buffer

    subroutine gl_buffer_data_local(target, size, data, usage)
        integer(c_int), intent(in) :: target, size, usage
        type(c_ptr), intent(in) :: data
        interface
            pure subroutine ss_glBufferData(t, s, d, u) bind(c, name="ss_glBufferData")
                import :: c_int, c_ptr
                integer(c_int), value, intent(in) :: t, s, u
                type(c_ptr), value, intent(in) :: d
            end subroutine ss_glBufferData
        end interface
        call ss_glBufferData(target, size, data, usage)
    end subroutine gl_buffer_data_local

    subroutine gl_delete_buffers_local(n, arr)
        integer(c_int), intent(in) :: n
        integer(c_int), intent(in) :: arr(*)
        interface
            pure subroutine ss_glDeleteBuffers(n, a) bind(c, name="ss_glDeleteBuffers")
                import :: c_int
                integer(c_int), value, intent(in) :: n
                integer(c_int), intent(in) :: a(*)
            end subroutine ss_glDeleteBuffers
        end interface
        call ss_glDeleteBuffers(n, arr)
    end subroutine gl_delete_buffers_local

    subroutine gl_enable_vertex_attrib_array_local(index)
        integer(c_int), intent(in) :: index
        interface
            pure subroutine ss_glEnableVertexAttribArray(i) bind(c, name="ss_glEnableVertexAttribArray")
                import :: c_int
                integer(c_int), value, intent(in) :: i
            end subroutine ss_glEnableVertexAttribArray
        end interface
        call ss_glEnableVertexAttribArray(index)
    end subroutine gl_enable_vertex_attrib_array_local

    subroutine gl_vertex_attrib_pointer_offset_local(index, size, type, normalized, stride, byte_offset)
        integer(c_int), intent(in) :: index, size, type, stride
        logical, intent(in) :: normalized
        integer, intent(in) :: byte_offset
        integer(c_int) :: norm_i
        interface
            pure subroutine ss_glVertexAttribPointer(idx, sz, tp, ni, st, off) &
                    bind(c, name="ss_glVertexAttribPointer")
                import :: c_int
                integer(c_int), value, intent(in) :: idx, sz, tp, ni, st, off
            end subroutine ss_glVertexAttribPointer
        end interface
        norm_i = 0_c_int
        if (normalized) norm_i = 1_c_int
        call ss_glVertexAttribPointer(index, size, type, norm_i, stride, int(byte_offset, c_int))
    end subroutine gl_vertex_attrib_pointer_offset_local

end module hud_text
