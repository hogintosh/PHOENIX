!______________________________________________________________________________
!
module source
!______________________________________________________________________________
!
	use geometry
	use initialization
	use parameters

	implicit none
	contains

	subroutine source_term
	
	integer i,j,k
	real(8) fraclu,fraclv,fraclw,tw,variable1,volht,twc
	real(8) term,term1,term3
	real(8) tulc,tvlc,twlc
	real(8) flew,flns,fltb

	go to (100,200,300,400,500) ivar

!*********************************************************************
100	continue
	do k=kstat,nkm1
	do j=jstat,jend
	do i=istatp1,iendm1
		fraclu=fracl(i,j,k)*(1.0-fracx(i-1))+fracl(i-1,j,k)*fracx(i-1)
		if(fraclu.gt.0) then
!------mushy zone--------
			term=1.6e4*(1.0-fraclu)**2/(fraclu**3+small)  
			sp(i,j,k)=sp(i,j,k)-term*volume_u(i,j,k)
!-----scanning velocity
			term1 = rhoscan*areajk(j,k)*(uVel(i-1,j,k)-uVel(i,j,k))
			su(i,j,k)=su(i,j,k)+term1
		endif
	enddo
	enddo
	enddo

!-----k=nk ------
	do j=jstat,jend
	do i=istatp1,iendm1
		su(i,j,nkm1)=su(i,j,nkm1)+at(i,j,nkm1)*uVel(i,j,nk)
		sp(i,j,nkm1)=sp(i,j,nkm1)-at(i,j,nkm1)
		at(i,j,nkm1)=0.0
	enddo
	enddo 

!-----j=1 ------
	do k=kstat,nkm1
	do i=istatp1,iendm1
		uVel(i,1,k)=uVel(i,2,k)
		su(i,2,k)=su(i,2,k)+as(i,2,k)*uVel(i,1,k)
		sp(i,2,k)=sp(i,2,k)-as(i,2,k)
		as(i,2,k)=0.0
	enddo
	enddo

!-------------------------------------
	do k=kstat,nkm1
	do j=jstat,jend
	do i=istatp1,iendm1
		ap(i,j,k)=an(i,j,k)+as(i,j,k)+ae(i,j,k)+aw(i,j,k)+at(i,j,k)+ab(i,j,k)+apnot(i,j,k)-sp(i,j,k)
		dux(i,j,k)=areajk(j,k)/ap(i,j,k) 

!-----under-relaxation
		ap(i,j,k)=ap(i,j,k)/urfu
		su(i,j,k)=su(i,j,k)+(1.-urfu)*ap(i,j,k)*uVel(i,j,k)
		dux(i,j,k)=dux(i,j,k)*urfu

!------zero velocity-------
		tulc=min(temp_hyw(i,j,k),temp_hyw(i-1,j,k))
		if(tulc.le.tsolidmatrix(i,j,k)) then
			su(i,j,k)=0.0
			an(i,j,k)=0.0
			as(i,j,k)=0.0
			ae(i,j,k)=0.0
			aw(i,j,k)=0.0
			at(i,j,k)=0.0
			ab(i,j,k)=0.0
			ap(i,j,k)=great  
		endif
	enddo
	enddo
	enddo

	return

!*********************************************************************
200	continue
	do k=kstat,nkm1
	do j=jstat,jend
	do i=istatp1,iendm1
		fraclv=fracl(i,j,k)*(1.0-fracy(j-1))+fracl(i,j-1,k)*fracy(j-1)
		if(fraclv.gt.0) then

!------mushy zone--------------------
			term=1.6e4*(1.0-fraclv)**2/(fraclv**3+small)
			sp(i,j,k)=sp(i,j,k)-term*volume_v(i,j,k)

!-----scanning velocity!------------------
			term1 = rhoscan*areavjk(j,k)*(vVel(i-1,j,k)-vVel(i,j,k))
			su(i,j,k)=su(i,j,k)+term1
		endif
	enddo
	enddo
	enddo

!---k=nk---------
	do j=jstat,jend
	do i=istatp1,iendm1
		su(i,j,nkm1)=su(i,j,nkm1)+at(i,j,nkm1)*vVel(i,j,nk)
		sp(i,j,nkm1)=sp(i,j,nkm1)-at(i,j,nkm1)
		at(i,j,nkm1)=0.0
	enddo
	enddo 

!-----------------------------------
	do k=kstat,nkm1
	do j=jstat,jend
	do i=istatp1,iendm1
		ap(i,j,k)=an(i,j,k)+as(i,j,k)+ae(i,j,k)+aw(i,j,k)+at(i,j,k)+ab(i,j,k)+apnot(i,j,k)-sp(i,j,k)
		dvy(i,j,k)=areaik(i,k)/ap(i,j,k)

!-----under-relaxation--------
		ap(i,j,k)=ap(i,j,k)/urfv
		su(i,j,k)=su(i,j,k)+(1.-urfv)*ap(i,j,k)*vVel(i,j,k)
		dvy(i,j,k)=dvy(i,j,k)*urfv 

!------zero velocity ------------
		tvlc=min(temp_hyw(i,j,k),temp_hyw(i,j-1,k))
		if(tvlc.le.tsolidmatrix(i,j,k)) then
			su(i,j,k)=0.0
			an(i,j,k)=0.0
			as(i,j,k)=0.0
			ae(i,j,k)=0.0
			aw(i,j,k)=0.0
			at(i,j,k)=0.0
			ab(i,j,k)=0.0
			ap(i,j,k)=great
		endif
	enddo
	enddo
	enddo

	return

!********************************************************************
300	continue
	do k=kstat,nkm1
	do j=jstat,jend
	do i=istatp1,iendm1
		fraclw=fracl(i,j,k)*(1.0-fracz(k-1))+fracl(i,j,k-1)*fracz(k-1)
		if(fraclw.gt.0) then

!------mushy zone----------------
			term=1.6e4*(1.0-fraclw)**2/(fraclw**3+small)
			sp(i,j,k)=sp(i,j,k)-term*volume_w(i,j,k)

!-----scanning velocity------------
			term1 = rhoscan*areawjk(j,k)*(wVel(i-1,j,k)-wVel(i,j,k))
			su(i,j,k)=su(i,j,k)+term1

!-----buoyancy----------------
			tw=temp_hyw(i,j,k)*(1.0-fracz(k-1))+temp_hyw(i,j,k-1)*fracz(k-1)
			twc=concentration(i,j,k)*(1.0-fracz(k-1))+concentration(i,j,k-1)*fracz(k-1)
			su(i,j,k) = su(i,j,k)+boufac*volume_w(i,j,k)*(tw-tsolidmatrix(i,j,k)) &
			+boufacc*volume_w(i,j,k)*(1.0-concentration(i,j,k))
              
		endif

	enddo
	enddo
	enddo

!-----j=1------------
	do k=kstat,nkm1
	do i=istatp1,iendm1
		wVel(i,1,k)=wVel(i,2,k)
		su(i,2,k)=su(i,2,k)+as(i,2,k)*wVel(i,1,k)
		sp(i,2,k)=sp(i,2,k)-as(i,2,k)
		as(i,2,k)=0.0
	enddo
	enddo

!-----------------------------------
	do k=kstat,nkm1
	do j=jstat,jend
	do i=istatp1,iendm1
		ap(i,j,k)=an(i,j,k)+as(i,j,k)+ae(i,j,k)+aw(i,j,k)+at(i,j,k)+ab(i,j,k)+apnot(i,j,k)-sp(i,j,k)
		dwz(i,j,k)=areaij(i,j)/ap(i,j,k)

!-----under-relaxation--------------
		ap(i,j,k)=ap(i,j,k)/urfw
		su(i,j,k)=su(i,j,k)+(1.-urfw)*ap(i,j,k)*wVel(i,j,k)
		dwz(i,j,k)=dwz(i,j,k)*urfw

!------zero velocity---------
		twlc=min(temp_hyw(i,j,k),temp_hyw(i,j,k-1))
		if(twlc.le.tsolidmatrix(i,j,k)) then
			su(i,j,k)=0.0
			an(i,j,k)=0.0
			as(i,j,k)=0.0
			ae(i,j,k)=0.0
			aw(i,j,k)=0.0
			at(i,j,k)=0.0
			ab(i,j,k)=0.0
			ap(i,j,k)=great
		endif
	enddo
	enddo
	enddo

	return

!********************************************************************
400	continue

	do k=kstat,nkm1
	do j=jstat,jend
	do i=istatp1,iendm1
		ap(i,j,k)=an(i,j,k)+as(i,j,k)+ae(i,j,k)+aw(i,j,k)+at(i,j,k)+ab(i,j,k)-sp(i,j,k)
		if(temp_hyw(i,j,k).le.tsolidmatrix(i,j,k))then
			su(i,j,k)=0.0
			ap(i,j,k)=great
			an(i,j,k)=0.0
			as(i,j,k)=0.0
			ae(i,j,k)=0.0
			aw(i,j,k)=0.0
			at(i,j,k)=0.0
			ab(i,j,k)=0.0
		endif
	enddo
	enddo
	enddo

	return

!********************************************************************
500	continue

!-----source term------
	if(scanvel.gt.small)then
		do k=2,nkm1
		do j=2,njm1
			term1=areajk(j,k)*rhoscan
			do i=2,nim1
				su(i,j,k)=su(i,j,k)+acpacp(i,j,k)*temperature(i-1,j,k)*term1
				sp(i,j,k)=sp(i,j,k)-acpacp(i,j,k)*term1
				term3=rhoscan*hlatntmatrix(i,j,k)*areajk(j,k)*(fracl(i-1,j,k)-fracl(i,j,k))
				su(i,j,k)=su(i,j,k)+term3
			enddo
		enddo
		enddo
	endif

	variable1=dens/delt
	do k=2,nkm1
	do j=2,njm1
	do i=2,nim1
		volht=volume(i,j,k)*variable1*hlatntmatrix(i,j,k)
		su(i,j,k)=su(i,j,k)-volht*(fracl(i,j,k)-fraclnot(i,j,k))
		flew=areajk(j,k)*(max(uVel(i,j,k),0.0)*fracl(i-1,j,k)-max(-uVel(i,j,k),0.0)*fracl(i,j,k) &
			+max(-uVel(i+1,j,k),0.0)*fracl(i+1,j,k)-max(uVel(i+1,j,k),0.0)*fracl(i,j,k))
		flns=areaik(i,k)*(max(vVel(i,j,k),0.0)*fracl(i,j-1,k)-max(-vVel(i,j,k),0.0)*fracl(i,j,k)  &
			+max(-vVel(i,j+1,k),0.0)*fracl(i,j+1,k)-max(vVel(i,j+1,k),0.0)*fracl(i,j,k))
		fltb=areaij(i,j)*(max(wVel(i,j,k),0.0)*fracl(i,j,k-1)-max(-wVel(i,j,k),0.0)*fracl(i,j,k) &
			+max(-wVel(i,j,k+1),0.0)*fracl(i,j,k+1)-max(wVel(i,j,k+1),0.0)*fracl(i,j,k))
		su(i,j,k)=su(i,j,k)+dens*hlatntmatrix(i,j,k)*(flew+flns+fltb)
	enddo
	enddo
	enddo

!----- k=nk & k=1 ------
	do j=2,njm1
	do i=2,nim1
		su(i,j,2)=su(i,j,2)+ab(i,j,2)*temperature(i,j,1)
		sp(i,j,2)=sp(i,j,2)-ab(i,j,2)
		ab(i,j,2)=0.0
		su(i,j,nkm1)=su(i,j,nkm1)+at(i,j,nkm1)*temperature(i,j,nk)
		sp(i,j,nkm1)=sp(i,j,nkm1)-at(i,j,nkm1)
		at(i,j,nkm1)=0.0
	enddo
	enddo

!----- j=1 & j=nj ------
	do k=2,nkm1
	do i=2,nim1
		su(i,2,k)=su(i,2,k)+as(i,2,k)*temperature(i,1,k)
		sp(i,2,k)=sp(i,2,k)-as(i,2,k)
		as(i,2,k)=0.0
		su(i,njm1,k)=su(i,njm1,k)+an(i,njm1,k)*temperature(i,nj,k)
		sp(i,njm1,k)=sp(i,njm1,k)-an(i,njm1,k)
		an(i,njm1,k)=0.0
	enddo
	enddo

!----- i=1 & i=ni---
	do k=2,nkm1
	do j=2,njm1
		su(2,j,k)=su(2,j,k)+aw(2,j,k)*temperature(1,j,k)
		sp(2,j,k)=sp(2,j,k)-aw(2,j,k)
		aw(2,j,k)=0.0
		su(nim1,j,k)=su(nim1,j,k)+ae(nim1,j,k)*temperature(ni,j,k)
		sp(nim1,j,k)=sp(nim1,j,k)-ae(nim1,j,k)
		ae(nim1,j,k)=0.0
	enddo
	enddo

	do k=2,nkm1
	do j=2,njm1
	do i=2,nim1
		ap(i,j,k)=an(i,j,k)+as(i,j,k)+ae(i,j,k)+aw(i,j,k)+at(i,j,k)+ab(i,j,k)+apnot(i,j,k)-sp(i,j,k)  

!-----under-relaxation---
		ap(i,j,k)=ap(i,j,k)/urfh
		su(i,j,k)=su(i,j,k)+(1.-urfh)*ap(i,j,k)*temperature(i,j,k)
	enddo
	enddo
	enddo

	return
end subroutine source_term
end module source