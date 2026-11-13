-- ChibiWave: a BaseChibi that bobs up and down while it runs, and may rock side to side.
--   wave: { first = px from the run line to the first turn (+ is down), height = px between
--           the turns, beats = beats per swing }
--   sway: { first = degrees to the first lean (+ is forward), height = degrees between leans,
--           beats = beats per rock } (optional)
-- Both start when the chibi lands: the first swing only covers `first`, then each swing goes
-- the full height, back and forth.
local BaseChibi = require("background/bg_objects/chibi/base")
local Timing = require("background/bg_objects/timing")
local chain_moves, sum, Loop = Timing.chain_moves_lua, Timing.sum, Timing.Loop

local Swing = {}
Swing.__index = Swing

function Swing.new(s, beat, unit, now)
    local self = setmetatable({}, Swing)
    local lead = s.beats * math.abs(s.first) / s.height
    local dir  = s.first > 0 and -1 or 1
    self.lead     = chain_moves({ { lead, s.first } }, beat, unit)
    self.lead_end = now + lead * beat
    self.loop     = Loop.new(2 * s.beats * beat, function()
        return { v = chain_moves({ { s.beats, dir * s.height }, { s.beats, -dir * s.height } }, beat, unit) }
    end)
    return self
end

function Swing:update(now)
    for _, m in ipairs(self.lead) do m:update(now) end
    if now >= self.lead_end then self.loop:update(now) end
end

function Swing:value()
    return sum(self.lead) + (self.loop.anims and sum(self.loop.anims.v) or 0)
end

local ChibiWave = setmetatable({}, { __index = BaseChibi })
ChibiWave.__index = ChibiWave

function ChibiWave.new(spec, path, folder, bpm, is_2p)
    local self = setmetatable({}, ChibiWave)
    self:init(spec, path, folder, bpm, is_2p)
    return self
end

function ChibiWave:update_extra(current_time_ms)
    if self.hopping then return end
    local spec = self.spec
    self.bob  = self.bob or Swing.new(spec.wave, self.beat, self.scale, current_time_ms)
    self.rock = self.rock or (spec.sway and Swing.new(spec.sway, self.beat, 1, current_time_ms))
    self.bob:update(current_time_ms)
    if self.rock then self.rock:update(current_time_ms) end
end

function ChibiWave:place()
    local at = BaseChibi.place(self)
    if self.bob then at.y = at.y + self.bob:value() / self.scale end
    if self.rock then at.rot = self.rock:value() end
    return at
end

return ChibiWave
