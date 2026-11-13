local Timing = require("background/bg_objects/timing")
local chain_moves, sum = Timing.chain_moves, Timing.sum

-- Fever: the rainbow-gauge line-up. It jumps up from `rise` px below its
-- rest position, overshooting `peak` px above it, bounces `bounce` px once a beat, and when
-- the rainbow is lost hops to the top of the bounce and drops `drop` px off the screen.
-- Every texture in the folder is drawn together; with `poses`, they switch between frames
-- 0 and 1 on every bounce. Timed in beats. The texture.json position is the rest position.
-- spec (optional): name (folder, default "fever_0"), keys (draw order, default sorted), rise,
-- peak, bounce, drop, poses, additive (set of keys drawn with additive blend, e.g. glows)

local DEFAULT = { rise = 210, peak = 72, bounce = 72, drop = 400 } -- fever_0..2

-- the default line-ups (folders fever_0..3), by Fever.create index
local SPECS = {
    [0] = {},
    [1] = {},
    [2] = {},
    [3] = { rise = 262, drop = 334 },
}

local Fever   = {}
Fever.__index = Fever

function Fever.new(bpm, path, spec)
    local self = setmetatable({}, Fever)
    spec = spec or {}
    self.name   = spec.name or "fever_0"
    self.path   = path
    self.rise   = spec.rise or DEFAULT.rise
    self.bounce = spec.bounce or DEFAULT.bounce
    self.peak   = spec.peak or self.bounce
    self.drop   = spec.drop or DEFAULT.drop
    self.poses  = spec.poses
    tex.load_folder(self.path, "fever/" .. self.name)
    local keys = spec.keys
    if not keys then
        keys = tex.get_texture_keys(self.name) or {}
        table.sort(keys)
    end
    local additive = spec.additive or {}
    self._ids = {}
    for _, key in ipairs(keys) do
        table.insert(self._ids, {
            tex.get_texture(self.path .. "/" .. self.name .. "/" .. key) or 0,
            additive[key] and "additive" or nil,
        })
    end
    self.beat  = 60000 / bpm
    self.pose  = 0
    self.state = nil -- nil (hidden), "in", "bounce", "out"
    return self
end

function Fever:play(state, moves, offset)
    self.state  = state
    self.offset = offset
    self.moves  = chain_moves(moves, self.beat, tex.get_screen_scale())
end

function Fever:y()
    return self.offset + sum(self.moves)
end

function Fever:start()
    local scale = tex.get_screen_scale()
    self.pose = 0
    self:play("in", { { 0.5, -(self.rise + self.peak), "out" }, { 0.5, self.peak, "in" } },
        math.floor(self.rise * scale))
end

-- leaves from wherever the bounce currently is
function Fever:stop()
    if not self.state then return end
    local y = self:y()
    self:play("out", { { 0.25, -self.bounce - y / tex.get_screen_scale(), "out" }, { 0.75, self.drop, "in" } }, y)
end

function Fever:update(current_time_ms, bpm)
    if bpm then self.beat = 60000 / bpm end
    if not self.state then return end
    for _, m in ipairs(self.moves) do m:update(current_time_ms) end
    if not self.moves[#self.moves].is_finished then return end
    if self.state == "out" then
        self.state = nil
    else
        if self.poses then self.pose = 1 - self.pose end
        self:play("bounce", { { 0.5, -self.bounce, "out" }, { 0.5, self.bounce, "in" } }, 0)
    end
end

function Fever:draw()
    if not self.state then return end
    local y = self:y()
    for _, t in ipairs(self._ids) do tex.draw_texture(t[1], { frame = self.pose, y = y, blend = t[2] }) end
end

function Fever:destroy() tex.unload_folder(self.path, "fever/" .. self.name) end

-- a default line-up (index 0-3) from the folder fever_<index> under path
function Fever.create(index, bpm, path)
    local spec = setmetatable({ name = "fever_" .. index }, { __index = SPECS[index] })
    return Fever.new(bpm, path or "background", spec)
end

return Fever
