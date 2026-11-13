-- YataiDONSimpleStyle v2: no bottom characters (the mascots are drawn by result_player.lua). Stub.
BottomCharacters = {}
BottomCharacters.__index = BottomCharacters
function BottomCharacters.new() return setmetatable({}, BottomCharacters) end
function BottomCharacters:start() end
function BottomCharacters:update() end
function BottomCharacters:is_finished() return true end
function BottomCharacters:draw() end
