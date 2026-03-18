!______________________________________________________________________________
!
module residue
!______________________________________________________________________________
!
	use constant
	use geometry
	use initialization
	use dimensions
	use parameters
	use discretization
	
	implicit none

	real(8) resoru,resorv,resorw,resorh
	real(8) resorc
	contains

subroutine residual
	integer i,j,k
	real(8) sumd,resor,abs,umaxt,denom,dtpvar,sumh 
	go to (100,200,300,400,500) ivar

!********************************************************************
100	continue
	sumd=0.0

	do k=kstat,nkm1
	do j=jstat,jend
	do i=istatp1,iendm1
		resor=an(i,j,k)*uVel(i,j+1,k)+as(i,j,k)*uVel(i,j-1,k)+ae(i,j,k)*uVel(i+1,j,k)+aw(i,j,k)*uVel(i-1,j,k) &
			+at(i,j,k)*uVel(i,j,k+1)+ab(i,j,k)*uVel(i,j,k-1)+su(i,j,k)-ap(i,j,k)*uVel(i,j,k) 	
		sumd=sumd+abs(resor)
	enddo
	enddo
	enddo

	umaxt=maxval(abs(uVel(istatp1:iendm1,2:jend,nk)))

!---reference momentum---------
	refmom=0.25*pi*width**2*dens*umaxt**2+small

!----normalized residual--------- 
	resoru=sumd/refmom
	return

!********************************************************************
200	continue
	sumd=0.0
	do k=kstat,nkm1
	do j=jstat,jend
	do i=istatp1,iendm1
		resor=an(i,j,k)*vVel(i,j+1,k)+as(i,j,k)*vVel(i,j-1,k)+ae(i,j,k)*vVel(i+1,j,k)+aw(i,j,k)*vVel(i-1,j,k) &
			+at(i,j,k)*vVel(i,j,k+1)+ab(i,j,k)*vVel(i,j,k-1)+su(i,j,k)-ap(i,j,k)*vVel(i,j,k)
		sumd=sumd+abs(resor)
	enddo
	enddo
	enddo

	resorv=sumd/refmom
	return

!********************************************************************
300	continue
	sumd=0.0
	do k=kstat,nkm1
	do j=jstat,jend
	do i=istatp1,iendm1
		resor=an(i,j,k)*wVel(i,j+1,k)+as(i,j,k)*wVel(i,j-1,k)+ae(i,j,k)*wVel(i+1,j,k)+aw(i,j,k)*wVel(i-1,j,k) &
			+at(i,j,k)*wVel(i,j,k+1)+ab(i,j,k)*wVel(i,j,k-1)+su(i,j,k)-ap(i,j,k)*wVel(i,j,k)
		sumd=sumd+abs(resor)
	enddo
	enddo
	enddo

	resorw=sumd/refmom
	return

!********************************************************************
400	continue
!----- normalized mass source
	denom=0.0
	do k=kstat,nkm1
	do j=jstat,jend
	do i=istatp1,iendm1
		dtpvar=(abs(uVel(i,j,k))+abs(uVel(i+1,j,k)))*areajk(j,k)+(abs(vVel(i,j,k))+abs(vVel(i,j+1,k))) &
			*areaik(i,k)+(abs(wVel(i,j,k))+abs(wVel(i,j,k+1)))*areaij(i,j)
		denom=denom+0.5*abs(dtpvar)
	enddo
	enddo
	enddo

	denom=denom*dens
	resorm=resorm/(denom+small)
	return

!********************************************************************
500	continue

	sumh=0.0
	sumd=0.0

	do k=2,nkm1
	do j=2,njm1
	do i=2,nim1
		resor=(an(i,j,k)*temperature(i,j+1,k)+as(i,j,k)*temperature(i,j-1,k)+ae(i,j,k)*temperature(i+1,j,k)+ &
			aw(i,j,k)*temperature(i-1,j,k)+at(i,j,k)*temperature(i,j,k+1)+ab(i,j,k)*temperature(i,j,k-1)+ &
			su(i,j,k))/ap(i,j,k)-temperature(i,j,k)
		sumd=sumd+abs(resor)
		sumh=sumh+abs(temperature(i,j,k))
	enddo
	enddo
	enddo

	resorh=sumd/(sumh+small)
	return
	
end subroutine residual
end module residue