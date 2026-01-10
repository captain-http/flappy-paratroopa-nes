; Flappy Bird for NES - Constants

; Zero page variables (8.8 fixed-point)
bird_y_frac = $00       ; Bird Y position (fractional)
bird_y      = $01       ; Bird Y position (integer)
bird_vel_lo = $02       ; Bird Y velocity (fractional)
bird_vel_hi = $03       ; Bird Y velocity (integer, signed)
nmi_flag    = $04       ; Set by NMI, cleared by main loop

; Controller variables
buttons     = $05       ; Current button state
buttons_old = $06       ; Previous frame buttons
buttons_new = $07       ; Newly pressed this frame

; Scroll variables
scroll_x    = $08       ; X scroll position (0-255)
scroll_nt   = $09       ; Nametable select (0 or 1)

; Physics (8.8 fixed-point)
GRAVITY     = $40       ; ~0.25 pixels/frame² (floaty feel)
FLAP_VEL_LO = $00       ; Flap velocity fractional
FLAP_VEL_HI = $FC       ; Flap velocity integer (-4 pixels/frame)

; Screen bounds
CEILING_Y   = 8         ; Top of screen (bird stops here)
GROUND_Y    = 192       ; Ground level (bird sits on top of visible ground at row 26)
