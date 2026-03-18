      module mod_vaporization
      use initialization, only : concentration,temperature,tliquidmatrix
     l ,vap_heatloss,window_hyw,tboiltable,cstep,tstep,machtable,tmachl
     l,tmachh,deltmMov,vapprintc,vapprintcontrol,heatin,vap_heatloss
      use geometry,only:x_hyw,y,areaij,volume,ni,nj,nk
      use parameters,only:delt
      use laserinput,only:beam_pos,timet
	use DFLOGM  
	include 'resource.fd'  
c-----initialization-------------------------------------------------------
      character*60 filenames(3), val(11)
	dimension valnov(11)
	logical retlog,icheck(2)
	real gastype,dianz,flrate,wtpfe,wtpmn,wtpcr,wtpni,scvel,density,
	1plfac !,beamloc,delt,timet,volume
	real tsurf
	real amwtgas,amuroom,renno,fre,erf,pfe,pmn,pcr,pni,aa,bb
	real cc,tboil
	integer retint,iedit,itermax,imore
	type (dialog) dlg
	real gamma1,gamma3,rtemp,pi,amwtfe,amwtmn,amwtcr,amwtni
	real vap_latentfe,vap_latentmn,vap_latentcr,vap_latentni
	real amffe,amfmn,amfcr,amfni
	real totfe,totmn,totcr,totni,totgd,diffe,difmn,difcr,difni
	real totdi,cflfe,cflmn,cflcr,cflni,confl,amach
	real rdis,psp,amwtvap,spedrt,am
	real visgas,dfegas,dmngas,dcrgas,dnigas
	
      data gamma1,gamma3,rtemp,pi/1.6667,1.6667,298.0,3.1416/
      data amwtfe,amwtmn,amwtcr,amwtni/55.85,54.93,51.996,58.70/
	data tmelt,imore/1811.,-1/
	data vap_latentfe,vap_latentmn,vap_latentcr,vap_latentni
     l /6615000,4091000,5945000,5862000/

      contains
      subroutine vaporization
      real term1,t3ts,tt,r3rs,p3ps,temp3,a3a1,term2,p2p1
      real psp1,rs,rho3,sped
      real prsure,avtemp,dengas,akinvis,rd,rd2,rd3
      real scno,shno,amasco,scnomn,amascomn                  
                            
                             
      
      
c	This program calculates the vaporization rate and composition change 
c	during welding of Stainless Steels
c	The program needs to be compiled together with resource files
c	including 'resource.fd', 'resource.h', and 'vap.rc'.
      vap_heatloss(:,:)=0.0
      if(window_hyw.eq.1)goto 134
c-----Welcome window-------------------------------------------------------
	retlog=dlginit(dialog1, dlg)
	retint=dlgmodal(dlg)
	call dlguninit(dlg)
c-----Window for modifying parameters--------------------------------------
5	retlog=dlginit(dialog2, dlg)
		imore=-100
c-----Set default parameters-----------------------------------------------
10		retlog=dlgset(dlg, edit_inf, 'in')
		retlog=dlgset(dlg, edit_outf,'out')
		retlog=dlgset(dlg, edit_tec, 'tecout')
		retlog=dlgset(dlg, check_he, .false.)
		retlog=dlgset(dlg, check_ar, .true.)
		retlog=dlgset(dlg, edit_fe,'72.3')
		retlog=dlgset(dlg, edit_mn,'1.0')
		retlog=dlgset(dlg, edit_cr,'18.1')
		retlog=dlgset(dlg, edit_ni,'8.6')
		retlog=dlgset(dlg, edit_nozzle,'0.6')
		retlog=dlgset(dlg, edit_gasflow,'1500')
		retlog=dlgset(dlg, edit_speed,'0.01')
		retlog=dlgset(dlg, edit_plasma,'1.0')
		retlog=dlgset(dlg, edit_density,'7.2')
		retlog=dlgset(dlg, edit_iteration,'10')
		retlog=dlgset(dlg, edit_beamloc,'0.15')
	retint=dlgmodal(dlg)
c-----Get modified parameters----------------------------------------
		retlog=dlgget(dlg, edit_inf, filenames(1))
		retlog=dlgget(dlg, edit_outf,filenames(2))
		retlog=dlgget(dlg, edit_tec, filenames(3))
		retlog=dlggetlog(dlg, check_he, icheck(1))
		retlog=dlggetlog(dlg, check_ar, icheck(2))
		if (icheck(1).and.icheck(2)) goto 10
		if (icheck(1)) gastype=1.0
		if (icheck(2)) gastype=2.0
		do 11 i=1,11
		iedit=1003+i
		retlog=dlgget(dlg, iedit, val(i))
11		continue
		do 12 i=1,11
		read (val(i),*) valnov(i)
12		continue
	call dlguninit(dlg)
c-----end data input, assign user friendly names for the variable---------
      wtpfe   = valnov(1)
      wtpmn   = valnov(2)
	wtpcr   = valnov(3)
	wtpni   = valnov(4)
      dianz   = valnov(5)
      flrate  = valnov(6)
      scvel   = valnov(7)
      density = valnov(8)
	plfac   = valnov(9)
      itermax = valnov(10)
	beamloc = valnov(11)
	if ((wtpmn+wtpfe+wtpcr+wtpni).ne.100.) then
	wtpfe=100.-wtpmn-wtpcr-wtpni
	endif
c-----store original composition data--------------------------------------
      wtpoldfe=wtpfe
      wtpoldmn=wtpmn
	wtpoldcr=wtpcr
      wtpoldni=wtpni
c-----pick molecular wt. and room temp. viscosity of the shielding gas-----
      if (gastype.lt.1.5) then
      amwtgas=4.0026
      amuroom=1.97391e-4
      else
      amwtgas=39.94
      amuroom=2.2527e-4
      end if
c-----calculate Reynolds number and its function---------------------------
      renno=4.*flrate*(amwtgas*273.)/(22400.*298.)/(amuroom*pi*dianz)
      fre=2.*sqrt(renno)*sqrt(1.+renno**0.55/200.)
c-----open input and output files------------------------------------------
      open (unit=8, file=filenames(1))
      open (unit=16,file=filenames(2))
      open (unit=24,file='./result/vaploss.plt')
	open (unit=35,file='./result/vapmassni.plt')
	open (unit=30,file='./result/vapmassfe.plt')
	open (unit=31,file='./result/machtable.plt')
	open (unit=32,file='./result/boiltable.plt')
	window_hyw=1
    !  read(8,*) l1, m1
 !     l1=ni
  !    m1=nj
    !  read(8,*) delt
      call initialize_tboil
      call initialize_mach
      write(24,*)'TITLE = vaporization heat flux file'
      write(24,*)'VARIABLES="x","y","LaserIn","VHLoss"'
      write(30,*)'TITLE = vaporization mass flux file fe'
      write(30,*)'VARIABLES="x","y","T","tboil","cflfe","diffe","fe"
	1	'
      write(35,*)'TITLE = vaporization mass flux file ni'
      write(35,*)'VARIABLES="x","y","T",
	1	,"cflni","difni","ni","M"'
	!      rewind(8)
c-----start of calculations------------------------------------------------ 
!	do 1000 iter=1,itermax
c-----calculate composition in mole fraction from weight percent-----------

c-----find tboil from equilibrium pressures for the given composition------
c-----above tboil there is vapor flux due to pressure gradient-------------
c-----bisection method used: aa & bb are initial guessed values------------

!	write(*,*) 'boiling point = ', tboil
c-----read from input file (data of surface temperature)-------------------
 !    ! read(8,*)l1,m1
  !   ! read(8,*)delt
  !    do 440 i=1,8000    !!!!Do calculation for every grid point, revise
  !    read(8,*)timet,x_hyw,y,xcv,ycv,tsurf
  
134   if(vapprintcontrol)then
      write(30,*)'ZONE I=',ni,' J=',nj,' F=POINT'
	write(30,*)'STRANDID = 1,SOLUTIONTIME =',timet 
	write(35,*)'ZONE I=',ni,' J=',nj,' F=POINT'
	write(35,*)'STRANDID = 1,SOLUTIONTIME =',timet
	endif
      do j=1,nj
      do i=1,ni
!      if(timet.lt.0) go to 201
      tsurf=temperature(i,j,nk)
      wtpfe=concentration(i,j,nk)*100
      wtpni=(1-concentration(i,j,nk))*100
      wtpmn=0.0
      wtpcr=0.0
      cc=concentration(i,j,nk)
      call interpolate_tboil(tboil,cc)
    !  totmol=wtpfe/amwtfe+wtpmn/amwtmn+wtpcr/amwtcr+wtpni/amwtni
      amffe=concentration(i,j,nk)*1   !wtpfe/(totmol*amwtfe)
      amfmn=0   !wtpmn/(totmol*amwtmn)
      amfcr=0   !wtpcr/(totmol*amwtcr)
      amfni=(1-concentration(i,j,nk))*1   !wtpni/(totmol*amwtni)
c-----initializing the variables-------------------------------------------
      totfe=0.
      totmn=0.
      totcr=0.
      totni=0.
      totgd=0.
      diffe=0.
      difmn=0.
      difcr=0.
      difni=0.
      totdif=0.
      cflfe=0.
      cflmn=0.
      cflcr=0.
      cflni=0.
      confl=0.
    !  tboil=2000
      amach=0.0
      if(temperature(i,j,nk).le.tliquidmatrix(i,j,nk))goto 5555
      
!	areaxy=areaij(i,j) !xcv*ycv
	rdis=sqrt((x_hyw(i)-beam_pos)**2+y(j)**2)
!     if (tsurf.lt.tmelt) goto 101
c-----calculate thermodynamic pressure, equation (3.37)--------------------
      call eqpres(tsurf,pfe,pmn,pcr,pni)
      psp=amffe*pfe+amfmn*pmn+amfcr*pcr+amfni*pni        
      if (tsurf.lt.tboil) goto 102
c-----pressure gradient driven vaporization flux---------------------------
c-----calculate average molecular weight of vapor, equation(3.38)----------
      amwtvap=(amffe*pfe*amwtfe+amfmn*pmn*amwtmn+amfcr*pcr*amwtcr+
     1	amfni*pni*amwtni)/psp           
c-----speed of sound in vapor at room temperature--------------------------
      spedrt=sqrt(1.667*8314.*rtemp/amwtvap)*100.            
c-----begin calculation of mach number, equations (3.36) to (3.42)---------
!221   
      call interpolate_mach(amach,tsurf,cc)
      am=amach*sqrt(gamma3/2.)                             
      term1=(gamma3-1.)*am/((gamma3+1.)*2.)                 
c-----temperature jump condition across Knudsen layer, equation (3.36)-----
      t3ts=(sqrt(1.+pi*term1*term1)-sqrt(pi)*term1)**2      
      tt=1./(1.+0.47047*am)                                
      erf=0.34802*tt-0.09588*tt*tt+0.74786*tt*tt*tt         
c-----density jump condition across Knudsen layer, equation (3.37)---------
      r3rs=sqrt(1./t3ts)*((am**2+0.5)*erf-am/sqrt(pi))       
      r3rs=r3rs+0.5*(1./t3ts)*(1-sqrt(pi)*am*erf)           
c-----pressure jump condition across Knudsen layer, equation (3.37)--------
      p3ps=r3rs*t3ts                                       
c-----temperature at edge of Knudsen layer surface, equation (3.36)--------
      temp3=tsurf*t3ts                                     
      a3a1=sqrt(gamma3*temp3*amwtgas)/sqrt(gamma1*rtemp*amwtvap)
      term2=(gamma1+1.)/4.*amach*a3a1                       
c-----Rankine Hogonoit relation, equation (3.41)---------------------------
      p2p1=1.+gamma1*a3a1*amach*(term2+sqrt(1.+term2*term2))
c-----gasdynamic pressure at pool surface ---------------------------------
      psp1=p2p1/p3ps                                        
c-----difference between gasdynamic and thermodynamic pressure-------------
!      resd=abs(psp1/psp-1.)                               
!      amach = amach+0.00005                               
!      if (resd.gt.0.001) go to 221                           
c-----end mach number calculation, density at pool surface (ideal)---------
      rs=amwtvap*273.*psp/(22400.*tsurf)                    
c-----density at edge of Knudsen layer-------------------------------------
      rho3=r3rs*rs                                         
c-----velocity of vapor at edge of  Knudsen layer--------------------------
      sped=spedrt*sqrt(temp3/rtemp)                           
c-----calculate total flux, equation (3.43)--------------------------------
      confl=rho3*amach*sped
      cflfe=amffe*confl*pfe/psp
      cflmn=amfmn*confl*pmn/psp
      cflcr=amfcr*confl*pcr/psp
      cflni=amfni*confl*pni/psp
c-----end calculation of pressure gradient driven vaporization flux--------
102   continue
c-----calculate vaporization flux due to concentration gradient------------
      prsure=1.
      if (tsurf.gt.tboil) prsure=(psp+1.)/2.
c      prsure=(psp+1.)/2.
      avtemp=(tsurf+rtemp)/2.
      call gasprop(gastype,avtemp,prsure,visgas,dfegas,dmngas,
     1	dcrgas,dnigas)
      dengas=amwtgas*273.*prsure/(22400.*avtemp)
      akinvis=visgas/dengas
	rd=rdis/dianz
	rd2=rd*rd
	rd3=0.483-0.108*rd+7.71e-3*rd2
c---------------iron-------------------------------------------------------
      scno=akinvis/dfegas
      shno=fre*scno**0.42*rd3
      amasco=shno*dfegas/dianz
      diffe=amasco*pfe*amwtfe*amffe/(82.0594*tsurf)
c---------------manganese--------------------------------------------------
      scnomn=akinvis/dmngas
      shno=fre*scnomn**0.42*rd3
      amascomn=shno*dmngas/dianz
      difmn=amascomn*pmn*amwtmn*amfmn/(82.0594*tsurf)
c---------------chromium---------------------------------------------------
      scno=akinvis/dcrgas
      shno=fre*scno**0.42*rd3
      amasco=shno*dcrgas/dianz
      difcr=amasco*pcr*amwtcr*amfcr/(82.0594*tsurf)
c---------------nickel-----------------------------------------------------
      scno=akinvis/dnigas
      shno=fre*scno**0.42*rd3
      amasco=shno*dnigas/dianz
      difni=amasco*pni*amwtni*amfni/(82.0594*tsurf)
c-----calculate vapor fluxes consider suppressing effect of plasma---------
      totdif=(diffe+difmn+difcr+difni)*plfac
      confl=confl*plfac
	totfe=(cflfe+diffe)*plfac
      totmn=(cflmn+difmn)*plfac
      totcr=(cflcr+difcr)*plfac
      totni=(cflni+difni)*plfac
      totgd=totdif+confl
      
      vap_heatloss(i,j)=totfe*vap_latentfe+totmn*vap_latentmn+
     l totcr*vap_latentcr+totni*vap_latentni
c-----write the local vaporization flux into a file. The data in this
c     file are used for calculting composition change in a subroutine------
!101	write(30,999) timet,areaxy,totfe,totmn,totcr,totni
!	If ((tsurf.lt.400).and.(mod(tsurf,100.0).lt.1)) then
!	write(35,999) timet,tsurf,rho3,amach,sped,amach*sped
!	endif
!999   format(6e14.6)
!	if(iter.lt.itermax) goto 440  !!!!!!!!!need revising
c-----write output files---------------------------------------------------
c     if (timet.eq.3.e-3) then
!	if ((abs(timet-3.0e-3)*1000).lt.1e-6) then
5555  if(vapprintcontrol)then
      write(30,998)x_hyw(i),y(j),tsurf,tboil,cflfe,diffe,totfe
	write(35,998)x_hyw(i),y(j),tsurf
	1	,cflni,difni,totni,amach 
	endif
!	write(24,998)10.*(x_hyw-beam_pos),10.*y,confl*10.,totdif*10.,totgd*10.,
!	1tsurf,totfe*10.,totmn*10.,totcr*10.,totni*10. 
	
!	endif
998   format(7(e14.4,' '))
      
      enddo
      enddo
      vapprintcontrol=.false.
c-----call subroutine to calculate composition change----------------------
 !     call totflux(iter,itermax,volume,scvel,density,wtpfe,wtpmn,
!     1 wtpcr,wtpni,wtpoldfe,wtpoldmn,wtpoldcr,wtpoldni,imore,delt)
!1000  continue
!1100	if (imore.gt.0) goto 5
	end subroutine vaporization
c-----subroutine to calculate composition change---------------------------
 !     subroutine totflux(iter,itermax,volume,scvel,density,wtpfe,wtpmn,
 !    1 wtpcr,wtpni,wtpoldfe,wtpoldmn,wtpoldcr,wtpoldni,imore,delt)

!      end subroutine totflux
c-----subroutine to calculate the viscosity of the shielding gas and
c     diffusivity of the alloying elements in the shielding gas------------
      subroutine gasprop(gastype,t,prsure,visgas,dfegas,dmngas,
     1	dcrgas,dnigas)
	if (gastype.lt.1.5) then
      visgas = 2.2029e-4 + 2.2171e-7*t
      dfegas = (-2.1360+5.4957e-3*t+2.4247e-6*t**2)/prsure
      dmngas = (-1.6174+4.7797e-3*t+2.4582e-6*t**2)/prsure
      dcrgas = (-2.2310+5.5302e-3*t+2.3683e-6*t**2)/prsure
      dnigas = (-2.2184+5.6412e-3*t+2.4499e-6*t**2)/prsure
      else
      visgas = 2.7373e-4 + 2.7681e-7*t
      dfegas = (-0.61024+1.1274e-3*t+6.4892e-7*t**2)/prsure
      dmngas = (-0.59274+1.1469e-3*t+6.1891e-7*t**2)/prsure
      dcrgas = (-0.60579+1.1331e-3*t+6.4741e-7*t**2)/prsure
      dnigas = (-0.60938+1.1335e-3*t+6.5149e-7*t**2)/prsure
      endif
      return
      end subroutine gasprop
c-----subroutine to calculate equilibrium vapor pressure ------------------

      subroutine eqpres(aa,pfe,pmn,pcr,pni)   
	pmn=10.**(-5.58e-4*aa-1.503e4/aa+12.609)/1.013e5
	pcr=10.**(-13.505e3/aa+33.658*alog10(aa)-9.29e-3*aa
     1	+8.381e-7*aa*aa-87.077)/1.013e5
                 
c     df=86900.-aa*27.78
c     pfe=(exp(-df/(1.987*aa)))
c	pfe=exp(-4.3734e4/aa+13.98)	    
c	pni=10.**(-3519./aa+74.94*alog10(aa)-18.042e-3*aa
c     1	+15.14e-7*aa*aa-214.297)/1.013e5
c	reference 1
	pfe=10.**(11.5549-1.9538e4/aa-0.62549*alog10(aa)
	1	-2.7182e-9*aa+1.9086e-13*aa**2)/760.    

c	reference 4	
c	pfe=10.**(6.347-19574/aa)
	
	pni=10.**(6.666-20765/aa)
c	pni=10.**(10.557-22606/aa-0.8717*alog10(aa))
c 	pcr=10.**(6.8-20733/aa+0.4391*alog10(aa)-0.4094e-3*aa)
	
      end subroutine eqpres
      
      subroutine findtboil(tboil,cc)
      amffe=cc
      amfmn=0  
      amfcr=0   
      amfni=1-cc

      aa=1000.
      bb=5000.
 !     goto 166
110   tboil=(aa+bb)/2.0
      call eqpres(aa,pfe,pmn,pcr,pni)
      ptaa=amffe*pfe+amfmn*pmn+amfcr*pcr+amfni*pni-1.
      call eqpres(tboil,pfe,pmn,pcr,pni)
      ptboil=amffe*pfe+amfmn*pmn+amfcr*pcr+amfni*pni-1.
      if ((ptaa*ptboil).lt.0) then
      bb=tboil
      else
      aa=tboil
      endif
      if (abs(ptboil).lt.0.01) go to 20
      go to 110
20    continue
      return
      end subroutine findtboil
      
      subroutine initialize_tboil
      integer i
      write(32,*)'TITLE = tboil table'
      write(32,*)'VARIABLES="x","tboil"'
      write(32,*)'ZONE I=',cstep+1,'
     l F=POINT'
      do i=0,cstep
      call findtboil(tboiltable(i),i*1.0/cstep)
      write(32,998)i*1.0/cstep,tboiltable(i)
      enddo
      close(32)
998   format(2(e14.6,'  '))
      end subroutine initialize_tboil
      
      subroutine interpolate_tboil(tboil,cc)
      integer aa
      aa=floor(cstep*cc)
      if(aa.le.0)aa=0
      if(aa.ge.1)aa=1
      tboil=tboiltable(aa)+(cc*cstep-aa)*
     l(tboiltable(aa+1)-tboiltable(aa))
      return
      
      end subroutine interpolate_tboil
      
      subroutine find_mach(amach,tsurf,cc)
      integer aa
      real term1,t3ts,tt,r3rs,p3ps,temp3,a3a1,term2,p2p1
      real psp1,rs,rho3,sped
 !     real,intent(out)::term1
      aa=floor(cstep*cc)
      amach=0.0
      tboil=tboiltable(aa)
      if (tsurf.lt.tboil) return
      amffe=cc
      amfmn=0  
      amfcr=0   
      amfni=1-cc
      call eqpres(tsurf,pfe,pmn,pcr,pni)
      psp=amffe*pfe+amfmn*pmn+amfcr*pcr+amfni*pni
!      print*, cc
c-----pressure gradient driven vaporization flux---------------------------
c-----calculate average molecular weight of vapor, equation(3.38)----------
      amwtvap=(amffe*pfe*amwtfe+amfmn*pmn*amwtmn+amfcr*pcr*amwtcr+
     1	amfni*pni*amwtni)/psp           
c-----speed of sound in vapor at room temperature--------------------------
      spedrt=sqrt(1.667*8314.*rtemp/amwtvap)*100.            
c-----begin calculation of mach number, equations (3.36) to (3.42)---------
221   am=amach*sqrt(gamma3/2.)                             
      term1=(gamma3-1.)*am/((gamma3+1.)*2.)                 
c-----temperature jump condition across Knudsen layer, equation (3.36)-----
      t3ts=(sqrt(1.+pi*term1*term1)-sqrt(pi)*term1)**2      
      tt=1./(1.+0.47047*am)                                
      erf=0.34802*tt-0.09588*tt*tt+0.74786*tt*tt*tt         
c-----density jump condition across Knudsen layer, equation (3.37)---------
      r3rs=sqrt(1./t3ts)*((am**2+0.5)*erf-am/sqrt(pi))       
      r3rs=r3rs+0.5*(1./t3ts)*(1-sqrt(pi)*am*erf)           
c-----pressure jump condition across Knudsen layer, equation (3.37)--------
      p3ps=r3rs*t3ts                                       
c-----temperature at edge of Knudsen layer surface, equation (3.36)--------
      temp3=tsurf*t3ts                                     
      a3a1=sqrt(gamma3*temp3*amwtgas)/sqrt(gamma1*rtemp*amwtvap)
      term2=(gamma1+1.)/4.*amach*a3a1                       
c-----Rankine Hogonoit relation, equation (3.41)---------------------------
      p2p1=1.+gamma1*a3a1*amach*(term2+sqrt(1.+term2*term2))
c-----gasdynamic pressure at pool surface ---------------------------------
      psp1=p2p1/p3ps                                        
c-----difference between gasdynamic and thermodynamic pressure-------------
      resd=abs(psp1/psp-1.)                               
      amach = amach+0.00005    
!      print*, amach
      if (resd.gt.0.001) go to 221  
!      print*, "2"
c-----end mach number calculation      end subroutine initialize_vaphm
      return
      end subroutine find_mach
      
      subroutine initialize_mach
      integer i,j
      print*, "Mach table begin!"
      write(31,*)'TITLE = mach table'
      write(31,*)'VARIABLES="x","y","mach"'
      write(31,*)'ZONE I=',tmachh/tstep-tmachl/tstep+1,' J=',cstep+1,'
     l F=POINT'
      
      do j=0,cstep
      do i=tmachl/tstep,tmachh/tstep
!      print*, i*tstep
      call find_mach(machtable(i,j),i*tstep*1.0,j*1.0/cstep)
      write(31,998)i*tstep*1.0,j*1.0/cstep*1000,machtable(i,j)
      enddo
      enddo
      close(31)
998   format(3(e14.6,'  '))
      print*, "Mach table finished!"
      end subroutine initialize_mach

      subroutine interpolate_mach(amach,tsurf,cc)
      integer aa,bb
      aa=floor(cstep*cc)
      bb=floor(tsurf/tstep)
      if(aa.le.0)aa=0
      if(aa.ge.1)aa=1
      if(bb.le.tmachl/tstep)bb=tmachl/tstep
      if(bb.ge.tmachh/tstep)bb=tmachh/tstep
      amach=machtable(bb,aa)+(cc*cstep-aa)*
     l(machtable(bb,aa+1)-machtable(bb,aa))+
     l(tsurf/tstep-bb)*(machtable(bb+1,aa)-machtable(bb,aa))
      !if(tsurf.ge.tmachh)amach=machtable(tmachh/tstep,0)
      return
      
      end subroutine interpolate_mach
      
      subroutine vapprint
    !  use initialization, only :vap_heatloss
    !  use geometry,only:x_hyw,y,areaij,ni,nj,nk
    ! ! use laserinput,only:timet
      integer i,j
      if(mod(vapprintc,deltmMov).lt.1)then
            write(24,*)'ZONE I=',ni,' J=',nj,' F=POINT'
            
	write(24,*)'STRANDID = 1,SOLUTIONTIME =',timet
      do j=1,nj
	do i=1,ni
      write(24,998)x_hyw(i),y(j),heatin(i,j),vap_heatloss(i,j) 
!	write(24,998)10.*(x_hyw-beam_pos),10.*y,confl*10.,totdif*10.,totgd*10.,
!	1tsurf,totfe*10.,totmn*10.,totcr*10.,totni*10. 
	
!	endif
      enddo
      enddo
998   format(4(e14.6,'  '))
      endif
      return
      end subroutine vapprint
      
      end module mod_vaporization
c--------------end of the program-/1.013e5-----------------------------------------
