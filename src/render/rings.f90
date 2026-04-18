!===============================================================================
! rings.f90 — Saturn ring system: flat annulus mesh + textured quad shader.
!
! The ring mesh lives in the planet's local XZ plane. Radii are in the same
! visual-unit space as the planet sphere (matching the Saturn visual radius
! chosen in the renderer).
!===============================================================================
module rings_mod
    use, intrinsic :: iso_c_binding, only: c_float, c_int, c_ptr, c_loc, c_null_ptr
    use gl_bindings, only: &
        gl_gen_buffers, gl_bind_buffer, gl_buffer_data, gl_delete_buffers, &
        gl_gen_vertex_arrays, gl_bind_vertex_array, gl_delete_vertex_arrays, &
        gl_enable_vertex_attrib_array, gl_vertex_attrib_pointer, &
        gl_vertex_attrib_pointer_offset, &
        gl_use_program, gl_bind_texture, gl_active_texture, &
        gl_draw_elements_instanced, &
        gl_enable, gl_disable, gl_depth_mask, gl_blend_func, &
        GL_ARRAY_BUFFER, GL_ELEMENT_ARRAY_BUFFER, &
        GL_STATIC_DRAW, GL_FLOAT, GL_UNSIGNED_INT, GL_TRIANGLES, &
        GL_TEXTURE_2D, GL_TEXTURE0, GL_BLEND, GL_SRC_ALPHA, &
        GL_ONE_MINUS_SRC_ALPHA, GL_TRUE, GL_FALSE
    use shader_mod, only: shader_program_t, shader_load, shader_use, &
                          shader_destroy, set_uniform_mat4, set_uniform_vec3, &
                          set_uniform_float, set_uniform_int
    use texture_mod, only: texture_t, texture_load, texture_destroy, texture_bind
    use mat4_math, only: mat4, mat4_to_array
    use logging, only: log_msg, LOG_INFO
    implicit none
    private

    public :: rings_t, rings_init, rings_render, rings_destroy

    type :: rings_t
        integer(c_int)          :: vao = 0_c_int
        integer(c_int)          :: vbo = 0_c_int
        integer(c_int)          :: ebo = 0_c_int
        integer(c_int)          :: n_idx = 0_c_int
        type(shader_program_t)  :: shader
        type(texture_t)         :: tex
        real(c_float)           :: inner_radius = 1.3_c_float
        real(c_float)           :: outer_radius = 2.2_c_float
        logical                 :: initialized = .false.
    end type rings_t

contains

    subroutine rings_init(rings, texture_path, inner, outer, segments)
        type(rings_t), intent(out) :: rings
        character(len=*), intent(in) :: texture_path
        real(c_float), intent(in) :: inner, outer
        integer, intent(in) :: segments

        integer :: i, nv, ni, vi, ii
        real(c_float), allocatable, target :: verts(:)
        integer(c_int), allocatable, target :: idx(:)
        integer(c_int) :: vao(1), vbo(1), ebo(1)
        real(c_float) :: pi, ang, ca, sa

        pi = 3.14159265358979323846_c_float
        rings%inner_radius = inner
        rings%outer_radius = outer

        nv = (segments + 1) * 2            ! inner+outer per segment, duplicated at seam
        ni = segments * 6
        allocate(verts(5 * nv))            ! pos(3) + uv(2)
        allocate(idx(ni))

        vi = 0
        do i = 0, segments
            ang = 2.0_c_float * pi * real(i, c_float) / real(segments, c_float)
            ca = cos(ang); sa = sin(ang)
            ! Inner vertex
            verts(vi + 1) = inner * ca
            verts(vi + 2) = 0.0_c_float
            verts(vi + 3) = inner * sa
            verts(vi + 4) = 0.0_c_float          ! u=0 at inner
            verts(vi + 5) = 0.5_c_float
            ! Outer vertex
            verts(vi + 6) = outer * ca
            verts(vi + 7) = 0.0_c_float
            verts(vi + 8) = outer * sa
            verts(vi + 9)  = 1.0_c_float         ! u=1 at outer
            verts(vi + 10) = 0.5_c_float
            vi = vi + 10
        end do

        ii = 0
        do i = 0, segments - 1
            idx(ii + 1) = int(i * 2,       c_int)
            idx(ii + 2) = int(i * 2 + 1,   c_int)
            idx(ii + 3) = int(i * 2 + 2,   c_int)
            idx(ii + 4) = int(i * 2 + 1,   c_int)
            idx(ii + 5) = int(i * 2 + 3,   c_int)
            idx(ii + 6) = int(i * 2 + 2,   c_int)
            ii = ii + 6
        end do

        call gl_gen_vertex_arrays(1, vao)
        call gl_bind_vertex_array(vao(1))

        call gl_gen_buffers(1, vbo)
        call gl_bind_buffer(GL_ARRAY_BUFFER, vbo(1))
        call gl_buffer_data(GL_ARRAY_BUFFER, int(5 * 4 * nv, c_int), &
                            c_loc(verts(1)), GL_STATIC_DRAW)

        call gl_gen_buffers(1, ebo)
        call gl_bind_buffer(GL_ELEMENT_ARRAY_BUFFER, ebo(1))
        call gl_buffer_data(GL_ELEMENT_ARRAY_BUFFER, int(4 * ni, c_int), &
                            c_loc(idx(1)), GL_STATIC_DRAW)

        call gl_enable_vertex_attrib_array(0)
        call gl_vertex_attrib_pointer(0, 3, GL_FLOAT, .false., 20, c_null_ptr)
        call gl_enable_vertex_attrib_array(1)
        call gl_vertex_attrib_pointer_offset(1, 2, GL_FLOAT, .false., 20, 12)

        call gl_bind_vertex_array(0_c_int)
        call gl_bind_buffer(GL_ARRAY_BUFFER, 0_c_int)
        call gl_bind_buffer(GL_ELEMENT_ARRAY_BUFFER, 0_c_int)

        rings%vao = vao(1)
        rings%vbo = vbo(1)
        rings%ebo = ebo(1)
        rings%n_idx = int(ni, c_int)

        rings%shader = shader_load("shaders/ring.vert", "shaders/ring.frag")
        call texture_load(rings%tex, texture_path, srgb=.true., clamp=.true.)

        rings%initialized = rings%shader%valid .and. rings%tex%valid
        deallocate(verts, idx)
        if (rings%initialized) call log_msg(LOG_INFO, "Rings initialized")
    end subroutine rings_init

    subroutine rings_render(rings, model, view, proj, light_pos, planet_pos, planet_radius)
        type(rings_t), intent(in) :: rings
        type(mat4), intent(in) :: model
        real(c_float), intent(in) :: view(16), proj(16)
        real(c_float), intent(in) :: light_pos(3), planet_pos(3), planet_radius

        real(c_float) :: model_arr(16)

        if (.not. rings%initialized) return

        call shader_use(rings%shader)
        model_arr = mat4_to_array(model)
        call set_uniform_mat4(rings%shader, "u_model", model_arr)
        call set_uniform_mat4(rings%shader, "u_view", view)
        call set_uniform_mat4(rings%shader, "u_proj", proj)

        call texture_bind(rings%tex, GL_TEXTURE0)
        call set_uniform_int(rings%shader, "u_alpha", 0_c_int)
        call set_uniform_vec3(rings%shader, "u_light_pos", &
                              light_pos(1), light_pos(2), light_pos(3))
        call set_uniform_vec3(rings%shader, "u_planet_pos", &
                              planet_pos(1), planet_pos(2), planet_pos(3))
        call set_uniform_float(rings%shader, "u_planet_radius", planet_radius)
        call set_uniform_vec3(rings%shader, "u_tint", &
                              1.0_c_float, 0.95_c_float, 0.85_c_float)

        call gl_bind_vertex_array(rings%vao)
        call gl_enable(GL_BLEND)
        call gl_blend_func(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
        call gl_depth_mask(.false.)
        call gl_draw_elements_instanced(GL_TRIANGLES, rings%n_idx, &
                                        GL_UNSIGNED_INT, c_null_ptr, 1_c_int)
        call gl_depth_mask(.true.)
        call gl_disable(GL_BLEND)
        call gl_bind_vertex_array(0_c_int)
    end subroutine rings_render

    subroutine rings_destroy(rings)
        type(rings_t), intent(inout) :: rings
        integer(c_int) :: tmp(1)
        if (.not. rings%initialized) return
        tmp(1) = rings%vbo; call gl_delete_buffers(1, tmp)
        tmp(1) = rings%ebo; call gl_delete_buffers(1, tmp)
        tmp(1) = rings%vao; call gl_delete_vertex_arrays(1, tmp)
        call shader_destroy(rings%shader)
        call texture_destroy(rings%tex)
        rings%initialized = .false.
    end subroutine rings_destroy

end module rings_mod
