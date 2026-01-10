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
```

Output: `build/flappy.nes`

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
- [x] Ground collision — bird stops at ground (Y=192)

### Phase 3: Obstacles
- [x] Draw one static pipe — bottom pipe rising from ground
- [ ] Scroll pipe leftward — pipe moves, wraps when offscreen
- [ ] Pipe collision detection — game over on touch
- [ ] Multiple pipes — 2-3 pipes spaced apart, all scrolling

### Phase 4: Game Loop
- [ ] Add score counter — increment when passing pipe
- [ ] Display score on screen — numbers via sprites or background
- [ ] Game over state — freeze, show score, wait for restart
- [ ] Title screen — press Start to begin

### Phase 5: Polish
- [ ] Replace squares with real pixel art tiles
- [ ] Add animation frames — bird flapping, rotation on fall
- [ ] Add sound effects — flap, score, death
- [ ] Add music (optional)

## Dev Reference

See [DEVREF.md](DEVREF.md) for technical decisions and implementation details.

## License

MIT License - See [LICENSE](LICENSE)
