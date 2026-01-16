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

**Decision:** Redraw pipes dynamically when the off-screen nametable needs to be prepared, split across eight frames to fit within vblank.

**Variables:**
| Variable | Address | Description |
|----------|---------|-------------|
| pipe_redraw | $0B | Redraw state: 0-7=active frame, $FF=none |
| nt_base | $0C | Nametable base ($20=NT0, $24=NT1) |
| pipe_col | $0D | Current pipe column (0 or 16) |
| pipe_gap | $0E | Gap start row (random, GAP_MIN to GAP_MAX) |
| pipe0_drawn_gap | $0F | Temp storage for collision Y check |
| rng_lo | $10 | LFSR low byte |
| rng_hi | $11 | LFSR high byte |
| nt0_pipe0_gap | $12 | NT0 pipe 0 gap row |
| nt0_pipe1_gap | $13 | NT0 pipe 1 gap row |
| nt1_pipe0_gap | $14 | NT1 pipe 0 gap row |
| nt1_pipe1_gap | $15 | NT1 pipe 1 gap row |
| nt0_has_pipes | $16 | 0 = NT0 empty, 1 = NT0 has pipes |

**Mechanism:**
1. Initial state: NT0 empty, NT1 has both pipes
2. When scroll_x wraps (255→0), toggle scroll_nt
3. When switching TO NT1: NT0 just scrolled off-screen, queue NT0 redraw
4. When switching TO NT0: NT1 just scrolled off-screen, queue NT1 redraw
5. NMI handler checks pipe_redraw and calls draw_pipes_in_nt if needed

**Key insight:** Redraw the nametable that just went OFF-screen, not the one becoming visible. This ensures pipes are ready before the nametable scrolls back into view (~4.3 seconds at 1px/frame).

**Eight-Frame Redraw:**

Drawing a full pipe column requires ~2400 cycles (26 rows × ~92 cycles/row), which exceeds vblank. The gap position also varies, making top-half row count variable (4-23 rows). Solution: split each pipe into 4 parts across 8 total frames.

```
Frame 0: pipe 0 body+cap   → set pipe_redraw=1
Frame 1: pipe 0 gap clear  → set pipe_redraw=2
Frame 2: pipe 0 bottom     → set pipe_redraw=3
Frame 3: pipe 0 attrs      → set pipe_redraw=4, next_pipe_gap
Frame 4: pipe 1 body+cap   → set pipe_redraw=5
Frame 5: pipe 1 gap clear  → set pipe_redraw=6
Frame 6: pipe 1 bottom     → set pipe_redraw=7
Frame 7: pipe 1 attrs      → set pipe_redraw=$FF, next_pipe_gap
```

| Frame | What | Max Rows | Max Cycles |
|-------|------|----------|------------|
| 0, 4 | Body + cap | 15 | ~1275 |
| 1, 5 | Gap clear | 8 | ~680 |
| 2, 6 | Bottom (cap + body) | 14 | ~1190 |
| 3, 7 | Attributes | 7 bytes | ~170 |

All frames fit comfortably within the ~1700 cycle budget (after OAM DMA + overhead).

**Gap Clearing:**

When redrawing pipes with different gap positions, old tiles from the previous pipe remain visible. The gap area (8 rows) is explicitly cleared with empty tiles ($00) to prevent visual artifacts.

**Timing:**
```
NT0 visible → scroll 256px → switch to NT1 → queue NT0 redraw
  NMI frames 0-7: redraw both pipes in NT0
NT1 visible → scroll 256px → switch to NT0 → queue NT1 redraw
  NMI frames 0-7: redraw both pipes in NT1
... continues seamlessly, alternating nametables
```

**Cycle Budget:**
```
VBlank total:       ~2273 cycles
OAM DMA:            - 513 cycles
NMI overhead:       - 60 cycles
Available:          ~1700 cycles
Worst frame (body): ~1275 cycles  ✓ fits with margin
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
- Check all 4 pipes (2 per nametable) based on scroll position
- Use per-nametable gap tracking for correct collision
- Skip NT0 collision checks until NT0 has been drawn (`nt0_has_pipes` flag)

**Future:** Press Start to reset game.

## Random Pipe Heights

**Decision:** Use 16-bit Galois LFSR for pseudo-random pipe gap positions.

**LFSR Implementation:**
```
Polynomial: $B400 (taps at bits 16, 14, 13, 11)
Period: 65535 (maximal length)
Seed: $A501 (arbitrary non-zero)
```

**Algorithm:**
```asm
rand_lfsr:
    lda rng_lo
    lsr a                 ; Shift right, bit 0 -> carry
    ror rng_hi            ; Rotate high byte
    ror rng_lo            ; Rotate low byte
    bcc @no_tap           ; If carry clear, skip XOR
    lda rng_hi
    eor #$B4              ; Apply taps
    sta rng_hi
@no_tap:
    rts
```

**Gap Range Mapping:**
```asm
    lda rng_lo
    eor rng_hi            ; Mix bytes for better distribution
    and #$0F              ; 0-15
    ; Map to GAP_MIN..GAP_MAX (4-15)
    ; Values 12-15 wrap to 4-7
```

**Entropy Source:**
- LFSR runs every frame during STATE_WAITING
- Player's timing to press start determines initial LFSR state
- Each game has different random sequence based on wait time

**Cycle Cost:** ~50 cycles per call (negligible for vblank)

## Per-Nametable Collision Detection

**Decision:** Track gap values separately for each pipe in each nametable.

**Why needed:**
- Both nametables have pipes after first scroll loop
- Single gap variable would be overwritten on each redraw
- Collision must check the correct gap for the visible pipe

**Variables:**
| Variable | Description |
|----------|-------------|
| nt0_pipe0_gap | NT0 pipe at column 0 |
| nt0_pipe1_gap | NT0 pipe at column 16 |
| nt1_pipe0_gap | NT1 pipe at column 0 |
| nt1_pipe1_gap | NT1 pipe at column 16 |
| nt0_has_pipes | Skip NT0 collision until drawn |

**Collision Check Order:**
```
When scroll_nt = 0 (viewing NT0):
  1. Check NT0 pipe 1 (screen_x = 128 - scroll_x)
  2. Check NT1 pipe 0 (screen_x = 256 - scroll_x)

When scroll_nt = 1 (viewing NT1):
  1. Check NT1 pipe 1 (screen_x = 128 - scroll_x)
  2. Check NT0 pipe 0 (screen_x = 256 - scroll_x)
```

**X Overlap Test:**
- Pipe overlaps bird if screen_x in [25, 72]
- Bird X range: 56-72, pipe width: 32px

**Y Overlap Test:**
- gap_top_y = gap_row × 8
- gap_bottom_y = gap_top_y + 64
- Collision if bird_y < gap_top_y OR bird_y > gap_bottom_y - 16

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
2. Pipe redraw if queued (0-1275 cycles depending on frame)
3. Set PPU_SCROLL (X and Y)
4. Set PPU_CTRL with nametable select
5. Signal main loop via `nmi_flag`

**Cycle budget:** Variable based on pipe redraw state:
- No redraw: ~560 cycles
- Worst case (body+cap frame): ~1850 cycles
- All within ~2273 VBlank budget
