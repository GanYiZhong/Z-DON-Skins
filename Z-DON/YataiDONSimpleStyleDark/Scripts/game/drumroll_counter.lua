-- Drumroll bubble and count in SimpleStyle's own art: one bubble everywhere, no opening fan or AI colours.

DrumrollCounter = {}
DrumrollCounter.__index = DrumrollCounter

function DrumrollCounter.new(player_num)
    local self = setmetatable({}, DrumrollCounter)
    self.t_bubble  = tex.get_texture("game/drumroll_counter/bubble")
    self.t_counter = tex.get_texture("game/drumroll_counter/counter")
    self.margin    = tex.get_skin_config("game_drumroll_counter_margin").x
    self.x, self.y = 0.0, 0.0
    if tex.current_screen() == "AI_GAME" then
        local ai_lane = player_num ~= tex.player_num()
        local pos = tex.get_skin_config(ai_lane and "ai_game_drumroll_ai" or "ai_game_drumroll")
        if pos then self.x, self.y = pos.x, pos.y end
    end
    return self
end

function DrumrollCounter:draw(y, count, fade, stretch)
    y = y + self.y
    tex.draw_texture(self.t_bubble, { x = self.x, y = y, fade = fade })

    local digits = tostring(count)
    local total_width = #digits * self.margin
    for i = 1, #digits do
        tex.draw_texture(self.t_counter, {
            frame = tonumber(digits:sub(i, i)),
            x = self.x - total_width * 0.5 + (i - 1) * self.margin,
            y = y - stretch,
            y2 = stretch,
            fade = fade,
        })
    end
end

return DrumrollCounter
