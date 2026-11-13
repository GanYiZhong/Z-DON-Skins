-- YataiDON-HSS override of PyTaikoGreen/background/bg_objects/chibi/2.lua: rotation origin from x2[1]/y2[1]
local BaseChibi = require("background/bg_objects/chibi/base")

local Chibi2 = setmetatable({}, { __index = BaseChibi })
Chibi2.__index = Chibi2

function Chibi2.new(index, bpm, is_2p, path)
    path = path or "background"
    bpm = bpm or 120

    local self = setmetatable({}, Chibi2)
    local base = BaseChibi.new(index, bpm, is_2p, path)
    for k, v in pairs(base) do
        self[k] = v
    end

    local screen_height = tex.get_screen_height()
    self.rotate = anim.move(60000 / self.bpm, {
        total_distance = screen_height / 2,
        loop = false
    })
    self.rotate:start()

    return self
end

function Chibi2:update(current_time_ms, bpm)
    -- retime the rotation against the pre-update bpm
    local prev_bpm = self.bpm
    BaseChibi.update(self, current_time_ms, bpm)
    self.rotate:update(current_time_ms)

    if self.rotate.is_finished then
        self.rotate:restart()
    end

    if bpm and bpm ~= prev_bpm then
        self.rotate.duration = 60000 / bpm
    end
end

function Chibi2:draw()
    local y_offset = self.is_2p and 804 or 0

    local tex_info = self.body_info
    if not tex_info then return end
    local origin_x = tex_info.x2[1] / 2
    local origin_y = tex_info.y2[1] / 2

    tex.draw_texture(self.t_body, {
        frame = self.texture_change.attribute,
        x = self.hori_move.attribute + origin_x,
        y = origin_y + y_offset,
        origin = { origin_x, origin_y },
        rotation = self.rotate.attribute
    })
end

return Chibi2
