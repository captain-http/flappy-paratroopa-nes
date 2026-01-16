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

; Pipe redraw variables
pipe_redraw = $0B       ; Nametable to redraw pipes in (0, 1, or $FF=none)
nt_base     = $0C       ; Nametable base high byte ($20=NT0, $24=NT1)
pipe_col    = $0D       ; Current pipe column (0 or 16)
pipe_gap    = $0E       ; Gap start row (for drawing)
pipe0_drawn_gap = $0F   ; Gap of pipe 0 when it was drawn (for collision)

; Random number generator (16-bit LFSR)
rng_lo      = $10       ; LFSR low byte
rng_hi      = $11       ; LFSR high byte

; Per-nametable pipe gap tracking (for collision detection)
nt0_pipe0_gap = $12     ; NT0 pipe 0 gap row
nt0_pipe1_gap = $13     ; NT0 pipe 1 gap row
nt1_pipe0_gap = $14     ; NT1 pipe 0 gap row
nt1_pipe1_gap = $15     ; NT1 pipe 1 gap row
nt0_has_pipes = $16     ; 0 = NT0 empty, 1 = NT0 has pipes

; Pipe layout constants
DEFAULT_GAP = 12        ; Default gap row
GAP_ROWS    = 8         ; Gap size in rows (64 pixels)
GAP_MIN     = 4         ; Minimum gap row
GAP_MAX     = 15        ; Maximum gap row

; Game state constants
STATE_WAITING = 0       ; Waiting for player to press A/B
STATE_PLAYING = 1
STATE_DYING   = 2
STATE_DEAD    = 3

; Pipe collision constants (based on scroll position)
; Both pipes in NT1 (initial screen is empty)
PIPE0_COL    = 0        ; Pipe 0 at NT1 column 0 (world pixel 256)
PIPE1_COL    = 16       ; Pipe 1 at NT1 column 16 (world pixel 384)
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
