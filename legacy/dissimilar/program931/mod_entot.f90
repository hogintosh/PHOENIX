!______________________________________________________________________________
!
module entotemp
!______________________________________________________________________________
!
	use initialization
	use parameters

	contains
	subroutine temperature_to_temp
	implicit none
	integer i,j,k ! special attention should be paid to this module.

	do k=1,nk
	do j=1,nj
	do i=1,ni
!	acp=677
!	acpl=677  
!	if(temp_hyw(i,j,k).le.1035.15)acp = 3E-06*temperature(i,j,k)**3 - 0.004*temperature(i,j,k)**2 + 2.439*temperature(i,j,k) + 36.85
 !   if(temp_hyw(i,j,k).gt.1035.15.and.temp_hyw(i,j,k).le.1273.15)acp = 0.013*temperature(i,j,k)**2 - 33.08*temperature(i,j,k)+ 20581


 !   acp2=763
 !   acpl2=763
 !   if(temp_hyw(i,j,k).le.1173.15)acp2 = - 0.372*temperature(i,j,k)+ 616.6

!	acp2=792
	!if(temp_hyw(i,j,k).le.1873.15)acp2=0.108*temperature(i,j,k) + 605.9
!	acp=0.152*(temp_hyw(i,j,k)-300)+500
!	acpl=acp
		if(temperature(i,j,k).ge.tvapmatrix(i,j,k))then 
!		diff(i,j,k)=10e6
		temperature(i,j,k)=tvapmatrix(i,j,k)
		endif
	temp_hyw(i,j,k)=temperature(i,j,k)
	acpacp(i,j,k)=acp*concentration(i,j,k)+acp2*(1-concentration(i,j,k))
		if(temperature(i,j,k).ge.tliquidmatrix(i,j,k)) then
			fracl(i,j,k)=1.0
		!	acplacpl(i,j,k)=acpl*concentration(i,j,k)+acpl2*(1-concentration(i,j,k))
			acpacp(i,j,k)=acpl*concentration(i,j,k)+acpl2*(1-concentration(i,j,k))
		elseif(temperature(i,j,k).le.tsolidmatrix(i,j,k)) then
			fracl(i,j,k)=0.0
		!	temp_hyw(i,j,k)=tsolid-(hsmelt-temperature(i,j,k))/acpacp(i,j,k)
		else
			fracl(i,j,k)=(temperature(i,j,k)-tsolidmatrix(i,j,k))/(tliquidmatrix(i,j,k)-tsolidmatrix(i,j,k))
			acpacp(i,j,k)=cpavg
		!	temp_hyw(i,j,k)=deltemp*fracl(i,j,k)+tsolid
		endif
	enddo
	enddo
	enddo
	
	return
end subroutine temperature_to_temp
end module entotemp
