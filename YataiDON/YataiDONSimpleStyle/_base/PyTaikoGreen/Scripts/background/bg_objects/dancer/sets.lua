-- The default dancer sets (folders dancer_0..20). A set is a table of dancer specs by dancer
-- index (or `default`); see BaseDancer in bg_objects/dancer.lua. Every dancer's origin is at
-- y 670.
local Timing = require("background/bg_objects/timing")
local steps  = Timing.steps
local concat = Timing.concat

local SETS = {}

-- 06 (dancer_5) and 07 (dancer_6): rise out of the floor fluttering, then dance through their frames,
-- 0.3 beat each; leaving, it bursts into an ink splash and its spirit floats away
local INK_SPLASH = {
    { -- the dancer jumps, lands as a splat of ink that spreads and fades
        { 0,     7, 0, -151, key = "start" },
        { 0.075, 8, 0, -154, key = "start", to = { 0, -168 } },
        { 0.375, 0, 0, -170 },
        { 0.45,  1, 0, -164, to = { 0, -145 } },
        { 0.85,  0, 0, -145, key = "ink_s", to = { 0, -98 } },
        { 1,     0, 0, -98,  key = "ink_s", scale = 1.02, alpha = 0.97, to = { 0, -98, scale = 1.1, alpha = 0.87 } },
        { 1.125, 0, 0, -98,  key = "ink_l", scale = 1.12, alpha = 0.84, to = { 0, -158, "out", scale = 2.02, alpha = 0.08 } },
        { 1.325, hide = true },
    },
    { -- a second ring of ink
        { 1.1, 0, 0, -98, key = "ink_l", scale = 0.81, alpha = 0.84, to = { 0, -158, scale = 1.56, alpha = 0.08 } },
        { 1.325, hide = true },
    },
    { -- its spirit floats up and fades
        { 0.85, 2, 0, -153, to = { 0, -242 } },
        { 1.25, 2, 0, -249, alpha = 0.88, to = { 0, -300, alpha = 0 } },
        { 1.45, hide = true },
    },
}
-- rises out of the floor, flutters at the top and drifts down, then hops and lands
local INK_RISE = {
    beats = 2,
    { 0,     0, 0, 190, to = { 0, -80 } },
    { 0.325, 1, 3, -149 }, { 0.4, 2, 6, -191 }, { 0.475, 3, 11, -195 }, { 0.55, 4, 9, -200 },
    { 0.625, 5, 2, -199 }, { 0.7, 6, 0, -199 },
    { 0.775, 0, 0, -194 }, { 0.85, 1, 3, -185 }, { 0.925, 2, 6, -174 }, { 1, 3, 11, -155 },
    { 1.075, 4, 9, -145 }, { 1.15, 5, 2, -133 }, { 1.225, 6, 0, -120 },
    { 1.3, 6, 0, -135 }, { 1.375, 7, 0, -151 }, { 1.45, 8, 0, -154 },
    { 1.525, 8, 0, -159, to = { 0, -145 } }, { 1.775, 8, 0, -145 },
}

SETS[5] = { default = {
    origin = { 156, 156 },
    at     = { -10, -140 },
    enter  = INK_RISE,
    dance  = steps({ { 0, 0.3 }, { 1, 0.3 }, { 2, 0.3 }, { 3, 0.3 }, { 4, 0.3 }, { 5, 0.3 }, { 6, 0.2 },
                     { 7, 0.3 }, { 8, 0.3 }, { 9, 0.3 }, { 10, 0.3 }, { 11, 0.3 }, { 12, 0.3 }, { 13, 0.2 } }),
    leave  = { beats = 2, INK_SPLASH[1], INK_SPLASH[2], INK_SPLASH[3] },
} }

-- 07 (dancer_6): the same ink dancer with 16 frames, standing a little to the right
local function ink_bar(first)
    return { { first, 0.175 }, { first + 1, 0.125 }, { first + 2, 0.3 }, { first + 3, 0.3 },
             { first + 4, 0.3 }, { first + 5, 0.3 }, { first + 6, 0.3 }, { first + 7, 0.2 } }
end
SETS[6] = { default = {
    origin = { 156, 156 },
    at     = { 10, -140 },
    enter  = INK_RISE,
    dance  = steps(ink_bar(0), ink_bar(8)),
    leave  = { beats = 2, INK_SPLASH[1], INK_SPLASH[2], INK_SPLASH[3] },
} }

-- 10 (dancer_9): rises up, rears back and lands with a squash; sways for 8 beats with a
-- flourish halfway and at the end; leaving, it unwinds, shakes its head and drops away
local function sway(flourish)
    return { { 0, 0.5 }, { 1, 0.5 }, { 0, 0.5 }, { 1, 0.5 }, { 0, 0.475 },
             { flourish, 0.25 }, { flourish + 1, 0.25 }, { flourish + 2, 1.025 } }
end
SETS[9] = { default = {
    origin = { 152, 152 },
    at     = { 0, -125 },
    enter  = {
        beats = 2,
        { 0,     0, 2, 132, to = { 2, -130, "in" } },
        { 0.525, 0, 2, -130 }, { 0.625, 1, 2, -144 }, { 0.7, 2, 2, -159 }, { 0.775, 3, 2, -167 },
        { 0.85,  4, 2, -167 }, { 1.1, 4, 2, -164, to = { 2, -137 } }, { 1.375, 5, 2, -134 },
        { 1.45,  6, 2, -130, to = { 2, -121, sy = 0.9 } },
        { 1.65,  6, 2, -121, sy = 0.93, to = { 2, -120, sy = 1 } },
        { 1.725, 6, 2, -120 },
    },
    dance  = steps(sway(2), sway(5)),
    leave  = {
        beats = 2,
        {
            key = "start",
            { 0,     6, 0, -125 },
            { 0.075, 5, 0, -123, to = { 0, -136 } },
            { 0.275, 4, 0, -140, to = { 0, -138 } },
            { 0.5, 3, 0, -141 }, { 0.575, 2 }, { 0.65, 1 }, { 0.725, 0 },
            -- shakes its head
            { 0.8,   0, rot = -4,  to = { rot = -20 } },
            { 0.925, 0, rot = -12, to = { rot = -4 } },
            { 0.975, 0, rot = 4,   to = { rot = 12 } },
            { 1.025, 0, rot = 20,  to = { rot = 16 } },
            { 1.075, 0, rot = 12,  to = { rot = 0 } },
            { 1.175, 0 },
            { 1.35,  0, 0, -127, key = "end" },
            { 1.425, 1, 0, -113, key = "end", to = { 0, 131, "in" } },
            { 1.9, hide = true },
        },
    },
} }

-- 11 (dancer_10): shoots up from below, bobs and lands with a squash; dances a 4-beat
-- routine, stamping (squash) twice; leaving, it hops up and drops while a piece of it flies off
SETS[10] = { default = {
    origin = { 164, 152 },
    at     = { 0, -125 },
    enter  = {
        beats = 2,
        { 0,     0, 5, 225, to = { 5, -161, "out" } },
        { 0.825, 1, 5, -161 },
        { 0.85,  2, 5, -175, to = { 5, -143, "in" } },
        { 1.35,  1, 5, -145, to = { 5, -128 } },
        { 1.525, 0, 5, -125, to = { 5, -121, sy = 0.95 } },
        { 1.65,  0, 5, -122, sy = 0.96, to = { 5, -125, sy = 1 } },
        { 1.775, 0, 5, -125 },
    },
    dance  = {
        length = 4,
        { 0, 3, key = "start" },
        { 0.5, 0 }, { 0.6, 1 }, { 0.8, 2 }, { 0.9, 3 },
        { 1,   4, 0, -125, to = { 0, -122, sy = 0.96 } },        -- stamp
        { 1.1, 5, 0, -121, sy = 0.95, to = { 0, -125, sy = 1 } },
        { 1.4, 5, 0, -125 }, { 1.75, 6 }, { 1.875, 7 },
        { 2, 8 }, { 2.5, 9 }, { 2.6, 10 }, { 2.8, 11 }, { 2.9, 12 },
        { 3,   13, 0, -125, to = { 0, -122, sy = 0.96 } },       -- stamp
        { 3.1, 14, 0, -121, sy = 0.95, to = { 0, -125, sy = 1 } },
        { 3.425, 14, 0, -125 }, { 3.75, 15 }, { 3.875, 16 },
    },
    leave  = {
        beats = 2,
        {
            key = "start",
            { 0, 0, 5, -112 }, { 0.2, 1 }, { 0.375, 2 },
            { 0.525, 0, 5, -112, key = "end", to = { 5, -122, "out" } },
            { 0.65,  0, 5, -122, key = "end", to = { 5, 253, "in" } },
            { 1.65, hide = true },
        },
        { -- the piece that flies off
            { 0.525, 1, 5, -185, to = { 5, -204, "out" } },
            { 0.8,   1, 5, -204, to = { 5, 235, "in" } },
            { 1.9, hide = true },
        },
    },
} }

-- 12 (dancer_11): springs up from below and lands squashed; dances three frames a beat for
-- 8 beats; leaving, it crouches, jumps, hangs at the top and falls
local function beat3(a, b, c, last) return { { a, 0.325 }, { b, 0.325 }, { c, last or 0.35 } } end
SETS[11] = { default = {
    origin = { 112, 124 },
    at     = { 26, -102 },
    enter  = {
        beats = 2,
        { 0,     0, 0, 231 },
        { 0.1,   1, 0, 231, to = { 0, 111, sy = 0.9 } },
        { 0.225, 2, 0, 101, to = { 0, -199, "out" } },
        { 0.875, 3, 0, -199, to = { 0, -95, "in", sy = 0.9 } },
        { 1.175, 3, 0, -95, sy = 0.9, to = { 0, -86, "in", sy = 0.8 } },
        { 1.3,   3, 0, -86, sy = 0.8 },
        { 1.4,   1, 0, -94, sy = 0.9, to = { 0, -103, "out", sy = 1 } },
        { 1.675, 1, 0, -103 }, { 1.725, 0, 0, -103 },
    },
    dance  = steps({ { 0, 0.3 }, { 1, 0.225 }, { 2, 0.225 }, { 3, 0.225 } },
                   beat3(4, 5, 6), beat3(7, 8, 9), beat3(10, 11, 12), beat3(1, 2, 3),
                   beat3(13, 14, 15), beat3(16, 8, 9), beat3(17, 18, 19, 0.375)),
    leave  = {
        beats = 2,
        { 0,     0, 0, -102 },
        { 0.2,   1, 0, -102, to = { 0, -94, "out", sy = 0.9 } },
        { 0.425, 1, 0, -94, sy = 0.9 },
        { 0.45,  2, 0, -97, sy = 0.9, to = { 0, -202, "out", sy = 1.1 } },
        { 0.875, 3, 0, -207, to = { 0, -207, "in", sy = 0.96 } },
        { 1,     3, 0, -207, sy = 0.93, to = { sy = 0.9 } },
        { 1.05,  3, 0, -207, sy = 0.9 },
        { 1.1,   4, 0, -202, to = { 0, -201 } },
        { 1.175, 4, 0, -199, to = { 0, -197 } },
        { 1.225, 4, 0, -194, to = { 0, 208, "in", sy = 0.9 } },
    },
} }

-- 20 (dancer_18) and 21 (dancer_19): pop up from below and land with a squash; leaving, they
-- jump and fall. dy: how much higher than dancer_18 the set stands
local function pop_up(dy)
    return {
        beats = 2,
        { 0.4,   0, -4, 331 + dy, to = { -4, -199 + dy, "out" } },
        { 1,     0, -4, -199 + dy, to = { -4, -164 + dy, "in" } },
        { 1.25,  1, -4, -159 + dy }, { 1.35, 2 },
        { 1.425, 3, -4, -159 + dy, to = { -4, -153 + dy, sy = 0.95 } },
        { 1.55,  3, -4, -155 + dy, sy = 0.96, to = { -4, -159 + dy, sy = 1 } },
        { 1.65,  3, -4, -159 + dy },
    }
end
local function jump_off(dy)
    return {
        beats = 2,
        { 0, 0, 0, -192 + dy }, { 0.15, 1 },
        { 0.3,   2, 0, -192 + dy, to = { 0, -237 + dy, "out" } },
        { 0.475, 2, 0, -237 + dy, to = { 0, 258 + dy, "in" } },
    }
end

-- 20: two poses a beat
local function halves(...)
    local out = {}
    for _, f in ipairs({ ... }) do table.insert(out, { f, 0.5 }) end
    return out
end
SETS[18] = { default = {
    origin = { 176, 200, loop = { 120, 152 } },
    at     = { 0, -122 },
    enter  = pop_up(0),
    dance  = steps(halves(0, 1, 2, 3, 1, 2, 3, 4, 5, 6, 7, 8, 6, 7, 8, 9)),
    leave  = jump_off(0),
} }

-- 21: its 14 frames slowly, then twice as fast, twice
local SLOW = { { 0, 0.15 }, { 1, 0.175 }, { 2, 0.175 }, { 3, 0.375 }, { 4, 0.375 }, { 5, 0.375 }, { 6, 0.375 },
               { 7, 0.15 }, { 8, 0.175 }, { 9, 0.175 }, { 10, 0.375 }, { 11, 0.375 }, { 12, 0.375 }, { 13, 0.375 } }
local FAST = { { 0, 0.125 }, { 1, 0.125 }, { 2, 0.15 }, { 3, 0.15 }, { 4, 0.15 }, { 5, 0.15 }, { 6, 0.15 },
               { 7, 0.125 }, { 8, 0.125 }, { 9, 0.15 }, { 10, 0.15 }, { 11, 0.15 }, { 12, 0.15 }, { 13, 0.15 } }
SETS[19] = { default = {
    origin = { 176, 200, loop = { 140, 140 } },
    at     = { 0, -120 },
    enter  = pop_up(-8),
    dance  = steps(SLOW, FAST, FAST),
    leave  = jump_off(-8),
} }

-- A puff of smoke from `beat`, centred dx, dy from the dancer, using
-- texture `key` ("poof" shared by the set, or "_poof" per dancer): five layers of puffs
-- growing, rising and fading over a beat
local POOF = {
    {
        { 0,     0, 0, 0 },
        { 0.125, 1, 3, -3, scale = 1.08, to = { -3, -39, scale = 1.36 } }, { 0.25, hide = true },
        { 0.3,   1, 2, -45, alpha = 0.4, to = { alpha = 0.7 } },
        { 0.55,  4, -2, 12, alpha = 0.27, to = { alpha = 0.05 } }, { 0.725, hide = true },
        { 0.825, 6, 2, -2, scale = 0.93, alpha = 0.32 }, { 0.85, hide = true },
    },
    {
        { 0.25, 2, 5, 21, sx = 0.89, sy = 0.81, to = { 0, -10, sx = 1.1, sy = 1.1 } },
        { 0.4,  3, 0, -4, to = { 0, -34, alpha = 0.77 } }, { 0.6, hide = true },
        { 0.7,  5, 0, 6, to = { 0, -4, alpha = 0.22 } }, { 0.825, hide = true },
    },
    { { 0.5, 4, 0, 0, to = { 0, -20, alpha = 0.67 } }, { 0.7, hide = true } },
    {
        { 0.175, 2, 0, -30, scale = 1.23, alpha = 0.8, to = { 0, -37, scale = 1.28, alpha = 0.35 } },
        { 0.425, 2, 0, 0, alpha = 0.8, to = { alpha = 0.04 } }, { 0.65, hide = true },
    },
    { { 0.6, 3, 0, -13, alpha = 0.5, to = { 0, -34, alpha = 0.12 } }, { 0.775, hide = true } },
}
local function poof(beat, dx, dy, key)
    local layers = {}
    for _, src in ipairs(POOF) do
        local layer = { key = key, origin = { 136, 188 } }
        for _, p in ipairs(src) do
            local q = {}
            for k, v in pairs(p) do q[k] = v end
            q[1] = p[1] + beat
            if p[3] then q[3], q[4] = p[3] + dx, p[4] + dy end
            if p.to then
                q.to = {}
                for k, v in pairs(p.to) do q.to[k] = v end
                if p.to[1] then q.to[1], q.to[2] = p.to[1] + dx, p.to[2] + dy end
            end
            table.insert(layer, q)
        end
        table.insert(layers, layer)
    end
    return layers
end

-- a part made of `main` plus extra layers
local function with(main, extra)
    local part = { beats = main.beats, main }
    for _, layer in ipairs(extra) do table.insert(part, layer) end
    return part
end

-- 08 (dancer_7): appears in a puff of smoke, shuffles and strikes two poses over 6 beats;
-- leaving, it springs up and drops away
local function shuffle(s, a, b, c, d, e, f)
    return { { s + 1, 0.05 }, { s + 2, 0.2 }, { s + 3, 0.175 }, { s + 2, 0.2 }, { s + 3, 0.375 },
             { a, 0.25 }, { b, 0.175 }, { c, 0.175 }, { d, 0.2 }, { e, 0.2 }, { f, 0.925 }, { d, 0.075 } }
end
-- fades in as the smoke clears, then stretches through its entry frames (sets 08, 09)
local SMOKE_APPEAR = {
    beats = 2,
    { 0.45, 0, 0, -122, alpha = 0.12, to = { alpha = 1 } },
    { 0.675, 0 }, { 1.15, 1 }, { 1.3, 2 }, { 1.45, 3 }, { 1.625, 4 },
}
local function smoke_dancer(s)
    return {
        origin = { 120, 152 },
        at     = { 0, -125 },
        enter  = with(SMOKE_APPEAR, poof(0, 3, -137, "poof")),
        dance  = steps(shuffle(s - 1, s + 3, s + 4, s + 5, s + 6, s + 7, s + 8),
                       shuffle(s - 1, s + 9, s + 10, s + 11, s + 12, s + 13, s + 14)),
        leave  = {
            beats = 2,
            { 0, s + 15, 0, -130, key = "loop" },
            { 0.6,   0, 0, -140, to = { 0, -146, "out" } },
            { 1.125, 1, 0, -121 }, { 1.25, 2, 0, -118 },
            { 1.35,  3, 0, -110, to = { 0, 80 } },
            { 1.6, hide = true },
        },
    }
end
SETS[7] = { default = smoke_dancer(0) }

-- 09 (dancer_8): appears in a puff of smoke; rocks between two figures, slower in the middle
-- of its 8 beats; leaving, it springs up and drops away
local function rock(a, b, c) -- one beat
    return { { 0, 0.15 }, { a, 0.15 }, { b, 0.15 }, { c, 0.25 }, { b, 0.15 }, { a, 0.15 } }
end
local function rock_slow(a, b, c) -- two beats, the swing twice
    return { { 0, 0.175 }, { a, 0.175 }, { b, 0.175 }, { c, 0.3 }, { b, 0.175 }, { a, 0.175 },
             { b, 0.175 }, { c, 0.3 }, { b, 0.175 }, { a, 0.175 } }
end
SETS[8] = { default = {
    origin = { 108, 152 },
    at     = { 0, -122 },
    enter  = with(SMOKE_APPEAR, poof(0, 3, -129, "poof")),
    dance  = steps(rock(1, 4, 5), rock(3, 2, 6), rock_slow(1, 4, 5), rock_slow(3, 2, 6),
                   rock(1, 4, 5), rock(3, 2, 6)),
    leave  = {
        beats = 2,
        { 0, 0, 0, -130 },
        { 0.6,   1, 0, -140, to = { 0, -146, "out" } },
        { 1.125, 2, 0, -108 }, { 1.25, 3, 0, -105 },
        { 1.35,  4, 0, -97, to = { 0, 93 } },
        { 1.6, hide = true },
    },
} }

-- 13 (dancer_12): appears in a puff of smoke and settles; steps through its frames over 4
-- beats; leaves with TUMBLE
-- winds up, hops twice and tumbles away (sets 13, 14)
local TUMBLE = {
    beats = 2,
    { 0, 5, 0, -110, key = "start" },
    { 0.425, 0, 0, -113 }, { 0.55, 1, 0, -117 }, { 0.675, 2, 0, -120 },
    { 0.75,  3, 0, -126, to = { 0, -129 } },
    { 0.925, 4, 0, -130, to = { 0, -132 } }, { 1.275, 4, 0, -132 },
    { 1.35,  5, 0, -113, to = { 0, -101 } },
    { 1.5,   4, 0, -96, to = { 0, -52 } },
    { 1.65,  5, 0, -47, to = { 0, 23 } },
    { 1.8,   4, 0, 36, to = { 0, 86 } },
    { 1.95, hide = true },
}

SETS[12] = { default = {
    origin = { 152, 152 },
    at     = { 0, -110 },
    enter  = with({
        beats = 2,
        { 0.3, 0, -12, -103 }, { 0.85, 1 }, { 0.975, 2 }, { 1.1, 3 }, { 1.225, 4 }, { 1.35, 5, 0, -110 },
    }, poof(0, 3, -137, "_poof")),
    dance  = {
        length = 4,
        { 0, 5, key = "start" }, { 0.925, 0 }, { 1.125, 1 }, { 1.35, 2 }, { 1.575, 3, -4, -110 },
        { 1.825, 4, 0, -110 }, { 2.075, 5 }, { 2.95, 4 }, { 3.15, 6 }, { 3.35, 7 }, { 3.55, 8 }, { 3.775, 0 },
    },
    leave  = TUMBLE,
} }

-- 14 (dancer_13): appears like set 13; turns and holds four times, then repeats a quick
-- one-beat bar seven times (16 beats); leaves with TUMBLE
local SWING_IN = { { 0, 0.175 }, { 1, 0.175 }, { 2, 0.15 }, { 11, 0.15 } }
local BAR      = { { 0, 0.175 }, { 1, 0.175 }, { 2, 0.15 }, { 11, 0.15 }, { 12, 0.175 }, { 13, 0.175 } }
SETS[13] = { default = {
    origin = { 152, 152 },
    at     = { 0, -110 },
    enter  = with({
        beats = 2,
        { 0.3, 0, -3, -98 }, { 0.85, 1 }, { 0.975, 2 }, { 1.1, 3 }, { 1.225, 4 }, { 1.35, 5, 0, -110 },
    }, poof(0, 3, -137, "_poof")),
    dance  = steps(SWING_IN, { { 3, 0.175 }, { 4, 0.175 }, { 5, 0.125 }, { 4, 0.875 } },
                   { { 5, 0.15 }, { 3, 0.225 }, { 6, 0.2 }, { 7, 0.225 }, { 8, 0.2 }, { 9, 0.125 }, { 8, 0.875 } },
                   { { 9, 0.15 }, { 7, 0.225 }, { 6, 0.2 }, { 3, 0.225 }, { 4, 0.2 }, { 5, 0.125 }, { 4, 0.975 } },
                   { { 5, 0.15 }, { 3, 0.2 }, { 6, 0.2 }, { 7, 0.225 }, { 8, 0.125 }, { 9, 0.125 }, { 8, 0.675 },
                     { 10, 0.125 }, { 11, 0.725 }, { 12, 0.175 }, { 13, 0.175 } },
                   BAR, BAR, BAR, BAR, BAR, BAR, BAR),
    leave  = TUMBLE,
} }

-- 22 (dancer_20): bounces in squashing and stretching; hops right twice and back left twice,
-- then stomps (squashing) for 8 beats; leaving, it crouches, springs up and falls.
-- y0: where the dancer stands (the second dancer stands 15px lower)
local function twin(y0)
    -- crouch on frame c, jump dx px over frame a (up `up`, down `down` beats), land on frame l
    local function hop(x0, dx, c, a, l, up, down, land)
        return {
            { c, 0.175, x = x0, y = y0, to = { x0, y0 + 10, "in", sy = 0.9 } },
            { a, up,    x = x0, y = y0 - 2, to = { x0 + dx / 2, y0 - 10, "out" } },
            { a, down,  x = x0 + dx / 2, y = y0 - 10, to = { x0 + dx, y0 - 2, "in" } },
            { l, land,  x = x0 + dx, y = y0 + 10, sy = 0.9, to = { x0 + dx, y0, "out", sy = 1 } },
        }
    end
    -- squash on frame d, rise on frame u, then a little flourish
    local function stomp(first, d, u, flourish)
        local out = {
            { first, 0.075, y = y0 },
            { d, 0.2, to = { nil, y0 + 9, "out", sy = 0.9 } },
            { u, 0.225, y = y0 + 9, sy = 0.9, to = { nil, y0, "out", sy = 1 } },
        }
        for _, s in ipairs(flourish or {}) do table.insert(out, s) end
        return out
    end
    local STOMP_A = stomp(38, 33, 34, { { 35, 0.075 }, { 36, 0.075 }, { 37, 0.275 }, { 34, 0.075 } })
    local STOMP_B = stomp(38, 39, 40, { { 41, 0.075 }, { 42, 0.075 }, { 43, 0.275 }, { 40, 0.075 } })
    return {
        at     = { 0, y0 },
        enter  = {
            beats = 2,
            { 0,     0, 0, y0 + 300, sy = 0.7, to = { 0, y0 - 95, "out", sy = 1.1 } },
            { 0.65,  1, 0, y0 - 95, sy = 1.1, to = { 0, y0 + 9, "in", sy = 0.9 } },
            { 0.975, 2, 0, y0 + 17, sy = 0.8, to = { 0, y0, "out", sy = 1 } },
            { 1.15, 3 }, { 1.25, 4 }, { 1.35, 5 },
        },
        dance  = steps(
            -- hops right twice, then a pose
            { { 0, 0.05, x = 0, y = y0 }, { 1, 0.05 }, { 2, 0.05 }, { 3, 0.05 }, { 4, 0.125 } },
            hop(0, 20, 5, 6, 7, 0.25, 0.25, 0.125),
            { { 7, 0.025 }, { 8, 0.05 }, { 9, 0.05 }, { 10, 0.05 }, { 4, 0.05 } },
            hop(20, 20, 5, 6, 7, 0.25, 0.225, 0.125),
            { { 7, 0.025 }, { 8, 0.05 }, { 9, 0.05 }, { 10, 0.05 }, { 4, 0.45 },
              { 11, 0.125 }, { 12, 0.125 }, { 13, 0.625 }, { 14, 0.075 }, { 2, 0.075 }, { 15, 0.075 },
              { 16, 0.075 }, { 17, 0.075 } },
            -- hops back left twice, then a pose
            { { 18, 0.325, x = 40, y = y0 } },
            hop(40, -20, 19, 20, 21, 0.275, 0.25, 0.1),
            { { 21, 0.025 }, { 22, 0.05 }, { 23, 0.05 }, { 24, 0.05 }, { 25, 0.05 } },
            hop(20, -20, 19, 20, 21, 0.275, 0.225, 0.15),
            { { 21, 0.025 }, { 22, 0.05 }, { 23, 0.05 }, { 24, 0.05 }, { 25, 0.4 },
              { 17, 0.125 }, { 26, 0.125 }, { 27, 0.8 }, { 28, 0.05 }, { 29, 0.05 }, { 30, 0.05 }, { 31, 0.05 } },
            -- stomps
            { { 32, 0.575, x = 0, y = y0 } },
            STOMP_A, STOMP_B, STOMP_A, STOMP_B, STOMP_A, STOMP_B, STOMP_A,
            stomp(38, 39, 40)
        ),
        leave  = {
            beats = 2,
            { 0,     0, 0, y0 },
            { 0.125, 1, 0, y0, to = { 0, y0 + 13, sy = 0.9 } },
            { 0.35,  1, 0, y0 + 13, sy = 0.9 },
            { 0.375, 2, 0, y0 + 5, sy = 0.9, to = { 0, y0 - 100, "out", sy = 1.1 } },
            { 0.875, 3, 0, y0 - 105, sy = 1.1, to = { 0, y0 - 100, sy = 1 } },
            { 1.05,  4, 0, y0 - 100 }, { 1.15, 5 },
            { 1.2,   5, 0, y0 - 98, to = { 0, y0 + 310, "in", sy = 0.8 } },
        },
    }
end
local TWIN_1, TWIN_2 = twin(-120), twin(-105)
TWIN_1.origin, TWIN_2.origin = { 108, 140 }, { 108, 124 }
SETS[20] = { [0] = TWIN_1, [1] = TWIN_2 }

-- 19 (dancer_17): shoots up from below and settles; dances four one-beat figures in the
-- order A B A C B A B D; leaving, it hops up and drops away
local function figure(a, b, c, d, e, f, hold)
    return { { a, 0.125 }, { b, 0.125 }, { c, 0.125 }, { d, 0.125 }, { e, 0.125 }, { f, 0.125 }, { hold, 0.25 } }
end
local function flourish(a, b, c, d, hold)
    return { { a, 0.15 }, { b, 0.15 }, { c, 0.15 }, { d, 0.15 }, { hold, 0.4 } }
end
local FIG_A, FIG_B = figure(0, 1, 6, 7, 8, 9, 10), figure(16, 14, 15, 2, 3, 4, 5)
local FIG_C, FIG_D = flourish(22, 11, 12, 13, 23), flourish(17, 18, 19, 20, 21)
SETS[17] = { default = {
    origin = { 140, 152 },
    at     = { 0, -130 },
    enter  = {
        beats = 2,
        { 0.25,  0, 0, 160, to = { 0, -200, "out" } },
        { 0.975, 0, 0, -200 }, { 1.05, 1, 0, -184 }, { 1.15, 2, 0, -171 },
        { 1.25,  3, 0, -135 }, { 1.375, 4, 0, -132 }, { 1.475, 5, 0, -130 }, { 1.575, 6 },
    },
    dance  = steps(FIG_A, FIG_B, FIG_A, FIG_C, FIG_B, FIG_A, FIG_B, FIG_D),
    leave  = {
        beats = 2,
        { 0,     0, 0, -130, to = { 0, -137 } },
        { 0.075, 1, 0, -140, to = { 0, -148 } },
        { 0.175, 2, 0, -150, to = { 0, -170 } },
        { 0.275, 2, 0, -170, to = { 0, 240, "in" } },
        { 1.625, hide = true },
    },
} }

-- 15 (dancer_14): shoots up, flutters and settles; over 48 beats it sways up and back down
-- (4 times), flutters 13px higher, sways the other way (4 times) and flutters again; leaving,
-- it squashes, springs up and drops while a piece of it tumbles off spinning
local function sway_up(a, b, c, d, e, top, rest)
    return { { a, 0.2, y = -110 }, { b, 0.2 }, { c, 0.2 }, { d, 0.2 }, { e, 0.2 }, { top, 1 },
             { e, 0.2 }, { d, 0.2 }, { c, 0.2 }, { b, 0.2 }, { a, 0.2 }, { rest, 1 } }
end
local SWAY_A = sway_up(0, 1, 2, 3, 4, 5, 20)
local SWAY_B = sway_up(13, 19, 18, 17, 16, 15, 14)
local FLUTTER = {
    { 6, 1, y = -123 }, { 7, 0.225 }, { 6, 0.25 }, { 7, 0.3 }, { 6, 1.225 }, { 7, 1 }, { 6, 1 },
    { 7, 0.25 }, { 6, 0.25 }, { 7, 0.5 },
    { 8, 0.275 }, { 9, 0.225 }, { 10, 0.25 }, { 11, 0.25 }, { 12, 0.75 }, { 6, 0.25 },
}
SETS[14] = { default = {
    origin = { 120, 132, loop = { 144, 144 }, ["end"] = { 108, 144 } },
    at     = { 0, -110 },
    enter  = {
        beats = 2,
        { 0,     0, 0, 220, to = { 0, -70, "out" } },
        { 0.325, 1, 0, -90 }, { 0.4, 2, 0, -130 }, { 0.475, 3, 0, -135 }, { 0.55, 4, 0, -137 },
        { 0.625, 5, 0, -138 }, { 0.7, 6, 0, -138 },
        { 0.775, 2, 0, -133 }, { 0.85, 3, 0, -124 }, { 0.925, 4, 0, -119 }, { 1, 5, 0, -116 },
        { 1.075, 6, 0, -112 }, { 1.15, 7, 0, -110 }, { 1.3, 8 }, { 1.45, 9, 0, -104 },
        { 1.6, 10, 0, -110 }, { 1.75, 11 },
    },
    dance  = steps(SWAY_A, SWAY_A, SWAY_A, SWAY_A, FLUTTER, SWAY_B, SWAY_B, SWAY_B, SWAY_B, FLUTTER),
    leave  = {
        beats = 2,
        {
            { 0,     0, 0, -110, to = { 0, -101, sy = 0.9 } },
            { 0.175, 0, 0, -103, sx = 0.98, sy = 0.92, to = { 0, -110, sx = 0.9, sy = 1 } },
            { 0.3,   0, 0, -113, sx = 0.91, to = { 0, -133, "out", sx = 1 } },
            { 0.525, 0, 0, -132 }, { 0.55, 1 },
            { 0.675, 2, 0, -141, to = { 0, -147 } },
            { 0.775, 3, 0, -147 },
            { 0.825, 3, 0, -147, to = { 0, 232, "in" } },
            { 1.975, hide = true },
        },
        { -- the piece that tumbles off
            { 0.775, 4, 0, -157, to = { 0, -161 } },
            { 0.85,  4, -1, -161, rot = 1, to = { -43, -128, "in", rot = 62 } },
            { 1.325, 4, -40, -119, rot = 58, to = { 0, 25, rot = 0 } },
            { 1.675, 4, 2, 39, rot = -3, to = { 13, 139, rot = -21 } },
            { 1.875, 4, 13, 159, rot = -21, to = { 12, 198 } },
            { 1.95,  4, 12, 218, rot = -21 },
            { 1.975, hide = true },
        },
    },
} }

-- 16 (dancer_15): pops up and steps in; dances with two glowing lights in its hands, which
-- flash on the two big poses of each 4-beat half; leaving, it crouches, springs and falls.
-- (The lights glow at a steady middle brightness rather than pulsing.)
local LIGHT_BEATS = { 0, 0.45, 0.75, 1.05, 1.35, 1.65, 1.95, 2.25, 2.55, 2.85, 3.15, 3.8,
                      4, 4.45, 4.75, 5.05, 5.35, 5.65, 5.95, 6.25, 6.55, 6.85, 7.15, 7.8 }
local LIGHT_FLASH = { [10] = true, [11] = true, [22] = true, [23] = true }
local function light(points)
    local layer = { key = "light", origin = { 44, 44 }, blend = "additive", length = 8 }
    for i, beat in ipairs(LIGHT_BEATS) do
        local x, y = points[i][1], points[i][2]
        local pose = { beat, 0, x, y, alpha = 0.47, blend = (i >= 12 and i <= 21) and false or nil }
        if LIGHT_FLASH[i] then pose.alpha, pose.to = 0.9, { x, y, "in", alpha = 0.3 } end
        table.insert(layer, pose)
    end
    return layer
end
local function dance_half(a, b, c, d, e, f, g, h, i, j)
    return { { a, 0.45, y = -110 }, { b, 0.3 }, { c, 0.3 }, { d, 0.3 }, { e, 0.3 }, { a, 0.3 }, { b, 0.3 },
             { f, 0.3 }, { g, 0.3 }, { h, 0.3, y = -118 }, { i, 0.65, y = -110 }, { j, 0.2 } }
end
SETS[15] = { default = {
    origin = { 144, 128 },
    at     = { 0, -110 },
    enter  = {
        beats = 2,
        { 0, 0, 0, 134, to = { 0, -110, "out" } }, { 0.35, 1, 0, -120 }, { 0.65, 2, 0, -110 },
        { 0.775, 3 }, { 0.9, 4 }, { 1.025, 5 }, { 1.15, 0 },
    },
    dance  = {
        steps(dance_half(0, 1, 2, 3, 4, 5, 6, 7, 8, 9), dance_half(10, 11, 12, 13, 14, 15, 16, 17, 18, 19)),
        light({ { 66, -135 }, { 52, -64 }, { -6, -70 }, { -20, -126 }, { 44, -150 }, { 66, -135 },
                { 52, -64 }, { 4, -53 }, { -35, -85 }, { -45, -130 }, { -45, -108 }, { -38, -111 },
                { -8, -113 }, { 4, -53 }, { 55, -57 }, { 81, -114 }, { 52, -151 }, { -9, -113 },
                { 5, -52 }, { 54, -49 }, { 89, -87 }, { 99, -137 }, { 98, -114 }, { 92, -116 } }),
        light({ { 3, -113 }, { -12, -53 }, { -63, -56 }, { -90, -113 }, { -61, -149 }, { 3, -113 },
                { -12, -53 }, { -58, -50 }, { -94, -87 }, { -103, -136 }, { -104, -114 }, { -97, -117 },
                { -71, -136 }, { -59, -65 }, { -2, -70 }, { 11, -126 }, { -52, -151 }, { -71, -137 },
                { -59, -65 }, { -9, -52 }, { 29, -85 }, { 39, -130 }, { 39, -109 }, { 34, -109 } }),
    },
    leave  = {
        beats = 2,
        {
            key = "start",
            { 0,     0, 0, -110 },
            { 0.3,   0, 0, -110, sy = 0.99, to = { 0, -97, sy = 0.9 } },
            { 0.5,   5, 0, -110 },
            { 0.625, 2, 0, -110, to = { 0, -134, "out" } },
            { 0.775, 1, 0, -132, to = { 0, 205, "in" } },
            { 1.975, hide = true },
        },
    },
} }

-- 17 (dancer_16): appears in a puff of smoke, wobbles and settles (on its routine frames);
-- dances an 8-beat routine; leaving, it bounces up and drops, a piece falling after it
SETS[16] = { default = {
    origin = { 152, 152 },
    at     = { 0, -90 },
    enter  = with({
        beats = 2,
        key = "loop",
        { 0.375, 0, 0, -90, key = "start" },
        { 0.8, 1 }, { 0.925, 2, -4, -90 },
        { 1.05, 3, -17, -107, to = { -18, -107, rot = -1 } },        -- wobbles
        { 1.1,  3, -19, -108, rot = -2, to = { -28, -111, rot = -10 } },
        { 1.3,  3, -26, -110, rot = -9, to = { -19, -108, rot = -1 } },
        { 1.45, 3, -17, -107 }, { 1.475, 4, -8, -97, rot = -10 },
        { 1.6, 5, 0, -90 }, { 1.775, 6, -3, -90 }, { 1.95, 7, 0, -90 },
    }, poof(0, 3, -137, "_poof")),
    dance  = steps({ { 7, 0.5 }, { 8, 0.25 }, { 9, 0.5 }, { 8, 0.25 }, { 7, 0.5 } },
                   { { 2, 0.25 }, { 10, 0.25 }, { 11, 0.25 }, { 12, 0.25 }, { 13, 0.75 } },
                   { { 14, 0.75 }, { 15, 0.25 }, { 16, 0.5 }, { 15, 0.25 }, { 14, 0.5 } },
                   { { 17, 0.25 }, { 3, 0.25 }, { 4, 0.25 }, { 18, 0.25 }, { 6, 0.75 }, { 7, 0.25 } }),
    leave  = {
        beats = 2,
        {
            { 0,    7, 0, -90, key = "loop" }, { 0.15, 6, -9, -90, key = "loop" },
            { 0.6,  0, 0, -97, to = { 0, -115 } },
            { 0.75, 1, 0, -119 },
            { 0.95, 2, 0, -135, to = { 0, -128 } },
            { 1.075, 3, 0, -120, to = { 0, -96 } },
            { 1.3,  5, 0, -93, to = { 0, -48 } },
            { 1.475, 6, 1, -46, to = { 1, 4 } },
            { 1.675, 3, 2, 13, rot = -5, to = { 2, 28 } },
            { 1.725, 3, 2, 43, rot = -5, to = { 2, 178 } },
            { 1.975, 3, 2, 193, rot = -5 },
        },
        { -- the piece that falls after it
            { 1.075, 4, 0, -126, to = { 0, 184, "in" } },
            { 1.825, hide = true },
        },
    },
} }

-- 04 (dancer_3): three different dancers bounce up from below and settle; each holds a pose,
-- swings up through eight frames (1.5 beats), holds, and swings back down (4 beats)
local function swing(hold, up, down)
    return steps({ { hold, 0.5 } }, up, { { hold, 0.5 } }, down)
end
SETS[3] = {
    [1] = {
        origin = { 152, 120 },
        at     = { 0, -74 },
        enter  = {
            beats = 2,
            { 0, 0, 0, 212, to = { 0, 34, "out" } }, { 0.25, 1, 0, -6, to = { 0, -50, "out" } },
            { 0.35, 2, 0, -83 }, { 0.45, 3, 2, -123 }, { 0.55, 7, 0, -128 },
            { 0.675, 5, 0, -124, rot = -3 }, { 0.8, 6, 0, -123 },
            { 0.925, 0, 0, -114 }, { 1.05, 1, 0, -103 }, { 1.15, 2, 0, -100 }, { 1.25, 3, 0, -74 },
            { 1.35, 8, 0, -70, sy = 0.95, to = { 0, -71, sy = 0.96 } },
            { 1.4,  8, 0, -73, sy = 0.98, to = { 0, -74, sy = 1 } },
            { 1.45, 8, 0, -74 },
        },
        dance  = swing(2,
            { { 10, 0.2 }, { 4, 0.2 }, { 5, 0.15 }, { 11, 0.2 }, { 12, 0.175 }, { 8, 0.175 }, { 13, 0.2 }, { 14, 0.2 } },
            { { 14, 0.2 }, { 13, 0.2 }, { 8, 0.2 }, { 12, 0.175 }, { 11, 0.2 }, { 5, 0.175 }, { 4, 0.175 }, { 10, 0.175 } }),
        leave  = {
            beats = 2,
            { 0, 2, 0, -74, key = "loop" },
            { 0.15, 0 }, { 0.3, 1 }, { 0.55, 1, 0, -70, sy = 0.95 }, { 0.7, 2, 0, -76 },
            { 0.875, 3, 0, -98 }, { 1.025, 4, 0, -116 }, { 1.125, 5, 0, -128 }, { 1.225, 5, 0, -133 },
            { 1.4, 6, 0, -105, to = { 0, 183, "in" } },
            { 1.925, hide = true },
        },
    },
    [0] = {
        origin = { 152, 120 },
        at     = { 0, -94 },
        enter  = {
            beats = 2,
            { 0, 0, -4, 160 }, { 0.15, 0, -4, 30 }, { 0.25, 1, -4, -50 }, { 0.35, 2, -4, -120 },
            { 0.45, 3, -4, -163 }, { 0.55, 4, -4, -170 }, { 0.65, 5, -4, -180 }, { 0.75, 6, -4, -170 },
            { 0.85, 7, -4, -165 }, { 0.95, 0, -4, -160 }, { 1.05, 1, -4, -147 }, { 1.15, 2, -4, -139 },
            { 1.25, 9, 0, -118 }, { 1.35, 10, 0, -104 }, { 1.475, 11, 0, -94 },
        },
        dance  = swing(2,
            { { 3, 0.15 }, { 4, 0.15 }, { 5, 0.175 }, { 6, 0.175 }, { 10, 0.15 }, { 8, 0.15 }, { 9, 0.175 },
              { 1, 0.175 }, { 0, 0.2 } },
            { { 0, 0.175 }, { 1, 0.15 }, { 9, 0.175 }, { 8, 0.15 }, { 10, 0.175 }, { 6, 0.175 }, { 5, 0.175 },
              { 4, 0.175 }, { 3, 0.15 } }),
        leave  = {
            beats = 2,
            {
                { 0, 2, 0, -94, key = "loop" },
                { 0.125, 0 }, { 0.25, 1 }, { 0.625, 2 }, { 0.775, 3, 0, -99 },
                { 0.85, 6, 0, -115, key = "start" }, { 0.95, 7, 0, -133, key = "start" },
                { 1.05, 0, 0, -151, key = "start" },
                { 1.15, 4, 0, -154 }, { 1.325, 5, 0, -125 },
                { 1.45, 6, 5, -54, to = { 5, 221 } },
                { 1.9, hide = true },
            },
            { { 1.45, 7, 0, -98, to = { 0, 212, "in" } } }, -- a piece drops away
        },
    },
    [2] = {
        origin = { 152, 152 },
        at     = { 0, -122 },
        enter  = {
            beats = 2,
            { 0, 0, 0, 168, to = { 0, -16, "out" } }, { 0.175, 0, 0, -16 }, { 0.25, 1, 0, -49 },
            { 0.35, 2, 0, -122 }, { 0.45, 3, 0, -165 }, { 0.55, 12, 0, -171 },
            { 0.65, 4, 0, -176, key = "loop" }, { 0.75, 5, 0, -178, key = "loop" },
            { 0.85, 13, 0, -171 }, { 0.95, 0, 0, -164 }, { 1.05, 1, 0, -149 }, { 1.15, 2, 0, -141 },
            { 1.25, 3, 0, -122 }, { 1.35, 12, 0, -122 }, { 1.425, 2, 0, -122, key = "loop" },
        },
        dance  = swing(2,
            { { 3, 0.2 }, { 10, 0.2 }, { 11, 0.15 }, { 6, 0.2 }, { 7, 0.175 }, { 8, 0.175 }, { 12, 0.2 }, { 0, 0.2 } },
            { { 0, 0.2 }, { 12, 0.2 }, { 8, 0.2 }, { 7, 0.175 }, { 6, 0.2 }, { 11, 0.175 }, { 10, 0.175 }, { 3, 0.175 } }),
        leave  = {
            beats = 2,
            { 0, 2, 0, -122, key = "loop" },
            { 0.15, 0 }, { 0.3, 1 }, { 0.6, 0 }, { 0.7, 2, 0, -126 }, { 0.85, 3, 0, -136 },
            { 0.925, 4, 0, -152 }, { 1.025, 5, 0, -172 }, { 1.125, 6, 0, -182 }, { 1.225, 7, 0, -184 },
            { 1.4, 8, 0, -158, to = { 0, -129 } }, { 1.525, 9, 0, -122, to = { 0, -61 } },
            { 1.65, 10, 0, -52, to = { 0, -22 } }, { 1.775, 11, 0, 18, to = { 0, 68 } },
            { 1.875, 9, 0, 144, to = { 0, 202 } }, { 1.95, 11, 0, 231 },
            { 1.975, hide = true },
        },
    },
}

-- 05 (dancer_4): set 04's dancers on their own frames: they bounce up from below and settle,
-- dance a 2-beat routine and hop up and drop away
-- ten routine frames from `first`, quick in the middle
local function loop_run(first)
    local out = {}
    for i, b in ipairs({ 0.25, 0.2, 0.15, 0.15, 0.15, 0.15, 0.25, 0.15, 0.15, 0.15 }) do
        table.insert(out, { first + i - 1, b })
    end
    return out
end
SETS[4] = {
    [1] = {
        origin = { 152, 152 },
        at     = { 0, -119 },
        enter  = {
            beats = 2,
            { 0, 0, 0, 139, to = { 0, -10, "out" } }, { 0.25, 1, 0, -50, to = { 0, -94, "out" } },
            { 0.35, 2, 0, -127 }, { 0.45, 3, 2, -167 }, { 0.55, 4, 0, -172 },
            { 0.675, 5, 0, -168, rot = -3 }, { 0.8, 6, 0, -167 },
            { 0.925, 0, 0, -158 }, { 1.05, 1, 0, -147 }, { 1.15, 2, 0, -144 }, { 1.25, 3, 0, -119 },
            { 1.35, 7, 1, -114, sy = 0.95, to = { 0, -119, sy = 1 } }, { 1.45, 7, 0, -119 },
        },
        dance  = steps({ { 7, 0.25, key = "start" } }, loop_run(0)),
        leave  = {
            beats = 2,
            { 0, 7, 0, -119, key = "start" }, { 0.15, 0 }, { 0.3, 1 }, { 0.55, 1, 0, -113, sy = 0.95 },
            { 0.7, 2, 0, -121 }, { 0.875, 3, 0, -143 }, { 1.025, 4, 0, -161 }, { 1.125, 5, 0, -173 },
            { 1.225, 5, 0, -178 }, { 1.4, 5, 0, -150, to = { 0, 18, "in" } },
            { 1.925, hide = true },
        },
    },
    [0] = {
        origin = { 144, 148 },
        at     = { 0, -119 },
        enter  = {
            beats = 2,
            { 0, 0, 0, 21 }, { 0.15, 0, 0, -9 }, { 0.25, 1, 0, -49 }, { 0.35, 2, 0, -119 },
            { 0.45, 3, 0, -162 }, { 0.55, 4, 0, -169 }, { 0.65, 5, 0, -179 }, { 0.75, 6, 0, -169 },
            { 0.85, 7, 0, -164 }, { 0.95, 0, 0, -159 }, { 1.05, 1, 0, -146 }, { 1.15, 2, 0, -138 },
            { 1.25, 8, 0, -119 }, { 1.45, 9 }, { 1.575, 10 },
        },
        dance  = steps({ { 10, 0.25, key = "start" } }, loop_run(0)),
        leave  = {
            beats = 2,
            {
                { 0, 10, 0, -119, key = "start" }, { 0.125, 0 }, { 0.25, 1 }, { 0.625, 2 },
                { 0.775, 3, 0, -124 }, { 0.85, 4, 0, -170 }, { 0.95, 5, 0, -188 }, { 1.05, 6, 0, -206 },
                { 1.15, 7, 0, -179 }, { 1.325, 8, 0, -150 },
                { 1.45, 9, 0, -109, to = { 0, 166 } },
                { 1.9, hide = true },
            },
            { { 1.45, 10, 0, -123, to = { 0, 187, "in" } } }, -- a piece drops away
        },
    },
    [2] = {
        origin = { 168, 160 },
        at     = { 0, -109 },
        enter  = {
            beats = 2,
            { 0, 0, 0, 181, to = { 0, -3, "out" } }, { 0.175, 0, 0, -3 }, { 0.25, 1, 0, -36 },
            { 0.35, 2, 0, -109 }, { 0.45, 3, 0, -152 }, { 0.55, 4, 0, -158 }, { 0.65, 5, 0, -163 },
            { 0.75, 6, 0, -165 }, { 0.85, 7, 0, -158 }, { 0.95, 0, 0, -151 }, { 1.05, 1, 0, -136 },
            { 1.15, 2, 0, -128 }, { 1.25, 3, 0, -109 }, { 1.35, 4 }, { 1.425, 8 },
        },
        dance  = steps({ { 0, 0.25 } }, loop_run(1)),
        leave  = {
            beats = 2,
            { 0, 0, 0, -109 }, { 0.15, 1 }, { 0.3, 2 }, { 0.6, 1 }, { 0.7, 3, 0, -113 },
            { 0.85, 4, 0, -123 }, { 0.925, 5, 0, -139 }, { 1.025, 6, 0, -159 }, { 1.125, 7, 0, -169 },
            { 1.225, 8, 0, -171 }, { 1.4, 9, 0, -145, to = { 0, -116 } },
            { 1.525, 10, 0, -109, to = { 0, -38 } }, { 1.65, 11, 0, -29, to = { 0, -9 } },
            { 1.775, 12, 0, 31, to = { 0, 81 } }, { 1.875, 10, 0, 157, to = { 0, 195 } },
            { 1.95, 12, 0, 214 },
            { 1.975, hide = true },
        },
    },
}

-- 01-03 (dancer_0..2): five dancers. Each set's routine (16 beats): sway (0 1 2 1 0 1 2),
-- a short turn (`tail`), eight half-beat poses, then two quick wiggles, twice.
local function wiggle(a, b, c)
    return { { a, 0.25 }, { b, 0.25 }, { c, 0.25 }, { b, 0.25 }, { a, 0.2 }, { b, 0.2 }, { c, 0.2 }, { b, 0.2 }, { a, 0.2 } }
end
local function routine(tail, poses, w1, w2)
    return steps({ { 0, 0.5 }, { 1, 0.5 }, { 2, 0.5 }, { 1, 0.5 }, { 0, 0.5 }, { 1, 0.5 }, { 2, 0.25 } }, tail,
                 halves(table.unpack(poses)), wiggle(table.unpack(w1)), wiggle(table.unpack(w2)),
                 wiggle(table.unpack(w1)), wiggle(table.unpack(w2)))
end

-- the outer pair (keys 0, 1): shoot up, land with a squash; leaving, rise and drop.
-- leave_x: where they stand while rising (key 1 rises a little to the left)
local function outer(leave_x)
    return {
        origin = { 100, 116 },
        at     = { -20, -134 },
        enter  = {
            beats = 2,
            { 0,   0, -20, 186, to = { -20, -214, "out" } },
            { 0.8, 0, -20, -212, to = { -20, -146, "in" } },
            { 1.2, 1, -20, -134, to = { -20, -124, sy = 0.9 } },
            { 1.3, 1, -20, -127, sy = 0.93, to = { -20, -134, sy = 1 } },
            { 1.375, 1, -20, -134 }, { 1.5, 2 }, { 1.6, 3 }, { 1.725, 4 },
        },
        dance  = routine({ { 3, 0.25 }, { 9, 0.25 }, { 7, 0.25 } }, { 4, 5, 6, 5, 4, 5, 6, 7 }, { 8, 9, 10 }, { 11, 12, 13 }),
        leave  = {
            beats = 2,
            { 0,     9, leave_x, -134, key = "loop" },
            { 0.1,   0, leave_x, -150, to = { leave_x, -213 } },
            { 0.425, 0, leave_x, -210, to = { leave_x, -156 } },
            { 0.975, 1, -20, -120 }, { 1.05, 2, -20, -117 },
            { 1.125, 3, -20, -110, to = { -20, 81 } },
            { 1.35, hide = true },
        },
    }
end

-- key 2: jumps up from below, lands squashed; leaving, jumps and falls. Stands at x, y0;
-- `squash`/`settle` are the frames it lands and settles on, `last` the one it leaves from
local function inner(x, y0, squash, settle, last, tail, poses)
    return {
        origin = { 128, 144 },
        at     = { x, y0 },
        enter  = {
            beats = 2,
            { 0,     0, x, y0 + 330, to = { x, y0 - 60, "out" } },
            { 0.925, 1, x, y0 - 60, to = { x, y0 - 6, "in" } },
            { 1.45,  squash[1], x, y0, key = squash.key, to = { x, y0 + 6, sy = 0.93 } },
            { 1.55,  squash[1], x, y0 + 4, key = squash.key, sy = 0.95, to = { x, y0, sy = 1 } },
            { 1.625, squash[1], x, y0, key = squash.key },
            { 1.675, settle[1], x, y0, key = settle.key },
        },
        dance  = routine(tail, poses, { 9, 10, 11 }, { 12, 13, 14 }),
        leave  = {
            beats = 2,
            { 0,   last[1], x, y0, key = last.key },
            { 0.1, 0, x, y0, to = { x, y0 - 60, "out" } },
            { 0.5, 0, x, y0 - 60, to = { x, y0 + 361, "in" } },
            { 1.45, hide = true },
        },
    }
end

-- key 3: springs up, hangs, and lands with a squash; leaving, jumps and falls
local function flyer(tail, poses)
    return {
        origin = { 116, 132 },
        at     = { -23, -147 },
        enter  = {
            beats = 2,
            { 0,     0, -23, 173, to = { -23, -196, "out" } },
            { 0.65,  1, -23, -197, to = { -23, -221 } },
            { 0.775, 2, -23, -227, to = { -23, -209 } },
            { 1.075, 1, -23, -207, to = { -23, -159 } },
            { 1.2,   0, -23, -147, to = { -23, -141, sy = 0.93 } },
            { 1.3,   0, -23, -143, sy = 0.95, to = { -23, -147, sy = 1 } },
            { 1.375, 0, -23, -147 },
        },
        dance  = routine(tail, poses, { 9, 10, 11 }, { 12, 13, 14 }),
        leave  = {
            beats = 2,
            { 0,   0, -23, -147, key = "start" },
            { 0.1, 0, -23, -147, to = { -23, -207, "out" } },
            { 0.5, 0, -23, -207, to = { -23, 174, "in" } },
            { 1.45, hide = true },
        },
    }
end

-- key 4, in the centre: hops up while a ball drops onto its head; the ball bounces behind it
-- every beat for the first 8 beats of the routine; leaving, it jumps and the ball flies off
local function bounce(beat, frame, x, y)
    return {
        { beat, frame, x, y },
        { beat + 0.325, frame, x, y + 1, to = { x, y + 5 } },
        { beat + 0.425, frame, x, y + 5 },
        { beat + 0.475, frame, x, y + 2, to = { x, y - 33 } },
        { beat + 0.75,  frame, x, y - 30, to = { x, y } },
    }
end
local BALL = concat(bounce(0, 15, -17, -126), bounce(1, 15, -17, -126), bounce(2, 15, -17, -126),
    { { 3, 15, -17, -126 }, { 3.25, 15, -10, -128 }, { 3.475, 16, -14, -128 }, { 3.725, 17, -19, -127 } },
    bounce(4, 17, -11, -125), bounce(5, 17, -11, -125), bounce(6, 17, -11, -125),
    { { 7, 17, -11, -125 }, { 7.5, 17, -18, -129 }, { 8, hide = true } })
BALL.length = 16
local JUGGLER = {
    origin = { 92, 112 },
    at     = { -15, -126 },
    enter  = {
        beats = 2,
        {
            { 0,     0, -15, -44, to = { -15, -170 } }, { 0.375, 1, -15, -170, to = { -15, -202 } },
            { 0.5,   2, -15, -210, to = { -15, -224 } }, { 0.625, 3, -15, -228 },
            { 0.75,  4, -15, -228, to = { -15, -218 } }, { 0.875, 5, -15, -215, to = { -15, -159 } },
            { 1.1,   0, -15, -152, to = { -15, -135 } },
            { 1.2,   6, -15, -129, to = { -15, -128, sy = 0.95 } },
            { 1.275, 6, -15, -128, sy = 0.97, to = { -15, -129, sy = 1 } }, { 1.35, 6, -15, -129 },
        },
        { -- the ball drops in, lands on its head and bounces to rest
            { 0.9,   7, -15, -390, alpha = 0, to = { -15, -127, alpha = 1 } },
            { 1.275, 7, -15, -127, sy = 0.99, to = { -15, -125, sy = 0.95 } },
            { 1.375, 7, -15, -142, sy = 0.96, to = { -15, -245, sy = 0.99 } },
            { 1.6,   7, -15, -245 }, { 1.65, 7, -15, -235, to = { -15, -222 } },
            { 1.775, 7, -15, -219, to = { -15, -216 } }, { 1.825, 7, -15, -216 },
        },
    },
    dance  = { BALL, routine({ { 3, 0.225 }, { 4, 0.25 }, { 8, 0.275 } }, { 5, 6, 7, 6, 5, 6, 7, 8 },
                             { 9, 10, 11 }, { 12, 13, 14 }) },
    leave  = {
        beats = 2,
        {
            key = "start",
            { 0, 6, -15, -129 },
            { 0.1,   0, -15, -143, to = { -15, -160 } },
            { 0.525, 5, -15, -161, to = { -15, -227, "out" } },
            { 0.825, 5, -15, -227, to = { -15, 89, "in" } },
            { 1.45, hide = true },
        },
        { -- the ball flies up and drops away
            { 0,     7, -15, -187, key = "start", to = { -15, -281 } },
            { 0.475, 0, -42, -290, to = { -42, -334, "out", sy = 0.95 } },
            { 0.875, 0, -42, -334, sy = 0.95, to = { -42, -324, "in" } },
            { 1.075, 7, -15, -301, key = "start", to = { -15, 54, "in" } },
            { 1.45, hide = true },
        },
    },
}

local FLYER_0 = flyer({ { 3, 0.225 }, { 4, 0.25 }, { 8, 0.275 } }, { 5, 6, 7, 6, 5, 6, 5, 8 })
local FLYER_12 = flyer({ { 3, 0.225 }, { 4, 0.25 }, { 5, 0.275 } }, { 6, 7, 8, 7, 6, 7, 6, 5 })
SETS[0] = {
    [0] = outer(-20), [1] = outer(-30), [3] = FLYER_0, [4] = JUGGLER,
    [2] = inner(-13, -160, { 4, key = "loop" }, { 2, key = "start" }, { 2, key = "start" },
                { { 3, 0.225 }, { 2, 0.25, key = "start" }, { 8, 0.275 } }, { 5, 6, 7, 6, 5, 6, 7, 8 }),
}
SETS[1] = {
    [0] = outer(-20), [1] = outer(-30), [3] = FLYER_12, [4] = JUGGLER,
    [2] = inner(-28, -165, { 4, key = "loop" }, { 4, key = "loop" }, { 4, key = "loop" },
                { { 3, 0.225 }, { 4, 0.25 }, { 5, 0.275 } }, { 6, 7, 8, 7, 6, 7, 8, 5 }),
}
SETS[2] = {
    [0] = outer(-20), [1] = outer(-30), [3] = FLYER_12, [4] = JUGGLER,
    [2] = inner(-26, -168, { 2, key = "start" }, { 4, key = "loop" }, { 4, key = "loop" },
                { { 3, 0.225 }, { 4, 0.25 }, { 5, 0.275 } }, { 6, 7, 8, 7, 6, 7, 8, 5 }),
}

return SETS
