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
nam/          # Background nametable data (.nam binary files)
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

### Title Screen

The title screen features:
- Fade-in from black on boot
- Paratroopa flies across screen with gravity/flap physics
- "FLAPPY PARATROOPA 2026" title text
- "PRESS START" prompt
- TOP score display (hi-score from SRAM)

Press START to transition to the waiting screen ("PRESS A OR B TO FLAP!").

### Shell Color Easter Egg

Press SELECT on the title or waiting screen to cycle through 16 shell colors:

| # | Value | Color |
|---|-------|-------|
| 1 | $1A | Green (default) |
| 2 | $16 | Red |
| 3 | $02 | Dark Blue |
| 4 | $14 | Purple |
| 5 | $0F | Black |
| 6 | $17 | Brown |
| 7 | $0A | Dark Green |
| 8 | $06 | Dark Red/Maroon |
| 9 | $1C | Dark Cyan |
| 10 | $04 | Dark Purple |
| 11 | $00 | Dark Gray |
| 12 | $12 | Medium Blue |
| 13 | $07 | Dark Brown |
| 14 | $2A | Bright Green |
| 15 | $1B | Teal |
| 16 | $0C | Dark Teal |

Shell color is saved to SRAM immediately on change and persists across power cycles.

**Variables:**
- `turtle_color` ($3E) - Current shell color index (0-15)
- `shell_color_dirty` ($3F) - Flag to update palette in NMI

**Key subroutines:**
- `cycle_shell_color` - Increment color and save to SRAM
- `update_shell_color` - Write color to PPU palette

### Death Sequence

When the Koopa dies, it goes through a multi-state animation:

1. **Shell** (`STATE_DYING`/`STATE_STUNNED`): Hides in shell, falls to ground
2. **Stunned**: Feet peek out animation (toggles every 10 frames)
3. **Walk Off** (`STATE_WALK_OFF`): Walks left off screen
4. **Fade Out** (`STATE_FADE_OUT`): Palette fades to black
5. **Game Over** (`STATE_GAME_OVER`): Results screen, press START to restart

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

### Game Over Screen

After fade-out, displays results on a black background with white text:

**Normal game:**
```
GAME OVER
SCORE XXX
BEST XXX
NICE TRY!
PRESS START!
```

**New high score:**
```
GAME OVER
SCORE XXX
NEW RECORD!
SHARE IT!
#FLAPPYPARATROOPA
PRESS START!
```

**Tiles used:**
- Alphabet: `$20`-`$39` (A=`$20`, B=`$21`, ...)
- Background digits: `$50`-`$59` (0=`$50`, 1=`$51`, ...)
- Special: `!`=`$48`, `#`=`$49`

**Key subroutine:**
- `show_game_over_screen` - Clears nametable, draws text, enables BG rendering

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

## SRAM Persistence

Hi-score and shell color are saved to battery-backed SRAM at $6000-$6006:

| Address | Variable | Description |
|---------|----------|-------------|
| $6000 | `SRAM_MAGIC_1` | Magic byte 1 ($F1) |
| $6001 | `SRAM_MAGIC_2` | Magic byte 2 ($AB) |
| $6002 | `SRAM_HISCORE_H` | Hundreds digit |
| $6003 | `SRAM_HISCORE_T` | Tens digit |
| $6004 | `SRAM_HISCORE_O` | Ones digit |
| $6005 | `SRAM_SHELL_CLR` | Shell color index (0-15) |
| $6006 | `SRAM_CHECKSUM` | Checksum: (H+T+O+shell) XOR $55 |

Data is validated on load via magic bytes and checksum. Invalid data resets to defaults (score=000, green shell).

## Sound System

Uses NES APU channels for sound effects:

| Sound | Trigger | Channel | Description |
|-------|---------|---------|-------------|
| Flap | Press A/B while playing | Pulse 1 | Rising sweep (~250Hz start) |
| Score | Pass a pipe | Pulse 2 | Mario-style coin (B5 → E6) |
| Crash | Hit a pipe | Noise + Pulse 1 | Noise burst + falling whistle |
| Ground hit | Hit floor directly | Noise | Noise burst only |
| Game Over Melody | Turtle lands on floor | Pulse 1 + 2 | Koji Kondo style harmonized melody |
| Firework | New record celebration | Pulse 2 + Noise | "pu pum pum-pssss" explosion |

### Sound Variables (Zero Page)

| Address | Variable | Purpose |
|---------|----------|---------|
| $1D | `sound_timer` | Frames until next sound state |
| $1E | `sound_state` | State machine (0=idle, 1-2=coin sound) |
| $3A | `fw_sound_state` | Firework sound state (0=idle, 1-5=explosion) |
| $3B | `fw_sound_timer` | Firework sound timer |
| $3C | `go_melody_idx` | Game over melody note index ($FF=idle) |
| $3D | `go_melody_timer` | Game over melody timer |

### Game Over Melody

Koji Kondo style two-channel harmonized melody plays when turtle lands on floor (both high score and regular deaths):
- A4+E4 (minor opening) → E4+A3 (echo) → F4+D4, E4+C4 (sighing descent) → D4+B3, C4+A3 (resolution)
- Uses Pulse 1 (melody) + Pulse 2 (harmony)

### Firework Sound

Drum-style explosion: "pu pum pum-pssss"
- "pu" - quick hit + noise pop
- "pum" - deeper hit (noise silent)
- "pum" - deepest hit + crash starts
- "pssss" - crash trails off

### APU Registers Used

- `SQ1_VOL`, `SQ1_SWEEP`, `SQ1_LO`, `SQ1_HI` - Flap, crash whistle, game over melody
- `SQ2_VOL`, `SQ2_SWEEP`, `SQ2_LO`, `SQ2_HI` - Coin/score, melody harmony, firework
- `NOISE_VOL`, `NOISE_LO`, `NOISE_HI` - Crash, ground hit, firework explosion

## Firework System

SMB-style fireworks celebrate new high scores on the game over screen.

### Firework Variables (Zero Page)

| Address | Variable | Purpose |
|---------|----------|---------|
| $35 | `fw_timer` | Animation frame timer |
| $36 | `fw_frame` | Current frame (0, 1, 2) |
| $37 | `fw_current` | Current position index (0-3) |
| $38 | `fw_wait` | Wait timer between fireworks |

### Firework Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `FW_ANIM_SPEED` | 8 | Frames between animation updates |
| `FW_WAIT_TIME` | 30 | Frames to wait between fireworks |
| `FW_NUM_POSITIONS` | 4 | Number of firework positions |
| `FW_OAM` | 56 | OAM buffer offset for firework sprites |

### Firework Tiles (2x2 sprites)

| Frame | Top-Left Tile | Description |
|-------|---------------|-------------|
| 0 | $4A | Small burst |
| 1 | $4C | Medium burst |
| 2 | $4E | Large burst |

### Firework Positions

4 positions symmetric around game over text, cycles through 2 rounds (8 total fireworks) then stops.

### Key Subroutines

- `setup_firework_sprite` - Position sprites and play explosion sound
- `update_firework_tiles` - Update tiles for current animation frame
- `update_fireworks` - Main animation update (called each frame)
- `hide_fireworks` - Hide firework sprites
- `play_firework_sound` - Start explosion sound effect

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

## Background System

Backgrounds are stored as binary `.nam` files in the `nam/` directory (960 bytes each, no attribute data).

| File | Contents |
|------|----------|
| `bg0.nam` | Initial empty sky |
| `bg1.nam` | Sky with hill and bush |
| `bg2.nam` | Sky with single cloud |
| `bg3.nam` | Sky with two clouds |

Backgrounds cycle as the game scrolls. Each nametable (256 pixels) loads a new background when it wraps.

### Title Text

On the title screen, "PRESS A OR B" / "TO PLAY!" displays using palette 3 (white text).
The attribute at `$23DC` is temporarily set to `$FF` for palette 3, then restored to `$AA` when NT0 wraps during gameplay.

## Agents & Skills

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

### NES Dev Skill

The `nes-dev-expert` skill (`.claude/skills/nes-dev-expert/`) includes reference docs:
- `ppu-reference.md` - PPU registers, pattern tables, attributes, OAM
- `apu-reference.md` - APU channels and registers
- `patterns.md` - Common NES code patterns
- `mappers.md` - NROM, UxROM, MMC1, MMC3 mapper info
