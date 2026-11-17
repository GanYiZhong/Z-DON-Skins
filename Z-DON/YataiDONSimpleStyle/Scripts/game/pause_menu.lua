-- YataiDONSimpleStyle: the pause menu (engine pause_menu.cpp, upstream 1cd3844; every play screen).
-- PauseMenu:draw(index, t) while the menu is open: index 0 resume / 1 restart / 2 quit, t = ms since it
-- opened. The engine keeps the input and draws the 3-2-1 countdown after "resume" itself.
-- A dither scrim, then one dialog: the gold title band, "this score will not be saved", three stacked buttons
-- (the focused one gold with a blinking ▶), opening in UI.open_rect's 3 steps.
local UI = require("global.ss_ui")
local P, U = UI.P, UI.U

PauseMenu = {}
PauseMenu.__index = PauseMenu

local ROWS = { "pm_resume", "pm_restart", "pm_quit" }
local W, BTN_W, BTN_H, GAP = 600, 432, 60, 15
local TITLE_H = 20 * U

function PauseMenu.new()
    return setmetatable({ last_index = nil, moved_ms = 0 }, PauseMenu)
end

function PauseMenu:draw(index, t)
    UI.wipe(2, P.shade)
    local h = TITLE_H + 15 * U + #ROWS * BTN_H + (#ROWS - 1) * GAP + 10 * U
    h = math.ceil(h / U) * U
    local x0, y0 = UI.grid(960 - W / 2), UI.grid(540 - h / 2)
    local x, y, w, hh, done = UI.open_rect(x0, y0, W, h, t)
    if not x then return end
    local ix, iy, iw, ih = UI.chrome.dialog(x, y, w, hh)
    if not done then return end
    UI.rect(ix, iy, iw, TITLE_H, P.focus)
    UI.draw_text(UI.text_key("pm_title", 36, "ink"), ix + iw / 2, iy + TITLE_H / 2, "c")
    UI.draw_text(UI.text_key("pm_note", 24, { color = P.text2, outline = false }), ix + iw / 2,
        iy + TITLE_H + 7 * U, "c")
    if index ~= self.last_index then
        self.last_index, self.moved_ms = index, t
    end
    local by = iy + TITLE_H + 15 * U
    local bx = UI.grid(ix + (iw - BTN_W) / 2)
    for i, key in ipairs(ROWS) do
        local focused = (i - 1) == index
        local cx, cy, cw, ch = UI.chrome.button(bx, by, BTN_W, BTN_H, focused and "focused" or "normal")
        UI.draw_text(UI.text_key(key, 36, "ink"), cx + cw / 2, cy + ch / 2, "c")
        if focused and UI.blink_on(t - self.moved_ms, 400) then
            -- ▶ left of the focused button
            local ax, acy = bx - 6 * U, UI.grid(by + BTN_H / 2)
            for k = 0, 2 do
                local hgt = (3 - k) * 2 - 1
                UI.rect(ax + k * U, acy - (hgt * U - U) / 2, U, hgt * U, P.ink)
            end
        end
        by = by + BTN_H + GAP
    end
end
