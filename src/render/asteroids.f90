!===============================================================================
! asteroids.f90 — Instanced Keplerian asteroid belt.
!
! Generates N asteroids with randomised orbital elements in the main-belt band
! (a in [2.2, 3.3] AU by default). Positions are solved entirely on the GPU
! from time via Newton-Raphson on Kepler's equation, so this module uploads
! each instance's elements once and then costs nothing per frame beyond the
! draw call.
!
! Visual variety comes from three procedurally-displaced low-poly "icosphere"
! meshes — really low-res UV spheres with per-vertex radial noise — rendered
! with flat shading (the fragment shader derives the normal from dFdx/dFdy of
! the world-space position). Each mesh gets its own VAO + instance VBO and is
! drawn in a single call.
!===============================================================================
module asteroids_mod
    use, intrinsic :: iso_c_binding, only: c_float, c_int, c_loc, c_null_ptr
    use, intrinsic :: iso_fortran_env, only: real64
    use gl_bindings, only: &
        gl_gen_buffers, gl_bind_buffer, gl_buffer_data, gl_delete_buffers, &
        gl_gen_vertex_arrays, gl_bind_vertex_array, gl_delete_vertex_arrays, &
        gl_enable_vertex_attrib_array, gl_vertex_attrib_pointer, &
        gl_vertex_attrib_pointer_offset, gl_vertex_attrib_divisor, &
        gl_enable, gl_set_cull_face, gl_set_front_face, &
        gl_draw_elements_instanced, &
        GL_ARRAY_BUFFER, GL_ELEMENT_ARRAY_BUFFER, &
        GL_STATIC_DRAW, GL_FLOAT, GL_TRIANGLES, GL_UNSIGNED_INT, &
        GL_DEPTH_TEST, GL_CULL_FACE, GL_BACK, GL_CCW
    use shader_mod, only: shader_program_t, shader_load, shader_use, &
                          shader_destroy, set_uniform_mat4, set_uniform_vec3, &
                          set_uniform_float
    use camera_mod, only: camera_t, camera_get_view, camera_get_projection
    use logging, only: log_msg, LOG_INFO, LOG_ERROR
    use constants, only: G_SI, M_SUN, AU
    implicit none
    private

    public :: asteroids_t, asteroids_init, asteroids_shutdown, asteroids_render

    integer, parameter :: N_VARIANTS        = 3
    integer, parameter :: MESH_LAT_SEGMENTS = 8
    integer, parameter :: MESH_LON_SEGMENTS = 10
    integer, parameter :: FLOATS_PER_INST   = 12   ! 3 × vec4

    real(c_float), parameter :: PI_F    = 3.14159265358979323846_c_float
    real(c_float), parameter :: TWOPI_F = 2.0_c_float * PI_F
    real(c_float), parameter :: AU_F    = real(AU, c_float)
    real(c_float), parameter :: GM_SUN_F = real(G_SI * M_SUN, c_float)

    type :: asteroid_variant_t
        integer(c_int) :: vao       = 0_c_int
        integer(c_int) :: vbo_mesh  = 0_c_int
        integer(c_int) :: ebo       = 0_c_int
        integer(c_int) :: vbo_inst  = 0_c_int
        integer(c_int) :: n_idx     = 0_c_int
        integer(c_int) :: n_inst    = 0_c_int
    end type asteroid_variant_t

    type :: asteroids_t
        type(asteroid_variant_t) :: variants(N_VARIANTS)
        type(shader_program_t)   :: shader
        integer                  :: total = 0
        logical                  :: initialized = .false.
    end type asteroids_t

contains

    !---------------------------------------------------------------
    ! Build three lumpy meshes and distribute N asteroids across them.
    !---------------------------------------------------------------
    subroutine asteroids_init(at, n_asteroids, a_min_au, a_max_au)
        type(asteroids_t), intent(out) :: at
        integer, intent(in) :: n_asteroids
        real, intent(in) :: a_min_au, a_max_au

        integer :: k, seed_size, per_variant, leftover, count_k, offset_k
        integer, allocatable :: seed(:)

        if (n_asteroids <= 0) then
            at%total = 0
            at%initialized = .false.
            return
        end if

        ! Deterministic RNG so the belt is reproducible.
        call random_seed(size = seed_size)
        allocate(seed(seed_size))
        seed = 1337
        call random_seed(put = seed)
        deallocate(seed)

        per_variant = n_asteroids / N_VARIANTS
        leftover    = n_asteroids - per_variant * N_VARIANTS

        offset_k = 0
        do k = 1, N_VARIANTS
            count_k = per_variant
            if (k <= leftover) count_k = count_k + 1
            call build_variant(at%variants(k), k, count_k, &
                               real(a_min_au, c_float), real(a_max_au, c_float))
            offset_k = offset_k + count_k
        end do

        at%shader = shader_load("shaders/asteroid.vert", "shaders/asteroid.frag")
        if (.not. at%shader%valid) then
            call log_msg(LOG_ERROR, "Asteroids: shader load failed")
            at%initialized = .false.
            return
        end if

        at%total = n_asteroids
        at%initialized = .true.
        call log_msg(LOG_INFO, "Asteroid belt: " // itoa(n_asteroids) // &
                     " asteroids across " // itoa(N_VARIANTS) // " meshes")
    end subroutine asteroids_init

    subroutine asteroids_shutdown(at)
        type(asteroids_t), intent(inout) :: at
        integer :: k
        integer(c_int) :: arr(1)
        if (.not. at%initialized) return
        do k = 1, N_VARIANTS
            if (at%variants(k)%vbo_inst /= 0) then
                arr(1) = at%variants(k)%vbo_inst; call gl_delete_buffers(1, arr)
            end if
            if (at%variants(k)%vbo_mesh /= 0) then
                arr(1) = at%variants(k)%vbo_mesh; call gl_delete_buffers(1, arr)
            end if
            if (at%variants(k)%ebo /= 0) then
                arr(1) = at%variants(k)%ebo;     call gl_delete_buffers(1, arr)
            end if
            if (at%variants(k)%vao /= 0) then
                arr(1) = at%variants(k)%vao;     call gl_delete_vertex_arrays(1, arr)
            end if
        end do
        call shader_destroy(at%shader)
        at%initialized = .false.
    end subroutine asteroids_shutdown

    !---------------------------------------------------------------
    ! Render the whole belt: one draw per mesh variant.
    !---------------------------------------------------------------
    subroutine asteroids_render(at, cam, sun_pos, sim_time_sec)
        type(asteroids_t), intent(inout) :: at
        type(camera_t), intent(in) :: cam
        real(c_float), intent(in) :: sun_pos(3)
        real(real64), intent(in)  :: sim_time_sec

        real(c_float) :: view_arr(16), proj_arr(16)
        integer :: k

        if (.not. at%initialized) return
        if (at%total == 0) return

        view_arr = camera_get_view(cam)
        proj_arr = camera_get_projection(cam)

        call shader_use(at%shader)
        call set_uniform_mat4(at%shader, "u_view", view_arr)
        call set_uniform_mat4(at%shader, "u_proj", proj_arr)
        call set_uniform_float(at%shader, "u_time", real(sim_time_sec, c_float))
        call set_uniform_vec3(at%shader, "u_light_pos", &
                              sun_pos(1), sun_pos(2), sun_pos(3))
        call set_uniform_vec3(at%shader, "u_light_color", &
                              1.0_c_float, 0.97_c_float, 0.90_c_float)
        call set_uniform_float(at%shader, "u_ambient", 0.06_c_float)

        call gl_enable(GL_DEPTH_TEST)
        call gl_enable(GL_CULL_FACE)
        call gl_set_cull_face(GL_BACK)
        call gl_set_front_face(GL_CCW)

        do k = 1, N_VARIANTS
            if (at%variants(k)%n_inst == 0) cycle
            call gl_bind_vertex_array(at%variants(k)%vao)
            call gl_draw_elements_instanced(GL_TRIANGLES, &
                                            at%variants(k)%n_idx, &
                                            GL_UNSIGNED_INT, &
                                            c_null_ptr, &
                                            at%variants(k)%n_inst)
        end do
        call gl_bind_vertex_array(0_c_int)
    end subroutine asteroids_render

    !---------------------------------------------------------------
    ! Build one variant: lumpy sphere mesh + per-instance orbital data.
    !---------------------------------------------------------------
    subroutine build_variant(var, variant_seed, n_inst, a_min, a_max)
        type(asteroid_variant_t), intent(out) :: var
        integer, intent(in) :: variant_seed, n_inst
        real(c_float), intent(in) :: a_min, a_max

        real(c_float), allocatable, target :: verts(:)
        integer(c_int), allocatable, target :: indices(:)
        real(c_float), allocatable, target :: inst(:)

        integer :: n_vert, n_tri, n_idx
        integer(c_int) :: buf(1)

        call gen_lumpy_mesh(variant_seed, verts, indices, n_vert, n_tri)
        n_idx = 3 * n_tri

        call gl_gen_vertex_arrays(1, buf); var%vao = buf(1)
        call gl_bind_vertex_array(var%vao)

        call gl_gen_buffers(1, buf); var%vbo_mesh = buf(1)
        call gl_bind_buffer(GL_ARRAY_BUFFER, var%vbo_mesh)
        call gl_buffer_data(GL_ARRAY_BUFFER, &
                            int(3 * 4 * n_vert, c_int), &
                            c_loc(verts(1)), GL_STATIC_DRAW)

        call gl_gen_buffers(1, buf); var%ebo = buf(1)
        call gl_bind_buffer(GL_ELEMENT_ARRAY_BUFFER, var%ebo)
        call gl_buffer_data(GL_ELEMENT_ARRAY_BUFFER, &
                            int(4 * n_idx, c_int), &
                            c_loc(indices(1)), GL_STATIC_DRAW)

        ! Vertex layout: single vec3 position at loc 0, stride 12.
        call gl_enable_vertex_attrib_array(0)
        call gl_vertex_attrib_pointer(0, 3, GL_FLOAT, .false., 12, c_null_ptr)

        ! Per-instance data at locs 2, 3, 4. Stride = 48 (12 floats).
        call gen_instance_data(variant_seed, n_inst, a_min, a_max, inst)
        call gl_gen_buffers(1, buf); var%vbo_inst = buf(1)
        call gl_bind_buffer(GL_ARRAY_BUFFER, var%vbo_inst)
        call gl_buffer_data(GL_ARRAY_BUFFER, &
                            int(FLOATS_PER_INST * 4 * n_inst, c_int), &
                            c_loc(inst(1)), GL_STATIC_DRAW)

        call gl_enable_vertex_attrib_array(2)
        call gl_vertex_attrib_pointer_offset(2, 4, GL_FLOAT, .false., &
                                              FLOATS_PER_INST * 4, 0)
        call gl_vertex_attrib_divisor(2, 1)

        call gl_enable_vertex_attrib_array(3)
        call gl_vertex_attrib_pointer_offset(3, 4, GL_FLOAT, .false., &
                                              FLOATS_PER_INST * 4, 16)
        call gl_vertex_attrib_divisor(3, 1)

        call gl_enable_vertex_attrib_array(4)
        call gl_vertex_attrib_pointer_offset(4, 4, GL_FLOAT, .false., &
                                              FLOATS_PER_INST * 4, 32)
        call gl_vertex_attrib_divisor(4, 1)

        call gl_bind_vertex_array(0_c_int)
        call gl_bind_buffer(GL_ARRAY_BUFFER, 0_c_int)
        call gl_bind_buffer(GL_ELEMENT_ARRAY_BUFFER, 0_c_int)

        var%n_idx  = int(n_idx, c_int)
        var%n_inst = int(n_inst, c_int)

        deallocate(verts, indices, inst)
    end subroutine build_variant

    !---------------------------------------------------------------
    ! Generate a low-poly lumpy sphere. Returns vertices (pos only) and
    ! indices. Displacement amplitude depends on the variant seed so each
    ! mesh is distinctly shaped.
    !---------------------------------------------------------------
    subroutine gen_lumpy_mesh(variant_seed, verts, indices, n_vert, n_tri)
        integer, intent(in) :: variant_seed
        real(c_float), allocatable, intent(out) :: verts(:)
        integer(c_int), allocatable, intent(out) :: indices(:)
        integer, intent(out) :: n_vert, n_tri

        integer :: nlat, nlon, i, j, vi, ti
        real(c_float) :: phi, theta, sin_phi, cos_phi, cos_th, sin_th
        real(c_float) :: displ, amp, base_r
        integer(c_int) :: a, b, c, d

        nlat = MESH_LAT_SEGMENTS
        nlon = MESH_LON_SEGMENTS
        n_vert = (nlat + 1) * (nlon + 1)
        n_tri  = nlat * nlon * 2
        allocate(verts(3 * n_vert))
        allocate(indices(3 * n_tri))

        ! Amplitude tweak per variant — variant 1 chunky, 2 jagged, 3 smoother.
        select case (variant_seed)
        case (1); amp = 0.35_c_float
        case (2); amp = 0.45_c_float
        case default; amp = 0.22_c_float
        end select

        vi = 0
        do i = 0, nlat
            phi = real(i, c_float) * PI_F / real(nlat, c_float)
            sin_phi = sin(phi); cos_phi = cos(phi)
            do j = 0, nlon
                theta = real(j, c_float) * TWOPI_F / real(nlon, c_float)
                sin_th = sin(theta); cos_th = cos(theta)
                displ = hash_noise3(variant_seed, i, j)
                base_r = 1.0_c_float + amp * (displ - 0.5_c_float) * 2.0_c_float
                verts(vi + 1) = base_r * sin_phi * cos_th
                verts(vi + 2) = base_r * cos_phi
                verts(vi + 3) = base_r * sin_phi * sin_th
                vi = vi + 3
            end do
        end do

        ti = 0
        do i = 0, nlat - 1
            do j = 0, nlon - 1
                a = int(i * (nlon + 1) + j, c_int)
                b = a + 1_c_int
                c = int((i + 1) * (nlon + 1) + j, c_int)
                d = c + 1_c_int
                indices(ti + 1) = a
                indices(ti + 2) = c
                indices(ti + 3) = b
                indices(ti + 4) = b
                indices(ti + 5) = c
                indices(ti + 6) = d
                ti = ti + 6
            end do
        end do
    end subroutine gen_lumpy_mesh

    !---------------------------------------------------------------
    ! Generate per-instance orbital elements + visual data for one
    ! variant slice. Uses random_number — caller must have seeded the RNG.
    !---------------------------------------------------------------
    subroutine gen_instance_data(variant_seed, n_inst, a_min, a_max, inst)
        integer, intent(in) :: variant_seed, n_inst
        real(c_float), intent(in) :: a_min, a_max
        real(c_float), allocatable, intent(out) :: inst(:)

        integer :: i, off
        real(c_float) :: a_au, ecc, inc, node, peri, mean0, nmot, spin
        real(c_float) :: scale, gray, phase, tilt
        real(c_float) :: r1, r2, r3, r4, r5, r6, r7, r8, a_m
        real(c_float), parameter :: INC_MAX = 0.14_c_float   ! ~8°
        real(c_float), parameter :: E_MAX   = 0.18_c_float

        allocate(inst(FLOATS_PER_INST * n_inst))

        do i = 0, n_inst - 1
            call random_number(r1)
            call random_number(r2)
            call random_number(r3)
            call random_number(r4)
            call random_number(r5)
            call random_number(r6)
            call random_number(r7)
            call random_number(r8)

            ! Semi-major axis distribution — bias slightly toward inner belt.
            a_au  = a_min + (a_max - a_min) * (r1 ** 0.75_c_float)
            ecc   = E_MAX * r2
            inc   = INC_MAX * (r3 - 0.5_c_float) * 2.0_c_float
            node  = TWOPI_F * r4
            peri  = TWOPI_F * r5
            mean0 = TWOPI_F * r6

            a_m  = a_au * AU_F
            nmot = sqrt(GM_SUN_F / (a_m * a_m * a_m))

            ! Spin rate 0.01..0.4 rad/s of simulated time. Sign random.
            spin = (0.01_c_float + 0.39_c_float * r7) * merge(1.0_c_float, -1.0_c_float, r8 > 0.5_c_float)

            ! Asteroid size: fat-tail — a handful are visibly large.
            call random_number(scale)
            scale = scale ** 5.0_c_float
            select case (variant_seed)
            case (1); scale = 0.004_c_float + 0.010_c_float * scale
            case (2); scale = 0.003_c_float + 0.007_c_float * scale
            case default; scale = 0.002_c_float + 0.005_c_float * scale
            end select

            call random_number(gray)
            gray = 0.25_c_float + 0.35_c_float * gray   ! dusty greys

            call random_number(phase)
            phase = TWOPI_F * phase
            call random_number(tilt)
            tilt  = TWOPI_F * tilt

            off = i * FLOATS_PER_INST
            inst(off + 1)  = a_au
            inst(off + 2)  = ecc
            inst(off + 3)  = inc
            inst(off + 4)  = node
            inst(off + 5)  = peri
            inst(off + 6)  = mean0
            inst(off + 7)  = nmot
            inst(off + 8)  = spin
            inst(off + 9)  = scale
            inst(off + 10) = gray
            inst(off + 11) = phase
            inst(off + 12) = tilt
        end do
    end subroutine gen_instance_data

    !---------------------------------------------------------------
    ! Tiny deterministic hash → float in [0,1). Stable across runs.
    !---------------------------------------------------------------
    pure function hash_noise3(s, i, j) result(f)
        integer, intent(in) :: s, i, j
        real(c_float) :: f
        integer :: h
        h = s * 374761393 + i * 668265263 + j * 2147483647
        h = ieor(h, ishft(h, 13))
        h = h * 1274126177
        h = ieor(h, ishft(h, -16))
        f = real(iand(h, int(z'00FFFFFF')), c_float) / real(int(z'01000000'), c_float)
    end function hash_noise3

    pure function itoa(i) result(s)
        integer, intent(in) :: i
        character(len=16) :: s
        write(s, "(I0)") i
    end function itoa

end module asteroids_mod
