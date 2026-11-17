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
    self.to_ura, self.landed = is_backwards, false
end

function UraSwitchAnimation:update(current_ms)
    self.texture_change:update(current_ms)
    self.fade_out:update(current_ms)
    if self.to_ura and not self.landed and self.texture_change.is_finished then
        self.landed = true
        if audio.has_sound("ura_land") then audio.play_sound("ura_land", "sound") end
    end
end

function UraSwitchAnimation:draw()
    tex.draw_texture(self.t_ura_switch, {
        frame = math.floor(self.texture_change.attribute),
        fade = self.fade_out.attribute,
    })
end
