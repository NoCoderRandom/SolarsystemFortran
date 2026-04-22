!===============================================================================
! mat4.f90 — 4x4 column-major matrix math for OpenGL (real32 / GL_FLOAT)
!===============================================================================
module mat4_math
    use, intrinsic :: iso_c_binding, only: c_float
    use, intrinsic :: iso_fortran_env, only: real32
    implicit none
    private

    public :: mat4
    public :: mat4_identity, mat4_perspective, mat4_look_at
    public :: mat4_translate, mat4_scale_xyz, mat4_rotate_y, mat4_rotate_x, mat4_rotate_z
    public :: mat4_mul_vec3, mat4_to_array

    type, public :: mat4
        real(c_float) :: m(4, 4) = 0.0_c_float
    end type mat4

contains

    !=====================================================================
    ! Identity matrix
    !=====================================================================
    pure function mat4_identity() result(r)
        type(mat4) :: r
        integer :: i
        do i = 1, 4
            r%m(i, i) = 1.0_c_float
        end do
    end function mat4_identity

    !=====================================================================
    ! Perspective projection matrix
    !   fovy  — vertical field of view in radians
    !   aspect — width / height
    !   znear, zfar — depth range (must be > 0)
    !=====================================================================
    pure function mat4_perspective(fovy, aspect, znear, zfar) result(r)
        real(c_float), intent(in) :: fovy, aspect, znear, zfar
        type(mat4) :: r
        real(c_float) :: f, inv_range

        f = 1.0_c_float / tan(fovy * 0.5_c_float)
        inv_range = 1.0_c_float / (znear - zfar)

        r%m = 0.0_c_float
        r%m(1,1) = f / aspect
        r%m(2,2) = f
        r%m(3,3) = (zfar + znear) * inv_range
        r%m(3,4) = 2.0_c_float * zfar * znear * inv_range
        r%m(4,3) = -1.0_c_float
    end function mat4_perspective

    !=====================================================================
    ! LookAt view matrix
    !   eye    — camera position
    !   target — point to look at
    !   up     — up vector (usually 0,1,0)
    !=====================================================================
    pure function mat4_look_at(eye, target, up) result(r)
        real(c_float), intent(in) :: eye(3), target(3), up(3)
        type(mat4) :: r
        real(c_float) :: zx, zy, zz, len
        real(c_float) :: xx, xy, xz
        real(c_float) :: yx, yy, yz
        real(c_float) :: tx, ty, tz

        ! z = normalize(eye - target)
        zx = eye(1) - target(1)
        zy = eye(2) - target(2)
        zz = eye(3) - target(3)
        len = sqrt(zx*zx + zy*zy + zz*zz)
        if (len > 0.0_c_float) then
            zx = zx/len; zy = zy/len; zz = zz/len
        end if

        ! x = normalize(cross(up, z))
        xx = up(2)*zz - up(3)*zy
        xy = up(3)*zx - up(1)*zz
        xz = up(1)*zy - up(2)*zx
        len = sqrt(xx*xx + xy*xy + xz*xz)
        if (len > 0.0_c_float) then
            xx = xx/len; xy = xy/len; xz = xz/len
        end if

        ! y = cross(z, x)
        yx = zy*xz - zz*xy
        yy = zz*xx - zx*xz
        yz = zx*xy - zy*xx

        ! Translation: t = -R^T · eye, where R has columns (x,y,z)
        tx = -(xx*eye(1) + xy*eye(2) + xz*eye(3))
        ty = -(yx*eye(1) + yy*eye(2) + yz*eye(3))
        tz = -(zx*eye(1) + zy*eye(2) + zz*eye(3))

        r%m = 0.0_c_float
        r%m(1,1) = xx; r%m(1,2) = xy; r%m(1,3) = xz; r%m(1,4) = tx
        r%m(2,1) = yx; r%m(2,2) = yy; r%m(2,3) = yz; r%m(2,4) = ty
        r%m(3,1) = zx; r%m(3,2) = zy; r%m(3,3) = zz; r%m(3,4) = tz
        r%m(4,1) = 0.0_c_float; r%m(4,2) = 0.0_c_float
        r%m(4,3) = 0.0_c_float; r%m(4,4) = 1.0_c_float
    end function mat4_look_at

    !=====================================================================
    ! Translation matrix
    !=====================================================================
    pure function mat4_translate(tx, ty, tz) result(r)
        real(c_float), intent(in) :: tx, ty, tz
        type(mat4) :: r
        r = mat4_identity()
        r%m(1,4) = tx
        r%m(2,4) = ty
        r%m(3,4) = tz
    end function mat4_translate

    !=====================================================================
    ! Scale matrix
    !=====================================================================
    pure function mat4_scale_xyz(sx, sy, sz) result(r)
        real(c_float), intent(in) :: sx, sy, sz
        type(mat4) :: r
        r%m = 0.0_c_float
        r%m(1,1) = sx
        r%m(2,2) = sy
        r%m(3,3) = sz
        r%m(4,4) = 1.0_c_float
    end function mat4_scale_xyz

    !=====================================================================
    ! Rotation around Y axis (radians)
    !=====================================================================
    pure function mat4_rotate_y(angle) result(r)
        real(c_float), intent(in) :: angle
        type(mat4) :: r
        real(c_float) :: c, s
        c = cos(angle)
        s = sin(angle)
        r = mat4_identity()
        r%m(1,1) =  c; r%m(1,3) = s
        r%m(3,1) = -s; r%m(3,3) = c
    end function mat4_rotate_y

    pure function mat4_rotate_x(angle) result(r)
        real(c_float), intent(in) :: angle
        type(mat4) :: r
        real(c_float) :: c, s
        c = cos(angle)
        s = sin(angle)
        r = mat4_identity()
        r%m(2,2) =  c; r%m(2,3) = -s
        r%m(3,2) =  s; r%m(3,3) =  c
    end function mat4_rotate_x

    pure function mat4_rotate_z(angle) result(r)
        real(c_float), intent(in) :: angle
        type(mat4) :: r
        real(c_float) :: c, s
        c = cos(angle)
        s = sin(angle)
        r = mat4_identity()
        r%m(1,1) =  c; r%m(1,2) = -s
        r%m(2,1) =  s; r%m(2,2) =  c
    end function mat4_rotate_z

    !=====================================================================
    ! Transform a 3D vector (position) by a mat4, returning real32 vec3
    !=====================================================================
    pure function mat4_mul_vec3(m, v) result(r)
        type(mat4), intent(in) :: m
        real(c_float), intent(in) :: v(3)
        real(c_float) :: r(3)
        real(c_float) :: w
        r(1) = m%m(1,1)*v(1) + m%m(1,2)*v(2) + m%m(1,3)*v(3) + m%m(1,4)
        r(2) = m%m(2,1)*v(1) + m%m(2,2)*v(2) + m%m(2,3)*v(3) + m%m(2,4)
        r(3) = m%m(3,1)*v(1) + m%m(3,2)*v(2) + m%m(3,3)*v(3) + m%m(3,4)
        w    = m%m(4,1)*v(1) + m%m(4,2)*v(2) + m%m(4,3)*v(3) + m%m(4,4)
        if (abs(w) > 1.0e-7_c_float) then
            r = r / w
        end if
    end function mat4_mul_vec3

    !=====================================================================
    ! Flatten to 16-element array (for glUniformMatrix4fv)
    !=====================================================================
    pure function mat4_to_array(m) result(a)
        type(mat4), intent(in) :: m
        real(c_float) :: a(16)
        integer :: i, j, k
        k = 0
        do j = 1, 4
            do i = 1, 4
                k = k + 1
                a(k) = m%m(i, j)
            end do
        end do
    end function mat4_to_array

end module mat4_math
