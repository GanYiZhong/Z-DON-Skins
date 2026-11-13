local SKIN_S = tex.get_screen_scale()
local SKIN = {
    high_score_indicator_margin = { x = 14 * SKIN_S },
}
HighScoreIndicator = {}
HighScoreIndicator.__index = HighScoreIndicator

function HighScoreIndicator.new(score_diff, is_2p)
    local self = setmetatable({}, HighScoreIndicator)

    self.move_anim = tex.get_animation(18, "result")
    self.fade_anim = tex.get_animation(19, "result")
    self.move_anim:start()
    self.fade_anim:start()

    self.score_diff = score_diff
    self.is_2p      = is_2p

    self.t_label = tex.get_texture("result/score/high_score")
    self.t_num   = tex.get_texture("result/score/high_score_num")
    local hs = SKIN.high_score_indicator_margin
    self.sc_margin = hs and hs.x or 0

    return self
end

function HighScoreIndicator:update(current_ms)
    self.move_anim:update(current_ms)
    self.fade_anim:update(current_ms)
end

function HighScoreIndicator:draw()
    local p_idx = self.is_2p and 1 or 0
    local y    = self.move_anim.attribute
    local fade = self.fade_anim.attribute
    if self.t_label then
        tex.draw_texture(self.t_label, { y = y, fade = fade, index = p_idx })
    end
    if self.t_num and self.score_diff > 0 then
        local str = tostring(self.score_diff)
        for i = 1, #str do
            local d = tonumber(string.sub(str, #str - i + 1, #str - i + 1)) or 0
            tex.draw_texture(self.t_num, {
                frame = d,
                x     = -((i - 1) * self.sc_margin),
                y     = y,
                fade  = fade,
                index = p_idx,
            })
        end
    end
end
