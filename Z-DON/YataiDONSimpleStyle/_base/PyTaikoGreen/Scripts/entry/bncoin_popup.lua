BanaCoinPopup = {}
BanaCoinPopup.__index = BanaCoinPopup

local S = tex.get_screen_scale()
local F = 1000 / 60
local FADE_MS = 10 * F
local NOTICE_MS = 210 * F
local TOUCH_MS = 210 * F + 15000
local CONFIRM_S = 20
local LEFT, RIGHT, DECIDE = 1, 2, 3
local USE, NOT_USE = 1, 2

local WHITE, BLACK = { 255, 255, 255, 255 }, { 0, 0, 0, 255 }
local NOTICE_FONT, NOTICE_PITCH, NOTICE_MAX_W = 48, 52.5, 620

-- warning icon offset from its rest (the shortage spot), text left x and line centres
local NOTICES = {
    shortage  = { se = "bncoin_notenough", warn = { 0, 0 }, key = "bncoin_shortage", x = 429, y = 249.85,
                  balance = { dy = 0, cx = 722, cy = 380 } },
    remain    = { se = "bncoin_popup", balance = { dy = -30, cx = 722, cy = 350 }, note = true },
    onlyplay  = { se = "bncoin_onlysingle", warn = { -47, 107.65 }, key = "bncoin_onlyplay", x = 379, y = 360 },
    cantuse   = { se = "bncoin_offline", warn = { 23, 107.65 }, key = "bncoin_cantuse", x = 449, y = 357.25 },
    cantplay  = { se = "bncoin_na", warn = { 23, 107.15 }, key = "bncoin_cantplay", x = 449, y = 359 },
    firstplay = { se = "bncoin_na", warn = { -56, 107.15 }, key = "bncoin_firstplay", x = 369, y = 357.25 },
    cantshop  = { se = "bncoin_na", ad = true },
    touch     = {},
}

-- digit slot centres from the number's right edge; slot 4 is the comma
local SLOTS = { 0, -42, -84, -114, -144.5, -186.5, -228.5 }
local COMMA = 10

local CONFIRM_CX, BUTTON_DX, BUTTON_Y = 640, 127.5, 440
local BORDER_MS, BORDER_ON_MS = 1000, 683
local TIMER_DX, TIMER_DY, TIMER_CX = -66.8, -112.6, 1006
local DIGIT_PITCH, DIGIT_SCALE = 25 * S, 0.64

local function clamp01(v) return math.max(0.0, math.min(1.0, v)) end

local function lines(key, size, outline)
    local out = {}
    for line in tex.skin_text(key):gmatch("[^\n]+") do
        out[#out + 1] = text.create_raw_text(line, math.floor(size * S), WHITE, BLACK, false, outline or 5, 2.0)
    end
    return out
end

-- align: "left" from x, "right" to x, else centred on x
local function draw_lines(list, x, cy, pitch, max_w, fade, align)
    for i, t in ipairs(list) do
        local scale = math.min(1, max_w * S / t.width)
        local w = t.width * scale
        local left = align == "left" and x * S or (align == "right" and x * S - w or x * S - w / 2)
        local y = (cy + (i - (#list + 1) / 2) * pitch) * S
        t:draw({ x = left, y = y - t.height * scale / 2, scale = scale, fade = fade })
    end
end

function BanaCoinPopup.new(kind, balance, cost)
    local self = setmetatable({}, BanaCoinPopup)
    self.tex = {}
    for _, key in ipairs({ "notice_box", "warn", "balance_label", "remain_note", "touch_card", "cost_line",
                           "cancel_bar", "hint_drum", "hint_rim", "hint_arrow", "digits", "banapass_ad",
                           "confirm_box" }) do
        self.tex[key] = tex.get_texture("entry/bncoin/" .. key)
    end
    for _, key in ipairs({ "button_red", "button_yellow", "button_outline", "arrow" }) do
        self.tex[key] = tex.get_texture("entry/name_entry/" .. key)
    end
    for _, key in ipairs({ "timer_glow", "timer", "digits" }) do
        self.tex["timer_" .. key] = tex.get_texture("entry/campaign/mac_" .. key)
    end
    self.text = {
        unit = lines("bncoin_unit", 33), consume = lines("bncoin_consume", 33), cancel = lines("bncoin_cancel", 29, 0),
        question = lines("bncoin_confirm_question", 32),
        use = lines("bncoin_confirm_use", 31), not_use = lines("bncoin_confirm_not_use", 31),
    }
    for name, n in pairs(NOTICES) do
        if n.key then self.text[name] = lines(n.key, NOTICE_FONT) end
    end
    self.balance, self.cost = balance, cost
    self.result = "cancel"
    self.now = tex.get_current_ms()
    self:enter(kind == "practice" and "touch" or kind)
    return self
end

function BanaCoinPopup:enter(name)
    self.stage = { name = name, t0 = self.now, sel = USE }
    local se = NOTICES[name] and NOTICES[name].se
    if se and audio.has_sound(se) then audio.play_sound(se, "sound") end
end

-- fade the current stage out, then show `next` (nil: finished)
function BanaCoinPopup:leave(next)
    if self.stage.out_t0 then return end
    self.stage.out_t0, self.stage.next = self.now, next or false
end

function BanaCoinPopup:pay()
    self.result = "pay"
    self.balance = self.balance - self.cost
    self:leave("remain")
end

function BanaCoinPopup:elapsed() return self.now - self.stage.t0 end

function BanaCoinPopup:seconds_left()
    return math.max(0, CONFIRM_S - math.floor(math.max(0, self:elapsed() - FADE_MS) / 1000))
end

function BanaCoinPopup:update(current_ms)
    self.now = current_ms
    local st = self.stage
    if self.done then return end
    if st.out_t0 then
        if self.now - st.out_t0 >= FADE_MS then
            if st.next then self:enter(st.next) else self.done = true end
        end
        return
    end
    local el = self:elapsed()
    if st.name == "touch" then
        if el >= TOUCH_MS then self:leave("confirm") end
    elseif st.name == "confirm" then
        if self:seconds_left() == 0 then self:input(DECIDE) end
    elseif el >= NOTICE_MS - FADE_MS then
        self:leave(nil)
    end
end

function BanaCoinPopup:input(action)
    local st = self.stage
    if self.done or st.out_t0 or self:elapsed() < FADE_MS then return false end
    if st.name == "touch" then
        if action == DECIDE then self:pay() else self:leave("confirm") end
        return true
    elseif st.name == "confirm" then
        if action == DECIDE then
            if st.sel == USE then self:pay() else self:leave(nil) end
            return true
        end
        local target = action == LEFT and USE or NOT_USE
        if target == st.sel then return false end
        st.sel, st.border_t0 = target, self.now
        return true
    end
    return false
end

function BanaCoinPopup:is_done() return self.done == true end
function BanaCoinPopup:get_result() return self.result end

function BanaCoinPopup:fade()
    local st = self.stage
    if st.out_t0 then return 1 - clamp01((self.now - st.out_t0) / FADE_MS) end
    return clamp01(self:elapsed() / FADE_MS)
end

function BanaCoinPopup:draw_number(n, cx, cy, fade)
    local s = tostring(math.max(0, math.floor(n)))
    local slot = 1
    for i = #s, 1, -1 do
        if slot == 4 then
            tex.draw_texture(self.tex.digits, { frame = COMMA, x = (cx + SLOTS[slot] - 25) * S, y = (cy - 39) * S,
                                                fade = fade })
            slot = slot + 1
        end
        tex.draw_texture(self.tex.digits, { frame = tonumber(s:sub(i, i)), x = (cx + SLOTS[slot] - 25) * S,
                                            y = (cy - 39) * S, fade = fade })
        slot = slot + 1
    end
end

function BanaCoinPopup:draw_hint(fade)
    local t = self.tex
    local f = (self:elapsed() / F) % 120
    local rim = f < 30 and f / 30 or (f < 60 and 0.965 * (1 - (f - 30) / 30) or 0)
    tex.draw_texture(t.hint_drum, { fade = fade })
    tex.draw_texture(t.hint_rim, { fade = fade * rim })
    tex.draw_texture(t.hint_rim, { x = 24 * S, mirror = "horizontal", fade = fade * rim })
    if f < 60 then
        tex.draw_texture(t.hint_arrow, { x = -7 * S * f / 60, fade = fade * (1 - f / 60) })
    end
end

function BanaCoinPopup:draw_notice(name, fade)
    local t, n = self.tex, NOTICES[name]
    tex.draw_texture(t.notice_box, { fade = fade })
    if n.warn then
        tex.draw_texture(t.warn, { x = n.warn[1] * S, y = n.warn[2] * S, fade = fade })
        draw_lines(self.text[name], n.x, n.y, NOTICE_PITCH, NOTICE_MAX_W, fade, "left")
    end
    if n.balance then
        tex.draw_texture(t.balance_label, { y = n.balance.dy * S, fade = fade })
        self:draw_number(self.balance, n.balance.cx, n.balance.cy, fade)
    end
    if n.note then tex.draw_texture(t.remain_note, { fade = fade }) end
    if n.ad then tex.draw_texture(t.banapass_ad, { fade = fade }) end
    if name == "touch" then
        self:draw_number(self.cost, 510.35, 250, fade)
        tex.draw_texture(t.cost_line, { fade = fade })
        draw_lines(self.text.unit, 690, 262.35, 0, 300, fade, "right")
        draw_lines(self.text.consume, 708, 262.35, 0, 300, fade, "left")
        tex.draw_texture(t.touch_card, { fade = fade })
        tex.draw_texture(t.cancel_bar, { fade = fade })
        draw_lines(self.text.cancel, 682.85, 480.3, 0, 300, fade)
        self:draw_hint(fade)
    end
end

function BanaCoinPopup:draw_confirm(fade)
    local t, st = self.tex, self.stage
    tex.draw_texture(t.confirm_box, { fade = fade })
    draw_lines(self.text.question, CONFIRM_CX, 170, 0, 700, fade)
    local ready = self:elapsed() >= FADE_MS and not st.out_t0
    local border_t0 = st.border_t0 or (st.t0 + FADE_MS)
    for i = 1, 2 do
        local cx = CONFIRM_CX + (i == USE and -BUTTON_DX or BUTTON_DX)
        local on = i == st.sel
        tex.draw_texture(on and t.button_yellow or t.button_red,
            { x = (cx - 128) * S, y = (BUTTON_Y - 40) * S, fade = fade })
        if on and ready and (self.now - border_t0) % BORDER_MS < BORDER_ON_MS then
            tex.draw_texture(t.button_outline, { x = (cx - 128) * S, y = (BUTTON_Y - 40) * S, fade = fade })
        end
        draw_lines(i == USE and self.text.use or self.text.not_use, cx, BUTTON_Y, 0, 230, fade)
    end
    local ph = (self:elapsed() % 1000) / 1000
    local a = ph < 0.5 and 1.0 or (0.965 * (1 - (ph - 0.5) * 2))
    local ax = CONFIRM_CX + (st.sel == USE and (8 + 10 * ph) or -(13 + 10 * ph))
    tex.draw_texture(t.arrow, { x = (ax - 24) * S, y = (BUTTON_Y - 24) * S, fade = fade * a,
                                mirror = st.sel == USE and "horizontal" or nil })

    tex.draw_texture(t.timer_timer_glow, { x = TIMER_DX * S, y = TIMER_DY * S, scale = 0.8, fade = fade * 0.3 })
    tex.draw_texture(t.timer_timer, { x = TIMER_DX * S, y = TIMER_DY * S, scale = 0.8, fade = fade })
    local s = tostring(self:seconds_left())
    local left = (TIMER_CX + TIMER_DX) * S - (#s * DIGIT_PITCH) / 2 - (48 * S * DIGIT_SCALE - DIGIT_PITCH) / 2
    for i = 1, #s do
        tex.draw_texture(t.timer_digits, { frame = tonumber(s:sub(i, i)), x = left + (i - 1) * DIGIT_PITCH,
                                           y = TIMER_DY * S, scale = DIGIT_SCALE, fade = fade })
    end
end

function BanaCoinPopup:draw()
    if self.done then return end
    local fade = self:fade()
    if self.stage.name == "confirm" then
        self:draw_confirm(fade)
    else
        self:draw_notice(self.stage.name, fade)
    end
end
