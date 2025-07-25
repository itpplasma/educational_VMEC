!> \file
!> \brief Evaulate the Jacobian of the transform from flux- to cylindrical coordinates.

!> \brief Evaulate the Jacobian of the transform from flux- to cylindrical coordinates.
!>
SUBROUTINE jacobian
  USE vmec_main, ONLY: ohs, nrzt, first, iter2, num_eqsolve_retries
  USE vmec_params, ONLY: meven, modd
  use vmec_input, only: input_extension, nzeta, dump_jacobian
  USE realspace
  USE vmec_dim, ONLY: ns, ntheta3
  USE vforces, r12 => armn_o, ru12 => azmn_e, zu12 => armn_e, &
               rs  => bzmn_e, zs   => brmn_e, tau  => azmn_o

  use dbgout

  IMPLICIT NONE

  REAL(rprec), PARAMETER :: zero=0.0_dp, p5=0.5_dp, p25=p5*p5

  INTEGER :: l, js, ku, lk
  REAL(rprec) :: taumax, taumin, dshalfds=p25, temp(nrzt/ns) ! TODO: nrzt/ns == nznt?

  ! (RS, ZS)=(R, Z) SUB S, (RU12, ZU12)=(R, Z) SUB THETA(=U)
  ! AND TAU=SQRT(G)/R ARE DIFFERENCED ON HALF MESH
  !
  ! SQRT(G) = R*TAU IS COMPUTED IN BCOVAR
  !
  ! HERE, TAU = (Ru * Zs - Rs * Zu).

  ! THE DERIVATIVES OF SHALF = SQRT(s) WERE COMPUTED EXPLICITLY AS: d(shalf)/ds = .5/shalf
  ! This can be understood by noting shalf(i) = sqrt(s_{i-1/2}),
  ! leading to d/ds sqrt(s_{i-1/2}) = 1/2 * (s_{i-1/2})^{-1/2} = 0.5 / shalf.

  ! initially, all good
  first = 1

  ! try to fix weird leftover stuff in first entry
  r12 (1) = 0.0_dp
  ru12(1) = 0.0_dp
  zu12(1) = 0.0_dp
  rs  (1) = 0.0_dp
  zs  (1) = 0.0_dp

  DO l = 2,nrzt
    r12(l)  =  p5*( r1(l,meven) + r1(l-1,meven) + shalf(l)*( r1(l,modd)  + r1(l-1,modd)) ) ! R on half grid

    ru12(l) =  p5*( ru(l,meven) + ru(l-1,meven) + shalf(l)*( ru(l,modd)  + ru(l-1,modd)) ) ! dR/du on half grid
    zu12(l) =  p5*( zu(l,meven) + zu(l-1,meven) + shalf(l)*( zu(l,modd)  + zu(l-1,modd)) ) ! dZ/du on half grid

    rs(l)   = ohs*( r1(l,meven) - r1(l-1,meven) + shalf(l)*( r1(l,modd)  - r1(l-1,modd)) ) ! dR/ds on half grid
    zs(l)   = ohs*( z1(l,meven) - z1(l-1,meven) + shalf(l)*( z1(l,modd)  - z1(l-1,modd)) ) ! dZ/ds on half grid

    ! TODO: the lower four lines of below expression could be split off into some separate variables...
    tau(l)  = ru12(l)*zs(l) - rs(l)*zu12(l) + dshalfds*                               &
              (      ru(l,modd) *z1(l,modd) + ru(l-1,modd) *z1(l-1,modd)              &
                   - zu(l,modd) *r1(l,modd) - zu(l-1,modd) *r1(l-1,modd)              &
               + (   ru(l,meven)*z1(l,modd) + ru(l-1,meven)*z1(l-1,modd)              &
                   - zu(l,meven)*r1(l,modd) - zu(l-1,meven)*r1(l-1,modd) )/shalf(l) )
    
    ! Debug: trace negative tau values (first few radial/theta indices)
    if (tau(l) < 0.0 .and. l <= 5*ntheta3) then
      print *, "DEBUG: Negative tau at l=", l, " tau=", tau(l)
      print *, "  tau_main=", ru12(l)*zs(l) - rs(l)*zu12(l)
      print *, "  ru12=", ru12(l), " zs=", zs(l), " rs=", rs(l), " zu12=", zu12(l)
    endif
  END DO

  ! extrapolate as constant to axis
  temp(:) = tau(2:nrzt:ns)
  tau(1:nrzt:ns) = temp(:)

! TEST FOR SIGN CHANGE IN JACOBIAN
  taumax = MAXVAL(tau(2:nrzt))
  taumin = MINVAL(tau(2:nrzt))
  ! Debug: output jacobian status with iteration info
  if (taumax*taumin .lt. zero) then
     ! bad jacobian !
     first = 2
     print *, "DEBUG: Educational_VMEC BAD_JACOBIAN - taumin=", taumin, " taumax=", taumax, " iter=", iter2
  else
     print *, "DEBUG: Educational_VMEC GOOD_JACOBIAN - taumin=", taumin, " taumax=", taumax, " iter=", iter2
  end if

  ! check output from jacobian()
  if (open_dbg_context("jacobian", num_eqsolve_retries)) then

    call add_real_3d("r12",  ns, nzeta, ntheta3, r12 )
    call add_real_3d("ru12", ns, nzeta, ntheta3, ru12)
    call add_real_3d("zu12", ns, nzeta, ntheta3, zu12)
    call add_real_3d("rs",   ns, nzeta, ntheta3, rs  )
    call add_real_3d("zs",   ns, nzeta, ntheta3, zs  )
    call add_real_3d("tau",  ns, nzeta, ntheta3, tau )

    call add_real("taumax", taumax)
    call add_real("taumin", taumin)
    call add_int("irst", first)

    call close_dbg_out()
  end if

END SUBROUTINE jacobian
