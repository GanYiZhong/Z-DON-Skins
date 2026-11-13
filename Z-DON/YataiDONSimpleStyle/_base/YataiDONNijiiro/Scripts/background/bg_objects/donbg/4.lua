-- YataiDON-HSS override of PyTaikoGreen/background/bg_objects/donbg/4.lua:
-- restores the parent DonBG4 overlay row (funassyi's flag banners) on top of the
-- base contract.
local DonBGBase = require("background/bg_objects/donbg/base")

local DonBG4 = setmetatable({}, { __index = DonBGBase })
DonBG4.__index = DonBG4

function DonBG4.new(index, player_num, path)
    local self = setmetatable({}, DonBG4)
    local base = DonBGBase.new(index, player_num, path)
    for k, v in pairs(base) do self[k] = v end
    self.overlay_move = tex.get_animation(2, "background")
    self.overlay_texture = tex.get_texture_info(self.name, "overlay")
    self._id_overlay = tex.get_texture(self.path .. "/" .. self.name .. "/overlay")  -- nil = missing
    return self
end

function DonBG4:update(current_time_ms)
    DonBGBase.update(self, current_time_ms)
    if self.overlay_move then self.overlay_move:update(current_time_ms) end
end

function DonBG4:draw_textures(fade, y, frame)
    local w = self.bg_texture and self.bg_texture.x2[1] or 0
    local ow = self.overlay_texture and self.overlay_texture.x2[1] or 0
    local mv = self.move and self.move.attribute or 0
    local omv = self.overlay_move and self.overlay_move.attribute or 0
    for i = 0, 4 do
        if self._id_bg then
            tex.draw_texture(self._id_bg, {
                frame = frame,
                fade = fade,
                x = (i * w) + mv,
                y = y
            })
        end
        -- banner row scrolls with the tiles and bobs on anim 2
        if self._id_overlay and self.overlay_texture then
            tex.draw_texture(self._id_overlay, {
                frame = frame,
                fade = fade,
                x = (i * ow) + mv,
                y = omv + y
            })
        end
    end
end

return DonBG4
