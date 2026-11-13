-- Ending banner (clear / full combo / donderful / fail), replayed from exported
-- cabinet movie data: game/ending_anim/ending_<kind>.lua frames + one texture per shape.
local Ending = {}
Ending.__index = Ending

local FRAME_MS = 1000.0 / 60.0
local STAGE_Y  = 276
-- the movie root places every ending clip at (1209, 109.5) on its 1920x264 stage;
-- the exported frames are clip-local, so add that placement
local CLIP_X, CLIP_Y = 1209, 109.5
local CLIPS = { donderful = "ending_donderful", full_combo = "ending_fullcombo",
                clear = "ending_clear", fail = "ending_fail" }

function Ending.available(kind)
    local name = CLIPS[kind]
    if not name then return false end
    local ok, data = pcall(require, "game/ending_anim/" .. name)
    return ok and type(data) == "table" and data.frames ~= nil
end

function Ending.new(kind, player_num, path)
    local name = CLIPS[kind]
    local ok, data = pcall(require, "game/ending_anim/" .. name)
    if not ok or type(data) ~= "table" or not data.frames then return nil end
    local self = setmetatable({}, Ending)
    self.kind   = kind
    self.subset = name .. "_anim"
    self.path   = path or "game"
    tex.load_folder(self.path, self.subset)
    self.data   = data
    self.ids    = {}
    self.t0     = nil
    self.y      = STAGE_Y
    if player_num == 2 then
        -- the 2P lane sits at game_p2_y, the 1P lane at 184 (both x screen scale)
        local p2 = tex.get_skin_config("game_p2_y")
        local lane1 = 184 * tex.get_screen_scale()
        self.y = STAGE_Y + ((p2 and p2.y) and (p2.y - lane1) or 0)
    end
    return self
end

function Ending:id_of(shape)
    local id = self.ids[shape]
    if id == nil then
        id = tex.get_texture(self.path .. "/" .. self.subset .. "/s" .. shape) or false
        self.ids[shape] = id
    end
    return id or nil
end

function Ending:frame(current_ms)
    if not self.t0 then self.t0 = current_ms end
    local f = math.floor((current_ms - self.t0) / FRAME_MS)
    local n, loop_at = self.data.nframes, self.data.loop_at
    if f >= n then
        local span = n - loop_at
        f = (span > 0) and (loop_at + (f - loop_at) % span) or (n - 1)
    end
    return f
end

function Ending:draw(current_ms)
    local rows = self.data.frames[self:frame(current_ms) + 1]
    if not rows then return end
    local shapes = self.data.shapes
    for i = 1, #rows do
        local r = rows[i]
        local s  = shapes[r[1]]
        local id = s and self:id_of(r[1])
        if id then
            local sx, sy = r[4], r[5]
            tex.draw_texture(id, {
                x        = CLIP_X + r[2],
                y        = self.y + CLIP_Y + r[3],
                x2       = s[1] * (sx - 1),
                y2       = s[2] * (sy - 1),
                origin   = { s[3] * sx, s[4] * sy },
                rotation = r[6],
                fade     = r[7],
                blend    = (r[8] == 8) and "additive" or nil,   -- cabinet add-blended leaf
            })
        end
    end
end

function Ending:destroy()
    tex.unload_folder(self.path, self.subset)
end

return Ending
