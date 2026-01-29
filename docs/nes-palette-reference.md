# NES PPU Palette Reference

## Overview

The PPU has 32 bytes of palette RAM at $3F00-$3F1F, defining colors for backgrounds and sprites. Each palette contains 4 colors, with color 0 being transparent (except for the universal backdrop).

## Memory Layout

| Address | Purpose |
|---------|---------|
| $3F00 | Universal background (backdrop) |
| $3F01-$3F03 | Background palette 0 |
| $3F04 | Mirror of $3F00 |
| $3F05-$3F07 | Background palette 1 |
| $3F08 | Mirror of $3F00 |
| $3F09-$3F0B | Background palette 2 |
| $3F0C | Mirror of $3F00 |
| $3F0D-$3F0F | Background palette 3 |
| $3F10 | Mirror of $3F00 |
| $3F11-$3F13 | Sprite palette 0 |
| $3F14 | Mirror of $3F00 |
| $3F15-$3F17 | Sprite palette 1 |
| $3F18 | Mirror of $3F00 |
| $3F19-$3F1B | Sprite palette 2 |
| $3F1C | Mirror of $3F00 |
| $3F1D-$3F1F | Sprite palette 3 |

**Mirroring:** $3F00-$3F1F mirrors throughout $3F00-$3FFF.

## Palette Structure

### Background Palettes ($3F00-$3F0F)
```
Palette 0: $3F00 (transparent), $3F01, $3F02, $3F03
Palette 1: $3F04 (transparent), $3F05, $3F06, $3F07
Palette 2: $3F08 (transparent), $3F09, $3F0A, $3F0B
Palette 3: $3F0C (transparent), $3F0D, $3F0E, $3F0F
```

### Sprite Palettes ($3F10-$3F1F)
```
Palette 0: $3F10 (transparent), $3F11, $3F12, $3F13
Palette 1: $3F14 (transparent), $3F15, $3F16, $3F17
Palette 2: $3F18 (transparent), $3F19, $3F1A, $3F1B
Palette 3: $3F1C (transparent), $3F1D, $3F1E, $3F1F
```

## Color Index Construction

The PPU builds a 5-bit palette index:
```
43210
|||||
|||++- Pixel value from tile data (2 bits)
|++--- Palette number from attribute table (2 bits)
+----- 0=background, 1=sprite
```

When pixel value is 0, the color is transparent and shows the backdrop ($3F00).

## Color Value Format (6-bit)

```
76543210
  VVHHHH
  ||||||
  ||++++- Hue (0-15)
  ++------ Luma/Value (0-3)
```

### Hue Values
| Hue | Color |
|-----|-------|
| $0 | Gray |
| $1 | Azure |
| $2 | Blue |
| $3 | Violet |
| $4 | Magenta |
| $5 | Rose |
| $6 | Red |
| $7 | Orange |
| $8 | Yellow |
| $9 | Chartreuse |
| $A | Green |
| $B | Spring |
| $C | Cyan |
| $D | Gray (dark) |
| $E-$F | Black (mirrors) |

### Luma Values
| Luma | Brightness |
|------|------------|
| $0X | Darkest |
| $1X | Dark |
| $2X | Normal |
| $3X | Lightest |

### Common Colors
| Value | Color |
|-------|-------|
| $0F | Black |
| $00 | Dark gray |
| $10 | Light gray |
| $20 | White-ish gray |
| $30 | White |
| $22 | Light blue |
| $16 | Red |
| $1A | Green |
| $12 | Blue |

## Universal Background Color

- Located at $3F00
- Displayed where both background and sprites are transparent
- Also shown in overscan/border areas
- Writes to $3F00, $3F04, $3F08, $3F0C, $3F10, $3F14, $3F18, $3F1C all update this color

## Transparency

- Color index 0 in any palette is transparent
- For sprites: shows background or backdrop behind
- For background: shows backdrop ($3F00)
- Palette entries at $3F04, $3F08, $3F0C, $3F10, $3F14, $3F18, $3F1C are technically unused but mirror $3F00

## PPUMASK Effects

### Grayscale Mode (Bit 0)
```asm
lda #%00000001
sta PPUMASK      ; Enable grayscale
```
Forces all colors to column $0X (grays only). Affects display, not palette RAM.

### Color Emphasis (Bits 5-7)
```
76543210
|||
||+------ Emphasize red (darken green/blue)
|+------- Emphasize green (darken red/blue)
+-------- Emphasize blue (darken red/green)
```

On composite output (NTSC/PAL), emphasis darkens other colors.
On RGB PPUs, emphasis brightens the selected channel.

## Writing Palettes

```asm
; Set PPU address to palette
lda #$3F
sta PPUADDR
lda #$00
sta PPUADDR

; Write background palette 0
lda #$0F         ; Black (transparent/backdrop)
sta PPUDATA
lda #$16         ; Red
sta PPUDATA
lda #$1A         ; Green
sta PPUDATA
lda #$12         ; Blue
sta PPUDATA

; Continue with more palettes...
```

## Reading Palettes

Reading palette RAM has a quirk: the read buffer returns the previous VRAM read, while the actual palette value appears immediately. Use a dummy read or understand buffering behavior.

```asm
; Read palette value
lda #$3F
sta PPUADDR
lda #$01         ; Address $3F01
sta PPUADDR
lda PPUDATA      ; Returns palette value immediately (no buffering for $3F00+)
```

## Best Practices

1. **Set palettes during vblank** to avoid mid-frame glitches
2. **Use $0F for black**, not $0E or $1D (those may have slight color tint)
3. **Share backdrop color** - all palettes see the same $3F00 value
4. **Reset PPU address after palette writes** before setting scroll

```asm
; After writing palettes, reset address
lda #$00
sta PPUADDR
sta PPUADDR      ; Point to $0000 before setting scroll
```

## References

- https://www.nesdev.org/wiki/PPU_palettes
- https://www.nesdev.org/wiki/PPU_registers
