local FRAME_MS = 1000 / 60

local function clamp01(v)
    return math.max(0, math.min(1, v))
end

local function lerp(a, b, q)
    return a + (b - a) * clamp01(q)
end

local function ease_out(t)
    return 1 - (1 - t) * (1 - t)
end

-- 0 at both ends of a cycle, 1 at `peak`
local function swell(u, peak)
    return u < peak and u / peak or (1 - u) / (1 - peak)
end

local GHOST_WOOD = {
    pop_ms = 283,
    dead = { hold = 150, burst = 867, key = "boss_ghost_wood", x = 894, y = 358, s = 0.909, fade_ms = 467,
        glow = 1.136, glow_ms = 783 },
}

function GHOST_WOOD.draw(self, p)
    local dx, sy, fade, glow, leaves = 0, 1, 1, 1, true
    local cdx, cdy, cfade = 0, 0, 1
    if p.dying then
        glow, leaves = 1 - p.dying, p.dying < 1
        cdx, cdy, cfade = -80 * p.dying, -200 * p.dying, 1 - p.dying
    elseif not p.idle then
        local q = p.t / GHOST_WOOD.pop_ms
        dx, fade, glow, leaves = lerp(94, 5, q), 0.945 * q, 0, false
        cdx, cdy, cfade = lerp(80, 0, q), lerp(-120, -50, q), q
    else
        local u = p.idle % 767
        if u < 333 then
            sy, glow, cdy = 1 - 0.039 * u / 333, 1 - 0.79 * u / 333, 27 * clamp01(u / 300)
        else
            local q = (u - 333) / 434
            sy, glow, cdy = 0.961 + 0.039 * q, 0.21 + 0.79 * q, 27 * (1 - ease_out(q))
        end
    end
    if p.hurt then dx, glow = dx + 10 * (1 - p.hurt), glow * lerp(0.38, 1, p.hurt) end
    if p.knock then sy, glow, cdx, cdy = p.sy, 0.73, p.dx, p.dy end
    local x, y = 902 + p.dx + dx, 782 + p.dy
    local o = { ax = 0.5, ay = 1, sy = sy, fade = fade }
    self:spr("boss_ghost_wood", x, y, o)
    if glow > 0 then self:spr("boss_ghost_wood_glow", x, y, { ax = 0.5, ay = 1, sy = sy, fade = fade * glow }) end
    if leaves then self:spr("boss_ghost_wood_leaves", x, y, o) end
    if cfade > 0 then self:spr("boss_chick", 731 + cdx, 57 + cdy, { fade = cfade }) end
end

local function later_pose(p, breathes)
    local dx, dy, sy, fade = 0, 0, p.sy, 1
    if p.t < 283 then
        local q = p.t / 283
        dx, dy, fade = lerp(100, 2, q), lerp(-290, -3, q), 0.945 * q
    elseif p.t < 383 then
        local q = (p.t - 283) / 100
        dx, dy = lerp(-4, 0, q), lerp(14, 0, q)
    end
    if breathes and p.idle and not p.knock and not p.dying then
        local w = swell(p.idle % 917 / 917, 0.33)
        dy, sy = dy + 4 * w, 1 - 0.011 * w
    end
    if p.hurt then
        local r = 1 - p.hurt
        dx, dy, sy = dx + 20 * r, dy + 8 * r, sy * (1 - 0.023 * r)
    end
    return p.dx + dx, p.dy + dy, sy, fade
end

local function later_dead(key, x, y, voice)
    return { hold = 0, burst = 617, key = key, x = x - 8, y = y + 17, s = 0.909, fade_ms = 450, glow = 1.028,
        glow_ms = 400, voice = voice }
end

local BASILISK = { pop_ms = 433, dead = later_dead("boss_basilisk", 902, 285) }

-- two purple puffs leave the nostrils at the start of every breath
local BREATH_PUFFS = {
    { key = "boss_basilisk_breath", from = { 758, 693, 0.32 }, mid = { 808, 678, 0.79 }, to = { 918, 662, 1.07 } },
    { key = "boss_basilisk_breath_small", from = { 624, 630, 0.36 }, mid = { 607, 603, 0.82 },
        to = { 638, 503, 1.05 } },
}

function BASILISK.draw(self, p)
    local dx, dy, sy, fade = later_pose(p, true)
    self:spr("boss_basilisk", 902 + dx, 285 + dy, { sy = sy, fade = fade })
    if not p.idle or p.knock or p.dying or p.hurt then return end
    local f = p.idle % 917 / FRAME_MS
    if f >= 42 then return end
    for _, puff in ipairs(BREATH_PUFFS) do
        local a, b, q = puff.from, puff.mid, f / 16
        if f >= 16 then a, b, q = puff.mid, puff.to, (f - 16) / 26 end
        local alpha = f < 16 and q or 1 - q
        self:spr(puff.key, lerp(a[1], b[1], q), lerp(a[2], b[2], q), { s = lerp(a[3], b[3], q), fade = alpha })
    end
end

local SCYLLA = { pop_ms = 433, spark_hit = true, voice = "scylla", dead = later_dead("boss_scylla_bright", 902, 285, "vo_scylla_vanish") }

function SCYLLA.draw(self, p)
    local dx, dy, sy, fade = later_pose(p, true)
    local x, y = 902 + dx, 285 + dy
    self:spr("boss_scylla", x, y, { sy = sy, fade = fade })
    if p.hurt or p.knock or p.dying then
        self:spr("boss_scylla_hurt", x + 85, y + 129 * sy, { sy = sy, fade = fade })
        return
    end
    if not p.idle then return end
    local q = (p.idle % 917 / FRAME_MS - 12) / 25
    if q >= 0 and q < 1 then
        self:spr("boss_scylla_bubbles", 1035, lerp(417, 368, q), { s = lerp(0.51, 0.81, q), fade = lerp(1, 0.39, q) })
    end
end

local PHOENIX = { pop_ms = 433, spark_hit = true, voice = "phoenix", dead = later_dead("boss_phoenix", 902, 364, "vo_phoenix_vanish") }

-- hovers 50 px up and back every 2067 ms; the glow shows at both ends of the hover
function PHOENIX.draw(self, p)
    local dx, dy, sy, fade = later_pose(p, false)
    local x, y = 902 + dx, 364 + dy
    if p.hurt or p.knock or p.dying or not p.idle then
        self:spr("boss_phoenix", x, y, { sy = sy, fade = fade })
        if p.t >= 283 and p.t < 383 then
            local q = (p.t - 283) / 100
            self:spr("boss_phoenix", x, y, { s = lerp(1, 1.42, q), fade = lerp(0.6, 0.1, q), add = true })
        end
        return
    end
    local u = p.idle % 2067 / 2067
    local lift = 25 * (1 - math.cos(2 * math.pi * u))
    self:spr("boss_phoenix_glow", x, y - lift, { fade = math.abs(math.cos(2 * math.pi * u)) })
    self:spr("boss_phoenix", x, y - lift)
end

-- the Dragon King is a rig of head, wing and claw around (648, 363) while idle, one whole picture otherwise
local DRAGON_KING = {
    pop_ms = 767,
    voice = "dragon",
    spark_hit = true,
    dead = { hold = 0, burst = 1017, key = "boss_dragon_king", x = 857, y = 359, s = 1, grow = 1.168, fade_ms = 300,
        voice = "vo_dragon_vanish" },
}

function DRAGON_KING.draw(self, p)
    if p.knock and p.knock.back then
        self:spr("boss_dragon_king_fall", 930 + p.dx, 318 + p.dy, { sy = p.sy })
        return
    end
    if p.knock or p.hurt or p.dying then
        self:spr("boss_dragon_king", 857 + p.dx + (p.hurt and 16 * p.hurt or 0), 359 + p.dy, { sy = p.sy })
        return
    end
    local q = p.t / DRAGON_KING.pop_ms
    local ox, oy = lerp(614, 648, q), lerp(381, 363, q)
    local f = (p.idle or 0) % 1983 / FRAME_MS
    local w = 1 - math.abs(f / 59.5 - 1)
    self:spr("boss_dragon_head_glow", ox + 302 - 22 * w, oy + 18 * w, { fade = 1 - 0.6 * w })
    self:spr("boss_dragon_head", ox + 302 - 22 * w, oy + 18 * w)
    local wx, wy = ox + 220 + 18 * w, oy - 136 - 40 * w
    self:spr("boss_dragon_wing_glow", wx, wy, { rot = 8.7 * w, fade = 1 - 0.5 * w })
    self:spr("boss_dragon_wing", wx, wy, { rot = 8.7 * w })
    if f >= 32 and f < 70 then
        local k = (f - 32) / 38
        self:spr("boss_dragon_breath", ox + lerp(457, 589, k), oy + lerp(134, 88, k),
            { s = lerp(0.74, 1, k), fade = lerp(0.16, 1, k) })
    elseif f >= 70 then
        local k = (f - 70) / 49
        self:spr("boss_dragon_breath", ox + lerp(589, 810, k), oy + lerp(88, 2, k),
            { sx = lerp(1, 1.27, k), sy = lerp(1, 1.56, k), fade = 1 - k })
    end
    self:spr("boss_dragon_claw_glow", ox + 644 - 66 * w, oy + 272 + 22 * w, { fade = 1 - 0.6 * w })
    self:spr("boss_dragon_claw", ox + 644 - 66 * w, oy + 272 + 22 * w)
end

local MAOU = {
    pop_ms = 300,
    voice = "maou",
    spark_hit = true,
    dead = { hold = 0, burst = 883, fade_ms = 417, glow = 1.144, glow_ms = 433, voice = "vo_maou_vanish" },
}
-- the idle clock runs from the pop: 195 frames, then frames 1-194 again
local MAOU_LOOP, MAOU_LOOP_2 = 194, 91
local SOB = { x = 707, y = 501 }
-- part centres from SOB
local SOB_PARTS = { { "boss_maou_sob_legs", 134, 109, 2 }, { "boss_maou_sob_head", 212, -82, 2 },
    { "boss_maou_sob_hand", 316, 83, 4 } }

local function maou_thumb(f)
    f = f >= MAOU_LOOP_2 and f - MAOU_LOOP_2 or f
    if f >= 20 and f < 40 then
        local q = (f - 20) / 20
        return lerp(3.8, 78, q), lerp(1, 19, q), lerp(-2, -35, q)
    elseif f >= 40 and f < 45 then
        local q = 1 - ease_out((f - 40) / 5)
        return 50 * q, 12 * q, -22 * q
    end
    return 0, 0, 0
end

local function maou_head(f)
    if f >= 40 and f < 55 then return 0, -15 * ease_out((f - 40) / 15), nil end
    if f >= 55 and f < 70 then return 0, -15 * (1 - ease_out((f - 55) / 15)), nil end
    if f < 130 or f >= 177 then return 0, 0, nil end
    local up = f < 153 and ease_out((f - 130) / 23) or 1 - ease_out((f - 153) / 23)
    return 14 * up, -53 * up, 360 * (f - 130) / 47
end

local function maou_finger(f)
    f = (f >= 162 and f - 92 or f) - 70
    if f < 0 or f >= 33 then return 0, 0 end
    if f < 8 then return lerp(0, -25, f / 8), lerp(-1, -10, f / 8) end
    if f < 17 then return lerp(-22, -1.5, (f - 8) / 9), lerp(-9, 1, (f - 8) / 9) end
    if f < 26 then return lerp(1, 22, (f - 17) / 9), lerp(2, 12, (f - 17) / 9) end
    return lerp(19, 0, (f - 26) / 7), lerp(10, 0, (f - 26) / 7)
end

function MAOU.draw(self, p)
    if p.hurt or p.knock or p.dying then
        local dx = p.hurt and lerp(6, -21, 2 * p.hurt) or 0
        local w = swell((p.t == math.huge and 0 or p.t) % 267 / 267, 0.5)
        local s = p.s or 1
        for _, part in ipairs(SOB_PARTS) do
            local x, y = SOB.x + p.dx + dx + part[2] * s, SOB.y + p.dy + (part[3] - part[4] * w) * s
            self:spr(part[1], x, y, { s = s, sy = s * p.sy, fade = p.fade, add = p.add })
        end
        return
    end
    local slide = p.idle and 0 or 315 * (1 - p.t / MAOU.pop_ms)
    local fade = p.idle and 1 or p.t / MAOU.pop_ms
    local f = (p.idle and p.idle + MAOU.pop_ms or p.t) / FRAME_MS
    if f >= MAOU_LOOP + 1 then f = 1 + (f - 1) % MAOU_LOOP end
    local x, y = 857 + p.dx + slide, 507 + p.dy
    local rot, tx, ty = maou_thumb(f)
    local hx, hy, spin = maou_head(f)
    local lift = f >= 32 and f < 61 and -3 * swell((f - 32) / 29, 0.5) or 0
    if f >= 123 and f < 152 then lift = -3 * swell((f - 123) / 29, 0.5) end
    -- the spin turns the head about a point 20 px right of and 31 px below its centre
    local px, py = 0, 0
    if spin then
        local r = math.rad(spin)
        px, py = 20.5 - 20.5 * math.cos(r) + 31.2 * math.sin(r), 31.2 - 20.5 * math.sin(r) - 31.2 * math.cos(r)
    end
    local thumb = { rot = rot, fade = fade }
    local head = { rot = spin or 0, fade = fade }
    self:spr("boss_maou_thumb_outline", x - 124 + tx, y + 34 + ty, thumb)
    self:spr("boss_maou_head_outline", x - 24 + hx + px, y - 82 + hy + py, head)
    self:spr("boss_maou_legs", x - 5, y + 89 + lift, { fade = fade })
    self:spr("boss_maou_thumb", x - 124 + tx, y + 34 + ty, thumb)
    self:spr("boss_maou_head", x - 24 + hx + px, y - 82 + hy + py, head)
    local frot, fdx = maou_finger(f)
    self:spr("boss_maou_finger", x + 110 + fdx, y - 9, { rot = frot, fade = fade })
end

return {
    { bg = "stage_plains", enemies = { "enemy_sprout", "enemy_moth", "enemy_turtle", "enemy_chameleon",
        "enemy_wolf" } },
    { bg = "stage_forest", boss = GHOST_WOOD },
    { bg = "stage_rocky", enemies = { "enemy_pebble", "enemy_cactus", "enemy_bandit", "enemy_fang_bird",
        "enemy_golem" } },
    { bg = "stage_rocky_night", scenery = { "stage_rocky_spires", 463, -159 }, boss = BASILISK },
    { bg = "stage_seaside", enemies = { "enemy_jellyfish", "enemy_starfish", "enemy_shell_turtle", "enemy_crab",
        "enemy_spout_fish", "enemy_robo_fish", "enemy_seaweed_eye", "enemy_wave_croc" } },
    { bg = "stage_undersea", boss = SCYLLA },
    { bg = "stage_volcano", enemies = { "enemy_magma_slime", "enemy_hermit", "enemy_fire_bird", "enemy_fire_bee",
        "enemy_miner_snake", "enemy_volcano_bull", "enemy_fire_bear" } },
    { bg = "stage_lava", boss = PHOENIX },
    { bg = "stage_lands_end", enemies = { "enemy_poison_slime", "enemy_crystal_drop", "enemy_shadow_bird",
        "enemy_dark_robo_fish", "enemy_dark_beast", "enemy_red_golem" } },
    { bg = "stage_final", boss = DRAGON_KING },
    { bg = "stage_maou", boss = MAOU },
}
