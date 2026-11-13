-- YataiDONSimpleStyle v2 standalone: copied from the nearest ancestor at build time (ss/v2_standalone.py), colours in our ink
-- "Revive!" message after a failed result, before the retry mini-game (Lumen result msg_retry, sprite 877):
-- an orange burst with 復活連打, then a yellow one with もう1曲あそべるドン！. The burst is one corner art
-- drawn in four quadrants; the message fades in over 233 ms. Lumen leaves which label is shown to the
-- game, so the hold times are ours.
ResultRetryMessage = {}
ResultRetryMessage.__index = ResultRetryMessage

local FADE_IN_MS = 233
local REVIVE_MS = 1100
local MORE_MS = 1100

-- burst size; a quadrant turned a half circle pivots about its centre
local BURST_W, BURST_H = 456, 336

function ResultRetryMessage.new()
    local self = setmetatable({}, ResultRetryMessage)
    self.t0 = nil
    self.t = 0
    self.revive = { burst = tex.get_texture("result/retry/burst_revive"), text = tex.get_texture("result/retry/text_revive_" .. tex.language()) }
    self.more = { burst = tex.get_texture("result/retry/burst_more"), text = tex.get_texture("result/retry/text_more_" .. tex.language()) }
    return self
end

function ResultRetryMessage:update(current_ms)
    if not self.t0 then self.t0 = current_ms end
    self.t = current_ms - self.t0
end

function ResultRetryMessage:is_finished()
    return self.t >= REVIVE_MS + MORE_MS
end

local function draw_set(set, fade)
    if not set.burst then return end
    -- draw indices: normal, turned 180 degrees, mirrored, flipped
    tex.draw_texture(set.burst, { index = 0, fade = fade })
    tex.draw_texture(set.burst, { index = 1, fade = fade, rotation = 180, x = BURST_W / 2, y = BURST_H / 2, origin = { BURST_W / 2, BURST_H / 2 } })
    tex.draw_texture(set.burst, { index = 2, fade = fade, mirror = "horizontal" })
    tex.draw_texture(set.burst, { index = 3, fade = fade, mirror = "vertical" })
    if set.text then tex.draw_texture(set.text, { fade = fade }) end
end

function ResultRetryMessage:draw()
    local t = self.t
    if t < REVIVE_MS then
        draw_set(self.revive, math.min(1, t / FADE_IN_MS))
    else
        draw_set(self.more, math.min(1, (t - REVIVE_MS) / FADE_IN_MS))
    end
end
