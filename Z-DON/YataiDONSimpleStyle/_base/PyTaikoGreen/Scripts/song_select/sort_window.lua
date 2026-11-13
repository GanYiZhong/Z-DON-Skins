local SKIN_S = tex.get_screen_scale()
local SKIN = {
    diff_sort_margin_1 = { x = 25 * SKIN_S },
    diff_sort_margin_2 = { x = 23 * SKIN_S },
    diff_sort_margin_3 = { x = 10 * SKIN_S },
    diff_sort_offset = { x = 100 * SKIN_S },
    diff_sort_offset_2 = { x = 245 * SKIN_S },
    diff_sort_star_spacing = { x = 40.5 * SKIN_S },
    diff_sort_stat_num_star = { x = 70 * SKIN_S, y = -108 * SKIN_S },
}

local M = {}

local function T(name)
    return tex.get_texture("song_select/diff_sort/" .. name)
end

local function digit_of(counter, i)
    return counter:byte(i) - 48
end

local function draw_statistics(w)
    local box, in_level = w:box(), w:in_level()

    tex.draw_texture(T("stat_bg_" .. w:stats_player() .. "p"))
    tex.draw_texture(T("stat_overlay"))
    tex.draw_texture(T("stat_diff"), { frame = math.min(box, 4) })

    local m1 = SKIN.diff_sort_margin_1.x
    local m2 = SKIN.diff_sort_margin_2.x
    local m3 = SKIN.diff_sort_margin_3.x

    -- centred digit row at the given margin
    local function centred(sprite, counter, margin, params)
        local total_width = #counter * margin
        for i = 1, #counter do
            local p = { frame = digit_of(counter, i), x = -(total_width / 2) + (i - 1) * margin }
            for k, v in pairs(params or {}) do p[k] = v end
            tex.draw_texture(sprite, p)
        end
    end

    if in_level or box == 5 then
        tex.draw_texture(T("stat_starx"))
        local stats
        local counter
        if box == 5 then
            tex.draw_texture(T("stat_prev"))
            counter = tostring(w:prev_level())
            stats = w:stats(w:prev_diff(), w:prev_level())
        else
            counter = tostring(w:level())
            stats = w:stats(box, w:level())
        end
        local star = SKIN.diff_sort_stat_num_star
        for i = 1, #counter do
            tex.draw_texture(T("stat_num_star"),
                { frame = digit_of(counter, i), x = star.x - (#counter - (i - 1)) * m1, y = star.y })
        end

        local total = tostring(stats.total)
        centred(T("stat_num"), total, m2)
        for j = 0, 1 do centred(T("stat_num_small"), total, m3, { index = j }) end
        for j = 0, 1 do
            centred(T("stat_num_star"), tostring(j == 0 and stats.full_combos or stats.clears), m1, { index = j + 1 })
        end
    else
        local sums = w:sums(box)
        local total = tostring(sums.total)
        centred(T("stat_num"), total, m2)
        for j = 0, 1 do centred(T("stat_num_small"), total, m3, { index = j }) end
        for j = 0, 1 do
            centred(T("stat_num_star"), tostring(j == 0 and sums.full_combos or sums.clears), m1, { index = j + 1 })
        end
    end
end

local function draw_diff_select(w, a)
    local box, num_boxes = w:box(), w:num_boxes()
    tex.draw_texture(T("background"), { scale = a.bg_resize, center = true })
    tex.draw_texture(T("back"), { fade = a.fade_in })

    local offset = SKIN.diff_sort_offset.x
    for i = 0, num_boxes - 1 do
        if i == box then
            tex.draw_texture(T("box_highlight"),      { x = offset * i, fade = a.fade_in })
            tex.draw_texture(T("box_text_highlight"), { frame = i, x = offset * i, fade = a.fade_in })
        else
            tex.draw_texture(T("box"),      { x = offset * i, fade = a.fade_in })
            tex.draw_texture(T("box_text"), { frame = i, x = offset * i, fade = a.fade_in })
        end
    end

    if box == -1 then
        tex.draw_texture(T("back_outline"), { fade = a.flicker })
    else
        tex.draw_texture(T("box_outline"), { x = offset * box, fade = a.flicker })
    end

    for i = 0, num_boxes - 1 do
        if i < 5 then tex.draw_texture(T("box_diff"), { frame = i, x = offset * i }) end
    end
    if box ~= -1 and box ~= num_boxes - 1 then draw_statistics(w) end
end

local function draw_level_select(w, a)
    local box, level = w:box(), w:level()
    tex.draw_texture(T("background"), { scale = a.bg_resize, center = true })
    if w:confirmation() then
        tex.draw_texture(T("star_select_prompt"))
    else
        tex.draw_texture(T("star_select_text"), { fade = a.fade_in })
    end
    tex.draw_texture(T("star_limit"), { frame = box, fade = a.fade_in })
    tex.draw_texture(T("level_box"),  { fade = a.fade_in })
    tex.draw_texture(T("diff"),       { frame = box, fade = a.fade_in })
    tex.draw_texture(T("star_num"),   { frame = level, fade = a.fade_in })
    local spacing = SKIN.diff_sort_star_spacing.x
    for i = 0, level - 1 do
        tex.draw_texture(T("star"), { x = i * spacing, fade = a.fade_in })
    end
    if w:stats(box, level).total == 0 then
        tex.draw_texture(T("no_songs"), { fade = a.fade_in })
    end

    if w:confirmation() then
        local lb = tex.get_texture_info("diff_sort", "level_box")
        if lb then tex.draw_rect(lb.x[1], lb.y[1], lb.x2[1], lb.y2[1], 0, 0, 0, 127) end
        local y = a.bounce
        local offset = SKIN.diff_sort_offset_2.x
        for i = 0, 2 do
            if i == w:confirm_index() then
                tex.draw_texture(T("small_box_highlight"),      { x = i * offset, y = y })
                tex.draw_texture(T("small_box_text_highlight"), { frame = i, x = i * offset, y = y })
                tex.draw_texture(T("small_box_outline"),        { x = i * offset, y = y, fade = a.flicker })
            else
                tex.draw_texture(T("small_box"),      { x = i * offset, y = y })
                tex.draw_texture(T("small_box_text"), { frame = i, x = i * offset, y = y })
            end
        end
    else
        tex.draw_texture(T("pongos"))
        if level ~= 1 then
            tex.draw_texture(T("arrow"), { x = -a.arrow_move, fade = a.arrow_fade, index = 0 })
        end
        if level ~= w:limit(box) then
            tex.draw_texture(T("arrow"), { mirror = "horizontal", x = a.arrow_move, fade = a.arrow_fade, index = 1 })
        end
    end
    draw_statistics(w)
end

local WHICH_BOARDS = {
    { art = "which_left",  text = "which_left_text",  dx = 18,  dy = -104 },
    { art = nil,           text = "which_back_text",  dx = 250, dy = -104 },
    { art = "which_right", text = "which_right_text", dx = 476, dy = -105 },
}

local function draw_which(w, a)
    tex.draw_texture(T("which_panel"))
    tex.draw_texture(T("which_question"))
    for i, b in ipairs(WHICH_BOARDS) do
        local on = (i - 1) == w:which_index()
        local at = { x = b.dx * SKIN_S, y = b.dy * SKIN_S }
        if on then
            tex.draw_texture(T("small_box_highlight"), at)
        elseif b.art then
            tex.draw_texture(T(b.art))
        else
            tex.draw_texture(T("small_box"), at)
        end
        tex.draw_texture(T(b.text), { frame = on and 1 or 0 })
        if on then
            tex.draw_texture(T("small_box_outline"), { x = at.x, y = at.y, fade = a.flicker })
        end
    end
end

-- Installed as SongSelect:draw_sort_window.
function M.draw_sort_window(_self, w)
    if w:one_menu() then return end
    tex.draw_rect(0, 0, tex.get_screen_width(), tex.get_screen_height(), 0, 0, 0, 153)
    local a = w:anim()
    if w:which() then
        draw_which(w, a)
    elseif w:in_level() then
        draw_level_select(w, a)
    else
        draw_diff_select(w, a)
    end
end

return M
