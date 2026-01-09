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

    ; Setup bird sprites (4 sprites in 2x2)
    ; Sprite 0: top-left
    lda #100              ; Y position
    sta OAM_BUFFER+0
    lda #$00              ; Tile 0
    sta OAM_BUFFER+1
    lda #$00              ; Attributes (palette 0)
    sta OAM_BUFFER+2
    lda #120              ; X position
    sta OAM_BUFFER+3

    ; Sprite 1: top-right
    lda #100
    sta OAM_BUFFER+4
    lda #$00
    sta OAM_BUFFER+5
    lda #$00
    sta OAM_BUFFER+6
    lda #128              ; X + 8
    sta OAM_BUFFER+7

    ; Sprite 2: bottom-left
    lda #108              ; Y + 8
    sta OAM_BUFFER+8
    lda #$00
    sta OAM_BUFFER+9
    lda #$00
    sta OAM_BUFFER+10
    lda #120
    sta OAM_BUFFER+11

    ; Sprite 3: bottom-right
    lda #108
    sta OAM_BUFFER+12
    lda #$00
    sta OAM_BUFFER+13
    lda #$00
    sta OAM_BUFFER+14
    lda #128
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

forever:
    jmp forever           ; Infinite loop

nmi:
    pha
    ; OAM DMA transfer
    lda #$00
    sta OAM_ADDR
    lda #>OAM_BUFFER      ; High byte of $0200
    sta OAM_DMA
    pla
    rti

irq:
    rti

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
