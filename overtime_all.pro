; NAME: overtime_all
;
; PURPOSE:
; Plots the variation of triggered ADC conversions over time
; Currently only looks at the first two ASICs, and assumes they are ASIC0 and ASIC1
; Typically used on don't-wait-for-trigger data, where all channels "trigger"
;
; INPUTS:
;   adc     structure of 64xN arrays of raw ADC values
;   time    structure of 64xN arrays of trigger times in ticks of 10 ns
;   duration    duration in ms to plot (defaults to 300 ms)

pro overtime_all,adc,time,duration

duration = fcheck(duration, 300)

;minimum number of triggers before deeming a channel live
min = 10

list0 = where(total(time.(0) ne 0, 2) gt min, n0)
list1 = where(total(time.(1) ne 0, 2) gt min, n1)
print, "First ASIC: "+num2str(n0)+" channels"
print, "Second ASIC: "+num2str(n1)+" channels"

; For A/B harness, 8 on ASIC0 and 31 on ASIC1 for the old bonding diagram
; channel 35 is not supposed to be on this harness?

print,"*** Using pause.pro: press space/enter to progress, press 'E' to exit early"

;plot ASIC0
if n0 gt 0 then begin
  for i=0,ceil(n_elements(list0)/4.)-1 do begin
    !p.multi=[0,1,4]
    for j=0,3 do begin
      k = i*4+j
      if k LT n_elements(list0) then begin
        plot,time.asic_0[list0[k],*]*1e-5,adc.asic_0[list0[k],*],$
          xr=min(time.asic_0[list0[k],*]*1e-5)+[0,duration],/xs,xtitle='Milliseconds',$
          yr=mean(adc.asic_0[list0[k],*])+[-100,100],/ys,ytitle='ADC bin',$
          title='ASIC0-'+num2str(list0[k]),charsize=2
      endif
    endfor
    !p.multi=0
    if k LT n_elements(list0)-1 then pause
  endfor
  if k GE n_elements(list0)-1 then pause
endif

;plot ASIC1
if n1 gt 0 then begin
  for i=0,ceil(n_elements(list1)/4.)-1 do begin
    !p.multi=[0,1,4]
    for j=0,3 do begin
      k = i*4+j
      if k LT n_elements(list1) then begin
        plot,time.asic_1[list1[k],*]*1e-5,adc.asic_1[list1[k],*],$
          xr=min(time.asic_1[list1[k],*]*1e-5)+[0,duration],/xs,xtitle='Milliseconds',$
          yr=mean(adc.asic_1[list1[k],*])+[-100,100],/ys,ytitle='ADC bin',$
          title='ASIC1-'+num2str(list1[k]),charsize=2
      endif
    endfor
    !p.multi=0
    if k LT n_elements(list1)-1 then pause
  endfor
endif

print,"*** All triggering channels plotted"

end
