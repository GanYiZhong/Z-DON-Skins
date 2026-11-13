-- GAME→RESULT fade: a full-stage black plate whose alpha ramps 0 → 1, then holds.

local anim = require("anim/sampler")

ResultTransition = {}
ResultTransition.__index = ResultTransition

local F_IN, F_STOP = 6, 115                  -- loading_kuro_result frame labels
-- direct feed YKjsle7VBCI: the fade takes 1.5 s from the first dimming to black (clip frames 6..115 would take 1.82 s)
local MS_PER_F     = 1000.0 / 60.0 / 1.2
local TRACK        = "#3@0"                  -- the black plate's own placement

function ResultTransition.new(player_num)
    local self = setmetatable({}, ResultTransition)
    self.player_num = player_num
    self.t0         = nil
    self.alpha      = 0.0
    -- refuse to run the clock before start()
    self.started    = false
    -- missing table -> NULL clip, update falls back to the linear ramp below
    self.clip    = anim.safe("anim/kuro_result")
    self.t_black = tex.get_texture("global/result_transition/fade")
    return self
end

function ResultTransition:start()
    self.t0      = nil
    self.alpha   = 0.0
    self.started = true
end

function ResultTransition:update(current_ms)
    if not self.started then return end
    if not self.t0 then self.t0 = current_ms end
    local f = F_IN + (current_ms - self.t0) / MS_PER_F
    if f > F_STOP then f = F_STOP end

    local a = self.clip:at(TRACK, f)
    if not a then
        -- fallback: linear 0 → 1 across the ramp
        a = (f - F_IN) / (F_STOP - F_IN)
    end
    if a < 0 then a = 0 elseif a > 1 then a = 1 end
    self.alpha = a
end

-- The engine hands the screen over once this is true AND the result voice has stopped.
function ResultTransition:is_finished()
    return self.started and self.alpha >= 1.0
end

function ResultTransition:draw()
    if not self.t_black then return end
    if self.alpha <= 0.004 then return end       -- below the engine's own 1/256 quantisation
    local w = tex.get_screen_width()
    local h = tex.get_screen_height()
    -- 8×8 plate stretched to the full screen via x2/y2
    tex.draw_texture(self.t_black, { x = 0, y = 0, x2 = w - 8, y2 = h - 8, fade = self.alpha })
end

return ResultTransition
