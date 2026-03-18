!______________________________________________________________________________
!
module convergence
!______________________________________________________________________________
!
	use initialization
	contains

subroutine enhance_converge_speed
	implicit none
	integer i,j,k
	real(8) denom
		
    DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE ::bl, blp, blm, blc, delh, pib,qib
    allocate(bl(nx), blp(nx), blm(nx), blc(nx), delh(nx), pib(nx),qib(nx))	
    bl(1:ni)=0.0
	blp(1:ni)=0.0
	blm(1:ni)=0.0
	blc(1:ni)=0.0

	do k=2,nkm1
	do j=2,njm1
	do i=2,nim1
		bl(i)=bl(i)+ap(i,j,k)-an(i,j,k)-as(i,j,k)-at(i,j,k)-ab(i,j,k)
		blp(i)=blp(i)+ae(i,j,k)
		blm(i)=blm(i)+aw(i,j,k)
		blc(i)=blc(i)+ae(i,j,k)*temperature(i+1,j,k)+aw(i,j,k)*temperature(i-1,j,k)+an(i,j,k)*temperature(i,j+1,k)+ &
			as(i,j,k)*temperature(i,j-1,k)+at(i,j,k)*temperature(i,j,k+1)+ab(i,j,k)*temperature(i,j,k-1)+su(i,j,k) &
			-ap(i,j,k)*temperature(i,j,k)
	enddo
	enddo
	enddo

	pib(2)=blp(2)/bl(2)
	qib(2)=blc(2)/bl(2)

	do i=3,nim1
		denom=bl(i)-blm(i)*pib(i-1)
		pib(i)=blp(i)/denom
		qib(i)=(blc(i)+blm(i)*qib(i-1))/denom
	enddo
	delh(nim1)=qib(nim1)

	do i=nim1-1,2,-1
		delh(i)=pib(i)*delh(i+1)+qib(i)
	enddo

	do k=2,nkm1
	do j=2,njm1
	do i=2,nim1
		temperature(i,j,k)=temperature(i,j,k)+delh(i)
	enddo
	enddo
	enddo
    deallocate(bl, blp, blm, blc, delh, pib,qib)	
	return

end subroutine enhance_converge_speed
end module convergence
