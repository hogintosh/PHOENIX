!______________________________________________________________________________
!
module solver
!______________________________________________________________________________
!
	use initialization
	use parameters
!	use Variables
	contains

	subroutine solution_uvw
	
	implicit none
	integer i,j,k,ksweep,jsweep
	real(8) d,denom
	!real(8) pr,qr,d,denom
!dimension pr(nx),qr(nx)
    DOUBLE PRECISION,DIMENSION(:), ALLOCATABLE ::pr,qr
	allocate(pr(nx),qr(nx))

!********************************************************************
	do ksweep=1,2
	do k=nkm1,kstat,-1
	do jsweep=1,2
	do j=jstat,jend
		i=istat
		pr(i)=0.0
		qr(i)=phi_hyw(i,j,k,ivar)

		do i=istatp1,iendm1
			d = at(i,j,k)*phi_hyw(i,j,k+1,ivar)+ab(i,j,k)*phi_hyw(i,j,k-1,ivar)+an(i,j,k)*phi_hyw(i,j+1,k,ivar) &
				+as(i,j,k)*phi_hyw(i,j-1,k,ivar)+su(i,j,k)
			denom=ap(i,j,k)-aw(i,j,k)*pr(i-1)
			pr(i)=ae(i,j,k)/denom
			qr(i)=(d+aw(i,j,k)*qr(i-1))/denom
		enddo
!-----back---------------- 
		do i=iendm1, istatp1, -1
			phi_hyw(i,j,k,ivar)=pr(i)*phi_hyw(i+1,j,k,ivar)+qr(i)
		enddo
	enddo
	enddo
	enddo
	enddo
	deallocate(pr,qr)
	return
end subroutine solution_uvw
!********************************************************************
subroutine solution_temperature

!-----TDMA

	implicit none
	integer i,j,k,ksweep,jsweep
	real(8) d,denom
	!real(8) pr,qr,d,denom
!dimension pr(nx),qr(nx)
    DOUBLE PRECISION,DIMENSION(:), ALLOCATABLE ::pr,qr
	allocate(pr(nx),qr(nx))

	do ksweep=1,2
	do k=nkm1,2,-1
	do jsweep=1,2
	do j=2,njm1
		pr(1)=0.0
		qr(1)=temperature(1,j,k)
		do i=2,nim1
			d = at(i,j,k)*temperature(i,j,k+1)+ab(i,j,k)*temperature(i,j,k-1)+an(i,j,k)*temperature(i,j+1,k)+ &
				as(i,j,k)*temperature(i,j-1,k)+su(i,j,k)
			denom=ap(i,j,k)-aw(i,j,k)*pr(i-1)
			pr(i)=ae(i,j,k)/denom
			qr(i)=(d+aw(i,j,k)*qr(i-1))/denom
		enddo

!-----back 
		do i=nim1,2,-1
			temperature(i,j,k)=pr(i)*temperature(i+1,j,k)+qr(i)
		enddo
	enddo
	enddo
	enddo
	enddo
	deallocate(pr,qr)
	return
end subroutine solution_temperature


subroutine cleanuvw

	implicit none
	integer i,j,k
	real(8) tulc,tvlc,twlc

	do k=kstat,nkm1
	do j=jstat,jend
	do i=istatp1,iendm1
		tulc=min(temp_hyw(i,j,k),temp_hyw(i+1,j,k))
		tvlc=min(temp_hyw(i,j,k),temp_hyw(i,j+1,k))
		twlc=min(temp_hyw(i,j,k),temp_hyw(i,j,k+1))
		if(tulc.le.tsolidmatrix(i,j,k)) uVel(i+1,j,k)=0.0
		if(tvlc.le.tsolidmatrix(i,j,k)) vVel(i,j+1,k)=0.0
		if(twlc.le.tsolidmatrix(i,j,k)) wVel(i,j,k+1)=0.0
	!	if(lv(i,j,k))nktemp=k
	enddo
	enddo
	enddo
!	temperature(:,:,nktemp+1:nk)=298.0  !(lv(i,j,k)
	return

end subroutine cleanuvw

end module