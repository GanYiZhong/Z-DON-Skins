-- 演奏オプション / 音色 board — replaces ModifierSelector::draw() / NeiroSelector::draw().
-- Same texture.json bases and skin_config keys the C++ board used, so geometry is exact.
-- Split out of song_select.lua.

local base = require("song_select/file_navigator/box_base")
local SKIN = {
    modifier_offset = { y = 61 },
    modifier_offset_2 = { x = 44, y = 140 },
    modifier_text = { x = 300, y = 1178, font_size = 26 },
    option_p2 = { x = 1490 },
}

local get_any = base.get_any
local outline = base.outline

local OPT_CURSOR_MS     = 1000                  -- cursor loop = 60 frames @ 60 fps
local OPT_CURSOR_MIN    = 51 / 256              -- its alpha floor
local OPT_GREY          = { 166, 168, 171, 255 }
local OPT_CHANGED       = { 255, 255, 0, 255 }
local OPT_SCRIM         = { 0, 0, 0, 128 }
local OPT_ARROW_NUDGE   = 5

function SongSelect:_opt_ids()
    if self._opt_ids_t then return self._opt_ids_t end
    -- Must load these subsets here: script_manager.tex is its own TextureWrapper, so a
    -- subset the engine loaded elsewhere is not resident in the Lua one.
    tex.load_folder("song_select", "modifier")
    tex.load_folder("song_select", "neiro")
    local t = {}
    t.top    = get_any("modifier", "top")
    t.bottom = get_any("modifier", "bottom")
    t.bg     = get_any("modifier", "background")
    t.row    = get_any("modifier", "mod_bg")
    t.row_hl = get_any("modifier", "mod_bg_highlight")
    t.box    = get_any("modifier", "mod_box")
    t.arrow  = get_any("modifier", "blue_arrow")
    t.p      = { get_any("modifier", "1p"), get_any("modifier", "2p") }
    t.icon   = {
        auto     = get_any("modifier", "mod_auto"),
        speed    = get_any("modifier", "mod_baisaku"),
        sanbai   = get_any("modifier", "mod_sanbai"),
        yonbai   = get_any("modifier", "mod_yonbai"),
        speed_by_value = {
            [11] = get_any("modifier", "mod_speed_x1_1"), [12] = get_any("modifier", "mod_speed_x1_2"),
            [13] = get_any("modifier", "mod_speed_x1_3"), [14] = get_any("modifier", "mod_speed_x1_4"),
            [15] = get_any("modifier", "mod_speed_x1_5"), [16] = get_any("modifier", "mod_speed_x1_6"),
            [17] = get_any("modifier", "mod_speed_x1_7"), [18] = get_any("modifier", "mod_speed_x1_8"),
            [19] = get_any("modifier", "mod_speed_x1_9"), [20] = get_any("modifier", "mod_speed_x2"),
            [25] = get_any("modifier", "mod_speed_x2_5"), [30] = get_any("modifier", "mod_speed_x3"),
            [35] = get_any("modifier", "mod_speed_x3_5"), [40] = get_any("modifier", "mod_speed_x4"),
        },
        display  = get_any("modifier", "mod_doron"),
        inverse  = get_any("modifier", "mod_abekobe"),
        kimagure = get_any("modifier", "mod_kimagure"),
        detarame = get_any("modifier", "mod_detarame"),
    }
    self._opt_ids_t = t
    return t
end

-- Row label / value strings as OutlinedText, cached by content.
function SongSelect:_opt_text(s)
    if s == nil or s == "" then return nil end
    if not self._opt_texts then
        self._opt_texts = {}
        local cfg = SKIN.modifier_text
        self._opt_font = (cfg and cfg.font_size ~= 0 and cfg.font_size) or 26
    end
    local t = self._opt_texts[s]
    if t == nil then
        t = text.create_raw_text(s, self._opt_font, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, outline(3.0), 2.0) or false
        self._opt_texts[s] = t
    end
    return t or nil
end

-- Arcade cursor pulse, sampled from anim/option_cursor; hand triangle is the fallback.
local option_cursor_ok, option_cursor_anim = pcall(require, "anim/sampler")
local OPT_CURSOR_CLIP = (option_cursor_ok and option_cursor_anim.safe("anim/option_cursor"))
                        or { get = function() return nil end, first = function() return 0 end,
                             last = function() return 0 end }
local OPT_CURSOR_LEN  = math.max(1, OPT_CURSOR_CLIP:last() - OPT_CURSOR_CLIP:first() + 1)
local function opt_cursor_alpha(ms)
    local f = (ms * 0.06) % OPT_CURSOR_LEN
    local a = OPT_CURSOR_CLIP:get("#3@0", f, "a")
    if a then return a end
    local u = (ms % OPT_CURSOR_MS) / OPT_CURSOR_MS
    local tri = (u < 0.5) and (u * 2) or ((1 - u) * 2)
    return 1.0 - (1.0 - OPT_CURSOR_MIN) * tri
end

-- One board. `rows` = {label, value, changed, greyed, name}; `cursor` = 1-based row (nil = none).
function SongSelect:draw_option_board(player, offset, rows, cursor, change)
    local ids = self:_opt_ids()
    if not ids.top or not ids.row or not ids.box then return end
    local p     = player:player_num()
    local p2cfg = SKIN.option_p2
    local x     = (p - 1) * ((p2cfg and p2cfg.x) or 1490)
    local pitch = SKIN.modifier_offset
    pitch       = (pitch and pitch.y ~= 0 and pitch.y) or 61
    local tcfg  = SKIN.modifier_text
    local ocfg  = SKIN.modifier_offset_2
    local text_x, text_y = (tcfg and tcfg.x) or 300, (tcfg and tcfg.y) or 1178
    local name_x         = (ocfg and ocfg.x) or 44
    local arrow_span     = (ocfg and ocfg.y) or 140
    local n              = #rows
    local ms             = tex.get_current_ms()

    tex.draw_texture(ids.top, { x = x, y = offset })
    if n > 7 then
        -- Z-DON adds rows (等速): the frame image holds seven; its rows part and foot are drawn again lower
        -- (rows start 86 px into the 420 x 538 frame)
        local extra = (n - 7) * pitch
        tex.draw_texture(ids.top, { x = x, y = offset + extra + 86, y2 = -86,
                                    src = { x = 0, y = 86, width = 420, height = 538 - 86 } })
    end
    if ids.p[p] then tex.draw_texture(ids.p[p], { x = x, y = offset }) end
    if ids.bottom then tex.draw_texture(ids.bottom, { x = x, y = offset + n * pitch }) end

    for i = 1, n do
        local row    = rows[i]
        local row_y  = offset + (i - 1) * pitch
        local is_cur = (cursor == i)

        if ids.bg then tex.draw_texture(ids.bg, { x = x, y = row_y }) end
        tex.draw_texture(ids.row, { x = x, y = row_y })
        if row.greyed then
            -- arcade "grayout": flat grey laid on top of the row plate
            if ids.row_hl then tex.draw_texture(ids.row_hl, { x = x, y = row_y, color = OPT_GREY }) end
        elseif is_cur and ids.row_hl then
            tex.draw_texture(ids.row_hl, { x = x, y = row_y, fade = opt_cursor_alpha(ms) })
        end
        tex.draw_texture(ids.box, { x = x, y = row_y, color = row.changed and OPT_CHANGED or nil })

        local label = self:_opt_text(row.label)
        if label then label:draw({ x = name_x + x, y = text_y + row_y }) end
        local value = self:_opt_text(row.value)
        if value then
            value:draw({ x = math.floor(text_x - value.width / 2 + 0.5) + x, y = text_y + row_y })
        end

        -- engine row icon; state is the raw value so it never depends on the localised string
        local icon
        local st = row.state or 0
        if row.name == "speed" then
            if st > 10 then
                local best
                for v, id in pairs(ids.icon.speed_by_value or {}) do
                    if id and v <= st and (not best or v > best) then best = v end
                end
                icon = best and ids.icon.speed_by_value[best] or nil
            end
            if not icon then
                if st >= 40 then icon = ids.icon.yonbai
                elseif st >= 30 then icon = ids.icon.sanbai
                elseif st > 10 then icon = ids.icon.speed end
            end
        elseif row.name == "random" then
            if st == 2 then icon = ids.icon.detarame
            elseif st == 1 then icon = ids.icon.kimagure end
        elseif row.changed then
            icon = ids.icon[row.name]
        end
        if icon then tex.draw_texture(icon, { x = x, y = row_y }) end

        if is_cur and ids.arrow then
            local nl, nr = 0, 0
            if change and change.active then
                local amp = OPT_ARROW_NUDGE * math.max(0, math.min(1, change.fade))
                if change.dir > 0 then nl = amp else nr = amp end
            end
            tex.draw_texture(ids.arrow, { x = x - nl, y = row_y })
            tex.draw_texture(ids.arrow, { mirror = "horizontal", x = x + arrow_span + nr, y = row_y })
        end

        if row.greyed then tex.draw_texture(ids.row, { x = x, y = row_y, color = OPT_SCRIM }) end
    end
end

-- Z-DON adds rows (等速): a board taller than the arcade's seven rows sits higher, so its foot stays on
-- screen (the header title follows through _mod_off)
function SongSelect:mod_lift(player)
    local rows = player.modifier_rows and player:modifier_rows()
    local n = rows and #rows or 0
    if n <= 7 then return 0 end
    local pitch = SKIN.modifier_offset
    pitch = (pitch and pitch.y ~= 0 and pitch.y) or 61
    return (n - 7) * pitch
end

-- Engine entry point. kind: 1 = 演奏オプション, 2 = the standalone 音色 panel.
function SongSelect:draw_option_panel(player, kind)
    if kind == 1 then
        local rows = player.modifier_rows and player:modifier_rows()
        local off  = player.modifier_offset and player:modifier_offset()
        if not rows or not off then return end
        off = off - self:mod_lift(player)
        local cursor = player.modifier_index and player:modifier_index() or nil
        if cursor and (cursor < 1 or cursor > #rows) then cursor = nil end
        if player.modifier_confirmed and player:modifier_confirmed() then cursor = nil end
        self._mod_off[player:player_num()] = off
        self:draw_option_board(player, off, rows, cursor,
                               player.modifier_change and player:modifier_change())
    else
        local names = player.neiro_names and player:neiro_names()
        local off   = player.neiro_offset and player:neiro_offset()
        if not names or not off then return end
        local idx  = (player.neiro_index and player:neiro_index()) or 1
        local rows = { { name = "neiro", state = idx - 1, value = names[idx] or "",
                         changed = (idx ~= 1), greyed = false } }
        self:draw_option_board(player, off, rows, 1, nil)
    end
end
