-- YataiDON's AI song select: this skin draws its own tension plate (global/ai_battle.lua), so the menu only passes the
-- AI's condition on. The difficulty's support levels are off (screen option ai_no_support_levels).
local AIB = require("global.ai_battle")

AISupportMenu = {}
AISupportMenu.__index = AISupportMenu

function AISupportMenu.new() return setmetatable({}, AISupportMenu) end
function AISupportMenu:set_status(_) end

function AISupportMenu:draw(_, _, _, _, _, _, tension)
    AIB.up_tension = (tension or 2) + 1   -- 0..4 -> the plate's 1..5
end