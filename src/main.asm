; Flappy Bird for NES
; main.asm - Entry point

.include "nes.inc"
.include "constants.inc"

;===============================================================================
; iNES Header
;===============================================================================
.segment "HEADER"
    .byte "NES", $1A      ; iNES magic number
    .byte $02             ; PRG-ROM: 2 x 16KB = 32KB
    .byte $01             ; CHR-ROM: 1 x 8KB = 8KB
    .byte $01             ; Flags 6: vertical mirroring, no battery, no trainer, NROM
    .byte $00             ; Flags 7: mapper 0 (NROM)
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

    ; Clear both nametables (VRAM persists on reset)
    bit PPU_STATUS
    lda #$20
    sta PPU_ADDR
    lda #$00
    sta PPU_ADDR          ; PPU address = $2000
    tax                   ; X = 0, A = 0 (sky tile)
    ldy #8                ; 8 pages = 2048 bytes (NT0 + NT1)
@clear_nametables:
    sta PPU_DATA
    inx
    bne @clear_nametables
    dey
    bne @clear_nametables

    ; Draw "PRESS A OR B" title text in NT0
    jsr draw_title_text

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

    ; Set attribute tables
    ; Sky area (rows 0-5): palette 3 for clouds
    ; Ground area (rows 6-7): palette 1

    ; NT0 sky attributes (rows 0-5 = 48 bytes at $23C0-$23EF)
    lda #$23
    sta PPU_ADDR
    lda #$C0
    sta PPU_ADDR          ; $23C0 = attribute row 0
    lda #$FF              ; %11111111 = palette 3 for all quadrants
    ldx #48               ; 6 rows * 8 bytes
@attr0_sky:
    sta PPU_DATA
    dex
    bne @attr0_sky

    ; NT0 ground attributes (rows 6-7 = 16 bytes at $23F0-$23FF)
    lda #$55              ; %01010101 = palette 1 for all
    ldx #16
@attr0_ground:
    sta PPU_DATA
    dex
    bne @attr0_ground

    ; NT1 sky attributes (rows 0-5 = 48 bytes at $27C0-$27EF)
    lda #$27
    sta PPU_ADDR
    lda #$C0
    sta PPU_ADDR          ; $27C0 = attribute row 0
    lda #$FF              ; %11111111 = palette 3 for all quadrants
    ldx #48
@attr1_sky:
    sta PPU_DATA
    dex
    bne @attr1_sky

    ; NT1 ground attributes (rows 6-7 = 16 bytes at $27F0-$27FF)
    lda #$55              ; %01010101 = palette 1 for all
    ldx #16
@attr1_ground:
    sta PPU_DATA
    dex
    bne @attr1_ground

    ;=========================================================================
    ; CLOUDS - Randomized placement
    ;=========================================================================
    bit PPU_STATUS

    ; Draw random clouds in NT0
    lda #$20
    sta nt_base
    jsr draw_random_clouds

    ; Draw random clouds in NT1
    lda #$24
    sta nt_base
    jsr draw_random_clouds

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
    ; Bird hit ground - start stunned state
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
    ; Queue column-based redraw for the nametable that just went off-screen
    ; scroll_nt = 1: switched TO NT1, queue NT0 redraw
    ; scroll_nt = 0: switched TO NT0, queue NT1 redraw
    beq @queue_nt1
    ; Switched to NT1 - queue NT0 redraw
    ; Clear NT0 scored flags (bits 0-1)
    lda pipes_scored
    and #%11111100
    sta pipes_scored
    lda #$20
    jsr start_column_redraw
    jmp @no_scroll
@queue_nt1:
    ; Switched to NT0 - queue NT1 redraw
    ; Clear NT1 scored flags (bits 2-3)
    lda pipes_scored
    and #%11110011
    sta pipes_scored
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
    lda #1
    sta clear_title       ; Queue title clear for next NMI
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

    ; Column-based pipe/cloud drawing (one column per frame)
    jsr draw_column

    ; Check if we need to clear title text
    lda clear_title
    beq @no_clear_title
    jsr clear_title_text
    lda #0
    sta clear_title
@no_clear_title:

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
    ; Rectangle collision: bird (56,bird_y)-(72,bird_y+16) vs pipes
    ; Top pipe: Y from 0 to gap_top_y
    ; Bottom pipe: Y from gap_top_y+64 to ground
    ;
    ; Bird safe if: bird_y >= gap_top_y AND bird_y+16 <= gap_top_y+64

    ; Calculate gap_top_y = gap * 8
    asl a
    asl a
    asl a                 ; A = gap_top_y
    sta pipe0_drawn_gap

    ; Check top pipe: bird_y < gap_top_y means bird top is in top pipe
    lda bird_y
    cmp pipe0_drawn_gap   ; compare bird_y with gap_top_y
    bcc @collision        ; bird_y < gap_top_y, hit top pipe

    ; Check bottom pipe: bird_y+16 > gap_top_y+64 means bird bottom is in bottom pipe
    ; Equivalent: bird_y > gap_top_y+48
    lda pipe0_drawn_gap
    clc
    adc #(GAP_ROWS * 8)   ; A = gap_top_y + 64 (gap bottom / bottom pipe top)
    sec
    sbc #16               ; A = gap_top_y + 48 (max safe bird_y)
    cmp bird_y            ; compare threshold with bird_y
    bcc @collision        ; threshold < bird_y, bird bottom in pipe

@no_collision:
    rts

@collision:
    ; Bird hit pipe - start dying
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
    ; Draw "PRESS A OR B" in front of bird
    ; Row 14, column 10 = $21CA
    ; Alphabet: A=$20, B=$21, ... Z=$39
    ; P=$2F, R=$31, E=$24, S=$32, A=$20, O=$2E, B=$21
    bit PPU_STATUS
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
@clear_loop:
    sta PPU_DATA
    dex
    bne @clear_loop
    rts

;===============================================================================
; Column-Based Pipe/Cloud Drawing (called from NMI during vblank)
;===============================================================================
; Draws one vertical column per frame using PPUCTRL +32 increment mode.
; Spreads redraw work across the entire scroll cycle (~128 frames per NT).
;
; Column layout (24 active columns):
;   idx 0-3:   Pipe 0 columns 0-3
;   idx 4-11:  Cloud zone A columns 4-11
;   idx 12-15: Pipe 1 columns 16-19
;   idx 16-23: Cloud zone B columns 20-27
;   idx 24:    Attributes for pipe 0
;   idx 25:    Attributes for pipe 1
;   idx 26:    Draw clouds
;   idx $FF:   Idle (no redraw in progress)
;
; Variables:
;   col_draw_idx  - Current column index (0-26, $FF=idle)
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
    ; Dispatch based on column index
    cmp #4
    bcc @pipe0_col        ; 0-3: Pipe 0
    cmp #12
    bcc @cloud_a_col      ; 4-11: Cloud zone A
    cmp #16
    bcc @pipe1_col        ; 12-15: Pipe 1
    cmp #24
    bcc @cloud_b_col      ; 16-23: Cloud zone B
    cmp #24
    beq @pipe0_attrs      ; 24: Pipe 0 attributes
    cmp #25
    beq @pipe1_attrs      ; 25: Pipe 1 attributes
    ; 26: Draw clouds and finish
    jmp @draw_clouds

;---------------------------------------
; Pipe 0 columns (idx 0-3 -> cols 0-3)
;---------------------------------------
@pipe0_col:
    ; Column = col_draw_idx
    sta pipe_col
    lda col_pipe0_gap
    sta pipe_gap
    jsr draw_pipe_column
    jmp @next_column

;---------------------------------------
; Cloud zone A (idx 4-11 -> cols 4-11)
;---------------------------------------
@cloud_a_col:
    ; Column = col_draw_idx (4-11)
    sta pipe_col
    jsr draw_empty_column
    jmp @next_column

;---------------------------------------
; Pipe 1 columns (idx 12-15 -> cols 16-19)
;---------------------------------------
@pipe1_col:
    ; Column = col_draw_idx - 12 + 16 = col_draw_idx + 4
    clc
    adc #4                ; idx 12->col 16, idx 13->col 17, etc.
    sta pipe_col
    lda col_pipe1_gap
    sta pipe_gap
    jsr draw_pipe_column
    jmp @next_column

;---------------------------------------
; Cloud zone B (idx 16-23 -> cols 20-27)
;---------------------------------------
@cloud_b_col:
    ; Column = col_draw_idx + 4 (idx 16->col 20, idx 17->col 21, etc.)
    clc
    adc #4
    sta pipe_col
    jsr draw_empty_column
    jmp @next_column

;---------------------------------------
; Pipe 0 attributes
;---------------------------------------
@pipe0_attrs:
    bit PPU_STATUS        ; Reset PPU latch
    lda col_nt_base
    sta nt_base
    jsr draw_pipe0_attrs_only
    jmp @next_column

;---------------------------------------
; Pipe 1 attributes
;---------------------------------------
@pipe1_attrs:
    bit PPU_STATUS        ; Reset PPU latch
    lda col_nt_base
    sta nt_base
    jsr draw_pipe1_attrs_only
    jmp @next_column

;---------------------------------------
; Draw clouds and finish
;---------------------------------------
@draw_clouds:
    bit PPU_STATUS        ; Reset PPU latch
    lda col_nt_base
    sta nt_base
    jsr draw_random_clouds
    ; Mark as done
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
    ora scroll_nt         ; Preserve current nametable for rendering
    sta PPU_CTRL

    ; Determine which column within pipe (0-3)
    lda pipe_col
    and #$03              ; 0, 1, 2, or 3
    tax                   ; X = column within pipe

    ; Draw rows 0 to 25
    ldy #0                ; Y = current row
@draw_loop:
    ; Determine tile based on row and pipe structure
    ; Top pipe body: rows 0 to (gap-3)
    ; Top cap row 1: row (gap-2)
    ; Top cap row 2: row (gap-1)
    ; Gap: rows gap to (gap+7)
    ; Bot cap row 1: row (gap+8)
    ; Bot cap row 2: row (gap+9)
    ; Bot pipe body: rows (gap+10) to 25

    tya
    clc
    adc #3                ; A = row + 3
    cmp pipe_gap          ; Compare (row + 3) with gap
    bcc @top_body         ; row + 3 < gap => row < gap - 3 => top body

    tya
    clc
    adc #2
    cmp pipe_gap          ; Compare (row + 2) with gap
    bcc @top_cap1         ; row + 2 < gap => row = gap - 2 => top cap row 1

    tya
    clc
    adc #1
    cmp pipe_gap
    bcc @top_cap2         ; row + 1 < gap => row = gap - 1 => top cap row 2

    tya
    cmp pipe_gap
    bcc @gap_tile         ; row < gap (shouldn't happen after above checks)

    ; row >= gap
    tya
    sec
    sbc pipe_gap          ; A = row - gap
    cmp #GAP_ROWS
    bcc @gap_tile         ; row - gap < 8 => in gap

    ; row >= gap + 8
    cmp #GAP_ROWS
    beq @bot_cap1         ; row - gap = 8 => bot cap row 1

    cmp #(GAP_ROWS + 1)
    beq @bot_cap2         ; row - gap = 9 => bot cap row 2

    ; row - gap >= 10 => bot body
    jmp @bot_body

@top_body:
    ; Top pipe body tiles: $19, $1A, $1B, $1C (cols 0-3)
    lda pipe_top_body_tiles, x
    jmp @write_tile

@top_cap1:
    ; Top cap row 1 (under lip): $15, $16, $17, $18
    lda pipe_top_cap1_tiles, x
    jmp @write_tile

@top_cap2:
    ; Top cap row 2 (lip edge): $11, $12, $13, $14
    lda pipe_top_cap2_tiles, x
    jmp @write_tile

@gap_tile:
    ; Gap: empty tile
    lda #$00
    jmp @write_tile

@bot_cap1:
    ; Bot cap row 1: $05, $06, $07, $08
    lda pipe_bot_cap1_tiles, x
    jmp @write_tile

@bot_cap2:
    ; Bot cap row 2: $09, $0A, $0B, $0C
    lda pipe_bot_cap2_tiles, x
    jmp @write_tile

@bot_body:
    ; Bot pipe body: $0D, $0E, $0F, $10
    lda pipe_bot_body_tiles, x
    ; Fall through to write_tile

@write_tile:
    sta PPU_DATA
    iny
    cpy #26               ; Rows 0-25 (stop before ground at 26)
    bcc @draw_loop

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

    ; Mark NT as having pipes (for collision detection)
    cmp #$24
    beq @nt1_setup
    ; NT0 setup
    lda #1
    sta nt0_has_pipes
    jmp @gen_gaps

@nt1_setup:
    ; NT1 (no special flag needed, always has pipes)

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
    ; Frame 3: Draw pipe 0 attrs
    jsr draw_pipe0_attrs_only
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
    ; Frame 6: Draw pipe 1 bottom
    jsr draw_pipe_bottom
    ; Draw pipe 1 attrs (combine with frame 6)
    jsr draw_pipe1_attrs_only
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

;---------------------------------------
; Draw attributes for pipe 0 only (column 0)
; Sets all rows 0-5 to pipe palette, row 6 to pipe/ground
;---------------------------------------
draw_pipe0_attrs_only:
    lda nt_base
    clc
    adc #3
    sta nt_base           ; attr base

    ; Attr rows 0-5: pipe palette ($AA)
    lda nt_base
    sta PPU_ADDR
    lda #$C0              ; Row 0
    sta PPU_ADDR
    lda #$AA
    sta PPU_DATA

    lda nt_base
    sta PPU_ADDR
    lda #$C8              ; Row 1
    sta PPU_ADDR
    lda #$AA
    sta PPU_DATA

    lda nt_base
    sta PPU_ADDR
    lda #$D0              ; Row 2
    sta PPU_ADDR
    lda #$AA
    sta PPU_DATA

    lda nt_base
    sta PPU_ADDR
    lda #$D8              ; Row 3
    sta PPU_ADDR
    lda #$AA
    sta PPU_DATA

    lda nt_base
    sta PPU_ADDR
    lda #$E0              ; Row 4
    sta PPU_ADDR
    lda #$AA
    sta PPU_DATA

    lda nt_base
    sta PPU_ADDR
    lda #$E8              ; Row 5
    sta PPU_ADDR
    lda #$AA
    sta PPU_DATA

    ; Attr row 6: pipe/ground ($5A)
    lda nt_base
    sta PPU_ADDR
    lda #$F0              ; Row 6
    sta PPU_ADDR
    lda #$5A
    sta PPU_DATA

    ; Restore nt_base
    lda nt_base
    sec
    sbc #3
    sta nt_base
    rts

;---------------------------------------
; Draw attributes for pipe 1 only (column 4)
; Sets all rows 0-5 to pipe palette, row 6 to pipe/ground
;---------------------------------------
draw_pipe1_attrs_only:
    lda nt_base
    clc
    adc #3
    sta nt_base           ; attr base

    ; Attr rows 0-5: pipe palette ($AA)
    lda nt_base
    sta PPU_ADDR
    lda #$C4              ; Row 0
    sta PPU_ADDR
    lda #$AA
    sta PPU_DATA

    lda nt_base
    sta PPU_ADDR
    lda #$CC              ; Row 1
    sta PPU_ADDR
    lda #$AA
    sta PPU_DATA

    lda nt_base
    sta PPU_ADDR
    lda #$D4              ; Row 2
    sta PPU_ADDR
    lda #$AA
    sta PPU_DATA

    lda nt_base
    sta PPU_ADDR
    lda #$DC              ; Row 3
    sta PPU_ADDR
    lda #$AA
    sta PPU_DATA

    lda nt_base
    sta PPU_ADDR
    lda #$E4              ; Row 4
    sta PPU_ADDR
    lda #$AA
    sta PPU_DATA

    lda nt_base
    sta PPU_ADDR
    lda #$EC              ; Row 5
    sta PPU_ADDR
    lda #$AA
    sta PPU_DATA

    ; Attr row 6: pipe/ground ($5A)
    lda nt_base
    sta PPU_ADDR
    lda #$F4              ; Row 6
    sta PPU_ADDR
    lda #$5A
    sta PPU_DATA

    ; Restore nt_base
    lda nt_base
    sec
    sbc #3
    sta nt_base
    rts

;===============================================================================
; Pattern-Based Cloud Drawing
; Called during init to draw clouds from curated patterns
;===============================================================================

; Cloud width lookup table (indexed by cloud_size)
cloud_widths:
    .byte 4, 6, 8         ; single=4, double=6, triple=8

; Cloud patterns: 16 patterns x 6 bytes each
; Format: col1, size1, row1, col2, size2, row2
; col=0 means no cloud, col=4-11 is zone A, col=20-27 is zone B
PATTERN_COUNT = 16
cloud_patterns:
    ; 0: Empty - clear sky
    .byte 0, 0, 0,    0, 0, 0
    ; 1: Single high (A)
    .byte 5, 0, 2,    0, 0, 0
    ; 2: Single low (B)
    .byte 22, 0, 7,   0, 0, 0
    ; 3: Double mid (A)
    .byte 4, 1, 5,    0, 0, 0
    ; 4: Triple high (B)
    .byte 20, 2, 3,   0, 0, 0
    ; 5: Single + Single (different heights)
    .byte 6, 0, 3,    24, 0, 6
    ; 6: Single + Double
    .byte 7, 0, 4,    20, 1, 6
    ; 7: Double + Single
    .byte 4, 1, 3,    25, 0, 7
    ; 8: Triple + Single
    .byte 4, 2, 4,    25, 0, 2
    ; 9: Single + Triple
    .byte 8, 0, 2,    20, 2, 5
    ; 10: Double + Double
    .byte 5, 1, 3,    21, 1, 6
    ; 11: Single low (A) - variation
    .byte 6, 0, 6,    0, 0, 0
    ; 12: Single high (B) - variation
    .byte 23, 0, 2,   0, 0, 0
    ; 13: Double (B)
    .byte 21, 1, 4,   0, 0, 0
    ; 14: Triple (A)
    .byte 4, 2, 5,    0, 0, 0
    ; 15: Single + Single (both high)
    .byte 5, 0, 2,    23, 0, 3

;---------------------------------------
; Draw clouds from random pattern
; Input: nt_base = $20 (NT0) or $24 (NT1)
;---------------------------------------
draw_random_clouds:
    ; Pick random pattern (0-15)
    jsr rand_lfsr
    lda rng_hi            ; Use high byte (more entropy)
    and #$0F              ; 0-15

    ; Calculate pattern offset (pattern * 6)
    sta cloud_temp
    asl a                 ; *2
    clc
    adc cloud_temp        ; *3
    asl a                 ; *6
    tax                   ; X = pattern offset

    ; Draw cloud 1 (if col != 0)
    lda cloud_patterns, x
    beq @skip_cloud1      ; col=0 means no cloud
    sta cloud_col
    lda cloud_patterns+1, x
    sta cloud_size
    lda cloud_patterns+2, x
    sta cloud_row
    txa
    pha                   ; Save pattern offset
    jsr draw_one_cloud
    pla
    tax                   ; Restore pattern offset

@skip_cloud1:
    ; Draw cloud 2 (if col != 0)
    lda cloud_patterns+3, x
    beq @done             ; col=0 means no cloud
    sta cloud_col
    lda cloud_patterns+4, x
    sta cloud_size
    lda cloud_patterns+5, x
    sta cloud_row
    jsr draw_one_cloud

@done:
    rts

;---------------------------------------
; Draw one cloud at cloud_col, cloud_row
; Uses cloud_size for width
;---------------------------------------
draw_one_cloud:
    ; Row 0: top bumps ($00 $3A $3B ... $00)
    lda cloud_row
    ldx cloud_col
    jsr set_cloud_ppu_addr
    jsr write_cloud_row0

    ; Row 1: middle body ($3C $3D ... $3E)
    lda cloud_row
    clc
    adc #1
    ldx cloud_col
    jsr set_cloud_ppu_addr
    jsr write_cloud_row1

    ; Row 2: bottom ($3F $40 $41 ... $42)
    lda cloud_row
    clc
    adc #2
    ldx cloud_col
    jsr set_cloud_ppu_addr
    jsr write_cloud_row2

    rts

;---------------------------------------
; Set PPU address for cloud drawing
; A = row, X = column
;---------------------------------------
set_cloud_ppu_addr:
    pha                   ; Save row
    lsr a
    lsr a
    lsr a                 ; row / 8
    clc
    adc nt_base
    sta PPU_ADDR          ; High byte

    pla
    and #$07
    asl a
    asl a
    asl a
    asl a
    asl a                 ; (row & 7) * 32
    stx cloud_temp
    clc
    adc cloud_temp        ; + column
    sta PPU_ADDR          ; Low byte
    rts

;---------------------------------------
; Write cloud row 0 (top bumps)
; Pattern: $00, ($3A $3B)..., $00
;---------------------------------------
write_cloud_row0:
    lda #$00
    sta PPU_DATA          ; Left edge

    ldx cloud_size
    lda cloud_widths, x
    sec
    sbc #2                ; Width minus 2 edges
    lsr a                 ; Divide by 2 for bump pairs
    sta cloud_temp        ; Number of bump pairs

@bump_loop:
    lda #CLOUD_TILE_BASE
    sta PPU_DATA
    lda #(CLOUD_TILE_BASE + 1)
    sta PPU_DATA
    dec cloud_temp
    bne @bump_loop

    lda #$00
    sta PPU_DATA          ; Right edge
    rts

;---------------------------------------
; Write cloud row 1 (middle body)
; Pattern: $3C, $3D..., $3E
;---------------------------------------
write_cloud_row1:
    lda #(CLOUD_TILE_BASE + 2)
    sta PPU_DATA          ; Left edge

    ldx cloud_size
    lda cloud_widths, x
    sec
    sbc #2                ; Width minus 2 edges
    sta cloud_temp        ; Middle tiles count

@mid_loop:
    lda #(CLOUD_TILE_BASE + 3)
    sta PPU_DATA
    dec cloud_temp
    bne @mid_loop

    lda #(CLOUD_TILE_BASE + 4)
    sta PPU_DATA          ; Right edge
    rts

;---------------------------------------
; Write cloud row 2 (bottom)
; Pattern: $3F, ($40 $41)..., $42
;---------------------------------------
write_cloud_row2:
    lda #(CLOUD_TILE_BASE + 5)
    sta PPU_DATA          ; Left edge

    ldx cloud_size
    lda cloud_widths, x
    sec
    sbc #2                ; Width minus 2 edges
    lsr a                 ; Divide by 2 for pairs
    sta cloud_temp

@bot_loop:
    lda #(CLOUD_TILE_BASE + 6)
    sta PPU_DATA
    lda #(CLOUD_TILE_BASE + 7)
    sta PPU_DATA
    dec cloud_temp
    bne @bot_loop

    lda #(CLOUD_TILE_BASE + 8)
    sta PPU_DATA          ; Right edge
    rts

;---------------------------------------
; Clear cloud zone A top half (cols 4-11, rows 2-5)
; Split to fit in vblank - 4 rows x 8 tiles = 32 tiles
;---------------------------------------
clear_cloud_zone_a_top:
    lda #CLOUD_ZONE_A     ; Column 4
    sta cloud_col
    lda #CLOUD_ROW_MIN    ; Row 2
    ldy #6                ; End before row 6
    jmp clear_cloud_zone_partial

;---------------------------------------
; Clear cloud zone A bottom half (cols 4-11, rows 6-10)
; Split to fit in vblank - 5 rows x 8 tiles = 40 tiles
;---------------------------------------
clear_cloud_zone_a_bottom:
    lda #CLOUD_ZONE_A     ; Column 4
    sta cloud_col
    lda #6                ; Row 6
    ldy #(CLOUD_ROW_MAX + 3)  ; End at row 11
    jmp clear_cloud_zone_partial

;---------------------------------------
; Clear cloud zone B top half (cols 20-27, rows 2-5)
; Split to fit in vblank - 4 rows x 8 tiles = 32 tiles
;---------------------------------------
clear_cloud_zone_b_top:
    lda #CLOUD_ZONE_B     ; Column 20
    sta cloud_col
    lda #CLOUD_ROW_MIN    ; Row 2
    ldy #6                ; End before row 6
    jmp clear_cloud_zone_partial

;---------------------------------------
; Clear cloud zone B bottom half (cols 20-27, rows 6-10)
; Split to fit in vblank - 5 rows x 8 tiles = 40 tiles
;---------------------------------------
clear_cloud_zone_b_bottom:
    lda #CLOUD_ZONE_B     ; Column 20
    sta cloud_col
    lda #6                ; Row 6
    ldy #(CLOUD_ROW_MAX + 3)  ; End at row 11
    ; Fall through to clear_cloud_zone_partial

;---------------------------------------
; Clear partial cloud zone
; A = start row, Y = end row (exclusive)
; cloud_col must be set before calling
;---------------------------------------
clear_cloud_zone_partial:
    sta cloud_row
    sty cloud_temp        ; Store end row

@clear_row:
    ; Set PPU address for this row
    lda cloud_row
    ldx cloud_col
    jsr set_cloud_ppu_addr

    ; Write 8 empty tiles
    lda #$00
    ldx #8
@clear_tile:
    sta PPU_DATA
    dex
    bne @clear_tile

    ; Next row
    inc cloud_row
    lda cloud_row
    cmp cloud_temp        ; Compare to end row
    bcc @clear_row

    rts

;===============================================================================
; CHR-ROM
;===============================================================================
.segment "CHARS"

; Include external CHR file (8KB)
; Bank 0 ($0000-$0FFF): Sprites
; Bank 1 ($1000-$1FFF): Background
.incbin "../chr/graphics.chr"
