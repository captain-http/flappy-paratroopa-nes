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

    ; Draw static test pipe pair at column 16
    ; Pipe tiles: $05-$08 cap row1, $09-$0C cap row2, $0D-$10 body
    ; Gap between pipes: rows 14-19 (6 tiles = 48 pixels)
    ;
    ; Top pipe: body rows 4-13 (hanging from ceiling)
    ; Bottom pipe: cap rows 20-21, body rows 22-25

    ; Top pipe body (rows 0-11) using inverted body tiles
    ldx #0                ; Row counter (start from ceiling)
@pipe_top:
    ; Calculate high byte: $20 + (row / 8)
    txa
    lsr a
    lsr a
    lsr a                 ; A = row / 8
    clc
    adc #$20              ; A = $20 + (row / 8)
    sta PPU_ADDR
    ; Calculate low byte: ((row & 7) * 32) + column
    txa
    and #$07              ; A = row & 7
    asl a
    asl a
    asl a
    asl a
    asl a                 ; A = (row & 7) * 32
    clc
    adc #16               ; + column 16
    sta PPU_ADDR
    lda #$19              ; Inverted body tiles
    sta PPU_DATA
    lda #$1A
    sta PPU_DATA
    lda #$1B
    sta PPU_DATA
    lda #$1C
    sta PPU_DATA
    inx
    cpx #12               ; End at row 11
    bne @pipe_top

    ; Top pipe cap (rows 12-13) using inverted cap tiles
    lda #$21              ; $2000 + 12*32 + 16 = $2180 + $10 = $2190
    sta PPU_ADDR
    lda #$90
    sta PPU_ADDR
    lda #$15              ; Inverted cap row 1 (under lip)
    sta PPU_DATA
    lda #$16
    sta PPU_DATA
    lda #$17
    sta PPU_DATA
    lda #$18
    sta PPU_DATA

    lda #$21              ; $2000 + 13*32 + 16 = $21A0 + $10 = $21B0
    sta PPU_ADDR
    lda #$B0
    sta PPU_ADDR
    lda #$11              ; Inverted cap row 2 (lip edge)
    sta PPU_DATA
    lda #$12
    sta PPU_DATA
    lda #$13
    sta PPU_DATA
    lda #$14
    sta PPU_DATA

    ; Bottom pipe cap (rows 20-21)
    lda #$22              ; $2000 + 20*32 + 16 = $2290
    sta PPU_ADDR
    lda #$90
    sta PPU_ADDR
    lda #$05
    sta PPU_DATA
    lda #$06
    sta PPU_DATA
    lda #$07
    sta PPU_DATA
    lda #$08
    sta PPU_DATA

    lda #$22              ; $2000 + 21*32 + 16 = $22B0
    sta PPU_ADDR
    lda #$B0
    sta PPU_ADDR
    lda #$09
    sta PPU_DATA
    lda #$0A
    sta PPU_DATA
    lda #$0B
    sta PPU_DATA
    lda #$0C
    sta PPU_DATA

    ; Pipe body (rows 22-25)
    ldx #22               ; Row counter
@pipe_body:
    ; Calculate high byte: $20 + (row / 8)
    txa
    lsr a
    lsr a
    lsr a                 ; A = row / 8
    clc
    adc #$20              ; A = $20 + (row / 8)
    sta PPU_ADDR
    ; Calculate low byte: ((row & 7) * 32) + column
    txa
    and #$07              ; A = row & 7
    asl a
    asl a
    asl a
    asl a
    asl a                 ; A = (row & 7) * 32
    clc
    adc #16               ; + column 16
    sta PPU_ADDR
    lda #$0D
    sta PPU_DATA
    lda #$0E
    sta PPU_DATA
    lda #$0F
    sta PPU_DATA
    lda #$10
    sta PPU_DATA
    inx
    cpx #26               ; End at row 25 (before ground at row 26)
    bne @pipe_body

    ; Set attributes for pipe area (palette 2)
    ; Pipe at columns 16-19 is in attribute column 4
    ;
    ; Top pipe attributes:
    ; Attr row 0 (tile rows 0-3): all pipe = $AA
    ; Attr row 1 (tile rows 4-7): all pipe = $AA
    ; Attr row 2 (tile rows 8-11): all pipe = $AA
    ; Attr row 3 (tile rows 12-15): top=pipe, bottom=sky = $0A
    lda #$23
    sta PPU_ADDR
    lda #$C4              ; Attribute row 0, column 4
    sta PPU_ADDR
    lda #$AA
    sta PPU_DATA
    lda #$23
    sta PPU_ADDR
    lda #$CC              ; Attribute row 1, column 4
    sta PPU_ADDR
    lda #$AA
    sta PPU_DATA
    lda #$23
    sta PPU_ADDR
    lda #$D4              ; Attribute row 2, column 4
    sta PPU_ADDR
    lda #$AA
    sta PPU_DATA
    lda #$23
    sta PPU_ADDR
    lda #$DC              ; Attribute row 3, column 4
    sta PPU_ADDR
    lda #$0A              ; %00001010 = top palette 2, bottom palette 0
    sta PPU_DATA
    ;
    ; Bottom pipe attributes:
    ; Attr row 5 (tile rows 20-23): all pipe = $AA
    ; Attr row 6 (tile rows 24-27): top=pipe, bottom=ground = $5A
    lda #$23
    sta PPU_ADDR
    lda #$EC              ; Attribute row 5, column 4
    sta PPU_ADDR
    lda #$AA
    sta PPU_DATA
    lda #$23
    sta PPU_ADDR
    lda #$F4              ; Attribute row 6, column 4
    sta PPU_ADDR
    lda #$5A              ; %01011010 = top palette 2, bottom palette 1
    sta PPU_DATA

    ; Draw second pipe pair in nametable 1 at column 16

    ; Top pipe body (rows 0-11) using inverted body tiles
    ldx #0                ; Row counter (start from ceiling)
@pipe_top2:
    ; Calculate high byte: $24 + (row / 8)
    txa
    lsr a
    lsr a
    lsr a                 ; A = row / 8
    clc
    adc #$24              ; A = $24 + (row / 8)
    sta PPU_ADDR
    ; Calculate low byte: ((row & 7) * 32) + column
    txa
    and #$07              ; A = row & 7
    asl a
    asl a
    asl a
    asl a
    asl a                 ; A = (row & 7) * 32
    clc
    adc #16               ; + column 16
    sta PPU_ADDR
    lda #$19              ; Inverted body tiles
    sta PPU_DATA
    lda #$1A
    sta PPU_DATA
    lda #$1B
    sta PPU_DATA
    lda #$1C
    sta PPU_DATA
    inx
    cpx #12               ; End at row 11
    bne @pipe_top2

    ; Top pipe cap (rows 12-13) using inverted cap tiles
    lda #$25              ; $2400 + 12*32 + 16 = $2590
    sta PPU_ADDR
    lda #$90
    sta PPU_ADDR
    lda #$15              ; Inverted cap row 1 (under lip)
    sta PPU_DATA
    lda #$16
    sta PPU_DATA
    lda #$17
    sta PPU_DATA
    lda #$18
    sta PPU_DATA

    lda #$25              ; $2400 + 13*32 + 16 = $25B0
    sta PPU_ADDR
    lda #$B0
    sta PPU_ADDR
    lda #$11              ; Inverted cap row 2 (lip edge)
    sta PPU_DATA
    lda #$12
    sta PPU_DATA
    lda #$13
    sta PPU_DATA
    lda #$14
    sta PPU_DATA

    ; Bottom pipe cap (rows 20-21)
    lda #$26              ; $2400 + 20*32 + 16 = $2690
    sta PPU_ADDR
    lda #$90
    sta PPU_ADDR
    lda #$05
    sta PPU_DATA
    lda #$06
    sta PPU_DATA
    lda #$07
    sta PPU_DATA
    lda #$08
    sta PPU_DATA

    lda #$26              ; $2400 + 21*32 + 16 = $26B0
    sta PPU_ADDR
    lda #$B0
    sta PPU_ADDR
    lda #$09
    sta PPU_DATA
    lda #$0A
    sta PPU_DATA
    lda #$0B
    sta PPU_DATA
    lda #$0C
    sta PPU_DATA

    ; Pipe body (rows 22-25)
    ldx #22               ; Row counter
@pipe_body2:
    ; Calculate high byte: $24 + (row / 8)
    txa
    lsr a
    lsr a
    lsr a                 ; A = row / 8
    clc
    adc #$24              ; A = $24 + (row / 8)
    sta PPU_ADDR
    ; Calculate low byte: ((row & 7) * 32) + column
    txa
    and #$07              ; A = row & 7
    asl a
    asl a
    asl a
    asl a
    asl a                 ; A = (row & 7) * 32
    clc
    adc #16               ; + column 16
    sta PPU_ADDR
    lda #$0D
    sta PPU_DATA
    lda #$0E
    sta PPU_DATA
    lda #$0F
    sta PPU_DATA
    lda #$10
    sta PPU_DATA
    inx
    cpx #26               ; End at row 25 (before ground at row 26)
    bne @pipe_body2

    ; Set attributes for pipe in nametable 1
    ; Top pipe attributes
    lda #$27
    sta PPU_ADDR
    lda #$C4              ; Attribute row 0, column 4
    sta PPU_ADDR
    lda #$AA
    sta PPU_DATA
    lda #$27
    sta PPU_ADDR
    lda #$CC              ; Attribute row 1, column 4
    sta PPU_ADDR
    lda #$AA
    sta PPU_DATA
    lda #$27
    sta PPU_ADDR
    lda #$D4              ; Attribute row 2, column 4
    sta PPU_ADDR
    lda #$AA
    sta PPU_DATA
    lda #$27
    sta PPU_ADDR
    lda #$DC              ; Attribute row 3, column 4
    sta PPU_ADDR
    lda #$0A              ; %00001010 = top palette 2, bottom palette 0
    sta PPU_DATA
    ; Bottom pipe attributes
    lda #$27
    sta PPU_ADDR
    lda #$EC              ; Attribute row 5, column 4
    sta PPU_ADDR
    lda #$AA
    sta PPU_DATA
    lda #$27
    sta PPU_ADDR
    lda #$F4              ; Attribute row 6, column 4
    sta PPU_ADDR
    lda #$5A              ; %01011010 = top palette 2, bottom palette 1
    sta PPU_DATA

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

    ; Read controller
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
    ; Check ground collision
    lda bird_y
    cmp #GROUND_Y
    bcc @no_ground        ; bird_y < GROUND_Y, no collision
    lda #GROUND_Y         ; Clamp to ground
    sta bird_y
    lda #0                ; Stop falling
    sta bird_vel_lo
    sta bird_vel_hi
    sta bird_y_frac
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

    jmp game_loop

nmi:
    pha
    ; OAM DMA transfer
    lda #$00
    sta OAM_ADDR
    lda #>OAM_BUFFER      ; High byte of $0200
    sta OAM_DMA

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
; CHR-ROM
;===============================================================================
.segment "CHARS"

; Include external CHR file (8KB)
; Bank 0 ($0000-$0FFF): Sprites
; Bank 1 ($1000-$1FFF): Background
.incbin "../chr/graphics.chr"
