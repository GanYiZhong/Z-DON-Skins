-- YataiDONSimpleStyle v2: clear banner (engine ClearAnimation); see game/ss_ending.lua
local Ending = require("game/ss_ending")
ClearAnimation = {}
function ClearAnimation.new(is_2p)
    return Ending.new("clear", is_2p, "clear")
end
