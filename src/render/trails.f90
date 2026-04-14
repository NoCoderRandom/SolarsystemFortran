!===============================================================================
! trails.f90 — GPU-buffered orbit trails with fading
!
! Per-body ring buffer: one large VBO holding N positions per body.
! Ring buffer managed CPU-side (head index), uploaded via glBufferSubData
! each frame for the single changed slot.
!
! Rendering: one glDrawArrays(GL_LINE_STRIP) per body.
! Fading computed in vertex shader from slot index vs head.
!===============================================================================
module trails_mod
    use, intrinsic :: iso_c_binding, only: c_float, c_int, c_null_ptr, c_loc, c_ptr, c_char
    use gl_bindings, only: &
        gl_use_program, gl_enable, gl_disable, gl_draw_arrays, &
        gl_gen_vertex_arrays, gl_bind_vertex_array, gl_delete_vertex_arrays, &
        gl_gen_buffers, gl_bind_buffer, gl_buffer_data, gl_buffer_subdata, &
        gl_delete_buffers, &
        GL_ARRAY_BUFFER, GL_DYNAMIC_DRAW, GL_FLOAT, GL_LINE_STRIP, &
        GL_BLEND, GL_TRUE
    use shader_mod, only: shader_program_t, shader_load, shader_use, shader_destroy, &
                          set_uniform_mat4, set_uniform_vec3, set_uniform_float, &
                          set_uniform_int
    use camera_mod, only: camera_t, camera_get_view, camera_get_projection
    use body_mod, only: body_t
    use constants, only: AU
    implicit none
    private

    public :: trails_t, trails_init, trails_shutdown, trails_clear
    public :: trails_push_body, trails_render, trails_set_visibility

    !-----------------------------------------------------------------------
    ! Ring buffer per body.
    ! VBO layout: n_bodies × max_slots × 3 floats
    ! Each body writes to its own slice. Head index tracked per body.
    !-----------------------------------------------------------------------
    type, public :: trails_t
        type(shader_program_t) :: shader
        integer(c_int) :: vao = 0_c_int
        integer(c_int) :: vbo = 0_c_int
        logical :: initialized = .false.
        logical :: visible = .true.
        ! CPU-side ring buffer head indices (0-based)
        integer, allocatable :: head(:)   ! head(body_index)
        integer, allocatable :: count(:)  ! how many valid entries
        integer :: n_bodies = 0
        integer :: max_slots = 0
    end type trails_t

contains

    !=====================================================================
    ! trails_init — allocate VBO and CPU ring state, fill with initial pos
    !=====================================================================
    subroutine trails_init(trails, n_bodies, max_slots)
        type(trails_t), intent(out) :: trails
        integer, intent(in) :: n_bodies, max_slots
        integer :: total_slots
        real(c_float), allocatable, target :: initial_data(:)
        integer :: i
        integer(c_int) :: buf_arr(1)

        trails%shader = shader_load("shaders/trail.vert", "shaders/trail.frag")
        if (.not. trails%shader%valid) return

        trails%n_bodies = n_bodies
        trails%max_slots = max_slots
        total_slots = n_bodies * max_slots

        ! Allocate VBO
        call gl_gen_buffers(1, buf_arr)
        trails%vbo = buf_arr(1)
        call gl_gen_vertex_arrays(1, buf_arr)
        trails%vao = buf_arr(1)

        ! Allocate initial data: fill all positions with zeros for seeding
        allocate(initial_data(3 * total_slots))
        initial_data = 0.0_c_float
        call gl_bind_buffer(GL_ARRAY_BUFFER, trails%vbo)
        call gl_buffer_data(GL_ARRAY_BUFFER, &
                            int(3_c_int * 4_c_int * total_slots, c_int), &
                            c_loc(initial_data(1)), GL_DYNAMIC_DRAW)

        ! CPU-side ring state
        allocate(trails%head(n_bodies))
        allocate(trails%count(n_bodies))
        do i = 1, n_bodies
            trails%head(i) = 0
            trails%count(i) = 0
        end do

        trails%initialized = .true.
        trails%visible = .true.

        deallocate(initial_data)
    end subroutine trails_init

    !=====================================================================
    ! trails_set_visibility
    !=====================================================================
    subroutine trails_set_visibility(trails, vis)
        type(trails_t), intent(inout) :: trails
        logical, intent(in) :: vis
        trails%visible = vis
    end subroutine trails_set_visibility

    !=====================================================================
    ! trails_clear — reset ring buffers (set head=0, count=0, zero VBO)
    !=====================================================================
    subroutine trails_clear(trails)
        type(trails_t), intent(inout) :: trails
        integer :: i, total_slots
        real(c_float), allocatable, target :: zero_data(:)

        if (.not. trails%initialized) return

        do i = 1, trails%n_bodies
            trails%head(i) = 0
            trails%count(i) = 0
        end do

        ! Zero the VBO
        total_slots = trails%n_bodies * trails%max_slots
        allocate(zero_data(3 * total_slots))
        zero_data = 0.0_c_float
        call gl_bind_buffer(GL_ARRAY_BUFFER, trails%vbo)
        call gl_buffer_subdata(GL_ARRAY_BUFFER, 0_c_int, &
                               int(3_c_int * 4_c_int * total_slots, c_int), &
                               c_loc(zero_data(1)))
        deallocate(zero_data)
    end subroutine trails_clear

    !=====================================================================
    ! trails_push_body — write current position to ring buffer
    !
    ! body_idx: 1-based index into bodies array
    ! pos_au: position in AU (world units for the renderer)
    !=====================================================================
    subroutine trails_push_body(trails, body_idx, pos_au)
        type(trails_t), intent(inout) :: trails
        integer, intent(in) :: body_idx
        real(c_float), intent(in) :: pos_au(3)

        integer :: slot_offset, byte_offset
        real(c_float), target :: pos_data(3)

        if (.not. trails%initialized) return

        ! Advance ring buffer head
        trails%head(body_idx) = mod(trails%head(body_idx) + 1, trails%max_slots)
        if (trails%count(body_idx) < trails%max_slots) then
            trails%count(body_idx) = trails%count(body_idx) + 1
        end if

        ! Write position to the ring buffer slot
        pos_data = pos_au
        slot_offset = (body_idx - 1) * trails%max_slots + trails%head(body_idx) - 1
        byte_offset = slot_offset * 3 * 4  ! 3 floats * 4 bytes

        call gl_bind_buffer(GL_ARRAY_BUFFER, trails%vbo)
        call gl_buffer_subdata(GL_ARRAY_BUFFER, int(byte_offset, c_int), &
                               int(12, c_int), c_loc(pos_data(1)))
    end subroutine trails_push_body

    !=====================================================================
    ! trails_render — draw all trail line strips
    !=====================================================================
    subroutine trails_render(trails, cam)
        type(trails_t), intent(inout) :: trails
        type(camera_t), intent(in) :: cam
        integer :: i, start_slot, count
        integer(c_int) :: loc
        real(c_float) :: view_arr(16), proj_arr(16)

        if (.not. trails%initialized) return
        if (.not. trails%visible) return

        ! Enable additive blending for trails
        call gl_enable(GL_BLEND)

        call shader_use(trails%shader)
        call gl_bind_vertex_array(trails%vao)
        call gl_bind_buffer(GL_ARRAY_BUFFER, trails%vbo)

        ! Set view and projection uniforms once
        view_arr = camera_get_view(cam)
        proj_arr = camera_get_projection(cam)
        loc = gl_get_uniform_location_local(trails%shader%id, "u_view")
        call gl_uniform_matrix4fv_local(loc, view_arr)
        loc = gl_get_uniform_location_local(trails%shader%id, "u_proj")
        call gl_uniform_matrix4fv_local(loc, proj_arr)

        ! Set up vertex attribute: position (3 floats)
        call gl_enable_vertex_attrib_array(0)
        call gl_vertex_attrib_pointer_with_offset(0, 3, GL_FLOAT, .false., 0, 0)

        do i = 1, trails%n_bodies
            if (trails%count(i) < 2) cycle

            count = trails%count(i)
            start_slot = mod(trails%head(i) - trails%count(i), trails%max_slots)
            if (start_slot < 0) start_slot = start_slot + trails%max_slots

            ! Set uniforms
            loc = gl_get_uniform_location_local(trails%shader%id, "u_head")
            call gl_uniform1i_local(loc, trails%head(i) - 1)

            loc = gl_get_uniform_location_local(trails%shader%id, "u_max_slots")
            call gl_uniform1i_local(loc, trails%max_slots)

            ! Bind the correct buffer slice via byte offset
            call gl_vertex_attrib_pointer_with_offset(0, 3, GL_FLOAT, .false., 0, &
                                                       start_slot * 12)

            call gl_draw_arrays(GL_LINE_STRIP, 0, int(count, c_int))
        end do

        call gl_disable(GL_BLEND)
        call gl_bind_vertex_array(0_c_int)
    end subroutine trails_render

    !=====================================================================
    ! trails_shutdown
    !=====================================================================
    subroutine trails_shutdown(trails)
        type(trails_t), intent(inout) :: trails
        integer(c_int) :: buf_arr(1)

        if (.not. trails%initialized) return

        call shader_destroy(trails%shader)
        if (trails%vbo /= 0_c_int) then
            buf_arr(1) = trails%vbo
            call gl_delete_buffers(1, buf_arr)
        end if
        if (trails%vao /= 0_c_int) then
            buf_arr(1) = trails%vao
            call gl_delete_vertex_arrays(1, buf_arr)
        end if
        if (allocated(trails%head)) deallocate(trails%head)
        if (allocated(trails%count)) deallocate(trails%count)
        trails%initialized = .false.
    end subroutine trails_shutdown

    !=====================================================================
    ! Local GL wrappers
    !=====================================================================
    subroutine gl_enable_vertex_attrib_array(index)
        integer(c_int), intent(in) :: index
        interface
            pure subroutine ss_glEnableVertexAttribArray(index) bind(c, name="ss_glEnableVertexAttribArray")
                import :: c_int
                integer(c_int), value, intent(in) :: index
            end subroutine ss_glEnableVertexAttribArray
        end interface
        call ss_glEnableVertexAttribArray(index)
    end subroutine gl_enable_vertex_attrib_array

    subroutine gl_vertex_attrib_pointer_with_offset(index, size, type, normalized, stride, byte_offset)
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
    end subroutine gl_vertex_attrib_pointer_with_offset

    function gl_get_uniform_location_local(program, name) result(loc)
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
    end function gl_get_uniform_location_local

    subroutine gl_uniform1i_local(loc, v)
        integer(c_int), intent(in) :: loc, v
        interface
            pure subroutine ss_glUniform1i(l, val) bind(c, name="ss_glUniform1i")
                import :: c_int
                integer(c_int), value, intent(in) :: l, val
            end subroutine ss_glUniform1i
        end interface
        call ss_glUniform1i(loc, v)
    end subroutine gl_uniform1i_local

    subroutine gl_uniform_matrix4fv_local(loc, m)
        integer(c_int), intent(in) :: loc
        real(c_float), intent(in) :: m(16)
        interface
            pure subroutine ss_glUniformMatrix4fv(l, cnt, tr, val) &
                    bind(c, name="ss_glUniformMatrix4fv")
                import :: c_int, c_float
                integer(c_int), value, intent(in) :: l, cnt, tr
                real(c_float), intent(in) :: val(*)
            end subroutine ss_glUniformMatrix4fv
        end interface
        call ss_glUniformMatrix4fv(loc, 1, 0, m)
    end subroutine gl_uniform_matrix4fv_local

end module trails_mod
