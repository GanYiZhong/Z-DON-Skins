local SKIN_S = tex.get_screen_scale()
local SKIN = {
    yellow_box_bottom = { y = 539 * SKIN_S },
}
-- Shared BaseBox + YellowBox draw code and text helpers, split out of song_select.lua.
-- Mirrors src/objects/song_select/file_navigator/box_base.cpp and box_yellow.cpp.
-- All positions are in the skin's own pixels (1280x720 for PyTaikoGreen); box positions
-- and engine animations are already in screen pixels.

local M = {}

-- TextureIndex (box/folder_texture colour frame) — must match enums.h.
local TI_NONE, TI_VOCALOID, TI_DEFAULT, TI_RECOMMENDED, TI_FAVORITE, TI_RECENT = 0, 1, 2, 3, 4, 5
-- GenreIndex (raw enum; folder_graphic / diff_overlay frame) — must match enums.h.
local GI_DIFFICULTY = 14
local GI_TUTORIAL, GI_DAN = 0, 13

M.TI_NONE, M.TI_DEFAULT = TI_NONE, TI_DEFAULT
M.GI_DIFFICULTY = GI_DIFFICULTY
M.GI_TUTORIAL, M.GI_DAN = GI_TUTORIAL, GI_DAN

-- Lazy texture cache: tex.get_texture returns nil on a miss, and the C++ board code
-- dereferences these unconditionally, so cache the resolved id (or nil) once.
local _tex = {}
local function T(subset, name)
    local key = subset .. "/" .. name
    local id = _tex[key]
    if id == nil then
        id = tex.get_texture("song_select/" .. subset .. "/" .. name)
        _tex[key] = id
    end
    return id
end
M.T = T

-- Lazy skin_config geometry.
local _song_box_bg_width, _yellow_box_bottom_y, _edge_height
local function song_box_bg_width()
    if _song_box_bg_width == nil then
        local c = tex.get_skin_config("song_select_box_bg")
        _song_box_bg_width = (c and c.width) or 0
    end
    return _song_box_bg_width
end
local function yellow_box_bottom_y()
    if _yellow_box_bottom_y == nil then
        local c = SKIN.yellow_box_bottom
        _yellow_box_bottom_y = (c and c.y) or 0
    end
    return _yellow_box_bottom_y
end
local function edge_height()
    if _edge_height == nil then
        local info = tex.get_texture_info("yellow_box", "yellow_box_bottom_right")
        _edge_height = (info and info.height) or 0
    end
    return _edge_height
end
M.song_box_bg_width = song_box_bg_width

-- Count UTF-8 codepoints (== Lua string length for ASCII; handles multibyte genres).
function M.utf8_char_count(s)
    local count = 0
    local i = 1
    while i <= #s do
        local c = s:byte(i)
        if not c then break end
        if (c & 0xC0) ~= 0x80 then count = count + 1 end
        i = i + 1
    end
    return count
end

-- The five yellow_box shadow strips. index 0 = closed (1p), index 1 = open (2p/highlight).
function M.draw_shadows(bx, by, fade, index)
    tex.draw_texture(T("yellow_box", "shadow_bottom_left"),  { x = bx, y = by, fade = fade, index = index })
    tex.draw_texture(T("yellow_box", "shadow_bottom"),       { x = bx, y = by, fade = fade, index = index })
    tex.draw_texture(T("yellow_box", "shadow_bottom_right"), { x = bx, y = by, fade = fade, index = index })
    tex.draw_texture(T("yellow_box", "shadow_right"),        { x = bx, y = by, fade = fade, index = index })
    tex.draw_texture(T("yellow_box", "shadow_top_right"),    { x = bx, y = by, fade = fade, index = index })
end

-- The 9-slice yellow frame (YellowBox::draw). is_diff picks the diff-select animation set.
function M.draw_yellow_box(is_diff, fade, y_offset)
    y_offset = y_offset or 0
    local right_x       = tex.get_animation(is_diff and 14 or 10).attribute
    local left_x        = tex.get_animation(is_diff and 13 or 9).attribute
    local center_width  = tex.get_animation(is_diff and 15 or 11).attribute
    local top_y         = tex.get_animation(16).attribute
    local center_height = tex.get_animation(17).attribute
    local bottom_y      = yellow_box_bottom_y()
    local eh            = edge_height()

    tex.draw_texture(T("yellow_box", "yellow_box_bottom_right"), { x = right_x,             y = bottom_y + y_offset,      fade = fade })
    tex.draw_texture(T("yellow_box", "yellow_box_bottom_left"),  { x = left_x,              y = bottom_y + y_offset,      fade = fade })
    tex.draw_texture(T("yellow_box", "yellow_box_top_right"),    { x = right_x,             y = top_y + y_offset,         fade = fade })
    tex.draw_texture(T("yellow_box", "yellow_box_top_left"),     { x = left_x,              y = top_y + y_offset,         fade = fade })
    tex.draw_texture(T("yellow_box", "yellow_box_bottom"),       { x = left_x + eh,         y = bottom_y + y_offset,      x2 = center_width,  fade = fade })
    tex.draw_texture(T("yellow_box", "yellow_box_right"),        { x = right_x,             y = top_y + eh + y_offset,    y2 = center_height, fade = fade })
    tex.draw_texture(T("yellow_box", "yellow_box_left"),         { x = left_x,              y = top_y + eh + y_offset,    y2 = center_height, fade = fade })
    tex.draw_texture(T("yellow_box", "yellow_box_top"),          { x = left_x + eh,         y = top_y + y_offset,         x2 = center_width,  fade = fade })
    tex.draw_texture(T("yellow_box", "yellow_box_center"),       { x = left_x + eh,         y = top_y + eh + y_offset,    x2 = center_width,  y2 = center_height, fade = fade })
end

-- BaseBox::draw_closed — the generic folder_texture board (colour frame = texture_index).
-- BackBox and DanBox reuse this; SongBox/FolderBox call it before their own closed content.
function M.draw_base_closed(box)
    local bx = box:box_x()
    local by = box:box_y()
    local fade = box.fade.attribute
    local tex_index = box:texture_index()
    local use_shader = box:has_recolor()

    M.draw_shadows(bx, by, fade, 0)

    if use_shader then box:begin_recolor() end
    tex.draw_texture(T("box", "folder_texture_left"),  { frame = tex_index, x = bx, y = by, fade = fade })
    tex.draw_texture(T("box", "folder_texture"),       { frame = tex_index, x = bx, y = by, x2 = song_box_bg_width(), fade = fade })
    tex.draw_texture(T("box", "folder_texture_right"), { frame = tex_index, x = bx, y = by, fade = fade })
    if use_shader then box:end_recolor() end

    if tex_index == TI_DEFAULT then
        tex.draw_texture(T("box", "genre_overlay"), { x = bx, y = by, fade = fade })
    end
    if box:genre_index() == GI_DIFFICULTY then
        tex.draw_texture(T("box", "diff_overlay"), { x = bx, y = by, fade = fade })
    end
end

-- The vertical song/folder title (BaseBox::load_text name). text_color is always white for
-- song/folder/back; the outline is the genre's fore_color. Cached per box on `self`.
function M.vertical_name(self, box)
    self._name_cache = self._name_cache or {}
    local name = box.text_name or ""
    local fc = box:fore_color() or { r = 0, g = 0, b = 0, a = 255 }
    local key = box:path() .. "\0" .. tostring(fc.r or 0) .. "." .. tostring(fc.g or 0) .. "." .. tostring(fc.b or 0)
    local t = self._name_cache[key]
    if t == nil then
        local cfg = tex.get_skin_config("song_select_box_name")
        local font_size = (cfg and cfg.font_size) or 40
        if M.utf8_char_count(name) >= 30 then
            font_size = font_size - 10 * tex.get_screen_scale()
        end
        local outline = { fc.r or 0, fc.g or 0, fc.b or 0, fc.a or 255 }
        t = text.create_raw_text(name, font_size, { 255, 255, 255, 255 }, outline, true, 5.0, 2.0, 1.0)
        self._name_cache[key] = t
    end
    return t
end

-- Highest-crown helper shared by SongBox/FolderBox closed states.
-- Returns frame (min(diff, URA)) and the crown value, or nil.
function M.highest_crown(map)
    local highest_key = -1
    for k in pairs(map) do
        if type(k) == "number" and k > highest_key then highest_key = k end
    end
    if highest_key < 0 then return nil end
    local frame = math.min(4, highest_key)   -- Difficulty::URA == 4
    return map[highest_key], frame
end

-- Draw a single crown icon (crown_dfc/crown_fc/crown_clear) at frame, position px, y.
-- crowns: {0=none,1=clear,2=fc,3=dfc}
function M.draw_crown(crown, frame, px, y, fade)
    if crown == 3 then
        tex.draw_texture(T("yellow_box", "crown_dfc"),   { frame = frame, x = px, y = y, fade = fade })
    elseif crown == 2 then
        tex.draw_texture(T("yellow_box", "crown_fc"),    { frame = frame, x = px, y = y, fade = fade })
    elseif crown and crown >= 1 then
        tex.draw_texture(T("yellow_box", "crown_clear"), { frame = frame, x = px, y = y, fade = fade })
    end
end

-- Localized song count ("全{0}曲" / "{0} Songs").
function M.format_song_count(count)
    local template = tex.skin_text("song_count")
    if template == "" then template = "全{0}曲" end
    local out, n = template:gsub("{0}", tostring(count))
    if n == 0 then out = template .. tostring(count) end
    return out
end

-- ---------------------------------------------------------------------------
-- Yellow-box animation driving. The engine no longer starts/advances the shared
-- yellow-box animations (9..18); the skin does it, keyed off the box draw_state.
-- ---------------------------------------------------------------------------
local YB_OPEN_ANIMS  = { 9, 10, 11 }
local YB_DIFF_ANIMS  = { 13, 14, 15, 16, 17, 18 }
local YB_RESET_ANIMS = { 9, 10, 11, 14, 16, 17 }

local function yb_anim(id) return tex.get_animation(id) end

local function yb_open()     -- expand_box reset + create_anim (start 9/10/11)
    for _, id in ipairs(YB_RESET_ANIMS) do yb_anim(id):reset() end
    for _, id in ipairs(YB_OPEN_ANIMS) do yb_anim(id):start() end
    -- Z-DON AI select (zdon_ai_instant_page0): the cabinet's page 0 is already open at the cut
    if tex.ai_instant_open and tex.ai_instant_open() then
        for _, id in ipairs(YB_OPEN_ANIMS) do yb_anim(id):fast_forward() end
    end
end
local function yb_diff()     -- create_anim_2 (start 13..18)
    for _, id in ipairs(YB_DIFF_ANIMS) do yb_anim(id):start() end
end
local function yb_back()     -- exit_box -> create_anim (reset 14/16/17 + start 9/10/11)
    yb_anim(14):reset(); yb_anim(16):reset(); yb_anim(17):reset()
    for _, id in ipairs(YB_OPEN_ANIMS) do yb_anim(id):start() end
end

-- Per-open-box state (only one box is open at a time).
local yb_box = { path = nil, state = "closed" }

function M.reset_yellow_box()
    yb_box.path, yb_box.state = nil, "closed"
end

-- Call once per box from draw_box; detects open/enter/exit transitions.
function M.track_yellow_box(box)
    local state = box:draw_state()
    local path = box:path()
    if state == "closed" then
        if yb_box.path == path then
            yb_box.path, yb_box.state = nil, "closed"
        end
        return
    end
    if yb_box.path ~= path then
        yb_box.path, yb_box.state = path, state
        yb_open()
        if state == "diff_select" then yb_diff() end
    elseif yb_box.state ~= state then
        yb_box.state = state
        if state == "diff_select" then yb_diff() else yb_back() end
    end
end

-- Call once per frame from SongSelect:update; advances the shared yellow-box animations.
function M.update_yellow_box(current_ms)
    for _, id in ipairs(YB_OPEN_ANIMS) do yb_anim(id):update(current_ms) end
    for _, id in ipairs(YB_DIFF_ANIMS) do yb_anim(id):update(current_ms) end
end

return M
