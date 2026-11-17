BattleResultBoard = {}
BattleResultBoard.__index = BattleResultBoard

local S = tex.get_screen_scale()
local FRAME_MS = 1000 / 60

local PANEL_IN, START = 10, 30
local LEVEL_FRAMES, COUNT_FRAMES, STEP_WAIT = 30, 40, 20
local CHEST_STEP, PLAYER_WAIT = 25, 600

local PRIZE_FRAMES, PRIZE_X, PRIZE_Y, PRIZE_ENEMY_DY = 120, 879, 426, -64
local PRIZE_KIND = { song = "ai_reward_song", costume = "battle_reward_costume", title = "ai_reward_title" }
local BOSS_REWARD_DY = 68
local CHEST_X, CHEST_Y = { 773, 851, 929 }, 273

local MOVE_UNLOCKS = { 0, 1, 2, 3, 5, 6, 7, 8, 9 }
local MOVE_HACCHAKE, EX_STAGE = 4, 11

local ORB_SWAP = 15
-- jingle + Don's line after the last count-up; Amitie answers in the next story intro
local OUTCOMES = {
    maou = { "jingle_boss_maou", "vo_lastboss_don" },
    lastboss = { "jingle_lastboss", "vo_lastboss_don" },
    boss = { "jingle_boss", "vo_boss_don" },
    stage = { "jingle_stage", "vo_stage_don" },
    update = { "jingle_update", "vo_update_don" },
}
local MOVE_FRAMES, COMPLETE_FRAMES, BANNER_AT = 150, 240, 104
local BOSS_BANNER_X, BOSS_BANNER_Y = 403, 493

local WINDOW_SHAFTS = {
    { -151.65, 24, 4.801, 0.832, 21, 0.75 }, { 187.15, -93.8, 0.688, 0.466, 21, 1, true },
    { -241.05, -47.6, 0.828, 0.446, 26, 1, true },
}

local STREAKS = {
    { 0, 0.75, 0, 57, 94, 392.3, 25, -402.6, 1, 1, 1 },
    { 47.35, 0.312, 34, 89, 134, 210.3, 70, -422.65, 1, 1, 1 },
    { 71.35, 0.75, 59, 95, 137, 283.3, -145, -409.25, 0.151, 0.904, 0.151 },
}

local LEVEL_SPARKLES = { { -59, -63, 1, 5 }, { 52, -43, 0.917, 6 }, { 22, 65, 0.667, 7 }, { -76, 3, 0.833, 8 } }

local BANNER_SPARKLES = {
    { "complete_sparkle", 2.35, -41.65, 10 }, { "chest_sparkle", 31, -48.65, 25 }, { "chest_sparkle", -27, -49.65, 0 },
    { "chest_sparkle", -113, 34.95, 20 }, { "complete_sparkle", 95.35, 33.3, 0 },
}

local WHITE, BLACK = { 255, 255, 255, 255 }, { 0, 0, 0, 255 }

local function clamp01(v) return math.max(0, math.min(1, v)) end
local function ramp(t, at, len) return clamp01((t - at) / len) end
local function lerp(a, b, u) return a + (b - a) * u end

local function swell(u) return 1 - math.abs(2 * u - 1) end
local function ease_out(u) return 1 - (1 - u) * (1 - u) end
local function pop(t, at)
    if t < at then return 0 end
    local u = t - at
    return u < 6 and lerp(1.4, 0.9, u / 6) or u < 10 and lerp(0.9, 1, (u - 6) / 4) or 1
end

local function tip_rows(key)
    local rows = {}
    for row in (tex.skin_text(key) .. "\n"):gmatch("(.-)\n") do
        rows[#rows + 1] = text.create_raw_text(row, 20, BLACK, WHITE, false, 4, 2)
    end
    return rows
end

local function play(name)
    if audio.has_sound(name) then audio.play_sound(name, name:find("^vo_") and "voice" or "sound") end
end

function BattleResultBoard.new(data)
    local self = setmetatable({}, BattleResultBoard)
    self.ids, self.sizes = {}, {}
    self.data = data
    self.f = 0
    self.started = false
    self.played = {}
    tex.load_folder("battle_result", "board")
    if audio.has_sound("battle_bgm") then audio.play_sound("battle_bgm", "music") end
    return self
end

local function level_segments(before, after)
    local fill = function(s) return s.exp_next > 0 and s.exp / s.exp_next or 1 end
    if after.bond == before.bond then
        return { { level = before.bond, from = fill(before), to = fill(after) } }
    end
    local segs = { { level = before.bond, from = fill(before), to = 1, up = true } }
    for level = before.bond + 1, after.bond - 1 do
        segs[#segs + 1] = { level = level, from = 0, to = 1, up = true }
    end
    segs[#segs + 1] = { level = after.bond, from = 0, to = fill(after) }
    return segs
end

function BattleResultBoard:begin(answer)
    local d = self.data
    self.answer = answer
    self.start_ms = nil
    self.f = 0
    self.played = {}
    self.leaving = false
    local t = START
    if answer then
        self.segs = level_segments(answer.before, answer.after)
        self.exp_at = t
        t = t + #self.segs * LEVEL_FRAMES + STEP_WAIT
    end
    self.power_at = t
    t = t + COUNT_FRAMES + STEP_WAIT
    self.fight_at = t
    t = t + COUNT_FRAMES + STEP_WAIT
    if d.boss then t = t + 30 end
    self.boss = answer and answer.boss or (d.boss and {
        hp_before = d.boss_hp, hp_after = math.max(0, d.boss_hp - d.damage), max = d.boss_hp_max,
    }) or nil
    if answer then
        self.chest_at = t
        t = t + #answer.chests * CHEST_STEP + (#answer.chests > 0 and STEP_WAIT or 0)
        self.unlocked = answer.after.moves > answer.before.moves
        if self.unlocked then
            self.move_at = t
            self.move_complete = answer.after.move_cost < 0
            self.move_id = MOVE_UNLOCKS[answer.after.moves] or 0
            self.move_kind = text.create_text("battle_reward_move", WHITE, BLACK, false, 5, 2)
            self.tip = tip_rows("battle_tip_move")
            self.move_len = self.move_complete and COMPLETE_FRAMES or MOVE_FRAMES
            t = t + self.move_len
        end

        if answer.before.orb_cost > 0 then
            self.orb_swap_at = t
            self.orb_at = t + ORB_SWAP
            t = self.orb_at + #answer.orb_chests * CHEST_STEP + STEP_WAIT
            local orb = answer.orb_reward
            if orb then
                self.orb_prize_at = t
                t = t + MOVE_FRAMES
                local move = orb.kind == "move"
                self.orb_kind = text.create_text(move and "battle_reward_move" or PRIZE_KIND.song, WHITE, BLACK, false,
                    5, 2)
                self.orb_name = not move and text.create_raw_text(orb.name, 30, WHITE, BLACK, false, 5, 2) or nil
                self.orb_tip = tip_rows(move and "battle_tip_move" or "battle_tip_maou")
            end
        end
    end
    local prize = answer and answer.reward
    if prize and PRIZE_KIND[prize.kind] then
        self.prize_at = t
        t = t + PRIZE_FRAMES
        self.prize_kind = text.create_text(PRIZE_KIND[prize.kind], WHITE, BLACK, false, 5, 2)
        self.prize_name = text.create_raw_text(prize.name, 30, WHITE, BLACK, false, 5, 2)
    end
    self.end_at = t
    self.deadline = t + PLAYER_WAIT
    self.best = answer and d.power > answer.before.best_power
    self.outcome = answer and self:outcome_of(answer)
    self.started = true
    play("vo_call")
end

function BattleResultBoard:outcome_of(a)
    if a.boss and a.boss.hp_before > 0 and a.boss.hp_after == 0 then
        local stage = self.data.stage
        return OUTCOMES[stage == EX_STAGE and "maou" or stage >= 10 and "lastboss" or "boss"]
    end
    if a.after.stage > a.before.stage then return OUTCOMES.stage end
    return self.best and OUTCOMES.update or nil
end

function BattleResultBoard:jingle(name)
    if not audio.has_sound(name) then return end
    audio.stop_sound("battle_bgm")
    if self.jingle_playing then audio.stop_sound(self.jingle_playing) end
    self.jingle_playing = name
    audio.play_sound(name, "music")
end

function BattleResultBoard:decide()
    if self.leaving or not self.started then return false end
    if self.f < self.end_at then
        self.start_ms = self.now_ms - self.end_at * FRAME_MS
        self.f = self.end_at
        self.skipped = true
        return true
    end
    self.leaving = true
    return true
end

function BattleResultBoard:is_done()
    return self.leaving
end

function BattleResultBoard:once(key, at)
    if not self.played[key] and self.f >= at then
        self.played[key] = true
        return not self.skipped
    end
    return false
end

function BattleResultBoard:update(ms)
    self.now_ms = ms
    if not self.started then return end
    self.start_ms = self.start_ms or ms
    self.f = (ms - self.start_ms) / FRAME_MS
    local d, a = self.data, self.answer
    if self.segs then
        for i, seg in ipairs(self.segs) do
            local at = self.exp_at + (i - 1) * LEVEL_FRAMES
            if self:once("exp" .. i, at) then play("num_up") end
            if seg.up and self:once("lvup" .. i, at + LEVEL_FRAMES) then
                play("se_lvup")
                if i == 1 then play("vo_lvup") end
            elseif not seg.up and self:once("exp_end" .. i, at + LEVEL_FRAMES) then
                play("se_gauge_kime")
            end
        end
    end
    if self:once("power", self.power_at) then play("num_up") end
    if self:once("power_end", self.power_at + COUNT_FRAMES) then
        play("se_gauge_kime")
        play("se_power_up")
    end
    if self:once("fight", self.fight_at) then
        play("num_up")
        play("vo_dondon")
    end
    if self:once("fight_end", self.fight_at + COUNT_FRAMES) then
        play("se_gauge_kime")
        if self.boss then
            local won = self.boss.hp_after == 0
            play(won and "se_boss_win" or "vo_boss_fail")
            if won then
                play("vo_boss_win")
                self:jingle(self.data.stage == EX_STAGE and "jingle_win_maou" or "jingle_win")
            end
        end
    end
    if a then
        for i, n in ipairs(a.chests) do
            if self:once("chest" .. i, self.chest_at + (i - 1) * CHEST_STEP) then
                play("se_treasure")
                play("se_gohoubi_light")
                play(n >= 5 and "se_treasure_big" or "se_treasure_small")
            end
        end
        if self.unlocked and self:once("reward", self.move_at) then
            play("se_reward_window")
            play("vo_reward_get")
        end
        if self.move_complete and self:once("complete", self.move_at + BANNER_AT) then
            play("se_complete")
            play("se_gohoubi_stamp")
        end
        for i, n in ipairs(self.orb_at and a.orb_chests or {}) do
            if self:once("orb_chest" .. i, self.orb_at + (i - 1) * CHEST_STEP) then
                play("se_treasure")
                play("se_gohoubi_light")
                play(n >= 5 and "se_treasure_big" or "se_treasure_small")
            end
        end
        if self.orb_prize_at and self:once("orb_prize", self.orb_prize_at) then
            play("se_reward_window")
            play("vo_reward_get")
        end
    end
    if self.prize_at and self:once("prize", self.prize_at) then
        play("se_reward_window")
        play("vo_reward_get")
    end
    local o = self.outcome
    if o and self.f >= self.end_at and not self.played.outcome then
        self.played.outcome = true
        self:jingle(o[1])
        play(o[2])
    end
    if self.f >= self.deadline then self.leaving = true end
end

function BattleResultBoard:put(key, cx, cy, o)
    o = o or {}
    local path = (o.dir or "battle_result/board") .. "/" .. key
    local id = self.ids[path]
    if id == nil then
        id = tex.get_texture(path)
        self.ids[path] = id
        self.sizes[path] = tex.get_texture_info(path:match("([^/]+)/[^/]+$"), key)
    end
    local info = self.sizes[path]
    if not info then return end
    local sx, sy = o.sx or o.s or 1, o.sy or o.s or 1
    local w, h = info.width * S, info.height * S
    tex.draw_texture(id, {
        x = cx * S, y = cy * S,
        x2 = w * (sx - 1), y2 = h * (sy - 1),
        origin = { w * sx * 0.5, h * sy * 0.5 },
        fade = o.fade or 1,
        frame = o.frame or 0,
        blend = o.add and "additive" or nil,
    })
end

function BattleResultBoard:bar(key, left, cy, width, u, o)
    if u <= 0 then return end
    o = o or {}
    o.sx = u
    self:put(key, left + width * u * 0.5, cy, o)
end

function BattleResultBoard:number(key, value, right_x, y, step, o)
    value = math.max(0, math.floor(value))
    local x = right_x
    repeat
        o = o or {}
        o.frame = value % 10
        self:put(key, x, y, o)
        value = value // 10
        x = x - step
    until value == 0
    return x
end

function BattleResultBoard:draw_background()
    local stage = self.data.stage
    self:put("stage", 640, 360, { frame = (self.data.boss or stage % 2 == 1) and stage - 1 or stage - 2 })
    self:put("header_band", 638, 47)
    self:put("title", 182, 45)
    self:put("song_count", 323, 44, { frame = math.max(0, math.min(3, self.data.song_number - 1)) })
    self:put("stage_plate", 110, 115)
    if stage == EX_STAGE then
        self:put("stage_ex", 133, 107)
    else
        self:number("stage_digits", stage, 138, 107, 10)
    end
    if self.started and self.f >= self.end_at then
        self:put("skip_hint", 1082, 688, { fade = 0.6 + 0.4 * math.cos(self.f / 20) })
    end
end

function BattleResultBoard:draw_bond(fade)
    local a = self.answer
    self:put("bond_panel", 491, 288, { fade = fade })
    self:put("partner", 369, 282, { s = 0.62, fade = fade })
    self:put("exp_gauge_back", 550, 329, { fade = fade })
    local level, fill, up_at = self.data.bond, 0, nil
    if a then
        local t = self.f - self.exp_at
        local idx = math.max(1, math.min(#self.segs, math.floor(t / LEVEL_FRAMES) + 1))
        local seg = self.segs[idx]
        level = seg.level
        fill = lerp(seg.from, seg.to, ease_out(ramp(t, (idx - 1) * LEVEL_FRAMES, LEVEL_FRAMES)))
        if t >= LEVEL_FRAMES then
            for i = idx - 1, 1, -1 do
                if self.segs[i].up then up_at = self.exp_at + i * LEVEL_FRAMES break end
            end
        end
        if t < 0 then level, fill = a.before.bond, self.segs[1].from end
    end
    self:bar(fill >= 1 and "exp_gauge_full" or "exp_gauge_fill", 440, 329, 220, fill, { fade = fade })
    self:put("exp_gauge_frame", 550, 329, { fade = fade })
    local digits = up_at and "bond_digits_up" or "bond_digits"
    local s = up_at and pop(self.f, up_at) or 1
    self:number(digits, level, 644, 298, 24, { s = s, fade = fade })
    if up_at then
        local u = self.f - up_at
        self:put("bond_glow", 637, 297, { add = true, fade = fade * (1 - ramp(u, 0, 20)) })
        local flash = ramp(u, 0, 15)
        self:put("levelup_flash", 375, 292, { add = true, s = lerp(1, 1.3, flash), fade = fade * (1 - flash) })
        self:put("levelup_gauge", 550, 329, { sx = 0.995, sy = 1.1, fade = fade })
        self:put("levelup_glow", 550, 327, { fade = fade * (0.6 + 0.4 * math.cos(u / 10)) })
        if u >= 25 then self:put("levelup_shine", 550, 329, { sx = 1.032, sy = 1.1, add = true, fade = fade }) end
        self:put("levelup_text", 550, 327, { s = pop(self.f, up_at), fade = fade })
        for _, s in ipairs(LEVEL_SPARKLES) do
            local v = u - s[4]
            if v >= 0 and v < 80 then
                self:put("levelup_sparkle", 374 + s[1], 292 + s[2],
                    { s = s[3], add = true, fade = fade * swell(v % 40 / 40) })
            end
        end
    end
end

function BattleResultBoard:draw_power(fade)
    local d = self.data
    local u = ease_out(ramp(self.f, self.power_at, COUNT_FRAMES))
    self:put("power_box", 491, 404, { fade = fade })
    self:number("count_digits", d.power * u, 633, 403, 23, { fade = fade })
    if self.best and self.f >= self.power_at + COUNT_FRAMES then
        local t = self.f - self.power_at - COUNT_FRAMES
        local y = 369 + lerp(47, 0, ease_out(ramp(t, 0, 15))) - 3 * math.sin(t / 20)
        local f = fade * ramp(t, 0, 15)
        self:put("best_bubble", 560, y, { s = 0.934, fade = f })
        local left = self:number("best_digits", d.power - self.answer.before.best_power, 659, y + 1, 15, { fade = f })
        self:put("best_plus", left + 2, y + 1, { fade = f })
    end
end

function BattleResultBoard:draw_fight(fade)
    local d = self.data
    local u = ease_out(ramp(self.f, self.fight_at, COUNT_FRAMES))
    if not self.boss then
        self:put("kills_box", 491, 480, { fade = fade })
        self:number("count_digits", d.kills * u, 633, 493, 23, { fade = fade })
        return
    end
    local b = self.boss
    self:put("damage_box", 491, 527, { fade = fade })
    self:number("damage_digits", d.damage * u, 645, 562, 20, { fade = fade })
    local max = math.max(1, b.max)
    local before, now = b.hp_before / max, lerp(b.hp_before, b.hp_after, u) / max
    self:put("boss_gauge_back", 429, 525, { fade = fade })
    self:bar("boss_gauge_lost", 319, 525, 220, before, { fade = fade })
    local color = now > 0.5 and 0 or now > 0.2 and 1 or 2
    self:bar("boss_gauge_fill", 319, 525, 220, now, { frame = color, fade = fade })
    self:put("boss_life_frame", 427, 518, { fade = fade })
    if now > 0 then self:put("boss_gauge_marker", 319 + 220 * now, 524, { fade = fade }) end
    local t = self.f - self.fight_at - COUNT_FRAMES
    if t >= 0 then self:draw_boss_banner(t, b.hp_after == 0, fade) end
end

function BattleResultBoard:draw_boss_banner(t, won, fade)
    local x, y = BOSS_BANNER_X, BOSS_BANNER_Y
    if won then
        local w = t < 16 and math.min(t / 7, (16 - t) / 9) or t < 21 and 0 or swell((t - 21) % 70 / 70)
        self:put("boss_clear_burst", x, y + 1, { sx = 1 + 0.059 * w, sy = 1 + 0.077 * w, fade = fade })
        self:put("boss_clear_text", x, y - 1, { s = 1 + 0.04 * swell(ramp(t, 0, 15)), fade = fade })
    else
        local w = t < 19 and t / 19 * 0.25 or swell((t - 19) % 71 / 71)
        self:put("boss_replay_cloud", x - 1, y - 8, { s = 1 + 0.035 * w, fade = fade * ramp(t, 0, 6) })
        if t >= 6 then self:put("boss_replay_text", x, y - 10, { fade = fade }) end
    end
end

function BattleResultBoard:draw_reward(fade, orbs)
    local a = self.answer
    local dy = self.data.boss and BOSS_REWARD_DY or 0
    local pre = orbs and "orb_" or ""
    local at0, chests = orbs and self.orb_at or self.chest_at, orbs and a.orb_chests or a.chests
    local got_at = orbs and self.orb_prize_at or self.move_at
    local got = got_at and self.f >= got_at
    local before, after = a.before, a.after
    local complete
    if orbs then
        complete = after.orb_rewards >= 2 and (not got_at or got)
    else
        complete = after.move_cost < 0 and (not self.unlocked or got)
    end
    self:put("reward_back", 849, 343 + dy, { fade = fade })
    if complete then
        self:put("reward_complete", 850, 352 + dy, { fade = fade })
        return
    end
    self:put(orbs and "orb_label" or "stone_label", 848, 194 + dy, { fade = fade })
    local count = orbs and before.orbs or before.stones
    for i, n in ipairs(chests) do
        local at = at0 + (i - 1) * CHEST_STEP
        local x, y = CHEST_X[i], CHEST_Y + dy
        if self.f < at then
            self:put(pre .. "chest_closed", x, y, { fade = fade })
        else
            count = count + n
            local t = self.f - at
            local glow = t < 72 and lerp(1, 0.578, t / 72) or 0.578 + 0.422 * swell((t - 72) % 104 / 104)
            if n >= 5 then
                self:put(pre .. "chest_glow", x, y, { fade = fade * glow })
                self:put(pre .. "chest_open", x, y - 4, { fade = fade })
            else
                self:put(pre .. "chest_glow_small", x, y, { fade = fade * glow })
                self:put(pre .. "chest_open_small", x, y, { fade = fade })
                if n >= 3 then
                    local rays = t < 32 and 1 - t / 32 or t < 52 and (t - 32) / 20
                        or 1 - 0.22 * swell((t - 52) % 104 / 104)
                    self:put("chest_rays", x, y, { fade = fade * rays })
                end
            end
            local frame = n >= 5 and 2 or n >= 3 and 1 or 0
            local rise = 30 + 10 * ease_out(ramp(t, 0, 10))
            self:put(orbs and "orb_chest_orbs" or "chest_stones", x, y - rise, { frame = frame, s = pop(self.f, at),
                fade = fade })
            if t < 20 then
                self:put("chest_sparkle", x + 30, y - 30, { s = 1 + t / 20, fade = fade * (1 - t / 20) })
            end
        end
    end
    local cost = orbs and before.orb_cost or before.move_cost
    if got then
        count, cost = orbs and after.orbs or after.stones, orbs and after.orb_cost or after.move_cost
    end
    self:number("stone_digits", count, 826, 357 + dy, 25, { fade = fade })
    self:put("stone_slash", 862, 357 + dy, { fade = fade })
    if cost >= 0 then self:number("stone_digits", cost, 940, 357 + dy, 25, { fade = fade }) end
    if orbs then
        self:put("orb_next_box", 849, 446 + dy, { fade = fade * 0.891 })
    else
        self:put("next_box", 849, 448 + dy, { fade = fade })
    end
end

function BattleResultBoard:draw_window(fade, t, kind, name, tip, complete, move_id)
    local grow, settle = ramp(t, 0, 16), ramp(t, 16, 3)
    local sx, sy = lerp(lerp(1, 1.25, grow), 1, settle), lerp(lerp(0.14, 1.25, grow), 1, settle)
    local a = fade * grow
    local cy = PRIZE_Y + (self.data.boss and 0 or PRIZE_ENEMY_DY) + lerp(8, 0, grow)
    local function part(key, ox, oy, o)
        o = o or {}
        o.sx, o.sy = (o.sx or o.s or 1) * sx, (o.sy or o.s or 1) * sy
        o.fade = (o.fade or 1) * a
        self:put(key, PRIZE_X + ox * sx, cy + oy * sy, o)
    end
    local function label(obj, oy, f)
        obj:draw({ x = PRIZE_X * S - obj.width / 2, y = (cy + oy * sy) * S - obj.height / 2, fade = f })
    end
    local function shafts(front)
        for _, p in ipairs(WINDOW_SHAFTS) do
            if (p[7] or false) == front and t >= p[5] then
                local l = (t - p[5]) % 138
                for _, s in ipairs(STREAKS) do
                    if l >= s[3] and l <= s[5] then
                        local rise = l <= s[4]
                        local u = rise and (l - s[3]) / (s[4] - s[3]) or (l - s[4]) / (s[5] - s[4])
                        local y = rise and lerp(s[6], s[7], u) or lerp(s[7], s[8], u)
                        local ys = rise and lerp(s[9], s[10], u) or lerp(s[10], s[11], u)
                        part("window_streak", p[1] + s[1] * p[3], p[2] + y * p[4],
                            { sx = s[2] * p[3], sy = ys * p[4], fade = p[6] * (rise and u or 1 - u) })
                    end
                end
            end
        end
    end
    local breath = t < 21 and 1 or 1 - 0.7 * swell((t - 21) % 94 / 94)
    shafts(false)
    part("reward_window_glow", 0, 0, { fade = t < 21 and 1 or 0.6 + 0.4 * swell((t - 21) % 94 / 94) })
    part("reward_window", 0, 0)
    local h = t % 130
    for i, word in ipairs({ { "reward_new", -110, 0 }, { "reward_get", 2, 22 }, { "reward_got", 118, 40 } }) do
        local u = h - word[3]
        local hop = u >= 0 and u < 21 and 7 * (1 - math.abs(u - 10) / 10) or 0
        part(word[1], word[2], -123 - hop)
    end
    local plate = t < 12 and 1 or t < 17 and lerp(1, 1.222, (t - 12) / 5) or lerp(1.222, 1, ramp(t, 17, 3))
    if t >= 21 then part("reward_plate_glow", 1, -16, { fade = breath }) end
    part("reward_plate", 0, -15, { s = plate })
    local tf = a * ramp(t, 12, 8)
    label(kind, -32, tf)
    if name then
        label(name, -2, tf)
    else
        part("skill_name", 0, -2, { dir = "song_select/enso_battle", frame = move_id, fade = ramp(t, 12, 8) })
    end
    if tip and not (complete and t >= BANNER_AT) then
        for i, row in ipairs(tip) do label(row, 80 + (i - (#tip + 1) / 2) * 26, a * ramp(t, 17, 3)) end
    end
    shafts(true)
    if complete and t >= BANNER_AT then
        local u = t - BANNER_AT
        local s = u < 5 and lerp(1, 1.83, u / 5) or u < 14 and lerp(1.715, 0.915, (u - 6) / 8) or
            lerp(0.943, 1, ramp(u, 14, 2))
        part("complete_banner", -1, 85, { s = s, fade = ramp(u, 0, 5) })
        for _, k in ipairs(BANNER_SPARKLES) do
            part(k[1], k[2] - 1, k[3] + 85, { fade = ramp(u, 0, 5) * swell((u - k[4] + 50) % 100 / 100) })
        end
    end
end

function BattleResultBoard:nameplate_pos()
    if not self.started then return nil end
    return { 285 * S, 157 * S, ramp(self.f, 0, PANEL_IN) }
end

function BattleResultBoard:draw()
    if not self.started then return end
    local fade = ramp(self.f, 0, PANEL_IN)
    local d = self.data
    local side = d.player == 2 and "_2p" or ""
    if d.boss then
        self:put("panel_boss" .. side, 646, 380, { fade = fade })
    else
        self:put("panel_enemy" .. side, 645, 345, { fade = fade })
    end
    self:put("difficulty", 620, 212, { frame = math.max(0, math.min(4, d.difficulty)), fade = fade })
    self:draw_bond(fade)
    self:draw_power(fade)
    self:draw_fight(fade)
    if self.prize_at and self.f >= self.prize_at then
        self:draw_window(fade, self.f - self.prize_at, self.prize_kind, self.prize_name)
    elseif self.orb_prize_at and self.f >= self.orb_prize_at then
        self:draw_window(fade, self.f - self.orb_prize_at, self.orb_kind, self.orb_name, self.orb_tip, false,
            MOVE_HACCHAKE)
    elseif self.move_at and self.f >= self.move_at and self.f < self.move_at + self.move_len then
        self:draw_window(fade, self.f - self.move_at, self.move_kind, nil, self.tip, self.move_complete, self.move_id)
    elseif self.orb_swap_at and self.f >= self.orb_swap_at then
        local u = ramp(self.f, self.orb_swap_at, ORB_SWAP)
        if u < 1 then self:draw_reward(fade * (1 - u)) end
        self:draw_reward(fade * u, true)
    elseif self.answer then
        self:draw_reward(fade)
    end
end
