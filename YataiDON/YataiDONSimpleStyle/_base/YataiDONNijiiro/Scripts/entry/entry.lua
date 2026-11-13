require("global/guide_panel")

Entry = {}
Entry.__index = Entry

function Entry.new()
    local self = setmetatable({}, Entry)
    __hss_entry_reset = true

    self.bg_flicker       = tex.get_animation(1, "entry")
    self.side_select_fade = tex.get_animation(0, "entry")
    self.bg_flicker:start()

    self.text_cancel      = text.create_text("entry_cancel",       { 255, 255, 255, 255 }, {  40,  24,  12, 255 }, false, 3, 0)
    self.text_credit_p    = {
        text.create_text("entry_credit_1p",    {   0,   0,   0, 255 }, { 255, 255, 255, 255 }, false, 7.0 / tex.get_screen_scale(), 0),
        text.create_text("entry_credit_2p",    {   0,   0,   0, 255 }, { 255, 255, 255, 255 }, false, 7.0 / tex.get_screen_scale(), 0),
    }
    local CREDIT_BORDER = 7.0 / tex.get_screen_scale()
    self.text_credit_msg    = text.create_text("entry_credit_start", { 255, 255, 255, 255 }, {   0,   0,   0, 255 }, false, CREDIT_BORDER, 0)
    self.text_credit_msg_hl = text.create_text("entry_credit_start", { 255, 255, 255, 255 }, { 255, 236,  67, 255 }, false, CREDIT_BORDER, 0)

    self.bg_bg               = tex.get_texture("entry/background/bg")
    self.bg_tower            = tex.get_texture("entry/background/tower")
    self.bg_shops_center     = tex.get_texture("entry/background/shops_center")
    self.bg_people           = tex.get_texture("entry/background/people")
    self.bg_shops_left       = tex.get_texture("entry/background/shops_left")
    self.bg_shops_right      = tex.get_texture("entry/background/shops_right")
    self.bg_lights           = tex.get_texture("entry/background/lights")

    self.bg_street_lit       = tex.get_texture("entry/background/street_lit")
    self.bg_glow             = tex.get_texture("entry/background/glow")
    self.bg_twinkle          = tex.get_texture("entry/background/twinkle")
    self.bg_t0               = tex.get_current_ms()

    self.cr_pill             = tex.get_texture("entry/side_select/credit_pill")
    self.cr_flash            = tex.get_texture("entry/side_select/credit_flash")
    self.cr_t0               = tex.get_current_ms()
    self.cr_blink_t0         = self.cr_t0
    self.cr_side             = 1
    self.cr_frame            = 0
    self.cr_seen_frame       = nil
    self.cr_decide_t0        = nil
    self.cr_decide_row       = nil

    self.cr_pending_decide   = nil

    -- side select box (entry/banapass_entry.nulm), shown after an online login
    local function ss(name) return tex.get_texture("entry/side_select/" .. name) end
    self.box = {
        panel = ss("box_panel"),
        button = { [0] = ss("button_left"), [1] = ss("button_none"), [2] = ss("button_right") },
        ring = ss("select_ring"), glow = ss("select_glow"), decide_ring = ss("decide_ring"), flash = ss("decide_flash"),
        none_ring = ss("none_ring"), none_glow = ss("none_glow"), none_decide_ring = ss("none_decide_ring"),
        none_flash = ss("none_decide_flash"),
    }
    local function raw(key, size, color, outline, border)
        local str = tex.skin_text(key)
        if str == "" then return nil end
        return text.create_raw_text(str, size, color, outline, false, border / tex.get_screen_scale(), 0)
    end
    self.box_question = raw("entry_side_question", 46, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, 5.5)
    self.box_label = {
        [0] = raw("entry_side_left", 40, { 0, 0, 0, 255 }, { 0, 0, 0, 255 }, 0),
        [1] = raw("entry_side_none", 32, { 0, 0, 0, 255 }, { 0, 0, 0, 255 }, 0),
        [2] = raw("entry_side_right", 40, { 0, 0, 0, 255 }, { 0, 0, 0, 255 }, 0),
    }
    self.box_ms     = nil   -- last frame the box was drawn (a decide then belongs to it, not the rows)
    self.box_decide = nil   -- { t0, side }

    self.guide      = GuidePanel.new()
    self.any_joined = false

    return self
end

function Entry:draw_control_guide()
    if not self.guide then return end
    if self.any_joined then return end
    self.guide:draw(GuidePanel.Loop.DECIDE, 0, 0, 1.0)
end

function Entry:update(current_ms)
    self.bg_flicker:update(current_ms)
    self.side_select_fade:update(current_ms)
    self.cr_frame = (self.cr_frame or 0) + 1
end

function Entry:start_side_select()
    self.side_select_fade:start()
    self:restart_credit()
end

function Entry:restart_side_select()
    self.side_select_fade:restart()
    self:restart_credit()
end

function Entry:restart_credit()
    local now = tex.get_current_ms()
    self.cr_t0        = now
    self.cr_blink_t0  = now
    self.cr_side      = 1
    self.cr_decide_t0 = nil
    self.cr_decide_row = nil
    self.cr_seen_frame = nil
    self.cr_pending_decide = nil
end

function Entry:get_side_select_fade()
    return self.side_select_fade.attribute
end

local ea_ok, entry_anim = pcall(require, "anim/sampler")
if not ea_ok then entry_anim = { safe = function()
    local n = {}
    n.at = function() return nil end; n.get = function() return nil end
    n.label = function() return nil end; n.has = function() return false end
    n.first = function() return 0 end;  n.last = function() return 0 end
    return n
end } end
local entry_bg    = entry_anim.safe("anim/entry_bg")
local credit_row = entry_anim.safe("anim/credit_row")
local credit_fade = entry_anim.safe("anim/credit_fade")

local CREDIT_CX   = 960
local ROW_CY      = { 432 + 72, 432 + 248 }
local LABEL_INK_X = CREDIT_CX - 443
local MSG_INK_X   = CREDIT_CX + 190
local TEXT_INK_DY = 0.5
local PAD5        = 9
local PAD_LABEL   = 2
local CANCEL_CX, CANCEL_CY = 960, 838
local ROW_LOOP_F0, ROW_LOOP_LEN = 5, 120
local DIM_UNSELECTED = 0.72
local DECIDE_FLASH_F = 24
local entry_bg_len = math.max(1, entry_bg:last() - entry_bg:first() + 1)
local BG_LIT_END = 19
local ENTRY_TWINKLES = {
    { 0, 0, "#11@1/#5@0/#3@0" },
    { 1, 0, "#11@1/#9@2/#3@0" },
    { 2, 1, "#11@1/#8@1/#6@0" },
    { 3, 1, "#11@1/#10@3/#6@0" },
}

function Entry:draw_background()
    local f = ((tex.get_current_ms() - self.bg_t0) * 0.06) % entry_bg_len   -- arcade frames @ 60 fps

    tex.draw_texture(self.bg_bg)

    if self.bg_twinkle then
        for i = 1, #ENTRY_TWINKLES do
            local tw = ENTRY_TWINKLES[i]
            local s, a = entry_bg:at(tw[3], f)
            if a and a > 0.002 then
                tex.draw_texture(self.bg_twinkle,
                    { index = tw[1], frame = tw[2], center = true, scale = s, fade = a })
            end
        end
    end

    if self.bg_glow then
        local ga = entry_bg:get("#16@3/#14@0", f, "a") or 1.0
        for i = 0, 1 do
            tex.draw_texture(self.bg_glow, { index = i, frame = i, fade = ga })
        end
    end

    if self.bg_street_lit then
        local lf = (tex.get_current_ms() - self.bg_t0) * 0.06     -- monotonic, NOT wrapped
        if lf < BG_LIT_END then
            local la = entry_bg:get("#17@7", lf, "a") or 0.0
            if la > 0.002 then tex.draw_texture(self.bg_street_lit, { fade = la }) end
        end
    end
end

-- banapass_entry.nulm sprite 47 at the screen centre: panel at y +19, question c35, buttons 6 / 10 / 14 at y +260
local BOX_CX, BOX_CY = 960, 540
local BOX_W, BOX_H = 1200, 896
local QUESTION_CY = BOX_CY + 109 + 48
local BUTTON_Y = BOX_CY + 260
local BUTTON_DX = { [0] = -304, [1] = 0, [2] = 304 }
local BUTTON_SIZE = { [0] = { 304, 144 }, [1] = { 336, 128 }, [2] = { 304, 144 } }
local LABEL_DY = 5                          -- label boxes sit 5 px under the button centre
local GLOW_MS, DECIDE_MS, BOX_OUT_MS = 1000, 517, 317

local function clamp01(v) return math.max(0, math.min(1, v)) end

local function put(t, w, h, cx, cy, fade)
    if t then tex.draw_texture(t, { x = cx - w / 2, y = cy - h / 2, fade = fade }) end
end

function Entry:draw_box_panel(fade)
    put(self.box.panel, BOX_W, BOX_H, BOX_CX, BOX_CY + 19, fade)
    local q = self.box_question
    if q then q:draw({ x = BOX_CX - q.width / 2, y = QUESTION_CY - q.height / 2, fade = fade }) end
end

-- buttons, the selection on `side` (21 / 28: steady ring + glow pulsing 1 -> 0 -> 1 a second) and, after a
-- decide `dt` ms ago, the white ring and flash blinking three times (21 depth 2, 31 / 34)
function Entry:draw_box_buttons(side, fade, dt)
    local b = self.box
    for i = 0, 2 do
        local w, h = BUTTON_SIZE[i][1], BUTTON_SIZE[i][2]
        local x = BOX_CX + BUTTON_DX[i]
        put(b.button[i], w, h, x, BUTTON_Y, fade)
        local l = self.box_label[i]
        if l then l:draw({ x = x - l.width / 2, y = BUTTON_Y + LABEL_DY - l.height / 2, fade = fade }) end
    end
    local w, h = BUTTON_SIZE[side][1], BUTTON_SIZE[side][2]
    local x = BOX_CX + BUTTON_DX[side]
    local none = side == 1
    local ph = ((tex.get_current_ms() - self.cr_t0) % GLOW_MS) / GLOW_MS
    local glow = ph < 0.45 and (1 - ph / 0.45) ^ 2 or 1 - (1 - math.min(1, (ph - 0.45) / 0.47)) ^ 2
    put(none and b.none_ring or b.ring, w, h, x, BUTTON_Y, fade)
    put(none and b.none_glow or b.glow, w, h, x, BUTTON_Y, fade * glow)
    if dt then
        local t = (dt % 167) / 167
        local blink = dt < DECIDE_MS and (1 - math.abs(t * 2 - 1)) or 0
        put(none and b.none_decide_ring or b.decide_ring, w, h, x, BUTTON_Y, fade * blink)
        put(none and b.none_flash or b.flash, w, h, x, BUTTON_Y, fade * blink * 0.9)
    end
end

function Entry:draw_side_select()
    self.box_ms = tex.get_current_ms()
    self:draw_box_panel(self.side_select_fade.attribute)
end

-- after the decide the engine leaves side select: the box blinks, then fades out (sprite 48 `out`)
function Entry:draw_box_decide()
    local d = self.box_decide
    if not d then return end
    local dt = tex.get_current_ms() - d.t0
    local fade = 1 - clamp01((dt - DECIDE_MS) / BOX_OUT_MS)
    if fade <= 0 then
        self.box_decide = nil
        return
    end
    self:draw_box_panel(fade)
    self:draw_box_buttons(d.side, fade, dt)
end

-- One player row.  `row` is 1 (upper, 1P) or 2 (lower, 2P); `f` is the row timeline frame.
function Entry:draw_credit_row(row, f, a)
    if a <= 0.002 then return end
    tex.draw_texture(self.cr_pill, { index = row - 1, fade = a })

    local cy = ROW_CY[row]
    local lbl = self.text_credit_p[row]
    if lbl then
        lbl:draw({ x = LABEL_INK_X - PAD_LABEL, y = cy + TEXT_INK_DY - lbl.height / 2, fade = a })
    end

    -- fill alpha and the outline copy colour multiply, both read from the export
    local ma = credit_row:get("text_message_instance", f, "a") or 1
    local _, cr = credit_row:at("text_message_instance_2", f)
    local yellow = (cr and cr / 256.0) or 0.0          -- 0 = black outline, 1 = (256,236,67)
    local msg = self.text_credit_msg
    if msg and ma > 0.002 then
        local x = MSG_INK_X - msg.width / 2
        local y = cy + TEXT_INK_DY - msg.height / 2
        msg:draw({ x = x, y = y, fade = a * ma })
        if yellow > 0.001 and self.text_credit_msg_hl then
            self.text_credit_msg_hl:draw({ x = x, y = y, fade = a * ma * yellow })
        end
    end
end

function Entry:draw_credit(a, sel, blink_f, flash_row, flash_a, loop_rows)
    for row = 1, 2 do
        local armed = (row == sel)
        local ra = (sel == nil or sel == 0 or armed) and a or (a * DIM_UNSELECTED)
        local rf = (armed or loop_rows) and blink_f or ROW_LOOP_F0
        self:draw_credit_row(row, rf, ra)
    end
    local now = tex.get_current_ms()
    if sel and sel > 0 then
        local pulse = 0.08 + 0.10 * math.sin((now - self.cr_blink_t0) * 0.006)
        tex.draw_texture(self.cr_flash, { index = sel - 1, fade = a * pulse })
    end


    if flash_row and flash_a and flash_a > 0.002 then
        tex.draw_texture(self.cr_flash, { index = flash_row - 1, fade = a * flash_a })
    end
end

-- the 1P / 2P rows; arcade = waiting for a drum (both rows blink), else the side select cursor after an
-- online login (`side` 0 / 1 / 2 = 1P / none / 2P)
function Entry:draw_credit_rows(side, arcade)
    local now = tex.get_current_ms()
    __hss_entry_guide = { ms = now, phase = "side" }
    if side ~= self.cr_side then
        self.cr_side     = side
        self.cr_blink_t0 = now          -- a newly armed row restarts its attract cycle
    end
    self.cr_seen_frame = self.cr_frame
    self.cr_decide_t0  = nil

    local fi = math.min(15, 5 + (now - self.cr_t0) * 0.06)
    local a  = credit_fade:get("player1_text_instance", fi, "a") or 1.0

    local sel = (not arcade) and ((side == 0 and 1) or (side == 2 and 2) or 0) or nil
    local blink_f = ROW_LOOP_F0 + ((now - self.cr_blink_t0) * 0.06) % ROW_LOOP_LEN
    self:draw_credit(a, sel, blink_f, nil, nil, arcade)
    -- depth 28 > depth 23: the guide sits OVER the credit rows.
    self:draw_control_guide()
    YD_ENTRY_CREDIT_MS = now
end

function Entry:draw_side_select_buttons(side)
    __hss_entry_guide = { ms = tex.get_current_ms(), phase = "side" }
    self:draw_box_buttons(side, self.side_select_fade.attribute, nil)
end
function Entry:draw_waiting() self:draw_credit_rows(1, true) end

function Entry:draw_footer(p1_joined, p2_joined)
    YD_ENTRY_BOTH_JOINED = (p1_joined == true and p2_joined == true)
    self.any_joined = (p1_joined == true or p2_joined == true)
end

function Entry:draw_player_entry()
    self:draw_credit_decide()
    self:draw_box_decide()
end

function Entry:decide_side_select(side)
    local now = tex.get_current_ms()
    if self.box_ms and now - self.box_ms < 100 then
        self.box_decide = { t0 = now, side = side }
        return
    end
    self.cr_pending_decide = (side == 2) and 2 or 1
end

function Entry:draw_credit_decide()
    local now = tex.get_current_ms()
    if self.cr_seen_frame ~= nil and self.cr_decide_t0 == nil then
        if self.cr_frame > self.cr_seen_frame then
            self.cr_seen_frame = nil
            if self.cr_pending_decide then
                -- the engine told us which row entered (drum join or side select)
                self.cr_decide_t0      = now
                self.cr_decide_row     = self.cr_pending_decide
                self.cr_pending_decide = nil
            elseif self.cr_side == 0 or self.cr_side == 2 then
                -- cursor model: side 1 is 「つかわない」 -- cancelled, not decided.
                self.cr_decide_t0  = now
                self.cr_decide_row = (self.cr_side == 0) and 1 or 2
            end
        end
    end
    if self.cr_decide_t0 == nil then return end

    local t       = (now - self.cr_decide_t0) * 0.06                 -- frames since decide
    local flash_a = credit_row:get("#8@4", 125 + math.min(t, DECIDE_FLASH_F), "a") or 0
    local fade_f  = 16 + math.max(0, t - (DECIDE_FLASH_F + 1))       -- fade_out starts after
    local a       = credit_fade:get("player1_text_instance", math.min(fade_f, 35), "a") or 0
    if a <= 0.002 then
        self.cr_decide_t0 = nil
        return
    end
    self:draw_credit(a, nil, ROW_LOOP_F0, self.cr_decide_row, flash_a)
    YD_ENTRY_CREDIT_MS = now
end
