local DonBGBase = require("background/bg_objects/donbg/base")
-- Hand-tuned band kept for the collabs that build on it (not yet reviewed). The default
-- band 4 is DonBG.SPECS[4].
DonBG4 = setmetatable({}, { __index = DonBGBase })
DonBG4.__index = DonBG4

function DonBG4.new(index, player_num, path)
    local self = setmetatable({}, DonBG4)
    local base = DonBGBase.new(index, player_num, path)
    for k, v in pairs(base) do
        self[k] = v
    end
    self.overlay_move = tex.get_animation(2, "background")
    self.overlay_texture = tex.get_texture_info(self.name, "overlay")
    self._id_overlay = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "overlay") or 0
    return self
end

function DonBG4:update(current_time_ms)
    DonBGBase.update(self, current_time_ms)
    self.overlay_move:update(current_time_ms)
end

function DonBG4:draw_textures(fade, y, frame)
    for i = 0, 4 do
        tex.draw_texture(self._id_bg, {
            frame = frame,
            fade = fade,
            x = (i * self.bg_texture.width) + self.move.attribute,
            y = y
        })
        tex.draw_texture(self._id_overlay, {
            frame = frame,
            fade = fade,
            x = (i * self.overlay_texture.width) + self.move.attribute,
            y = self.overlay_move.attribute + y
        })
    end
end

return DonBG4
