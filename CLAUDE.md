# CLAUDE.md

## Project Overview

**Flappy Bird for NES** - Written in 6502 assembly using the cc65 toolchain.

## Build

```bash
make          # Build ROM (build/flappy.nes)
make run      # Build and run in emulator
make clean    # Clean build artifacts
```

## Structure

```
src/          # Assembly source and includes
chr/          # CHR graphics data
scripts/      # FCEUX Lua debug scripts
nes.cfg       # Linker config (NROM-256)
build/        # Output directory
```

## Sprite System

The player character is a Koopa Paratroopa using a 2x3 sprite arrangement (16x24 pixels, 6 hardware sprites).

### Tile Layout (Sprite Pattern Table $0000)

| Frame 1 | Frame 2 | Position |
|---------|---------|----------|
| $01 $02 | $07 $08 | Top |
| $03 $04 | $09 $0A | Middle |
| $05 $06 | $0B $0C | Bottom |

### Palette (Sprite Palette 0 at $3F10)

| Index | Value | Color |
|-------|-------|-------|
| 0 | $22 | Light blue (sky/transparent) |
| 1 | $1A | Green (shell) |
| 2 | $30 | White (belly/face) |
| 3 | $27 | Orange (feet/details) |

### Animation

Wing flapping animation runs during `STATE_PLAYING`:
- `anim_timer` increments each frame
- Every `ANIM_SPEED` (8) frames, `anim_frame` toggles between 0 and 6
- Sprite tile indices = base tile ($01-$06) + `anim_frame` offset

### Death Sequence

When the Koopa dies, it goes through a multi-state animation:

1. **Shell** (`STATE_DYING`/`STATE_STUNNED`): Hides in shell, falls to ground
2. **Stunned**: Feet peek out animation (toggles every 10 frames)
3. **Walk Off** (`STATE_WALK_OFF`): Walks left off screen
4. **Fade Out** (`STATE_FADE_OUT`): Palette fades to black, then full reset

**Shell Tiles (2x2):**

| Tile | Position |
|------|----------|
| $1A $1B | Top |
| $1C $1D | Bottom (or $2A $2B with feet) |

**Walking Tiles (2x3):**

| Frame 1 | Frame 2 | Position |
|---------|---------|----------|
| $1E $1F | $24 $25 | Top |
| $20 $21 | $26 $27 | Middle |
| $22 $23 | $28 $29 | Bottom |

**Key subroutines:**
- `switch_to_shell` - Transition to shell sprite
- `switch_to_walking` - Transition to walking sprite
- `apply_fade_palette` - Apply current fade level

## Scoring System

Score increments when the bird passes a pipe (pipe's right edge passes bird's left edge).

### Score Display (Sprites)

3 sprites display the score (max 999), centered at top of screen:

| OAM Offset | Digit | X Position |
|------------|-------|------------|
| +24 | Hundreds | 112 |
| +28 | Tens | 120 |
| +32 | Ones | 128 |

Digit tiles: `$10` = '0', `$11` = '1', ... `$19` = '9'

### Score Variables (Zero Page)

| Address | Variable | Purpose |
|---------|----------|---------|
| $19 | `score_ones` | Ones digit (0-9) |
| $1A | `score_tens` | Tens digit (0-9) |
| $1B | `score_hundreds` | Hundreds digit (0-9) |
| $1C | `pipes_scored` | Bitmask preventing double-scoring |

### Debug Script

`scripts/score_display.lua` - FCEUX Lua script that overlays score and game state for debugging.

## Sound System

Uses NES APU channels for sound effects:

| Sound | Trigger | Channel | Description |
|-------|---------|---------|-------------|
| Flap | Press A/B while playing | Pulse 1 | Rising sweep (~250Hz start) |
| Score | Pass a pipe | Pulse 2 | Mario-style coin (B5 → E6) |
| Crash | Hit a pipe | Noise + Pulse 1 | Noise burst + falling whistle |
| Ground hit | Hit floor directly | Noise | Noise burst only |

### Sound Variables (Zero Page)

| Address | Variable | Purpose |
|---------|----------|---------|
| $1D | `sound_timer` | Frames until next sound state |
| $1E | `sound_state` | State machine (0=idle, 1-2=coin sound) |

### APU Registers Used

- `SQ1_VOL`, `SQ1_SWEEP`, `SQ1_LO`, `SQ1_HI` - Flap and crash whistle
- `SQ2_VOL`, `SQ2_LO`, `SQ2_HI` - Coin/score sound
- `NOISE_VOL`, `NOISE_LO`, `NOISE_HI` - Crash and ground hit

## Cloud System

SMB-style clouds using pattern-based randomization. Clouds regenerate each time a nametable wraps.

### Cloud Tiles (Background Pattern Table $1000)

| Tile | Description |
|------|-------------|
| $3A-$3B | Top bumps |
| $3C-$3E | Middle body (left edge, fill, right edge) |
| $3F-$42 | Bottom (left edge, fill pair, right edge) |

### Cloud Sizes

| Size | Width | Tiles |
|------|-------|-------|
| Single | 4 tiles | 1 bump pair |
| Double | 6 tiles | 2 bump pairs |
| Triple | 8 tiles | 3 bump pairs |

### Cloud Patterns

16 curated patterns randomly selected per nametable:
- Empty (no clouds)
- Single/Double/Triple alone (various positions)
- Two-cloud combinations (Single+Single, Single+Double, etc.)

### Cloud Zones (safe columns avoiding pipes)

| Zone | Columns | Description |
|------|---------|-------------|
| Zone A | 4-11 | Left side, before pipe 0 |
| Zone B | 20-27 | Right side, after pipe 0 |

### Palette 3 (Clouds)

| Index | Value | Color |
|-------|-------|-------|
| 0 | $22 | Sky blue (transparent) |
| 1 | $30 | White (cloud body) |
| 2 | $21 | Cyan (shading) |
| 3 | $0F | Black (outline) |

Sky area (attr rows 0-5) prefilled with palette 3 at init. Title text tiles should use palette 3 colors.

## Agents

Use these agents for NES development tasks:

| Agent | When to Use |
|-------|-------------|
| `6502-asm-expert` | Writing/reviewing 6502 assembly, opcodes, addressing modes, cycle counting |
| `ca65-expert` | Assembler syntax, macros, segments, directives |
| `ld65-expert` | Linker config, memory layout, segment placement |
| `nes-dev-expert` | PPU, APU, sprites, backgrounds, scrolling, NES hardware |

**Invoke proactively** when:
- Any NES development task → `nes-dev-expert` (primary agent)
- Writing/optimizing 6502 code → `6502-asm-expert`
- Assembler syntax issues → `ca65-expert`
- Linker/memory issues → `ld65-expert`
