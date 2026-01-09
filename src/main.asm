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

    ; Background palette 0
    lda #$21              ; Light blue (universal bg)
    sta PPU_DATA
    lda #$21
    sta PPU_DATA
    sta PPU_DATA
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
    lda #$00              ; Tile 0
    sta OAM_BUFFER+1
    sta OAM_BUFFER+5
    sta OAM_BUFFER+9
    sta OAM_BUFFER+13
    lda #$00              ; Attributes (palette 0)
    sta OAM_BUFFER+2
    sta OAM_BUFFER+6
    sta OAM_BUFFER+10
    sta OAM_BUFFER+14
    ; X positions (fixed)
    lda #120
    sta OAM_BUFFER+3
    sta OAM_BUFFER+11
    lda #128
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

    ; Enable NMI and set sprite pattern table to $1000
    lda #%10001000
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

    jmp game_loop

nmi:
    pha
    ; OAM DMA transfer
    lda #$00
    sta OAM_ADDR
    lda #>OAM_BUFFER      ; High byte of $0200
    sta OAM_DMA
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

; Background pattern table ($0000-$0FFF) - empty
.res $1000

; Sprite pattern table ($1000-$1FFF)
; Tile 0: Solid block (color 1 = yellow)
.byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ; Bit plane 0 (all pixels on)
.byte $00,$00,$00,$00,$00,$00,$00,$00  ; Bit plane 1 (all pixels off)
; Result: all pixels = %01 = color 1

; Fill rest of sprite tiles with zeros
.res $1000 - 16
