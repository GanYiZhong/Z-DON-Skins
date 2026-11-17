local M = {}

local function clamp01(v)
    return math.max(0, math.min(1, v))
end

local function lerp(a, b, q)
    return a + (b - a) * clamp01(q)
end

local function span(f, a, b)
    return clamp01((f - a) / (b - a))
end

local function ease_out(q)
    return 1 - (1 - q) * (1 - q)
end

-- 0 -> 1 over [a, b], then 1 -> 0 over [c, d]
local function window(f, a, b, c, d)
    if f < a or f >= d then return 0 end
    if f < b then return (f - a) / (b - a) end
    if f < c then return 1 end
    return 1 - (f - c) / (d - c)
end

-- a fixed pseudo-random value in [0, 1) per particle i and property k, so layouts hold still between frames
local function rnd(i, k)
    local v = math.sin(i * 12.9898 + k * 78.233) * 43758.5453
    return v - math.floor(v)
end

-- everything leaves with the band
local function out(f)
    return 1 - span(f, 139, 148)
end

local function leaf_storm(o, f)
    if f < 64 then return end
    local fade = out(f)
    o:spr("leaf_glow", 846, 455, { sx = 1.65, fade = 0.14 * fade })
    for _, p in ipairs({ { 668, 50 }, { -177, -1763 } }) do
        o:spr("leaf_streak", p[1] + 3 * (f - 64), p[2] + 6.5 * (f - 64), { s = 2.5, rot = -25, fade = fade })
    end
    for i = 1, 16 do
        local q = (f - 72 - 38 * rnd(i, 5)) / 30
        if q >= 0 and q < 1 then
            o:spr("leaf_burst", 500 + 780 * rnd(i, 6), 380 + 330 * rnd(i, 7) - 20 * q,
                { s = 0.75 * ease_out(q), fade = (1 - q) * fade })
        end
    end
    for i = 1, 60 do
        local age = f - 65 - 15 * rnd(i, 1)
        if age >= 0 then
            local wind = i % 3 == 0
            local speed = (wind and 8 or 4) + 6 * rnd(i, 2)
            local x = 340 + 1060 * rnd(i, 3) + 0.42 * speed * age
            local y = -130 + 480 * rnd(i, 4) + 0.91 * speed * age
            o:spr(wind and "leaf_wind" or "leaf", x, y, {
                frame = wind and i % 3 or i % 9, s = 0.35 + 0.65 * rnd(i, 8), rot = i % 4 == 0 and -15 or -25,
                fade = (wind and 0.6 or 1) * span(age, 0, 2) * fade,
            })
        end
    end
end

local THUNDER_BOLTS = {
    { 72, 926, 85, -60, 1.93, 152, -156 }, { 77, 894, 577, 105, 1.68, -40, -60 },
    { 89, 586, 540, 32, 1.19, -78, -63 }, { 92, 454, 278, -143, 2.35, -151, -218 },
    { 93, 963, 672, 145, 1.38, 0, 0 }, { 101, 942, 362, 105, 1.0, 74, -172 },
}
local THUNDER_CRAWL = { { 103, 1245, 634, 0, 0.56, 0.37 }, { 110, 1135, 352, -37, 0.83, 0.45 },
    { 115, 412, 356, -118, 0.65, 0.45 } }

local function thunderbolt(o, f)
    if f < 64 then return end
    local fade = out(f)
    local life = span(f, 64, 149)
    o:spr("thunder_glow", 718, 334, { s = lerp(1.6, 2, life), fade = 0.93 * lerp(1, 0.66, life) * fade })
    if f < 67 then return end
    local grow = lerp(0.54, 1, span(f, 67, 73))
    local strike = 0.93 * (1 - span(f, 118, 147))
    local flicker = math.floor(f / 2) % 2 == 0 and 1 or 0.65
    o:spr("thunder_bolts_glow", 743 + 20 * life, 349, { s = grow, fade = strike })
    o:spr("thunder_bolts", 763, 349, { s = grow, fade = strike * flicker })
    o:spr("thunder_bolts", 762, 342, { s = grow, fade = 0.48 * strike, add = true })
    if f >= 73 then o:spr("thunder_sparks", 767, 347, { fade = strike * flicker }) end
    if f >= 77 then o:spr("thunder_haze", 804, 388, { fade = strike }) end
    for i, b in ipairs(THUNDER_BOLTS) do
        local q = span(f, b[1], 147)
        if f >= b[1] then
            local blink = math.floor(f / 3 + i) % 3 == 0 and 0.5 or 1
            o:spr("thunder_bolt", b[2] + b[6] * q, b[3] + b[7] * q, {
                s = b[5], rot = b[4], fade = 0.93 * blink * (1 - q) * fade,
            })
        end
    end
    if f >= 74 then
        local q = span(f, 74, 147)
        o:spr("thunder_bolt_long", 976 + 162 * q, 87 - 196 * q,
            { sx = lerp(1, 1.76, q), rot = -51, fade = 0.93 * (1 - q) })
    end
    for _, c in ipairs(THUNDER_CRAWL) do
        if f >= c[1] then
            o:spr("thunder_crawl", c[2], c[3], {
                sx = c[5], sy = c[6], rot = c[4], fade = 0.93 * (1 - span(f, c[1], 147)), add = true,
            })
        end
    end
end

-- key, x, y, frame it bursts out of the ground
local ROCKS = { { "rocks_back", 1112, 480, 89 }, { "rocks_right", 997, 426, 95 }, { "rocks_left", 656, 485, 92 },
    { "rocks_tall", 588, 480, 97 } }
local DUST = { { "dust_left", 551, 530, 511, 472, 0.26, 1.03, 102 },
    { "dust_right", 950, 636, 1118, 499, 0.53, 1.2, 102 },
    { "dust_mid", 762, 550, 762, 441, 1, 1, 112 } }
local CHIPS = { { 103, 264, 70, 575, 0.93, 1 }, { 105, 1262, 144, 459, 0.92, 1 }, { 111, 417, 94, 203, 0.71, 0.7 },
    { 112, 678, 5, 155, 0.89, 0.7 } }

local function earthquake(o, f)
    if f < 88 then return end
    local fade = out(f)
    if f < 94 then o:spr("rock_burst", 761, 526 - 2.6 * (f - 88), { s = 1 + 0.005 * (f - 88) }) end
    for _, d in ipairs(DUST) do
        if f >= 92 then
            local q = span(f, 92, 148)
            local a = 0.7 * window(f, 92, d[8], 140, 148)
            for _, dy in ipairs({ 0, 164 }) do
                o:spr(d[1], lerp(d[2], d[4], q), lerp(d[3], d[5], q) + dy, { s = lerp(d[6], d[7], q), fade = a })
            end
        end
    end
    for _, r in ipairs(ROCKS) do
        local q = span(f, r[4], r[4] + 4)
        if f >= r[4] then
            o:spr(r[1], r[2], r[3] + 40 * (1 - ease_out(q)) + 10 * span(f, r[4] + 4, 148),
                { sy = lerp(1.06, 1, q), fade = fade })
        end
    end
    for i, d in ipairs({ { 89, 617, 562, 396, 261, 0.86, 1 }, { 91, 997, 536, 1210, 241, 1, 1.37 } }) do
        local q = span(f, d[1], d[1] + 14)
        if f >= d[1] and q < 1 then
            o:spr("rock_debris", lerp(d[2], d[4], q), lerp(d[3], d[5], q),
                { s = lerp(d[6], d[7], q), rot = i == 1 and 180 * (1 - q) or 0, fade = 1 - q })
        end
    end
    if f >= 92 then
        o:spr("rock_pebbles", 852, lerp(651, 682, span(f, 92, 96)),
            { s = lerp(0.35, 1, span(f, 92, 96)), fade = window(f, 92, 96, 120, 148) })
    end
    if f >= 94 and f < 97 then o:spr("dust_puff", 797, 501) end
    if f >= 99 and f < 114 then
        local q = span(f, 99, 113)
        o:spr("dust_ring", 796, lerp(538, 500, q), { sx = lerp(0.88, 1.43, q), sy = lerp(0.88, 1.28, q), fade = 1 - q })
    end
    for _, c in ipairs(CHIPS) do
        if f >= c[1] then
            o:spr("rock_chips", c[2], lerp(c[3], c[4], span(f, c[1], 148)),
                { s = c[5], fade = c[6] * window(f, c[1], c[1] + 4, 140, 148) })
        end
    end
end

local function bubble_launcher(o, f)
    if f < 38 then return end
    local fade = out(f)
    for i = 1, 38 do
        local born = 38 + 22 * rnd(i, 1)
        local age = f - born
        local pop = i % 5 == 0 and math.huge or 69 + 38 * rnd(i, 2)
        if age >= 0 and f < pop + 10 then
            local q = ease_out(span(age, 0, 40))
            local x = lerp(380 + 300 * rnd(i, 3), 560 + 700 * rnd(i, 4), q) + 0.6 * age
            local y = lerp(300 + 320 * rnd(i, 5), 80 + 640 * rnd(i, 6), q) - 0.3 * age
            local s = lerp(0.1, 0.2 + 0.75 * rnd(i, 7), q)
            if f < pop then
                o:spr("bubble", x, y, { frame = i % 4, s = s, fade = span(age, 0, 3) * fade })
            else
                local p = span(f, pop, pop + 10)
                o:spr("bubble_pop", x, y, { frame = i % 3, s = s * lerp(1.6, 2.2, p), fade = 1 - p * p })
            end
        end
    end
    if f >= 93 then
        local q = span(f, 93, 148)
        for i, p in ipairs({ { 724, 350 }, { 1025, 490 } }) do
            o:spr("bubble_sparkles", p[1], p[2], { frame = i - 1, s = lerp(0.5, 1, q), fade = fade, add = true })
        end
    end
end

local function energy_cannon_back(o, f)
    if f >= 86 then
        local tint = window(f, 86, 91, 130, 149)
        local sy = f < 91 and lerp(0.05, 1.22, span(f, 86, 91)) or lerp(1.22, 0.14, span(f, 91, 149))
        o:spr("beam_tint", 844, 551, { sx = 117.5, sy = sy, fade = 0.5 * tint })
        o:spr("beam_tint", 648, 134, { sx = 171, sy = 0.95, fade = 0.15 * tint })
    end
    if f < 88 then return end
    local grow = span(f, 88, 94)
    local fade = out(f)
    local key = math.floor(f / 2) % 2 == 0 and "beam" or "beam_alt"
    o:spr(key, 286, 532, { ax = 0, sx = lerp(0.18, 1, grow), sy = 1.45, fade = fade })
    o:spr("beam_sparks", lerp(403, 925, grow), 536, { frame = math.floor(f / 3) % 3, fade = fade })
end

local function energy_cannon_front(o, f)
    local x, y = 409, 548
    if f >= 51 and f < 69 then
        local q = span(f, 51, 69)
        o:spr("beam_petals", x, y, { s = lerp(2, 0.1, q), fade = 1 - q })
    end
    if f >= 52 and f < 64 then
        local q = span(f, 52, 63)
        o:spr("beam_charge", x, y, { s = lerp(3, 0.01, q), fade = q })
    end
    if f >= 56 and f < 72 then
        local q = span(f, 56, 71)
        o:spr("beam_flash", x, y, { s = lerp(0.1, 6, q), fade = 1 - q, add = true })
    end
    if f >= 57 and f < 75 then
        local q = span(f, 57, 75)
        o:spr("beam_petals_green", x, y, { s = lerp(2, 0.1, q), fade = 1 - q })
    end
end

local function bloody_faust_portrait(o, f, amitie_x, fade)
    if f < 88 then
        local x = amitie_x + 589
        o:spr("cutin_don", x, 540, { fade = fade })
        o:spr("cutin_don_fist", x + 12, 540, { fade = fade })
    else
        o:spr("cutin_don_punch", lerp(486, 502, span(f, 88, 148)), 540, { fade = fade })
    end
end

local function bloody_faust_front(o, f)
    if f >= 39 and f < 59 then
        local q = span(f, 39, 58)
        o:spr("faust_ring", lerp(77, 91, q), 412, { s = lerp(1.8, 0.2, q) })
    end
    if f >= 53 and f < 85 then
        local q = span(f, 53, 84)
        o:spr("faust_flare", 91, 410, { s = lerp(0.2, 1.5, q), rot = 120 * q, fade = 1 - q })
    end
    if f < 88 then return end
    for _, d in ipairs({ 88, 93 }) do
        local q = span(f, d, d + 33)
        if q < 1 then
            o:spr("faust_fire", lerp(774, 446, q), lerp(476, 643, q),
                { s = lerp(0.3, 1.5, q), fade = 1 - span(q, 0.5, 1) })
        end
    end
    local q = span(f, 88, 112)
    if q < 1 then
        local burn = 1 - span(q, 0.5, 1)
        o:spr("faust_flame", lerp(828, 982, q), lerp(445, 338, q), { s = lerp(0.3, 1.2, q), fade = burn })
        o:spr("faust_blast", 807, 474, { s = lerp(0.4, 1.5, q), fade = burn })
    end
    q = span(f, 88, 121)
    if q < 1 then
        o:spr("faust_sparks", 802, 476, { s = lerp(0.2, 2, q), fade = 1 - q })
        o:spr("faust_sparks", 802, 476, { s = lerp(0.2, 1.3, q), rot = 55, fade = 1 - q })
    end
end

-- frame the ray lands, x, ground y, scale
local HOLY_RAYS = { { 75, 875, 690, 1 }, { 101, 1164, 600, 0.62 }, { 111, 602, 535, 0.62 } }

local function holy_ray(o, f)
    local fade = out(f)
    for r, ray in ipairs(HOLY_RAYS) do
        local land, x, ground, k = ray[1], ray[2], ray[3], ray[4]
        local g = f - land
        if g >= -20 then
            local bottom = lerp(-60, ground, span(g, -20, 0))
            local beam = k < 1 and 1 - 0.83 * span(g, 0, 18) or 1
            if k == 1 or g < 19 then
                local sy = (bottom + 60) / 1061
                o:spr("holy_pillar", x, bottom, { ay = 1, sx = 1.24 * k, sy = sy, fade = beam * fade })
                o:spr("holy_pillar_core", x, bottom, { ay = 1, sx = 1.3 * k, sy = sy, fade = beam * fade })
            end
        end
        if g >= 0 then
            o:spr("holy_glow", x + 22 * k, ground + 48 - 48 * span(g, 0, 74),
                { s = k * lerp(1, 1.12, span(g, 0, 74)), fade = 0.5 * fade })
            if g < 13 then
                o:spr("holy_dome", x, ground - 13, { frame = math.floor(g / 2) % 3, s = k * lerp(0.3, 0.7, g / 13) })
            elseif g < 18 then
                local q = span(g, 13, 18)
                o:spr("holy_dome", x, ground - 150 * k * q, { frame = 0, s = k * lerp(1.7, 2.6, q), fade = 1 - q * q })
                o:spr("holy_burst", x + 11 * k, ground - 110 * k, { s = k * lerp(0.81, 1.05, q) })
            end
            if g < 18 then
                o:spr("holy_orb", x + 15 * k, ground - 36 - 36 * span(g, 0, 17),
                    { s = k * lerp(0.5, 2.15, span(g, 0, 17)), fade = window(g, 0, 4, 4, 17) })
            end
            local w = span(g, 13, 40)
            if g >= 13 and w < 1 then
                o:spr("holy_wisps", x - 13 * k, ground - lerp(171, 428, w) * k,
                    { s = k * lerp(1.18, 3.23, w), fade = 0.5 * window(g, 13, 24, 24, 40) })
            end
            if g >= 15 then
                local q = span(g, 15, 60)
                o:spr("holy_smoke", x, ground - 20,
                    { s = k * lerp(0.6, 1.2, q), fade = 0.8 * window(g, 15, 20, 40, 60) * fade })
            end
            for i = 1, 6 do
                local born = 1 + 40 * rnd(r * 10 + i, 1)
                local age = g - born
                if age >= 0 and age < 38 then
                    o:spr("holy_sparkles", x + (rnd(r * 10 + i, 2) - 0.5) * 300 * k, ground - 40 - 6.3 * age,
                        { frame = i % 2, s = lerp(0.2, 1, rnd(r * 10 + i, 3)),
                            fade = window(age, 0, 6, 26, 38) * fade })
                end
            end
        end
    end
end

local function true_saber_mid(o, f)
    if f >= 41 and f < 81 then
        o:spr("true_glow", 128, 515, { fade = window(f, 41, 45, 60, 81), add = true })
    end
end

local function true_saber_front(o, f)
    local fade = out(f)
    if f >= 41 then
        local q = span(f, 41, 149)
        o:spr("true_sparkle", lerp(14, 40, q), lerp(497, 553, q),
            { s = lerp(0.5, 1.38, span(f, 41, 60)), fade = fade, add = true })
    end
    if f >= 42 and f < 97 then
        local q = span(f, 42, 96)
        o:spr("true_flare", 48 + 306 * q, 515 + 149 * q, { s = lerp(1, 2.22, q), fade = 1 - q })
    end
    if f >= 48 then
        o:spr("true_rays", 43, 475, { s = lerp(1, 2.41, span(f, 48, 149)), rot = 12 * span(f, 48, 149), fade = fade })
        for i = 1, 3 do
            local born = 48 + 40 * rnd(i, 1)
            local age = f - born
            if age >= 0 and age < 60 then
                o:spr("true_specks", -72 + 1033 * rnd(i, 2), 300 + 400 * rnd(i, 3) - 2.4 * age, {
                    s = lerp(0.61, 1, rnd(i, 4)), rot = ({ -135, 0, 95, 120, 180 })[i % 5 + 1],
                    fade = 0.6 * window(age, 0, 5, 40, 60),
                })
            end
        end
    end
    if f >= 78 then
        local q = span(f, 78, 148)
        local key = math.floor(f / 2) % 2 == 0 and "true_arc" or "true_arc_alt"
        o:spr(key, lerp(745, 780, q), 302, { s = 2.05, fade = window(f, 78, 80, 116, 140) })
    end
    if f >= 93 and f < 139 then
        local q = span(f, 93, 138)
        o:spr("true_slash_halo", lerp(102, 233, q), lerp(229, 327, q),
            { s = lerp(1.86, 2.47, q), fade = 0.94 * (1 - q), add = true })
    end
end

local EMBERS = { { 90, 809, 362, 0 }, { 95, 676, 372, 1 }, { 104, 649, 401, 0 }, { 109, 555, 318, 1 },
    { 118, 939, 251, 0 }, { 123, 855, 336, 1 }, { 132, 939, 251, 0 }, { 137, 690, 187, 1 } }

local function hacchake_back(o, f)
    if f < 34 then return end
    o:spr("hacchake_haze", 641, 140, { sx = 325, fade = 0.398 * window(f, 34, 51, 135, 145) })
end

local function hacchake_portrait(o, f)
    if f < 31 or f >= 149 then return end
    local g = f - 31
    local x = 101 - 272 + 812 * ease_out(span(f, 31, 128))
    o:spr("cutin_rulco", x, 536, { frame = g < 35 and 0 or g < 40 and 1 or g < 45 and 2 or 3,
        fade = f < 131 and 1 or 0.945 * (1 - span(f, 131, 148)) })
end

local function hacchake_front(o, f)
    if f < 85 or f >= 146 then return end
    local key = { frame = math.floor((f - 85) / 3) % 3 }
    if f < 93 then
        local q = span(f, 85, 92)
        key.sx, key.sy, key.fade = lerp(0.105, 1, q), lerp(0.054, 1, q), q
        o:spr("hacchake_fire", 101 + lerp(313, 750, q), 540 + lerp(171, -4, q), key)
    elseif f < 139 then
        o:spr("hacchake_fire", 851, 536, key)
    else
        local q = span(f, 139, 145)
        key.sx, key.sy, key.fade = lerp(1.026, 1.18, q), lerp(1.057, 1.4, q), lerp(0.855, 0, q)
        o:spr("hacchake_fire", 101 + lerp(762, 838, q), 540 + lerp(-15, -78, q), key)
    end
    for _, e in ipairs(EMBERS) do
        if f >= e[1] and f < e[1] + 9 then
            o:spr("hacchake_embers", e[2], e[3], { frame = e[4], fade = window(f, e[1], e[1] + 4, e[1] + 6, e[1] + 9) })
        end
    end
end

M[2] = { back = leaf_storm, sounds = { { 64, "se_skill_02" } } }
M[3] = { back = thunderbolt, sounds = { { 64, "se_skill_03" } } }
M[4] = { back = earthquake, sounds = { { 88, "se_skill_04" } } }
M[5] = {
    back = hacchake_back, portrait = hacchake_portrait, front = hacchake_front,
    sounds = { { 88, "se_skill_05" }, { 88, "se_skill_05_hit" } },
}
M[6] = { back = bubble_launcher, sounds = { { 39, "se_skill_06" }, { 88, "se_skill_06_hit" } } }
M[7] = { back = energy_cannon_back, front = energy_cannon_front, sounds = { { 51, "se_skill_07" } } }
M[8] = {
    portrait = bloody_faust_portrait, front = bloody_faust_front,
    sounds = { { 35, "se_skill_08" }, { 88, "se_skill_08_hit" } },
}
M[9] = { back = holy_ray, sounds = { { 55, "se_skill_09" }, { 88, "se_skill_09_hit" } } }
M[10] = {
    mid = true_saber_mid, front = true_saber_front, cutin_sound = "se_cutin_10",
    slash = { start = "true_slash_start", main = "true_slash", glow = "true_slash_glow", delay = 15, dx = 50 },
    sounds = { { 77, "se_skill_10" } },
}

return M
