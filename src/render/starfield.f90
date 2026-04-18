!===============================================================================
! starfield.f90 — Point-sprite star background.
!
! Generates N stars on a unit sphere at startup with a power-law magnitude
! distribution (most dim, few very bright) and temperature-coloured tints.
! Rendered as GL_POINTS with depth write off so scene geometry always occludes.
! The view matrix has its translation zeroed before upload so the sphere feels
! infinitely far regardless of how far the camera has panned.
!===============================================================================
module starfield_mod
    use, intrinsic :: iso_c_binding, only: c_float, c_int, c_loc, c_null_ptr
    use gl_bindings, only: &
        gl_gen_buffers, gl_bind_buffer, gl_buffer_data, gl_delete_buffers, &
        gl_gen_vertex_arrays, gl_bind_vertex_array, gl_delete_vertex_arrays, &
        gl_enable_vertex_attrib_array, gl_vertex_attrib_pointer, &
        gl_vertex_attrib_pointer_offset, &
        gl_enable, gl_disable, gl_depth_mask, gl_blend_func, &
        gl_draw_arrays, &
        GL_ARRAY_BUFFER, GL_STATIC_DRAW, GL_FLOAT, &
        GL_POINTS, GL_PROGRAM_POINT_SIZE, GL_DEPTH_TEST, &
        GL_BLEND, GL_SRC_ALPHA, GL_ONE
    use shader_mod, only: shader_program_t, shader_load, shader_use, &
                          shader_destroy, set_uniform_mat4, set_uniform_float
    use camera_mod, only: camera_t, camera_get_view, camera_get_projection
    use logging, only: log_msg, LOG_INFO, LOG_ERROR
    implicit none
    private

    public :: starfield_t, starfield_init, starfield_shutdown, starfield_render

    type :: starfield_t
        integer(c_int)         :: vao   = 0_c_int
        integer(c_int)         :: vbo   = 0_c_int
        integer                :: count = 0
        type(shader_program_t) :: shader
        logical                :: initialized = .false.
    end type starfield_t

contains

    subroutine starfield_init(sf, n_stars)
        type(starfield_t), intent(out) :: sf
        integer, intent(in) :: n_stars

        integer, parameter :: FLOATS_PER_STAR = 8  ! pos(3) + col(3) + mag(1) + phase(1)
        integer :: i, n
        real(c_float), allocatable, target :: verts(:)
        integer(c_int) :: arr(1)
        real(c_float) :: theta, phi, ct, st, cp, sp, r1, r2
        real(c_float) :: temp_t, cr, cg, cb, mag
        integer :: seed_size
        integer, allocatable :: seed(:)

        n = max(n_stars, 0)
        sf%count = n
        if (n == 0) return

        ! Deterministic seed so the sky looks the same every run.
        call random_seed(size = seed_size)
        allocate(seed(seed_size))
        seed = 424242
        call random_seed(put = seed)
        deallocate(seed)

        allocate(verts(FLOATS_PER_STAR * n))

        do i = 0, n - 1
            ! Uniform point on a sphere via spherical coords with cos(theta) uniform.
            call random_number(r1)
            call random_number(r2)
            theta = acos(1.0_c_float - 2.0_c_float * r1)  ! 0..pi
            phi   = 2.0_c_float * 3.14159265_c_float * r2

            ct = cos(theta); st = sin(theta)
            cp = cos(phi);   sp = sin(phi)

            ! Magnitude: power distribution — most dim.
            call random_number(mag)
            mag = mag ** 3.0_c_float     ! skews toward 0 → mostly dim
            mag = 0.15_c_float + 0.85_c_float * mag

            ! Stellar temperature: most yellow-white, some bluer, some redder.
            call random_number(temp_t)
            call color_from_temperature(temp_t, cr, cg, cb)

            verts(i * FLOATS_PER_STAR + 1) = st * cp
            verts(i * FLOATS_PER_STAR + 2) = ct
            verts(i * FLOATS_PER_STAR + 3) = st * sp
            verts(i * FLOATS_PER_STAR + 4) = cr
            verts(i * FLOATS_PER_STAR + 5) = cg
            verts(i * FLOATS_PER_STAR + 6) = cb
            verts(i * FLOATS_PER_STAR + 7) = mag
            call random_number(verts(i * FLOATS_PER_STAR + 8))  ! phase 0..1
        end do

        call gl_gen_vertex_arrays(1, arr); sf%vao = arr(1)
        call gl_gen_buffers(1, arr);       sf%vbo = arr(1)

        call gl_bind_vertex_array(sf%vao)
        call gl_bind_buffer(GL_ARRAY_BUFFER, sf%vbo)
        call gl_buffer_data(GL_ARRAY_BUFFER, &
                            int(FLOATS_PER_STAR * 4 * n, c_int), &
                            c_loc(verts(1)), GL_STATIC_DRAW)

        ! stride = 32 bytes
        call gl_enable_vertex_attrib_array(0)
        call gl_vertex_attrib_pointer(0, 3, GL_FLOAT, .false., 32, c_null_ptr)
        call gl_enable_vertex_attrib_array(1)
        call gl_vertex_attrib_pointer_offset(1, 3, GL_FLOAT, .false., 32, 12)
        call gl_enable_vertex_attrib_array(2)
        call gl_vertex_attrib_pointer_offset(2, 1, GL_FLOAT, .false., 32, 24)
        call gl_enable_vertex_attrib_array(3)
        call gl_vertex_attrib_pointer_offset(3, 1, GL_FLOAT, .false., 32, 28)

        call gl_bind_vertex_array(0_c_int)
        call gl_bind_buffer(GL_ARRAY_BUFFER, 0_c_int)

        sf%shader = shader_load("shaders/star.vert", "shaders/star.frag")
        sf%initialized = sf%shader%valid

        deallocate(verts)

        if (sf%initialized) then
            call log_msg(LOG_INFO, "Starfield: " // itoa(n) // " stars generated")
        else
            call log_msg(LOG_ERROR, "Starfield: shader load failed")
        end if
    end subroutine starfield_init

    subroutine starfield_shutdown(sf)
        type(starfield_t), intent(inout) :: sf
        integer(c_int) :: arr(1)
        if (.not. sf%initialized) return
        call shader_destroy(sf%shader)
        if (sf%vbo /= 0) then; arr(1) = sf%vbo; call gl_delete_buffers(1, arr); end if
        if (sf%vao /= 0) then; arr(1) = sf%vao; call gl_delete_vertex_arrays(1, arr); end if
        sf%initialized = .false.
    end subroutine starfield_shutdown

    !---------------------------------------------------------------
    ! Render the starfield into whatever FBO is currently bound.
    ! Must be called before the rest of the scene: depth write is off
    ! and we clear to place stars at the far plane.
    !---------------------------------------------------------------
    subroutine starfield_render(sf, cam, t_sec, intensity)
        type(starfield_t), intent(inout) :: sf
        type(camera_t), intent(in) :: cam
        real(c_float), intent(in) :: t_sec, intensity

        real(c_float) :: view_arr(16), proj_arr(16)

        if (.not. sf%initialized) return
        if (sf%count == 0) return

        view_arr = camera_get_view(cam)
        proj_arr = camera_get_projection(cam)

        ! Zero out translation columns so the background sphere feels infinite.
        ! In column-major layout emitted by mat4_to_array, the translation lives
        ! at indices 13,14,15 (column 4, rows 1..3).
        view_arr(13) = 0.0_c_float
        view_arr(14) = 0.0_c_float
        view_arr(15) = 0.0_c_float

        call shader_use(sf%shader)
        call set_uniform_mat4(sf%shader, "u_view", view_arr)
        call set_uniform_mat4(sf%shader, "u_proj", proj_arr)
        call set_uniform_float(sf%shader, "u_time", t_sec)
        call set_uniform_float(sf%shader, "u_intensity", intensity)

        call gl_enable(GL_PROGRAM_POINT_SIZE)
        call gl_enable(GL_BLEND)
        call gl_blend_func(GL_SRC_ALPHA, GL_ONE)
        call gl_depth_mask(.false.)

        call gl_bind_vertex_array(sf%vao)
        call gl_draw_arrays(GL_POINTS, 0_c_int, int(sf%count, c_int))
        call gl_bind_vertex_array(0_c_int)

        call gl_depth_mask(.true.)
        call gl_disable(GL_BLEND)
        call gl_disable(GL_PROGRAM_POINT_SIZE)
    end subroutine starfield_render

    !---------------------------------------------------------------
    ! Rough stellar colour from a 0..1 temperature parameter.
    ! Maps: 0.0 = deep red, 0.5 = yellow-white, 0.85+ = blue-white.
    ! Most stars cluster around mid-range to look natural.
    !---------------------------------------------------------------
    pure subroutine color_from_temperature(t01, r, g, b)
        real(c_float), intent(in)  :: t01
        real(c_float), intent(out) :: r, g, b
        real(c_float) :: t
        ! Bias distribution toward the yellow-white middle.
        t = 0.35_c_float + 0.55_c_float * t01
        if (t < 0.5_c_float) then
            ! Red → yellow-white
            r = 1.0_c_float
            g = 0.55_c_float + 0.9_c_float * (t - 0.35_c_float) / 0.15_c_float
            b = 0.35_c_float + 0.55_c_float * (t - 0.35_c_float) / 0.15_c_float
        else
            ! Yellow-white → blue-white
            r = 1.0_c_float - 0.15_c_float * (t - 0.5_c_float) / 0.4_c_float
            g = 1.0_c_float - 0.05_c_float * (t - 0.5_c_float) / 0.4_c_float
            b = 1.0_c_float
        end if
        if (r > 1.0_c_float) r = 1.0_c_float
        if (g > 1.0_c_float) g = 1.0_c_float
        if (b > 1.0_c_float) b = 1.0_c_float
    end subroutine color_from_temperature

    pure function itoa(i) result(s)
        integer, intent(in) :: i
        character(len=16) :: s
        write(s, "(I0)") i
    end function itoa

end module starfield_mod
