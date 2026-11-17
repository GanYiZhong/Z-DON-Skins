local function clamp01(v)
    return math.max(0, math.min(1, v))
end

local function lerp(a, b, q)
    return a + (b - a) * clamp01(q)
end

-- 1 -> 0.9 -> 1 every `period` frames
local function pulse(f, period)
    return 1 - 0.1 * (1 - math.abs(2 * (f % period) / period - 1))
end

-- Scylla
local BUBBLES_A = {
    { "bubble_big", 0, 155, 166, 0, 329, -16, -305, -9, -349, 1 },
    { "bubble_small", 19, 155, 166, 0, 329, -25, -217, -18, -266, 1 },
    { "bubble_heart", 7, 140, 166, 0, 328, -25, -174, -32, -283, 0.85 },
    { "bubble_big", 21, 165, 176, 0, 461, -18, -279, -10, -340, 1 },
    { "bubble_small", 54, 175, 186, 5, 348, -23, -217, -11, -278, 0.85 },
    { "bubble_small", 25, 175, 186, -16, 402, 64, -269, 49, -316, 1 },
    { "bubble_small", 21, 165, 178, -23, 354, 51, -316, 21, -380, 0.9 },
    { "bubble_specks", 71, 181, nil, 2, 342, 42, -247 },
    { "bubble_specks", 43, 153, nil, -67, 379, -27, -210 },
}
local BUBBLES_B = {
    { "bubble_heart", 0, 104, 115, 0, 329, -16, -306, -8, -353, 1 },
    { "bubble_small", 18, 104, 115, 0, 329, -25, -217, -18, -266, 1 },
    { "bubble_heart_small", 4, 104, 115, 13, 346, -39, -268, -13, -310, 1 },
    { "bubble_heart", 8, 104, 115, 13, 346, -55, -215, -42, -261, 1 },
    { "bubble_heart", 20, 114, 125, 0, 461, -18, -279, -10, -340, 1 },
    { "bubble_small", 53, 124, 135, 5, 348, -23, -217, -11, -278, 0.85 },
    { "bubble_heart_small", 24, 124, 135, -16, 402, 64, -269, 49, -316, 1 },
    { "bubble_small", 20, 114, 127, -23, 354, 51, -316, 21, -380, 0.9 },
    { "bubble_specks", 70, 130, nil, 2, 342, 42, -247 },
    { "bubble_specks", 43, 103, nil, -67, 379, -27, -210 },
}
local BUBBLE_GROUPS = { a = { BUBBLES_A, 189 }, b = { BUBBLES_B, 139 } }

local function bubbles(o, set, g, x, y, s, fade)
    for _, b in ipairs(set) do
        local f = g - b[2]
        if f >= 0 then
            local bx, by, alpha
            if not b[4] then
                local q = f / (b[3] - b[2])
                if q < 1 then bx, by, alpha = lerp(b[5], b[7], q), lerp(b[6], b[8], q), 1 - q end
            elseif g < b[3] then
                local q = f / (b[3] - b[2])
                bx, by, alpha = lerp(b[5], b[7], q), lerp(b[6], b[8], q), clamp01(f / 6)
            elseif g < b[4] then
                local q = (g - b[3]) / (b[4] - b[3])
                bx, by, alpha = lerp(b[7], b[9], q), lerp(b[8], b[10], q), 0.918 * (1 - q)
            end
            if bx then
                local k = s * (b[11] or 1) * pulse(f, 20)
                o:spr("scylla_" .. b[1], x + bx * s, y + by * s, { s = k, fade = alpha * fade })
            end
        end
    end
end

-- groups: { group, frame, x, y, scale } around the pattern's origin
local function bubble_pattern(len, ox, oy, groups)
    return {
        len = len,
        draw = function(o, f, fade)
            for _, g in ipairs(groups) do
                local set = BUBBLE_GROUPS[g[1]]
                local gf = f - g[2]
                if gf >= 0 and gf < set[2] then
                    if gf < 1 then o:cue_once(g, "se_scylla_bubble") end
                    bubbles(o, set[1], gf, ox + g[3], oy + g[4], g[5] or 1, fade)
                end
            end
        end,
    }
end

-- an ink splat pops in over two frames, holds and fades over nine: key, frame, x, y, x-scale, y-scale
local function splats(o, parts, f, hold, x, y, fade)
    for _, p in ipairs(parts) do
        local g = f - p[2]
        if g >= 0 and f < hold + 9 then
            local pop = g < 2 and lerp(0.15, 1.1, g / 2) or g < 3 and 1.05 or 1
            local alpha = f < hold and 1 or 0.891 * (1 - (f - hold) / 9)
            o:spr("scylla_" .. p[1], x + p[3], y + p[4], { sx = p[5] * pop, sy = p[6] * pop, fade = alpha * fade })
        end
    end
end

local INK = {
    pair = { 104, { { "ink_magenta", 0, -16, -24, 1, 1 }, { "ink_drops_pink", 2, -16, -24, 1.159, 1 } } },
    purple = { 69, { { "ink_purple", 1, 200, 112, 1, 1 } } },
    blue = { 79, { { "ink_blue", 0, -360, 130, 1, 1 } } },
    pink = { 109, { { "ink_pink", 0, -360, 130, 1, 1 }, { "ink_drops", 2, -360, 130, 0.767, 0.767 } } },
    skull = { 160, {
        { "ink_skull", 0, 0, 0, 1, 1 }, { "ink_skull_drops", 5, 0, 0, 1, 1 },
        { "ink_pink", 16, -361, 168, 0.767, 0.767 }, { "ink_drops", 18, -366, 165, 0.767, 0.767 },
        { "ink_purple", 22, 235, -163, 1, 1 }, { "ink_drops_purple", 22, 232, -161, 0.744, 0.744 },
    } },
}

-- inks: { ink, frame, x, y } around the pattern's origin
local function ink_pattern(len, ox, oy, inks)
    return {
        len = len,
        draw = function(o, f, fade)
            for _, i in ipairs(inks) do
                local ink = INK[i[1]]
                local g = f - i[2]
                if g >= 0 then
                    if g >= 1 then o:cue_once(i, i[1] == "skull" and "se_scylla_ink_big" or "se_scylla_ink") end
                    splats(o, ink[2], g, ink[1], ox + i[3], oy + i[4], fade)
                end
            end
        end,
    }
end

local SCYLLA = {
    normal = {
        events = { { 60, 1 }, { 585, 2 }, { 900, 3 }, { 1500, 0 } },
        sounds = { { "vo_scylla_disturb_1" }, { "vo_scylla_disturb_1" },
            { "vo_scylla_disturb_2", "se_scylla_bubble_big" } },
        fade = 25,
        pats = {
            bubble_pattern(443, 978, 151, { { "a", 1, -239, 280 }, { "a", 109, 128, 280 }, { "a", 246, -327, 156 } }),
            bubble_pattern(242, 974, 222, { { "a", 1, 193, 210 }, { "a", 49, -217, 158, 0.625 } }),
            bubble_pattern(561, 998, 103, {
                { "b", 1, 168, 328 }, { "a", 15, 233, 145, 1.75 }, { "a", 44, 348, 918 }, { "a", 49, -225, 277, 1.5 },
                { "a", 53, 144, 1142 }, { "a", 70, 184, 452 }, { "b", 92, -237, 90 }, { "a", 116, -362, -7, 1.25 },
                { "b", 128, 158, 164, 1.5 }, { "b", 137, -317, 138 },
            }),
        },
    },
    gogo = {
        events = { { 60, 1 }, { 300, 2 }, { 520, 3 }, { 705, 4 }, { 905, 0 } },
        sounds = { { "vo_scylla_disturb_3" } },
        fade = 174,
        pats = {
            ink_pattern(170, 993, 273, { { "skull", 0, 0, 0 } }),
            ink_pattern(124, 945, 193, { { "pink", 1, 89, 96 }, { "pair", 10, 60, -5 }, { "purple", 23, 92, 46 } }),
            ink_pattern(119, 1012, 218, {
                { "pair", 1, 180, 213 }, { "blue", 15, 464, -192 }, { "purple", 22, -250, 14 },
                { "pair", 39, -251, -67 },
            }),
            ink_pattern(119, 920, 208, { { "pair", 1, -64, -84 }, { "purple", 15, -31, -83 } }),
        },
    },
}

-- Ghost Wood

local function ease_in(q)
    q = clamp01(q)
    return q * q
end

-- the chick sits on the lane, blinking, with an anger mark that throbs twice every 100 frames
local function chick(o, f, x, y, sy, rot, fade)
    local c = f % 100
    local blink = (c >= 49 and c < 58) or (c >= 67 and c < 76)
    o:spr(blink and "wood_chick_blink" or "wood_chick", x, y, { sy = sy, rot = rot, fade = fade })
    local throb = 1
    for _, at in ipairs({ 20, 30, 80, 90 }) do
        local u = c - at
        if u >= 0 and u < 10 then
            throb = u < 5 and lerp(1.1, 1.5, u / 4) or u < 8 and lerp(1.4, 1.2, (u - 5) / 2) or lerp(1.1, 1, u - 8)
        end
    end
    o:spr("wood_chick_anger", x + 2, y - 28, { s = throb, rot = rot, fade = fade })
end

-- normal chicks drop onto the lane, sit, then hop off down to the left; `slide` ones skid left first
local function chick_drop(slide)
    return function(f)
        if f < 30 then return 299, lerp(-254, 126, f / 29), lerp(1, 0.9, f / 29), 0, 1 end
        if f < 36 then return 299, lerp(125, 123, (f - 30) / 5), lerp(0.92, 1, (f - 30) / 5), 0, 1 end
        if f < 120 then return 299, 123, 1, 0, 1 end
        if f < 142 then
            local q = ease_in((f - 120) / 19)
            return lerp(299, 204, q), lerp(123, 54, q), lerp(1, 1.057, q), 0, 1
        end
        -- the hop off: fast sideways, falling ever faster
        if not slide then
            if f < 186 then
                local u = clamp01((f - 142) / 43)
                return lerp(190, 65, 1 - (1 - u) ^ 2), lerp(55, 304, u ^ 1.5), 1.03, 0, 1
            end
            local q = (f - 186) / 12
            return lerp(64, 55, q), lerp(312, 398, q), 1, 0, 0.92 * (1 - q)
        end
        if f < 183 then
            local u = clamp01((f - 142) / 40)
            return lerp(190, 65, 1 - (1 - u) ^ 2), lerp(55, 301, u ^ 1.5), 1.03, 0, 1
        end
        if f < 207 then
            local q = (f - 183) / 23
            return lerp(60, -92, q), lerp(296, 264, q) - 40 * math.sin(math.pi * q), 1, 0, 1
        end
        local q = ease_in((f - 207) / 36)
        return lerp(-96, -180, q), lerp(267, 441, q), 1, 0, 0.973 * (1 - q)
    end
end

-- gogo chicks shoot in from the upper right, bounce, then spin off down the lane
local function chick_spin(f)
    if f < 10 then return lerp(465, 299, f / 9), lerp(-66, 123, f / 9), 1, 0, 1 end
    if f < 15 then return 299, lerp(125, 129, (f - 10) / 4), lerp(0.96, 0.8, (f - 10) / 4), 0, 1 end
    if f < 20 then return 299, lerp(121, 86, (f - 15) / 4), lerp(0.9, 1.3, (f - 15) / 4), 0, 1 end
    if f < 25 then return 299, lerp(94, 123, (f - 20) / 4), lerp(1.24, 1, (f - 20) / 4), 0, 1 end
    if f < 101 then return 299, 123, 1, 0, 1 end
    if f < 128 then
        local q = (f - 101) / 27
        return lerp(298, 207, q), lerp(119, 54, q) - 20 * math.sin(math.pi * q), 1, -360 * q, 1
    end
    if f < 166 then
        local q = ease_in((f - 128) / 37)
        return lerp(207, 135, q), lerp(54, 303, q), 1, -80 * q, 1
    end
    local q = (f - 166) / 17
    return lerp(135, 141, q), lerp(310, 437, q), 1, lerp(-80, -105, q), f < 171 and 1 or lerp(0.92, 0, (f - 171) / 12)
end

local function chick_pattern(len, x, y, path, land)
    return {
        len = len,
        draw = function(o, f, fade)
            if f >= land then o:cue_once(path, "se_wood_chick") end
            local cx, cy, sy, rot, alpha = path(f)
            chick(o, f, x + cx, y + cy, sy, rot, alpha * fade)
        end,
    }
end

local DROP, SKID = chick_drop(false), chick_drop(true)

local GHOST_WOOD = {
    normal = {
        events = { { 60, 2 }, { 205, 3 }, { 235, 1 }, { 435, 5 }, { 640, 1 }, { 670, 3 }, { 875, 0 } },
        sounds = {},
        fade = 25,
        pats = {
            chick_pattern(206, 582, 27, DROP, 29), chick_pattern(206, 712, 25, DROP, 29),
            chick_pattern(206, 843, 27, DROP, 29), chick_pattern(206, 600, 27, DROP, 29),
            chick_pattern(245, 728, 25, SKID, 29), chick_pattern(206, 863, 27, DROP, 29),
        },
    },
    gogo = {
        events = { { 0, 3 }, { 10, 2 }, { 20, 1 }, { 205, 0 } },
        sounds = {},
        fade = 25,
        pats = {
            chick_pattern(185, 527, 28, chick_spin, 9), chick_pattern(185, 697, 28, chick_spin, 9),
            chick_pattern(185, 867, 28, chick_spin, 9),
        },
    },
}

-- Basilisk

-- a rock tumbles through its points { frame, x, y }: in on a straight line, then hopping between the rest (an arc
-- a third as high as it is long), fading over the last; it spins `spin` degrees a frame
local function tumble(o, key, s, spin, pts, f, x, y, fade, mirror)
    if f < pts[1][1] or f >= pts[#pts][1] then return end
    local i = 1
    while pts[i + 1][1] <= f do i = i + 1 end
    local a, b = pts[i], pts[i + 1]
    local u = (f - a[1]) / (b[1] - a[1])
    local rx, ry = lerp(a[2], b[2], u), lerp(a[3], b[3], u)
    if i > 1 and i < #pts - 1 then ry = ry - math.abs(b[2] - a[2]) / 3 * math.sin(math.pi * u) end
    local alpha = i == #pts - 1 and 1 - u or 1
    if mirror then rx = -rx end
    o:spr("basil_" .. key, x + rx, y + ry, { s = s, rot = spin * (f - pts[1][1]), fade = alpha * fade })
end

-- a dust puff grows and fades: frame, x, y, scale from, to, frames
local function puff(o, key, d, f, x, y, fade, mirror)
    local u = (f - d[1]) / d[6]
    if u < 0 or u >= 1 then return end
    local dx = mirror and -d[2] or d[2]
    o:spr("basil_" .. key, x + dx, y + d[3], { s = lerp(d[4], d[5], u), fade = (1 - u) * fade })
end

-- rocks: { key, scale, spin, points }, dusts: { frame, x, y, from, to, frames }
local function rockfall(len, ox, oy, rocks, dusts, dust_key)
    return {
        len = len,
        draw = function(o, f, fade, x, y, mirror)
            x, y = (x or 0) + ox, (y or 0) + oy
            for _, d in ipairs(dusts or {}) do puff(o, dust_key or "dust", d, f, x, y, fade, mirror) end
            for _, r in ipairs(rocks) do tumble(o, r[1], r[2], r[3], r[4], f, x, y, fade, mirror) end
        end,
    }
end

local BASIL_NORMAL = {
    rockfall(160, 22, -25, {
        { "rock", 1, -9, { { 0, 1329, 112 }, { 44, 975, 358 }, { 65, 856, 344 }, { 91, 731, 348 }, { 105, 657, 342 },
            { 117, 589, 416 } } },
        { "rock_small", 1, -6, { { 91, 1224, 21 }, { 113, 1034, 351 }, { 140, 742, 310 }, { 148, 686, 400 } } },
        { "rock_mid", 0.875, -7, { { 83, 1353, 226 }, { 134, 694, 348 }, { 144, 631, 327 }, { 158, 541, 354 } } },
    }, { { 43, 980, 365, 0.4, 1.25, 18 }, { 134, 694, 353, 0.5, 1.26, 21 } }),
    rockfall(107, 5, -17, {
        { "rock_small", 1, 6, { { 29, 1523, 249 }, { 68, 918, 319 }, { 82, 768, 315 }, { 93, 678, 317 },
            { 105, 570, 376 } } },
        { "rock", 1, 6, { { 0, 1347, 238 }, { 52, 894, 343 }, { 70, 784, 342 }, { 80, 698, 349 }, { 90, 645, 420 } } },
    }, { { 53, 894, 351, 0.5, 1.08, 18 } }),
    rockfall(144, 36, 4, {
        { "bird", 1, 0, { { 0, 1327, 287 }, { 37, 1202, 214 }, { 94, 991, 300 }, { 113, 917, 281 },
            { 141, 730, 451 } } },
        { "rock", 1, 0, { { 92, 1317, 10 }, { 113, 928, 254 }, { 135, 506, -104 } } },
        { "rock_small", 1, -5, { { 50, 1214, -32 }, { 78, 929, 317 }, { 100, 731, 321 }, { 124, 534, 379 } } },
    }),
    rockfall(136, -45, -4, {
        { "rock_mid", 1, -5, { { 38, 1231, -60 }, { 82, 939, 322 }, { 106, 742, 325 }, { 133, 481, 386 } } },
        { "rock_small", 1, 0, { { 14, 1119, -45 }, { 52, 966, 319 }, { 76, 682, 328 }, { 91, 562, 443 } } },
        { "rock", 1, -3, { { 0, 1408, 233 }, { 52, 836, 320 }, { 98, 610, 478 } } },
    }),
}

local RAIN = rockfall(90, 0, 0, {
    { "rock_small", 1, 0, { { 0, 751, -83 }, { 24, 751, 353 }, { 38, 501, 108 }, { 50, 318, 182 } } },
    { "rock_mid", 1, 0, { { 42, 701, -156 }, { 68, 701, 344 }, { 76, 606, 307 }, { 86, 487, 427 } } },
    { "rock", 1, 4, { { 0, 849, -172 }, { 25, 849, 309 }, { 45, 1063, 315 }, { 57, 1094, 397 } } },
    { "rock", 1, -3, { { 45, 931, -86 }, { 65, 931, 322 }, { 71, 871, 328 }, { 89, 716, 466 } } },
}, { { 24, 750, 359, 1, 1.7, 15 }, { 28, 857, 338, 1, 2.275, 20 }, { 68, 915, 364, 1, 2.275, 9 },
    { 68, 701, 341, 1, 1.337, 12 } }, "dust_alt")
local BOULDER = rockfall(169, 0, 0, {
    { "rock_big", 1, -5, { { 0, -150, -310 }, { 42, -151, 405 }, { 58, -329, 378 }, { 74, -501, 534 } } },
    { "rock_big", 1, 6, { { 62, -155, -35 }, { 89, -156, 449 }, { 101, -292, 438 }, { 120, -442, 599 } } },
}, { { 42, -150, 400, 2.086, 2.175, 37 }, { 89, -56, 465, 1.528, 2.175, 37 } }, "dust_alt")
local BOULDER_LATE = rockfall(169, 0, 0, {
    { "rock_big", 1, 6, { { 62, -155, -35 }, { 89, -156, 449 }, { 101, -292, 438 }, { 120, -442, 599 } } },
    { "rock_big_alt", 1, 3, { { 96, -64, -324 }, { 121, -64, 448 }, { 127, 39, 377 }, { 145, 260, 664 } } },
}, { { 81, -56, 465, 1.528, 2.175, 47 } }, "dust_alt")

-- copies of a part at frames and offsets: { part, frame, x, y, mirror }
local function sequence(len, ox, oy, items)
    return {
        len = len,
        draw = function(o, f, fade)
            for _, it in ipairs(items) do
                local g = f - it[2]
                if g >= 0 and g < it[1].len then it[1].draw(o, g, fade, ox + it[3], oy + it[4], it[5]) end
            end
        end,
    }
end

local BASILISK = {
    normal = {
        events = { { 60, 1 }, { 205, 2 }, { 345, 4 }, { 350, 2 }, { 515, 3 }, { 675, 2 } },
        sounds = { { "se_basil_rock" }, { "se_basil_rock" }, { "se_basil_rock" }, {}, { "se_basil_rock" } },
        fade = 25,
        pats = BASIL_NORMAL,
    },
    gogo = {
        events = { { 0, 1 }, { 175, 2 }, { 360, 0 } },
        sounds = { { "se_basil_rock_big" }, { "se_basil_rock_big" } },
        fade = 25,
        pats = {
            sequence(139, -29, 5, { { RAIN, 0, -11, -16 }, { RAIN, 14, 132, -16 }, { RAIN, 50, 1929, -23, true } }),
            sequence(351, -12, 5, {
                { RAIN, 0, -11, -16 }, { RAIN, 23, 132, -16 }, { RAIN, 150, -11, -16 },
                { BOULDER, 16, 1101, -123 }, { BOULDER, 60, 993, -117, true }, { BOULDER_LATE, 132, 996, -117 },
            }),
        },
    },
}

-- Phoenix

-- draws through a rotation by `ang` degrees about the local origin, then a move to (x, y)
local function turned(o, x, y, ang)
    local r = math.rad(ang)
    local c, sn = math.cos(r), math.sin(r)
    return {
        spr = function(_, key, px, py, t)
            t = t or {}
            t.rot = (t.rot or 0) + ang
            o:spr(key, x + px * c - py * sn, y + px * sn + py * c, t)
        end,
        cue_once = function(_, k, n) o:cue_once(k, n) end,
    }
end

local function fireball(o, f, x, y, s, rot, fade)
    o:spr(f % 6 < 3 and "phoenix_fireball" or "phoenix_fireball_alt", x, y, { s = s, rot = rot, fade = fade })
end

-- four flame frames cross-fade every 32 frames; the flames stand on (x, y)
local FLAME_KEYS = { "phoenix_flame_low", "phoenix_flame_wide", "phoenix_flame_tall", "phoenix_flame_bits" }
local function flames(o, f, x, y, s, fade)
    local c = f % 32
    local w = { c < 9 and 0.855 or 0.855 * (1 - (c - 9) / 7), c < 9 and c / 8 or (c < 17 and 1 or 0),
        c >= 8 and (c < 17 and (c - 8) / 8 or 0.875 * (1 - (c - 17) / 8)) or 0,
        c >= 16 and (c < 25 and (c - 16) / 8 or 0.855 * (1 - (c - 25) / 7)) or 0 }
    for i, k in ipairs(FLAME_KEYS) do
        if w[i] > 0 then o:spr(k, x, y + 208 * s, { s = s, ay = 1, fade = clamp01(w[i]) * fade, add = true }) end
    end
end

-- a fireball erupts from the bottom of the screen and shoots up past the lane
local function eruption(x, y)
    return {
        len = 48,
        draw = function(o, f, fade)
            if f >= 2 then o:cue_once(x, "se_phoenix_launch") end
            if f >= 2 then
                local u = (f - 2) / 45
                local g = f < 31 and (f - 2) / 28 or 0.941 * (1 - (f - 31) / 16)
                o:spr("phoenix_embers", x, y, { sx = lerp(1, 2.03, u), sy = lerp(1, 2.03, u * 1.4), fade = g * fade,
                    add = true })
                flames(o, f - 2, x, y - 126, 0.808, (f < 30 and 1 or 0.945 * (1 - (f - 30) / 17)) * fade)
            end
            if f >= 2 and f < 13 then
                local u = (f - 2) / 10
                o:spr("phoenix_fireball_small", x, y - 37 * u, { sx = lerp(1.25, 0.58, u), sy = lerp(0.56, 0.61, u),
                    fade = u * fade })
            end
            if f >= 14 then
                local u = (f - 14) / 33
                fireball(o, f, x, lerp(y - 335, y - 992, u), lerp(0.85, 1, u), 0, fade)
                local e = f < 31 and (f - 14) / 16 or 0.941 * (1 - (f - 31) / 16)
                o:spr("phoenix_embers", x, lerp(y - 160, y - 756, u), { sx = 0.9, rot = 180, fade = e * fade,
                    add = true })
            end
        end,
    }
end

-- a fireball drops head first through the lane
local FALLING = {
    len = 51,
    draw = function(o, f, fade)
        o:cue_once(FLAME_KEYS, "se_phoenix_fall")
        fireball(o, f, 952, lerp(-205, 1119, f / 50), 0.852, 180, fade)
    end,
}

-- one shot of the gogo volley: smoke, a rising glow and three fireballs, around (ox, oy)
local function shot(o, f, ox, oy, fade)
    if f >= 7 and f < 45 then
        local u = (f - 7) / 37
        o:spr("phoenix_smoke", ox + 856, oy + 392, { sx = lerp(1.35, 2.01, u), sy = lerp(1, 1.49, u),
            fade = lerp(0.2, 0, u) * fade })
    end
    if f < 20 then
        local a = f < 16 and lerp(0, 0.8, f / 16) or lerp(0.8, 0.2, (f - 16) / 3)
        o:spr("phoenix_embers", ox + 972, oy + (f < 4 and 532 or lerp(505, 180, (f - 4) / 12)),
            { s = f < 16 and 1.65 or lerp(1.74, 1.96, (f - 16) / 3), fade = a * fade, add = true })
    end
    for _, b in ipairs({ { 7, 31, 1040, 715, -377, 0.837 }, { 11, 42, 744, 715, -565, 0.682 },
        { 25, 52, 932, 707, -549, 0.852 } }) do
        if f >= b[1] and f <= b[2] then
            fireball(o, f, ox + b[3], oy + lerp(b[4], b[5], (f - b[1]) / (b[2] - b[1])), b[6], 0, fade)
        end
    end
end

-- the gogo volley: four shots under three flames and a swelling glow
local VOLLEY_SHOTS = { { 0, -856, -529 }, { 18, -1139, -508 }, { 33, -856, -529 }, { 51, -856, -529 } }
local VOLLEY_FLAMES = {
    { 7, 75, 86, -100, 32, 0.721 }, { 18, 81, 91, 148, 32, 0.721 }, { 18, 91, 101, -215, 51, 0.601 },
}
local function volley(o, f, fade)
    for _, s in ipairs(VOLLEY_SHOTS) do
        if f >= s[1] and f < s[1] + 54 then shot(o, f - s[1], s[2], s[3], fade) end
    end
    for _, fl in ipairs(VOLLEY_FLAMES) do
        if f >= fl[1] and f <= fl[3] then
            local a = f <= fl[2] and 1 or 0.9 * (1 - (f - fl[2]) / (fl[3] - fl[2]))
            flames(o, f - fl[1], fl[4], fl[5], fl[6], a * fade)
        end
    end
    if f >= 9 and f < 69 then
        local u = (f - 9) / 59
        o:spr("phoenix_embers", -27, -148, { s = lerp(1.744, 2.6, u), fade = (f < 16 and (f - 9) / 6 or 1 - u) * fade,
            add = true })
    end
end

local function volley_pattern(x, y, ang)
    return {
        len = 106,
        draw = function(o, f, fade)
            volley(turned(o, x, y, ang), f, fade)
        end,
    }
end

local PHOENIX = {
    normal = {
        events = { { 60, 1 }, { 150, 3 }, { 250, 2 }, { 350, 3 }, { 450, 1 }, { 550, 3 }, { 620, 0 } },
        sounds = { { "vo_phoenix_disturb_1" }, {}, { "vo_phoenix_disturb_2" }, {}, { "vo_phoenix_disturb_3" } },
        fade = 25,
        pats = { eruption(1174, 759), eruption(756, 758), FALLING },
    },
    gogo = {
        events = { { 60, 1 }, { 240, 2 }, { 300, 3 }, { 450, 0 } },
        sounds = { { "se_phoenix_launch_big", "se_phoenix_shooting" } },
        fade = 174,
        pats = {
            volley_pattern(999, 581, 0), volley_pattern(1230, 164, 220.5), volley_pattern(1313, 253, 220.5),
        },
    },
}

-- Dragon King

-- crystals the Dragon King lifted fall back through the lane: key, scale, rotation, x, y from, y to, frames
local CRYSTALS = {
    { "crystal_small", 1.2, 0, 737, 80, 766, 283, 345 }, { "crystal_small", 1, 0, 369, -26, 662, 283, 356 },
    { "crystal_cluster", 1.5, 0, 505, 70, 743, 285, 332 }, { "crystal_dark", 1.2, 0, 215, 44, 690, 283, 348 },
    { "crystal_cluster", 1.5, -60, 789, -329, 770, 298, 358 }, { "crystal_dark_small", 1, 0, 513, -226, 669, 310, 387 },
    { "crystal_cluster", 1.65, 210, 312, -363, 741, 322, 381 }, { "crystal_small", 2, 0, 713, -278, 736, 343, 403 },
    { "crystal_dark", 1, 0, 313, -231, 675, 361, 419 },
}
-- the purple flashes where the first crystals start: key pair, x, y, scale from, to
local CRYSTAL_FLASHES = {
    { "haze_a", "haze_b", 721, 95, 1.2, 2 }, { "haze_a", "haze_b", 353, -15, 1, 1.5 },
    { "haze_c", "haze_d", 502, 40, 1.2, 1.89 }, { "haze_c", "haze_d", 222, 32, 1.2, 2 },
}

local CRYSTAL_RAIN = {
    len = 500,
    draw = function(o, f, fade)
        local function put(key, x, y, t)
            t.s = (t.s or 1) * 0.93
            o:spr("dragon_" .. key, 458.75 + 0.93 * (21.3 + x), 171.9 + 0.93 * (8.35 + y), t)
        end
        if f >= 2 then o:cue_once(CRYSTALS, "se_dragon_liftup") end
        if f >= 42 and f < 134 then
            local q = (f - 42) / 24
            local y = f < 67 and lerp(14, -211, q) or lerp(-213, -392, (f - 67) / 67)
            put("crystal_small", 560 - 94 * clamp01((f - 67) / 67), y, { s = 0.906, fade = clamp01(q) * fade })
        end
        if f < 283 then return end
        o:cue_once(CRYSTAL_FLASHES, "se_dragon_drop")
        for _, c in ipairs(CRYSTAL_FLASHES) do
            local u = (f - 283) / 7
            if u < 1 then
                put(c[1], c[3], c[4], { s = lerp(c[5], c[6], u), fade = 0.5 * (1 - u) * fade, add = true })
                put(c[2], c[3], c[4], { s = lerp(c[5], c[6], u), fade = 0.5 * (1 - u) * fade, add = true })
            end
        end
        for _, c in ipairs(CRYSTALS) do
            if f >= c[7] and f <= c[8] then
                put(c[1], c[4], lerp(c[5], c[6], (f - c[7]) / (c[8] - c[7])), { s = c[2], rot = c[3], fade = fade })
            end
        end
    end,
}

local function blast(o, key, f, x, y, s, fade)
    if f >= 1 then o:cue_once(key, "se_dragon_flash") end
    if f >= 57 then o:cue_once(tostring(key), "se_dragon_explosion") end
    local function put(key, dx, dy, t)
        t.s = (t.s or 1) * s
        o:spr("dragon_" .. key, x + dx * s, y + dy * s, t)
    end
    if f < 57 then
        local k, oy, a = 0.8, 24, 1
        if f < 14 then
            k, oy, a = lerp(5, 0.8, f / 13), 40, lerp(0.05, 1, f / 13)
        elseif f < 36 then
            oy = lerp(39, 24, (f - 14) / 21)
        elseif f >= 44 then
            k = math.floor(f / 2) % 2 == 0 and 1.2 or 0.8
        end
        local p = f % 15
        put("flash", 1, oy, { s = k, fade = a * fade })
        put("flash", 2, oy, { s = k * lerp(0.3, 1.5, p / 14), fade = a * (p < 11 and 1 or 1 - (p - 10) / 4) * fade })
        return
    end
    if f < 62 then
        put("flash", 0, 24, { s = lerp(1.5, 1.83, (f - 57) / 4), fade = (1 - (f - 57) / 5) * fade, add = true })
    end
    if f < 81 then
        local k = f < 70 and lerp(0.15, 1, 1 - (1 - (f - 57) / 12) ^ 2) or lerp(1.01, 1.1, (f - 70) / 10)
        put("explosion", 6, 22, { s = k, fade = (f < 70 and 1 or 0.91 * (1 - (f - 70) / 10)) * fade })
    end
    if f < 69 then
        local u = (f - 57) / 11
        put("rays", 18, 34, { s = lerp(0.21, 2, u), fade = (f < 63 and 1 or 1 - (f - 62) / 6) * fade, add = true })
    end
    if f >= 67 and f < 94 then
        local u = (f - 67) / 26
        put("smoke_purple", 6, 22, { s = lerp(0.7, 1.09, u), fade = (f < 69 and (f - 67) / 2 or 1 - u) * fade })
    end
    if f >= 73 and f < 118 then
        local a = f < 87 and 0.6 * (f - 73) / 13 or 0.58 * (1 - (f - 87) / 30)
        put("smoke_dark", 6, 22, { s = f < 87 and 1 or lerp(1, 1.2, (f - 87) / 30), fade = a * fade })
    end
end

-- the gogo barrage: eight blasts around (1003.6, 286.9): frame, x, y, scale
local BLASTS = {
    { 1, -308, 52, 0.903 }, { 10, -95, -189, 1.389 }, { 22, 139, -119, 1.389 }, { 28, -346, -169, 1.389 },
    { 28, 221, -53, 1.389 }, { 28, -94, 66, 1 }, { 77, 80, 27, 1 }, { 88, -272, -98, 1.176 },
}
local BARRAGE = {
    len = 235,
    draw = function(o, f, fade)
        for _, b in ipairs(BLASTS) do
            local g = f - b[1]
            if g >= 0 and g < 120 then blast(o, b, g, 1003.6 + b[2], 286.9 + b[3], b[4], fade) end
        end
    end,
}

local DRAGON_KING = {
    normal = {
        events = { { 60, 1 }, { 500, 0 } },
        sounds = { { "vo_dragon_disturb_1" } },
        fade = 25,
        pats = { CRYSTAL_RAIN },
    },
    gogo = {
        events = { { 60, 1 }, { 200, 0 } },
        sounds = { { "vo_dragon_disturb_2" } },
        fade = 25,
        pats = { BARRAGE },
    },
}

-- Maou

-- a Maou head on a spring drops onto the lane, bounces four times (59 frames each) and is pulled back up
local MAOU_BOUNCES = { 48, 107, 166, 225 }
local function spring_head(x)
    return {
        len = 325,
        draw = function(o, f, fade)
            for i, at in ipairs(MAOU_BOUNCES) do
                if f >= at then o:cue_once(MAOU_BOUNCES[i] .. x, "se_maou_bound") end
            end
            local hy, stretch, ry = 0, 1, -120
            if f < 49 then
                local q = (f / 48) ^ 2
                hy, stretch, ry = lerp(-157, 123, q), lerp(1, 3, q), lerp(-260, -120, q)
            elseif f < 285 then
                local c = (f - 49) % 59
                if f >= 256 then
                    local q = ((f - 256) / 28) ^ 2
                    hy, stretch = lerp(73, 153, q), lerp(2.27, 3.43, q)
                elseif c < 30 then
                    local q = 1 - (1 - c / 29) ^ 2
                    hy, stretch = lerp(120, 73, q), lerp(2.95, 2.26, q)
                else
                    local q = ((c - 30) / 28) ^ 2
                    hy, stretch = lerp(73, 123, q), lerp(2.26, 3, q)
                end
            else
                local q = 1 - (1 - (f - 285) / 39) ^ 2
                hy, stretch, ry = lerp(138, -157, q), lerp(3.3, 1, q), lerp(-127, -260, q)
            end
            -- the spring hangs from its top edge
            o:spr("maou_reel", x - 7, 92 + ry, { sy = stretch, ay = 0, fade = fade })
            o:spr("maou_head", x, 92 + hy, { fade = fade })
        end,
    }
end

-- the huge faint face that drifts behind the lane the whole fight (sprite 5, 960 frames): frame, x, y, alpha
local FACE_PATH = {
    { 0, -707, -92, 0 }, { 114, -349, -196, 0.957 }, { 362, 327, 2, 1 }, { 497, 715, -93, 1 },
    { 596, 343, -197, 1 }, { 853, -407, -3, 0.29 }, { 960, -560, -40, 0 },
}
local FACE = {
    len = 960,
    draw = function(o, f, fade)
        local i = 1
        while FACE_PATH[i + 1][1] <= f do i = i + 1 end
        local a, b = FACE_PATH[i], FACE_PATH[i + 1]
        local u = (f - a[1]) / (b[1] - a[1])
        o:spr("maou_face", 642 + lerp(a[2], b[2], u), 357 + lerp(a[3], b[3], u),
            { fade = lerp(a[4], b[4], u) * fade, add = true })
    end,
}

local MAOU_EVENTS = {
    events = { { 60, 2 }, { 330, 4 }, { 580, 1 }, { 840, 3 }, { 1010, 1 }, { 1360, 4 }, { 1560, 1 }, { 1860, 3 },
        { 2100, 0 } },
    sounds = { {}, { "vo_maou_disturb_1" }, {}, {}, {}, { "vo_maou_disturb_2" } },
    fade = 25,
    pats = { spring_head(1142), spring_head(980), spring_head(850), spring_head(676) },
}
local MAOU = { normal = MAOU_EVENTS, gogo = MAOU_EVENTS, always = FACE }

return { [2] = GHOST_WOOD, [4] = BASILISK, [6] = SCYLLA, [8] = PHOENIX, [10] = DRAGON_KING, [11] = MAOU }
