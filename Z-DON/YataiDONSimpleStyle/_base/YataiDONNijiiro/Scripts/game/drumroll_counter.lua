-- Drumroll fan and count. On the AI battle's stage it moves into each lane, turns teal and opens over 12 frames.

DrumrollCounter = {}
DrumrollCounter.__index = DrumrollCounter

-- centres of the fan and of a digit, from game/drumroll_counter/texture.json at scale 1
local FAN_CX,   FAN_CY   = 618.0, -140.0
local DIGIT_CX, DIGIT_CY = 658.0, -164.0

local UNFOLD_FRAMES = 12
local UNFOLD_SHAPE  = { 0, 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 3 }
local UNFOLD_ALPHA  = { 0.0, 0.332, 0.668, 1.0, 1.0 }

function DrumrollCounter.new(player_num)
    local self = setmetatable({}, DrumrollCounter)
    self.t_bubble  = tex.get_texture("game/drumroll_counter/bubble")
    self.t_counter = tex.get_texture("game/drumroll_counter/counter")
    self.margin    = tex.get_skin_config("game_drumroll_counter_margin").x
    self.x         = 0.0
    self.y         = 0.0
    self.scale     = 1.0
    if tex.current_screen() == "AI_GAME" then
        local ai_lane = player_num ~= tex.player_num()
        local pos = tex.get_skin_config(ai_lane and "ai_game_drumroll_ai" or "ai_game_drumroll")
        self.x, self.y = pos.x, pos.y
        self.scale    = tex.get_skin_config("game_ai_drumroll_counter_scale").x
        self.t_bubble = tex.get_texture("game/drumroll_counter/bubble_ai")
        self.t_unfold = tex.get_texture("game/drumroll_counter/bubble_unfold_ai")
    end
    return self
end

-- the digits scale with the fan, about the fan's centre
function DrumrollCounter:scaled(value, origin, centre, fan)
    return origin + fan - centre + self.scale * (centre - fan + value - origin)
end

function DrumrollCounter:draw(y, count, fade, stretch)
    y = y + self.y
    local bubble_alpha, digit_alpha, shape = 1.0, 1.0, nil
    if self.t_unfold then
        local now = tex.get_current_ms()
        self.start_ms = self.start_ms or now
        local k = math.floor(math.max(now - self.start_ms, 0.0) * 60.0 / 1000.0)
        if k < UNFOLD_FRAMES then
            shape = UNFOLD_SHAPE[k + 1]
            bubble_alpha = UNFOLD_ALPHA[k + 1] or 1.0
            digit_alpha = k < 8 and 0.0 or 0.2 * (k - 7)
        end
    end

    tex.draw_texture(shape and self.t_unfold or self.t_bubble, {
        frame = shape or 0,
        scale = self.scale,
        center = true,
        x = self.x,
        y = y,
        fade = fade * bubble_alpha,
    })
    if digit_alpha <= 0.0 then return end

    local digits = tostring(count)
    local s = tex.get_screen_scale()
    local total_width = #digits * self.margin
    for i = 1, #digits do
        tex.draw_texture(self.t_counter, {
            frame = tonumber(digits:sub(i, i)),
            scale = self.scale,
            center = true,
            x = self:scaled(self.x - total_width * 0.5 + (i - 1) * self.margin, self.x, DIGIT_CX * s, FAN_CX * s),
            y = self:scaled(y - stretch, y, DIGIT_CY * s, FAN_CY * s),
            y2 = stretch * self.scale,
            fade = fade * digit_alpha,
        })
    end
end

return DrumrollCounter
