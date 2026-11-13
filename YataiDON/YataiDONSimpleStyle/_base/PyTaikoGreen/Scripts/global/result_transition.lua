ResultTransition = {}
ResultTransition.__index = ResultTransition

function ResultTransition.new(player_num)
    local self = setmetatable({}, ResultTransition)
    self.player_num = player_num
    self.move = tex.get_animation(5, "global")   -- result shutter move in

    local screen_w = tex.get_screen_width()
    if player_num == 3 then                      -- PlayerNum.TWO_PLAYER
        self.t_shutter_1p = tex.get_texture("global/result_transition/1p_shutter")
        self.t_shutter_2p = tex.get_texture("global/result_transition/2p_shutter")
        self.t_footer_1p  = tex.get_texture("global/result_transition/1p_shutter_footer")
        self.t_footer_2p  = tex.get_texture("global/result_transition/2p_shutter_footer")
        self.has_footer   = self.t_footer_1p ~= nil and self.t_footer_2p ~= nil

        local f1 = tex.get_texture_info("result_transition", "1p_shutter_footer")
        local f2 = tex.get_texture_info("result_transition", "2p_shutter_footer")
        self.tex_height    = (f1 and f1.height) or 0
        self.tex_height_2p = (f2 and f2.height) or 0

        local s = tex.get_texture_info("result_transition", "1p_shutter")
        self.shutter_width = (s and s.width) or (screen_w / 5)
    else
        local ps           = (player_num == 2) and "2p" or "1p" -- PlayerNum.P2, else 1p
        ps = (player_num == 4) and "4p" or ps
        self.t_shutter = tex.get_texture("global/result_transition/" .. ps .. "_shutter")
        self.t_footer  = tex.get_texture("global/result_transition/" .. ps .. "_shutter_footer")
        self.has_footer = self.t_footer ~= nil

        local f = tex.get_texture_info("result_transition", ps .. "_shutter_footer")
        self.tex_height = (f and f.height) or 0

        local s = tex.get_texture_info("result_transition", ps .. "_shutter")
        self.shutter_width = (s and s.width) or (screen_w / 5)
    end
    return self
end

function ResultTransition:start()
    self.move:start()
    self.t0 = nil
end

function ResultTransition:update(current_ms)
    self.move:update(current_ms)
    self.now = current_ms
    if self.t0 == nil then self.t0 = current_ms end
end

function ResultTransition:is_finished()
    return false   -- the engine's move animation and result_transition voice decide
end

function ResultTransition:draw()
    -- Green AI battle: the cabinet fades the laurel to black over 0.9 s (direct feed Tl7g8XXXvAM 274.1 -> 275.0)
    -- instead of closing the red shutters
    if tex.ai_active ~= nil and tex.ai_active() then
        local a = math.min(1, ((self.now or 0) - (self.t0 or 0)) / 850)
        tex.draw_rect(0, 0, tex.get_screen_width(), tex.get_screen_height(), 0, 0, 0, a * 255)
        return
    end
    if not self.has_footer then return end

    local attr     = self.move.attribute
    local screen_h = tex.get_screen_height()
    local screen_w = tex.get_screen_width()
    local two      = self.player_num == 3
    local top_y    = -screen_h - 20 + attr
    local bottom_y =  screen_h + 20 - attr
    local x = 0
    while x < screen_w do
        local shutter_1 = two and self.t_shutter_1p or self.t_shutter
        local shutter_2 = two and self.t_shutter_2p or self.t_shutter
        local footer_1  = two and self.t_footer_1p or self.t_footer
        local footer_2  = two and self.t_footer_2p or self.t_footer
        tex.draw_texture(shutter_1, { x = x, y = top_y + 20, fade = 0.4 })
        tex.draw_texture(shutter_1, { x = x, y = top_y })
        tex.draw_texture(footer_1,  { x = x, y = top_y + 288 })
        tex.draw_texture(shutter_2, { x = x, y = bottom_y + 20, fade = 0.4 })
        tex.draw_texture(shutter_2, { x = x, y = bottom_y })
        tex.draw_texture(footer_2,  { x = x, y = bottom_y + 288 })
        x = x + self.shutter_width
    end
end
