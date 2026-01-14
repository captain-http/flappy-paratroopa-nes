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

## Background Color: $22

**Decision:** Use NES palette color `$22` (SMB sky blue) as the universal background.

This matches Super Mario Bros. sky color. All palettes share this as color 0.

## CHR-ROM Layout (SMB-style)

**Decision:** Use external CHR file with SMB-style pattern table layout.

```
Pattern Table 0 ($0000-$0FFF): Sprites
Pattern Table 1 ($1000-$1FFF): Background
```

**PPU_CTRL:** `%10010000`
- Bit 3 = 0: Sprites from $0000
- Bit 4 = 1: Background from $1000

**External CHR:** `chr/graphics.chr` (8KB, included via `.incbin`)

## Ground Tiles

**Decision:** Use SMB-style 2x2 repeating tile pattern for ground.

```
Rows 26-27: $01 $02 $01 $02...  (top-left, top-right)
            $03 $04 $03 $04...  (bottom-left, bottom-right)
Rows 28-29: Repeat pattern
```

**Palette 1 (ground):** `$22, $36, $17, $0F`
- $22: Universal bg (mirrored)
- $36: Light orange
- $17: Brown
- $0F: Black

**Attribute alignment:** Ground starts at row 26 to align with attribute row 6 ($23F0), matching SMB's approach.

**Nametable:** Both nametables filled for scrolling support.

## Pipe Tiles

**Decision:** 4-tile wide pipes with 2-row cap and repeating body.

**Tile layout:**
```
Bottom pipe (cap facing up):
  Cap row 1:  $05 $06 $07 $08
  Cap row 2:  $09 $0A $0B $0C
  Body:       $0D $0E $0F $10

Top pipe (cap facing down, inverted):
  Cap row 1:  $11 $12 $13 $14 (lip edge)
  Cap row 2:  $15 $16 $17 $18 (under lip)
  Body:       $19 $1A $1B $1C (inverted shading)
```

**Pipe pair layout (rows):**
```
Rows 0-9:    Top pipe body (inverted)
Row 10:      Top pipe cap ($15-$18)
Row 11:      Top pipe cap lip ($11-$14)
Rows 12-19:  Gap (8 tiles = 64px)
Rows 20-21:  Bottom pipe cap ($05-$0C)
Rows 22-25:  Bottom pipe body ($0D-$10)
Rows 26-29:  Ground
```

**Gap size:** 64px matches original Flappy Bird ratio (~4x bird height).

**Palette 2 (pipes):** `$22, $29, $1A, $0F`
- $22: Universal bg (mirrored)
- $29: Light green
- $1A: Dark green
- $0F: Black

**Attribute alignment:**
- Top pipe: attr rows 0-2 all pipe ($AA), row 3 top=pipe/bottom=sky ($0A)
- Bottom pipe: attr row 5 all pipe ($AA), row 6 top=pipe/bottom=ground ($5A)

NES background tiles cannot be flipped, so inverted tiles are stored separately in CHR-ROM.

## Pipe Spacing

**Decision:** 128px (16 tiles) between consecutive pipes, with empty initial screen.

**Layout:**
```
Nametable 0: Empty (no pipes) - initial screen
Nametable 1: Both pipes
  Pipe 0: column 0  (world pixel 256)
  Pipe 1: column 16 (world pixel 384)
Spacing: 384 - 256 = 128 pixels
```

**Why empty NT0:**
- Initial screen shows no pipes (clean start)
- First pipe appears only after scrolling 256 pixels
- Gives player time to learn controls before first obstacle

**Why 128px spacing:**
- Original Flappy Bird uses ~3.5x bird width spacing (~110-120px)
- 128px is close to original and aligns with NES tile boundaries (16 tiles)

**Attribute columns (in NT1):**
- Pipe 0: attribute column 0 (tiles 0-3)
- Pipe 1: attribute column 4 (tiles 16-19)

## Pipe Redraw on Scroll Loop

**Decision:** Redraw pipes dynamically when the off-screen nametable needs to be prepared, split across two frames to fit within vblank.

**Variables:**
| Variable | Address | Description |
|----------|---------|-------------|
| pipe_redraw | $0B | Redraw state (see state machine below) |
| nt_base | $0C | Nametable base ($20=NT0, $24=NT1) |
| pipe_col | $0D | Current pipe column (0 or 16) |

**Mechanism:**
1. Initial state: NT1 has both pipes at default gap, NT0 is empty
2. When scroll_x wraps (255→0), toggle scroll_nt
3. When switching TO NT1: NT0 just scrolled off-screen, set pipe_redraw=0
4. When switching TO NT0: NT1 just scrolled off-screen, set pipe_redraw=2
5. NMI handler checks pipe_redraw and calls draw_pipes_in_nt if needed

**Key insight:** Redraw the nametable that just went OFF-screen, not the one becoming visible. This ensures pipes are ready before the nametable scrolls back into view.

**Two-Frame Redraw:**

Drawing both pipes (~2560 cycles) exceeds the available vblank time (~1760 cycles after OAM DMA). Writing to VRAM outside vblank causes visual glitches. Solution: split across two frames.

```
NT0 Redraw:
Frame N:   pipe_redraw=0 → draw NT0 pipe 0 + attrs → set pipe_redraw=1
Frame N+1: pipe_redraw=1 → draw NT0 pipe 1 + attrs → set pipe_redraw=$FF

NT1 Redraw:
Frame N:   pipe_redraw=2 → draw NT1 pipe 0 + attrs → set pipe_redraw=3
Frame N+1: pipe_redraw=3 → draw NT1 pipe 1 + attrs → set pipe_redraw=$FF
```

| Frame | What | Cycles |
|-------|------|--------|
| 1 | Pipe 0 + attributes | ~1280 |
| 2 | Pipe 1 + attributes | ~1280 |

Each frame fits within the ~1760 cycle budget. The 1-frame delay (1/60th second) between pipes is invisible to the player.

**Timing:**
```
NT0 (empty) visible → scroll → switch to NT1 → pipe_redraw=0
NT1 visible, NMI draws pipe 0 in NT0 → pipe_redraw=1
NT1 visible, NMI draws pipe 1 in NT0 → pipe_redraw=$FF
... scroll continues ...
NT0 (now has pipes) visible → scroll → switch to NT0 → pipe_redraw=2
NT0 visible, NMI draws pipe 0 in NT1 → pipe_redraw=3
NT0 visible, NMI draws pipe 1 in NT1 → pipe_redraw=$FF
... continues seamlessly, both nametables now get random pipes
```

**Cycle Budget:**
```
VBlank total:     ~2273 cycles
OAM DMA:          - 513 cycles
Available:        ~1760 cycles
Per-pipe redraw:  ~1280 cycles  ✓ fits
```

## Bird Sprite: 16x16 (4 tiles)

**Decision:** Use 4 tiles arranged 2x2 for the bird.

```
┌───┬───┐
│ 1 │ 1 │  Currently: all use tile $01 (placeholder)
├───┼───┤  Future: tiles $01-$04 for proper bird graphic
│ 1 │ 1 │  4 OAM entries needed
└───┴───┘
```

**Sprite tile:** `$01` from pattern table 0 (sprite bank)

**X position:** 56-72 (centered at 1/4 screen width)
- NES screen width: 256 pixels
- Bird center: 64 pixels (256 ÷ 4)
- Left tiles: X=56, Right tiles: X=64
- Matches original Flappy Bird positioning

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
GRAVITY   = $40   ; ~0.25 pixels/frame² (floaty feel)
CEILING_Y = 8     ; Top boundary
GROUND_Y  = 192   ; Bottom boundary (bird sits on ground at row 26)
```

**Why 8.8:**
- Smooth movement without jerky pixel jumps
- Gravity of 1 pixel/frame was too fast
- Allows fine-tuning physics feel

## Controller Input

**Decision:** Edge detection for flap (new press only, not held).

**Implementation:**
```
buttons_new = buttons AND (NOT buttons_old)
```

This ensures:
- Holding button doesn't spam flaps
- Either A or B button works
- Responsive single-press input

**Constants:**
```
FLAP_VEL_LO = $00    ; Fractional part
FLAP_VEL_HI = $FC    ; -4 in signed 8-bit
```

Flap gives -4 pixels/frame upward velocity, which gravity counteracts over time creating the characteristic parabolic arc.

## Game State

**Decision:** Four-state machine for game flow.

**Variables:**
| Variable | Address | Description |
|----------|---------|-------------|
| game_state | $0A | 0 = waiting, 1 = playing, 2 = dying, 3 = dead |

**States:**
| State | Value | Behavior |
|-------|-------|----------|
| STATE_WAITING | 0 | Bird visible, waiting for A/B to start |
| STATE_PLAYING | 1 | Normal gameplay, input + physics + scrolling |
| STATE_DYING | 2 | No input, gravity only, bird falls |
| STATE_DEAD | 3 | Fully frozen, waiting for reset |

**Triggers:**
- A/B button press in WAITING → STATE_PLAYING (game starts)
- Pipe collision → STATE_DYING (bird tumbles down)
- Ground collision → STATE_DEAD (fully frozen)

**Pipe collision detection:**
- Calculate pipe X from scroll position
- Check X overlap: bird (56-72) vs pipe (pipe_x to pipe_x+32)
- Check Y overlap: bird outside gap using dynamic gap position

**Future:** Press Start to reset game.

## Random Pipe Heights

**Decision:** Randomize gap position on each pipe redraw for varied gameplay.

**RNG Implementation:**
8-bit LFSR (Linear Feedback Shift Register) with polynomial $1D:
```asm
get_random:
    lda rng_state
    asl a
    bcc @no_xor
    eor #$1D
@no_xor:
    sta rng_state
    rts
```

**Gap Range:**
- Minimum gap row: 8 (gap Y = 64px)
- Maximum gap row: 14 (gap Y = 112px)
- Gap size: 8 rows = 64 pixels (constant)

**Variables:**
| Variable | Address | Description |
|----------|---------|-------------|
| nt0_gap0 | $0E | NT0 pipe 0 gap row |
| nt0_gap1 | $0F | NT0 pipe 1 gap row |
| nt1_gap0 | $10 | NT1 pipe 0 gap row |
| nt1_gap1 | $11 | NT1 pipe 1 gap row |
| pipe_gap | $12 | Current gap (for drawing) |
| rng_state | $13 | RNG state (non-zero) |

**Why per-nametable tracking:**
- Each nametable has its own pipes with independent gaps
- Collision detection must use the correct gap for the visible pipe
- When viewing NT0, check against nt0_gap values
- When viewing NT1, check against nt1_gap values

**Pipe Drawing with Variable Gap:**
The `draw_pipe` routine uses `pipe_gap` to determine:
- Top body: rows 0 to (pipe_gap - 3)
- Top cap: rows (pipe_gap - 2) to (pipe_gap - 1)
- Gap: rows pipe_gap to (pipe_gap + 7) - draws sky tiles
- Bottom cap: rows (pipe_gap + 8) to (pipe_gap + 9)
- Bottom body: rows (pipe_gap + 10) to 25

**Redraw State Machine:**
```
pipe_redraw values:
0: Draw NT0 pipe 0, then set to 1
1: Draw NT0 pipe 1, then set to $FF
2: Draw NT1 pipe 0, then set to 3
3: Draw NT1 pipe 1, then set to $FF
$FF: No redraw needed
```

**When pipes are randomized:**
- When NT0 goes off-screen (switch to NT1): queue NT0 redraw (pipe_redraw=0)
- When NT1 goes off-screen (switch to NT0): queue NT1 redraw (pipe_redraw=2)
- New random gap generated for each pipe during redraw

## Scrolling

**Decision:** Horizontal scrolling active only when bird is flying.

**Variables:**
| Variable | Address | Description |
|----------|---------|-------------|
| scroll_x | $08 | X scroll position (0-255) |
| scroll_nt | $09 | Nametable select (0 or 1) |

**Logic:**
- Bird on ground (Y = GROUND_Y): no scrolling
- Bird flying: scroll 1 pixel/frame
- When scroll_x wraps 255→0, toggle scroll_nt

**Implementation:**
- Scroll updated in main game loop
- PPU_SCROLL and PPU_CTRL set in NMI handler (after OAM DMA)
- Both nametables pre-filled with ground tiles for seamless wrap

## NMI Handler

**Decision:** Minimal NMI handler with full register preservation.

**Register preservation:**
```asm
nmi:
    pha         ; Save A
    txa
    pha         ; Save X
    tya
    pha         ; Save Y
    ; ... handler code ...
    pla
    tay         ; Restore Y
    pla
    tax         ; Restore X
    pla         ; Restore A
    rti
```

**Why preserve all registers:**
- NMI can fire at any point during the game loop
- If game loop code is using X or Y when NMI fires, those values would be corrupted
- Critical for stability - prevents random glitchy behavior

**NMI responsibilities (in order):**
1. OAM DMA transfer (~513 cycles)
2. Set PPU_SCROLL (X and Y)
3. Set PPU_CTRL with nametable select
4. Signal main loop via `nmi_flag`

**Cycle budget:** ~560 cycles total (well under ~2273 VBlank budget)
