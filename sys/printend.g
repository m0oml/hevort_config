; ======================================================================================
; printend.g — called from the slicer end G-code: M98 P"0:/sys/printend.g"
; ======================================================================================
; Chamber is turned OFF here. daemon.g writes global.chamberSP to the PLC on its
; 5s poll, so clearing the setpoint is all that is needed.
; ======================================================================================
; Drop the bed clear of the part: Z200 for a small print, otherwise 100mm below
; the nozzle, capped at Z max. Same rule as stop.g and cancel.g.
if move.axes[2].homed
    var zClear = {max(200, move.axes[2].machinePosition + 100)}
    if var.zClear > move.axes[2].max
        set var.zClear = move.axes[2].max
    G90                                                 ; Absolute positioning
    G1 Z{var.zClear} F1000                              ; Lower the bed away from the part

M104 S0                                                 ; Nozzle off
M140 S0                                                 ; Bed: S0 first, or the active target stays at the old value
M140 S-273.1                                            ; Bed fully off
M106 P1 S0                                              ; Part fan off (enclosure/pump/bay fans stay thermostatic)
set global.chamberSP = 0                                ; Chamber off (tenths degC)

if move.axes[0].homed && move.axes[1].homed
    G1 X200 Y200 F9000                                  ; Park at bed centre
    M400                                                ; Let the park move finish before dropping the motors
M18                                                     ; Motors off - never leave them holding bed strain
M118 P0 S"[END] print finished, heaters off, chamber off"
