-- YataiDONSimpleStyle: 段位道場 gauge threshold plate + captions + threshold marker.
-- Nijiiro's dan_info.lua (same interface, same plate / marker geometry, same g_dan_gauge_border
-- hand-off) with the captions drawn as SimpleStyle engine text: UI.text(.., "on_ink") = paper with
-- NO outline (Nijiiro's #000000 / #503C2D outlines left a halo on our ink chips: review r4 G3'),
-- each centred in an ink chip sized to it (the plate art: ss/v2_game.py build_dan, body + arrow only).
-- Owner: the game module (it draws the plate art). The file lives in the stage module's
-- Scripts/background folder only because background.lua requires it from there.
local UI = require("global.ss_ui")

local M = {}
M.__index = M

local GAUGE_Y     = 248
local GAUGE_X0    = 738    -- cell 1 starts here
local CELL_PITCH  = 21
local CELL_COUNT  = 50
local PLATE_W, PLATE_H = 586, 60    -- the plate's grey body; the art adds a 9 px margin
local PLATE_ART_PAD    = 9          -- (the pill's top/left edge and the drop shadow)
local PLATE_GAP        = 12           -- px between the plate's bottom and the bar top
local PLATE_OVERHANG   = 24           -- px the plate extends PAST the threshold

-- caption centres, plate-body-local (= the plate art's chip centres), and UI.text role sizes
local NAME_CX, NAME_CY   = 150, 21
local VALUE_CX, VALUE_CY = 477, 30
local NAME_SIZE, VALUE_SIZE = 18, 24

-- the threshold marker (gauge_border_cell): its white inside (x 7, y 7 in the art) lands on
-- the threshold cell's left edge + 1, from y 238, as the cabinet's border_N
local MARKER_INNER_X, MARKER_INNER_Y = 7, 7
local MARKER_Y = 238

-- "70 ％以上" (space + full-width ％) reads as a double space in the pixel font: "70%以上",
-- the same join as dan result (exam_threshold_text)
local function threshold_text(red)
    local fmt = tex.skin_text("dan_exam_text_gauge"):gsub("%%%%", "\1")
    if fmt == "" then fmt = UI.t("dan_fmt_more") or "%s" end
    local out = fmt:gsub("%%s", tostring(red)):gsub("\1", "%%")
    out = out:gsub(" ?\239\188\133", "%%"):gsub(" %%", "%%")
    return out
end

function M.new()
    return setmetatable({ state = nil, label = nil, label_for = nil,
                          name_label = nil, plate = nil, plate_tried = false,
                          marker = nil, marker_tried = false }, M)
end

function M:plate_id()
    if not self.plate_tried then
        self.plate_tried = true
        self.plate = tex.get_texture("game/dan_info/gauge_border_plate")
    end
    return self.plate
end

function M:marker_id()
    if not self.marker_tried then
        self.marker_tried = true
        self.marker = tex.get_texture("game/dan_info/gauge_border_cell")
    end
    return self.marker
end

local function gauge_exam(state)
    if not state or not state.exams then return nil end
    for _, e in ipairs(state.exams) do
        if e.type == "gauge" then return e end
    end
    return nil
end

-- Called from Background:handle_dan.
function M:handle(state)
    self.state = state
    local ex = gauge_exam(state)
    _G.g_dan_gauge_border = (ex and ex.red and ex.red > 0)
        and math.max(1, math.min(CELL_COUNT, math.floor(ex.red / 2))) or nil
end

-- Called from Background:draw_fore(), i.e. after the whole GAME_DAN HUD.
function M:draw()
    local st = self.state
    if not st then return end
    local ex = gauge_exam(st)
    if not ex or not ex.red or ex.red <= 0 then return end

    -- the threshold, on the gauge's own 50-cell grid (2 % quantised)
    local pct = ex.red
    local n = math.floor(pct / 2)
    if n < 1 then n = 1 end                      -- border_0 == border_1 on the cabinet
    if n > CELL_COUNT then n = CELL_COUNT end    -- dan.json may say >100 %; the cabinet cannot
    local x = GAUGE_X0 + CELL_PITCH * n - CELL_PITCH / 2 - 1

    if self.label_for ~= ex.red then
        self.label = UI.text(threshold_text(ex.red), VALUE_SIZE, "on_ink")
        self.name_label = UI.text(tex.skin_text("dan_gauge_name"), NAME_SIZE, "on_ink")
        self.label_for = ex.red
    end

    local pid = self:plate_id()
    -- the plate overhangs the threshold by 24 px (the baked arrow lands ON it)
    -- and floats PLATE_GAP above the bar
    local px = math.max(0, math.floor(x - PLATE_W + PLATE_OVERHANG + 0.5))
    local py = GAUGE_Y - PLATE_GAP - PLATE_H
    if pid then
        tex.draw_texture(pid, { x = px - PLATE_ART_PAD, y = py - PLATE_ART_PAD })
    end

    -- the two ink chips, sized to the captions in the player's language (2U-symmetric about their
    -- centres, 5U text padding each side; the value chip stays inside the plate body), then the words
    local U = UI.U
    local function chip(t, cx, cy, half_h)
        if not t then return cx end
        local w = math.ceil(((t.width - 2 * UI.text_pad(t)) + 10 * U) / (2 * U)) * 2 * U
        cx = math.min(cx, PLATE_W - 2 * U - w / 2)
        UI.rect(px + cx - w / 2, py + cy - half_h, w, 2 * half_h, UI.P.ink)
        return cx
    end
    local ncx = chip(self.name_label, NAME_CX, NAME_CY, 5 * U)
    local vcx = chip(self.label, VALUE_CX, VALUE_CY, 7 * U)
    UI.draw_text(self.name_label, px + ncx, py + NAME_CY, "c")
    UI.draw_text(self.label, px + vcx, py + VALUE_CY, "c")
end

-- The threshold marker, drawn over the lane's frame as on the cabinet (it reaches below the
-- gauge), so from Background:draw_fore() rather than with the plate in the gauge layer.
function M:draw_marker()
    local ex = gauge_exam(self.state)
    if not ex or not ex.red or ex.red <= 0 then return end
    local n = math.max(1, math.min(CELL_COUNT, math.floor(ex.red / 2)))
    local mid = self:marker_id()
    if not mid then return end
    local cell_left = GAUGE_X0 + CELL_PITCH * (n - 1)
    tex.draw_texture(mid, { x = cell_left + 1 - MARKER_INNER_X, y = MARKER_Y - MARKER_INNER_Y })
end

return M
