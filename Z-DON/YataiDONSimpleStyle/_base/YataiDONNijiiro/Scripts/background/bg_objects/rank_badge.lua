-- Score-rank badge (粋 / 雅 / 極) at the top-left of the player panel, shown as the
-- score crosses each rank line during play; the plate is swapped per rank and a new
-- rank line restarts the clip.
--
-- Rank lines (the engine's own table): 1 white 500 000, 2 bronze 600 000,
-- 3 silver 700 000, 4 gold 800 000, 5 pink 900 000, 6 purple 950 000,
-- 7 rainbow 1 000 000.
local ClipPlayer = require("game/clip_player")

local RankBadge = {}
RankBadge.__index = RankBadge

local THRESHOLDS = { 500000, 600000, 700000, 800000, 900000, 950000, 1000000 }
local PLATE_SHAPES = { 36, 38, 40, 42, 44, 46, 48 }   -- rank 1..7
local BASE_SHAPE = 36
local POS = { [1] = { 152, 276 - 118 }, [2] = { 152, 276 + 646 } }

function RankBadge.rank_of(score)
    local r = 0
    for i, t in ipairs(THRESHOLDS) do
        if score >= t then r = i end
    end
    return r
end

function RankBadge.available()
    local ok, d = pcall(require, "game/ending_anim/rank_hud")
    return ok and type(d) == "table" and d.frames ~= nil
end

function RankBadge.new(player_num, path)
    local self = setmetatable({}, RankBadge)
    local p = POS[player_num] or POS[1]
    self.clip = ClipPlayer.new("game/ending_anim/rank_hud", path or "game", "rank_hud_anim", p[1], p[2])
    if self.clip then self.clip.hold_last = true end
    self.rank = 0
    return self
end

function RankBadge:set_score(score, now)
    local r = RankBadge.rank_of(score)
    if r == self.rank then return end
    self.rank = r
    if r > 0 and self.clip then
        self.clip.shape_map = { [BASE_SHAPE] = PLATE_SHAPES[r] }
        self.clip:start(now)
    end
end

function RankBadge:draw(now)
    if self.clip and self.clip:started() and not self.clip:finished(now) then
        self.clip:draw(now)
    end
end

function RankBadge:destroy()
    if self.clip then self.clip:destroy() end
end

return RankBadge
