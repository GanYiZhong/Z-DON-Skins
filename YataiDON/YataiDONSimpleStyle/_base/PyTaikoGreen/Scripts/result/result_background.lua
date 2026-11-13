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

ResultBackground = {}
ResultBackground.__index = ResultBackground

function ResultBackground.new(player_num, width)
    local self      = setmetatable({}, ResultBackground)
    self.player_num = player_num
    self.width      = width
    return self
end

function ResultBackground:draw()
    if require("global.ai_battle").draw_result_bg() then   -- Z-DON AI battle: result_bg
        -- strict audit (round 2): the cabinet's AI result keeps the red 成績発表 header (result_normal shape 821) at
        -- the top left (direct feed Tl7g8XXXvAM t=288); the child skin (Nijiiro) opts out with zdon_green_strict x 0
        local gs = tex.get_skin_config("zdon_green_strict")
        local rt = gs and (gs.x or 0) ~= 0 and tex.get_texture("result/background/result_text")
        if rt then tex.draw_texture(rt) end
        return
    end
    draw_background_tiles(self.player_num, self.width, 1.0)
    local rt = tex.get_texture("result/background/result_text")
    if rt then tex.draw_texture(rt) end
end
