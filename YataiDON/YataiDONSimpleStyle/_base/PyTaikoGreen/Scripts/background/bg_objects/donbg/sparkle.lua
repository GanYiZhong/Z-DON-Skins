local DonBGBase = require("background/bg_objects/donbg/base")

-- SparkleDonBG: a DonBGBase band whose clear set has stars twinkling in clusters over it
-- (still, not scrolling), as in IMAS SideM and Love Live!. Both ensos place the clusters the
-- same way and time the stars the same way; only the star sizes differ, so each collab gives
-- its two star sets. Ambient, in ms.
--
-- Twinkles in a 2s cycle, counted in Lumen frames (120 a cycle): { pop, life, x, y, from, to }.
-- A star pops up to `from` size in 5 frames, grows to `to` until `life` frames after the pop
-- and shrinks away in 5 more. x, y: offset from the cluster's centre.
-- stars = { trio = (three stars taking turns), pair = (one star in the middle, the other
-- hopping between two spots) }; texture key "sparkle" is the 55px star.
local SPARKLE_MS, SPARKLE_FRAMES, SPARKLE_POP = 2000, 120, 5
local SPARKLE_PIVOT = 27.5 -- the star's centre in its image

-- clusters: { set, x, y, size } (a negative size turns the cluster round)
local CLUSTERS = {
    { "trio", 54.5, 28.5, 1 }, { "trio", 413.7, 32.7, -0.8 }, { "trio", 795.7, 170.2, 0.8 },
    { "trio", 228.75, 163.6, 0.5 }, { "trio", 578.95, 162.5, 1 }, { "trio", 894.4, 102, 0.5 },
    { "trio", 1057.45, 48, -1 }, { "trio", 1179.45, 117.1, 0.5 }, { "trio", 1292.45, 162.5, 1 },
    { "pair", 38.3, 114.35, 1 }, { "pair", 546.4, 44.35, 1 }, { "pair", 959, 148.4, 1 },
}

-- size and opacity of a twinkle `f` frames into the cycle (nil while it's hidden)
local function twinkle(s, f)
    local pop, life, from, to = s[1], s[2], s[5], s[6]
    local u = (f - pop) % SPARKLE_FRAMES
    if u < SPARKLE_POP then return from * u / SPARKLE_POP, u / SPARKLE_POP end
    if u < life then return from + (to - from) * (u - SPARKLE_POP) / (life - SPARKLE_POP), 1 end
    if u < life + SPARKLE_POP then
        local k = 1 - (u - life) / SPARKLE_POP
        return to * k, 0.8 * k
    end
end

local SparkleDonBG   = setmetatable({}, { __index = DonBGBase })
SparkleDonBG.__index = SparkleDonBG

function SparkleDonBG.new(player_num, path, spec, stars)
    local self = setmetatable(DonBGBase.new(1, player_num, path, spec), SparkleDonBG)
    self._id_sparkle  = tex.get_texture(path .. "/" .. self.name .. "/" .. "sparkle") or 0
    self.sparkle_size = tex.get_texture_info(self.name, "sparkle").width
    self.stars        = stars
    self.now          = 0
    return self
end

function SparkleDonBG:update(current_time_ms, bpm)
    DonBGBase.update(self, current_time_ms, bpm)
    self.now = current_time_ms
end

function SparkleDonBG:draw_band(y)
    DonBGBase.draw_band(self, y)
    if self.clear <= 0 then return end
    local sc, w = tex.get_screen_scale(), self.sparkle_size
    local f = (self.now % SPARKLE_MS) * SPARKLE_FRAMES / SPARKLE_MS
    for _, c in ipairs(CLUSTERS) do
        local k = c[4]
        for _, s in ipairs(self.stars[c[1]]) do
            local size, alpha = twinkle(s, f)
            if size and size > 0 then
                size = size * math.abs(k)
                local o = SPARKLE_PIVOT * size * sc
                tex.draw_texture(self._id_sparkle, {
                    x = (c[2] + s[3] * k) * sc, y = y + (c[3] + s[4] * k) * sc,
                    x2 = w * (size - 1), y2 = w * (size - 1), origin = { o, o },
                    fade = alpha * self.clear,
                })
            end
        end
    end
end

function SparkleDonBG:draw(y) self:draw_dark(SparkleDonBG.draw_band, y or 0) end

return SparkleDonBG
