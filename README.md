# Flappy Bird for NES

A clone of the classic mobile game, written in 6502 assembly for the Nintendo Entertainment System.

## Building

```bash
# Install cc65 toolchain
sudo apt-get install cc65  # Debian/Ubuntu
brew install cc65          # macOS

# Build the ROM
make

# Build and run in emulator
make run

# Create distribution ROM (No-Intro naming convention)
make dist      # Flappy Paratroopa (World) (Unl).nes
make dist-ver  # Flappy Paratroopa (World) (Unl) (v1.0).nes
```

Output: `build/flappy.nes` (dev) or `build/Flappy Paratroopa (World) (Unl).nes` (dist)

## Development Plan

### Phase 1: Foundation
- [x] Basic NES setup — solid color background, proves toolchain works
- [x] Render static background — fill nametable with sky color
- [x] Draw a single sprite — a square for the bird, static
- [ ] ~~Move sprite with controller~~ (skipped - not needed for Flappy Bird)

### Phase 2: Core Mechanics
- [x] Implement gravity — bird falls automatically every frame (8.8 fixed-point)
- [x] Add flap mechanic — A/B button gives upward velocity (-4 px/frame)
- [x] Add ground — SMB-style 2x2 tile pattern with external CHR graphics
- [x] Ground collision — bird hits ground triggers game over (Y=192)

### Phase 3: Obstacles
- [x] Draw one static pipe pair — top and bottom pipes with 64px gap
- [x] Scroll pipe leftward — background scrolls, pipes redrawn on loop
- [x] Pipe collision detection — game over on touch, bird falls
- [x] Multiple pipes — 2 pipes spaced 128px apart, both scrolling

### Phase 4: Game Loop
- [x] Add score counter — increment when passing pipe (max 999)
- [x] Display score on screen — 3-digit sprite display centered at top
- [x] Game over state — dying state (falls), dead state (frozen)
- [ ] Title screen — press Start to begin

### Phase 5: Polish
- [x] Replace squares with real pixel art tiles — Koopa Paratroopa (2x3 sprites)
- [x] Add animation frames — wing flapping every 8 frames
- [x] Add sound effects — flap, score (coin), crash, ground hit
- [ ] Add music (optional)

## Dev Reference

See [DEVREF.md](DEVREF.md) for technical decisions and implementation details.

## License

MIT License - See [LICENSE](LICENSE)
