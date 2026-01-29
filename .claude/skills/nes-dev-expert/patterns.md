# Common NES Patterns

## Initialization Code

```asm
reset:
    sei             ; Disable IRQs
    cld             ; Clear decimal mode
    ldx #$40
    stx $4017       ; Disable APU frame IRQ
    ldx #$FF
    txs             ; Setup stack
    inx             ; X = 0
    stx PPUCTRL     ; Disable NMI
    stx PPUMASK     ; Disable rendering
    stx $4010       ; Disable DMC IRQs

    ; First wait for vblank
@vwait1:
    bit PPUSTATUS
    bpl @vwait1

    ; Clear RAM
    lda #$00
@clrmem:
    sta $0000, x
    sta $0100, x
    sta $0200, x
    sta $0300, x
    sta $0400, x
    sta $0500, x
    sta $0600, x
    sta $0700, x
    inx
    bne @clrmem

    ; Second wait for vblank (PPU ready)
@vwait2:
    bit PPUSTATUS
    bpl @vwait2

    ; PPU is now ready
    ; Initialize palette, nametables, etc.
```

## NMI Handler Template

```asm
nmi:
    pha
    txa
    pha
    tya
    pha

    ; OAM DMA (must be in vblank)
    lda #$00
    sta OAMADDR
    lda #>oam_buffer  ; High byte of OAM buffer
    sta OAMDMA

    ; Update VRAM (palettes, nametables, etc.)
    ; ...

    ; Reset scroll (after any PPUADDR writes!)
    bit PPUSTATUS
    lda #$00
    sta PPUSCROLL
    sta PPUSCROLL
    lda ppu_ctrl_val
    sta PPUCTRL

    ; Signal main loop
    inc nmi_ready

    pla
    tay
    pla
    tax
    pla
    rti
```

## Game Loop Patterns

### NMI-Synchronized Main Loop

```asm
main_loop:
    ; Wait for NMI to signal vblank complete
    lda nmi_ready
    beq main_loop
    lda #0
    sta nmi_ready

    ; Game logic runs here (outside vblank)
    jsr read_controllers
    jsr update_game_state
    jsr update_sprites

    jmp main_loop
```

### Lag Frame Handling

When game logic takes longer than one frame:

```asm
nmi:
    ; Check if main loop is ready
    lda nmi_ready
    bne @skip_update   ; Still processing - lag frame

    ; Normal vblank work
    jsr upload_oam
    jsr update_vram
    inc nmi_ready

@skip_update:
    rti
```

**Lag Frame Consequences:**
- Sprites show stale positions (visible jitter)
- Audio timing may drift
- Controller input feels delayed

### Double Buffering VRAM Updates

```asm
; Main loop prepares updates in buffer
    lda #TILE_ID
    sta vram_buffer, x
    inx
    inc vram_buffer_len

; NMI uploads buffer to PPU
nmi_upload:
    ldx #0
@loop:
    cpx vram_buffer_len
    beq @done
    lda vram_buffer, x
    sta PPUDATA
    inx
    bne @loop
@done:
    lda #0
    sta vram_buffer_len
```

## Advanced Scrolling

### Split Scrolling (Status Bar)

Status bar at top with scrolling playfield below:

```asm
; In NMI - set scroll for status bar
    lda #0
    sta PPUSCROLL    ; X = 0
    sta PPUSCROLL    ; Y = 0

; After sprite 0 hit - change scroll
wait_sprite0:
    bit PPUSTATUS
    bvs wait_sprite0  ; Wait for flag clear
@wait:
    bit PPUSTATUS
    bvc @wait         ; Wait for hit

    ; Change scroll for playfield
    lda scroll_x
    sta PPUSCROLL
    lda scroll_y
    sta PPUSCROLL
```

### Mid-Frame Scroll Change (PPUADDR Method)

For precise mid-screen scroll changes:

```asm
; Set X scroll via PPUSCROLL (fine X)
    lda new_scroll_x
    sta PPUSCROLL

; Set coarse X, Y, and nametable via PPUADDR
    lda new_scroll_high  ; NN YYYYY X (upper bits)
    sta PPUADDR
    lda new_scroll_low   ; XXXXX YYY (lower bits + fine Y in coarse)
    sta PPUADDR
```

**Timing Critical:** Must complete before dot 257 of target scanline.

### Horizontal Scrolling Pattern

```asm
; Update scroll position
    clc
    lda scroll_x
    adc scroll_speed
    sta scroll_x
    lda scroll_x+1
    adc #0
    and #$01          ; Wrap at 512 pixels (2 screens)
    sta scroll_x+1

; In NMI
    lda scroll_x
    sta PPUSCROLL
    lda #0
    sta PPUSCROLL
    lda ppu_ctrl_val
    ora scroll_x+1    ; Add nametable bit
    sta PPUCTRL
```

## Math Techniques

### Negation (Two's Complement)
```asm
; Negate A
    eor #$FF
    clc
    adc #1
; Or equivalently:
    eor #$FF
    sec
    adc #0
```

### Arithmetic Right Shift (Signed Division by 2)
```asm
    cmp #$80      ; Set carry if negative
    ror a         ; Shift right, preserving sign
```

### Sign Extension (8-bit to 16-bit)
```asm
    ; A contains signed 8-bit value
    sta value_lo
    ora #$7F      ; Keep sign bit
    bmi @negative
    lda #$00
    beq @store
@negative:
    lda #$FF
@store:
    sta value_hi
```

### 8-bit Multiplication (Russian Peasant)
```asm
; Multiply A * Y, result in A (high) and temp (low)
multiply:
    sty temp
    lda #0
    ldx #8
@loop:
    lsr temp      ; Shift multiplier
    bcc @no_add
    clc
    adc factor1   ; Add multiplicand if bit set
@no_add:
    ror a         ; Shift result
    ror result_lo
    dex
    bne @loop
    ; A = high byte, result_lo = low byte
    rts
```

### 16-bit Increment/Decrement
```asm
; Increment 16-bit value
    inc value_lo
    bne @done
    inc value_hi
@done:

; Decrement 16-bit value
    lda value_lo
    bne @no_borrow
    dec value_hi
@no_borrow:
    dec value_lo
```

## Random Number Generation

### 16-bit LFSR (Galois)
```asm
; Returns random 8-bit value in A
; seed must be non-zero
prng:
    lda seed+1
    lsr a
    lda seed
    ror a
    bcc @no_eor
    eor #$39      ; Polynomial feedback
@no_eor:
    sta seed
    lda seed+1
    bcc @no_eor2
    eor #$00
@no_eor2:
    sta seed+1
    lda seed
    rts
```

**Properties:**
- Period: 65,535 (all non-zero values)
- Cycle count: ~137 cycles
- Code size: 19 bytes

**Seed Initialization:**
```asm
; Count frames until button press for random seed
wait_start:
    inc seed
    bne @no_wrap
    inc seed+1
    bne @no_wrap
    inc seed      ; Avoid zero seed
@no_wrap:
    lda buttons
    and #BUTTON_START
    beq wait_start
```

## Controller Reading (Extended)

### DPCM-Safe Controller Read

```asm
; Read controller twice, compare results
read_controller_safe:
    jsr read_controller_once
    sta buttons_temp
    jsr read_controller_once
    cmp buttons_temp
    bne read_controller_safe  ; Mismatch - retry
    sta buttons
    rts

read_controller_once:
    lda #$01
    sta $4016
    lsr a
    sta $4016
    ldx #8
@loop:
    lda $4016
    lsr a
    rol buttons
    dex
    bne @loop
    lda buttons
    rts
```

### New vs Held Button Detection

```asm
; Call after reading buttons
    lda buttons
    eor buttons_old    ; Changed buttons
    and buttons        ; Only newly pressed
    sta buttons_new
    lda buttons
    sta buttons_old
```

## Common Code Snippets

### Enable Rendering
```asm
    lda #%00011110  ; BG + sprites on
    sta PPUMASK
```

### Disable Rendering
```asm
    lda #$00
    sta PPUMASK
```

### Load Palette
```asm
    bit PPUSTATUS
    lda #$3F
    sta PPUADDR
    lda #$00
    sta PPUADDR
    ldx #$00
@loop:
    lda palette, x
    sta PPUDATA
    inx
    cpx #$20
    bne @loop
```

### Wait for VBlank (polling)
```asm
@wait:
    bit PPUSTATUS
    bpl @wait
```

### Hide All Sprites
```asm
    lda #$FF        ; Y = 255 (off screen)
    ldx #$00
@loop:
    sta oam_buffer, x
    inx
    inx
    inx
    inx
    bne @loop
```

### Sprite Flickering Mitigation
```asm
; Rotate OAM starting index each frame
    lda oam_offset
    clc
    adc #4            ; Next sprite slot
    and #$FC          ; Align to 4-byte boundary
    sta oam_offset
```

## Sample RAM Map

Standard organization for NES RAM:

| Address | Size | Usage |
|---------|------|-------|
| $0000-$000F | 16B | Local variables, pointer temps |
| $0010-$00FF | 240B | Global game state (zero page) |
| $0100-$01FF | 256B | Stack |
| $0200-$02FF | 256B | OAM shadow buffer (DMA source) |
| $0300-$03FF | 256B | Variables, buffers |
| $0400-$07FF | 1KB | Level data, entity arrays |

**Zero Page Best Practices:**
- Reserve $00-$0F for temporary variables
- Use $10+ for frequently accessed game state
- Keep pointer pairs together (low/high bytes)
- Place time-critical variables in ZP for fastest access

## Compression Techniques

### PackBits (Apple MacPaint)

| Control Byte | Meaning |
|--------------|---------|
| $00-$7F | Copy next (n+1) bytes literally |
| $80 | No operation |
| $81-$FF | Repeat next byte (257-n) times |

### Konami RLE (Contra, Simon's Quest)

| Control Byte | Meaning |
|--------------|---------|
| $00-$80 | Repeat next byte n times |
| $81-$FE | Copy next (n-128) literal bytes |
| $FF | End of stream |

### Simple RLE Decompressor

```asm
; Decompress to PPU or RAM
; src_ptr points to compressed data
decompress:
    ldy #0
@loop:
    lda (src_ptr), y
    beq @done         ; $00 = end marker
    bmi @run          ; High bit = run

    ; Literal: copy N bytes
    tax
@literal:
    iny
    lda (src_ptr), y
    sta PPUDATA       ; Or sta (dest_ptr), y
    dex
    bne @literal
    iny
    bne @loop

@run:
    and #$7F          ; Get count
    tax
    iny
    lda (src_ptr), y  ; Get repeated byte
@repeat:
    sta PPUDATA
    dex
    bne @repeat
    iny
    bne @loop

@done:
    rts
```
