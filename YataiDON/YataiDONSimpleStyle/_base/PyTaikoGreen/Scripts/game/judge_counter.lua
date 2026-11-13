-- The judge counter shown beside the lane when it is enabled in the settings: the good / ok / bad
-- percentages and counts, the total percentage and the drum roll hits.
-- The engine's JudgeCounter (judge_counter.h) keeps the counts; this draws them.

local SKIN_S = tex.get_screen_scale()
local SKIN = {
    margin = 23 * SKIN_S,
    x = { 260 * SKIN_S, 180 * SKIN_S, 270 * SKIN_S },   -- percent column, count column, total percent column
    y = { 440 * SKIN_S, 477 * SKIN_S, 515 * SKIN_S, 398 * SKIN_S },   -- good, ok, bad, total percent
    drumroll_y = 577 * SKIN_S,
}

JudgeCounter = {}
JudgeCounter.__index = JudgeCounter

local ORANGE, WHITE = { 253, 161, 0, 255 }, { 255, 255, 255, 255 }

function JudgeCounter.new()
    local self = setmetatable({}, JudgeCounter)
    local function T(name) return tex.get_texture("judge_counter/" .. name) end
    self.counter, self.bg, self.total_percent = T("counter"), T("bg"), T("total_percent")
    self.judgments, self.drumrolls, self.percent = T("judgments"), T("drumrolls"), T("percent")
    return self
end

-- right-aligned digits ending at x
function JudgeCounter:draw_counter(value, x, y, color)
    if not (value >= 0) then value = 0 end   -- guards negative values and NaN
    local str = tostring(math.floor(value + 0.5))
    for i = 1, #str do
        tex.draw_texture(self.counter, {
            color = color, frame = str:byte(i) - 48,
            x = x - (#str - (i - 1)) * SKIN.margin, y = y,
        })
    end
end

function JudgeCounter:draw(good, ok, bad, drumrolls)
    tex.draw_texture(self.bg)
    tex.draw_texture(self.total_percent)
    tex.draw_texture(self.judgments)
    tex.draw_texture(self.drumrolls)
    for i = 0, 3 do tex.draw_texture(self.percent, { color = ORANGE, index = i }) end

    local total = good + ok + bad
    if total == 0 then total = 1 end
    local x, y = SKIN.x, SKIN.y

    self:draw_counter(good / total * 100, x[1], y[1], ORANGE)
    self:draw_counter(ok / total * 100, x[1], y[2], ORANGE)
    self:draw_counter(bad / total * 100, x[1], y[3], ORANGE)
    self:draw_counter((good + ok) / total * 100, x[3], y[4], ORANGE)
    self:draw_counter(good, x[2], y[1], WHITE)
    self:draw_counter(ok, x[2], y[2], WHITE)
    self:draw_counter(bad, x[2], y[3], WHITE)
    self:draw_counter(drumrolls, x[2], SKIN.drumroll_y, WHITE)
end
