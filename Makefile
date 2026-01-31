# Flappy Paratroopa for NES - Build System

# Project info
PROJECT = flappy
GAME_NAME = Flappy Paratroopa
VERSION = v1.0

# ROM filename following No-Intro naming convention:
# Game Name (Region) (Unl) (Version).nes
# - (World) = works on all regions (NTSC/PAL)
# - (Unl) = Unlicensed/homebrew
REGION = World
ROM_NAME = $(GAME_NAME) ($(REGION)) (Unl)

# Assembler and linker (cc65 toolchain)
AS = ca65
LD = ld65

# Flags
ASFLAGS = -t nes -g -I $(SRC_DIR)
LDFLAGS = -C nes.cfg

# Directories
SRC_DIR = src
BUILD_DIR = build

# Source files (main.asm includes all others)
SOURCES = $(SRC_DIR)/main.asm

# Object files
OBJECTS = $(patsubst $(SRC_DIR)/%.asm,$(BUILD_DIR)/%.o,$(SOURCES))

# Output ROM (internal name for build, final name for distribution)
ROM = $(BUILD_DIR)/$(PROJECT).nes
ROM_DIST = $(BUILD_DIR)/$(ROM_NAME).nes

# Default target
.PHONY: all
all: directories $(ROM)

# Create build directory
.PHONY: directories
directories:
	@mkdir -p $(BUILD_DIR)

# Link object files to create ROM
$(ROM): $(OBJECTS) nes.cfg
	@echo "Linking $(ROM)..."
	$(LD) $(LDFLAGS) -o $@ $(OBJECTS)
	@echo "Build complete: $(ROM)"
	@ls -lh $(ROM)

# Assemble source files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.asm
	@echo "Assembling $<..."
	$(AS) $(ASFLAGS) -o $@ $<

# Clean build artifacts
.PHONY: clean
clean:
	@echo "Cleaning build directory..."
	rm -rf $(BUILD_DIR)/*
	@echo "Clean complete."

# Run in emulator
.PHONY: run
run: all
	@if command -v fceux >/dev/null 2>&1; then \
		fceux $(ROM); \
	elif command -v mesen >/dev/null 2>&1; then \
		mesen $(ROM); \
	elif command -v nestopia >/dev/null 2>&1; then \
		nestopia $(ROM); \
	else \
		echo "No NES emulator found. Install fceux, mesen, or nestopia."; \
		echo "ROM available at: $(ROM)"; \
	fi

# Distribution build with proper naming convention
.PHONY: dist
dist: all
	@cp "$(ROM)" "$(ROM_DIST)"
	@echo "Distribution ROM created:"
	@ls -lh "$(ROM_DIST)"

# Versioned distribution (includes version tag)
ROM_DIST_VER = $(BUILD_DIR)/$(GAME_NAME) ($(REGION)) (Unl) ($(VERSION)).nes

.PHONY: dist-ver
dist-ver: all
	@cp "$(ROM)" "$(ROM_DIST_VER)"
	@echo "Versioned distribution ROM created:"
	@ls -lh "$(ROM_DIST_VER)"

# Debug build with symbols
.PHONY: debug
debug: LDFLAGS += --dbgfile $(BUILD_DIR)/$(PROJECT).dbg
debug: all
	@echo "Debug info written to $(BUILD_DIR)/$(PROJECT).dbg"

# Show build info
.PHONY: info
info:
	@echo "Project: $(PROJECT)"
	@echo "Game: $(GAME_NAME)"
	@echo "Version: $(VERSION)"
	@echo "Build ROM: $(ROM)"
	@echo "Dist ROM: $(ROM_NAME).nes"
	@echo "Sources: $(SOURCES)"

# Help
.PHONY: help
help:
	@echo "Flappy Paratroopa NES - Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all      - Build the ROM (default)"
	@echo "  dist     - Build ROM with No-Intro naming: $(ROM_NAME).nes"
	@echo "  dist-ver - Build ROM with version tag included"
	@echo "  clean    - Remove build artifacts"
	@echo "  run      - Build and run in emulator"
	@echo "  debug    - Build with debug symbols"
	@echo "  info     - Show build information"
	@echo "  help     - Show this help"
	@echo ""
	@echo "Requirements: cc65 toolchain (ca65, ld65)"

.PHONY: rebuild
rebuild: clean all
