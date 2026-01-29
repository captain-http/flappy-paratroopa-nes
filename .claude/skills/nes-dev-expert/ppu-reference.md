# PPU Reference

## PPU Memory Map

| Address | Size | Description |
|---------|------|-------------|
| $0000-$0FFF | 4KB | Pattern Table 0 (CHR) |
| $1000-$1FFF | 4KB | Pattern Table 1 (CHR) |
| $2000-$23BF | 960B | Nametable 0 |
| $23C0-$23FF | 64B | Attribute Table 0 |
| $2400-$27BF | 960B | Nametable 1 |
| $27C0-$27FF | 64B | Attribute Table 1 |
| $2800-$2BBF | 960B | Nametable 2 |
| $2BC0-$2BFF | 64B | Attribute Table 2 |
| $2C00-$2FBF | 960B | Nametable 3 |
| $2FC0-$2FFF | 64B | Attribute Table 3 |
| $3000-$3EFF | | Mirror of $2000-$2EFF |
| $3F00-$3F0F | 16B | Background Palettes |
| $3F10-$3F1F | 16B | Sprite Palettes |
| $3F20-$3FFF | | Mirrors of $3F00-$3F1F |

## PPU Registers

### PPUCTRL ($2000) - Write Only

```
7654 3210
VPHB SINN
|||| ||||
|||| ||++- Nametable select (0=$2000, 1=$2400, 2=$2800, 3=$2C00)
|||| |+--- VRAM increment (0: +1 across, 1: +32 down)
|||| +---- Sprite pattern table (0: $0000, 1: $1000)
|||+------ Background pattern table (0: $0000, 1: $1000)
||+------- Sprite size (0: 8x8, 1: 8x16)
|+-------- PPU master/slave (0: read backdrop from EXT, 1: output color)
+--------- NMI enable (0: off, 1: on)
```

**Timing:** Setting bit 7 from 0→1 while vblank flag is set triggers immediate NMI.

### PPUMASK ($2001) - Write Only

```
7654 3210
BGRs bMmG
|||| ||||
|||| |||+- Greyscale (0: normal, 1: greyscale)
|||| ||+-- Show background in left 8 pixels
|||| |+--- Show sprites in left 8 pixels
|||| +---- Show background
|||+------ Show sprites
||+------- Emphasize red (green on PAL)
|+-------- Emphasize green (red on PAL)
+--------- Emphasize blue
```

**Common values:** $1E (rendering on), $00 (rendering off)

### PPUSTATUS ($2002) - Read Only

```
7654 3210
VSO. ....
|||| ||||
|||+-++++- Open bus / PPU 2C05 signature
||+------- Sprite overflow (buggy)
|+-------- Sprite 0 hit
+--------- VBlank flag (cleared on read)
```

**Side effect:** Reading resets write toggle (w) for PPUSCROLL/PPUADDR.

### OAMADDR ($2003) - Write Only
OAM address for OAMDATA access. Write $00 before OAMDMA.

### OAMDATA ($2004) - Read/Write
OAM data port. Avoid for bulk writes - use OAMDMA.

### PPUSCROLL ($2005) - Write x2
1st write: X scroll (0-255)
2nd write: Y scroll (0-239; 240-255 cause glitches)

### PPUADDR ($2006) - Write x2
1st write: High byte of VRAM address (bits 8-13, bit 14 cleared)
2nd write: Low byte of VRAM address

**Critical:** Shares internal registers with PPUSCROLL. Reload scroll after VRAM writes.

### PPUDATA ($2007) - Read/Write
VRAM data port. Auto-increments address by 1 or 32 (per PPUCTRL bit 2).

**Read buffer:** First read returns stale data. Palette reads ($3F00+) return immediately but corrupt buffer.

### OAMDMA ($4014) - Write Only
Write page number (high byte). Copies 256 bytes from $xx00 to OAM.
**Timing:** 513 cycles (+1 if started on odd CPU cycle).

## Pattern Tables (Tiles)

Two 256-tile pattern tables at $0000-$0FFF ("left") and $1000-$1FFF ("right").

Each tile is 16 bytes: two 8-byte bitplanes.

### Tile Address Format

```
0HRRRR RRRCPPP
 |││││ │││││││
 |││││ │││└┴┴┴─ Fine Y offset (row 0-7 within tile)
 |││││ ││└───── Bit plane (0=low bits, 1=high bits)
 |└┴┴┴─┴┴────── Tile number ($00-$FF)
 └───────────── Pattern table half (0=$0000, 1=$1000)
```

**Example:** Row 1 of tile $69 in left table:
- Plane 0 at $0691
- Plane 1 at $0699

### Bitplane Encoding

```
Plane 0 (bytes 0-7):  Controls bit 0 of color index
Plane 1 (bytes 8-15): Controls bit 1 of color index

Pixel value = (plane1_bit << 1) | plane0_bit
```

| Pixel Value | Meaning |
|-------------|---------|
| 0 | Transparent / Background color |
| 1 | Color 1 |
| 2 | Color 2 |
| 3 | Color 3 |

### Pattern Table Selection

PPUCTRL ($2000) controls which pattern table is used:
- Bit 4: Background pattern table (0=$0000, 1=$1000)
- Bit 3: 8×8 sprite pattern table (0=$0000, 1=$1000)
- For 8×16 sprites: Bit 0 of OAM tile index selects pattern table

## Nametables

960 bytes of tile indices (32 columns × 30 rows) + 64 bytes attribute table.

### Nametable Mirroring

| Type | $2000 | $2400 | $2800 | $2C00 | Use |
|------|-------|-------|-------|-------|-----|
| Horizontal | A | A | B | B | Vertical scrolling |
| Vertical | A | B | A | B | Horizontal scrolling |
| Single-screen | A | A | A | A | Mapper controlled |
| Four-screen | A | B | C | D | Requires extra VRAM |

## Attribute Tables

64-byte array (8×8 grid) at $23C0, $27C0, $2BC0, or $2FC0 per nametable.

Each byte controls palette for a 32×32 pixel region (4×4 tiles), divided into four 16×16 pixel quadrants (2×2 tiles each).

```
Attribute byte layout:
7654 3210
││││ ││└┴─ Palette for top-left quadrant (2×2 tiles)
││││ └┴─── Palette for top-right quadrant
││└┴────── Palette for bottom-left quadrant
└┴──────── Palette for bottom-right quadrant
```

### Building an Attribute Byte

```
value = (bottom_right << 6) | (bottom_left << 4) | (top_right << 2) | top_left
```

**Example:** Palettes TL=3, TR=1, BL=2, BR=2:
```
value = (2 << 6) | (2 << 4) | (1 << 2) | 3
      = $80     | $20     | $04     | $03
      = $A7
```

### Attribute Address Calculation

```
attribute_addr = $23C0 | (v & $0C00) | ((v >> 4) & $38) | ((v >> 2) & $07)
```

Where `v` is the current VRAM address. The formula extracts:
- Nametable select from bits 10-11
- Coarse Y / 4 for row (bits 7-9 → bits 3-5)
- Coarse X / 4 for column (bits 2-4 → bits 0-2)

## Palettes

| Address | Description |
|---------|-------------|
| $3F00 | Universal background |
| $3F01-$3F03 | BG palette 0 |
| $3F05-$3F07 | BG palette 1 |
| $3F09-$3F0B | BG palette 2 |
| $3F0D-$3F0F | BG palette 3 |
| $3F11-$3F13 | Sprite palette 0 |
| $3F15-$3F17 | Sprite palette 1 |
| $3F19-$3F1B | Sprite palette 2 |
| $3F1D-$3F1F | Sprite palette 3 |

**Mirrors:** $3F10, $3F14, $3F18, $3F1C mirror $3F00, $3F04, $3F08, $3F0C.

## OAM (Sprites)

256 bytes of internal PPU memory = 64 sprites × 4 bytes each.

| Address Range | Contents |
|---------------|----------|
| $00-$03 | Sprite 0 |
| $04-$07 | Sprite 1 |
| ... | ... |
| $FC-$FF | Sprite 63 |

### Byte 0: Y Position
- Top of sprite, **minus 1** (write Y-1 to position at Y)
- Values $EF-$FF hide the sprite (off bottom of screen)
- Sprites cannot appear on scanline 0

### Byte 1: Tile Index

**8×8 Sprites:** Tile number from pattern table selected by PPUCTRL bit 3

**8×16 Sprites:**
- Bit 0: Pattern table bank ($0000 or $1000)
- Bits 1-7: Tile number (top half; bottom half is next tile)
- PPUCTRL sprite pattern bit ignored

### Byte 2: Attributes

```
7654 3210
VHP. ..PP
││││ ││└┴─ Palette (4-7, adds 4 to get palette index)
│││└─┴┴─── Unimplemented (read as 0)
││└─────── Priority (0: in front of BG, 1: behind BG)
│└──────── Flip horizontally
└───────── Flip vertically
```

### Byte 3: X Position
- Left edge of sprite (0-255)
- Values $F9-$FF push sprite partially/fully off right edge
- Left-edge clipping controlled by PPUMASK bit 2

### Sprite Priority
- Lower OAM index = higher priority (drawn on top)
- Sprite 0 always has highest priority when in range
- Max 8 sprites per scanline (others dropped, sets overflow flag)

### Sprite 0 Hit
PPUSTATUS bit 6 set when opaque sprite 0 pixel overlaps opaque BG pixel.

**Not set when:**
- At X=255
- At X=0-7 with left clipping enabled
- Rendering disabled
- Already set this frame (cleared at vblank)

### OAM DMA

```asm
lda #$00
sta OAMADDR      ; Start at OAM address 0
lda #$02         ; High byte of $0200
sta OAMDMA       ; Transfer $0200-$02FF to OAM
```

**Timing:** 513 cycles (+1 if started on odd cycle). Much faster than manual loop (~2048 cycles).

### OAM Quirks
- OAM uses dynamic RAM that decays without refresh
- Update during vblank only (in NMI handler)
- Bits 2-4 of attribute byte always read as 0
- Set OAMADDR to 0 before OAMDMA

## PPU Timing

### Frame Structure

| Scanline | Name | Description |
|----------|------|-------------|
| 0-239 | Visible | Rendering occurs |
| 240 | Post-render | Idle |
| 241-260 | VBlank | Safe VRAM access (NTSC: 20 lines) |
| 261 (-1) | Pre-render | Setup for next frame |

### Scanline Timing (341 dots)

| Dots | Activity |
|------|----------|
| 0 | Idle |
| 1-256 | Tile fetches, pixel output |
| 257-320 | Sprite fetches for next line |
| 321-336 | First 2 tiles for next line |
| 337-340 | Unused fetches |

### Key Events
- **Scanline 241, dot 1:** VBlank flag set, NMI fires
- **Pre-render, dot 1:** VBlank flag cleared, sprite 0 cleared
- **Pre-render, dots 280-304:** Vertical scroll reloaded
- **Dot 257:** Horizontal scroll reloaded from t to v

## Scrolling

### Internal Registers

```
v: Current VRAM address (15 bits)
t: Temporary VRAM address (15 bits)
x: Fine X scroll (3 bits)
w: Write toggle (1 bit)
```

### v/t Register Format

```
 yyy NN YYYYY XXXXX
 ||| || ||||| |||||
 ||| || ||||| +++++- Coarse X (tile column 0-31)
 ||| || +++++------- Coarse Y (tile row 0-29)
 ||| ++------------- Nametable select
 +++---------------- Fine Y (pixel row 0-7)
```

### Scroll Setup Sequence
```asm
; During VBlank or rendering off:
    bit PPUSTATUS    ; Reset w toggle
    lda #X_SCROLL
    sta PPUSCROLL    ; Write X
    lda #Y_SCROLL
    sta PPUSCROLL    ; Write Y
    lda #PPUCTRL_VAL ; Nametable in bits 0-1
    sta PPUCTRL
```

### Mid-Frame Scroll Changes
- Write PPUSCROLL X before dot 257 (horizontal reload)
- Full X/Y change requires PPUADDR/PPUSCROLL trick
- Write timing critical to avoid glitches

## Hardware Errata

### PPU Bugs
- **Sprite overflow flag:** Buggy detection, false positives/negatives
- **Sprite 0 hit:** Cannot trigger at X=255
- **OAM corruption:** Writing OAMADDR mid-frame corrupts OAM rows
- **OAM decay:** Dynamic RAM needs refresh each frame
- **Palette read:** Unreliable on early PPU revisions
- **PPU warmup:** Registers ignored for ~30,000 cycles after reset

## Safe VRAM Access

VRAM ($2006/$2007) only safe:
- During VBlank (scanlines 241-260)
- With rendering disabled (PPUMASK = $00)

Writing during rendering corrupts display and scroll position.
