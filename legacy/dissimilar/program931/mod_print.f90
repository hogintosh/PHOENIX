!______________________________________________________________________________
!
module printing
!______________________________________________________________________________
!
	use dimensions
	use geometry
	use initialization
	use residue
	use fluxes
	use parameters
	use laserinput
	
	implicit none
	integer itertot,niter,nii  !main

	real(8) aAveSec
	integer, private:: i,j,k,ist
	integer, private:: itimestart,itimeend
	dimension iTimeStart(8),iTimeEnd(8)
	real(8) data_and_time,adtdys,area
    logical tempout
	contains

!********************************************************************
subroutine StartTime
    tempout=.true.
	call date_and_time(values = iTimeStart)
	write(6,800)iTimeStart(1:3),iTimeStart(5:7)
	write(9,800)iTimeStart(1:3),iTimeStart(5:7)
800	format(2x,'Date: ',I4,'-',I2,'-',I2,2x,'time: ',2(I2,' :'),I2,/)
end subroutine StartTime

!********************************************************************
subroutine outputres
	if(tpeak.gt.tsolidtemp) then
		umax=maxval(abs(uVel(istatp1:iendm1,jstat:jend,kstat:nk)))
		vmax=maxval(abs(vVel(istatp1:iendm1,jstat:jend,kstat:nk)))
		wmax=maxval(abs(wVel(istatp1:iendm1,jstat:jend,kstat:nk)))
	else
		umax=0.0
		vmax=0.0
		wmax=0.0
	endif

	if(steady)then
		write(9,7)niter,aAveSec,resorh,resorm,resoru,resorv,resorw
		write(9,*)"res_species"
		write(9,"(e8.1)") resorc        
		write(9,4)tpeak,umax,vmax,wmax,alen,depth,width
		write(9,9)flux_north,flux_south,flux_top,ahtoploss,flux_bottom,flux_west,flux_east,heatout,heatinLaser,ratio
		write(6,7)niter,aAveSec,resorh,resorm,resoru,resorv,resorw
		write(6,*)"res_species"
		write(6,"(e8.1)") resorc        
		write(6,4)tpeak,umax,vmax,wmax,alen,depth,width
		write(6,9)flux_north,flux_south,flux_top,ahtoploss,flux_bottom,flux_west,flux_east,heatout,heatinLaser,ratio

4		format('  Tmax        umax       vmax       wmax      length      depth    width',/, &
			f9.2,2x,3(f9.3,2x),3(1p(e9.2),3x))
7		format('  iter    time/iter    res_enth    res_mass     res_u      res_v      res_w',/, &
			1x,i5,4x,f7.3,6x,(5(1p(e8.2),4x)))
9		format('  north  south  top   toploss  bottom   east    west      hout     hin    ratio',/, &
			5(f7.1),1x,2(f7.1),1x,2(f7.1,1x),f7.2,/)
	else

		write(9,3)timet,niter,aAveSec,itertot,resorh,resorm,resoru,resorv,resorw 
		write(9,*) "res_species"
		write(9,"(e8.1)") resorc        
		write(9,5)tpeak,umax,vmax,wmax,alen,depth,width
		write(9,2)flux_north,flux_south,flux_top,ahtoploss,flux_bottom,flux_west,flux_east,heatout,accul,heatinLaser,ratio
		write(6,3)timet,niter,aAveSec,itertot,resorh,resorm,resoru,resorv,resorw 
		write(6,*) "res_species"
		write(6,"(e8.1)") resorc        
		write(6,5)tpeak,umax,vmax,wmax,alen,depth,width
		write(6,2)flux_north,flux_south,flux_top,ahtoploss,flux_bottom,flux_west,flux_east,heatout,accul,heatinLaser,ratio

3		format('  time  iter  time/iter  tot_iter  res_enth  res_mass   res_u   res_v   res_w',/, & 
		1p(e8.1),1x,i4,2x,0pf7.3,3x,i7,2x,1p(e8.1),2x,1p(e8.1),1x,(3(1p(e8.1),1x)))  
2		format('  north  south   top  toploss  bottom  east   west   hout   accu   hin   ratio',/, &
		3(f7.1),1x,4(f7.1),3(f7.1),f7.2,/)
5		format('  Tmax        umax       vmax       wmax      length      depth    width',/, &
		f9.2,2x,3(1p(e8.2),3x),3(1p(e8.2),3x))
	endif
end subroutine outputres

!********************************************************************
subroutine tec_out
!-----velocities at scalar nodes--------

	do i=2,nim1
	do j=2,njm1
	do k=2,nkm1
		auvl(i,j,k)=(uVel(i,j,k)+uVel(i+1,j,k))*0.5
		avvl(i,j,k)=(vVel(i,j,k)+vVel(i,j+1,k))*0.5
		awvl(i,j,k)=(wVel(i,j,k)+wVel(i,j,k+1))*0.5
		if(temp_hyw(i,j,k).le.tsolidmatrix(i,j,k)) then
			auvl(i,j,k)=0.0
			avvl(i,j,k)=0.0
			awvl(i,j,k)=0.0
		endif
	enddo
	enddo
	enddo
 
!-----top plane--------
	do i=2,nim1
	do j=2,njm1
		auvl(i,j,nk)=(uVel(i,j,nk)+uVel(i+1,j,nk))*0.5
		avvl(i,j,nk)=(vVel(i,j,nk)+vVel(i,j+1,nk))*0.5
		if(temp_hyw(i,j,nk).le.tsolidmatrix(i,j,k)) then
			auvl(i,j,nk)=0.0
			avvl(i,j,nk)=0.0
		endif
	enddo
	enddo

!-----symmetry plane
	do i=2,nim1
	do k=2,nkm1
		auvl(i,1,k)=(uVel(i,1,k)+uVel(i+1,1,k))*0.5
		awvl(i,1,k)=(wVel(i,1,k)+wVel(i,1,k+1))*0.5
		if(temp_hyw(i,1,k).le.tsolidmatrix(i,1,k)) then
			auvl(i,1,k)=0.0
			awvl(i,1,k)=0.0
		endif
	enddo
	enddo

!-----left plane---------
	do j=2,njm1
	do k=2,nkm1
		avvl(1,j,k)=(vVel(1,j,k)+vVel(1,j+1,k))*0.5
		awvl(1,j,k)=(wVel(1,j,k)+wVel(1,j,k+1))*0.5
		if(temp_hyw(1,j,k).le.tsolidmatrix(1,j,k)) then
			avvl(1,j,k)=0.0
			awvl(1,j,k)=0.0
		endif
	enddo
	enddo

	open(unit=91,file='./result/tecout.plt')
	write(91,*) 'TITLE = "FLUID FLOW AND HEAT TRANSFER IN WELD POOL"'
	write(91,*)'VARIABLES = "x", "Y", "Z", "U", "V", "W","T","C","fracl","tu","tv","cu","cv" '
	write(91,*)'ZONE I=',ni,'J=',nj,'K=',nk,'F=POINT'
	do k=1,nk
	do j=1,nj
	do i=1,ni
		write(91,111) x_hyw(i),y(j),z(k),auvl(i,j,k),avvl(i,j,k),awvl(i,j,k),temp_hyw(i,j,k),concentration(i,j,k),fracl(i,j,k),dgdtdtdxu(i,j,k),dgdtdtdxv(i,j,k),dgdcdcdxu(i,j,k),dgdcdcdxv(i,j,k)
	enddo
	enddo
	enddo
111	format(13(e14.4))
	close(91)
end subroutine tec_out

!********************************************************************
subroutine final_out
	write(9,124)
124	format('  Some important calculated parameters at the end of heating cycle',/)
	write(9,125) alen
125	format('  Length of the pool     (cm)             ',1p(e14.4))
	write(9,112) depth
112	format('  Depth of the pool      (cm)             ',1p(e14.4))
	write(9,113) width
113	format('  width of the pool (cm)             ',1p(e14.4))
	write(9,114) tpeak
114	format('  Peak temperature       (K)              ',1p(e14.4))
	write(9,115) umax
115	format('  Maximum u-velocity     (cm/s)           ',1p(e14.4))
	write(9,116) vmax
116	format('  Maximum v-velocity     (cm/s)           ',1p(e14.4))
	write(9,117) wmax
117	format('  Maximum w-velocity     (cm/s)           ',1p(e14.4))
	write(9,118) heatinLaser
118	format('  Rate of heat input     (cal/s)          ',1p(e14.4))
	write(9,119) heatout
119	format('  Rate of heat output    (cal/s)          ',1p(e14.4))
	write(9,120) ratio
120	format('  Ratio of heat input to heat output      ',1p(e14.4),/)
end subroutine final_out


!********************************************************************
subroutine Cust_Out

!----- save thermal cycle------------
	write(40,806)timet,temp_hyw(istart,1,1),temp_hyw(istart,54,nk),temp_hyw(istart,1,26),temp_hyw(istart,1,18), &
		temp_hyw(istart,5,nk),temp_hyw(istart,9,nk),temp_hyw(istart,12,nk),temp_hyw(istart,15,nk)
806	format(F7.4,8E13.4)

!----temperature and velocity fields at top (xy) and cross (xz) planes------------

	if(timet.lt.lasertime.or.tpeak.lt.tsolidtemp)	then
!		if(timet.lt.tmMovOut)	return
		tmMovOut=tmMovOut+1
		vapprintc=vapprintc+1
		if(mod(tmMovOut,deltmMov).ge.1)	return
	endif
if(timet.ge.0.2.and.tempout)then
call tec_out
tempout=.false.
endif
!-----top plane------------
	do i=2,nim1
	do j=2,njm1
		auvl(i,j,nk)=(uVel(i,j,nk)+uVel(i+1,j,nk))*0.5
		avvl(i,j,nk)=(vVel(i,j,nk)+vVel(i,j+1,nk))*0.5
		if(temp_hyw(i,j,nk).le.tsolidmatrix(i,j,nk)) then
			auvl(i,j,nk)=0.0
			avvl(i,j,nk)=0.0
		endif
	enddo
	enddo
	
nii=0
do nii=1,nim1
	if(.not.steady) then
	
		if(timet.le.lasertime)	then
			if(x_hyw(nii).ge.(xstart - timet * scanvel))exit  !+
		else 
			if(x_hyw(nii).ge.(xstart - lasertime * scanvel))exit !+
		endif
	endif	
	if(steady.and.x_hyw(nii).ge.xstart)exit

enddo


!-----cross plane------------
	do j=2,njm1
	do k=2,nkm1
		avvl(nii,j,k)=(vVel(nii,j,k)+vVel(nii,j+1,k))*0.5
		awvl(nii,j,k)=(wVel(nii,j,k)+wVel(nii,j,k+1))*0.5
		if(temp_hyw(nii,j,k).le.tsolidmatrix(nii,j,k)) then
			avvl(nii,j,k)=0.0
			awvl(nii,j,k)=0.0
		endif
	enddo
	enddo


	k=nk
	write(41,410)timet, ni, nj, 1
410	format('ZONE T = "XY ', F6.4,'" I=',I4,' J=',I4,' K=', I4,' F=POINT') !F6.2
	write(41,420)timet
420	format('STRANDID = 1,SOLUTIONTIME =',e14.4) !F6.2
	do j=1,nj
	do i=1,ni
		write(41,111) x_hyw(i),y(j),auvl(i,j,k),avvl(i,j,k),temp_hyw(i,j,k),concentration(i,j,k),fracl(i,j,k),dgdtdtdxu(i,j,k),dgdtdtdxv(i,j,k),dgdcdcdxu(i,j,k),dgdcdcdxv(i,j,k)
	enddo
	enddo

	i=nii
	write(42,412)timet, 1, nj, nk
412	format('ZONE T = "YZ ', F6.4,'" I=',I4,' J=',I4,' K=', I4,' F=POINT')
	write(42,422)timet
422	format('STRANDID=1,SOLUTIONTIME=', e14.4) !F6.2
	do k=1,nk
	do j=1,nj
		write(42,111) y(j),z(k),avvl(i,j,k),awvl(i,j,k),temp_hyw(i,j,k),concentration(i,j,k),fracl(i,j,k),dgdtdtdxu(i,j,k),dgdtdtdxv(i,j,k),dgdcdcdxu(i,j,k),dgdcdcdxv(i,j,k)
111		format(11(e14.4))
	enddo
	enddo
!-----sys plane------------
do j=1,nj
if(y(j).ge.0.0)exit
enddo
njj=j
if(half_hyw)njj=2
	do i=2,nim1
	do k=2,nkm1
		auvl(i,njj-1,k)=(uVel(i,njj-1,k)+uVel(i+1,njj-1,k))*0.5
		awvl(i,njj-1,k)=(wVel(i,njj-1,k)+wVel(i,njj-1,k+1))*0.5
		if(temp_hyw(i,njj-1,k).le.tsolidmatrix(i,njj-1,k)) then
			auvl(i,njj-1,k)=0.0
			awvl(i,njj-1,k)=0.0
		endif
	enddo
	enddo	
	write(43,413)timet, ni, nk, 1
413	format('ZONE T = "XZ ', F6.4,'" I=',I4,' J=',I4,' K=', I4,' F=POINT')
	write(43,423)timet
423	format('STRANDID=1,SOLUTIONTIME=', e14.4) !F6.2
j=njj
if(half_hyw)j=1
	do k=1,nk
	do i=1,ni
		write(43,111) x_hyw(i),z(k),auvl(i,j,k),awvl(i,j,k),temp_hyw(i,j,k),concentration(i,j,k),fracl(i,j,k),dgdtdtdxu(i,j,k),dgdtdtdxv(i,j,k),dgdcdcdxu(i,j,k),dgdcdcdxv(i,j,k)
!111		format(8(e14.4))
	enddo
	enddo
end subroutine Cust_Out

!********************************************************************
subroutine other_out
	area=width*alen
	open(unit=39,file='./result/speout')
	write(39,*) area
	write(39,*)ni,nj
	do i=1,ni
	do j=1,nj
		write(39,99)x_hyw(i),y(j),temp_hyw(i,j,nk)
	enddo
	enddo
99	format(2(f6.3,2x),f8.2)
	close(39)
end subroutine other_out

!********************************************************************
subroutine CalTime
	integer isecused
	call date_and_time(values = iTimeEnd)
	iSecUsed=86400*(iTimeEnd(3)-iTimeStart(3))+3600*(iTimeEnd(5)-iTimeStart(5))+60* &
		(iTimeEnd(6)-iTimeStart(6))+iTimeEnd(7)-iTimeStart(7)
	aAveSec=real(iSecUsed)/real(itertot)
end subroutine CalTime

!********************************************************************
subroutine EndTime
	call date_and_time(values = iTimeEnd)
	write(6,807)iTimeEnd(1:3),iTimeEnd(5:7)
	write(9,807)iTimeEnd(1:3),iTimeEnd(5:7)
807	format(2x,'Date: ',I4,'-',I2,'-',I2,2x,'time: ',2(I2,':'),I2,/)
	if(iTimeEnd(7).lt.iTimeStart(7)) then
		iTimeEnd(7)=iTimeEnd(7)+60
		iTimeEnd(6)=iTimeEnd(6)-1
	endif
	if(iTimeEnd(6).lt.iTimeStart(6)) then
		iTimeEnd(6)=iTimeEnd(6)+60
		iTimeEnd(5)=iTimeEnd(5)-1
	endif
	if(iTimeEnd(5).lt.iTimeStart(5))	 iTimeEnd(5)=iTimeEnd(5)+24
	write(6,808)(iTimeEnd(5)-iTimeStart(5)),(iTimeEnd(6)-iTimeStart(6)),(iTimeEnd(7)-iTimeStart(7))
	write(9,808)(iTimeEnd(5)-iTimeStart(5)),(iTimeEnd(6)-iTimeStart(6)),(iTimeEnd(7)-iTimeStart(7))
808	format(2x,'Total time used:',I6,2x,'hr',I6,2x,'m',I6,2x,'s',/)

!----- close output file------------
	close(9)
	if(.not.steady)then
!-----close movie, cycle and solid files---------------
		close(38)
		close(40)
		close(41)
		close(42)
		close(43)
	endif
	return
end subroutine EndTime

!********************************************************************
subroutine output_steady_end
	call tec_out
	call final_out
	call other_out
end subroutine output_steady_end


!********************************************************************
subroutine tableout(nmax,xyz,xyzuvw,str1,str2,str3,iunit)
	dimension xyz(1),xyzuvw(1)
	character*3 str1,str2,str3
	integer i,nmax,iunit,leng,ibeg
	real(8) xyz,xyzuvw
	leng=7
	iend=0
41	if (iend.eq.nmax) return
	ibeg=iend+1
	iend=iend+leng
	iend=min0(iend,nmax)
	write(iunit,51) str1,(i,i=ibeg,iend)
	write(iunit,52) str2,(xyz(i),i=ibeg,iend)
	write(iunit,52) str3,(xyzuvw(i),i=ibeg,iend)
	goto 41
51	format(/2x,a3,4x,7(i5,6x))
52	format(2x,a3,1x,7(1pe11.3))
	return
end subroutine tableout

!********************************************************************
subroutine OpenFiles

	open(unit=9,file='./result/output.txt')
	if(.not.steady) then
		open(unit=38,file='./result/solidification.txt')
		open(unit=40,file='./result/temp_history.txt')
		open(unit=41,file='./result/tecmovxy.plt')
		open(unit=42,file='./result/tecmovyz.plt')
		open(unit=43,file='./result/tecmovxz.plt')
		write(41,*)'TITLE = "HEAT TRANSFER AND FLUID FLOW DURING LASER PROCESSING"'
		write(41,*)'VARIABLES = "x", "Y", "U", "V","T","C","fracl","tu","tv","cu","cv" '
		write(42,*)'TITLE = "HEAT TRANSFER AND FLUID FLOW DURING LASER PROCESSING"'
		write(42,*)'VARIABLES = "x", "Y",  "U", "V","T","C","fracl","tu","tv","cu","cv" '
		write(43,*)'TITLE = "HEAT TRANSFER AND FLUID FLOW DURING LASER PROCESSING"'
		write(43,*)'VARIABLES = "x", "Y",  "U", "V","T","C","fracl","tu","tv","cu","cv" '
		write(40,*)'time p1 p2 p3 p4 p5 p6 p7 p8'
	endif
	return
end subroutine OpenFiles

!********************************************************************
subroutine PowerOff
	write(6,803)
	write(9,803)
803	format(//,'  Starting Cooling Cycle',//)
	heatinLaser=0.0
	heatin=0.0
!----- change under-relaxation number------------
	urfu=0.5
	urfw=0.5
	urfv=0.5
	urfp=0.7
	urfh=0.9

	call ArcOff_Out

end subroutine PowerOff


!********************************************************************
subroutine ArcOff_Out
	call tec_out
	call final_out
end subroutine ArcOff_Out

end module printing