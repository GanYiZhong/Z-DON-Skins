-- YataiDONSimpleStyle v2: the result screens' word chrome, drawn at run time in the player's language
-- (result_player.lua + dan_result_draw.lua). Every chip / plate is sized to its MEASURED label
-- (UI.label_width), so en / ko words never clip; the geometry matches the baked chrome it replaces
-- (ss/v2_result.py chip_w, chrome.plate, course.plate). All coordinates LOGICAL (1920x1080).
local UI = require("global.ss_ui")
local P = UI.P
local U = UI.U

local FX = require("result.ss_result_fx")

local W = {}

-- chip height: 30 (10U) = the 24 px label (role 18 renders as 24) + 1U border each side + 1U air each side
W.CH = 30

-- chip width for a label: ink width + 2 x 4U pad + 2U border, ceiled to U (= ss/v2_result.py chip_w)
function W.chip_w(key, style)
    return math.ceil((UI.label_width(key, 18, style or "ink") + 10 * U) / U) * U
end

-- a chip (chrome.chip) with its label centred: accent fill, or bg3 + 1U accent edge (edge = true);
-- style "ink" (default) or "paper" (outlined: on saturated fills). w = nil: sized to the label, else at
-- least w. Returns the width.
function W.chip(key, x, y, w, accent, edge, style)
    w = math.max(w or 0, W.chip_w(key, style))
    local ix, iy, iw, ih = UI.chrome.chip(x, y, w, W.CH, accent, edge)
    UI.draw_text(UI.text_key(key, 18, style or "ink"), ix + iw / 2, iy + ih / 2, "c")
    return w
end

-- a header plate (chrome.plate, 54 tall): paper text area, accent icon cell (54) with a 1U ink divider,
-- 36 px ink text; course = draw that course's glyph in the cell (course.plate). s = a raw string.
function W.plate_w(s)
    return math.ceil((54 + 4 * U + UI.text_width(s, 36, "ink") + 5 * U) / U) * U
end

function W.plate(s, x, y, accent, course)
    local t = UI.text(s, 36, "ink")
    local w = W.plate_w(s)
    local ix, iy, iw, ih = UI.frame(x, y, w, 54, {})
    local cx1 = ix + 54 - U
    UI.rect(ix, iy, cx1 - ix, ih, accent)
    UI.rect(cx1, iy, U, ih, P.ink)
    if course then UI.course.glyph(course, (ix + cx1) / 2, iy + ih / 2, "s") end
    UI.draw_text(t, cx1 + 4 * U - UI.text_pad(t), iy + ih / 2, "l")
    return w
end

function W.course_plate(c, x, y)
    return W.plate(UI.course.name(c), x, y, UI.course.color(c), c)
end

-- the gauge end cap: the baked disc (t: frame 0 dark / 1 lit / 2 full) with 魂 on it; a word wider
-- than the disc (en "Soul") gets a 30-tall chip of the same colours instead (full = paper inner ring).
-- (x, y) = the disc cell's top-left (48 x 48).
function W.soul_cap(t, frame, x, y)
    local st = { color = frame == 0 and P.text2 or P.ink, outline = false }
    if UI.label_width("soul", 18, st) <= 30 then
        if t then tex.draw_texture(t, { frame = frame, x = x, y = y }) end
        UI.draw_text(UI.text_key("soul", 18, st), x + 24, y + 24, "c")
        return
    end
    local w = W.chip_w("soul", st)
    local ix, iy, iw, ih = UI.frame(x, y + 3 * U, w, 10 * U, { fill = frame == 0 and P.bg3 or P.clear, shadow = 0 })
    if frame == 2 then
        UI.frame(ix, iy, iw, ih, { border_c = P.paper, fill = P.clear, shadow = 0, notch = 0 })
    end
    UI.draw_text(UI.text_key("soul", 18, st), x + w / 2, y + 24, "c")
end

-- the 自己ベスト更新 banner: a gold chip (426, or wider for a long label), label on the left; returns the
-- width (the caller right-aligns the +diff digits at x + w - 6)
-- glint = ms since the banner settled (nil: none): a paper glint crosses it every 1600 ms
function W.best_banner(x, y, glint)
    local w = math.max(426, W.chip_w("best") + 30 * U)
    local ix, iy, iw, ih = UI.chrome.chip(x, y, w, W.CH, P.clear, false)
    if glint then FX.glint(ix, iy, iw, ih, glint, 1600) end
    local t = UI.text_key("best", 18, "ink")
    UI.draw_text(t, ix + 3 * U - UI.text_pad(t), iy + ih / 2, "l")
    return w
end

return W
