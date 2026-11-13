-- ChibiRoll: a BaseChibi that rolls along its run: the character turns a full circle every
-- `roll.beats` over a shadow, swaying `roll.sway` px back and forth as it turns. While rolling
-- it draws frame 1 of its key (the unshadowed picture) over the `shadow` texture.
local BaseChibi = require("background/bg_objects/chibi/base")
local Timing = require("background/bg_objects/timing")
local chain_moves, sum, Loop = Timing.chain_moves_lua, Timing.sum, Timing.Loop

local SHADOW = { 3, 5 } -- the shadow sits this far from the character's centre

local ChibiRoll = setmetatable({}, { __index = BaseChibi })
ChibiRoll.__index = ChibiRoll

function ChibiRoll.new(spec, path, folder, bpm, is_2p)
    local self = setmetatable({}, ChibiRoll)
    self:init(spec, path, folder, bpm, is_2p)
    return self
end

function ChibiRoll:update_extra(current_time_ms)
    if self.hopping then return end
    local r, beat, scale = self.spec.roll, self.beat, self.scale
    local q, h = r.beats / 4, r.sway / 2
    self.roll = self.roll or Loop.new(r.beats * beat, function()
        return {
            rot  = chain_moves({ { r.beats, 360 } }, beat, 1),
            -- back and forth like a cosine: eases out of each end, quickest in the middle
            sway = chain_moves({ { q, -h, "in" }, { q, -h, "out" }, { q, h, "in" }, { q, h, "out" } }, beat, scale),
        }
    end)
    self.roll:update(current_time_ms)
end

function ChibiRoll:draw()
    if not self.t0 then return end
    local at = self:place()
    if self.hopping or not (self.roll and self.roll.anims) then return self:draw_image(at) end
    local a = self.roll.anims
    at.x, at.rot, at.frame = at.x + sum(a.sway) / self.scale, sum(a.rot), self.first + 1
    self:draw_image({ x = at.x + SHADOW[1], y = at.y + SHADOW[2], rot = at.rot }, "shadow")
    self:draw_image(at)
end

return ChibiRoll
