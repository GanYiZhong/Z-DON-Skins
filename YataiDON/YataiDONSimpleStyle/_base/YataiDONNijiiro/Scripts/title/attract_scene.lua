-- Nijiiro has no camera attract scene: stub of PyTaikoGreen/title/attract_scene.lua that
-- finishes immediately, so the title goes straight on to the next attract state.
AttractScene = {}
AttractScene.__index = AttractScene

function AttractScene.new() return setmetatable({}, AttractScene) end
function AttractScene:update(current_ms) end
function AttractScene:draw() end
function AttractScene:is_finished() return true end
function AttractScene:close() end
