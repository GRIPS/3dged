Analysis code for GRIPS 3D-GeDs
===============================

Example workflow (starting with June 2014)
==================================

See the example workflow for data files prior to June 2014 for explanations of each step.
The difference with recent data files is that they always contain data from at least two ASICs,
and thus the parsed data are structures of arrays.

```
; Ba-133 data with ASIC 0 and 1, triggering channels are 0-56 and 1-4
parse,'data/2014_07_03_12_16_12_000.csv',adc,time,event=event ; contains ASIC 0 and 1

gap_rate,adc.asic_0,event.asic_0,/deadtime
gap_rate,adc.asic_1,event.asic_1,/deadtime ; same as ASIC 0 because both ASICs are read at the same time

; example non-triggering channels
gap_base,adc.asic_0,event.asic_0,50,yr=[1400,1600]
gap_base,adc.asic_1,event.asic_1,2,yr=[1500,1700]

list_0 = [50, 53, 56, 57, 59, 60, 62, 63]
make_spectra,adc.asic_0,time.asic_0,raw_0,cms_0,channels=list_0

list_1 = [1, 3, 4, 6, 7, 9, 12, 13, 27, 29, 34, 36, 38, 40, 44, 46, 50, 51, 53, 54, 56, 57, 59, 60, 62]
make_spectra,adc.asic_1,time.asic_1,raw_1,cms_1,channels=list_1

roi,cms_0[56,*],xr=[0,1000],/ylog
energy_0_56 = getgain([114,267,696,800],[0,81,303,356])
roi,cms_0[56,*],gain=energy_0_56,xr=[0,400],/ylog
; FWHM is 2.5 keV at the 81 keV line

roi,cms_1[4,*],xr=[0,1000],/ylog
energy_1_4 = getgain([99,259,705,814],[0,81,303,356])
roi,cms_1[4,*],gain=energy_1_4,xr=[0,400],/ylog
; FWHM is 2.8 keV at the 81 keV line
```

Example workflow (before June 2014)
===================================

Read in the data
----------------
```
parse,'data/2014_01_07_16_11_51_000.csv',adc,time,event=event,/swapshort
```
The `swapshort` keyword is needed to fix GSE files and compensate for a subsequent change in the time step.

Look for good channels
----------------------
```
gap_rate,adc,event,/deadtime
```
Here's the plot for the event rate as a function of the time between events, and also displays the minimal deadtime.
If detector events are independent, the data should be exponential.

```
gap_base,adc,event,35
gap_base,adc,event,35,/fit,params=params
```
The first command plots the post-conversion baseline oscillation for channel 35.  The second command makes the same
plot, but also fits the oscillation using a sinusoid with an exponential envelope.

```
corrplot,adc[21,*],adc[23,*],xrange=[1200,1600],yrange=[1200,1600],/xy
```
Here's how to check one channel against another.  The baseline/pedestal should be well correlated with a slope of 1.
If one channel varies by about half as much, chances are it is disconnected from the detector.

Produce spectra
---------------
```
list = [12, 13, 15, 16, 17, 18, 21, 22, 23, 25, 26, 27, 33, 35, 36, 37, 38,$
        40, 41, 42, 43, 45, 47, 51, 53, 55, 56, 57, 58, 60]
make_spectra,adc,time,raw,cms,channels=list
```
`raw` is the spectrum of unmodified ADC values, and `cms` is the common-mode-subtracted spectrum.  The common-mode level is calculated by averaging all of the channels with conversions, or just the ones in the list if it is provided.

Analyze spectra
---------------
```
roi,cms[35,*],xr=[0,1000]
```
`roi` is a crude interactive program.  Use left clicks to fit peaks and use a right click to exit out.  In this case,
the fits indicate that the pedestal (0 keV) is at ADC bin 92 and the 59.5 keV Am-241 line is at ADC bin 260.  This is
enough to get a calibration.
```
energy = getgain([92.,260.], [0,59.5])
roi,cms[35,*],gain=energy,xr=[0,70]
```
Now, when we fit the Am-241 line, we can get the FWHM in energy units.  In this case, it comes out to 2.5 keV.
