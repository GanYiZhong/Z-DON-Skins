-- The default chibi sets (folders chibi_0..13). Each set is one motion (a chibi class and its
-- settings) shared by its characters; a character is a texture key, plus `first` when a key
-- holds two characters.
-- Poses are { beat, frame, x, y } offsets from the run line; see chibi/base.lua.
local BaseChibi    = require("background/bg_objects/chibi/base")
local ChibiWave     = require("background/bg_objects/chibi/wave")
local ChibiRoll     = require("background/bg_objects/chibi/roll")
local ChibiStretch  = require("background/bg_objects/chibi/stretch")
local ChibiTail     = require("background/bg_objects/chibi/tail")
local concat        = require("background/bg_objects/timing").concat

local FOUR  = { { key = "3" }, { key = "2" }, { key = "1" }, { key = "0" } }
-- a quicker, lower hop (sets 05, 06)
local SHORT_HOP = function(from_y, peak_y)
    return { from = { -418, from_y }, peak = { -341, peak_y }, up = 0.275 }
end

-- `frames` played in turn every `step` beats from `beat`, `count` times, at heights `ys`
local function cycle(beat, step, count, frames, ys)
    local out = {}
    for i = 0, count - 1 do
        local k = i % #frames + 1
        table.insert(out, { beat + i * step, frames[k], 0, ys[k] })
    end
    return out
end


local SETS = {}

-- 01: rocks back and forth and bobs as it toddles along
-- (steady swings; the original rock and bob are a little irregular)
SETS[0] = {
    class  = ChibiWave,
    chars  = { { key = "2" }, { key = "1" }, { key = "0" } },
    hop    = { from = { -418, 20 }, peak = { -326, -27 }, up = 0.325 },
    run    = { y = 17 },
    wave   = { first = -12, height = 22, beats = 0.5 },
    sway   = { first = 15, height = 25, beats = 0.725 },
    period = 1,
    poses  = { { 0, 0 }, { 0.1, 1 }, { 0.175, 2 }, { 0.225, 3 }, { 0.5, 2 }, { 0.575, 1 }, { 0.75, 0 } },
}

-- 02: crouches back, then leaps up and forward and drops onto its feet, every beat
SETS[1] = {
    class  = BaseChibi,
    chars  = FOUR,
    period = 1,
    poses  = {
        { 0,     1, -11,   3 },
        { 0.1,   2, -26,  12 },
        { 0.15,  2, -32,  12 },
        { 0.225, 3, -42,   6 },
        { 0.325, 4, -14, -23, to = { 12, -55, "out" } },
        { 0.65,  4,  15, -53, to = { 25, -45 } },
        { 0.75,  4,  25, -45 },
        { 0.825, 0,  30,  -2, to = { 0, -2 } },
    },
}

-- 03: rolls along, a full turn every 2 beats
SETS[2] = {
    class = ChibiRoll,
    chars = FOUR,
    roll  = { beats = 2, sway = 28 },
}

-- 04: winds up backwards, then hops forward, every beat
SETS[3] = {
    class  = BaseChibi,
    chars  = FOUR,
    period = 1,
    poses  = {
        { 0, 1, 0, 0 }, { 0.075, 2, -12, 0 }, { 0.15, 3, -22, -2 }, { 0.225, 3, -40, 0 },
        { 0.25, 4, -16, -12 }, { 0.375, 4, -9, -16 }, { 0.5, 5, 2, -21 }, { 0.65, 6, 2, -14 },
        { 0.725, 7, 0, -10 }, { 0.85, 0, 0, 0 },
    },
}

-- 05: waddles for 1.4 beats, then flutters a little off the ground and settles, every 3 beats
SETS[4] = {
    class  = BaseChibi,
    chars  = FOUR,
    hop    = SHORT_HOP(31, -15),
    run    = { y = 25 },
    period = 3,
    poses  = concat(
        cycle(0, 0.125, 11, { 1, 2, 3, 4 }, { 0, -6, -10, -6 }),
        cycle(1.375, 0.075, 18, { 0, 5, 6 }, { -15, -14, -15 }),
        { { 2.725, 3, 0, -8 }, { 2.8, 3, 0, 0 }, { 2.9, 4, 0, 0 } }),
}

-- 06: crouches, jumps and turns around in the air, flaps down, then jumps and turns back,
-- every 2 beats (mirrored poses face the other way)
SETS[5] = {
    class  = BaseChibi,
    chars  = FOUR,
    hop    = SHORT_HOP(21, -24),
    run    = { y = 15 },
    period = 2,
    poses  = {
        { 0, 1, 0, 0 }, { 0.075, 2, -10, 0 }, { 0.15, 2, -20, 0 }, { 0.225, 3, -30, 0 },
        { 0.3, 4, -20, -9 }, { 0.5, 5, -15, -25 }, { 0.7, 4, 1, -35, mirror = true },
        -- flaps down
        { 0.875, 6, 0, -35 }, { 0.925, 7, 0, -35 }, { 0.975, 6, 0, -30 }, { 1.025, 7, 0, -30 },
        { 1.075, 6, 0, -22 }, { 1.125, 7, 0, -22 }, { 1.175, 6, 0, -15 }, { 1.225, 7, 0, -10 },
        { 1.275, 6, 0, -10 },
        { 1.325, 4, 0, -10 }, { 1.5, 5, 0, -7 }, { 1.675, 4, 1, -4, mirror = true }, { 1.85, 8, 0, 0 },
    },
}

-- 07: bounces up a step at a time and drops back down, landing squashed, twice every 2 beats
SETS[6] = {
    class  = BaseChibi,
    chars  = FOUR,
    period = 2,
    poses  = {
        { 0,     0, 0,  20, to = { 0, 0 }, sy = { 0.8, 1 } },
        { 0.2,   1, 0, -10 },
        { 0.4,   2, 0, -20 },
        { 0.6,   3, 0, -30 },
        { 0.775, 4, 0, -30, to = { 0, 0 } },
        { 0.975, 5, 0,  10, to = { 0, -10 }, sy = { 0.8, 1 } },
        { 1.175, 6, 0, -20, to = { 0, -30 } },
        { 1.375, 7, 0, -30 },
        { 1.575, 8, 0, -30 },
        { 1.8,   9, 0, -30, to = { 0, 0 } },
    },
}

-- 08: lunges forward stretching wide every 2 beats; two of the characters paddle as they go
local PADDLE = { { 0, 0 }, { 0.15, 1 }, { 0.325, 2 }, { 0.5, 0 }, { 0.65, 1 }, { 0.825, 2 },
                 { 1, 0 }, { 1.15, 1 }, { 1.325, 2 }, { 1.5, 0 }, { 1.65, 1 }, { 1.825, 2 } }
SETS[7] = {
    class  = ChibiStretch,
    chars  = { { key = "2" }, { key = "3" }, { key = "1", poses = PADDLE }, { key = "0", poses = PADDLE } },
    period = 2,
    lunge  = { beats = 2, crouch = 30, spring = 110 },
}

-- 09: steps through its walk frames in place
SETS[8] = {
    class  = BaseChibi,
    chars  = FOUR,
    period = 1,
    poses  = { { 0, 1 }, { 0.15, 2 }, { 0.325, 3 }, { 0.5, 1 }, { 0.65, 4 }, { 0.825, 0 } },
}

-- 10: crouches back, squashes, then springs high (stretched) and floats down, every beat;
-- sinks 12px over the run
SETS[9] = {
    class  = BaseChibi,
    chars  = FOUR,
    run    = { y = 1, drift = 12 },
    period = 1,
    poses  = {
        { 0, 0, 0, -4 }, { 0.05, 1, 0, 6 }, { 0.15, 2, -10, 6 }, { 0.25, 3, -20, 6 },
        { 0.3, 3, -20, 8, sy = 0.9 }, { 0.375, 4, -20, 7 },
        { 0.45, 4, -17, -13, to = { -16, -19 }, sy = { 1, 1.11 } }, { 0.5, 4, -16, -19, sy = 1.11 },
        { 0.525, 5, -15, -37 }, { 0.6, 5, -12, -41 }, { 0.725, 6, -6, -44 },
        { 0.825, 6, 0, -46, to = { 0, -36 } }, { 0.875, 6, 0, -36 }, { 0.95, 0, 0, -22 },
    },
}

-- 11: winds up backwards, then hops up and lands, every beat
SETS[10] = {
    class  = BaseChibi,
    chars  = FOUR,
    period = 1,
    poses  = {
        { 0, 1, 0, 0 }, { 0.075, 2, -7, 0 }, { 0.15, 3, -21, 0 }, { 0.225, 3, -24, 0 },
        { 0.25, 4, -15, -14 }, { 0.375, 4, -11, -23 }, { 0.5, 0, -3, -30 }, { 0.65, 0, 0, -22 },
        { 0.725, 5, 0, -10 }, { 0.85, 6, 0, 0 },
    },
}

-- 12: ducks down and back, then jumps up and drops, every beat (two characters per key)
SETS[11] = {
    class  = BaseChibi,
    chars  = { { key = "1", first = 5 }, { key = "1" }, { key = "0", first = 5 }, { key = "0" } },
    period = 1,
    poses  = {
        { 0, 1, 0, 12 }, { 0.1, 2, 0, 22 }, { 0.15, 2, -12, 22 }, { 0.2, 2, -23, 22 },
        { 0.25, 1, -21, 11 }, { 0.3, 1, -15, -1 }, { 0.35, 3, -11, -10 }, { 0.4, 3, -9, -18 },
        { 0.45, 0, 7, -34 }, { 0.6, 4, 0, -30 }, { 0.75, 0, 0, -21 }, { 0.9, 3, 0, -6 },
    },
}

-- 13: floats up 20px through its frames and back down, every 2 beats
SETS[12] = {
    class  = BaseChibi,
    chars  = { { key = "1" }, { key = "0" } },
    period = 2,
    poses  = {
        { 0, 0, 0, 0 },
        { 0.175, 1, 0, 0,   to = { 0, -5 } },
        { 0.375, 2, 0, -5,  to = { 0, -10 } },
        { 0.575, 3, 0, -10, to = { 0, -15 } },
        { 0.775, 4, 0, -15 },
        { 0.975, 5, 0, -20 },
        { 1.175, 4, 0, -20, to = { 0, -15 } },
        { 1.375, 3, 0, -15, to = { 0, -10 } },
        { 1.575, 2, 0, -10, to = { 0, -5 } },
        { 1.775, 1, 0, -5,  to = { 0, 0 } },
    },
}

-- 14: bobs along pulsing every beat, wagging its tail
SETS[13] = {
    class = ChibiTail,
    chars = FOUR,
}

return SETS
