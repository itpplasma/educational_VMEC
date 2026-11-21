!> \file
!> \brief Compute the cylindrical components of the magnetic field due to external coils
!>        by bi-cubic Lagrange interpolation of the \c mgrid file.

!> \brief Compute the cylindrical components of the magnetic field due to external coils.
!>        by bi-cubic Lagrange interpolation of the \c mgrid file.
!>
!> @param rad \f$R\f$ at which to evaluate the external magnetic field
!> @param zee \f$Z\f$ at which to evaluate the external magnetic field
!> @param brvac cylindrical component of external magnetic field \f$B^R\f$
!> @param bpvac cylindrical component of external magnetic field \f$B^\varphi\f$
!> @param bzvac cylindrical component of external magnetic field \f$B^Z\f$
SUBROUTINE becoil(rad, zee, brvac, bpvac, bzvac)

  ! USE vparams, ONLY: nthreed
  USE vacmod
  USE mgrid_mod, ONLY: nr0b, np0b, nz0b, rminb, zminb, rmaxb, zmaxb, delrb, delzb

  use json

  IMPLICIT NONE

  REAL(rprec), DIMENSION(nuv2), INTENT(in) :: rad, zee
  REAL(rprec), DIMENSION(nr0b,nz0b,np0b), INTENT(in) :: brvac, bpvac, bzvac

  CHARACTER(LEN=50), PARAMETER :: warning = 'Plasma Boundary exceeded Vacuum Grid Size'

  INTEGER, SAVE :: icount = 0
  INTEGER :: i, kv, ir, jz, ii, jj, nrw, nzw
  REAL(rprec) :: rad0, zee0, ri, zj, pr, qz, w
  REAL(rprec), DIMENSION(4) :: wr, wz

  ! DETERMINE THE CYLINDRICAL COMPONENTS OF THE EXTERNAL
  ! MAGNETIC FIELD (BR, BP, BZ) AT A FIXED PHI PLANE BY
  ! USING 2-D TENSOR-PRODUCT 4-POINT (CUBIC) LAGRANGE INTERPOLATION
  ! ON A CENTRED STENCIL, SHIFTED INWARD AT THE GRID EDGES.
  ! THE FORMER BILINEAR FORMULA (ABRAMOWITZ AND STEGUN 25.2.66) LEFT
  ! AN O(H**2) FIELD ERROR THAT MOVED THE FREE BOUNDARY.
  !
  ! BRVAC, BPVAC, BZVAC: CYLINDRICAL COMPONENTS OF VACUUM B-FIELD
  !                      STORED ON R, Z, PHI GRID
  !
  ! RAD, ZEE:            ARRAY OF R, Z VALUES (ON FLUX SURFACE)
  !                      AT WHICH B-FIELD IS TO BE DETERMINED

!   if (icount .eq. 0) then
!     ! dump MGRID contents to text file for comparison with re-created file
!
!     call open_dbg_out("mgrid.json")
!
!     call add_int("nr0b", nr0b)
!     call add_int("nz0b", nz0b)
!     call add_int("np0b", np0b)
!
!     call add_real_3d("brvac", nr0b, nz0b, np0b, brvac)
!     call add_real_3d("bpvac", nr0b, nz0b, np0b, bpvac)
!     call add_real_3d("bzvac", nr0b, nz0b, np0b, bzvac)
!
!     call close_dbg_out()
!   end if

  icount = icount + 1

  DO i = 1, nuv2

     ! CHECK THAT BOUNDARY POINTS ARE INSIDE VACUUM GRID.
     ! IF NOT, SET THEM EQUAL TO LARGEST (OR SMALLEST) VACUUM GRID POINTS
     rad0 = MIN(rad(i), rmaxb)
     rad0 = MAX(rad0,   rminb)
     zee0 = MIN(zee(i), zmaxb)
     zee0 = MAX(zee0,   zminb)

     ! DETERMINE PHI-PLANE, KV (MUST LIE IN FIRST FIELD PERIOD)
     kv = 1 + MOD(i - 1,nv)

     ! Axi-symmetric special case
     kv = MIN (kv, np0b)

     ! DETERMINE THE FIRST STENCIL NODE (IR,JZ) AND THE OFFSETS PR, QZ
     ! OF THE POINT FROM IT IN UNITS OF THE GRID SPACING
     nrw = MIN(4, nr0b)
     nzw = MIN(4, nz0b)
     ri = (rad0 - rminb)/delrb
     zj = (zee0 - zminb)/delzb
     ir = MIN(MAX(INT(ri) - 1, 0), nr0b - nrw) + 1
     jz = MIN(MAX(INT(zj) - 1, 0), nz0b - nzw) + 1
     pr = ri - (ir - 1)
     qz = zj - (jz - 1)
     CALL lagrange_weights(pr, nrw, wr)
     CALL lagrange_weights(qz, nzw, wz)

     ! COMPUTE B FIELD AT R, PHI, Z BY INTERPOLATION
     brad(i) = 0
     bphi(i) = 0
     bz(i)   = 0
     DO jj = 1, nzw
       DO ii = 1, nrw
         w = wr(ii)*wz(jj)
         brad(i) = brad(i) + w*brvac(ir+ii-1,jz+jj-1,kv)
         bphi(i) = bphi(i) + w*bpvac(ir+ii-1,jz+jj-1,kv)
         bz(i)   = bz(i)   + w*bzvac(ir+ii-1,jz+jj-1,kv)
       END DO
     END DO

  END DO

  IF (MOD(icount,25).eq.0) THEN
     ! PRINT INFO IF R, Z OUT OF BOX
     i = 0
     rad0 = MAXVAL(rad)
     zee0 = MAXVAL(zee)
     IF (rad0 .gt. rmaxb) i = 1
     IF (zee0 .gt. zmaxb) i = i + 2
     ri   = MINVAL(rad)
     zj   = MINVAL(zee)
     IF (ri .lt. rminb) i = i + 4
     IF (zj .lt. zminb) i = i + 8
     IF (i .ne. 0) THEN
        PRINT *, warning
        ! WRITE (nthreed, *) warning
        IF (i/8 .ne. 0) PRINT *,' zmin = ', zj
        i = MOD(i,8)
        IF (i/4 .ne. 0) PRINT *,' rmin = ', ri
        i = MOD(i,4)
        IF (i/2 .ne. 0) PRINT *,' zmax = ', zee0
        i = MOD(i,2)
        IF (i .ne. 0) PRINT *,' rmax = ', rad0
     END IF
  ENDIF

CONTAINS

  !> \brief Weights of the n-node Lagrange polynomial on the nodes 0, ..., n-1 at u.
  SUBROUTINE lagrange_weights(u, n, wt)
    REAL(rprec), INTENT(in) :: u
    INTEGER, INTENT(in) :: n
    REAL(rprec), DIMENSION(4), INTENT(out) :: wt
    INTEGER :: k, m

    wt = 0
    DO k = 1, n
      wt(k) = 1
      DO m = 1, n
        IF (m .ne. k) wt(k) = wt(k)*(u - (m - 1))/(k - m)
      END DO
    END DO
  END SUBROUTINE lagrange_weights

END SUBROUTINE becoil
