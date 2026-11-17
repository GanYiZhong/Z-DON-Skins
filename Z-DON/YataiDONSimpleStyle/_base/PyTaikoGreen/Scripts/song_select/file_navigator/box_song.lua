-- SongBox rendering (song board closed/open/diff-select), split out of song_select.lua.
-- Mirrors src/objects/song_select/file_navigator/box_song.cpp.

local base = require("song_select/file_navigator/box_base")
local SKIN_S = tex.get_screen_scale()
local SKIN = {
    yb_diff_offset = { x = 60 * SKIN_S, y = -17 * SKIN_S },
}

local T = base.T
local utf8_char_count = base.utf8_char_count
local draw_shadows = base.draw_shadows
local draw_yellow_box = base.draw_yellow_box
local draw_base_closed = base.draw_base_closed
local vertical_name = base.vertical_name

-- Difficulty enum (must match enums.h).
local DIFF_EASY, DIFF_NORMAL, DIFF_HARD, DIFF_ONI, DIFF_URA = 0, 1, 2, 3, 4

local BLACK = { 0, 0, 0, 255 }
local WHITE = { 255, 255, 255, 255 }
local BLANK = { 0, 0, 0, 0 }
local POPULAR_SCALE = 0.6

local function is_2p_screen()
    local screen = tex.current_screen and tex.current_screen() or ""
    return screen == "SONG_SELECT_2P" or screen == "WAIWAI_SONG_SELECT"
end

-- Build a set of vertical OutlinedText labels sized to fit one shared box (mirrors
-- build_vertical_label_set in box_song.cpp).
local function build_vertical_labels(keys, box_cfg, v_advance, font_bonus, fills, outlines, thickness)
    local labels = {}
    local max_chars = 1
    for i, key in ipairs(keys) do
        labels[i] = tex.skin_text(key)
        if labels[i] == "" then labels[i] = "?" end
        max_chars = math.max(max_chars, utf8_char_count(labels[i]))
    end
    local width_cap = box_cfg.width - 4.0
    local height_cap = (box_cfg.height - 4.0) / (1.0 + (max_chars - 1) * v_advance)
    local font_size = math.floor(math.min(width_cap, height_cap) + font_bonus)
    local out = {}
    for i = 1, #keys do
        out[i] = text.create_raw_text(labels[i], font_size, fills[i], outlines[i], true, thickness, 2.0, v_advance)
    end
    return out
end

local function scaled_box(x, y, w, h)
    local s = tex.get_screen_scale()
    return { x = x * s, y = y * s, width = w * s, height = h * s }
end

local function diff_tower_label_box() return scaled_box(475, 158, 53, 152) end
local function difficulty_bar_label_box() return scaled_box(481, 256, 26, 96) end

-- diff_tower_label (5 diffs) — static cache in C++, cached on self here.
local function diff_tower_labels(self)
    if self._diff_tower_labels then return self._diff_tower_labels end
    local cfg = diff_tower_label_box()
    local keys = { "diff_tower_easy", "diff_tower_normal", "diff_tower_hard", "diff_tower_oni", "diff_tower_ura" }
    local fills = { BLACK, BLACK, BLACK, BLACK, WHITE }
    local outlines = { BLANK, BLANK, BLANK, BLANK, { 0, 73, 90, 255 } }
    self._diff_tower_labels = build_vertical_labels(keys, cfg, 0.9, 5.0, fills, outlines, 3.0)
    return self._diff_tower_labels
end

-- difficulty_bar_label (4 diffs).
local function difficulty_bar_labels(self)
    if self._difficulty_bar_labels then return self._difficulty_bar_labels end
    local cfg = difficulty_bar_label_box()
    local keys = { "diff_tower_easy", "diff_tower_normal", "diff_tower_hard", "diff_tower_oni" }
    local colors = { BLACK, BLACK, BLACK, BLACK }
    self._difficulty_bar_labels = build_vertical_labels(keys, cfg, 0.9, 7.0, colors, colors, 0.0)
    return self._difficulty_bar_labels
end

-- The three song text objects (name, name_black, subtitle) from BaseBox::load_text +
-- SongBox::load_text, cached per box on self.
local function song_texts(self, box)
    self._song_texts = self._song_texts or {}
    local name = box.text_name or ""
    local fc = box:fore_color() or { r = 0, g = 0, b = 0, a = 255 }
    local key = box:path() .. "\0" .. tostring(fc.r or 0) .. "." .. tostring(fc.g or 0) .. "." .. tostring(fc.b or 0)
    local t = self._song_texts[key]
    if t == nil then
        local sub = box.text_subtitle or ""
        local fore = { fc.r or 0, fc.g or 0, fc.b or 0, fc.a or 255 }

        local name_cfg = tex.get_skin_config("song_select_box_name") or { font_size = 40 }
        local base_name_font = name_cfg.font_size or 40
        local name_font = base_name_font
        local name_outline = 5.0
        if utf8_char_count(name) >= 30 then
            name_font = base_name_font - 10 * tex.get_screen_scale()
            name_outline = 5.0 * (name_font / base_name_font)
        end
        local name_text = text.create_raw_text(name, name_font, WHITE, fore, true, 5.0, 2.0, 1.0)
        local name_black = text.create_raw_text(name, name_font, WHITE, BLACK, true, name_outline, 2.0, 1.0)

        local sub_cfg = tex.get_skin_config("song_select_box_subtitle") or { font_size = 30 }
        local base_sub_font = sub_cfg.font_size or 30
        local sub_font = base_sub_font
        local sub_outline = 5.0
        if utf8_char_count(sub) >= 30 then
            sub_font = base_sub_font - 10 * tex.get_screen_scale()
            sub_outline = 5.0 * (sub_font / base_sub_font)
        end
        local subtitle = text.create_raw_text(sub, sub_font, WHITE, BLACK, true, sub_outline, 2.0, 1.0)

        t = { name = name_text, name_black = name_black, subtitle = subtitle }
        self._song_texts[key] = t
    end
    return t
end

local function course_tag(info, papamama_first)
    if not (info.is_branching or info.is_papamama) then return nil end
    local cycle = math.floor(tex.get_current_ms() / 1000)
    if cycle % 2 == 1 then return nil end
    if info.is_branching and info.is_papamama then
        local second = math.floor(cycle / 2) % 2 == 1
        return (second == papamama_first) and "branch" or "papamama"
    end
    return info.is_branching and "branch" or "papamama"
end

-- draw_diff_outline (small crown outline; doubled in 2P).
local function draw_diff_outline(x, y, fade)
    if is_2p_screen() then
        local half = tex.get_texture_info("yellow_box", "s_crown_dfc")
        half = (half and half.width or 0) * 0.35
        tex.draw_texture(T("yellow_box", "s_crown_outline"), { x = x - half, y = y, fade = fade })
        tex.draw_texture(T("yellow_box", "s_crown_outline"), { x = x + half, y = y, fade = fade })
    else
        tex.draw_texture(T("yellow_box", "s_crown_outline"), { x = x, y = y, fade = fade })
    end
end

-- draw_diff_crown (small crown per diff; uses p1/p2 scores in 2P).
local function draw_diff_crown(box, diff, x, y, fade)
    local function draw_one(info, px)
        if not info.has_score then return end
        if info.crown == 3 then
            tex.draw_texture(T("yellow_box", "s_crown_dfc"),   { x = px, y = y, fade = fade })
        elseif info.crown == 2 then
            tex.draw_texture(T("yellow_box", "s_crown_fc"),    { x = px, y = y, fade = fade })
        elseif info.crown >= 1 then
            tex.draw_texture(T("yellow_box", "s_crown_clear"), { x = px, y = y, fade = fade })
        end
    end
    if is_2p_screen() then
        local half = tex.get_texture_info("yellow_box", "s_crown_dfc")
        half = (half and half.width or 0) * 0.35
        draw_one(box:course_info(diff),    x - half)
        draw_one(box:course_info_p2(diff), x + half)
    else
        draw_one(box:course_info(diff), x)
    end
end

-- draw_box_crown (the closed-state best crown; highest-difficulty score wins).
local function draw_box_crown(box, x, y, fade)
    local function highest(info_fn)
        local best_key = -1
        local best_crown = 0
        for d = 0, 4 do
            local info = info_fn(d)
            if info.has_course and info.has_score then
                if d > best_key then best_key = d; best_crown = info.crown end
            end
        end
        if best_key < 0 then return nil, nil end
        return best_crown, math.min(DIFF_URA, best_key)
    end

    local crown_1p, frame_1p = highest(function(d) return box:course_info(d) end)
    local crown_2p, frame_2p
    if is_2p_screen() then
        crown_2p, frame_2p = highest(function(d) return box:course_info_p2(d) end)
    end

    if crown_2p then
        local info = tex.get_texture_info("yellow_box", "crown_dfc")
        local half = (info and info.width or 0) * 0.35
        if crown_1p then base.draw_crown(crown_1p, frame_1p, x - half, y, fade) end
        base.draw_crown(crown_2p, frame_2p, x + half, y, fade)
    elseif crown_1p then
        base.draw_crown(crown_1p, frame_1p, x, y, fade)
    end
end

-- draw_text (the open-state name/subtitle, tracking the yellow box's expansion).
local function draw_text(box, texts)
    local right_out   = tex.get_animation(10)
    local right_out_2 = tex.get_animation(14)
    local top_y_out   = tex.get_animation(16)
    local x = box:box_x()
        + (right_out.attribute * 0.90 - right_out.start_position * 0.90)
        + right_out_2.attribute - right_out_2.start_position

    local sub_cfg = tex.get_skin_config("song_select_box_subtitle") or { x = -15, y = 545, height = 410 }
    local h = math.min(texts.subtitle.height, sub_cfg.height)
    texts.subtitle:draw({
        x = x + sub_cfg.x,
        y = sub_cfg.y - h + top_y_out.attribute - top_y_out.start_position,
        y2 = h - texts.subtitle.height,
        fade = box.open_fade.attribute
    })

    local name_cfg = tex.get_skin_config("song_select_box_name") or { x = 47, y = 129, height = 417 }
    local name_h = math.min(texts.name.height, name_cfg.height) - texts.name.height
    local name_x = x + name_cfg.x - math.floor(texts.name.width / 2)
    local name_y = name_cfg.y + top_y_out.attribute - top_y_out.start_position
    texts.name_black:draw({ x = name_x, y = name_y, y2 = name_h, fade = box.open_fade.attribute })
    texts.name:draw({ x = name_x, y = name_y, y2 = name_h, fade = 1 - box.open_fade.attribute })
end

function SongSelect:draw_song_closed(box)
    if tex.zdon_ai_select() and require("global.ai_battle").draw_list_strip(box, box:box_x(), box.fade.attribute) then return end
    draw_base_closed(box)

    local bx = box:box_x()
    local by = box:box_y()
    local fade = box.fade.attribute

    local name = vertical_name(self, box)
    local name_cfg = tex.get_skin_config("song_select_box_name") or { x = 47, y = 129, height = 417 }
    local name_x = bx + name_cfg.x - math.floor(name.width / 2)
    local name_y = name_cfg.y + by
    local name_h = math.min(name.height, name_cfg.height)
    name:draw({ x = name_x, y = name_y, y2 = name_h - name.height, fade = fade })

    if box:has_preimage() then
        tex.draw_texture(T("yellow_box", "preimage_bg"), { x = bx, y = by, fade = fade })
        local ps = tex.get_screen_scale()
        box:draw_preimage(bx + 20 * ps, by + 30 * ps, 53 * ps, 53 * ps, fade)
    elseif box:ex_data_flag() == 3 then  -- limited_time
        tex.draw_texture(T("yellow_box", "ex_data_limited_time_balloon"), { x = bx, y = by, fade = fade })
    elseif box.is_new then
        tex.draw_texture(T("yellow_box", "ex_data_new_song_balloon"), { x = bx, y = by, fade = fade })
    end

    draw_box_crown(box, bx, by, fade)

    if box.popular_rank > 0 then
        local info = tex.get_texture_info("yellow_box", "popular_rank")
        tex.draw_texture(T("yellow_box", "popular_rank"), {
            frame = box.popular_rank - 1, x = bx, y = by, fade = fade,
            x2 = info.width * (POPULAR_SCALE - 1), y2 = info.height * (POPULAR_SCALE - 1),
        })
    end
end

function SongSelect:draw_song_open(box)
    if tex.zdon_ai_select() and require("global.ai_battle").draw_list_card(box, box:box_x(), box.open_fade.attribute) then return end
    local bx = box:box_x()
    local by = box:box_y()
    local open_fade = box.open_fade.attribute

    draw_shadows(bx, by, open_fade, 1)
    draw_yellow_box(false, 1.0, 0.0)

    local offset = (SKIN.yb_diff_offset or { x = 60 }).x
    local texts = song_texts(self, box)

    -- diff outlines + crowns (diff < URA)
    for d = 0, 3 do
        local info = box:course_info(d)
        if info.has_course then
            draw_diff_outline(d * offset, 0.0, math.min(open_fade, 0.25))
            draw_diff_crown(box, d, d * offset, 0.0, open_fade)
        end
    end

    -- ex_data / new icon
    local exd = box:ex_data_flag()
    if exd == 1 then
        tex.draw_texture(T("yellow_box", "ex_data_new_audio"), { fade = open_fade })
    elseif exd == 2 then
        tex.draw_texture(T("yellow_box", "ex_data_old_audio"), { fade = open_fade })
    elseif exd == 3 then
        tex.draw_texture(T("yellow_box", "ex_data_limited_time"), { fade = open_fade })
    elseif box.is_new then
        tex.draw_texture(T("yellow_box", "ex_data_new_song"), { fade = open_fade })
    end

    if tex.display_bpm() then
        local bpm = box:bpm_text()
        local cfg = tex.get_skin_config("song_select_box_bpm") or { x = 628, y = 120 }
        if bpm then bpm:draw({ x = cfg.x, y = cfg.y, fade = open_fade }) end
    end

    if box.is_favorite then
        tex.draw_texture(T("yellow_box", "favorite_" .. tex.player_num() .. "p"), { fade = open_fade })
    end

    -- difficulty bars (4)
    for i = 0, 3 do
        tex.draw_texture(T("yellow_box", "difficulty_bar"), { frame = i, x = i * offset, fade = open_fade })
        if not box:course_info(i).has_course then
            tex.draw_texture(T("yellow_box", "difficulty_bar_shadow"), { frame = i, x = i * offset, fade = math.min(open_fade, 0.25) })
        end
    end

    -- difficulty bar labels
    local labels = difficulty_bar_labels(self)
    local box_cfg = difficulty_bar_label_box()
    for i = 0, 3 do
        local label = labels[i + 1]
        label:draw({
            x = box_cfg.x + i * offset + box_cfg.width / 2 - label.width / 2,
            y = box_cfg.y,
            y2 = math.min(label.height, box_cfg.height) - label.height,
            fade = open_fade
        })
    end

    -- stars + branch indicator (diff < URA)
    local offset_y = (SKIN.yb_diff_offset or { y = -17 }).y
    for d = 0, 3 do
        local info = box:course_info(d)
        if info.has_course then
            for j = 0, info.level - 1 do
                tex.draw_texture(T("yellow_box", "star"), { x = d * offset, y = j * offset_y, fade = open_fade })
            end
            local tag = course_tag(info, true)
            if tag == "branch" then
                tex.draw_texture(T("yellow_box", "branch_indicator_bg"), { x = d * offset, fade = open_fade })
                tex.draw_texture(T("yellow_box", "branch_indicator"), { x = d * offset, fade = open_fade })
            elseif tag == "papamama" then
                tex.draw_texture(T("yellow_box", "papamama_indicator"), { x = d * offset, fade = open_fade })
            end
        end
    end

    draw_text(box, texts)
end

function SongSelect:draw_song_diff_select(box)
    draw_yellow_box(true, 1.0, 0.0)

    local diff_fade = box.diff_fade_in.attribute
    tex.draw_texture(T("diff_select", "back"),   { fade = diff_fade })
    tex.draw_texture(T("diff_select", "option"), { fade = diff_fade })
    if tex.current_screen() == "BATTLE_SELECT" then
        tex.draw_texture(T("enso_battle", "skill_box"), { fade = diff_fade })
    else
        tex.draw_texture(T("diff_select", "neiro"), { fade = diff_fade })
    end

    local s            = tex.get_screen_scale()
    -- strict audit (Green AI board, direct feed Tl7g8XXXvAM 2:07): towers stand 100 px apart, no empty crown outlines
    local strict = tex.zdon_ai_select()
    local offset_x     = (strict and 100 or 115) * s
    local offset_y     = -120 * s
    local crown_offset = 8 * s

    -- hidden_oni: the oni / ura slot stays empty until the player opens it
    local last_slot = box.oni_locked and DIFF_ONI - 1 or DIFF_ONI

    -- diff crowns (diff < URA)
    for d = 0, last_slot do
        local info = box:course_info(d)
        if info.has_course then
            local cx = d * offset_x + crown_offset
            if not strict then draw_diff_outline(cx, offset_y, math.min(diff_fade, 0.25)) end
            draw_diff_crown(box, d, cx, offset_y, diff_fade)
        end
    end

    -- diff towers + labels
    local tower_labels = diff_tower_labels(self)
    local box_cfg = diff_tower_label_box()
    for i = 0, last_slot do
        local label_index = i
        if i == DIFF_ONI and box.is_ura then
            tex.draw_texture(T("diff_select", "diff_tower"), { frame = 4, x = i * offset_x, fade = diff_fade })
            tex.draw_texture(T("diff_select", "ura_oni_plate"), { fade = diff_fade })
            label_index = 4
        else
            tex.draw_texture(T("diff_select", "diff_tower"), { frame = i, x = i * offset_x, fade = diff_fade })
        end
        if not box:course_info(i).has_course then
            tex.draw_texture(T("diff_select", "diff_tower_shadow"), { frame = i, x = i * offset_x, fade = math.min(diff_fade, 0.25) })
        end
        local label = tower_labels[label_index + 1]
        label:draw({
            x = box_cfg.x + i * offset_x + (box_cfg.width - label.width) / 2,
            y = box_cfg.y,
            fade = diff_fade
        })
    end

    -- ura stars + branch indicator
    local star_offset_y = -20 * tex.get_screen_scale()
    for d = 0, box.oni_locked and last_slot or DIFF_URA do
        local info = box:course_info(d)
        if info.has_course then
            if (d == DIFF_URA and not box.is_ura) or (d == DIFF_ONI and box.is_ura) then
                -- skip
            else
                for j = 0, info.level - 1 do
                    tex.draw_texture(T("yellow_box", "star_ura"), { x = math.min(d, DIFF_ONI) * offset_x, y = j * star_offset_y, fade = diff_fade })
                end
                local tag = course_tag(info, false)
                if tag then
                    local name = tag .. "_indicator" .. ((d == DIFF_URA) and "_ura" or "_diff")
                    tex.draw_texture(T("yellow_box", name), { x = math.min(d, DIFF_ONI) * offset_x, fade = diff_fade })
                end
            end
        end
    end

    draw_text(box, song_texts(self, box))
end
