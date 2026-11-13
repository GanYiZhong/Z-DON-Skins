-- Soul-gauge skin hook. No longer draws (the engine owns the cabinet grid now);
-- keeps the handle_gauge / draw_one hook shape and unloads the gauge folders so
-- other scripts' gauge draws stay honest.

local ArcadeGauge   = {}
ArcadeGauge.__index = ArcadeGauge

function ArcadeGauge.new()
    local self = setmetatable({}, ArcadeGauge)
    self.p     = {}

    return self
end

-- Record gauge state for readers; nothing draws.
function ArcadeGauge:handle_gauge(player_num, progress, is_clear, is_rainbow, clear_progress, flash)
    if player_num ~= 1 and player_num ~= 2 then return end
    local g = self.p[player_num]
    if not g then g = {}; self.p[player_num] = g end
    g.progress       = progress or 0
    g.is_clear       = is_clear and true or false
    g.is_rainbow     = is_rainbow and true or false
    g.clear_progress = clear_progress or 1
    g.flash          = flash or 0
end

function ArcadeGauge:draw_one(player_num) end
function ArcadeGauge:draw() end

return ArcadeGauge
