-- Entry mode-select board list (arcade reference layout). The C++ BoxManager owns
-- selection/input; this script only draws. All positions are 1080p pixels.

EntryBox = {}
EntryBox.__index = EntryBox

-- Shared list state (one Lua state for all boxes).
__hss_entry_boxes = __hss_entry_boxes or {}
__hss_entry_mode  = __hss_entry_mode or { sel = 1, t0 = 0 }

local CENTER_X, CENTER_Y = 960, 540   -- arcade open-board centre (round 9: +5, direct feed YKjsle7VBCI settled tile)
local FRAME_MS = 1000 / 60            -- one arcade frame in ms
local SLIDE_F  = 9                    -- list_anim_up/down slide length (frames, linear)
local TITLE_SIZE = 72                 -- text_title font size
local INFO_SIZE  = 34                 -- text_info font size
local TITLE_Y_ON, TITLE_Y_OFF = -97, 4
local INFO_CY, INFO_LINE_H = 59.5, 53
local TITLE_OUTER_T, TITLE_INNER_T = 8, 4   -- outer black rim / inner mode-colour outline
local INFO_COLOR   = { 255, 255, 255, 255 }
local INFO_OUTLINE = { 0, 0, 0, 255 }
local INFO_BORDER  = 5.0
local TITLE_SPACING, INFO_SPACING = 2.0, 1.0

-- Board art is baked into the parent's fixed texture "box" as framed textures; the
-- mode is recognised by matching the engine's title text against skin_config keys.
local MODES = {
    game = {
        frame = 0, outline = {251, 1, 29, 255},
        title_key = "entry_game",
        comment_keys = { "entry_game_comment_1", "entry_game_comment_2" },
    },
    practice = {
        frame = 2, outline = {34, 138, 117, 255},
        title_key = "entry_practice",
        comment_keys = { "entry_practice_comment_1", "entry_practice_comment_2" },
    },
    costume = {
        frame = 4, outline = {200, 120, 222, 255},
        title_key = "entry_costume",
        comment_keys = { "entry_costume_comment_1", "entry_costume_comment_2" },
        skin_font_lang = { zh = true },   -- FOT-Seurat has no glyph for the 咚 of "咚醬"
    },
    ai = {   -- frames 15/16: the arcade's AI board (ai label: teal, the robot and the girl, the 1P-only tag; direct feed 0wD5 0:11)
        frame = 15, outline = {34, 138, 117, 255},
        title_key = "entry_ai_battle",
        comment_keys = { "entry_ai_battle_comment_1", "entry_ai_battle_comment_2" },
        skin_font_lang = { zh = true },   -- FOT-Seurat has no glyph for the 咚 of "AI咚"
    },
    record = {   -- frames 13/14: Z-DON's recording mode (the practice board, recoloured pink)
        frame = 13, outline = {200, 28, 100, 255},
        title_key = "entry_record",
        comment_keys = { "entry_record_comment_1", "entry_record_comment_2" },
    },
    dan = {
        frame = 6, outline = {76, 60, 151, 255},
        title_key = "mode_dan",
        comment_keys = { "mode_dan_comment_1", "mode_dan_comment_2", "mode_dan_comment_3" },
    },
    settings = {
        frame = 9, outline = {0, 132, 212, 255},
        title_key = "entry_settings",
        comment_keys = { "entry_settings_comment_1", "entry_settings_comment_2" },
    },
}

-- ja/zh titles can be the same string, so prefer the engine's reported language,
-- then fall back to a scan over every language.
local LANGS = { "ja", "en", "zh", "ko" }
local function find_mode(text_str)
    local ok, cur = pcall(function() return tex.language() end)
    if ok and type(cur) == "string" then
        for key, m in pairs(MODES) do
            if tex.skin_text(m.title_key, cur) == text_str then return m, cur end
        end
    end
    for key, m in pairs(MODES) do
        for _, lang in ipairs(LANGS) do
            if tex.skin_text(m.title_key, lang) == text_str then return m, lang end
        end
    end
    return MODES.settings, "ja", true
end

local function ease_out(t)
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    return 1 - (1 - t) * (1 - t)
end

local function clamp01(v)
    if v <= 0 then return 0 end
    if v >= 1 then return 1 end
    return v
end

-- Board openness is a crossfade between the baked "off"/"on" plates, driven by
-- timelines sampled from anim/mode_board and anim/mode_list.
local sampler_ok, box_anim = pcall(require, "anim/sampler")
if not sampler_ok then
    box_anim = { safe = function()
        local n = {}
        n.at = function() return nil end; n.get = function() return nil end
        n.label = function() return nil end; n.has = function() return false end
        n.first = function() return 0 end;  n.last = function() return 0 end
        return n
    end }
end
local mode_board = box_anim.safe("anim/mode_board")
local CURSOR_GLOW = box_anim.safe("anim/cursor_glow")
local CURSOR_GLOW_LEN = math.max(1, CURSOR_GLOW:last() - CURSOR_GLOW:first() + 1)   -- 60 frames = 1 s
local mode_list = box_anim.safe("anim/mode_list")
local LIST_WAIT = mode_list:label("wait") or 13
local LIST_IN   = mode_list:label("in")   or 87
local BOARD_SELECT_ON  = mode_board:label("select_on")  or 27
local BOARD_ON         = mode_board:label("on")         or 42
local BOARD_SELECT_OFF = mode_board:label("select_off") or 52
local BOARD_IN         = mode_board:label("in")         or 67
local BOARD_CHOOSE     = mode_board:label("choose")     or 117
-- centre band scaleY at the two rest states -> the 0..1 openness the rest of the file speaks
local BOARD_SY_CLOSED, BOARD_SY_OPEN = 0.1857, 1.0

-- Clamp u so a caller that passes a huge value stays on the segment's last frame.
local function board_seg(base, u, limit)
    if u < 0 then u = 0 elseif u > limit then u = limit end
    return base + u
end
local function board_open(f)
    local sy = mode_board:get("board_bg_center_instance", f, "sy") or BOARD_SY_CLOSED
    return clamp01((sy - BOARD_SY_CLOSED) / (BOARD_SY_OPEN - BOARD_SY_CLOSED))
end

-- select_on (label 27): board grows, title rises, comment fades in.
local ON_LIMIT  = BOARD_SELECT_OFF - BOARD_SELECT_ON - 1
local OFF_LIMIT = BOARD_IN - BOARD_SELECT_OFF - 1
local IN_LIMIT  = BOARD_CHOOSE - BOARD_IN - 1
local function on_open(u)    return board_open(board_seg(BOARD_SELECT_ON, u, ON_LIMIT)) end
local function on_info(u) return mode_board:get("text_info_instance", board_seg(BOARD_SELECT_ON, u, ON_LIMIT), "a") or 0 end
-- select_off (label 52): comment fades out, board closes.
local function off_open(u)    return board_open(board_seg(BOARD_SELECT_OFF, u, OFF_LIMIT)) end
local function off_info(u) return mode_board:get("text_info_instance", board_seg(BOARD_SELECT_OFF, u, OFF_LIMIT), "a") or 0 end
-- in (label 67): four staggered ramps (fade, open, contents, cursor glow).
local function in_board_fade(t) return mode_board:get("board_bg_center_instance", board_seg(BOARD_IN, t, IN_LIMIT), "a") or 0 end
local function in_open(t)        return board_open(board_seg(BOARD_IN, t, IN_LIMIT)) end
local function in_contents(t)   return mode_board:get("text_info_instance", board_seg(BOARD_IN, t, IN_LIMIT), "a") or 0 end
local function in_cursor(t)     return mode_board:get("cursor_center", board_seg(BOARD_IN, t, IN_LIMIT), "a") or 0 end
local IN_TOTAL_F = IN_LIMIT
-- The list flies in: closed boards start three slots out and ease onto their slot.
local LIST_IN_DELAY_F, LIST_IN_F = 10, 12
local LIST_IN_DX, LIST_IN_DY = 170, 878
do
    local tx, ty = mode_list:at("kanban_3", LIST_IN)
    if tx then LIST_IN_DX, LIST_IN_DY = tx, ty end
end
-- choose (label 117): white board-shaped flash overlay.
local CHOOSE_LIMIT = mode_board:last() - BOARD_CHOOSE
local function choose_flash(c)
    if c < 0 then return 0 end
    if c > CHOOSE_LIMIT then return 0 end
    return mode_board:get("#22@6", BOARD_CHOOSE + c, "a") or 0
end

-- Slot offsets are read from the exported timeline; the fallback series matches it.
local function kanban_of(rel)
    if rel == 0 then return "kanban_1" end
    local n = math.abs(rel)
    return "kanban_" .. (2 * n + (rel < 0 and 0 or 1))
end
local function slot_offset(rel)
    if rel == 0 then return 0, 0 end
    local tx, ty = mode_list:at(kanban_of(rel), LIST_WAIT)
    if not tx then                       -- more slots than the arcade list carries
        local n, s = math.abs(rel), (rel < 0 and -1 or 1)
        return s * (50 + (n - 1) * 40), s * (305 + (n - 1) * 191)
    end
    return tx, ty
end

function EntryBox.new(text_str, font_size)
    local self = setmetatable({}, EntryBox)

    if __hss_entry_reset then
        __hss_entry_boxes = {}
        __hss_entry_mode  = { sel = 1, t0 = 0, in_t0 = nil }
        __hss_entry_reset = false
    end
    __hss_entry_boxes[#__hss_entry_boxes + 1] = self
    self.index = #__hss_entry_boxes

    local mode, lang, unknown = find_mode(text_str)
    self.mode = mode
    self.title_outer = text.create_raw_text(text_str, TITLE_SIZE, { 0, 0, 0, 255 }, { 0, 0, 0, 255 }, false, TITLE_OUTER_T, TITLE_SPACING)
    -- a second, thinner black pass fills the gaps the first leaves so the rim reads smooth
    self.title_outer2 = text.create_raw_text(text_str, TITLE_SIZE, { 0, 0, 0, 255 }, { 0, 0, 0, 255 }, false, TITLE_OUTER_T - 3, TITLE_SPACING)
    self.title       = text.create_raw_text(text_str, TITLE_SIZE, { 255, 255, 255, 255 }, mode.outline, false, TITLE_INNER_T, TITLE_SPACING)
    self.info  = {}
    if not unknown then
        local lines = {}
        for i, key in ipairs(mode.comment_keys) do lines[i] = tex.skin_text(key, lang) end
        local info_font = "FOT-Seurat_Pro_B.otf"
        if mode.skin_font_lang and mode.skin_font_lang[lang] then info_font = nil end
        for i, line in ipairs(lines) do
            self.info[i] = text.create_raw_text(line, INFO_SIZE, INFO_COLOR, INFO_OUTLINE, false,
                                                INFO_BORDER / tex.get_screen_scale(), INFO_SPACING, 1.0, info_font)
        end
    end

    self.board   = tex.get_texture("entry/mode_select/box")                  -- framed: see MAPPING.md
    self.cursor  = tex.get_texture("entry/mode_select/box_highlight_center") -- yellow glow ring
    self.frame_flash = 8   -- white silhouette of the "on" board
    self.frame_on, self.frame_off = mode.frame, mode.frame + 1

    -- animated state (screen px relative to the list centre)
    self.cur_x, self.cur_y = nil, nil
    self.from_x, self.from_y = 0, 0
    self.tgt_x, self.tgt_y = 0, 0
    self.t0 = 0
    self.open_t0, self.opening, self.was_selected = nil, false, false
    self.choose_t0 = nil

    return self
end

-- List slide: every board moves to its next slot linearly over SLIDE_F frames.
function EntryBox:_retarget(now, tx, ty, tvis)
    if self.cur_x == nil then
        self.cur_x, self.cur_y, self.cur_vis = tx, ty, tvis
        self.tgt_x, self.tgt_y, self.tgt_vis = tx, ty, tvis
        self.from_x, self.from_y, self.from_vis = tx, ty, tvis
        self.t0 = now - SLIDE_F * FRAME_MS
        return
    end
    if tx ~= self.tgt_x or ty ~= self.tgt_y or tvis ~= self.tgt_vis then
        self.from_x, self.from_y, self.from_vis = self.cur_x, self.cur_y, self.cur_vis
        self.tgt_x, self.tgt_y, self.tgt_vis = tx, ty, tvis
        self.t0 = now
    end
    local p = clamp01((now - self.t0) / (SLIDE_F * FRAME_MS))
    self.cur_x   = self.from_x   + (self.tgt_x   - self.from_x)   * p
    self.cur_y   = self.from_y   + (self.tgt_y   - self.from_y)   * p
    self.cur_vis = self.from_vis + (self.tgt_vis - self.from_vis) * p
end

-- Box::draw(x, left_x, right_x, is_selected, move_finished, open_attr, fade, y_pos).
-- `fade < 1` is the engine's decide signal (its entry animation), so it drives `choose`.
function EntryBox:draw(x, left_x, right_x, is_selected, move_finished, open_attr, fade, y_pos)
    local now = tex.get_current_ms()
    local shared = __hss_entry_mode
    if shared.in_t0 == nil then shared.in_t0 = now end     -- first frame the list is drawn
    __hss_entry_guide = { ms = now, phase = "mode", count = #__hss_entry_boxes }
    if is_selected and shared.sel ~= self.index then
        shared.sel = self.index
        shared.t0 = now
    end

    -- The open runs after the slide, so delay select_on by the slide length.
    if is_selected ~= self.was_selected then
        self.was_selected = is_selected
        self.open_t0 = now + (is_selected and SLIDE_F * FRAME_MS or 0)
        self.opening = is_selected
    end

    local t_in = (now - shared.in_t0) / FRAME_MS                  -- frames since the list appeared
    local in_running = t_in <= IN_TOTAL_F

    local rel = self.index - shared.sel
    local ox, oy = slot_offset(rel)
    -- boards further than one slot away fade out
    self:_retarget(now, ox, oy, (math.abs(rel) <= 1) and 1 or 0)

    local dx, dy = self.cur_x, self.cur_y
    -- list fly-in: the closed boards start three slots out and ease onto their slot
    if in_running and rel ~= 0 then
        local q = ease_out(clamp01((t_in - LIST_IN_DELAY_F) / LIST_IN_F))
        local s = (rel < 0) and -1 or 1
        dx = dx + (1 - q) * (s * LIST_IN_DX - ox)
        dy = dy + (1 - q) * (s * LIST_IN_DY - oy)
    end

    -- openness (0 = "off" board, 1 = "on"); the `in` timeline owns it while running
    local o, info_a, cursor_a
    if in_running then
        o        = is_selected and in_open(t_in) or 0
        info_a   = is_selected and in_contents(t_in) or 0
        cursor_a = is_selected and in_cursor(t_in) or 0
        fade     = (fade or 1.0) * in_board_fade(t_in)
    else
        local u = self.open_t0 and ((now - self.open_t0) / FRAME_MS) or 999
        if self.opening then
            o, info_a = on_open(u), on_info(u)
        else
            o, info_a = off_open(u), off_info(u)
        end
        cursor_a = o
        fade = fade or 1.0
    end
    local vis_fade = fade * self.cur_vis
    if vis_fade <= 0.001 then return end

    -- the cursor glow sits under the board, so characters leaning out stand in front of it
    if cursor_a > 0.001 then
        local pulse = CURSOR_GLOW:get("#12@0", (now * 0.06) % CURSOR_GLOW_LEN, "a") or 1.0
        tex.draw_texture(self.cursor, { x = dx, y = dy, fade = vis_fade * cursor_a * pulse })
    end
    if o < 0.999 then
        tex.draw_texture(self.board, { frame = self.frame_off, x = dx, y = dy, fade = vis_fade * (1 - o) })
    end
    if o > 0.001 then
        tex.draw_texture(self.board, { frame = self.frame_on, x = dx, y = dy, fade = vis_fade * o })
    end
    if info_a > 0.001 and #self.info > 0 then
        local n = #self.info
        for i, t in ipairs(self.info) do
            local cy = CENTER_Y + dy + INFO_CY + (i - 1 - (n - 1) / 2) * INFO_LINE_H
            t:draw({ x = CENTER_X + dx - (t.width - INFO_SPACING) / 2, y = cy - t.height / 2, fade = vis_fade * info_a })
        end
    end

    -- title rides openness and, during `in`, fades in with the comment
    local title_a = vis_fade
    if in_running and is_selected then title_a = vis_fade * in_contents(t_in) end
    local ty = TITLE_Y_OFF + (TITLE_Y_ON - TITLE_Y_OFF) * o
    self.title_outer:draw({
        x = CENTER_X + dx - (self.title_outer.width - TITLE_SPACING) / 2,
        y = CENTER_Y + dy + ty - self.title_outer.height / 2,
        fade = title_a,
    })
    self.title_outer2:draw({
        x = CENTER_X + dx - (self.title_outer2.width - TITLE_SPACING) / 2,
        y = CENTER_Y + dy + ty - self.title_outer2.height / 2,
        fade = title_a,
    })
    self.title:draw({
        x = CENTER_X + dx - (self.title.width - TITLE_SPACING) / 2,
        y = CENTER_Y + dy + ty - self.title.height / 2,
        fade = title_a,
    })

    -- `choose`: the picked board flashes white
    if fade < 0.999 and is_selected then
        if self.choose_t0 == nil then self.choose_t0 = now end
        local fl = choose_flash((now - self.choose_t0) / FRAME_MS)
        if fl > 0.001 then
            tex.draw_texture(self.board, { frame = self.frame_flash, x = dx, y = dy, fade = fl })
        end
    end
end
