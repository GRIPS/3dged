; NAME: parse2
;
; PURPOSE:
; Parses a CSV file (the more efficient "compressed" format)
;
; INPUTS:
;   filename  name of the CSV file
;
; OUTPUTS:
;   adc       8x64xN array of raw ADC values
;   time      8x64xN array of trigger times in ticks of 10 ns
;   event     2xN array of event times in ticks of 10 ns
;   id        optional - N array of incrementing counter
;
; HISTORY:
;   2014-11-18, AYS: initial release


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


pro parse2, filename, adc, time, event, id=id

csvfile = (file_search(filename, count=count))[0]
if count eq 0 then begin
  print,"No such file"
  return
endif

print, "Parsing ", csvfile

data = read_csv(csvfile, count=lines, header=header)

xasic = byte(data.(0))
xid = ulong(data.(1)) ;TODO: should this be unwrapped?
xtrigger = decode64(data.(2))
xevent = ulong64(ulong(data.(3))) ;TODO: should this be unwrapped?

xtime = ulon64arr(64, lines)
xadc = uintarr(64, lines)
for i=0,63 do begin
  xtime[i,*] = data.(i+5)
  ;Skip over REF channel
  xadc[i,*] = data.(i+71)
endfor

working = where(histogram(xasic, min=0, max=7))
print, "Detected ASICs:", working

id = xid[uniq(xid)]
num = n_elements(id)
keep = bytarr(num)+1
keep[num-1] = 0 ;remove the last event since it's likely corrupted

adc = uintarr(8, 64, num)
time = ulon64arr(8, 64, num)
event = ulon64arr(2, num)

for k=0l,num-1 do begin
  for i=0,n_elements(working)-1 do begin
    loc = where(xasic eq working[i] and xid eq id[k], found)
    if found gt 0 then begin
      if found gt 1 then begin
        print, "Warning: ID rollover not fixed!"
        loc = loc[0]
      endif
      adc[i, *, k] = xadc[*, loc]
      event[i/4, k] = xevent[loc]

      time[i, *, k] = xtime[*, loc]
      ;Use the top 64-16=48 bits of the event time for the trigger time
      ;TODO: detect and fix clock rollovers
      to_modify = where(xtrigger[*, loc])
      time[i, to_modify, k] += event[i/4, k] and not ulong64(65535)
    endif else begin
      print,"Warning: event " + num2str(id[k]) + " is missing data from ASIC " + num2str(working[i])
      keep[k] = 0
    endelse
  endfor
endfor

;Remove questionable events
num = total(keep)
id = id[where(keep)]
adc = adc[*, *, where(keep)]
time = time[*, *, where(keep)]
event = event[*, where(keep)]

print,num2str(long(num)) + " events over " + num2str((event[0, num-1] - event[0, 0])*1d-8) + " seconds"

print,"Normal conversions: " + num2str(long(total(adc gt 0 and adc lt 32768)))
print,"Glitched conversions: " + num2str(long(total(adc ge 32768)))

end
