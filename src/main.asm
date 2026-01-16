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

    ; Initialize pipe gap (start of cycle)
    lda #GAP_MIN
    sta pipe_gap
    sta pipe0_drawn_gap   ; Initial collision gap

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
    ; Queue pipe redraw for the nametable that just went off-screen
    ; scroll_nt = 1: switched TO NT1, queue NT0 redraw
    ; scroll_nt = 0: switched TO NT0, queue NT1 redraw
    beq @queue_nt1
    ; Switched to NT1 - queue NT0 redraw
    lda #$20
    jmp @queue_redraw
@queue_nt1:
    ; Switched to NT0 - queue NT1 redraw
    lda #$24
@queue_redraw:
    sta nt_base
    lda #0
    sta pipe_redraw
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
    lda #STATE_DEAD
    sta game_state
@dying_no_ground:

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
    beq @waiting_done
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

    ; Check if we need to redraw pipes (two-frame approach)
    ; draw_pipes_in_nt manages pipe_redraw state internally
    lda pipe_redraw
    cmp #$FF
    beq @no_pipe_redraw
    jsr draw_pipes_in_nt
@no_pipe_redraw:

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
    ; Both pipes are in NT1:
    ; Pipe 0: NT1 column 0 = world pixel 256
    ; Pipe 1: NT1 column 16 = world pixel 384
    ;
    ; When scroll_nt = 0: viewing NT0, pipes in NT1 are to the right
    ;   pipe0_screen_x = 256 - scroll_x (visible when scroll_x > 0)
    ; When scroll_nt = 1: viewing NT1, pipes are here
    ;   pipe0_screen_x = 0 - scroll_x (visible when scroll_x < 32)

    lda scroll_nt
    bne @nt1_view

    ; Viewing NT0: pipe 0 is at screen_x = 256 - scroll_x
    ; If scroll_x = 0, pipe is at 256 (off screen right)
    ; If scroll_x = 200, pipe is at 56 (visible)
    lda scroll_x
    beq @no_collision     ; scroll_x = 0, pipe off screen right
    ; pipe_x = 256 - scroll_x, but in 8-bit: (0 - scroll_x) wraps correctly
    lda #0
    sec
    sbc scroll_x          ; A = 256 - scroll_x (due to borrow from bit 8)
    jmp @check_x_overlap

@nt1_view:
    ; Viewing NT1: pipe 0 is at screen_x = 0 - scroll_x
    ; If scroll_x = 0, pipe is at 0 (visible)
    ; If scroll_x > 32, pipe is off screen left
    lda scroll_x
    cmp #32
    bcs @no_collision     ; scroll_x >= 32, pipe off screen left
    ; pipe_x = 0 - scroll_x (negative, but we handle it)
    lda #0
    sec
    sbc scroll_x          ; A = -scroll_x (wrapped to 256-scroll_x, but for small scroll_x this works)

@check_x_overlap:
    ; A = pipe_x (left edge of pipe)
    ; Check if bird (X=56-72) overlaps pipe (X=pipe_x to pipe_x+32)
    ; Bird overlaps if: pipe_x < bird_right (72) AND pipe_x + 32 > bird_left (56)

    ; Check: pipe_x >= 72 means no overlap (pipe is to the right)
    cmp #BIRD_RIGHT
    bcs @no_collision     ; pipe_x >= 72, no overlap

    ; Check: pipe_x + 32 <= 56 means no overlap (pipe is to the left)
    ; pipe_x + 32 <= 56 means pipe_x <= 24
    cmp #(BIRD_LEFT - PIPE_WIDTH + 1)
    bcc @no_collision     ; pipe_x < 25, pipe is to the left

    ; X overlaps! Now check Y
    ; Bird must be OUTSIDE the gap to collide
    ; Gap top Y = pipe0_drawn_gap * 8
    ; Gap bottom Y = (pipe0_drawn_gap + 8) * 8
    ; Bird is 16px tall

    ; Calculate gap_top_y = pipe0_drawn_gap * 8
    lda pipe0_drawn_gap
    asl a
    asl a
    asl a                 ; A = gap * 8 = gap_top_y

    ; Check if bird_y < gap_top_y (hit top pipe)
    cmp bird_y
    beq @check_bottom     ; bird_y == gap_top_y, check bottom
    bcc @check_bottom     ; bird_y > gap_top_y, check bottom
    jmp @collision        ; bird_y < gap_top_y, hit top pipe

@check_bottom:
    ; Calculate gap_bottom_y - 16 = gap * 8 + 64 - 16 = gap * 8 + 48
    lda pipe0_drawn_gap
    asl a
    asl a
    asl a                 ; A = gap * 8
    clc
    adc #(GAP_ROWS * 8 - 16)  ; A = gap_top_y + 48
    cmp bird_y
    beq @collision        ; bird_y == threshold, hit bottom
    bcs @no_collision     ; bird_y < threshold, in gap (safe)
                          ; bird_y > threshold, hit bottom (fall through)

@no_collision:
    rts

@collision:
    ; Bird hit pipe - start dying
    lda #STATE_DYING
    sta game_state
    rts

;===============================================================================
; Pipe Drawing (called from NMI during vblank)
;===============================================================================
draw_pipes_in_nt:
    ; Eight-frame pipe redraw to fit in vblank
    ; pipe_redraw = 0: draw pipe 0 body+cap, set to 1
    ; pipe_redraw = 1: draw pipe 0 gap clear, set to 2
    ; pipe_redraw = 2: draw pipe 0 bottom, set to 3
    ; pipe_redraw = 3: draw pipe 0 attrs, set to 4
    ; pipe_redraw = 4: draw pipe 1 body+cap, set to 5
    ; pipe_redraw = 5: draw pipe 1 gap clear, set to 6
    ; pipe_redraw = 6: draw pipe 1 bottom, set to 7
    ; pipe_redraw = 7: draw pipe 1 attrs, set to $FF (done)
    ; pipe_redraw = $FF: skip (checked by NMI before calling)
    ; Caller must set nt_base before queuing redraw

    bit PPU_STATUS        ; Reset PPU latch

    lda pipe_redraw
    beq @frame0
    cmp #1
    beq @frame1
    cmp #2
    beq @frame2
    cmp #3
    beq @frame3
    cmp #4
    beq @frame4
    cmp #5
    beq @frame5
    cmp #6
    beq @frame6
    ; Fall through to frame 7

@frame7:
    ; Frame 8: Draw pipe 1 attrs
    jsr draw_pipe1_attrs_only
    jsr next_pipe_gap     ; Increment gap for next pipe
    lda #$FF
    sta pipe_redraw       ; Done
    rts

@frame0:
    ; Frame 1: Draw pipe 0 body+cap
    lda #0
    sta pipe_col
    lda pipe_gap
    sta pipe0_drawn_gap   ; Save gap for collision detection
    jsr draw_pipe_body_cap
    lda #1
    sta pipe_redraw
    rts

@frame1:
    ; Frame 2: Draw pipe 0 gap clear
    jsr draw_pipe_gap
    lda #2
    sta pipe_redraw
    rts

@frame2:
    ; Frame 3: Draw pipe 0 bottom
    jsr draw_pipe_bottom
    lda #3
    sta pipe_redraw
    rts

@frame3:
    ; Frame 4: Draw pipe 0 attrs
    jsr draw_pipe0_attrs_only
    jsr next_pipe_gap     ; Increment gap for next pipe
    lda #4
    sta pipe_redraw
    rts

@frame4:
    ; Frame 5: Draw pipe 1 body+cap
    lda #16
    sta pipe_col
    jsr draw_pipe_body_cap
    lda #5
    sta pipe_redraw
    rts

@frame5:
    ; Frame 6: Draw pipe 1 gap clear
    jsr draw_pipe_gap
    lda #6
    sta pipe_redraw
    rts

@frame6:
    ; Frame 7: Draw pipe 1 bottom
    jsr draw_pipe_bottom
    lda #7
    sta pipe_redraw
    rts

;---------------------------------------
; Increment pipe_gap, wrap at max
;---------------------------------------
next_pipe_gap:
    inc pipe_gap
    lda pipe_gap
    cmp #(GAP_MAX + 1)
    bcc @done
    lda #GAP_MIN          ; Wrap to min
    sta pipe_gap
@done:
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
; CHR-ROM
;===============================================================================
.segment "CHARS"

; Include external CHR file (8KB)
; Bank 0 ($0000-$0FFF): Sprites
; Bank 1 ($1000-$1FFF): Background
.incbin "../chr/graphics.chr"
