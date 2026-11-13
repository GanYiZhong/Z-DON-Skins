local WAIT_PANELS = false

local WAIT_BOX_KEYS = {
    "box_top_left", "box_top_right", "box_bottom_left", "box_bottom_right",
    "box_top", "box_bottom", "box_left", "box_right", "box_center",
}

Entry = {}
Entry.__index = Entry

function Entry.new()
    local self = setmetatable({}, Entry)

    self.bg_flicker       = tex.get_animation(1, "entry")
    self.side_select_fade = tex.get_animation(0, "entry")
    self.bg_flicker:start()
    self.banner_move = tex.get_animation(15, "entry")
    self.banner_fade = tex.get_animation(16, "entry")
    self.banner_move:start()
    self.banner_fade:start()

    if WAIT_PANELS then
        self.wait_bob   = tex.get_animation(17, "entry")
        self.wait_pulse = tex.get_animation(18, "entry")
        self.wait_bob:start()
        self.wait_pulse:start()
        self.text_wait  = text.create_text("entry_wait", { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 4, -1)
        self.wait_cloud = tex.get_texture("entry/wait/cloud")
        self.wait_box   = {}
        for _, suf in ipairs({ "_1p", "_2p" }) do
            for _, key in ipairs(WAIT_BOX_KEYS) do
                self.wait_box[key .. suf] = tex.get_texture("entry/costume_select/" .. key .. suf)
            end
        end
    end

    self.wait_pill      = tex.get_texture("entry/wait/pill")
    self.text_wait_pill = text.create_text("entry_wait_pill", { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 4, -1)

    self.text_question = text.create_text("entry_question", { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 4, -1)
    self.text_cancel   = text.create_text("entry_cancel",   { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 4, -4)
    self.text_1p       = text.create_text("entry_1p",       { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 4, -2)
    self.text_2p       = text.create_text("entry_2p",       { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 4, -2)

    self.bg_bg               = tex.get_texture("entry/background/bg")
    self.bg_tower            = tex.get_texture("entry/background/tower")
    self.bg_shops_center     = tex.get_texture("entry/background/shops_center")
    self.bg_people           = tex.get_texture("entry/background/people")
    self.bg_shops_left       = tex.get_texture("entry/background/shops_left")
    self.bg_shops_right      = tex.get_texture("entry/background/shops_right")
    self.bg_lights           = tex.get_texture("entry/background/lights")

    self.ss_box_top_left     = tex.get_texture("entry/side_select/box_top_left")
    self.ss_box_top_right    = tex.get_texture("entry/side_select/box_top_right")
    self.ss_box_bot_left     = tex.get_texture("entry/side_select/box_bottom_left")
    self.ss_box_bot_right    = tex.get_texture("entry/side_select/box_bottom_right")
    self.ss_box_top          = tex.get_texture("entry/side_select/box_top")
    self.ss_box_bottom       = tex.get_texture("entry/side_select/box_bottom")
    self.ss_box_left         = tex.get_texture("entry/side_select/box_left")
    self.ss_box_right        = tex.get_texture("entry/side_select/box_right")
    self.ss_box_center       = tex.get_texture("entry/side_select/box_center")
    self.ss_1p               = tex.get_texture("entry/side_select/1P")
    self.ss_cancel           = tex.get_texture("entry/side_select/cancel")
    self.ss_2p               = tex.get_texture("entry/side_select/2P")
    self.ss_1p_highlight     = tex.get_texture("entry/side_select/1P_highlight")
    self.ss_1p2p_outline     = tex.get_texture("entry/side_select/1P2P_outline")
    self.ss_cancel_highlight = tex.get_texture("entry/side_select/cancel_highlight")
    self.ss_cancel_outline   = tex.get_texture("entry/side_select/cancel_outline")
    self.ss_2p_highlight     = tex.get_texture("entry/side_select/2P_highlight")
    self.ss_footer           = tex.get_texture("entry/side_select/footer")
    self.ss_footer_left      = tex.get_texture("entry/side_select/footer_left")
    self.ss_footer_right     = tex.get_texture("entry/side_select/footer_right")
    self.global_player_entry = tex.get_texture("entry/global/player_entry")

    self.text_afk     = text.create_text("entry_afk", { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 4, -1)
    self.afk_panel    = tex.get_texture("entry/afk/panel")
    self.afk_drum     = tex.get_texture("entry/afk/drum")
    self.afk_stick    = tex.get_texture("entry/afk/stick")
    self.afk_stick_up = tex.get_texture("entry/afk/stick_up")

    return self
end

function Entry:update(current_ms)
    self.bg_flicker:update(current_ms)
    self.banner_move:update(current_ms)
    self.banner_fade:update(current_ms)
    if WAIT_PANELS then
        self.wait_bob:update(current_ms)
        self.wait_pulse:update(current_ms)
    end
    self.side_select_fade:update(current_ms)
end

function Entry:start_side_select()
    self.side_select_fade:start()
end

function Entry:restart_side_select()
    self.side_select_fade:restart()
end

function Entry:get_side_select_fade()
    return self.side_select_fade.attribute
end

function Entry:draw_background()
    tex.draw_texture(self.bg_bg)
    tex.draw_texture(self.bg_tower)
    tex.draw_texture(self.bg_shops_center)
    tex.draw_texture(self.bg_people)
    tex.draw_texture(self.bg_shops_left)
    tex.draw_texture(self.bg_shops_right)
    tex.draw_texture(self.bg_lights, { scale = 2.0, fade = self.bg_flicker.attribute })
end

function Entry:draw_side_select()
    local fade = self.side_select_fade.attribute
    tex.draw_texture(self.ss_box_top_left,  { fade = fade })
    tex.draw_texture(self.ss_box_top_right, { fade = fade })
    tex.draw_texture(self.ss_box_bot_left,  { fade = fade })
    tex.draw_texture(self.ss_box_bot_right, { fade = fade })
    tex.draw_texture(self.ss_box_top,       { fade = fade })
    tex.draw_texture(self.ss_box_bottom,    { fade = fade })
    tex.draw_texture(self.ss_box_left,      { fade = fade })
    tex.draw_texture(self.ss_box_right,     { fade = fade })
    tex.draw_texture(self.ss_box_center,    { fade = fade })

    self.text_question:draw({
        x    = -self.text_question.width / 2,
        fade = fade,
    })
end

function Entry:draw_side_select_buttons(side)
    local fade = self.side_select_fade.attribute
    tex.draw_texture(self.ss_1p,     { fade = fade })
    tex.draw_texture(self.ss_cancel, { fade = fade })
    tex.draw_texture(self.ss_2p,     { fade = fade })

    if side == 0 then
        tex.draw_texture(self.ss_1p_highlight, { fade = fade })
        tex.draw_texture(self.ss_1p2p_outline, { mirror = "horizontal", fade = fade, index = 0 })
    elseif side == 1 then
        tex.draw_texture(self.ss_cancel_highlight, { fade = fade })
        tex.draw_texture(self.ss_cancel_outline,   { fade = fade })
    else
        tex.draw_texture(self.ss_2p_highlight, { fade = fade })
        tex.draw_texture(self.ss_1p2p_outline, { fade = fade, index = 1 })
    end

    local cancel_info = tex.get_texture_info("side_select", "cancel")
    local text_x = cancel_info.x[1] + (cancel_info.width / 2) - (self.text_cancel.width / 2)
    local text_y = cancel_info.y[1] + (cancel_info.height / 2) - (self.text_cancel.height / 2)
    self.text_cancel:draw({ x = text_x, y = text_y, fade = fade })

    local p1_info = tex.get_texture_info("side_select", "1P")
    local p2_info = tex.get_texture_info("side_select", "2P")
    self.text_1p:draw({ x = p1_info.x[1] - (self.text_1p.width / 2), y = p1_info.y[1] - (self.text_1p.height / 2), fade = fade })
    self.text_2p:draw({ x = p2_info.x[1] - (self.text_2p.width / 2), y = p2_info.y[1] - (self.text_2p.height / 2), fade = fade })
end

function Entry:draw_footer(p1_joined, p2_joined)
    tex.draw_texture(self.ss_footer)
    if p1_joined and p2_joined then
        -- both players joined, no footer sides
    elseif not p1_joined and not p2_joined then
        tex.draw_texture(self.ss_footer_left)
        tex.draw_texture(self.ss_footer_right)
    elseif p1_joined then
        tex.draw_texture(self.ss_footer_right)
    else
        tex.draw_texture(self.ss_footer_left)
    end
end

-- one piece of the panel box, stretched from its texture.json size to w x h (nil = unchanged)
local function wait_piece(id, name, x, y, w, h)
    local info = tex.get_texture_info("costume_select", name)
    local base_w = (info.x2 and info.x2[1]) or info.width
    local base_h = (info.y2 and info.y2[1]) or info.height
    tex.draw_texture(id, {
        x  = x - info.x[1],
        y  = y - info.y[1],
        x2 = w and (w - base_w) or 0,
        y2 = h and (h - base_h) or 0,
    })
end

local function wait_box()
    local s = tex.get_screen_scale()
    return { x = 42 * s, x_2p = 806 * s, y = 164 * s, width = 432 * s, height = 432 * s }
end

function Entry:draw_wait_panel(p2)
    local box  = wait_box()
    local x    = p2 and box.x_2p or box.x
    local y    = box.y
    local suf  = p2 and "_2p" or "_1p"
    local cw   = box.width  - 128
    local ch   = box.height - 128
    local far_x, far_y = x + box.width - 64, y + box.height - 64
    local b = self.wait_box
    local function id(key) return b[key .. suf] end
    -- the costume dialog pieces are drawn per player; reuse its textures
    wait_piece(id("box_top_left"),     "box_top_left"     .. suf, x,        y)
    wait_piece(id("box_top_right"),    "box_top_right"    .. suf, far_x,    y)
    wait_piece(id("box_bottom_left"),  "box_bottom_left"  .. suf, x,        far_y)
    wait_piece(id("box_bottom_right"), "box_bottom_right" .. suf, far_x,    far_y)
    wait_piece(id("box_top"),          "box_top"          .. suf, x + 64,   y,     cw)
    wait_piece(id("box_bottom"),       "box_bottom"       .. suf, x + 64,   far_y, cw)
    wait_piece(id("box_left"),         "box_left"         .. suf, x,        y + 64, nil, ch)
    wait_piece(id("box_right"),        "box_right"        .. suf, far_x,    y + 64, nil, ch)
    wait_piece(id("box_center"),       "box_center"       .. suf, x + 64,   y + 64, cw, ch)

    local dx = x - box.x

    local bob = self.wait_bob.attribute
    tex.draw_texture(self.wait_cloud, { x = dx, y = bob, scale = self.wait_pulse.attribute, center = true })
    -- the text already carries entry_wait's x, y (the cloud centre) as its offset
    self.text_wait:draw({
        x = dx - self.text_wait.width / 2,
        y = bob - self.text_wait.height / 2,
    })
end

function Entry:wait_chara_pos(p2)
    if not WAIT_PANELS then return nil end
    local s   = tex.get_screen_scale()
    local box = wait_box()
    local dx  = p2 and (box.x_2p - box.x) or 0
    return { 251 * s + dx, 520 * s }
end


local AFK_DELAY = 5000
local FRAME = 1000 / 60

local AFK_BOB = {
    { 0, 19, 0, -10, "out" }, { 19, 34, -10, 0, "in" },
    { 34, 43, 0, -6, "out" }, { 43, 51, -6, 0, "in" },
    { 51, 56, 0, -3, "out" }, { 56, 60, -3, 0, "in" },
}

local function afk_bob(f)
    f = f % 60
    for _, k in ipairs(AFK_BOB) do
        if f < k[2] then
            local u = (f - k[1]) / (k[2] - k[1])
            u = k[5] == "out" and 1 - (1 - u) ^ 2 or u ^ 2
            return k[3] + (k[4] - k[3]) * u
        end
    end
    return 0
end

function Entry:draw_afk(idle_ms)
    local t = idle_ms - AFK_DELAY
    if t < 0 then return end
    local s = tex.get_screen_scale()
    local f = t / FRAME
    local fade = math.min(t / (29 * FRAME), 1)

    tex.draw_texture(self.afk_panel, { fade = fade })


    local info = tex.get_texture_info("afk", "panel")
    local ox, oy = tex.get_draw_offset()
    tex.begin_scissor(info.x[1] + 153 * s + ox, info.y[1] - 7 * s + oy, 472 * s, 384 * s)

    local loop = f % 20
    tex.draw_texture(self.afk_drum, { y = 4 * math.abs(1 - loop / 10) * s, fade = fade })
    local right_up = f % 20 < 5
    local left_up = (f + 10) % 20 < 5
    tex.draw_texture(left_up and self.afk_stick_up or self.afk_stick, { index = 0, mirror = "horizontal", fade = fade })
    tex.draw_texture(right_up and self.afk_stick_up or self.afk_stick, { index = 1, fade = fade })
    tex.end_scissor()

    self.text_afk:draw({
        x    = -self.text_afk.width / 2,
        y    = afk_bob(f) * s - self.text_afk.height / 2,
        fade = fade,
    })
end

function Entry:draw_waiting(idle_ms)
    local fade = self.banner_fade.attribute
    tex.draw_texture(self.wait_pill, { fade = fade })
    -- one line per player, stacked about entry_wait_pill's x, y (the pill centre), which the text carries as its offset
    local t, dy = self.text_wait_pill, 20 * tex.get_screen_scale()
    for _, off in ipairs({ -dy, dy }) do
        t:draw({ x = -t.width / 2, y = off - t.height / 2, fade = fade })
    end
    if WAIT_PANELS then
        self:draw_wait_panel(false)
        self:draw_wait_panel(true)
    end
    if idle_ms then self:draw_afk(idle_ms) end
end

function Entry:draw_player_entry()
    tex.draw_texture(self.global_player_entry, { x = self.banner_move.attribute, fade = self.banner_fade.attribute })
end
