local SKIN_S = tex.get_screen_scale()
local SKIN = {
    combo_announce_add_x = { x = 435 * SKIN_S },
    combo_announce_thousands_add_x = { x = 429 * SKIN_S },
    combo_announce_number_thousands_x = { x = -23 * SKIN_S },
    combo_announce_text_offset = { x = -30 * SKIN_S },
    combo_announce_thousands_offset = { x = -110 * SKIN_S },
    combo_announce_hundreds_offset = { x = 20 * SKIN_S },
}
-- Combo announce (100/200/.../1000+) using the number+add composite: this skin
-- has no per-digit "announce_digit" strip, only announce_number (hundreds 1-9)
-- and announce_add (thousands digit + "+" marker).
-- Ported from src/objects/game/combo_announce.cpp.

ComboAnnounce = {}
ComboAnnounce.__index = ComboAnnounce

function ComboAnnounce.new(combo, player_num)
    local self = setmetatable({}, ComboAnnounce)
    local suffix = player_num .. "p"
    self.t_bg     = tex.get_texture("game/combo/announce_bg_" .. suffix)
    self.t_text   = tex.get_texture("game/combo/announce_text")
    self.t_number = tex.get_texture("game/combo/announce_number")
    self.t_add    = tex.get_texture("game/combo/announce_add")
    self.combo    = combo
    return self
end

function ComboAnnounce:draw(y, fade_value)
    if not self.t_bg then return end
    tex.draw_texture(self.t_bg, { y = y, fade = fade_value })

    local combo = self.combo
    if combo >= 1000 then
        local thousands = math.floor(combo / 1000)
        local remaining_hundreds = math.floor((combo % 1000) / 100)
        local thousands_offset = SKIN.combo_announce_thousands_offset.x
        local hundreds_offset  = SKIN.combo_announce_hundreds_offset.x

        if combo % 1000 == 0 then
            if self.t_number then
                tex.draw_texture(self.t_number, {
                    frame = thousands - 1,
                    x = SKIN.combo_announce_number_thousands_x.x,
                    y = y, fade = fade_value,
                })
            end
            if self.t_add then
                tex.draw_texture(self.t_add, { frame = 0, x = SKIN.combo_announce_add_x.x, y = y, fade = fade_value })
            end
        else
            if thousands <= 5 and self.t_add then
                tex.draw_texture(self.t_add, {
                    frame = thousands,
                    x = SKIN.combo_announce_thousands_add_x.x + thousands_offset,
                    y = y, fade = fade_value,
                })
            end
            if remaining_hundreds > 0 and self.t_number then
                tex.draw_texture(self.t_number, { frame = remaining_hundreds - 1, x = hundreds_offset, y = y, fade = fade_value })
            end
        end

        if self.t_text then
            local text_offset = SKIN.combo_announce_text_offset.x
            tex.draw_texture(self.t_text, { x = -text_offset / 2, y = y, fade = fade_value })
        end
    elseif combo >= 100 then
        if self.t_number then
            tex.draw_texture(self.t_number, { frame = math.floor(combo / 100) - 1, x = 0, y = y, fade = fade_value })
        end
        if self.t_text then
            tex.draw_texture(self.t_text, { x = 0, y = y, fade = fade_value })
        end
    end
end

return ComboAnnounce
