ResultCrown = {}
ResultCrown.__index = ResultCrown

function ResultCrown.new(crown_type, is_2p)
    local self = setmetatable({}, ResultCrown)

    self.resize       = tex.get_animation(2, "result")
    self.resize_fix   = tex.get_animation(3, "result")
    self.white_fadein = tex.get_animation(4, "result")
    self.gleam        = tex.get_animation(5, "result")
    self.fadein       = tex.get_animation(6, "result")
    self.resize:start()
    self.resize_fix:start()
    self.white_fadein:start()
    self.gleam:start()
    self.fadein:start()

    self.is_2p        = is_2p
    self.sound_played = false

    local crown_names = { [0] = "crown_clear", [1] = "crown_fc", [2] = "crown_dfc" }
    self.t_crown      = tex.get_texture("result/crown/" .. (crown_names[crown_type] or "crown_clear"))
    self.t_crown_fade = tex.get_texture("result/crown/crown_fade")
    self.t_gleam      = tex.get_texture("result/crown/gleam")

    return self
end

function ResultCrown:update(current_ms)
    self.fadein:update(current_ms)
    self.resize:update(current_ms)
    self.resize_fix:update(current_ms)
    self.white_fadein:update(current_ms)
    self.gleam:update(current_ms)
    if self.resize_fix.is_finished and not self.sound_played then
        audio.play_sound("crown", "sound")
        self.sound_played = true
    end
end

function ResultCrown:is_settled()
    return self.resize_fix.is_finished
end

function ResultCrown:draw()
    local p_idx = self.is_2p and 1 or 0
    local scale = self.resize.is_finished
        and self.resize_fix.attribute
        or  self.resize.attribute
    if self.t_crown then
        tex.draw_texture(self.t_crown,
            { scale = scale, center = true, index = p_idx })
    end
    if self.t_crown_fade then
        tex.draw_texture(self.t_crown_fade,
            { fade = self.white_fadein.attribute, index = p_idx })
    end
    if self.t_gleam and self.gleam.attribute >= 0 then
        tex.draw_texture(self.t_gleam,
            { frame = math.floor(self.gleam.attribute), index = p_idx })
    end
end
