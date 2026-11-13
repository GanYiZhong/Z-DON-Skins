-- DanBox / other box rendering: a plain board in the arcade "dani" colour. This is the
-- `else` branch of the wheel dispatch, split out of song_select.lua.

local base = require("song_select/file_navigator/box_base")

local CEN_CLOSED_H, CEN_OPEN_H = base.CEN_CLOSED_H, base.CEN_OPEN_H
local FOLDER_CLOSE_MS, STALE_TIMER_MS = base.FOLDER_CLOSE_MS, base.STALE_TIMER_MS
local draw_board, draw_glow, glow_pulse = base.draw_board, base.draw_glow, base.glow_pulse
local draw_title = base.draw_title
local box_id = base.box_id
local box_fade, fly_offset = base.box_fade, base.fly_offset
local wheel_open_t, wheel_close_step = base.wheel_open_t, base.wheel_close_step
local folder_open_timeline, folder_close_timeline = base.folder_open_timeline, base.folder_close_timeline

function SongSelect:draw_other_board(box, state)
    -- dan / other boxes: plain board in the arcade "dani" colour
    local bx, by = box:box_x(), box:box_y()
    local fdx, fdy = fly_offset(box); bx, by = bx + fdx, by + fdy   -- wheel fly-in
    local key = "o\0" .. box_id(box)
    local p
    if state == "open" then
        local t = wheel_open_t(key)
        p = t and (folder_open_timeline(t)) or 0.0
    else
        local e = wheel_close_step(key, FOLDER_CLOSE_MS, STALE_TIMER_MS)
        p = e and (folder_close_timeline(e)) or 0.0
    end
    local cen_h = CEN_CLOSED_H + (CEN_OPEN_H - CEN_CLOSED_H) * p
    local fade = math.min(1.0, box_fade(box))
    if p > 0 then draw_glow(self._id_glow, bx, by, cen_h, fade * p * glow_pulse()) end
    draw_board((p > 0) and self._id_bar_folder or self._id_bar_genre, 10, bx, by, cen_h, fade, p <= 0 or p >= 1)
    if p > 0 and p < 1 then draw_board(self._id_bar_genre, 10, bx, by, cen_h, fade * (1.0 - p)) end
    draw_title(self:folder_title(box), bx, by - 94 * p, fade)
end
