# NES Mappers

## NROM (Mapper 0) - No banking

| Memory | Size | Description |
|--------|------|-------------|
| $8000-$BFFF | 16KB | PRG-ROM (or mirror of $C000) |
| $C000-$FFFF | 16KB | PRG-ROM |
| $0000-$1FFF | 8KB | CHR-ROM |

**Variants:**
- NROM-128: 16KB PRG (mirrored)
- NROM-256: 32KB PRG

## UxROM (Mapper 2) - PRG banking

| Memory | Description |
|--------|-------------|
| $8000-$BFFF | Switchable 16KB PRG bank |
| $C000-$FFFF | Fixed last 16KB PRG bank |

**Bank select:** Write bank number to $8000-$FFFF.

## MMC1 (Mapper 1) - Serial register

| Register | Address | Description |
|----------|---------|-------------|
| Control | $8000-$9FFF | Mirroring, PRG/CHR mode |
| CHR 0 | $A000-$BFFF | CHR bank 0 |
| CHR 1 | $C000-$DFFF | CHR bank 1 |
| PRG | $E000-$FFFF | PRG bank + RAM enable |

**Write:** 5 serial writes (bit 0), reset on bit 7 set.

## MMC3 (Mapper 4) - Scanline IRQ

| Register | Address | Description |
|----------|---------|-------------|
| Bank select | $8000 | Select bank register (R0-R7) |
| Bank data | $8001 | Bank number for selected register |
| Mirroring | $A000 | Bit 0: 0=vertical, 1=horizontal |
| PRG RAM | $A001 | Enable/write protect |
| IRQ latch | $C000 | Scanline counter reload value |
| IRQ reload | $C001 | Reload counter at next scanline |
| IRQ disable | $E000 | Disable IRQ, acknowledge |
| IRQ enable | $E001 | Enable IRQ |

**Banking:**
- R0-R1: 2KB CHR banks at $0000/$0800
- R2-R5: 1KB CHR banks at $1000-$1C00
- R6-R7: 8KB PRG banks

## iNES Header Format

| Byte | Content |
|------|---------|
| 0-3 | "NES" + $1A |
| 4 | PRG-ROM size (16KB units) |
| 5 | CHR-ROM size (8KB units, 0=CHR-RAM) |
| 6 | Flags 6 |
| 7 | Flags 7 |
| 8-15 | Extended flags (NES 2.0) or zero |

### Flags 6

```
NNNN FTBM
|||| ||||
|||| |||+- Mirroring (0: horizontal, 1: vertical)
|||| ||+-- Battery-backed PRG-RAM
|||| |+--- 512-byte trainer at $7000
|||| +---- Alternative nametable layout
++++------ Mapper low nibble
```

### Flags 7

```
NNNN xxPV
|||| ||||
|||| |||+- VS Unisystem
|||| ||+-- PlayChoice-10
|||| ++--- NES 2.0 identifier (if = 2)
++++------ Mapper high nibble
```
