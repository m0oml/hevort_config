; ======================================================================================
; printstart.g — called from the slicer start G-code with parameters
; ======================================================================================
; Slicer start block (preFlight / PrusaSlicer placeholders):
;   M140 S0                     ; both zeros suppress the slicer's auto-inserted
;   M104 S0                     ; heat commands - this macro owns the heaters
;   M98 P"0:/sys/printstart.g" B{first_layer_bed_temperature[0]} C{min(chamber_temperature[0], 75)} T{first_layer_temperature[0]} L{first_layer_print_min[0]} F{first_layer_print_min[1]} W{first_layer_print_size[0]} D{first_layer_print_size[1]}
;
; Parameters:
;   B = first layer BED temperature, degC          (required)
;   C = CHAMBER target, degC, under 40 = off       (required)
;   T = first layer NOZZLE temperature, degC       (required)
;   P = probing nozzle temperature, default 150
;   L = first layer footprint min X, mm            (optional)
;   F = first layer footprint min Y, mm            (optional)
;   W = first layer footprint size X, mm           (optional)
;   D = first layer footprint size Y, mm           (optional)
;
; L/F/W/D keep the purge line clear of the model and size the bed mesh. Without
; them the purge falls back to the old fixed X10 Y6 and the WHOLE bed is meshed
; (7x7), so an old profile or a hand-sent M98 still works.
; G32 runs on EVERY print regardless.
;
; ORDER MATTERS. The chamber and the bed both reach temperature BEFORE the Z
; datum is probed - the datum moves 10.7um per degC of chamber air.
; ======================================================================================
if !exists(param.B) || !exists(param.C) || !exists(param.T)
    abort "printstart.g: needs B<bed> C<chamber> T<nozzle> - check the slicer start G-code"
var probeTemp = {exists(param.P) ? param.P : 150}
var haveModel = {exists(param.L) && exists(param.F) && exists(param.W) && exists(param.D)}

G21                                                    ; mm
G90                                                     ; Absolute XYZ
M83                                                     ; Relative E
M568 P0 R0 S0                                           ; Zero T0 temps so tpost0.g's M116 has no stale setpoint to wait for
T0                                                      ; Select tool
M140 S{param.B}                                         ; Bed on, no wait - it helps heat the chamber

if param.C >= 40
    M98 P"0:/macros/chamber_heat.g" S{param.C}          ; Chamber via PLC macro. Blocks until within 2C of target.

M190 S{param.B}                                         ; Wait for bed - 10kg granite, slow
M568 P0 R{var.probeTemp} S{param.T} A1                  ; Standby = probe temp, active = print temp. Probe temp softens residue and won't ooze - the nozzle IS the probe
M116 H1                                                 ; Wait for the hotend at standby

G32                                                     ; ALWAYS tram at temperature - the time is trivial against bed heat and cool
if result != 0                                          ; (bed.g homes itself if needed and ends with the centre G30 datum)
    abort "printstart.g: G32 failed - bed not trammed"
G1 Z5 F600                                              ; Lift straight away - never leave a hot nozzle sat on the bed

; Bed compensation. The bed is meshed HERE, at the temperature the print will
; actually run at, over just the area the part covers: footprint + 10mm margin,
; clamped to mesh.g's proven reach (X10:390 Y16:384), points per axis =
; round(span/55)+1 clamped to 2..7. No stored maps are loaded - they carry the
; thermal state they were taken in. With no footprint the whole bed is meshed.
var fpL = {var.haveModel ? param.L : 0}
var fpF = {var.haveModel ? param.F : 0}
var fpW = {var.haveModel ? param.W : 400}
var fpD = {var.haveModel ? param.D : 400}
var x0 = {max(var.fpL - 10, 10)}
var x1 = {min(var.fpL + var.fpW + 10, 390)}
var y0 = {max(var.fpF - 10, 16)}
var y1 = {min(var.fpF + var.fpD + 10, 384)}
var nx = {min(max(floor((var.x1 - var.x0) / 55 + 0.5) + 1, 2), 7)}
var ny = {min(max(floor((var.y1 - var.y0) / 55 + 0.5) + 1, 2), 7)}
M557 X{var.x0, var.x1} Y{var.y0, var.y1} P{var.nx, var.ny}     ; comma-list form: X{a}:{b} is rejected on 3.7.0-rc.1 (tested 25/09/2026)
M561                                                ; Never mesh on top of a mesh
M558 K0 H5:2 F450:450 T12000 A8 S0.02               ; Normal probe settings, as mesh.g restates them
G31 P500 X0 Y0 Z{global.trigZ}                      ; M558 wipes the trigger height - re-issue it
M17 Z                                               ; Enable Z, releasing brakes
G4 P200                                             ; Brake release delay, as mesh.g
G1 Z5 F1000                                         ; Lift to dive height before the first travel
G29 S0                                              ; Probe the grid, activate, save to 0:/sys/heightmap.csv
if result != 0
    M561                                            ; Do not leave a partial transform active
    abort "printstart.g: adaptive mesh failed"
G1 X200 Y200 F9000                                  ; Bed centre - as mesh.g, re-datum there after meshing
G30                                                 ; Re-set Z0 datum at bed centre
if result != 0
    abort "printstart.g: centre G30 failed after mesh - Z datum not set"
G1 Z5 F600                                          ; Lift straight away - never leave a hot nozzle sat on the bed
M118 P0 S{"[START] adaptive mesh " ^ var.nx ^ "x" ^ var.ny ^ " over X" ^ var.x0 ^ ":" ^ var.x1 ^ " Y" ^ var.y0 ^ ":" ^ var.y1 ^ ", mean " ^ move.compensation.meshDeviation.mean ^ "mm, deviation " ^ move.compensation.meshDeviation.deviation ^ "mm"}

; --- Purge line, kept clear of the model ---------------------------------------
; Default is the old fixed line along the front edge. With a footprint, put it
; 6mm in front of the part, or 6mm behind it when the part starts near the front
; edge. Line geometry is KAMP's: 1mm of filament per 1mm of travel, which gives
; a 3.0mm wide by 0.8mm tall bead (1.75mm filament = 2.405mm2 per mm of travel).
var purgeY = 6
var purgeX = 10
var doPurge = true
if var.haveModel
    if param.F >= 12
        set var.purgeY = {param.F - 6}
    elif {param.F + param.D + 6} <= 395
        set var.purgeY = {param.F + param.D + 6}
    else
        set var.doPurge = false                         ; Part spans front to back - nowhere to purge

; Park clear of the bed edge while the nozzle comes to temperature, so ooze
; never lands on the model. Without a footprint there is no safe spot near the
; part, so use the front-left corner.
if var.doPurge
    G1 X{max(var.purgeX - 5, 5)} Y{max(var.purgeY - 5, 5)} F12000
else
    G1 X5 Y5 F12000                                     ; No purge - still never heat over the model
M568 P0 A2                                              ; Active temp, reached at the park and never over the model
M116 H1                                                 ; Wait for print temp
if var.doPurge
    G1 X{var.purgeX} Y{var.purgeY} F12000               ; To purge start
    G1 Z0.8 F600                                        ; KAMP purge height
    G1 X{var.purgeX + 30} E30 F300                      ; Fat line, 30mm, 72mm3 at 12mm3/s
    G1 X{var.purgeX + 50} F12000                        ; Wipe off, 20mm clear
    G1 Z1.6 F600                                        ; Z-hop, 2x purge height
else
    M118 P0 S"[START] purge SKIPPED - model leaves no clear strip"

M118 P0 S{"[START] bed " ^ param.B ^ "C, chamber " ^ param.C ^ "C, nozzle " ^ param.T ^ "C, purge " ^ var.doPurge ^ ", mesh " ^ var.nx ^ "x" ^ var.ny}
