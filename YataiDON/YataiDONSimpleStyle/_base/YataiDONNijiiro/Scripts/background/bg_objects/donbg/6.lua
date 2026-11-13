-- YataiDON-HSS override of PyTaikoGreen/background/bg_objects/donbg/6.lua:
-- adds the cabinet's three sakura-petal drifters (between the two scrolling layers).
local DonBGBase = require("background/bg_objects/donbg/base")

local DonBG6 = setmetatable({}, { __index = DonBGBase })
DonBG6.__index = DonBG6

local PETAL_W, PETAL_H   = 391, 208
local PETAL_REG_X        = -195
local PETAL_REG_Y        = -104
local PETAL_LOOP_FRAMES  = 160
local PETAL_X0, PETAL_Y0 = 2308.0, -106.0
local PETAL_DX           = -4.830189
local PETAL_DY           = 3.069182
local PETAL_GAP          = 980.0
local PETAL_COPIES       = 3
local BAND_H             = 276

function DonBG6.new(index, player_num, path)
    local self = setmetatable({}, DonBG6)
    local base = DonBGBase.new(index, player_num, path)
    for k, v in pairs(base) do self[k] = v end
    self._id_petal = tex.get_texture(self.path .. "/" .. self.name .. "/overlay_2")
    -- fail soft: only the DEFAULT pack ("5_x", path "background") owns this rig
    self._petals_on = self.use_layers and (self._id_petal ~= nil)
    return self
end

-- One petal cluster, cropped to the band [y, y + 276).
function DonBG6:_draw_petal(frame, fade, y, cx, top)
    local band_top, band_bottom = y, y + BAND_H
    if top >= band_bottom or top + PETAL_H <= band_top then return end
    local sy = 0
    if top < band_top then sy = band_top - top end
    local h = PETAL_H - sy
    if top + sy + h > band_bottom then h = band_bottom - (top + sy) end
    if h <= 0 then return end
    tex.draw_texture(self._id_petal, {
        frame = frame, fade = fade,
        x = cx + PETAL_REG_X,
        y = top + sy,
        src = { x = 0, y = sy, width = PETAL_W, height = h },
        y2 = h - PETAL_H,
    })
end

function DonBG6:_draw_petals(frame, fade, y)
    if not self._petals_on then return end
    local f = (self.elapsed / (1000.0 / 60.0)) % PETAL_LOOP_FRAMES
    local cx = PETAL_X0 + PETAL_DX * f
    local top = (PETAL_Y0 + PETAL_DY * f) + PETAL_REG_Y + y
    for i = 0, PETAL_COPIES - 1 do
        self:_draw_petal(frame, fade, y, cx - i * PETAL_GAP, top)
    end
end

-- Same shape as DonBGBase:draw(), with the drifters slotted in at their real
-- display-list depth: after the depth-0 backdrop, before the depth-4 motif row.
function DonBG6:draw_band(y)
    y = y or 0
    if not self.use_layers then return DonBGBase.draw_band(self, y) end

    local normal = self.states.normal or {}
    local fever  = self.states.fever
    local back, front = {}, {}
    for i, l in ipairs(normal) do
        table.insert(i == 1 and back or front, l)
    end
    self:draw_layers(back, 1.0, y)
    self:_draw_petals(0, 1.0, y)
    self:draw_layers(front, 1.0, y)

    local fade = nil
    if self.is_clear then
        fade = self.clear_fade.attribute
    elseif self.exit_fade then
        fade = self.exit_fade.attribute
    end
    if fade and fever then
        local fback, ffront = {}, {}
        for i, l in ipairs(fever) do
            table.insert(i == 1 and fback or ffront, l)
        end
        self:draw_layers(fback, fade, y)
        self:_draw_petals(1, fade, y)
        self:draw_layers(ffront, fade, y)
    end
end

function DonBG6:draw(y)
    self:draw_dark(DonBG6.draw_band, y or 0)
end

return DonBG6
