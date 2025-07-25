!> \file
!> \brief Compute the real-space MHD forces.

!> \brief Compute the real-space MHD forces.
!>
SUBROUTINE forces
  USE vmec_main, p5 => cp5
  USE realspace

  ! I guess these double aliases are intended to show at which point in the code
  ! the respective arrays hold what quantity...
  ! E.g., ru12 gets filled by jacobian() and is overwritten with the force component azmn_e here.
  USE vforces,   ru12 => azmn_e,   zu12 => armn_e, &
               azmn_e => azmn_e, armn_e => armn_e, &
                 lv_e => crmn_e,   lu_e => czmn_e,   lu_o => czmn_o, &
               crmn_e => crmn_e, czmn_e => czmn_e, czmn_o => czmn_o

  use dbgout

  IMPLICIT NONE

  REAL(rprec), PARAMETER :: p25 = p5*p5
  REAL(rprec), PARAMETER :: dshalfds=p25

  INTEGER :: l, js, lk, ku
  INTEGER :: ndim
  REAL(rprec), DIMENSION(:), POINTER :: bsqr
  REAL(rprec), DIMENSION(:), POINTER :: gvvs
  REAL(rprec), DIMENSION(:), POINTER :: guvs
  REAL(rprec), DIMENSION(:), POINTER :: guus

  logical :: dbg_forces

  character(len=255) :: dump_filename2

  ! ON ENTRY, ARMN=ZU, BRMN=ZS, AZMN=RU, BZMN=RS, LU=R*BSQ, LV = BSQ*SQRT(G)/R12
  ! HERE, XS (X=Z,R) DO NOT INCLUDE DERIVATIVE OF EXPLICIT SQRT(S)
  ! BSQ = |B|**2/2 + p
  ! GIJ = (BsupI * BsupJ) * SQRT(G)  (I,J = U,V)
  ! IT IS ESSENTIAL THAT LU,LV AT j=1 ARE ZERO INITIALLY
  !
  ! SOME OF THE BIGGER LOOPS WERE SPLIT TO FACILITATE CACHE HITS, PIPELINING ON RISCS
  !
  ! ORIGIN OF VARIOUS TERMS
  !
  ! LU :  VARIATION OF DOMINANT RADIAL-DERIVATIVE TERMS IN JACOBIAN
  !
  ! LV :  VARIATION OF R-TERM IN JACOBIAN
  !
  ! GVV:  VARIATION OF R**2-TERM AND Rv**2,Zv**2 IN gvv
  !
  ! GUU, GUV: VARIATION OF Ru, Rv, Zu, Zv IN guu, guv

  ! inputs:
  ! lu_e, lv_e
  ! guu, guv, gvv
  ! ru12, zu12
  ! brmn_e, bzmn_e
  ! r1, z1, ru, zu, ru0, zu0
  ! rcon, zcon, rcon0, zcon0, gcon
  ! if lthreed:
  !  rv, zv

  dbg_forces = open_dbg_context("forces", num_eqsolve_retries)
  if (dbg_forces) then

    call add_real_3d("lu_e",        ns, nzeta, ntheta3, lu_e     )
    call add_real_3d("lv_e_in",     ns, nzeta, ntheta3, lv_e     )
    call add_real_3d("guu_in",      ns, nzeta, ntheta3, guu      )
    call add_real_3d("guv_in",      ns, nzeta, ntheta3, guv      )
    call add_real_3d("gvv_in",      ns, nzeta, ntheta3, gvv      )
    call add_real_3d("ru12",        ns, nzeta, ntheta3, ru12     )
    call add_real_3d("zu12",        ns, nzeta, ntheta3, zu12     )
    call add_real_3d("brmn_e_in",   ns, nzeta, ntheta3, brmn_e   )
    call add_real_3d("bzmn_e_in",   ns, nzeta, ntheta3, bzmn_e   )
    call add_real_3d("ru0",         ns, nzeta, ntheta3, ru0      )
    call add_real_3d("zu0",         ns, nzeta, ntheta3, zu0      )
    call add_real_3d("rcon0",       ns, nzeta, ntheta3, rcon0    )
    call add_real_3d("zcon0",       ns, nzeta, ntheta3, zcon0    )
    call add_real_3d("gcon",        ns, nzeta, ntheta3, gcon     )

    call add_real_4d("r1",   ns, 2, nzeta, ntheta3, r1,   order=(/ 1, 3, 4, 2 /) )
    call add_real_4d("z1",   ns, 2, nzeta, ntheta3, z1,   order=(/ 1, 3, 4, 2 /) )
    call add_real_4d("ru",   ns, 2, nzeta, ntheta3, ru,   order=(/ 1, 3, 4, 2 /) )
    call add_real_4d("zu",   ns, 2, nzeta, ntheta3, zu,   order=(/ 1, 3, 4, 2 /) )
    call add_real_4d("rcon_in", ns, 2, nzeta, ntheta3, rcon, order=(/ 1, 3, 4, 2 /) )
    call add_real_4d("zcon_in", ns, 2, nzeta, ntheta3, zcon, order=(/ 1, 3, 4, 2 /) )

    if (lthreed) then
      call add_real_4d("rv", ns, 2, nzeta, ntheta3, rv, order=(/ 1, 3, 4, 2 /) )
      call add_real_4d("zv", ns, 2, nzeta, ntheta3, zv, order=(/ 1, 3, 4, 2 /) )
    else
      call add_null("rv")
      call add_null("zv")
    end if
  end if ! dump_forces

  ndim = 1+nrzt ! TODO: remove this; one extra element at the end of a large vector sound like reconstruction stuff...

  ! POINTER ALIASES
  bsqr => extra1(:,1) ! output or temp
  gvvs => extra2(:,1) ! output or temp
  guvs => extra3(:,1) ! output or temp
  guus => extra4(:,1) ! output or temp

  ! zero values at axis
  lu_e(1:ndim:ns) = 0.0_dp ! fixup input
  lv_e(1:ndim:ns) = 0.0_dp ! fixup input
  guu(1:ndim:ns) = 0.0_dp ! fixup input
  guv(1:ndim:ns) = 0.0_dp ! fixup input
  gvv(1:ndim:ns) = 0.0_dp ! fixup input

  guus = guu*shalf ! output or temp
  guvs = guv*shalf ! output or temp
  gvvs = gvv*shalf ! output or temp

  armn_e  = ohs*zu12 * lu_e ! output or temp
  azmn_e  =-ohs*ru12 * lu_e ! output or temp
  brmn_e  = brmn_e * lu_e ! output or temp
  bzmn_e  =-bzmn_e * lu_e ! output or temp
  bsqr    = dshalfds*lu_e/shalf ! output or temp

  armn_o(1:ndim)  = armn_e(1:ndim) *shalf ! output or temp
  azmn_o(1:ndim)  = azmn_e(1:ndim) *shalf ! output or temp
  brmn_o(1:ndim)  = brmn_e(1:ndim) *shalf ! output or temp
  bzmn_o(1:ndim)  = bzmn_e(1:ndim) *shalf ! output or temp

  ! CONSTRUCT CYLINDRICAL FORCE KERNELS
  ! NOTE: presg(ns+1) == 0, AND WILL BE "FILLED IN" AT EDGE FOR FREE-BOUNDARY BY RBSQ
  
  ! Debug: Add debug output to compare with VMEC++ first iteration behavior
  if (iter2 == 1) then
    print *, "DEBUG: Educational_VMEC first iteration force construction starting"
    print *, "  First few guu values: ", guu(1:5)
    print *, "  First few gvv values: ", gvv(1:5)
    print *, "  First few armn_e values: ", armn_e(1:5)
    print *, "  First few azmn_e values: ", azmn_e(1:5)
    print *, "  First few lu_e values: ", lu_e(1:5)
    print *, "  First few shalf values: ", shalf(1:5)
    print *, "  First few zu12 values: ", zu12(1:5)
    print *, "  First few ru12 values: ", ru12(1:5)
    
    ! Check for NaN at specific indices that are problematic in VMEC++
    do l = 1, min(20, nrzt)
      if (.not. (armn_e(l) == armn_e(l))) then
        print *, "ERROR: NaN detected in armn_e at l=", l
      endif
      if (.not. (azmn_e(l) == azmn_e(l))) then
        print *, "ERROR: NaN detected in azmn_e at l=", l
      endif
      if (.not. (lu_e(l) == lu_e(l))) then
        print *, "ERROR: NaN detected in lu_e at l=", l, " value=", lu_e(l)
      endif
    end do
  end if
  
  DO l = 1, nrzt
     guu(l) = p5*(guu(l) + guu(l+1))
     gvv(l) = p5*(gvv(l) + gvv(l+1))
     bsqr(l) = bsqr(l) + bsqr(l+1)
     guus(l) = p5*(guus(l) + guus(l+1))
     gvvs(l) = p5*(gvvs(l) + gvvs(l+1))
     armn_e(l) = armn_e(l+1) - armn_e(l) + p5*(lv_e(l) + lv_e(l+1))
     azmn_e(l) = azmn_e(l+1) - azmn_e(l)
     brmn_e(l) = p5*(brmn_e(l) + brmn_e(l+1))
     bzmn_e(l) = p5*(bzmn_e(l) + bzmn_e(l+1))
  END DO

  armn_e(:nrzt) = armn_e(:nrzt)                            - (gvvs(:nrzt)*r1(:nrzt,1) + gvv(:nrzt)*r1(:nrzt,0))
  brmn_e(:nrzt) = brmn_e(:nrzt) +  bsqr(:nrzt)*z1(:nrzt,1) - (guus(:nrzt)*ru(:nrzt,1) + guu(:nrzt)*ru(:nrzt,0))
  bzmn_e(:nrzt) = bzmn_e(:nrzt) - (bsqr(:nrzt)*r1(:nrzt,1) +  guus(:nrzt)*zu(:nrzt,1) + guu(:nrzt)*zu(:nrzt,0))
  lv_e(1:ndim) = lv_e(1:ndim)*shalf(1:ndim)
  lu_o(1:ndim) = dshalfds*lu_e(1:ndim)

  DO l = 1, nrzt
     armn_o(l) = armn_o(l+1) - armn_o(l) - zu(l,0)*bsqr(l) + p5*(lv_e(l) + lv_e(l+1))
     azmn_o(l) = azmn_o(l+1) - azmn_o(l) + ru(l,0)*bsqr(l)
     brmn_o(l) = p5*(brmn_o(l) + brmn_o(l+1))
     bzmn_o(l) = p5*(bzmn_o(l) + bzmn_o(l+1))
     lu_o(l)   = lu_o(l) + lu_o(l+1)
  END DO

  if (dbg_forces) then
    ! save data before it gets overwritten again
    ! due to array re-usage

    call add_real_3d("lu_o",     ns, nzeta, ntheta3, lu_o  )
    call add_real_3d("lv_e_out", ns, nzeta, ntheta3, lv_e  )
  end if

  guu(1:nrzt)  = guu(1:nrzt) * sqrts(1:nrzt)**2
  bsqr(1:nrzt) = gvv(1:nrzt) * sqrts(1:nrzt)**2

  armn_o(:nrzt) = armn_o(:nrzt) - (zu(:nrzt,1)*lu_o(:nrzt) + bsqr(:nrzt)*r1(:nrzt,1) + gvvs(:nrzt)*r1(:nrzt,0))
  azmn_o(:nrzt) = azmn_o(:nrzt) +  ru(:nrzt,1)*lu_o(:nrzt)
  brmn_o(:nrzt) = brmn_o(:nrzt) +  z1(:nrzt,1)*lu_o(:nrzt) - (guu(:nrzt)*ru(:nrzt,1) + guus(:nrzt)*ru(:nrzt,0))
  bzmn_o(:nrzt) = bzmn_o(:nrzt) - (r1(:nrzt,1)*lu_o(:nrzt) + guu(:nrzt)*zu(:nrzt,1) + guus(:nrzt)*zu(:nrzt,0))

  IF (lthreed) THEN
     DO l = 1, nrzt
        guv(l)  = p5*(guv(l) + guv(l+1))
        guvs(l) = p5*(guvs(l) + guvs(l+1))
     END DO

     brmn_e(:nrzt) = brmn_e(:nrzt) - (guv(:nrzt)*rv(:nrzt,0) + guvs(:nrzt)*rv(:nrzt,1))
     bzmn_e(:nrzt) = bzmn_e(:nrzt) - (guv(:nrzt)*zv(:nrzt,0) + guvs(:nrzt)*zv(:nrzt,1))
     crmn_e(:nrzt) = guv(:nrzt) *ru(:nrzt,0) + gvv(:nrzt) *rv(:nrzt,0) + gvvs(:nrzt)*rv(:nrzt,1) + guvs(:nrzt)*ru(:nrzt,1)
     czmn_e(:nrzt) = guv(:nrzt) *zu(:nrzt,0) + gvv(:nrzt) *zv(:nrzt,0) + gvvs(:nrzt)*zv(:nrzt,1) + guvs(:nrzt)*zu(:nrzt,1)

     guv(:nrzt) = guv(:nrzt) * sqrts(:nrzt)*sqrts(:nrzt)

     brmn_o(:nrzt) = brmn_o(:nrzt) - (guvs(:nrzt)*rv(:nrzt,0) + guv(:nrzt)*rv(:nrzt,1))
     bzmn_o(:nrzt) = bzmn_o(:nrzt) - (guvs(:nrzt)*zv(:nrzt,0) + guv(:nrzt)*zv(:nrzt,1))
     crmn_o(:nrzt) = guvs(:nrzt)*ru(:nrzt,0) + gvvs(:nrzt)*rv(:nrzt,0) + bsqr(:nrzt)*rv(:nrzt,1) + guv(:nrzt) *ru(:nrzt,1)
     czmn_o(:nrzt) = guvs(:nrzt)*zu(:nrzt,0) + gvvs(:nrzt)*zv(:nrzt,0) + bsqr(:nrzt)*zv(:nrzt,1) + guv(:nrzt) *zu(:nrzt,1)
  ENDIF

  ! ASSIGN EDGE FORCES (JS = NS) FOR FREE BOUNDARY CALCULATION
  IF (ivac .ge. 1) THEN

!     if (ns.eq.16) then
!
!        ! plasma forces on LCFS before vacuum contribution gets added
!        write(dump_filename2, 997) iter2, trim(input_extension)
! 997 format('lcfsfp_',i5.5,'.',a)
!        open(unit=43, file=trim(dump_filename2), status="unknown")
!
!        lk = ns
!        do l=1, nznt
!          write(43, *) armn_e(lk+(l-1)*nznt), &
!                       armn_o(lk+(l-1)*nznt), &
!                       azmn_e(lk+(l-1)*nznt), &
!                       azmn_o(lk+(l-1)*nznt)
!        end do
!
!        close(43)
!
!
!
!
!        write(dump_filename2, 998) iter2, trim(input_extension)
! 998 format('vacforce_',i5.5,'.',a)
!        open(unit=43, file=trim(dump_filename2), status="unknown")
!
!        do l=1, nznt
!          write(43, *)  zu0(ns+(l-1)*nznt)*rbsq(l), &
!                       -ru0(ns+(l-1)*nznt)*rbsq(l)
!        end do
!
!        close(43)
!      end if



     ! no need for sqrt(s) scaling of odd-m contributions,
     ! since free-boundary contribution enters at LCFS where s=1 ==> sqrt(s)=1
     armn_e(ns:nrzt:ns) = armn_e(ns:nrzt:ns) + zu0(ns:nrzt:ns)*rbsq(1:nznt)
     armn_o(ns:nrzt:ns) = armn_o(ns:nrzt:ns) + zu0(ns:nrzt:ns)*rbsq(1:nznt)
     azmn_e(ns:nrzt:ns) = azmn_e(ns:nrzt:ns) - ru0(ns:nrzt:ns)*rbsq(1:nznt)
     azmn_o(ns:nrzt:ns) = azmn_o(ns:nrzt:ns) - ru0(ns:nrzt:ns)*rbsq(1:nznt)
  ENDIF

! #ifndef _HBANGLE
  ! COMPUTE CONSTRAINT FORCE KERNELS
  rcon(:nrzt,0) = (rcon(:nrzt,0) - rcon0(:nrzt)) * gcon(:nrzt)
  zcon(:nrzt,0) = (zcon(:nrzt,0) - zcon0(:nrzt)) * gcon(:nrzt)

  brmn_e(:nrzt) = brmn_e(:nrzt) + rcon(:nrzt,0)
  bzmn_e(:nrzt) = bzmn_e(:nrzt) + zcon(:nrzt,0)
  brmn_o(:nrzt) = brmn_o(:nrzt) + rcon(:nrzt,0) * sqrts(:nrzt)
  bzmn_o(:nrzt) = bzmn_o(:nrzt) + zcon(:nrzt,0) * sqrts(:nrzt)

  ! real-space B-type forces due to constraint only
  brmn_e_con(:nrzt) = brmn_e_con(:nrzt) + rcon(:nrzt,0)
  bzmn_e_con(:nrzt) = bzmn_e_con(:nrzt) + zcon(:nrzt,0)
  brmn_o_con(:nrzt) = brmn_o_con(:nrzt) + rcon(:nrzt,0) * sqrts(:nrzt)
  bzmn_o_con(:nrzt) = bzmn_o_con(:nrzt) + zcon(:nrzt,0) * sqrts(:nrzt)

  rcon(:nrzt,0) =  ru0(:nrzt) * gcon(:nrzt)
  zcon(:nrzt,0) =  zu0(:nrzt) * gcon(:nrzt)
  rcon(:nrzt,1) = rcon(:nrzt,0) * sqrts(:nrzt)
  zcon(:nrzt,1) = zcon(:nrzt,0) * sqrts(:nrzt)
! #end /* ndef _HBANGLE */

  if (dbg_forces) then
    call add_real_3d("armn_e", ns, nzeta, ntheta3, armn_e)
    call add_real_3d("armn_o", ns, nzeta, ntheta3, armn_o)
    call add_real_3d("brmn_e", ns, nzeta, ntheta3, brmn_e)
    call add_real_3d("brmn_o", ns, nzeta, ntheta3, brmn_o)
    call add_real_3d("azmn_e", ns, nzeta, ntheta3, azmn_e)
    call add_real_3d("azmn_o", ns, nzeta, ntheta3, azmn_o)
    call add_real_3d("bzmn_e", ns, nzeta, ntheta3, bzmn_e)
    call add_real_3d("bzmn_o", ns, nzeta, ntheta3, bzmn_o)
    if (lthreed) then
      call add_real_3d("crmn_e", ns, nzeta, ntheta3, crmn_e)
      call add_real_3d("crmn_o", ns, nzeta, ntheta3, crmn_o)
      call add_real_3d("czmn_e", ns, nzeta, ntheta3, czmn_e)
      call add_real_3d("czmn_o", ns, nzeta, ntheta3, czmn_o)
    else
      call add_null("crmn_e")
      call add_null("crmn_o")
      call add_null("czmn_e")
      call add_null("czmn_o")
    end if

    call add_real_3d("guu_out",  ns, nzeta, ntheta3, guu   )
    call add_real_3d("guus",     ns, nzeta, ntheta3, guus  )
    call add_real_3d("guv_out",  ns, nzeta, ntheta3, guv   )
    call add_real_3d("guvs",     ns, nzeta, ntheta3, guvs  )
    call add_real_3d("gvv_out",  ns, nzeta, ntheta3, gvv   )
    call add_real_3d("gvvs",     ns, nzeta, ntheta3, gvvs  )
    call add_real_3d("bsqr",     ns, nzeta, ntheta3, bsqr  )

    call add_real_4d("rcon_out", ns, 2, nzeta, ntheta3, rcon, order=(/ 1, 3, 4, 2 /) )
    call add_real_4d("zcon_out", ns, 2, nzeta, ntheta3, zcon, order=(/ 1, 3, 4, 2 /) )

    call close_dbg_out()
  end if

END SUBROUTINE forces
