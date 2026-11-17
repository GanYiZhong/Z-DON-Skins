local SKILLS = require("game/enso_skills")
local STAGES = require("game/enso_stages")
local INTERCEPTS = require("game/enso_intercepts")

EnsoBattleOverlay = {}
EnsoBattleOverlay.__index = EnsoBattleOverlay

local function folder_of(key)
    return key:sub(1, 6) == "stage_" and "battle_stage" or "enso_battle"
end
local S = tex.get_screen_scale()

local FIELD = { x0 = 660, x1 = 1220, y0 = 470, y1 = 660, near = 0.7, far = 0.5 }
local POP_STAGGER_MS = 120

local POP_MS, DEAD_MS, ESCAPE_MS = 550, 450, 500
local HIT_TILT_MS, HIT_SHAKE_MS, SPARK_MS = 67, 200, 200
local LANE_HIT_MS = 250
local NUMBER = { x = 414, y = 168, drop_from = -10, drop_to = 12, drop_ms = 67, life_ms = 300 }
local KILL_TICK_MS, KILL_TICK_CATCHUP = 250, 20
local KILL_ADD = { x = 450, cy = 92, gap = -8 }
local DIGIT_POP_MS = 67
local SPARK = { per_kill = 3, delay_ms = 250, fly_ms = 650, x = 470, y = 92, field_x0 = 480, field_x1 = 1100 }
local ROLL = { x = 425, y = 140, spread_x = 85, spread_y = 45, s = 0.6, bg_ms = 550, number_ms = 483, max = 14 }
local CUTIN_MS, CUTIN_IN, SLASH_AT, CUTIN_OUT = 2420, 450, 1167, 2117
local FRAME_MS = 1000 / 60
local SLASH = { x = -314, y = -75, s = 0.873, cx = 186, cy = 323 }
local CHEST_MS = 1900
local CHEST_COUNT = { x = 171.5, y = 260.4, badge_x = 192.5, badge_y = 234.4, orb_y = 266.4, delay = 1133 }

local BOSS_DMG_MS = 117
local BEST_BANNER = { x = 72, y = 163, x_off = -86, slide = 14, out = 136, len = 149 }
local BOSS_HIT = { x0 = 650, x1 = 1000, y0 = 380, y1 = 600, ms = 300, max = 6 }
local BOSS_KNOCK = { at = 1300, out_ms = 350, back = 767, land = 1183, settle = 1317, done = 1500 }
local FINISH = { delay = 1000, boss_dead = 0, x = 804, y = 260, seal_x = 1040, seal_y = 260, slash_dx = -285,
    slash_dy = 15, shatter = 1517, shard_ms = 383, banner = 1833 }
local FC = { dx = -4, dy = -6.6, loop_from = 44, loop_len = 95, band_from = 39, band_period = 90 }
local SHARDS = {
    { -15, -139, -1, -244, 1.765 }, { -159, -49, -318, -158, 1.618 },
    { -105, 65, -148, 149, 1.618 }, { 67, -18, 241, -41, 1.882 },
}
local BOSS_GAUGE = { w = 440, warn = 1 / 3, critical = 0.1, warn_ms = 850, critical_ms = 583, bump_ms = 33 }

local KILL_DIGITS = { right = 440, cy = 90, gap = -6 }
local POWER_DIGITS = { right = 106, cy = 208, gap = -2 }
local GAUGE_FILL_WIDTH = 200

local function clamp01(v)
    return math.max(0, math.min(1, v))
end

local function lerp(a, b, q)
    return a + (b - a) * clamp01(q)
end

local function ease_out(t)
    return 1 - (1 - t) * (1 - t)
end

-- 0 -> 1 over [a, b] ms, then 1 -> 0 over [c, d]
local function window(t, a, b, c, d)
    if t < a or t >= d then return 0 end
    if t < b then return (t - a) / (b - a) end
    if t < c then return 1 end
    return 1 - (t - c) / (d - c)
end

function EnsoBattleOverlay.new()
    local self = setmetatable({}, EnsoBattleOverlay)
    self.ids = {}
    self.sizes = {}
    self:reset(414 * S, 256 * S)
    return self
end

function EnsoBattleOverlay:id(key)
    self.ids[key] = self.ids[key] or tex.get_texture(folder_of(key) .. "/" .. key)
    return self.ids[key]
end

function EnsoBattleOverlay:size(key)
    local info = self.sizes[key]
    if not info then
        info = tex.get_texture_info(folder_of(key), key)
        self.sizes[key] = info
    end
    return info.width * S, info.height * S
end

function EnsoBattleOverlay:spr(key, x, y, o)
    o = o or {}
    local w, h = self:size(key)
    local sx, sy = o.sx or o.s or 1, o.sy or o.s or 1
    tex.draw_texture(self:id(key), {
        x = x * S, y = y * S,
        x2 = w * (sx - 1), y2 = h * (sy - 1),
        origin = { w * sx * (o.ax or 0.5), h * sy * (o.ay or 0.5) },
        rotation = o.rot or 0,
        fade = o.fade or 1,
        frame = o.frame or 0,
        blend = o.add and "additive" or nil,
    })
end

local function play(name, preset)
    name = "enso_battle_" .. name
    if audio.has_sound(name) then audio.play_sound(name, preset or "sound") end
end

function EnsoBattleOverlay:reset(judge_x, judge_y, stage, orbs, best_power)
    self.judge = { x = judge_x / S, y = judge_y / S }
    self.chest_count = { orbs = orbs, counts = {}, bumps = {} }
    stage = STAGES[stage] and stage or 1
    -- the EX stage (11) fields stage 9's enemies once its boss is gone
    self.stage, self.enemy_stage = STAGES[stage], STAGES[math.min(stage - 1 + stage % 2, 9)]
    self.intercept_def = INTERCEPTS[stage]
    self.intercept = nil
    self.enemies = {}
    self.next_pop = 0
    self.fallen = {}
    self.number = nil
    self.kill_add = nil
    self.skill_add = nil
    self.kill_count = { target = 0, shown = 0, next_tick = 0, pops = {}, incoming = {} }
    self.sparks = {}
    self.puff = nil
    self.rolls = {}
    self.power_count = { shown = 0, pops = {} }
    self.lane_hits = {}
    self.chests = {}
    self.skill = nil
    self.ended = nil
    self.end_banner = nil
    self.fight = nil
    self.power, self.fill = 0, 0
    self.best_power = best_power and best_power >= 0 and best_power or nil
    self.best_banner = nil
end

function EnsoBattleOverlay:boss(ms, hp, max)
    self.fight = { start = ms, hp = hp, shown = hp, from = hp, max = max, hits = {} }
    self.fight.def = self.stage.boss or STAGES[2].boss
    if self.fight.def.voice then play("vo_" .. self.fight.def.voice .. "_begin", "voice") end
    if self.intercept_def then
        self.intercept = { start = ms, last = ms, gogo = false, active = {},
            normal = { t = 0, i = 1 }, gogo_mode = { t = 0, i = 1 } }
    end
end

function EnsoBattleOverlay:set_gogo(ms, on)
    local ic = self.intercept
    if not ic or ic.gogo == on then return end
    ic.gogo = on
    for _, a in ipairs(ic.active) do
        if a.gogo ~= on and not a.out then a.out = ms end
    end
end

function EnsoBattleOverlay:cue_once(key, name)
    local played = self.intercept_played
    if played and not played[key] then
        played[key] = true
        play(name)
    end
end

function EnsoBattleOverlay:draw_intercept(ms)
    local ic = self.intercept
    if not ic then return end
    if self.ended and not ic.over then
        ic.over = true
        for _, a in ipairs(ic.active) do a.out = a.out or ms end
    end
    if not ic.over then
        local mode = ic.gogo and ic.gogo_mode or ic.normal
        local def = ic.gogo and self.intercept_def.gogo or self.intercept_def.normal
        mode.t = mode.t + (ms - ic.last) / FRAME_MS
        local ev = def.events[mode.i]
        if mode.t >= ev[1] then
            if ev[2] > 0 then
                ic.active[#ic.active + 1] = {
                    start = ms, gogo = ic.gogo, pat = def.pats[ev[2]], def = def, played = {},
                }
            end
            for _, name in ipairs(def.sounds[mode.i] or {}) do
                play(name, name:sub(1, 3) == "vo_" and "voice" or nil)
            end
            mode.i = mode.i + 1
            if mode.i > #def.events then mode.t, mode.i = 0, 1 end
        end
    end
    ic.last = ms
    local always = self.intercept_def.always
    if always then
        local fade = ic.over and math.max(0, 1 - (ms - (ic.over_ms or ms)) / FRAME_MS / 25) or 1
        ic.over_ms = ic.over and (ic.over_ms or ms) or nil
        if fade > 0 then always.draw(self, (ms - ic.start) / FRAME_MS % always.len, fade) end
    end
    for i = #ic.active, 1, -1 do
        local a = ic.active[i]
        local f = (ms - a.start) / FRAME_MS
        local fade = 1
        if a.out then
            local q = (ms - a.out) / FRAME_MS / a.def.fade
            fade = a.gogo and (1 - q) * (1 - q) or 1 - q
        end
        if f >= a.pat.len or fade <= 0 then
            table.remove(ic.active, i)
        else
            self.intercept_played = a.played
            a.pat.draw(self, f, math.min(fade, 1))
        end
    end
    self.intercept_played = nil
end

function EnsoBattleOverlay:boss_hit(ms)
    local b = self.fight
    b.hit = ms
    if #b.hits >= BOSS_HIT.max then table.remove(b.hits, 1) end
    b.hits[#b.hits + 1] = {
        start = ms,
        x = BOSS_HIT.x0 + math.random() * (BOSS_HIT.x1 - BOSS_HIT.x0),
        y = BOSS_HIT.y0 + math.random() * (BOSS_HIT.y1 - BOSS_HIT.y0),
    }
end

function EnsoBattleOverlay:draw_spark_hit(x, y, f)
    if f >= 2 and f < 15 then
        local u = (f - 2) / 13
        self:spr("boss_hit_ring", x, y, { s = 0.3 + 1.02 * ease_out(u), fade = 1 - u })
    end
    if f < 4 then
        self:spr("boss_hit_spark", x, y, { s = lerp(0.5, 1, f / 2) })
    elseif f < 12 then
        self:spr("boss_hit_spark", x, y, { frame = f < 8 and 1 or 2 })
    elseif f < 16 then
        self:spr("boss_hit_spark", x, y, { frame = 3, s = lerp(1, 1.2, (f - 12) / 4), fade = 0.852 })
    end
end

function EnsoBattleOverlay:free_spot()
    local best, best_gap = nil, -1
    for _ = 1, 6 do
        local x = FIELD.x0 + math.random() * (FIELD.x1 - FIELD.x0)
        local y = FIELD.y0 + math.random() * (FIELD.y1 - FIELD.y0)
        local gap = math.huge
        for _, e in ipairs(self.enemies) do
            gap = math.min(gap, (e.x - x) ^ 2 + ((e.y - y) * 2) ^ 2)
        end
        if gap > best_gap then best, best_gap = { x = x, y = y }, gap end
    end
    return best
end

function EnsoBattleOverlay:pop_enemy(ms, kind)
    local spot = self:free_spot()
    local enemies = self.enemy_stage.enemies
    self.next_pop = math.max(ms, self.next_pop + POP_STAGGER_MS)
    self.enemies[#self.enemies + 1] = {
        key = enemies[kind + 1] or enemies[1], start = self.next_pop, x = spot.x, y = spot.y,
        s = FIELD.far + (FIELD.near - FIELD.far) * (spot.y - FIELD.y0) / (FIELD.y1 - FIELD.y0),
    }
end

function EnsoBattleOverlay:hit(ms, damage, good, critical, kat, big)
    local target = self.enemies[1]
    if target then target.hit = ms end
    if self.fight then self:boss_hit(ms) end
    local key = critical and "critical_digits" or good and "good_digits" or "ok_digits"
    self.number = { value = damage, start = ms, key = key }
    local face = critical and ("critical_" .. (kat and "kat" or "don")) or good and "good" or "ok"
    local key = "hit_" .. face .. (big and "_big" or "")
    self.lane_hits[#self.lane_hits + 1] = { key = key, start = ms, critical = critical }
    if critical then play("se_critical") end
end

function EnsoBattleOverlay:roll_hit(ms, damage)
    local target = self.enemies[1]
    if target then target.hit = ms end
    if self.fight then self:boss_hit(ms) end
    if #self.rolls >= ROLL.max then table.remove(self.rolls, 1) end
    self.rolls[#self.rolls + 1] = {
        value = damage, start = ms, rise = math.random() < 0.5,
        x = ROLL.x + (math.random() * 2 - 1) * ROLL.spread_x,
        y = ROLL.y + (math.random() * 2 - 1) * ROLL.spread_y,
    }
end

function EnsoBattleOverlay:kill(ms, skill)
    local e = table.remove(self.enemies, 1)
    local count = self.kill_count
    if e and e.start <= ms then
        e.start = ms
        self.fallen[#self.fallen + 1] = e
    end
    if not skill then
        count.target = count.target + 1
        play("se_defeat")
        return
    end
    local arrive = ms + SPARK.delay_ms + SPARK.fly_ms
    local last = count.incoming[#count.incoming]
    if last and last.at == arrive then
        last.n = last.n + 1
    else
        count.incoming[#count.incoming + 1] = { at = arrive, n = 1 }
    end
    local from_x = e and e.x or SPARK.field_x0 + math.random() * (SPARK.field_x1 - SPARK.field_x0)
    local from_y = e and e.y - 40 or 560
    for _ = 1, SPARK.per_kill do
        self.sparks[#self.sparks + 1] = {
            start = ms + math.random() * SPARK.delay_ms,
            x = from_x + (math.random() - 0.5) * 80, y = from_y + (math.random() - 0.5) * 60,
            lift = 80 + math.random() * 160, small = math.random() < 0.5, spin = math.random() * 360,
        }
    end
end

function EnsoBattleOverlay:start_skill(ms, skill)
    self.skill = { start = ms, skill = skill, move = SKILLS[skill] or {}, played = {} }
    if self.fight then self.fight.knock, self.fight.knock_played = ms + BOSS_KNOCK.at, {} end
    play(self.skill.move.cutin_sound or "se_cutin")
    play("vo_skill", "voice")
end

function EnsoBattleOverlay:drop_chest(ms, orbs)
    self.chests[#self.chests + 1] = { start = ms + SLASH_AT, x = 620 + math.random() * 120, y = 660,
        kind = orbs and "orb_chest" or "chest" }
    local cc = self.chest_count
    cc.bumps[#cc.bumps + 1] = { at = ms + SLASH_AT + CHEST_COUNT.delay, orbs = orbs and true or false }
end

function EnsoBattleOverlay:song_end(ms, full_combo)
    self.ended = ms
    self.full_combo = full_combo
    local b = self.fight
    if b and b.hp <= 0 then
        b.finish, b.finish_played = ms + FINISH.delay, {}
        b.dead, b.dead_played = b.finish + FINISH.boss_dead, {}
    else
        self.end_banner, self.end_played = ms + FINISH.delay, {}
    end
end

function EnsoBattleOverlay:set_status(power, fill, boss_hp)
    self.power, self.fill = power, fill
    if self.fight and boss_hp then self.fight.hp = boss_hp end
end

-- Marks the digits that differ between two numbers (counted from the right) to pop.
local function pop_changed(pops, old, new, ms)
    old, new = tostring(old), tostring(new)
    for i = 1, #new do
        if old:sub(-i, -i) ~= new:sub(-i, -i) then pops[i] = ms end
    end
end

function EnsoBattleOverlay:tick_counters(ms)
    local count = self.kill_count
    while count.incoming[1] and ms >= count.incoming[1].at do
        local batch = table.remove(count.incoming, 1)
        count.target = count.target + batch.n
        local add = self.skill_add
        if add and not add.leaving then
            add.count, add.until_kills = add.count + batch.n, count.target
        else
            self.skill_add = { count = batch.n, start = ms, until_kills = count.target }
        end
        self.puff = { start = ms }
    end
    local gap = count.target - count.shown
    if gap > 0 and ms >= count.next_tick then
        local step = math.max(1, math.ceil(gap / KILL_TICK_CATCHUP))
        pop_changed(count.pops, count.shown, count.shown + step, ms)
        count.shown = count.shown + step
        count.next_tick = ms + KILL_TICK_MS
        if not self.skill_add then self.kill_add = { count = step, start = ms } end
    end
    local add = self.skill_add
    if add and not add.leaving and count.shown >= add.until_kills then add.leaving = ms end
    local power = self.power_count
    if power.shown ~= self.power then
        pop_changed(power.pops, power.shown, self.power, ms)
        power.shown = self.power
    end
end

function EnsoBattleOverlay:draw_enemy(e, ms)
    local t = ms - e.start
    if t < 0 then return end
    local x, y, sx, sy, rot, fade = e.x, e.y, e.s, e.s, 0, 1
    if t < POP_MS then
        local p = t / POP_MS
        if p < 0.33 then
            local q = p / 0.33
            x, y, fade = x + 56 * (1 - q), y - 27 * (1 - q), q
        else
            local q = (p - 0.33) / 0.67
            y = y - 26 * math.sin(q * math.pi)
            sy = e.s * (1 - 0.16 * math.max(0, math.sin((q - 0.5) * 2 * math.pi)))
        end
    else
        sy = e.s * (1 - 0.045 * (1 - math.cos((t - POP_MS) / 650 * math.pi)))
    end
    if e.hit then
        local h = ms - e.hit
        if h < HIT_TILT_MS then
            x, rot = x + 10, 30
        elseif h < HIT_SHAKE_MS then
            x = x + (math.random() - 0.5) * 2
        end
    end
    if self.ended then
        local q = clamp01((ms - self.ended) / ESCAPE_MS)
        x, fade = x + 50 * q, fade * (1 - q)
    end
    self:spr(e.key, x, y, { ax = 0.5, ay = 1, sx = sx, sy = sy, rot = rot, fade = fade })
    if e.hit and ms - e.hit < SPARK_MS then
        local q = (ms - e.hit) / SPARK_MS
        local _, h = self:size(e.key)
        self:spr("defeat_flash", e.x, e.y - h * e.s / S / 2, { s = 0.4 + 0.3 * q, fade = 1 - q, add = true })
    end
end

function EnsoBattleOverlay:draw_fallen(e, ms)
    local q = (ms - e.start) / DEAD_MS
    if q >= 1 then return true end
    local _, h = self:size(e.key)
    local mid = e.y - h * e.s / S / 2
    self:spr(e.key, e.x + 570 * q, mid - 190 * ease_out(q), { s = e.s, rot = 30 + 105 * q, fade = 1 - q })
    self:spr("defeat_flash", e.x, mid, { s = 0.6 + 0.8 * q, fade = 1 - q, add = true })
    return false
end

function EnsoBattleOverlay:draw_amitie(ms)
    local frame, bob = 0, math.sin(ms / 400) * 2
    if self.skill then
        local t = ms - self.skill.start
        frame = t < SLASH_AT and 2 or 3
    end
    tex.draw_texture(self:id("amitie"), { y = bob * S, frame = frame })
end

function EnsoBattleOverlay:draw_chest(c, ms)
    local t = ms - c.start
    if t < 0 then return false end
    if t >= CHEST_MS then return true end
    local drop = clamp01(t / 300)
    local y = c.y - 220 * (1 - ease_out(drop))
    local fade = clamp01((CHEST_MS - t) / 300)
    if t < 600 then
        self:spr("chest_beam", c.x, c.y, { ay = 1, fade = 1 - t / 600, add = true })
    end
    self:spr("chest_halo", c.x, c.y - 20, { fade = fade * 0.8, add = true })
    self:spr(c.kind, c.x, y, { ay = 1, fade = fade })
    if drop >= 1 then
        local q = clamp01((t - 300) / 400)
        self:spr(c.kind .. "_ring", c.x, c.y - 72, { s = 0.5 + q, fade = (1 - q) * fade, add = true })
    end
    return false
end

-- plays `name` once, the first frame `ready` holds
local function cue(played, ready, name, preset)
    if ready and not played[name] then
        played[name] = true
        play(name, preset)
    end
end

-- offset, squash and visibility while the special move throws the boss away and it falls back
function EnsoBattleOverlay:boss_knock(b, ms)
    local k = ms - b.knock
    if k < 0 then return nil end
    local K = BOSS_KNOCK
    cue(b.knock_played, true, "se_boss_knock")
    if b.def.voice then cue(b.knock_played, true, "vo_" .. b.def.voice .. "_wazahit", "voice") end
    cue(b.knock_played, k >= K.back, "se_boss_fall")
    cue(b.knock_played, k >= K.land, "se_boss_land")
    if k < K.out_ms then
        local q = k / K.out_ms
        return { dx = lerp(44, 919, q), dy = lerp(-23, -487, q) }
    elseif k < K.back then
        return { hidden = true }
    elseif k < K.land then
        local q = (k - K.back) / (K.land - K.back)
        return { dx = lerp(117, 0, q), dy = lerp(-1007, 0, q), back = true }
    elseif k < K.settle then
        return { sy = lerp(0.99, 0.918, (k - K.land) / (K.settle - K.land)), back = true }
    elseif k < K.done then
        return { sy = lerp(0.926, 1, (k - K.settle) / (K.done - K.settle)), back = true }
    end
    b.knock = nil
    return nil
end

function EnsoBattleOverlay:draw_boss_dead(b, ms)
    local k, B = ms - b.dead, b.def
    local D = B.dead
    cue(b.dead_played, k >= D.hold, "se_boss_shake")
    cue(b.dead_played, k >= D.burst, D.voice and "se_major_boss_vanish" or "se_boss_vanish")
    if D.voice then cue(b.dead_played, k >= D.burst, D.voice, "voice") end
    if k < D.burst then
        local dx = k < D.hold and 0 or math.floor((k - D.hold) / 50) % 2 == 0 and 10 or -10
        local dying = D.hold > 0 and clamp01(k / D.hold) or 1
        B.draw(self, { t = math.huge, idle = 0, dx = dx, dy = 0, sy = 1, dying = dying })
        return
    end
    -- a boss without a single burst picture draws its dying pose scaled
    local function burst(s, fade, add)
        if D.key then return self:spr(D.key, D.x, D.y, { s = s, fade = fade, add = add }) end
        B.draw(self, { t = math.huge, idle = 0, dx = 0, dy = 0, sy = 1, dying = 1, s = s, fade = fade, add = add })
    end
    local q = (k - D.burst) / D.fade_ms
    if q < 1 then burst(lerp(D.s or 1, D.grow or D.s or 1, q), 1 - q) end
    if D.glow then
        local g = ease_out(clamp01((k - D.burst) / D.glow_ms))
        burst(lerp(D.s or 1, D.glow, g), 1 - g, true)
    end
end

function EnsoBattleOverlay:draw_boss(ms)
    local b = self.fight
    if b.dead and ms >= b.dead then return self:draw_boss_dead(b, ms) end
    local t = ms - b.start
    local p = { t = t, idle = t >= b.def.pop_ms and t - b.def.pop_ms or nil, dx = 0, dy = 0, sy = 1 }
    if b.hit and ms - b.hit < BOSS_DMG_MS then p.hurt = (ms - b.hit) / BOSS_DMG_MS end
    local knock = b.knock and self:boss_knock(b, ms)
    if knock then
        if knock.hidden then return end
        p.knock, p.dx, p.dy, p.sy = knock, knock.dx or 0, knock.dy or 0, knock.sy or 1
    end
    b.def.draw(self, p)
    for i = #b.hits, 1, -1 do
        local h = b.hits[i]
        local k = ms - h.start
        if k >= BOSS_HIT.ms then
            table.remove(b.hits, i)
        elseif not knock and b.def.spark_hit then
            self:draw_spark_hit(h.x, h.y, k / FRAME_MS)
        elseif not knock then
            local hit_fade = k < 83 and lerp(0.89, 1, k / 83) or lerp(0.91, 0, (k - 100) / 167)
            self:spr("boss_hit", h.x, h.y, { fade = hit_fade })
        end
    end
end

function EnsoBattleOverlay:draw_win_banner(t)
    local F = FINISH
    local band_sx, band_x, band_sy, band_fade = 15.35, 0, 1, 1
    if t < 100 then
        local q = t / 100
        band_sx, band_x, band_sy, band_fade = lerp(1.8, 15.35, q), lerp(-881, 0, q), lerp(1, 1.155, q), q
    elseif t < 333 then
        band_sy = lerp(1.155, 1, (t - 100) / 233)
    elseif t < 1167 then
        band_sy = lerp(1, 0.904, (t - 333) / 834)
    else
        band_sy = 1.013 - 0.111 * math.cos((t - 1167) / 1833 * 2 * math.pi)
    end
    for _ = 1, 2 do
        self:spr("boss_win_band", F.x + band_x, F.y, { sx = band_sx, sy = band_sy, fade = band_fade })
    end
    if t < 650 then
        local sx, sy, x, fade = 1, 0.167, 0, 1
        if t < 167 then
            local q = t / 167
            sx, sy, x, fade = lerp(0.126, 1, q), lerp(2.53, 0.167, q), lerp(-877, 0, q), q
        elseif t >= 333 then
            local q = clamp01((t - 333) / 167)
            sy, fade = lerp(0.417, 3.33, q * q), lerp(0.89, 0, (t - 500) / 150)
            if t < 500 then fade = 1 end
        end
        self:spr("boss_win_line", F.x + x, F.y + 2, { sx = sx, sy = sy, fade = fade })
    end
    if self.full_combo then
        self:draw_fc_text(t)
        return
    end
    if t >= 500 then
        local s, fade = 2, 0.77
        if t < 667 then
            s, fade = lerp(1.68, 2, (t - 500) / 167), (t - 500) / 167
        elseif t < 1167 then
            fade = lerp(0.965, 0.77, (t - 667) / 500)
        else
            s = 1.833 + 0.167 * math.cos((t - 1167) / 1833 * 2 * math.pi)
        end
        self:spr("boss_win_glow", F.x, F.y, { s = s, fade = fade, add = true })
    end
    local x, fade = 0, 1
    if t < 283 then
        x, fade = lerp(-776, 256, t / 283), lerp(0.06, 1, t / 283)
    elseif t < 333 then
        x = lerp(170, 0, (t - 283) / 50)
    end
    local pop = (t >= 433 and t < 567) and math.sin((t - 433) / 133 * math.pi) or 0
    self:spr("boss_win_banner", F.x + x, F.y + 5, { s = 1 + 0.167 * pop, fade = fade })
    if pop > 0 then
        self:spr("boss_win_banner", F.x, F.y + 5, { s = 1 + 0.167 * pop, fade = 1 - (t - 433) / 133, add = true })
    end
end

function EnsoBattleOverlay:draw_fc_text(t)
    local F = FINISH
    local f = t / FRAME_MS
    local x, y = F.x + FC.dx, F.y + FC.dy

    if f >= FC.band_from then
        local b = f - FC.band_from
        local sx, sy, fade = 15.32, 1, 0.8
        if b < 4 then
            local q = b / 4
            sx, sy, fade = lerp(3.23, 15.32, q), lerp(1, 1.88, q), lerp(0, 0.8, q)
        else
            local c = math.cos((b - 4) / FC.band_period * 2 * math.pi)
            sy, fade = 1.555 + 0.325 * c, 0.895 - 0.095 * c
        end
        self:spr("fc_band_flash", F.x, F.y, { sx = sx, sy = sy, fade = fade, add = true })
    end

    local p = f < FC.loop_from and f or FC.loop_from + (f - FC.loop_from) % FC.loop_len
    local pulse, flash = 1, window(p, 82, 88, 88, 95)
    if p >= 82 and p < 89 then
        pulse = lerp(1.014, 1.097, (p - 82) / 7)
    elseif p >= 89 and p < 96 then
        pulse = lerp(1.083, 1, (p - 89) / 7)
    end

    if f < 44 then
        local rise, white, glow = -15, 1, 1
        if f < 15 then
            local q = f / 15
            rise, white, glow = -15 * ease_out(q), q, q
        elseif f >= 25 and f < 38 then
            local q = (f - 25) / 12
            rise, white, glow = -15 * (1 - q * q), 1 - q, lerp(1, 0.5, q)
        elseif f >= 38 then
            rise, white, glow = 0, 0, lerp(0.42, 0, (f - 38) / 6)
        end
        self:spr("fc_text_flash", x, y + rise, { fade = clamp01(white) })
        self:spr("fc_text_glow", x, y + rise, { fade = clamp01(glow), add = true })
    elseif flash > 0 then
        self:spr("fc_text_flash", x, y, { s = pulse, fade = 0.32 * flash })
        self:spr("fc_text_glow", x, y, { s = pulse, fade = flash, add = true })
    end

    if f < 24 then return end
    local dy, sy = 0, 1
    if f < 38 then
        local q = (f - 24) / 13
        dy = -15 * (1 - q * q)
    elseif f < 41 then
        sy, dy = lerp(0.939, 0.818, (f - 38) / 2), lerp(2.35, 7, (f - 38) / 2)
    elseif f < 44 then
        sy, dy = lerp(0.879, 1, (f - 41) / 2), lerp(4.7, 0, (f - 41) / 2)
    end
    local flicker = 0.8 + 0.2 * (1 - math.abs(2 * (f % 20) / 20 - 1))
    self:spr("fc_text_glow", x, y + dy, { sx = pulse, sy = sy * pulse, fade = flicker, add = true })
    self:spr("fc_text", x, y + dy, { sx = pulse, sy = sy * pulse })
end

function EnsoBattleOverlay:draw_end_banner(ms)
    local t = ms - self.end_banner
    if t < 0 then return end
    local F = FINISH
    local fc = self.full_combo
    cue(self.end_played, true, fc and "se_fc_start" or "se_battle_end")
    cue(self.end_played, t >= 333, fc and "se_fc_banner" or "se_battle_end_banner")
    if fc then cue(self.end_played, t >= 333, "vo_fullcombo", "voice") end
    local boss_voice = self.fight and self.fight.def.voice
    if boss_voice then cue(self.end_played, t >= (fc and 1500 or 733), "vo_" .. boss_voice .. "_laugh", "voice") end
    local copies, band_sx, band_x, band_sy, band_fade = 2, 15.35, 0, 1, 1
    if t < 167 then
        band_sx, band_x, band_fade = lerp(0.108, 15.35, t / 167), lerp(-473, 0, t / 167), t / 167
    elseif t < 1317 then
        band_sy, band_fade = lerp(1, 1.126, (t - 167) / 1150), lerp(1, 0, (t - 167) / 1150)
    elseif t < 1483 then
        copies, band_sy, band_fade = 1, 1.128, lerp(0, 0.9, (t - 1317) / 166)
    else
        band_fade = (1 + math.cos((t - 1483) / 2017 * 2 * math.pi)) / 2
        band_sy = 0.902 + 0.226 * band_fade
    end
    for _ = 1, copies do
        self:spr("boss_win_band", F.x + band_x, F.y, { sx = band_sx, sy = band_sy, fade = band_fade })
    end
    if t >= 83 and t < 733 then
        local sx, sy, x, fade = 1, 0.017, 0, window(t, 83, 167, 517, 733)
        if t < 167 then
            local q = (t - 83) / 84
            sx, sy, x = lerp(0.187, 1, q), lerp(2.533, 0.167, q), lerp(-386, 0, q)
        elseif t < 267 then
            sy = lerp(0.137, 0.017, (t - 183) / 67)
        else
            local q = clamp01((t - 267) / 250)
            sy = lerp(0.047, 3.332, q * q)
        end
        self:spr("boss_win_line", F.x + x, F.y + 2, { sx = sx, sy = sy, fade = fade })
    end
    if t < 333 then return end
    if fc then
        self:draw_fc_text(t - 333)
        return
    end
    local sy = 1
    if t < 517 then
        sy = lerp(0.08, 1.8, (t - 333) / 184)
    elseif t < 683 then
        sy = lerp(1.8, 0.4, (t - 517) / 166)
    elseif t < 733 then
        sy = lerp(0.6, 0.8, (t - 700) / 17)
    end
    self:spr("battle_end_banner", F.x, F.y, { sy = sy, fade = clamp01((t - 333) / 184) })
    local glow = window(t, 333, 517, 517, 733)
    if glow > 0 then self:spr("battle_end_banner", F.x, F.y, { sy = sy, fade = glow, add = true }) end
end

function EnsoBattleOverlay:draw_finish(b, ms)
    local t = ms - b.finish
    if t < 0 then return end
    local F = FINISH
    local fc = self.full_combo
    cue(b.finish_played, true, fc and "se_boss_fc_start" or "se_boss_finish_start")
    cue(b.finish_played, t >= 300, "se_boss_sword")
    cue(b.finish_played, t >= F.shatter, "se_boss_break")
    if fc then
        cue(b.finish_played, t >= F.banner, "se_boss_fc_banner")
        cue(b.finish_played, t >= F.banner, "vo_fullcombo", "voice")
    else
        cue(b.finish_played, t >= F.banner + 433, "vo_boss_win", "voice")
    end
    if t >= F.banner then self:draw_win_banner(t - F.banner) end
    if t < 1183 then
        local dx = t < 583 and lerp(-5, 5, t / 583) or (math.floor((t - 583) / 33) % 2 == 0 and -4 or 5)
        self:spr("boss_seal", F.seal_x + dx, F.seal_y, { fade = clamp01(t / 583) })
    elseif t >= F.shatter and t < F.shatter + F.shard_ms then
        local q = (t - F.shatter) / F.shard_ms
        for i, s in ipairs(SHARDS) do
            self:spr("boss_seal_shards", F.seal_x + lerp(s[1], s[3], q), F.seal_y + lerp(s[2], s[4], q), {
                frame = i - 1, s = lerp(1, s[5], q), fade = 1 - q,
            })
        end
    end
    local slash_x, slash_y = F.seal_x + F.slash_dx, F.seal_y + F.slash_dy
    if t >= 300 and t < 517 then
        local fade = t < 333 and (t - 300) / 33 or t < 450 and 0.95 or lerp(0.89, 0, (t - 450) / 67)
        self:spr("boss_seal_slash", slash_x + 10 * (t - 300) / 217, slash_y, { s = 0.732, fade = fade })
    elseif t >= 500 and t < 717 then
        local fade = t < 517 and (t - 500) / 17 or t < 667 and 0.93 or lerp(0.67, 0, (t - 667) / 50)
        self:spr("boss_seal_slash", slash_x, slash_y, { s = 0.74, rot = 45, fade = fade })
    end
end

function EnsoBattleOverlay:draw_bar(key, frac, dy)
    local w, h = self:size(key)
    tex.draw_texture(self:id(key), {
        src = { x = w / S * (1 - frac), y = 0, width = w / S * frac, height = h / S },
        x = w * (1 - frac), y = dy * S, x2 = w * frac - w,
    })
end

function EnsoBattleOverlay:draw_boss_gauge(ms)
    local b, G = self.fight, BOSS_GAUGE
    if b.hp < b.shown then b.bump = ms end
    b.shown = b.hp
    local dy = b.bump and ms - b.bump < G.bump_ms and -2 or 0
    local r, from = b.hp / b.max, b.from / b.max
    tex.draw_texture(self:id("boss_gauge_back"), { y = dy * S })
    self:draw_bar("boss_gauge_lost", from, dy)
    if r > 0 then
        self:draw_bar(r > 2 / 3 and "boss_gauge_high" or r > G.warn and "boss_gauge_mid" or "boss_gauge_low", r, dy)
    end
    tex.draw_texture(self:id("boss_gauge_frame"), { y = dy * S })
    if r < G.critical then
        tex.draw_texture(self:id("boss_gauge_warn"), { y = dy * S })
        local pulse = 0.5 + 0.5 * math.cos(ms / G.critical_ms * 2 * math.pi)
        tex.draw_texture(self:id("boss_gauge_warn_glow"), { y = dy * S, fade = pulse })
    elseif r < G.warn then
        local pulse = 0.5 + 0.5 * math.cos(ms / G.warn_ms * 2 * math.pi)
        tex.draw_texture(self:id("boss_gauge_warn"), { y = dy * S, fade = pulse })
    end
    if from < 1 then
        tex.draw_texture(self:id("boss_gauge_needle"), { x = G.w * (1 - from) * S, y = dy * S })
    end
end

function EnsoBattleOverlay:draw_back(ms)
    local zone = self.fight and self.stage or self.enemy_stage
    tex.draw_texture(self:id(zone.bg), {})
    if self.fight and zone.scenery then
        local sc = zone.scenery
        self:spr(sc[1], sc[2], sc[3], { ax = 0, ay = 0 })
    end
    self:draw_amitie(ms)
    if self.fight then self:draw_boss(ms) end
    for i = #self.fallen, 1, -1 do
        if self:draw_fallen(self.fallen[i], ms) then table.remove(self.fallen, i) end
    end
    local order = {}
    for i, e in ipairs(self.enemies) do order[i] = e end
    table.sort(order, function(a, b) return a.y < b.y end)
    for _, e in ipairs(order) do self:draw_enemy(e, ms) end
    for i = #self.chests, 1, -1 do
        if self:draw_chest(self.chests[i], ms) then table.remove(self.chests, i) end
    end
end

function EnsoBattleOverlay:draw_number(key, value, right, cy, gap, o)
    o = o or {}
    local s = o.s or 1
    local digits = tostring(math.floor(value))
    local step = (self:size(key) / S + gap) * s
    local x = right - step * #digits + step / 2
    for i = 1, #digits do
        local pop = o.pops and o.pops[#digits - i + 1]
        local ds = s
        if pop then ds = s * (1 + 0.4 * (1 - clamp01((o.ms - pop) / DIGIT_POP_MS))) end
        self:spr(key, x, cy, { frame = tonumber(digits:sub(i, i)), s = ds, fade = o.fade })
        x = x + step
    end
end

function EnsoBattleOverlay:draw_damage(ms)
    local n = self.number
    if not n then return end
    local t = ms - n.start
    if t >= NUMBER.life_ms then
        self.number = nil
        return
    end
    local q = clamp01(t / NUMBER.drop_ms)
    local y = NUMBER.y + NUMBER.drop_from + (NUMBER.drop_to - NUMBER.drop_from) * q
    local fade = 0.5 + 0.5 * q
    if t > NUMBER.life_ms - 67 then fade = (NUMBER.life_ms - t) / 67 end
    local half = (self:size(n.key) / S - 4) * #tostring(n.value) / 2
    self:draw_number(n.key, n.value, NUMBER.x + half, y, -4, { fade = fade })
end

function EnsoBattleOverlay:draw_rolls(ms)
    for i = #self.rolls, 1, -1 do
        local r = self.rolls[i]
        local t = ms - r.start
        if t >= ROLL.bg_ms then
            table.remove(self.rolls, i)
        else
            local bg = t < 83 and lerp(0.6, 0.8, t / 83) or t < 417 and 0.8 or lerp(0.71, 0, (t - 417) / 133)
            self:spr("roll_burst", r.x, r.y, { s = ROLL.s, fade = bg })
            if t < ROLL.number_ms then
                local fade = t < 100 and lerp(0.6, 1, t / 100) or t < 350 and 1 or lerp(0.89, 0, (t - 350) / 133)
                local y = r.y
                if r.rise then
                    y = y - (t < 100 and lerp(0, 20.6, t / 100) or t < 350 and 20.6 or lerp(22, 35.6, (t - 350) / 133))
                end
                local half = (self:size("ok_digits") / S - 4) * ROLL.s * #tostring(r.value) / 2
                self:draw_number("ok_digits", r.value, r.x + half, y, -4, { s = ROLL.s, fade = fade })
            end
        end
    end
end

function EnsoBattleOverlay:draw_sparks(ms)
    for i = #self.sparks, 1, -1 do
        local p = self.sparks[i]
        local t = ms - p.start
        if t >= SPARK.fly_ms then
            table.remove(self.sparks, i)
        elseif t >= 0 then
            local q = t / SPARK.fly_ms
            local e = q * q
            local x = p.x + (SPARK.x - p.x) * e
            local y = p.y + (SPARK.y - p.y) * e - p.lift * math.sin(q * math.pi)
            local twinkle = 0.75 + 0.25 * math.sin((ms + p.spin) / 40)
            self:spr(p.small and "kill_sparkle_small" or "kill_sparkle", x, y, {
                s = lerp(1.4, 0.8, q) * twinkle, rot = p.spin + q * 90, fade = math.min(1, t / 80), add = true,
            })
        end
    end
    local puff = self.puff
    if puff then
        local q = (ms - puff.start) / 500
        if q >= 1 then
            self.puff = nil
        else
            self:spr("kill_puff", SPARK.x + 40, SPARK.y, { s = lerp(0.6, 1.2, q), fade = (1 - q) * 0.9, add = true })
        end
    end
end

-- "+N" with its sign: frame 10 of the digit sheet
function EnsoBattleOverlay:draw_add(key, count, x, y, fade, s)
    local w = (self:size(key) / S + KILL_ADD.gap) * s
    self:spr(key, x + w / 2, y, { frame = 10, fade = fade, s = s })
    self:draw_number(key, count, x + w * (1 + #tostring(count)), y, KILL_ADD.gap, { fade = fade, s = s })
end

function EnsoBattleOverlay:draw_best_banner(ms)
    local f = (ms - self.best_banner) / FRAME_MS
    if f >= BEST_BANNER.len then return end
    local x, y = BEST_BANNER.x, BEST_BANNER.y
    if f < BEST_BANNER.slide then
        local q = f / BEST_BANNER.slide
        x, y = lerp(BEST_BANNER.x_off, x, q), lerp(y - 6, y, q)
    elseif f >= BEST_BANNER.out then
        x = lerp(x - 13, BEST_BANNER.x_off - 15, (f - BEST_BANNER.out) / 12)
    end
    local glow = f >= BEST_BANNER.slide and f < BEST_BANNER.out
    local loop = f - BEST_BANNER.slide
    local pulse = 0.5 + 0.5 * math.cos(2 * math.pi * loop / 60)
    if glow then self:spr("kill_puff", BEST_BANNER.x + 2, y - 0.5, { fade = pulse }) end
    local breathe = glow and 1 - 0.055 * (1 - math.cos(2 * math.pi * (loop - 1) / 60)) / 2 or 1
    self:spr("best_banner_cloud", x, y, { s = breathe })
    if glow then
        local drift = loop >= 61 and 5.8 * (1 - math.abs(loop - 91) / 30) or 0
        self:spr("best_banner_glow", BEST_BANNER.x, y - 1 - drift, { fade = pulse })
    end
    self:spr("best_banner_text", x, y)
    if glow then
        local p = loop % 60
        local q = p % 30
        local fade = q < 15 and q / 15 or 0.93 * (1 - (q - 15) / 14)
        self:spr(p < 30 and "kill_sparkle_small" or "kill_sparkle", BEST_BANNER.x + 2, y, { fade = fade })
    end
end

function EnsoBattleOverlay:draw_kill_add(ms)
    local a = self.kill_add
    if not a then return end
    local t = ms - a.start
    if t >= 600 then
        self.kill_add = nil
        return
    end
    local dx, dy, fade = 0, 0, 1
    if t < 83 then
        local q = t / 83
        dx, dy, fade = 10 * (1 - q), 10 * (1 - q), 0.5 + 0.5 * q
    elseif t >= 500 then
        local q = (t - 500) / 100
        dx, dy, fade = -10 * q, 10 * q, 1 - q
    end
    self:draw_add("kill_add_digits", a.count, KILL_ADD.x + dx, KILL_ADD.cy + dy, fade, 1)
end

function EnsoBattleOverlay:draw_skill_add(ms)
    local a = self.skill_add
    if not a then return end
    local t = ms - a.start
    local dx, dy, fade, s = 0, 0, 1, 1
    if t < 117 then
        dx = 30 * (1 - t / 117)
    elseif t < 467 then
        dy = -math.sin((t - 117) / 350 * math.pi) * 1.5
    end
    if a.leaving then
        local q = (ms - a.leaving) / 150
        if q >= 1 then
            self.skill_add = nil
            return
        end
        dx, s, fade = -46 * q, 0.94 - 0.52 * q, 1 - q
    end
    self:draw_add("kill_skill_digits", a.count, KILL_ADD.x + dx, KILL_ADD.cy + dy, fade, s)
end

function EnsoBattleOverlay:draw_lane_hit(h, ms)
    local q = (ms - h.start) / LANE_HIT_MS
    if q >= 1 then return true end
    self:spr(h.key, self.judge.x, self.judge.y, { s = 0.8 + 0.4 * q, fade = 1 - q, add = true })
    if h.critical then
        self:spr("hit_critical_rays", self.judge.x, self.judge.y, {
            s = 0.9 + 0.5 * q, rot = 20 * q, fade = 1 - q, add = true,
        })
    end
    return false
end

function EnsoBattleOverlay:draw_gauge(ms)
    tex.draw_texture(self:id("skill_gauge_bubble"), {})
    local w = GAUGE_FILL_WIDTH * S
    if self.fill > 0 then
        tex.draw_texture(self:id("skill_gauge_fill"), { x2 = w * (self.fill - 1) })
    end
    tex.draw_texture(self:id("skill_gauge_frame"), {})
    if self.fill >= 1 then
        local pulse = 0.5 + 0.5 * math.sin(ms / 120)
        tex.draw_texture(self:id("skill_gauge_full"), { fade = pulse, blend = "additive" })
        tex.draw_texture(self:id("skill_gauge_glow"), { frame = math.floor(ms / 50) % 5, blend = "additive" })
    end
end

local SPIRIT_SABER = { start = "slash_start", main = "slash", glow = "slash_glow", delay = 0, dx = 0 }

function EnsoBattleOverlay:draw_slash(t, keys)
    local f = (t - SLASH_AT) / FRAME_MS - keys.delay
    if f < 0 then return end
    local drift = 36 * clamp01((f - 4) / 56)
    local master = clamp01(f / 3) * lerp(1, 0.8, (f - 4) / 56) * (1 - clamp01((f - 57) / 17))
    local x, cx = SLASH.x + drift, SLASH.cx + drift + keys.dx
    if f < 6 then
        self:spr("slash_blur", cx - 179, SLASH.cy - 72, { s = 1.746, rot = -4, fade = 0.91 * (1 - f / 6), add = true })
    end
    if f < 8 then
        self:spr(keys.start, x, SLASH.y, { ax = 0, ay = 0, s = SLASH.s, fade = master * lerp(0, 0.75, f / 3) })
    end
    if f >= 4 and f < 26 then
        local q = (f - 4) / 22
        self:spr(keys.glow, cx, SLASH.cy, {
            s = SLASH.s * lerp(1, 1.134, q), fade = master * 0.5 * (1 - q), add = true,
        })
    end
    if f >= 8 and f < 30 then
        local q = (f - 8) / 22
        self:spr(keys.glow, cx, SLASH.cy, {
            s = SLASH.s * lerp(1, 1.223, q), fade = master * 0.2 * (1 - q), add = true,
        })
    end
    if f >= 4 and f < 68 then
        local fade = f < 50 and 1 or lerp(0.97, 0.34, (f - 50) / 18)
        self:spr(keys.main, x, SLASH.y, { ax = 0, ay = 0, s = SLASH.s, fade = master * fade })
    end
end

function EnsoBattleOverlay:draw_cutin(ms)
    if not self.skill then return end
    local t = ms - self.skill.start
    if t >= CUTIN_MS then
        self.skill = nil
        return
    end
    local sk = self.skill
    local move = sk.move
    local f = t / FRAME_MS + 4
    if sk.skill == 1 then
        if t >= CUTIN_IN and not sk.swung then
            sk.swung = true
            play("se_slash")
        end
        if t >= SLASH_AT and not sk.slashed then
            sk.slashed = true
            play("se_slash_hit")
        end
    end
    for i, cue in ipairs(move.sounds or {}) do
        if f >= cue[1] and not sk.played[i] then
            sk.played[i] = true
            play(cue[2])
        end
    end
    if t < CUTIN_IN + 100 then
        local veil = math.min(t / 300, 1) * (1 - clamp01((t - CUTIN_IN) / 100))
        tex.draw_rect(0, 360 * S, 1280 * S, 360 * S, 255, 255, 255, math.floor(90 * veil))
        self:spr("cutin_band", 0, 350, { ax = 0, ay = 0, sx = lerp(0.05, 0.2, t / CUTIN_IN), fade = veil, add = true })
    end
    local out = clamp01((t - CUTIN_OUT) / 300)
    local fade = 1 - out
    if move.back then move.back(self, f) end
    if t < CUTIN_IN then return end
    local band = sk.skill - 1
    local band_x = lerp(-1021, -279, (t - CUTIN_IN) / 100)
    local band_sx = lerp(0.859, 1, out)
    local swap = 0.5 + 0.5 * math.sin(t / 1200 * 2 * math.pi)
    self:spr("cutin_band", band_x, 350, { ax = 0, ay = 0, sx = band_sx, frame = band, fade = fade })
    self:spr("cutin_band", band_x, 350, { ax = 0, ay = 0, sx = band_sx, frame = band, fade = fade * (1 - swap) })
    self:spr("cutin_band_alt", band_x, 350, { ax = 0, ay = 0, sx = band_sx, frame = band, fade = fade * swap })

    local lines_x = t < CUTIN_OUT and lerp(-651, -241, (t - 517) / 67) or lerp(-241, -172, out)
    local lines_fade = window(t, 517, 583, CUTIN_OUT, CUTIN_MS) * 0.5
    local alt = math.floor(t / (3 * FRAME_MS)) % 2 == 0
    self:spr(alt and "cutin_lines" or "cutin_lines_alt", lines_x, 350, { ax = 0, ay = 0, fade = lines_fade })

    local p = t - CUTIN_IN
    local amitie_x = -289 - 15 * (1 - clamp01(p / 1617)) - 797 * math.exp(-p / 68)
    if move.mid then move.mid(self, f) end
    if move.portrait then
        move.portrait(self, f, amitie_x, fade)
    else
        self:spr("cutin_amitie", amitie_x, 350, { ax = 0, ay = 0, fade = fade })
    end
    if sk.skill == 1 or move.slash then self:draw_slash(t, move.slash or SPIRIT_SABER) end
    if move.front then move.front(self, f) end
end

-- the counter's glows: in, dip, back up, out over 100 frames
local function count_glow(t)
    local g = t < 11 and t / 10 or t < 32 and lerp(0.98, 0.65, (t - 11) / 20)
        or t < 52 and lerp(0.67, 1, (t - 32) / 19) or lerp(0.98, 0, (t - 52) / 47)
    return clamp01(g)
end

-- one badge: the count, popping 1.5 -> 1 with a fading glow and a widening ring when it goes up
function EnsoBattleOverlay:draw_chest_badge(key, n, y, bump, ms)
    local C = CHEST_COUNT
    local t = bump and (ms - bump) / FRAME_MS
    local s = 1
    if t and t < 9 then s = t < 5 and lerp(1, 1.5, t / 4) or lerp(1.375, 1, (t - 5) / 3) end
    if t and t < 110 then
        self:spr("chest_count_glow", C.badge_x, y, { fade = count_glow(t) })
    end
    self:spr(key, C.badge_x, y, { s = s })
    self:spr("chest_count_digits", C.badge_x, y, { s = s, frame = math.min(n, 6) })
    if t and t < 9 then self:spr("chest_count_ring", C.badge_x, y, { s = lerp(1, 2.083, t / 8), fade = 1 - t / 8 }) end
end

function EnsoBattleOverlay:draw_chest_count(ms)
    local C, cc = CHEST_COUNT, self.chest_count
    local n, orbs, last, last_orb = 0, 0, nil, nil
    for _, b in ipairs(cc.bumps) do
        if ms >= b.at then
            if b.orbs then orbs, last_orb = orbs + 1, b.at else n, last = n + 1, b.at end
        end
    end
    local latest = math.max(last or -1e9, last_orb or -1e9)
    local t = (ms - latest) / FRAME_MS
    local s = 1
    if t >= 0 and t < 11 then s = t < 4 and lerp(1.034, 1.136, t / 3) or lerp(1.114, 1, (t - 4) / 6) end
    if t >= 0 and t < 100 then
        self:spr("chest_count_icon_glow", C.x, C.y, { fade = count_glow(t) })
    end
    self:spr("chest_count_icon", C.x, C.y, { s = s })
    if t >= 0 and t < 14 then
        local k = t < 4 and lerp(0.364, 1, t / 3) or lerp(1.036, 1.364, (t - 4) / 9)
        local fade = t < 4 and t / 3 or 0.9 * (1 - (t - 4) / 9)
        self:spr("chest_count_sparkle", C.badge_x, C.badge_y - 2, { s = k, fade = fade })
    end
    self:draw_chest_badge("chest_count_badge", n, C.badge_y, last, ms)
    if cc.orbs then self:draw_chest_badge("chest_count_orb_badge", orbs, C.orb_y, last_orb, ms) end
end

function EnsoBattleOverlay:draw_front(ms)
    self:draw_intercept(ms)
    self:draw_chest_count(ms)
    for i = #self.lane_hits, 1, -1 do
        if self:draw_lane_hit(self.lane_hits[i], ms) then table.remove(self.lane_hits, i) end
    end
    self:draw_damage(ms)
    self:draw_rolls(ms)
    self:tick_counters(ms)
    if self.fight then
        self:draw_boss_gauge(ms)
    else
        tex.draw_texture(self:id("kill_panel"), {})
        local kills = self.kill_count
        self:draw_number("kill_digits", kills.shown, KILL_DIGITS.right, KILL_DIGITS.cy, KILL_DIGITS.gap,
            { pops = kills.pops, ms = ms })
        if self.skill_add then self:draw_skill_add(ms) else self:draw_kill_add(ms) end
        self:draw_sparks(ms)
    end
    if self.fight and self.fight.finish then self:draw_finish(self.fight, ms) end
    if self.end_banner then self:draw_end_banner(ms) end
    tex.draw_texture(self:id("power_panel"), {})
    self:draw_number("power_digits", self.power, POWER_DIGITS.right, POWER_DIGITS.cy, POWER_DIGITS.gap,
        { pops = self.power_count.pops, ms = ms })
    if self.best_power and not self.best_banner and self.power > self.best_power then self.best_banner = ms end
    if self.best_banner then self:draw_best_banner(ms) end
    self:draw_gauge(ms)
end
