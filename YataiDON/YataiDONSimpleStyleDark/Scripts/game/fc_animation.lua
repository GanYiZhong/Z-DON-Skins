-- YataiDONSimpleStyle v2: full combo / donderful banner (engine FCAnimation); see game/ss_ending.lua
local Ending = require("game/ss_ending")
FCAnimation = {}
function FCAnimation.new(is_2p, donderful)
    local snd = (donderful and audio.has_sound("donderful_combo")) and "donderful_combo" or "full_combo"
    local self = Ending.new(donderful and "donderful" or "full_combo", is_2p, snd)
    local voice = (donderful and audio.has_sound("donderful_combo_voice")) and "donderful_combo_voice" or "full_combo_voice"
    self.voice = voice
    return self
end
