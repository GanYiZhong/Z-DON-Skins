-- 段位道場 exam-panel extras only Lua can draw: the soul-gauge pass-threshold
-- callout plate + captions and the white threshold marker on the threshold cell, anchored
-- on the gauge's own 50-cell grid. It also hands the threshold (in cells) to the gauge script
-- (g_dan_gauge_border), which colours the track by it.
local M = {}
M.__index = M

local GAUGE_Y     = 248
local GAUGE_X0    = 738    -- cell 1 starts here
local CELL_PITCH  = 21
local CELL_COUNT  = 50
local LABEL_SIZE = 30                     -- arcade ＭＳ 明朝 36; ours reads heavier
local WHITE = { 255, 255, 255, 255 }
local BLACK = { 0, 0, 0, 255 }

local PLATE_W, PLATE_H = 586, 60    -- the plate's grey body; the art adds a 9 px margin
local PLATE_ART_PAD    = 9          -- (the pill's top/left edge and the drop shadow)
local PLATE_GAP        = 12           -- px between the plate's bottom and the bar top
local PLATE_OVERHANG   = 24           -- px the plate extends PAST the threshold

local PILL_CX, PILL_CY = 150, 20      -- 魂ゲージ ink centre, plate-local
local VALUE_RIGHT      = 532          -- 100%以上 is RIGHT-aligned to this
local VALUE_CY         = 35           -- its ink centre y, plate-local
local NAME_SIZE        = 26           -- arcade id 142
local VALUE_SIZE       = 36           -- arcade id 141

-- the threshold marker (gauge_border_cell): its white inside (x 7, y 7 in the art) lands on
-- the threshold cell's left edge + 1, from y 238, as the cabinet's border_N
local MARKER_INNER_X, MARKER_INNER_Y = 7, 7
local MARKER_Y = 238

local CAP_FILL      = { 255, 255, 255, 255 }
local CAP_OUTLINE   = { 80, 60, 45, 255 }    -- #503C2D
local VALUE_OUTLINE = { 0, 0, 0, 255 }

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
        -- skin_config: dan_gauge_name (魂ゲージ) and dan_exam_text_gauge ("%s ％以上", %% = %)
        local fmt = tex.skin_text("dan_exam_text_gauge"):gsub("%%%%", "\1")
        local caption = fmt:gsub("%%s", tostring(ex.red)):gsub("\1", "%%")
        self.label = text.create_raw_text(caption,
                                          VALUE_SIZE, CAP_FILL, VALUE_OUTLINE, false,
                                          4.0 / tex.get_screen_scale())
        self.name_label = text.create_raw_text(tex.skin_text("dan_gauge_name"),
                                          NAME_SIZE, CAP_FILL, CAP_OUTLINE, false,
                                          3.0 / tex.get_screen_scale())
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

    -- fail soft: with no plate art the two captions still draw, at the same places
    if self.name_label then
        self.name_label:draw({
            x = math.floor(px + PILL_CX - self.name_label.width / 2 + 0.5),
            y = math.floor(py + PILL_CY - self.name_label.height / 2 + 0.5),
        })
    end
    if self.label then
        -- tx_border is RIGHT-aligned; its box's right edge is plate-local 532
        self.label:draw({
            x = math.floor(px + VALUE_RIGHT - self.label.width + 0.5),
            y = math.floor(py + VALUE_CY - self.label.height / 2 + 0.5),
        })
    end
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
