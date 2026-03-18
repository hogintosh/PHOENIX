!______________________________________________________________________________
!
module laserinput
!______________________________________________________________________________
!
	use geometry
	use constant
	use initialization

	implicit none

	integer istart,imin,imax,jmin,jmax,kmin,kmax
	real(8) heatinLaser,peakhin,timet,beam_pos,absorpamplify

	contains   

	subroutine laser_beam


	integer i,j,iout,k

	real(8) xloc,rb2,varlas,xdist,dist2

	if(steady) beam_pos = xstart  
	
	if(.not.steady) then
	
		if(timet.le.lasertime)	then
			beam_pos = xstart - timet * scanvel  !+
		else 
			beam_pos = xstart - lasertime * scanvel !+
		endif
	
	endif	

	iout=0
	xloc=beam_pos
	do i=2,nim1
		if (xloc.le.x_hyw(i)) go to 701
		iout=i
	enddo
701	if(abs(xloc-x_hyw(iout+1)).lt.abs(xloc-x_hyw(iout))) iout=iout+1  
	istart=iout

	absorpamplify=1.0
	heatin=0.0
	heatinLaser=0.0
	rb2=alasrb**2
	varlas=alaspow*alaseta
	peakhin=alasfact*varlas/(pi*rb2)
	
	k=nk
	do i = 1,ni
		xdist=beam_pos-x_hyw(i)
		do j=1,nj
			dist2=xdist**2+y(j)**2
			if(fracl(i,j,nk).gt.0.0)absorpamplify=1.0 !(7E-05*temperature(i,j,k) + 0.249)/0.27
			heatin(i,j)=absorpamplify*peakhin*exp(-alasfact*dist2/rb2)*(concentration(i,j,k)*1.0+(1-concentration(i,j,k))*1.0)
!			varlas=(7E-05*temperature(i,j,k) + 0.249)*absorpamplify
			if(alasfact.lt.1.e-6.and.dist2.lt.rb2) heatin(i,j)=(concentration(i,j,k)*varlas*1.0+(1-concentration(i,j,k))*varlas)/(pi*rb2)
			! The factor 0.5 means the reflectivity of copper is much higher, or the absorbility is much lower.
			heatinLaser=heatinLaser+areaij(i,j)*heatin(i,j)
		enddo
	enddo

!----- output-------------------- 
!	write(*,601)varlas/2.0,heatinLaser
!601	format('  Laser power (supplied)  :',f9.3,1x'; Laser power (integrated):',f9.3,' J/s')

!------------------initial dimension of the pool---------------
	imin=istart-2  
	imax=istart+2
	jmin=njj-2
	jmax=njj-2
	kmin=nk-4
	kmax=nkm1



	return
end subroutine laser_beam

end module laserinput
