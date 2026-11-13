-- Arcade msg_L_mc / msg_R_mc bubbles (perfect/success/near/miss) baked as
-- crown/message frames; 0..3 left bubble, 4..7 right bubble (2P).
ResultCrownMessage = {}
ResultCrownMessage.__index = ResultCrownMessage

local FRAME_MS = 1000 / 60

local ok, msg_anim = pcall(require, "anim/sampler")
if not ok then msg_anim = { safe = function()
    local n = {}
    n.at = function() return nil end; n.get = function() return nil end
    n.label = function() return nil end; n.has = function() return false end
    n.first = function() return 0 end;  n.last = function() return 0 end
    return n
end } end
local MSG       = msg_anim.safe("anim/result_msg")
local MSG_TRACK = "#277@0"
local MSG_F0    = MSG:label("success") or 35    -- the exported range starts here
local MSG_F1    = math.max(MSG_F0, MSG:last())

-- frame (pre is_2p offset) is the judgement: 0 miss, 1 near, 2 success, 3 perfect
-- (result_player.lua's gauge_state/gauge_length -> frame mapping).
local MSG_KEY = {
    [0] = "crown_message_miss",
    [1] = "crown_message_near",
    [2] = "crown_message_success",
    [3] = "crown_message_perfect",
}

local MSG_W, MSG_H = 520, 340
local MSG_CENTER = {
    { 410 + MSG_W / 2, 626 + MSG_H / 2 },  -- 1P
    { 989 + MSG_W / 2, 626 + MSG_H / 2 },  -- 2P
}

function ResultCrownMessage.new(frame, is_2p)
    local self = setmetatable({}, ResultCrownMessage)
    self.t0    = tex.get_current_ms()
    self.now   = self.t0
    self.frame = frame + (is_2p and 4 or 0)
    self.is_2p = is_2p
    self.t_msg = tex.get_texture("result/crown/message")
    local key  = MSG_KEY[frame]
    self.t_text = key and text.create_text(key, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 4, 2) or nil
    return self
end

function ResultCrownMessage:update(current_ms)
    self.now = current_ms
end

function ResultCrownMessage:draw()
    if not self.t_msg then return end
    local f = MSG_F0 + (self.now - self.t0) * 0.06
    if f > MSG_F1 then f = MSG_F1 end
    local scale = MSG:get(MSG_TRACK, f, "sx") or 1.0
    local fade  = MSG:get(MSG_TRACK, f, "a")  or 1.0
    if fade <= 0 then return end
    tex.draw_texture(self.t_msg, {
        frame = self.frame, scale = scale, center = true, fade = fade,
        index = self.is_2p and 1 or 0,
    })

    local t = self.t_text
    if t and t.width and t.width > 0 then
        local c = MSG_CENTER[self.is_2p and 2 or 1]
        local w, h = t.width * scale, t.height * scale
        t:draw({
            x = c[1] - w / 2, y = c[2] - h / 2,
            x2 = w - t.width, y2 = h - t.height,
            fade = fade,
        })
    end
end
