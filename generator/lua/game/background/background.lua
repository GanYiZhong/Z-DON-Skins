-- YataiDONSimpleStyle (light 8-bit): enso background.
-- The band above a lane is a pixel sky with drifting pixel clouds; the player box holds Momo (pink
-- rabbit, UI.Mascot) who hops on the beat and reacts to the play (good hits, combo milestones, miss
-- streaks, GOGO, clear / full combo / fail). In single-player GAME the lower half is an information
-- panel (pixbox windows: song, course, live BPM, judgement counts, max combo, accuracy, average
-- timing when the engine's show_timing_offset is on) and Hoshi (the husky buddy) cheers from the
-- bottom with a one-line speech box. 2P, dan, practice and AI screens keep the lower half empty
-- because the engine draws a lane or its own panels there.
--
-- Data comes only from the background callbacks and tex.* bindings: nothing here needs engine
-- changes. Colours are the generated palette (global/ss_def.lua).

local UI = require("global.ss_ui")
local P = UI.P
local rect = UI.rect

local COURSE_COLOR = { [0] = P.easy, [1] = P.normal, [2] = P.hard, [3] = P.oni, [4] = P.ura }

Background = {}
Background.__index = Background

local function new_state()
    return { clear = false, rainbow = false, gogo = false, miss = false, progress = 0,
             good = 0, ok = 0, bad = 0, roll = 0, combo = 0, max_combo = 0, score = 0, ending = nil }
end

-- ------------------------------------------------------------------ 8-bit drawing helpers
-- everything snaps to whole pixels (S = screen scale)
local function snap(v) return math.floor(v + 0.5) end

-- ink-bordered window with notched corners and a hard drop shadow (same recipe as ss/style.py pixbox)
local function pixbox(x, y, w, h, fill, border, shadow, px, S)
    S = S or 1
    border = border or P.ink
    px = (px or 3) * S
    shadow = (shadow == nil and 4 or shadow) * S
    x, y, w, h = snap(x), snap(y), snap(w), snap(h)
    local n = px
    if shadow > 0 then
        rect(x + shadow + n, y + h, w - n, shadow, border)
        rect(x + w, y + shadow + n, shadow, h - 2 * n, border)
    end
    rect(x + n, y, w - 2 * n, h, border)
    rect(x, y + n, w, h - 2 * n, border)
    rect(x + px, y + px, w - 2 * px, h - 2 * px, fill or P.paper)
end

-- segmented meter: ink frame, groove, flat fill, optional segment ticks
local function pixbar(x, y, w, h, frac, fill, groove, segs, S)
    S = S or 1
    local px = 2 * S
    x, y, w, h = snap(x), snap(y), snap(w), snap(h)
    rect(x, y, w, h, P.ink)
    rect(x + px, y + px, w - 2 * px, h - 2 * px, groove or P.bg3)
    local fw = snap((w - 2 * px) * math.max(0, math.min(1, frac)))
    if fw > 0 then
        rect(x + px, y + px, fw, h - 2 * px, fill)
        rect(x + px, y + px, fw, math.max(1, S), UI.mix(fill, P.paper, 0.5))
    end
    if segs and segs > 1 then
        for i = 1, segs - 1 do
            rect(x + px + snap(i * (w - 2 * px) / segs), y + px, px, h - 2 * px, P.ink)
        end
    end
end

-- a pixel cloud: stacked blocks, flat paper colour with a pale shade row underneath
local function cloud(x, y, u, col, shade)
    local function blk(cx, cy, cw, ch, c) rect(x + cx * u, y + cy * u, cw * u, ch * u, c) end
    blk(2, 3, 12, 1, shade)
    blk(1, 1, 14, 2, col)
    blk(3, 0, 5, 1, col)
    blk(9, -1, 4, 2, col)
    blk(5, -1, 3, 1, col)
    blk(0, 2, 1, 1, col)
    blk(15, 2, 1, 1, col)
end

local SPEECH = {
    ja = { idle = "ファイト！", blink = "ファイト！", good = "いいね！", combo = "すごい！　その調子！",
           sad = "ドンマイ！　まだまだ！", gogo = "ノってきた！", clear = "クリアおめでとう！", fail = "つぎは いけるよ！",
           full_combo = "フルコンボ！　かんぺき！", donderful = "ドンダフル！！　さいこう！" },
    en = { idle = "Let's go!", blink = "Let's go!", good = "Nice!", combo = "Amazing! Keep it up!",
           sad = "It's okay! Keep going!", gogo = "Feeling it!", clear = "You cleared it!", fail = "Next time!",
           full_combo = "Full combo! Perfect!", donderful = "DONDERFUL!! Amazing!" },
}

function Background.new(player_num, bpm, scene_preset)
    local self = setmetatable({}, Background)
    UI.reset()
    self.player_num = player_num
    self.is_2p = (player_num == 3)
    self.bpm = (bpm and bpm > 0) and bpm or 120
    self.ms = 0
    self.S = tex.get_screen_scale()
    self.W = tex.get_screen_width()
    self.H = tex.get_screen_height()
    self.screen = tex.current_screen()
    self.state = { [1] = new_state(), [2] = new_state() }
    -- 2P play: player 2's band shows Hoshi (the buddy); single-player screens keep Momo
    self.mascot = { [1] = UI.Mascot.new(), [2] = UI.Mascot.new({ buddy = self.is_2p }) }
    -- the lower info panel only in plain single-player play
    self.panel = (not self.is_2p) and (self.screen == "GAME")
    self.last_restart = audio.play_count and audio.play_count("restart") or 0
    if self.panel then
        self:make_texts()
        self.buddy = UI.Mascot.new()
    end
    return self
end

function Background:make_texts()
    local S = self.S
    local title = tex.song_title() or ""
    local sub = tex.song_subtitle() or ""
    self.t_title = (title ~= "") and text.create_raw_text(title, 38 * S, UI.rgba(P.text), { 0, 0, 0, 0 }, false, 0, 0) or nil
    self.t_sub = (sub ~= "") and text.create_raw_text(sub, 20 * S, UI.rgba(P.text2), { 0, 0, 0, 0 }, false, 0, 0) or nil
    -- course + level from our song select (Scripts/song_select/song_select.lua): unknown when a song
    -- is started directly (command line)
    local pn = (self.player_num == 2) and 2 or 1
    self.course = (type(SS_COURSE_BY_PLAYER) == "table") and SS_COURSE_BY_PLAYER[pn] or nil
    -- Hoshi's lines (one text object per expression, created once)
    local lang = (tex.language and tex.language() == "ja") and "ja" or "en"
    self.t_name = text.create_raw_text(lang == "ja" and "ホシ" or "Hoshi", 16 * S, UI.rgba(P.text), { 0, 0, 0, 0 }, false, 0, 0)
    self.speech = {}
    for k, str in pairs(SPEECH[lang]) do
        self.speech[k] = text.create_raw_text(str, 26 * S, UI.rgba(P.text), { 0, 0, 0, 0 }, false, 0, 0)
    end
end

local function st(self, pn) return self.state[pn == 2 and 2 or 1] end
local function mas(self, pn) return self.mascot[pn == 2 and 2 or 1] end

-- F1 restarts the song without a new Background: start the counters again
function Background:check_restart()
    if not audio.play_count then return end
    local n = audio.play_count("restart")
    if n ~= self.last_restart then
        self.last_restart = n
        self.state = { [1] = new_state(), [2] = new_state() }
        for i = 1, 2 do self.mascot[i]:set_mood(nil) end
        if self.buddy then self.buddy:set_mood(nil) end
    end
end

function Background:update(current_ms, bpm)
    self.ms = current_ms
    if bpm and bpm > 0 then self.bpm = bpm end
    self:check_restart()
    for i = 1, 2 do self.mascot[i]:update(current_ms, self.bpm) end
    if self.buddy then self.buddy:update(current_ms, self.bpm) end
end

local function hit(self, pn, kind)
    local s = st(self, pn)
    s[kind] = s[kind] + 1
    s.combo = s.combo + 1
    if s.combo > s.max_combo then s.max_combo = s.combo end
    local m = mas(self, pn)
    if s.combo % 100 == 0 then
        m:flash("combo", 900)
        if self.buddy then self.buddy:flash("combo", 1800) end
    elseif kind == "good" then
        m:flash("good", 220)
        if self.buddy and s.combo % 25 == 0 then self.buddy:flash("good", 1400) end
    end
end

function Background:handle_good(pn) hit(self, pn, "good") end
function Background:handle_ok(pn) hit(self, pn, "ok") end
function Background:handle_bad(pn)
    local s = st(self, pn)
    s.bad = s.bad + 1
    s.combo = 0
end
function Background:handle_drumroll(pn) local s = st(self, pn); s.roll = s.roll + 1 end
function Background:handle_balloon(pn) local s = st(self, pn); s.roll = s.roll + 1 end
function Background:handle_kusudama(pn) local s = st(self, pn); s.roll = s.roll + 1 end
function Background:handle_score(pn, score) st(self, pn).score = score end

function Background:handle_miss_streak(pn, on)
    local s = st(self, pn)
    s.miss = on
    self:refresh_mood(pn)
end

function Background:handle_gogo(pn, on)
    st(self, pn).gogo = on
    self:refresh_mood(pn)
end

function Background:refresh_mood(pn)
    local s, m = st(self, pn), mas(self, pn)
    if s.ending then return end
    local mood = nil
    if s.miss then mood = "sad" elseif s.gogo then mood = "gogo" end
    m:set_mood(mood)
    if self.buddy then self.buddy:set_mood(mood) end
end

function Background:handle_gauge(pn, progress, is_clear, is_rainbow)
    local s = st(self, pn)
    s.progress, s.clear, s.rainbow = progress or 0, is_clear, is_rainbow
end

function Background:handle_ending(pn, kind)
    local s = st(self, pn)
    s.ending = kind
    local mood = (kind == "fail") and "fail" or "clear"
    mas(self, pn):set_mood(mood)
    if self.buddy then self.buddy:set_mood(mood) end
end

-- ------------------------------------------------------------------ drawing
-- the band above a lane (1P: y 0..184; 2P's player two: below its lane). `flip` = the band sits below
-- its lane (the sky fades upwards then)
function Background:draw_band(y, h, s, m, accent, flip)
    local S = self.S
    local W = self.W
    local sky, cl, shade = P.sky, P.paper, UI.mix(P.sky, P.paper, 0.35)
    shade = UI.mix(P.sky, { 120, 160, 200 }, 0.25)
    if s.gogo then
        sky = UI.mix(P.sky, { 255, 205, 170 }, 0.9)
        shade = UI.mix(sky, P.gogo, 0.25)
    end
    if s.miss then
        sky = UI.mix(sky, P.mute, 0.35)
        shade = UI.mix(sky, P.text2, 0.25)
    end
    rect(0, y, W, h, P.bg0)
    local sh = 132 * S                       -- sky height; a 2-row checker dither steps into the cream
    local sy = flip and (y + h - sh) or y
    rect(0, sy, W, sh, sky)
    local cell = 6 * S
    local dy = flip and (sy - 2 * cell) or (sy + sh)
    for row = 0, 1 do
        for cx = (row % 2) * cell, W - 1, cell * 2 do
            rect(cx, dy + row * cell, math.min(cell, W - cx), cell, sky)
        end
    end
    -- drifting pixel clouds (6 px per game pixel, slow parallax)
    local u = 4 * S
    local drift = (self.ms or 0) * 0.012 * S
    for _, c in ipairs({ { 120, 30, 1.0 }, { 520, 78, 0.75 }, { 860, 22, 1.0 }, { 1180, 70, 0.75 } }) do
        local cx = (c[1] * S + drift * c[3]) % (W + 200 * S) - 100 * S
        cloud(snap(cx / u) * u, sy + snap(c[2] * S / u) * u, snap(u * c[3] / S) * S, cl, shade)
    end
    -- the player box: Momo stands in it (pink, ink border, hard shadow)
    -- (the engine's score popup floats just under it: the box ends at y 144 and the popup lane stays clear)
    local bx, by, bw, bh = 12 * S, y + 6 * S, 160 * S, 138 * S
    if flip then by = y + h - 10 * S - bh end
    local fill = P.pink
    if s.gogo then fill = P.clear elseif s.miss then fill = P.bg3 end
    if s.ending == "fail" then fill = P.bg3
    elseif s.ending == "clear" then fill = P.mint
    elseif s.ending then fill = P.clear end      -- full combo / donderful: gold
    pixbox(bx, by, bw, bh, fill, P.ink, 4, 3, S)
    rect(bx + 3 * S, by + 3 * S, bw - 6 * S, 3 * S, UI.mix(fill, P.paper, 0.5))
    -- a flat shadow under the feet, then Momo (whole-pixel scale: 8 px frame pixels x 0.5)
    local foot = by + bh - 9 * S
    rect(bx + 36 * S, foot, 88 * S, 4 * S, UI.mix(fill, P.ink, 0.25))
    m:draw(bx + bw / 2, foot, 0.5 * S)
end

-- Hoshi stands on a ground line: the dialog box sits on it too (right of Hoshi), and nothing here goes past
-- y 708 or x 1210 (the engine's network indicator owns the bottom-right corner)
local LABEL_TXT = {
    ja = { good = "良", ok = "可", bad = "不可", roll = "連打", maxcombo = "最大コンボ", acc = "精度",
           offset = "平均タイミング", ms = "ms", bpm = "BPM", gauge = "魂ゲージ", level = "★",
           course0 = "かんたん", course1 = "ふつう", course2 = "むずかしい", course3 = "おに", course4 = "裏おに" },
    en = { good = "GOOD", ok = "OK", bad = "BAD", roll = "ROLL", maxcombo = "MAX COMBO", acc = "ACCURACY",
           offset = "AVG TIMING", ms = "ms", bpm = "BPM", gauge = "SOUL", level = "LV",
           course0 = "EASY", course1 = "NORMAL", course2 = "HARD", course3 = "ONI", course4 = "URA" },
}

-- labels drawn here (the shared label strip is 12 px, too small for these cards): created once each
function Background:lab(key, col)
    self.lbls = self.lbls or {}
    local id = key .. (col[1] * 65536 + col[2] * 256 + col[3])
    local t = self.lbls[id]
    if not t then
        local lang = (tex.language and tex.language() == "ja") and "ja" or "en"
        t = text.create_raw_text(LABEL_TXT[lang][key] or key, 16 * self.S, UI.rgba(col), { 0, 0, 0, 0 }, false, 0, 0)
        self.lbls[id] = t
    end
    return t
end

local function label(self, key, x, y, col)
    local t = self:lab(key, col)
    t:draw({ x = x, y = y - t.height / 2 })
    return t.width
end

-- one value cell of the judgement grid: label above, tabular number below
local function cell(self, x, y, label_key, value, col)
    label(self, label_key, x, y, col or P.text2)
    UI.num(value, x, y + 36 * self.S, "l", P.text, 255, "l")
end

function Background:draw_panel(y, h, s)
    local S = self.S
    local pad = 40 * S
    local ch = 196 * S
    local top = y + 14 * S
    local W = self.W
    local lw = 560 * S
    -- the judge counter (a setting; the engine loads its script only when it is on) takes the left
    -- 334 px of this half: the song card then shrinks to BPM + gauge and moves right of it
    local jc = rawget(_G, "JudgeCounter") ~= nil
    local lx = pad
    if jc then lx = 358 * S; lw = pad + 560 * S - lx end
    -- left card: the song
    pixbox(lx, top, lw, ch, P.paper, P.ink, 4, 3, S)
    local x = lx + 28 * S
    local maxw = lw - 56 * S
    local ty = top + 14 * S
    if self.t_title and not jc then
        local sc = math.min(1, maxw / math.max(1, self.t_title.width))
        self.t_title:draw({ x = x, y = ty, scale = sc })
        ty = ty + self.t_title.height * sc + 2 * S
    end
    if self.t_sub and not jc then
        local sc = math.min(1, maxw / math.max(1, self.t_sub.width))
        self.t_sub:draw({ x = x, y = ty, scale = sc })
    end
    -- bottom row: course + level, live BPM, soul gauge
    local ry = top + ch - 72 * S
    rect(x, ry - 24 * S, maxw, 2 * S, P.bg3)
    local cx = x
    if self.course and self.course.diff and COURSE_COLOR[self.course.diff] and not jc then
        local d = self.course.diff
        label(self, "course" .. d, cx, ry, P.text2)
        rect(cx, ry + 26 * S, 12 * S, 12 * S, P.ink)
        rect(cx + 2 * S, ry + 28 * S, 8 * S, 8 * S, COURSE_COLOR[d])
        local lv = (self.course.level and self.course.level > 0) and tostring(self.course.level) or "-"
        label(self, "level", cx + 18 * S, ry + 32 * S, P.gold_t)
        UI.num(lv, cx + 44 * S, ry + 32 * S, "m", P.text, 255, "l")
        cx = cx + 170 * S
    end
    label(self, "bpm", cx, ry, P.text2)
    local bpm = self.bpm
    local bs = (math.abs(bpm - math.floor(bpm + 0.5)) < 0.05) and tostring(math.floor(bpm + 0.5))
        or string.format("%.1f", bpm)
    UI.num(bs, cx, ry + 32 * S, "m", P.text, 255, "l")
    cx = cx + (jc and 104 or 150) * S
    label(self, "gauge", cx, ry, P.text2)
    local g = math.floor(math.min(1, s.progress or 0) * 100 + 0.5)
    UI.num(tostring(g) .. "%", cx, ry + 32 * S, "m", (s.clear or s.rainbow) and P.gold_t or P.text, 255, "l")

    -- right card: the play so far
    local rx = pad + 560 * S + 24 * S
    local rw = W - pad - rx
    pixbox(rx, top, rw, ch, P.paper, P.ink, 4, 3, S)
    local gx = rx + 28 * S
    local colw = (rw - 56 * S) / 4
    local gy = top + 24 * S
    cell(self, gx, gy, "good", s.good, P.gold_t)
    cell(self, gx + colw, gy, "ok", s.ok, P.text2)
    cell(self, gx + colw * 2, gy, "bad", s.bad, P.red_t)
    cell(self, gx + colw * 3, gy, "roll", s.roll, P.blue_t)
    local by2 = top + ch - 72 * S
    rect(gx, by2 - 24 * S, rw - 56 * S, 2 * S, P.bg3)
    cell(self, gx, by2, "maxcombo", s.max_combo)
    local judged = s.good + s.ok + s.bad
    local acc = judged > 0 and (s.good + s.ok * 0.5) / judged * 100 or 0
    local ax = gx + colw * 1.35
    label(self, "acc", ax, by2, P.text2)
    local accs = judged > 0 and string.format("%.1f%%", acc) or "-"
    UI.num(accs, ax, by2 + 36 * S, "l", P.text, 255, "l")
    -- a segmented bar under the accuracy figure
    local bw = colw * 1.3
    pixbar(ax, by2 + 58 * S, bw, 8 * S, judged > 0 and acc / 100 or 0, P.normal, P.bg3, 10, S)
    local off = tex.timing_offset and tex.timing_offset(self.player_num == 2 and 2 or 1)
    if off then
        local ox = gx + colw * 2.85
        label(self, "offset", ox, by2, P.text2)
        local v = off:gsub(" ms", ""):gsub("ms", "")
        local w = UI.num(v, ox, by2 + 36 * S, "l", P.text, 255, "l") or 0
        if v ~= "--" then label(self, "ms", ox + w + 4 * S, by2 + 44 * S, P.text2) end
    end

    -- Hoshi (the buddy) cheers from the ground line: a one-line speech box and the husky itself
    self:draw_buddy(lx, 1210 * S, s)
end

function Background:draw_buddy(x0, x1, s)
    local S = self.S
    local b = self.buddy
    local body = tex.get_texture("game/ss_hoshi/body")
    if not b or not body then return end
    local M = UI.D.MASCOT
    local expr = b:current_expr()
    local size = 102 * S                          -- 34 sprite cells x 3 px
    local ground = 692 * S
    local hop = 0
    if b:beat() > 0.3 and expr ~= "sad" and expr ~= "fail" then hop = 3 * S end
    -- the ground: an ink line with a two-row checker strip under it
    rect(x0, ground, x1 - x0, 4 * S, P.ink)
    local cell_w = 6 * S
    for row = 0, 1 do
        for gx = x0 + (row % 2) * cell_w, x1 - cell_w, cell_w * 2 do
            rect(gx, ground + 4 * S + row * cell_w, cell_w, cell_w, UI.mix(P.mint, P.bg0, 0.4))
        end
    end
    local hx = x0 + 14 * S
    tex.draw_texture(body, { frame = M.expr[expr] or 0, x = hx, y = ground - size - hop })
    -- speech box right of Hoshi, standing on the ground; the tail points at Hoshi
    local bx = hx + size + 26 * S
    local bw = x1 - 6 * S - bx
    local bh = 84 * S
    local by = ground - 4 * S - bh
    pixbox(bx, by, bw, bh, P.paper, P.ink, 4, 3, S)
    rect(bx - 9 * S, by + 24 * S, 9 * S, 18 * S, P.ink)           -- tail: ink step
    rect(bx - 6 * S, by + 27 * S, 12 * S, 12 * S, P.paper)
    -- name tab on the top edge
    if self.t_name then
        local tw = self.t_name.width + 24 * S
        pixbox(bx + 18 * S, by - 12 * S, tw, 24 * S, P.paper, P.ink, 0, 3, S)
        self.t_name:draw({ x = bx + 30 * S, y = by - 12 * S + (24 * S - self.t_name.height) / 2 })
    end
    local key = (s.ending == "full_combo" or s.ending == "donderful") and s.ending or expr
    local t = self.speech and (self.speech[key] or self.speech[expr] or self.speech.idle)
    if t then
        t:draw({ x = bx + 28 * S, y = by + (bh - t.height) / 2 + 4 * S })
    end
    -- blinking "next" cursor
    if (math.floor(self.ms / 400) % 2) == 0 then
        local cx, cy = bx + bw - 30 * S, by + bh - 24 * S
        rect(cx, cy, 12 * S, 3 * S, P.mute)
        rect(cx + 3 * S, cy + 3 * S, 6 * S, 3 * S, P.mute)
        rect(cx + 5 * S, cy + 6 * S, 2 * S, 3 * S, P.mute)
    end
end

function Background:draw_field(y, h, s)
    rect(0, y, self.W, h, s.miss and UI.mix(P.bg0, P.mute, 0.18) or P.bg0)
    -- a checker strip where the lane ends
    local cell = 6 * self.S
    for row = 0, 1 do
        for cx = (row % 2) * cell, self.W - 1, cell * 2 do
            rect(cx, y + row * cell, math.min(cell, self.W - cx), cell, P.bg3)
        end
    end
    if self.panel then self:draw_panel(y, h, s) end
end

function Background:draw_back()
    local S = self.S
    rect(0, 0, self.W, self.H, P.bg0)
    if self.is_2p then
        self:draw_band(0, 184 * S, self.state[1], self.mascot[1], P.p1, false)
        self:draw_band(536 * S, 184 * S, self.state[2], self.mascot[2], P.p2, true)
    else
        local pn = (self.player_num == 2) and 2 or 1
        local s = self.state[pn]
        self:draw_band(0, 184 * S, s, self.mascot[pn], pn == 2 and P.p2 or P.p1, false)
        self:draw_field(360 * S, self.H - 360 * S, s)
    end
end

function Background:draw_fore() end

function Background:destroy() end
