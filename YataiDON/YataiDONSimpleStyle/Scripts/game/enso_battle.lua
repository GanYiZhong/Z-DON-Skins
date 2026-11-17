-- YataiDONSimpleStyle: the enso battle play screen (BattleGameScreen, engine battle_overlay.cpp).
-- The engine keeps the score: it calls reset / boss / pop_enemy / hit / roll_hit / kill / start_skill /
-- drop_chest / set_gogo / song_end / set_status, and draws draw_back (behind the stage character),
-- draw_cutin (behind the lane) and draw_front (over the lane). The lane, notes, the 1P plate and the combo
-- stay the engine's (SimpleStyle's game textures); the gauge, score and judgement are hidden by the engine, so
-- this draws the judgement itself: 良 / 可 from hit() (the engine's hit_effect/judge_* textures and the circle
-- flash), 不可 when the combo breaks (game/ss_play.lua Play.player(1).combo: a 不可 deals no damage, so the
-- engine never calls hit() for it). The damage number pops over the creature (or boss) that took it.
-- Layout (logical 1920x1080): sky band above the lane (kills / power panels), the lane 276..540, the field
-- below (Momo and Hoshi on the left, the creatures or the boss on the right).
local UI = require("global.ss_ui")
local BT = require("global.ss_battle")
local Play = require("game/ss_play")
local P, U = UI.P, UI.U
local ON_ACC = { color = UI.P.on_acc, outline = false }   -- text on gold / accent fills

EnsoBattleOverlay = {}
EnsoBattleOverlay.__index = EnsoBattleOverlay

-- field slots (2 rows x 5): feet positions, back row first so the front row draws over it
local SLOTS = {}
for r = 0, 1 do
    for c = 0, 4 do
        SLOTS[#SLOTS + 1] = { x = 1000 + c * 168 + r * 84, foot = 800 + r * 150 }
    end
end
local BOSS_X, BOSS_FOOT = 1440, 1010
local MOMO_X, HOSHI_X, PARTY_FOOT = 450, 175, 1005
local POP_MS, DEAD_MS, HIT_MS = 300, 360, 160
local CUTIN_MS, SLASH_AT, BAND_END = 1600, 1167, 1050
local CHEST_MS = 1900
local NUM_MS, ROLL_MS = 420, 520
local JUDGE_MS, FLASH_MS = 380, 120
local judge_tex = {}   -- hit_effect textures (draw_judgement)
local END_DELAY = 1000
local KILL_TICK_MS = 60

local function clamp01(v) return math.max(0, math.min(1, v)) end

-- the song title band behind the engine's title (white text, right-aligned at x 1854, centre y 54): the same
-- band game/score_counter.lua draws in normal play, which the engine hides in this mode (hide_score_counter)
local TITLE_RIGHT, TITLE_CY, TITLE_MAX = 1854, 54, 840
local BAND_H, BAND_PAD, BAND_SLACK = 22 * U, 4 * U, 2 * U
local title_w = {}
local function band_width(str)
    if str == nil or str == "" then return nil end
    local w = title_w[str]
    if w == nil then
        local t = text.create_raw_text(str, UI.D.TEXT_ENGINE[36], { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 0)
        w = (t and t.width and t.width > 0) and t.width or TITLE_MAX
        title_w[str] = w
    end
    return math.ceil((math.min(TITLE_MAX, w) + BAND_SLACK + 2 * BAND_PAD) / U) * U
end

local function play(name, preset)
    name = "enso_battle_" .. name
    if audio.has_sound(name) then audio.play_sound(name, preset or "sound") end
end

function EnsoBattleOverlay.new()
    local self = setmetatable({}, EnsoBattleOverlay)
    BT.reset()
    judge_tex = {}        -- handles from an earlier screen may be stale
    self.momo = UI.Mascot.new({ role = "scene", char = "momo" })
    self.hoshi = UI.Mascot.new({ role = "scene", char = "hoshi" })
    self.momo:face(1)
    self.hoshi:face(1)
    self:reset(618, 384, 1, false, -1)
    return self
end

function EnsoBattleOverlay:reset(judge_x, judge_y, stage, orbs, best_power)
    self.judge = { x = judge_x, y = judge_y }
    self.stage = stage or 1
    self.zone = BT.zone(self.stage)
    self.orbs = orbs and true or false
    self.best_power = (best_power and best_power >= 0) and best_power or nil
    self.enemies, self.fallen, self.slots = {}, {}, {}
    self.next_pop = 0
    self.fight = nil
    self.number, self.rolls, self.stars = nil, {}, {}
    self.judgement, self.last_combo = nil, 0
    self.judge_t = nil
    self.kills = { target = 0, shown = 0, next_tick = 0 }
    self.power, self.fill = 0, 0
    self.skill = nil
    self.chests, self.chest_count = {}, { gold = 0, orb = 0 }
    self.ended, self.full_combo = nil, false
    self.gogo = false
    self.best_at = nil
end

function EnsoBattleOverlay:boss(ms, hp, max)
    self.fight = { start = ms, hp = hp, max = math.max(1, max), shown = hp, hit = -1e9, knock = nil }
end

function EnsoBattleOverlay:set_gogo(ms, on)
    self.gogo = on
    self.momo:react(on and "gogo" or "gogo_end")
    self.hoshi:react(on and "gogo" or "gogo_end")
end

function EnsoBattleOverlay:free_slot()
    local used = {}
    for _, e in ipairs(self.enemies) do used[e.slot] = true end
    local free = {}
    for i = 1, #SLOTS do if not used[i] then free[#free + 1] = i end end
    if #free == 0 then return math.random(#SLOTS) end
    return free[math.random(#free)]
end

function EnsoBattleOverlay:pop_enemy(ms, kind)
    self.next_pop = math.max(ms, self.next_pop + 90)
    local slot = self:free_slot()
    self.enemies[#self.enemies + 1] = { kind = kind, slot = slot, start = self.next_pop, hit = -1e9,
        phase = math.random(0, 400) }
end

function EnsoBattleOverlay:add_star(x, y, ms)
    if #self.stars >= 24 then table.remove(self.stars, 1) end
    self.stars[#self.stars + 1] = { x = x, y = y, start = ms }
end

function EnsoBattleOverlay:target_xy()
    if self.fight then return BOSS_X, BOSS_FOOT - 190 end
    local e = self.enemies[1]
    if not e then return nil end
    local s = SLOTS[e.slot]
    return s.x, s.foot - BT.mob_size(self.zone, e.kind) / 2
end

function EnsoBattleOverlay:hit(ms, damage, good, critical, kat, big)
    local target = self.enemies[1]
    if target then target.hit = ms end
    if self.fight then self.fight.hit = ms end
    local x, y = self:target_xy()
    if x then self:add_star(x + math.random(-40, 40), y + math.random(-40, 40), ms) end
    self.number = { value = damage, start = ms, critical = critical, good = good, x = x, y = y }
    self.judgement = { kind = good and "good" or "ok", big = big, start = ms }
    self.momo:react(kat and "ka" or "don")
    if critical then play("se_critical") end
end

function EnsoBattleOverlay:roll_hit(ms, damage)
    local target = self.enemies[1]
    if target then target.hit = ms end
    if self.fight then self.fight.hit = ms end
    if #self.rolls >= 10 then table.remove(self.rolls, 1) end
    local x, y = self:target_xy()
    self.rolls[#self.rolls + 1] = { value = damage, start = ms, x = (x or 1300) + math.random(-70, 70),
        y = (y or 760) + math.random(-30, 30) }
    self.momo:react("hit")
end

function EnsoBattleOverlay:kill(ms, skill)
    local e = table.remove(self.enemies, 1)
    if e then
        e.dead = ms
        e.skill = skill
        self.fallen[#self.fallen + 1] = e
        local s = SLOTS[e.slot]
        self:add_star(s.x, s.foot - BT.mob_size(self.zone, e.kind) / 2, ms)
    end
    self.kills.target = self.kills.target + 1
    if not skill then play("se_defeat") end
end

function EnsoBattleOverlay:start_skill(ms, skill)
    self.skill = { start = ms, move = (skill or 1) - 1, slashed = false }
    if self.fight then self.fight.knock = ms + SLASH_AT end
    self.momo:react("decide")
    self.hoshi:react("decide")
    play("se_cutin")
end

function EnsoBattleOverlay:drop_chest(ms, orbs)
    self.chests[#self.chests + 1] = { start = ms + SLASH_AT, x = 620 + math.random(0, 120), orb = orbs and true or false }
end

function EnsoBattleOverlay:song_end(ms, full_combo)
    self.ended = ms
    self.full_combo = full_combo
    if self.fight and self.fight.hp <= 0 then
        self.momo:react("clear")
        self.hoshi:react("clear")
        play("se_boss_break")
    else
        play("se_battle_end")
    end
end

function EnsoBattleOverlay:set_status(power, fill, boss_hp)
    if self.best_power and power > self.best_power and self.power <= self.best_power and not self.best_at then
        self.best_at = tex.get_current_ms()
    end
    self.power, self.fill = power, fill
    if self.fight and boss_hp then self.fight.hp = boss_hp end
end

-- ---------------------------------------------------------------- per-frame bookkeeping
function EnsoBattleOverlay:tick(ms)
    local k = self.kills
    if k.shown < k.target and ms >= k.next_tick then
        k.shown = k.shown + math.max(1, math.ceil((k.target - k.shown) / 12))
        k.next_tick = ms + KILL_TICK_MS
        k.pop = ms
    end
    local f = self.fight
    if f and f.shown ~= f.hp then
        local step = math.max(1, math.ceil(math.abs(f.shown - f.hp) / 10))
        f.shown = f.shown > f.hp and math.max(f.hp, f.shown - step) or math.min(f.hp, f.shown + step)
    end
    self.momo:update(ms)
    self.hoshi:update(ms)
end

-- ---------------------------------------------------------------- draw: behind the stage character
function EnsoBattleOverlay:draw_enemy(e, ms)
    local t = ms - e.start
    if t < 0 then return end
    local s = SLOTS[e.slot]
    local x, dy = s.x, 0
    if t < POP_MS then        -- hop in from the right
        local q = t / POP_MS
        x = x + (1 - q) * 120
        dy = math.sin(q * math.pi) * 40
    end
    local frame = math.floor((ms + e.phase) / 400) % 2
    if ms - e.hit < HIT_MS then
        x = x + ((math.floor((ms - e.hit) / 40) % 2 == 0) and 6 or -6)
    end
    BT.draw_mob(self.zone, e.kind, x, s.foot, { frame = frame, dy = dy })
end

function EnsoBattleOverlay:draw_fallen(e, ms)
    local t = ms - e.dead
    local s = SLOTS[e.slot]
    if e.skill then            -- blown away up and to the right
        local q = t / 600
        if q >= 1 then return true end
        BT.draw_mob(self.zone, e.kind, s.x + q * 900, s.foot, { frame = 0, dy = math.sin(q * math.pi) * 50,
            mirror = math.floor(q * 8) % 2 == 1 })
        return false
    end
    if t >= DEAD_MS then return true end
    -- a short hop, then gone (alpha is never partial: drawn whole or not at all)
    if math.floor(t / 60) % 2 == 0 then
        BT.draw_mob(self.zone, e.kind, s.x, s.foot, { frame = 0, dy = math.sin(t / DEAD_MS * math.pi) * 50 })
    end
    return false
end

function EnsoBattleOverlay:draw_boss(ms)
    local f = self.fight
    if not f then return end
    local t = ms - f.start
    local dy = 0
    if t < 600 then dy = (1 - t / 600) * -400 end      -- drops in from above the field
    local frame = math.floor(ms / 500) % 2
    local x = BOSS_X
    if ms - f.hit < HIT_MS then
        frame = 2
        x = x + ((math.floor((ms - f.hit) / 40) % 2 == 0) and 8 or -8)
    end
    if f.knock and ms >= f.knock and ms < f.knock + 500 then
        local q = (ms - f.knock) / 500
        frame = 2
        x = x + math.sin(q * math.pi) * 90
    end
    if self.ended and f.hp <= 0 and ms >= self.ended + END_DELAY then
        local q = (ms - self.ended - END_DELAY) / 700
        if q >= 1 then return end
        frame = 2
        dy = -q * q * 500
        if math.floor(q * 10) % 2 == 1 then return end
    end
    BT.draw_boss(self.stage, x, BOSS_FOOT, frame, -dy)
end

function EnsoBattleOverlay:draw_party(ms)
    -- Hoshi behind, Momo in front (the player's seat): both facing the field
    self.hoshi:draw(HOSHI_X, PARTY_FOOT - 20)
    self.momo:draw(MOMO_X, PARTY_FOOT)
end

function EnsoBattleOverlay:draw_chests(ms)
    for i = #self.chests, 1, -1 do
        local c = self.chests[i]
        local t = ms - c.start
        if t >= CHEST_MS then
            table.remove(self.chests, i)
            if c.orb then self.chest_count.orb = self.chest_count.orb + 1
            else self.chest_count.gold = self.chest_count.gold + 1 end
        elseif t >= 0 then
            local y = 990
            if t < 300 then y = 990 - (1 - t / 300) * 260 end
            local open = t > 700
            local key = (c.orb and "orb" or "chest") .. (open and "_open" or "")
            BT.draw_item(key, c.x, y - 50)
            if open and t < 900 then UI.burst(c.x, y - 110, t - 700) end
        end
    end
end

function EnsoBattleOverlay:draw_title()
    if self.band_w == nil then
        self.band_w = band_width(tex.song_title and tex.song_title() or "") or false
        self.genre_info = tex.get_texture_info("song_info", "genre")
    end
    if self.band_w then
        local x1 = TITLE_RIGHT + BAND_PAD
        UI.frame(x1 - self.band_w, TITLE_CY - BAND_H / 2, self.band_w, BAND_H,
                 { fill = P.hint_bg, border = U, shadow = U, border_c = P.ink })
    end
    local g = self.genre_info
    if g and g.x and g.x[1] then
        UI.frame(g.x[1] - U, g.y[1] - U, g.width + 2 * U, g.height + 2 * U, { fill = P.ink, notch = 0 })
    end
end

function EnsoBattleOverlay:draw_back(ms)
    self:tick(ms)
    BT.draw_bg(self.stage)
    self:draw_title()
    self:draw_party(ms)
    -- back row first, then the front row; the target gets a little ▼ marker
    for row = 0, 1 do
        for _, e in ipairs(self.enemies) do
            if (e.slot > 5) == (row == 1) then self:draw_enemy(e, ms) end
        end
    end
    for i = #self.fallen, 1, -1 do
        if self:draw_fallen(self.fallen[i], ms) then table.remove(self.fallen, i) end
    end
    self:draw_boss(ms)
    local e = self.enemies[1]
    if e and ms >= e.start + POP_MS and not self.ended then
        local s = SLOTS[e.slot]
        local top = s.foot - BT.mob_size(self.zone, e.kind) - 6 * U - (math.floor(ms / 300) % 2) * U
        UI.rect(UI.grid(s.x - 3 * U), UI.grid(top), 6 * U, U, P.ink)
        UI.rect(UI.grid(s.x - 2 * U), UI.grid(top) + U, 4 * U, U, P.clear)
        UI.rect(UI.grid(s.x - U), UI.grid(top) + 2 * U, 2 * U, U, P.ink)
    end
    self:draw_chests(ms)
    for i = #self.stars, 1, -1 do
        local st = self.stars[i]
        local f = math.floor((ms - st.start) / 70)
        if f >= 3 then table.remove(self.stars, i) else BT.draw_item("star", st.x, st.y, f) end
    end
end

-- ---------------------------------------------------------------- draw: the special move's cut-in
function EnsoBattleOverlay:draw_cutin(ms)
    local sk = self.skill
    if not sk then return end
    local t = ms - sk.start
    if t >= CUTIN_MS then
        self.skill = nil
        return
    end
    -- the slash across the field, once the band has closed (the engine deals the damage at 1300 ms)
    if t >= SLASH_AT - 120 and t < SLASH_AT + 380 then
        local f = math.min(2, math.floor((t - SLASH_AT + 120) / 70))
        for i = 0, 2 do
            BT.draw_item("slash", 1120 + i * 250, 820 - (i % 2) * 90, f)
        end
    end
    -- the band over the whole field: opens in 3 steps, holds, closes in 3 steps
    local k
    if t < 150 then k = ({ 0.33, 0.66, 1 })[math.floor(t / 50) + 1]
    elseif t < BAND_END - 150 then k = 1
    elseif t < BAND_END then k = ({ 1, 0.66, 0.33 })[math.floor((t - BAND_END + 150) / 50) + 1]
    else return end
    local top, bottom = 552, 1080
    local full = bottom - top
    local band_h = UI.grid(full * k)
    local y = UI.grid(top + (full - band_h) / 2)
    local col = BT.move_color(sk.move)
    UI.rect(0, y - U, 1920, band_h + 2 * U, P.ink)
    UI.rect(0, y, 1920, band_h, col)
    for i = 0, 9 do       -- speed lines
        local lx = (i * 271 - t * 2.2) % 2100 - 120
        UI.rect(UI.grid(lx), UI.grid(y + 24 + i * (band_h - 48) / 9), 180, U, P.paper)
    end
    if k < 1 then return end
    -- Momo and Hoshi run in from the left, cheering
    local slide = math.min(1, t / 250)
    local foot = bottom - 36
    self.hoshi:draw(-300 + slide * 560, foot - 12, { expr = "cheer", still = true })
    self.momo:draw(-100 + slide * 620, foot, { expr = "cheer", still = true })
    -- the move's name plate slides in from the right
    local name = BT.move_name(sk.move)
    local tt = UI.text(name, 48, "ink")
    local w = math.ceil((UI.text_width(name, 48) + 16 * U) / U) * U
    local px = UI.grid(1260 - w / 2 + (1 - math.min(1, t / 200)) * 400)
    local cy = 780
    local ix, iy, iw, ih = UI.frame(px, UI.grid(cy - 13 * U), w, 26 * U, { fill = P.paper, border = 2 * U, shadow = 2 * U })
    UI.draw_text(tt, ix + iw / 2, iy + ih / 2, "c")
    UI.burst(px + w, cy - 13 * U, t - 200)
end

-- ---------------------------------------------------------------- draw: over the lane
function EnsoBattleOverlay:draw_numbers(ms)
    -- the damage over the creature / boss that took it (rises 2 steps), the drumroll hits beside it
    local n = self.number
    if n and n.x and ms - n.start < NUM_MS then
        local t = ms - n.start
        local lift = (t < 50) and 0 or ((t < 100) and U or 2 * U)
        BT.num_chip(n.value, n.x, n.y - 60 - lift, "l", n.critical and P.clear or P.paper)
    end
    for i = #self.rolls, 1, -1 do
        local r = self.rolls[i]
        local t = ms - r.start
        if t >= ROLL_MS then
            table.remove(self.rolls, i)
        else
            BT.num_chip(r.value, r.x, r.y - 40 - math.floor(t / 100) * U, "s", P.paper)
        end
    end
end

-- the judgement at the hit circle, as in normal play: the circle flash, then 良 / 可 / 不可 above the circle
-- (hit_effect textures carry their own positions; the lane's top is judge y - 110)
local function jt(key)
    local t = judge_tex[key]
    if t == nil then
        t = tex.get_texture("hit_effect/" .. key) or false
        judge_tex[key] = t
    end
    return t or nil
end

function EnsoBattleOverlay:track_bad(ms)
    local p = Play.player(1)
    local c = p and p.combo or 0
    if c < self.last_combo and c == 0 and not self.ended then
        self.judgement = { kind = "bad", start = ms }
    end
    self.last_combo = c
end

function EnsoBattleOverlay:draw_judgement(ms)
    local j = self.judgement
    if not j then return end
    local t = ms - j.start
    if t >= JUDGE_MS then
        self.judgement = nil
        return
    end
    local lane_y = self.judge.y - 110
    if j.kind ~= "bad" and t < FLASH_MS then
        local fx = jt("hit_effect_" .. j.kind .. (j.big and "_big" or ""))
        if fx then tex.draw_texture(fx, { x = 0, y = lane_y }) end
    end
    local text_t = jt("judge_" .. j.kind)
    if text_t then
        local rise = (t < 50) and 2 * U or ((t < 100) and U or 0)
        tex.draw_texture(text_t, { x = 0, y = lane_y + rise })
    end
end

function EnsoBattleOverlay:draw_panels(ms)
    -- kills (top left), battle power under it; chests + skill meter under the lane
    local k = self.kills
    local x, y = 24, 24
    local ix, iy, iw, ih = UI.frame(x, y, 435, 105, { fill = P.paper, border = 2 * U, shadow = 2 * U })
    UI.draw_text(UI.text_key("bt_kills", 36), ix + 5 * U, iy + ih / 2, "l")
    local bump = (k.pop and ms - k.pop < 80) and -U or 0
    UI.num(tostring(k.shown), ix + iw - 5 * U, iy + ih / 2 + bump, "xl", P.ink, 255, "r")

    ix, iy, iw, ih = UI.frame(x, 141, 435, 66, { fill = P.paper })
    UI.rect(ix, iy, 2 * U, ih, P.p1)
    UI.draw_text(UI.text_key("bt_power", 24), ix + 5 * U, iy + ih / 2, "l")
    UI.num(tostring(self.power), ix + iw - 4 * U, iy + ih / 2, "l", P.ink, 255, "r")

    -- best power banner: slides out of the power panel for 2.4 s
    if self.best_at then
        local t = ms - self.best_at
        if t < 2400 then
            local s = UI.text_key("bt_new_best", 24, ON_ACC)
            local w = math.ceil((s.width + 8 * U) / U) * U
            local bx = UI.grid(471 - (t < 150 and (1 - t / 150) * w or 0))
            local bix, biy, biw, bih = UI.frame(bx, 147, w, 54, { fill = P.clear })
            UI.draw_text(s, bix + biw / 2, biy + bih / 2, "c")
            if t < 260 then UI.burst(bx + w, 150, t) end
        end
    end
end

function EnsoBattleOverlay:draw_gauge(ms)
    local x, y, w = 24, 558, 456
    local full = self.fill >= 1
    local ix, iy, iw, ih = UI.frame(x, y, w, 66, { fill = full and P.clear or P.paper })
    local label = full and "bt_skill_ready" or "bt_skill"
    UI.draw_text(UI.text_key(label, 24, full and ON_ACC or "ink"), ix + 4 * U, iy + ih / 2, "l")
    local bx = ix + 50 * U
    local fill_col = full and ((math.floor(ms / 120) % 2 == 0) and P.don or P.oni) or P.pink
    UI.pixbar(bx, iy + 4 * U, ix + iw - 4 * U - bx, ih - 8 * U, self.fill, fill_col, 5)
    -- chests found so far
    local cx = x + w + 6 * U
    local n = self.chest_count
    if n.gold > 0 or n.orb > 0 then
        local cw = 108 + (n.orb > 0 and 108 or 0)
        local cix, ciy, ciw, cih = UI.frame(cx, y, cw + 6 * U, 66, { fill = P.paper })
        BT.draw_item("chest", cix + 30, ciy + cih / 2 - 8)
        UI.num(tostring(n.gold), cix + 72, ciy + cih / 2, "m", P.ink, 255, "l")
        if n.orb > 0 then
            BT.draw_item("orb", cix + 138, ciy + cih / 2 - 8)
            UI.num(tostring(n.orb), cix + 180, ciy + cih / 2, "m", P.ink, 255, "l")
        end
    end
end

function EnsoBattleOverlay:draw_boss_gauge(ms)
    local f = self.fight
    if not f then return end
    local x, y, w, h = 1008, 564, 888, 78
    local ix, iy, iw, ih = UI.frame(x, y, w, h, { fill = P.paper, border = 2 * U, shadow = 2 * U })
    local name = UI.text(BT.boss_name(self.stage), 24, "ink")
    UI.draw_text(name, ix + 4 * U, iy + ih / 2, "l")
    local frac = clamp01(f.shown / f.max)
    local bx = ix + 8 * U + math.max(240, name.width)
    local warn = frac <= 0.2 and frac > 0 and math.floor(ms / 250) % 2 == 0
    UI.pixbar(bx, iy + 4 * U, ix + iw - 4 * U - bx, ih - 8 * U, frac, warn and P.oni or BT.hp_color(frac), 10)
end

function EnsoBattleOverlay:draw_end(ms)
    if not self.ended then return end
    local t = ms - self.ended - END_DELAY
    if t < 0 then return end
    local key = "bt_battle_end"
    if self.fight and self.fight.hp <= 0 then key = "bt_boss_down"
    elseif self.full_combo then key = "bt_full_combo" end
    local s = UI.text_key(key, 48, "ink")
    local w = math.ceil((s.width + 24 * U) / U) * U
    local h = 36 * U
    local x, y = UI.grid(960 - w / 2), UI.grid(760 - h / 2)
    local ox, oy, ow, oh, done = UI.open_rect(x, y, w, h, t)
    if not ox then return end
    local fill = (key == "bt_battle_end") and P.paper or P.clear
    UI.frame(ox, oy, ow, oh, { fill = fill, border = 2 * U, shadow = 2 * U })
    if done then
        UI.draw_text(UI.text_key(key, 48, fill == P.paper and "ink" or ON_ACC), 960, y + h / 2, "c")
        UI.burst(x, y, t - 100)
        UI.burst(x + w, y + h, t - 200)
    end
end

function EnsoBattleOverlay:draw_front(ms)
    self:track_bad(ms)
    self:draw_judgement(ms)
    self:draw_panels(ms)
    self:draw_gauge(ms)
    self:draw_boss_gauge(ms)
    self:draw_numbers(ms)
    self:draw_end(ms)
end
