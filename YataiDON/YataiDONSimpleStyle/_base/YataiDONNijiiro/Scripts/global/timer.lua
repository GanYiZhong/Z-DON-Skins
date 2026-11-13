local SKIN = {
    timer_text_margin = { x = 48 },
}
-- Countdown timer; the voice cues match the arcade's schedule (30/10/5 s, nothing at 0).
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

    self.bg           = tex.get_texture("global/timer/bg")
    self.bg_red       = tex.get_texture("global/timer/bg_red")
    self.counter_black = tex.get_texture("global/timer/counter_black")
    self.counter_white = tex.get_texture("global/timer/counter_white")
    self.highlight    = tex.get_texture("global/timer/highlight")

    self.num_resize       = tex.get_animation(9,  "global")
    self.highlight_resize = tex.get_animation(10, "global")
    self.highlight_fade   = tex.get_animation(11, "global")

    self.margin = SKIN.timer_text_margin.x

    return self
end

function Timer:update(current_ms)
    -- reaching 0 stops any playing voice and finishes immediately
    if self.time == 0 and not self.is_finished then
        self.is_finished = true
        stop_all_voices()
        self.confirm_func()
    end

    self.num_resize:update(current_ms)
    self.highlight_resize:update(current_ms)
    self.highlight_fade:update(current_ms)

    if self.is_frozen then return end

    if current_ms >= self.last_time + 1000 and self.time > 0 then
        self.time      = self.time - 1
        self.last_time = current_ms

        if self.time < 10 then
            audio.play_sound("timer_blip", "sound")
            self.num_resize:start()
            self.highlight_fade:start()
            self.highlight_resize:start()
        end

        if self.time == 30 then
            audio.play_sound("voice_timer_30", "voice")
        elseif self.time == 10 then
            -- pre-empt a still-running earlier voice
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
    local counter = tostring(self.time)
    local counter_tex

    if self.time < 10 then
        tex.draw_texture(self.bg_red)
        counter_tex = self.counter_white
        tex.draw_texture(self.highlight, {
            scale  = self.highlight_resize.attribute,
            center = true,
            fade   = self.highlight_fade.attribute,
        })
    else
        tex.draw_texture(self.bg)
        counter_tex = self.counter_black
    end

    local total_width = #counter * self.margin
    for i = 1, #counter do
        local digit = string.byte(counter, i) - string.byte("0")
        tex.draw_texture(counter_tex, {
            frame  = digit,
            scale  = self.num_resize.attribute,
            center = true,
            x      = -(total_width / 2) + ((i - 1) * self.margin),
        })
    end
end
