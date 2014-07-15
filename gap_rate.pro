; NAME: gap_rate
;
; PURPOSE:
; Plots the event rate as a function of time since preceding event/conversion
; with a scale of 10 milliseconds
;
; INPUTS:
;   adc     64xN array of raw ADC values (not actually used yet)
;   event   N array of event times in ticks of 10 ns
;   channel specific channel to look at (not actually used yet)
;   deadtime    keyword - displays the deadtime
;   _extra  all other keywords are passed through to the plot call
;
; OUTPUTS:
;
; HISTORY:
;   2014-01-14, AYS: initial release
;   2014-07-15, AYS: switched timing to 10-ns ticks (100 MHz clock)

pro gap_rate,adc,event,channel,deadtime=deadtime,_extra=_extra

delta = (event-shift(event,1))[1:*]/1d5 ; milliseconds

x = histogram(delta,min=0,bin=0.01)

yrange = fcheck(yrange, [1,max(x)])

plot,findgen(n_elements(x))*0.01,x,xr=[0,10],yrange=yrange,/ylog,$
  xtitle='Milliseconds since previous event',ytitle='Counts',_extra=_extra

if keyword_set(deadtime) then begin
  z = min(delta)
  oplot,z*[1,1],10^!y.crange,color=3,linestyle=1
  xyouts,total(!x.crange*[0.4,0.6]),10^total(!y.crange*[0.2,0.8]),'Deadtime: '+num2str(z*1000)+'us'
endif

end
