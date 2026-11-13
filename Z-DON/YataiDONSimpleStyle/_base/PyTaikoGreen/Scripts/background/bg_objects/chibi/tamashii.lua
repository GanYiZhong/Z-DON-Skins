-- ChibiTamashii: the bad-hit spirit (the same in every set). It fades in
-- while drifting in from behind the lane, then zigzags 35px up and down every half beat as it
-- crosses the band (1280px over 5 beats). Its frames play 0-4 once, then loop 4, 3.
local BaseChibi = require("background/bg_objects/chibi/base")
local Timing = require("background/bg_objects/timing")
local chain_moves, frame_change, sum, Loop = Timing.chain_moves_lua, Timing.frame_change_lua, Timing.sum, Timing.Loop

local FROM      = { -419, 24 }
local FADE_IN   = 0.475
local CROSS     = 1282
local ZIGZAG    = { height = 35, beats = 0.5 }
local INTRO     = { { 0, 0.225 }, { 1, 0.25 }, { 2, 0.25 }, { 3, 0.25 }, { 4, 0.5 }, { 3, 0.525 } }
local FLAP      = { { 4, 0.5 }, { 3, 0.525 } }

local ChibiTamashii = setmetatable({}, { __index = BaseChibi })
ChibiTamashii.__index = ChibiTamashii

function ChibiTamashii.new(path, bpm, is_2p)
    local self = setmetatable({}, ChibiTamashii)
    self:init({ key = "0" }, path, "chibi_bad", bpm, is_2p)
    return self
end

function ChibiTamashii:start()
    local beat, scale = self.beat, self.scale
    self.x    = chain_moves({ { 5, CROSS } }, beat, scale)
    self.fade = chain_moves({ { FADE_IN, 1000 } }, beat, 1)
    self.intro = frame_change(INTRO, beat)
    self.intro:start()
    local z = ZIGZAG
    self.zigzag = Loop.new(2 * z.beats * beat, function()
        return { y = chain_moves({ { z.beats, -z.height }, { z.beats, z.height } }, beat, scale) }
    end)
end

function ChibiTamashii:update(current_time_ms)
    if not self.t0 then
        self.t0 = current_time_ms
        self:start()
    end
    local t = (current_time_ms - self.t0) / self.beat
    self.done = t >= 5
    for _, m in ipairs(self.x) do m:update(current_time_ms) end
    for _, m in ipairs(self.fade) do m:update(current_time_ms) end
    self.intro:update(current_time_ms)
    if self.intro.is_finished and not self.flap then
        self.flap = frame_change(FLAP, self.beat, { loop = true })
        self.flap:start()
    end
    if self.flap then self.flap:update(current_time_ms) end
    if t >= FADE_IN then self.zigzag:update(current_time_ms) end
end

function ChibiTamashii:draw()
    if not self.t0 then return end
    local z = self.zigzag.anims
    self:draw_image({
        x     = FROM[1] + sum(self.x) / self.scale,
        y     = FROM[2] + (z and sum(z.y) or 0) / self.scale,
        frame = (self.flap or self.intro).attribute,
        fade  = sum(self.fade) / 1000,
    })
end

return ChibiTamashii
