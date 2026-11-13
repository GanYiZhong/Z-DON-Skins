local SKIN_S = tex.get_screen_scale()
local SKIN = {
    genre_bg_title = { y = 44 * SKIN_S, width = 300 * SKIN_S },
}
-- Inline-list background (GenreBG) drawing, split out of song_select.lua.
-- Mirrors src/objects/song_select/file_navigator/genre_bg.cpp.

local function T(name)
    return tex.get_texture("song_select/box/" .. name)
end

local _bg_edge_width, _bg_folder_edge_width
local function bg_edge_width()
    if _bg_edge_width == nil then
        local info = tex.get_texture_info("box", "folder_background_edge")
        _bg_edge_width = (info and info.width) or 0
    end
    return _bg_edge_width
end
local function bg_folder_edge_width()
    if _bg_folder_edge_width == nil then
        local info = tex.get_texture_info("box", "folder_background_folder_edge")
        _bg_folder_edge_width = (info and info.width) or 0
    end
    return _bg_folder_edge_width
end

-- draw_anim (folder still entering; box's bounds drive the growing span).
local function draw_anim(gb, box)
    if not box then return end
    local s = gb.scale.attribute
    local offset = 5 * s
    local edge_width = bg_edge_width() * s
    local center = (box.left_bound + box.right_bound) / 2.0
    local half_width = (box.right_bound - box.left_bound) / 2.0
    local base_start = center - half_width * s
    local base_end = center + half_width * s
    local exiting = (gb.move_left ~= nil and gb.move_right ~= nil)
    local start_position = exiting and (base_start + gb.move_left.attribute) or base_start
    local end_position = exiting and (base_end + gb.move_right.attribute) or (base_end + gb.move.attribute)

    local frame = gb:texture_frame()
    local fade = gb.fade.attribute
    local sy = -(gb.stretch.attribute * s)
    local recolor = gb:has_recolor()

    if recolor then gb:begin_recolor() end
    tex.draw_texture(T("folder_background_edge"), { frame = frame, scale = s, center = true, mirror = "horizontal", x = start_position - offset, y = sy, y2 = gb.stretch.attribute * s, fade = fade })
    tex.draw_texture(T("folder_background"), { frame = frame, scale = s, center = true, x = start_position + edge_width - offset, y = sy, x2 = end_position - start_position - edge_width - offset, y2 = gb.stretch.attribute * s, fade = fade })
    tex.draw_texture(T("folder_background_edge"), { frame = frame, scale = s, center = true, x = end_position - edge_width + offset, y = sy, y2 = gb.stretch.attribute * s, fade = fade })

    local edge_width_top = bg_folder_edge_width() * s
    local title_cfg = SKIN.genre_bg_title or { y = 0, width = 300 }
    local name = gb:name()
    local dest_width = math.min(title_cfg.width, name.width) * s

    tex.draw_texture(T("folder_background_folder_edge"), { frame = frame, scale = s, center = true, mirror = "horizontal", x = center - dest_width / 2 - edge_width_top, y = sy, y2 = gb.stretch.attribute * s, fade = fade })
    tex.draw_texture(T("folder_background_folder"), { frame = frame, scale = s, center = true, x = center - dest_width / 2, y = sy, x2 = dest_width, y2 = gb.stretch.attribute * s, fade = fade })
    tex.draw_texture(T("folder_background_folder_edge"), { frame = frame, scale = s, center = true, x = center + dest_width / 2, y = sy, y2 = gb.stretch.attribute * s, fade = fade })
    if recolor then gb:end_recolor() end

    name:draw({ center = true, x = center - dest_width / 2, y = title_cfg.y - gb.stretch.attribute * s, x2 = dest_width - name.width, y2 = gb.stretch.attribute * s, fade = fade })
end

-- draw_exit_anim (folder closing; move_left/move_right drive the shrink).
local function draw_exit_anim(gb)
    local s = gb.scale.attribute
    local offset = 5 * s
    local edge_width = bg_edge_width() * s
    local anim_start = gb.move_left.attribute
    local anim_end = gb.move_right.attribute
    local frame = gb:texture_frame()
    local fade = gb.fade.attribute
    local recolor = gb:has_recolor()

    if recolor then gb:begin_recolor() end
    tex.draw_texture(T("folder_background_edge"), { frame = frame, scale = s, mirror = "horizontal", x = anim_start - offset, fade = fade })
    tex.draw_texture(T("folder_background"), { frame = frame, scale = s, x = anim_start + edge_width - offset, x2 = anim_end - anim_start - edge_width - offset, fade = fade })
    tex.draw_texture(T("folder_background_edge"), { frame = frame, scale = s, x = anim_end - edge_width + offset, fade = fade })

    local edge_width_top = bg_folder_edge_width()
    local title_cfg = SKIN.genre_bg_title or { width = 300 }
    local name = gb:name()
    local dest_width = math.min(title_cfg.width, name.width)
    local center = 638.5 * tex.get_screen_scale()

    tex.draw_texture(T("folder_background_folder_edge"), { frame = frame, mirror = "horizontal", x = center - dest_width / 2 - edge_width_top, fade = fade })
    tex.draw_texture(T("folder_background_folder"), { frame = frame, x = center - dest_width / 2, x2 = dest_width, fade = fade })
    tex.draw_texture(T("folder_background_folder_edge"), { frame = frame, x = center + dest_width / 2, fade = fade })
    if recolor then gb:end_recolor() end

    name:draw({ x = center - dest_width / 2, y = title_cfg.y, x2 = dest_width - name.width, fade = fade })
end

function SongSelect:draw_genre_bg(gb, start_position, end_position, folder)
    -- Z-DON AI battle (zdon_ai_arcade_flow): the arcade's red band + header replace the folder band over the filtered list
    if tex.zdon_ai_select() and require("global.ai_battle").draw_list_band() then return end
    if not gb:is_finished() then
        draw_anim(gb, folder)
        return
    elseif not gb:is_complete() then
        draw_exit_anim(gb)
        return
    end

    -- Steady state: fill the span between the first and last song's bounds.
    local screen_width = tex.get_screen_width()
    local frame = gb:texture_frame()
    local fade = gb.fade.attribute
    local name = gb:name()
    local title_cfg = SKIN.genre_bg_title or { y = 0, width = 300 }
    local boundary = tex.get_skin_config("song_select_genre_bg_boundary") or { x = 442, width = 835 }

    local edge_width_top = bg_folder_edge_width()
    local dest_width = math.min(title_cfg.width, name.width)
    local center = 638.5 * tex.get_screen_scale()

    local bg_start_pos = start_position
    local bg_end_pos = end_position
    if boundary.x < start_position and start_position < center then
        bg_start_pos = boundary.x
    end
    if center < end_position and end_position < boundary.width then
        bg_end_pos = boundary.width
    end

    local recolor = gb:has_recolor()
    if recolor then gb:begin_recolor() end

    if bg_start_pos > bg_end_pos then
        -- wraps around: two segments
        local offset = 5
        local edge_width = bg_edge_width()
        local draw_end_l = math.min(bg_end_pos, screen_width)
        if 0 < draw_end_l then
            if bg_end_pos < screen_width then
                tex.draw_texture(T("folder_background"), { frame = frame, x = 0, x2 = draw_end_l - edge_width + offset, fade = fade })
                tex.draw_texture(T("folder_background_edge"), { frame = frame, x = draw_end_l - edge_width + offset, fade = fade })
            else
                tex.draw_texture(T("folder_background"), { frame = frame, x = 0, x2 = draw_end_l, fade = fade })
            end
        end
        local draw_start_r = math.max(bg_start_pos, 0)
        if draw_start_r < screen_width then
            if bg_start_pos > 0 then
                tex.draw_texture(T("folder_background"), { frame = frame, x = draw_start_r + edge_width - offset, x2 = screen_width, fade = fade })
                tex.draw_texture(T("folder_background_edge"), { frame = frame, mirror = "horizontal", x = draw_start_r - offset, fade = fade })
            else
                tex.draw_texture(T("folder_background"), { frame = frame, x = draw_start_r, x2 = screen_width, fade = fade })
            end
        end
    else
        local offset = 5
        local edge_width = bg_edge_width()
        local draw_start = math.max(bg_start_pos, 0)
        local draw_end = math.min(bg_end_pos, screen_width)
        if draw_start < draw_end then
            local fill_start = draw_start
            local fill_end = draw_end
            if bg_start_pos > 0 then
                tex.draw_texture(T("folder_background_edge"), { frame = frame, mirror = "horizontal", x = draw_start - offset, fade = fade })
                fill_start = draw_start + edge_width - offset
            end
            if bg_end_pos < screen_width then
                tex.draw_texture(T("folder_background_edge"), { frame = frame, x = draw_end - edge_width + offset, fade = fade })
                fill_end = draw_end - edge_width + offset
            end
            if fill_start < fill_end then
                tex.draw_texture(T("folder_background"), { frame = frame, x = fill_start, x2 = fill_end - fill_start, fade = fade })
            end
        end
    end

    local center_not_covered = (start_position <= end_position)
        and (center < start_position or end_position < center)
        or (end_position < center and center < start_position)
    if center_not_covered then
        if recolor then gb:end_recolor() end
        return
    end

    tex.draw_texture(T("folder_background_folder_edge"), { frame = frame, mirror = "horizontal", x = center - dest_width / 2 - edge_width_top, fade = fade })
    tex.draw_texture(T("folder_background_folder"), { frame = frame, x = center - dest_width / 2, x2 = dest_width, fade = fade })
    tex.draw_texture(T("folder_background_folder_edge"), { frame = frame, x = center + dest_width / 2, fade = fade })

    if recolor then gb:end_recolor() end

    name:draw({ x = center - dest_width / 2, y = title_cfg.y, x2 = dest_width - name.width, fade = fade })
end
