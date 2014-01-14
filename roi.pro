; NAME: roi
;
; PURPOSE: Fits Gaussian lines to regions-of-interest (ROIs).  If the ROIs are
;	not passed in (using band), an interactive mode is entered.  In the
;	interactive mode, left-click-drag to define an ROI, left-click to
;	sample a point, and right-click to exit the interactive mode.  X-axis
;	units are channels unless a gain calibration is supplied.
;
; INPUTS: (all extra keywords are passed through to "plot")
;   y		1D spectrum
;   band	optional - 2xN array for ROIs
;   gain	optional - energy gain calibration from "getgain"
;   verbose	keyword - turns on output for passed-in ROIs
;
; OUTPUTS:
;   result	array with fitted line energies, FWHMs, and strengths
;
; EXAMPLES:
;   roi,sf,xr=[0,1500],/yl
;   roi,sr,gain=gr,xr=[0,400]
;
; HISTORY:
;   2012-12-08, AYS: release
;   2014-01-14, AYS: include fu_gauss_lin and fitgauss2 directly

pro fu_gauss_lin, x,a,f,pder
ex = exp(-(x-a(2))^2./(2.*a(1)^2))
exm = a(0)/sqrt(2.*!pi)/a(1)*ex
f = exm  + a(4)*x + a(3)

if n_params(0) LE 3 then return
pder = dblarr(n_elements(x),n_elements(a))
pder(*,0) = exm/a(0)
pder(*,1) = -exm/a(1) + exm*(x-a(2))^2./a(1)^3.
pder(*,2) = exm*(x-a(2))/a(1)^2.
pder(*,3) = 1.
pder(*,4) = x
end

pro fitgauss2,x=x,y,w=w,fit_fwhm,fit_center,fit_area,ffe,fce,fae,quiet=quiet,$
   startwidth=startwidth, startcent=startcent,yfit=yfit,chisq=chisq,estimates

x=fcheck(x,findgen(n_elements(y)))
w=fcheck(w,fltarr(n_elements(y))+1.)
y1=y[0]
y2=y[n_elements(y)-1]
x1=x[0]
x2=x[n_elements(x)-1]
baseave=(y1+y2)/2.
baseslope=(y2-y1)/(x2-x1)
center = (where(y EQ max(y)))[0]
baseline = baseave + baseslope*(x-(x[center])[0])
height=max(y-baseline)
peak = where(y-baseline GT height/2.)

width = (x[max(peak)]-x[min(peak)]) / (2.*sqrt(2.*alog(2.)))
if width EQ 0 then width =( x[1]-x[0] ) / (2.*sqrt(2.*alog(2.)))

estimates=[height*width*sqrt(2.*!pi),width,x[center],$
           baseave-baseslope*center,baseslope]
if (keyword_set(startwidth)) then estimates[1]=startwidth
if (keyword_set(startcent)) then estimates[2]=startcent

if NOT keyword_set(quiet) then print,estimates
for j=0, 5 do begin
     yfit=curvefit(x,y,w,estimates,chisq=chisq,sigma,/double,function_name='fu_gauss_lin')
end

if NOT keyword_set(quiet) then begin
  plot,x,y
  oploterr,x,y,sqrt(1./w)
  oplot,x,yfit,psym=0
;  print,estimates
;  print,sigma
endif
fit_fwhm = estimates[1]*2.*sqrt(2.*alog(2.))
fit_center = estimates[2]
fit_area = estimates[0]
ffe = sigma[1]*2.*sqrt(2.*alog(2.))
fce = sigma[2]
fae = sigma[0]
end

pro roi,y,band,gain=gain,result=result,verbose=verbose,_extra=_extra

x = fcheck(gain,findgen(n_elements(y)))

result = [0,0,0]

if (keyword_set(band)) then begin

  nband = n_elements(band)/2

  for i=0,nband-1 do begin
    xs = [min(band[*,i]),max(band[*,i])]
    w = where(x ge xs[0] and x le xs[1])
    fitgauss2,x=x[w],y[w],fwhm,center,area,/quiet
    fitgauss2,x=w,y[w],fwhm2,center2,area2,/quiet
    if (keyword_set(verbose)) then begin
      print,xs[0],min(w),xs[1],max(w),format='("Region of interest: ",F7.2," (",I4,") "," to ",F7.2," (",I4,")")'
      print,center,center2,fwhm,area,format='("  Center: ",F7.2," (",F7.2,") ","  FWHM: ",F7.2,"  Area: ",F9.2)'
    endif
    result = [[result],[center,fwhm,area]]
  endfor

endif else begin

  plot,x,y,psym=10,_extra=_extra

  repeat begin

    cursor,x1,y1,/down
    cursor,x2,y2,/up

    m = !mouse

    if (m.button eq 1) then begin
      xs = [min([x1,x2]),max([x1,x2])]
      w = where(x ge xs[0] and x le xs[1],nw)
      if nw ge 2 then begin
        fitgauss2,x=x[w],y[w],fwhm,center,area,/quiet
        fitgauss2,x=w,y[w],fwhm2,center2,area2,/quiet
        print,xs[0],min(w),xs[1],max(w),format='("Region of interest: ",F7.2," (",I4,") "," to ",F7.2," (",I4,")")'
        print,center,center2,fwhm,area,format='("  Centroid: ",F7.2," (",F7.2,") ","  FWHM: ",F7.2,"  Area: ",F9.2)'
        result = [[result],[center,fwhm,area]]
      endif else begin
        temp = min(abs(x-x1),index)
        print,x1,index,format='("Bin sample: ",F7.2," (",I4,")")'
        print,x[index],y[index],format='("  Position: ",F7.2,"  Value: ",F7.2)'
      endelse
    endif

  endrep until (m.button eq 4)

endelse

if (n_elements(result) gt 3) then result = result[*,1:*]

end
