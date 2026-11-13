-- Result fade-in: the arcade background drawn on top and faded out (animation 15).
ResultFadeIn = {}
ResultFadeIn.__index = ResultFadeIn

local ok_layers, Layers = pcall(require, "result/result_bg_layers")
if not ok_layers then Layers = nil end

function ResultFadeIn.new(player_num)
    local self      = setmetatable({}, ResultFadeIn)
    self.player_num = player_num
    __hss_result_bg_clear = 0.0     -- first object the result scene builds; clear last run's state
    self.fade_in = tex.get_animation(15, "result")
    self.fade_in:start()
    if Layers then
        local ok, obj = pcall(Layers.new, player_num)
        if ok then self.layers = obj end
    end
    if not self.layers then
        self.t_bg = tex.get_texture(player_num == 3 and "result/background/background_2p"
                                                      or "result/background/background_1p")
    end
    return self
end

-- retry: the parent plays the same cover back the other way, closing over the screen
function ResultFadeIn:start_reverse()
    self.reversed = true
    self.fade_in:restart()
end

function ResultFadeIn:update(current_ms)
    self.fade_in:update(current_ms)
end

function ResultFadeIn:is_finished()
    return self.fade_in.is_finished
end

function ResultFadeIn:draw()
    local fade = self.fade_in.attribute
    if self.reversed then fade = 1 - fade end
    if tex.ai_active and tex.ai_active() then   -- Z-DON AI battle: its result comes up out of black, not the normal 2P cover
        if fade > 0.002 then tex.draw_rect(0, 0, 1920, 1080, 0, 0, 0, 255 * fade) end
        return
    end
    if self.layers then
        self.layers:draw(fade, __hss_result_bg_clear or 0.0)
    elseif self.t_bg then
        tex.draw_texture(self.t_bg, { fade = fade })
    end
end
