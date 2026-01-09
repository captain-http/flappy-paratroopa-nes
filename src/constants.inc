; Flappy Bird for NES - Constants

; Zero page variables (8.8 fixed-point)
bird_y_frac = $00       ; Bird Y position (fractional)
bird_y      = $01       ; Bird Y position (integer)
bird_vel_lo = $02       ; Bird Y velocity (fractional)
bird_vel_hi = $03       ; Bird Y velocity (integer, signed)
nmi_flag    = $04       ; Set by NMI, cleared by main loop

; Physics (8.8 fixed-point)
GRAVITY     = $40       ; ~0.25 pixels/frame² (floaty feel)

; Screen bounds
GROUND_Y    = 200       ; Ground level (bird stops here)
