# Technical Decisions

## Mapper: NROM-256

**Decision:** Use NROM (mapper 0) with 32KB PRG-ROM and 8KB CHR-ROM.

**Why NROM:**
- Simplest NES mapper - no bank switching logic needed
- Sufficient for a small game like Flappy Bird
- Maximum compatibility with emulators and hardware

**Memory Layout:**
```
PRG-ROM: $8000-$FFFF (32KB)
CHR-ROM: 8KB (256 background + 256 sprite tiles)
RAM:     $0000-$07FF (2KB)
```

**Limitations:**
- 32KB code/data maximum
- 8KB graphics maximum (512 tiles total)
- No CHR-RAM (tiles fixed at compile time)

**ROM Output:**
```
Offset   Size    Content
$0000    16B     iNES header
$0010    32KB    PRG-ROM
$8010    8KB     CHR-ROM
```

## Background Color: $21

**Decision:** Use NES palette color `$21` (light blue) as the universal background.

This color fills the sky. All palettes share this as color 0, so design sprites and tiles accordingly.

## Bird Sprite: 16x16 (4 tiles)

**Decision:** Use 4 tiles arranged 2x2 for the bird.

```
┌───┬───┐
│ 0 │ 1 │  Each tile = 8x8
├───┼───┤  Total = 16x16 pixels
│ 2 │ 3 │  4 OAM entries needed
└───┴───┘
```

**Prototype color:** `$27` (yellow)

## Physics: 8.8 Fixed-Point

**Decision:** Use 8.8 fixed-point math for smooth subpixel movement.

**Format:**
```
High byte = integer (pixels)
Low byte  = fraction (256ths of a pixel)
```

**Variables:**
| Variable | Address | Description |
|----------|---------|-------------|
| bird_y_frac | $00 | Y position fractional |
| bird_y | $01 | Y position integer |
| bird_vel_lo | $02 | Velocity fractional |
| bird_vel_hi | $03 | Velocity integer (signed) |

**Constants:**
```
GRAVITY  = $40    ; ~0.25 pixels/frame² (floaty feel)
GROUND_Y = 200    ; Invisible ground level
```

**Why 8.8:**
- Smooth movement without jerky pixel jumps
- Gravity of 1 pixel/frame was too fast
- Allows fine-tuning physics feel
