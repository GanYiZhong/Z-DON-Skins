-- BackBox rendering ("back" brown board with a label), split out of song_select.lua.

local base = require("song_select/file_navigator/box_base")

local folder_leg = base.folder_leg
local BOARD_W = base.BOARD_W
local CEN_CLOSED_H, CEN_OPEN_H = base.CEN_CLOSED_H, base.CEN_OPEN_H
local FOLDER_CLOSE_MS, STALE_TIMER_MS = base.FOLDER_CLOSE_MS, base.STALE_TIMER_MS
local BOARD_OUTLINE_BACK = base.BOARD_OUTLINE_BACK
local draw_board, draw_glow, glow_pulse = base.draw_board, base.draw_glow, base.glow_pulse
local draw_title = base.draw_title
local outline = base.outline
local box_id = base.box_id
local go_get, leg_f, box_fade, fly_offset = base.go_get, base.leg_f, base.box_fade, base.fly_offset
local wheel_open_t, wheel_close_step = base.wheel_open_t, base.wheel_close_step
local folder_open_timeline, folder_close_timeline = base.folder_open_timeline, base.folder_close_timeline

function SongSelect:back_label()
    if not self._back_label then
        local cfg = tex.get_skin_config("song_back_label")
        if cfg then
            self._back_label = text.create_text("song_back_label", { 58, 38, 51, 255 }, { 255, 255, 255, 255 }, false, outline(3.0), 2.0)
        else
            self._back_label = text.create_raw_text("BACK", 44, { 58, 38, 51, 255 }, { 255, 255, 255, 255 }, false, outline(3.0), 2.0)
        end
    end
    return self._back_label
end

local function back_pb_open(box)
    local key = "b\0" .. box_id(box)
    local t = wheel_open_t(key)
    if t == nil then return 0.0 end
    return (folder_open_timeline(t))
end

local function back_pb_closed(box)
    local key = "b\0" .. box_id(box)
    local e = wheel_close_step(key, FOLDER_CLOSE_MS, STALE_TIMER_MS)
    if e == nil then return 0.0 end
    return (folder_close_timeline(e))
end

function SongSelect:draw_back_board(box, p)
    local bx, by = box:box_x(), box:box_y()
    local fdx, fdy = fly_offset(box); bx, by = bx + fdx, by + fdy   -- wheel fly-in
    local cen_h = CEN_CLOSED_H + (CEN_OPEN_H - CEN_CLOSED_H) * p
    local fade = math.min(1.0, box_fade(box))

    local lta = 1.0
    local lf = (box:draw_state() == "open") and leg_f() or nil
    if lf and folder_leg.kind == "open" and lf < folder_leg.open_swap - 1 then return end   -- not yet
    if lf then
        local sx, ba = go_get("song_board_sx", lf, 1), go_get("song_board_sx", lf, 2)
        if sx and ba then
            if ba <= 0.0 then return end
            if sx < 1.0 then
                draw_board(self._id_bar_back, 0, bx, by, CEN_OPEN_H,
                           fade * ba, false, sx)
                return
            end
            lta = go_get("song_title_a", lf, 1) or 1.0
        end
    end

    if p > 0 then draw_glow(self._id_glow, bx, by, cen_h, fade * p * glow_pulse()) end
    draw_board(self._id_bar_back, 0, bx, by, cen_h, fade)
    draw_title(self:back_label(), bx, by, fade * lta)
end

function SongSelect:draw_back_closed(box)
    self:draw_back_board(box, back_pb_closed(box))
end

function SongSelect:draw_back_open(box)
    self:draw_back_board(box, back_pb_open(box))
end
