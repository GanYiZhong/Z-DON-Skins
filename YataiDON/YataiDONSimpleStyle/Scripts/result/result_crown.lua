-- YataiDONSimpleStyle v2: the crown is drawn by result_player.lua (pixel crown, 3-frame drop).
-- This stub keeps the class defined so the parent's crown art is never loaded or drawn.
ResultCrown = {}
ResultCrown.__index = ResultCrown
function ResultCrown.new() return setmetatable({}, ResultCrown) end
function ResultCrown:update() end
function ResultCrown:is_settled() return true end
function ResultCrown:draw() end
