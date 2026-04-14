!===============================================================================
! vector3d.f90 — 3D vector type with operator overloads (real64 components)
!===============================================================================
module vector3d
    use, intrinsic :: iso_fortran_env, only: real64
    implicit none
    private

    public :: vec3, zero_vec3
    public :: dot, cross, norm, norm_squared, normalize
    public :: operator(+), operator(-), operator(*), operator(/)
    public :: operator(.eq.), operator(.ne.)

    !-----------------------------------------------------------------------
    ! 3D vector with double-precision components
    !-----------------------------------------------------------------------
    type, public :: vec3
        real(real64) :: x = 0.0_real64
        real(real64) :: y = 0.0_real64
        real(real64) :: z = 0.0_real64
    end type vec3

    ! Named constant for the zero vector
    type(vec3), parameter :: zero_vec3 = vec3(0.0_real64, 0.0_real64, 0.0_real64)

    !-----------------------------------------------------------------------
    ! Operator overloads
    !-----------------------------------------------------------------------
    interface operator(+)
        module procedure vec3_add
    end interface

    interface operator(-)
        module procedure vec3_sub
        module procedure vec3_negate
    end interface

    interface operator(*)
        module procedure vec3_mul_scalar
        module procedure scalar_mul_vec3
    end interface

    interface operator(/)
        module procedure vec3_div_scalar
    end interface

    interface operator(.eq.)
        module procedure vec3_eq
    end interface

    interface operator(.ne.)
        module procedure vec3_ne
    end interface

contains

    !=====================================================================
    ! Arithmetic operators
    !=====================================================================
    pure elemental function vec3_add(a, b) result(r)
        type(vec3), intent(in) :: a, b
        type(vec3) :: r
        r%x = a%x + b%x
        r%y = a%y + b%y
        r%z = a%z + b%z
    end function vec3_add

    pure elemental function vec3_sub(a, b) result(r)
        type(vec3), intent(in) :: a, b
        type(vec3) :: r
        r%x = a%x - b%x
        r%y = a%y - b%y
        r%z = a%z - b%z
    end function vec3_sub

    pure elemental function vec3_negate(a) result(r)
        type(vec3), intent(in) :: a
        type(vec3) :: r
        r%x = -a%x
        r%y = -a%y
        r%z = -a%z
    end function vec3_negate

    pure elemental function vec3_mul_scalar(v, s) result(r)
        type(vec3), intent(in) :: v
        real(real64), intent(in) :: s
        type(vec3) :: r
        r%x = v%x * s
        r%y = v%y * s
        r%z = v%z * s
    end function vec3_mul_scalar

    pure elemental function scalar_mul_vec3(s, v) result(r)
        real(real64), intent(in) :: s
        type(vec3), intent(in) :: v
        type(vec3) :: r
        r%x = s * v%x
        r%y = s * v%y
        r%z = s * v%z
    end function scalar_mul_vec3

    pure elemental function vec3_div_scalar(v, s) result(r)
        type(vec3), intent(in) :: v
        real(real64), intent(in) :: s
        type(vec3) :: r
        r%x = v%x / s
        r%y = v%y / s
        r%z = v%z / s
    end function vec3_div_scalar

    !=====================================================================
    ! Comparison operators — tolerance-based (epsilon ~ 1e-14 for real64)
    !=====================================================================
    pure elemental function vec3_eq(a, b) result(equal)
        type(vec3), intent(in) :: a, b
        logical :: equal
        real(real64), parameter :: eps = 1.0e-14_real64
        equal = (abs(a%x - b%x) < eps) .and. (abs(a%y - b%y) < eps) .and. &
                (abs(a%z - b%z) < eps)
    end function vec3_eq

    pure elemental function vec3_ne(a, b) result(notequal)
        type(vec3), intent(in) :: a, b
        logical :: notequal
        notequal = .not. (a .eq. b)
    end function vec3_ne

    !=====================================================================
    ! Vector algebra — pure functions
    !=====================================================================
    pure function dot(a, b) result(r)
        type(vec3), intent(in) :: a, b
        real(real64) :: r
        r = a%x * b%x + a%y * b%y + a%z * b%z
    end function dot

    pure function cross(a, b) result(r)
        type(vec3), intent(in) :: a, b
        type(vec3) :: r
        r%x = a%y * b%z - a%z * b%y
        r%y = a%z * b%x - a%x * b%z
        r%z = a%x * b%y - a%y * b%x
    end function cross

    pure function norm_squared(a) result(r)
        type(vec3), intent(in) :: a
        real(real64) :: r
        r = dot(a, a)
    end function norm_squared

    pure function norm(a) result(r)
        type(vec3), intent(in) :: a
        real(real64) :: r
        r = sqrt(norm_squared(a))
    end function norm

    pure function normalize(a) result(r)
        type(vec3), intent(in) :: a
        type(vec3) :: r
        real(real64) :: n
        n = norm(a)
        if (n > 0.0_real64) then
            r = a / n
        else
            r = zero_vec3
        end if
    end function normalize

end module vector3d
