-- YataiDONSimpleStyle v2: combo announce (100 / 200 / ... / 1000+) as the portrait mascot's speech
-- bubble: the bubble (combo/announce_bg_*, tail pointing left at the mascot's mouth), the number in
-- 48 px gold-outlined block digits and "コンボ!" (36 px ink engine text in the player's language). The bubble opens in 3 frames (1U steps
-- down into place, bible 2.7) and the engine's fade_value closes it.

local UI = require("global.ss_ui")
local U = UI.U

ComboAnnounce = {}
ComboAnnounce.__index = ComboAnnounce

local BODY_X0, BODY_X1 = 264 + 36, 264 + 420   -- bubble body (screen x)
local BODY_Y0, BODY_Y1 = 36, 144                -- frame-local body rows (frame top = y - 264)
local CELL = 104
local PITCH = 66
-- texture.json position of the digit strip (draw x / y are offsets from it)
local DIGIT_X, DIGIT_Y = 362, -196

function ComboAnnounce.new(combo, player_num)
    local self = setmetatable({}, ComboAnnounce)
    local suffix = player_num .. "p"
    self.t_bg    = tex.get_texture("game/combo/announce_bg_" .. suffix)
    self.t_digit = tex.get_texture("game/combo/announce_digit_" .. suffix)
    self.number  = tostring(combo)
    self.t0 = nil
    return self
end

function ComboAnnounce:draw(y, fade_value)
    fade_value = UI.solid(fade_value)   -- alpha policy: shown or gone, never translucent
    if fade_value == 0 then return end
    if not self.t_bg then return end
    local now = tex.get_current_ms()
    self.t0 = self.t0 or now
    local f = math.floor((now - self.t0) / 16.67)
    local drop = (f < 3) and (3 - f) * U or 0
    local yy = y - drop
    tex.draw_texture(self.t_bg, { y = yy, fade = fade_value })

    local top = yy - 264
    local cy = top + (BODY_Y0 + BODY_Y1) / 2
    local n = #self.number
    -- "コンボ!" in the player's language: 36 px ink engine text after the digits (12 px gap), the
    -- digits + word centred in the bubble body
    local t = UI.text_key("combo_announce", 36, "ink")
    local text_w = t and (t.width - 2 * UI.text_pad(t)) or 0
    local w = n * PITCH + 12 + text_w
    local x = math.floor(((BODY_X0 + BODY_X1) / 2 - w / 2) / U) * U
    if self.t_digit then
        for i = 1, n do
            tex.draw_texture(self.t_digit, {
                frame = tonumber(self.number:sub(i, i)),
                x = x + (i - 1) * PITCH - (CELL - PITCH) / 2 - DIGIT_X,
                y = cy - CELL / 2 - DIGIT_Y, fade = fade_value,
            })
        end
    end
    UI.draw_text(t, x + n * PITCH + 12 - UI.text_pad(t), cy, "l", fade_value)
end

return ComboAnnounce
