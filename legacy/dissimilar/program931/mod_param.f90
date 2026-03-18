!______________________________________________________________________________
!
module parameters
!______________________________________________________________________________
!
	use constant

	implicit none
	real(8) alaspow, alaseta, alasrb, alasfact, lasertime, xstart, scanvel
	real(8) dens, viscos, tsolid, tliquid, tvap, hsmelt, hlfriz, acp, acpl, thcons, thconl, beta, emiss, dgdtp
	real(8) dens2, viscos2, tsolid2, tliquid2, tvap2, hsmelt2, hlfriz2, acp2, acpl2, thcons2, thconl2, beta2, emiss2, dgdtp2,betac
	real(8) deltini,delt, timax, urfu, urfv, urfw, urfp, urfh	
	real(8) xzone(nx1),yzone(ny1),zzone(nz1),powrx(nx1),powry(ny1),powrz(nz1)!,tliquidmatrix(nx,ny,nz) !,tsolidmatrix(nx,ny,nz),tvapmatrix(nx,ny,nz)
	real(8) htci1, htcl1, htcm1, htck1, htcn1, tempWest, tempEast, tempNorth, tempBottom, tempPreheat, tempAmb	
	real(8) dgconst,massdiffl,dgconst2,smoothdistance
	integer nzx, nzy, nzz, maxit,deltprint
	integer ncvx(nx1),ncvy(ny1),ncvz(nz1)

	namelist / process_parameters /alaspow, alaseta, alasrb, alasfact, lasertime, xstart, scanvel
	namelist / material_properties /dens, viscos, tsolid, tliquid,tvap, hsmelt, hlfriz, acp, acpl,  &
		thcons, thconl, beta, emiss, dgdtp, dgconst,massdiffl
	namelist / material_properties2 /dens2, viscos2, tsolid2, tliquid2,tvap2, hsmelt2, hlfriz2, acp2, acpl2,  &
		thcons2, thconl2, beta2, emiss2, dgdtp2, dgconst2                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 
	namelist / numerical_relax / maxit, deltini, timax, urfu, urfv, urfw, urfp, urfh, deltprint,smoothdistance
	namelist / boundary_conditions / htci1, htcl1, htcm1, htck1, htcn1,	tempWest, tempEast, tempNorth, &
		tempBottom, tempPreheat, tempAmb

	contains

subroutine read_data
	
	integer i,j,k

	open(unit=10,file='./result/input_param.txt',form='formatted',status='old')

!-----geometrical parameters-------------------------------
	
	read(10,*)			
	read(10,*) nzx		
	read(10,*) (xzone(i),i=1,nzx)	
	read(10,*) (ncvx(i),i=1,nzx)	
	read(10,*) (powrx(i),i=1,nzx)	
	read(10,*) nzy		
	read(10,*) (yzone(i),i=1,nzy)	
	read(10,*) (ncvy(i),i=1,nzy)
	read(10,*) (powry(i),i=1,nzy)	
	read(10,*) nzz	
	read(10,*) (zzone(i),i=1,nzz)	
	read(10,*) (ncvz(i),i=1,nzz)	
	read(10,*) (powrz(i),i=1,nzz)	
 
	READ (10, NML=process_parameters)
	READ (10, NML=material_properties)
	READ (10, NML=material_properties2)
 	READ (10, NML=numerical_relax)
	READ (10, NML=boundary_conditions)
nx=4;ny=4;nz=4
do i=1,nzx
nx=ncvx(i)+nx
enddo
do i=1,nzy
ny=ncvy(i)+ny
enddo
do i=1,nzz
nz=ncvz(i)+nx
enddo

ny=ny*2
if(half_hyw)ny=ny
	close(10)
	return
end subroutine read_data
end module parameters