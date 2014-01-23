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
;   adc     64xN array of raw ADC values (not actually used yet)
;   event   N array of event times in 50 MHz clock units
;   channel specific channel to look at (not actually used yet)
;   period  optional - plot vertical lines with a spacing in milliseconds
;   offset  optional - shift the above vertical lines by this many milliseconds
;   fit     keyword - perform a fit to get the oscillation period and offset
;           function is P[0]+P[1]*SIN(2*!PI*(X-P[2])/P[3])*EXP(-(X-P[2])/P[4])
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

pro gap_base,adc,event,channel,period=period,offset=offset,_extra=_extra,fit=fit,params=params

delta = (event-shift(event,1))[1:*]/5d4 ; milliseconds

x = histogram(delta,min=0,reverse_indices=r,bin=0.01)

y = x
for i=0,n_elements(x)-1 do y[i] = r[i] ne r[i+1] ? mean(adc[channel,r[r[i]:r[i+1]-1]+1]) : 0

dy = x
for i=0,n_elements(x)-1 do dy[i] = r[i] ne r[i+1] ? stddev(adc[channel,r[r[i]:r[i+1]-1]+1]) : 0

t = findgen(n_elements(x))*0.01

plot,t,y,xr=[0,10],$
  xtitle='Milliseconds since previous event',ytitle='Raw ADC',_extra=_extra

if keyword_set(fit) then begin
  index = min(where(y gt 0))
  yy = y[index:1000]
  dyy = dy[index:1000]
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
