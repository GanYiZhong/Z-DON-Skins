SongTransition = {}
SongTransition.__index = SongTransition

local FRAME = 1000 / 60

-- scene 1
local CENTER_START, CENTER_MS = 183.33, 416.67
local SIDE_START, SIDE_MS     = 466.67, 266.67

-- scene 2 (ms from the hold)
local CENTER_LEAVE, CENTER_LEAVE_MS = 250, 566.67
local SIDE_LEAVE, SIDE_LEAVE_MS     = 383.33, 316.67

local function clamp(v, a, b) if v < a then return a elseif v > b then return b else return v end end
local function ease_in(q)  q = clamp(q, 0, 1) return q * q end
local function ease_out(q) q = clamp(q, 0, 1) return 1 - (1 - q) * (1 - q) end
local function lerp(a, b, p) return a + (b - a) * p end

function SongTransition.new(title, subtitle, is_second)
    local self = setmetatable({}, SongTransition)
    self.is_second = is_second and true or false
    self.t0 = nil
    self.t = 0
    if self.is_second then
        self.rainbow  = tex.get_animation(2, "global")
        self.fade_out = tex.get_animation(3, "global")
    else
        self.rainbow = tex.get_animation(0, "global")
        self.fade_in = tex.get_animation(1, "global")
    end

    self.t_rainbow_bg_bottom = tex.get_texture("global/rainbow_transition/rainbow_bg_bottom")
    self.t_rainbow_bg_top    = tex.get_texture("global/rainbow_transition/rainbow_bg_top")
    self.t_rainbow_bg        = tex.get_texture("global/rainbow_transition/rainbow_bg")
    self.t_chara_left        = tex.get_texture("global/rainbow_transition/chara_left")
    self.t_chara_right       = tex.get_texture("global/rainbow_transition/chara_right")
    self.t_chara_center      = tex.get_texture("global/rainbow_transition/chara_center")

    return self
end

function SongTransition:start()
    self.t0 = nil
    for _, a in ipairs({ self.rainbow, self.fade_in or self.fade_out }) do a:start() end
end

function SongTransition:update(current_ms)
    if not self.t0 then self.t0 = current_ms end
    self.t_real = current_ms - self.t0
    -- Green AI battle: the loading card wipes in over 52 frames in the direct feed Tl7g8XXXvAM (the normal transition's
    -- 28); skin key zdon_ai_wipe_in x = stretch percent (Green arcade-flow only; Nijiiro leaves it out)
    local ts = current_ms
    if not self.is_second and tex.ai_transition and tex.ai_transition() then
        local k = tex.get_skin_config("zdon_ai_wipe_in")
        if k and (k.x or 0) > 100 then ts = self.t0 + (current_ms - self.t0) * 100 / k.x end
    end
    self.t = ts - self.t0
    for _, a in ipairs({ self.rainbow, self.fade_in or self.fade_out }) do a:update(ts) end
end

function SongTransition:state()
    if self.is_second then
        return { rainbow_up = self.rainbow.attribute, fade_out = self.fade_out.attribute,
                 finished = self.rainbow.is_finished }
    end
    -- round 14: the AI battle's loading card stays up about 5.4 s (direct feed Tl7g8XXXvAM: the wipe at t=131.3, the card
    -- t=132..136, the arena at t=137), not the 1 s of the short transition; Green arcade-flow key only (Nijiiro sets 0)
    local finished = self.fade_in.is_finished
    if finished and tex.ai_transition and tex.ai_transition() and (self.t_real or self.t) < 5400 then
        local k = tex.get_skin_config("zdon_ai_arcade_flow")
        if k and (k.x or 0) ~= 0 then finished = false end
    end
    return { rainbow_up = self.rainbow.attribute, fade = self.fade_in.attribute, finished = finished }
end

local function center_y(self)
    local t = self.t
    if self.is_second then
        local y = lerp(550, 560, clamp((t - FRAME) / (14 * FRAME), 0, 1))
        return y - 1080 * ease_in((t - CENTER_LEAVE) / CENTER_LEAVE_MS)
    end
    local y = lerp(1270, 530, ease_in((t - CENTER_START) / CENTER_MS))
    return y + 20 * ease_out((t - (CENTER_START + CENTER_MS)) / 233.33)
end

local function side_pos(self, right)
    local t = self.t

    local x0, y0 = 640, 880
    local x1, y1 = 280, 190
    if right == 1 then x0, y0, x1, y1 = 670, 880, 1090, 210 end
    if self.is_second then
        local y = y1 + 5 + 10 * clamp(t / 366.67, 0, 1)
        local leave = right == 1 and 329 or 309
        return x1, y - leave * ease_in((t - SIDE_LEAVE) / SIDE_LEAVE_MS)
    end
    local p = ease_out((t - SIDE_START) / SIDE_MS)
    return lerp(x0, x1, p), lerp(y0, y1, p) + 5 * ease_in((t - SIDE_START - SIDE_MS) / 233.33)
end

function SongTransition:draw_bg(total_offset, rainbow_up)
    tex.draw_texture(self.t_rainbow_bg_bottom, { y = -rainbow_up - total_offset })
    tex.draw_texture(self.t_rainbow_bg_top,    { y = -rainbow_up - total_offset })
    tex.draw_texture(self.t_rainbow_bg,        { y = -rainbow_up - total_offset })

    local lx, ly = side_pos(self, 0)
    local rx, ry = side_pos(self, 1)
    tex.draw_texture(self.t_chara_left,   { x = lx - 640, y = ly - 880 })
    tex.draw_texture(self.t_chara_right,  { x = rx - 670, y = ry - 880 })
    tex.draw_texture(self.t_chara_center, { y = center_y(self) - 1270 })
end
