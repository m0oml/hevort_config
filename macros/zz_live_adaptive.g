var haveModel = true
var meshFile = "x"
if !move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed
    M98 P"0:/sys/homeall.g"
if var.haveModel
    var x0 = {max(132.5 - 10, 10)}
    var x1 = {min(132.5 + 135 + 10, 390)}
    var y0 = {max(147 - 10, 16)}
    var y1 = {min(147 + 106 + 10, 384)}
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
    set var.meshFile = {"adaptive " ^ var.nx ^ "x" ^ var.ny}
    M118 P0 S{"[START] adaptive mesh " ^ var.nx ^ "x" ^ var.ny ^ " over X" ^ var.x0 ^ ":" ^ var.x1 ^ " Y" ^ var.y0 ^ ":" ^ var.y1 ^ ", mean " ^ move.compensation.meshDeviation.mean ^ "mm, deviation " ^ move.compensation.meshDeviation.deviation ^ "mm"}
M118 P0 S{"TESTDONE " ^ var.meshFile}
M561
