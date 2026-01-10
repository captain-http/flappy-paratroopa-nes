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

    ; Load palettes
    bit PPU_STATUS        ; Reset PPU address latch
    lda #$3F
    sta PPU_ADDR
    lda #$00
    sta PPU_ADDR          ; PPU address = $3F00

    ; Background palette 0 (sky)
    lda #$22              ; SMB sky blue (universal bg)
    sta PPU_DATA
    lda #$22              ; Color 1 (unused)
    sta PPU_DATA
    sta PPU_DATA          ; Color 2 (unused)
    sta PPU_DATA          ; Color 3 (unused)

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

    ; Skip to sprite palette 0 ($3F10)
    lda #$3F
    sta PPU_ADDR
    lda #$10
    sta PPU_ADDR
    lda #$21              ; Transparent (uses bg color)
    sta PPU_DATA
    lda #$27              ; Yellow (bird color)
    sta PPU_DATA

    ; Initialize bird state (8.8 fixed-point)
    lda #0
    sta bird_y_frac
    lda #100
    sta bird_y
    lda #0
    sta bird_vel_lo
    sta bird_vel_hi

    ; Initialize sprite Y positions from bird_y
    lda bird_y
    sta OAM_BUFFER+0      ; Top-left Y
    sta OAM_BUFFER+4      ; Top-right Y
    clc
    adc #8
    sta OAM_BUFFER+8      ; Bottom-left Y
    sta OAM_BUFFER+12     ; Bottom-right Y

    ; Setup sprite tiles and attributes (static parts)
    lda #$01              ; Tile 1 (bird)
    sta OAM_BUFFER+1
    sta OAM_BUFFER+5
    sta OAM_BUFFER+9
    sta OAM_BUFFER+13
    lda #$00              ; Attributes (palette 0)
    sta OAM_BUFFER+2
    sta OAM_BUFFER+6
    sta OAM_BUFFER+10
    sta OAM_BUFFER+14
    ; X positions (fixed at 1/4 screen width)
    lda #56
    sta OAM_BUFFER+3
    sta OAM_BUFFER+11
    lda #64
    sta OAM_BUFFER+7
    sta OAM_BUFFER+15

    ; Hide remaining sprites
    lda #$FF
    ldx #16
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

    ; Set attribute tables for ground (palette 1)
    ; Ground at rows 26-29 = attr row 6 and 7
    ; $23F0 = attribute row 6, $23F8 = attribute row 7
    lda #$23
    sta PPU_ADDR
    lda #$F0
    sta PPU_ADDR          ; $23F0 = attribute row 6
    lda #$55              ; %01010101 = palette 1 for all
    ldx #16               ; 8 bytes row 6 + 8 bytes row 7
@attr0_ground:
    sta PPU_DATA
    dex
    bne @attr0_ground

    ; Nametable 1 attributes
    lda #$27
    sta PPU_ADDR
    lda #$F0
    sta PPU_ADDR          ; $27F0 = attribute row 6
    lda #$55
    ldx #16               ; 8 bytes row 6 + 8 bytes row 7
@attr1_ground:
    sta PPU_DATA
    dex
    bne @attr1_ground

    ; Initialize pipe tracking variables
    lda #PIPE0_INIT_COL
    sta pipe0_col
    lda #PIPE0_INIT_GAP
    sta pipe0_gap
    lda #0                ; Pipe 0 starts in nametable 0
    sta pipe0_nt

    lda #PIPE1_INIT_COL
    sta pipe1_col
    lda #PIPE1_INIT_GAP
    sta pipe1_gap
    lda #1                ; Pipe 1 starts in nametable 1
    sta pipe1_nt

    lda #0
    sta pipe_redraw
    lda #$47              ; Seed RNG
    sta rng_state

    ; Draw pipe 0 in nametable 0
    lda pipe0_nt
    sta temp_nt
    lda pipe0_col
    sta temp_col
    lda pipe0_gap
    sta temp_gap
    jsr draw_pipe

    ; Draw pipe 1 in nametable 1
    lda pipe1_nt
    sta temp_nt
    lda pipe1_col
    sta temp_col
    lda pipe1_gap
    sta temp_gap
    jsr draw_pipe

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

    ; Check game state
    lda game_state
    cmp #STATE_DEAD
    bne @not_dead
    jmp @dead_state           ; Fully frozen
@not_dead:
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
@no_flap:

    ; Check pipe collision
    jsr check_pipe_collision

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
    ; Check ground collision - bird is now dead
    lda bird_y
    cmp #GROUND_Y
    bcc @no_ground        ; bird_y < GROUND_Y, no collision
    ; Bird hit ground - dead!
    lda #GROUND_Y         ; Clamp to ground
    sta bird_y
    lda #0                ; Stop falling
    sta bird_vel_lo
    sta bird_vel_hi
    sta bird_y_frac
    lda #STATE_DEAD       ; Fully dead
    sta game_state
@no_ground:

    ; Update sprite Y positions
    lda bird_y
    sta OAM_BUFFER+0      ; Top-left
    sta OAM_BUFFER+4      ; Top-right
    clc
    adc #8
    sta OAM_BUFFER+8      ; Bottom-left
    sta OAM_BUFFER+12     ; Bottom-right

    ; Scroll if bird is flying (not on ground)
    lda bird_y
    cmp #GROUND_Y
    beq @no_scroll        ; Bird on ground, don't scroll
    ; Bird is flying, scroll by 1 pixel
    inc scroll_x
    bne @no_scroll        ; No overflow, done
    ; scroll_x wrapped from 255 to 0, toggle nametable
    lda scroll_nt
    eor #$01              ; Toggle bit 0
    sta scroll_nt
@no_scroll:

    ; Check if any pipe has scrolled off-screen and needs repositioning
    jsr check_pipes_offscreen

    jmp game_loop

@dying_state:
    ; Bird is dying - apply gravity but no input, no scrolling
    ; Apply gravity to velocity
    lda bird_vel_lo
    clc
    adc #GRAVITY
    sta bird_vel_lo
    lda bird_vel_hi
    adc #0
    sta bird_vel_hi

    ; Apply velocity to position
    lda bird_y_frac
    clc
    adc bird_vel_lo
    sta bird_y_frac
    lda bird_y
    adc bird_vel_hi
    sta bird_y

    ; Check ground collision
    cmp #GROUND_Y
    bcc @dying_no_ground
    ; Hit ground - now dead
    lda #GROUND_Y
    sta bird_y
    lda #0
    sta bird_vel_lo
    sta bird_vel_hi
    sta bird_y_frac
    lda #STATE_DEAD
    sta game_state
@dying_no_ground:

    ; Update sprite Y positions
    lda bird_y
    sta OAM_BUFFER+0
    sta OAM_BUFFER+4
    clc
    adc #8
    sta OAM_BUFFER+8
    sta OAM_BUFFER+12

    jmp game_loop

@dead_state:
    ; Bird is dead - fully frozen, wait for reset
    jmp game_loop

@waiting_state:
    ; Waiting for player to press A or B to start
    jsr read_controller
    lda buttons_new
    and #(BUTTON_A | BUTTON_B)
    beq @waiting_done         ; No button pressed, keep waiting
    ; Button pressed - start the game!
    lda #STATE_PLAYING
    sta game_state
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

    ; Check if pipe needs redrawing (must happen before scroll setup)
    lda pipe_redraw
    beq @no_pipe_update

    ; Pipe redraw needed
    cmp #1
    bne @redraw_pipe1

    ; Redraw pipe 0 at its new position
    lda pipe0_nt
    sta temp_nt
    lda pipe0_col
    sta temp_col
    lda pipe0_gap
    sta temp_gap
    jsr draw_pipe
    jmp @pipe_update_done

@redraw_pipe1:
    ; Redraw pipe 1 at its new position
    lda pipe1_nt
    sta temp_nt
    lda pipe1_col
    sta temp_col
    lda pipe1_gap
    sta temp_gap
    jsr draw_pipe

@pipe_update_done:
    ; Clear the redraw flag
    lda #0
    sta pipe_redraw

@no_pipe_update:
    ; Set scroll position (must be last before RTI)
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
; Check both pipes for collision with bird
check_pipe_collision:
    ; Check pipe 0
    lda pipe0_col
    sta temp_col
    lda pipe0_gap
    sta temp_gap
    lda pipe0_nt
    sta temp_nt
    jsr check_single_pipe
    bcs @collision

    ; Check pipe 1
    lda pipe1_col
    sta temp_col
    lda pipe1_gap
    sta temp_gap
    lda pipe1_nt
    sta temp_nt
    jsr check_single_pipe
    bcs @collision

    rts                   ; No collision

@collision:
    lda #STATE_DYING
    sta game_state
    rts

; Check collision with a single pipe
; Input: temp_col, temp_gap, temp_nt
; Output: Carry set if collision
check_single_pipe:
    ; Calculate pipe screen X position
    ; pipe_pixel_x = temp_col * 8
    lda temp_col
    asl a
    asl a
    asl a                 ; A = column * 8 = pixel X in nametable

    ; Adjust for scroll: screen_x = pipe_pixel_x - scroll_x
    ; But need to account for which nametable we're viewing vs pipe is in
    sec
    sbc scroll_x          ; A = pipe_x - scroll_x (may wrap)

    ; If pipe is in different nametable than we're viewing, adjust by 256
    ; If viewing NT0 (scroll_nt=0) and pipe in NT1 (temp_nt=1): add 256
    ; If viewing NT1 (scroll_nt=1) and pipe in NT0 (temp_nt=0): result is correct with wrap
    ldx scroll_nt
    cpx temp_nt
    beq @same_nt

    ; Different nametables
    ldx temp_nt
    beq @pipe_in_nt0
    ; Pipe in NT1, viewing NT0: pipe is 256 pixels to the right
    ; If result is < 128, it's off-screen right (add 256 would make it > 255)
    cmp #128
    bcs @check_x          ; Visible range
    clc                   ; No collision (off-screen right)
    rts

@pipe_in_nt0:
    ; Pipe in NT0, viewing NT1: pipe may be on screen or off left
    ; The subtraction already wraps correctly
    jmp @check_x

@same_nt:
    ; Same nametable - straightforward

@check_x:
    ; A = pipe screen X (left edge)
    ; Check X overlap with bird (56-72)
    cmp #BIRD_RIGHT
    bcs @no_hit           ; pipe_x >= 72, pipe is to the right

    ; Check if pipe right edge (pipe_x + 32) > bird left (56)
    ; i.e., pipe_x > 56 - 32 = 24
    cmp #(BIRD_LEFT - PIPE_WIDTH + 1)
    bcc @no_hit           ; pipe_x < 25, pipe is to the left

    ; X overlaps - check Y against this pipe's gap
    ; gap_top_y = temp_gap * 8
    lda temp_gap
    asl a
    asl a
    asl a                 ; A = gap_top in pixels
    sta temp_row          ; Save gap_top

    ; Collision if bird_y < gap_top
    lda bird_y
    cmp temp_row
    bcc @hit              ; bird_y < gap_top, hit top pipe

    ; Collision if bird_y + 16 > gap_top + 64 (gap_bottom)
    ; i.e., bird_y > gap_top + 64 - 16 = gap_top + 48
    lda temp_row
    clc
    adc #(GAP_HEIGHT - 16) ; gap_top + 48
    sta temp_row
    lda bird_y
    cmp temp_row
    bcs @hit              ; bird_y >= gap_top + 48, hit bottom pipe

@no_hit:
    clc                   ; Clear carry = no collision
    rts

@hit:
    sec                   ; Set carry = collision
    rts

;===============================================================================
; Pipe Off-Screen Detection
;===============================================================================
; Check if pipes have scrolled off-screen left and need repositioning
check_pipes_offscreen:
    ; Only check if no redraw is pending
    lda pipe_redraw
    bne @done             ; Already have a pending redraw

    ; Check pipe 0
    lda pipe0_col
    asl a
    asl a
    asl a                 ; A = pipe0 pixel X in its nametable
    sec
    sbc scroll_x          ; A = relative screen X

    ; Adjust for which nametable pipe is in vs which we're viewing
    ldx pipe0_nt
    cpx scroll_nt
    beq @check_pipe0_offscreen
    ; Different nametables - pipe is far away, skip
    jmp @check_pipe1

@check_pipe0_offscreen:
    ; Same nametable - check if pipe has scrolled off left
    clc
    adc #PIPE_WIDTH       ; A = right edge
    cmp #PIPE_WIDTH       ; If right edge < 32, pipe is off left
    bcs @check_pipe1

    ; Pipe 0 is off-screen - reposition to OTHER nametable
    lda #1
    sta pipe_redraw       ; Mark pipe 0 for redraw

    ; Toggle nametable for pipe 0
    lda pipe0_nt
    eor #1
    sta pipe0_nt

    ; New column: 28 (near right edge of the new nametable)
    lda #28
    sta pipe0_col

    ; Generate random gap
    jsr get_random_gap
    sta pipe0_gap

    rts

@check_pipe1:
    ; Check pipe 1
    lda pipe1_col
    asl a
    asl a
    asl a                 ; A = pipe1 pixel X
    sec
    sbc scroll_x

    ; Check if in same nametable as we're viewing
    ldx pipe1_nt
    cpx scroll_nt
    beq @check_pipe1_offscreen
    ; Different nametables - skip
    jmp @done

@check_pipe1_offscreen:
    clc
    adc #PIPE_WIDTH
    cmp #PIPE_WIDTH
    bcs @done

    ; Pipe 1 is off-screen - reposition to OTHER nametable
    lda #2
    sta pipe_redraw

    ; Toggle nametable for pipe 1
    lda pipe1_nt
    eor #1
    sta pipe1_nt

    ; New column
    lda #28
    sta pipe1_col

    ; Generate random gap
    jsr get_random_gap
    sta pipe1_gap

@done:
    rts

;===============================================================================
; Pipe Drawing Subroutine
;===============================================================================
; Inputs: temp_nt (0 or 1), temp_col (0-31), temp_gap (gap top row, 8-16)
; Draws a full pipe pair at the specified column with gap at specified row
draw_pipe:
    ; Calculate nametable base address high byte
    lda temp_nt
    beq @nt0_base
    lda #$24              ; Nametable 1 base
    jmp @store_base
@nt0_base:
    lda #$20              ; Nametable 0 base
@store_base:
    sta temp_row          ; Reuse temp_row to store NT base high byte

    ; === TOP PIPE BODY (rows 0 to gap-2) ===
    ldx #0                ; Row counter
@top_body:
    txa
    clc
    adc #2                ; A = row + 2
    cmp temp_gap          ; Compare row+2 with gap
    bcs @top_cap          ; If row+2 >= gap, done with body

    ; Calculate PPU address: base + (row/8)*$100 + (row&7)*32 + col
    jsr calc_pipe_row_addr
    lda #$19              ; Inverted body tiles
    sta PPU_DATA
    lda #$1A
    sta PPU_DATA
    lda #$1B
    sta PPU_DATA
    lda #$1C
    sta PPU_DATA
    inx
    jmp @top_body

@top_cap:
    ; === TOP PIPE CAP (2 rows before gap) ===
    ; Cap row 1 (gap-2): tiles $15-$18
    lda temp_gap
    sec
    sbc #2
    tax                   ; X = gap - 2
    jsr calc_pipe_row_addr
    lda #$15
    sta PPU_DATA
    lda #$16
    sta PPU_DATA
    lda #$17
    sta PPU_DATA
    lda #$18
    sta PPU_DATA

    ; Cap row 2 (gap-1): tiles $11-$14 (lip)
    lda temp_gap
    sec
    sbc #1
    tax                   ; X = gap - 1
    jsr calc_pipe_row_addr
    lda #$11
    sta PPU_DATA
    lda #$12
    sta PPU_DATA
    lda #$13
    sta PPU_DATA
    lda #$14
    sta PPU_DATA

    ; === GAP (8 rows) - clear with sky tiles ===
    lda temp_gap
    tax                   ; X = gap start row
    ldy #8                ; 8 rows to clear
@clear_gap:
    jsr calc_pipe_row_addr
    lda #$00              ; Sky tile
    sta PPU_DATA
    sta PPU_DATA
    sta PPU_DATA
    sta PPU_DATA
    inx
    dey
    bne @clear_gap

    ; === BOTTOM PIPE CAP (gap+8 and gap+9) ===
    ; Cap row 1 (gap+8): tiles $05-$08
    lda temp_gap
    clc
    adc #8
    tax                   ; X = gap + 8
    jsr calc_pipe_row_addr
    lda #$05
    sta PPU_DATA
    lda #$06
    sta PPU_DATA
    lda #$07
    sta PPU_DATA
    lda #$08
    sta PPU_DATA

    ; Cap row 2 (gap+9): tiles $09-$0C
    lda temp_gap
    clc
    adc #9
    tax                   ; X = gap + 9
    jsr calc_pipe_row_addr
    lda #$09
    sta PPU_DATA
    lda #$0A
    sta PPU_DATA
    lda #$0B
    sta PPU_DATA
    lda #$0C
    sta PPU_DATA

    ; === BOTTOM PIPE BODY (gap+10 to row 25) ===
    lda temp_gap
    clc
    adc #10
    tax                   ; X = gap + 10
@bottom_body:
    cpx #26               ; Stop at row 26 (ground)
    bcs @set_attributes

    jsr calc_pipe_row_addr
    lda #$0D
    sta PPU_DATA
    lda #$0E
    sta PPU_DATA
    lda #$0F
    sta PPU_DATA
    lda #$10
    sta PPU_DATA
    inx
    jmp @bottom_body

@set_attributes:
    ; === SET ATTRIBUTES FOR PIPE COLUMN ===
    ; Attribute column = temp_col / 4
    ; We need to set palette 2 for pipe tiles

    ; Calculate attribute base: $23C0 (NT0) or $27C0 (NT1)
    lda temp_nt
    beq @attr_nt0
    lda #$27
    jmp @attr_base
@attr_nt0:
    lda #$23
@attr_base:
    sta PPU_ADDR

    ; Attribute column = temp_col / 4
    lda temp_col
    lsr a
    lsr a                 ; A = col / 4
    clc
    adc #$C0              ; + $C0 = attribute table offset
    sta PPU_ADDR

    ; Row 0: all pipe
    lda #$AA
    sta PPU_DATA

    ; Need to set remaining attribute rows
    ; Attr row 1 (at +8)
    lda temp_nt
    beq @attr1_nt0
    lda #$27
    jmp @attr1_set
@attr1_nt0:
    lda #$23
@attr1_set:
    sta PPU_ADDR
    lda temp_col
    lsr a
    lsr a
    clc
    adc #$C8              ; Row 1
    sta PPU_ADDR
    lda #$AA
    sta PPU_DATA

    ; Attr row 2 (at +16)
    lda temp_nt
    beq @attr2_nt0
    lda #$27
    jmp @attr2_set
@attr2_nt0:
    lda #$23
@attr2_set:
    sta PPU_ADDR
    lda temp_col
    lsr a
    lsr a
    clc
    adc #$D0              ; Row 2
    sta PPU_ADDR
    lda #$AA
    sta PPU_DATA

    ; Attr row 5 (bottom pipe)
    lda temp_nt
    beq @attr5_nt0
    lda #$27
    jmp @attr5_set
@attr5_nt0:
    lda #$23
@attr5_set:
    sta PPU_ADDR
    lda temp_col
    lsr a
    lsr a
    clc
    adc #$E8              ; Row 5
    sta PPU_ADDR
    lda #$AA
    sta PPU_DATA

    ; Attr row 6 (pipe/ground transition)
    lda temp_nt
    beq @attr6_nt0
    lda #$27
    jmp @attr6_set
@attr6_nt0:
    lda #$23
@attr6_set:
    sta PPU_ADDR
    lda temp_col
    lsr a
    lsr a
    clc
    adc #$F0              ; Row 6
    sta PPU_ADDR
    lda #$5A              ; Top=pipe (palette 2), bottom=ground (palette 1)
    sta PPU_DATA

    rts

; Helper: Calculate PPU address for pipe row
; Input: X = row number, temp_row = NT base high byte, temp_col = column
; Sets PPU_ADDR
calc_pipe_row_addr:
    ; High byte: base + (row / 8)
    txa
    lsr a
    lsr a
    lsr a                 ; A = row / 8
    clc
    adc temp_row          ; Add NT base
    sta PPU_ADDR
    ; Low byte: (row & 7) * 32 + column
    txa
    and #$07
    asl a
    asl a
    asl a
    asl a
    asl a                 ; A = (row & 7) * 32
    clc
    adc temp_col
    sta PPU_ADDR
    rts

;===============================================================================
; Clear Pipe (write sky tiles)
;===============================================================================
; Inputs: temp_nt (0 or 1), temp_col (0-31)
; Clears the pipe column with sky tiles
clear_pipe:
    ; Calculate nametable base
    lda temp_nt
    beq @clear_nt0
    lda #$24
    jmp @clear_base
@clear_nt0:
    lda #$20
@clear_base:
    sta temp_row          ; Store NT base

    ; Clear rows 0-25 (ground at 26)
    ldx #0
@clear_loop:
    cpx #26
    bcs @clear_done

    jsr calc_pipe_row_addr
    lda #$00              ; Sky tile
    sta PPU_DATA
    sta PPU_DATA
    sta PPU_DATA
    sta PPU_DATA
    inx
    jmp @clear_loop

@clear_done:
    ; Clear attributes for this column (reset to sky/ground)
    lda temp_nt
    beq @clear_attr_nt0
    lda #$27
    jmp @clear_attr_rows
@clear_attr_nt0:
    lda #$23
@clear_attr_rows:
    ; Rows 0-2: set to $00 (sky)
    pha                   ; Save high byte
    sta PPU_ADDR
    lda temp_col
    lsr a
    lsr a
    clc
    adc #$C0
    sta PPU_ADDR
    lda #$00
    sta PPU_DATA

    pla
    pha
    sta PPU_ADDR
    lda temp_col
    lsr a
    lsr a
    clc
    adc #$C8
    sta PPU_ADDR
    lda #$00
    sta PPU_DATA

    pla
    pha
    sta PPU_ADDR
    lda temp_col
    lsr a
    lsr a
    clc
    adc #$D0
    sta PPU_ADDR
    lda #$00
    sta PPU_DATA

    ; Rows 5-6: reset to ground palette
    pla
    pha
    sta PPU_ADDR
    lda temp_col
    lsr a
    lsr a
    clc
    adc #$E8
    sta PPU_ADDR
    lda #$55              ; Ground palette
    sta PPU_DATA

    pla
    sta PPU_ADDR
    lda temp_col
    lsr a
    lsr a
    clc
    adc #$F0
    sta PPU_ADDR
    lda #$55
    sta PPU_DATA

    rts

;===============================================================================
; Random Number Generator (8-bit LFSR)
;===============================================================================
; Returns random value in A, updates rng_state
get_random:
    lda rng_state
    beq @seed             ; Avoid stuck at 0
    asl a
    bcc @no_xor
    eor #$1D              ; Tap polynomial
@no_xor:
    sta rng_state
    rts
@seed:
    lda #$47              ; Seed value
    sta rng_state
    jmp get_random

; Get random gap row (9-16)
get_random_gap:
    jsr get_random
    and #$07              ; 0-7
    clc
    adc #9                ; 9-16
    rts

;===============================================================================
; CHR-ROM
;===============================================================================
.segment "CHARS"

; Include external CHR file (8KB)
; Bank 0 ($0000-$0FFF): Sprites
; Bank 1 ($1000-$1FFF): Background
.incbin "../chr/graphics.chr"
