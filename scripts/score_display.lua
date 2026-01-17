-- score_display.lua
-- FCEUX Lua script to display score from RAM
-- Usage: In FCEUX, File -> Lua -> New Lua Script Window, then load this file

-- RAM addresses (must match constants.inc)
local SCORE_ONES     = 0x19
local SCORE_TENS     = 0x1A
local SCORE_HUNDREDS = 0x1B
local GAME_STATE     = 0x0A

-- Game state constants
local STATE_WAITING = 0
local STATE_PLAYING = 1
local STATE_DYING   = 2
local STATE_DEAD    = 3

local state_names = {
    [STATE_WAITING] = "WAITING",
    [STATE_PLAYING] = "PLAYING",
    [STATE_DYING]   = "DYING",
    [STATE_DEAD]    = "DEAD"
}

function display_score()
    local ones = memory.readbyte(SCORE_ONES)
    local tens = memory.readbyte(SCORE_TENS)
    local hundreds = memory.readbyte(SCORE_HUNDREDS)
    local state = memory.readbyte(GAME_STATE)

    local score = hundreds * 100 + tens * 10 + ones
    local state_name = state_names[state] or "UNKNOWN"

    -- Draw score in top-left corner
    gui.text(8, 8, string.format("SCORE: %03d", score), "white", "clear")

    -- Draw game state below score
    gui.text(8, 18, string.format("STATE: %s", state_name), "yellow", "clear")
end

-- Register to run after each frame
emu.registerafter(display_score)

print("Flappy Bird score display loaded!")
print("RAM addresses: score=$19-$1B, state=$0A")
