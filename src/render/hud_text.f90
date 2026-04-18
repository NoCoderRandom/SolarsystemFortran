!===============================================================================
! hud_text.f90 — HUD text + UI-rect renderer
!
! Each printable character is drawn as up to 35 tiny colored squares from a
! 5x7 bitmap font stored as one int32 per glyph row (5 low bits). In the same
! batch we also emit solid-color rectangles for menu bars, dropdown panels,
! and hover highlights (hud_rect).
!===============================================================================
module hud_text
    use, intrinsic :: iso_c_binding, only: c_float, c_int, c_null_ptr, c_loc, c_ptr
    use gl_bindings, only: &
        gl_use_program, gl_draw_arrays, &
        GL_ARRAY_BUFFER, GL_DYNAMIC_DRAW, GL_FLOAT, GL_TRIANGLES, GL_TRUE
    use shader_mod, only: shader_program_t, shader_load, shader_use, shader_destroy, &
                          set_uniform_vec2
    implicit none
    private

    public :: hud_text_t, hud_text_init, hud_text_shutdown, hud_text_clear
    public :: hud_text_render, hud_text_draw, hud_text_rect
    public :: hud_text_width, GLYPH_W, GLYPH_H, GLYPH_ADVANCE

    integer, parameter :: FLOATS_PER_VERT = 5  ! x, y, r, g, b
    integer, parameter :: MAX_VERTS = 200000
    integer, parameter :: VERTS_PER_RECT = 6

    ! Glyph cell = 5x7, plus 1 px space between chars. Render at 2px pixel size.
    integer(c_int), parameter :: GLYPH_PX       = 2_c_int
    real(c_float),  parameter :: GLYPH_W        = 5.0_c_float * real(GLYPH_PX, c_float)
    real(c_float),  parameter :: GLYPH_H        = 7.0_c_float * real(GLYPH_PX, c_float)
    real(c_float),  parameter :: GLYPH_ADVANCE  = 6.0_c_float * real(GLYPH_PX, c_float)

    type, public :: hud_text_t
        type(shader_program_t) :: shader
        integer(c_int) :: vao = 0_c_int
        integer(c_int) :: vbo = 0_c_int
        integer :: n_verts = 0
        logical :: initialized = .false.
    end type hud_text_t

    real(c_float), allocatable, target, save :: g_verts(:)

    !-------------------------------------------------------------------
    ! 5x7 bitmap font. Each glyph has 7 rows; low 5 bits = pixel mask,
    ! MSB is leftmost column. Indexed by ASCII code 32..127; unmapped
    ! characters fall back to the "?" glyph.
    !-------------------------------------------------------------------
    integer, parameter :: FONT_FIRST = 32
    integer, parameter :: FONT_LAST  = 127
    integer, parameter :: FONT_ROWS  = 7
    integer :: glyph_rows(FONT_ROWS, FONT_FIRST:FONT_LAST)

    logical, save :: font_initialized = .false.

contains

    subroutine hud_text_init(hud)
        type(hud_text_t), intent(out) :: hud

        hud%shader = shader_load("shaders/hud.vert", "shaders/hud.frag")
        if (.not. hud%shader%valid) return

        allocate(g_verts(FLOATS_PER_VERT * MAX_VERTS))
        hud%n_verts = 0
        hud%initialized = .true.
        if (.not. font_initialized) then
            call build_font()
            font_initialized = .true.
        end if
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

    !-------------------------------------------------------------------
    ! Text width in pixels for a given string (trimmed).
    !-------------------------------------------------------------------
    pure function hud_text_width(text) result(w)
        character(len=*), intent(in) :: text
        real(c_float) :: w
        w = real(len_trim(text), c_float) * GLYPH_ADVANCE
    end function hud_text_width

    !-------------------------------------------------------------------
    ! Solid colored rectangle (used by menu bar / dropdown backgrounds).
    !-------------------------------------------------------------------
    subroutine hud_text_rect(hud, x, y, w, h, r, g, b)
        type(hud_text_t), intent(inout) :: hud
        real(c_float), intent(in) :: x, y, w, h, r, g, b
        integer :: base
        if (.not. hud%initialized) return
        if (hud%n_verts + VERTS_PER_RECT > MAX_VERTS) return
        base = hud%n_verts * FLOATS_PER_VERT + 1
        call add_rect(base, x, y, w, h, r, g, b)
        hud%n_verts = hud%n_verts + VERTS_PER_RECT
    end subroutine hud_text_rect

    !-------------------------------------------------------------------
    ! Draw one line of text at (x,y). y grows downward (screen space).
    !-------------------------------------------------------------------
    subroutine hud_text_draw(hud, x, y, text, r, g, b)
        type(hud_text_t), intent(inout) :: hud
        real(c_float), intent(in) :: x, y, r, g, b
        character(len=*), intent(in) :: text
        integer :: i, ch, row, col, bits, base, ascii
        real(c_float) :: cx, px

        if (.not. hud%initialized) return
        cx = x
        px = real(GLYPH_PX, c_float)
        do i = 1, len_trim(text)
            ascii = iachar(text(i:i))
            if (ascii < FONT_FIRST .or. ascii > FONT_LAST) ascii = iachar("?")
            ch = ascii
            do row = 1, FONT_ROWS
                bits = glyph_rows(row, ch)
                if (bits == 0) cycle
                do col = 0, 4
                    if (iand(bits, ishft(1, 4 - col)) /= 0) then
                        if (hud%n_verts + VERTS_PER_RECT > MAX_VERTS) return
                        base = hud%n_verts * FLOATS_PER_VERT + 1
                        call add_rect(base, &
                            cx + real(col, c_float) * px, &
                            y  + real(row - 1, c_float) * px, &
                            px, px, r, g, b)
                        hud%n_verts = hud%n_verts + VERTS_PER_RECT
                    end if
                end do
            end do
            cx = cx + GLYPH_ADVANCE
        end do
    end subroutine hud_text_draw

    subroutine hud_text_render(hud, screen_w, screen_h)
        type(hud_text_t), intent(inout) :: hud
        integer, intent(in) :: screen_w, screen_h
        integer(c_int) :: buf_arr(1)

        if (hud%n_verts == 0) return

        call shader_use(hud%shader)
        call set_uniform_vec2(hud%shader, "u_resolution", &
                              real(screen_w, c_float), real(screen_h, c_float))

        call gl_gen_vertex_arrays_local(1, buf_arr)
        hud%vao = buf_arr(1)
        call gl_bind_vertex_array(hud%vao)
        call gl_gen_buffers_local(1, buf_arr)
        hud%vbo = buf_arr(1)
        call gl_bind_buffer(GL_ARRAY_BUFFER, hud%vbo)
        call gl_buffer_data_local(GL_ARRAY_BUFFER, &
                            int(5_c_int * 4_c_int * hud%n_verts, c_int), &
                            c_loc(g_verts(1)), GL_DYNAMIC_DRAW)

        call gl_enable_vertex_attrib_array_local(0)
        call gl_vertex_attrib_pointer_offset_local(0, 2, GL_FLOAT, .false., 20, 0)
        call gl_enable_vertex_attrib_array_local(1)
        call gl_vertex_attrib_pointer_offset_local(1, 3, GL_FLOAT, .false., 20, 8)

        call gl_draw_arrays(GL_TRIANGLES, 0, int(hud%n_verts, c_int))

        call gl_delete_vertex_arrays_local(1, buf_arr)
        call gl_delete_buffers_local(1, buf_arr)
        hud%vao = 0_c_int
        hud%vbo = 0_c_int
    end subroutine hud_text_render

    !=====================================================================
    ! Bitmap font — 5 pixels wide, 7 tall. One byte per row (low 5 bits,
    ! bit 4 = leftmost column). Generated characters: SPACE, A-Z, 0-9,
    ! and a handful of punctuation common in menu labels.
    !=====================================================================
    subroutine build_font()
        integer :: i
        glyph_rows = 0

        ! ---- digits 0-9 ----
        call glyph('0', [int(B"01110"), int(B"10001"), int(B"10011"), int(B"10101"), int(B"11001"), int(B"10001"), int(B"01110")])
        call glyph('1', [int(B"00100"), int(B"01100"), int(B"00100"), int(B"00100"), int(B"00100"), int(B"00100"), int(B"01110")])
        call glyph('2', [int(B"01110"), int(B"10001"), int(B"00001"), int(B"00010"), int(B"00100"), int(B"01000"), int(B"11111")])
        call glyph('3', [int(B"11111"), int(B"00010"), int(B"00100"), int(B"00010"), int(B"00001"), int(B"10001"), int(B"01110")])
        call glyph('4', [int(B"00010"), int(B"00110"), int(B"01010"), int(B"10010"), int(B"11111"), int(B"00010"), int(B"00010")])
        call glyph('5', [int(B"11111"), int(B"10000"), int(B"11110"), int(B"00001"), int(B"00001"), int(B"10001"), int(B"01110")])
        call glyph('6', [int(B"00110"), int(B"01000"), int(B"10000"), int(B"11110"), int(B"10001"), int(B"10001"), int(B"01110")])
        call glyph('7', [int(B"11111"), int(B"00001"), int(B"00010"), int(B"00100"), int(B"01000"), int(B"01000"), int(B"01000")])
        call glyph('8', [int(B"01110"), int(B"10001"), int(B"10001"), int(B"01110"), int(B"10001"), int(B"10001"), int(B"01110")])
        call glyph('9', [int(B"01110"), int(B"10001"), int(B"10001"), int(B"01111"), int(B"00001"), int(B"00010"), int(B"01100")])

        ! ---- uppercase A-Z ----
        call glyph('A', [int(B"01110"), int(B"10001"), int(B"10001"), int(B"11111"), int(B"10001"), int(B"10001"), int(B"10001")])
        call glyph('B', [int(B"11110"), int(B"10001"), int(B"10001"), int(B"11110"), int(B"10001"), int(B"10001"), int(B"11110")])
        call glyph('C', [int(B"01110"), int(B"10001"), int(B"10000"), int(B"10000"), int(B"10000"), int(B"10001"), int(B"01110")])
        call glyph('D', [int(B"11110"), int(B"10001"), int(B"10001"), int(B"10001"), int(B"10001"), int(B"10001"), int(B"11110")])
        call glyph('E', [int(B"11111"), int(B"10000"), int(B"10000"), int(B"11110"), int(B"10000"), int(B"10000"), int(B"11111")])
        call glyph('F', [int(B"11111"), int(B"10000"), int(B"10000"), int(B"11110"), int(B"10000"), int(B"10000"), int(B"10000")])
        call glyph('G', [int(B"01110"), int(B"10001"), int(B"10000"), int(B"10111"), int(B"10001"), int(B"10001"), int(B"01111")])
        call glyph('H', [int(B"10001"), int(B"10001"), int(B"10001"), int(B"11111"), int(B"10001"), int(B"10001"), int(B"10001")])
        call glyph('I', [int(B"01110"), int(B"00100"), int(B"00100"), int(B"00100"), int(B"00100"), int(B"00100"), int(B"01110")])
        call glyph('J', [int(B"00111"), int(B"00010"), int(B"00010"), int(B"00010"), int(B"00010"), int(B"10010"), int(B"01100")])
        call glyph('K', [int(B"10001"), int(B"10010"), int(B"10100"), int(B"11000"), int(B"10100"), int(B"10010"), int(B"10001")])
        call glyph('L', [int(B"10000"), int(B"10000"), int(B"10000"), int(B"10000"), int(B"10000"), int(B"10000"), int(B"11111")])
        call glyph('M', [int(B"10001"), int(B"11011"), int(B"10101"), int(B"10101"), int(B"10001"), int(B"10001"), int(B"10001")])
        call glyph('N', [int(B"10001"), int(B"11001"), int(B"10101"), int(B"10011"), int(B"10001"), int(B"10001"), int(B"10001")])
        call glyph('O', [int(B"01110"), int(B"10001"), int(B"10001"), int(B"10001"), int(B"10001"), int(B"10001"), int(B"01110")])
        call glyph('P', [int(B"11110"), int(B"10001"), int(B"10001"), int(B"11110"), int(B"10000"), int(B"10000"), int(B"10000")])
        call glyph('Q', [int(B"01110"), int(B"10001"), int(B"10001"), int(B"10001"), int(B"10101"), int(B"10010"), int(B"01101")])
        call glyph('R', [int(B"11110"), int(B"10001"), int(B"10001"), int(B"11110"), int(B"10100"), int(B"10010"), int(B"10001")])
        call glyph('S', [int(B"01110"), int(B"10001"), int(B"10000"), int(B"01110"), int(B"00001"), int(B"10001"), int(B"01110")])
        call glyph('T', [int(B"11111"), int(B"00100"), int(B"00100"), int(B"00100"), int(B"00100"), int(B"00100"), int(B"00100")])
        call glyph('U', [int(B"10001"), int(B"10001"), int(B"10001"), int(B"10001"), int(B"10001"), int(B"10001"), int(B"01110")])
        call glyph('V', [int(B"10001"), int(B"10001"), int(B"10001"), int(B"10001"), int(B"10001"), int(B"01010"), int(B"00100")])
        call glyph('W', [int(B"10001"), int(B"10001"), int(B"10001"), int(B"10101"), int(B"10101"), int(B"11011"), int(B"10001")])
        call glyph('X', [int(B"10001"), int(B"10001"), int(B"01010"), int(B"00100"), int(B"01010"), int(B"10001"), int(B"10001")])
        call glyph('Y', [int(B"10001"), int(B"10001"), int(B"01010"), int(B"00100"), int(B"00100"), int(B"00100"), int(B"00100")])
        call glyph('Z', [int(B"11111"), int(B"00001"), int(B"00010"), int(B"00100"), int(B"01000"), int(B"10000"), int(B"11111")])

        ! ---- punctuation / symbols ----
        call glyph(' ', [0, 0, 0, 0, 0, 0, 0])
        call glyph('.', [0, 0, 0, 0, 0, int(B"00100"), int(B"00100")])
        call glyph(',', [0, 0, 0, 0, 0, int(B"00100"), int(B"01000")])
        call glyph(':', [0, int(B"00100"), int(B"00100"), 0, int(B"00100"), int(B"00100"), 0])
        call glyph('-', [0, 0, 0, int(B"01110"), 0, 0, 0])
        call glyph('+', [0, int(B"00100"), int(B"00100"), int(B"11111"), int(B"00100"), int(B"00100"), 0])
        call glyph('/', [int(B"00001"), int(B"00010"), int(B"00010"), int(B"00100"), int(B"01000"), int(B"01000"), int(B"10000")])
        call glyph('?', [int(B"01110"), int(B"10001"), int(B"00010"), int(B"00100"), int(B"00100"), 0, int(B"00100")])
        call glyph('!', [int(B"00100"), int(B"00100"), int(B"00100"), int(B"00100"), int(B"00100"), 0, int(B"00100")])
        call glyph('(', [int(B"00010"), int(B"00100"), int(B"01000"), int(B"01000"), int(B"01000"), int(B"00100"), int(B"00010")])
        call glyph(')', [int(B"01000"), int(B"00100"), int(B"00010"), int(B"00010"), int(B"00010"), int(B"00100"), int(B"01000")])
        call glyph('[', [int(B"01110"), int(B"01000"), int(B"01000"), int(B"01000"), int(B"01000"), int(B"01000"), int(B"01110")])
        call glyph(']', [int(B"01110"), int(B"00010"), int(B"00010"), int(B"00010"), int(B"00010"), int(B"00010"), int(B"01110")])
        call glyph('<', [0, int(B"00010"), int(B"00100"), int(B"01000"), int(B"00100"), int(B"00010"), 0])
        call glyph('>', [0, int(B"01000"), int(B"00100"), int(B"00010"), int(B"00100"), int(B"01000"), 0])
        call glyph('=', [0, 0, int(B"11111"), 0, int(B"11111"), 0, 0])
        call glyph('*', [0, int(B"10101"), int(B"01110"), int(B"11111"), int(B"01110"), int(B"10101"), 0])
        call glyph('#', [int(B"01010"), int(B"01010"), int(B"11111"), int(B"01010"), int(B"11111"), int(B"01010"), int(B"01010")])
        call glyph('%', [int(B"11001"), int(B"11010"), int(B"00100"), int(B"01000"), int(B"01011"), int(B"10011"), 0])

        ! Lowercase → map to uppercase shape so labels are case-insensitive.
        do i = iachar('a'), iachar('z')
            glyph_rows(:, i) = glyph_rows(:, i - 32)
        end do
    end subroutine build_font

    subroutine glyph(ch, rows)
        character(len=1), intent(in) :: ch
        integer, intent(in) :: rows(FONT_ROWS)
        integer :: code
        code = iachar(ch)
        if (code < FONT_FIRST .or. code > FONT_LAST) return
        glyph_rows(:, code) = rows
    end subroutine glyph

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
