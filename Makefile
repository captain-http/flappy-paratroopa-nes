# Flappy Bird for NES - Build System

# Project name
PROJECT = flappy

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

# Output ROM
ROM = $(BUILD_DIR)/$(PROJECT).nes

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

# Debug build with symbols
.PHONY: debug
debug: LDFLAGS += --dbgfile $(BUILD_DIR)/$(PROJECT).dbg
debug: all
	@echo "Debug info written to $(BUILD_DIR)/$(PROJECT).dbg"

# Show build info
.PHONY: info
info:
	@echo "Project: $(PROJECT)"
	@echo "Output: $(ROM)"
	@echo "Sources: $(SOURCES)"

# Help
.PHONY: help
help:
	@echo "Flappy Bird NES - Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all     - Build the ROM (default)"
	@echo "  clean   - Remove build artifacts"
	@echo "  run     - Build and run in emulator"
	@echo "  debug   - Build with debug symbols"
	@echo "  info    - Show build information"
	@echo "  help    - Show this help"
	@echo ""
	@echo "Requirements: cc65 toolchain (ca65, ld65)"

.PHONY: rebuild
rebuild: clean all
