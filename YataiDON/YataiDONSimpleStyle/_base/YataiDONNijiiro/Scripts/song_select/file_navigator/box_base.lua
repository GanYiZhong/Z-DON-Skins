-- Shared song-select board chrome, text/colour helpers and the wheel/folder/song
-- animation timers, split out of song_select.lua. All positions are 1080p pixels;
-- box positions and engine animations are already in screen pixels.

local DIFF_BACK, DIFF_MODIFIER, DIFF_NEIRO = -3, -2, -1
local DIFF_EASY, DIFF_NORMAL, DIFF_HARD, DIFF_ONI, DIFF_URA = 0, 1, 2, 3, 4
local CROWN_NONE, CROWN_CLEAR, CROWN_FC, CROWN_DFC = 0, 1, 2, 3

-- Arcade board geometry (960x352 board texture: top/bottom caps + centre slice).
local BOARD_W      = 960
local CAP_H        = 56
local CEN_SRC_H    = 240
local CEN_CLOSED_H = 52
local CEN_OPEN_H   = 240
local GLOW_CAP_H   = 80     -- cursor glow 1024x400: 80 / 240 / 80
local GLOW_W       = 1024

local GUIDE_SELECT_CX, GUIDE_DECIDE_CX, GUIDE_LABEL_CY = 904, 1077, 980
local GUIDE_LABEL_SPACING = 2.0

-- tex.get_texture tries "<name>" then "<name>_<language>"; fall back to _en/_ja so we
-- never hand draw_texture a nil id.
local function get_any(subset, name)
    return tex.get_texture("song_select/" .. subset .. "/" .. name)
        or tex.get_texture("song_select/" .. subset .. "/" .. name .. "_en")
        or tex.get_texture("song_select/" .. subset .. "/" .. name .. "_ja")
end

-- draw a w x h texture centred on (cx, cy)
local function draw_centered(id, cx, cy, w, h, extra)
    extra = extra or {}
    extra.x = cx - w / 2
    extra.y = cy - h / 2
    tex.draw_texture(id, extra)
end

-- Same, but subtracts the texture.json base offset the engine adds when it draws in 2P.
local function draw_centered_b(id, base, cx, cy, w, h, extra)
    extra = extra or {}
    extra.x = cx - w / 2 - base[1]
    extra.y = cy - h / 2 - base[2]
    tex.draw_texture(id, extra)
end
local SEL_BASE_BALLOON = { 683, 308 }   -- 1p/2p_balloon(_half) = cursor bubble

-- Title centred on (bx, cy). max_w (optional): squeeze long text horizontally down to the
-- box width, never below min_scale (default 0.75). Destination x/y snap to whole pixels.
local function draw_title(text, bx, cy, fade, max_w, min_scale)
    if not text then return end
    local w = text.width
    if max_w and w > max_w then
        w = math.floor(math.max(max_w, w * (min_scale or 0.75)) + 0.5)
    end
    text:draw({ x = math.floor(bx - w / 2 + 0.5), y = math.floor(cy - text.height / 2 + 0.5),
                x2 = w - text.width, fade = fade })
end
-- Song-wheel box titles: one size for every language, matched to the AC wheel (≈0.66 of the old base).
local TITLE_SCALE = 0.66
local function title_scale()
    return TITLE_SCALE
end
-- Post-selection header title / subtitle: one size for every language, matched to the AC header (≈0.88).
local HEADER_SCALE = 1.05
local function header_scale()
    return HEADER_SCALE
end
-- control-guide pill labels
local function draw_guide_label(t, cx, cy, fade)
    if not t then return end
    t:draw({ x = math.floor(cx - (t.width - GUIDE_LABEL_SPACING) / 2 + 0.5),
             y = math.floor(cy - t.height / 2 + 0.5), fade = fade })
end
local SONG_TEXT_BOX_W = 860   -- main_song_board text_title / text_sub box width
local DS_TEXT_BOX_W   = 1000  -- main_diff text_title_song / text_song_title_sub box width

-- OutlinedText multiplies the outline thickness by screen_scale, so divide the stage-px
-- border back out.
local function outline(border) return border / tex.get_screen_scale() end

-- Board title/subtitle outline colour by genre frame (0..12).
local BOARD_OUTLINE = {
    [0]  = {  18,  72,  76, 255 },
    [1]  = {  18,  72,  76, 255 },
    [2]  = { 155,  24,  99, 255 },
    [3]  = {  78,  29, 118, 255 },
    [4]  = { 150,  31,   0, 255 },
    [5]  = { 101,  67,  42, 255 },
    [6]  = {  20,  79,  20, 255 },
    [7]  = { 165,  50,   0, 255 },
    [8]  = {  38,  52,  73, 255 },
    [9]  = {  18,  72,  76, 255 },
    [10] = {   0,  25,  95, 255 },
    [11] = { 100,   6,  22, 255 },
    [12] = { 119,  26,  45, 255 },
}
local BOARD_OUTLINE_BACK = { 76, 50, 20, 255 }

local function board_outline(frame)
    return BOARD_OUTLINE[frame or 0] or BOARD_OUTLINE[0]
end

local function clamp01(v) return math.max(0.0, math.min(1.0, v)) end

-- Board chrome: 3-slice (cap / centre / cap) from a 960x352 texture, centred on (bx,by).
-- sx = optional horizontal scale (the folder-ENTER furl/unfurl); a furled board is drawn
-- from flat column slices so its edges stay sharp.
local function draw_board(bar_id, frame, bx, by, cen_h, fade, crop_center, sx)
    local w = BOARD_W
    if sx and sx ~= 1.0 then w = math.max(2, math.floor(BOARD_W * sx + 0.5)) end
    local x = math.floor(bx - w / 2 + 0.5)
    local top = math.floor(by - cen_h / 2 + 0.5) - CAP_H
    local src_y, src_h = CAP_H, CEN_SRC_H
    if crop_center ~= false and cen_h < CEN_SRC_H then
        src_h = math.max(1, math.floor(cen_h + 0.5))
        src_y = CAP_H + math.floor((CEN_SRC_H - src_h) / 2)
        cen_h = src_h
    end
    local bands = { { top, 0, CAP_H, CAP_H }, { top + CAP_H, src_y, src_h, cen_h },
                    { top + CAP_H + cen_h, CAP_H + CEN_SRC_H, CAP_H, CAP_H } }
    if w == BOARD_W then
        for _, b in ipairs(bands) do
            tex.draw_texture(bar_id, { frame = frame, x = x, y = b[1], y2 = b[4] - 352, fade = fade,
                                       src = { x = 0, y = b[2], width = BOARD_W, height = b[3] } })
        end
        return
    end
    local CORNER, BAND, PANEL = 40, 43, 794          -- source widths; 40+43+794+43+40 = 960
    local cols
    if w >= 2 * CORNER then
        local corner = CORNER
        local inner  = w - 2 * corner
        local band   = math.floor(inner * BAND / (2 * BAND + PANEL) + 0.5)
        local panel  = inner - 2 * band
        cols = {
            { 0, CORNER, x, corner },
            { CORNER + BAND / 2 - 4, 8, x + corner, band },
            { BOARD_W / 2 - 4, 8, x + corner + band, panel },
            { BOARD_W - CORNER - BAND / 2 - 4, 8, x + corner + band + panel, band },
            { BOARD_W - CORNER, CORNER, x + w - corner, corner },
        }
    else
        -- narrower than both corners: draw the outline columns + a flat centre slice
        local ol = math.max(2, math.min(8, math.floor(w / 6)))
        local mid = math.max(0, w - 2 * ol)
        cols = {
            { 13, 8, x, ol },
            { BOARD_W / 2 - 4, 8, x + ol, mid },
            { 940, 8, x + ol + mid, ol },
        }
    end
    for _, b in ipairs(bands) do
        for _, c in ipairs(cols) do
            if c[4] > 0 then
                tex.draw_texture(bar_id, { frame = frame, x = c[3], y = b[1], x2 = c[4] - BOARD_W, y2 = b[4] - 352,
                                           fade = fade, src = { x = c[1], y = b[2], width = c[2], height = b[3] } })
            end
        end
    end
end

-- Yellow cursor glow around the board.
local function draw_glow(glow_id, bx, by, cen_h, fade)
    local x = math.floor(bx - GLOW_W / 2 + 0.5)
    local top = math.floor(by - cen_h / 2 + 0.5) - CAP_H - 24
    local src_h = math.max(1, math.min(240, math.floor(cen_h + 0.5)))
    cen_h = src_h
    tex.draw_texture(glow_id, { x = x, y = top, y2 = GLOW_CAP_H - 400, fade = fade,
                                src = { x = 0, y = 0, width = GLOW_W, height = GLOW_CAP_H } })
    tex.draw_texture(glow_id, { x = x, y = top + GLOW_CAP_H, y2 = cen_h - 400, fade = fade,
                                src = { x = 0, y = GLOW_CAP_H + math.floor((240 - src_h) / 2), width = GLOW_W, height = src_h } })
    tex.draw_texture(glow_id, { x = x, y = top + GLOW_CAP_H + cen_h, y2 = GLOW_CAP_H - 400, fade = fade,
                                src = { x = 0, y = GLOW_CAP_H + 240, width = GLOW_W, height = GLOW_CAP_H } })
end

local glow_ok, glow_anim = pcall(require, "anim/sampler")
if not glow_ok then glow_anim = { safe = function()
    local n = {}
    n.at = function() return nil end; n.get = function() return nil end
    n.label = function() return nil end; n.has = function() return false end
    n.first = function() return 0 end;  n.last = function() return 0 end
    return n
end } end
local GLOW_CLIP  = glow_anim.safe("anim/cursor_glow")
local GLOW_LEN   = math.max(1, GLOW_CLIP:last() - GLOW_CLIP:first() + 1)   -- 60 frames = 1 s
-- song-board oni/ura chip cross-fade loop
local URA_LOOP     = glow_anim.safe("anim/song_board_ura")
local URA_LOOP_F0  = URA_LOOP:first()                                      -- label 'ura' = f10
local URA_LOOP_LEN = math.max(1, URA_LOOP:last() - URA_LOOP_F0 + 1)        -- 180 frames = 3 s
local function glow_pulse()
    local f = (tex.get_current_ms() * 0.06) % GLOW_LEN
    return GLOW_CLIP:get("#12@0", f, "a") or 1.0
end

-- Arcade genre board open / close, sampled from anim/folder_board.
local folder_anim = glow_anim
local FOLDER_CLIP = folder_anim.safe("anim/folder_board")
local F_SELECT_ON  = FOLDER_CLIP:label("select_on")  or 5
local F_SELECT_OFF = FOLDER_CLIP:label("select_off") or 30
local FOLDER_CLOSE_END_F = 8            -- select_off + 8 = f38, the last frame that moves
local FOLDER_CLOSE_MS = FOLDER_CLOSE_END_F / 0.06
-- Duration the engine keeps the box "closed" between navigate() and expand_box().
local NAV_REOPEN_MS  = 166
-- A transient navigation closure is < NAV_REOPEN_MS; anything longer resets the open timer.
local STALE_TIMER_MS = math.max(FOLDER_CLOSE_MS, NAV_REOPEN_MS) + 50
local CABINET_OPEN_WAIT_MS = 61 / 120 * 1000                                   -- = 508.33 ms
local EXTRA_OPEN_HOLD_MS   = math.max(0, CABINET_OPEN_WAIT_MS - NAV_REOPEN_MS) -- = 342.33 ms
-- centre band scaleY at the two rest states -> 0..1 openness
local SY_CLOSED, SY_OPEN = 0.2168, 1.0

-- Song board timeline, same labels as the genre board.
local SONG_CLIP = folder_anim.safe("anim/song_board")
local S_SELECT_ON  = SONG_CLIP:label("select_on")  or 5
local S_SELECT_OFF = SONG_CLIP:label("select_off") or 30
local SONG_CLOSE_END_F = 13
local SONG_CLOSE_MS = SONG_CLOSE_END_F / 0.06   -- = 216.7 ms
local SONG_STALE_MS = math.max(SONG_CLOSE_MS, NAV_REOPEN_MS) + 50

-- Folder enter/exit wheel choreography: slots sweep out along the tilted line, hold, then
-- fly back in (sampled from anim/wheel_decide).
local WHEEL_FLY   = folder_anim.safe("anim/wheel_decide")
local FLY_END_F   = WHEEL_FLY:label("return") or 150
local FLY_TRACKS_UP   = { "kanban_genre_2", "kanban_genre_4", "kanban_genre_6", "kanban_genre_8" }
local FLY_TRACKS_DOWN = { "kanban_genre_3", "kanban_genre_5", "kanban_genre_7" }
local FLY_CENTER_Y, FLY_ROW_GAP, FLY_ROW_PITCH = 540, 120, 135
do  -- wheel geometry is skin_config-driven; follow it if restated
    local ok, pitch = pcall(tex.get_skin_config, "song_select_row_pitch")
    if ok and pitch and pitch.x and pitch.x > 0 then
        FLY_ROW_PITCH = pitch.x
        if pitch.y and pitch.y > 0 then FLY_ROW_GAP = pitch.y end
    end
end
-- A wheel animation-timer key must be unique per BOX. text_name is not (two charts of one
-- song share a title), so prefer box:path() and fall back to title+subtitle+ex_data.
local function box_id(box)
    local ok, p = pcall(function() return box:path() end)
    if ok and p and p ~= "" then return p end
    local id = box.text_name or ""
    local ok_s, sub = pcall(function() return box.text_subtitle end)
    if ok_s and sub then id = id .. "\1" .. sub end
    local ok_x, x = pcall(function() return box:ex_data_flag() end)
    if ok_x and x then id = id .. "\1" .. tostring(x) end
    return id
end

-- Folder enter/exit leg state (anim/genre_open), driven by the engine's wheel events.
local folder_leg = {
    clip     = nil,
    t0 = nil, f0 = 0, kind = nil, swapped = false,
    open_f0 = 45, open_swap = 114, open_end = 145,
    close_f0 = 150, close_swap = 219, close_end = 250,
    open_furl = 100,     -- first frame the decided genre board furls shut
    seq = nil,
    have_events = false,
    snap_once = false, snap_ms = nil,
    nohold_once = false, nohold_ms = nil,
}
do
    local ok, t = pcall(require, "anim/genre_open")
    if ok and type(t) == "table" and type(t.tracks) == "table" then
        folder_leg.clip = t
        for _, k in ipairs({ "open_f0", "open_swap", "open_end",
                             "close_f0", "close_swap", "close_end" }) do
            if t[k] then folder_leg[k] = t[k] end
        end
        local rows = t.tracks and t.tracks.genre_board_sx
        if rows then
            for i = 1, #rows do
                if rows[i][2] < 0.999 then folder_leg.open_furl = rows[i][1]; break end
            end
        end
    end
end
-- Linear sampler over the generated {frame, v1, v2...} rows.
local function go_get(name, f, col)
    if not folder_leg.clip then return nil end
    local rows = folder_leg.clip.tracks[name]
    if not rows or #rows == 0 then return nil end
    col = col or 1
    if f <= rows[1][1] then return rows[1][col + 1] end
    if f >= rows[#rows][1] then return rows[#rows][col + 1] end
    for i = 1, #rows - 1 do
        local a, b = rows[i], rows[i + 1]
        if f >= a[1] and f <= b[1] then
            local span = b[1] - a[1]
            if span <= 0 then return a[col + 1] end
            local u = (f - a[1]) / span
            return a[col + 1] + (b[col + 1] - a[col + 1]) * u
        end
    end
    return rows[#rows][col + 1]
end

-- Current clip frame, clamped just short of the swap until the engine signals it.
local function leg_f()
    if not folder_leg.clip or not folder_leg.t0 then return nil end
    local f = folder_leg.f0 + (tex.get_current_ms() - folder_leg.t0) * 0.06
    if not folder_leg.swapped then
        -- hold until the swap: the open leg parks on the furl, the close leg one frame
        -- short of its swap, so the board stays up as the loading state
        local hold = (folder_leg.kind == "close") and (folder_leg.close_swap - 1) or (folder_leg.open_furl - 1)
        if f > hold then f = hold end
        return f
    end
    local fin = (folder_leg.kind == "close") and folder_leg.close_end or folder_leg.open_end
    if f >= fin then folder_leg.t0 = nil; folder_leg.kind = nil; return nil end
    return f
end

-- The engine's own box fade, ignored during the pre-swap half of the close leg.
local function box_fade(box)
    if folder_leg.kind == "close" and folder_leg.t0 and not folder_leg.swapped then return 1.0 end
    return box.fade.attribute
end

-- Start / advance the leg. `begin` puts the clock on the label frame; `swap` re-anchors
-- it on the content-swap frame.
local function leg_event(id)
    local now = tex.get_current_ms()
    if id == 3 then         -- OPEN_BEGIN
        folder_leg.t0, folder_leg.f0, folder_leg.kind, folder_leg.swapped = now, folder_leg.open_f0, "open", false
        folder_leg.dec_id, folder_leg.dec_box = folder_leg.last_open_id, folder_leg.last_open_box
    elseif id == 4 then     -- OPEN_SWAP
        local f = (folder_leg.kind == "open" and folder_leg.t0) and (folder_leg.f0 + (now - folder_leg.t0) * 0.06) or nil
        if not f or f >= folder_leg.open_furl - 1 then
            folder_leg.t0, folder_leg.f0 = now, folder_leg.open_furl
        end
        folder_leg.kind, folder_leg.swapped = "open", true
        folder_leg.snap_once, folder_leg.snap_ms = true, now
    elseif id == 5 then     -- CLOSE_BEGIN
        folder_leg.t0, folder_leg.f0, folder_leg.kind, folder_leg.swapped = now, folder_leg.close_f0, "close", false
    elseif id == 6 then     -- CLOSE_SWAP
        folder_leg.t0, folder_leg.f0, folder_leg.kind, folder_leg.swapped = now, folder_leg.close_swap, "close", true
        folder_leg.snap_once, folder_leg.snap_ms = true, now
    elseif id == 1 or id == 7 then                  -- SCENE_ENTRY / COURSE_BACK
        folder_leg.nohold_once, folder_leg.nohold_ms = true, now
    end
    -- id == 2 (CURSOR_MOVE) needs no flag.
end

-- The wheel clip shares the board clips' labels, so one clock drives all three.
local function fly_offset(box)
    local f = leg_f()
    if not f then return 0.0, 0.0 end
    if folder_leg.kind == "open" then
        if f >= FLY_END_F then return 0.0, 0.0 end
    elseif folder_leg.kind == "close" then
        if f >= (WHEEL_FLY:label("genre_deceide2") or 255) - 1 then return 0.0, 0.0 end
    else
        return 0.0, 0.0
    end
    local st = box:draw_state()
    if st == "open" or st == "diff_select" then return 0.0, 0.0 end   -- the decided board stays
    local d = box:box_y() - FLY_CENTER_Y
    local ring = math.floor((math.abs(d) - FLY_ROW_GAP) / FLY_ROW_PITCH + 0.5)
    if ring < 1 then ring = 1 end
    local track
    if d < 0 then track = FLY_TRACKS_UP[math.min(ring, #FLY_TRACKS_UP)]
    else          track = FLY_TRACKS_DOWN[math.min(ring, #FLY_TRACKS_DOWN)] end
    local x, y = WHEEL_FLY:get(track, f, "tx"), WHEEL_FLY:get(track, f, "ty")
    if not x or not y then return 0.0, 0.0 end
    local rx = WHEEL_FLY:get(track, FLY_END_F, "tx") or 0.0
    local ry = WHEEL_FLY:get(track, FLY_END_F, "ty") or 0.0
    return x - rx, y - ry
end

-- true while `box` is the genre board the player just decided on (open leg running)
local function is_decided(box)
    return folder_leg.kind == "open" and folder_leg.t0 ~= nil and folder_leg.dec_id ~= nil and box_id(box) == folder_leg.dec_id
end

-- How a fresh open starts: "hold" (cursor move), "snap" (folder enter/exit), "nohold"
-- (scene entry / course back). One-shots are armed by the engine's real transitions.
-- (diff-seen timestamp lives on folder_leg so box_song can mutate it across the module split.)
local OPEN_SNAP_TTL_MS   = 2000.0
local OPEN_NOHOLD_TTL_MS = 3000.0

local function open_start_mode(now)
    if folder_leg.snap_once then
        folder_leg.snap_once = false
        if folder_leg.snap_ms and (now - folder_leg.snap_ms) < OPEN_SNAP_TTL_MS then return "snap" end
    end
    if folder_leg.nohold_once then
        folder_leg.nohold_once = false
        if folder_leg.nohold_ms and (now - folder_leg.nohold_ms) < OPEN_NOHOLD_TTL_MS then return "nohold" end
    end
    -- Legacy fallback for a binary without the event channel.
    if not folder_leg.have_events and folder_leg.diff_seen_ms and (now - folder_leg.diff_seen_ms) < 300.0 then
        return "nohold"
    end
    return "hold"
end

-- Shared wheel-panel open/close wall-clock timers. Keys are "<kind>\0<name>".
local wheel_open_start = {}
local wheel_open_mode  = {}
local wheel_open_seen  = {}
local wheel_close_at   = {}
local wheel_close_start= {}
local wheel_last_draw  = {}
local wheel_last_fresh_key, wheel_last_fresh_ms = nil, nil

-- Returns t in ms into the select_on growth window (0..233, clamped), or nil during the
-- 508 ms pre-growth hold (draw fully closed).
local function wheel_open_t(key)
    local now = tex.get_current_ms()
    wheel_close_start[key] = nil
    wheel_open_seen[key]   = now
    wheel_close_at[key]    = nil

    -- off-screen for > NAV_REOPEN_MS with the animation finished -> reset the timer
    local last = wheel_last_draw[key]
    wheel_last_draw[key] = now
    if wheel_open_start[key] and last and (now - last) > NAV_REOPEN_MS then
        local hold = (wheel_open_mode[key] == "hold") and EXTRA_OPEN_HOLD_MS or 0.0
        if (now - wheel_open_start[key]) >= (hold + 233.0) then
            wheel_open_start[key] = nil
        end
    end

    if not wheel_open_start[key] then
        wheel_open_start[key] = now
        wheel_open_mode[key]  = open_start_mode(now)
        wheel_last_fresh_key, wheel_last_fresh_ms = key, now
    end
    local mode = wheel_open_mode[key]
    if mode == "snap" then return 233.0 end
    local elapsed = now - wheel_open_start[key]
    local hold = (mode == "hold") and EXTRA_OPEN_HOLD_MS or 0.0
    if elapsed < hold then return nil end
    return math.min(elapsed - hold, 233.0)
end

-- Closed-state bookkeeping + close animation. Returns e in ms into the select_off
-- timeline while closing, else nil (draw at rest).
local function wheel_close_step(key, close_ms, stale_ms)
    local now = tex.get_current_ms()
    if not wheel_close_start[key] then
        wheel_close_start[key] = now
    end
    if wheel_open_start[key] and (now - wheel_close_start[key]) > stale_ms then
        wheel_open_start[key] = nil
    end
    local seen = wheel_open_seen[key]
    if seen and now - seen < 100 then      -- was drawn open a frame ago -> start closing
        wheel_close_at[key]  = now
        wheel_open_seen[key] = nil
    end
    local c = wheel_close_at[key]
    if c then
        local e = now - c
        if e < close_ms then return e end
        wheel_close_at[key] = nil
    end
    return nil
end

-- `f` is an absolute arcade frame on sprite 73's timeline.
-- pb = board progress 0..1, ch_alpha = character alpha, ch_off = character offset,
-- ta = intro ("N songs") text alpha.
local function folder_sample(f)
    local sy = FOLDER_CLIP:get("instance_board_center", f, "sy") or SY_CLOSED
    local pb = clamp01((sy - SY_CLOSED) / (SY_OPEN - SY_CLOSED))
    local ch_alpha = FOLDER_CLIP:get("instance_character_l", f, "a") or 0.0
    local ch_x     = FOLDER_CLIP:get("instance_character_l", f, "tx") or -340.0
    local ta       = FOLDER_CLIP:get("text_kanban_intro_genre", f, "a") or 0.0
    return pb, ch_alpha, -ch_x, ta
end

local function folder_open_timeline(t)
    return folder_sample(F_SELECT_ON + t * 0.06)
end

local function folder_close_timeline(e)
    return folder_sample(F_SELECT_OFF + e * 0.06)
end

-- Same reader for the song board: pb = board progress, ia = contents alpha, ic = NEW-icon alpha.
local function song_sample(f)
    local sy = SONG_CLIP:get("instance_board_center", f, "sy") or SY_CLOSED
    local pb = clamp01((sy - SY_CLOSED) / (SY_OPEN - SY_CLOSED))
    local ia = SONG_CLIP:get("song_kanban_info", f, "a") or (pb >= 1.0 and 1.0 or 0.0)
    local ic = SONG_CLIP:get("instance_icon", f, "a") or (1.0 - pb)
    return pb, clamp01(ia), clamp01(ic)
end

local function song_open_timeline(t)  return song_sample(S_SELECT_ON  + t * 0.06) end
local function song_close_timeline(e) return song_sample(S_SELECT_OFF + e * 0.06) end

-- 演奏オプション header title of the C++ option panel.
local MOD_SLIDE, MOD_SLIDE_MS, MOD_JSON_Y, MOD_HEADER_CY, MOD_CX = 548, 333.33, 1080, 49, 215

-- Difficulty select geometry (shared by the diff-select board and the selector cursor).
local DS_SLOT_X = { [DIFF_BACK] = 440, [DIFF_MODIFIER] = 572, [DIFF_NEIRO] = 440,
                    [DIFF_EASY] = 745, [DIFF_NORMAL] = 960, [DIFF_HARD] = 1175, [DIFF_ONI] = 1390 }
local DS_BOARD_Y = 583
local DS_COURSE_NAME_DY = 49   -- course-name centre below the card origin
local URA_ANIM_MS   = 1500   -- oni_main change_ura/change_oni: 90 frames @ 60 fps
local URA_SWAP_MS   = 450    -- board_oni -> board_ura swap
local URA_CELLS     = 90
local DS_BTN_Y   = 462
local DS_CURSOR_Y = 370
local DS_NEIRO_Y = 602

-- main_diff_mark: 680x680, drawn under the buttons/cards.
local DS_MARK_X = { [1] = 200, [2] = 1720 }
local DS_MARK_Y = 408
-- main_diff_mark 'course_decide_start', one row per frame:
-- { mark alpha, mark y-scale, white alpha, white y-scale, white backing alpha }.
local DS_MARK_DECIDE = {
    { 0.5, 1, 0, 1, 0 },
    { 0.5938, 1.0447, 0.1914, 1.0447, 0.1016 },
    { 0.6797, 1.0847, 0.3594, 1.0847, 0.1992 },
    { 0.7539, 1.12, 0.5117, 1.12, 0.3008 },
    { 0.8203, 1.1506, 0.6406, 1.1506, 0.3984 },
    { 0.875, 1.1765, 0.75, 1.1765, 0.5 },
    { 0.9219, 1.1976, 0.8398, 1.1976, 0.6016 },
    { 0.9531, 1.2141, 0.9102, 1.2141, 0.6992 },
    { 0.9805, 1.2259, 0.9609, 1.2259, 0.8008 },
    { 0.9961, 1.2329, 0.9883, 1.2329, 0.8984 },
    { 1, 1.2353, 1, 1.2353, 1 },
    { 1, 1.2229, 0.9961, 1.2346, 1 },
    { 1, 1.2105, 0.9883, 1.2327, 1 },
    { 1, 1.1981, 0.9766, 1.2294, 1 },
    { 1, 1.1858, 0.957, 1.2248, 1 },
    { 1, 1.1733, 0.9297, 1.219, 1 },
    { 1, 1.161, 0.8984, 1.2118, 1 },
    { 1, 1.1486, 0.8633, 1.2033, 1 },
    { 1, 1.1362, 0.8242, 1.1936, 1 },
    { 1, 1.1238, 0.7773, 1.1825, 1 },
    { 1, 1.1114, 0.7227, 1.1701, 1 },
    { 1, 1.0991, 0.6641, 1.1564, 1 },
    { 1, 1.0867, 0.6016, 1.1414, 1 },
    { 1, 1.0743, 0.5312, 1.1251, 1 },
    { 1, 1.0619, 0.457, 1.1075, 1 },
    { 1, 1.0495, 0.375, 1.0886, 1 },
    { 1, 1.0371, 0.2891, 1.0684, 1 },
    { 1, 1.0247, 0.1992, 1.0469, 1 },
    { 1, 1.0124, 0.1016, 1.0241, 1 },
    { 1, 1, 0, 1, 1 },
}
local DS_MARK_DECIDE_MS = 1000 / 60

return {
    DIFF_BACK = DIFF_BACK, DIFF_MODIFIER = DIFF_MODIFIER, DIFF_NEIRO = DIFF_NEIRO,
    DIFF_EASY = DIFF_EASY, DIFF_NORMAL = DIFF_NORMAL, DIFF_HARD = DIFF_HARD,
    DIFF_ONI = DIFF_ONI, DIFF_URA = DIFF_URA,
    CROWN_NONE = CROWN_NONE, CROWN_CLEAR = CROWN_CLEAR, CROWN_FC = CROWN_FC, CROWN_DFC = CROWN_DFC,

    BOARD_W = BOARD_W, CAP_H = CAP_H, CEN_SRC_H = CEN_SRC_H,
    CEN_CLOSED_H = CEN_CLOSED_H, CEN_OPEN_H = CEN_OPEN_H,
    GLOW_CAP_H = GLOW_CAP_H, GLOW_W = GLOW_W,

    SEL_BASE_BALLOON = SEL_BASE_BALLOON,
    GUIDE_SELECT_CX = GUIDE_SELECT_CX, GUIDE_DECIDE_CX = GUIDE_DECIDE_CX,
    GUIDE_LABEL_CY = GUIDE_LABEL_CY, GUIDE_LABEL_SPACING = GUIDE_LABEL_SPACING,
    SONG_TEXT_BOX_W = SONG_TEXT_BOX_W, DS_TEXT_BOX_W = DS_TEXT_BOX_W,
    BOARD_OUTLINE = BOARD_OUTLINE, BOARD_OUTLINE_BACK = BOARD_OUTLINE_BACK,

    FOLDER_CLOSE_MS = FOLDER_CLOSE_MS, STALE_TIMER_MS = STALE_TIMER_MS,
    SONG_CLOSE_MS = SONG_CLOSE_MS, SONG_STALE_MS = SONG_STALE_MS,
    URA_LOOP = URA_LOOP, URA_LOOP_F0 = URA_LOOP_F0, URA_LOOP_LEN = URA_LOOP_LEN,

    MOD_SLIDE = MOD_SLIDE, MOD_SLIDE_MS = MOD_SLIDE_MS, MOD_JSON_Y = MOD_JSON_Y,
    MOD_HEADER_CY = MOD_HEADER_CY, MOD_CX = MOD_CX,
    DS_SLOT_X = DS_SLOT_X, DS_BOARD_Y = DS_BOARD_Y, DS_COURSE_NAME_DY = DS_COURSE_NAME_DY,
    URA_ANIM_MS = URA_ANIM_MS, URA_SWAP_MS = URA_SWAP_MS, URA_CELLS = URA_CELLS,
    DS_BTN_Y = DS_BTN_Y, DS_CURSOR_Y = DS_CURSOR_Y, DS_NEIRO_Y = DS_NEIRO_Y,
    DS_MARK_X = DS_MARK_X, DS_MARK_Y = DS_MARK_Y, DS_MARK_DECIDE = DS_MARK_DECIDE,
    DS_MARK_DECIDE_MS = DS_MARK_DECIDE_MS,

    get_any = get_any, draw_centered = draw_centered, draw_centered_b = draw_centered_b,
    draw_title = draw_title, draw_guide_label = draw_guide_label, title_scale = title_scale, header_scale = header_scale,
    outline = outline, board_outline = board_outline, clamp01 = clamp01,
    draw_board = draw_board, draw_glow = draw_glow, glow_pulse = glow_pulse,

    box_id = box_id, go_get = go_get, leg_f = leg_f, box_fade = box_fade,
    leg_event = leg_event, fly_offset = fly_offset, is_decided = is_decided,
    open_start_mode = open_start_mode, wheel_open_t = wheel_open_t, wheel_close_step = wheel_close_step,
    folder_open_timeline = folder_open_timeline, folder_close_timeline = folder_close_timeline,
    song_open_timeline = song_open_timeline, song_close_timeline = song_close_timeline,

    folder_leg = folder_leg,
}
