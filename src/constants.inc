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
game_state  = $0A       ; Current game state (see STATE_* constants)

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

; Animation variables
anim_timer    = $17     ; Animation frame counter
anim_frame    = $18     ; Animation frame offset (0 or 6)
ANIM_SPEED    = 8       ; Frames between animation updates

; Score variables
score_ones    = $19     ; Score ones digit (0-9)
score_tens    = $1A     ; Score tens digit (0-9)
score_hundreds = $1B    ; Score hundreds digit (0-9)
pipes_scored  = $1C     ; Bitmask: bit 0=NT0P0, 1=NT0P1, 2=NT1P0, 3=NT1P1

; Score display (sprites)
DIGIT_TILE_BASE = $10   ; Tile $10 = '0', $11 = '1', ... $19 = '9'
SCORE_Y         = 16    ; Y position of score digits
SCORE_X_HUNDREDS = 112  ; X position of hundreds digit (centered)
SCORE_X_TENS     = 120  ; X position of tens digit
SCORE_X_ONES     = 128  ; X position of ones digit

; Sound variables
sound_timer     = $1D   ; Frames until next sound state
sound_state     = $1E   ; 0=idle, 1=coin B5, 2=coin E6

; Title text
clear_title     = $1F   ; Set to 1 to clear title text in NMI

; Death sequence variables
bird_x          = $20   ; Bird X position (for walk-off)
fade_timer      = $21   ; Frames until next fade step
fade_step       = $22   ; Current fade level (0=normal, 4=black)
update_palette  = $23   ; Flag to update palette in NMI

; Column-based drawing variables
col_draw_idx    = $28   ; Current column index (0-25, $FF=idle)
col_nt_base     = $29   ; Nametable being redrawn ($20=NT0, $24=NT1)
col_pipe0_gap   = $2A   ; Gap row for pipe 0 being drawn
col_pipe1_gap   = $2B   ; Gap row for pipe 1 being drawn
col_buffer_ready = $2C  ; Flag: 1 = pipe column buffer filled, ready for NMI
bg_index         = $31  ; Current background index (0 to BG_COUNT-1)
next_bg_idx      = $32  ; Next background to load when nametable wraps

; Multi-frame background loading
bg_load_row     = $33   ; Current row being loaded (0-29, $FF=idle)
bg_load_nt      = $34   ; Target nametable high byte ($20 or $24)

; Hi-score variables (zero page)
hiscore_ones     = $2E  ; Hi-score ones digit (0-9)
hiscore_tens     = $2F  ; Hi-score tens digit (0-9)
hiscore_hundreds = $30  ; Hi-score hundreds digit (0-9)

; SRAM addresses for hi-score persistence
SRAM_MAGIC_1    = $6000 ; Magic byte 1 ($F1)
SRAM_MAGIC_2    = $6001 ; Magic byte 2 ($AB)
SRAM_HISCORE_H  = $6002 ; Hundreds digit
SRAM_HISCORE_T  = $6003 ; Tens digit
SRAM_HISCORE_O  = $6004 ; Ones digit
SRAM_CHECKSUM   = $6005 ; Checksum: (H + T + O) XOR $55

; SRAM magic values
SRAM_MAGIC_VAL1 = $F1
SRAM_MAGIC_VAL2 = $AB

; Hi-score display constants
HISCORE_Y        = 32   ; Y position of hi-score display
HISCORE_LABEL_X1 = 96   ; X position of 'H' label
HISCORE_LABEL_X2 = 104  ; X position of 'I' label
HISCORE_X_HUNDREDS = 112 ; X position of hundreds digit
HISCORE_X_TENS     = 120 ; X position of tens digit
HISCORE_X_ONES     = 128 ; X position of ones digit
TILE_H           = $27  ; Tile for 'H' (A=$20, so H=$27)
TILE_I           = $28  ; Tile for 'I'

; Pipe column tile buffer (26 bytes at $0300-$0319)
; Pre-filled in main loop, copied to PPU during NMI
PIPE_COL_BUFFER = $0300

; Shell sprite (death animation)
SHELL_TILE_BASE = $1A   ; 2x2 shell tiles at $1A-$1D
SHELL_FEET_BASE = $2A   ; Shell with feet showing at $2A-$2B
STUN_ANIM_SPEED = 10    ; Frames between stunned animation updates

; Walking sprite (no wings)
WALK_TILE_BASE  = $1E   ; 2x3 walk frame 1 at $1E-$23
WALK_TILE_BASE2 = $24   ; 2x3 walk frame 2 at $24-$29
WALK_ANIM_SPEED = 8     ; Frames between walk animation updates

; Fade timing
FADE_DELAY      = 15    ; Frames per fade step

; Alphabet tiles (background pattern table)
ALPHA_TILE_BASE = $20   ; A=$20, B=$21, ... Z=$39

; Pipe layout constants
DEFAULT_GAP = 12        ; Default gap row
GAP_ROWS    = 8         ; Gap size in rows (64 pixels)
GAP_MIN     = 4         ; Minimum gap row
GAP_MAX     = 15        ; Maximum gap row

; Game state constants
STATE_WAITING  = 0      ; Waiting for player to press A/B
STATE_PLAYING  = 1      ; Active gameplay
STATE_DYING    = 2      ; Shell falling after collision
STATE_STUNNED  = 3      ; Recovering after hitting ground
STATE_WALK_OFF = 4      ; Walking left off screen
STATE_FADE_OUT = 5      ; Fading to black, then full reset

; Stun timing
STUN_DELAY     = 75     ; Frames to wait before walking (~1.25 sec)

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
GROUND_Y    = 184       ; Ground level (2x3 sprite sits on top of visible ground at row 26)
