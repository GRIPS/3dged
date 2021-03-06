; NAME: parse2
;
; PURPOSE:
; Parses a CSV file (the more efficient "compressed" format)
;
; INPUTS:
;   filename  name of the CSV file
;   lv        keyword - only look at LV-side ASICs (0-3), recommended for non-coincident data
;   hv        keyword - only look at HV-side ASICs (4-7), recommended for non-coincident data
;
; OUTPUTS:
;   adc       8x64xN array of raw ADC values
;   time      8x64xN array of trigger times in ticks of 10 ns
;   event     2xN array of event times in ticks of 10 ns
;   id        optional - N array of incrementing counter
;
; HISTORY:
;   2014-11-18, AYS: initial release
;   2014-11-19, AYS: can now read files where ASIC channels (columns) have been removed
;   2014-12-10, AYS: fixed some bugs and added keywords to allow for looking at just one side (e.g., for non-coincident data)


;Utility function to unwrap a wrapping clock
;Decreases in clock1 are interpreted as an implicit increment of size "step"
;clock2 is adjusted accordingly and returned as output
function unwrap, clock1, clock2, step = step

step = fcheck(step,ulong64(2)^32)

jumps = where((clock1 lt shift(clock1,1))[1:*],njumps)+1
if njumps gt 0 then begin
  offset = ulon64arr(n_elements(clock1))
  for j=0,njumps-1 do offset[jumps[j]:*] += step
  return,clock2 + offset
endif else return,clock2

end


;Utility function to convert a 64-bit integer to the binary representation
function decode64, in

out = bytarr(64, n_elements(in))
for i=0,63 do out[63-i, *] = (in and ulong64(2)^i)/ulong64(2)^i
return, out

end


pro parse2, filename, adc, time, event, id=id, lv=lv, hv=hv

csvfile = (file_search(filename, count=count))[0]
if count eq 0 then begin
  print,"No such file"
  return
endif

print, "Parsing ", csvfile

data = read_csv(csvfile, count=lines, header=header)

xasic = byte(data.(0))
xid = ulong(data.(1))

;Event timestamp may not auto-detect as 64-bit integers
if data_type(data.(3)) eq 3 then begin ;detected as signed long
  xevent = ulong64(ulong(data.(3)))
endif else begin
  xevent = ulong64(data.(3))
endelse

;Event IDs and timestamps need to be unwrapped on a per-ASIC basis
for iasic=0,7 do begin
  ;TODO: can combine with later detection of working ASICs
  use = where(xasic eq iasic, nuse)
  if nuse gt 0 then begin
    temp = ulong(unwrap(xid[use], xid[use], step=65536))
    xid[use] = temp
    if data_type(data.(3)) eq 3 then begin
      temp = unwrap(xevent[use], xevent[use])
      xevent[use] = temp
    endif
  endif
endfor

xtrigger = decode64(data.(2))

xtime = ulon64arr(64, lines)
left = (where(header eq '0'))[0]
right = (where(header eq '63'))[0]
for i=left,right do begin
  xtime[uint(header[i]),*] = data.(i)
endfor

xadc = uintarr(64, lines)
left = (reverse(where(header eq '0')))[0]
right = (reverse(where(header eq '63')))[0]
for i=left,right do begin
  xadc[uint(header[i]),*] = data.(i)
endfor

working = where(histogram(xasic, min=0, max=7))
print, "  Detected ASICs:", working, format='(A, 8I2)'
if keyword_set(lv) and not keyword_set(hv) then begin
  working = working[where(working le 3)]
  print, "  Using just LV ASICs:", working, format='(A, 4I2)'
  use = where(xasic le 3)
  xasic = xasic[use]
  xid = xid[use]
  xtrigger = xtrigger[*, use]
  xevent = xevent[use]
  xtime = xtime[*, use]
  xadc = xadc[*, use]
endif else if keyword_set(hv) and not keyword_set(lv) then begin
  working = working[where(working ge 4)]
  print, "  Using just HV ASICs:", working, format='(A, 4I2)'
  use = where(xasic ge 4)
  xasic = xasic[use]
  xid = xid[use]
  xtrigger = xtrigger[*, use]
  xevent = xevent[use]
  xtime = xtime[*, use]
  xadc = xadc[*, use]
endif

temp = xid[sort(xid)]
id = temp[uniq(temp)]
num = n_elements(id)
keep = bytarr(num)+1
keep[num-1] = 0 ;remove the last event since it's likely corrupted

adc = uintarr(8, 64, num)
time = ulon64arr(8, 64, num)
event = ulon64arr(2, num)

for k=0l,num-1 do begin
  set = where(xid eq id[k], found)
  if found eq n_elements(working) then begin
    for l=0,found-1 do begin
      iline = set[l]
      iasic = xasic[iline]
      adc[iasic, *, k] = xadc[*, iline]
      event[iasic/4, k] = xevent[iline]

      time[iasic, *, k] = xtime[*, iline]
      ;Use the top 64-16=48 bits of the event time for the trigger time
      ;TODO: detect and fix clock rollovers
      to_modify = where(xtrigger[*, iline], ntriggers)
      if ntriggers gt 0 then time[iasic, to_modify, k] += event[iasic/4, k] and not ulong64(65535)
    endfor
  endif else begin
    print,"Warning: event " + num2str(id[k]) + " is missing data from some ASICs"
    keep[k] = 0
  endelse
endfor

;Remove questionable events
num = total(keep)
id = id[where(keep)]
adc = adc[*, *, where(keep)]
time = time[*, *, where(keep)]
event = event[*, where(keep)]

print,"  " + num2str(long(num)) + " complete events over " + num2str((event[0, num-1] - event[0, 0])*1d-8) + " seconds"

print,"  Conversions: " + num2str(long(total(adc gt 0 and adc lt 32767))) + " valid and " + num2str(long(total(adc ge 32768))) + " glitched"

end
