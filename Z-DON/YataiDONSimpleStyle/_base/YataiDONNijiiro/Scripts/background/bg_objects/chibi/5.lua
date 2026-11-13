local BaseChibi = require("background/bg_objects/chibi/base")

local Chibi5 = setmetatable({}, { __index = BaseChibi })
Chibi5.__index = Chibi5

function Chibi5.new(index, bpm, is_2p, path)
    path = path or "background"
    local self = setmetatable({}, Chibi5)
    local base = BaseChibi.new(index, bpm, is_2p, path)
    for k, v in pairs(base) do
        self[k] = v
    end
    return self
end

function Chibi5:draw()
    local y_offset = self.is_2p and 804 or 0

    tex.draw_texture(self.t_body, {
        frame = self.texture_change.attribute,
        x = self.hori_move.attribute,
        y = y_offset
    })
end

return Chibi5
