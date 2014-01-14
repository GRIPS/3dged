; NAME: corrplot
;
; PURPOSE:
; Plots a correlation plot between two arrays
;
; INPUTS:
;   x       the first array
;   y       the second array
;   xrange  optional - specifies the range to plot for x (highly recommended)
;   yrange  optional - specifies the range to plot for y (highly recommended)
;   xy      keyword - plots the y=x line for visual comparison
;   _extra  all other keywords are passed through to the plot call
;
; OUTPUTS:
;
; HISTORY:
;   2014-01-14, AYS: initial release

pro corrplot, x, y, xrange=xrange, yrange=yrange, xy=xy, _extra=_extra

xrange = fcheck(xrange, [min(x), max(x)])
yrange = fcheck(yrange, [min(y), max(y)])

h = hist_2d(x, y, min1 = 0 < xrange[0], max1 = xrange[1], min2 = 0 < yrange[0], max2 = yrange[1])

loadct,0

contour, h, xrange=xrange, yrange=yrange, /fill, levels=10^(findgen(31)/30*alog10(max(h))), _extra=_extra

if keyword_set(xy) then begin
  hsi_linecolors
  range = [min([!x.crange[0],!y.crange[0]]), max([!x.crange[1],!y.crange[1]])]
  oplot, range, range, linestyle=1, color=6
endif

end
