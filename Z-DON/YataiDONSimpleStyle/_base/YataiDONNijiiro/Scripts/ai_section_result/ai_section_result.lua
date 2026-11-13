-- YataiDON's AI result (AIResultScreen): the cabinet's VS panel and emblem from global/ai_battle.lua
local AIB = require("global.ai_battle")

local MIN_MS, LEAVE_MS = 3500, 12000   -- a press leaves once the emblem is in; otherwise it leaves by itself

AISectionBoard = {}
AISectionBoard.__index = AISectionBoard

function AISectionBoard.new(data)
    local self = setmetatable({}, AISectionBoard)
    AIB.up_result(data.sections, data.won)
    self.begun, self.leaving = false, false
    if audio.has_sound("ai_bgm") then audio.play_sound("ai_bgm", "music") end
    return self
end

function AISectionBoard:begin(progress)
    self.begun = true
    self.begin_ms = nil
    if progress and progress.bests then AIB.up_bests(progress.bests) end
end

function AISectionBoard:update(ms)
    self.ms = ms
    if self.begun then
        self.begin_ms = self.begin_ms or ms
        if ms - self.begin_ms >= LEAVE_MS then self.leaving = true end
    end
end

function AISectionBoard:decide()
    if self.leaving or not self.begin_ms or self.ms - self.begin_ms < MIN_MS then return false end
    self.leaving = true
    return true
end

-- kat: the detail page and back
function AISectionBoard:toggle()
    if self.leaving or not self.begin_ms or self.ms - self.begin_ms < MIN_MS then return false end
    AIB.up_section_scores(AIB.up.total_score or 0)
    AIB.up.detail = not AIB.up.detail
    self.begin_ms = math.max(self.begin_ms, self.ms - LEAVE_MS + 5000)   -- stays a while for reading
    return true
end
function AISectionBoard:draw_background() AIB.draw_result_bg() end
function AISectionBoard:draw() AIB.draw_result(self.begun) end
function AISectionBoard:is_done() return self.leaving end