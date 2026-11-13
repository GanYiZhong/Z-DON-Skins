-- Difficulty sort window, split out of song_select.lua.

local base = require("song_select/file_navigator/box_base")

local draw_centered = base.draw_centered
local draw_title = base.draw_title
local draw_guide_label = base.draw_guide_label
local outline = base.outline
local GUIDE_SELECT_CX, GUIDE_DECIDE_CX = base.GUIDE_SELECT_CX, base.GUIDE_DECIDE_CX

local SW_ROW_Y     = { 410, 551, 692 }
local SW_BOARD_W, SW_BOARD_H = 1320, 760
local SW_CURSOR_W, SW_CURSOR_H = 1240, 180
local SW_PILL_CX   = 1124          -- 960 + 164
local SW_PILL_W, SW_PILL_H = 792, 104
local SW_MARK_CX   = 871           -- 960 - 89
local SW_ARROW_LX  = 786           -- 960 - 174
local SW_ARROW_RX  = 1462          -- 960 + 502
local SW_HEADER_CX = 560           -- 960 - 400
local SW_TEXT_DY   = -13
local SW_GUIDE_Y   = 827
local SW_GUIDE_W, SW_GUIDE_H = 372, 96
local SW_NUM_RIGHT = 1379
local SW_NUM_Y     = 289
local SW_NUM_PITCH = 34
local SW_NUM_W, SW_NUM_H = 48, 56
local SW_SONGS_X   = 1402          -- ink LEFT edge (EditText align = left)
local SW_SONGS_Y   = 277
local SW_TITLE_X   = 405
local SW_TITLE_Y   = 272
local SW_TITLE_OUTLINE = { 119, 26, 45, 255 }
local SW_HEADER_BOX_W  = 310
local SW_ITEM_BOX_W    = { 620, 430, 430 }
local SW_CURSOR_CYCLE = 51.0

local SW_KEYS = {
    header = { "sort_window_diff", "sort_window_star", "sort_window_order" },
    course = { "course_name_0", "course_name_1", "course_name_2", "course_name_3", "course_name_3" },
    order  = { "sort_window_order_0", "sort_window_order_1", "sort_window_order_2", "sort_window_order_3" },
    title  = "folder_sort_select",
    songs  = "sort_window_songs",
}

local function sw_words(group)
    local k = SW_KEYS[group]
    if type(k) == "table" then
        local out = {}
        for i, key in ipairs(k) do out[i] = tex.skin_text(key) end
        return out
    end
    return tex.skin_text(k)
end

-- OutlinedText cache: key = group .. "\0" .. index.
function SongSelect:_sw_text(key, str, size, thickness, outline)
    self._sw_texts = self._sw_texts or {}
    local t = self._sw_texts[key]
    if t == nil then
        t = text.create_raw_text(str, size, { 255, 255, 255, 255 },
                                 outline or { 0, 0, 0, 255 }, false, thickness, 2.0)
        self._sw_texts[key] = t or false
    end
    return t or nil
end

-- Fit-shrink: when a string does not fit its box, re-rasterise it at a smaller (uniformly
-- scaled) point size instead of stretching the bitmap, so glyphs keep their proportions.
local SW_FIT_MIN_SIZE = 22
function SongSelect:_sw_text_fit(key, str, size, thickness, outline, max_w)
    self._sw_texts = self._sw_texts or {}
    local t = self._sw_texts[key]
    if t == nil then
        t = text.create_raw_text(str, size, { 255, 255, 255, 255 },
                                 outline or { 0, 0, 0, 255 }, false, thickness, 2.0)
        if t and max_w and t.width > max_w then
            local fit_size = math.max(SW_FIT_MIN_SIZE, math.floor(size * max_w / t.width))
            if fit_size < size then
                local fit_thickness = thickness * fit_size / size
                local t2 = text.create_raw_text(str, fit_size, { 255, 255, 255, 255 },
                                                outline or { 0, 0, 0, 255 }, false, fit_thickness, 2.0)
                if t2 then t = t2 end
            end
        end
        self._sw_texts[key] = t or false
    end
    return t or nil
end

-- Draw an OutlinedText with its ink LEFT edge on x.
local function draw_text_left(t, x, cy, fade)
    if not t then return end
    t:draw({ x = math.floor(x + 0.5), y = math.floor(cy - t.height / 2 + 0.5), fade = fade })
end

-- cursor glow alpha over the 51-frame loop, sampled from anim/sort_cursor.
local sort_cursor_ok, sort_cursor_anim = pcall(require, "anim/sampler")
local SW_CURSOR_CLIP = (sort_cursor_ok and sort_cursor_anim.safe("anim/sort_cursor"))
                       or { get = function() return nil end, label = function() return nil end }
local SW_ON_F = SW_CURSOR_CLIP:label("on") or 9
local function sw_cursor_glow(ms)
    local r = (ms * 0.06) % SW_CURSOR_CYCLE
    local a = SW_CURSOR_CLIP:get("#3@0", SW_ON_F + r, "a")
    if a then return a end
    if r <= 20.0 then return 1.0 - r / 20.0 end
    return (r - 20.0) / 30.0
end

function SongSelect:_sw_ids()
    if self._sw_loaded then return end
    tex.load_folder("song_select", "diff_sort")
    self._id_sw_board  = tex.get_texture("song_select/diff_sort/background")     -- 1320x760 window
    self._id_sw_pill   = tex.get_texture("song_select/diff_sort/level_box")      -- 792x104 white item pill
    self._id_sw_cur    = tex.get_texture("song_select/diff_sort/box_highlight")  -- 1240x180 flat yellow bar
    self._id_sw_glow   = tex.get_texture("song_select/diff_sort/box_outline")    -- 1240x180 pulsing glow
    self._id_sw_mark   = tex.get_texture("song_select/diff_sort/diff")           -- 96x96, frame = course
    self._id_sw_arrow  = tex.get_texture("song_select/diff_sort/arrow")          -- 48x56, frame 1 = rotated
    self._id_sw_digit  = tex.get_texture("song_select/diff_sort/stat_num")       -- 48x56, frame = digit
    self._id_sw_guide  = tex.get_texture("song_select/diff_sort/star_select_text") -- s_menfuchi_kp loop
    self._sw_loaded = true
end

function SongSelect:draw_sort_window(w)
    -- the classic two-step window is the default sort_window module's
    if not w:one_menu() then return false end
    self:_sw_ids()
    local a = w:alpha()
    if a <= 0.0 or not self._id_sw_board then return end
    local ms = tex.get_current_ms()
    local session = w:session()
    local vals = { w:diff(), w:star(), w:order() }

    draw_centered(self._id_sw_board, 960, 540, SW_BOARD_W, SW_BOARD_H, { fade = a })

    -- the three rows, in the cabinet's own depth order (order, star, diff)
    for row = 3, 1, -1 do
        local ry = SW_ROW_Y[row]
        local idx = row - 1                       -- 0-based, matching SortWindow:session()
        if idx == session and self._id_sw_cur then
            if self._id_sw_glow then
                draw_centered(self._id_sw_glow, 960, ry, SW_CURSOR_W, SW_CURSOR_H,
                              { fade = a * sw_cursor_glow(ms) })
            end
            draw_centered(self._id_sw_cur, 960, ry, SW_CURSOR_W, SW_CURSOR_H, { fade = a })
        end
        if self._id_sw_pill then
            draw_centered(self._id_sw_pill, SW_PILL_CX, ry, SW_PILL_W, SW_PILL_H, { fade = a })
        end
        -- diff_mark is visible on the むずかしさ row only
        if row == 1 and self._id_sw_mark then
            draw_centered(self._id_sw_mark, SW_MARK_CX, ry, 96, 96,
                          { frame = math.max(0, math.min(4, vals[1] - 1)), fade = a })
        end
        if self._id_sw_arrow then
            local dx = w:arrow_offset(idx)
            draw_centered(self._id_sw_arrow, SW_ARROW_LX + dx, ry, 48, 56, { frame = 0, fade = a })
            draw_centered(self._id_sw_arrow, SW_ARROW_RX - dx, ry, 48, 56, { frame = 1, fade = a })
        end
        -- item value
        local str, key
        if row == 1 then
            local n = math.max(1, math.min(5, vals[1]))
            str, key = sw_words("course")[n], "course" .. n
        elseif row == 2 then
            str, key = tostring(vals[2]), "star" .. vals[2]
        else
            local n = math.max(1, math.min(4, vals[3]))
            str, key = sw_words("order")[n], "order" .. n
        end
        draw_title(self:_sw_text_fit(key, str, 42, outline(6.5), nil, SW_ITEM_BOX_W[row]),
                   SW_PILL_CX, ry + SW_TEXT_DY, a, SW_ITEM_BOX_W[row], 0)
        -- header
        draw_title(self:_sw_text_fit("hdr" .. row, sw_words("header")[row], 42, outline(6.5), nil, SW_HEADER_BOX_W),
                   SW_HEADER_CX, ry + SW_TEXT_DY, a, SW_HEADER_BOX_W, 0)
    end

    -- control guide + its two pill labels
    if self._id_sw_guide then
        local cell = math.floor((ms * 0.06) % 210)
        draw_centered(self._id_sw_guide, 960, SW_GUIDE_Y, SW_GUIDE_W, SW_GUIDE_H,
                      { frame = cell, fade = a })
        local labels = self:guide_labels()
        if labels then
            draw_guide_label(labels.select, GUIDE_SELECT_CX, SW_GUIDE_Y + 2, a)
            draw_guide_label(labels.decide, GUIDE_DECIDE_CX, SW_GUIDE_Y + 2, a)
        end
    end

    -- song counter: 「N 曲」 (right-aligned digits, then the unit label)
    local n = math.max(0, math.min(9999, w:song_num()))
    local digits = tostring(n)
    for i = 1, #digits do
        local d = tonumber(digits:sub(i, i))
        local x = SW_NUM_RIGHT - (#digits - i) * SW_NUM_PITCH
        draw_centered(self._id_sw_digit, x, SW_NUM_Y, SW_NUM_W, SW_NUM_H, { frame = d, fade = a })
    end
    draw_text_left(self:_sw_text("songs", sw_words("songs"), 42, outline(6.5)), SW_SONGS_X, SW_SONGS_Y, a)

    -- board title, with the cabinet's dark-red outline add
    draw_text_left(self:_sw_text("title", sw_words("title"), 54, outline(7.5), SW_TITLE_OUTLINE),
                   SW_TITLE_X, SW_TITLE_Y, a)
end
