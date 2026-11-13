local oni_open = require("song_select/oni_open")

local M = {}

local S = tex.get_screen_scale()

local SELECTOR_OFFSET   = 115 * S    -- distance between the course columns
local BALLOON_OFFSET_1  = -220 * S   -- balloon shift on the back / neiro slots
local BALLOON_OFFSET_2  = 70 * S     -- distance between the back / neiro slots
local BG_DIFF_P2_OFFSET = 1025 * S
local DIFF_TEXT_X, DIFF_TEXT_Y, DIFF_TEXT_FONT = 125 * S, 203 * S, math.floor(61 * S)

local DIFF_NEIRO, DIFF_BACK, DIFF_EASY, DIFF_ONI, DIFF_URA = -1, -3, 0, 3, 4

local function diff_select_sprite(name)
    return tex.get_texture("song_select/diff_select/" .. name)
end

-- pass 0 is drawn under the wheel by the skins that split the cursor; the default draws it once, over
function M.draw_selector(_self, player, is_half, fade_in, pass)
    if pass ~= 1 or fade_in < 1.0 then return end
    local st        = player:selector_state()
    local fade      = st.panel and 0.5 or fade_in
    local direction = st.move_right and 1 or -1
    local selected, prev = st.selected, st.prev

    if st.papamama then
        local u = (tex.get_current_ms() % 1000) / 1000
        local bob = 5 * S * (u < 0.5 and u * 2 or 2 - u * 2)
        tex.draw_texture(diff_select_sprite("papamama_announce"), { y = -bob, fade = fade })
    end

    local p       = player:player_num() .. "p"
    local suffix  = is_half and "_half" or ""
    local balloon      = diff_select_sprite(p .. "_balloon" .. suffix)
    local outline      = diff_select_sprite(p .. "_outline" .. suffix)
    local outline_back = diff_select_sprite(p .. "_outline_back" .. suffix)

    if selected <= DIFF_NEIRO or prev == DIFF_NEIRO then
        if prev == DIFF_NEIRO and selected >= DIFF_EASY then
            if not st.move2_done then
                local bx = ((prev + 3) * BALLOON_OFFSET_2) + BALLOON_OFFSET_1 + st.move2 * direction
                tex.draw_texture(balloon,      { x = bx, fade = fade })
                tex.draw_texture(outline_back, { x = ((prev + 3) * BALLOON_OFFSET_2) + st.move2 * direction })
            else
                local difficulty = math.min(DIFF_ONI, selected)
                tex.draw_texture(balloon, { x = difficulty * SELECTOR_OFFSET, fade = fade })
                tex.draw_texture(outline, { x = difficulty * SELECTOR_OFFSET })
            end
        elseif not st.move2_done then
            if selected ~= DIFF_BACK then
                tex.draw_texture(outline_back, { x = ((prev + 3) * BALLOON_OFFSET_2) + st.move2 * direction })
                local bx = ((prev + 3) * BALLOON_OFFSET_2) + BALLOON_OFFSET_1 + st.move2 * direction
                tex.draw_texture(balloon, { x = bx, fade = fade })
            else
                tex.draw_texture(outline_back, { x = ((prev + 3) * BALLOON_OFFSET_2) + st.move2 * direction, fade = fade })
            end
        else
            if selected ~= DIFF_BACK then
                tex.draw_texture(outline_back, { x = (selected + 3) * BALLOON_OFFSET_2 })
                tex.draw_texture(balloon, { x = ((selected + 3) * BALLOON_OFFSET_2) + BALLOON_OFFSET_1, fade = fade })
            else
                tex.draw_texture(outline_back, { x = (selected + 3) * BALLOON_OFFSET_2, fade = fade })
            end
        end
    else
        if prev == DIFF_NEIRO then return end
        if not st.move1_done then
            local difficulty = math.min(DIFF_ONI, prev)
            local bx = (difficulty * SELECTOR_OFFSET) + st.move1 * direction
            tex.draw_texture(balloon, { x = bx, fade = fade })
            tex.draw_texture(outline, { x = bx })
        else
            local difficulty = math.min(DIFF_ONI, selected)
            tex.draw_texture(balloon, { x = difficulty * SELECTOR_OFFSET, fade = fade })
            tex.draw_texture(outline, { x = difficulty * SELECTOR_OFFSET })
        end
    end
end

-- the four banner labels (easy .. oni), rebuilt when the language changes
local labels, labels_lang

local function diff_label(index)
    local lang = tex.language()
    if lang ~= labels_lang then
        labels = {}
        for i, key in ipairs({ "diff_tower_easy", "diff_tower_normal", "diff_tower_hard", "diff_tower_oni" }) do
            labels[i] = text.create_raw_text(tex.skin_text(key), DIFF_TEXT_FONT,
                { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 5.0, 2.0)
        end
        labels_lang = lang
    end
    return labels[index + 1]
end

local function global_sprite(name)
    return tex.get_texture("song_select/global/" .. name)
end

-- called only while a song is selected and a course is chosen
function M.draw_background_diffs(_self, player)
    local st       = player:bg_diff_state()
    local x_offset = (player:player_num() == 2) and BG_DIFF_P2_OFFSET or 0
    if st.oni_open_ms >= 0 then
        local elapsed = tex.get_current_ms() - st.oni_open_ms
        if elapsed < oni_open.DURATION_MS then
            oni_open.draw(elapsed, x_offset)
            return
        end
    end
    local bounce_y, bounce_y2 = -st.bounce, st.bounce
    local diff_frame     = math.min(DIFF_URA, st.selected)
    local diff_frame_oni = math.min(DIFF_ONI, st.selected)

    tex.draw_texture(global_sprite("background_diff"),
        { frame = diff_frame, x = x_offset, y = bounce_y, y2 = bounce_y2, fade = math.min(0.5, st.fade_in) })
    if st.highlight_on then
        tex.draw_texture(global_sprite("background_diff"),
            { frame = diff_frame, x = x_offset, y = bounce_y, y2 = bounce_y2 })
    end
    tex.draw_texture(global_sprite("background_diff_highlight"),
        { frame = diff_frame_oni, x = x_offset, fade = st.highlight_fade })
    tex.draw_texture(global_sprite("bg_diff_text_bg"),
        { scale = st.text_resize, center = true, x = x_offset, fade = math.min(0.5, st.text_fade_in) })

    local label = diff_label(diff_frame_oni)
    label:draw({
        scale = st.text_resize,
        center = true,
        x = DIFF_TEXT_X + x_offset - label.width / 2.0,
        y = DIFF_TEXT_Y - label.height / 2.0,
        fade = st.text_fade_in,
    })
end

-- The search overlay. A skin's SongSelect can set `search_box_layout = { x, y, width, height }` (pixels,
-- x/y offset from the screen centre) to move the text pill without drawing the overlay itself.
local search_text, search_text_str

function M.draw_search_box(self, box)
    local sw, sh = tex.get_screen_width(), tex.get_screen_height()
    tex.draw_rect(0, 0, sw, sh, 0, 0, 0, 153)
    local background = tex.get_texture("song_select/diff_sort/background")
    local info = tex.get_texture_info("diff_sort", "background")
    if not background or not info then return end

    local cx, cy = sw / 2.0, sh / 2.0
    tex.draw_texture(background, {
        scale = box.bg_resize, center = true,
        x = cx - (info.width / 2 + info.x[1]), y = cy - (info.height / 2 + info.y[1]),
    })

    local layout = self.search_box_layout or { x = 0, y = 0, width = 400 * S, height = 60 * S }
    local w, h = layout.width, layout.height
    local x, y = cx - w / 2 + layout.x, cy - h / 2 + layout.y
    local alpha = math.floor(255 * box.fade_in)
    tex.draw_rounded_rect(x, y, w, h, h > 0 and math.min(40 / h, 1) or 0,
        { 255, 255, 255, alpha }, 3, { 119, 26, 45, alpha })

    if box.search == "" then return end
    if box.search ~= search_text_str then
        search_text = text.create_raw_text(box.search, math.floor(30 * S),
            { 0, 0, 0, 255 }, { 0, 0, 0, 0 }, false, 0, 1.0)
        search_text_str = box.search
    end
    search_text:draw({ x = x + w / 2 - search_text.width / 2, y = y + h / 2 - search_text.height / 2 })
end

return M
