-- SimpleStyle v2 (meta): the retry mini-game (Nijiiro disables it with disable_retry_game; covered in
-- case a user turns it on). Logic, timing and sounds are PyTaikoGreen's; the picture is ours: the house
-- scene, a dialog with the rule / count, six lanterns that light up with the hits, Momo drumming (k=9)
-- and Hoshi reacting. Every Green retry_game texture is blanked.
local SSM = require("global.ss_meta")
local UI = SSM.UI
local DD = UI.D
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
    if self.momo then self.momo:react("hit") end
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

local LAMP_X0, LAMP_DX, LAMP_Y = 645, 108, 309
local DLG_X, DLG_Y, DLG_W, DLG_H = 510, 72, 900, 162
local GROUND = 1032

function RetryGame:ss_init()
    if self.momo then return end
    UI.reset()
    self.momo = UI.Mascot.new({ role = "scene", beat = false })
    self.hoshi = UI.Mascot.new({ char = DD.MASCOT.buddy, role = "scene", beat = false })
    self.hoshi:react("turn", -1)
    self.l_rule = UI.text_key("retry_rule", 36, nil, tostring(self.norma))
    self.l_ready = UI.text_key("retry_ready", 36)
    self.l_go = UI.text_key("retry_go", 48)
    self.l_ok = UI.text_key("retry_ok", 48)
    self.l_ng = UI.text_key("retry_ng", 48)
end

function RetryGame:chara_pos() return { -4000, -4000, 1.0 } end

function RetryGame:phase()
    if not self.timeup then return self:counting() and "count" or "wait" end
    return self.success and "success" or "failure"
end

function RetryGame:draw_back()
    self:ss_init()
    local now = (self.t0 or 0) + self.t
    self.momo:update(now)
    self.hoshi:update(now)
    local scene = SSM.T("scene")
    if scene then tex.draw_texture(scene, { x = 0, y = 0 }) end
    -- six lanterns: lit with the hits
    local lamp = SSM.T("lamp")
    local lit = self:lamps_lit()
    for i = 0, 5 do
        if lamp then tex.draw_texture(lamp, { frame = (i < lit) and 1 or 0, x = LAMP_X0 + i * LAMP_DX, y = LAMP_Y }) end
    end
    if self.lit_at then
        for i = 0, 5 do UI.burst(LAMP_X0 + i * LAMP_DX + 21, LAMP_Y + 30, self.t - self.lit_at - i * 66) end
    end
end

function RetryGame:draw_front()
    local t = self.t
    -- dialog: rule / ready / go / count / result
    local open = t - 200
    local x, y, w, h, full = UI.open_rect(DLG_X, DLG_Y, DLG_W, DLG_H, open)
    if x then
        UI.chrome.dialog(x, y, w, h)
        if full then
            local cx, cy = DLG_X + DLG_W / 2, DLG_Y + DLG_H / 2
            if self.result_at then
                UI.draw_text(self.success and self.l_ok or self.l_ng, cx, cy, "c")
            elseif self.timeup then
                UI.num("0", cx, cy, "xl", DD.P.don, 255, "c")
            elseif self:counting() then
                if t < self.t_go + GO_MS then
                    UI.draw_text(self.l_go, cx, cy, "c")
                else
                    local left = math.max(0, math.ceil((self.t_end - t) / 1000))
                    UI.num(tostring(left), cx - 90, cy, "xl", left <= 2 and DD.P.don or DD.P.ink, 255, "c")
                    UI.num(tostring(self.hits) .. "/" .. tostring(self.norma), cx + 120, cy, "l", DD.P.ink, 255, "c")
                end
            elseif t >= self.t_ready then
                UI.draw_text(self.l_ready, cx, cy, "c")
            else
                UI.draw_text(self.l_rule, cx, cy, "c")
            end
        end
    end
    -- the pair on the grass: Momo drums, Hoshi cheers or sulks
    if self.result_at then
        if self.success then self.momo:set_mood("clear"); self.hoshi:react("decide")
        else self.momo:set_mood("sit_fail"); self.hoshi:set_mood("sad") end
    end
    self.momo:draw(870, GROUND)
    self.hoshi:draw(1260, GROUND)
    -- opening: sky dither out; success flash: paper dither in/out around the scene switch
    UI.wipe(UI.wipe_out(t, 50), DD.P.sky)
    if self.result_at and self.success then
        local e = self.t - self.result_at
        if e < 150 then UI.wipe(3 - math.floor(e / 50), DD.P.paper) end
    end
end

function RetryGame:draw()
    self:draw_back()
    self:draw_front()
end
