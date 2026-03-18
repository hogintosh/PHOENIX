!______________________________________________________________________________
!
module property
!______________________________________________________________________________
!
	use initialization
	use parameters
	contains

subroutine properties
	implicit none
	integer i,j,k
	
	do k=1,nk
	do j=1,nj
	do i=1,ni
	dgdt(i,j,k)=dgdtp*concentration(i,j,k)+dgdtp2*(1-concentration(i,j,k))
    dgdc(i,j,k)=(dgconst-dgconst2) !*concentration(i,j,k)+(dgdtp2-dgdtp2)*temperature(i,j,k)
!	difsdifs(i,j,k)=thcons*concentration(i,j,k)+thcons2*(1-concentration(i,j,k))
!	difldifl(i,j,k)=thconl*concentration(i,j,k)+thconl2*(1-concentration(i,j,k))
!	difsdifs(i,j,k)=thconsthcons(i,j,k)
!	difldifl(i,j,k)=thconlthconl(i,j,k)
	tsolidmatrix(i,j,k)=tsolid*concentration(i,j,k)+tsolid2*(1-concentration(i,j,k))
	tliquidmatrix(i,j,k)=tliquid*concentration(i,j,k)+tliquid2*(1-concentration(i,j,k))
    tvapmatrix(i,j,k)=tvap*concentration(i,j,k)+tvap2*(1-concentration(i,j,k))
	hlatntmatrix(i,j,k)=hlatnt*concentration(i,j,k)+hlatnt2*(1-concentration(i,j,k))
	enddo
	enddo
	enddo	

	do k=1,nk
	do j=1,nj
	do i=1,ni
	
	    vis(i,j,k)=viscos*concentration(i,j,k)+viscos2*(1-concentration(i,j,k))	!	thcons=21
	!	thconl=30
	!	if(temp_hyw(i,j,k).le.1273.15)thcons = -0.019*temperature(i,j,k) + 44.43 
		thcons = 0.014633737*(temperature(i,j,k)-380.1) + 15.62 
		thconl = (0.014633737*(temperature(i,j,k)-380.1) + 15.62)*2.0
	!	thcons2= 0.017*temperature(i,j,k)+ 3.338
	!	thcons2=24
	!	thconl2=30
	!	if(temp_hyw(i,j,k).le.1173.15)thcons2= 0.017*temperature(i,j,k)+ 3.338

		diff(i,j,k)=thconl*concentration(i,j,k)+thconl2*(1-concentration(i,j,k))
		

		if(temp_hyw(i,j,k).ge.tsolidmatrix(i,j,k)) cycle

			diff(i,j,k)=thcons*concentration(i,j,k)+thcons2*(1-concentration(i,j,k))
			vis(i,j,k)=1.e10
		if(temp_hyw(i,j,k).le.tsolidmatrix(i,j,k)) cycle
			diff(i,j,k)=fracl(i,j,k)*(thconl*concentration(i,j,k)+thconl2*(1-concentration(i,j,k))) &
			+(1.0-fracl(i,j,k))*(thcons*concentration(i,j,k)+thcons2*(1-concentration(i,j,k)))
			vis(i,j,k)=viscos
		if(temp_hyw(i,j,k).ge.tvapmatrix(i,j,k))then 
		diff(i,j,k)=10e6
		temperature(i,j,k)=tvapmatrix(i,j,k)
		temp_hyw(i,j,k)=tvapmatrix(i,j,k)
		endif
	enddo
	enddo
	enddo
	return

end subroutine properties	
end module property

