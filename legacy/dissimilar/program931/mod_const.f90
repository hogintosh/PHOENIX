!______________________________________________________________________________
!
module constant
!______________________________________________________________________________
!
	implicit none
	real(8) g,pi,sigm,great,small
	parameter(g=9.8,pi=3.1415926,sigm=5.67e-8,great=1.0e20,small=1.0e-12)
	integer nx,ny,nz,nvar
	integer nx1,ny1,nz1,ng
	logical half_hyw
	parameter (nvar=4 )!,nx=90,ny=45,nz=90)
	parameter (nx1=3,ny1=2,nz1=2,ng=5)
	parameter (half_hyw=.false.)

end module constant