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

; Game state
game_state  = $0A       ; 0 = waiting, 1 = playing, 2 = dying, 3 = dead

; Game state constants
STATE_WAITING = 0       ; Waiting for player to press A/B
STATE_PLAYING = 1
STATE_DYING   = 2
STATE_DEAD    = 3

; Pipe collision constants (based on scroll position)
PIPE0_COL    = 28       ; Pipe 0 at NT0 column 28 (pixel X = 224)
PIPE1_COL    = 12       ; Pipe 1 at NT1 column 12 (pixel X = 352)
PIPE0_X      = 224      ; Pipe 0 pixel X position (28 * 8)
PIPE_WIDTH   = 32       ; Pipe is 4 tiles wide
GAP_TOP      = 96       ; Top of gap (row 12 * 8)
GAP_BOTTOM   = 160      ; Bottom of gap (row 20 * 8)
BIRD_LEFT    = 56       ; Bird left edge X
BIRD_RIGHT   = 72       ; Bird right edge X (56 + 16)

; Physics (8.8 fixed-point)
GRAVITY     = $40       ; ~0.25 pixels/frame² (floaty feel)
FLAP_VEL_LO = $00       ; Flap velocity fractional
FLAP_VEL_HI = $FC       ; Flap velocity integer (-4 pixels/frame)

; Screen bounds
CEILING_Y   = 8         ; Top of screen (bird stops here)
GROUND_Y    = 192       ; Ground level (bird sits on top of visible ground at row 26)
