-- YataiDONSimpleStyle v2: the result "fade in" is the board's 3-frame window open (drawn by
-- result_player.lua); this object only reports when it is done. Reverse (retry): a 2-frame close.
ResultFadeIn = {}
ResultFadeIn.__index = ResultFadeIn

local OPEN_MS = 150

function ResultFadeIn.new(player_num)
    local self = setmetatable({}, ResultFadeIn)
    self.t0 = tex.get_current_ms()
    self.now = self.t0
    return self
end

function ResultFadeIn:start_reverse()
    self.reversed = true
    self.t0 = self.now
end

function ResultFadeIn:update(current_ms) self.now = current_ms end

function ResultFadeIn:is_finished()
    return self.now - self.t0 >= (self.reversed and 100 or OPEN_MS)
end

function ResultFadeIn:draw()
    if not self.reversed then return end
    -- close in 2 frames: sky covers half, then all of the screen
    local p = (self.now - self.t0) < 50 and 0.5 or 1.0
    local c = require("global.ss_ui").P.sky
    tex.draw_rect(0, 0, 1920, math.floor(1080 * p), c[1], c[2], c[3], 255)
end
