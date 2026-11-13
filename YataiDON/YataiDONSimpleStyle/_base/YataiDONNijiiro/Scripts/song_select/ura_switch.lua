-- YataiDONNijiiro: the oni <-> ura change plays on the difficulty board (song_select.lua), so the
-- engine's ura switch overlay draws nothing here (without this override the parent skin's art showed).
UraSwitchAnimation = {}
UraSwitchAnimation.__index = UraSwitchAnimation

function UraSwitchAnimation.new()
    return setmetatable({}, UraSwitchAnimation)
end

function UraSwitchAnimation:start(is_backwards) end

function UraSwitchAnimation:update(current_ms) end

function UraSwitchAnimation:draw() end
