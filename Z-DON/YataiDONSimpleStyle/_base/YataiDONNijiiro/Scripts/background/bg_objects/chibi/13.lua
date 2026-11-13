local BaseChibi = require("background/bg_objects/chibi/base")

Chibi13 = setmetatable({}, { __index = BaseChibi })
Chibi13.__index = Chibi13

function Chibi13.new(index, bpm, is_2p, path)
    path = path or "background"
    bpm = bpm or 120

    local self = setmetatable({}, Chibi13)
    local base = BaseChibi.new(index, bpm, is_2p, path)
    for k, v in pairs(base) do
        self[k] = v
    end

    local duration = (60000 / self.bpm)
    self.scale = anim.fade(duration, {
        initial_opacity = 1.0,
        final_opacity = 0.75,
        delay = duration,
        reverse_delay = duration,
        loop = true
    })
    self.scale:start()

    self.frame = 0
    self._id_tail = tex.get_texture(self.path .. "/" .. self.name .. "/tail") or 0

    return self
end

function Chibi13:update(current_time_ms, bpm)
    BaseChibi.update(self, current_time_ms, bpm)
    local scale_attr = self.scale:update(current_time_ms)

    if bpm and bpm ~= self.bpm then
        local duration = (60000 / self.bpm)
        self.scale = anim.fade(duration, {
            initial_opacity = 1.0,
            final_opacity = 0.75,
            delay = duration,
            reverse_delay = duration,
            loop = true
        })
        self.scale:start()
        scale_attr = self.scale.attribute
    end

    if scale_attr == 0.75 then
        self.frame = 1
    else
        self.frame = 0
    end
end

function Chibi13:draw()
    local y_offset = self.is_2p and 804 or 0

    tex.draw_texture(self._id_tail, {
        frame = self.frame,
        x = self.hori_move.attribute,
        y = -self.vert_move.attribute + y_offset
    })

    -- texture_index is chosen randomly at init so the name is dynamic; use draw_texture
    if self.scale.attribute == 0.75 then
        tex.draw_texture(self.t_body, {
            frame = self.frame,
            x = self.hori_move.attribute,
            y = -self.vert_move.attribute + y_offset
        })
    else
        tex.draw_texture(self.t_body, {
            frame = self.frame,
            scale = self.scale.attribute,
            center = true,
            x = self.hori_move.attribute,
            y = -self.vert_move.attribute + y_offset
        })
    end
end

return Chibi13
