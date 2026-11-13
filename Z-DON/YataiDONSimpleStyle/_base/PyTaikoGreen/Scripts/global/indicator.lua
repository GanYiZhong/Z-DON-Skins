local SKIN_S = tex.get_screen_scale()
local SKIN = {
    indicator_face_offset = { x = 214 * SKIN_S },
    indicator_kat_offset = { x = 24 * SKIN_S },
    indicator_don_offset = { x = 214 * SKIN_S },
}
Indicator = {}
Indicator.__index = Indicator

Indicator.State = {
    SKIP   = 0,
    SIDE   = 1,
    SELECT = 2,
    WAIT   = 3,
    CANCEL = 4,
}

local TEXT_KEYS = {
    [Indicator.State.SKIP]   = "indicator_text_skip",
    [Indicator.State.SIDE]   = "indicator_text_skip",
    [Indicator.State.SELECT] = "indicator_text",
    [Indicator.State.WAIT]   = "indicator_text_wait",
    [Indicator.State.CANCEL] = "indicator_text_cancel",
}

function Indicator.new(state)
    local self           = setmetatable({}, Indicator)
    self.state           = state

    self.background      = tex.get_texture("global/indicator/background")
    self.drum_face       = tex.get_texture("global/indicator/drum_face")
    self.drum_kat        = tex.get_texture("global/indicator/drum_kat")
    self.drum_don        = tex.get_texture("global/indicator/drum_don")
    self.blue_arrow      = tex.get_texture("global/indicator/blue_arrow")

    self.don_fade        = tex.get_animation(6, "global")
    self.blue_arrow_move = tex.get_animation(7, "global")
    self.blue_arrow_fade = tex.get_animation(8, "global")

    self.cancel_fade     = tex.get_animation(67, "global")

    self.select_text     = text.create_text(TEXT_KEYS[state], { 255, 255, 255, 255 }, { 0, 0, 0, 0 }, false, 0, -5)

    local text_config    = tex.get_skin_config("indicator_text")
    local bg_info        = tex.get_texture_info("indicator", "background")
    self.text_offset_x   = text_config.x
    self.bg_half_height  = bg_info.height / 2
    self.kat_offset_x    = SKIN.indicator_kat_offset.x
    self.face_offset_x   = SKIN.indicator_face_offset.x
    self.don_offset_x    = SKIN.indicator_don_offset.x

    return self
end

-- { x, y } of the indicator on a screen
function Indicator:screen_pos(_screen)
    local s = tex.get_screen_scale()
    return { 396 * s, 575 * s }
end

-- Z-DON AI battle (Green skin key zdon_ai_indicator_phase; Nijiiro 0): the cabinet's own indicator timeline
-- (indicator.lm sprites 9 / 16 / 21, 60 fps, 120 frames = 2 s loop; footage Tl7g8XXXvAM shows plain circles half the
-- time). The don / kat overlays rise 0 -> 1 over frames 0..29 and fall to 0 by frame 59 (then 1 s of plain circles); the
-- blue arrows fade 1 -> 0 over frames 0..60 while sliding 7 px outwards
local function official_phase(ms)
    local f = (ms % 2000) * 0.06
    local a = 0
    if f < 29 then a = f / 29 elseif f < 59.5 then a = 1 - (f - 29) / 30.5 end
    local aa = (f < 60) and (1 - f / 60) or 0
    local mv = (f < 60) and (7 * f / 60) or 7
    return a, aa, mv
end

function Indicator:update(current_ms)
    local ph = tex.get_skin_config("zdon_ai_indicator_phase")
    if ph and (ph.x or 0) ~= 0 and require("global.ai_battle").active() then
        self.t0 = self.t0 or current_ms
        local a, aa, mv = official_phase(current_ms - self.t0)
        self.official = { don = a, arrow = aa, move = mv }
        return
    end
    self.official = nil
    self.t0 = nil
    self.don_fade:update(current_ms)
    self.blue_arrow_move:update(current_ms)
    self.blue_arrow_fade:update(current_ms)
    self.cancel_fade:update(current_ms)
end

function Indicator:draw(x, y, fade)
    fade = fade or 1.0
    if tex.zdon_ai_select() then
        local fdx, fdy = require("global.ai_battle").sel_off("footer")
        x, y = x + fdx, y + fdy
    end
    local state_val = self.state
    local o = self.official
    local don_a = o and o.don or self.don_fade.attribute
    local arrow_a = o and o.arrow or self.blue_arrow_fade.attribute
    local arrow_mv = o and o.move or self.blue_arrow_move.attribute
    local cancel_a = o and o.don or self.cancel_fade.attribute

    tex.draw_texture(self.background, { x = x, y = y, fade = fade })

    local text_y = y + self.bg_half_height - (self.select_text.height / 2)
    self.select_text:draw({ x = x, y = text_y, fade = fade })

    if self.state == Indicator.State.WAIT then
        return
    end

    if self.state == Indicator.State.CANCEL then
        local kat_fade = math.min(fade, cancel_a)
        tex.draw_texture(self.drum_face, { x = x, y = y, fade = fade, index = Indicator.State.SELECT })
        tex.draw_texture(self.drum_kat, { x = x, y = y, fade = kat_fade })
        tex.draw_texture(self.drum_kat, { mirror = "horizontal", x = x + self.kat_offset_x, y = y, fade = kat_fade })
        return
    end

    tex.draw_texture(self.drum_face, { x = x, y = y, fade = fade, index = state_val })

    if self.state == Indicator.State.SELECT then
        local kat_fade   = math.min(fade, don_a)
        local arrow_fade = math.min(fade, arrow_a)

        tex.draw_texture(self.drum_kat, { x = x, y = y, fade = kat_fade })
        tex.draw_texture(self.drum_kat, { mirror = "horizontal", x = x + self.kat_offset_x, y = y, fade = kat_fade })
        tex.draw_texture(self.drum_face, { x = x + self.face_offset_x, y = y, fade = fade, index = state_val })
        tex.draw_texture(self.drum_don, { x = x + self.don_offset_x, y = y, fade = kat_fade, index = state_val })
        tex.draw_texture(self.blue_arrow, { x = x - arrow_mv, y = y, fade = arrow_fade })
        tex.draw_texture(self.blue_arrow,
            { mirror = "horizontal", x = x + arrow_mv, y = y, fade = arrow_fade, index = 1 })
    else
        tex.draw_texture(self.drum_don, { x = x, y = y, fade = math.min(fade, don_a), index = state_val })
    end
end
