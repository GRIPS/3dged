Analysis code for GRIPS 3D-GeDs
===============================

Sample workflow

Read in the data
----------------
```
parse,'data/2014_01_07_16_11_51_000.csv',adc,time,event=event,/swapshort
```
The `swapshort` keyword is needed to fix certain GSE files.

Look for good channels
----------------------
```
gap_base,adc,event,35
```
Here's how to plot the post-conversion baseline oscillation for channel 35.

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

Analyze spectra
---------------
```
roi,c51[35,*],xr=[0,1000]

```
`roi` is a crude interactive program.  Use left clicks to fit peaks and use a right click to exit out.
