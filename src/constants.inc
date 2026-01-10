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

; Pipe tracking (for scrolling pipes)
pipe0_col   = $0B       ; Pipe 0 tile column (0-31)
pipe0_gap   = $0C       ; Pipe 0 gap top row (8-16)
pipe0_nt    = $0D       ; Pipe 0 current nametable (0 or 1)
pipe1_col   = $0E       ; Pipe 1 tile column (0-31)
pipe1_gap   = $0F       ; Pipe 1 gap top row (8-16)
pipe1_nt    = $10       ; Pipe 1 current nametable (0 or 1)
pipe_redraw = $11       ; Pipe needing redraw (0=none, 1=pipe0, 2=pipe1)
rng_state   = $12       ; Random number generator state

; Temp variables for pipe drawing
temp_col    = $13       ; Temp column for draw_pipe
temp_gap    = $14       ; Temp gap row for draw_pipe
temp_nt     = $15       ; Temp nametable for draw_pipe
temp_row    = $16       ; Temp row counter

; Game state constants
STATE_WAITING = 0       ; Waiting for player to press A/B
STATE_PLAYING = 1
STATE_DYING   = 2
STATE_DEAD    = 3

; Pipe constants
PIPE_WIDTH   = 32       ; Pipe is 4 tiles wide (pixels)
GAP_HEIGHT   = 64       ; Gap is 8 tiles (64 pixels)
BIRD_LEFT    = 56       ; Bird left edge X
BIRD_RIGHT   = 72       ; Bird right edge X (56 + 16)

; Initial pipe positions
PIPE0_INIT_COL = 16     ; Pipe 0 starts at column 16
PIPE0_INIT_GAP = 12     ; Pipe 0 gap at row 12
PIPE1_INIT_COL = 24     ; Pipe 1 starts at column 24 (staggered)
PIPE1_INIT_GAP = 10     ; Pipe 1 gap at row 10

; Physics (8.8 fixed-point)
GRAVITY     = $40       ; ~0.25 pixels/frame² (floaty feel)
FLAP_VEL_LO = $00       ; Flap velocity fractional
FLAP_VEL_HI = $FC       ; Flap velocity integer (-4 pixels/frame)

; Screen bounds
CEILING_Y   = 8         ; Top of screen (bird stops here)
GROUND_Y    = 192       ; Ground level (bird sits on top of visible ground at row 26)
