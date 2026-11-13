-- SongSelectState constants (must match enums.h)
local STATE_BROWSING      = 0
local STATE_SONG_SELECTED = 1
local STATE_DIFF_SORTING  = 2
local STATE_SEARCHING     = 3
local STATE_DAN_SELECTED  = 4

SongSelect = {}
SongSelect.__index        = SongSelect

require("song_select/file_navigator/box_base")
require("song_select/file_navigator/box_song")
require("song_select/file_navigator/box_folder")
require("song_select/file_navigator/box_back")
require("song_select/file_navigator/genre_bg")
local base = require("song_select/file_navigator/box_base")

function SongSelect.new()
    local self = setmetatable({}, SongSelect)
    base.reset_yellow_box()
    tex.load_folder("song_select", "global")
    tex.load_folder("song_select", "box")
    tex.load_folder("song_select", "yellow_box")
    tex.load_folder("song_select", "diff_select")
    if tex.current_screen() == "SONG_SELECT_2P" then tex.load_folder("waiwai_song_select", "enter") end
    -- upstream AI battle (Green): its AI select background; Z-DON's AI select keeps SongSelect:draw_background
    if tex.current_screen() == "AI_SELECT" and not tex.zdon_ai_select() then
        self.draw_background = require("song_select/ai_background").new()
    end

    -- Animations (IDs from song_select/animation.json)
    self.text_fade_in    = tex.get_animation(4)   -- fade in/out the top-left label text
    self.blue_arrow_fade = tex.get_animation(29)  -- blue arrow opacity pulse
    self.blue_arrow_move = tex.get_animation(30)  -- blue arrow horizontal drift

    self.blue_arrow_fade:start()
    self.blue_arrow_move:start()
    self.text_fade_in:start()

    -- Cached texture IDs
    self._id_footer            = tex.get_texture("song_select/global/footer")            or 0
    self._id_arrow             = tex.get_texture("song_select/global/arrow")             or 0
    self._id_song_num_bg       = tex.get_texture("song_select/global/song_num_bg")       or 0

    local waiwai_title = tex.current_screen() == "WAIWAI_SONG_SELECT"
        and tex.get_texture("waiwai_song_select/panels/mode_title")
    self._id_song_select       = waiwai_title or tex.get_texture("song_select/global/song_select") or 0
    self._id_difficulty_select = tex.get_texture("song_select/global/difficulty_select") or 0

    return self
end

function SongSelect:update(current_ms)
    self.text_fade_in:update(current_ms)
    self.blue_arrow_fade:update(current_ms)
    self.blue_arrow_move:update(current_ms)
    base.update_yellow_box(current_ms)
end

-- Call whenever the screen state changes so the label cross-fades correctly.
function SongSelect:restart_text_fade()
    self.text_fade_in:start()
end

-- Z-DON AI battle: the AI select may draw Green's AI room. The engine skips its own background whenever this
-- hook exists, so the genre background (Navigator::draw_background) is drawn here too.
function SongSelect:draw_background(nav)
    if tex.zdon_ai_select() and require("global.ai_battle").draw_select_bg() then return end
    self._id_background = self._id_background or tex.get_texture("box/background") or 0
    local info = tex.get_texture_info("box", "background")
    if self._id_background == 0 or not info then return end
    local width = info.width
    local move = nav:background_move().attribute
    local fade_change = nav:background_fade_change().attribute
    local last_frame = nav:last_bg_genre_frame()
    local curr_frame = nav:bg_genre_frame()
    for i = 0, width * 3, width do
        tex.draw_texture(self._id_background, { frame = last_frame, x = i - move })
        tex.draw_texture(self._id_background, { frame = curr_frame, x = i - move, fade = 1 - fade_change })
    end
end

-- Z-DON AI battle (skin_config zdon_ai_arcade_flow): the arcade's columns as the Diff Sort window; false = the default one
function SongSelect:draw_sort_window(w)
    if tex.zdon_ai_select() then return require("global.ai_battle").draw_sort_window(w) end
    return false
end

-- Z-DON AI battle (zdon_ai_arcade_flow): the cabinet's counter is plain outlined text, no pill
function SongSelect:draw_song_num()
    if tex.zdon_ai_select() then return require("global.ai_battle").draw_song_counter() end
    return false
end

function SongSelect:draw_footer()
    if tex.zdon_ai_select() then require("global.ai_battle").draw_stage() end   -- Z-DON: under the Don
    tex.draw_texture(self._id_footer)
    if tex.zdon_ai_select() then require("global.ai_battle").draw_floor_dim() end
end

-- Draw the navigation arrows and the top-left state label.
-- state: one of the STATE_* constants above (passed from C++ as an int).
function SongSelect:draw_overlays(state)
    if tex.zdon_ai_select() then require("global.ai_battle").draw_select(state) end   -- Z-DON
    -- Blue navigation arrows are only shown while browsing.
    -- strict audit (round 2): the AI battle's course-first page has none (direct feed t=114.5)
    if state == STATE_BROWSING and not (tex.ai_diff_stage and (tex.ai_diff_stage() or -1) >= 0) then
        local drift = self.blue_arrow_move.attribute * 2
        local fade  = self.blue_arrow_fade.attribute
        local adx, ady = 0, 0
        if tex.zdon_ai_select() then adx, ady = require("global.ai_battle").sel_off("arrows") end
        if not (tex.zdon_ai_select() and (require("global.ai_battle").draw_list_arrows(fade, drift)
                or require("global.ai_battle").draw_p0_arrows())) then
            tex.draw_texture(self._id_arrow, { x = -drift + adx,       y = ady, fade = fade, index = 0 })
            tex.draw_texture(self._id_arrow, { mirror = "horizontal",
                                      x =  drift + adx,       y = ady, fade = fade, index = 1 })
        end
    end

    -- Top-left label: cross-fade between "SONG SELECT" and "DIFFICULTY SELECT".
    -- Z-DON AI battle: the cabinet has no label there, the rank-up conditions take the corner
    if tex.zdon_ai_select() then return end
    local label_fade = self.text_fade_in.attribute
    if state == STATE_SONG_SELECTED then
        tex.draw_texture(self._id_difficulty_select, { fade = label_fade })
        tex.draw_texture(self._id_song_select,       { fade = 1 - label_fade })
    else
        tex.draw_texture(self._id_difficulty_select, { fade = 1 - label_fade })
        tex.draw_texture(self._id_song_select,       { fade = label_fade })
    end
end

function SongSelect:draw_box(box)
    base.track_yellow_box(box)
    local kind = box:lua_kind()
    local state = box:draw_state()
    if kind == "song" then
        if state == "diff_select" then
            self:draw_song_diff_select(box)
        elseif state == "open" then
            self:draw_song_open(box)
        else
            self:draw_song_closed(box)
        end
    elseif kind == "folder" then
        if state == "open" then
            self:draw_folder_open(box)
        else
            self:draw_folder_closed(box)
        end
    elseif kind == "back" then
        if state == "open" then
            self:draw_back_open(box)
        else
            self:draw_back_closed(box)
        end
    end
end
