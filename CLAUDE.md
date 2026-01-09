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
nes.cfg       # Linker config (NROM-256)
build/        # Output directory
```

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
