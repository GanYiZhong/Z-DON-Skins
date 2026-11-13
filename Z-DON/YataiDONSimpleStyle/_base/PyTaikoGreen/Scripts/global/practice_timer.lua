PracticeTimer = {}
PracticeTimer.__index = PracticeTimer

local GAUGE_FRAMES = 120
local GREEN        = { 0, 255, 0, 255 }
local RED          = { 255, 51, 51, 255 }
local DIM_MS       = 433  -- time-up dim fades in over this
local BANNER_MS    = 83

function PracticeTimer.new(max_seconds)
    local self = setmetatable({}, PracticeTimer)
    self.max = math.max(max_seconds, 1)

    self.disc        = tex.get_texture("global/practice_timer/disc")
    self.gauge       = tex.get_texture("global/practice_timer/gauge")
    self.digits      = tex.get_texture("global/practice_timer/digits")
    self.unit_minute = tex.get_texture("global/practice_timer/unit_minute")
    self.unit_second = tex.get_texture("global/practice_timer/unit_second")
    self.remaining   = tex.get_texture("global/practice_timer/remaining")
    self.mode_label  = tex.get_texture("global/practice_timer/mode_label")
    self.banner      = tex.get_texture("global/practice_timer/banner")
    self.fade        = tex.get_texture("global/practice_timer/fade")
    return self
end

function PracticeTimer:draw(seconds, up_ms, max_seconds)
    local max = max_seconds or self.max
    seconds = math.max(seconds, 0)
    local minutes_mode = seconds >= 60
    local value = minutes_mode and math.min(seconds // 60, 99) or seconds

    local frame = math.min(math.floor(GAUGE_FRAMES * seconds / math.max(max, 1)), GAUGE_FRAMES - 1)
    tex.draw_texture(self.disc, { color = minutes_mode and GREEN or RED })
    tex.draw_texture(self.gauge, { frame = frame })

    tex.draw_texture(self.mode_label)
    tex.draw_texture(self.remaining)
    tex.draw_texture(minutes_mode and self.unit_minute or self.unit_second)

    local str = tostring(math.floor(value))
    if #str == 1 then
        tex.draw_texture(self.digits, { frame = value, x = -19 })
    else
        tex.draw_texture(self.digits, { frame = tonumber(str:sub(2, 2)), x = 0 })
        tex.draw_texture(self.digits, { frame = tonumber(str:sub(1, 1)), x = -44 })
    end

    if up_ms and up_ms >= 0 then
        tex.draw_texture(self.fade, { fade = 0.965 * math.min(up_ms / DIM_MS, 1) })
        tex.draw_texture(self.banner, { fade = math.min(up_ms / BANNER_MS, 1) })
    end
end
