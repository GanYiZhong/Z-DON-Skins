RetryGame = {}
RetryGame.__index = RetryGame

local PATH = "retry_game/"
local FRAME = 1000 / 60

local SHUTTER_MS = 500           -- shutter halves leave (ease-in)
local SHUTTER_TRAVEL = 380
local MOON_IN_MS = 283
local MOON_SETTLE_MS = 84
local RULE_AT = 700
local RULE_MS = 5600            -- the two rule voice lines (2.3 s + 3.3 s)
local READY_MS = 2000
local GO_MS = 700
local COUNT_MS = 5000
local ZERO_MS = 1500             -- the "0" after time-up
local WHITE_RISE_AT, WHITE_RISE_MS = 1000, 633
local WHITE_HOLD_MS, WHITE_FALL_MS = 784, 466
local SWITCH_AT = 2400           -- scene changes under the white
local SUCCESS_MS = 1660
local FAILURE_MS = 2250
local END_HOLD_MS = 2000
local LAMP_OFF_MS = 130
local MARK_SPIN_MS = 2000

local MOON_CENTER_X, MOON_CENTER_Y = 640, 180
local BACK_SCALE = { 0.4, 0.5, 0.6, 0.7, 0.75, 0.8 }
local BIG_W = { 112, 144, 176, 240, 296, 360 }
-- light beams when the moon lights up: rest centre x, y, angle (right side mirrors), and where each sweeps in from
local BEAMS = {
    { 400, 400, 20, -130, 357, 5 }, { 260, 340, 35, -227, 305, 20 }, { 150, 250, 40, -256, 298, 30 },
}
-- fireworks over the lit moon: centre x, y and delay after the beams start (ms)
local FIREWORKS = { { 370, 100, 1167 }, { 940, 100, 1333 }, { 640, 130, 1483 } }
local ENCOURAGE = { "voice_renda" }
-- the leaf that blows across after a failure: frame, x, y (from (592, 508)), turn in degrees
local LEAF = {
    { 0, 737, -139, 0 }, { 10, 520, -33, 7.8 }, { 17, 360, 22, 9.3 }, { 30, 56, 80, 20.6 }, { 37, -77, 4, 94.3 },
    { 45, 37, -134, 177.2 }, { 47, 60, -141, 194 }, { 52, 180, -81, 265.7 }, { 61, 20, 41, 351.2 },
    { 69, -165, 86, 352.2 }, { 77, -356, 111, 357.5 }, { 89, -647, 100, 360 },
}
local TILES_X = { 0, 256, 512, 768, 1024 }

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function lerp(a, b, p) return a + (b - a) * p end
local function ease_out(p) return 1 - (1 - p) * (1 - p) end
local function ease_in(p) return p * p end
local function seg(t, from, len) return clamp((t - from) / len, 0, 1) end

local function snd(name, kind)
    if audio.has_sound(name) then audio.play_sound(name, kind or "sound") end
end

local function T(folder, name) return tex.get_texture(PATH .. folder .. "/" .. name) end
local function draw(t, params) if t then tex.draw_texture(t, params) end end

function RetryGame.new(player_num, norma)
    local self = setmetatable({}, RetryGame)
    self.player = player_num or 0
    self.norma = math.max(1, norma or 30)
    self.hits = 0
    self.lit = false
    self.lit_at = nil
    self.hand_pose = 0
    self.hand_toggle = 0
    self.hand_hit_at = -1e9
    self.drum_hit_at = -1e9
    self.waves = {}
    self.t0 = nil
    self.t = 0
    self.finished = false
    self.success = false
    self.timeup = false
    self.result_at = nil

    self.sky = T("background", "sky")
    self.sky_win = T("background", "sky_win")
    self.stars = T("background", "stars")
    self.moon = T("moon", "moon")
    self.mark = T("moon", "mark")
    self.face_win = T("moon", "face_win")
    self.face_lose = T("moon", "face_lose")
    self.wave = T("moon", "wave")
    self.pole = T("stage", "pole")
    self.rope_a = T("stage", "rope_a")
    self.rope_b = T("stage", "rope_b")
    self.yagura = T("stage", "yagura")
    self.stall_octopus = T("stage", "stall_octopus")
    self.stall_squid = T("stage", "stall_squid")
    self.face_octopus = T("stage", "face_octopus")
    self.face_squid = T("stage", "face_squid")
    self.drum_body = T("drum", "body")
    self.drum_hit = T("drum", "hit")
    self.drum_ring = T("drum", "ring")
    self.back, self.front, self.big, self.glow = {}, {}, {}, {}
    for i = 0, 5 do
        self.back[i] = T("lamps", "back_" .. i)
        self.front[i] = T("lamps", "front_" .. i)
        self.big[i] = T("lamps", "big_" .. i)
        self.glow[i] = T("lamps", "glow_" .. i)
    end
    self.fist_line = T("hands", "fist_outline")
    self.stick_line = T("hands", "stick_outline")
    self.fist_fill = T("hands", "fist_fill")
    self.stick_fill = T("hands", "stick_fill")
    self.rule = T("text", "rule_" .. tex.language())
    self.ready = T("text", "ready_" .. tex.language())
    self.go = T("text", "go_" .. tex.language())
    self.burst = T("text", "burst_" .. tex.language())
    self.success_text = T("text", "success_" .. tex.language())
    self.failure_text = T("text", "failure_" .. tex.language())
    self.more_text = T("text", "more_" .. tex.language())
    self.digits = T("text", "digits")
    self.rays = T("effects", "rays")
    self.white = T("effects", "white")
    self.beam = T("effects", "beam")
    self.firework = T("effects", "firework")
    self.leaf = T("effects", "leaf")
    local color = self.player == 2 and "blue" or "red"
    self.tile = T("shutter", color .. "_tile")
    self.cap = T("shutter", color .. "_cap")

    self.fired = {}
    self.t_rule = RULE_AT
    self.t_ready = self.t_rule + RULE_MS
    self.t_go = self.t_ready + READY_MS
    self.t_end = self.t_go + COUNT_MS
    return self
end

function RetryGame:counting()
    return self.t >= self.t_go and self.t < self.t_end
end

function RetryGame:lamps_lit()
    if self.result_at and not self.success then
        local e = self.t - self.result_at
        return math.max(0, self.lamps_at_end - math.floor(e / LAMP_OFF_MS))
    end
    if self.lit then return 6 end
    return clamp(math.floor(self.hits * 6 / self.norma), 0, 5)
end

function RetryGame:hit()
    if not self:counting() then return end
    local lamps_before = self:lamps_lit()
    self.hits = self.hits + 1
    self.drum_hit_at = self.t
    self.hand_hit_at = self.t
    self.hand_pose = self.hand_toggle == 0 and 1 or 3
    self.hand_toggle = 1 - self.hand_toggle
    if not self.lit then
        self.waves[#self.waves + 1] = self.t
        if #self.waves > 8 then table.remove(self.waves, 1) end
        if self.hits >= self.norma then
            self.lit = true
            self.lit_at = self.t
            self.waves = {}
            snd("moon")
            snd("voice_more", "voice")
        end
        if self:lamps_lit() > lamps_before then snd("lamp_up") end
    end
end

-- fire `fn` once, the first time `cond` holds
function RetryGame:once(key, cond, fn)
    if cond and not self.fired[key] then
        self.fired[key] = true
        fn()
    end
end

function RetryGame:sounds()
    local t = self.t
    self:once("appear", true, function() snd("appear") end)
    self:once("about", t >= self.t_rule, function() snd("voice_about_1", "voice") end)
    self:once("about2", self.fired.about and t >= self.t_rule + 100 and not audio.is_sound_playing("voice_about_1"),
        function() snd("voice_about_2", "voice") end)
    self:once("yoi", t >= self.t_ready, function() snd("voice_yoi", "voice") end)
    self:once("go", t >= self.t_go, function()
        snd("voice_don", "voice")
        snd("bgm", "music")
    end)
    for k = 1, 4 do
        self:once("cnt" .. k, t >= self.t_go + k * 1000 - FRAME, function() snd("timer_blip") end)
    end
    -- encouragement at equal spacing while the goal is out of reach
    for i, name in ipairs(ENCOURAGE) do
        local at = self.t_go + i * COUNT_MS / (#ENCOURAGE + 1)
        self:once("encourage" .. i, t >= at and t < at + 500 and not self.lit, function() snd(name, "voice") end)
    end
    if self.lit_at and not self.timeup then
        for i, f in ipairs(FIREWORKS) do
            self:once("firework" .. i, t - self.lit_at >= f[3], function() snd("fireworks") end)
        end
    end
    self:once("timeout", self.timeup, function()
        if audio.is_sound_playing("bgm") then audio.stop_sound("bgm") end
        snd("whistle")
    end)
    if self.timeup and self.success then
        self:once("flash", t >= self.t_end + ZERO_MS + 650, function() snd("se_flash") end)
        self:once("success", self.result_at ~= nil, function()
            snd("clear")
            snd("voice_clear", "voice")
        end)
    elseif self.timeup then
        self:once("miss", true, function()
            snd("fail")
            snd("voice_fail", "voice")
        end)
        local lamps = self:lamps_lit()
        if lamps < (self.last_lamps or lamps) then snd("lamp_down") end
        self.last_lamps = lamps
        self:once("wind", t >= self.result_at + FAILURE_MS, function() snd("wind") end)
    end
end

function RetryGame:update(current_ms)
    if not self.t0 then self.t0 = current_ms end
    self.t = current_ms - self.t0

    if not self.timeup and self.t >= self.t_end then
        self.timeup = true
        self.success = self.lit
        self.lamps_at_end = self:lamps_lit()
        if not self.success then self.result_at = self.t_end end
    end
    if self.timeup and self.success and not self.result_at and self.t >= self.t_end + ZERO_MS + SWITCH_AT then
        self.result_at = self.t
    end
    if self.result_at then
        local len = self.success and SUCCESS_MS or FAILURE_MS
        if self.t >= self.result_at + len + END_HOLD_MS then self.finished = true end
    end
    self:sounds()
end

function RetryGame:is_finished() return self.finished end
function RetryGame:is_success() return self.success end

-- hands: a pose rests on wait0/wait1 and strikes on swing0/swing1 for a few frames
function RetryGame:hand_frame()
    local since = self.t - self.hand_hit_at
    if since < 100 then return self.hand_pose end
    if self.hand_pose == 1 then return 2 end
    return 0
end

function RetryGame:draw_lamp_set(set, size_of, count)
    for i = 0, 5 do
        local t = set[i]
        if t then
            local on = i < count and 1 or 0
            local s = size_of(i)
            for side = 0, 1 do
                local params = { index = side, frame = on, scale = s }
                if side == 0 then params.mirror = "horizontal" end
                draw(t, params)
            end
        end
    end
end

function RetryGame:draw_lamp_glows(count)
    local pulse = 0.6 + 0.4 * math.sin(self.t / 130)
    local sets = {
        { set = self.back, name = "back_", w = function(i) return 96 * BACK_SCALE[i + 1] end },
        { set = self.front, name = "front_", w = function() return 96 end },
        { set = self.big, name = "big_", w = function(i) return BIG_W[i + 1] end },
    }
    for _, spec in ipairs(sets) do
        for i = 0, count - 1 do
            local g = self.glow[i]
            local info = tex.get_texture_info("lamps", spec.name .. i)
            if g and info then
                local w = spec.w(i)
                local px = w * 1.45
                for side = 1, 2 do
                    draw(g, { x = info.x[side] + (w - px) / 2, y = info.y[side] + (w * 1.25 - px) / 2,
                              x2 = px - 256, y2 = px - 256, fade = 0.55 * pulse })
                end
            end
        end
    end
end

function RetryGame:draw_shutter()
    local p = ease_in(seg(self.t, 0, SHUTTER_MS))
    if p >= 1 then return end
    local dy = SHUTTER_TRAVEL * p
    for half = 0, 1 do
        local y = half == 0 and (-360 - dy) or (360 + dy)
        for _, x in ipairs(TILES_X) do
            draw(self.tile, { x = x, y = y + 20, fade = 0.4 })
        end
        for _, x in ipairs(TILES_X) do
            draw(self.tile, { x = x, y = y })
            draw(self.cap, { x = x, y = y + 288 })
        end
    end
end

function RetryGame:draw_moon()
    local t = self.t
    local y = 0
    if t < MOON_IN_MS then
        y = lerp(-560, 20, ease_out(t / MOON_IN_MS))
    elseif t < MOON_IN_MS + MOON_SETTLE_MS then
        y = lerp(20, 0, ease_in((t - MOON_IN_MS) / MOON_SETTLE_MS))
    end
    local shine = self.lit or (self.success and self.timeup)
    if shine then
        local px = 256 * 2.5
        local pulse = 0.6 + 0.2 * math.sin(t / 160)
        draw(self.glow[2], { x = MOON_CENTER_X - px / 2, y = MOON_CENTER_Y + y - px / 2, x2 = px - 256, y2 = px - 256, fade = pulse })
    end
    draw(self.moon, { y = y })
    if shine then
        draw(self.face_win, { y = y })
    elseif self.timeup then
        draw(self.face_lose, { y = y })
    else
        local angle = (t % MARK_SPIN_MS) / MARK_SPIN_MS * 360
        draw(self.mark, { x = 320, y = 320 + y, rotation = angle, origin = { 320, 320 }, fade = 0.4 })
    end
    for _, at in ipairs(self.waves) do
        local p = seg(t, at, 333)
        if p < 1 then
            local s = p < 0.5 and lerp(1.6, 1.04, p / 0.5) or lerp(1.04, 0.95, (p - 0.5) / 0.5)
            local a = p < 0.35 and 0.3 or (p < 0.7 and lerp(0.3, 0.9, (p - 0.35) / 0.35) or lerp(0.9, 0, (p - 0.7) / 0.3))
            draw(self.wave, { center = true, scale = s, y = y, fade = a })
        end
    end
end

function RetryGame:draw_hands()
    if self.timeup then return end
    local frame = self:hand_frame()
    draw(self.fist_line, { frame = frame })
    draw(self.stick_line, { frame = frame })
    draw(self.fist_fill, { frame = frame })
    draw(self.stick_fill, { frame = frame })
end

function RetryGame:draw_drum()
    draw(self.drum_body)
    local since = self.t - self.drum_hit_at
    if since >= 0 and since < 133 then
        local dip = since < 67 and lerp(0, 5, ease_out(since / 67)) or lerp(5, 0, ease_in((since - 67) / 66))
        draw(self.drum_ring, { y = dip, fade = 0.4 })
        draw(self.drum_hit, { y = dip })
    end
end

function RetryGame:draw_stalls()
    draw(self.yagura, { index = 0 })
    draw(self.yagura, { index = 1, mirror = "horizontal" })
    if self.lit or (self.timeup and self.success) then
        local pulse = 0.5 + 0.2 * math.sin(self.t / 140)
        for _, x in ipairs({ 467, 537, 607, 677, 747 }) do
            draw(self.glow[5], { x = x, y = 406, x2 = 64 - 256, y2 = 64 - 256, fade = pulse })
        end
    end
    draw(self.stall_octopus)
    draw(self.stall_squid)
    local face = 0
    if self.timeup and self.success then face = 1 elseif self.timeup then face = 2 end
    draw(self.face_octopus, { frame = face })
    draw(self.face_squid, { frame = face })
end

function RetryGame:draw_signal()
    local t = self.t
    if t >= self.t_rule and t < self.t_ready + 1 then
        local e = t - self.t_rule
        local s = e < 250 and lerp(0.8, 1.1, ease_out(e / 250)) or (e < 500 and lerp(1.1, 1, (e - 250) / 250) or 1)
        draw(self.rule, { center = true, scale = s, fade = clamp(e / 250, 0, 1) })
    elseif t >= self.t_ready and t < self.t_go then
        local e = t - self.t_ready
        local s = e < 317 and lerp(2, 0.95, ease_in(e / 317)) or (e < 467 and lerp(0.955, 1, (e - 317) / 150) or 1)
        draw(self.ready, { center = true, scale = s, fade = e < 317 and lerp(0.2, 1, e / 317) or 1 })
    elseif t >= self.t_go and t < self.t_go + GO_MS then
        local e = t - self.t_go
        local s, a = 1, 1
        if e < 167 then s = lerp(1, 1.2, ease_out(e / 167))
        elseif e < 334 then s = lerp(1.2, 1, ease_in((e - 167) / 167))
        elseif e > 451 then a = lerp(0.8, 0, ease_out(clamp((e - 451) / 133, 0, 1))) end
        draw(self.go, { center = true, scale = s, fade = a })
    end
end

function RetryGame:draw_count()
    local t = self.t
    if self:counting() then
        local e = t - self.t_go
        local left = math.ceil((COUNT_MS - e) / 1000)
        local p = (e % 1000) / 1000
        local s = 0.7 + 0.3 * math.sin(math.pi * clamp(p / 0.95, 0, 1))
        draw(self.digits, { frame = clamp(left, 1, 5), center = true, scale = s })
        local pulse = 0.975 + 0.025 * math.sin(e / 467 * math.pi * 2)
        local bs, ba = pulse, 1
        if self.lit_at then
            local q = t - self.lit_at
            if q < 100 then bs, ba = lerp(0.6, 1, q / 100), q / 100
            elseif q < 200 then bs = lerp(1, 1.2, (q - 100) / 100)
            elseif q < 300 then bs = lerp(1.2, 1, (q - 200) / 100) end
        end
        draw(self.burst, { center = true, scale = bs, fade = ba })
    elseif self.timeup and t < self.t_end + ZERO_MS then
        local e = t - self.t_end
        local s = e < 100 and lerp(1.3, 1.14, e / 100) or (e < 320 and lerp(1.14, 1, ease_out((e - 100) / 220)) or 1)
        local a = e > 1283 and lerp(0.93, 0, (e - 1283) / 217) or 1
        draw(self.digits, { frame = 0, center = true, scale = s, fade = a })
    end
end

function RetryGame:draw_result()
    if not self.result_at then return end
    local e = self.t - self.result_at
    if self.success then
        local y, s = 0, 1
        if e < 217 then y = lerp(-90, -40, e / 217); s = lerp(0.4, 0.7, e / 217)
        elseif e < 317 then y = lerp(-40, 10, (e - 217) / 100); s = lerp(0.7, 1.1, (e - 217) / 100)
        elseif e < 400 then y = lerp(10, 0, (e - 317) / 83); s = lerp(1.1, 1, (e - 317) / 83)
        elseif e < 1300 then y = 0
        else y = lerp(0, -90, ease_out(clamp((e - 1300) / 267, 0, 1))) end
        draw(self.success_text, { center = true, scale = s, y = y, fade = clamp(e / 217, 0, 1) })
        if e > 1283 then
            local p = ease_out(clamp((e - 1283) / 183, 0, 1))
            draw(self.more_text, { center = true, scale = lerp(1, 1.02, p), fade = p })
        end
    else
        local y = 0
        if e < 317 then y = lerp(-450, 0, ease_in(e / 317))
        elseif e < 550 then y = -119.5 * ease_out(seg(e, 317, 233))
        elseif e < 767 then y = lerp(-119.5, 10, ease_in(seg(e, 550, 217)))
        elseif e < 950 then y = lerp(10, -20, ease_out(seg(e, 767, 183)))
        elseif e < 1050 then y = lerp(-20, 0, ease_in(seg(e, 950, 100)))
        end
        draw(self.failure_text, { y = y, fade = clamp(e / 317, 0, 1) })
        self:draw_leaf(e - FAILURE_MS)
    end
end

-- side rays flash over the success scene
function RetryGame:draw_rays()
    if not (self.timeup and self.success and self.result_at) then return end
    local e = self.t - self.result_at
    local a = clamp(e / 333, 0, 1) * 0.5
    local frame = math.floor(e / (5 * FRAME)) % 3
    draw(self.rays, { index = 0, frame = frame, fade = a })
    draw(self.rays, { index = 1, frame = frame, fade = a, mirror = "horizontal" })
end

-- beams and fireworks play while the moon is lit and the clock still runs
function RetryGame:draw_lit_effects()
    if not self.lit_at or self.timeup then return end
    local e = self.t - self.lit_at
    for _, b in ipairs(BEAMS) do
        local p = ease_out(seg(e, 233, 560))
        local sy = lerp(0.1, 1, ease_out(seg(e, 233, 300)))
        if e >= 233 then
            for side = -1, 1, 2 do
                local x = side == -1 and lerp(b[1] + b[4], b[1], p) or lerp(1280 - b[1] - b[4], 1280 - b[1], p)
                local y = lerp(b[2] + b[5], b[2], p)
                local ang = lerp(b[6], b[3], p) * (side == -1 and 1 or -1)
                draw(self.beam, { x = x, y = y, y2 = 840 * sy - 840, origin = { 60, 420 * sy }, rotation = ang, fade = 0.7 })
            end
        end
    end
    for _, f in ipairs(FIREWORKS) do
        local fe = e - f[3]
        if fe >= 0 and fe < 1000 then
            local s = fe < 450 and lerp(0.001, 1, ease_out(fe / 450)) or lerp(1, 1.1, (fe - 450) / 550)
            local a = fe < 500 and 1 or lerp(1, 0, (fe - 500) / 483)
            draw(self.firework, { x = f[1] - 200, y = f[2] - 200, center = true, scale = s, fade = clamp(a, 0, 1) })
        end
    end
end

function RetryGame:draw_leaf(e)
    local f = e / FRAME
    local last = LEAF[#LEAF]
    if f < 0 or f > last[1] then return end
    for i = 2, #LEAF do
        local a, b = LEAF[i - 1], LEAF[i]
        if f <= b[1] then
            local p = (f - a[1]) / (b[1] - a[1])
            draw(self.leaf, { x = 592 + lerp(a[2], b[2], p), y = 508 + lerp(a[3], b[3], p), origin = { 48, 32 }, rotation = lerp(a[4], b[4], p) })
            return
        end
    end
end

function RetryGame:draw_white()
    if not self.timeup or not self.success then return end
    local e = self.t - (self.t_end + ZERO_MS)
    local a = 0
    if e >= WHITE_RISE_AT then
        if e < WHITE_RISE_AT + WHITE_RISE_MS then a = (e - WHITE_RISE_AT) / WHITE_RISE_MS
        elseif e < WHITE_RISE_AT + WHITE_RISE_MS + WHITE_HOLD_MS then a = 1
        else a = 1 - seg(e, WHITE_RISE_AT + WHITE_RISE_MS + WHITE_HOLD_MS, WHITE_FALL_MS) end
    end
    if a > 0 then draw(self.white, { fade = a }) end
end

local CHARA_X, CHARA_Y, CHARA_SCALE = 640, 330, 1.0

function RetryGame:chara_pos() return { CHARA_X, CHARA_Y, CHARA_SCALE } end

function RetryGame:phase()
    if not self.timeup then return self:counting() and "count" or "wait" end
    return self.success and "success" or "failure"
end

function RetryGame:draw_back()
    -- the success scene (daylight sky, happy faces) replaces the night one under the white
    local e_end = self.t - (self.t_end + ZERO_MS)
    local switched = self.timeup and self.success and e_end >= SWITCH_AT
    draw(switched and self.sky_win or self.sky)
    draw(self.stars, { fade = 0.4 })
    self:draw_moon()
    self:draw_lit_effects()  -- behind the stage, over the moon
    draw(self.pole, { index = 0 })
    draw(self.pole, { index = 1, mirror = "horizontal" })
    draw(self.rope_a, { index = 0 })
    draw(self.rope_a, { index = 1, mirror = "horizontal" })
    draw(self.rope_b, { index = 0 })
    draw(self.rope_b, { index = 1, mirror = "horizontal" })

    local count = self:lamps_lit()
    self:draw_lamp_set(self.back, function(i) return BACK_SCALE[i + 1] end, count)
    self:draw_lamp_set(self.front, function() return 1 end, count)
end

function RetryGame:draw_front()
    local count = self:lamps_lit()
    self:draw_hands()
    self:draw_drum()
    self:draw_stalls()
    self:draw_lamp_set(self.big, function() return 1 end, count)
    self:draw_lamp_glows(count)
    self:draw_rays()
    self:draw_signal()
    self:draw_count()
    self:draw_white()
    self:draw_result()
    self:draw_shutter()
end

function RetryGame:draw()
    self:draw_back()
    self:draw_front()
end
