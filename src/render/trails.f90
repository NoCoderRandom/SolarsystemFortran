!===============================================================================
! trails.f90 — GPU-buffered orbit trails with fading
!
! Per-body ring buffer: one VBO holding N positions per body.
! Ring buffer managed CPU-side (head/count per body). Each frame we write
! the current position into the head slot via glBufferSubData (12 bytes).
!
! Rendering: one VAO shared, one glDrawArrays(GL_LINE_STRIP) per body
! (two draws when the ring has wrapped, to walk the ring in oldest→newest
! order). Fade is computed in the vertex shader from the vertex's sequence
! index; additive blending produces a glow where trails overlap.
!===============================================================================
module trails_mod
    use, intrinsic :: iso_c_binding, only: c_float, c_int, c_null_ptr, c_loc
    use gl_bindings, only: &
        gl_enable, gl_disable, gl_draw_arrays, &
        gl_gen_vertex_arrays, gl_bind_vertex_array, gl_delete_vertex_arrays, &
        gl_gen_buffers, gl_bind_buffer, gl_buffer_data, gl_buffer_subdata, &
        gl_delete_buffers, &
        gl_enable_vertex_attrib_array, gl_vertex_attrib_pointer_offset, &
        gl_line_width, gl_depth_mask, gl_blend_func, &
        GL_ARRAY_BUFFER, GL_DYNAMIC_DRAW, GL_FLOAT, GL_LINE_STRIP, &
        GL_BLEND, GL_SRC_ALPHA, GL_ONE
    use shader_mod, only: shader_program_t, shader_load, shader_use, &
                          shader_destroy, set_uniform_mat4, set_uniform_vec3, &
                          set_uniform_float, set_uniform_int
    use camera_mod, only: camera_t, camera_get_view, camera_get_projection
    implicit none
    private

    public :: trails_t, trails_init, trails_shutdown, trails_clear
    public :: trails_push_body, trails_render, trails_set_visibility
    public :: trails_set_body_color

    type, public :: trails_t
        type(shader_program_t) :: shader
        integer(c_int) :: vao = 0_c_int
        integer(c_int) :: vbo = 0_c_int
        logical :: initialized = .false.
        logical :: visible = .true.
        integer, allocatable :: head(:)             ! next-write slot per body
        integer, allocatable :: count(:)            ! filled slots per body
        real(c_float), allocatable :: body_colors(:,:)  ! (3, n_bodies)
        integer :: n_bodies = 0
        integer :: max_slots = 0
        real(c_float) :: line_width = 2.0_c_float
        real(c_float) :: gamma = 1.5_c_float
    end type trails_t

contains

    subroutine trails_init(trails, n_bodies, max_slots)
        type(trails_t), intent(out) :: trails
        integer, intent(in) :: n_bodies, max_slots
        integer :: total_slots, i
        real(c_float), allocatable, target :: zero_data(:)
        integer(c_int) :: buf_arr(1)

        trails%shader = shader_load("shaders/trail.vert", "shaders/trail.frag")
        if (.not. trails%shader%valid) return

        trails%n_bodies = n_bodies
        trails%max_slots = max_slots
        total_slots = n_bodies * max_slots

        call gl_gen_buffers(1, buf_arr)
        trails%vbo = buf_arr(1)
        call gl_gen_vertex_arrays(1, buf_arr)
        trails%vao = buf_arr(1)

        allocate(zero_data(3 * total_slots))
        zero_data = 0.0_c_float
        call gl_bind_buffer(GL_ARRAY_BUFFER, trails%vbo)
        call gl_buffer_data(GL_ARRAY_BUFFER, &
                            int(3_c_int * 4_c_int * total_slots, c_int), &
                            c_loc(zero_data(1)), GL_DYNAMIC_DRAW)
        deallocate(zero_data)

        ! Configure VAO attribute (buffer bound above).
        call gl_bind_vertex_array(trails%vao)
        call gl_bind_buffer(GL_ARRAY_BUFFER, trails%vbo)
        call gl_enable_vertex_attrib_array(0)
        call gl_vertex_attrib_pointer_offset(0, 3, GL_FLOAT, .false., &
                                             int(3_c_int * 4_c_int, c_int), 0)
        call gl_bind_vertex_array(0_c_int)

        allocate(trails%head(n_bodies))
        allocate(trails%count(n_bodies))
        allocate(trails%body_colors(3, n_bodies))
        do i = 1, n_bodies
            trails%head(i) = 0
            trails%count(i) = 0
            trails%body_colors(:, i) = 1.0_c_float
        end do

        trails%initialized = .true.
        trails%visible = .true.
    end subroutine trails_init

    subroutine trails_set_visibility(trails, vis)
        type(trails_t), intent(inout) :: trails
        logical, intent(in) :: vis
        trails%visible = vis
    end subroutine trails_set_visibility

    subroutine trails_set_body_color(trails, body_idx, r, g, b)
        type(trails_t), intent(inout) :: trails
        integer, intent(in) :: body_idx
        real(c_float), intent(in) :: r, g, b
        if (.not. trails%initialized) return
        if (body_idx < 1 .or. body_idx > trails%n_bodies) return
        trails%body_colors(1, body_idx) = r
        trails%body_colors(2, body_idx) = g
        trails%body_colors(3, body_idx) = b
    end subroutine trails_set_body_color

    subroutine trails_clear(trails)
        type(trails_t), intent(inout) :: trails
        integer :: i, total_slots
        real(c_float), allocatable, target :: zero_data(:)

        if (.not. trails%initialized) return

        do i = 1, trails%n_bodies
            trails%head(i) = 0
            trails%count(i) = 0
        end do

        total_slots = trails%n_bodies * trails%max_slots
        allocate(zero_data(3 * total_slots))
        zero_data = 0.0_c_float
        call gl_bind_buffer(GL_ARRAY_BUFFER, trails%vbo)
        call gl_buffer_subdata(GL_ARRAY_BUFFER, 0_c_int, &
                               int(3_c_int * 4_c_int * total_slots, c_int), &
                               c_loc(zero_data(1)))
        deallocate(zero_data)
    end subroutine trails_clear

    !---------------------------------------------------------------
    ! Write current position into the body's ring head and advance.
    !---------------------------------------------------------------
    subroutine trails_push_body(trails, body_idx, pos_au)
        type(trails_t), intent(inout) :: trails
        integer, intent(in) :: body_idx
        real(c_float), intent(in) :: pos_au(3)

        integer :: slot_offset, byte_offset, write_slot
        real(c_float), target :: pos_data(3)

        if (.not. trails%initialized) return
        if (body_idx < 1 .or. body_idx > trails%n_bodies) return

        write_slot = trails%head(body_idx)
        slot_offset = (body_idx - 1) * trails%max_slots + write_slot
        byte_offset = slot_offset * 3 * 4

        pos_data = pos_au
        call gl_bind_buffer(GL_ARRAY_BUFFER, trails%vbo)
        call gl_buffer_subdata(GL_ARRAY_BUFFER, int(byte_offset, c_int), &
                               int(12, c_int), c_loc(pos_data(1)))

        trails%head(body_idx) = mod(write_slot + 1, trails%max_slots)
        if (trails%count(body_idx) < trails%max_slots) then
            trails%count(body_idx) = trails%count(body_idx) + 1
        end if
    end subroutine trails_push_body

    !---------------------------------------------------------------
    ! Render all trails. Caller owns the surrounding depth/blend
    ! restore if it cares — we set the state we need and reset the
    ! bits that would affect opaque rendering downstream.
    !---------------------------------------------------------------
    subroutine trails_render(trails, cam, log_scale, log_center, log_k)
        type(trails_t), intent(inout) :: trails
        type(camera_t), intent(in) :: cam
        logical,       intent(in) :: log_scale
        real(c_float), intent(in) :: log_center(3), log_k

        integer :: i, body_base, start_slot, cnt
        integer :: count1, count2, byte_off
        real(c_float) :: view_arr(16), proj_arr(16)

        if (.not. trails%initialized) return
        if (.not. trails%visible) return

        call shader_use(trails%shader)
        view_arr = camera_get_view(cam)
        proj_arr = camera_get_projection(cam)
        call set_uniform_mat4(trails%shader, "u_view", view_arr)
        call set_uniform_mat4(trails%shader, "u_proj", proj_arr)
        call set_uniform_int(trails%shader, "u_max_slots", &
                             int(trails%max_slots, c_int))
        call set_uniform_float(trails%shader, "u_gamma", trails%gamma)
        call set_uniform_float(trails%shader, "u_log_scale", &
                               merge(1.0_c_float, 0.0_c_float, log_scale))
        call set_uniform_vec3(trails%shader, "u_log_center", &
                              log_center(1), log_center(2), log_center(3))
        call set_uniform_float(trails%shader, "u_log_k", log_k)

        call gl_enable(GL_BLEND)
        call gl_blend_func(GL_SRC_ALPHA, GL_ONE)
        call gl_depth_mask(.false.)
        call gl_line_width(trails%line_width)

        call gl_bind_vertex_array(trails%vao)
        call gl_bind_buffer(GL_ARRAY_BUFFER, trails%vbo)
        call gl_enable_vertex_attrib_array(0)

        do i = 1, trails%n_bodies
            cnt = trails%count(i)
            if (cnt < 2) cycle

            call set_uniform_vec3(trails%shader, "u_color", &
                trails%body_colors(1, i), trails%body_colors(2, i), &
                trails%body_colors(3, i))
            call set_uniform_int(trails%shader, "u_count", int(cnt, c_int))

            body_base = (i - 1) * trails%max_slots * 3 * 4
            start_slot = mod(trails%head(i) - cnt + trails%max_slots, &
                             trails%max_slots)

            if (cnt < trails%max_slots) then
                ! Ring not wrapped: contiguous [0 .. cnt-1].
                byte_off = body_base + start_slot * 3 * 4
                call gl_vertex_attrib_pointer_offset(0, 3, GL_FLOAT, .false., &
                                                    int(3_c_int * 4_c_int, c_int), &
                                                    byte_off)
                call set_uniform_int(trails%shader, "u_seq_offset", 0_c_int)
                call gl_draw_arrays(GL_LINE_STRIP, 0_c_int, int(cnt, c_int))
            else
                ! Wrapped: oldest at slot=head. Walk [head .. N-1] then [0 .. head-1].
                count1 = trails%max_slots - trails%head(i)
                count2 = trails%head(i)

                byte_off = body_base + trails%head(i) * 3 * 4
                call gl_vertex_attrib_pointer_offset(0, 3, GL_FLOAT, .false., &
                                                    int(3_c_int * 4_c_int, c_int), &
                                                    byte_off)
                call set_uniform_int(trails%shader, "u_seq_offset", 0_c_int)
                call gl_draw_arrays(GL_LINE_STRIP, 0_c_int, int(count1, c_int))

                if (count2 > 0) then
                    byte_off = body_base
                    call gl_vertex_attrib_pointer_offset(0, 3, GL_FLOAT, .false., &
                                                        int(3_c_int * 4_c_int, c_int), &
                                                        byte_off)
                    call set_uniform_int(trails%shader, "u_seq_offset", &
                                         int(count1, c_int))
                    call gl_draw_arrays(GL_LINE_STRIP, 0_c_int, int(count2, c_int))
                end if
            end if
        end do

        call gl_bind_vertex_array(0_c_int)

        ! Restore state for subsequent opaque passes.
        call gl_depth_mask(.true.)
        call gl_disable(GL_BLEND)
    end subroutine trails_render

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
        if (allocated(trails%head))        deallocate(trails%head)
        if (allocated(trails%count))       deallocate(trails%count)
        if (allocated(trails%body_colors)) deallocate(trails%body_colors)
        trails%initialized = .false.
    end subroutine trails_shutdown

end module trails_mod
