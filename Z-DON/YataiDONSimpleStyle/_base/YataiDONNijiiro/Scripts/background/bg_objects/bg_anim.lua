-- Replays an exported cabinet backdrop movie (lower half of the screen).
-- Data: background/bg_data/bg_anim/<name>.lua; textures: bga_<name>/s<c>.png.
local BGAnim = {}
BGAnim.__index = BGAnim

local FRAME_MS = 1000.0 / 60.0
local STAGE_Y  = 540
local ONE = string.byte("1")

function BGAnim.available(name)
    local ok, data = pcall(require, "background/bg_data/bg_anim/" .. name)
    return ok and type(data) == "table" and data.normal ~= nil
end

function BGAnim.new(name, path)
    local ok, data = pcall(require, "background/bg_data/bg_anim/" .. name)
    if not ok or type(data) ~= "table" or not data.normal then return nil end
    local self = setmetatable({}, BGAnim)
    self.name = name
    self.subset = "bga_" .. name
    self.path = path or "background"
    tex.load_folder(self.path, self.subset)
    self.data = data
    self.ids = {}
    self.elapsed = 0
    self.last_ms = nil
    return self
end

function BGAnim:id_of(shape)
    local id = self.ids[shape]
    if id == nil then
        id = tex.get_texture(self.path .. "/" .. self.subset .. "/s" .. shape) or false
        self.ids[shape] = id
    end
    return id or nil
end

-- beat_frames: replay on the song's beat instead of the wall clock, one beat per
-- beat_frames movie frames (the collab dancer movies are authored at 40 frames a beat)
function BGAnim:set_beat(beat_frames)
    self.beat_frames = beat_frames
end

function BGAnim:update(current_ms, bpm)
    if self.last_ms then
        local dt = current_ms - self.last_ms
        if dt > 0 and dt < 500 then
            if self.beat_frames and bpm and bpm > 0 then
                dt = dt * FRAME_MS / ((60000 / bpm) / self.beat_frames)
            end
            self.elapsed = self.elapsed + dt
        end
    end
    self.last_ms = current_ms
end

local ch = require("background/bg_objects/packed_channel")   -- number, per-frame table or packed string

function BGAnim:draw(fade)
    fade = fade or 1.0
    if fade <= 0.002 then return end
    local frame = math.floor(self.elapsed / FRAME_MS)
    local list = self.data.normal
    local shapes = self.data.shapes
    for k = 1, #list do
        local e = list[k]
        local i = (frame % e.period) + 1
        local a = ch(e.a, i)
        if a > 0.002 and e.on then
            if e.on:byte((frame % e.on_period) + 1) ~= ONE then a = 0 end
        end
        if a > 0.002 then
            local s = shapes[e.shape]
            local id = s and self:id_of(e.shape)
            if id then
                local sx, sy = ch(e.sx, i), ch(e.sy, i)
                -- mir: a mirroring placement; the texture flips inside its rect, so the
                -- origin moves to the other side of the png
                local mir = e.mir and ch(e.mir, i) == 1
                -- cr/cg/cb: the placement's colour multiply (tinted spotlights and the like)
                local col = e.cr and { ch(e.cr, i) * 255, ch(e.cg, i) * 255, ch(e.cb, i) * 255, 255 } or nil
                tex.draw_texture(id, {
                    color    = col,
                    x        = ch(e.tx, i),
                    y        = STAGE_Y + ch(e.ty, i),
                    x2       = s[1] * (sx - 1),
                    y2       = s[2] * (sy - 1),
                    origin   = { (mir and (s[1] - s[3]) or s[3]) * sx, s[4] * sy },
                    rotation = ch(e.rot, i),
                    fade     = a * fade,
                    mirror   = mir and "horizontal" or nil,
                })
            end
        end
    end
end

function BGAnim:destroy()
    tex.unload_folder(self.path, self.subset)
end

return BGAnim
