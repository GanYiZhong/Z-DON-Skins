local BaseChibi = require("background/bg_objects/chibi/base")

local Chibi8 = setmetatable({}, { __index = BaseChibi })
Chibi8.__index = Chibi8

function Chibi8.new(index, bpm, is_2p, path)
    path = path or "background"
    local self = setmetatable({}, Chibi8)
    local base = BaseChibi.new(index, bpm, is_2p, path)
    for k, v in pairs(base) do
        self[k] = v
    end
    return self
end

function Chibi8:draw()
    local y_offset = self.is_2p and 804 or 0

    tex.draw_texture(self.t_body, {
        frame = self.texture_change.attribute,
        x = self.hori_move.attribute,
        y = y_offset
    })
end

return Chibi8
