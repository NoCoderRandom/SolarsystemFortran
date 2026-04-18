!===============================================================================
! mesh.f90 — VAO + VBO + EBO wrapper with UV-sphere generator
!===============================================================================
module mesh_mod
    use, intrinsic :: iso_c_binding, only: c_float, c_int, c_ptr, c_null_ptr, &
        c_loc, c_intptr_t
    use, intrinsic :: iso_fortran_env, only: real32
    use gl_bindings, only: &
        gl_gen_buffers, gl_bind_buffer, gl_buffer_data, gl_delete_buffers, &
        gl_gen_vertex_arrays, gl_bind_vertex_array, gl_delete_vertex_arrays, &
        gl_enable_vertex_attrib_array, gl_vertex_attrib_pointer, &
        gl_vertex_attrib_divisor, gl_vertex_attrib_pointer_offset, &
        GL_ARRAY_BUFFER, GL_ELEMENT_ARRAY_BUFFER, &
        GL_STATIC_DRAW, GL_FLOAT, GL_FALSE, GL_TRIANGLES, GLuint_t
    use logging, only: log_msg, LOG_DEBUG
    implicit none
    private

    public :: mesh_t, mesh_create_sphere, mesh_destroy

    type, public :: mesh_t
        integer(c_int) :: vao    = 0_c_int
        integer(c_int) :: vbo    = 0_c_int
        integer(c_int) :: ebo    = 0_c_int
        integer(c_int) :: n_idx  = 0_c_int
        logical        :: valid  = .false.
    end type mesh_t

contains

    subroutine mesh_create_sphere(mesh, lat_segments, lon_segments)
        type(mesh_t), intent(out) :: mesh
        integer, intent(in) :: lat_segments, lon_segments

        integer, parameter :: FLOATS_PER_VERT = 14
        integer, parameter :: STRIDE_BYTES    = FLOATS_PER_VERT * 4
        integer :: n_vertices, n_indices
        real(c_float), allocatable, target :: vertices(:)
        integer(c_int), allocatable, target :: indices(:)
        integer(c_int) :: vbo(1), ebo(1), vao(1)
        integer :: i, j, vi
        integer(c_int) :: idx
        integer(c_int) :: a, b, c_idx, d_idx
        real(c_float) :: pi, lat_step, lon_step
        real(c_float) :: phi, theta, x, y, z, sin_phi, cos_phi
        real(c_float) :: u, v
        real(c_float) :: sin_th, cos_th
        real(c_float) :: tx, ty, tz, bx, by, bz

        pi = 3.14159265358979323846_c_float

        lat_step = pi / real(lat_segments, c_float)
        lon_step = 2.0_c_float * pi / real(lon_segments, c_float)
        n_vertices = (lat_segments + 1) * (lon_segments + 1)
        n_indices  = lat_segments * lon_segments * 6
        allocate(vertices(FLOATS_PER_VERT * n_vertices))
        allocate(indices(n_indices))

        ! Generate vertices: pos(3) + uv(2) + normal(3) + tangent(3) + bitangent(3)
        ! For a unit sphere the normal equals the position.
        ! Tangent  (along +U, i.e. d/dθ, normalized): (-sinθ, 0, cosθ)
        ! Bitangent (along +V, i.e. d/dφ):           ( cosφ cosθ, -sinφ, cosφ sinθ )
        vi = 0
        do i = 0, lat_segments
            phi = real(i, c_float) * lat_step
            sin_phi = sin(phi)
            cos_phi = cos(phi)
            do j = 0, lon_segments
                theta = real(j, c_float) * lon_step
                sin_th = sin(theta)
                cos_th = cos(theta)
                x = sin_phi * cos_th
                y = cos_phi
                z = sin_phi * sin_th
                u = real(j, c_float) / real(lon_segments, c_float)
                v = real(i, c_float) / real(lat_segments, c_float)

                tx = -sin_th; ty = 0.0_c_float; tz = cos_th
                bx = cos_phi * cos_th; by = -sin_phi; bz = cos_phi * sin_th

                vertices(vi + 1) = x
                vertices(vi + 2) = y
                vertices(vi + 3) = z
                vertices(vi + 4) = u
                vertices(vi + 5) = v
                vertices(vi + 6) = x   ! normal = position
                vertices(vi + 7) = y
                vertices(vi + 8) = z
                vertices(vi + 9)  = tx
                vertices(vi + 10) = ty
                vertices(vi + 11) = tz
                vertices(vi + 12) = bx
                vertices(vi + 13) = by
                vertices(vi + 14) = bz
                vi = vi + FLOATS_PER_VERT
            end do
        end do

        ! Generate indices
        idx = 0_c_int
        do i = 0, lat_segments - 1
            do j = 0, lon_segments - 1
                a = int(i * (lon_segments + 1) + j, c_int)
                b = a + 1_c_int
                c_idx = int((i + 1) * (lon_segments + 1) + j, c_int)
                d_idx = c_idx + 1_c_int
                indices(idx + 1) = a
                indices(idx + 2) = b
                indices(idx + 3) = c_idx
                indices(idx + 4) = b
                indices(idx + 5) = d_idx
                indices(idx + 6) = c_idx
                idx = idx + 6_c_int
            end do
        end do

        ! Upload to GPU
        call gl_gen_vertex_arrays(1, vao)
        call gl_bind_vertex_array(vao(1))

        call gl_gen_buffers(1, vbo)
        call gl_bind_buffer(GL_ARRAY_BUFFER, vbo(1))
        call gl_buffer_data(GL_ARRAY_BUFFER, &
                            int(STRIDE_BYTES * n_vertices, c_int), &
                            c_loc(vertices(1)), GL_STATIC_DRAW)

        call gl_gen_buffers(1, ebo)
        call gl_bind_buffer(GL_ELEMENT_ARRAY_BUFFER, ebo(1))
        call gl_buffer_data(GL_ELEMENT_ARRAY_BUFFER, &
                            int(4_c_int * n_indices, c_int), &
                            c_loc(indices(1)), GL_STATIC_DRAW)

        ! Vertex layout (stride 56): pos(0..11) uv(12..19) normal(20..31)
        !                            tangent(32..43) bitangent(44..55)
        call gl_enable_vertex_attrib_array(0)
        call gl_vertex_attrib_pointer(0, 3, GL_FLOAT, .false., STRIDE_BYTES, c_null_ptr)

        call gl_enable_vertex_attrib_array(1)
        call gl_vertex_attrib_pointer_offset(1, 2, GL_FLOAT, .false., STRIDE_BYTES, 12)

        ! Normal/tangent/bitangent at attribute slots 7/8/9
        ! (slots 2..6 are reserved for per-instance model matrix + color)
        call gl_enable_vertex_attrib_array(7)
        call gl_vertex_attrib_pointer_offset(7, 3, GL_FLOAT, .false., STRIDE_BYTES, 20)
        call gl_enable_vertex_attrib_array(8)
        call gl_vertex_attrib_pointer_offset(8, 3, GL_FLOAT, .false., STRIDE_BYTES, 32)
        call gl_enable_vertex_attrib_array(9)
        call gl_vertex_attrib_pointer_offset(9, 3, GL_FLOAT, .false., STRIDE_BYTES, 44)

        call gl_bind_vertex_array(0_c_int)
        call gl_bind_buffer(GL_ARRAY_BUFFER, 0_c_int)
        call gl_bind_buffer(GL_ELEMENT_ARRAY_BUFFER, 0_c_int)

        mesh%vao   = vao(1)
        mesh%vbo   = vbo(1)
        mesh%ebo   = ebo(1)
        mesh%n_idx = int(n_indices, c_int)
        mesh%valid = .true.

        call log_msg(LOG_DEBUG, "Sphere mesh: " // trim(itoa(n_vertices)) // &
                     " vertices, " // trim(itoa(n_indices)) // " indices")

        deallocate(vertices, indices)
    end subroutine mesh_create_sphere

    subroutine mesh_destroy(mesh)
        type(mesh_t), intent(inout) :: mesh
        integer(c_int) :: buf(1)

        if (.not. mesh%valid) return

        buf(1) = mesh%vbo
        call gl_delete_buffers(1, buf)
        buf(1) = mesh%ebo
        call gl_delete_buffers(1, buf)
        buf(1) = mesh%vao
        call gl_delete_vertex_arrays(1, buf)

        mesh%vao   = 0_c_int
        mesh%vbo   = 0_c_int
        mesh%ebo   = 0_c_int
        mesh%n_idx = 0_c_int
        mesh%valid = .false.
    end subroutine mesh_destroy

    pure function itoa(i) result(s)
        integer, intent(in) :: i
        character(len=12) :: s
        write(s, "(I0)") i
    end function itoa

end module mesh_mod
