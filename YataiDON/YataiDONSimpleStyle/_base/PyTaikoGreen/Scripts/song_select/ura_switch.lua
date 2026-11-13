UraSwitchAnimation = {}
UraSwitchAnimation.__index = UraSwitchAnimation

function UraSwitchAnimation.new()
    local self = setmetatable({}, UraSwitchAnimation)

    self.texture_change = tex.get_animation(7, "song_select")
    self.fade_out       = tex.get_animation(8, "song_select")
    self.t_ura_switch   = tex.get_texture("song_select/diff_select/ura_switch")

    return self
end

function UraSwitchAnimation:start(is_backwards)
    self.texture_change = tex.get_animation(is_backwards and 6 or 7, "song_select")
    self.texture_change:start()
    self.fade_out:start()
end

function UraSwitchAnimation:update(current_ms)
    self.texture_change:update(current_ms)
    self.fade_out:update(current_ms)
end

function UraSwitchAnimation:draw()
    tex.draw_texture(self.t_ura_switch, {
        frame = math.floor(self.texture_change.attribute),
        fade = self.fade_out.attribute,
    })
end
