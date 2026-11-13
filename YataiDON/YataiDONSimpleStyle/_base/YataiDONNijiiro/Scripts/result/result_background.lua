-- Arcade result background; layers and the clear cross-fade are drawn by
-- result_bg_layers.lua, driven by __hss_result_bg_clear.
ResultBackground = {}
ResultBackground.__index = ResultBackground

-- FAIL SOFT: a broken layer module must not take the result screen down with it.
local ok_layers, Layers = pcall(require, "result/result_bg_layers")
if not ok_layers then Layers = nil end

function ResultBackground.new(player_num, width)
    local self      = setmetatable({}, ResultBackground)
    self.player_num = player_num
    self.width      = width
    __hss_result_bg_clear = 0.0     -- DAN_RESULT builds no ResultFadeIn, so reset here too
    if Layers then
        local ok, obj = pcall(Layers.new, player_num)
        if ok then self.layers = obj end
    end
    if not self.layers then
        -- fallback: static sky plate alone
        self.t_bg = tex.get_texture(player_num == 3 and "result/background/background_2p"
                                                      or "result/background/background_1p")
    end
    return self
end

function ResultBackground:draw()
    if require("global.ai_battle").draw_result_bg() then return end   -- Z-DON AI battle
    if self.layers then
        self.layers:draw(1.0, __hss_result_bg_clear or 0.0)
    elseif self.t_bg then
        tex.draw_texture(self.t_bg)
    end
end
