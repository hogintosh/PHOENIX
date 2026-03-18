!______________________________________________________________________________
!
module dimensions
!______________________________________________________________________________
!
	use initialization
	use parameters
	use laserinput
	implicit none

	real(8) alen,depth,width,hpeak,tpeak,umax,vmax,wmax
	contains

subroutine pool_size
	
	integer i,j,k
	real(8) dtdxxinv,dtdzzinv,dtdyyinv,dep,wid,wid2 
	real(8) xxmax,xxmin
	tpeak=maxval(temp_hyw(1:ni,:,nk)) 
	if(tpeak.le.tsolidtemp) then
		alen=0.0
		depth=0.0
		width=0.0
	return
	endif
!-----length--------------------- 
	imax=istart
	imin=istart
	alen=0.0
	
	do i=nim1,istart,-1
	do j=2,njm1
	do k=2,nkm1
		if (temp_hyw(i,j,k).ge.tsolidtemp) goto 21
	enddo
	enddo
	enddo
21 imax=i	
	
	
	dtdxxinv = (x_hyw(imax)-x_hyw(imax+1))/(temp_hyw(imax,njj-1,nk)-temp_hyw(imax+1,njj-1,nk))
	xxmax = x_hyw(imax) !+ (tsolidtemp - temp_hyw(imax,njj-1,nk))*dtdxxinv  
    
	do i=2,istart
	do j=2,njm1
	do k=2,nkm1
		if (temp_hyw(i,j,k).ge.tsolidtemp) goto 22
	enddo
	enddo
	enddo
22 imin=i	
	
	dtdxxinv = (x_hyw(imin)-x_hyw(imin-1))/(temp_hyw(imin,njj-1,nk)-temp_hyw(imin-1,njj-1,nk))
	xxmin = x_hyw(imin) !+(tsolidtemp - temp_hyw(imin,njj-1,nk))*dtdxxinv
	alen=xxmax-xxmin

!-----depth--------------------- 
	kmin = nkm1
	depth = 0.0

	do k=1,nkm1
	
	do i=2,nim1
	do j=2,njm1
	if (temp_hyw(i,j,k).ge.tsolidtemp) goto 23
	enddo
	enddo
	enddo
23	kmin=k
	
    depth = z(nk)-z(kmin)
	kmax=nkm1

!-----width------------------------- 
	jmax = njj-1
	jmin=njj-1
	width = 0.0
	
	do j=2,njj-1	
	do k=1,nkm1	
	do i=2,nim1
	if (temp_hyw(i,j,k).ge.tsolidtemp) goto 24
	enddo
	enddo
	enddo
24	jmin=j
	
	do j=njm1,njj-1,-1	
	do k=1,nkm1	
	do i=2,nim1
	if (temp_hyw(i,j,k).ge.tsolidtemp) goto 25
	enddo
	enddo
	enddo
25	jmax=j



  width=y(jmax+1)-y(jmin-1)






!----- define solution domain for momentum equations----------------------------
102	istat=max(imin-3,2)
	jstat=max(jmin-3,2)
	kstat=max(kmin-2,2)
	iend=min(imax+3,nim1)
	jend=min(jmax+2,njm1)
	istatp1=istat+1  
	iendm1=iend-1
	
	if(istat.ge.iend.or.jstat.ge.jend.or.kstat.ge.nkm1) goto 101 
	return
101  istat=2
	jstat=2
	kstat=2
	iend=nim1
	jend=njm1
	istatp1=istat+1  
	iendm1=iend-1
	return

end subroutine pool_size
end module dimensions