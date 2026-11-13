local function draw_background_tiles(player_num, width, fade)
    local screen_h = tex.get_screen_height()
    local screen_w = tex.get_screen_width()
    local x = 0
    if player_num == 3 then -- TWO_PLAYER
        local bg1  = tex.get_texture("result/background/background_1p")
        local bg2  = tex.get_texture("result/background/background_2p")
        local ft1  = tex.get_texture("result/background/footer_1p")
        local ft2  = tex.get_texture("result/background/footer_2p")
        local info = tex.get_texture_info("background", "footer_1p")
        local fh   = info and info.height or 0
        while x < width do
            if bg1 then tex.draw_texture(bg1, { x = x, y = -screen_h / 2, fade = fade }) end
            if bg2 then tex.draw_texture(bg2, { x = x, y = screen_h / 2, fade = fade }) end
            if ft1 then tex.draw_texture(ft1, { x = x, y = -(fh / 2), fade = fade }) end
            if ft2 then tex.draw_texture(ft2, { x = x, y = screen_h - fh / 2, fade = fade }) end
            x = x + screen_w / 5
        end
    else
        local ps   = tostring(player_num) .. "p"
        local bg   = tex.get_texture("result/background/background_" .. ps)
        local ft   = tex.get_texture("result/background/footer_" .. ps)
        local info = tex.get_texture_info("background", "footer_" .. ps)
        local fh   = info and info.height or 0
        while x < width do
            if bg then tex.draw_texture(bg, { x = x, y = -screen_h / 2, fade = fade }) end
            if bg then tex.draw_texture(bg, { x = x, y = screen_h / 2, fade = fade }) end
            if ft then tex.draw_texture(ft, { x = x, y = -(fh / 2), fade = fade }) end
            if ft then tex.draw_texture(ft, { x = x, y = screen_h - fh / 2, fade = fade }) end
            x = x + screen_w / 5
        end
    end
end

ResultFadeIn = {}
ResultFadeIn.__index = ResultFadeIn

function ResultFadeIn.new(player_num)
    local self      = setmetatable({}, ResultFadeIn)
    self.player_num = player_num
    self.fade_in = tex.get_animation(15, "result")
    self.fade_in:start()
    return self
end

-- plays the same cover back the other way: the result background closes over the screen
function ResultFadeIn:start_reverse()
    self.reversed = true
    self.fade_in:restart()
end

function ResultFadeIn:update(current_ms)
    self.fade_in:update(current_ms)
    self.now = current_ms
    if self.t0 == nil then self.t0 = current_ms end
end

function ResultFadeIn:is_finished()
    return self.fade_in.is_finished
end

function ResultFadeIn:draw()
    local screen_w = tex.get_screen_width()
    local fade = self.fade_in.attribute
    if self.reversed then fade = 1 - fade end
    draw_background_tiles(self.player_num, screen_w, fade)
    -- Green AI battle: the result comes up out of black (direct feed Tl7g8XXXvAM 277.3 -> 278.3, 1 s)
    if tex.ai_active ~= nil and tex.ai_active() and not self.reversed then
        local a = 1 - math.min(1, ((self.now or 0) - (self.t0 or 0)) / 910)
        if a > 0 then tex.draw_rect(0, 0, screen_w, tex.get_screen_height(), 0, 0, 0, a * 255) end
    end
end
