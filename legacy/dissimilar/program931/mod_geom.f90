!______________________________________________________________________________
!
module geometry
!______________________________________________________________________________
!
	use constant
	use parameters
	
	implicit none

	real(8) dimx,dimy,dimz		
	DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE ::x_hyw,y,z,dxpwinv,xu_hyw,yv_hyw,zw_hyw,dypsinv,dzpbinv,fracx,fracy,fracz	
!	DOUBLE PRECISION, DIMENSION(:,:,:), ALLOCATABLE ::volume_u,volume_v,volume_w,volume
	DOUBLE PRECISION, DIMENSION(:,:), ALLOCATABLE ::areaij,areajk,areaik,areauij,areauik,areavjk,areavij,areawik,areawjk
    DOUBLE PRECISION, DIMENSION(:,:,:), ALLOCATABLE :: volume, volume_u, volume_v, volume_w
	integer ni,nim1,nj,njm1,nk,nkm1,njj,nkm1temp,nktemp  
			
	integer	istat,jstat,kstat,iend,jend,istatp1,iendm1  
	contains 

subroutine generate_grid
integer i,j,k,ist
real statloc,term
ALLOCATE(x_hyw(nx),y(ny),z(nz),dxpwinv(nx),xu_hyw(nx),yv_hyw(ny),zw_hyw(nz),dypsinv(ny),dzpbinv(nz))
!ALLOCATE(volume_u(nx,ny,nz),volume_v(nx,ny,nz),volume_w(nx,ny,nz),volume(nx,ny,nz))
ALLOCATE(areaij(nx,ny),areajk(ny,nz),areaik(nx,nz))
ALLOCATE(volume(nx,ny,nz), volume_u(nx,ny,nz), volume_v(nx,ny,nz), volume_w(nx,ny,nz))
ALLOCATE(areauij(nx,ny),areauik(nx,nz),areavjk(ny,nz),areavij(nx,ny),areawik(nx,nz),areawjk(ny,nz))
ALLOCATE(fracx(nx),fracy(ny),fracz(nz))
areaij(:,:)=0
ni=nx-1
nj=ny-1
nk=nz-1
nktemp=nk-1
nkm1temp=nktemp-1

nim1=ni-1
njm1=nj-1
nkm1=nk-1
nktemp=nk
nkm1temp=nktemp-1

!----x_hyw grid---------------------------------------
	xu_hyw(1:2) = 0.0 
	ist = 2
	statloc = 0
	ni=2
	do i=1, nzx
		ni=ni+ncvx(i)
		do j=1, ncvx(i)
			if(powrx(i).ge.0.0)then
				term=(real(j)/real(ncvx(i)))**powrx(i)
			else
				term=1.0-(1.0-real(j)/real(ncvx(i)))**(-powrx(i))
			endif
			xu_hyw(j+ist) = statloc + xzone(i)*term 
		enddo
		ist = ist + ncvx(i)
		statLoc = statLoc + xzone(i)
	enddo
	nim1=ni-1

	do i=1,nim1
		x_hyw(i)=(xu_hyw(i+1)+xu_hyw(i))*0.5
	enddo
	x_hyw(ni)=xu_hyw(ni)

!-------y grids----------------------------
if(half_hyw)then
	yv_hyw(1:2) = 0.0
	ist = 2
	statloc = 0.0
	nj=2
	do i=1, nzy
		nj=nj+ncvy(i)
		do j=1, ncvy(i)
			if(powry(i).ge.0.0)then
				term=(real(j)/real(ncvy(i)))**powry(i)
			else
				term=1.0-(1.0-real(j)/real(ncvy(i)))**(-powry(i))
			endif
			yv_hyw(j+ist) = statloc + yzone(i)*term
		enddo
		ist = ist + ncvy(i)
		statLoc = statLoc + yzone(i)
	enddo
	njm1=nj-1
	
	do i=1,njm1
		y(i)=(yv_hyw(i+1)+yv_hyw(i))*0.5
	enddo
	y(nj)=yv_hyw(nj)
	njj=3

else
	yv_hyw(1:2) = 0.0
	ist = 2
	statloc = 0.0
	njj=2
	do i=1, nzy
		njj=njj+ncvy(i)
		do j=1, ncvy(i)
			if(powry(i).ge.0.0)then
				term=(real(j)/real(ncvy(i)))**powry(i)
			else
				term=1.0-(1.0-real(j)/real(ncvy(i)))**(-powry(i))
			endif
			yv_hyw(j+ist) = statloc + yzone(i)*term
		enddo
		ist = ist + ncvy(i)
		statLoc = statLoc + yzone(i)
	enddo
	nj=2*njj-3
	
	do j=njj,3,-1
	yv_hyw(j+njj-3)=yv_hyw(j)
	enddo
	!yv_hyw(2*njj-1)=yv_hyw(2*njj-2)

	!yv_hyw(njj)=yv_hyw(2)
	do j=1,njj-2
	yv_hyw(j)=-yv_hyw(2*njj-2-j)
	enddo
	yv_hyw(njj-1)=0.0
	njm1=nj-1
	
	do i=2,njm1
		y(i)=(yv_hyw(i+1)+yv_hyw(i))*0.5
	enddo
	y(1)=yv_hyw(1)
   y(nj)=yv_hyw(nj)
endif
!-----------z grids----------------------------
	zw_hyw(1:2) = 0.0
	ist = 2
	statloc = 0.0
	nk=2
	do i = 1,nzz
		nk=nk+ncvz(i)
		do j = 1, ncvz(i)
			if(powrz(i).ge.0.0)then
				term=(real(j)/real(ncvz(i)))**powrz(i)
			else
				term=1.0-(1.0-real(j)/real(ncvz(i)))**(-powrz(i))
			endif
			zw_hyw(j+ist) = statloc + zzone(i)*term
		enddo
		ist = ist + ncvz(i)
		statLoc = statLoc + zzone(i)
	enddo
	nkm1=nk-1

	do i=1,nkm1
	z(i)=(zw_hyw(i+1)+zw_hyw(i))*0.5
	enddo
	z(nk)=zw_hyw(nk)

!********************************************************************

	do i=2,ni
		dxpwinv(i)=1.0/(x_hyw(i)-x_hyw(i-1))
	enddo

	do j=2,nj
		dypsinv(j)=1.0/(y(j)-y(j-1))
	enddo

	do k=2,nk
		dzpbinv(k)=1.0/(z(k)-z(k-1))
	enddo

!	interpolation
	do i=1,nim1
		fracx(i)=(x_hyw(i+1)-xu_hyw(i+1))/(x_hyw(i+1)-x_hyw(i))
	enddo

	do j=1,njm1
		fracy(j)=(y(j+1)-yv_hyw(j+1))/(y(j+1)-y(j))
	enddo

	do k=1,nkm1
		fracz(k)=(z(k+1)-zw_hyw(k+1))/(z(k+1)-z(k))
	enddo

!---volumes-------------------------
	do k=2,nkm1
	do j=2,njm1
	do i=2,nim1
		volume(i,j,k)=(xu_hyw(i+1)-xu_hyw(i))*(yv_hyw(j+1)-yv_hyw(j))*(zw_hyw(k+1)-zw_hyw(k))
		volume_u(i,j,k)=(x_hyw(i)-x_hyw(i-1))*(yv_hyw(j+1)-yv_hyw(j))*(zw_hyw(k+1)-zw_hyw(k))
		volume_v(i,j,k)=(xu_hyw(i+1)-xu_hyw(i))*(y(j)-y(j-1))*(zw_hyw(k+1)-zw_hyw(k))
		volume_w(i,j,k)=(xu_hyw(i+1)-xu_hyw(i))*(yv_hyw(j+1)-yv_hyw(j))*(z(k)-z(k-1))
	enddo
	enddo
	enddo

!----------areas-----------------------
	do j=2,njm1
	do i=2,nim1
		areaij(i,j)=(xu_hyw(i+1)-xu_hyw(i))*(yv_hyw(j+1)-yv_hyw(j))
		areauij(i,j)=(x_hyw(i)-x_hyw(i-1))*(yv_hyw(j+1)-yv_hyw(j))
		areavij(i,j)=(xu_hyw(i+1)-xu_hyw(i))*(y(j)-y(j-1))
	enddo
	enddo
	
	do k=2,nkm1
	do i=2,nim1
		areaik(i,k)=(xu_hyw(i+1)-xu_hyw(i))*(zw_hyw(k+1)-zw_hyw(k))
		areawik(i,k)=(xu_hyw(i+1)-xu_hyw(i))*(z(k)-z(k-1))
		areauik(i,k)=(x_hyw(i)-x_hyw(i-1))*(zw_hyw(k+1)-zw_hyw(k))
	enddo
	enddo

	do k=2,nkm1
	do j=2,njm1
		areajk(j,k)=(yv_hyw(j+1)-yv_hyw(j))*(zw_hyw(k+1)-zw_hyw(k))
		areavjk(j,k)=(y(j)-y(j-1))*(zw_hyw(k+1)-zw_hyw(k))
		areawjk(j,k)=(yv_hyw(j+1)-yv_hyw(j))*(z(k)-z(k-1))
	enddo
	enddo

	dimx=x_hyw(ni)
	dimy=y(nj)
	dimz=z(nk)

	return
end subroutine generate_grid
end module geometry