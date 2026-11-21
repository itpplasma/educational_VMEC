!> \file
!> \brief Unit test for the mgrid interpolation in becoil.
!>
!> becoil must reproduce a field that is cubic in R and in Z to rounding error,
!> also next to the grid edges. The earlier bilinear interpolation leaves an
!> O(h**2) error of about 1e-2 on this grid, so the test fails against it.
program test_becoil
  use stel_kinds, only: rprec
  use vacmod0, only: nuv2, nv
  use vacmod, only: brad, bphi, bz
  use mgrid_mod, only: nr0b, nz0b, np0b, rminb, rmaxb, zminb, zmaxb, delrb, delzb
  implicit none

  integer, parameter :: nr = 9, nz = 11, npts = 400
  real(rprec), parameter :: tol = 1.0e-12_rprec

  real(rprec) :: brvac(nr, nz, 1), bpvac(nr, nz, 1), bzvac(nr, nz, 1)
  real(rprec) :: rad(npts), zee(npts)
  real(rprec) :: br0, bp0, bz0, err
  integer :: i, j

  nr0b = nr
  nz0b = nz
  np0b = 1
  rminb = 1.0_rprec
  rmaxb = 2.6_rprec
  zminb = -0.9_rprec
  zmaxb = 0.9_rprec
  delrb = (rmaxb - rminb)/(nr - 1)
  delzb = (zmaxb - zminb)/(nz - 1)
  nv = 1
  nuv2 = npts
  allocate (brad(npts), bphi(npts), bz(npts))

  do j = 1, nz
    do i = 1, nr
      call field(rminb + (i - 1)*delrb, zminb + (j - 1)*delzb, &
                 brvac(i, j, 1), bpvac(i, j, 1), bzvac(i, j, 1))
    end do
  end do

  ! points spread over the whole box, including the cells at its edges
  do i = 1, npts
    rad(i) = rminb + (rmaxb - rminb)*mod(0.6180339887_rprec*i, 1.0_rprec)
    zee(i) = zminb + (zmaxb - zminb)*mod(0.4142135624_rprec*i, 1.0_rprec)
  end do

  call becoil(rad, zee, brvac, bpvac, bzvac)

  err = 0
  do i = 1, npts
    call field(rad(i), zee(i), br0, bp0, bz0)
    err = max(err, abs(brad(i) - br0), abs(bphi(i) - bp0), abs(bz(i) - bz0))
  end do

  print *, "max interpolation error", err
  if (err > tol) error stop 1

contains

  subroutine field(r, z, fr, fp, fz)
    real(rprec), intent(in)  :: r, z
    real(rprec), intent(out) :: fr, fp, fz

    fr = r**3 - 2*r*z**2 + z
    fp = 2 - r*z + z**3*r**2
    fz = r**2*z - 0.5_rprec*z**2 + r**3*z**3
  end subroutine field

end program test_becoil
