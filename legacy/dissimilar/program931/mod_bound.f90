!______________________________________________________________________________
!
module boundary
!______________________________________________________________________________
!
	use initialization
	use parameters
	use laserinput
	implicit none
	contains 

subroutine bound_condition
	
!********************************************************************
	
	integer i,j,k
	real(8) dtdx,dtdy,term1,acptp,ctmp1,dtemp,htcbtm,tmp,dcdx,dcdy
	real(8) fraclu,fraclv
	real(8) hlossradia,hlossconvec		       
	real(8) visu1,visv1,ttemp1,ttemp2
if(half_hyw)then
	if(ivar.eq.2)then
	jstat=3
	else
	jstat=2
	endif
endif
!********************************************************************
	goto (100,200,300,400,500)ivar

!********************************************************************
100	continue

!-----k =nk 
	do j=jstat,jend
	do i=istatp1,iendm1
	ttemp1=temp_hyw(i,j,nk)
	ttemp2=temp_hyw(i-1,j,nk)
			if(ttemp1.ge.tvapmatrix(i,j,nk))ttemp1=tvapmatrix(i,j,nk)
		if(ttemp2.ge.tvapmatrix(i-1,j,nk))ttemp2=tvapmatrix(i-1,j,nk)
	
		dtdx = (ttemp1-ttemp2)*dxpwinv(i)
		dcdx = (concentration(i,j,nk)-concentration(i-1,j,nk))*dxpwinv(i)
		fraclu=fracl(i,j,nk)*(1.0-fracx(i-1))+fracl(i-1,j,nk)*fracx(i-1)
		visu1=vis(i,j,nkm1)*vis(i-1,j,nkm1)/(vis(i-1,j,nkm1)*(1.0-fracx(i-1))+vis(i,j,nkm1)*fracx(i-1))
		term1=fraclu/(visu1*dzpbinv(nk)) *(dgdt(i,j,nk)*dtdx+dgdc(i,j,nk)*dcdx)
		uVel(i,j,nk)=uVel(i,j,nkm1)+term1  
		dgdtdtdxu(i,j,nk)=dgdt(i,j,nk)*dtdx*fraclu
		dgdcdcdxu(i,j,nk)=dgdc(i,j,nk)*dcdx*fraclu
	enddo
	enddo

!----- in solid
	uVel(istat,jstat:jend,kstat:nkm1)=0.0
	uVel(iend,jstat:jend,kstat:nkm1)=0.0
	return

!********************************************************************
200	continue
!-----k=nk 
	do j=jstat,jend
	do i=istatp1,iendm1
		ttemp1=temp_hyw(i,j,nk)
	    ttemp2=temp_hyw(i,j-1,nk)	
		if(ttemp1.ge.tvapmatrix(i,j,nk))ttemp1=tvapmatrix(i,j,nk)
		if(ttemp2.ge.tvapmatrix(i,j-1,nk))ttemp2=tvapmatrix(i,j-1,nk)
		dtdy = (ttemp1-ttemp2)*dypsinv(j)
		dcdy = (concentration(i,j,nk)-concentration(i,j-1,nk))*dypsinv(j)
		fraclv=fracl(i,j,nk)*(1.0-fracy(j-1))+fracl(i,j-1,nk)*fracy(j-1)
		visv1=vis(i,j,nkm1)*vis(i,j-1,nkm1)/(vis(i,j-1,nkm1)*(1.0-fracy(j-1))+vis(i,j,nkm1)*fracy(j-1))
		term1=fraclv/(visv1*dzpbinv(nk))  *(dgdt(i,j,nk)*dtdy+dgdc(i,j,nk)*dcdy)
		vVel(i,j,nk)=vVel(i,j,nkm1)+term1
		dgdtdtdxv(i,j,nk)=dgdt(i,j,nk)*dtdy*fraclv
		dgdcdcdxv(i,j,nk)=dgdc(i,j,nk)*dcdy*fraclv
	enddo
	enddo

!-----in solid
	vVel(istat,jstat:jend,kstat:nkm1)=0.0
	vVel(iend,jstat:jend,kstat:nkm1)=0.0
	return

!********************************************************************
300	continue
!-----in solid
	wVel(istat,jstat:jend,kstat:nkm1)=0.0
	wVel(iend,jstat:jend,kstat:nkm1)=0.0
	return

!********************************************************************
400	continue
!----- pp velocities in solid
	pp(istat,jstat:jend,kstat:nkm1)=0.0  
	pp(iend,jstat:jend,kstat:nkm1)=0.0
	return

!********************************************************************
500	continue

!-----k=nk 
	
	ahtoploss=0.0

	do j=2,njm1
	do i=2,nim1
		hlossradia=emiss*sigm*(temp_hyw(i,j,nk)**4-tempAmb**4)  
		hlossconvec=htcn1*(temp_hyw(i,j,nk)-tempAmb)
		ctmp1=diff(i,j,nkm1)*dzpbinv(nk)	
		temperature(i,j,nk)=temperature(i,j,nkm1)+(heatin(i,j)-vap_heatloss(i,j)-hlossradia-hlossradia)/ctmp1
		ahtoploss=ahtoploss+(hlossradia+hlossradia+vap_heatloss(i,j))*areaij(i,j)
	enddo
	enddo

!-----k=1 

	do j=2,njm1
	do i=2,nim1
		hlossconvec=htck1*(temp_hyw(i,j,1)-tempAmb)	
		ctmp1=diff(i,j,2)*dzpbinv(2)
		temperature(i,j,1)=temperature(i,j,2)-hlossconvec/ctmp1
	enddo
	enddo

!-----j=1 
if(steady)then
	temperature(ni,:,:)=temperature(ni-1,:,:)
	temperature(1,:,:)=temperature(2,:,:)
else
	temperature(ni,:,:)=temperature(ni-1,:,:)
	temperature(1,:,:)=temperature(2,:,:)
endif
if(half_hyw)then	
	temperature(:,1,:)=temperature(:,2,:)
else	
	temperature(:,nj,:)=temperature(:,nj-1,:)
	temperature(:,1,:)=temperature(:,2,:)
endif
	return

	return
end subroutine bound_condition
end module boundary
