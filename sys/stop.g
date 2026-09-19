; ======================================================================================
; stop.g — called by M0 (end of print / stop)
; Normal end of print — does NOT drop PLC safety relay
; Chamber continues heating if SP is set (e.g. post-print soak)
; Chamber setpoint management handled by printend.g
; A print CANCELLED from paused state runs cancel.g instead of this file.
; ======================================================================================
; Intentionally does not drop OUT8 — only genuine stop/estop should do that
M106 P1 S0                                       ; Part fan off - nothing else stops it on M0

; --- Drop the bed clear of the part ---------------------------------------------
; Z200 for a small print, otherwise 100mm below the nozzle, capped at Z max.
; Skipped entirely if Z is not homed - there is no reference to move against.
if move.axes[2].homed
    var zClear = {max(200, move.axes[2].machinePosition + 100)}
    if var.zClear > move.axes[2].max
        set var.zClear = move.axes[2].max
    G90                                          ; Absolute positioning
    G1 Z{var.zClear} F1000                       ; Lower the bed away from the part
