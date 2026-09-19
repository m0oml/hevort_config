; ======================================================================================
; cancel.g — run when a print is CANCELLED from the paused state (M0 while paused).
; RRF runs this instead of stop.g when it exists. Since 3.5.0beta1 it runs whether
; or not the axes are homed, so every move here is guarded.
; Does NOT drop the PLC safety relay — only a genuine stop/estop does that.
; ======================================================================================
M106 P1 S0                                       ; Part fan off - nothing else stops it
M104 S0                                          ; Nozzle off
M140 S0                                          ; Bed: S0 first, or the active target stays at the old value
M140 S-273.1                                     ; Bed fully off
set global.chamberSP = 0                         ; Chamber off (tenths degC) - the slicer end gcode never runs on a cancel

; --- Drop the bed clear of the part ---------------------------------------------
; Z200 for a small print, otherwise 100mm below the nozzle, capped at Z max.
if move.axes[2].homed
    var zClear = {max(200, move.axes[2].machinePosition + 100)}
    if var.zClear > move.axes[2].max
        set var.zClear = move.axes[2].max
    G90                                          ; Absolute positioning
    G1 Z{var.zClear} F1000                       ; Lower the bed away from the part

M118 P0 S"[CANCEL] print cancelled, bed lowered, heaters and chamber off"
