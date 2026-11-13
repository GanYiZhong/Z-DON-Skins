-- ChibiStretch: a BaseChibi that lunges as it runs. Every `lunge.beats` it crouches back
-- `crouch` px squeezing to 80% width, springs `spring` px forward stretching to 120% width,
-- holds, then eases back to where it started at full width.
local BaseChibi = require("background/bg_objects/chibi/base")
local Timing = require("background/bg_objects/timing")
local chain_moves, sum, Loop = Timing.chain_moves_lua, Timing.sum, Timing.Loop

local ChibiStretch = setmetatable({}, { __index = BaseChibi })
ChibiStretch.__index = ChibiStretch

function ChibiStretch.new(spec, path, folder, bpm, is_2p)
    local self = setmetatable({}, ChibiStretch)
    self:init(spec, path, folder, bpm, is_2p)
    return self
end

function ChibiStretch:update_extra(current_time_ms)
    if self.hopping then return end
    local l, beat, scale = self.spec.lunge, self.beat, self.scale
    self.lunge = self.lunge or Loop.new(l.beats * beat, function()
        local back = l.beats - 0.5 - 0.375 - 0.1
        return {
            x     = chain_moves({ { 0.5, -l.crouch }, { 0.375, l.crouch + l.spring, "out" }, { 0.1, 0 },
                                  { back, -l.spring, "in" } }, beat, scale),
            width = chain_moves({ { 0.5, -200 }, { 0.375, 400, "out" }, { 0.1, 0 }, { back, -200, "in" } }, beat, 1),
        }
    end)
    self.lunge:update(current_time_ms)
end

function ChibiStretch:place()
    local at = BaseChibi.place(self)
    local a = self.lunge and self.lunge.anims
    if a then
        at.x  = at.x + sum(a.x) / self.scale
        at.sx = 1 + sum(a.width) / 1000
    end
    return at
end

return ChibiStretch
