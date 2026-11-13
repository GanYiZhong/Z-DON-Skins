AttractChara = {}
AttractChara.__index = AttractChara

local FRAME = 1000 / 60
local START_MS = 3000
local GAP_MS = 500

local function ease_out(t) return t * (2 - t) end
local function ease_in(t) return t * t end
local function lerp(a, b, t) return a + (b - a) * t end
local function span(t, t0, t1) return math.max(0, math.min(1, (t - t0) / (t1 - t0))) end

-- Shiba: rises from below, overshoots, settles, then sinks away
local SHIBA_MS = 3100
local SHIBA_REST_Y = 202.5
local SHIBA_RISE = { from = 632.5, top = 157.5, ms = 333, settle_ms = 167 }
local SHIBA_SINK = { start = 2533, ms = 333, to = 590.5 }
local SHIBA_WAG_START = 500
-- breath puffs: { index in texture.json, ms they pop at, fades out linearly }
local PUFFS = {
    { 1, 500 }, { 2, 750, true }, { 3, 1000 },
    { 1, 1700 }, { 2, 1933, true }, { 3, 2167 },
}
local PUFF_POP_MS = 100
local PUFF_FADE_MS = 833

-- Fox-mask bear: slides in from the left, waves, slides back out
local FOX_MS = 3583
local FOX_X = { from = 11.5, rest = 246.5, to = 16.5, in_ms = 500, out_at = 3167, out_ms = 417 }

-- Chicks: { texture, flap ms per frame, first flap, path of { frame, x, y } }
local BIRDS_MS = 3917
local BIRDS = {
    { "bird_yellow", 5, 21, { { 0, 742, -16 }, { 20, 742, 128 }, { 21, 742, 133 }, { 139, 742, 598 } } },
    { "bird_pink", 5, 40, { { 0, 153, 114 }, { 15, 249, 66 }, { 16, 257, 66 }, { 28, 332, 111 }, { 39, 371, 184 }, { 40, 374, 185 }, { 159, 366, 594 } } },
    { "bird_green", 8, 39, { { 39, 501, -8 }, { 198, 501, 593 } } },
    { "bird_blue", 5, 111, { { 49, 994, 94 }, { 70, 877, 61 }, { 71, 871, 61 }, { 110, 678, 164 }, { 111, 676, 170 }, { 234, 594, 597 } } },
}

local SEQUENCES = { { "shiba", SHIBA_MS }, { "fox", FOX_MS }, { "birds", BIRDS_MS } }
local LAP_MS = 0
for _, s in ipairs(SEQUENCES) do LAP_MS = LAP_MS + s[2] + GAP_MS end

function AttractChara.new()
    local self = setmetatable({}, AttractChara)
    self.start_ms = tex.get_current_ms()
    self.active = nil
    self.t = 0

    self.tail_wag = tex.get_animation(46, "title")
    self.fox_poses = tex.get_animation(47, "title")

    self.t_shiba = tex.get_texture("title/camera/shiba")
    self.t_tail = tex.get_texture("title/camera/shiba_tail")
    self.t_puff = tex.get_texture("title/camera/shiba_puff")
    self.t_fox = tex.get_texture("title/camera/fox")
    self.t_birds = {}
    for _, b in ipairs(BIRDS) do
        self.t_birds[b[1]] = tex.get_texture("title/camera/" .. b[1])
    end
    return self
end

function AttractChara:update(current_ms)
    local now = current_ms - self.start_ms - START_MS
    local active
    if now >= 0 then
        local at = now % LAP_MS
        for _, s in ipairs(SEQUENCES) do
            if at < s[2] then
                active, self.t = s[1], at
                break
            end
            at = at - s[2] - GAP_MS
            if at < 0 then break end
        end
    end
    if active ~= self.active then
        self.active = active
        if active == "shiba" then self.tail_wag:start() end
        if active == "fox" then self.fox_poses:start() end
    end
    self.tail_wag:update(current_ms)
    self.fox_poses:update(current_ms)
end

local function path_at(path, ms)
    local frame = ms / FRAME
    if frame < path[1][1] or frame > path[#path][1] then return nil end
    for i = 2, #path do
        local a, b = path[i - 1], path[i]
        if frame <= b[1] then
            local t = (frame - a[1]) / (b[1] - a[1])
            return lerp(a[2], b[2], t), lerp(a[3], b[3], t)
        end
    end
end

function AttractChara:draw_shiba()
    local t = self.t
    local y
    if t < SHIBA_RISE.ms then
        y = lerp(SHIBA_RISE.from, SHIBA_RISE.top, ease_out(t / SHIBA_RISE.ms))
    elseif t < SHIBA_RISE.ms + SHIBA_RISE.settle_ms then
        y = lerp(SHIBA_RISE.top, SHIBA_REST_Y, ease_in((t - SHIBA_RISE.ms) / SHIBA_RISE.settle_ms))
    else
        y = lerp(SHIBA_REST_Y, SHIBA_SINK.to, span(t, SHIBA_SINK.start, SHIBA_SINK.start + SHIBA_SINK.ms))
    end
    local dy = y - SHIBA_REST_Y

    -- the tail swings about its base, the bottom-right corner of the image
    local angle = t < SHIBA_WAG_START and -70 or self.tail_wag.attribute / 10
    tex.draw_texture(self.t_tail, { y = dy, origin = { 128, 152 }, rotation = angle })

    local frame = 0
    if t >= SHIBA_WAG_START and math.floor((t - SHIBA_WAG_START) / (10 * FRAME)) % 2 == 0 then frame = 1 end
    tex.draw_texture(self.t_shiba, { y = dy, frame = frame })

    for _, puff in ipairs(PUFFS) do
        local u = t - puff[2]
        if u >= 0 and u < PUFF_POP_MS + PUFF_FADE_MS then
            local scale, fade = 1, 1
            if u < PUFF_POP_MS then
                scale = lerp(0.3, 1, u / PUFF_POP_MS)
            else
                local f = (u - PUFF_POP_MS) / PUFF_FADE_MS
                fade = 0.96 * (1 - (puff[3] and f or ease_out(f)))
            end
            tex.draw_texture(self.t_puff, { index = puff[1] - 1, scale = scale, center = true, fade = fade })
        end
    end
end

function AttractChara:draw_fox()
    local t = self.t
    local x
    if t < FOX_X.out_at then
        x = lerp(FOX_X.from, FOX_X.rest, span(t, 0, FOX_X.in_ms))
    else
        x = lerp(FOX_X.rest, FOX_X.to, span(t, FOX_X.out_at, FOX_X.out_at + FOX_X.out_ms))
    end
    -- texture.json x is the rest position
    tex.draw_texture(self.t_fox, { x = x - FOX_X.rest, frame = math.floor(self.fox_poses.attribute) })
end

function AttractChara:draw_birds()
    for _, b in ipairs(BIRDS) do
        local x, y = path_at(b[4], self.t)
        if x then
            local frame = 0
            if self.t >= b[3] * FRAME then
                frame = math.floor((self.t - b[3] * FRAME) / (b[2] * FRAME)) % 2
            end
            tex.draw_texture(self.t_birds[b[1]], { x = x, y = y, frame = frame })
        end
    end
end

function AttractChara:draw()
    if self.active == "shiba" then
        self:draw_shiba()
    elseif self.active == "fox" then
        self:draw_fox()
    elseif self.active == "birds" then
        self:draw_birds()
    end
end
