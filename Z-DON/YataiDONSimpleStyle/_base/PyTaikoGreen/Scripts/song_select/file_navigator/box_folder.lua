-- FolderBox rendering (genre folder closed/open), split out of song_select.lua.
-- Mirrors src/objects/song_select/file_navigator/box_folder.cpp.

local base = require("song_select/file_navigator/box_base")

local T = base.T
local draw_shadows = base.draw_shadows
local draw_base_closed = base.draw_base_closed
local vertical_name = base.vertical_name

local WHITE = { 255, 255, 255, 255 }
local BLACK = { 0, 0, 0, 255 }

local function is_2p_screen()
    local screen = tex.current_screen and tex.current_screen() or ""
    return screen == "SONG_SELECT_2P" or screen == "WAIWAI_SONG_SELECT"
end

-- Waiwai's special folders have baked Lumen art. The overlay loads "panels", song_select.lua loads "enter".
local WAIWAI_PANELS = {
    WAIWAI_MODE = { dir = "enter", tab = "tab", board = "board_name", "detail_art", "detail_badge", "detail_text" },
    WAIWAI_NORMAL = { dir = "panels", tab = "tab_normal_game", board = "board_normal_name", bubble = "board_bubble",
                      "detail_normal_art", "detail_normal_badge", "detail_normal_text" },
    WAIWAI_TUTORIAL = { dir = "panels", tab = "tab_tutorial", "detail_tutorial_art", "detail_tutorial_text" },
}
local function waiwai_art(panel, name)
    return tex.get_texture("waiwai_song_select/" .. panel.dir .. "/" .. name)
end

local function make_count_text(count)
    return text.create_raw_text(base.format_song_count(count), math.floor(35 * tex.get_screen_scale()), WHITE, BLACK, false, 5.0, 2.0, 1.0)
end

-- Folder text objects (hori_name, tja_count_text, explanation) from FolderBox::load_text,
-- cached per box on self. The song count is filled in by a background scan after the box is
-- first drawn, so its text is rebuilt whenever the count changes (it stayed at 0 otherwise).
local function folder_texts(self, box)
    self._folder_texts = self._folder_texts or {}
    local key = box:path()
    local t = self._folder_texts[key]
    if t == nil then
        local name = box.text_name or ""

        local hori_name = text.create_raw_text(name, math.floor(40 * tex.get_screen_scale()), WHITE, BLACK, false, 5.0, 2.0, 1.0)

        local count = box.tja_count or 0
        local tja_count_text = make_count_text(count)

        local explanation = box:explanation() or {}
        local exp_font = math.floor(34 * tex.get_screen_scale())
        local exp_wrap = 160 * tex.get_screen_scale() - 20.0
        local lang = tex.language()
        local is_cjk = text.language_is_cjk(lang)
        local exp_texts = {}
        for i = 1, 3 do
            local s = explanation[i]
            if s and s ~= "" then
                local content = s
                if not is_cjk then
                    content = text.word_wrap(s, exp_font, 2.0, exp_wrap)
                end
                exp_texts[i] = text.create_raw_text(content, exp_font, WHITE, BLACK, is_cjk, 5.0, 2.0, 1.0)
            end
        end

        t = { hori_name = hori_name, tja_count_text = tja_count_text, count = count, explanation = exp_texts }
        self._folder_texts[key] = t
    else
        local count = box.tja_count or 0
        if count ~= t.count then
            t.tja_count_text = make_count_text(count)
            t.count = count
        end
    end
    return t
end

-- FolderBox::draw_closed crown badge (best crown, no fade).
local function draw_folder_crown(box, bx, by)
    local function draw_one(info, px)
        if not info then return end
        base.draw_crown(info.crown, info.frame, px, by, 1.0)
    end
    local crown_1p = box:highest_crown()
    local crown_2p
    if is_2p_screen() then crown_2p = box:highest_crown_p2() end

    if crown_2p then
        local info = tex.get_texture_info("yellow_box", "crown_dfc")
        local half = (info and info.width or 0) * 0.35
        draw_one(crown_1p, bx - half)
        draw_one(crown_2p, bx + half)
    elseif crown_1p then
        draw_one(crown_1p, bx)
    end
end

local function G(box, name)
    return (box:has_gradient() and box:gradient_texture(name)) or T("box", name)
end

function SongSelect:draw_folder_closed(box)
    if tex.zdon_ai_select() and require("global.ai_battle").list_mode() then return end
    draw_base_closed(box)

    local bx = box:box_x()
    local by = box:box_y()
    local fade = box.fade.attribute
    local tex_index = box:texture_index()
    local use_shader = box:has_flat_recolor()

    if use_shader then box:begin_recolor() end
    tex.draw_texture(T("box", "folder_clip"), { frame = tex_index, x = bx - (1.0 * tex.get_screen_scale()), y = by, fade = fade })
    if use_shader then box:end_recolor() end

    local waiwai_panel = WAIWAI_PANELS[box.collection]
    if waiwai_panel and waiwai_panel.board then
        tex.draw_texture(waiwai_art(waiwai_panel, waiwai_panel.board), { x = bx, y = by, fade = fade })
        if waiwai_panel.bubble then
            tex.draw_texture(waiwai_art(waiwai_panel, waiwai_panel.bubble), { x = bx, y = by, fade = fade })
        end
        return
    end

    local name = vertical_name(self, box)
    local name_cfg = tex.get_skin_config("song_select_box_name") or { x = 47, y = 129, height = 417 }
    local name_h = math.min(name.height, name_cfg.height)
    name:draw({
        x = bx + name_cfg.x - math.floor(name.width / 2),
        y = name_cfg.y + by,
        y2 = name_h - name.height,
        fade = fade
    })

    if box:has_box_icon() then
        box:draw_box_icon({ cx = bx + name_cfg.x, cy = by + 63 * tex.get_screen_scale(), fade = fade })
    end

    draw_folder_crown(box, bx, by)
    if tex.zdon_ai_select() then require("global.ai_battle").draw_shelf_tag(box.text_name, bx) end
end

-- strict green8b: the AI select's native Diff Sort box sits 2,-3 off the arcade (Green skin_config zdon_ai_off_box)
local function ai_box_off(box)
    if tex.zdon_ai_select() and box:genre_index() == base.GI_DIFFICULTY then
        local o = tex.get_skin_config("zdon_ai_off_box")
        if o then return (o.x or 0) * tex.get_screen_scale(), (o.y or 0) * tex.get_screen_scale() end
    end
    return 0, 0
end

local function draw_open_bg(self, box, fade)
    local aox, aoy = ai_box_off(box)
    local bx = box:box_x() + aox
    local by = box:box_y() + aoy
    local shadow_fade = math.min(fade, box.open_fade.attribute)
    draw_shadows(bx, by, shadow_fade, 1)

    local tex_index = box:texture_index()
    local use_shader = box:has_recolor()
    local open_anim = box.open_anim.attribute

    if open_anim >= (100.0 * tex.get_screen_scale()) then
        local top_shader = box:has_flat_recolor()
        if top_shader then box:begin_recolor() end
        tex.draw_texture(T("box", "folder_top_edge"), { frame = tex_index, mirror = "horizontal", x = aox, y = by - open_anim, fade = fade })
        tex.draw_texture(T("box", "folder_top"),      { frame = tex_index, x = aox, y = by - open_anim, fade = fade })
        tex.draw_texture(T("box", "folder_top_edge"), { frame = tex_index, x = 268 * tex.get_screen_scale() + aox, y = by - open_anim, fade = fade })
        if top_shader then box:end_recolor() end
    end

    if use_shader then box:begin_recolor() end
    tex.draw_texture(G(box, "folder_texture_left"),  { frame = tex_index, x = bx - open_anim, y = by, fade = fade })
    tex.draw_texture(G(box, "folder_texture"),       { frame = tex_index, x = bx - open_anim, y = by, x2 = (open_anim * 2.0) + base.song_box_bg_width(), fade = fade })
    tex.draw_texture(G(box, "folder_texture_right"), { frame = tex_index, x = bx + open_anim, y = by, fade = fade })
    if use_shader then box:end_recolor() end
end

local function draw_open_fg(self, box, fade)
    local aox, aoy = ai_box_off(box)
    local texts = folder_texts(self, box)
    local open_anim = box.open_anim.attribute

    local waiwai_panel = WAIWAI_PANELS[box.collection]
    if waiwai_panel then
        -- the tab rides up with the folder top like the text name, rest y 56 at 204 - open_anim
        if open_anim >= (100.0 * tex.get_screen_scale()) then
            tex.draw_texture(waiwai_art(waiwai_panel, waiwai_panel.tab), { y = (148 * tex.get_screen_scale()) - open_anim, fade = fade })
        end
        for _, name in ipairs(waiwai_panel) do
            tex.draw_texture(waiwai_art(waiwai_panel, name), { fade = fade })
        end
        return
    end

    if open_anim >= (100.0 * tex.get_screen_scale()) then
        local s = tex.get_screen_scale()
        local dest_width = math.min(300 * s, texts.hori_name.width)
        if not (box:genre_index() == base.GI_DIFFICULTY and tex.zdon_ai_select()
                and (require("global.ai_battle").draw_native_title or function() return false end)(open_anim, fade)) then
        texts.hori_name:draw({
            x = 642 * s - dest_width / 2.0,
            y = 204 * s - open_anim,
            x2 = dest_width - texts.hori_name.width,
            fade = fade
        })
        end
    end

    if box.collab then
        tex.draw_texture(T("box", "genre_overlay_large"), { fade = fade })
    end
    if box:genre_index() == base.GI_DIFFICULTY then
        tex.draw_texture(T("box", "diff_overlay_large"), { x = aox, y = aoy, fade = fade })
    end

    -- no song count where the number means nothing: difficulty sort, dan, tutorial, waiwai
    local gi = box:genre_index()
    if gi ~= base.GI_DIFFICULTY and gi ~= base.GI_DAN and gi ~= base.GI_TUTORIAL and box.collection ~= "WAIWAI_MODE" then
        tex.draw_texture(T("yellow_box", "song_count_back"), { fade = math.min(fade, 0.5) })
        local s = tex.get_screen_scale()
        local dest_width = math.min(184 * s, texts.tja_count_text.width)
        texts.tja_count_text:draw({
            x = 560 * s - dest_width / 2.0,
            y = 130 * s,
            x2 = dest_width - texts.tja_count_text.width,
            fade = fade
        })
    end

    if box:has_box_texture() then
        local s = tex.get_screen_scale()
        box:draw_box_texture({
            cx = box:box_x() + 48 * s,
            cy = 330 * s + box:box_y(),
            max_w = 344 * s,
            max_h = 424 * s,
            fade = fade
        })
    elseif not box.collab then
        tex.draw_texture(T("box", "folder_graphic"), { frame = box:genre_index(), x = aox, y = aoy, fade = fade })

        local s = tex.get_screen_scale()
        local exp_cfg = { x = 776 * s, y = 131 * s, width = 43 * s, height = 73 * s }
        local exp_box = { x = 650 * s, y = 125 * s, width = 160 * s, height = 400 * s }
        local lang = tex.language()
        local is_cjk = text.language_is_cjk(lang)
        if is_cjk then
            for i = 1, 3 do
                local t = texts.explanation[i]
                if t then
                    local idx = i - 1
                    local center_x = exp_cfg.x - exp_cfg.width * idx
                    t:draw({ x = center_x - t.width / 2.0, y = exp_cfg.y + exp_cfg.height * idx, fade = fade })
                end
            end
        else
            local total_h = 0.0
            for i = 1, 3 do
                if texts.explanation[i] then total_h = total_h + texts.explanation[i].height end
            end
            local scale = total_h > exp_box.height and (exp_box.height / total_h) or 1.0
            local y = exp_box.y
            for i = 1, 3 do
                local t = texts.explanation[i]
                if t then
                    local dest_h = t.height * scale
                    t:draw({
                        x = exp_box.x + (exp_box.width - t.width) / 2.0,
                        y = y,
                        y2 = dest_h - t.height,
                        fade = fade
                    })
                    y = y + dest_h
                end
            end
        end
    end
end

function SongSelect:draw_folder_open(box)
    if tex.zdon_ai_select() and require("global.ai_battle").list_mode() then return end
    if box.entered then
        draw_open_bg(self, box, 0.0)
        draw_open_fg(self, box, box:enter_fade().attribute)
    else
        draw_open_bg(self, box, math.min(1.0, box.fade.attribute))
        draw_open_fg(self, box, math.min(box.open_fade.attribute, box.fade.attribute))
    end
end
