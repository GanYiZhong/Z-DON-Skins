-- YataiDONSimpleStyle v2: fail banner (engine FailAnimation); see game/ss_ending.lua
local Ending = require("game/ss_ending")
FailAnimation = {}
function FailAnimation.new(is_2p)
    return Ending.new("fail", is_2p, "fail")
end
