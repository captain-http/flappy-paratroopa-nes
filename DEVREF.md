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
