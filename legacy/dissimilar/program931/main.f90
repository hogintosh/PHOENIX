
!****************************************************************************
!
!  Heat Transfer and Fluid Flow during Laser Processing
!
!  Version 1.0
!
!  July, 2008
!
!****************************************************************************

program main
	use geometry
	use parameters
	use initialization
	use discretization
	use dimensions
	use boundary
	use source
	use residue
	use solver
	use fluxes
	use printing
	use constant
	use entotemp
	use convergence
	use property
	use revision
	use laserinput
	use species_transport
	use mod_vaporization

	implicit none
	integer i,j,k
	integer flag
	integer maxitcon
    integer nitercon,vap_control
	real(8) amaxres
	integer deltvaryit
	
	call read_data
	call generate_grid
	call OpenFiles
	call initialize

	if (steady .or. scanvel.eq.0) call laser_beam
	call StartTime

	ipoweroff=0
	itertot=0
	timet=small
!    call vaporization
10	timet=timet+delt
 !   if(timet.ge.19e-3)delt=5e-5
!	vap_control=0
    vapprintcontrol=.false.
	if (.not. steady .and. scanvel.ne.0.and.ipoweroff.lt.1) call laser_beam  ! not equal
    if(ipoweroff.ge.1)maxit=100
	niter=0
!	call vaporization
!-----iteration loop----------------
30	niter=niter+1
	itertot=itertot+1
!-----ivar=5------------
	ivar=5
!    if(vap_control.gt.0)call vaporization
	call vaporization
	call bound_condition
	call discretize
	call source_term
	call residual
	call enhance_converge_speed
	call solution_temperature
	call temperature_to_temp
	call properties
	call pool_size
	if(tpeak.le.tsolid) goto 41
	call cleanuvw

!-----ivar=1,4------------
	do ivar=1,4
		call bound_condition
if(ivar.eq.1)phi_hyw(1:,:,:,1)=uVel(1:,:,:)
if(ivar.eq.2)phi_hyw(1:,:,:,2)=vVel(1:,:,:)
if(ivar.eq.3)phi_hyw(1:,:,:,3)=wVel(1:,:,:)
if(ivar.eq.4)phi_hyw(1:,:,:,4)=pp(1:,:,:)
		call discretize
		call source_term
		call residual
		call solution_uvw
if(ivar.eq.1)	uVel(1:,:,:)=phi_hyw(1:,:,:,1)
if(ivar.eq.2)	vVel(1:,:,:)=phi_hyw(1:,:,:,2)
if(ivar.eq.3)	wVel(1:,:,:)=phi_hyw(1:,:,:,3)
if(ivar.eq.4)	pp(1:,:,:)=phi_hyw(1:,:,:,4)
		call revision_p
	enddo
phi_hyw(1:,:,:,1)=uVel(1:,:,:)
phi_hyw(1:,:,:,2)=vVel(1:,:,:)
phi_hyw(1:,:,:,3)=wVel(1:,:,:)
phi_hyw(1:,:,:,4)=pp(1:,:,:)
!	if(resoru.ge.1e5)uVel(1:,:,:)=0.0
!	if(resorv.ge.1e5)vVel(1:,:,:)=0.0
!	if(resorw.ge.1e5)wVel(1:,:,:)=0.0
41	continue
call boundary_species
call species  
call source_species
call residual_species
call enhance_species_speed
call solution_species 
	amaxres=max(resorm,resoru,resorv,resorw,resorc)  
!if(resorw.ge.10e10)wVel(:,:,:)=0.0
!-----convergence criterion------------
444		call heat_fluxes
	if(steady) then
		if(mod(niter,100).eq.0) then
			call caltime
			call outputres
		endif
		if(ratio.le.1.001.and.ratio.ge.0.999.and.amaxres.lt.5.0e-5) goto 50 

	else
		if(ipoweroff.lt.1.and.ratio.le.1.001.and.ratio.ge.0.999.and.amaxres.lt.5.0e-5) goto 50
		if(ipoweroff.ge.1.and.amaxres.lt.5.0e-10) goto 50
	endif  
	if(niter.lt.maxit) goto 30
50	continue

if(amaxres.ge.10.)then
write(*,*)timet
write(*,*)delt
        deltvaryit=0
			uVel(:,:,:)=unot(:,:,:)
			vVel(:,:,:)=vnot(:,:,:)
			wVel(:,:,:)=wnot(:,:,:)
     if(delt.le.1e-6)then
			temp_hyw(:,:,:)=tnot(:,:,:)
			temperature(:,:,:)=temperaturenot(:,:,:)
			concentration(:,:,:)= concentrationnot(:,:,:)
	!		fracl(:,:,:)=fraclnot(:,:,:)
        timet=timet-delt
        delt=delt/2
        write(*,*)timet
        write(*,*)delt
        goto 10
     endif
endif
deltvaryit=deltvaryit+1
if(deltvaryit.ge.6)then
delt=deltini !/4 !min(delt*4,deltini)
deltvaryit=0
write(*,*)deltvaryit
write(*,*)timet
write(*,*)delt
endif

    if(mod(vapprintc,deltmMov).lt.1)vapprintcontrol=.true.
    call vaporization
    call vapprint
!flag=1
!maxitcon=1e4
!nitercon=0
!do while(flag>0.and.nitercon.lt.maxitcon)
!call boundary_species
!call species  
!call source_species
!call residual_species
!call enhance_species_speed
!call solution_species 
!if(resorc.lt.5.0e-7) flag=0
!nitercon=nitercon+1
!end do
!if(nitercon.ge.maxitcon) write(*,*) nitercon



	call CalTime
	if(.not.steady) then
		call outputres

		do k=1,nk
		do j=1,nj
		do i=1,ni
	if(temp_hyw(i,j,k).le.tempPreheat)temp_hyw(i,j,k)=tempPreheat
			if(temp_hyw(i,j,k).le.tsolidmatrix(i,j,k)) then
				uVel(i,j,k)=0.0
				vVel(i,j,k)=0.0
				wVel(i,j,k)=0.0
			endif
			unot(i,j,k)=uVel(i,j,k)
			vnot(i,j,k)=vVel(i,j,k)
			wnot(i,j,k)=wVel(i,j,k)
			tnot(i,j,k)=temp_hyw(i,j,k)
			temperaturenot(i,j,k)=temperature(i,j,k)
			concentrationnot(i,j,k)=concentration(i,j,k)   
			fraclnot(i,j,k)=fracl(i,j,k)
		enddo
		enddo
		enddo

		call Cust_Out
		if(timet.gt.lasertime) ipoweroff=ipoweroff+1
		if(ipoweroff.eq.1) call PowerOff
	endif


	if(timet.lt.timax) goto 10


 	if(steady)then
		call output_steady_end
	endif

	call EndTime

	stop
	end


