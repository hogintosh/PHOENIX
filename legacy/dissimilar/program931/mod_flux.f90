!______________________________________________________________________________
!
module fluxes
!______________________________________________________________________________
!
	use initialization
	use parameters
	use laserinput

	implicit none
	real(8) heatout,flux_west,flux_east,flux_top,flux_bottom,flux_north,flux_south,accul,ratio
	contains
	
subroutine heat_fluxes

	integer i,j,k
	real(8) fluxi1,fluxl1,fluxk1,fluxn1,fluxm1,fluxj1,dh1
		

!********************************************************************
!-----i=1 & i=ni-----
	flux_west=0.0
	flux_east=0.0
	do k=2,nkm1
	do j=2,njm1
		fluxi1=diff(2,j,k)*(temperature(1,j,k)-temperature(2,j,k))*dxpwinv(2)
		fluxl1=diff(nim1,j,k)*(temperature(ni,j,k)-temperature(nim1,j,k))*dxpwinv(ni)
!----- laser beam velocity----
		flux_west=flux_west+areajk(j,k)*(fluxi1+acpacp(1,j,k)*rhoscan*temperature(1,j,k))
		flux_east=flux_east+areajk(j,k)*(fluxl1-acpacp(nim1,j,k)*rhoscan*temperature(nim1,j,k))
	enddo
	enddo

!********************************************************************
!-----k=nk and k=1------------
	flux_bottom=0.0
	flux_top=0.0
	do j=2,njm1
	do i=2,nim1
		fluxk1=diff(i,j,2)*(temperature(i,j,1)-temperature(i,j,2))*dzpbinv(2)
		fluxn1=diff(i,j,nkm1)*(temperature(i,j,nk)-temperature(i,j,nkm1))*dzpbinv(nk)
		flux_bottom=flux_bottom+areaij(i,j)*fluxk1
		flux_top=flux_top+areaij(i,j)*fluxn1
	enddo
	enddo

!********************************************************************
!-----j=1 and j=nj--------
	flux_north=0.0
	flux_south=0.0
	do k=2,nkm1
	do i=2,nim1
		fluxm1=diff(i,njm1,k)*(temperature(i,nj,k)-temperature(i,njm1,k))*dypsinv(nj)
		fluxj1=diff(i,2,k)*(temperature(i,1,k)-temperature(i,2,k))*dypsinv(2)
		flux_south=flux_south+areaik(i,k)*fluxj1
		flux_north=flux_north+areaik(i,k)*fluxm1
	enddo
	enddo

!********************************************************************
!-----heat accumulation--------
	if(.not.steady) then
		accul=0.0
		do k=2,nkm1
		do j=2,njm1
		do i=2,nim1
			dh1=acpacp(i,j,k)*(temperature(i,j,k)-temperaturenot(i,j,k))+(fracl(i,j,k)-fraclnot(i,j,k))*hlatnt
			accul=accul+volume(i,j,k)*dens*dh1/delt
		enddo
		enddo
		enddo
	endif

!********************************************************************
	heatout=flux_north+flux_bottom+flux_west+flux_east+flux_south-ahtoploss
	if(steady) then
		ratio=-heatout/heatinLaser
	else
		ratio=accul/(heatinLaser+heatout+small)
	endif
	return
end subroutine heat_fluxes
end module fluxes
