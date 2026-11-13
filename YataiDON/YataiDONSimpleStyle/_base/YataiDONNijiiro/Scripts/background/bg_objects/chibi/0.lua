local BaseChibi = require("background/bg_objects/chibi/base")

local Chibi0 = setmetatable({}, { __index = BaseChibi })
Chibi0.__index = Chibi0

function Chibi0.new(index, bpm, is_2p, path)
    local self = setmetatable({}, Chibi0)
    local base = BaseChibi.new(index, bpm, is_2p, path)
    for k, v in pairs(base) do
        self[k] = v
    end
    return self
end

function Chibi0:draw()
    local y_offset = self.is_2p and 804 or 0

    tex.draw_texture(self.t_body, {
        frame = self.texture_change.attribute,
        x = self.hori_move.attribute,
        y = self.vert_move.attribute + y_offset
    })
end

return Chibi0
