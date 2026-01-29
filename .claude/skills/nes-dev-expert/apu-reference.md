# APU Reference

## Pulse Channels ($4000-$4007)

**Pulse 1:** $4000-$4003 | **Pulse 2:** $4004-$4007

| Offset | Bits | Description |
|--------|------|-------------|
| +0 | DDLC VVVV | Duty, loop/halt, constant vol, volume |
| +1 | EPPP NSSS | Sweep enable, period, negate, shift |
| +2 | TTTT TTTT | Timer low |
| +3 | LLLL LTTT | Length load, timer high (resets phase) |

**Duty cycles:** 12.5% (0), 25% (1), 50% (2), 75% (3)

## Triangle Channel ($4008-$400B)

| Register | Bits | Description |
|----------|------|-------------|
| $4008 | CRRR RRRR | Control/halt, linear counter reload |
| $400A | TTTT TTTT | Timer low |
| $400B | LLLL LTTT | Length load, timer high |

## Noise Channel ($400C-$400F)

| Register | Bits | Description |
|----------|------|-------------|
| $400C | --LC VVVV | Loop/halt, constant vol, volume |
| $400E | M--- PPPP | Mode (short/long), period index |
| $400F | LLLL L--- | Length load |

## DMC Channel ($4010-$4013)

| Register | Bits | Description |
|----------|------|-------------|
| $4010 | IL-- RRRR | IRQ enable, loop, rate index |
| $4011 | -DDD DDDD | Direct 7-bit PCM output |
| $4012 | AAAA AAAA | Sample address: $C000 + (A × 64) |
| $4013 | LLLL LLLL | Sample length: (L × 16) + 1 bytes |

## Status ($4015)

**Write:** ---D NT21 (enable channels)
**Read:** IF-D NT21 (length status, DMC active, IRQ flags)

Reading clears frame IRQ flag (not DMC IRQ).

## Frame Counter ($4017)

```
MI-- ----
||
|+-------- IRQ inhibit
+--------- Mode (0: 4-step, 1: 5-step)
```

## APU Bugs

- **DMC length:** Reads 1 byte past sample end
- **Pulse sweep:** Asymmetric between channels
- **High timer write:** Resets phase, causes clicks

## Timing Issues

- **DPCM + controller:** DMA corrupts reads
- **DPCM + PPUDATA:** Can skip bytes during VRAM access
