!===============================================================================
! post.f90 — HDR post-processing pipeline: bright pass, bloom, tonemap
!
! Pipeline:
!   scene  → hdr_fbo (RGBA16F + depth)
!   hdr    → bright_fbo (half-res, RGBA16F)
!   for each mip level l:
!     blur_h[l] ← horizontal blur sampling from previous level
!     blur_v[l] ← vertical   blur sampling from blur_h[l]
!   combine_fbo ← upscaled-and-added mip chain
!   default fbo ← ACES(hdr + bloom * intensity) with gamma correction
!
! The fullscreen triangle trick (gl_VertexID → clip coords) means post passes
! need a VAO but no VBO — the driver generates vertex positions in-shader.
!===============================================================================
module post_mod
    use, intrinsic :: iso_c_binding, only: c_int, c_float, c_null_ptr
    use gl_bindings, only: &
        gl_use_program, gl_bind_vertex_array, gl_gen_vertex_arrays, &
        gl_delete_vertex_arrays, gl_active_texture, gl_bind_texture, &
        gl_draw_arrays, gl_viewport, gl_bind_framebuffer, &
        gl_disable, gl_enable, gl_depth_mask, &
        GL_TRIANGLES, GL_TEXTURE_2D, GL_TEXTURE0, GL_TEXTURE1, &
        GL_FRAMEBUFFER, GL_DEPTH_TEST, GL_CULL_FACE, GL_BLEND, &
        GL_RGBA16F
    use framebuffer_mod, only: framebuffer_t, framebuffer_create, &
                               framebuffer_destroy, framebuffer_bind, &
                               framebuffer_unbind, framebuffer_resize
    use shader_mod, only: shader_program_t, shader_load, shader_use, &
                          shader_destroy, set_uniform_int, set_uniform_float, &
                          set_uniform_vec3
    use gl_bindings, only: gl_clear, gl_clear_color, &
                           GLFW_COLOR_BUFFER_BIT, GLFW_DEPTH_BUFFER_BIT
    use logging, only: log_msg, LOG_INFO, LOG_ERROR
    implicit none
    private

    public :: post_t, post_init, post_shutdown, post_resize
    public :: post_begin_scene, post_end_scene
    public :: post_apply_bloom_and_tonemap
    public :: MAX_BLOOM_MIPS

    integer, parameter :: MAX_BLOOM_MIPS = 5

    type :: post_t
        type(framebuffer_t) :: hdr
        type(framebuffer_t) :: bright
        type(framebuffer_t) :: blur_h(MAX_BLOOM_MIPS)
        type(framebuffer_t) :: blur_v(MAX_BLOOM_MIPS)
        type(framebuffer_t) :: combine

        type(shader_program_t) :: bright_shader
        type(shader_program_t) :: blur_shader
        type(shader_program_t) :: combine_shader
        type(shader_program_t) :: tonemap_shader

        integer(c_int) :: tri_vao = 0_c_int
        integer :: n_mips = 5
        integer :: screen_w = 0, screen_h = 0
        logical :: initialized = .false.
    end type post_t

contains

    subroutine post_init(post, w, h, n_mips)
        type(post_t), intent(out) :: post
        integer, intent(in) :: w, h, n_mips
        integer :: i, mw, mh
        integer(c_int) :: arr(1)

        post%screen_w = w
        post%screen_h = h
        post%n_mips = min(max(n_mips, 1), MAX_BLOOM_MIPS)

        ! HDR scene target: full resolution + depth
        call framebuffer_create(post%hdr, w, h, GL_RGBA16F, .true.)

        ! Bright-pass target: half resolution
        call framebuffer_create(post%bright, w / 2, h / 2, GL_RGBA16F, .false.)

        ! Blur mip chain — each level half the previous
        mw = w / 2
        mh = h / 2
        do i = 1, post%n_mips
            mw = max(mw / 2, 4)
            mh = max(mh / 2, 4)
            call framebuffer_create(post%blur_h(i), mw, mh, GL_RGBA16F, .false.)
            call framebuffer_create(post%blur_v(i), mw, mh, GL_RGBA16F, .false.)
        end do

        ! Combine target: same size as bright pass
        call framebuffer_create(post%combine, w / 2, h / 2, GL_RGBA16F, .false.)

        ! Shaders
        post%bright_shader  = shader_load("shaders/fullscreen.vert", "shaders/bright_pass.frag")
        post%blur_shader    = shader_load("shaders/fullscreen.vert", "shaders/blur.frag")
        post%combine_shader = shader_load("shaders/fullscreen.vert", "shaders/bloom_combine.frag")
        post%tonemap_shader = shader_load("shaders/fullscreen.vert", "shaders/tonemap.frag")

        if (.not. post%tonemap_shader%valid) then
            call log_msg(LOG_ERROR, "post: shader load failed")
            return
        end if

        ! Fullscreen triangle VAO (no VBO — vertex shader uses gl_VertexID)
        call gl_gen_vertex_arrays(1, arr)
        post%tri_vao = arr(1)

        post%initialized = .true.
        call log_msg(LOG_INFO, "Post-processing pipeline initialized")
    end subroutine post_init

    subroutine post_shutdown(post)
        type(post_t), intent(inout) :: post
        integer :: i
        integer(c_int) :: arr(1)
        if (.not. post%initialized) return
        call framebuffer_destroy(post%hdr)
        call framebuffer_destroy(post%bright)
        call framebuffer_destroy(post%combine)
        do i = 1, post%n_mips
            call framebuffer_destroy(post%blur_h(i))
            call framebuffer_destroy(post%blur_v(i))
        end do
        call shader_destroy(post%bright_shader)
        call shader_destroy(post%blur_shader)
        call shader_destroy(post%combine_shader)
        call shader_destroy(post%tonemap_shader)
        if (post%tri_vao /= 0) then
            arr(1) = post%tri_vao
            call gl_delete_vertex_arrays(1, arr)
            post%tri_vao = 0_c_int
        end if
        post%initialized = .false.
    end subroutine post_shutdown

    subroutine post_resize(post, w, h)
        type(post_t), intent(inout) :: post
        integer, intent(in) :: w, h
        integer :: i, mw, mh
        if (.not. post%initialized) return
        if (post%screen_w == w .and. post%screen_h == h) return
        post%screen_w = w
        post%screen_h = h
        call framebuffer_resize(post%hdr, w, h)
        call framebuffer_resize(post%bright, w / 2, h / 2)
        call framebuffer_resize(post%combine, w / 2, h / 2)
        mw = w / 2; mh = h / 2
        do i = 1, post%n_mips
            mw = max(mw / 2, 4); mh = max(mh / 2, 4)
            call framebuffer_resize(post%blur_h(i), mw, mh)
            call framebuffer_resize(post%blur_v(i), mw, mh)
        end do
    end subroutine post_resize

    !---------------------------------------------------------------
    ! Bind HDR target and clear it — scene rendering goes here
    !---------------------------------------------------------------
    subroutine post_begin_scene(post, clear_r, clear_g, clear_b)
        type(post_t), intent(in) :: post
        real(c_float), intent(in) :: clear_r, clear_g, clear_b
        call framebuffer_bind(post%hdr)
        call gl_clear_color(clear_r, clear_g, clear_b, 1.0_c_float)
        call gl_clear(ior(GLFW_COLOR_BUFFER_BIT, GLFW_DEPTH_BUFFER_BIT))
    end subroutine post_begin_scene

    subroutine post_end_scene(post)
        type(post_t), intent(in) :: post
        integer :: unused
        unused = post%n_mips
        call framebuffer_unbind()
    end subroutine post_end_scene

    !---------------------------------------------------------------
    ! Run the full bloom + tonemap chain.
    !---------------------------------------------------------------
    subroutine post_apply_bloom_and_tonemap(post, bloom_on, threshold, &
                                            intensity, exposure)
        type(post_t), intent(inout) :: post
        logical, intent(in) :: bloom_on
        real(c_float), intent(in) :: threshold, intensity, exposure

        integer :: i
        integer(c_int) :: src_tex, prev_tex

        if (.not. post%initialized) return

        ! Disable depth/cull/blend for all post passes
        call gl_disable(GL_DEPTH_TEST)
        call gl_disable(GL_CULL_FACE)
        call gl_disable(GL_BLEND)
        call gl_depth_mask(.false.)

        call gl_bind_vertex_array(post%tri_vao)

        if (bloom_on) then
            !-------------------------------------------------------
            ! Bright pass
            !-------------------------------------------------------
            call framebuffer_bind(post%bright)
            call shader_use(post%bright_shader)
            call set_uniform_int(post%bright_shader, "u_src", 0_c_int)
            call set_uniform_float(post%bright_shader, "u_threshold", threshold)
            call gl_active_texture(GL_TEXTURE0)
            call gl_bind_texture(GL_TEXTURE_2D, post%hdr%color_tex)
            call gl_draw_arrays(GL_TRIANGLES, 0_c_int, 3_c_int)

            !-------------------------------------------------------
            ! Blur ping-pong across mip chain
            !-------------------------------------------------------
            prev_tex = post%bright%color_tex
            do i = 1, post%n_mips
                ! Horizontal
                call framebuffer_bind(post%blur_h(i))
                call shader_use(post%blur_shader)
                call set_uniform_int(post%blur_shader, "u_src", 0_c_int)
                call set_uniform_int(post%blur_shader, "u_horizontal", 1_c_int)
                call set_uniform_float(post%blur_shader, "u_texel_x", &
                    1.0_c_float / real(post%blur_h(i)%width, c_float))
                call set_uniform_float(post%blur_shader, "u_texel_y", &
                    1.0_c_float / real(post%blur_h(i)%height, c_float))
                call gl_active_texture(GL_TEXTURE0)
                call gl_bind_texture(GL_TEXTURE_2D, prev_tex)
                call gl_draw_arrays(GL_TRIANGLES, 0_c_int, 3_c_int)

                ! Vertical
                call framebuffer_bind(post%blur_v(i))
                call set_uniform_int(post%blur_shader, "u_horizontal", 0_c_int)
                call gl_bind_texture(GL_TEXTURE_2D, post%blur_h(i)%color_tex)
                call gl_draw_arrays(GL_TRIANGLES, 0_c_int, 3_c_int)

                prev_tex = post%blur_v(i)%color_tex
            end do

            !-------------------------------------------------------
            ! Combine: upsample-and-add all mips into combine target
            ! (starts from the coarsest mip and additively blends up)
            !-------------------------------------------------------
            call framebuffer_bind(post%combine)
            call shader_use(post%combine_shader)
            call set_uniform_int(post%combine_shader, "u_src", 0_c_int)
            call gl_active_texture(GL_TEXTURE0)
            ! Clear combine target then add all mips with GL_ONE blending
            call gl_clear_color(0.0_c_float, 0.0_c_float, 0.0_c_float, 1.0_c_float)
            call gl_clear(GLFW_COLOR_BUFFER_BIT)
            call gl_enable(GL_BLEND)
            call gl_blend_func_add()
            do i = post%n_mips, 1, -1
                call gl_bind_texture(GL_TEXTURE_2D, post%blur_v(i)%color_tex)
                call set_uniform_float(post%combine_shader, "u_weight", &
                    1.0_c_float / real(i, c_float))
                call gl_draw_arrays(GL_TRIANGLES, 0_c_int, 3_c_int)
            end do
            call gl_disable(GL_BLEND)

            src_tex = post%combine%color_tex
        else
            src_tex = 0_c_int  ! No bloom — sampled but tonemap will zero-weight it
        end if

        !-------------------------------------------------------
        ! Tonemap to default framebuffer
        !-------------------------------------------------------
        call gl_bind_framebuffer(GL_FRAMEBUFFER, 0_c_int)
        call gl_viewport(0_c_int, 0_c_int, &
                         int(post%screen_w, c_int), int(post%screen_h, c_int))
        call shader_use(post%tonemap_shader)
        call set_uniform_int(post%tonemap_shader, "u_scene", 0_c_int)
        call set_uniform_int(post%tonemap_shader, "u_bloom", 1_c_int)
        call set_uniform_float(post%tonemap_shader, "u_exposure", exposure)
        call set_uniform_float(post%tonemap_shader, "u_bloom_intensity", intensity)
        if (bloom_on) then
            call set_uniform_float(post%tonemap_shader, "u_bloom_on", 1.0_c_float)
        else
            call set_uniform_float(post%tonemap_shader, "u_bloom_on", 0.0_c_float)
        end if

        call gl_active_texture(GL_TEXTURE0)
        call gl_bind_texture(GL_TEXTURE_2D, post%hdr%color_tex)
        call gl_active_texture(GL_TEXTURE1)
        if (bloom_on) then
            call gl_bind_texture(GL_TEXTURE_2D, src_tex)
        else
            call gl_bind_texture(GL_TEXTURE_2D, post%hdr%color_tex)
        end if
        call gl_draw_arrays(GL_TRIANGLES, 0_c_int, 3_c_int)

        call gl_bind_vertex_array(0_c_int)
        call gl_active_texture(GL_TEXTURE0)
        call gl_depth_mask(.true.)
    end subroutine post_apply_bloom_and_tonemap

    ! Local shim for additive blending (no src-alpha weight) used in combine.
    subroutine gl_blend_func_add()
        use gl_bindings, only: gl_blend_func_local => gl_blend_func, &
                               GL_ONE
        call gl_blend_func_local(GL_ONE, GL_ONE)
    end subroutine gl_blend_func_add

end module post_mod
