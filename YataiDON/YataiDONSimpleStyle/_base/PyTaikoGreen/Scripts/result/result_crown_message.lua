ResultCrownMessage = {}
ResultCrownMessage.__index = ResultCrownMessage

function ResultCrownMessage.new(frame, is_2p)
    local self = setmetatable({}, ResultCrownMessage)

    self.scale_in   = tex.get_animation(21, "result")
    self.scale_fix  = tex.get_animation(22, "result")
    self.fade_in_a  = tex.get_animation(23, "result")
    self.fade_out_a = tex.get_animation(24, "result")
    self.scale_in:start()
    self.scale_fix:start()
    self.fade_in_a:start()
    self.fade_out_a:start()

    self.frame = frame
    self.is_2p = is_2p

    self.t_msg = tex.get_texture("result/crown/message")

    return self
end

function ResultCrownMessage:update(current_ms)
    self.scale_in:update(current_ms)
    self.scale_fix:update(current_ms)
    self.fade_in_a:update(current_ms)
    self.fade_out_a:update(current_ms)
end

function ResultCrownMessage:draw()
    local scale = self.scale_in.is_finished
        and self.scale_fix.attribute
        or  self.scale_in.attribute
    local fade = math.min(self.fade_in_a.attribute, self.fade_out_a.attribute)
    if fade <= 0 then return end
    local p_idx = self.is_2p and 1 or 0
    if self.t_msg then
        tex.draw_texture(self.t_msg,
            { frame = self.frame, scale = scale, center = true, fade = fade, index = p_idx })
    end
end
