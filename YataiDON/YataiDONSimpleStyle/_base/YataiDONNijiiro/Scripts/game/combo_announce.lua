-- Combo announce (100/200/.../1000+) drawn from the per-digit announce_digit strip.

ComboAnnounce = {}
ComboAnnounce.__index = ComboAnnounce

local CELL         = 104.0
local GROUP_CX      = 204.0   -- combo_num's origin inside the scroll
local PITCH_WIDE    = 64.0
local PITCH_NARROW  = 54.0
local SX_NARROW     = 0.85
local NARROW_X0     = -70.0   -- leftmost cell, local to GROUP_CX
local TEXTMC_WIDE    = 392.0
local TEXTMC_NARROW  = 398.0
local TEXT_DX = -84.0
local TEXT_W  = 123.0

-- sx, pitch, first_cx (centre of the leftmost cell, scroll frame), textmc_x
local function layout(digits)
    if digits <= 3 then
        return 1.0, PITCH_WIDE, GROUP_CX - PITCH_WIDE * (digits - 1) * 0.5, TEXTMC_WIDE
    end
    if digits == 4 then
        return SX_NARROW, PITCH_NARROW, GROUP_CX + NARROW_X0, TEXTMC_NARROW
    end
    local k = 4.0 / digits
    local pitch = PITCH_NARROW * k
    return SX_NARROW * k, pitch, GROUP_CX + 92.0 - pitch * (digits - 1), TEXTMC_NARROW
end

function ComboAnnounce.new(combo, player_num)
    local self = setmetatable({}, ComboAnnounce)
    if tex.current_screen() == "AI_GAME" then return self end   -- YataiDON's AI battle: no plate, as the cabinet's
    local suffix = player_num .. "p"
    self.t_bg    = tex.get_texture("game/combo/announce_bg_" .. suffix)
    self.t_digit = tex.get_texture("game/combo/announce_digit_" .. suffix)
    self.t_text  = tex.get_texture("game/combo/announce_text")
    self.number  = tostring(combo)
    return self
end

function ComboAnnounce:draw(y, fade_value)
    if not self.t_bg then return end
    tex.draw_texture(self.t_bg, { y = y, fade = fade_value })

    if not self.t_digit then return end

    local n = #self.number
    local sx, pitch, first_cx, textmc_x = layout(n)
    local dw = CELL * sx

    for i = 1, n do
        local cx = first_cx + pitch * (i - 1)
        tex.draw_texture(self.t_digit, {
            frame = tonumber(self.number:sub(i, i)),
            x = cx - dw * 0.5,
            y = y,
            x2 = dw - CELL,   -- horizontal condense only; sy stays 1
            fade = fade_value,
        })
    end

    if self.t_text then
        tex.draw_texture(self.t_text, {
            x = textmc_x + sx * TEXT_DX,
            y = y,
            x2 = TEXT_W * (sx - 1.0),
            fade = fade_value,
        })
    end
end

return ComboAnnounce
