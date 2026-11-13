local BaseChibi = require("background/bg_objects/chibi/base")

ChibiBad = setmetatable({}, { __index = BaseChibi })
ChibiBad.__index = ChibiBad

function ChibiBad.new(index, bpm, is_2p, path)
    path = path or "background"
    bpm = bpm or 120

    local self = setmetatable({}, ChibiBad)

    self.name = "chibi_bad"
    self.bpm = bpm
    self.is_2p = is_2p or false
    self.index = index
    self.path = path

    local screen_width = tex.get_screen_width()
    local screen_scale = tex.get_screen_scale()

    self.game_2p_offset_y = 804

    self.texture_index = math.random(0, 2)
    self.keyframes = { 3, 4 }

    local duration = (60000 / self.bpm) / 2

    self.hori_move = anim.move(duration * 10, {
        total_distance = screen_width,
        loop = false
    })
    self.hori_move:start()

    self.vert_move = anim.move(duration, {
        total_distance = 50 * screen_scale,
        reverse_delay = 0,
        loop = true
    })
    self.vert_move:start()

    self.fade_in = anim.fade(duration, {
        initial_opacity = 0.0,
        final_opacity = 1.0,
        loop = false
    })
    self.fade_in:start()

    local s_keyframes = { 0, 1, 2 }
    local s_textures = {}
    for i, frame_idx in ipairs(s_keyframes) do
        local start_time = (duration / #s_keyframes) * (i - 1)
        local end_time = (duration / #s_keyframes) * i
        table.insert(s_textures, { start_time, end_time, frame_idx })
    end
    self.s_texture_change = anim.texture_change(duration, s_textures, { loop = false })
    self.s_texture_change:start()

    duration = duration * 2
    local textures = {}
    for i, frame_idx in ipairs(self.keyframes) do
        local start_time = (duration / #self.keyframes) * (i - 1)
        local end_time = (duration / #self.keyframes) * i
        table.insert(textures, { start_time, end_time, frame_idx })
    end
    self.texture_change = anim.texture_change(duration, textures, { loop = true })
    self.texture_change:start()

    self._id_0 = tex.get_texture(self.path .. "/" .. self.name .. "/0") or 0

    return self
end

function ChibiBad:update(current_time_ms, bpm)
    self.hori_move:update(current_time_ms)
    self.vert_move:update(current_time_ms)
    self.fade_in:update(current_time_ms)
    self.s_texture_change:update(current_time_ms)
    self.texture_change:update(current_time_ms)

    -- Handle BPM changes
    if bpm and bpm ~= self.bpm then
        self.bpm = bpm
        local duration = (60000 / self.bpm) / 2

        local s_keyframes = { 0, 1, 2 }
        local s_textures = {}
        for i, frame_idx in ipairs(s_keyframes) do
            local start_time = (duration / #s_keyframes) * (i - 1)
            local end_time = (duration / #s_keyframes) * i
            table.insert(s_textures, { start_time, end_time, frame_idx })
        end
        self.s_texture_change = anim.texture_change(duration, s_textures, { loop = false })
        self.s_texture_change:start()

        duration = duration * 2
        local textures = {}
        for i, frame_idx in ipairs(self.keyframes) do
            local start_time = (duration / #self.keyframes) * (i - 1)
            local end_time = (duration / #self.keyframes) * i
            table.insert(textures, { start_time, end_time, frame_idx })
        end
        self.texture_change = anim.texture_change(duration, textures, { loop = true })
        self.texture_change:start()

        self.hori_move.duration = (60000 / self.bpm) / 2 * 10
        self.vert_move.duration = (60000 / self.bpm) / 2
    end
end

function ChibiBad:draw()
    local y_offset = self.is_2p and self.game_2p_offset_y or 0

    if not self.s_texture_change.is_finished then
        tex.draw_texture(self._id_0, {
            frame = self.s_texture_change.attribute,
            x = self.hori_move.attribute,
            y = self.vert_move.attribute + y_offset,
            fade = self.fade_in.attribute
        })
    else
        tex.draw_texture(self._id_0, {
            frame = self.texture_change.attribute,
            x = self.hori_move.attribute,
            y = self.vert_move.attribute + y_offset
        })
    end
end

return ChibiBad
