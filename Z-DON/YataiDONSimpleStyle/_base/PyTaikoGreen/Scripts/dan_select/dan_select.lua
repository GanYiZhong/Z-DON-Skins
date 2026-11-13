local SKIN_S = tex.get_screen_scale()
local SKIN = {
    total_notes_counter_margin = { x = 28 * SKIN_S },
    exam_counter_margin = { x = 25 * SKIN_S },
    dan_yellow_box_offset = { x = 144 * SKIN_S },
    dan_level_counter_margin = { x = 14 * SKIN_S },
    dan_hori_name = { x = 430 * SKIN_S, y = 73 * SKIN_S, width = 275 * SKIN_S },
    dan_exam_value_center = { x = 422 * SKIN_S, width = -4 * SKIN_S },
    yellow_box_bottom = { y = 539 * SKIN_S },
}
DanSelect = {}
DanSelect.__index = DanSelect

local _tex = {}
local function T(subset, name)
    local key = subset .. "/" .. name
    local id = _tex[key]
    if id == nil then
        id = tex.get_texture("dan_select/" .. subset .. "/" .. name)
        _tex[key] = id
    end
    return id
end

local function cfg(name)
    return tex.get_skin_config(name)
end

-- Texture draw-offset at index 0 (TextureObject::x[0] / y[0] / x2[0]).
local function tex_x0(subset, name)
    local info = tex.get_texture_info(subset, name)
    if info and info.x and info.x[1] then return info.x[1] end
    return 0
end
local function tex_y0(subset, name)
    local info = tex.get_texture_info(subset, name)
    if info and info.y and info.y[1] then return info.y[1] end
    return 0
end
local function tex_x2(subset, name)
    local info = tex.get_texture_info(subset, name)
    if info and info.x2 and info.x2[1] then return info.x2[1] end
    return 0
end

-- exam.type -> icon texture name (exam_icon_id in box_dan.cpp). "renda" resolves to
-- exam_roll, falling back to exam_drumroll in older skins. Returns the resolved name.
local EXAM_ICON = {
    gauge = "exam_gauge",        combo = "exam_combo",
    hit = "exam_hit",            judgebad = "exam_judgebad",
    judgegood = "exam_judgegood", judgeperfect = "exam_judgeperfect",
    score = "exam_score",        renda = "exam_roll",
}
local function exam_icon_name(type)
    local name = EXAM_ICON[type]
    if not name then return nil end
    if T("yellow_box", name) then return name end
    if T("yellow_box", "exam_drumroll") then return "exam_drumroll" end
    return nil
end

local yb_box = { path = nil, state = "closed", gaiden = false }

function DanSelect.new()
    local self = setmetatable({ now = 0 }, DanSelect)
    yb_box.path, yb_box.state, yb_box.gaiden = nil, "closed", false
    return self
end

local YB_DIFF_ANIMS = { 13, 14, 15, 16, 17, 18 }

local function draw_dan_yellow_box(is_diff, fade)
    local right_x       = tex.get_animation(is_diff and 14 or 10).attribute
    local left_x        = tex.get_animation(is_diff and 13 or 9).attribute
    local center_width  = tex.get_animation(is_diff and 15 or 11).attribute
    local top_y         = tex.get_animation(16).attribute
    local center_height = tex.get_animation(17).attribute
    local bottom_y      = (SKIN.yellow_box_bottom or { y = 0 }).y
    local info = tex.get_texture_info("yellow_box", "yellow_box_bottom_right")
    local eh = (info and info.height) or 0

    tex.draw_texture(T("yellow_box", "yellow_box_bottom_right"), { x = right_x,       y = bottom_y,             fade = fade })
    tex.draw_texture(T("yellow_box", "yellow_box_bottom_left"),  { x = left_x,        y = bottom_y,             fade = fade })
    tex.draw_texture(T("yellow_box", "yellow_box_top_right"),    { x = right_x,       y = top_y,                fade = fade })
    tex.draw_texture(T("yellow_box", "yellow_box_top_left"),     { x = left_x,        y = top_y,                fade = fade })
    tex.draw_texture(T("yellow_box", "yellow_box_bottom"),       { x = left_x + eh,   y = bottom_y,             x2 = center_width,  fade = fade })
    tex.draw_texture(T("yellow_box", "yellow_box_right"),        { x = right_x,       y = top_y + eh,           y2 = center_height, fade = fade })
    tex.draw_texture(T("yellow_box", "yellow_box_left"),         { x = left_x,        y = top_y + eh,           y2 = center_height, fade = fade })
    tex.draw_texture(T("yellow_box", "yellow_box_top"),          { x = left_x + eh,   y = top_y,                x2 = center_width,  fade = fade })
    tex.draw_texture(T("yellow_box", "yellow_box_center"),       { x = left_x + eh,   y = top_y + eh,           x2 = center_width,  y2 = center_height, fade = fade })
end

local rank_voice = nil
local function play_rank_voice(dan_index)
    if rank_voice then audio.stop_sound(rank_voice) end
    rank_voice = nil
    local name = "rank_" .. tostring(dan_index)
    if dan_index < 0 or not audio.has_sound(name) or audio.is_sound_playing("dan_select") then return end
    audio.play_sound(name, "voice")
    rank_voice = name
end

-- Track the open box and start the diff-select expansion on the closed -> diff_select
-- transition (the dan box never passes through the "open" draw_state).
local function track_dan_yellow_box(box)
    local state = box:draw_state()
    local path = box:path()
    if state == "closed" then
        if yb_box.path == path then
            yb_box.path, yb_box.state, yb_box.gaiden = nil, "closed", false
        end
        return
    end
    if yb_box.path ~= path then
        yb_box.path, yb_box.state, yb_box.gaiden = path, state, box.gaiden
        play_rank_voice(box.dan_index)
        for _, id in ipairs(YB_DIFF_ANIMS) do tex.get_animation(id):reset() end
        for _, id in ipairs(YB_DIFF_ANIMS) do tex.get_animation(id):start() end
    end
end

local function update_dan_yellow_box(ms)
    for _, id in ipairs(YB_DIFF_ANIMS) do tex.get_animation(id):update(ms) end
end

function DanSelect:update(ms)
    self.now = ms
    update_dan_yellow_box(ms)
end

local function draw_tex(subset, name, params)
    local id = T(subset, name)
    if id then tex.draw_texture(id, params) end
end

-- Dan box ribbon: { centre x, spacing between boxes, extra gap left of the selection, extra gap right }
function DanSelect:ribbon()
    local s = tex.get_screen_scale()
    return { 592 * s, 125 * s, 375 * s, 375 * s }
end

function DanSelect:draw_back()
    draw_tex("global", "bg", {})
    draw_tex("global", "bg_header", {})
    draw_tex("global", "bg_footer", {})
    draw_tex("global", "footer", {})
end

function DanSelect:draw_cursor(pos, now, since_move)
    if since_move < 0 or since_move >= 967 then return true end
    local p = since_move / 967
    local drift = 30 * p
    local fade = 0.984 * (1 - p)
    draw_tex("global", "arrow", { index = 0, x = -drift, fade = fade })
    draw_tex("global", "arrow", { index = 1, x = drift, fade = fade, mirror = "horizontal" })
    return true
end

function DanSelect:draw_title()
    draw_tex("global", (yb_box.gaiden and T("global", "dan_select_odai")) and "dan_select_odai" or "dan_select", {})
end

local CONFIRM_OPTION, CONFIRM_YES = 0, 1

-- fade: confirm_fade attribute; index: 0 option / 1 yes / 2 no
function DanSelect:draw_confirm(f, index)
    if f <= 0 then return end
    tex.draw_rect(0, 0, tex.get_screen_width(), tex.get_screen_height(), 0, 0, 0, math.min(0.5, f) * 255)
    draw_tex("confirm_box", "bg", { fade = f })
    local odai = yb_box.gaiden and T("confirm_box", "confirmation_text_odai")
    draw_tex("confirm_box", odai and "confirmation_text_odai" or "confirmation_text", { fade = f })
    for i = 0, 1 do
        draw_tex("confirm_box", "selection_box", { fade = f, index = i })
    end
    if index ~= CONFIRM_OPTION then
        -- selection_box slots are screen-left / screen-right; yes sits right of no unless swapped
        local yes_info = tex.get_texture_info("confirm_box", "yes")
        local no_info = tex.get_texture_info("confirm_box", "no")
        local yes_right = yes_info and no_info and yes_info.x[1] > no_info.x[1]
        local side = ((index == CONFIRM_YES) == (yes_right and true or false)) and 1 or 0
        draw_tex("confirm_box", "selection_box_highlight", { fade = f, index = side })
        draw_tex("confirm_box", "selection_box_outline",   { fade = f, index = side })
    end
    draw_tex("confirm_box", "yes", { fade = f })
    draw_tex("confirm_box", "no",  { fade = f })
    if T("confirm_box", "option") then
        if index == CONFIRM_OPTION then draw_tex("confirm_box", "option_highlight", { fade = f }) end
        draw_tex("confirm_box", "option", { fade = f })
    end
end

-- Draw a texture at an absolute position, ignoring its own x[0]/y[0] anchor (draw_abs).
local function draw_abs(subset, name, X, Y, fade, frame)
    local id = T(subset, name)
    if not id then return end
    tex.draw_texture(id, {
        frame = frame or 0,
        x = X - tex_x0(subset, name),
        y = Y - tex_y0(subset, name),
        fade = fade,
    })
end

local BACK_CX, BACK_BOTTOM, BACK_HALF0, BACK_HALF1 = 642, 539, 44.4, 191
local BACK_TOP0, BACK_TOP1, BACK_GROW_MS = 338 - 228, 338 - 231, 150

function DanSelect:draw_back_box(box)
    local bx = box:box_x()
    local fade = box.fade.attribute
    tex.draw_texture(T("back", "folder"), { x = bx, fade = fade })
    if box:draw_state() == "closed" then
        self.back_open_at = nil
        tex.draw_texture(T("back", "chip"), { x = bx, fade = fade })
        return
    end
    self.back_open_at = self.back_open_at or self.now
    local ms = self.now - self.back_open_at
    local u = math.min(math.max(ms / BACK_GROW_MS, 0), 1)
    local half = BACK_HALF0 + (BACK_HALF1 - BACK_HALF0) * u
    local top = BACK_TOP0 + (BACK_TOP1 - BACK_TOP0) * u
    local l, r = BACK_CX - half, BACK_CX + half - 32
    local w, h = r - l - 32, BACK_BOTTOM - top - 32
    local function piece(name, x, y, x2, y2)
        tex.draw_texture(T("back", name), { x = x, y = y, x2 = x2 and x2 - 32 or 0, y2 = y2 and y2 - 32 or 0 })
    end
    piece("board_tl", l, top);               piece("board_t", l + 32, top, w)
    piece("board_tr", r, top);               piece("board_r", r, top + 32, nil, h)
    piece("board_br", r, BACK_BOTTOM);       piece("board_b", l + 32, BACK_BOTTOM, w)
    piece("board_bl", l, BACK_BOTTOM);       piece("board_l", l, top + 32, nil, h)
    piece("board_c", l + 32, top + 32, w, h)
    local f = math.min(math.max((ms - 33) / 117, 0), 1)
    for _, name in ipairs({ "graphic", "text", "pill" }) do tex.draw_texture(T("back", name), { fade = f }) end
end

function DanSelect:draw_box(box)
    if box.is_back then return self:draw_back_box(box) end
    track_dan_yellow_box(box)
    local state = box:draw_state()
    if state == "closed" then
        self:draw_dan_closed(box)
    else
        self:draw_dan_open(box)
    end
end

-- ---------------------------------------------------------------------------
-- draw_chip (closed): folder board + vertical chip name.
-- ---------------------------------------------------------------------------
function DanSelect:draw_dan_closed(box)
    local bx = box:box_x()
    local fade = box.fade.attribute

    tex.draw_texture(T("box", "folder"), { frame = box.dan_color, x = bx, fade = fade })

    if box.clear_mark > 0 and T("box", "clear_mark") then
        tex.draw_texture(T("box", "clear_mark"), { frame = box.clear_mark - 1, x = bx, fade = fade })
    end

    local name = box:chip_name()
    if name then
        local nb = cfg("dan_select_chip_name") or cfg("song_select_box_name") or { x = 0, y = 0, height = 0 }
        name:draw({
            x = bx + nb.x - name.width / 2,
            y = nb.y,
            y2 = math.min(name.height, nb.height or name.height) - name.height,
            fade = fade,
        })
    end
end

-- ---------------------------------------------------------------------------
-- draw_open: chip + song ribbon + total notes + rank + exam box.
-- ---------------------------------------------------------------------------
function DanSelect:draw_dan_open(box)
    self:draw_dan_closed(box)
    local f = box.open_fade.attribute

    -- The yellow box board the course details sit on (opaque; its growth is driven by
    -- the diff-select animations, matching the song-select wheel).
    draw_dan_yellow_box(true, 1.0)

    local off = SKIN.dan_yellow_box_offset or { x = 0, y = 0 }
    local offset_x = off.x or 0
    local offset_y = off.y or 0

    local n = box:song_count()
    for i = 0, n - 1 do
        local x = i * offset_x
        local y = i * offset_y

        tex.draw_texture(T("yellow_box", "genre_banner"), { frame = box:song_genre(i), x = x, y = y, fade = f })

        local song_label = T("yellow_box", "song_label")
        if song_label then
            tex.draw_texture(song_label, { frame = math.min(i, 2), x = x, y = y, fade = f })
        end

        tex.draw_texture(T("yellow_box", "difficulty"),      { frame = box:song_difficulty(i), x = x, y = y, fade = f })
        if box:song_difficulty(i) == 4 and T("yellow_box", "difficulty_ura") then
            tex.draw_texture(T("yellow_box", "difficulty_ura"), { x = x, y = y, fade = f })
        end
        tex.draw_texture(T("yellow_box", "difficulty_x"),    { x = x, y = y, fade = f })
        tex.draw_texture(T("yellow_box", "difficulty_star"), { x = x, y = y, fade = f })

        -- Level counter
        local lvl = tostring(box:song_level(i))
        local margin = (SKIN.dan_level_counter_margin or { x = 0 }).x
        local total_w = #lvl * margin
        for j = 1, #lvl do
            local digit = string.byte(lvl, j) - 48
            tex.draw_texture(T("yellow_box", "difficulty_num"), {
                frame = digit, x = x - total_w / 2 + (j - 1) * margin, y = y, fade = f })
        end

        -- Song title + subtitle
        local title_text = box:song_title_text(i)
        local sub_text = box:song_subtitle_text(i)
        local td = cfg("dan_select_title") or { x = 0, y = 0, height = 0 }
        local sd = cfg("dan_select_subtitle") or { x = 0, y = 0, height = 0 }
        if box:song_masked(i) and T("yellow_box", "hidden_title") then
            tex.draw_texture(T("yellow_box", "hidden_title"), { x = x, y = y, fade = f })
        elseif title_text then
            title_text:draw({
                x = td.x + x, y = td.y + y,
                y2 = math.min(title_text.height, td.height or title_text.height) - title_text.height,
                fade = f })
        end
        if sub_text then
            sub_text:draw({
                x = sd.x + x,
                y = sd.y + y - math.min(sub_text.height, sd.height or sub_text.height),
                y2 = math.min(sub_text.height, sd.height or sub_text.height) - sub_text.height,
                fade = f })
        end
    end

    if box.clear_mark > 0 and T("yellow_box", "clear_mark") then
        tex.draw_texture(T("yellow_box", "clear_mark"), { frame = box.clear_mark - 1, fade = f })
    end

    -- Total notes
    tex.draw_texture(T("yellow_box", "total_notes_bg"), { fade = f })
    tex.draw_texture(T("yellow_box", "total_notes"), { fade = f })
    local tn = tostring(box.total_notes)
    local tn_margin = (SKIN.total_notes_counter_margin or { x = 0 }).x
    for i = 1, #tn do
        local digit = string.byte(tn, i) - 48
        -- Lumen centres the counter on its 4-digit width
        tex.draw_texture(T("yellow_box", "total_notes_counter"), { frame = digit, x = (i - 1 + (4 - #tn) / 2) * tn_margin, fade = f })
    end

    -- Rank plate / frame
    tex.draw_texture(T("yellow_box", "frame"), { frame = box.dan_color, fade = f })
    local hori = box:hori_name()
    if hori then
        local hn = SKIN.dan_hori_name or { x = 0, y = 0, width = 0 }
        hori:draw({
            x = hn.x - hori.width / 2,
            y = hn.y,
            x2 = math.min(hori.width, hn.width or hori.width) - hori.width,
            fade = f })
    end

    self:draw_exam_box(box, f)
end

-- ---------------------------------------------------------------------------
-- Exam board (the default "condition rows" layout).
-- ---------------------------------------------------------------------------
function DanSelect:draw_exam_box(box, f)
    local offset_y = (cfg("dan_select_exam_info") or { y = 0 }).y
    local margin = (SKIN.exam_counter_margin or { x = 0 }).x

    -- Four or more conditions do not fit the board: drop the soul-gauge row.
    local exam_count = box:exam_count()
    local shown = {}
    for i = 0, exam_count - 1 do
        if not (exam_count >= 4 and box:exam_type(i) == "gauge") then
            shown[#shown + 1] = i
        end
    end
    if #shown > 3 then
        while #shown > 3 do shown[#shown] = nil end
    end

    local L = ({ { dt = 38, row0 = 90, pitch = 0 }, { dt = 18, row0 = 37, pitch = 106 } })[#shown]
        or { dt = 0, row0 = 0, pitch = offset_y }
    local dt = L.dt
    local function part(name, p)
        p.fade = f
        tex.draw_texture(T("yellow_box", name), p)
    end
    part("exam_box_bottom_right", { y = -dt })
    part("exam_box_bottom_left",  { y = -dt })
    part("exam_box_top_right",    { y = dt })
    part("exam_box_top_left",     { y = dt })
    part("exam_box_bottom",       { y = -dt })
    part("exam_box_right",        { y = dt, y2 = -2 * dt })
    part("exam_box_left",         { y = dt, y2 = -2 * dt })
    part("exam_box_top",          { y = dt })
    part("exam_box_center",       { y = dt, y2 = -2 * dt })
    part("exam_header",           { y = dt })

    for idx = 1, #shown do
        local i = shown[idx]
        local y = L.row0 + (idx - 1) * L.pitch
        local etype = box:exam_type(i)
        local range = box:exam_range(i)

        tex.draw_texture(T("yellow_box", "judge_box"), { y = y, fade = f })

        local icon_name = exam_icon_name(etype)
        if icon_name then tex.draw_texture(T("yellow_box", icon_name), { y = y, fade = f }) end

        -- Centre the whole value (digits, %, suffix) on dan_exam_value_center.x.
        local vc = SKIN.dan_exam_value_center or { x = 0, width = 0 }
        local digits = tostring(box:exam_red(i))
        local pct = (etype == "gauge") and T("yellow_box", "exam_percent") or nil
        local suf = (range == "more") and T("yellow_box", "exam_more")
                    or (range == "less") and T("yellow_box", "exam_less") or nil

        local digits_w = (#digits - 1) * margin + tex_x2("yellow_box", "judge_num")
        local pct_w = pct and tex_x2("yellow_box", "exam_percent") or 0
        local suf_w = suf and tex_x2("yellow_box", (range == "more") and "exam_more" or "exam_less") or 0
        local gap = vc.width or 0
        local parts = 1 + (pct and 1 or 0) + (suf and 1 or 0)
        local total = digits_w + pct_w + suf_w + gap * (parts - 1)
        local cx = (vc.x or 0) - total / 2

        for j = 1, #digits do
            local digit = string.byte(digits, j) - 48
            tex.draw_texture(T("yellow_box", "judge_num"),
                { frame = digit, x = cx + (j - 1) * margin - tex_x0("yellow_box", "judge_num"), y = y, fade = f })
        end
        cx = cx + digits_w + gap
        if pct then
            tex.draw_texture(pct, { x = cx - tex_x0("yellow_box", "exam_percent"), y = y, fade = f })
            cx = cx + pct_w + gap
        end
        if suf then
            local suf_name = (range == "more") and "exam_more" or "exam_less"
            tex.draw_texture(suf, { x = cx - tex_x0("yellow_box", suf_name), y = y, fade = f })
        end
    end
end
