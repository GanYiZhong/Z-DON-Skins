local S = tex.get_screen_scale()
local DIR, SUB = "waiwai_result/reveal", "reveal"
local F = 1000 / 60

local INIT, GAUGE, WORD, PANEL, DUET, DRUM, MSG, FINISH = 1, 2, 3, 4, 5, 6, 7, 8
local WAIT = 60
local DIGIT_ROLL = 40
local CLEAR_POINT, MAX_POINT = 35, 50
local RED_CELLS = CLEAR_POINT - 1

local WORD_FAIL, WORD_CLEAR, WORD_AMAZING = 0, 1, 2
local BANNER = { [WORD_FAIL] = "banner_fail", [WORD_CLEAR] = "banner_clear", [WORD_AMAZING] = "banner_amazing" }
local BANNER_Y = 66

local SPARKLES = {
    { 22, -1.65, -48.65 }, { 31, 120.35, -48.65 }, { 40, -121.65, -48 }, { 49, -79.65, 48 },
    { 58, 156.35, 33.35 }, { 67, -161.65, 30 }, { 76, 68.35, 48 },
}
local MSG_KEYS = { [0] = "vbad", "bad", "good", "excellent" }
local RAYS = {
    { "ray_thin_teal", 10.0, 13.8, 1, 2, -562, -349, -518, -339, false, 0.70 },
    { "ray_wide_lime", 17.1, 18.8, 1, 2, -481, -329, -461, -323, false, 0.80 },
    { "ray_wide_cyan", 26.1, 26.8, 2, 2, -382, -289, -374, -286, false, 0.50 },
    { "ray_thin_purple", 36.0, 39.8, 1, 2, -280, -230, -244, -198, false, 0.70 },
    { "ray_thin_olive", 43.1, 44.9, 1, 2, -216, -175, -201, -161, false, 0.70 },
    { "ray_thin_olive", -41.9, -41.9, 1, 2, 231, -186, 247, -199, true, 0.70 },
    { "ray_thin_cyan", -39.9, -39.9, 1, 2, 212, -168, 248, -198, true, 0.70 },
    { "ray_wide_gold", -27.8, -27.8, 2, 2, 354, -273, 336, -262, true, 0.50 },
    { "ray_wide_lime", -19.8, -19.8, 1, 2, 511, -336, 485, -329, true, 0.80 },
    { "ray_thin_pink", -14.0, -14.0, 1, 2, 542, -345, 476, -326, true, 0.70 },
}
local STARS = {
    { "star_large", -366, -18, 1 }, { "star_large", -412.85, -4, 0.75 }, { "star_large", -103.8, -30, 1 }, { "star_large", 160.35, 31, 1 }, { "star_large", 172.4, -30, 1 },
    { "star_large", 380, 30, 1 }, { "star_small", -310.95, 30, 1 }, { "star_small", -251, 11, 1 }, { "star_small", -34.75, 30, 1 }, { "star_small", 86, -36, 0.5 },
    { "star_small", 401.45, -11, 0.75 }, { "star_small", 308.5, -24, 1 }, { "star_small", -189, 39, 0.5 }, { "star_small", -405, 17, 0.25 }, { "star_small", 426, -6, 0.25 },
}

WaiwaiResult = {}
WaiwaiResult.__index = WaiwaiResult

local function lerp(a, b, t) return a + (b - a) * t end
local function clamp01(t) return math.max(0, math.min(1, t)) end
local function seg(f, f0, f1, a, b) return lerp(a, b, clamp01((f - f0) / (f1 - f0))) end
local function ease_in(f, f0, f1, a, b) local t = clamp01((f - f0) / (f1 - f0)); return lerp(a, b, t * t) end
local function tri(f, period) local t = (f % period) / period; return t < 0.5 and t * 2 or 2 - t * 2 end
local function play(name, preset) if audio.has_sound(name) then audio.play_sound(name, preset) end end
-- every line has a take per player, routed to that player's output
local function play_vo(name)
    play(name .. "_1p", "voice")
    play(name .. "_2p", "voice")
end

function WaiwaiResult.new()
    local self = setmetatable({}, WaiwaiResult)
    tex.load_folder("waiwai_result", SUB)
    self.cache = {}
    self.frame = 0
    self.st, self.c = INIT, 0
    self.point, self.duet, self.msg = 0, 0, 0
    self.word = WORD_FAIL
    self.shown_point = 0
    self.digits, self.roll_count, self.roll_id = {}, 0, 1
    self.finished = false
    self.motion = -1
    return self
end

function WaiwaiResult:set_result(point, duet, msg, revive)
    self.point, self.duet, self.msg, self.revive = point, duet, msg, revive
    self.word = point < CLEAR_POINT and WORD_FAIL or (point < MAX_POINT and WORD_CLEAR or WORD_AMAZING)
    self.text = text.create_text("waiwai_result_msg_" .. MSG_KEYS[msg], { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 6, -1)
end

function WaiwaiResult:t(key)
    local t = self.cache[key]
    if not t then
        local info = tex.get_texture_info(SUB, key)
        t = { id = tex.get_texture(DIR .. "/" .. key), w = info and info.x2[1] or 0, h = info and info.y2[1] or 0 }
        self.cache[key] = t
    end
    return t
end

function WaiwaiResult:D(key, cx, cy, o)
    local t = self:t(key)
    if not t.id then return end
    o = o or {}
    local a = o.a or 1
    if a <= 0 then return end
    local sx, sy = o.sx or o.s or 1, o.sy or o.s or 1
    local w, h = t.w * sx, t.h * sy
    local p = { x2 = (w - t.w) * S, y2 = (h - t.h) * S, fade = a,
                mirror = o.flip and "horizontal" or nil, blend = o.add and "additive" or nil }
    if o.rot then
        p.x, p.y, p.origin, p.rotation = cx * S, cy * S, { w / 2 * S, h / 2 * S }, o.rot
    else
        p.x, p.y = (cx - w / 2) * S, (cy - h / 2) * S
    end
    tex.draw_texture(t.id, p)
end

function WaiwaiResult:next_state(st)
    self.st, self.c = st, 0
end

function WaiwaiResult:lock_word()
    self.shown_point = self.point
    self.motion = self.word
    self.word_f0 = self.word_f0 or self.frame
    self.panel_f0 = self.panel_f0 or self.frame
end

function WaiwaiResult:on_word()
    self.word_f0 = self.frame
    self.motion = self.word
    if self.word == WORD_FAIL then
        play_vo(self.shown_point < 17 and "vo_fail_bad" or "vo_fail")
        play("se_cheers_fail", "sound")
    elseif self.word == WORD_CLEAR then
        play_vo("vo_clr")
        play("se_cheers_clear", "sound")
    else
        play_vo("vo_clr_great")
        play("se_cheers_great", "sound")
    end
    play("se_slide", "sound")
end

function WaiwaiResult:step_duet()
    local value = tostring(self.duet)
    self.roll_count = self.roll_count + 1
    if self.c % 3 == 0 then play("se_countup", "sound") end
    if self.roll_count > DIGIT_ROLL then
        local i = self.roll_id
        self.digits[i] = tonumber(value:sub(#value - i + 1, #value - i + 1))
        self.roll_id, self.roll_count = i + 1, 0
        if self.roll_id > #value then self:next_state(DRUM); return end
    end
end

function WaiwaiResult:step()
    local st, c = self.st, self.c
    if st == INIT then
        self.c = c + 1
        if self.c >= WAIT * 2 then self:next_state(GAUGE) end
    elseif st == GAUGE then
        if c == 0 then self.gauge_f0 = self.frame end
        if self.shown_point < self.point then
            self.shown_point = self.shown_point + 1
            if self.shown_point == MAX_POINT then play("se_gaugemax", "sound") end
            if c % 3 == 0 then play("se_countup", "sound") end
        end
        self.c = c + 1
        if self.c >= WAIT then self:next_state(WORD) end
    elseif st == WORD then
        if c == 0 then self:on_word() end
        self.c = c + 1
        if self.c >= WAIT then self:next_state(PANEL) end
    elseif st == PANEL then
        if c == 0 then self.panel_f0 = self.frame end
        self.c = c + 1
        if self.c >= WAIT then self:next_state(DUET) end
    elseif st == DUET then
        self:step_duet()
        if self.st == DUET then self.c = c + 1 end
    elseif st == DRUM then
        if c == 0 then play("se_drumroll1", "sound") end
        self.c = c + 1
        if self.c >= WAIT then self:next_state(MSG) end
    elseif st == MSG then
        if c == 0 then self.msg_f0 = self.frame end
        if c == 23 then
            if self.word ~= WORD_FAIL then play("se_cheers2", "sound") end
            play("se_drumroll2", "sound")
        end
        self.c = c + 1
        if self.c >= WAIT * 7 then self:finish() end
    elseif st == FINISH then
        self.c = c + 1
        if self.c >= WAIT then self.finished = true end
    end
end

function WaiwaiResult:finish()
    if tex.song_limit() > 0 and tex.songs_played() == tex.song_limit() then play_vo("vo_selnext") end
    self:next_state(FINISH)
end

function WaiwaiResult:skip()
    self:lock_word()
    local value = tostring(self.duet)
    for i = 1, #value do self.digits[i] = tonumber(value:sub(#value - i + 1, #value - i + 1)) end
    self.roll_id = #value + 1
    self.msg_f0 = self.msg_f0 or self.frame
    self:finish()
end

function WaiwaiResult:update(ms, is_skipped)
    local f = math.floor(ms / F)
    if not self.t0 then
        self.t0 = f
        audio.play_sound("waiwai_bgm", "music")
        play_vo("vo_title")
    end
    if is_skipped ~= 0 and self.st < FINISH then self:skip() end
    while self.frame < f - self.t0 and not self.finished do
        self.frame = self.frame + 1
        self:step()
    end
end

function WaiwaiResult:is_finished()
    return self.finished
end

function WaiwaiResult:draw_rays(f, a)
    local k = tri(f, 160)
    for _, r in ipairs(RAYS) do
        self:D(r[1], 640 + lerp(r[6], r[8], k), 360 + lerp(r[7], r[9], k),
            { rot = lerp(r[2], r[3], k), sx = r[4], sy = r[5], flip = r[10], a = r[11] * a, add = true })
    end
end

function WaiwaiResult:draw_confetti(f)
    for _, col in ipairs({ -800, -320, 160 }) do
        for k = 0, 1 do
            local age = (f + k * 200) % 400
            local a = 0.7 * seg(age, 201, 398, 1, 0)
            local px, py = lerp(0, -246, age / 398), lerp(0, 644, age / 398)
            self:D("confetti", 640 + col + 327 + px, 340 - 449 + py, { s = 0.75, a = a })
            self:D("confetti", 640 + col + 573 + px, 340 - 449 + py, { s = 0.75, rot = 90, a = a })
        end
    end
    for _, col in ipairs({ -560, -110, 340 }) do
        for k = 0, 1 do
            local age = (f + k * 160) % 320
            self:D("confetti", 655 + col + 260 + lerp(0, -212, age / 318), 150 - 310 + lerp(0, 690, age / 318),
                { a = seg(age, 160, 318, 1, 0) })
        end
    end
end

function WaiwaiResult:draw(ms)
    self:D("backdrop", 640, 360)
    if not self.msg_f0 then return end
    local f = self.frame - self.msg_f0
    local a = seg(f, 0, 19, 0, 1)
    if self.msg < 2 then
        self:D("backdrop_band", 640, 360, { sx = 32, a = 0.4 * a })
        return
    end
    self:D("backdrop_band", 640, 360, { sx = 32, a = a })
    self:draw_rays(f, a)
    if self.msg == 3 then self:draw_confetti(f) end
end

function WaiwaiResult:draw_gauge()
    local a = seg(self.frame - self.gauge_f0, 4, 23, 0.05, 1)
    local p = self.shown_point
    local cleared = p >= CLEAR_POINT
    self:D(cleared and "gauge_frame_clear" or "gauge_frame_red", 640, 150, { a = a })
    self:D("gauge_back", 640, 150, { a = a })
    for i = 0, math.min(p, RED_CELLS) - 1 do
        self:D(i % 2 == 0 and "gauge_red_cell_0" or "gauge_red_cell_1", 268 + 15 * i, 163, { a = a })
    end
    for i = 0, p - RED_CELLS - 1 do
        self:D(i % 2 == 0 and "gauge_yellow_cell_0" or "gauge_yellow_cell_1", 783 + 15 * i, 151, { a = a })
    end
    if p >= MAX_POINT then
        local f = self.frame - self.gauge_f0
        self:D("gauge_frame_rainbow", 640, 150, { a = a })
        self:D("gauge_rainbow_" .. math.floor(f / 5) % 8, 640, 150, { a = a })
    end
    self:D(cleared and "gauge_clear_text_lit" or "gauge_clear_text", 812, 140, { a = a })
end

function WaiwaiResult:draw_word()
    local f = self.frame - self.word_f0
    local x = 640
    if f < 10 then x = x + seg(f, 0, 9, 900, -10)
    elseif f < 14 then x = x + seg(f, 10, 13, -6.25, 5)
    elseif f < 18 then x = x + seg(f, 14, 17, 3.75, 0) end
    self:D(BANNER[self.word], x, BANNER_Y)
    if self.word == WORD_FAIL then return end
    local loop = f < 21 and f or 21 + (f - 21) % 129
    for _, sp in ipairs(SPARKLES) do
        local lf = loop - sp[1]
        if lf >= 0 and lf < 20 then
            local s = lf < 11 and seg(lf, 0, 10, 0.2, 1) or 1
            local fade = lf < 11 and 1 or seg(lf, 11, 19, 0.891, 0)
            self:D("banner_sparkle", 640 + sp[2], BANNER_Y + sp[3], { s = s, a = fade })
        end
    end
end

function WaiwaiResult:draw_panel()
    local f = self.frame - self.panel_f0
    local a = seg(f, 2, 20, 0.05, 1)
    self:D("duet_label", 640, 460, { a = a })
    self:D("percent", 748, 526, { a = a })

    local xs = { 679, 611, 549 }
    local value = tostring(self.duet)
    for i = 1, #value do
        local n
        if self.digits[i] then
            n = self.digits[i]
        elseif self.roll_id == i and self.st == DUET then
            n = self.roll_count % 10
        elseif i == 1 then
            n = 0
        end
        if n then self:D("digit_" .. n, xs[i], 528, { a = a }) end
    end
end

function WaiwaiResult:draw_message()
    local f = self.frame - self.msg_f0
    local s = 1
    if f < 2 then s = 3
    elseif f <= 14 then s = ease_in(f, 2, 14, 2.988, 0.95)
    elseif f <= 18 then s = seg(f, 15, 18, 0.987, 1.1)
    elseif f <= 23 then s = seg(f, 19, 23, 1.08, 1) end
    local a = seg(f, 2, 14, 0, 1)
    local cx, cy = 640, 276
    if self.word ~= WORD_FAIL then
        local spot = seg(f, 14, 18, 0, 1) * (0.926 + 0.074 * tri(f, 70))
        self:D("spotlight", cx - 140, cy - 76, { a = spot })
        self:D("spotlight", cx + 140, cy - 76, { a = spot, flip = true })
        self:D("floor_glow", cx, cy + 10, { sx = 1.06, sy = 1.453, a = 0.3 * seg(f, 14, 18, 0, 1) })
    end
    if self.msg >= 2 then
        for i, st in ipairs(STARS) do
            local pulse = 0.85 + 0.15 * tri(f + i * 7, 60)
            self:D(st[1], cx + st[2] * s, cy + st[3] * s, { s = st[4] * s * 0.75 * pulse, a = a })
        end
    end
    if self.text then
        local w, h = self.text.width * s, self.text.height * s
        self.text:draw({ x = (cx * S) - w / 2, y = (cy * S) - h / 2, x2 = w - self.text.width, y2 = h - self.text.height, fade = a })
    end
end

function WaiwaiResult:draw_front(ms)
    if self.panel_f0 then self:draw_panel() end
    if self.msg_f0 then self:draw_message() end
    if self.gauge_f0 then self:draw_gauge() end
    if self.word_f0 then self:draw_word() end
    local head_a = clamp01(self.frame / 12)
    self:D("heading", 184, 43, { a = head_a })
end
