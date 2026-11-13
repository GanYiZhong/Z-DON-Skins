-- BaseChibi: a good-hit chibi. It hops in from behind the lane growing from
-- 70% size, lands on its run line and runs 1170px across the don band over 4.5 beats, cycling
-- through a loop of poses. Timed in beats. Texture.json puts each image at the point where chibis
-- appear, before it moves, so every position here is an offset from there.
--
-- spec (a motion, see chibi/sets.lua) plus the character:
--   key, first:  texture key and the character's first frame in it (default 0)
--   hop:         { from = { x, y }, peak = { x, y }, up = beats to the peak }
--   hop_frames:  frame_change steps while hopping (default frame 0)
--   run:         { x = where it lands (default -270), y = run line, drift = px down over the run,
--                  distance = px run (default 1170) }
--   period:      length of the pose loop in beats
--   poses:       { beat, frame, x, y, to = { x, y, ease }, sy = h | { from, to }, mirror = true }
--   start_size:  size it hops in at (default 0.7; 1 for sets that don't grow)
--   fade_in:     fades in over the hop
--                a pose holds its offset until the next one, or glides `to` it; sy squashes
local Timing = require("background/bg_objects/timing")
local chain_moves, frame_change, sum, Loop = Timing.chain_moves_lua, Timing.frame_change_lua, Timing.sum, Timing.Loop

local LIFE = 5 -- beats on screen
local HOP_BEATS = 0.5
local RUN_X, RUN_BEATS, RUN_DISTANCE = -270, 4.5, 1170
local START_SIZE = 0.7

local BaseChibi = {}
BaseChibi.__index = BaseChibi
BaseChibi.HOP = { from = { -418, 21 }, peak = { -324, -37 }, up = 0.325 }

-- Turns a pose table into frame, mirror, x, y and squash tracks for one loop
local function pose_tracks(poses, period, beat, scale, first)
    local frames, mirror, x, y, sy = {}, {}, {}, {}, {}
    local cx, cy, cs = 0, 0, 1000
    for i, p in ipairs(poses) do
        local beat_at, frame, px, py = p[1], p[2], p[3] or 0, p[4] or 0
        local length = (poses[i + 1] and poses[i + 1][1] or period) - beat_at
        table.insert(frames, { frame + first, length })
        table.insert(mirror, { p.mirror and 1 or 0, length })
        table.insert(x, { 0, px - cx })
        table.insert(y, { 0, py - cy })
        cx, cy = px, py
        if p.to then
            table.insert(x, { length, p.to[1] - cx, p.to[3] })
            table.insert(y, { length, p.to[2] - cy, p.to[3] })
            cx, cy = p.to[1], p.to[2]
        else
            table.insert(x, { length, 0 })
            table.insert(y, { length, 0 })
        end
        local s0, s1 = 1, 1
        if type(p.sy) == "number" then s0, s1 = p.sy, p.sy elseif p.sy then s0, s1 = p.sy[1], p.sy[2] end
        table.insert(sy, { 0, s0 * 1000 - cs })
        table.insert(sy, { length, (s1 - s0) * 1000 })
        cs = s1 * 1000
    end
    return {
        frame  = frame_change(frames, beat),
        mirror = frame_change(mirror, beat),
        x      = chain_moves(x, beat, scale),
        y      = chain_moves(y, beat, scale),
        sy     = chain_moves(sy, beat, 1),
    }
end

function BaseChibi.new(spec, path, folder, bpm, is_2p)
    local self = setmetatable({}, BaseChibi)
    self:init(spec, path, folder, bpm, is_2p)
    return self
end

function BaseChibi:init(spec, path, folder, bpm, is_2p)
    self.spec   = spec
    self.path   = path
    self.folder = folder
    self.key    = spec.key
    self.first  = spec.first or 0
    self.beat   = 60000 / bpm
    self.scale  = tex.get_screen_scale()
    self.y2p    = is_2p and 536 * tex.get_screen_scale() or 0
    self.run_x  = spec.run and spec.run.x or RUN_X
    self.run_y  = spec.run and spec.run.y or 1
    self._id    = tex.get_texture(path .. "/" .. folder .. "/" .. self.key) or 0
    self.info   = tex.get_texture_info(folder, self.key)
    self.ids    = {}
    self.has_poses = spec.poses ~= nil -- spec reads can go through an __index function
end

-- Builds the timeline on the first update, so it starts in step with the controller's clock
function BaseChibi:start()
    local spec, beat, scale = self.spec, self.beat, self.scale
    local hop = spec.hop or BaseChibi.HOP
    local from, peak, up = hop.from, hop.peak, hop.up
    local down = HOP_BEATS - up
    -- glides across, slows to the peak and drops onto the run line, growing steadily
    self.hop_x  = chain_moves({ { up, peak[1] - from[1] }, { down, self.run_x - peak[1] } }, beat, scale)
    self.hop_y  = chain_moves({ { up, peak[2] - from[2], "out" }, { down, self.run_y - peak[2], "in" } }, beat, scale)
    self.grow   = chain_moves({ { HOP_BEATS - 0.025, (1 - (spec.start_size or START_SIZE)) * 1000 } }, beat, 1)
    self.hop_frames = frame_change(spec.hop_frames or { { 0, HOP_BEATS } }, beat)
    self.hop_frames:start()
    self.run    = chain_moves({ { HOP_BEATS, 0 }, { RUN_BEATS, spec.run and spec.run.distance or RUN_DISTANCE } }, beat, scale)
    self.drift  = chain_moves({ { HOP_BEATS, 0 }, { RUN_BEATS, spec.run and spec.run.drift or 0 } }, beat, scale)
end

local function update_all(list, ms)
    for _, m in ipairs(list) do m:update(ms) end
end

function BaseChibi:update(current_time_ms)
    if not self.t0 then
        self.t0 = current_time_ms
        self:start()
    end
    local t = (current_time_ms - self.t0) / self.beat
    self.t       = t
    self.done    = t >= LIFE
    self.hopping = t < HOP_BEATS
    if self.hopping then -- place() only reads the hop anims until it lands
        update_all(self.hop_x, current_time_ms)
        update_all(self.hop_y, current_time_ms)
        update_all(self.grow, current_time_ms)
        self.hop_frames:update(current_time_ms)
    end
    update_all(self.run, current_time_ms)
    update_all(self.drift, current_time_ms)
    if not self.hopping and self.has_poses then
        local spec, beat, scale, first = self.spec, self.beat, self.scale, self.first
        self.poses = self.poses or Loop.new(spec.period * beat, function()
            local p = pose_tracks(spec.poses, spec.period, beat, scale, first)
            p.frame:start()
            p.mirror:start()
            return p
        end)
        self.poses:update(current_time_ms)
    end
    self:update_extra(current_time_ms)
end

function BaseChibi:update_extra(current_time_ms) end

-- Where the chibi is (offset from its texture.json position), its frame and size
function BaseChibi:place()
    -- one table per chibi, every field rewritten: place() runs each frame
    local at = self._at
    if not at then at = {}; self._at = at end
    at.mirror, at.rot, at.fade = nil, nil, nil
    if self.hopping then
        local size = (self.spec.start_size or START_SIZE) + sum(self.grow) / 1000
        local hop = self.spec.hop or BaseChibi.HOP
        at.x, at.y = hop.from[1] + sum(self.hop_x) / self.scale, hop.from[2] + sum(self.hop_y) / self.scale
        at.frame, at.sx, at.sy = self.first + self.hop_frames.attribute, size, size
        at.fade = self.spec.fade_in and self.t / HOP_BEATS or nil
        return at
    end
    at.x, at.y = self.run_x + sum(self.run) / self.scale, self.run_y + sum(self.drift) / self.scale
    at.frame, at.sx, at.sy = self.first, 1, 1
    local p = self.poses and self.poses.anims
    if p then
        at.x, at.y = at.x + sum(p.x) / self.scale, at.y + sum(p.y) / self.scale
        at.frame  = p.frame.attribute
        at.sy     = sum(p.sy) / 1000 + 1
        at.mirror = p.mirror.attribute == 1
    end
    return at
end

-- Draws texture `key` (default the character's) with its centre moved by x, y (unscaled px),
-- sized sx, sy about the centre and turned `rot` degrees about it
-- draw_texture reads these straight away, so every chibi shares one pair
local PARAMS, ORIGIN = {}, { 0, 0 }

function BaseChibi:draw_image(at, key)
    local id, info = self._id, self.info
    if key then
        id = self.ids[key] or tex.get_texture(self.path .. "/" .. self.folder .. "/" .. key) or 0
        self.ids[key] = id
        info = tex.get_texture_info(self.folder, key)
    end
    if not (info and info.width) then return end -- a key the folder doesn't have
    local s = self.scale
    local w, h = info.width, info.height
    local W, H = w * (at.sx or 1), h * (at.sy or 1)
    ORIGIN[1], ORIGIN[2] = W / 2, H / 2
    PARAMS.frame    = at.frame or 0
    PARAMS.x        = at.x * s + w / 2
    PARAMS.y        = at.y * s + h / 2 + self.y2p
    PARAMS.x2       = W - w
    PARAMS.y2       = H - h
    PARAMS.origin   = ORIGIN
    PARAMS.rotation = at.rot or 0
    PARAMS.mirror   = at.mirror and "horizontal" or nil
    PARAMS.fade     = at.fade
    PARAMS.color    = nil   -- donbg's dark wrapper sets one on whatever table it is handed
    tex.draw_texture(id, PARAMS)
end

function BaseChibi:draw()
    if not self.t0 then return end
    self:draw_image(self:place())
end

-- Adds a good-hit chibi to a ChibiController. cls defaults to BaseChibi; folder to "chibi_1"
function BaseChibi.add(controller, spec, path, player_num, cls, folder)
    cls = cls or BaseChibi
    table.insert(controller.chibis, cls.new(spec, path, folder or "chibi_1", controller.bpm, player_num == 2))
end

return BaseChibi
