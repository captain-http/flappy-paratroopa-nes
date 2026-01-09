; NES Hardware Definitions
; Memory-mapped I/O registers and system constants

;===============================================================================
; PPU (Picture Processing Unit) Registers
;===============================================================================
PPU_CTRL    = $2000  ; PPU Control Register 1
PPU_MASK    = $2001  ; PPU Control Register 2
PPU_STATUS  = $2002  ; PPU Status Register
OAM_ADDR    = $2003  ; OAM Address Register
OAM_DATA    = $2004  ; OAM Data Register
PPU_SCROLL  = $2005  ; PPU Scroll Register
PPU_ADDR    = $2006  ; PPU Address Register
PPU_DATA    = $2007  ; PPU Data Register

;===============================================================================
; APU (Audio Processing Unit) and I/O Registers
;===============================================================================
SQ1_VOL     = $4000  ; Square 1 Volume
SQ1_SWEEP   = $4001  ; Square 1 Sweep
SQ1_LO      = $4002  ; Square 1 Low Frequency
SQ1_HI      = $4003  ; Square 1 High Frequency

SQ2_VOL     = $4004  ; Square 2 Volume
SQ2_SWEEP   = $4005  ; Square 2 Sweep
SQ2_LO      = $4006  ; Square 2 Low Frequency
SQ2_HI      = $4007  ; Square 2 High Frequency

TRI_LINEAR  = $4008  ; Triangle Linear Counter
TRI_LO      = $400A  ; Triangle Low Frequency
TRI_HI      = $400B  ; Triangle High Frequency

NOISE_VOL   = $400C  ; Noise Volume
NOISE_LO    = $400E  ; Noise Low Frequency
NOISE_HI    = $400F  ; Noise High Frequency

DMC_FREQ    = $4010  ; DMC Frequency
DMC_RAW     = $4011  ; DMC Raw
DMC_START   = $4012  ; DMC Start Address
DMC_LEN     = $4013  ; DMC Sample Length

OAM_DMA     = $4014  ; OAM DMA Register (Sprite DMA)
SND_CHN     = $4015  ; Sound Channels Enable
JOY1        = $4016  ; Joypad 1
JOY2        = $4017  ; Joypad 2 / APU Frame Counter

;===============================================================================
; Controller Button Masks
;===============================================================================
BUTTON_A      = %10000000
BUTTON_B      = %01000000
BUTTON_SELECT = %00100000
BUTTON_START  = %00010000
BUTTON_UP     = %00001000
BUTTON_DOWN   = %00000100
BUTTON_LEFT   = %00000010
BUTTON_RIGHT  = %00000001

;===============================================================================
; PPU Control Register Flags (PPU_CTRL)
;===============================================================================
VBLANK_NMI       = %10000000  ; Enable NMI on VBlank
PPU_MASTER       = %01000000  ; Master/slave select
SPRITE_8x16      = %00100000  ; Sprite size (0=8x8, 1=8x16)
BG_PATTERN_1000  = %00010000  ; Background pattern table (0=$0000, 1=$1000)
SPR_PATTERN_1000 = %00001000  ; Sprite pattern table (0=$0000, 1=$1000)
VRAM_DOWN        = %00000100  ; VRAM increment (0=+1, 1=+32)
NAMETABLE_2400   = %00000010  ; Base nametable address
NAMETABLE_2800   = %00000001

;===============================================================================
; PPU Mask Register Flags (PPU_MASK)
;===============================================================================
EMPHASIZE_BLUE   = %10000000
EMPHASIZE_GREEN  = %01000000
EMPHASIZE_RED    = %00100000
SHOW_SPRITES     = %00010000  ; Enable sprite rendering
SHOW_BG          = %00001000  ; Enable background rendering
SHOW_SPR_LEFT    = %00000100  ; Show sprites in leftmost 8 pixels
SHOW_BG_LEFT     = %00000010  ; Show background in leftmost 8 pixels
GREYSCALE        = %00000001  ; Greyscale mode

;===============================================================================
; PPU Status Register Flags (PPU_STATUS)
;===============================================================================
VBLANK_FLAG      = %10000000  ; VBlank flag
SPRITE_0_HIT     = %01000000  ; Sprite 0 hit flag
SPRITE_OVERFLOW  = %00100000  ; Sprite overflow flag

;===============================================================================
; Memory Addresses
;===============================================================================
STACK_TOP       = $01FF
OAM_BUFFER      = $0200  ; OAM buffer in RAM (256 bytes)
