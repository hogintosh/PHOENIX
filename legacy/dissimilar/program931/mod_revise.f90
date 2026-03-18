!______________________________________________________________________________
!
module revision
!______________________________________________________________________________
!
	use initialization
	use parameters
	contains

	subroutine revision_p
	implicit none
	integer i,j,k
	real(8) tulc,tvlc,twlc

	goto (500,500,500,400,500)ivar

!********************************************************************
400	continue
	do k=kstat,nkm1
	do j=jstat,jend
	do i=istatp1,iendm1

		tulc=min(temp_hyw(i,j,k),temp_hyw(i-1,j,k))
		if(tulc.gt.tsolidmatrix(i,j,k))	uVel(i,j,k)=uVel(i,j,k)+dux(i,j,k)*(pp(i-1,j,k)-pp(i,j,k))

		tvlc=min(temp_hyw(i,j,k),temp_hyw(i,j-1,k))
		if(tvlc.gt.tsolidmatrix(i,j,k))	vVel(i,j,k)=vVel(i,j,k)+dvy(i,j,k)*(pp(i,j-1,k)-pp(i,j,k))

		twlc=min(temp_hyw(i,j,k),temp_hyw(i,j,k-1))
		if(twlc.gt.tsolidmatrix(i,j,k))	wVel(i,j,k)=wVel(i,j,k)+dwz(i,j,k)*(pp(i,j,k-1)-pp(i,j,k))
	enddo
	enddo
	enddo

!-------------------------
	do k=kstat,nkm1
	do j=jstat,jend
	do i=istatp1,iendm1
		if(temp_hyw(i,j,k).gt.tsolidmatrix(i,j,k)) then
			pressure(i,j,k)=pressure(i,j,k)+urfp*pp(i,j,k)
			pp(i,j,k)=0.0
		endif
	enddo
	enddo
	enddo
	return

!********************************************************************
500	return
	
end subroutine revision_p
end module revision
