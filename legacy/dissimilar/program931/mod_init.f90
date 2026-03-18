!______________________________________________________________________________
!
module initialization
!______________________________________________________________________________
!
	use geometry
	use constant
	use parameters

	implicit none

	logical steady
	!real(8) dgdt(nx,ny,nz),dgdc(nx,ny,nz)	 
	real(8) deltemp,cpavg,hlcal,hlatnt,hlatnt2,boufac,rhoscan,boufacc ! ,difsdifs(nx,ny,nz),difldifl(nx,ny,nz)
	!real(8) vis(nx,ny,nz),diff(nx,ny,nz),acpacp(nx,ny,nz),densmatrix(nx,ny,nz) !,acplacpl(nx,ny,nz)!,thconsthcons(nx,ny,nz),thconlthconl(nx,ny,nz)
	!real(8) uVel(nx,ny,nz),vVel(nx,ny,nz),wVel(nx,ny,nz),unot(nx,ny,nz),vnot(nx,ny,nz),wnot(nx,ny,nz)		
	!real(8) pressure(nx,ny,nz),pp(nx,ny,nz),temperature(nx,ny,nz),temperaturenot(nx,ny,nz),temp_hyw(nx,ny,nz),tnot(nx,ny,nz)
	!real(8) concentration(nx,ny,nz), concentrationnot(nx,ny,nz),concentrationaa(nx,ny,nz),hlatntmatrix(nx,ny,nz)
	!real(8) dux(nx,ny,nz),dvy(nx,ny,nz),dwz(nx,ny,nz),su(nx,ny,nz),sp(nx,ny,nz)
	!real(8) auvl(nx,ny,nz),avvl(nx,ny,nz),awvl(nx,ny,nz)
    real(8) kp_hyw ! Equilibrium partition coefficient

	DOUBLE PRECISION, DIMENSION(:,:,:), ALLOCATABLE ::dgdt,dgdc,vis,diff,acpacp,densmatrix, &
	  uVel,vVel,wVel,unot,vnot,wnot,&
	  pressure,pp,temperature,temperaturenot,temp_hyw,tnot, &
	  concentration, concentrationnot,concentrationaa,hlatntmatrix,&
	  dux,dvy,dwz,su,sp,&
	  auvl,avvl,awvl,tliquidmatrix,tsolidmatrix,tvapmatrix	


	integer ivar,ipoweroff,cstep,tstep,tmachl,tmachh,vapprintc,vapprintcontrol	!main
	integer tmMovOut,deltmMov !,lvinterface(nx,ny)
!	integer, DIMENSION(:,:), ALLOCATABLE ::lvinterface
	!real(8) phi_hyw(nx,ny,nz,nvar)
	DOUBLE PRECISION, DIMENSION(:,:,:,:), ALLOCATABLE ::phi_hyw
	!real(8) fracl(nx,ny,nz),fraclnot(nx,ny,nz)	
	DOUBLE PRECISION, DIMENSION(:,:,:), ALLOCATABLE ::fracl,fraclnot		
	real(8) resorm,refmom,ahtoploss
	real(8) tsolidtemp
	!real(8) ap(nx,ny,nz),an(nx,ny,nz),as(nx,ny,nz),ae(nx,ny,nz),aw(nx,ny,nz),at(nx,ny,nz),ab(nx,ny,nz), &
	!	apnot(nx,ny,nz),acpnot(nx,ny,nz) 
	DOUBLE PRECISION, DIMENSION(:,:,:), ALLOCATABLE ::ap,an,as,ae,aw,at,ab,apnot,acpnot
		
!	equivalence (phi_hyw(1,1,1,1),uVel(1,1,1)),(phi_hyw(1,1,1,2),vVel(1,1,1)),(phi_hyw(1,1,1,3),wVel(1,1,1)),	&
!		(phi_hyw(1,1,1,4),pp(1,1,1))

!equivalence (phi_hyw(1,1,1,1),uVel(1,1,1)),(phi_hyw(1,1,1,2),vVel(1,1,1)),(phi_hyw(1,1,1,3),wVel(1,1,1)),	&
!		(phi_hyw(1,1,1,4),pp(1,1,1))
				
  INTEGER :: temp1, temp2, ierr, status, ip, jp, kp,window_hyw
  	DOUBLE PRECISION, DIMENSION(:,:), ALLOCATABLE ::heatin,vap_heatloss
	DOUBLE PRECISION, DIMENSION(:,:,:), ALLOCATABLE ::massdiffusivity,dgdtdtdxu,dgdcdcdxu,dgdtdtdxv,dgdcdcdxv
	real, DIMENSION(:), ALLOCATABLE ::tboiltable
	real, DIMENSION(:,:), ALLOCATABLE ::machtable
	contains

subroutine initialize
		
	real(8) temperatureWest,temperatureEast,temperatureNorth,temperatureBottom,temperaturePreheat
	integer i,j,k
!********************************************************************
allocate(dgdt(nx,ny,nz),dgdc(nx,ny,nz),vis(nx,ny,nz),diff(nx,ny,nz),acpacp(nx,ny,nz),densmatrix(nx,ny,nz), &
	  uVel(nx,ny,nz),vVel(nx,ny,nz),wVel(nx,ny,nz),unot(nx,ny,nz),vnot(nx,ny,nz),wnot(nx,ny,nz),&
	  pressure(nx,ny,nz),pp(nx,ny,nz),temperature(nx,ny,nz),temperaturenot(nx,ny,nz),temp_hyw(nx,ny,nz),tnot(nx,ny,nz), &
	  concentration(nx,ny,nz), concentrationnot(nx,ny,nz),concentrationaa(nx,ny,nz),hlatntmatrix(nx,ny,nz),&
	  dux(nx,ny,nz),dvy(nx,ny,nz),dwz(nx,ny,nz),su(nx,ny,nz),sp(nx,ny,nz),&
	  auvl(nx,ny,nz),avvl(nx,ny,nz),awvl(nx,ny,nz),&
    !  lvinterface(nx,ny),&
      phi_hyw(nx,ny,nz,nvar),&
      fracl(nx,ny,nz),fraclnot(nx,ny,nz),&
      ap(nx,ny,nz),an(nx,ny,nz),as(nx,ny,nz),ae(nx,ny,nz),aw(nx,ny,nz),at(nx,ny,nz),ab(nx,ny,nz), &
      apnot(nx,ny,nz),acpnot(nx,ny,nz),&
      tliquidmatrix(nx,ny,nz),tsolidmatrix(nx,ny,nz),tvapmatrix(nx,ny,nz))

    allocate(heatin(nx,ny),vap_heatloss(nx,ny))
	allocate(massdiffusivity(nx,ny,nz),dgdtdtdxu(nx,ny,nz),dgdcdcdxu(nx,ny,nz),dgdtdtdxv(nx,ny,nz),dgdcdcdxv(nx,ny,nz))
    cstep=10
    tstep=20
    tmachl=2800
    tmachh=6000
    allocate(tboiltable(0-1:cstep+1))
    allocate(machtable(tmachl/tstep-1:tmachh/tstep+1,0-1:cstep+1)) ! for safety
!********************************************************************
    window_hyw=0
    tboiltable(:)=0.0
    machtable(:,:)=0.0
    vap_heatloss(:,:)=0.0
    betac = 0.23 !.76
	boufac = dens*g*beta
	boufacc= dens*g*betac
	rhoscan = dens*scanvel
    if(delt<100.0)then  
        rhoscan=0
		steady=.FALSE.
	else
		steady=.TRUE.
	endif
	!dgconst=1.872 !0.458
	!dgconst2=1.778 ! 1.650
	deltemp = tliquid - tsolid
	cpavg = (acp+acpl)*0.5
	hlcal = hsmelt+cpavg*deltemp
	hlatnt = hlfriz - hlcal
hlatnt=272000 !24100	
	deltemp = tliquid2 - tsolid2
	cpavg = (acp2+acpl2)*0.5
	hlcal = hsmelt2+cpavg*deltemp
	hlatnt2 = hlfriz2 - hlcal
hlatnt2=290000 !0 !21000	
	temperaturePreheat = tempPreheat
	temperatureWest = tempWest
	temperatureEast = tempEast
	temperatureNorth = tempNorth
	temperatureBottom = tempBottom
	do k=1,nk
	do j=1,nj
	do i=1,ni
		vis(i,j,k)=viscos
		uVel(i,j,k)=0.0
		unot(i,j,k)=0.0
		vVel(i,j,k)=0.0
		vnot(i,j,k)=0.0
		wVel(i,j,k)=0.0
		wnot(i,j,k)=0.0
		pressure(i,j,k)=0.0
		pp(i,j,k)=0.0
		temperature(i,j,k)=temperaturePreheat
		temperaturenot(i,j,k)=temperaturePreheat
		temp_hyw(i,j,k)=tempPreheat
		tnot(i,j,k)=tempPreheat
		dux(i,j,k)=0.0
		dvy(i,j,k)=0.0
		dwz(i,j,k)=0.0
		su(i,j,k)=0.0
		sp(i,j,k)=0.0
		concentration(i,j,k)=0.0
		concentrationnot(i,j,k)=0.0
		tsolidmatrix(i,j,k)=tsolid
        tvapmatrix(i,j,k)=tvap
		tliquidmatrix(i,j,k)=tliquid
		hlatntmatrix(i,j,k)=hlatnt
		auvl(i,j,k)=0.0
		avvl(i,j,k)=0.0
		awvl(i,j,k)=0.0
		dgdtdtdxu(i,j,k)=0.0
		dgdtdtdxv(i,j,k)=0.0
		dgdcdcdxu(i,j,k)=0.0
		dgdcdcdxv(i,j,k)=0.0
	enddo
	enddo
	enddo	



!------------initializaiton temperature BC: i=1 plane------------
	do j=1,nj
	do k=1,nk
		temperature(1,j,k)=temperatureWest
	enddo
	enddo

!-----i=ni plane------------------
	do j=1,nj
	do k=1,nk
		temperature(ni,j,k)=temperatureEast
	enddo
	enddo

!-----k=1 plane--------------
	do i=1,ni
	do j=1,nj
		temperature(i,j,1)=temperatureBottom
	enddo
	enddo

!-----j=nj plane---------------
	do i=1,ni
	do k=1,nk
		temperature(i,nj,k)=temperatureNorth
	enddo
	enddo
	
!	do k=1,nk
!	do j=1,nj
!	do i=1,ni
!	if(abs(y(j)).lt.2e-4)then
!	concentration(i,j,k)=(y(j)+2e-4)*0.5e4
!	concentrationnot(i,j,k)=(y(j)+2e-4)*0.5e4
!	endif
!	if(y(j).ge.0.0)then
!	concentration(i,j,k)=1.0
!	concentrationnot(i,j,k)=1.0
!	endif
!	enddo
!	enddo
!	enddo
	do k=1,nk
	do j=1,nj
	do i=1,ni
	if(abs(y(j)).lt.smoothdistance)then
	concentration(i,j,k)=(y(j)+smoothdistance)*0.5/smoothdistance
	concentrationnot(i,j,k)=(y(j)+smoothdistance)*0.5/smoothdistance
	endif
	if(y(j).ge.smoothdistance)then
	concentration(i,j,k)=1.0
	concentrationnot(i,j,k)=1.0
	endif
	enddo
	enddo
	enddo	
	do k=1,nk
	do j=1,nj
	do i=1,ni
	vis(i,j,k)=viscos*concentration(i,j,k)+viscos2*(1-concentration(i,j,k))
	dgdt(i,j,k)=dgdtp*concentration(i,j,k)+dgdtp2*(1-concentration(i,j,k))
    dgdc(i,j,k)=(dgconst-dgconst2) !*concentration(i,j,k)+(dgdtp2-dgdtp2)*temperature(i,j,k)
	acpacp(i,j,k)=acp*concentration(i,j,k)+acp2*(1-concentration(i,j,k))
!	acplacpl(i,j,k)=acpl*concentration(i,j,k)+acpl2*(1-concentration(i,j,k))
!	difsdifs(i,j,k)=thcons*concentration(i,j,k)+thcons2*(1-concentration(i,j,k))
!	difldifl(i,j,k)=thconl*concentration(i,j,k)+thconl2*(1-concentration(i,j,k))
!	difsdifs(i,j,k)=thconsthcons(i,j,k)
!	difldifl(i,j,k)=thconlthconl(i,j,k)
	tsolidmatrix(i,j,k)=tsolid*concentration(i,j,k)+tsolid2*(1-concentration(i,j,k))
	tliquidmatrix(i,j,k)=tliquid*concentration(i,j,k)+tliquid2*(1-concentration(i,j,k))
    tvapmatrix(i,j,k)=tvap*concentration(i,j,k)+tvap2*(1-concentration(i,j,k))
	hlatntmatrix(i,j,k)=hlatnt*concentration(i,j,k)+hlatnt2*(1-concentration(i,j,k))
	diff(i,j,k)=thconl*concentration(i,j,k)+thconl2*(1-concentration(i,j,k))
	enddo
	enddo
	enddo	
	delt=deltini

	tsolidtemp=min(tsolid,tsolid2)
	vapprintcontrol=.false.
	vapprintc=2
	tmMovOut = 1
	deltmMov = deltprint !e2
	return

end subroutine initialize

end module initialization

