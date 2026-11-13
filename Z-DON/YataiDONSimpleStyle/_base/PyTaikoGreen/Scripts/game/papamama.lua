Papamama = {}
Papamama.__index = Papamama

local function ease_out(p) return 1 - (1 - p) * (1 - p) end
local function ease_in(p) return p * p end

local function tween(segs, t)
    for _, s in ipairs(segs) do
        if t < s[1] then
            local p = t / s[1]
            return s[2] + (s[3] - s[2]) * (s[4] and s[4](p) or p)
        end
        t = t - s[1]
    end
    return nil
end

local BOARD = {
    { 417, 0, 1.045, ease_out },
    { 83, 1.045, 1, ease_in },
    { 9067, 1, 1 },
    { 67, 1, 1.047, ease_out },
    { 317, 1.047, 0, ease_in },
}
local BANNER_START = 11833
local BANNER_IN_S = { { 300, 0, 1.125, ease_out }, { 67, 1.125, 1, ease_in } }
local BANNER_IN_Y = { { 300, 41, -5, ease_out }, { 67, -5, 0, ease_in } }
local LOOP = 5367
local BOUNCE_START = 4750
local BOUNCE_S = {
    { 233, 1, 1.287, ease_out },
    { 83, 1.287, 0.725, ease_in },
    { 83, 0.725, 1.125, ease_out },
    { 67, 1.125, 0.875, ease_in },
    { 67, 0.875, 1, ease_out },
}
local BOUNCE_Y = {
    { 233, 0, -11.5, ease_out },
    { 83, -11.5, 11, ease_in },
    { 83, 11, -5, ease_out },
    { 67, -5, 5, ease_in },
    { 67, 5, 0, ease_out },
}

function Papamama.new()
    local self = setmetatable({}, Papamama)
    self.board = tex.get_texture("game/papamama/board")
    self.banner = tex.get_texture("game/papamama/banner")
    self.t = 0
    return self
end

function Papamama:update(ms)
    self.start = self.start or ms
    self.t = ms - self.start
end

function Papamama:draw()
    local t = self.t
    local s = tween(BOARD, t)
    if s and self.board then
        tex.draw_texture(self.board, { scale = s, center = true })
    end
    if t < BANNER_START or not self.banner then
        return
    end
    t = t - BANNER_START
    local y = 0
    s = tween(BANNER_IN_S, t)
    if s then
        y = tween(BANNER_IN_Y, t)
    else
        local l = (t - 367) % LOOP - BOUNCE_START
        s = l >= 0 and tween(BOUNCE_S, l) or 1
        y = l >= 0 and tween(BOUNCE_Y, l) or 0
        s = s or 1
        y = y or 0
    end
    tex.draw_texture(self.banner, { scale = s, y = y, center = true })
end

return Papamama
