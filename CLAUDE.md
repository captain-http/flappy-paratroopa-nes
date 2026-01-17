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
