local S = tex.get_screen_scale()
local WHITE = { 255, 255, 255, 255 }
local BLACK = { 0, 0, 0, 255 }

local FONT_SIZE = math.floor(24 * S)
local MARGIN = 24 * S
local CORNER = 32 * S
local MIN_H = 72 * S
local HOLD_MS, FADE_MS = 2200, 250

-- rest position and natural size of each slice in Graphics/global/toast/texture.json, in 1280-wide pixels
local SLICES = {
    { "top_left", 0, 0, 64, 64, "corner", "corner" },
    { "top_right", 400, 0, 64, 64, "corner", "corner" },
    { "bottom_left", 0, 180, 64, 64, "corner", "corner" },
    { "bottom_right", 400, 180, 64, 64, "corner", "corner" },
    { "top", 64, 0, 336, 64, "fill", "corner" },
    { "bottom", 64, 180, 336, 64, "fill", "corner" },
    { "left", 0, 64, 64, 116, "corner", "fill" },
    { "right", 400, 64, 64, 116, "corner", "fill" },
    { "center", 64, 64, 336, 116, "fill", "fill" },
}

Toast = {}
Toast.__index = Toast

function Toast.new()
    local self = setmetatable({ now = 0, shown_ms = 0, label = nil, boxes = {} }, Toast)
    for _, side in ipairs({ "1p", "2p" }) do
        local pieces = {}
        for i, s in ipairs(SLICES) do
            pieces[i] = tex.get_texture("global/toast/" .. s[1] .. "_" .. side)
        end
        self.boxes[side] = pieces
    end
    return self
end

function Toast:show(message)
    self.label = text.create_raw_text(message, FONT_SIZE, WHITE, BLACK, false, 4, 2.0)
    self.shown_ms = self.now
end

function Toast:update(current_ms)
    self.now = current_ms
    if self.label and current_ms - self.shown_ms > HOLD_MS + FADE_MS then
        self.label = nil
    end
end

local function draw_box(pieces, x, y, w, h, fade)
    local xs = { x, x + CORNER, x + w - CORNER }
    local ys = { y, y + CORNER, y + h - CORNER }
    local mid_w, mid_h = w - CORNER * 2, h - CORNER * 2
    for i, s in ipairs(SLICES) do
        local _, rx, ry, nw, nh, wk, hk = table.unpack(s)
        local px = rx == 0 and xs[1] or (rx == 400 and xs[3] or xs[2])
        local py = ry == 0 and ys[1] or (ry == 180 and ys[3] or ys[2])
        local pw = wk == "corner" and CORNER or mid_w
        local ph = hk == "corner" and CORNER or mid_h
        tex.draw_texture(pieces[i], {
            x = px - rx * S, y = py - ry * S,
            x2 = pw - nw * S, y2 = ph - nh * S,
            fade = math.min(fade, 0.75),
        })
    end
end

function Toast:draw()
    if not self.label then return end
    local age = self.now - self.shown_ms
    local fade = math.max(0, math.min(1, age / FADE_MS, (HOLD_MS + FADE_MS - age) / FADE_MS))

    local w = self.label.width + CORNER * 2
    local h = math.max(MIN_H, self.label.height + CORNER)
    local side = tex.player_num() == 2 and "2p" or "1p"
    draw_box(self.boxes[side], MARGIN, MARGIN, w, h, fade)
    self.label:draw({ x = MARGIN + CORNER, y = MARGIN + (h - self.label.height) / 2, fade = fade })
end
