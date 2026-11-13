-- YataiDONSimpleStyle v2: the 自己ベスト更新 banner is drawn by result_player.lua. Stub.
HighScoreIndicator = {}
HighScoreIndicator.__index = HighScoreIndicator
function HighScoreIndicator.new() return setmetatable({}, HighScoreIndicator) end
function HighScoreIndicator:update() end
function HighScoreIndicator:draw() end
