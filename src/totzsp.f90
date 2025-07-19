!> \file
!> \brief Inverse-Fourier-transform geometry from Fourier space to real space

!> \brief Inverse-Fourier-transform symmetric part of geometry from Fourier space to real space
!>
!>  Forier transforms between Fourier space and real space. Computes quantities
!>  for R, dR/du, dR/dv, Z, dZ/du, dZ/dv, dlambda/du and dlambda/dv. Non
!>  derivative quantities are trans formed via
!>
!>    A_real = A_mnc*cos(mu - nv) + A_mns*sin(mu - nv)                       (1)
!>
!>  Derivatives with respect to u are transformed as
!>
!>    dA_real/du = -m*A_mnc*sin(mu - nv) + m*A_mns*cos(mu - nv)              (2)
!>
!>  Derivatives with respect to v are transformed as
!>
!>    dA_real/dv = n*A_mnc*sin(mu - nv) - m*A_mns*cos(mu - nv)               (3)
!>
!>  @param rzl_array Fourier amplitudes for Rmnc, Zmns and Lmns for lasym false.
!>                   When lasym is true, this also contains Rmns, Zmnc, Lmnc.
!>  @paran r11       Real space R
!>  @param ru1       Real space dR/du
!>  @param rv1       Real space dR/dz
!>  @param z11       Real space Z
!>  @param zu1       Real space dZ/du
!>  @param zv1       Real space dZ/dv
!>  @param lu1       Real space dlambda/du
!>  @param lv1       Real space -dlambda/dv
!>  @param rcn1      related to spectral constraint; sum_mn[m(m-1)*Rmn*cos(mu-nv)]
!>  @param zcn1      related to spectral constraint; sum_mn[m(m-1)*Zmn*sin(mu-nv)]
SUBROUTINE totzsps(rzl_array, r11, ru1, rv1, z11, zu1, zv1, lu1, lv1, rcn1, zcn1)

  USE vmec_main
  USE stel_kinds, only: rprec
  USE vmec_params, ONLY: jmin1, jlam, ntmax, rcc, rss, zsc, zcs, m0, m1, n0

  IMPLICIT NONE

  REAL(rprec), DIMENSION(ns,0:ntor,0:mpol1,3*ntmax), TARGET, INTENT(inout) :: rzl_array
  REAL(rprec), DIMENSION(ns*nzeta*ntheta3,0:1), INTENT(out) :: r11
  REAL(rprec), DIMENSION(ns*nzeta*ntheta3,0:1), INTENT(out) :: ru1
  REAL(rprec), DIMENSION(ns*nzeta*ntheta3,0:1), INTENT(out) :: rv1
  REAL(rprec), DIMENSION(ns*nzeta*ntheta3,0:1), INTENT(out) :: z11
  REAL(rprec), DIMENSION(ns*nzeta*ntheta3,0:1), INTENT(out) :: zu1
  REAL(rprec), DIMENSION(ns*nzeta*ntheta3,0:1), INTENT(out) :: zv1
  REAL(rprec), DIMENSION(ns*nzeta*ntheta3,0:1), INTENT(out) :: lu1
  REAL(rprec), DIMENSION(ns*nzeta*ntheta3,0:1), INTENT(out) :: lv1
  REAL(rprec), DIMENSION(ns*nzeta*ntheta3,0:1), INTENT(out) :: rcn1
  REAL(rprec), DIMENSION(ns*nzeta*ntheta3,0:1), INTENT(out) :: zcn1

  INTEGER :: n, m, mparity, k, i, j1, l, j1l, nsl
  INTEGER :: ioff, joff, mj, ni, nsz
  REAL(rprec), DIMENSION(:,:,:), POINTER :: rmncc, rmnss, zmncs, zmnsc, lmncs, lmnsc

  ! WORK1 Array of inverse transforms in toroidal angle (zeta), for all radial positions
  ! NOTE: ORDERING OF LAST INDEX IS DIFFERENT HERE THAN IN PREVIOUS VMEC2000 VERSIONS
  REAL(rprec), DIMENSION(:,:), ALLOCATABLE :: work1
  REAL(rprec) :: cosmux, sinmux

  ! This is the inverse Fourier transform from the (odd-m-scaled-by-1/sqrt(s))-xc
  ! given in rzl_array to real space. Tangential derivatives are also computed.

  ! WHEN COMPUTING PRECONDITIONER, USE FASTER HESSIAN VERSION (totzsps_hess) INSTEAD.
  rmncc => rzl_array(:,:,:,rcc)               ! COS(mu) COS(nv)
  zmnsc => rzl_array(:,:,:,zsc+ntmax)         ! SIN(mu) COS(nv)
  lmnsc => rzl_array(:,:,:,zsc+2*ntmax)       ! SIN(mu) COS(nv)
  IF (lthreed) THEN
     rmnss => rzl_array(:,:,:,rss)            ! SIN(mu) SIN(nv)
     zmncs => rzl_array(:,:,:,zcs+ntmax)      ! COS(mu) SIN(nv)
     lmncs => rzl_array(:,:,:,zcs+2*ntmax)    ! COS(mu) SIN(nv)

! #ifndef _HBANGLE
     ! CONVERT FROM INTERNAL XC REPRESENTATION FOR m=1 MODES, R+(stored at rss) = .5(rss + zcs),
     ! R-(stored at zcs) = .5(rss - zcs), TO EXTERNAL ("PHYSICAL") rss, zcs FORMS. NEED THIS EVEN
     ! WHEN COMPUTING HESSIAN FOR FREE BOUNDARY (rmnss, zmncs at JS=NS needed in vacuum call)

     CALL convert_sym (rmnss, zmncs)
! #end /* ndef _HBANGLE */

  END IF

  ! v8.50: Norm for preconditioned R,Z forces: scale to boundary value only
  ! v8.51  Restore hs dependence (1:ns, not just ns)
  !     fnorm1 = one/SUM(rzl_array(1:ns,:,m1:,1:2*ntmax)**2)

  ! ORIGIN EXTRAPOLATION (JS=1) FOR M=1 MODES
  ! --> TODO: why? quantities on axis should not have a poloidal dependence ???
  ! NOTE: PREVIOUS VERSIONS OF VMEC USED TWO-POINT EXTRAPOLATION FOR R,Z.
  !       HOWEVER,THIS CAN NOT BE USED TO COMPUTE THE TRI-DIAG 2D PRECONDITIONER.
  rzl_array(1,:,m1,:) = rzl_array(2,:,m1,:) ! now this is a constant extrapolation to the axis (????)

  ioff = LBOUND(rmncc,2) ! starting index along n
  joff = LBOUND(rmncc,3) ! starting index along m

  ! ORIGIN EXTRAPOLATION OF M=0 MODES FOR LAMBDA
  IF (lthreed .and. jlam(m0).gt.1) then
     lmncs(1,:,m0+joff) = lmncs(2,:,m0+joff)
  end if

  nsz = ns*nzeta
  ALLOCATE (work1(nsz,12), stat=i)
  IF (i .ne. 0) STOP 'Allocation error in VMEC2000 totzsps'

  r11 = 0;  ru1 = 0;  rv1 = 0;  rcn1 = 0
  z11 = 0;  zu1 = 0;  zv1 = 0;  zcn1 = 0
  lu1 = 0;  lv1 = 0

  ! COMPUTE R, Z, AND LAMBDA IN REAL SPACE
  ! NOTE: LU = d(Lam)/du, LV = -d(Lam)/dv
  DO m = 0, mpol1
     mparity = MOD(m,2)
     mj = m+joff
     work1 = 0

     ! m>1 contributions start at js=2, not 1 (axis)
     ! TODO: why has the axis even an m=1 contribution?
     j1 = jmin1(m)

     ! INVERSE TRANSFORM IN N-ZETA, FOR FIXED M
     DO n = 0, ntor
        ni = n+ioff
        DO k = 1, nzeta
           l = ns*(k-1)

           j1l = j1+l
           nsl = ns+l

           work1(j1l:nsl, 1) = work1(j1l:nsl, 1) + rmncc(j1:ns,ni,mj)*cosnv(k,n)
           work1(j1l:nsl, 6) = work1(j1l:nsl, 6) + zmnsc(j1:ns,ni,mj)*cosnv(k,n)
           work1(j1l:nsl,10) = work1(j1l:nsl,10) + lmnsc(j1:ns,ni,mj)*cosnv(k,n)

           IF (.not.lthreed) CYCLE

           work1(j1l:nsl, 4) = work1(j1l:nsl, 4) + rmnss(j1:ns,ni,mj)*cosnvn(k,n)
           work1(j1l:nsl, 7) = work1(j1l:nsl, 7) + zmncs(j1:ns,ni,mj)*cosnvn(k,n)
           work1(j1l:nsl,11) = work1(j1l:nsl,11) + lmncs(j1:ns,ni,mj)*cosnvn(k,n)

           work1(j1l:nsl, 2) = work1(j1l:nsl, 2) + rmnss(j1:ns,ni,mj)*sinnv(k,n)
           work1(j1l:nsl, 5) = work1(j1l:nsl, 5) + zmncs(j1:ns,ni,mj)*sinnv(k,n)
           work1(j1l:nsl, 9) = work1(j1l:nsl, 9) + lmncs(j1:ns,ni,mj)*sinnv(k,n)

           work1(j1l:nsl, 3) = work1(j1l:nsl, 3) + rmncc(j1:ns,ni,mj)*sinnvn(k,n)
           work1(j1l:nsl, 8) = work1(j1l:nsl, 8) + zmnsc(j1:ns,ni,mj)*sinnvn(k,n)
           work1(j1l:nsl,12) = work1(j1l:nsl,12) + lmnsc(j1:ns,ni,mj)*sinnvn(k,n)
        END DO
     END DO

     ! INVERSE TRANSFORM IN M-THETA, FOR ALL RADIAL, ZETA VALUES
     l = 0
     DO i = 1, ntheta2

        ! start and end indices of poloidal slice of current flux surface
        j1l = l+1
        nsl = l+nsz

        l = l + nsz

        ! basis functions for spectral constraint
        cosmux = xmpq(m,1)*cosmu(i,m)
        sinmux = xmpq(m,1)*sinmu(i,m)

        r11(j1l:nsl,mparity)  = r11(j1l:nsl,mparity)  + work1(1:nsz,1)*cosmu(i,m)
        ru1(j1l:nsl,mparity)  = ru1(j1l:nsl,mparity)  + work1(1:nsz,1)*sinmum(i,m)

! #ifndef _HBANGLE
        rcn1(j1l:nsl,mparity) = rcn1(j1l:nsl,mparity) + work1(1:nsz,1)*cosmux ! rmncc*cosnv*cosmux
! #end /* ndef _HBANGLE */

        z11(j1l:nsl,mparity)  = z11(j1l:nsl,mparity)  + work1(1:nsz,6)*sinmu(i,m)
        zu1(j1l:nsl,mparity)  = zu1(j1l:nsl,mparity)  + work1(1:nsz,6)*cosmum(i,m)

! #ifndef _HBANGLE
        zcn1(j1l:nsl,mparity) = zcn1(j1l:nsl,mparity) + work1(1:nsz,6)*sinmux ! zmnsc*cosnv*sinmux
! #end /* ndef _HBANGLE */

        lu1(j1l:nsl,mparity)  = lu1(j1l:nsl,mparity)  + work1(1:nsz,10)*cosmum(i,m)

        IF (.not.lthreed) CYCLE

        r11(j1l:nsl,mparity)  = r11(j1l:nsl,mparity)  + work1(1:nsz,2)*sinmu(i,m)
        ru1(j1l:nsl,mparity)  = ru1(j1l:nsl,mparity)  + work1(1:nsz,2)*cosmum(i,m)

! #ifndef _HBANGLE
        rcn1(j1l:nsl,mparity) = rcn1(j1l:nsl,mparity) + work1(1:nsz,2)*sinmux ! rmnss*sinnv*sinmux
! #end /* ndef _HBANGLE */

        rv1(j1l:nsl,mparity)  = rv1(j1l:nsl,mparity)  + work1(1:nsz,3)*cosmu(i,m) &
                                                      + work1(1:nsz,4)*sinmu(i,m)
        z11(j1l:nsl,mparity)  = z11(j1l:nsl,mparity)  + work1(1:nsz,5)*cosmu(i,m)

        zu1(j1l:nsl,mparity)  = zu1(j1l:nsl,mparity)  + work1(1:nsz,5)*sinmum(i,m)

! #ifndef _HBANGLE
        zcn1(j1l:nsl,mparity) = zcn1(j1l:nsl,mparity) + work1(1:nsz,5)*cosmux ! zmncs*sinnv*cosmux
! #end /* ndef _HBANGLE */

        zv1(j1l:nsl,mparity)  = zv1(j1l:nsl,mparity)  + work1(1:nsz,7)*cosmu(i,m) &
                                                      + work1(1:nsz,8)*sinmu(i,m)

        lu1(j1l:nsl,mparity)  = lu1(j1l:nsl,mparity)  + work1(1:nsz,9)*sinmum(i,m)
        lv1(j1l:nsl,mparity)  = lv1(j1l:nsl,mparity)  - (  work1(1:nsz,11)*cosmu(i,m) &
                                                         + work1(1:nsz,12)*sinmu(i,m)  )
     END DO

  END DO

  DEALLOCATE (work1)

END SUBROUTINE totzsps

!> \brief Convert from internal representation to "physical" rmnss, zmncs Fourier form.
!>
!> @param rmnss
!> @param zmncs
SUBROUTINE convert_sym(rmnss, zmncs)

  USE vmec_main
  USE vmec_params, only: m1
  USE stel_kinds, only: rprec

  IMPLICIT NONE

  REAL(rprec), DIMENSION(ns,0:ntor,0:mpol1), INTENT(inout) :: rmnss, zmncs

  REAL(rprec), DIMENSION(ns,0:ntor) :: temp

  ! CONVERT FROM INTERNAL REPRESENTATION TO "PHYSICAL" RMNSS, ZMNCS FOURIER FORM
  ! rmnss = (RMNSS+ZMNCS)
  ! zmncs = (RMNSS-ZMNCS)
  IF (lconm1) then

     ! This essentially reverts the operation performed at the end of readin().

     temp(:,:) = rmnss(:,:,m1)                  !This is internal
     rmnss(:,:,m1) = temp(:,:) + zmncs(:,:,m1)  !Now these are physical
     zmncs(:,:,m1) = temp(:,:) - zmncs(:,:,m1)

  end if

END SUBROUTINE convert_sym

!> \brief Inverse-Fourier-transform anti-symmetric part of geometry from Fourier space to real space
!>
!> @param rzl_array
!> @param r11
!> @param ru1
!> @param rv1
!> @param z11
!> @param zu1
!> @param zv1
!> @param lu1
!> @param lv1
!> @param rcn1
!> @param zcn1
SUBROUTINE totzspa(rzl_array, r11, ru1, rv1, z11, zu1, zv1, lu1, lv1, rcn1, zcn1)

  USE vmec_main
  USE stel_kinds, only: rprec
  USE vmec_params, ONLY: jmin1, jlam, ntmax, rcs, rsc, zcc, zss, m0, m1, n0

  IMPLICIT NONE

  REAL(rprec), DIMENSION(ns,0:ntor,0:mpol1,3*ntmax), TARGET, INTENT(inout) :: rzl_array
  REAL(rprec), DIMENSION(ns*nzeta,ntheta3,0:1), INTENT(out) :: &
     r11, ru1, rv1, z11, zu1, zv1, lu1, lv1, rcn1, zcn1

  INTEGER :: m, n, mparity, k, i, l, j1, j1l, nsl
  INTEGER :: ioff, joff, mj, ni
  REAL(rprec), DIMENSION(:,:,:), POINTER :: rmncs, rmnsc, zmncc, zmnss, lmncc, lmnss
  REAL(rprec), DIMENSION(:,:), ALLOCATABLE :: work1
  REAL(rprec) :: cosmux, sinmux

  ! WHEN COMPUTING PRECONDITIONER, USE FASTER HESSIAN VERSION (totzsps_hess) INSTEAD.

  rmnsc => rzl_array(:,:,:,rsc)               !!SIN(mu) COS(nv)
  zmncc => rzl_array(:,:,:,zcc+ntmax)         !!COS(mu) COS(nv)
  lmncc => rzl_array(:,:,:,zcc+2*ntmax)       !!COS(mu) COS(nv)
  IF (lthreed) THEN
     rmncs => rzl_array(:,:,:,rcs)            !!COS(mu) SIN(nv)
     zmnss => rzl_array(:,:,:,zss+ntmax)      !!SIN(mu) SIN(nv)
     lmnss => rzl_array(:,:,:,zss+2*ntmax)    !!SIN(mu) SIN(nv)
  END IF

  ! CONVERT FROM INTERNAL XC REPRESENTATION FOR m=1 MODES, R+(at rsc) = .5(rsc + zcc),
  ! R-(at zcc) = .5(rsc - zcc), TO REQUIRED rsc, zcc FORMS

! #ifndef _HBANGLE
  CALL convert_asym (rmnsc, zmncc)
! #end /* ndef _HBANGLE */

  ioff = LBOUND(rmnsc,2)
  joff = LBOUND(rmnsc,3)

  ALLOCATE (work1(ns*nzeta,12), stat=i)
  IF (i .ne. 0) STOP 'Allocation error in VMEC totzspa'

  ! INITIALIZATION BLOCK
  r11 = 0;  ru1 = 0;  rv1 = 0
  z11 = 0;  zu1 = 0;  zv1 = 0
  lu1 = 0;  lv1 = 0
  rcn1 = 0; zcn1 = 0

  ! DEBUG: Print first few input Fourier coefficients for asymmetric case
  if (iter2 == 1) then
    print *, "DEBUG: totzspa first iteration - asymmetric transform"
    print *, "  ns=", ns, " ntor=", ntor, " mpol1=", mpol1
    print *, "  nzeta=", nzeta, " ntheta3=", ntheta3
    ! Print first few rmnsc coefficients (SIN(mu) COS(nv))
    print *, "  First rmnsc values:"
    do m = 0, min(2, mpol1)
      do n = 0, min(2, ntor)
        print *, "    m=", m, " n=", n, " rmnsc(1:3)=", rmnsc(1:min(3,ns), n+ioff, m+joff)
      end do
    end do
    ! Check for NaN in input arrays
    do j1 = 1, min(ns, 10)
      do n = 0, ntor
        do m = 0, mpol1
          if (.not. (rmnsc(j1,n+ioff,m+joff) == rmnsc(j1,n+ioff,m+joff))) then
            print *, "ERROR: NaN in rmnsc at j1=", j1, " n=", n, " m=", m
          endif
        end do
      end do
    end do
  end if

  IF (jlam(m0) .gt. 1) lmncc(1,:,m0+joff) = lmncc(2,:,m0+joff)

  DO m = 0, mpol1
     mparity = MOD(m,2)
     mj = m+joff
     work1 = 0
     j1 = jmin1(m)
     DO n = 0, ntor
        ni = n+ioff
        DO k = 1, nzeta
           l = ns*(k-1)
           j1l = j1+l
           nsl = ns+l
           work1(j1l:nsl,1) = work1(j1l:nsl,1)   + rmnsc(j1:ns,ni,mj)*cosnv(k,n)
           work1(j1l:nsl,6) = work1(j1l:nsl,6)   + zmncc(j1:ns,ni,mj)*cosnv(k,n)
           work1(j1l:nsl,10) = work1(j1l:nsl,10) + lmncc(j1:ns,ni,mj)*cosnv(k,n)

           IF (.not.lthreed) CYCLE

           work1(j1l:nsl,2) = work1(j1l:nsl,2)   + rmncs(j1:ns,ni,mj)*sinnv(k,n)
           work1(j1l:nsl,3) = work1(j1l:nsl,3)   + rmnsc(j1:ns,ni,mj)*sinnvn(k,n)
           work1(j1l:nsl,4) = work1(j1l:nsl,4)   + rmncs(j1:ns,ni,mj)*cosnvn(k,n)
           work1(j1l:nsl,5) = work1(j1l:nsl,5)   + zmnss(j1:ns,ni,mj)*sinnv(k,n)
           work1(j1l:nsl,7) = work1(j1l:nsl,7)   + zmnss(j1:ns,ni,mj)*cosnvn(k,n)
           work1(j1l:nsl,8) = work1(j1l:nsl,8)   + zmncc(j1:ns,ni,mj)*sinnvn(k,n)
           work1(j1l:nsl,9) = work1(j1l:nsl,9)   + lmnss(j1:ns,ni,mj)*sinnv(k,n)
           work1(j1l:nsl,11) = work1(j1l:nsl,11) + lmnss(j1:ns,ni,mj)*cosnvn(k,n)
           work1(j1l:nsl,12) = work1(j1l:nsl,12) + lmncc(j1:ns,ni,mj)*sinnvn(k,n)
        END DO
     END DO

     ! INVERSE TRANSFORM IN M-THETA
     DO i = 1, ntheta2

        cosmux = xmpq(m,1)*cosmu(i,m)
        sinmux = xmpq(m,1)*sinmu(i,m)

        r11(:,i,mparity) = r11(:,i,mparity) + work1(:,1)*sinmu(i,m)
        ru1(:,i,mparity) = ru1(:,i,mparity) + work1(:,1)*cosmum(i,m)
        z11(:,i,mparity) = z11(:,i,mparity) + work1(:,6)*cosmu(i,m)
        zu1(:,i,mparity) = zu1(:,i,mparity) + work1(:,6)*sinmum(i,m)
        lu1(:,i,mparity) = lu1(:,i,mparity) + work1(:,10)*sinmum(i,m)
        
        ! DEBUG: Check intermediate values for first few points
        if (iter2 == 1 .and. m <= 2 .and. i <= 3) then
          print *, "  m=", m, " i=", i, " mparity=", mparity
          print *, "    work1(1,1)=", work1(1,1), " sinmu=", sinmu(i,m)
          print *, "    r11(1,i,mparity)=", r11(1,i,mparity)
          ! Check for NaN
          if (.not. (r11(1,i,mparity) == r11(1,i,mparity))) then
            print *, "ERROR: NaN detected in r11 at i=", i, " m=", m
          endif
        end if

! #ifndef _HBANGLE
        rcn1(:,i,mparity) = rcn1(:,i,mparity) + work1(:,1)*sinmux
        zcn1(:,i,mparity) = zcn1(:,i,mparity) + work1(:,6)*cosmux
! #end /* ndef _HBANGLE */

        IF (.not.lthreed) CYCLE

        r11(:,i,mparity) = r11(:,i,mparity) + work1(:,2)*cosmu(i,m)
        ru1(:,i,mparity) = ru1(:,i,mparity) + work1(:,2)*sinmum(i,m)
        z11(:,i,mparity) = z11(:,i,mparity) + work1(:,5)*sinmu(i,m)
        zu1(:,i,mparity) = zu1(:,i,mparity) + work1(:,5)*cosmum(i,m)
        lu1(:,i,mparity) = lu1(:,i,mparity) + work1(:,9)*cosmum(i,m)

! #ifndef _HBANGLE
        rcn1(:,i,mparity) = rcn1(:,i,mparity) + work1(:,2)*cosmux
        zcn1(:,i,mparity) = zcn1(:,i,mparity) + work1(:,5)*sinmux
! #end /* ndef _HBANGLE */

        rv1(:,i,mparity) = rv1(:,i,mparity) + work1(:,3)*sinmu(i,m) + work1(:,4)*cosmu(i,m)
        zv1(:,i,mparity) = zv1(:,i,mparity) + work1(:,7)*sinmu(i,m) + work1(:,8)*cosmu(i,m)
        lv1(:,i,mparity) = lv1(:,i,mparity) - (work1(:,11)*sinmu(i,m)+work1(:,12)*cosmu(i,m))
     END DO
  END DO

  ! DEBUG: Print first few output values
  if (iter2 == 1) then
    print *, "DEBUG: totzspa output - first few values:"
    print *, "  r11(1:3,1,0)=", r11(1:3,1,0)
    print *, "  r11(1:3,1,1)=", r11(1:3,1,1)
    print *, "  z11(1:3,1,0)=", z11(1:3,1,0)
    print *, "  z11(1:3,1,1)=", z11(1:3,1,1)
    ! Check for NaN in outputs
    do i = 1, min(10, ns*nzeta)
      do j1 = 1, ntheta3
        do k = 0, 1
          if (.not. (r11(i,j1,k) == r11(i,j1,k))) then
            print *, "ERROR: NaN in r11 output at i=", i, " j1=", j1, " k=", k
          endif
          if (.not. (z11(i,j1,k) == z11(i,j1,k))) then
            print *, "ERROR: NaN in z11 output at i=", i, " j1=", j1, " k=", k
          endif
        end do
      end do
    end do
  end if

  DEALLOCATE (work1)

END SUBROUTINE totzspa

!> \brief Convert from internal representation to "physical" rmnsc, zmncc Fourier form.
!>
!> @param rmnsc
!> @param zmncc
SUBROUTINE convert_asym(rmnsc, zmncc)

  USE vmec_main
  USE stel_kinds, only: rprec

  IMPLICIT NONE

  REAL(rprec), DIMENSION(ns,0:ntor,0:mpol1), INTENT(inout) :: rmnsc, zmncc

  REAL(rprec), DIMENSION(ns,0:ntor) :: temp

  ! CONVERT FROM INTERNAL REPRESENTATION TO "PHYSICAL" RMNSC, ZMNCC FOURIER FORM
  ! rmnsc(in) = .5(RMNSC+ZMNCC), zmncc(in) = .5(RMNSC-ZMNCC) -> 0
  IF (lconm1) then

     temp(:,:) = rmnsc(:,:,1)                   !THIS IS INTERNAL
     rmnsc(:,:,1) = temp(:,:) + zmncc(:,:,1)    !NOW THE rmnsc,zmncc ARE PHYSICAL
     zmncc(:,:,1) = temp(:,:) - zmncc(:,:,1)

  end if

END SUBROUTINE convert_asym
