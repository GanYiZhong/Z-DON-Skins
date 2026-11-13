-- ChibiTail: a BaseChibi whose body bobs on a slow wave and pulses every beat (squeezes,
-- flicks to its second frame, then swells back), with a tail behind it wagging up to 30
-- degrees and back each beat. The tail is the `tail` texture.
local BaseChibi = require("background/bg_objects/chibi/base")
local Timing = require("background/bg_objects/timing")
local chain_moves, frame_change, sum, Loop = Timing.chain_moves_lua, Timing.frame_change_lua, Timing.sum, Timing.Loop

local BOB       = { { 0.525, 15 }, { 1, -25 }, { 0.5, 10 } }              -- px, about 2 beats
local PULSE     = { { 0, 0.15 }, { 1, 0.15 }, { 0, 0.7 } }                 -- frames over a beat
local SIZE      = { { 0.15, -230 }, { 0, 230 }, { 0.15, -210 }, { 0, -125 }, { 0.7, 335, "out" } }
local WAG       = { { 0.675, 45, "out" }, { 0.325, -45 } }                 -- degrees from -15
local WAG_FROM  = -15
local TAIL      = { 0, -5 } -- the tail's centre from the body's, at rest
local TAIL_SLIDE = 0.4      -- px the tail slides back per degree it wags up

local ChibiTail = setmetatable({}, { __index = BaseChibi })
ChibiTail.__index = ChibiTail

function ChibiTail.new(spec, path, folder, bpm, is_2p)
    local self = setmetatable({}, ChibiTail)
    self:init(spec, path, folder, bpm, is_2p)
    return self
end

function ChibiTail:update_extra(current_time_ms)
    if self.hopping then return end
    local beat, scale = self.beat, self.scale
    self.bob = self.bob or Loop.new(2.025 * beat, function() return { y = chain_moves(BOB, beat, scale) } end)
    self.pulse = self.pulse or Loop.new(beat, function()
        local f = frame_change(PULSE, beat)
        f:start()
        return { frame = f, size = chain_moves(SIZE, beat, 1), wag = chain_moves(WAG, beat, 1) }
    end)
    self.bob:update(current_time_ms)
    self.pulse:update(current_time_ms)
end

function ChibiTail:draw()
    if not self.t0 then return end
    local at = self:place()
    local b, p = self.bob and self.bob.anims, self.pulse and self.pulse.anims
    if self.hopping or not (b and p) then
        self:draw_image({ x = at.x, y = at.y, sx = at.sx, sy = at.sy }, "tail")
        return self:draw_image(at)
    end
    at.y = at.y + sum(b.y) / self.scale
    local wag = sum(p.wag)
    self:draw_image({ x = at.x + TAIL[1] + wag * TAIL_SLIDE, y = at.y + TAIL[2], rot = WAG_FROM + wag }, "tail")
    local size = 1 + sum(p.size) / 1000
    at.frame, at.sx, at.sy = self.first + p.frame.attribute, size, size
    self:draw_image(at)
end

return ChibiTail
