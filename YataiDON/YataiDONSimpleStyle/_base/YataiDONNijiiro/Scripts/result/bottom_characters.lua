BottomCharacters = {}
BottomCharacters.__index = BottomCharacters

function BottomCharacters.new()
    local self = setmetatable({}, BottomCharacters)

    self.move_up       = tex.get_animation(7,  "result")
    self.move_down     = tex.get_animation(8,  "result")
    self.bounce_up     = tex.get_animation(9,  "result")
    self.bounce_down   = tex.get_animation(10, "result")
    self.move_center   = tex.get_animation(11, "result")
    self.c_bounce_up   = tex.get_animation(12, "result")
    self.c_bounce_down = tex.get_animation(13, "result")
    self.flower_up     = tex.get_animation(14, "result")

    self.t_chara_0      = tex.get_texture("result/bottom/chara_0")
    self.t_chara_1      = tex.get_texture("result/bottom/chara_1")
    self.t_chara_center = tex.get_texture("result/bottom/chara_center")
    self.t_flowers      = tex.get_texture("result/bottom/flowers")

    self.sc_flowers_offset = 1188

    self.flower_index = 0
    self.flower_start = nil
    self.chara_index  = 0
    self.state        = nil

    return self
end

function BottomCharacters:start()
    self.move_up:start()
    self.move_down:start()
    self.c_bounce_up:start()
    self.c_bounce_down:start()
end

function BottomCharacters:update(current_ms, state)
    self.state = state
    if state >= 1 then  -- CLEAR or RAINBOW
        self.chara_index = 1
        if not self.bounce_up.is_started then
            self.bounce_up:start()
            self.bounce_down:start()
            self.move_center:start()
        end
        if not self.flower_start then
            self.flower_up:start()
            self.flower_start = current_ms
        end
    else
        self.chara_index = 2  -- FAIL
    end

    self.move_up:update(current_ms)
    self.move_down:update(current_ms)
    self.bounce_up:update(current_ms)
    self.bounce_down:update(current_ms)
    if self.bounce_down.is_finished then
        self.bounce_up:restart()
        self.bounce_down:restart()
    end
    self.move_center:update(current_ms)
    self.flower_up:update(current_ms)

    if self.flower_start then
        if current_ms > self.flower_start + 116 * 2 + 333 then
            self.flower_index = 2
        elseif current_ms > self.flower_start + 116 + 333 then
            self.flower_index = 1
        end
    end

    self.c_bounce_up:update(current_ms)
    self.c_bounce_down:update(current_ms)
    if self.c_bounce_down.is_finished then
        self.c_bounce_up:restart()
        self.c_bounce_down:restart()
    end
end

function BottomCharacters:is_finished()
    return self.move_down.is_finished
end

function BottomCharacters:draw()
    local flower_y = -self.flower_up.attribute
    if self.t_flowers then
        tex.draw_texture(self.t_flowers,
            { frame = self.flower_index, y = flower_y })
        tex.draw_texture(self.t_flowers,
            { frame = self.flower_index, mirror = "horizontal",
              x = self.sc_flowers_offset, y = flower_y })
    end

    local y = -self.move_up.attribute  + self.move_down.attribute
            +  self.bounce_up.attribute - self.bounce_down.attribute
    if self.state == 2 then  -- RAINBOW
        local center_y = self.c_bounce_up.attribute - self.c_bounce_down.attribute
        if self.t_chara_center then
            tex.draw_texture(self.t_chara_center,
                { y = -self.move_center.attribute + center_y })
        end
    end
    if self.t_chara_0 then tex.draw_texture(self.t_chara_0, { frame = self.chara_index, y = y }) end
    if self.t_chara_1 then tex.draw_texture(self.t_chara_1, { frame = self.chara_index, y = y }) end
end
