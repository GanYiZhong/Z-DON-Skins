PracticeHelp = {}
PracticeHelp.__index = PracticeHelp

local S = tex.get_screen_scale()
local F = 1000 / 60
local LEFT, RIGHT, DECIDE = 1, 2, 3
local INTRO_MS = 420 * F
local TOTAL_MS = 120000
local OUT_MS = 250
local BLINK_MS, BLINK_ON_MS = 30 * F, 15 * F
local POP_FROM = 0.05

local function clamp01(v) return math.max(0.0, math.min(1.0, v)) end
local function ease_out(t) t = clamp01(t); return 1 - (1 - t) * (1 - t) end
local function lerp(a, b, t) return a + (b - a) * t end

local PAGES = {
    { { k = "board_0" } },
    { { k = "board_1" }, { k = "shot_1" },
      { k = "bubble_any_song", pop = { 4, 5, 222, 220 } }, { k = "bubble_timer", pop = { 9, 5, 222, 0 } } },
    { { k = "board_2" }, { k = { "shot_2_1p", "shot_2_2p" } }, { k = "frame_wide", i = { 0, 1 }, blink = 9 },
      { k = "bubble_both_drums", pop = { 4, 5, 186, 214 } } },
    { { k = "board_3" }, { k = { "shot_2_1p", "shot_2_2p" } },
      { k = "frame_wide", blink = 19 }, { k = "frame_oval", blink = 19 }, { k = "frame_bar", blink = 19 },
      { k = "bubble_score", pop = { 4, 5, 284, 2 } }, { k = "bubble_position", pop = { 9, 5, 215, 219 } },
      { k = "bubble_help", pop = { 14, 5, 0, 71 } } },
    { { k = "board_4" }, { k = { "pause_drums_1p", "pause_drums_2p" } }, { k = "pause_drum" }, { k = "pause_text" },
      { k = "pause_arrow" },
      { k = "frame_circle", i = 0, blink = 0 }, { k = "frame_circle", i = 1, blink = 0 },
      { k = "frame_circle", i = 2, blink = 0 },
      { k = "bubble_rewind", i = { 0, 1 }, pop = { { 9, 14 }, 5, 152, 200, true } },
      { k = "bubble_tempo", i = { 0, 1 }, pop = { { 14, 9 }, 5, 152, 200, true } },
      { k = "bubble_menu", i = { 0, 1 }, pop = { 19, 5, 180, 1, true } } },
    { { k = "board_5" }, { k = "frame_tall", i = 0, blink = 0 }, { k = "frame_tall", i = 1, blink = 0 } },
    { { k = "board_6" }, { k = { "shot_6_1p", "shot_6_2p" } },
      { k = "frame_circle", i = { 3, 6 }, blink = 0 }, { k = "frame_circle", i = { 4, 7 }, blink = 0 },
      { k = "frame_circle", i = { 5, 8 }, blink = 0 } },
    { { k = "board_7" }, { k = "kat_text" }, { k = { "shot_7_1p", "shot_7_2p" } }, { kats = true },
      { k = "bubble_renda", i = { 0, 1 }, pop = { 4, 5, 145, 136 } } },
    { { k = "board_8" }, { k = "shot_8" } },
    { { k = "board_9" }, { k = "shot_9" } },
    { { k = "board_10" }, { k = { "shot_10_1p", "shot_10_2p" } },
      { k = "bubble_colors", pop = { 5, 4, 520, 0 } }, { k = "bubble_jump", i = { 0, 1 }, pop = { 10, 4, 0, 85 } },
      { k = "bubble_time_left", pop = { 15, 4, 0, 79 } } },
}

local KAT_LOOP, KAT_HOP = 55, 10

function PracticeHelp.new(is_2p)
    local self = setmetatable({}, PracticeHelp)
    self.side = is_2p and 2 or 1
    self.t = {}
    self.now = tex.get_current_ms()
    self.t0 = self.now
    self.page = nil -- nil: intro
    audio.play_sound("practice_help_bgm", "music", false)
    audio.play_sound("practice_help_vo", "voice")
    return self
end

function PracticeHelp:tex(key)
    local t = self.t[key]
    if t == nil then
        t = tex.get_texture("entry/practice_help/" .. key) or false
        self.t[key] = t
    end
    return t or nil
end

function PracticeHelp:pick(v)
    if type(v) == "table" then return v[self.side] end
    return v
end

function PracticeHelp:draw_tex(key, p)
    local t = self:tex(key)
    if t then tex.draw_texture(t, p or {}) end
end

function PracticeHelp:show_page(n)
    self.page, self.page_t0 = n, self.now
end

function PracticeHelp:finish()
    if self.out_t0 then return end
    self.out_t0 = self.now
    audio.stop_sound("practice_help_bgm")
end

function PracticeHelp:update(current_ms)
    self.now = current_ms
    if not self.page and self.now - self.t0 >= INTRO_MS then self:show_page(1) end
    if self.now - self.t0 >= TOTAL_MS then self:finish() end
end

function PracticeHelp:input(action)
    if self.out_t0 then return false end
    if not self.page then
        self:show_page(1)
        return true
    end
    if action == DECIDE then
        self:finish()
        return true
    end
    local n = self.page + (action == LEFT and -1 or 1)
    if n < 1 or n > #PAGES then return false end
    self:show_page(n)
    return true
end

function PracticeHelp:is_done()
    return self.out_t0 ~= nil and self.now - self.out_t0 >= OUT_MS
end

function PracticeHelp:draw_intro(el)
    local e = ease_out(el / (30 * F))
    self:draw_tex("intro_board", { y = -67 * (1 - e) * S, fade = e })
    if el < 20 * F then return end

    for side, dir in ipairs({ -1, 1 }) do
        local lr = side == 1 and "l" or "r"
        if el < 39 * F then
            local x, y
            if el < 33 * F then
                local t = ease_out((el - 20 * F) / (13 * F))
                x, y = lerp(265.3, 89.7, t), lerp(452.9, -31.8, t)
            else
                local t = ease_out((el - 33 * F) / (6 * F))
                x, y = lerp(89.7, 36, t), lerp(-31.8, -1, t)
            end
            self:draw_tex("don_jump_" .. lr, { x = dir * x * S, y = y * S })
        elseif el < 365 * F then
            self:draw_tex("don_sit_" .. lr)
        elseif el < 367 * F then
            self:draw_tex("don_sit_" .. lr, { y = 19 * S, y2 = -19.84 * S })
        else
            local t = ease_out((el - 367 * F) / (52 * F))
            self:draw_tex("don_jump_" .. lr, { y = -617 * t * S })
        end
    end
end

function PracticeHelp:draw_item(it, el)
    if it.kats then
        local f = math.floor(el / F) % KAT_LOOP
        for n = 0, 4 do
            local up = f >= 24 + 6 * n and f <= 29 + 6 * n
            self:draw_tex("kat_note", { index = n, y = up and -KAT_HOP * S or 0 })
        end
        return
    end
    local p = { index = self:pick(it.i) or 0 }
    if it.blink then
        local b = el - it.blink * F
        if b < 0 or b % BLINK_MS >= BLINK_ON_MS then return end
    end
    if it.pop then
        local delay, dur, px, py, fade = self:pick(it.pop[1]), it.pop[2], it.pop[3], it.pop[4], it.pop[5]
        local b = el - delay * F
        if b < 0 then return end
        local s = lerp(POP_FROM, 1, ease_out(b / (dur * F)))
        p.scale, p.x, p.y = s, px * (1 - s) * S, py * (1 - s) * S
        if fade then p.fade = s end
    end
    self:draw_tex(self:pick(it.k), p)
end

function PracticeHelp:draw_arrows()
    local a = (self.now - self.t0) % 1000
    local dx, fade
    if a < 30 * F then
        dx, fade = 29.65 * a / (30 * F), 1
    else
        local t = clamp01((a - 30 * F) / (30 * F))
        dx, fade = lerp(30, 40, t), lerp(0.965, 0, t)
    end
    if self.page > 1 then self:draw_tex("arrow", { index = 0, x = -dx * S, fade = fade }) end
    if self.page < #PAGES then
        self:draw_tex("arrow", { index = 1, x = dx * S, fade = fade, mirror = "horizontal" })
    end
end

function PracticeHelp:draw()
    for i = 0, 11 do self:draw_tex("bg", { index = i }) end
    if not self.page then
        self:draw_intro(self.now - self.t0)
    else
        local el = self.now - self.page_t0
        for _, it in ipairs(PAGES[self.page]) do self:draw_item(it, el) end
        self:draw_tex("end_hint")
        self:draw_arrows()
    end
    if self.out_t0 then
        local a = clamp01((self.now - self.out_t0) / OUT_MS)
        tex.draw_rect(0, 0, tex.get_screen_width(), tex.get_screen_height(), 0, 0, 0, math.floor(255 * a))
    end
end
