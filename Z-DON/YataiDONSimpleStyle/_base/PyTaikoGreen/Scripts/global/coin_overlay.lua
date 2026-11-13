CoinOverlay = {}
CoinOverlay.__index = CoinOverlay

function CoinOverlay.new()
    local self  = setmetatable({}, CoinOverlay)
    self.text   = text.create_text("free_play", { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 4, 5)
    self.config = tex.get_skin_config("free_play")
    -- coin mode ([general] zdon_coin_mode, default off): the cabinet's own credit line, baked from the official
    -- msg_coins movie (sprite 70 "coin" + digit sprite 55); the count is [general] zdon_coin_credits, no coin input
    self.coin_text   = tex.get_texture("global/coin/text")
    self.coin_digits = tex.get_texture("global/coin/digits")
    return self
end

function CoinOverlay:update(current_ms) end

function CoinOverlay:draw(x, y)
    if tex.coin_mode and tex.coin_mode() and self.coin_text and self.coin_digits then
        tex.draw_texture(self.coin_text)
        local n = math.max(0, math.min(99, tex.coin_credits()))
        if n >= 10 then
            tex.draw_texture(self.coin_digits, { frame = math.floor(n / 10), x = 671 }) -- the movie's num2 first slot
        end
        tex.draw_texture(self.coin_digits, { frame = n % 10 })
        return
    end
    local text_x = tex.get_screen_width() / 2 - self.text.width / 2 - self.config.x
    self.text:draw({ x = text_x })
end
