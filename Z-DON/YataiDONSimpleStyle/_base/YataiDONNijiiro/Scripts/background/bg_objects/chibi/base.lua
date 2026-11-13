BaseChibi = {}
BaseChibi.__index = BaseChibi

function BaseChibi.new(index, bpm, is_2p, path)
    path = path or "background"
    bpm = bpm or 120

    local self = setmetatable({}, BaseChibi)

    self.name = "chibi_" .. index
    self.bpm = bpm
    self.is_2p = is_2p or false
    self.index = index
    self.path = path

    local screen_width = tex.get_screen_width()
    local screen_scale = tex.get_screen_scale()

    self.hori_move = anim.move(60000 / self.bpm * 5, {
        total_distance = screen_width,
        loop = false
    })
    self.hori_move:start()

    self.vert_move = anim.move(60000 / self.bpm / 2, {
        total_distance = 50 * screen_scale,
        reverse_delay = 0,
        loop = true
    })
    self.vert_move:start()

    self.game_2p_offset_y = 804

    local texture_keys = tex.get_texture_keys(self.name)
    local digit_keys = {}
    for _, key in ipairs(texture_keys) do
        if tonumber(key) then
            table.insert(digit_keys, tonumber(key))
        end
    end
    self.texture_index = digit_keys[math.random(1, #digit_keys)]

    local tex_info = tex.get_texture_info(self.name, tostring(self.texture_index))
    self.body_info = tex_info
    self.t_body = tex.get_texture(self.path .. "/" .. self.name .. "/" .. tostring(self.texture_index))
    local keyframe_count = (tex_info and tex_info.frame_count) or 1

    self.keyframes = {}
    for i = 1, keyframe_count do
        table.insert(self.keyframes, i - 1)
    end

    local duration = (60000 / self.bpm) / 2
    local textures = {}
    for i, frame_idx in ipairs(self.keyframes) do
        local start_time = (duration / #self.keyframes) * (i - 1)
        local end_time = (duration / #self.keyframes) * i
        table.insert(textures, { start_time, end_time, frame_idx })
    end
    self.texture_change = anim.texture_change(duration, textures, {loop = true})
    self.texture_change:start()

    return self
end

function BaseChibi:update(current_time_ms, bpm)
    self.hori_move:update(current_time_ms)
    self.vert_move:update(current_time_ms)
    self.texture_change:update(current_time_ms)

    if bpm and bpm ~= self.bpm then
        self.bpm = bpm
        local duration = (60000 / self.bpm) / 2

        local textures = {}
        for i, frame_idx in ipairs(self.keyframes) do
            local start_time = (duration / #self.keyframes) * (i - 1)
            local end_time = (duration / #self.keyframes) * i
            table.insert(textures, {start_time, end_time, frame_idx})
        end
        self.texture_change = anim.texture_change(duration, textures, {loop = true})
        self.texture_change:start()

        self.hori_move.duration = 60000 / self.bpm * 5
        self.vert_move.duration = 60000 / self.bpm / 2
    end
end

function BaseChibi:draw()
    local y_offset = self.is_2p and self.game_2p_offset_y or 0

    tex.draw_texture(self.t_body, {
        frame = self.texture_change.attribute,
        x = self.hori_move.attribute,
        y = -self.vert_move.attribute + y_offset
    })
end

return BaseChibi
