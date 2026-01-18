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

**Key insight:** Redraw the nametable that just went OFF-screen, not the one becoming visible. This ensures pipes are ready before the nametable scrolls back into view (~2.1 seconds at 2px/frame).

**Eleven-Frame Redraw (Pipes + Clouds):**

Drawing a full pipe column requires ~2400 cycles (26 rows × ~92 cycles/row), which exceeds vblank. The gap position also varies, making top-half row count variable (4-23 rows). Solution: split each pipe into 4 parts, plus 3 frames for cloud regeneration.

```
Frame 0:  pipe 0 body+cap   → set pipe_redraw=1
Frame 1:  pipe 0 gap clear  → set pipe_redraw=2
Frame 2:  pipe 0 bottom     → set pipe_redraw=3
Frame 3:  pipe 0 attrs      → set pipe_redraw=4, next_pipe_gap
Frame 4:  pipe 1 body+cap   → set pipe_redraw=5
Frame 5:  pipe 1 gap clear  → set pipe_redraw=6
Frame 6:  pipe 1 bottom     → set pipe_redraw=7
Frame 7:  pipe 1 attrs      → set pipe_redraw=8, next_pipe_gap
Frame 8:  clear cloud zone A → set pipe_redraw=9
Frame 9:  clear cloud zone B → set pipe_redraw=10
Frame 10: draw random clouds → set pipe_redraw=$FF
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

## Bird Sprite: 16x24 (6 tiles) — Koopa Paratroopa

**Decision:** Use 6 tiles arranged 2x3 for the bird (Koopa Paratroopa from SMB).

```
┌───┬───┐
│$01│$02│  Top row (head/wings)
├───┼───┤
│$03│$04│  Middle row (shell)
├───┼───┤
│$05│$06│  Bottom row (feet)
└───┴───┘
```

**Animation frames (flying):**
- Frame 1: tiles $01-$06 (wings up)
- Frame 2: tiles $07-$0C (wings down)
- Toggles every 8 frames during `STATE_PLAYING`

**Shell sprite (2x2, death):**
```
┌───┬───┐
│$1A│$1B│  Top row
├───┼───┤
│$1C│$1D│  Bottom row (or $2A-$2B with feet)
└───┴───┘
```
- Used during `STATE_DYING` and `STATE_STUNNED`
- Top 2 sprites hidden (Y=$FF), shell uses middle/bottom sprite slots
- Feet animation: toggles bottom tiles between $1C/$1D and $2A/$2B every 10 frames

**Walking sprite (2x3, no wings):**
```
Frame 1: $1E-$23    Frame 2: $24-$29
┌───┬───┐           ┌───┬───┐
│$1E│$1F│           │$24│$25│
├───┼───┤           ├───┼───┤
│$20│$21│           │$26│$27│
├───┼───┤           ├───┼───┤
│$22│$23│           │$28│$29│
└───┴───┘           └───┴───┘
```
- Used during `STATE_WALK_OFF`
- Animation toggles every 8 frames
- Sprites hidden (Y=$FF) when X position wraps past screen edge

**Sprite palette 0:** `$22, $1A, $30, $27`
- $22: Light blue (transparent)
- $1A: Green (shell)
- $30: White (belly/face)
- $27: Orange (feet/details)

**X position:** 56-72 (centered at 1/4 screen width)
- NES screen width: 256 pixels
- Bird center: 64 pixels (256 ÷ 4)
- Left tiles: X=56, Right tiles: X=64

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
GROUND_Y  = 184   ; Bottom boundary (2x3 sprite sits on ground at row 26)
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

**Decision:** Six-state machine for game flow with animated death sequence.

**Variables:**
| Variable | Address | Description |
|----------|---------|-------------|
| game_state | $0A | Current state (0-5) |

**States:**
| State | Value | Behavior |
|-------|-------|----------|
| STATE_WAITING | 0 | Bird visible, "PRESS A OR B" text shown, waiting to start |
| STATE_PLAYING | 1 | Normal gameplay, input + physics + scrolling |
| STATE_DYING | 2 | Shell falls (no input, gravity only) |
| STATE_STUNNED | 3 | Shell on ground, feet animation, waiting to recover |
| STATE_WALK_OFF | 4 | Koopa walks left off screen |
| STATE_FADE_OUT | 5 | Palette fades to black, then full reset |

**Death Sequence:**
1. Pipe/ground collision → `STATE_DYING` (switch to shell, falls)
2. Shell hits ground → `STATE_STUNNED` (75 frames, feet peek animation)
3. Stun ends → `STATE_WALK_OFF` (switch to walking sprite, walk left)
4. Off screen → `STATE_FADE_OUT` (5-step palette fade)
5. Fully black → `jmp reset` (clean restart)

**Title Text:**
- "PRESS A OR B" displayed at PPU address $21CA during STATE_WAITING
- Uses alphabet tiles $20-$39 in background pattern table
- Cleared via `clear_title` flag when transitioning to STATE_PLAYING

**Pipe collision detection:**
- Check all 4 pipes (2 per nametable) based on scroll position
- Use per-nametable gap tracking for correct collision
- Skip NT0 collision checks until NT0 has been drawn (`nt0_has_pipes` flag)

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

**Rectangle Collision Detection:**

Bird and pipes are treated as axis-aligned rectangles:
```
Bird:        (56, bird_y) to (72, bird_y+16)  [16x16 pixels]
Top pipe:    (pipe_x, 0) to (pipe_x+32, gap_top_y)
Bottom pipe: (pipe_x, gap_top_y+64) to (pipe_x+32, ground)
```

**X Overlap Test:**
- Pipe overlaps bird if screen_x in [25, 72]
- Bird X range: 56-72, pipe width: 32px
- Formula: `BIRD_LEFT - PIPE_WIDTH + 1` to `BIRD_RIGHT - 1`

**Y Overlap Test (Rectangle-based):**
```
gap_top_y = gap_row × 8
gap_bottom_y = gap_top_y + 64

Bird safe if BOTH conditions met:
  1. bird_y >= gap_top_y        (bird top at or below gap top)
  2. bird_y + 16 <= gap_top_y + 64  (bird bottom at or above gap bottom)

Collision if EITHER:
  - bird_y < gap_top_y          → hit top pipe
  - bird_y > gap_top_y + 48     → hit bottom pipe (equivalent to bird_y+16 > gap_top_y+64)
```

This ensures the bird's entire 16px height must fit within the 64px gap.

## Scrolling

**Decision:** Horizontal scrolling at 2 pixels/frame when bird is flying.

**Variables:**
| Variable | Address | Description |
|----------|---------|-------------|
| scroll_x | $08 | X scroll position (0-255) |
| scroll_nt | $09 | Nametable select (0 or 1) |

**Speed:** 2 pixels/frame = 120 pixels/second (matches original Flappy Bird feel)

**Logic:**
- Bird on ground (Y = GROUND_Y): no scrolling
- Bird flying: scroll 2 pixels/frame
- When scroll_x wraps past 255, toggle scroll_nt

**Implementation:**
- Scroll updated in main game loop using `adc #2`
- Carry flag detects wrap (instead of `bne` with single increment)
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

## Scoring System

**Decision:** BCD score storage with sprite-based display, max 999.

**Variables:**
| Variable | Address | Description |
|----------|---------|-------------|
| score_ones | $19 | Ones digit (0-9) |
| score_tens | $1A | Tens digit (0-9) |
| score_hundreds | $1B | Hundreds digit (0-9) |
| pipes_scored | $1C | Bitmask preventing double-scoring |

**Score detection:**
- Score increments when pipe's right edge passes bird's left edge
- Uses `pipes_scored` bitmask (bits 0-3 for NT0P0, NT0P1, NT1P0, NT1P1)
- Bitmask resets when pipe scrolls off-screen and is redrawn

**Display (sprites):**
```
OAM+24: Hundreds digit at X=112, Y=16
OAM+28: Tens digit at X=120, Y=16
OAM+32: Ones digit at X=128, Y=16
```

**Digit tiles:** $10='0', $11='1', ... $19='9' (pattern table 0)

## Sound System

**Decision:** Use APU pulse and noise channels for sound effects.

**Channels used:**
- Pulse 1 ($4000-$4003): Flap sound, crash whistle
- Pulse 2 ($4004-$4007): Score/coin sound
- Noise ($400C-$400F): Crash and ground hit

**Sound effects:**
| Sound | Trigger | Implementation |
|-------|---------|----------------|
| Flap | A/B button while playing | Rising sweep on Pulse 1 (~250Hz start) |
| Score | Pass a pipe | Two-note coin (B5→E6) on Pulse 2 |
| Crash | Hit a pipe | Noise burst + falling whistle (Pulse 1 descending sweep) |
| Ground hit | Hit floor directly | Noise burst only |

**State machine (for coin sound):**
| State | Description |
|-------|-------------|
| 0 | Idle |
| 1 | Playing B5 (7 frames) |
| 2 | Playing E6 (14 frames) |

**Variables:**
| Variable | Address | Description |
|----------|---------|-------------|
| sound_timer | $1D | Frames until next sound state |
| sound_state | $1E | Current sound state |

**Frequency calculations:**
```
Timer = CPU_FREQ / (16 × freq) - 1
B5 (988 Hz) → timer $70
E6 (1318 Hz) → timer $54
```

## Death Sequence & Fade System

**Decision:** Animated death sequence with palette fade instead of instant game over.

**Death Sequence Variables:**
| Variable | Address | Description |
|----------|---------|-------------|
| bird_x | $20 | Bird X position (for walk-off) |
| fade_timer | $21 | Multi-purpose timer (stun delay, fade delay) |
| fade_step | $22 | Current fade level (0=normal, 4=black) |
| update_palette | $23 | Flag to update palette in NMI |
| clear_title | $1F | Flag to clear title text in NMI |

**Constants:**
```
STUN_DELAY      = 75    ; Frames before walking (~1.25 sec)
FADE_DELAY      = 15    ; Frames per fade step
STUN_ANIM_SPEED = 10    ; Frames between feet animation
WALK_ANIM_SPEED = 8     ; Frames between walk animation
```

**Fade Palette System:**

5-level fade from normal colors to black ($0F):
```
Level 0: Normal palette
Level 1: Darker
Level 2: Even darker
Level 3: Near black
Level 4: All $0F (black)
```

Fade palettes stored in `fade_palette_bg` and `fade_palette_spr` tables (5 × 16 bytes each).

**Sequence Flow:**
```
STATE_DYING:
  - Shell sprite falls with gravity
  - On ground hit → STATE_STUNNED

STATE_STUNNED:
  - fade_timer counts down from STUN_DELAY (75)
  - Feet animation toggles every STUN_ANIM_SPEED (10) frames
  - On timer expiry → STATE_WALK_OFF

STATE_WALK_OFF:
  - bird_x decrements each frame
  - Walk animation toggles every WALK_ANIM_SPEED (8) frames
  - Sprites hidden when bird_x >= $80 (off left edge)
  - When bird_x reaches $F0 → STATE_FADE_OUT

STATE_FADE_OUT:
  - fade_timer counts down from FADE_DELAY (15)
  - On expiry, increment fade_step and apply darker palette
  - When fade_step reaches 5 → jmp reset
```

**Why full reset:**
Using `jmp reset` instead of soft reset ensures clean state (pipes, nametables, variables) without visual glitches.

## Cloud System

**Decision:** Pattern-based randomized clouds that regenerate on nametable wrap.

**Cloud Tile Layout (Pattern Table 1, $1000):**
```
Tiles $3A-$42 (9 tiles total):
  Row 0 (bumps):  $00 $3A $3B $00  (corners empty, bumps in middle)
  Row 1 (body):   $3C $3D $3D $3E  (left edge, fill, right edge)
  Row 2 (bottom): $3F $40 $41 $42  (left edge, fill pair, right edge)
```

**Cloud Sizes:**
| Size | Width | Bump Pairs | Tile Pattern |
|------|-------|------------|--------------|
| Single | 4 tiles | 1 | $00 $3A $3B $00 |
| Double | 6 tiles | 2 | $00 $3A $3B $3A $3B $00 |
| Triple | 8 tiles | 3 | $00 $3A $3B $3A $3B $3A $3B $00 |

**Cloud Zones (avoiding pipe columns):**
- Zone A: columns 4-11 (before pipe 0 at column 0-3)
- Zone B: columns 20-27 (between pipe 0 and pipe 1 at column 16-19)

**Cloud Patterns (16 curated):**
```
Pattern 0:  Empty (no clouds)
Pattern 1:  Single high (zone A)
Pattern 2:  Single low (zone B)
Pattern 3:  Double mid (zone A)
Pattern 4:  Triple high (zone B)
Pattern 5:  Single + Single (different heights)
Pattern 6:  Single + Double
Pattern 7:  Double + Single
Pattern 8:  Triple + Single
Pattern 9:  Single + Triple
Pattern 10: Double + Double
Pattern 11: Single low (zone A) - variation
Pattern 12: Single high (zone B) - variation
Pattern 13: Double (zone B)
Pattern 14: Triple (zone A)
Pattern 15: Single + Single (both high)
```

**Pattern Data Format (6 bytes each):**
```
col1, size1, row1, col2, size2, row2
- col = 0: no cloud
- col = 4-11: zone A
- col = 20-27: zone B
- size = 0/1/2: single/double/triple
- row = 2-8: CLOUD_ROW_MIN to CLOUD_ROW_MAX
```

**Cloud Variables (Zero Page):**
| Variable | Address | Description |
|----------|---------|-------------|
| cloud_col | $24 | Current cloud column |
| cloud_row | $25 | Current cloud row |
| cloud_size | $26 | Current cloud size (0-2) |
| cloud_temp | $27 | Temporary variable |

**Palette 3 (Clouds):**
```
$22: Sky blue (color 0, transparent)
$30: White (cloud body)
$21: Cyan (cloud shading)
$0F: Black (outline)
```

**Sky Attribute Prefill:**

At init, entire sky area (attr rows 0-5) is set to palette 3 ($FF = all quadrants). This ensures:
- Empty sky tiles still appear as sky blue (color 0)
- All clouds automatically use correct palette
- No per-cloud attribute management needed
- Pipe drawing overwrites columns 0 and 4 with pipe palette

**Cloud Regeneration on Scroll:**

Clouds regenerate when nametables wrap, integrated into pipe redraw state machine:
```
Frame 0-7:  Pipe drawing (existing)
Frame 8:    Clear cloud zone A (8 cols × 9 rows)
Frame 9:    Clear cloud zone B (8 cols × 9 rows)
Frame 10:   Draw new random cloud pattern
Frame 11:   Done ($FF)
```

**Clearing Algorithm:**
- Write $00 (empty tile) to columns 4-11 and 20-27
- Rows 2-10 (CLOUD_ROW_MIN to CLOUD_ROW_MAX+2)
- 72 tiles per zone, split across 2 frames

**Pattern Selection:**
```asm
jsr rand_lfsr
lda rng_hi            ; Use high byte for better entropy
and #$0F              ; 0-15 (16 patterns)
; Multiply by 6 to get pattern offset
```

**Title Text Consideration:**

"PRESS A OR B" text uses background tiles in sky area, which now uses palette 3. Alphabet tiles ($20-$39) should be drawn with palette 3 colors (white for visibility against sky blue).
