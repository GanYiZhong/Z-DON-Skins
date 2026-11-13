local STATE_BROWSING      = 0
local STATE_SONG_SELECTED = 1
local STATE_DIFF_SORTING  = 2
local STATE_SEARCHING     = 3
local STATE_DAN_SELECTED  = 4

require("global/guide_panel")

SongSelect = {}
SongSelect.__index = SongSelect

local base   = require("song_select/file_navigator/box_base")
local folder = require("song_select/file_navigator/box_folder")
local SKIN = {
    option_p2 = { x = 1466 },
}
require("song_select/file_navigator/box_song")
require("song_select/file_navigator/box_back")
require("song_select/file_navigator/box_dan")
require("song_select/selector")
require("song_select/modifier")
require("song_select/diff_sort")
local dan_transition_ok, dan_transition = pcall(require, "song_select/dan_transition")

local folder_leg = base.folder_leg
local DIFF_EASY, DIFF_URA = base.DIFF_EASY, base.DIFF_URA
local get_any = base.get_any
local draw_centered = base.draw_centered
local draw_title = base.draw_title
local draw_guide_label = base.draw_guide_label
local outline = base.outline
local GUIDE_SELECT_CX, GUIDE_DECIDE_CX, GUIDE_LABEL_CY = base.GUIDE_SELECT_CX, base.GUIDE_DECIDE_CX, base.GUIDE_LABEL_CY
local MOD_CX, MOD_JSON_Y, MOD_HEADER_CY = base.MOD_CX, base.MOD_JSON_Y, base.MOD_HEADER_CY
local leg_f, leg_event, is_decided = base.leg_f, base.leg_event, base.is_decided
local folder_frame = folder.folder_frame

local _last_box_draw_ms = nil

function SongSelect.new()
    local self = setmetatable({}, SongSelect)
    -- the default search overlay (player_ui) with this skin's text pill
    self.search_box_layout = { x = 0, y = -130, width = 1200, height = 93 }
    tex.load_folder("song_select", "global")
    tex.load_folder("song_select", "box")
    tex.load_folder("song_select", "yellow_box")
    tex.load_folder("song_select", "diff_select")
    tex.load_folder("song_select", "ss_sel")   -- SimpleStyle: own cursors / clouds
    self._ss = require("song_select/ss_sel").new()

    self.text_fade_in = tex.get_animation(4)
    self.text_fade_in:start()

    -- global
    self._id_footer            = tex.get_texture("song_select/global/footer")            or 0
    self._id_song_select       = get_any("global", "song_select")       or 0   -- 352x80 header at (30,30)
    self._id_difficulty_select = get_any("global", "difficulty_select") or 0
    -- Arcade control_guide panel drawn here, under the header, from the layered control_guide clip (GuidePanel).
    -- The engine's own Indicator is parked off-screen; the arcade hides it during course select.
    self._id_guide_panel = GuidePanel.new()

    -- box
    self._id_bar_genre      = tex.get_texture("song_select/box/bar_genre")          -- song boards, 960x352, frame = genre
    self._id_bar_folder     = tex.get_texture("song_select/box/folder_graphic")     -- genre (folder) boards, same layout
    self._id_bar_back       = tex.get_texture("song_select/box/bar_genre_back")     -- "back" board (brown)
    self._id_glow           = tex.get_texture("song_select/box/bar_genre_overlay")  -- yellow cursor glow 1024x400
    self._id_background     = tex.get_texture("song_select/box/background")         -- 2880x1080 scrolling bg, frame = genre
    self._id_box_chara      = tex.get_texture("song_select/box/box_chara")          -- 1920x480 genre characters (L at 510, R at 1410)
    self._id_pattern        = tex.get_texture("song_select/box/genre_overlay_large") -- 960x120 event pattern strip
    self._id_song_counter   = tex.get_texture("song_select/yellow_box/song_count_back") -- 280x72 number_of_songs plate

    -- yellow_box
    self._id_crown_dfc    = tex.get_texture("song_select/yellow_box/crown_dfc")     -- 72x72, frame = diff
    self._id_crown_fc     = tex.get_texture("song_select/yellow_box/crown_fc")
    self._id_crown_clear  = tex.get_texture("song_select/yellow_box/crown_clear")
    self._id_score_rank   = tex.get_texture("song_select/yellow_box/score_rank")    -- 72x72, frame = (rank-1)*5 + diff
    self._id_plate        = tex.get_texture("song_select/yellow_box/frame_score")   -- 184x96 diff plate, frame = diff
    self._id_level_number = tex.get_texture("song_select/yellow_box/level_number")  -- 48x48, frame = diff*11 + (level-1), 11 = "10+"
    self._id_star         = tex.get_texture("song_select/yellow_box/star")          -- 40x40 tinted star, frame = diff
    self._id_branch       = tex.get_texture("song_select/yellow_box/branch_indicator")       -- 40x40
    self._id_branch_diff  = tex.get_texture("song_select/yellow_box/branch_indicator_diff")  -- 40x40 (diff select)
    self._id_new_icon     = get_any("yellow_box", "ex_data_new_song")       -- 120x96 NEW icon

    -- diff_select
    self._id_backboard   = tex.get_texture("song_select/diff_select/difficulty_back")        -- 1272x784, frame = genre
    self._id_diff_board  = tex.get_texture("song_select/diff_select/difficulty_bar")         -- 200x360, frame = diff (4 = ura)
    self._id_course_frame  = tex.get_texture("song_select/diff_select/difficulty_select_bar")  -- 248x408 yellow glow frame
    self._id_course_frame2 = tex.get_texture("song_select/diff_select/difficulty_select_bar2") -- 248x408 outline variant
    self._id_bubble_1p   = tex.get_texture("song_select/diff_select/1p_balloon")             -- 124x124 cursor bubble + 1P
    self._id_bubble_2p   = tex.get_texture("song_select/diff_select/2p_balloon")
    self._id_btn_back    = get_any("diff_select", "back")                   -- 168x168 (localised lookup)
    self._id_btn_option  = get_any("diff_select", "option")
    self._neiro_in_options = tex.get_option("option_neiro_row")
    self._id_btn_glow    = tex.get_texture("song_select/yellow_box/s_crown_clear")            -- 168x168 button cursor plate
    self._id_small_crown = tex.get_texture("song_select/diff_select/difficulty_crown")       -- 40x40, frame = crown (0 none)
    self._id_small_rank  = tex.get_texture("song_select/yellow_box/s_crown_outline")          -- 40x40, frame = rank-1
    self._id_small_star  = tex.get_texture("song_select/diff_select/difficulty_star")        -- 40x40
    self._id_dot_bar     = tex.get_texture("song_select/diff_select/ura_oni_plate")          -- 172x24 dotted level bar
    self._id_dot_star    = tex.get_texture("song_select/diff_select/disable")                -- 24x24 star for the dots
    self._id_guide_s     = tex.get_texture("song_select/diff_select/diff_tower")             -- 372x96 control_guide_s loop sheet
    self._id_diff_mark   = tex.get_texture("song_select/diff_select/diff_tower_shadow")      -- 680x680 main_diff_mark 'wait', frame = course
    -- main_diff_mark 'course_decide_start' opaque shapes (mark_course + white backing).
    tex.load_folder("song_select", "diff_mark_anim")
    self._id_mark, self._id_mark_w = {}, {}
    for i = DIFF_EASY, DIFF_URA do
        self._id_mark[i]   = tex.get_texture("song_select/diff_mark_anim/mark_" .. i)
        self._id_mark_w[i] = tex.get_texture("song_select/diff_mark_anim/white_" .. i)
    end
    -- oni<->ura switch cells (340x400, 45 cells); the engine's own ura_switch is transparent.
    self._id_ura_to_ura  = tex.get_texture("song_select/yellow_box/s_crown_dfc")
    self._id_ura_to_oni  = tex.get_texture("song_select/yellow_box/s_crown_fc")

    self._neiro_label = nil
    self._back_label  = nil
    self._count_cache = {}
    self._folder_titles = {}
    self._song_titles   = {}
    self._song_titles_n = 0
    self._course_labels = {}
    self._chip_labels   = {}
    self._mark_diff     = {}   -- per player: last cursor column for main_diff_mark
    self._mark_decided  = {}   -- per player: { t0 = ms, course } once decided
    self._ura_prev      = nil  -- box.is_ura seen last frame (toggle detection)
    self._ura_anim      = nil  -- { t0 = ms, to_ura = bool } while the change plays
    self._guide_labels  = nil
    self._mod_title     = nil
    self._mod_seen      = {}   -- per player: modifier_active() last frame
    self._mod_t0        = {}   -- per player: ms the panel appeared
    self._mod_off       = {}   -- per player: panel y offset this frame (nil = no panel)
    return self
end

function SongSelect:update(current_ms)
    self.text_fade_in:update(current_ms)
    if self._ss then self._ss:update(current_ms) end
end

function SongSelect:restart_text_fade()
    self.text_fade_in:start()
end

function SongSelect:draw_footer()
    if self._ss then self._ss:draw_footer() end   -- SimpleStyle fix1029
end

-- 「M曲」: the blue right half of the number_of_songs plate (only when a limit is set).
local SONG_MAX_CX = 1836

function SongSelect:draw_song_max()
    if not tex.song_limit then return end
    local limit = tex.song_limit()
    if not limit or limit <= 0 then return end
    if self._song_max_n ~= limit then
        local sc = tex.get_skin_config("song_num") or {}
        self._song_max_y = sc.y or 252
        self._song_max   = text.create_raw_text((tex.skin_text("song_num_max"):gsub("{0}", tostring(limit))),
            sc.font_size or 24, { 255, 255, 255, 255 }, { 58, 38, 51, 255 }, false, outline(3.0), 2.0, 1.0)
        self._song_max_n = limit
    end
    local t = self._song_max
    if not t then return end
    t:draw({ x = math.floor(SONG_MAX_CX - (t.width - 2.0) / 2 + 0.5),
             y = math.floor(self._song_max_y + 0.5) })
end

-- 段位道場 shutter doors, drawn on the top-most skin slot.
function SongSelect:draw_top(dan_progress)
    if not dan_transition_ok then return end
    dan_transition.set_progress(dan_progress)
    dan_transition.draw()
end

function SongSelect:draw_overlays(state)
    self:draw_decided_bridge()
    if self._ss then self._ss:draw_mascots(state, self._mod_off) end
    if dan_transition_ok then dan_transition.arm(state == STATE_DAN_SELECTED) end
    -- number_of_songs plate, under the engine's own song_num text.
    -- SimpleStyle: practice select has no 「N曲目」 (session timer), so no empty plate either
    if self._id_song_counter and (tex.current_screen and tex.current_screen() or "") ~= "PRACTICE_SELECT" then
        tex.draw_texture(self._id_song_counter, { x = 1754 - 140 + 12, y = 195 })   -- fix1029
        if self._ss then self._ss:draw_count_max(1754 - 140 + 12, 195) end
    end
    self:draw_song_max()
    local label_fade = self.text_fade_in.attribute
    -- SimpleStyle: one hint pill (UI.hint, bottom centre)
    if self._ss then self._ss:draw_hint(state) end
    if state == STATE_SONG_SELECTED then
        self:draw_modifier_title()
    else
        self._mod_seen = {}; self._mod_off = {}
    end
end

-- 演奏オプション header title of the C++ option panel.
function SongSelect:draw_modifier_title()
    if self._mod_title == nil then
        self._mod_title = tex.get_skin_config("modifier_title")
            and text.create_text("modifier_title", { 58, 38, 51, 255 }, { 255, 255, 255, 0 }, false, 0, 2.0) or false
    end
    if not self._mod_title then return end
    local p2x = SKIN.option_p2; p2x = p2x and p2x.x or 1490
    for p = 1, 2 do
        local off = self._mod_off[p]
        if off then
            draw_title(self._mod_title, MOD_CX + (p - 1) * p2x, MOD_JSON_Y + MOD_HEADER_CY + off, 1.0)
        end
    end
end

-- Scrolling genre backdrop (2880x1080 per genre)
function SongSelect:draw_background(nav)
    self._frame_no = (self._frame_no or 0) + 1
    self:refresh_folder_context(nav)
    self._ss:draw_background()   -- SimpleStyle: static sky + ground, drifting clouds
end

-- The decided genre board while the loader owns it, until it has furled.
function SongSelect:draw_decided_bridge()
    if not folder_leg.dec_box then return end
    local lf = (folder_leg.kind == "open") and leg_f() or nil
    if lf and lf < folder_leg.open_swap - 1 then
        if self._dec_frame ~= self._frame_no then
            pcall(self.draw_folder_open, self, folder_leg.dec_box)
        end
    else
        folder_leg.dec_id, folder_leg.dec_box = nil, nil
    end
end

-- Inside an event folder every song board uses the event colour add, not its own genre.
-- Refreshed once per frame from draw_background (the only method handed the navigator).
function SongSelect:refresh_folder_context(nav)
    self._inside_frame = nil
    -- read the engine's wheel events (a bumped counter; only the newest transition matters)
    if nav then
        local ok, seq = pcall(function() return nav.wheel_event_seq end)
        if ok and seq ~= nil then
            folder_leg.have_events = true
            if folder_leg.seq == nil then
                folder_leg.seq = seq
            elseif seq ~= folder_leg.seq then
                folder_leg.seq = seq
                local ok2, id = pcall(function() return nav.wheel_event end)
                if ok2 and id then leg_event(id) end
            end
        end
    end

    if not (nav and nav.current_folder) then return end
    local f = nav:current_folder()
    if not f then return end
    local ff, is_event = folder_frame(f)
    if is_event then self._inside_frame = ff end
end

function SongSelect:guide_labels()
    if not self._guide_labels then
        local function mk(key)
            if tex.get_skin_config(key) then
                return text.create_text(key, { 58, 38, 51, 255 }, { 0, 0, 0, 0 }, false, 0, 2.0, 1.0)
            end
        end
        self._guide_labels = { select = mk("guide_select_label"), decide = mk("guide_decide_label") }
    end
    return self._guide_labels
end

-- In 2P the engine draws neither the diff-select backboard nor the Lua selector, so both
-- are driven from draw_box.
local function is_2p_screen()
    return (tex.current_screen and tex.current_screen() or "") == "SONG_SELECT_2P"
end

function SongSelect:draw_box(box)
    -- scene-entry detection: the first box draw (or the first after a >1 s gap) arms "nohold"
    local nowms = tex.get_current_ms()
    if _last_box_draw_ms == nil or (nowms - _last_box_draw_ms) > 1000.0 then
        folder_leg.nohold_once = true
        folder_leg.nohold_ms = nowms
    end
    _last_box_draw_ms = nowms

    local kind, state = box:lua_kind(), box:draw_state()

    if kind == "song" then
        if state == "diff_select" then
            -- in 2P the backboard is drawn once; latch _bg_drawn so it never double-draws
            if is_2p_screen() and not self._bg_drawn then
                self:draw_song_diff_select_bg(box)
            end
            self:draw_song_diff_select(box)
        elseif state == "open" then self:draw_song_open(box)
        else self:draw_song_closed(box) end
    elseif kind == "folder" then
        if state == "open" or is_decided(box) then self:draw_folder_open(box)
        else self:draw_folder_closed(box) end
    elseif kind == "back" then
        if state == "open" then self:draw_back_open(box)
        else self:draw_back_closed(box) end
    else
        self:draw_other_board(box, state)
    end
end

function SongSelect:draw_box_bg(box)
    if box:lua_kind() ~= "song" then return end
    self._bg_drawn = true
    self:draw_song_diff_select_bg(box)
end
