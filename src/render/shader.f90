!===============================================================================
! shader.f90 — GLSL shader loading, compilation, linking, uniform setters
!===============================================================================
module shader_mod
    use, intrinsic :: iso_c_binding, only: c_float, c_int, c_null_ptr, c_loc, &
        c_char, c_null_char, c_ptr
    use gl_bindings, only: &
        gl_create_shader, gl_shader_source, gl_compile_shader, &
        gl_delete_shader, &
        gl_create_program, gl_attach_shader, gl_link_program, &
        gl_delete_program, gl_use_program, &
        gl_get_uniform_location, gl_uniform_matrix4fv, gl_uniform3f, &
        gl_uniform2f, gl_uniform1f, gl_uniform1i, &
        GL_VERTEX_SHADER, GL_FRAGMENT_SHADER, GL_LINK_STATUS, &
        GLuint_t
    use logging, only: log_msg, LOG_INFO, LOG_ERROR
    implicit none
    private

    public :: shader_program_t
    public :: shader_load, shader_use, shader_destroy
    public :: set_uniform_mat4, set_uniform_vec2, set_uniform_vec3, &
              set_uniform_float, set_uniform_int

    type, public :: shader_program_t
        integer(c_int) :: id = 0_c_int
        logical :: valid = .false.
    end type shader_program_t

contains

    !=====================================================================
    ! shader_load — compile vertex + fragment shaders, link program
    !=====================================================================
    function shader_load(vert_path, frag_path) result(prog)
        character(len=*), intent(in) :: vert_path, frag_path
        type(shader_program_t) :: prog

        integer(c_int) :: vert_id, frag_id, program_id
        character(len=4096) :: vert_src, frag_src
        integer :: rc

        call read_file(vert_path, vert_src, rc)
        if (rc /= 0) then
            call log_msg(LOG_ERROR, "Shader: failed to read " // trim(vert_path))
            prog%valid = .false.
            return
        end if

        call read_file(frag_path, frag_src, rc)
        if (rc /= 0) then
            call log_msg(LOG_ERROR, "Shader: failed to read " // trim(frag_path))
            prog%valid = .false.
            return
        end if

        ! Compile vertex shader
        vert_id = gl_create_shader(GL_VERTEX_SHADER)
        call gl_shader_source(vert_id, vert_src(1:len_trim(vert_src)))
        call gl_compile_shader(vert_id)
        call check_shader_compile(vert_id, trim(vert_path))

        ! Compile fragment shader
        frag_id = gl_create_shader(GL_FRAGMENT_SHADER)
        call gl_shader_source(frag_id, frag_src(1:len_trim(frag_src)))
        call gl_compile_shader(frag_id)
        call check_shader_compile(frag_id, trim(frag_path))

        ! Link program
        program_id = gl_create_program()
        call gl_attach_shader(program_id, vert_id)
        call gl_attach_shader(program_id, frag_id)
        call gl_link_program(program_id)

        ! Check link status
        block
            integer(c_int) :: status
            character(len=1024) :: info_log
            call glGetProgramiv_local(program_id, GL_LINK_STATUS, status)
            if (status == 0_c_int) then
                call glGetProgramInfoLog_local(program_id, info_log)
                call log_msg(LOG_ERROR, "Shader: link error: " // trim(info_log))
                call gl_delete_program(program_id)
                call gl_delete_shader(vert_id)
                call gl_delete_shader(frag_id)
                prog%valid = .false.
                return
            end if
        end block

        ! Clean up individual shaders
        call gl_delete_shader(vert_id)
        call gl_delete_shader(frag_id)

        prog%id = program_id
        prog%valid = .true.
        call log_msg(LOG_INFO, "Shader loaded: " // trim(vert_path) // " + " // trim(frag_path))
    end function shader_load

    subroutine shader_use(prog)
        type(shader_program_t), intent(in) :: prog
        if (prog%valid) call gl_use_program(prog%id)
    end subroutine shader_use

    subroutine shader_destroy(prog)
        type(shader_program_t), intent(inout) :: prog
        if (prog%valid .and. prog%id /= 0_c_int) then
            call gl_delete_program(prog%id)
        end if
        prog%id = 0_c_int
        prog%valid = .false.
    end subroutine shader_destroy

    !=====================================================================
    ! Uniform setters
    !=====================================================================
    subroutine set_uniform_mat4(prog, name, m)
        type(shader_program_t), intent(in) :: prog
        character(len=*), intent(in) :: name
        real(c_float), intent(in) :: m(16)
        integer(c_int) :: loc
        loc = gl_get_uniform_location(prog%id, name)
        if (loc >= 0_c_int) call gl_uniform_matrix4fv(loc, 1_c_int, .false., m)
    end subroutine set_uniform_mat4

    subroutine set_uniform_vec2(prog, name, x, y)
        type(shader_program_t), intent(in) :: prog
        character(len=*), intent(in) :: name
        real(c_float), intent(in) :: x, y
        integer(c_int) :: loc
        loc = gl_get_uniform_location(prog%id, name)
        if (loc >= 0_c_int) call gl_uniform2f(loc, x, y)
    end subroutine set_uniform_vec2

    subroutine set_uniform_vec3(prog, name, x, y, z)
        type(shader_program_t), intent(in) :: prog
        character(len=*), intent(in) :: name
        real(c_float), intent(in) :: x, y, z
        integer(c_int) :: loc
        loc = gl_get_uniform_location(prog%id, name)
        if (loc >= 0_c_int) call gl_uniform3f(loc, x, y, z)
    end subroutine set_uniform_vec3

    subroutine set_uniform_float(prog, name, v)
        type(shader_program_t), intent(in) :: prog
        character(len=*), intent(in) :: name
        real(c_float), intent(in) :: v
        integer(c_int) :: loc
        loc = gl_get_uniform_location(prog%id, name)
        if (loc >= 0_c_int) call gl_uniform1f(loc, v)
    end subroutine set_uniform_float

    subroutine set_uniform_int(prog, name, v)
        type(shader_program_t), intent(in) :: prog
        character(len=*), intent(in) :: name
        integer(c_int), intent(in) :: v
        integer(c_int) :: loc
        loc = gl_get_uniform_location(prog%id, name)
        if (loc >= 0_c_int) call gl_uniform1i(loc, v)
    end subroutine set_uniform_int

    !=====================================================================
    ! Internal helpers
    !=====================================================================

    !=====================================================================
    ! read_file — read entire file into a string
    !=====================================================================
    subroutine read_file(path, content, status)
        character(len=*), intent(in) :: path
        character(len=*), intent(out) :: content
        integer, intent(out) :: status
        integer :: unit
        character(len=:), allocatable :: fname
        character(len=256) :: line
        integer :: pos

        fname = trim(path) // c_null_char
        content = ""
        pos = 0

        open(newunit=unit, file=fname, status="old", action="read", &
             form="formatted", iostat=status)
        if (status /= 0) return

        do
            read(unit, "(A)", iostat=status) line
            if (status /= 0) exit
            if (pos + len_trim(line) <= len(content)) then
                content(pos+1:pos+len_trim(line)) = line(1:len_trim(line))
                pos = pos + len_trim(line)
                if (pos < len(content)) then
                    content(pos+1:pos+1) = new_line("A")
                    pos = pos + 1
                end if
            end if
        end do
        close(unit)
        status = 0
    end subroutine read_file

    !=====================================================================
    ! check_shader_compile
    !=====================================================================
    subroutine check_shader_compile(shader_id, path)
        integer(c_int), intent(in) :: shader_id
        character(len=*), intent(in) :: path
        integer(c_int) :: status
        character(len=1024) :: info_log

        call glGetShaderiv_local(shader_id, GL_LINK_STATUS, status)
        ! Note: GL_LINK_STATUS here is reused — the actual compile status
        ! constant has the same numeric value as GL_COMPILE_STATUS for our
        ! purposes since both indicate a boolean query result.
        ! Actually, let me use the correct constant:
        ! GL_COMPILE_STATUS = 0x8B81
        call glGetShaderiv_local(shader_id, int(z'8B81', c_int), status)
        if (status == 0_c_int) then
            call glGetShaderInfoLog_local(shader_id, info_log)
            call log_msg(LOG_ERROR, "Shader compile error (" // trim(path) // "): " // &
                         trim(info_log))
        end if
    end subroutine check_shader_compile

    !=====================================================================
    ! Local wrappers for glGet*iv and glGet*InfoLog
    !=====================================================================
    subroutine glGetShaderiv_local(shader, pname, params)
        integer(c_int), intent(in) :: shader, pname
        integer(c_int), intent(out) :: params
        interface
            pure subroutine ss_glGetShaderiv(shader, pname, params) &
                    bind(c, name="ss_glGetShaderiv")
                import :: c_int
                integer(c_int), value, intent(in) :: shader, pname
                integer(c_int), intent(out) :: params
            end subroutine ss_glGetShaderiv
        end interface
        call ss_glGetShaderiv(shader, pname, params)
    end subroutine glGetShaderiv_local

    subroutine glGetProgramiv_local(program, pname, params)
        integer(c_int), intent(in) :: program, pname
        integer(c_int), intent(out) :: params
        interface
            pure subroutine ss_glGetProgramiv(program, pname, params) &
                    bind(c, name="ss_glGetProgramiv")
                import :: c_int
                integer(c_int), value, intent(in) :: program, pname
                integer(c_int), intent(out) :: params
            end subroutine ss_glGetProgramiv
        end interface
        call ss_glGetProgramiv(program, pname, params)
    end subroutine glGetProgramiv_local

    subroutine glGetShaderInfoLog_local(shader, log)
        integer(c_int), intent(in) :: shader
        character(len=*), intent(out) :: log
        integer(c_int) :: length
        character(kind=c_char, len=len(log)), target :: buf
        interface
            pure subroutine ss_glGetShaderInfoLog(shd, bufSize, length, infoLog) &
                    bind(c, name="ss_glGetShaderInfoLog")
                import :: c_int, c_ptr
                integer(c_int), value, intent(in) :: shd, bufSize
                integer(c_int), intent(out) :: length
                type(c_ptr), value, intent(in) :: infoLog
            end subroutine ss_glGetShaderInfoLog
        end interface
        call ss_glGetShaderInfoLog(shader, int(len(log), c_int), length, c_loc(buf))
        log = transfer(buf, log)
    end subroutine glGetShaderInfoLog_local

    subroutine glGetProgramInfoLog_local(program, log)
        integer(c_int), intent(in) :: program
        character(len=*), intent(out) :: log
        integer(c_int) :: length
        character(kind=c_char, len=len(log)), target :: buf
        interface
            pure subroutine ss_glGetProgramInfoLog(prg, bufSize, length, infoLog) &
                    bind(c, name="ss_glGetProgramInfoLog")
                import :: c_int, c_ptr
                integer(c_int), value, intent(in) :: prg, bufSize
                integer(c_int), intent(out) :: length
                type(c_ptr), value, intent(in) :: infoLog
            end subroutine ss_glGetProgramInfoLog
        end interface
        call ss_glGetProgramInfoLog(program, int(len(log), c_int), length, c_loc(buf))
        log = transfer(buf, log)
    end subroutine glGetProgramInfoLog_local

end module shader_mod
