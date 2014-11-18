; NAME: gap_base
;
; PURPOSE:
; Plots the baseline as a function of time since preceding event/conversion
; with a scale of 10 milliseconds.  The baseline is calculated by averaging
; the ADC values of all events corresponding to each time bin of gap time.
; This will produce "spikes" if there are conversions that include actual
; energy deposition, which is very likely if triggers are enabled, but also
; possible from background.
;
; INPUTS:
;   adc     64xN array of raw ADC values
;   event   N array of event times in ticks of 10 ns
;   channel specific channel to look at
;   period  optional - plot vertical lines with a spacing in milliseconds
;   offset  optional - shift the above vertical lines by this many milliseconds
;   fit     keyword - perform a fit to get the oscillation period and offset
;           function is P[0]+P[1]*SIN(2*!PI*(X-P[2])/P[3])*EXP(-(X-P[2])/P[4])
;   sumglitch   keyword - includes glitched events (normally excluded)
;   _extra  all other keywords are passed through to the plot call
;
; OUTPUTS:
;   params  optional - the fitted parameters
;           params[0] is the ADC value of the relaxed baseline
;           params[1] is the amplitude of the baseline oscillation
;           params[2] is the phase of the baseline oscillation
;           params[3] is the period of the baseline oscillation
;           params[4] is the e-folding time of the baseline relaxation
;
; HISTORY:
;   2014-01-14, AYS: initial release
;   2014-01-23, AYS: ignore zeros when fitting
;   2014-02-05, AYS: added rejection (default) and inclusion (optional) of glitched events
;   2014-07-15, AYS: switched timing to 10-ns ticks (100 MHz clock), shortened fit duration, remove missing conversions

pro gap_base,adc,event,channel,period=period,offset=offset,_extra=_extra,fit=fit,params=params,sumglitch=sumglitch

delta = (event-shift(event,1))[1:*]/1d5 ; milliseconds

z = (reform(adc))[channel,*]

; if glitched events are to be included, erase the sign bit
use = where(z LT 32768, nuse)
print,"Channel "+num2str(channel)+" is "+num2str(100-100.*nuse/n_elements(z))+"% glitched events"
if keyword_set(sumglitch) then begin
  z = z and 32767
endif else begin
  if nuse GT 0 then begin
    z = z[use]
    delta = delta[use]
  endif
endelse

;Remove missing conversions (from an intermittent connection or early abort)
use = where(z NE 32767, nuse)
print,"Channel "+num2str(channel)+" is "+num2str(100-100.*nuse/n_elements(z))+"% missing conversions"
if nuse GT 0 then begin
  z = z[use]
  delta = delta[use]
endif

x = histogram(delta,min=0,max=1000,reverse_indices=r,bin=0.01)

y = x
for i=0,n_elements(x)-1 do y[i] = r[i] ne r[i+1] ? mean(z[r[r[i]:r[i+1]-1]+1]) : 0

dy = x
for i=0,n_elements(x)-1 do dy[i] = r[i] ne r[i+1] ? stddev(z[r[r[i]:r[i+1]-1]+1]) : 0

t = findgen(n_elements(x))*0.01

plot,t,y,xr=[0,10],$
  xtitle='Milliseconds since previous event',ytitle='Raw ADC',_extra=_extra

if keyword_set(fit) then begin
  index = min(where(y gt 0))
  yy = y[index:400]
  dyy = dy[index:400]
  use = where(yy gt 0 and dyy gt 0)
  yy = yy[use]
  dyy = dyy[use]
  tt = (t[index:1000])[use]

  start = [1300., 150., 0.2, 1.07, 3.5]
  pp = mpfitexpr('P[0]+P[1]*SIN(2*!PI*(X-P[2])/P[3])*EXP(-(X-P[2])/P[4])', tt, yy, dyy, start, /quiet)
  if (finite(pp))[0] then begin
    oplot,tt,pp[0]+pp[1]*sin(2*!pi*(tt-pp[2])/pp[3])*exp(-(tt-pp[2])/pp[4]),color=6
    params = pp
  endif else params = [0, 0, 0, 1, 1]
endif

if keyword_set(period) then begin
  offset = fcheck(offset, 0)
  for i=0,15 do oplot,i*period*[1,1]+offset,!y.crange,color=3,linestyle=1
endif

end
