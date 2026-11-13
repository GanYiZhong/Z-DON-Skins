-- Generic 60 fps replay of an exported clip (data.frames / data.shapes tables).
local ClipPlayer = {}
ClipPlayer.__index = ClipPlayer

local FRAME_MS = 1000.0 / 60.0

-- module: "game/ending_anim/<name>";  path/subset: texture folder (e.g. "game", "<name>_anim")
function ClipPlayer.new(module, path, subset, x, y)
    local ok, data = pcall(require, module)
    if not ok or type(data) ~= "table" or not data.frames then return nil end
    local self = setmetatable({}, ClipPlayer)
    self.data, self.path, self.subset = data, path, subset
    tex.load_folder(path, subset)
    self.x, self.y = x or 0, y or 0
    self.ids = {}
    self.shape_map = nil
    self.t0 = nil
    self.hold_last = false     -- true: stay on the last frame instead of looping
    return self
end

function ClipPlayer:id_of(shape)
    local id = self.ids[shape]
    if id == nil then
        id = tex.get_texture(self.path .. "/" .. self.subset .. "/s" .. shape) or false
        self.ids[shape] = id
    end
    return id or nil
end

function ClipPlayer:start(now)   self.t0 = now end
function ClipPlayer:started()    return self.t0 ~= nil end

function ClipPlayer:frame(now)
    if not self.t0 then return 0 end
    local f = math.floor((now - self.t0) / FRAME_MS)
    local n, loop_at = self.data.nframes, self.data.loop_at
    if f >= n then
        if self.hold_last then return n - 1 end
        local span = n - loop_at
        f = (span > 0) and (loop_at + (f - loop_at) % span) or (n - 1)
    end
    return f
end

-- true once the clip has passed its last frame at least once
function ClipPlayer:finished(now)
    return self.t0 ~= nil and (now - self.t0) / FRAME_MS >= self.data.nframes
end

function ClipPlayer:draw(now, fade)
    if not self.t0 then return end
    fade = fade or 1.0
    local rows = self.data.frames[self:frame(now) + 1]
    if not rows then return end
    local shapes, map = self.data.shapes, self.shape_map
    for i = 1, #rows do
        local r = rows[i]
        local shape = r[1]
        if map and map[shape] then shape = map[shape] end
        local s  = shapes[shape]
        local id = s and self:id_of(shape)
        if id then
            local sx, sy = r[4], r[5]
            tex.draw_texture(id, {
                x        = self.x + r[2],
                y        = self.y + r[3],
                x2       = s[1] * (sx - 1),
                y2       = s[2] * (sy - 1),
                origin   = { s[3] * sx, s[4] * sy },
                rotation = r[6],
                fade     = r[7] * fade,
                blend    = (r[8] == 8) and "additive" or nil,   -- add-blended leaf
            })
        end
    end
end

function ClipPlayer:destroy()
    tex.unload_folder(self.path, self.subset)
end

return ClipPlayer
