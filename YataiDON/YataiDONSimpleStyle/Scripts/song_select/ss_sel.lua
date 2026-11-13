-- YataiDONSimpleStyle song select: the static backdrop with drifting clouds, the blinking cursors
-- (the wheel's ▶ and the course column's ▼), the course select's 3-frame open, the one hint pill and
-- the menu mascots (bible 2.6, role "menu" = k 6, Nijiiro's configuration: the player's character stands
-- on its nameplate; Momo on the 1P plate, Hoshi on the 2P plate once a second player has joined).
-- Required from the patched Nijiiro song_select.lua; the patched box_base / box_song / selector call the
-- global SS_SEL hooks. Every coordinate is logical (1920x1080).
--
-- Overlay hide (SS1, owner: this module): while the course select is open (state 1, or the board is
-- opening / closing) every song select variant raises SS_OVERLAY_HIDE.invite every frame (update, the
-- board draw and the overlay draw), so v2_meta's coin_overlay never draws the 2P invite bubble over the
-- board. SS_SEL:course_open() is also true while the board is on screen.
local UI = require("global.ss_ui")

local M = {}
M.__index = M
local U = UI.U

-- Nijiiro skin_config: nameplate song_select_1p (14, 908) / song_select_2p (1494, 908) -> the plates'
-- top border is y 914; chara_3d song_select_1p / 2p x = 225 / 1695 (where Nijiiro's Don stands)
local PLATE_TOP  = 914
local CHARA_X    = { 225, 1695 }
local BLINK_MS   = 400                  -- ▶ / ▼ : 400 ms on, 400 ms off
local CLOUD_STEP = 3                    -- clouds drift 1U ...
local CLOUD_MS   = 500                  -- ... every 500 ms
local CLOUDS = { { "cloud_m", 150, 33 }, { "cloud_s", 810, 99 }, { "cloud_m", 1290, 51 } }
local DS_SLOT_X = { [-3] = 440, [-2] = 572, [-1] = 440, [0] = 745, [1] = 960, [2] = 1175, [3] = 1390, [4] = 1390 }
-- course select board (song_select/diff_select/difficulty_back): outer border box, shadow excluded
-- r3: 60 px shorter (header 144 tall, the cards / buttons / marker lane moved up 60; box_base DS_* patch)
local BACK_W, BACK_H = 1224, 718
local CURSOR_DOWN_Y = 300               -- the ▼ under the 1P/2P marker (DS_CURSOR_Y 310)
local OPEN_MS = 100                     -- UI.open_rect: 33 / 66 / 100 % height, 50 ms each

-- course colours (ss/style.py P: easy normal hard oni ura) for the level pips' tint
local COURSE_RGB = {
    [0] = { 242, 169, 59, 255 }, [1] = { 79, 174, 94, 255 }, [2] = { 91, 163, 230, 255 },
    [3] = { 236, 106, 163, 255 }, [4] = { 138, 91, 224, 255 },
}
function M.course_rgb(d) return COURSE_RGB[d] or COURSE_RGB[3] end

local function T(name) return tex.get_texture("song_select/ss_sel/" .. name) end

local function screen() return (tex.current_screen and tex.current_screen() or "") end
local function is_2p() return screen() == "SONG_SELECT_2P" end

function M.new()
    UI.reset()
    local self = setmetatable({}, M)
    self.t = {
        bg = tex.get_texture("song_select/box/background"),
        cursor = T("cursor"), down = T("cursor_down"), count_max = T("count_max"), footer = T("footer"),
        cloud_s = T("cloud_s"), cloud_m = T("cloud_m"), pattern = T("pattern"),
    }
    self.cloud_w = {}
    for _, c in ipairs(CLOUDS) do
        local info = tex.get_texture_info("ss_sel", c[1])
        self.cloud_w[c[1]] = (info and info.width) or 54
    end
    self.momo  = UI.Mascot.new({ role = "menu", beat = false })
    self.hoshi = UI.Mascot.new({ buddy = true, role = "menu", beat = false })
    -- Z-DON AI battle select: the AI robot stands on the 2P side
    self.robo  = UI.Mascot.new({ char = "robo", role = "menu", beat = false })
    self.ms = 0
    self.state = nil
    self.turn_until = nil
    self.focus = {}        -- polish: per player { slot, t } (the focused course card / button)
    self.decided = {}      -- polish: per player { slot, t, diff } (course decided)
    self.move_t = nil      -- polish: last wheel cursor move (the ▶ nudge / blink restart)
    SS_SEL = self
    return self
end

-- which mascot stands on which plate: { mascot, x, player } list for this screen
function M:cast()
    if screen() == "AI_SELECT" then
        return { { self.momo, CHARA_X[1], 1 }, { self.robo, CHARA_X[2], 2 } }
    end
    if is_2p() then
        return { { self.momo, CHARA_X[1], 1 }, { self.hoshi, CHARA_X[2], 2 } }
    end
    local p = (tex.player_num and tex.player_num() == 2) and 2 or 1
    return { { self.momo, CHARA_X[p], p } }
end

-- face the selection: dir from the mascot's x toward x_target
local function face(m, mx, x_target)
    if x_target == nil then m:react("turn", 0) return end
    m:react("turn", (x_target >= mx) and 1 or -1)
end

-- on the wheel the cast faces front (breathe / blink) and turns toward the wheel for a moment after a
-- cursor move; in the course select it keeps facing the focused column
local WHEEL_TURN_MS = 1200
function M:face_centre(ms)
    for _, c in ipairs(self:cast()) do face(c[1], c[2], 960) end
    self.turn_until = (ms or tex.get_current_ms()) + WHEEL_TURN_MS
end

-- raise the invite hide (keeps other modules' fresh keys; v2_meta holds a raise for 100 ms)
local function hide_invite()
    local now = tex.get_current_ms()
    local h = SS_OVERLAY_HIDE
    local n = { ms = now, invite = true }
    if h and h.ms and (now - h.ms) < 100 then
        for k, v in pairs(h) do if k ~= "ms" and v then n[k] = v end end
    end
    SS_OVERLAY_HIDE = n
end
M.hide_invite = hide_invite

function M:course_select_up()
    return self.state == 1 or self:course_open()
end

function M:update(ms)
    self.ms = ms
    self.frame = (self.frame or 0) + 1   -- fix1029: frame counter for ds_fade's "not drawn last frame" test
    if self:course_select_up() then hide_invite() end
    if self.turn_until and ms > self.turn_until and self.state ~= 1 then
        self.turn_until = nil
        self.momo:react("turn", 0)
        self.hoshi:react("turn", 0)
        self.robo:react("turn", 0)
    end
    self.momo:update(ms)
    self.hoshi:update(ms)
    self.robo:update(ms)
end

local function blink_on(ms) return UI.blink_on(ms, BLINK_MS) end

-- ---------------------------------------------------------------- backdrop
-- polish: the floor pattern (ss_sel/pattern, 192 x 252, bg3 / bg2 on cream: no accent) fills the cream
-- between the sky band and the floor strip, scrolled left 1U every 100 ms (steady, Nijiiro's moving
-- background). Three tile rows cover y 216..972; the floor strip (draw_footer) covers the rest.
local PAT_W, PAT_H, PAT_Y = 192, 252, 216
local PAT_STEP, PAT_MS = 3, 100
function M:draw_pattern()
    local id = self.t.pattern
    if not id then return end
    -- comfort mode: the pattern stands still (a constant judder behind the list)
    local off = UI.COMFORT and 0 or (math.floor(tex.get_current_ms() / PAT_MS) * PAT_STEP) % PAT_W
    for row = 0, 2 do
        local y = PAT_Y + row * PAT_H
        for x = -off, 1920, PAT_W do tex.draw_texture(id, { x = x, y = y }) end
    end
end

function M:draw_background()
    if self.t.bg then tex.draw_texture(self.t.bg, { x = 0, y = 0 }) end
    self:draw_pattern()
    -- comfort mode: the clouds glide at the same speed instead of hopping 1U every 500 ms
    local drift = UI.COMFORT and (tex.get_current_ms() / CLOUD_MS * CLOUD_STEP)
        or math.floor(tex.get_current_ms() / CLOUD_MS) * CLOUD_STEP
    for _, c in ipairs(CLOUDS) do
        local id = self.t[c[1]]
        if id then
            local w = self.cloud_w[c[1]]
            local span = 1920 + w
            local x = (c[2] + drift) % span - w
            tex.draw_texture(id, { x = UI.COMFORT and x or math.floor(x / 3) * 3, y = c[3] })
        end
    end
end

-- fix1029: the floor in front of the wheel. The backdrop's bottom strip (y 975..1080, ss_sel/footer) drawn
-- again after the navigator (SongSelect:draw_footer), so the wheel's lower plates slide behind the floor and
-- the bottom-centre hint pill (y 984..1023) never sits on a plate.
local FOOTER_Y = 975
function M:draw_footer()
    if self.t.footer then tex.draw_texture(self.t.footer, { x = 0, y = FOOTER_Y }) end
    if screen() == "AI_SELECT" then require("global.ss_ai").draw_select() end -- Z-DON AI battle
end

-- ---------------------------------------------------------------- 「N曲目」 plate
-- the 「M曲」 cell only exists when a song limit is set (otherwise the plate is one chip)
function M:draw_count_max(x, y)
    if not self.t.count_max or not tex.song_limit then return end
    local limit = tex.song_limit()
    if not limit or limit <= 0 then return end
    tex.draw_texture(self.t.count_max, { x = x, y = y })
end

-- ---------------------------------------------------------------- course select open (bible 2.7)
-- ds_fade(raw): the alpha every diff-select draw gets. raw = the engine's diff_fade_in. Opening: 0 until
-- the 3-frame open has finished, then 1. Closing (raw falling): raw snapped by UI.solid. Memoised per frame
-- (box_song calls it from two functions per frame).
-- fix1029: "back on the wheel" = the board was not drawn on the previous FRAME (update() counts frames). It
-- used to be "not drawn for 60 ms": one slow frame (closing the option panel saves the player's options to
-- scores.db synchronously, scores_manager.save_player_data) looked like a new open, so the board collapsed
-- to the 33 / 66 % dialog chrome and opened again, and the 1P/2P markers dropped in again.
function M:ds_fade(raw)
    local now = tex.get_current_ms()
    local fr = self.frame or 0
    if self._dsf_frame == fr and self._dsf_raw == raw then return self._dsf end
    -- not drawn last frame (back on the wheel): the next open starts fresh
    if self._dsf_frame and fr - self._dsf_frame > 1 then
        self.ds_t0, self.ds_closing, self.ds_last = nil, false, nil
    end
    self._dsf_ms, self._dsf_frame, self._dsf_raw = now, fr, raw
    if raw > 0 then hide_invite() end
    local v
    if raw <= 0 then
        self.ds_t0, self.ds_closing = nil, false
        v = 0
    else
        if not self.ds_t0 then
            self.ds_t0, self.ds_closing = now, false
            self.focus, self.decided, self.said_pick = {}, {}, nil   -- polish: a fresh open
        end
        if self.ds_last and raw < self.ds_last - 1e-4 then self.ds_closing = true end
        if self.ds_closing then v = UI.solid(raw)
        else v = (now - self.ds_t0 >= OPEN_MS) and 1 or 0 end
    end
    self.ds_last = raw
    self._dsf = v
    return v
end

function M:ds_open() return self._dsf or 0 end
function M:course_open()
    return self.ds_t0 ~= nil and (self.ds_last or 0) > 0 and ((self.frame or 0) - (self._dsf_frame or -1e9)) <= 1
end

-- ---------------------------------------------------------------- polish: card motion (course select)
-- Every step is a whole 50 ms frame and a whole U (no easing curves, no scaling):
-- * cascade: after the board's 3-frame open the six slots (back, options, the four course cards)
--   arrive left to right, one per 50 ms; each shows 3U low for its first step, then sits in place. The
--   1P/2P marker and the focus ring wait for the last card (cascade_done).
-- * focus lift: the card / button under a player's cursor stands 2U higher (1U for its first 50 ms), its
--   focus ring with it: the choice reads as picked up, not only outlined.
-- * decide press: the decided card goes down to its rest line for 50 ms, then 1U, then back up to 2U, and
--   its ring flashes off / on in 50 ms steps for 300 ms; an event burst (UI.burst) pops on its top edge.
local CASCADE_MS = 50
local SLOT_ORDER = { [-3] = 0, [-2] = 1, [0] = 2, [1] = 3, [2] = 4, [3] = 5 }
local N_SLOTS = 6
local CARD_TOP = 523 - 180          -- DS_BOARD_Y - half the 360 card
local FLASH_MS = 300

function M:cascade_t()
    if not self.ds_t0 or self.ds_closing then return nil end
    return tex.get_current_ms() - self.ds_t0 - OPEN_MS
end

function M:cascade_done()
    if not self.ds_t0 then return false end
    if self.ds_closing then return true end
    local e = self:cascade_t()
    return e ~= nil and e >= N_SLOTS * CASCADE_MS
end

-- lift of a slot from the players' focus (negative = up); the decided card presses down first
function M:lift(slot)
    local now = tex.get_current_ms()
    local best = 0
    for p = 1, 2 do
        local f = self.focus[p]
        if f and f.slot == slot then
            local dy = (now - f.t < CASCADE_MS) and -U or -2 * U
            local d = self.decided[p]
            if d and d.slot == slot then
                local e = now - d.t
                if e < CASCADE_MS then dy = 0 elseif e < 2 * CASCADE_MS then dy = -U else dy = -2 * U end
            end
            best = math.min(best, dy)
        end
    end
    return best
end

-- card_pose(slot) -> dy, visible: the cascade arrival plus the focus lift
function M:card_pose(slot)
    local k = SLOT_ORDER[slot]
    local e = self:cascade_t()
    if k == nil or e == nil then return self:lift(slot), true end
    local since = e - k * CASCADE_MS
    if since < 0 then return 0, false end
    if since < CASCADE_MS then return 3 * U, true end
    return self:lift(slot), true
end

-- the focus ring of player p on `slot`: dy (follows the card) and whether it shows this frame
function M:ring(p, slot)
    local dy = self:lift(slot)
    local d = self.decided[p]
    if d and d.slot == slot then
        local e = tex.get_current_ms() - d.t
        if e < FLASH_MS and math.floor(e / CASCADE_MS) % 2 == 0 then return dy, false end
    end
    return dy, true
end

-- the readout card left / right of the board: a new course drops in from 2U above (2U, 1U, rest)
function M:mark_dy(p)
    local f = self.focus[p]
    if not f then return 0 end
    local e = tex.get_current_ms() - f.t
    if e < CASCADE_MS then return -2 * U elseif e < 2 * CASCADE_MS then return -U end
    return 0
end

-- the backboard: frames 1-2 of the open are the dialog chrome at 33 / 66 % height (no texture
-- stretching), frame 3 the baked board at alpha 1; while closing it is shown until the fade passes 0.5
function M:draw_backboard(id, frame, x, y)
    if not self.ds_t0 then return end
    if self.ds_closing then
        if UI.solid(self.ds_last) == 1 then tex.draw_texture(id, { frame = frame, x = x, y = y }) end
        return
    end
    local rx, ry, rw, rh, done = UI.open_rect(x, y, BACK_W, BACK_H, tex.get_current_ms() - self.ds_t0)
    if not rx then return end
    if done then
        tex.draw_texture(id, { frame = frame, x = x, y = y })
    else
        UI.chrome.dialog(rx, ry, rw, rh)
    end
end

-- ---------------------------------------------------------------- the one hint pill
-- state: 0 browsing, 1 course select, 2 diff sort, 3 search, 4 dan
function M:draw_hint(state)
    if state ~= 0 and state ~= 1 and state ~= 2 then return end
    if tex.in_transition and tex.in_transition() then return end
    -- fix1029: bottom centre (core default), between the 1P / 2P nameplates in every variant
    UI.hint({ { "ka", "h_select" }, { "don", "h_decide" } })
end

-- ---------------------------------------------------------------- cursors
-- the wheel's focused plate: ▶ left of the gold ring, on the plate's centre row
-- polish: a cursor move restarts the blink (the ▶ is on the moment the wheel moves, never caught in its
-- off phase) and pushes it 1U toward the plate for one 50 ms step
local NUDGE_MS = 50
function M:board_cursor(bx, by, a)
    if not self.t.cursor or UI.solid(a or 0) == 0 then return end
    local now = tex.get_current_ms()
    local since = self.move_t and (now - self.move_t) or now
    if not blink_on(since) then return end
    local dx = (self.move_t and since < NUDGE_MS) and U or 0
    tex.draw_texture(self.t.cursor, { x = math.floor(bx - 546 + dx), y = math.floor(by - 33) })
end

-- the course column / button under the 1P/2P marker: ▼ between the marker and the gold ring
function M:column_cursor(sx, a)
    if not self.t.down or UI.solid(a or 0) == 0 or not blink_on(tex.get_current_ms()) then return end
    tex.draw_texture(self.t.down, { x = math.floor(sx - 16), y = CURSOR_DOWN_Y })
end

-- the 1P option panel is open (or sliding): box_song hides もどる under it (SS3)
function M:panel_open(p)
    return self.mod_off ~= nil and self.mod_off[p or 1] ~= nil
end

-- ---------------------------------------------------------------- dynamic text (SCREEN_GUIDE_V2 §11)
-- Every word on this screen is engine text in the player's language (ss/strings.py keys via UI.t); the
-- baked textures are the word-free chrome. Chips that hold a word are drawn here, sized to the measured
-- text (en / ko are wider than the ja box). Callers pass the alpha the texture had; it is snapped.
local P, U = UI.P, UI.U
local function shown(a) return UI.solid(a == nil and 1 or a) == 1 end
local function ceil_u(v) return math.ceil(v / U) * U end

-- the largest role size from `sizes` whose text fits max_w (the last one otherwise)
local function fit(key, sizes, max_w, style)
    for _, s in ipairs(sizes) do
        if UI.label_width(key, s, style) <= max_w then return s end
    end
    return sizes[#sizes]
end

local function label_at(key, cx, cy, size, style)
    UI.draw_text(UI.text_key(key, size, style), cx, cy, "c", 1)
end

-- もどる / オプション on the paper card of the card-tall buttons (frame 128x360 centred on (sx, by);
-- card inner 99 px wide centred at frame (61.5, 274.5), 141 tall). text24: 24 px; a word wider than the card
-- (ja オプション, 120 px) is set vertically, one glyph per 25 px row (a 5-glyph column is 125 px)
local BTN_CARD_W = 99 - 2 * U
local BTN_PITCH = 25
local function button_label(key, cx, cy)
    if UI.label_width(key, 24) <= BTN_CARD_W then
        label_at(key, cx, cy, 24)
        return
    end
    local str = UI.t(key) or key
    local chars = {}
    -- (the engine Lua has no utf8 library: a UTF-8 character is a lead byte + its continuation bytes)
    local i = 1
    while i <= #str do
        local b = str:byte(i)
        local n = (b >= 240 and 4) or (b >= 224 and 3) or (b >= 192 and 2) or 1
        chars[#chars + 1] = str:sub(i, i + n - 1)
        i = i + n
    end
    local y0 = cy - (#chars - 1) * BTN_PITCH / 2
    for i, ch in ipairs(chars) do
        UI.draw_text(UI.text(ch, 24, "ink"), cx, y0 + (i - 1) * BTN_PITCH, "c", 1)
    end
end
function M:button_labels(back_x, opt_x, by, a, back_shown)
    if not shown(a) then return end
    local y = by - 180 + 274.5
    local bdy, bvis = self:card_pose(-3)
    local ody, ovis = self:card_pose(-2)
    if back_shown and bvis then button_label("sel_back", back_x - 2.5, y + bdy) end
    if ovis then button_label("sel_options", opt_x - 2.5, y + ody) end
end

-- "1P" / "2P" on the course-select marker chip (frame 124x124 centred on (cx, cy), chip centre (63, 30))
function M:marker_label(p, cx, cy, a)
    if not shown(a) then return end
    label_at((p == 2) and "player_2p" or "player_1p", cx + 1, cy - 32, 24, "paper")
end

-- "1P" / "2P" on the option panel's player chip (modifier/1p at (32, 1097) + chip centre (31.5, 31.5))
function M:panel_label(p, x, offset)
    label_at((p == 2) and "player_2p" or "player_1p", x + 63.5, offset + 1128.5, 24, "paper")
end

-- the course name on the readout card left of the course select (diff_tower_shadow, 680x680 centred on
-- (cx, cy); card inner 270 px, name row centred at frame (303, 357))
local STAT_W, STAT_ROW = 274, 12 * U   -- text24: 12U rows (was 10U) so 24 px glyphs clear the dividers
function M:readout_name(d, cx, cy, a, box)
    if not shown(a) then return end
    local key = "course" .. UI.course.index(d)
    label_at(key, cx - 37, cy + 17, fit(key, { 36, 24 }, 270 - 4 * U))
    if box and box.chart_stats then
        local bottom = self:readout_stats(box:chart_stats(d), cx, cy)
        if bottom and box.recent_plays then self:readout_recent(box:recent_plays(d), cx, bottom) end
    end
end

-- Z-DON (SongBox:recent_plays): the last plays of the focused course (up to 10, oldest left) as score
-- bars under the stats panel, coloured by the play's crown: none grey, clear green, full combo red,
-- donderful gold. Upstream engines: nothing.
local RECENT_BAR_H = 15 * U
local CROWN_COL = { [0] = "ok", [1] = "normal", [2] = "don", [3] = "clear" }
function M:readout_recent(plays, cx, y_top)
    if not plays or #plays == 0 then return end
    local x = UI.grid(cx - 37 - STAT_W / 2)
    local y = UI.grid(y_top + 2 * U)
    local ix, iy, iw, ih = UI.chrome.panel(x, y, STAT_W, 10 * U + RECENT_BAR_H + 4 * U, P.paper)
    UI.draw_text(UI.text_key("ds_recent", 24, "ink"), ix + 4 * U, iy + 5 * U, "l")
    UI.num(tostring(#plays), ix + iw - 4 * U, iy + 5 * U, "m", P.ink, 255, "r")
    local n = 10
    local gx0, gw = ix + 3 * U, iw - 6 * U
    local bw = math.floor(gw / n / U) * U
    local base = iy + ih - 2 * U
    -- heights over the plays' own range (lowest 2U, highest full), so progress reads at a glance
    local lo, hi = math.huge, 0
    for _, p in ipairs(plays) do lo, hi = math.min(lo, p.score), math.max(hi, p.score) end
    local span = math.max(hi - lo, 1)
    UI.rect(gx0, base, bw * n, U, P.ink)
    for i, p in ipairs(plays) do
        local f = (hi > lo) and (p.score - lo) / span or 1
        local h = UI.grid(2 * U + (RECENT_BAR_H - 2 * U) * f)
        local c = P[CROWN_COL[math.max(0, math.min(3, p.crown or 0))]] or P.ok
        UI.rect(gx0 + (i - 1) * bw + U, base - h, bw - U, h, c)
    end
end

-- Z-DON (SongBox:chart_stats, src/objects/song_select/file_navigator/box_song_stats.cpp): BPM / notes /
-- length of the focused course in a paper panel under the readout card (card outer 274 x 210, centred
-- on cx - 37, bottom at cy + 71). Upstream engines have no chart_stats: nothing is drawn.
local function mmss(ms)
    local s = math.floor(ms / 1000 + 0.5)
    return string.format("%d:%02d", math.floor(s / 60), s % 60)
end
local function bpm_str(lo, hi)
    local a, b = math.floor(lo + 0.5), math.floor(hi + 0.5)
    if a == b then return tostring(a) end
    return tostring(a) .. "-" .. tostring(b)
end
function M:readout_stats(st, cx, cy)
    if not st or (st.notes or 0) <= 0 then return end
    local rows = { { "ds_bpm", bpm_str(st.bpm_min, st.bpm_max) }, { "ds_notes", tostring(st.notes) },
                   { "ds_length", mmss(st.length_ms) } }
    local x, y = UI.grid(cx - 37 - STAT_W / 2), UI.grid(cy + 71 + 4 * U)
    local ix, iy, iw, ih = UI.chrome.panel(x, y, STAT_W, #rows * STAT_ROW + 4 * U, P.paper)
    for i, r in ipairs(rows) do
        local ry = iy + 2 * U + (i - 0.5) * STAT_ROW
        UI.draw_text(UI.text_key(r[1], 24, "ink"), ix + 4 * U, ry, "l")
        UI.num(r[2], ix + iw - 4 * U, ry, "m", P.ink, 255, "r")
        if i < #rows then UI.rect(ix + 3 * U, iy + 2 * U + i * STAT_ROW, iw - 6 * U, U, P.line) end
    end
    return y + #rows * STAT_ROW + 4 * U    -- the panel's bottom (readout_recent goes under it)
end

-- a word chip (bg3 fill, 1U ink, no shadow) of height s: at least s wide, wider for a longer word.
-- 分 (branching chart) / 裏 marks. centred: (x, y) is the centre, else the top-left.
function M:mark(key, x, y, s, size, a, centred)
    if not shown(a) then return end
    local w = math.max(s, ceil_u(UI.label_width(key, size) + 3 * U))
    if centred then x, y = x - w / 2, y - s / 2 end
    local ix, iy, iw, ih = UI.frame(x, y, w, s, { fill = P.bg3, shadow = 0 })
    label_at(key, ix + iw / 2, iy + ih / 2, size)
end

-- a tag chip centred on (cx, cy): 24 px ink word, 13U tall, sized to the word (8U padding, +1U for the
-- accent edge); edge = bg3 + accent left edge, else accent fill. max_w: the ancestor frame's width.
function M:tag(key, cx, cy, a, accent, edge, max_w)
    if not shown(a) then return end
    local w = ceil_u(UI.label_width(key, 24) + 8 * U + (edge and U or 0))
    if max_w then w = math.min(w, max_w) end
    local h = 13 * U
    local ix, iy, iw, ih = UI.chrome.chip(UI.grid(cx - w / 2), UI.grid(cy - h / 2), w, h, accent, edge)
    label_at(key, ix + iw / 2, iy + ih / 2, 24)
end

-- 新音源 / 旧音源 / 期間限定 off the board's right edge; お気に入り over the board's top edge; NEW (新曲)
-- off its left edge (positions = the ancestor frames' centres)
local EXD_KEY = { [1] = "sel_new_audio", [2] = "sel_old_audio" }
function M:ex_tag(exd, bx, by, a)
    self:tag(EXD_KEY[exd] or "sel_limited", bx + 532, by + 4, a, (exd == 2) and P.line or P.clear, true, 330)
end
function M:fav_tag(p, bx, by, a)
    self:tag((p == 2) and "sel_fav_2p" or "sel_fav_1p", bx + 375, by + 52, a, (p == 2) and P.p2 or P.p1, true, 330)
end
function M:new_tag(bx, by, a)
    self:tag("sel_new_song", bx - 532, by + 4, a, P.clear, false, 114)
end

-- option-panel badges (自 ド 反 気 乱): bg3 chip right-aligned on the badge spot (modifier/mod_* frame at
-- (165, 1174), chip 3..36): 24 px for one glyph, else 18; wider for a longer word
local MOD_KEY = { auto = "mod_auto_sel", display = "mod_doron_sel", inverse = "mod_inverse_sel" }
function M:mod_badge(name, st, x, row_y)
    local key = MOD_KEY[name]
    if name == "random" then key = (st == 2) and "mod_random" or (st == 1) and "mod_kimagure" or nil end
    if not key then return end
    local size = (UI.label_width(key, 24) <= 33 - 4 * U) and 24 or 18
    local w = math.max(33, ceil_u(UI.label_width(key, size) + 4 * U))
    local ix, iy, iw, ih = UI.frame(x + 168 + 33 - w, row_y + 1177, w, 33, { fill = P.bg3, shadow = 0 })
    label_at(key, ix + iw / 2, iy + ih / 2, size)
end

-- score history: the 良 可 不可 連打 edge chips (frames' spots + (0, 12), 36 tall, 9U padding) and 点
local LB_JUDGE = { { "good", 342, "good" }, { "ok", 417, "ok" }, { "bad", 492, "bad" }, { "roll", 567, "roll" } }
function M:lb_labels()
    for _, j in ipairs(LB_JUDGE) do
        local w = math.min(93, ceil_u(UI.label_width(j[1], 24) + 9 * U))
        local ix, iy, iw, ih = UI.chrome.chip(39, j[2] + 12, w, 36, P[j[3]], true)
        label_at(j[1], ix + iw / 2, iy + ih / 2, 24)
    end
    -- 点 after the score (pts frame index 1 at (288, 271), 48x48: the word starts where 点 did)
    UI.draw_text(UI.text_key("sel_points", 24), 300, 295, "l", 1)
end

-- ---------------------------------------------------------------- mascot events
function M:wheel_event(id)
    if id == 2 then                         -- cursor move
        self.move_t = tex.get_current_ms()
        for _, c in ipairs(self:cast()) do c[1]:react("move") end
        self:face_centre()
    elseif id == 3 then                     -- folder decided
        for _, c in ipairs(self:cast()) do c[1]:react("decide") end
    elseif id == 7 then                     -- back from the course select
        self:face_centre()
    end
end

local function slot_of(diff)
    if diff == nil then return nil end
    if diff >= 0 then return math.min(3, diff) end
    if diff == -1 then return nil end      -- 音色 row: not a card
    return diff
end
M.slot_of = slot_of

function M:on_diff(p, diff, moved)
    local now = tex.get_current_ms()
    self.focus[p] = { slot = slot_of(diff), diff = diff, t = now }
    self.decided[p] = nil
    if moved then self.said_pick = true end   -- the "which one?" bubble leaves on the first move
    local x = DS_SLOT_X[diff]
    for _, c in ipairs(self:cast()) do
        if c[3] == p then
            face(c[1], c[2], x)
            if moved then c[1]:react("move") end
        end
    end
end

function M:on_decide(p)
    local f = self.focus[p]
    self.decided[p] = { slot = f and f.slot, diff = f and f.diff, t = tex.get_current_ms() }
    for _, c in ipairs(self:cast()) do
        if c[3] == p then c[1]:react("decide") end
    end
end

-- mod_off: SongSelect._mod_off (per player: the option panel's y offset, nil = no panel). A mascot whose
-- player's option panel is open is not drawn (the panel would cover it: never cut or covered); neither is
-- the cast while the sort window is open.
function M:draw_mascots(state, mod_off)
    self.mod_off = mod_off
    if state == 1 or self:course_open() then hide_invite() end
    if state ~= self.state then
        if state == 1 and self.state == 0 then
            for _, c in ipairs(self:cast()) do c[1]:react("decide") end
        elseif state ~= 1 then
            self:face_centre()
        end
        self.state = state
    end
    -- the sort window (state 2) spans the left plate: the cast steps out while it is open
    if state == 2 then return end
    if state ~= 1 then self.said_pick = nil end
    for _, c in ipairs(self:cast()) do
        if not (mod_off and mod_off[c[3]]) then
            c[1]:draw(c[2], PLATE_TOP)
            self:say(c[3], c[2])
        end
    end
    self:decide_bursts()
end

-- ---------------------------------------------------------------- polish: mascot lines (course select)
-- Each player's mascot talks about what that player does: "which one?" once the cards have landed (Momo,
-- 1.5 s or until the first move), then on a course decide "here we go!" (oni / ura: a braver line) until
-- the screen leaves. A 36 px UI.bubble over the mascot's head, box shifted outward so it never reaches
-- the board (x 324..1554); a new line pops in 1U low for one 50 ms step.
local SAY_TIP_Y = 704                -- 6 px over the head (menu sprite 204 tall, foot 914)
local SAY_CX = { [1] = 165, [2] = 1745 }
local SAY_MAX_W = 294               -- gutter 6..318 (1P) / 1590..1908 (2P) minus the 2U shadow
local PICK_MS = 1500
function M:say(p, mx)
    if self.state ~= 1 or not self:course_open() then return end
    local now = tex.get_current_ms()
    local key, t0
    local d = self.decided[p]
    if d then
        key = (d.diff and d.diff >= 3) and "sel_say_oni" or "say_start_0"
        t0 = d.t
    elseif p == 1 and not self.said_pick and self:cascade_done() and self.ds_t0 and not self.ds_closing then
        t0 = self.ds_t0 + OPEN_MS + N_SLOTS * CASCADE_MS
        if now - t0 < PICK_MS then key = "sel_say_pick" end
    end
    if not key then return end
    local dy = (now - t0 < CASCADE_MS) and U or 0
    -- 36 px when the box fits the 300 px gutter beside the board (x 324 / 1554), else 24 px (en / ko lines)
    local size = (UI.bubble_width(key, 36) <= SAY_MAX_W) and 36 or 24
    UI.bubble(key, mx, SAY_TIP_Y + dy, { cx = SAY_CX[p], size = size })
end

-- the event burst on top of each freshly decided card (UI.burst: 4 frames x 66 ms, then nothing)
function M:decide_bursts()
    if not self:course_open() then return end
    for p = 1, 2 do
        local d = self.decided[p]
        if d and d.slot and DS_SLOT_X[d.slot] then
            UI.burst(DS_SLOT_X[d.slot], CARD_TOP - 2 * U, tex.get_current_ms() - d.t)
        end
    end
end

return M
