MacPopup = {}
MacPopup.__index = MacPopup

local S = tex.get_screen_scale()
local FADE_MS = 250
local DELAY_MS = 1000
local SELECT_S = 20
local BORDER_MS, BORDER_ON_MS = 1000, 683
local ARROW_MS, ARROW_DX = 1000, 10 * S
local BUTTON_X = { 321 * S, 655 * S }
local ARROW_X = { 626 * S, 605 * S }
local LABEL_X, LABEL_Y = { 473, 807 }, 426
local DIGIT_PITCH, DIGIT_SCALE, TIMER_CX = 25 * S, 0.64, 1006 * S
local VOICE = "happy_set"
local NO, YES = 1, 2
local LEFT, RIGHT, DECIDE = 1, 2, 3

local WHITE, BLACK = { 255, 255, 255, 255 }, { 0, 0, 0, 255 }

local function clamp01(v) return math.max(0.0, math.min(1.0, v)) end

local function lines(key, size)
    local out = {}
    for line in tex.skin_text(key):gmatch("[^\n]+") do
        out[#out + 1] = text.create_raw_text(line, math.floor(size * S), WHITE, BLACK, false, 5, 2.0)
    end
    return out
end

local function draw_lines(list, cx, cy, pitch, max_w, fade)
    for i, t in ipairs(list) do
        local y = (cy + (i - (#list + 1) / 2) * pitch) * S
        local scale = math.min(1, max_w * S / t.width)
        t:draw({ x = cx * S - t.width / 2, y = y - t.height / 2, scale = scale, fade = fade })
    end
end

function MacPopup.new()
    local self = setmetatable({}, MacPopup)
    self.tex = {}
    for _, key in ipairs({ "box", "button_red", "button_yellow", "border", "logo", "notes", "title", "period", "arrow",
                           "timer_glow", "timer", "digits" }) do
        self.tex[key] = tex.get_texture("entry/campaign/mac_" .. key)
    end
    self.desc = lines("campaign_mac_desc", 31)
    self.label = { lines("campaign_mac_no", 29), lines("campaign_mac_yes", 29) }
    self.current = NO
    self.t0 = tex.get_current_ms()
    self.now = self.t0
    self.border_t0 = self.t0 + FADE_MS + DELAY_MS
    self.decided = nil
    return self
end

function MacPopup:ready() return self.now >= self.t0 + FADE_MS + DELAY_MS end

function MacPopup:seconds_left()
    local el = math.max(0, self.now - (self.t0 + FADE_MS + DELAY_MS))
    return math.max(0, SELECT_S - math.floor(el / 1000))
end

function MacPopup:update(current_ms)
    self.now = current_ms
    if not self.voiced and self.now - self.t0 >= FADE_MS then -- played when the fade-in ends
        self.voiced = true
        if audio.has_sound(VOICE) then audio.play_sound(VOICE, "voice") end
    end
    if not self.decided and self:ready() and self:seconds_left() == 0 then
        self.decided = self.now
    end
end

function MacPopup:input(action)
    if self.decided or not self:ready() then return false end
    if action == DECIDE then
        self.decided = self.now
        return true
    end
    local target = action == LEFT and NO or YES
    if target == self.current then return false end
    self.current = target
    self.border_t0 = self.now -- border blink restarts on the new button
    return true
end

function MacPopup:is_done() return self.decided ~= nil and self.now - self.decided >= FADE_MS end
function MacPopup:get_choice() return self.current == YES and "mac" or "skip" end

function MacPopup:draw()
    local fade = clamp01((self.now - self.t0) / FADE_MS)
    if self.decided then fade = 1 - clamp01((self.now - self.decided) / FADE_MS) end
    local t = self.tex

    tex.draw_texture(t.box, { fade = fade })
    for i, x in ipairs(BUTTON_X) do
        tex.draw_texture(i == self.current and t.button_yellow or t.button_red, { x = x, fade = fade })
    end
    if self:ready() and not self.decided and (self.now - self.border_t0) % BORDER_MS < BORDER_ON_MS then
        tex.draw_texture(t.border, { x = BUTTON_X[self.current], fade = fade })
    end
    for i, x in ipairs(LABEL_X) do
        draw_lines(self.label[i], x, LABEL_Y, 0, 270, fade)
    end
    for _, key in ipairs({ "logo", "notes", "title", "period" }) do
        tex.draw_texture(t[key], { fade = fade })
    end
    draw_lines(self.desc, 566, 320.5, 52, 730, fade)

    -- arrow drifts towards the other button, fading over the second half of its loop
    local u = ((self.now - self.t0) % ARROW_MS) / ARROW_MS
    local dir = self.current == NO and 1 or -1
    tex.draw_texture(t.arrow, { x = ARROW_X[self.current] + dir * ARROW_DX * u,
                                fade = fade * math.min(1, 2 * (1 - u)),
                                mirror = self.current == NO and "horizontal" or nil })

    tex.draw_texture(t.timer_glow, { scale = 0.8, fade = fade * 0.3 })
    tex.draw_texture(t.timer, { scale = 0.8, fade = fade })
    local s = tostring(self:seconds_left())
    local left = TIMER_CX - (#s * DIGIT_PITCH) / 2 - (48 * S * DIGIT_SCALE - DIGIT_PITCH) / 2
    for i = 1, #s do
        tex.draw_texture(t.digits, { frame = tonumber(s:sub(i, i)), x = left + (i - 1) * DIGIT_PITCH,
                                     scale = DIGIT_SCALE, fade = fade })
    end
end
