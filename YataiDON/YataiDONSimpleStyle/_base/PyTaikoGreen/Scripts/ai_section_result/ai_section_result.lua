AISectionBoard = {}
AISectionBoard.__index = AISectionBoard

local S = tex.get_screen_scale()
local FRAME_MS = 1000 / 60

local SECTION_END_WAIT, TOTAL_WAIT = 60, 60
local PLAYER_WAIT, DETAIL_WAIT = 600, 1200
local BADGE_FIRST_WAIT, BADGE_CHALLENGE_WAIT, BADGE_UNMET_WAIT = 60, 90, 60
local VOICE_WAIT, TOKEN_WAIT, WIN_WAIT = 60, 120, 210
local TOKEN_STEP, COUNT_FRAMES = 15, 30
local BOARD_FADE = 10

local RANK_MAX = 11
local LOGO_X, LOGO_DETAIL_X, LOGO_Y = 889, 1089, 502

local SIMPLE = {
    [3] = { x = { 300, 428, 556 }, y = { 485, 539, 485 } },
    [5] = { x = { 116, 244, 372, 500, 628 }, y = { 485, 539, 485, 539, 485 } },
}
local DETAIL = {
    [3] = { x = { 322, 510.5, 699 }, y = { 510, 528, 510 } },
    [5] = { x = { 168, 328, 488, 648, 808 }, y = { 510, 536, 510, 536, 510 } },
}
local ROW_COUNT_Y = { -1, 32, 65, 99 }
local ROW_DIFF_Y = { 0, 33, 66, 99 }
local ROW_KEYS = { "good", "ok", "bad", "drumroll" }

local function clamp01(v) return math.max(0, math.min(1, v)) end
local function ramp(t, at, len) return clamp01((t - at) / len) end
local function lerp(a, b, u) return a + (b - a) * u end

local function play(name)
    if audio.has_sound(name) then audio.play_sound(name, name:find("^vo_") and "voice" or "sound") end
end

local function beats_best(now, best)
    if now.good ~= best.good then return now.good > best.good end
    if now.ok ~= best.ok then return now.ok > best.ok end
    if now.bad ~= best.bad then return now.bad < best.bad end
    return now.drumroll > best.drumroll
end
local function no_best(best)
    return not best or (best.good == 0 and best.ok == 0 and best.bad == 0 and best.drumroll == 0)
end

function AISectionBoard.new(data)
    local self = setmetatable({}, AISectionBoard)
    self.sizes, self.ids = {}, {}
    self.sections = data.sections
    self.count = #data.sections
    self.won = data.won
    self.f = 0
    self.started = false
    tex.load_folder("ai_section_result", "ai_background")
    tex.load_folder("ai_section_result", "ai_board")
    if audio.has_sound("ai_bgm") then audio.play_sound("ai_bgm", "music") end
    return self
end

function AISectionBoard:begin(progress)
    self.progress = progress
    self.first_play = progress == nil
    if progress then
        for i, section in ipairs(self.sections) do
            section.best = progress.bests[i]
            self.first_play = self.first_play or no_best(section.best)
        end
    end
    self.best_updated = {}
    for i, section in ipairs(self.sections) do
        self.best_updated[i] = not self.first_play and beats_best(section, section.best)
    end
    self.start_ms = nil
    self.f = 0
    self.played = {}
    self.total_at = self:simple_end()
    self.rank_at = self.total_at + TOTAL_WAIT
    self.rank_events = self:rank_schedule()
    self.wait_at = self.rank_at + self.rank_events.finish
    self.mode = "simple"
    self.mode_at = 0
    self.leaving = false
    self.detail_seen_at = nil
    self.deadline = self.wait_at + PLAYER_WAIT
    self.started = true
    play("vo_call")
end

function AISectionBoard:simple_end()
    return 15 + SECTION_END_WAIT
end

function AISectionBoard:rank_schedule()
    local p = self.progress
    local events = { finish = 0 }
    if not p or not self.won then return events end
    local t = 0
    if p.tokens_after ~= p.tokens_before and p.rank_before < RANK_MAX then
        if p.challenge then
            t = t + BADGE_CHALLENGE_WAIT
            events.challenge = t
        end
        if p.first then
            t = t + BADGE_FIRST_WAIT
            events.first = t
        end
        t = t + VOICE_WAIT
        if p.first or p.challenge then events.voice = t end
        t = t + TOKEN_WAIT
        events.tokens = t
        t = t + (p.tokens_after - p.tokens_before) * TOKEN_STEP
        events.tokens_end = t
    elseif not p.fulfilled and p.rank_before < RANK_MAX then
        t = t + BADGE_UNMET_WAIT
        events.unmet = t
    end
    t = t + WIN_WAIT
    events.wins = t
    events.finish = t + COUNT_FRAMES
    return events
end

function AISectionBoard:skip_reveal()
    if self.f < self.wait_at then
        self.f = self.wait_at
        self.start_ms = self.now_ms - self.f * FRAME_MS
        for _, key in ipairs({ "popup", "marks", "logo", "challenge", "first", "unmet", "voice" }) do
            self.played[key] = true
        end
        return true
    end
    return false
end

function AISectionBoard:decide()
    if self.leaving then return false end
    if self:skip_reveal() then return true end
    if self.mode == "detail" and self.f < self.mode_at + self:detail_length() then
        self.mode_at = self.f - self:detail_length()
        return true
    end
    self.leaving = true
    return true
end

function AISectionBoard:toggle()
    if self.leaving or self.f < self.wait_at then return false end
    self.mode = self.mode == "simple" and "detail" or "simple"
    self.mode_at = self.f
    self.deadline = self.f + DETAIL_WAIT
    return true
end

function AISectionBoard:detail_length()
    return BOARD_FADE + 2 * COUNT_FRAMES + 20
end

function AISectionBoard:once(key, at)
    if not self.played[key] and self.f >= at then
        self.played[key] = true
        return true
    end
    return false
end

function AISectionBoard:update(ms)
    self.now_ms = ms
    if not self.started then return end
    self.start_ms = self.start_ms or ms
    self.f = (ms - self.start_ms) / FRAME_MS
    if self:once("popup", 5) then play("se_popup") end
    if self:once("marks", 7) then play("se_section_mark") end
    if self:once("logo", self.total_at) then play(self.won and "se_logo_win" or "se_logo_lose") end

    local e, rank_t = self.rank_events, self.rank_at
    if e.challenge and self:once("challenge", rank_t + e.challenge) then play("se_badge") end
    if e.first and self:once("first", rank_t + e.first) then
        play("se_badge")
        if e.challenge then play("se_badge_add") end
    end
    if e.unmet and self:once("unmet", rank_t + e.unmet) then play("se_badge") end
    if e.voice and self:once("voice", rank_t + e.voice) then play("vo_bonus") end
    if e.tokens then
        local steps = math.floor((self.f - rank_t - e.tokens) / TOKEN_STEP)
        if steps >= 0 and steps < self.progress.tokens_after - self.progress.tokens_before
            and self:once("token" .. steps, rank_t + e.tokens + steps * TOKEN_STEP) then
            play("se_count")
        end
    end
    if self:rankup() and e.tokens_end then
        if self:once("rankup", rank_t + e.tokens_end) then play("se_rankup_panel") end
        if self:once("rankup_shine", rank_t + e.tokens_end + 65) then play("se_rankup_shine") end
    end
    if e.wins and self:once("wins", rank_t + e.wins) then play("se_win_count") end

    if self.mode == "detail" and not self.detail_seen_at then self.detail_seen_at = self.mode_at end
    if self.mode == "detail" then
        local t = self.f - self.mode_at
        if t >= BOARD_FADE and t < BOARD_FADE + COUNT_FRAMES and self:once("detail_count", self.mode_at + BOARD_FADE) then
            play("se_count")
        end
        if not self.first_play then
            for _, updated in ipairs(self.best_updated) do
                if updated and self:once("best", self.mode_at + BOARD_FADE + 2 * COUNT_FRAMES) then play("se_best") end
            end
        end
    end
    if self.f >= self.deadline then self.leaving = true end
end

function AISectionBoard:rankup()
    local p = self.progress
    return p and p.next_rank_tokens >= 0 and p.tokens_after >= p.next_rank_tokens
end

function AISectionBoard:is_done()
    return self.leaving
end

function AISectionBoard:put(folder, key, cx, cy, o)
    o = o or {}
    local path = folder .. "/" .. key
    local id = self.ids[path]
    if id == nil then
        id = tex.get_texture("ai_section_result/" .. path)
        self.ids[path] = id
        self.sizes[path] = tex.get_texture_info(folder, key)
    end
    local info = self.sizes[path]
    if not info then return end
    local sx, sy = o.sx or o.s or 1, o.sy or o.s or 1
    local w, h = info.width * S, info.height * S
    tex.draw_texture(id, {
        x = cx * S, y = cy * S,
        x2 = w * (sx - 1), y2 = h * (sy - 1),
        origin = { w * sx * 0.5, h * sy * 0.5 },
        rotation = o.rot or 0,
        fade = o.fade or 1,
        frame = o.frame or 0,
        mirror = o.mirror,
        blend = o.add and "additive" or nil,
    })
end

function AISectionBoard:board(key, cx, cy, o)
    self:put("ai_board", key, cx, cy, o)
end

function AISectionBoard:draw_background()
    self.bg_start = self.bg_start or self.now_ms or 0
    local f = ((self.now_ms or 0) - self.bg_start) / FRAME_MS
    local bg = "ai_background"
    if self.won then
        self:put(bg, "gradient_win", 640, 360, { sx = 160 })
        for k = 0, 1 do
            local u = ((f * 1.35 + k * 425) % 850) / 850
            self:put(bg, "pattern", 640, 844 - u * 850, {
                fade = 0.13 * math.sin(math.pi * u), add = true, mirror = k == 0 and "horizontal" or nil,
            })
        end
        for k = 0, 2 do
            local u = ((f * 0.5 + k * 280) % 840) / 840
            self:put(bg, "triangle", 300 + k * 340, 800 - u * 880, { rot = f * 1.7 + k * 120, fade = 0.4 })
        end
    else
        self:put(bg, "gradient_lose", 640, 360, { sx = 160 })
        for k = 0, 2 do
            local u = ((f * 1.55 + k * 640) % 1920) / 1920
            self:put(bg, "pattern", -320 + u * 1920, 364, { fade = 0.13 * math.sin(math.pi * u), add = true })
        end
    end
end

function AISectionBoard:draw_simple(fade)
    local layout = SIMPLE[self.count]
    if not layout or fade <= 0 then return end
    local t = self.f
    for i, section in ipairs(self.sections) do
        local x, y = layout.x[i], layout.y[i]
        self:board("section_back", x, y, { fade = fade })
        self:board("section_back_top", x, y, { fade = fade })
        if section.won then
            local s = t < 7 and 1 or t < 10 and lerp(0.95, 1.05, ramp(t, 7, 3)) or t < 13 and lerp(1.05, 1, ramp(t, 10, 3)) or 1
            self:board("section_win", x, y, { s = s, fade = fade * ramp(t, 5, 1) })
            if t >= 7 and t < 17 then
                self:board("section_flash", x, y, { s = lerp(1, 1.5, ramp(t, 7, 10)), fade = fade * (1 - ramp(t, 7, 10)) })
            end
        else
            self:board("section_lose", x, y, { fade = fade * ramp(t, 5, 8) })
        end
        self:board("section_name", x - 2, y - 73, { frame = i - 1, fade = fade * ramp(t, 5, 1) })
    end
end

-- Right aligned digits; slots step left from the anchor.
function AISectionBoard:draw_number(key, value, right_x, y, step, fade)
    value = math.max(0, math.floor(value))
    local x = right_x
    repeat
        self:board(key, x, y, { frame = value % 10, fade = fade })
        value = value // 10
        x = x - step
    until value == 0
end

function AISectionBoard:draw_detail(fade)
    local layout = DETAIL[self.count]
    if not layout or fade <= 0 then return end
    local t = self.f - self.mode_at - BOARD_FADE
    local count_u = ramp(t, 0, COUNT_FRAMES)
    local diff_u = ramp(t, COUNT_FRAMES, COUNT_FRAMES)
    for i, section in ipairs(self.sections) do
        local x, y = layout.x[i], layout.y[i]
        self:board("detail_panel", x, y, { fade = fade })
        self:board(section.won and "detail_win" or "detail_lose", x + 37, y - 76, { fade = fade })
        self:board("section_name", x - 38, y - 76, { frame = i - 1, fade = fade })
        for row, key in ipairs(ROW_KEYS) do
            self:draw_number("digits_count", section[key] * count_u, x + 20, y - 2 + ROW_COUNT_Y[row], 17, fade)
            if not self.first_play and diff_u > 0 then
                local diff = section[key] - section.best[key]
                local sign = diff > 0 and "sign_plus" or diff < 0 and "sign_minus" or "sign_even"
                self:board(sign, x + 36, y - 2 + ROW_DIFF_Y[row], { fade = fade * diff_u })
                self:draw_number("digits_diff", math.abs(diff) * diff_u, x + 65, y - 2 + ROW_DIFF_Y[row], 10, fade * diff_u)
            end
        end
        if self.best_updated[i] then
            local best_fade = ramp(t, 2 * COUNT_FRAMES, 10)
            if best_fade > 0 then self:board("best_updated", x, y - 33, { fade = fade * best_fade }) end
        end
    end
end

function AISectionBoard:draw_logo(x, fade)
    if fade <= 0 then return end
    local t = self.f - self.total_at
    local y = LOGO_Y
    if self.won then
        local pulse = t < 14 and 1.087 or lerp(1.087, 0.725, math.abs(((t - 14) % 118) / 59 - 1))
        self:board("win_glow", x, y, { s = pulse, fade = fade * ramp(t, 2, 12) })
        if t >= 14 then
            self:board("win_ring_glow", x, y, { add = true, fade = fade * lerp(0.2, 1, math.abs(((t - 14) % 118) / 59 - 1)) })
        end
        if t >= 9 then
            self:board("win_laurel", x, y, { s = lerp(1.268, 1, ramp(t, 9, 5)), fade = fade * ramp(t, 9, 5) })
            self:board("win_rays", x, y, { s = 0.85, rot = t * 3, add = true, fade = fade * 0.3 * ramp(t, 9, 5) })
        end
        if t >= 9 and t < 14 then
            self:board("win_flash", x, y, { s = lerp(1.087, 1.812, ramp(t, 9, 5)), fade = fade * (1 - ramp(t, 9, 5)) })
        end
        for k, key in ipairs({ "triangle_yellow", "triangle_pale", "triangle_purple", "triangle_pink", "triangle_white" }) do
            local u = ramp(t, 23 + k * 2, 22)
            if u > 0 and u < 1 then
                local a = (k * 72) * math.pi / 180
                self:board(key, x + math.cos(a) * 170 * u, y + math.sin(a) * 170 * u, { rot = t * 8, fade = fade * (1 - u) })
            end
        end
        local logo_s = t < 6 and lerp(1, 2, ramp(t, 0, 6)) or lerp(1.772, 1, ramp(t, 6, 8))
        self:board("logo_win", x, y, { s = logo_s, fade = fade * ramp(t, 0, 5) })
        for k, spot in ipairs({ { 156, -107 }, { -167, 121 }, { -11, -159 }, { 140, 136 } }) do
            local at = 29 + (k - 1) * 15
            if t >= at then
                local u = ((t - at) % 170) / 60
                if u < 1 then self:board("sparkle", x + spot[1], y + spot[2], { fade = fade * math.sin(math.pi * u) }) end
            end
        end
    else
        if t < 13 then
            self:board("lose_burst", x, y, { s = lerp(0.145, 1.8, ramp(t, 0, 12)), fade = fade * (1 - ramp(t, 6, 6)) })
        end
        local show = fade * ramp(t, 6, 7)
        self:board("lose_disc", x, y, { fade = show })
        self:board("lose_ring", x, y, { rot = -t * 0.75, fade = show })
        self:board("lose_ring_thin", x, y, { rot = t * 0.75, fade = show })
        self:board("logo_lose", x, y, { fade = show })
    end
end

function AISectionBoard:draw_rank(fade)
    local p = self.progress
    if not p or fade <= 0 then return end
    local e, t = self.rank_events, self.f - self.rank_at
    local rankup = self:rankup() and e.tokens_end and t >= e.tokens_end
    local rank = rankup and p.rank_after or p.rank_before

    if rank >= RANK_MAX then
        self:board("rank_panel_max", 1159, 440, { fade = fade })
    else
        self:board("rank_panel", 1159, 440, { fade = fade })
        self:draw_number("digits_rank", rank, 1214 + (rank >= 10 and 17 or 0), 424, 35, fade)
        if p.next_rank_tokens >= 0 then
            local tokens = p.tokens_before
            if e.tokens and t >= e.tokens then
                tokens = math.min(p.tokens_after, p.tokens_before + math.floor((t - e.tokens) / TOKEN_STEP) + 1)
            end
            self:draw_number("digits_count", math.max(0, p.next_rank_tokens - tokens), 1201, 459, 17, fade)
        end
    end

    local wins = p.wins_before
    if e.wins and t >= e.wins then wins = lerp(p.wins_before, p.wins_after, ramp(t, e.wins, COUNT_FRAMES)) end
    local to_next = p.next_reward_wins >= 0 and p.next_reward_wins - math.floor(wins) or nil
    self:board(to_next and "wins_panel_next" or "wins_panel", 1160, 522, { fade = fade })
    self:draw_number("digits_wins", wins, 1244, 508, 17, fade)
    if to_next then self:draw_number("digits_count", to_next, 1218, 543, 17, fade) end
    if e.wins and p.reward_kind ~= "" and t >= e.wins + COUNT_FRAMES then
        local r = t - e.wins - COUNT_FRAMES
        self:board("reward_text", 1160, 522, { s = r < 10 and lerp(1.5, 1, ramp(r, 0, 10)) or 1, fade = fade * ramp(r, 0, 10) })
    end

    local slide = function(at) return lerp(225, 0, ramp(t, at + 1, 6)), lerp(0.5, 1, ramp(t, at + 1, 6)) end
    if e.challenge and t >= e.challenge then
        local dx, a = slide(e.challenge)
        self:board("badge_challenge", 1150 + dx, 379, { fade = fade * a })
    end
    if e.unmet and t >= e.unmet then
        local dx, a = slide(e.unmet)
        self:board("badge_unmet", 1150 + dx, 379, { fade = fade * a })
    end
    if e.first and t >= e.first then
        local dx, a = slide(e.first)
        self:board("badge_first", 1171 + dx, p.challenge and 345 or 383, { fade = fade * a })
    end
    if rankup then
        local r = t - e.tokens_end - 65
        if r >= 0 then
            local s = r < 10 and lerp(1, 1.5, ramp(r, 0, 10)) or r < 14 and lerp(1.375, 1, ramp(r, 10, 4)) or 1
            local a = ramp(r, 0, 10) * fade
            self:board("rankup_glow", 1160, 440, { s = s + (r >= 14 and 0.02 * math.sin(r / 11) or 0), fade = a })
            self:board("rankup_text", 1160, 440, { s = s, fade = a })
        end
    end
end

function AISectionBoard:draw_hints()
    local t = self.f % 120
    local simple = self.mode == "simple"
    self:board("hint_end", 1169, 687)
    self:board(simple and "hint_detail" or "hint_back", 930, 687)
    self:board("drum", 810, 688)
    self:board("drum", 1053, 688)
    local rim = t < 60 and 1 - math.abs(t / 30 - 1) or 0
    self:board("drum_rim", 798, 688, { fade = rim })
    self:board("drum_rim", 822, 688, { fade = rim, mirror = "horizontal" })
    local arrow = t < 60 and 1 - t / 60 or 0
    self:board("drum_arrow", 783 - 7 * (1 - arrow), 688, { fade = arrow })
    self:board("drum_arrow", 837 + 7 * (1 - arrow), 688, { fade = arrow, mirror = "horizontal" })
    self:board("drum_center", 1053, 688, { fade = rim })
end

function AISectionBoard:draw()
    if not self.started then return end
    local since = self.f - self.mode_at
    local detail = self.mode == "detail"
    local logo_u = ramp(self.f - self.total_at, 1, 8)
    if detail then
        local out = 1 - ramp(since, 0, 4)
        self:draw_simple(out)
        self:draw_rank(out)
        self:draw_logo(LOGO_X, logo_u * out)
        self:draw_logo(LOGO_DETAIL_X, ramp(since, 2, 7))
        self:draw_detail(ramp(since, 1, BOARD_FADE))
    else
        local back = self.detail_seen_at and ramp(since, 0, 4) or 1
        self:draw_simple(back)
        self:draw_rank(back)
        self:draw_logo(LOGO_X, math.min(logo_u, back))
    end
    if self.f >= self.wait_at then self:draw_hints() end
end
