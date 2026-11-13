-- YataiDONSimpleStyle: the AI battle's simplified charts. After the course, four columns: three easier levels and the
-- chart as written (the engine holds the cursor; skin_config zdon_ai_support_levels turns the step on).
local UI = require("global.ss_ui")
local P, U = UI.P, UI.U

AISupportMenu = {}
AISupportMenu.__index = AISupportMenu

local FIRST_LEVEL = { [1] = 2, [2] = 6, [3] = 10 }
local COLUMNS = 4
local CELL_W, CELL_H, GAP, PAD, TITLE_H = 56 * U, 56 * U, 6 * U, 8 * U, 22 * U

function AISupportMenu.new() return setmetatable({}, AISupportMenu) end
function AISupportMenu:set_status(_) end

function AISupportMenu:draw(_, course, cursor, choosing)
    local first = FIRST_LEVEL[course]
    if not choosing or not first then return end

    local w = COLUMNS * CELL_W + (COLUMNS - 1) * GAP + 2 * PAD + 4 * U
    local h = TITLE_H + CELL_H + 2 * PAD + 4 * U
    local x, y = UI.grid(960 - w / 2), UI.grid(540 - h / 2)
    UI.rect(0, 0, 1920, 1080, P.ink, 150)
    local ix, iy = UI.chrome.dialog(x, y, w, h)
    UI.draw_text(UI.text_key("ai_support_title", 36, "ink"), 960, iy + PAD + TITLE_H / 2 - 2 * U, "c")

    local top = iy + PAD + TITLE_H
    for i = 0, COLUMNS - 1 do
        local cx = ix + PAD + i * (CELL_W + GAP)
        UI.chrome.button(cx, top, CELL_W, CELL_H, i == cursor and "focused" or "normal")
        local mid = cx + CELL_W / 2
        UI.course.glyph(course, mid, top + 16 * U, "l")
        UI.draw_text(UI.text("Lv." .. (first + i), 36, "ink"), mid, top + 36 * U, "c")
        if i == COLUMNS - 1 then
            UI.draw_text(UI.text_key("ai_support_usual", 24, "ink"), mid, top + 48 * U, "c")
        end
    end
    UI.hint({ { "ka", "h_select" }, { "don", "h_decide" } }, { y1 = y + h + 22 * U })
end

return AISupportMenu
