; ======================================================================================
; Pause Macro - Retracts filament, lifts Z, parks at origin
; ======================================================================================

M83                                              ; Relative extruder moves
set global.pausedFanSpeed = fans[1].requestedValue   ; Remember part fan speed
M106 P1 S0                                       ; Part fan off while paused - nothing else stops it
G1 E-10 F3600                                    ; Retract 10mm
G91                                              ; Relative positioning
G1 Z5 F360                                       ; Lift Z by 5mm
G90                                              ; Absolute positioning
G1 X0 Y0 F6000                                  ; Park at origin
