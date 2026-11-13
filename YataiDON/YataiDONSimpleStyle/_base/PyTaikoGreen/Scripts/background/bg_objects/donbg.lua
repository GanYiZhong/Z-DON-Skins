local DonBGBase = require("background/bg_objects/donbg/base")

-- The default don bands (folders 0_x..5_x), by index; see DonBGBase for the
-- layer fields. Every background tile scrolls one tile left every 5.3s.
local SCROLL_MS = 5333
local SPECS = {
    -- lanterns bobbing over the band, a strip of footer tiles below
    [1] = { layers = {
        { key = "background", ms = SCROLL_MS },
        { key = "overlay", ms = SCROLL_MS, tile = 328, bob = { { 967, -20, "out" }, { 33, 0 }, { 1017, 20 } } },
        { key = "footer", ms = SCROLL_MS, dx = -336, bob = { { 1000, 9 }, { 1000, -9 } } },
    } },
    [2] = { layers = {
        { key = "background", ms = SCROLL_MS },
        { key = "overlay", ms = SCROLL_MS, bob = { { 1000, 23 }, { 1000, -23 } } },
    } },
    -- the overlay runs ahead of the background, bouncing
    [3] = { layers = {
        { key = "background", ms = SCROLL_MS, dx = -328 },
        { key = "overlay", ms = 3350, bob = {
            { 333, 19, "out" }, { 333, -19 }, { 317, 19, "out" }, { 600, -55, "in" }, { 250, 36, "in" },
        } },
    } },
    [4] = { layers = {
        { key = "background", ms = SCROLL_MS },
        { key = "overlay", ms = SCROLL_MS, bob = { { 1000, 23 }, { 1000, -23 } } },
    } },
    -- a row of animals 300px apart walking left, each hopping and landing with a squash
    [5] = { layers = {
        { key = "background", ms = SCROLL_MS },
        { key = "overlay", ms = 2667, tile = 300, period = 2183,
            bob    = { { 1333, 0 }, { 317, -20, "out" }, { 333, 20, "in" } },
            squash = { { 1983, 0 }, { 100, 9, "out" }, { 100, -9 } } },
    } },
    -- overlay_1 drifts down and left in a loop
    [6] = { layers = {
        { key = "background", ms = SCROLL_MS },
        { key = "overlay_1", ms = 2000, dx = -620, dy = 330, tile = 620 },
        { key = "overlay_2", ms = SCROLL_MS, bob = { { 1000, -20 }, { 1000, 20 } } },
    } },
}

DonBG = {}
DonBG.SPECS = SPECS

function DonBG.create(player_num, path, index)
    index = index or math.random(1, 6)
    return DonBGBase.new(index, player_num, path, SPECS[index])
end

-- Miku and GUMI: a still base under two parallax layers (fast, slow); clearing also brings
-- a pulsing sparkle layer that rides with the slow one. fast_x: the fast layer's tile phase
function DonBG.parallax(fast_x)
    return { layers = {
        { key = "background" },
        { key = "fast", ms = 2000, dx = -656, x = fast_x },
        { key = "slow", ms = 2000 },
        { key = "sparkle", ms = 2000, clear_only = true, pulse = { { 500, -500 }, { 500, 500 } } },
    } }
end

return DonBG
