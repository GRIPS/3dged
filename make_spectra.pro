; NAME: make_spectra
;
; PURPOSE:
; Creates spectra, both raw and common-mode-subtracted, from the arrays produced by parse.pro
; The units of the spectra are counts
; The common-mode level is determined by the average of all other channels (irrespective of triggers)
;
; INPUTS:
;   adc       64xN array of raw ADC values
;   time      64xN array of trigger times in 50 MHz clock units
;   maxraw    optional - the maximum raw ADC bin in the spectra
;   maxcms    optional - the maximum common-mode-subtracted ADC bin in the spectra
;   channels  optional - list of channels to use for common-mode subtraction
;
; OUTPUTS:
;   raw       64xM array of spectra in raw ADC bins (only the first M bins, where M==maxraw)
;   cms       64xL array of spectra in common-mode-subtracted ADC bins (starts at -100, L==maxcms+100)
;
; HISTORY:
;   2013-07-03: AYS, initial release
;   2013-12-05: AYS, added channels keyword

pro make_spectra,adc,time,raw,cms,maxraw=maxraw,maxcms=maxcms,channels=channels

maxraw = fcheck(maxraw,5000)
maxcms = fcheck(maxcms,3000)

raw = fltarr(64,maxraw)
cms = fltarr(64,maxcms+100)

;Default is to use the channels that have any signal whatsoever
channels = fcheck(channels, where(adc[*,0] ne 65535))

for i=0,n_elements(channels)-1 do begin
  raw[channels[i],*] = histogram(adc[channels[i],*],bin=1,min=0,max=maxraw-1)
  cms[channels[i],*] = histogram(adc[channels[i],*]-1.*(total(adc[channels,*],1)-adc[channels[i],*])/(n_elements(channels)-1),bin=1,min=-100,max=maxcms-1)
endfor

end
