-- YataiDON-HSS override of PyTaikoGreen/background/bg_objects/chibi.lua:
-- the chibi subsystem is OFF in this skin — no art ships, so keep the parent's
-- ChibiController API but load no folders and spawn nothing.
local ChibiController = {}
ChibiController.__index = ChibiController

function ChibiController.new(bpm, path, index)
    return setmetatable({ chibis = {} }, ChibiController)
end

function ChibiController:add_chibi(player_num, bad) end
function ChibiController:update(current_time_ms, bpm) end
function ChibiController:draw() end
function ChibiController:destroy() end

return ChibiController
