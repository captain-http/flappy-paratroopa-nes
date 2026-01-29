; Flappy Bird for NES
; main.asm - Entry point

.include "nes.inc"
.include "constants.inc"
.include "BG0.asm"
.include "BG1.asm"
.include "BG2.asm"
.include "BG3.asm"

;===============================================================================
; iNES Header
;===============================================================================
.segment "HEADER"
    .byte "NES", $1A      ; iNES magic number
    .byte $02             ; PRG-ROM: 2 x 16KB = 32KB
    .byte $01             ; CHR-ROM: 1 x 8KB = 8KB
    .byte $12             ; Flags 6: vertical mirroring, battery-backed SRAM, MMC1 lower nibble
    .byte $00             ; Flags 7: mapper upper nibble = 0 (MMC1 = mapper 1)
    .byte $00, $00, $00, $00, $00, $00, $00, $00  ; Padding

;===============================================================================
; Vectors
;===============================================================================
.segment "VECTORS"
    .addr nmi
    .addr reset
    .addr irq

;===============================================================================
; Code
;===============================================================================
.segment "CODE"

reset:
    sei                   ; Disable interrupts
    cld                   ; Clear decimal mode
    ldx #$40
    stx $4017             ; Disable APU frame IRQ
    ldx #$FF
    txs                   ; Initialize stack
    inx                   ; X = 0
    stx PPU_CTRL          ; Disable NMI
    stx PPU_MASK          ; Disable rendering
    stx $4010             ; Disable DMC IRQs

    ; MMC1 Initialization
    ; Reset shift register by writing with bit 7 set
    lda #$80
    sta $8000

    ; Control register ($8000): $0E = vertical mirroring, PRG mode 3, CHR 8KB
    lda #$0E
    jsr mmc1_write_8000

    ; CHR bank 0 ($A000): $00 = bank 0, PRG-RAM enabled (bit 4 = 0)
    lda #$00
    jsr mmc1_write_A000

    ; PRG bank ($E000): $00 = bank 0, PRG-RAM enabled (bit 4 = 0)
    lda #$00
    jsr mmc1_write_E000

    ; Wait for first vblank (PPU warmup)
@vblank1:
    bit PPU_STATUS
    bpl @vblank1

    ; Clear RAM while waiting for second vblank
    lda #$00
@clear_ram:
    sta $0000, x
    sta $0100, x
    sta $0200, x
    sta $0300, x
    sta $0400, x
    sta $0500, x
    sta $0600, x
    sta $0700, x
    inx
    bne @clear_ram

    ; Wait for second vblank (PPU ready)
@vblank2:
    bit PPU_STATUS
    bpl @vblank2

    ; Load hi-score from SRAM (or initialize if invalid)
    jsr load_hiscore

    ; Enable APU channels (pulse 1 for flap/death, pulse 2 for score, noise for crash)
    lda #%00001111        ; Enable pulse 1, 2, triangle, and noise
    sta SND_CHN

    ; Load palettes
    bit PPU_STATUS        ; Reset PPU address latch
    lda #$3F
    sta PPU_ADDR
    lda #$00
    sta PPU_ADDR          ; PPU address = $3F00

    ; Background palette 0 (sky + text)
    lda #$22              ; SMB sky blue (universal bg)
    sta PPU_DATA
    lda #$22              ; Color 1 (unused)
    sta PPU_DATA
    lda #$30              ; Color 2 - white (for text)
    sta PPU_DATA
    lda #$22              ; Color 3 (unused)
    sta PPU_DATA

    ; Background palette 1 (ground)
    lda #$22              ; Color 0 (mirrors to universal bg)
    sta PPU_DATA
    lda #$36              ; Color 1 - light orange
    sta PPU_DATA
    lda #$17              ; Color 2 - brown
    sta PPU_DATA
    lda #$0F              ; Color 3 - black
    sta PPU_DATA

    ; Background palette 2 (pipes)
    lda #$22              ; Color 0 (mirrors to universal bg)
    sta PPU_DATA
    lda #$29              ; Color 1 - light green
    sta PPU_DATA
    lda #$1A              ; Color 2 - dark green
    sta PPU_DATA
    lda #$0F              ; Color 3 - black
    sta PPU_DATA

    ; Background palette 3 (clouds)
    lda #$22              ; Color 0 (mirrors to universal bg)
    sta PPU_DATA
    lda #$30              ; Color 1 - white (cloud body)
    sta PPU_DATA
    lda #$21              ; Color 2 - cyan (cloud shading)
    sta PPU_DATA
    lda #$0F              ; Color 3 - black (outline)
    sta PPU_DATA

    ; Sprite palette 0 ($3F10) - Koopa Paratroopa colors
    lda #$3F
    sta PPU_ADDR
    lda #$10
    sta PPU_ADDR
    lda #$22              ; Color 0 - light blue (sky)
    sta PPU_DATA
    lda #$1A              ; Color 1 - green (shell)
    sta PPU_DATA
    lda #$30              ; Color 2 - white (belly/face)
    sta PPU_DATA
    lda #$27              ; Color 3 - orange (feet/details)
    sta PPU_DATA

    ; Load background 0 (title screen) into NT0
    lda #0
    sta bg_index
    lda #$20              ; Target = NT0
    jsr load_background_only

    lda #1
    sta bg_index
    lda #$24              ; Target = NT1
    jsr load_background_only

    ; Set up static attribute tables for both nametables (once, never changes)
    jsr init_attributes

    ; Draw title text on NT0
    jsr draw_title_text

    ; Next background to load when a nametable wraps
    lda #2
    sta next_bg_idx       ; bg0, bg1 loaded, next is bg2

    ; Initialize bird state (8.8 fixed-point)
    lda #0
    sta bird_y_frac
    lda #100
    sta bird_y
    lda #0
    sta bird_vel_lo
    sta bird_vel_hi

    ; Initialize LFSR only if both bytes are zero (prevents same sequence after reset)
    ; On fresh boot, RAM is unpredictable (usually non-zero = fine for LFSR)
    ; After playing, LFSR will be non-zero - preserve it for randomness
    lda rng_lo
    ora rng_hi
    bne @skip_rng_seed
    ; Both zero - seed with non-zero value
    lda #$01
    sta rng_lo
    lda #$A5
    sta rng_hi
@skip_rng_seed:

    ; Initialize pipe gaps
    ; NT0 starts empty - flag prevents collision checks until drawn
    lda #0
    sta nt0_has_pipes
    ; Initialize column drawing to idle (no active redraw)
    lda #$FF
    sta col_draw_idx
    sta bg_load_row       ; No background loading in progress
    ; NT1 gaps will be set by draw_pipes_in_nt during init
    jsr next_pipe_gap     ; Set initial pipe_gap for NT1 pipe 0

    ; Initialize sprite Y positions from bird_y (2x3 bird = 6 sprites)
    lda bird_y
    sta OAM_BUFFER+0      ; Top-left Y
    sta OAM_BUFFER+4      ; Top-right Y
    clc
    adc #8
    sta OAM_BUFFER+8      ; Mid-left Y
    sta OAM_BUFFER+12     ; Mid-right Y
    clc
    adc #8
    sta OAM_BUFFER+16     ; Bottom-left Y
    sta OAM_BUFFER+20     ; Bottom-right Y

    ; Setup sprite tiles (2x3 pattern: $01-$06)
    lda #$01
    sta OAM_BUFFER+1      ; Top-left tile
    lda #$02
    sta OAM_BUFFER+5      ; Top-right tile
    lda #$03
    sta OAM_BUFFER+9      ; Mid-left tile
    lda #$04
    sta OAM_BUFFER+13     ; Mid-right tile
    lda #$05
    sta OAM_BUFFER+17     ; Bottom-left tile
    lda #$06
    sta OAM_BUFFER+21     ; Bottom-right tile

    ; Attributes (palette 0 for all)
    lda #$00
    sta OAM_BUFFER+2
    sta OAM_BUFFER+6
    sta OAM_BUFFER+10
    sta OAM_BUFFER+14
    sta OAM_BUFFER+18
    sta OAM_BUFFER+22

    ; X positions (fixed at 1/4 screen width)
    lda #56               ; Left column
    sta OAM_BUFFER+3
    sta OAM_BUFFER+11
    sta OAM_BUFFER+19
    lda #64               ; Right column
    sta OAM_BUFFER+7
    sta OAM_BUFFER+15
    sta OAM_BUFFER+23

    ; Initialize score display sprites (3 digits)
    ; Hundreds digit (OAM_BUFFER+24)
    lda #SCORE_Y
    sta OAM_BUFFER+24     ; Y
    lda #DIGIT_TILE_BASE  ; Tile '0'
    sta OAM_BUFFER+25
    lda #$00              ; Attributes (palette 0)
    sta OAM_BUFFER+26
    lda #SCORE_X_HUNDREDS
    sta OAM_BUFFER+27     ; X

    ; Tens digit (OAM_BUFFER+28)
    lda #SCORE_Y
    sta OAM_BUFFER+28     ; Y
    lda #DIGIT_TILE_BASE  ; Tile '0'
    sta OAM_BUFFER+29
    lda #$00              ; Attributes (palette 0)
    sta OAM_BUFFER+30
    lda #SCORE_X_TENS
    sta OAM_BUFFER+31     ; X

    ; Ones digit (OAM_BUFFER+32)
    lda #SCORE_Y
    sta OAM_BUFFER+32     ; Y
    lda #DIGIT_TILE_BASE  ; Tile '0'
    sta OAM_BUFFER+33
    lda #$00              ; Attributes (palette 0)
    sta OAM_BUFFER+34
    lda #SCORE_X_ONES
    sta OAM_BUFFER+35     ; X

    ; Hide remaining sprites
    lda #$FF
    ldx #36
@hide_sprites:
    sta OAM_BUFFER, x
    inx
    inx
    inx
    inx
    bne @hide_sprites

    ; Draw ground in both nametables for scrolling
    ; Row 26 at $2000 + (26 * 32) = $2340 / $2740
    ; 2x2 tile pattern: $01/$02 top row, $03/$04 bottom row
    ; Aligned to attribute row 6 bottom half (like SMB)
    bit PPU_STATUS        ; Reset PPU latch

    ; Fill nametable 0 ground (rows 26-29)
    lda #$23
    sta PPU_ADDR
    lda #$40
    sta PPU_ADDR          ; PPU address = $2340 (row 26)
    ldx #16               ; 16 pairs per row
@fill_ground0_row26:
    lda #$01
    sta PPU_DATA
    lda #$02
    sta PPU_DATA
    dex
    bne @fill_ground0_row26
    ldx #16               ; Row 27
@fill_ground0_row27:
    lda #$03
    sta PPU_DATA
    lda #$04
    sta PPU_DATA
    dex
    bne @fill_ground0_row27
    ldx #16               ; Row 28
@fill_ground0_row28:
    lda #$01
    sta PPU_DATA
    lda #$02
    sta PPU_DATA
    dex
    bne @fill_ground0_row28
    ldx #16               ; Row 29
@fill_ground0_row29:
    lda #$03
    sta PPU_DATA
    lda #$04
    sta PPU_DATA
    dex
    bne @fill_ground0_row29

    ; Fill nametable 1 ground (rows 26-29)
    lda #$27
    sta PPU_ADDR
    lda #$40
    sta PPU_ADDR          ; PPU address = $2740 (row 26)
    ldx #16
@fill_ground1_row26:
    lda #$01
    sta PPU_DATA
    lda #$02
    sta PPU_DATA
    dex
    bne @fill_ground1_row26
    ldx #16               ; Row 27
@fill_ground1_row27:
    lda #$03
    sta PPU_DATA
    lda #$04
    sta PPU_DATA
    dex
    bne @fill_ground1_row27
    ldx #16               ; Row 28
@fill_ground1_row28:
    lda #$01
    sta PPU_DATA
    lda #$02
    sta PPU_DATA
    dex
    bne @fill_ground1_row28
    ldx #16               ; Row 29
@fill_ground1_row29:
    lda #$03
    sta PPU_DATA
    lda #$04
    sta PPU_DATA
    dex
    bne @fill_ground1_row29

    ;=========================================================================
    ; Pipe attributes baked into bg*.asm - no runtime attr writes needed
    ;=========================================================================

    ; Draw pipes in NT1 (initial screen is empty NT0)
    ; Use eight-frame drawing routine (outside vblank, no constraint)
    lda #$24              ; NT1 base
    sta nt_base
    lda #0
    sta pipe_redraw       ; Start with pipe 0 body+cap
    jsr draw_pipes_in_nt  ; Frame 1: pipe 0 body+cap
    jsr draw_pipes_in_nt  ; Frame 2: pipe 0 gap
    jsr draw_pipes_in_nt  ; Frame 3: pipe 0 bottom
    jsr draw_pipes_in_nt  ; Frame 4: pipe 0 attrs
    jsr draw_pipes_in_nt  ; Frame 5: pipe 1 body+cap
    jsr draw_pipes_in_nt  ; Frame 6: pipe 1 gap
    jsr draw_pipes_in_nt  ; Frame 7: pipe 1 bottom
    jsr draw_pipes_in_nt  ; Frame 8: pipe 1 attrs

    ; Reset scroll position
    bit PPU_STATUS
    lda #$00
    sta PPU_SCROLL
    sta PPU_SCROLL

    ; Enable NMI, sprites from $0000, background from $1000 (like SMB)
    lda #%10010000
    sta PPU_CTRL

    ; Enable rendering (bg + sprites)
    lda #%00011110
    sta PPU_MASK

;===============================================================================
; Main Game Loop
;===============================================================================
game_loop:
    ; Wait for NMI
@wait_nmi:
    lda nmi_flag
    beq @wait_nmi
    lda #0
    sta nmi_flag

    ; Update score display sprites
    jsr update_score_display
    jsr update_hiscore_display

    ; Update sound effects
    jsr update_sound

    ; Check game state
    lda game_state
    cmp #STATE_FADE_OUT
    bne @not_fade_out
    jmp @fade_out_state
@not_fade_out:
    cmp #STATE_WALK_OFF
    bne @not_walk_off
    jmp @walk_off_state
@not_walk_off:
    cmp #STATE_STUNNED
    bne @not_stunned
    jmp @stunned_state
@not_stunned:
    cmp #STATE_DYING
    bne @not_dying
    jmp @dying_state          ; Falling, no input
@not_dying:
    cmp #STATE_WAITING
    bne @not_waiting
    jmp @waiting_state        ; Waiting for start
@not_waiting:

    ; STATE_PLAYING: Normal gameplay
    jsr read_controller

    ; Check for flap (A or B pressed)
    lda buttons_new
    and #(BUTTON_A | BUTTON_B)
    beq @no_flap
    ; Flap! Set upward velocity
    lda #FLAP_VEL_LO
    sta bird_vel_lo
    lda #FLAP_VEL_HI
    sta bird_vel_hi
    jsr play_flap_sound
@no_flap:

    ; Check pipe collision
    jsr check_pipe_collision
    lda game_state
    cmp #STATE_DYING
    bne @no_collision_skip
    jmp @dying_state          ; Collision happened, skip to dying
@no_collision_skip:

    ; Check for scoring (passing pipes)
    jsr check_score

    ; Apply gravity to velocity (8.8 fixed-point)
    lda bird_vel_lo
    clc
    adc #GRAVITY
    sta bird_vel_lo
    lda bird_vel_hi
    adc #0                ; Add carry
    sta bird_vel_hi

    ; Apply velocity to position (8.8 fixed-point)
    lda bird_y_frac
    clc
    adc bird_vel_lo
    sta bird_y_frac
    lda bird_y
    adc bird_vel_hi
    sta bird_y

    ; Check ceiling collision (bird went too high or wrapped)
    cmp #CEILING_Y
    bcs @no_ceiling       ; bird_y >= CEILING_Y, check if wrapped
    ; bird_y < CEILING_Y, clamp to ceiling
@clamp_ceiling:
    lda #CEILING_Y
    sta bird_y
    lda #0                ; Stop upward velocity
    sta bird_vel_lo
    sta bird_vel_hi
    sta bird_y_frac
    jmp @no_ground        ; Skip ground check
@no_ceiling:
    ; Check if wrapped around (went negative, now 240+)
    cmp #240
    bcc @check_ground     ; bird_y < 240, normal range
    jmp @clamp_ceiling    ; Wrapped, clamp to ceiling

@check_ground:
    ; Check ground collision - bird hit ground directly
    lda bird_y
    cmp #GROUND_Y
    bcc @no_ground        ; bird_y < GROUND_Y, no collision
    ; Bird hit ground - check hi-score and start stunned state
    jsr check_update_hiscore
    lda #GROUND_Y         ; Clamp to ground
    sta bird_y
    lda #0                ; Stop falling
    sta bird_vel_lo
    sta bird_vel_hi
    sta bird_y_frac
    lda #STATE_STUNNED
    sta game_state
    lda #STUN_DELAY
    sta fade_timer        ; Reuse fade_timer for stun delay
    jsr switch_to_shell   ; Show shell while stunned
    jsr play_ground_hit   ; Just noise burst (no whistle)
    ; Update shell Y positions (same as dying state)
    lda bird_y
    clc
    adc #8
    sta OAM_BUFFER+8      ; Mid-left (shell top)
    sta OAM_BUFFER+12     ; Mid-right
    clc
    adc #8
    sta OAM_BUFFER+16     ; Bottom-left (shell bottom)
    sta OAM_BUFFER+20     ; Bottom-right
    jmp game_loop
@no_ground:

    ; Update sprite Y positions (2x3 bird)
    lda bird_y
    sta OAM_BUFFER+0      ; Top-left
    sta OAM_BUFFER+4      ; Top-right
    clc
    adc #8
    sta OAM_BUFFER+8      ; Mid-left
    sta OAM_BUFFER+12     ; Mid-right
    clc
    adc #8
    sta OAM_BUFFER+16     ; Bottom-left
    sta OAM_BUFFER+20     ; Bottom-right

    ; Update animation (wing flapping)
    inc anim_timer
    lda anim_timer
    cmp #ANIM_SPEED
    bcc @no_anim_update
    lda #0
    sta anim_timer
    ; Toggle frame between 0 and 6
    lda anim_frame
    eor #6
    sta anim_frame
@no_anim_update:
    ; Update sprite tiles based on animation frame
    lda anim_frame
    clc
    adc #$01
    sta OAM_BUFFER+1      ; Top-left tile
    adc #1
    sta OAM_BUFFER+5      ; Top-right tile
    adc #1
    sta OAM_BUFFER+9      ; Mid-left tile
    adc #1
    sta OAM_BUFFER+13     ; Mid-right tile
    adc #1
    sta OAM_BUFFER+17     ; Bottom-left tile
    adc #1
    sta OAM_BUFFER+21     ; Bottom-right tile

    ; Scroll if bird is flying (not on ground)
    lda bird_y
    cmp #GROUND_Y
    beq @no_scroll        ; Bird on ground, don't scroll
    ; Bird is flying, scroll by 2 pixels
    lda scroll_x
    clc
    adc #2
    sta scroll_x
    bcc @no_scroll        ; No overflow, done
    ; scroll_x wrapped from 255 to 0, toggle nametable
    lda scroll_nt
    eor #$01              ; Toggle bit 0
    sta scroll_nt
    ; Redraw pipes for the nametable that went off-screen
    ; Backgrounds stay static (loaded at init) - only pipes change
    ; scroll_nt = 1: switched TO NT1, redraw NT0
    ; scroll_nt = 0: switched TO NT0, redraw NT1
    beq @redraw_nt1
    ; Switched to NT1 - redraw NT0
    lda pipes_scored
    and #%11111100        ; Clear NT0 scored flags
    sta pipes_scored
    ; Load next background into NT0
    lda next_bg_idx
    sta bg_index
    lda #$20              ; NT0
    jsr load_bg_safe
    jsr advance_next_bg
    lda #$20
    jsr start_column_redraw
    jmp @no_scroll
@redraw_nt1:
    ; Switched to NT0 - redraw NT1
    lda pipes_scored
    and #%11110011        ; Clear NT1 scored flags
    sta pipes_scored
    ; Load next background into NT1
    lda next_bg_idx
    sta bg_index
    lda #$24              ; NT1
    jsr load_bg_safe
    jsr advance_next_bg
    lda #$24
    jsr start_column_redraw
@no_scroll:
    jmp game_loop

@dying_state:
    ; Bird is dying - apply gravity but no input, no scrolling
    lda bird_vel_lo
    clc
    adc #GRAVITY
    sta bird_vel_lo
    lda bird_vel_hi
    adc #0
    sta bird_vel_hi

    lda bird_y_frac
    clc
    adc bird_vel_lo
    sta bird_y_frac
    lda bird_y
    adc bird_vel_hi
    sta bird_y

    cmp #GROUND_Y
    bcc @dying_no_ground
    lda #GROUND_Y
    sta bird_y
    lda #0
    sta bird_vel_lo
    sta bird_vel_hi
    sta bird_y_frac
    lda #STATE_STUNNED
    sta game_state
    lda #STUN_DELAY
    sta fade_timer        ; Reuse fade_timer for stun delay
@dying_no_ground:

    ; Update shell sprite Y positions (2x2, skip hidden top sprites)
    lda bird_y
    clc
    adc #8
    sta OAM_BUFFER+8      ; Mid-left
    sta OAM_BUFFER+12     ; Mid-right
    clc
    adc #8
    sta OAM_BUFFER+16     ; Bottom-left
    sta OAM_BUFFER+20     ; Bottom-right

    jmp game_loop

@stunned_state:
    ; Koopa is stunned on ground, waiting to recover
    dec fade_timer
    bne @stunned_animate
    ; Stun timer expired - start walking
    lda #STATE_WALK_OFF
    sta game_state
    ; Initialize for walk off
    lda #56
    sta bird_x
    lda #0
    sta anim_timer
    sta anim_frame
    jsr switch_to_walking
    jmp game_loop

@stunned_animate:
    ; Animate feet peeking out of shell
    inc anim_timer
    lda anim_timer
    cmp #STUN_ANIM_SPEED
    bcc @stunned_done
    lda #0
    sta anim_timer
    ; Toggle anim_frame between 0 and 1
    lda anim_frame
    eor #1
    sta anim_frame
    beq @shell_no_feet
    ; Show feet (tiles $2A, $2B)
    lda #SHELL_FEET_BASE
    sta OAM_BUFFER+17     ; Bottom-left tile
    lda #(SHELL_FEET_BASE + 1)
    sta OAM_BUFFER+21     ; Bottom-right tile
    jmp game_loop
@shell_no_feet:
    ; Hide feet (tiles $1C, $1D)
    lda #(SHELL_TILE_BASE + 2)
    sta OAM_BUFFER+17     ; Bottom-left tile
    lda #(SHELL_TILE_BASE + 3)
    sta OAM_BUFFER+21     ; Bottom-right tile
@stunned_done:
    jmp game_loop

@walk_off_state:
    ; Koopa walks left off screen
    ; Decrement X position
    dec bird_x
    lda bird_x
    cmp #$F0              ; Fully off screen? (X = -16, right edge at 0)
    bne @walk_update_sprites
    ; Off screen - start fade out
    lda #STATE_FADE_OUT
    sta game_state
    lda #FADE_DELAY
    sta fade_timer
    lda #0
    sta fade_step
    jmp game_loop

@walk_update_sprites:
    ; Update walk animation
    inc anim_timer
    lda anim_timer
    cmp #WALK_ANIM_SPEED
    bcc @walk_no_anim
    lda #0
    sta anim_timer
    ; Toggle frame between 0 and 6
    lda anim_frame
    eor #6
    sta anim_frame
    ; Update sprite tiles
    jsr update_walk_tiles
@walk_no_anim:
    ; Update sprite X positions
    ; Check if bird_x wrapped (high bit set = off left edge)
    lda bird_x
    bmi @hide_sprites     ; If negative (>=128), hide sprites
    sta OAM_BUFFER+3      ; Top-left X
    sta OAM_BUFFER+11     ; Mid-left X
    sta OAM_BUFFER+19     ; Bottom-left X
    clc
    adc #8
    sta OAM_BUFFER+7      ; Top-right X
    sta OAM_BUFFER+15     ; Mid-right X
    sta OAM_BUFFER+23     ; Bottom-right X
    jmp game_loop

@hide_sprites:
    ; Hide all 6 sprites by setting Y to $FF
    lda #$FF
    sta OAM_BUFFER+0
    sta OAM_BUFFER+4
    sta OAM_BUFFER+8
    sta OAM_BUFFER+12
    sta OAM_BUFFER+16
    sta OAM_BUFFER+20
    jmp game_loop

@fade_out_state:
    ; Fade palette to black
    dec fade_timer
    bne @fade_out_done
    ; Timer expired - next fade step
    lda #FADE_DELAY
    sta fade_timer
    inc fade_step
    lda fade_step
    cmp #5                ; 5 steps: 0,1,2,3,4 (4 = fully black)
    bcc @fade_out_apply
    ; Fully faded to black - do a full reset
    jmp reset
@fade_out_apply:
    lda #1
    sta update_palette    ; Flag to update palette in NMI
@fade_out_done:
    jmp game_loop

@waiting_state:
    ; Waiting for player to press A or B to start
    ; Run LFSR each frame to gather entropy from player timing
    jsr rand_lfsr
    jsr read_controller
    lda buttons_new
    and #(BUTTON_A | BUTTON_B)
    beq @waiting_done
    lda #STATE_PLAYING
    sta game_state
    ; Title text scrolls off naturally, attr restored when NT0 wraps
@waiting_done:
    jmp game_loop

nmi:
    ; Preserve all registers (critical for stability)
    pha
    txa
    pha
    tya
    pha

    ; OAM DMA transfer
    lda #$00
    sta OAM_ADDR
    lda #>OAM_BUFFER      ; High byte of $0200
    sta OAM_DMA

    ; Multi-frame background loading (2 rows per frame)
    ; Must run BEFORE draw_column so pipes overwrite bg, not vice versa
    jsr load_bg_rows

    ; Column-based pipe/cloud drawing (one column per frame)
    jsr draw_column

    ; Check if we need to update palette (fade effect)
    lda update_palette
    beq @no_palette_update
    jsr apply_fade_palette
    lda #0
    sta update_palette
@no_palette_update:

    ; Set scroll position
    bit PPU_STATUS        ; Reset PPU latch
    lda scroll_x
    sta PPU_SCROLL        ; X scroll
    lda #$00
    sta PPU_SCROLL        ; Y scroll (always 0)

    ; Set PPU_CTRL with nametable select
    lda #%10010000        ; Base: NMI on, sprites $0000, bg $1000
    ora scroll_nt         ; Add nametable bit
    sta PPU_CTRL

    ; Signal main loop
    lda #1
    sta nmi_flag

    ; Restore all registers
    pla
    tay
    pla
    tax
    pla
    rti

irq:
    rti

;===============================================================================
; Controller Reading
;===============================================================================
read_controller:
    ; Save previous button state
    lda buttons
    sta buttons_old

    ; Strobe controller
    lda #$01
    sta $4016
    lda #$00
    sta $4016

    ; Read 8 buttons
    ldx #$08
@read_loop:
    lda $4016
    lsr a               ; Bit 0 -> Carry
    rol buttons         ; Carry -> buttons
    dex
    bne @read_loop

    ; Calculate newly pressed buttons (edge detection)
    lda buttons_old
    eor #$FF            ; Invert old state
    and buttons         ; AND with current = new presses only
    sta buttons_new

    rts

;===============================================================================
; Pipe Collision Detection
;===============================================================================
check_pipe_collision:
    ; Pipes are in both nametables:
    ; NT0 pipe 0: world X 0,    NT0 pipe 1: world X 128
    ; NT1 pipe 0: world X 256,  NT1 pipe 1: world X 384
    ;
    ; Check pipes based on scroll position. Bird is at screen X 56-72.
    ; A pipe overlaps if its screen_x is in range [25, 72] (accounting for 32px width)

    lda scroll_nt
    bne @viewing_nt1

@viewing_nt0:
    ; When viewing NT0, check:
    ; 1. NT0 pipe 1: screen_x = 128 - scroll_x (visible when scroll_x in ~[56, 103])
    ; 2. NT1 pipe 0: screen_x = 256 - scroll_x (visible when scroll_x in ~[184, 231])

    ; Skip NT0 pipes if NT0 hasn't been drawn yet
    lda nt0_has_pipes
    beq @check_nt1_pipe0

    ; Check NT0 pipe 1
    lda #128
    sec
    sbc scroll_x          ; A = 128 - scroll_x
    cmp #BIRD_RIGHT
    bcs @check_nt1_pipe0  ; screen_x >= 72, pipe to the right, check next
    cmp #(BIRD_LEFT - PIPE_WIDTH + 1)
    bcc @check_nt1_pipe0  ; screen_x < 25, pipe to the left, check next
    ; X overlaps with NT0 pipe 1
    lda nt0_pipe1_gap
    jmp @check_y

@check_nt1_pipe0:
    ; Check NT1 pipe 0: screen_x = 256 - scroll_x (wraps in 8-bit)
    lda #0
    sec
    sbc scroll_x          ; A = 256 - scroll_x (8-bit wrap)
    cmp #BIRD_RIGHT
    bcs @no_collision     ; screen_x >= 72, no overlap
    cmp #(BIRD_LEFT - PIPE_WIDTH + 1)
    bcc @no_collision     ; screen_x < 25, no overlap
    ; X overlaps with NT1 pipe 0
    lda nt1_pipe0_gap
    jmp @check_y

@viewing_nt1:
    ; When viewing NT1, check:
    ; 1. NT1 pipe 1: screen_x = 128 - scroll_x (visible when scroll_x in ~[56, 103])
    ; 2. NT0 pipe 0: screen_x = 256 - scroll_x (visible when scroll_x in ~[184, 231])

    ; Check NT1 pipe 1
    lda #128
    sec
    sbc scroll_x          ; A = 128 - scroll_x
    cmp #BIRD_RIGHT
    bcs @check_nt0_pipe0  ; screen_x >= 72, check next
    cmp #(BIRD_LEFT - PIPE_WIDTH + 1)
    bcc @check_nt0_pipe0  ; screen_x < 25, check next
    ; X overlaps with NT1 pipe 1
    lda nt1_pipe1_gap
    jmp @check_y

@check_nt0_pipe0:
    ; Skip NT0 pipes if NT0 hasn't been drawn yet
    lda nt0_has_pipes
    beq @no_collision

    ; Check NT0 pipe 0: screen_x = 256 - scroll_x (wraps in 8-bit)
    lda #0
    sec
    sbc scroll_x          ; A = 256 - scroll_x
    cmp #BIRD_RIGHT
    bcs @no_collision     ; screen_x >= 72, no overlap
    cmp #(BIRD_LEFT - PIPE_WIDTH + 1)
    bcc @no_collision     ; screen_x < 25, no overlap
    ; X overlaps with NT0 pipe 0
    lda nt0_pipe0_gap
    jmp @check_y

@check_y:
    ; A = gap row for the overlapping pipe
    ; Rectangle collision uses only the shell body (2x2 = 16x16), not the head
    ; Collision box: (56, bird_y+8) to (72, bird_y+24) - excludes 8px head
    ; Top pipe: Y from 0 to gap_top_y
    ; Bottom pipe: Y from gap_top_y+64 to ground
    ;
    ; Bird safe if: (bird_y+8) >= gap_top_y AND (bird_y+24) <= gap_top_y+64

    ; Calculate gap_top_y = gap * 8
    asl a
    asl a
    asl a                 ; A = gap_top_y
    sta pipe0_drawn_gap

    ; Check top pipe: (bird_y+8) < gap_top_y means shell top is in top pipe
    lda bird_y
    clc
    adc #8                ; A = bird_y + 8 (top of shell, skip head)
    cmp pipe0_drawn_gap   ; compare (bird_y+8) with gap_top_y
    bcc @collision        ; (bird_y+8) < gap_top_y, hit top pipe

    ; Check bottom pipe: (bird_y+24) > gap_top_y+64 means shell bottom is in bottom pipe
    ; Equivalent: bird_y > gap_top_y+40
    lda pipe0_drawn_gap
    clc
    adc #(GAP_ROWS * 8)   ; A = gap_top_y + 64 (gap bottom / bottom pipe top)
    sec
    sbc #24               ; A = gap_top_y + 40 (max safe bird_y for 24px tall collision)
    cmp bird_y            ; compare threshold with bird_y
    bcc @collision        ; threshold < bird_y, shell bottom in pipe

@no_collision:
    rts

@collision:
    ; Bird hit pipe - check for hi-score before dying
    jsr check_update_hiscore
    lda #STATE_DYING
    sta game_state
    jsr switch_to_shell
    jsr play_crash_sound
    rts

;===============================================================================
; Score Checking
;===============================================================================
check_score:
    ; Check if bird has passed any pipes (screen_x < 24 means fully passed)
    ; Bird scores when pipe's right edge (screen_x + 32) passes bird's left (56)
    ; That means screen_x < 24

    lda scroll_nt
    bne @check_nt1_scoring

@check_nt0_scoring:
    ; Viewing NT0 - check NT1 pipe 0 and NT0 pipe 1

    ; NT0 pipe 1: screen_x = 128 - scroll_x
    lda nt0_has_pipes
    beq @check_nt1_pipe0_score  ; NT0 not drawn yet
    lda #128
    sec
    sbc scroll_x
    cmp #24
    bcs @check_nt1_pipe0_score  ; screen_x >= 24, not passed yet
    ; Pipe passed - check if already scored
    lda pipes_scored
    and #%00000010            ; Bit 1 = NT0 pipe 1
    bne @check_nt1_pipe0_score ; Already scored
    ; Score!
    jsr increment_score
    lda pipes_scored
    ora #%00000010
    sta pipes_scored

@check_nt1_pipe0_score:
    ; NT1 pipe 0: screen_x = 256 - scroll_x (wraps)
    ; Only valid when scroll_x > 232 (pipe actually passed, not wrap-around)
    lda scroll_x
    cmp #233
    bcc @score_done           ; scroll_x < 233, pipe not yet passed (avoid wrap issue)
    lda #0
    sec
    sbc scroll_x
    cmp #24
    bcs @score_done           ; screen_x >= 24, not passed yet
    ; Pipe passed - check if already scored
    lda pipes_scored
    and #%00000100            ; Bit 2 = NT1 pipe 0
    bne @score_done           ; Already scored
    ; Score!
    jsr increment_score
    lda pipes_scored
    ora #%00000100
    sta pipes_scored
    jmp @score_done

@check_nt1_scoring:
    ; Viewing NT1 - check NT1 pipe 1 and NT0 pipe 0

    ; NT1 pipe 1: screen_x = 128 - scroll_x
    lda #128
    sec
    sbc scroll_x
    cmp #24
    bcs @check_nt0_pipe0_score ; screen_x >= 24, not passed yet
    ; Pipe passed - check if already scored
    lda pipes_scored
    and #%00001000            ; Bit 3 = NT1 pipe 1
    bne @check_nt0_pipe0_score ; Already scored
    ; Score!
    jsr increment_score
    lda pipes_scored
    ora #%00001000
    sta pipes_scored

@check_nt0_pipe0_score:
    ; NT0 pipe 0: screen_x = 256 - scroll_x (wraps)
    ; Only valid when scroll_x > 232 (pipe actually passed, not wrap-around)
    lda nt0_has_pipes
    beq @score_done           ; NT0 not drawn yet
    lda scroll_x
    cmp #233
    bcc @score_done           ; scroll_x < 233, pipe not yet passed (avoid wrap issue)
    lda #0
    sec
    sbc scroll_x
    cmp #24
    bcs @score_done           ; screen_x >= 24, not passed yet
    ; Pipe passed - check if already scored
    lda pipes_scored
    and #%00000001            ; Bit 0 = NT0 pipe 0
    bne @score_done           ; Already scored
    ; Score!
    jsr increment_score
    lda pipes_scored
    ora #%00000001
    sta pipes_scored

@score_done:
    rts

;===============================================================================
; Increment Score (BCD style, max 999)
;===============================================================================
increment_score:
    inc score_ones
    lda score_ones
    cmp #10
    bcc @score_ok
    lda #0
    sta score_ones
    inc score_tens
    lda score_tens
    cmp #10
    bcc @score_ok
    lda #0
    sta score_tens
    inc score_hundreds
    lda score_hundreds
    cmp #10
    bcc @score_ok
    ; Max score reached (999), clamp
    lda #9
    sta score_hundreds
@score_ok:
    ; Play score sound
    jsr play_score_sound
    rts

;===============================================================================
; Sound Effects
;===============================================================================
play_flap_sound:
    ; Jump-style rising sweep on pulse 1
    lda #%10011000        ; Duty 50%, length enabled, constant vol, vol=8
    sta SQ1_VOL
    ; Sweep: enabled, period=1, negative (pitch rises), shift=3
    lda #%10011011        ; Enable, period=1, negative, shift=3
    sta SQ1_SWEEP
    ; Start frequency ~250Hz (timer ≈ $1BF)
    lda #$BF
    sta SQ1_LO
    lda #%00101001        ; Length index 5, timer high = 1
    sta SQ1_HI
    rts

play_crash_sound:
    ; Hit sound - noise burst
    lda #%00011000        ; Length halt, constant vol, vol=8
    sta NOISE_VOL
    lda #%00000100        ; Noise period 4 (mid-range crunch)
    sta NOISE_LO
    lda #%00000100        ; Short length
    sta NOISE_HI
    ; Falling whistle - descending tone on pulse 1
    lda #%01010111        ; Duty 25% (thin whistle), length halt, constant vol, vol=7
    sta SQ1_VOL
    lda #%10010011        ; Sweep: enable, period=0 (fast), positive (descend), shift=3
    sta SQ1_SWEEP
    lda #$40              ; Start high frequency
    sta SQ1_LO
    lda #%11111000        ; Length halt, timer high = 0
    sta SQ1_HI
    rts

play_ground_hit:
    ; Noise burst only - for hitting ground without pipe collision
    lda #%00011000        ; Length halt, constant vol, vol=8
    sta NOISE_VOL
    lda #%00000100        ; Noise period 4
    sta NOISE_LO
    lda #%00000100        ; Short length
    sta NOISE_HI
    rts

play_score_sound:
    ; Mario coin sound: B5 (short) then E6 (short) - fast staccato
    ; Start with B5
    lda #%10010110        ; Duty 50%, length enabled, constant vol, vol=6
    sta SQ2_VOL
    lda #$00
    sta SQ2_SWEEP         ; Disable sweep completely
    ; B5 = 987.77 Hz, timer = 1789773/(16*987.77)-1 = 112 = $70
    lda #$70
    sta SQ2_LO
    lda #%00001000        ; Length index 1, timer high = 0
    sta SQ2_HI
    ; Switch to E6 in 7 frames (SMB timing)
    lda #1
    sta sound_state
    lda #7
    sta sound_timer
    rts

update_sound:
    ; Called every frame to manage coin sound timing
    lda sound_state
    beq @sound_done       ; State 0 = idle, nothing to do

    ; Decrement timer
    dec sound_timer
    bne @sound_done       ; Timer not expired yet

    ; Timer expired - check state
    lda sound_state
    cmp #1
    beq @switch_to_e6
    cmp #2
    beq @silence_sound
    rts

@switch_to_e6:
    ; Switch to E6 (coin sound)
    lda #$54              ; E6 = 1318 Hz
    sta SQ2_LO
    lda #%00001000
    sta SQ2_HI
    lda #2
    sta sound_state
    lda #14
    sta sound_timer
    rts

@silence_sound:
    lda #%00010000        ; Volume = 0
    sta SQ2_VOL
    lda #0
    sta sound_state
@sound_done:
    rts

;===============================================================================
; Palette Fade Effect
;===============================================================================
apply_fade_palette:
    ; Apply fade based on fade_step (0=normal, 4=black)
    ; Write all 32 palette entries with faded colors
    bit PPU_STATUS
    lda #$3F
    sta PPU_ADDR
    lda #$00
    sta PPU_ADDR          ; PPU address = $3F00

    ; Calculate fade offset: fade_step * 16 (16 colors per fade level)
    lda fade_step
    asl a
    asl a
    asl a
    asl a                 ; A = fade_step * 16
    tax                   ; X = offset into fade table

    ; Write 16 background palette colors
    ldy #16
@write_bg_palette:
    lda fade_palette_bg, x
    sta PPU_DATA
    inx
    dey
    bne @write_bg_palette

    ; Sprite palette starts at same offset
    lda fade_step
    asl a
    asl a
    asl a
    asl a
    tax

    ; Write 16 sprite palette colors
    ldy #16
@write_spr_palette:
    lda fade_palette_spr, x
    sta PPU_DATA
    inx
    dey
    bne @write_spr_palette

    rts

; Fade palette tables (5 levels: 0=normal, 4=black)
; Background palettes (16 colors x 5 levels = 80 bytes)
fade_palette_bg:
    ; Level 0 (normal)
    .byte $22, $22, $30, $22  ; Palette 0: sky + text
    .byte $22, $36, $17, $0F  ; Palette 1: ground
    .byte $22, $29, $1A, $0F  ; Palette 2: pipes
    .byte $22, $30, $21, $0F  ; Palette 3: clouds
    ; Level 1 (-$10)
    .byte $12, $12, $20, $12
    .byte $12, $26, $07, $0F
    .byte $12, $19, $0A, $0F
    .byte $12, $20, $11, $0F
    ; Level 2 (-$20)
    .byte $02, $02, $10, $02
    .byte $02, $16, $07, $0F
    .byte $02, $09, $0A, $0F
    .byte $02, $10, $01, $0F
    ; Level 3 (-$30)
    .byte $0F, $0F, $00, $0F
    .byte $0F, $06, $07, $0F
    .byte $0F, $09, $0A, $0F
    .byte $0F, $00, $01, $0F
    ; Level 4 (black)
    .byte $0F, $0F, $0F, $0F
    .byte $0F, $0F, $0F, $0F
    .byte $0F, $0F, $0F, $0F
    .byte $0F, $0F, $0F, $0F

; Sprite palettes (16 colors x 5 levels = 80 bytes)
fade_palette_spr:
    ; Level 0 (normal)
    .byte $22, $1A, $30, $27  ; Palette 0: Koopa
    .byte $22, $22, $22, $22  ; Palette 1: unused
    .byte $22, $22, $22, $22  ; Palette 2: unused
    .byte $22, $22, $22, $22  ; Palette 3: unused
    ; Level 1 (-$10)
    .byte $12, $0A, $20, $17
    .byte $12, $12, $12, $12
    .byte $12, $12, $12, $12
    .byte $12, $12, $12, $12
    ; Level 2 (-$20)
    .byte $02, $0A, $10, $07
    .byte $02, $02, $02, $02
    .byte $02, $02, $02, $02
    .byte $02, $02, $02, $02
    ; Level 3 (-$30)
    .byte $0F, $0A, $00, $07
    .byte $0F, $0F, $0F, $0F
    .byte $0F, $0F, $0F, $0F
    .byte $0F, $0F, $0F, $0F
    ; Level 4 (black)
    .byte $0F, $0F, $0F, $0F
    .byte $0F, $0F, $0F, $0F
    .byte $0F, $0F, $0F, $0F
    .byte $0F, $0F, $0F, $0F

;===============================================================================
; Background Data Pointer Table
;===============================================================================
; Each background is 1024 bytes (960 nametable tiles + 64 attributes)
; Stored in separate .asm files, included at top of main.asm
;
; Memory layout per background:
;   Bytes 0-959:    Nametable tiles (30 rows x 32 cols)
;   Bytes 960-1023: Attribute table (8 rows x 8 cols)
;
; Index:  0     1     2     3
;         bg0   bg1   bg2   bg3
;         (title screen, future screens...)
;
bg_table_lo:
    .byte <BG0, <BG1, <BG2, <BG3
bg_table_hi:
    .byte >BG0, >BG1, >BG2, >BG3

BG_COUNT = 4    ; 4 backgrounds that loop

;===============================================================================
; Switch to Shell Sprite (Death Animation)
;===============================================================================
switch_to_shell:
    ; Hide top 2 sprites (head/wings disappear)
    lda #$FF
    sta OAM_BUFFER+0      ; Top-left Y (hidden)
    sta OAM_BUFFER+4      ; Top-right Y (hidden)

    ; Update middle sprites to shell top row
    lda #SHELL_TILE_BASE
    sta OAM_BUFFER+9      ; Mid-left tile = $1A
    lda #(SHELL_TILE_BASE + 1)
    sta OAM_BUFFER+13     ; Mid-right tile = $1B

    ; Update bottom sprites to shell bottom row
    lda #(SHELL_TILE_BASE + 2)
    sta OAM_BUFFER+17     ; Bottom-left tile = $1C
    lda #(SHELL_TILE_BASE + 3)
    sta OAM_BUFFER+21     ; Bottom-right tile = $1D
    rts

;===============================================================================
; Switch to Walking Sprite (after landing)
;===============================================================================
switch_to_walking:
    ; Restore all 6 sprites for 2x3 walking Koopa
    ; Set Y positions (bird_y is at ground level)
    lda bird_y
    sta OAM_BUFFER+0      ; Top-left Y
    sta OAM_BUFFER+4      ; Top-right Y
    clc
    adc #8
    sta OAM_BUFFER+8      ; Mid-left Y
    sta OAM_BUFFER+12     ; Mid-right Y
    clc
    adc #8
    sta OAM_BUFFER+16     ; Bottom-left Y
    sta OAM_BUFFER+20     ; Bottom-right Y

    ; Set walking tiles (frame 1) - normal order
    lda #WALK_TILE_BASE
    sta OAM_BUFFER+1      ; Top-left tile
    lda #(WALK_TILE_BASE + 1)
    sta OAM_BUFFER+5      ; Top-right tile
    lda #(WALK_TILE_BASE + 2)
    sta OAM_BUFFER+9      ; Mid-left tile
    lda #(WALK_TILE_BASE + 3)
    sta OAM_BUFFER+13     ; Mid-right tile
    lda #(WALK_TILE_BASE + 4)
    sta OAM_BUFFER+17     ; Bottom-left tile
    lda #(WALK_TILE_BASE + 5)
    sta OAM_BUFFER+21     ; Bottom-right tile

    ; No flip - walking sprites already face left, or flip if they face right
    ; If your walking tiles face right, uncomment the flip:
    ; lda #$40              ; Horizontal flip bit
    lda #$00              ; No flip (tiles face left)
    sta OAM_BUFFER+2
    sta OAM_BUFFER+6
    sta OAM_BUFFER+10
    sta OAM_BUFFER+14
    sta OAM_BUFFER+18
    sta OAM_BUFFER+22
    rts

;===============================================================================
; Update Walking Tiles (animation)
;===============================================================================
update_walk_tiles:
    ; anim_frame is 0 or 6, normal order
    lda anim_frame
    clc
    adc #WALK_TILE_BASE
    sta OAM_BUFFER+1      ; Top-left
    clc
    adc #1
    sta OAM_BUFFER+5      ; Top-right
    clc
    adc #1
    sta OAM_BUFFER+9      ; Mid-left
    clc
    adc #1
    sta OAM_BUFFER+13     ; Mid-right
    clc
    adc #1
    sta OAM_BUFFER+17     ; Bottom-left
    clc
    adc #1
    sta OAM_BUFFER+21     ; Bottom-right
    rts

;===============================================================================
; Update Score Display Sprites
;===============================================================================
update_score_display:
    ; Update sprite tiles based on score digits
    lda score_hundreds
    clc
    adc #DIGIT_TILE_BASE
    sta OAM_BUFFER+25     ; Hundreds digit tile

    lda score_tens
    clc
    adc #DIGIT_TILE_BASE
    sta OAM_BUFFER+29     ; Tens digit tile

    lda score_ones
    clc
    adc #DIGIT_TILE_BASE
    sta OAM_BUFFER+33     ; Ones digit tile
    rts

;===============================================================================
; Title Text Drawing
;===============================================================================
draw_title_text:
    ; Draw "PRESS A OR B" on row 14, "TO PLAY" on row 15
    ; Row 14, column 10 = $21CA
    ; Row 15, column 12 = $21EC (centered under line 1)
    ; Alphabet: A=$20, B=$21, ... Z=$39
    bit PPU_STATUS

    ; Line 1: "PRESS A OR B" at row 14, col 10
    lda #$21
    sta PPU_ADDR
    lda #$CA
    sta PPU_ADDR          ; PPU address = $21CA

    lda #$2F              ; P
    sta PPU_DATA
    lda #$31              ; R
    sta PPU_DATA
    lda #$24              ; E
    sta PPU_DATA
    lda #$32              ; S
    sta PPU_DATA
    lda #$32              ; S
    sta PPU_DATA
    lda #$00              ; (space)
    sta PPU_DATA
    lda #$20              ; A
    sta PPU_DATA
    lda #$00              ; (space)
    sta PPU_DATA
    lda #$2E              ; O
    sta PPU_DATA
    lda #$31              ; R
    sta PPU_DATA
    lda #$00              ; (space)
    sta PPU_DATA
    lda #$21              ; B
    sta PPU_DATA

    ; Line 2: "TO PLAY" at row 15, col 12
    lda #$21
    sta PPU_ADDR
    lda #$EC
    sta PPU_ADDR          ; PPU address = $21EC

    lda #$33              ; T
    sta PPU_DATA
    lda #$2E              ; O
    sta PPU_DATA
    lda #$00              ; (space)
    sta PPU_DATA
    lda #$2F              ; P
    sta PPU_DATA
    lda #$2B              ; L
    sta PPU_DATA
    lda #$20              ; A
    sta PPU_DATA
    lda #$38              ; Y
    sta PPU_DATA
    lda #$48              ; !
    sta PPU_DATA

    ; Fix attribute for text area (attr row 3, byte 4 = $23DC)
    ; Change from $AA (pipe palette) to $FF (cloud/text palette)
    lda #$23
    sta PPU_ADDR
    lda #$DC
    sta PPU_ADDR
    lda #$FF              ; All quadrants use palette 3
    sta PPU_DATA
    rts

;---------------------------------------
; Clear title text (called from NMI)
;---------------------------------------
clear_title_text:
    ; Clear "PRESS A OR B" at row 14, column 10 (12 tiles)
    bit PPU_STATUS
    lda #$21
    sta PPU_ADDR
    lda #$CA
    sta PPU_ADDR          ; PPU address = $21CA
    lda #$00              ; Empty/sky tile
    ldx #12
@clear_line1:
    sta PPU_DATA
    dex
    bne @clear_line1

    ; Clear "TO PLAY!" at row 15, column 12 (8 tiles)
    lda #$21
    sta PPU_ADDR
    lda #$EC
    sta PPU_ADDR          ; PPU address = $21EC
    lda #$00
    ldx #8
@clear_line2:
    sta PPU_DATA
    dex
    bne @clear_line2

    ; Restore attribute for pipe area (attr row 3, byte 4 = $23DC)
    ; Change from $FF (text palette) back to $AA (pipe palette)
    lda #$23
    sta PPU_ADDR
    lda #$DC
    sta PPU_ADDR
    lda #$AA              ; All quadrants use palette 2
    sta PPU_DATA
    rts

;===============================================================================
; Column-Based Pipe/Cloud Drawing (called from NMI during vblank)
;===============================================================================
; Draws one vertical column per frame using PPUCTRL +32 increment mode.
; Spreads redraw work across ~28 frames instead of burst-drawing.
;
; Column layout:
;   idx 0:     Draw pipe attributes FIRST (before any tiles)
;   idx 1-4:   Pipe 0 columns 0-3
;   idx 5-12:  Cloud zone A columns 4-11 (cleared to empty)
;   idx 13-16: Pipe 1 columns 16-19
;   idx 17-24: Cloud zone B columns 20-27 (cleared to empty)
;   idx 25:    Draw cloud 1 (if pattern has one)
;   idx 26:    Draw cloud 2 (if pattern has one)
;   idx 27:    Mark done
;   idx $FF:   Idle (no redraw in progress)
;
; Drawing attributes FIRST ensures pipes always have correct palette,
; even if there's any timing edge case with nametable visibility.
;
; Variables:
;   col_draw_idx  - Current column index (0-24, $FF=idle)
;   col_nt_base   - Nametable being redrawn ($20=NT0, $24=NT1)
;   col_pipe0_gap - Gap row for pipe 0
;   col_pipe1_gap - Gap row for pipe 1
;===============================================================================

draw_column:
    ; Check if drawing is active
    lda col_draw_idx
    cmp #$FF
    bne @active
    rts                   ; Idle, nothing to do

@active:
    ; A already contains col_draw_idx from the check above
    ; Dispatch based on column index
    ; idx 0: Draw pipe attributes FIRST (before any tiles)
    ; idx 1-4: Pipe 0 columns 0-3
    ; idx 5-16: Clear zone A columns 4-15 (between pipe 0 and pipe 1)
    ; idx 17-20: Pipe 1 columns 16-19
    ; idx 21-32: Clear zone B columns 20-31 (after pipe 1)
    ; idx 33: Mark done
    cmp #1
    bcc @draw_attrs       ; 0: Draw pipe attrs first
    cmp #5
    bcc @pipe0_col        ; 1-4: Pipe 0
    cmp #17
    bcc @clear_a_col      ; 5-16: Clear zone A
    cmp #21
    bcc @pipe1_col        ; 17-20: Pipe 1
    cmp #33
    bcc @clear_b_col      ; 21-32: Clear zone B
    jmp @mark_done        ; 33: Mark done

;---------------------------------------
; Attributes (idx 0) - Restore title text attribute for NT0
;---------------------------------------
; NT0 had attr row 3, byte 4 set to $FF for title text palette.
; Restore to $AA (pipe palette) now that text has scrolled off.
@draw_attrs:
    lda col_nt_base
    cmp #$20              ; Is this NT0?
    bne @next_column      ; No, skip (NT1 never had title text)

    ; Restore $23DC to $AA (pipe palette)
    lda #$23
    sta PPU_ADDR
    lda #$DC
    sta PPU_ADDR
    lda #$AA
    sta PPU_DATA
    jmp @next_column

;---------------------------------------
; Pipe 0 columns (idx 1-4 -> cols 0-3)
;---------------------------------------
@pipe0_col:
    ; Column = col_draw_idx - 1
    sec
    sbc #1
    sta pipe_col
    lda col_pipe0_gap
    sta pipe_gap
    jsr draw_pipe_column
    jmp @next_column

;---------------------------------------
; Skip zone A (idx 5-16 -> cols 4-15)
; Don't clear - preserve background decorations
;---------------------------------------
@clear_a_col:
    jmp @next_column

;---------------------------------------
; Pipe 1 columns (idx 17-20 -> cols 16-19)
;---------------------------------------
@pipe1_col:
    ; Column = col_draw_idx - 1 (idx 17->col 16, idx 20->col 19)
    sec
    sbc #1
    sta pipe_col
    lda col_pipe1_gap
    sta pipe_gap
    jsr draw_pipe_column
    jmp @next_column

;---------------------------------------
; Skip zone B (idx 21-32 -> cols 20-31)
; Don't clear - preserve background decorations
;---------------------------------------
@clear_b_col:
    jmp @next_column

;---------------------------------------
; Mark done (idx 33)
;---------------------------------------
@mark_done:
    lda #$FF
    sta col_draw_idx
    rts

;---------------------------------------
; Advance to next column
;---------------------------------------
@next_column:
    inc col_draw_idx
    rts

;===============================================================================
; Draw one vertical pipe column using PPUCTRL +32 mode
; Input: pipe_col (0-31), pipe_gap, col_nt_base
; Draws rows 0-25 (ground at row 26)
;
; Optimized: Uses counted loops instead of per-row comparisons
; Structure: top_body, cap1, cap2, gap(8), cap1, cap2, bot_body
;===============================================================================
draw_pipe_column:
    bit PPU_STATUS        ; Reset PPU latch

    ; Set PPU address to row 0, column pipe_col
    lda col_nt_base
    sta PPU_ADDR
    lda pipe_col
    sta PPU_ADDR

    ; Enable vertical increment mode (+32)
    lda #%10010100        ; NMI on, sprites $0000, bg $1000, +32 increment
    ora scroll_nt
    sta PPU_CTRL

    ; Get column tile index (0-3)
    lda pipe_col
    and #$03
    tax                   ; X = column within pipe (preserved throughout)

    ; --- Top body: rows 0 to (gap-3) ---
    ; Count = gap - 2 (but at least 0)
    lda pipe_gap
    sec
    sbc #2
    beq @top_cap1         ; If gap <= 2, skip top body
    bmi @top_cap1         ; Safety check
    tay                   ; Y = top body count
    lda pipe_top_body_tiles, x
@top_body_loop:
    sta PPU_DATA
    dey
    bne @top_body_loop

@top_cap1:
    ; --- Top cap row 1 ---
    lda pipe_top_cap1_tiles, x
    sta PPU_DATA

@top_cap2:
    ; --- Top cap row 2 ---
    lda pipe_top_cap2_tiles, x
    sta PPU_DATA

@gap:
    ; --- Gap: 8 empty tiles ---
    lda #$00
    ldy #GAP_ROWS         ; 8 rows
@gap_loop:
    sta PPU_DATA
    dey
    bne @gap_loop

@bot_cap1:
    ; --- Bot cap row 1 ---
    lda pipe_bot_cap1_tiles, x
    sta PPU_DATA

@bot_cap2:
    ; --- Bot cap row 2 ---
    lda pipe_bot_cap2_tiles, x
    sta PPU_DATA

@bot_body:
    ; --- Bot body: rows (gap+10) to 25 ---
    ; Count = 26 - (gap + 10) = 16 - gap
    lda #16
    sec
    sbc pipe_gap
    beq @done             ; If gap >= 16, no bot body
    bmi @done             ; Safety check
    tay                   ; Y = bot body count
    lda pipe_bot_body_tiles, x
@bot_body_loop:
    sta PPU_DATA
    dey
    bne @bot_body_loop

@done:
    ; Restore horizontal increment mode (+1)
    lda #%10010000        ; NMI on, sprites $0000, bg $1000, +1 increment
    ora scroll_nt
    sta PPU_CTRL
    rts

; Pipe tile lookup tables (indexed by column 0-3)
pipe_top_body_tiles:
    .byte $19, $1A, $1B, $1C
pipe_top_cap1_tiles:
    .byte $15, $16, $17, $18
pipe_top_cap2_tiles:
    .byte $11, $12, $13, $14
pipe_bot_cap1_tiles:
    .byte $05, $06, $07, $08
pipe_bot_cap2_tiles:
    .byte $09, $0A, $0B, $0C
pipe_bot_body_tiles:
    .byte $0D, $0E, $0F, $10

;===============================================================================
; Draw one vertical empty column (for cloud zones)
; Input: pipe_col, col_nt_base
; Clears rows 0-25 to empty sky tile
;===============================================================================
draw_empty_column:
    bit PPU_STATUS        ; Reset PPU latch

    ; Set PPU address to row 0, column pipe_col
    lda col_nt_base
    sta PPU_ADDR
    lda pipe_col
    sta PPU_ADDR

    ; Enable vertical increment mode (+32)
    lda #%10010100        ; NMI on, sprites $0000, bg $1000, +32 increment
    ora scroll_nt
    sta PPU_CTRL

    ; Write 26 empty tiles (rows 0-25)
    lda #$00
    ldy #26
@clear_loop:
    sta PPU_DATA
    dey
    bne @clear_loop

    ; Restore horizontal increment mode (+1)
    lda #%10010000        ; NMI on, sprites $0000, bg $1000, +1 increment
    ora scroll_nt
    sta PPU_CTRL
    rts

;===============================================================================
; Start column-based redraw for a nametable
; Input: A = nametable base ($20=NT0, $24=NT1)
; Generates random gaps for both pipes and starts drawing
;===============================================================================
start_column_redraw:
    sta col_nt_base

    ; Mark NT0 as having pipes (for collision detection)
    ; NT1 always has pipes, NT0 gets them after first wrap
    cmp #$24
    beq @gen_gaps         ; NT1 - skip to gap generation

    ; NT0 - mark as having pipes
    lda #1
    sta nt0_has_pipes
    ; (Attributes already set at init - no PPU writes needed here)

@gen_gaps:
    ; Generate random gap for pipe 0
    jsr rand_lfsr
    jsr calc_pipe_gap
    sta col_pipe0_gap
    ; Also store in collision tracking variable
    lda col_nt_base
    cmp #$24
    beq @store_nt1_p0
    lda col_pipe0_gap
    sta nt0_pipe0_gap
    jmp @gen_gap1
@store_nt1_p0:
    lda col_pipe0_gap
    sta nt1_pipe0_gap

@gen_gap1:
    ; Generate random gap for pipe 1
    jsr rand_lfsr
    jsr calc_pipe_gap
    sta col_pipe1_gap
    ; Also store in collision tracking variable
    lda col_nt_base
    cmp #$24
    beq @store_nt1_p1
    lda col_pipe1_gap
    sta nt0_pipe1_gap
    jmp @start_draw
@store_nt1_p1:
    lda col_pipe1_gap
    sta nt1_pipe1_gap

@start_draw:
    ; Start drawing at column 0
    lda #0
    sta col_draw_idx
    rts

;---------------------------------------
; Calculate pipe gap from LFSR state
; Returns gap value (GAP_MIN to GAP_MAX) in A
;---------------------------------------
calc_pipe_gap:
    lda rng_lo
    eor rng_hi            ; Mix both bytes
    and #$0F              ; 0-15
    cmp #(GAP_MAX - GAP_MIN + 1)
    bcc @in_range         ; < 12, use as-is
    sec
    sbc #8                ; 12-15 -> 4-7
@in_range:
    clc
    adc #GAP_MIN          ; Add base (4)
    rts

;===============================================================================
; Legacy draw_pipes_in_nt (for initial NT1 setup during init)
; This is called 8 times during init to draw NT1 pipes before game starts
; Uses the old burst-draw approach (outside vblank, no constraint)
;===============================================================================
draw_pipes_in_nt:
    ; Multi-frame redraw (used only during init)
    ; pipe_redraw = 0: draw pipe 0 body+cap, set to 1
    ; pipe_redraw = 1: draw pipe 0 gap clear, set to 2
    ; pipe_redraw = 2: draw pipe 0 bottom, set to 3
    ; pipe_redraw = 3: draw pipe 0 attrs, set to 4
    ; pipe_redraw = 4: draw pipe 1 body+cap, set to 5
    ; pipe_redraw = 5: draw pipe 1 gap clear, set to 6
    ; pipe_redraw = 6: draw pipe 1 bottom, set to 7
    ; pipe_redraw = 7: draw pipe 1 attrs, done

    bit PPU_STATUS        ; Reset PPU latch

    lda pipe_redraw
    bne @not0
    jmp @frame0
@not0:
    cmp #1
    bne @not1
    jmp @frame1
@not1:
    cmp #2
    bne @not2
    jmp @frame2
@not2:
    cmp #3
    bne @not3
    jmp @frame3
@not3:
    cmp #4
    bne @not4
    jmp @frame4
@not4:
    cmp #5
    bne @not5
    jmp @frame5
@not5:
    cmp #6
    bne @not6
    jmp @frame6
@not6:
    ; Frame 7: Draw pipe 1 bottom
    jsr draw_pipe_bottom
    lda #$FF
    sta pipe_redraw       ; Done with init
    rts

@frame0:
    ; Frame 0: Draw pipe 0 body+cap
    lda #0
    sta pipe_col
    ; Save gap to correct per-nametable variable
    lda nt_base
    cmp #$24
    beq @frame0_nt1
    ; NT0 - save gap and mark as having pipes
    lda pipe_gap
    sta nt0_pipe0_gap
    lda #1
    sta nt0_has_pipes
    jmp @frame0_draw
@frame0_nt1:
    lda pipe_gap
    sta nt1_pipe0_gap
@frame0_draw:
    jsr draw_pipe_body_cap
    lda #1
    sta pipe_redraw
    rts

@frame1:
    ; Frame 1: Draw pipe 0 gap clear
    jsr draw_pipe_gap
    lda #2
    sta pipe_redraw
    rts

@frame2:
    ; Frame 2: Draw pipe 0 bottom
    jsr draw_pipe_bottom
    lda #3
    sta pipe_redraw
    rts

@frame3:
    ; Frame 3: Attrs now static (loaded at init), just gen next gap
    jsr next_pipe_gap
    lda #4
    sta pipe_redraw
    rts

@frame4:
    ; Frame 4: Draw pipe 1 body+cap
    lda #16
    sta pipe_col
    ; Save gap to correct per-nametable variable
    lda nt_base
    cmp #$24
    beq @frame4_nt1
    lda pipe_gap
    sta nt0_pipe1_gap
    jmp @frame4_draw
@frame4_nt1:
    lda pipe_gap
    sta nt1_pipe1_gap
@frame4_draw:
    jsr draw_pipe_body_cap
    lda #5
    sta pipe_redraw
    rts

@frame5:
    ; Frame 5: Draw pipe 1 gap clear
    jsr draw_pipe_gap
    lda #6
    sta pipe_redraw
    rts

@frame6:
    ; Frame 6: Draw pipe 1 bottom (attrs now static)
    jsr draw_pipe_bottom
    lda #7
    sta pipe_redraw
    rts

;---------------------------------------
; Set pipe_gap to random value (GAP_MIN to GAP_MAX)
; Uses LFSR for pseudo-random generation
;---------------------------------------
next_pipe_gap:
    jsr rand_lfsr         ; Get next random value
    lda rng_lo
    eor rng_hi            ; Mix both bytes for better distribution
    and #$0F              ; 0-15
    cmp #(GAP_MAX - GAP_MIN + 1)
    bcc @in_range         ; < 12, use as-is
    ; Value 12-15, subtract 8 to get 4-7
    sec
    sbc #8
@in_range:
    clc
    adc #GAP_MIN          ; Add base (4)
    sta pipe_gap
    rts

;---------------------------------------
; 16-bit LFSR (Galois)
; Taps: bits 16, 14, 13, 11 (polynomial $B400)
; Period: 65535
; ~30 cycles - negligible for vblank
;---------------------------------------
rand_lfsr:
    lda rng_lo
    lsr a                 ; Shift right, bit 0 -> carry
    ror rng_hi            ; Rotate high byte
    ror rng_lo            ; Rotate low byte
    bcc @no_tap           ; If carry clear, skip XOR
    ; XOR with $B4 on high byte (taps for maximal LFSR)
    lda rng_hi
    eor #$B4
    sta rng_hi
@no_tap:
    rts

;===============================================================================
; Unified Pipe Drawing
; Uses: nt_base ($20=NT0, $24=NT1), pipe_col (0 or 16)
;===============================================================================

;---------------------------------------
; Draw pipe body + cap (top pipe only)
; Uses pipe_gap to determine layout
;---------------------------------------
draw_pipe_body_cap:
    ; Top pipe body (rows 0 to pipe_gap-3)
    ldx #0
@top_body:
    jsr set_row_ppu_addr
    lda #$19
    sta PPU_DATA
    lda #$1A
    sta PPU_DATA
    lda #$1B
    sta PPU_DATA
    lda #$1C
    sta PPU_DATA
    inx
    txa
    clc
    adc #2                ; A = X + 2
    cmp pipe_gap          ; compare (X + 2) to pipe_gap
    bcc @top_body         ; continue if X + 2 < pipe_gap (i.e. X < pipe_gap - 2)

    ; Top pipe cap row 1 (under lip) - row = pipe_gap - 2
    ldx pipe_gap
    dex
    dex                   ; X = pipe_gap - 2
    jsr set_row_ppu_addr
    lda #$15
    sta PPU_DATA
    lda #$16
    sta PPU_DATA
    lda #$17
    sta PPU_DATA
    lda #$18
    sta PPU_DATA

    ; Top pipe cap row 2 (lip edge) - row = pipe_gap - 1
    ldx pipe_gap
    dex                   ; X = pipe_gap - 1
    jsr set_row_ppu_addr
    lda #$11
    sta PPU_DATA
    lda #$12
    sta PPU_DATA
    lda #$13
    sta PPU_DATA
    lda #$14
    sta PPU_DATA
    rts

;---------------------------------------
; Draw pipe gap (clear with empty tiles)
; Uses pipe_gap to determine layout
;---------------------------------------
draw_pipe_gap:
    ; Gap area (rows pipe_gap to pipe_gap+7) - clear with empty tiles
    ldx pipe_gap
@clear_gap:
    jsr set_row_ppu_addr
    lda #$00              ; Empty/sky tile
    sta PPU_DATA
    sta PPU_DATA
    sta PPU_DATA
    sta PPU_DATA
    inx
    txa
    sec
    sbc pipe_gap          ; A = X - pipe_gap
    cmp #GAP_ROWS
    bcc @clear_gap        ; continue while X < pipe_gap + 8
    rts

;---------------------------------------
; Draw pipe bottom half: cap + body
; Uses pipe_gap to determine layout
;---------------------------------------
draw_pipe_bottom:
    ; Bottom pipe cap row 1 - row = pipe_gap + 8
    lda pipe_gap
    clc
    adc #GAP_ROWS         ; A = pipe_gap + 8
    tax
    jsr set_row_ppu_addr
    lda #$05
    sta PPU_DATA
    lda #$06
    sta PPU_DATA
    lda #$07
    sta PPU_DATA
    lda #$08
    sta PPU_DATA

    ; Bottom pipe cap row 2 - row = pipe_gap + 9
    lda pipe_gap
    clc
    adc #(GAP_ROWS + 1)   ; A = pipe_gap + 9
    tax
    jsr set_row_ppu_addr
    lda #$09
    sta PPU_DATA
    lda #$0A
    sta PPU_DATA
    lda #$0B
    sta PPU_DATA
    lda #$0C
    sta PPU_DATA

    ; Bottom pipe body (rows pipe_gap+10 to 25)
    lda pipe_gap
    clc
    adc #(GAP_ROWS + 2)   ; A = pipe_gap + 10
    tax
@bot_body:
    jsr set_row_ppu_addr
    lda #$0D
    sta PPU_DATA
    lda #$0E
    sta PPU_DATA
    lda #$0F
    sta PPU_DATA
    lda #$10
    sta PPU_DATA
    inx
    cpx #26
    bcc @bot_body         ; continue while X < 26

    rts

;---------------------------------------
; Helper: Set PPU address for row X at pipe_col
; X = row number (0-29)
; Preserves X
;---------------------------------------
set_row_ppu_addr:
    txa
    lsr a
    lsr a
    lsr a                 ; A = row / 8
    clc
    adc nt_base           ; A = nt_base + (row / 8)
    sta PPU_ADDR
    txa
    and #$07
    asl a
    asl a
    asl a
    asl a
    asl a                 ; A = (row & 7) * 32
    clc
    adc pipe_col          ; + column
    sta PPU_ADDR
    rts

;===============================================================================
; Background Loading Routines
;===============================================================================
; Loads a background (1024 bytes) from ROM to a nametable.
; Each background includes 960 tile bytes + 64 attribute bytes.
;
; Usage:
;   lda #0              ; background index
;   sta bg_index
;   lda #$20            ; target nametable ($20=NT0, $24=NT1)
;   jsr load_background
;
; Or to cycle through backgrounds:
;   jsr next_background
;===============================================================================

;---------------------------------------
; Start Multi-Frame Background Load
; Queues background for loading across multiple vblanks (no flash)
; Input: bg_index already set, A = nametable base ($20 or $24)
;---------------------------------------
load_bg_safe:
    sta bg_load_nt        ; Store target nametable
    lda #0
    sta bg_load_row       ; Start loading from row 0
    rts

;---------------------------------------
; Load Background Rows (called from NMI)
; Loads 1 row per frame, skipping pipe columns (0-3 and 16-19)
; This prevents overwriting pipe tiles during parallel loading
;---------------------------------------
load_bg_rows:
    lda bg_load_row
    cmp #$FF
    bne @active
    rts                   ; Idle, nothing to do

@active:
    ; Setup source pointer: bg_table[bg_index] + bg_load_row * 32
    ldx bg_index
    lda bg_table_lo, x
    sta $FE
    lda bg_table_hi, x
    sta $FF

    ; Add row offset (bg_load_row * 32)
    lda bg_load_row
    lsr a                 ; row / 2
    lsr a                 ; row / 4
    lsr a                 ; row / 8 (high byte contribution)
    clc
    adc $FF
    sta $FF               ; Adjust high byte

    lda bg_load_row
    asl a
    asl a
    asl a
    asl a
    asl a                 ; row * 32 (low 8 bits)
    clc
    adc $FE
    sta $FE
    bcc @no_carry
    inc $FF
@no_carry:

    ; Calculate PPU high byte for this row
    lda bg_load_nt
    ldx bg_load_row
    cpx #8
    bcc @calc_low
    clc
    adc #1                ; Rows 8-15 -> add $100
    cpx #16
    bcc @calc_low
    clc
    adc #1                ; Rows 16-23 -> add $200
    cpx #24
    bcc @calc_low
    clc
    adc #1                ; Rows 24-29 -> add $300
@calc_low:
    sta $FD               ; Save PPU high byte

    ; Calculate PPU low byte base for this row
    lda bg_load_row
    and #$07              ; Row within 256-byte page
    asl a
    asl a
    asl a
    asl a
    asl a                 ; * 32
    sta $FC               ; Save PPU low byte base

    ; --- Write columns 4-15 (12 bytes) ---
    bit PPU_STATUS
    lda $FD
    sta PPU_ADDR
    lda $FC
    clc
    adc #4                ; Start at column 4
    sta PPU_ADDR

    ldy #4                ; Source offset
@copy_zone_a:
    lda ($FE), y
    sta PPU_DATA
    iny
    cpy #16               ; Stop at column 16
    bne @copy_zone_a

    ; --- Write columns 20-31 (12 bytes) ---
    bit PPU_STATUS
    lda $FD
    sta PPU_ADDR
    lda $FC
    clc
    adc #20               ; Start at column 20
    sta PPU_ADDR

    ldy #20               ; Source offset
@copy_zone_b:
    lda ($FE), y
    sta PPU_DATA
    iny
    cpy #32               ; Stop at column 32
    bne @copy_zone_b

    ; Advance to next row (1 row per frame now)
    inc bg_load_row
    lda bg_load_row
    cmp #30               ; Done with all 30 rows?
    bcc @not_done
    lda #$FF              ; Mark as idle
    sta bg_load_row
@not_done:
    rts

;---------------------------------------
; Load Background Tiles Only (no attributes)
; Input: bg_index = background to load (0 to BG_COUNT-1)
;        A = nametable base ($20=NT0, $24=NT1)
; Uses: $FE-$FF as pointer
; Loads 960 bytes (30 rows x 32 cols)
;---------------------------------------
load_background_only:
    pha                   ; Save nametable base

    ; Setup pointer from table
    ldx bg_index
    lda bg_table_lo, x
    sta $FE               ; pointer low byte
    lda bg_table_hi, x
    sta $FF               ; pointer high byte

    ; Set PPU address to target nametable
    bit PPU_STATUS
    pla                   ; Restore nametable base
    sta PPU_ADDR
    lda #$00
    sta PPU_ADDR

    ; Copy 960 bytes (3 pages + 192 bytes)
    ; Page 0-2: 768 bytes
    ldx #3
    ldy #0
@load_full_page:
    lda ($FE), y
    sta PPU_DATA
    iny
    bne @load_full_page
    inc $FF
    dex
    bne @load_full_page

    ; Remaining 192 bytes (960 - 768 = 192 = $C0)
    ldy #0
@load_partial:
    lda ($FE), y
    sta PPU_DATA
    iny
    cpy #$C0              ; 192 bytes
    bne @load_partial

    rts

;---------------------------------------
; Initialize static attribute tables for both nametables
; Called once at init - never changes during gameplay
;
; Layout:
;   Pipe cols (0, 4): palette 2 ($AA) - pipes
;   Other cols rows 0-5: palette 3 ($FF) - sky/clouds
;   Other cols row 6: $F5 (top=pal3 sky, bottom=pal1 ground)
;   Other cols row 7: palette 1 ($55) - ground
;---------------------------------------
init_attributes:
    ; Set up NT0 attributes
    lda #$23
    jsr write_attr_table

    ; Set up NT1 attributes
    lda #$27
    jmp write_attr_table

;---------------------------------------
; Write attribute table for one nametable
; Input: A = high byte of attr table ($23 or $27)
;---------------------------------------
write_attr_table:
    sta $FF               ; Save high byte

    ; Write 8 rows of attributes
    ; Each row is 8 bytes, rows are at offsets $C0, $C8, $D0, $D8, $E0, $E8, $F0, $F8

    ; Rows 0-4: pipe cols = $AA (pal 2), others = $00 (pal 0)
    lda #$C0              ; Starting offset
    ldx #5                ; 5 rows (0-4)
@sky_rows:
    pha                   ; Save offset
    bit PPU_STATUS
    lda $FF
    sta PPU_ADDR
    pla
    pha
    sta PPU_ADDR
    ; Write 8 bytes: $AA, $FF, $FF, $FF, $AA, $FF, $FF, $FF
    ; Pipe cols use palette 2, sky cols use palette 3 (for clouds)
    lda #$AA
    sta PPU_DATA          ; Col 0 (pipe)
    lda #$FF
    sta PPU_DATA          ; Col 1 (sky/clouds)
    sta PPU_DATA          ; Col 2 (sky/clouds)
    sta PPU_DATA          ; Col 3 (sky/clouds)
    lda #$AA
    sta PPU_DATA          ; Col 4 (pipe)
    lda #$FF
    sta PPU_DATA          ; Col 5 (sky/clouds)
    sta PPU_DATA          ; Col 6 (sky/clouds)
    sta PPU_DATA          ; Col 7 (sky/clouds)
    pla
    clc
    adc #8                ; Next row
    dex
    bne @sky_rows

    ; Row 5 ($E8): all $AA (palette 2 for bushes)
    bit PPU_STATUS
    lda $FF
    sta PPU_ADDR
    lda #$E8
    sta PPU_ADDR
    lda #$AA
    sta PPU_DATA
    sta PPU_DATA
    sta PPU_DATA
    sta PPU_DATA
    sta PPU_DATA
    sta PPU_DATA
    sta PPU_DATA
    sta PPU_DATA

    ; Row 6 ($F0): $5A (top=pal2 bushes, bottom=pal1 floor)
    bit PPU_STATUS
    lda $FF
    sta PPU_ADDR
    lda #$F0
    sta PPU_ADDR
    lda #$5A
    sta PPU_DATA
    sta PPU_DATA
    sta PPU_DATA
    sta PPU_DATA
    sta PPU_DATA
    sta PPU_DATA
    sta PPU_DATA
    sta PPU_DATA

    ; Row 7 ($F8): all $55 (palette 1 for floor)
    bit PPU_STATUS
    lda $FF
    sta PPU_ADDR
    lda #$F8
    sta PPU_ADDR
    lda #$55
    sta PPU_DATA
    sta PPU_DATA
    sta PPU_DATA
    sta PPU_DATA
    sta PPU_DATA
    sta PPU_DATA
    sta PPU_DATA
    sta PPU_DATA

    rts

;---------------------------------------
; Advance to Next Background (with wrap)
; Increments bg_index, wraps at BG_COUNT
; Then loads the new background into NT0
;---------------------------------------
next_background:
    inc bg_index
    lda bg_index
    cmp #BG_COUNT
    bcc @no_wrap
    lda #0
    sta bg_index
@no_wrap:
    lda #$20              ; Load into NT0
    jmp load_background_only

;---------------------------------------
; Advance next_bg_idx (with wrap)
; Called after loading a background to prepare for next wrap
;---------------------------------------
advance_next_bg:
    inc next_bg_idx
    lda next_bg_idx
    cmp #BG_COUNT
    bcc @adv_done
    lda #0
    sta next_bg_idx
@adv_done:
    rts

;===============================================================================
; MMC1 Write Routines
;===============================================================================
mmc1_write_8000:
    ; Write value in A to MMC1 control register ($8000)
    ; MMC1 uses a serial interface: write 5 bits, one at a time
    sta $8000
    lsr a
    sta $8000
    lsr a
    sta $8000
    lsr a
    sta $8000
    lsr a
    sta $8000
    rts

mmc1_write_A000:
    ; Write value in A to MMC1 CHR bank 0 ($A000)
    sta $A000
    lsr a
    sta $A000
    lsr a
    sta $A000
    lsr a
    sta $A000
    lsr a
    sta $A000
    rts

mmc1_write_E000:
    ; Write value in A to MMC1 PRG bank ($E000)
    sta $E000
    lsr a
    sta $E000
    lsr a
    sta $E000
    lsr a
    sta $E000
    lsr a
    sta $E000
    rts

;===============================================================================
; Hi-Score Routines
;===============================================================================
load_hiscore:
    ; Load hi-score from SRAM if valid, otherwise initialize to 000
    ; Check magic bytes
    lda SRAM_MAGIC_1
    cmp #SRAM_MAGIC_VAL1
    bne @init_hiscore
    lda SRAM_MAGIC_2
    cmp #SRAM_MAGIC_VAL2
    bne @init_hiscore

    ; Validate checksum: (H + T + O) XOR $55 should equal stored checksum
    lda SRAM_HISCORE_H
    clc
    adc SRAM_HISCORE_T
    clc
    adc SRAM_HISCORE_O
    eor #$55
    cmp SRAM_CHECKSUM
    bne @init_hiscore

    ; Validate digits are 0-9
    lda SRAM_HISCORE_H
    cmp #10
    bcs @init_hiscore
    lda SRAM_HISCORE_T
    cmp #10
    bcs @init_hiscore
    lda SRAM_HISCORE_O
    cmp #10
    bcs @init_hiscore

    ; Valid! Load hi-score to zero page
    lda SRAM_HISCORE_H
    sta hiscore_hundreds
    lda SRAM_HISCORE_T
    sta hiscore_tens
    lda SRAM_HISCORE_O
    sta hiscore_ones
    rts

@init_hiscore:
    ; Invalid or first boot - initialize to 000
    lda #0
    sta hiscore_ones
    sta hiscore_tens
    sta hiscore_hundreds
    ; Save initial values to SRAM
    jsr save_hiscore
    rts

save_hiscore:
    ; Save hi-score to SRAM with magic bytes and checksum
    lda #SRAM_MAGIC_VAL1
    sta SRAM_MAGIC_1
    lda #SRAM_MAGIC_VAL2
    sta SRAM_MAGIC_2

    lda hiscore_hundreds
    sta SRAM_HISCORE_H
    lda hiscore_tens
    sta SRAM_HISCORE_T
    lda hiscore_ones
    sta SRAM_HISCORE_O

    ; Calculate checksum: (H + T + O) XOR $55
    lda hiscore_hundreds
    clc
    adc hiscore_tens
    clc
    adc hiscore_ones
    eor #$55
    sta SRAM_CHECKSUM
    rts

check_update_hiscore:
    ; Compare current score with hi-score
    ; If score > hiscore, update hiscore and save
    ; Compare hundreds first
    lda score_hundreds
    cmp hiscore_hundreds
    bcc @no_update         ; score < hiscore
    bne @update            ; score > hiscore

    ; Hundreds equal, compare tens
    lda score_tens
    cmp hiscore_tens
    bcc @no_update
    bne @update

    ; Tens equal, compare ones
    lda score_ones
    cmp hiscore_ones
    bcc @no_update
    beq @no_update         ; Equal is not a new high score

@update:
    ; New high score!
    lda score_ones
    sta hiscore_ones
    lda score_tens
    sta hiscore_tens
    lda score_hundreds
    sta hiscore_hundreds
    jsr save_hiscore
@no_update:
    rts

;===============================================================================
; Hi-Score Display Routines
;===============================================================================
update_hiscore_display:
    ; Hi-score display disabled for now (CHR tiles not ready)
    ; TODO: Enable display once tiles are added
    ; Hide all 5 hi-score sprites
    lda #$FF
    sta OAM_BUFFER+36     ; Hide 'H'
    sta OAM_BUFFER+40     ; Hide 'I'
    sta OAM_BUFFER+44     ; Hide hundreds
    sta OAM_BUFFER+48     ; Hide tens
    sta OAM_BUFFER+52     ; Hide ones
    rts

;===============================================================================
; CHR-ROM
;===============================================================================
.segment "CHARS"

; Include external CHR file (8KB)
; Bank 0 ($0000-$0FFF): Sprites
; Bank 1 ($1000-$1FFF): Background
.incbin "../chr/graphics.chr"
