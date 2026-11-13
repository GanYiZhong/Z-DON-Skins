-- SimpleStyle v2: countdown timer. A panel (global/timer/bg) with 48 px pixel digits; under 10 s the
-- panel turns don red with paper digits (bg_red / counter_white) and shakes 1U for 2 frames on each
-- tick. No scaling of pixel art. Voice cues follow the arcade schedule (30/10/5 s, nothing at 0).
local U = 3
local MARGIN = 27        -- 48 px digit (24 wide) + 1U
local DIGIT_Y = 6        -- digits sit under the のこり label
local UI = require("global.ss_ui")
local LABEL_CX, LABEL_CY = 1789, 87   -- the label row of the panel (ss/v2_meta.py build_timer)

Timer = {}
Timer.__index = Timer

local function stop_voice(name)
    if audio.stop_sound and audio.is_sound_playing(name) then
        audio.stop_sound(name)
    end
end

local VOICES = { "voice_timer_30", "voice_timer_10", "voice_timer_5" }

local function stop_all_voices()
    for _, v in ipairs(VOICES) do stop_voice(v) end
end

function Timer.new(time, current_time_ms, confirm_func, is_frozen)
    local self = setmetatable({}, Timer)
    self.time         = time
    self.last_time    = current_time_ms
    self.confirm_func = confirm_func
    self.is_frozen    = is_frozen
    self.is_finished  = false
    self.tick_ms      = -1e9
    self.now          = current_time_ms
    self.bg            = tex.get_texture("global/timer/bg")
    self.bg_red        = tex.get_texture("global/timer/bg_red")
    self.counter_black = tex.get_texture("global/timer/counter_black")
    self.counter_white = tex.get_texture("global/timer/counter_white")
    return self
end

function Timer:update(current_ms)
    self.now = current_ms
    if self.time == 0 and not self.is_finished then
        self.is_finished = true
        stop_all_voices()
        self.confirm_func()
    end
    if self.is_frozen then return end

    if current_ms >= self.last_time + 1000 and self.time > 0 then
        self.time      = self.time - 1
        self.last_time = current_ms
        if self.time < 10 then
            audio.play_sound("timer_blip", "sound")
            self.tick_ms = current_ms
        end
        if self.time == 30 then
            audio.play_sound("voice_timer_30", "voice")
        elseif self.time == 10 then
            stop_voice("voice_timer_30")
            audio.play_sound("voice_timer_10", "voice")
        elseif self.time == 5 then
            stop_voice("voice_timer_30")
            stop_voice("voice_timer_10")
            audio.play_sound("voice_timer_5", "voice")
        end
    end
end

function Timer:draw(x, y)
    local red = self.time < 10
    -- 2-frame 1U shake on each tick under 10 s (50 ms right, 50 ms left)
    local dx = 0
    local e = self.now - self.tick_ms
    if red and e >= 0 and e < 100 then dx = (e < 50) and U or -U end
    tex.draw_texture(red and self.bg_red or self.bg, { x = dx })
    -- のこり: engine text in the player's language (paper on the red panel, text2 on paper)
    local P = UI.D.P
    UI.draw_text(UI.text_key("timer_left", 18, { color = red and P.paper or P.text2 }), LABEL_CX + dx, LABEL_CY, "c")
    local counter = tostring(self.time)
    local t = red and self.counter_white or self.counter_black
    local total = #counter * MARGIN
    for i = 1, #counter do
        local digit = string.byte(counter, i) - string.byte("0")
        -- counter frames are 64 wide at x 1781 (centre 1813); the panel centre is 1789
        local cx = 1789 - total / 2 + (i - 1) * MARGIN + MARGIN / 2
        tex.draw_texture(t, { frame = digit, x = math.floor(cx - 1813 + dx), y = DIGIT_Y })
    end
end
