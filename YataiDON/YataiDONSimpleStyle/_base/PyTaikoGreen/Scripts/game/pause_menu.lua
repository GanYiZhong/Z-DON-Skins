PauseMenu = {}
PauseMenu.__index = PauseMenu

local S = tex.get_screen_scale()
local OPEN_MS, TINT_ALPHA = 220, 170
local ROW_GAP, NOTE_GAP = 12 * S, 14 * S
local WHITE, BLACK = { 255, 255, 255, 255 }, { 0, 0, 0, 255 }
local ROWS = { "pause_menu_resume", "pause_menu_restart", "pause_menu_quit" }

function PauseMenu.new()
    return setmetatable({
        panel = tex.get_texture("entry/afk/panel"),
        box = tex.get_texture("settings/box/box"),
        box_selected = tex.get_texture("settings/box/box_highlight"),
        lang = nil,
    }, PauseMenu)
end

function PauseMenu:texts()
    local lang = tex.language()
    if self.lang == lang then return end
    self.lang = lang
    local fs = math.floor(36 * S)
    self.rows = {}
    for i, key in ipairs(ROWS) do
        self.rows[i] = text.create_raw_text(tex.skin_text(key), fs, WHITE, BLACK, false)
    end
    self.note = text.create_raw_text(tex.skin_text("pause_menu_note"), math.floor(28 * S), WHITE, BLACK, false)
end

function PauseMenu:draw(index, t)
    self:texts()
    local W, H = tex.get_screen_width(), tex.get_screen_height()
    local p = math.min(t / OPEN_MS, 1)
    p = 1 - (1 - p) ^ 3

    tex.draw_rect(0, 0, W, H, 0, 0, 0, math.floor(TINT_ALPHA * p))

    local pi = tex.get_texture_info("afk", "panel")
    local pw, ph = pi.x2[1], pi.y2[1]
    local px, py = (W - pw) / 2, (H - ph) / 2
    local ox, oy = tex.get_draw_offset()
    local vis = pw * p
    tex.begin_scissor(px + (pw - vis) / 2 + ox, py + oy, vis, ph)

    tex.draw_texture(self.panel, { x = px - pi.x[1], y = py - pi.y[1] })

    local bi = tex.get_texture_info("box", "box")
    local bw, bh = bi.x2[1], bi.y2[1]
    local top = py + (ph - (#ROWS * bh + (#ROWS - 1) * ROW_GAP)) / 2
    for i = 1, #ROWS do
        local bx, by = px + (pw - bw) / 2, top + (i - 1) * (bh + ROW_GAP)
        tex.draw_texture(i - 1 == index and self.box_selected or self.box, { x = bx, y = by })
        local label = self.rows[i]
        label:draw({ x = bx + (bw - label.width) / 2, y = by + (bh - label.height) / 2 })
    end
    tex.end_scissor()

    if p >= 1 then
        self.note:draw({ x = (W - self.note.width) / 2, y = py - NOTE_GAP - self.note.height })
    end
end
