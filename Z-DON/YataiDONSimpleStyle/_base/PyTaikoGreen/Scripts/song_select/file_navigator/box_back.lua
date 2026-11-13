-- BackBox rendering ("back" brown board + vertical label), split out of song_select.lua.
-- Mirrors src/objects/song_select/file_navigator/box_back.cpp.

local base = require("song_select/file_navigator/box_base")

local T = base.T
local draw_shadows = base.draw_shadows
local draw_yellow_box = base.draw_yellow_box
local draw_base_closed = base.draw_base_closed

local WHITE = { 255, 255, 255, 255 }
local BLACK = { 0, 0, 0, 255 }
local OUTLINE_COLOR = { 77, 39, 0, 255 }

-- back_text / back_text_highlight (vertical), cached on self.
local function back_texts(self)
    if self._back_texts then return self._back_texts end
    local cfg = tex.get_skin_config("box_back_text") or { font_size = 40 }
    local label = tex.skin_text("box_back_text")
    if label == "" then label = "Back" end
    local back_text = text.create_raw_text(label, cfg.font_size or 40, WHITE, OUTLINE_COLOR, true, 5.0, 2.0, 1.0)
    local back_text_highlight = text.create_raw_text(label, cfg.font_size or 40, WHITE, BLACK, true, 5.0, 2.0, 1.0)
    self._back_texts = { back_text = back_text, back_text_highlight = back_text_highlight }
    return self._back_texts
end

function SongSelect:draw_back_closed(box)
    if tex.zdon_ai_select() and require("global.ai_battle").draw_list_back(box, box:box_x(), false) then return end
    draw_base_closed(box)

    local bx = box:box_x()
    local by = box:box_y()
    local fade = box.fade.attribute
    tex.draw_texture(T("box", "back_icon"), { x = bx, y = by, fade = fade })

    local texts = back_texts(self)
    local cfg = tex.get_skin_config("box_back_text") or { x = 47, y = 173 }
    texts.back_text:draw({
        x = bx + cfg.x - texts.back_text.width / 2.0,
        y = by + cfg.y,
        fade = fade
    })
end

function SongSelect:draw_back_open(box)
    if tex.zdon_ai_select() and require("global.ai_battle").draw_list_back(box, box:box_x(), true) then return end
    local bx = box:box_x()
    local by = box:box_y()
    local mfade = math.min(box.fade.attribute, box.open_fade.attribute)

    draw_shadows(bx, by, mfade, 1)

    local right_out   = tex.get_animation(10)
    local right_out_2 = tex.get_animation(14)
    local x = bx
    draw_yellow_box(false, mfade, by)
    x = x + (right_out.attribute * 0.85 - right_out.start_position * 0.85)
          + right_out_2.attribute - right_out_2.start_position

    tex.draw_texture(T("box", "back_icon_highlight"), { x = x, y = by, fade = mfade })

    local texts = back_texts(self)
    local cfg = tex.get_skin_config("box_back_text") or { x = 47, y = 173 }
    texts.back_text_highlight:draw({
        x = x + cfg.x - texts.back_text_highlight.width / 2.0,
        y = by + cfg.y,
        fade = mfade
    })
    tex.draw_texture(T("box", "back_graphic"), { x = x, y = by, fade = mfade })
end
