local M = {}

local S = tex.get_screen_scale()
local TILE = 640
local TILES = 3
local SCREEN_WIDTH = 1280
local SCROLL_PER_MS = 0.02

function M.new()
    tex.load_folder("song_select", "enso_battle")
    local sky = tex.get_texture("song_select/enso_battle/sky")
    return function()
        local shift = (tex.get_current_ms() * SCROLL_PER_MS) % (TILE * TILES)
        local i = 0
        while i * TILE - shift < SCREEN_WIDTH do
            tex.draw_texture(sky, { frame = i % TILES, x = (i * TILE - shift) * S })
            i = i + 1
        end
    end
end

return M
