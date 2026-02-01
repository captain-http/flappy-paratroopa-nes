# Flappy Paratroopa

**You've stomped hundreds of them. Now be one.**

A Koopa Paratroopa escapes World 1-1 and finds itself in a familiar nightmare: endless pipes, one-hit deaths, and the cruel pull of gravity. Flap to survive. How far can you go?

This isn't a demake or a ROM hack—it's a brand new NES game, handcrafted in 6502 assembly and playable on real hardware.

## What Makes It Special

- **Your Koopa has personality.** Die and watch it retreat into its shell, peek out nervously, then waddle off-screen in shame.
- **Beat your high score? Fireworks.** You earned them.
- **Battery-backed saves.** Your best score is waiting for you next time.
- **Sounds like the real deal.** Crisp flap sounds, coin chimes, and a melancholy game over tune that wouldn't feel out of place in a first-party Nintendo game.
- **Poke around the title screen.** Not all Koopas are green...

## Controls

| Button | Action |
|--------|--------|
| A / B | Flap |
| START | Play |
| SELECT | ????? |

## Runs On

- Real NES/Famicom (via flashcart)
- Any NES emulator (Mesen, FCEUX, RetroArch, etc.)

One ROM. No compromises. Pure 8-bit.

## Download

Grab the ROM from the [Releases](../../releases) section—it's free!

If you enjoy the game, consider supporting the project on **[itch.io](https://captain-http.itch.io/flappy-paratroopa-nes)** where donations are welcome.

## Building From Source

Requires the [cc65](https://cc65.github.io/) toolchain.

```bash
# Install cc65
sudo apt-get install cc65  # Debian/Ubuntu
brew install cc65          # macOS

# Build the ROM
make

# Build and run in emulator
make run
```

Output: `build/flappy.nes`

## Technical Details

| | |
|-|-|
| Mapper | NROM-256 |
| PRG ROM | 32 KB |
| CHR ROM | 8 KB |
| SRAM | Battery-backed |

See [CLAUDE.md](CLAUDE.md) for the full technical breakdown—sprite layouts, memory maps, sound engine details, and more.

## Credits

Built by a human and an AI, pair-programming late into the night. [Claude Code](https://claude.ai/code) (Anthropic's AI coding agent) wrote the 6502 assembly and documentation. The human brought the vision, direction, and the patience to fix the cursed bugs we created together.

## License

**Code:** MIT License - See [LICENSE](LICENSE)

**Art/Characters:** The Koopa Paratroopa, pipes, and other visual elements are Nintendo's intellectual property. This is a fan project made for fun and education, not for profit.
