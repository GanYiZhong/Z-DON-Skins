-- 魂-max crowd, replayed from the cabinet's own movie data (f_<n>.lua frames).
local FeverAnim = {}
FeverAnim.__index = FeverAnim

-- The original re-times this movie to the song: the 40-frame bob is one beat.
local BEAT_FRAMES = 40
local function frame_ms(bpm)
    if not bpm or bpm <= 0 then return 1000.0 / 60.0 end
    return (60000.0 / bpm) / BEAT_FRAMES
end
local STAGE_Y  = 540   -- the 1920x540 crowd stage covers the lower half of the screen

function FeverAnim.available(index)
    local ok, data = pcall(require, "background/bg_data/fever_anim/f_" .. index)
    return ok and type(data) == "table"
end

function FeverAnim.new(index, bpm, path)
    local ok, data = pcall(require, "background/bg_data/fever_anim/f_" .. index)
    if not ok or type(data) ~= "table" then return nil end
    local self = setmetatable({}, FeverAnim)
    self.name = "fevera_" .. index
    self.path = path or "background"
    tex.load_folder(self.path, self.name)
    self.data    = data
    self.enter_f = data.labels.normal_fever or 0
    self.loop_f  = data.labels.fever or self.enter_f
    self.exit_f  = data.labels.fever_normal or data.nframes
    self.ids     = {}
    self.state   = "wait"
    self.cursor  = 0
    self.last_ms = nil
    return self
end

function FeverAnim:id_of(shape)
    local id = self.ids[shape]
    if id == nil then
        id = tex.get_texture(self.path .. "/" .. self.name .. "/s" .. shape) or false
        self.ids[shape] = id
    end
    return id or nil
end

-- rising edge: GotoAndPlay("normal_fever") -- also restarts a crowd that was leaving
function FeverAnim:start()
    if self.state == "enter" or self.state == "loop" then return end
    self.state  = "enter"
    self.cursor = self.enter_f
end

-- falling edge: GotoAndPlay("fever_normal")
function FeverAnim:stop()
    if self.state == "wait" or self.state == "exit" then return end
    self.state  = "exit"
    self.cursor = self.exit_f
end

function FeverAnim:is_visible()
    return self.state ~= "wait"
end

function FeverAnim:alpha()
    return self.state ~= "wait" and 1.0 or 0.0
end

function FeverAnim:update(current_ms, bpm)
    local last = self.last_ms
    self.last_ms = current_ms
    if self.state == "wait" or not last then return end
    local dt = current_ms - last
    if dt <= 0 then return end
    if dt > 500 then dt = 500 end
    self.cursor = self.cursor + dt / frame_ms(bpm)
    if self.state == "enter" and self.cursor >= self.loop_f then
        self.state = "loop"
    end
    if self.state == "loop" then
        local span = self.exit_f - self.loop_f
        if span > 0 then
            self.cursor = self.loop_f + (self.cursor - self.loop_f) % span
        else
            self.cursor = self.loop_f
        end
    elseif self.state == "exit" and self.cursor >= self.data.nframes then
        self.state = "wait"
    end
end

function FeverAnim:draw()
    if self.state == "wait" then return end
    local f = math.floor(self.cursor)
    if f < 0 then f = 0 elseif f >= self.data.nframes then f = self.data.nframes - 1 end
    local rows = self.data.frames[f + 1]
    if not rows then return end
    local shapes = self.data.shapes
    for i = 1, #rows do
        local r = rows[i]
        local a = r[7]
        if a > 0.002 then
            local s  = shapes[r[1]]
            local id = s and self:id_of(r[1])
            if id then
                local sx, sy = r[4], r[5]
                tex.draw_texture(id, {
                    x        = r[2],
                    y        = r[3] + STAGE_Y,
                    x2       = s[1] * (sx - 1),
                    y2       = s[2] * (sy - 1),
                    origin   = { s[3] * sx, s[4] * sy },
                    rotation = r[6],
                    fade     = a,
                })
            end
        end
    end
end

function FeverAnim:destroy()
    tex.unload_folder(self.path, self.name)
end

return FeverAnim
