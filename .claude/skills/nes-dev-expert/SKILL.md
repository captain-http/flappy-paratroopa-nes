---
name: nes-dev-expert
description: NES development skill. Use when programming NES games, working with PPU/APU registers, sprites, backgrounds, scrolling, mappers, or any NES hardware. Covers 2A03 CPU, PPU graphics, APU audio, input, memory maps, and timing.
disable-model-invocation: false
user-invocable: false
---

You are an NES development expert. Your knowledge is based on the authoritative NESDev wiki.

Reference: https://www.nesdev.org/wiki/NES_reference_guide

## System Overview

| Property | NTSC | PAL | Dendy |
|----------|------|-----|-------|
| CPU Clock | 1.789773 MHz | 1.662607 MHz | 1.773448 MHz |
| PPU dots/CPU cycle | 3 | 3.2 | 3 |
| Frame rate | 60.0988 Hz | 50.0070 Hz | 50.00 Hz |
| Scanlines/frame | 262 | 312 | 312 |
| VBlank scanlines | 20 | 70 | 51 |
| VBlank CPU cycles | ~2273 | ~7459 | ~7457 |

## CPU Memory Map

| Address | Size | Description |
|---------|------|-------------|
| $0000-$00FF | 256B | Zero Page |
| $0100-$01FF | 256B | Stack |
| $0200-$07FF | 1.5KB | RAM |
| $0800-$1FFF | 6KB | Mirrors of $0000-$07FF (x3) |
| $2000-$2007 | 8B | PPU Registers |
| $2008-$3FFF | 8KB | Mirrors of $2000-$2007 |
| $4000-$4017 | 24B | APU and I/O Registers |
| $4018-$401F | 8B | Disabled APU/IO |
| $4020-$5FFF | 8KB | Cartridge expansion |
| $6000-$7FFF | 8KB | PRG-RAM (battery save) |
| $8000-$FFFF | 32KB | PRG-ROM |

### Interrupt Vectors

| Address | Vector |
|---------|--------|
| $FFFA-$FFFB | NMI |
| $FFFC-$FFFD | Reset |
| $FFFE-$FFFF | IRQ/BRK |

## Additional Resources

For detailed information, see:

- [PPU Reference](ppu-reference.md) - PPU registers, memory map, timing, sprites, scrolling
- [APU Reference](apu-reference.md) - Audio registers, channels, sound programming
- [Patterns](patterns.md) - Initialization, game loop, scrolling, math techniques
- [Mappers](mappers.md) - NROM, UxROM, MMC1, MMC3 banking

## Quick Reference

### PPU Registers

| Register | Address | Access | Purpose |
|----------|---------|--------|---------|
| PPUCTRL | $2000 | W | NMI enable, sprite/BG pattern tables, VRAM increment |
| PPUMASK | $2001 | W | Rendering enable, emphasis, grayscale |
| PPUSTATUS | $2002 | R | VBlank flag, sprite 0 hit, overflow |
| OAMADDR | $2003 | W | OAM address |
| OAMDATA | $2004 | R/W | OAM data |
| PPUSCROLL | $2005 | W×2 | X/Y scroll position |
| PPUADDR | $2006 | W×2 | VRAM address |
| PPUDATA | $2007 | R/W | VRAM data |
| OAMDMA | $4014 | W | OAM DMA transfer |

### Controller Input

Button order (bits 7→0): A, B, Select, Start, Up, Down, Left, Right

```asm
    lda #$01
    sta $4016        ; Strobe on
    lsr a            ; A = 0
    sta $4016        ; Strobe off
    ldx #8
@loop:
    lda $4016        ; Read next button
    lsr a            ; Bit 0 -> Carry
    rol buttons      ; Carry -> buttons
    dex
    bne @loop
```

### VBlank Time Budget (NTSC)

| Operation | Cycles |
|-----------|--------|
| OAM DMA | 513-514 |
| Palette update | ~180 |
| Column update | ~300 |
| Remaining | ~1200 |

**Rule:** Keep NMI handler under 2000 cycles total.

## NES Limitations Summary

| Resource | Limit | Notes |
|----------|-------|-------|
| CPU RAM | 2KB | $0000-$07FF |
| Sprites | 64 total | 8 per scanline |
| BG Tiles | 256 | Per pattern table |
| Sprite Tiles | 256 | Per pattern table |
| Palettes | 4 BG + 4 sprite | 4 colors each |
| VBlank Time | ~2273 cycles | NTSC |
| Audio | 5 channels | 2 pulse, 1 tri, 1 noise, 1 DMC |
| PRG-ROM | 32KB max | Without mapper |
| CHR-ROM | 8KB max | Without mapper |
