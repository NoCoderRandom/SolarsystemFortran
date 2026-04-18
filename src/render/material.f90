!===============================================================================
! material.f90 — Material kinds and per-body texture bundles
!
! Each planet gets one material_t that owns its textures and describes
! the special-case branches the planet shader should take:
!   MATERIAL_GENERIC     — albedo + normal (optional) only
!   MATERIAL_EARTH       — adds night lights, ocean specular mask, cloud layer
!   MATERIAL_GAS_GIANT   — no normal map, low spec, atmospheric rim
!   MATERIAL_SATURN_RINGS— rendered through a separate ring shader
!===============================================================================
module material_mod
    use, intrinsic :: iso_c_binding, only: c_float
    use texture_mod, only: texture_t, texture_destroy
    implicit none
    private

    public :: material_t, material_destroy, &
              MATERIAL_GENERIC, MATERIAL_EARTH, MATERIAL_GAS_GIANT, &
              MATERIAL_SATURN_RINGS

    integer, parameter :: MATERIAL_GENERIC      = 0
    integer, parameter :: MATERIAL_EARTH        = 1
    integer, parameter :: MATERIAL_GAS_GIANT    = 2
    integer, parameter :: MATERIAL_SATURN_RINGS = 3

    type :: material_t
        integer         :: kind = MATERIAL_GENERIC
        type(texture_t) :: albedo
        type(texture_t) :: normal       ! optional — valid=.false. if absent
        type(texture_t) :: night        ! Earth only
        type(texture_t) :: specular     ! Earth: ocean mask
        type(texture_t) :: clouds       ! Earth: cloud layer (unused for now)
        ! Shading parameters
        real(c_float) :: shininess   = 32.0_c_float
        real(c_float) :: spec_scale  = 0.0_c_float  ! 0 = no specular
        real(c_float) :: rim_power   = 0.0_c_float  ! 0 = no atmospheric rim
        real(c_float) :: rim_color(3) = [0.3_c_float, 0.5_c_float, 0.9_c_float]
    end type material_t

contains

    subroutine material_destroy(mat)
        type(material_t), intent(inout) :: mat
        call texture_destroy(mat%albedo)
        call texture_destroy(mat%normal)
        call texture_destroy(mat%night)
        call texture_destroy(mat%specular)
        call texture_destroy(mat%clouds)
    end subroutine material_destroy

end module material_mod
