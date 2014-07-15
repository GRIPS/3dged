; NAME: parse
;
; PURPOSE:
; Parses a CSV file (ignores the common-mode subtraction columns)
;
; INPUTS:
;   filename  name of the CSV file
;   use_trigger_flag  keyword - uses the trigger flag to mask out stale timestamps for channels that didn't actually trigger
;   swapshort  keyword - fixes a bug in GSE output where the event timestamp has swapped shorts (2 bytes)
;   oldtime   keyword - input file has old time step of 20 ns rather than new time step of 10 ns (automatically true if swapshort is true)
;
; OUTPUTS:
;   data      64xN array of raw ADC values
;   time      64xN array of trigger times in ticks of 10 ns
;   event     optional - N array of event times in ticks of 10 ns
;   index     optional - N array of incrementing counter
;   *** If there are multiple ASICs in the file, then all the above are structures! ***
;
; HISTORY:
;   2013-07-03, AYS: initial release
;   2013-07-16, AYS: parsing of new format, added output of incrementing counter
;   2013-07-24, AYS: added first-generation parsing by ASIC ID
;   2013-07-30, AYS: fixed bug with older formats
;   2013-07-31, AYS: fixed wrapping of incrementing counter at 8192, added keyword use_trigger_flag
;   2013-12-06, AYS: added swapshort keyword
;   2014-02-05, AYS: added quick estimate of the duration of the data set
;   2014-07-15, AYS: switched timing to 10-ns ticks (100 MHz clock), added oldtime keyword for older files


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


pro parse, filename, data, time, event=event, index=index, use_trigger_flag=use_trigger_flag, swapshort=swapshort, oldtime=oldtime

if keyword_set(swapshort) then oldtime = 1

csvfile = (file_search(filename, count=count))[0]
if count eq 0 then begin
  print,"No such file"
  return
endif

print, "Parsing ", csvfile

data = read_csv(csvfile, count=count, header=header)

;To be safe, skips last line
trigger_flag = bytarr(64, count-1)
trigger_time = ulon64arr(64, count-1)
adc = uintarr(64, count-1)

;Starting with Feb 22 data, there has been an added column
format_b = header[66] eq "Event"

;Starting with Jul 16 data, there are two more columns at the start
format_c = header[0] eq "ASIC Board ID"

for i=0,63 do begin
  trigger_flag[i,*] = data.(i+1+2*format_c)[0:count-2]

  trigger_time[i,*] = ulong(data.(i+65+1+format_b+3*format_c)[0:count-2])

  if keyword_set(use_trigger_flag) then trigger_time[i,*] *= trigger_flag[i,*]

  adc[i,*] = data.(i+65+65+2+format_b+3*format_c)[0:count-2]
endfor

if format_b or format_c then begin
  event_raw = ulong64(ulong(data.(65+format_b+3*format_c)[0:count-2]))
  if keyword_set(swapshort) then event_raw = (event_raw mod 2l^16)*(2l^16) + event_raw/2l^16
endif else begin
  ;This may not work for force-triggered data
  event_raw = ulon64arr(count-1)
  for row=0,count-2 do begin
    temp = where(trigger_time[*,row] gt 0)
    event_raw[row] = min(trigger_time[temp,row])
  endfor
endelse

nasics = 1
index_raw = -1

if format_c then begin
  asic = data.(0)[0:count-2]
  index_raw = data.(1)[0:count-2]
  list_asics = asic[uniq(asic, sort(asic))]
  nasics = n_elements(list_asics)
endif

if nasics gt 1 then begin
  use = where(asic eq list_asics[nasics-1])
  data = create_struct('asic_'+num2str(list_asics[nasics-1]),adc[*,use])
  index = create_struct('asic_'+num2str(list_asics[nasics-1]),index_raw[use])
  event = create_struct('asic_'+num2str(list_asics[nasics-1]),event_raw[use])
  time = create_struct('asic_'+num2str(list_asics[nasics-1]),trigger_time[*,use])
  for i=nasics-2,0,-1 do begin
    use = where(asic eq list_asics[i])
    data = create_struct('asic_'+num2str(list_asics[i]),adc[*,use],data)
    index = create_struct('asic_'+num2str(list_asics[i]),index_raw[use],index)
    event = create_struct('asic_'+num2str(list_asics[i]),event_raw[use],event)
    time = create_struct('asic_'+num2str(list_asics[i]),trigger_time[*,use],time)
  endfor
  for i=0,nasics-1 do begin
    if keyword_set(oldtime) then begin
      for j=0,63 do time.(i)[j,*] = 2*unwrap(event.(i),time.(i)[j,*])*(time.(i)[j,*] ne 0)
      event.(i) = 2*unwrap(event.(i),event.(i))
      index.(i) = unwrap(index.(i),index.(i),step=8192)
    endif else begin
      for j=0,63 do begin
        event.(i) = unwrap(event.(i),event.(i))
        to_modify = where(time.(i)[j,*] gt 0)
        time.(i)[j,to_modify] += event.(i)[to_modify]
      endfor
    endelse
    print,"ASIC "+num2str(list_asics[i])+", duration of "+num2str((max(event.(i))-min(event.(i)))*1d-8)+" seconds"
  endfor
endif else begin
  data = adc
  index = index_raw

  ;Corrects for clock wrapping
  ;jumps = where((event lt shift(event,1))[1:*],njumps)+1
  ;if njumps gt 0 then begin
  ;  offset = ulon64arr(count-1)
  ;  for j=0,njumps-1 do offset[jumps[j]:*] += ulong64(2)^32
  ;  event += offset
  ;  for i=0,63 do trigger_time[i,*] += offset*(trigger_time[i,*] ne 0)
  ;endif

  time = trigger_time
  for i=0,63 do time[i,*] = 2*unwrap(event_raw,time[i,*])*(time[i,*] ne 0)
  event = 2*unwrap(event_raw,event_raw)

  print,"Single ASIC, duration of "+num2str((max(event)-min(event))*1d-8)+" seconds"

endelse

end
