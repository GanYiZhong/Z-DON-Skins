-- SimpleStyle v2 (meta): practice-mode time limit, top right. A panel with the 特訓 chip, のこり label,
-- 48 px digits + 分 / 秒 and a 10-segment pixbar (ink in minutes, don red in the last minute). Time up:
-- a 50 % ink dither over the screen and a dialog 「じかんぎれ！」. Everything is drawn here; the Green
-- textures of global/practice_timer are blanked.
local SSM = require("global.ss_meta")
local UI = SSM.UI
local P = UI.D.P
local U = 3

PracticeTimer = {}
PracticeTimer.__index = PracticeTimer

local X, Y, W, H = 1659, 54, 240, 120   -- text24: 6U wider, right edge kept (1899)

function PracticeTimer.new(max_seconds)
    local self = setmetatable({}, PracticeTimer)
    self.max = math.max(max_seconds, 1)
    self.l_mode = UI.text_key("pr_mode", 18)
    self.mode_w = math.max(72, math.ceil((UI.label_width("pr_mode", 18) + 6 * U) / U) * U)
    self.l_left = UI.text_key("pr_left", 18, { color = P.text2 })
    self.l_min = UI.text_key("pr_min", 24)
    self.l_sec = UI.text_key("pr_sec", 24)
    self.l_up = UI.text_key("pr_timeup", 48)
    return self
end

function PracticeTimer:draw(seconds, up_ms)
    seconds = math.max(seconds, 0)
    local minutes_mode = seconds >= 60
    local value = minutes_mode and math.min(seconds // 60, 99) or seconds
    local ix, iy, iw, ih = UI.chrome.panel(X, Y, W, H)
    -- 特訓 chip docked on the top-left corner
    local cx, cy, cw, ch = UI.chrome.chip(X - U, Y - 18, self.mode_w, 33, P.mint, false)   -- text24: 33 high (was 27)
    UI.draw_text(self.l_mode, cx + cw / 2, cy + ch / 2, "c")
    UI.draw_text(self.l_left, ix + 3 * U, iy + 33, "l")
    local s = tostring(math.floor(value))
    -- the unit (分 / min / 초 ...) right-aligned at 3U, the digits right before it (24 px words vary in width)
    local unit = minutes_mode and self.l_min or self.l_sec
    local uw = UI.draw_text(unit, ix + iw - 3 * U, iy + 60, "r")
    UI.num(s, ix + iw - 3 * U - uw - 2 * U, iy + 54, "xl", P.ink, 255, "r")
    UI.pixbar(ix + 3 * U, iy + ih - 27, iw - 6 * U, 18, seconds / self.max,
              minutes_mode and P.normal or P.don, 10, P.bg3)
    if up_ms and up_ms >= 0 then
        UI.wipe(math.min(2, 1 + math.floor(up_ms / 50)), P.ink)
        local x, y, ww, hh, full = UI.open_rect(600, 405, 720, 270, up_ms)
        if x then
            UI.chrome.dialog(x, y, ww, hh)
            if full then UI.draw_text(self.l_up, 960, 540, "c") end
        end
    end
end
