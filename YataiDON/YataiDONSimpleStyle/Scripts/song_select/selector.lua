-- SongSelectPlayer selector cursor (bubble + course frame / button glow), split out of
-- song_select.lua. Drawn in two passes (under/over the wheel).

local base = require("song_select/file_navigator/box_base")

local DIFF_EASY, DIFF_NEIRO, DIFF_ONI = base.DIFF_EASY, base.DIFF_NEIRO, base.DIFF_ONI
local DS_SLOT_X = base.DS_SLOT_X
local DS_BOARD_Y, DS_CURSOR_Y, DS_NEIRO_Y, DS_BTN_Y = base.DS_BOARD_Y, base.DS_CURSOR_Y, base.DS_NEIRO_Y, base.DS_BTN_Y
local SEL_BASE_BALLOON = base.SEL_BASE_BALLOON
local MOD_SLIDE, MOD_SLIDE_MS = base.MOD_SLIDE, base.MOD_SLIDE_MS
local draw_centered, draw_centered_b = base.draw_centered, base.draw_centered_b

-- main_diff sprite 40 (balloon): `in` f10-24 drops from y -50 with a fade (ease-out), `move` f4-9 bobs
-- 3.35 -> 10 -> 0 (linear). Returns y offset and alpha for the frame `i` of a state.
local FRAME_MS = 1000 / 60
local function balloon_motion(st, i)
    -- SimpleStyle (bible 2.7): no eased drop; a move nudges the marker 1U for 66 ms
    if st == "move" and i < 4 then return -3, 1 end
    return 0, 1
end

function SongSelect:draw_selector(player, is_half, fade_in, pass)
    local under = (pass == nil) or (pass == 0)
    local over  = (pass == nil) or (pass == 1)
    local diff = player:selected_difficulty()
    local p = player:player_num()
    if under then
        self._mark_diff[p] = diff
        local decided = diff >= DIFF_EASY and player.difficulty_decided and player:difficulty_decided()
        if decided then
            if not self._mark_decided[p] then
                self._mark_decided[p] = { t0 = tex.get_current_ms(), course = diff }
                if SS_SEL then SS_SEL:on_decide(p) end
            end
        else
            self._mark_decided[p] = nil
        end
    end
    self._bal = self._bal or {}
    if fade_in < 1.0 or (SS_SEL and (SS_SEL:ds_open() < 1 or not SS_SEL:cascade_done())) then self._bal[p] = nil return end
    local bal = self._bal[p]
    if not bal then
        bal = { diff = diff, t0 = tex.get_current_ms(), st = "in" }
        if SS_SEL then SS_SEL:on_diff(p, diff, false) end
        self._bal[p] = bal
    elseif bal.diff ~= diff then
        bal.diff, bal.t0, bal.st = diff, tex.get_current_ms(), "move"
        if SS_SEL then SS_SEL:on_diff(p, diff, true) end
    end
    local bal_dy, bal_a = balloon_motion(bal.st, (tex.get_current_ms() - bal.t0) / FRAME_MS)
    local mod_on = player:modifier_active()
    if player.modifier_offset then
        local mo = player:modifier_offset() -- nil while the board is closed
        self._mod_off[p] = mo and (mo - (self.mod_lift and self:mod_lift(player) or 0))
    elseif mod_on then
        if not self._mod_seen[p] then
            local now = tex.get_current_ms()
            local prev = self._last_sel_ms or now
            self._mod_t0[p] = (now - prev < 250) and math.min(now, prev + 16.7) or now
        end
        local u = math.max(0.0, math.min(1.0, (tex.get_current_ms() - self._mod_t0[p]) / MOD_SLIDE_MS))
        self._mod_off[p] = -MOD_SLIDE * u * (2 - u)
    else
        self._mod_off[p] = nil
    end
    self._last_sel_ms = tex.get_current_ms()
    self._mod_seen[p] = mod_on
    local fade = fade_in   -- SimpleStyle: marker / focus ring stay solid while a panel is open
    -- the cursor offset is +-40 only while both players sit on the same slot
    local cursor_dx = is_half and ((p == 2) and 40 or -40) or 0
    local sx = DS_SLOT_X[(diff >= DIFF_EASY) and math.min(DIFF_ONI, diff) or diff]
    if not sx then return end

    if diff >= DIFF_EASY then
        local col = math.min(DIFF_ONI, diff)
        if col == DIFF_ONI and self._ura_anim then return end   -- cursor/frame hidden during the change
        sx = DS_SLOT_X[col]
        local frame_id = (p == 1) and self._id_course_frame or self._id_course_frame2
        local ss_dy, ss_on = 0, true
        if SS_SEL then ss_dy, ss_on = SS_SEL:ring(p, col) end
        if under and ss_on then draw_centered(frame_id, sx, DS_BOARD_Y + ss_dy, 248, 408, { fade = fade }) end
        if over then
            draw_centered_b((p == 1) and self._id_bubble_1p or self._id_bubble_2p, SEL_BASE_BALLOON,
                            sx + cursor_dx, DS_CURSOR_Y + bal_dy, 124, 124, { fade = fade * bal_a })
            if SS_SEL then SS_SEL:column_cursor(sx + cursor_dx, fade * bal_a) end
            if SS_SEL then SS_SEL:marker_label(p, sx + cursor_dx, DS_CURSOR_Y + bal_dy, fade * bal_a) end
        end
    else
        local by = (diff == DIFF_NEIRO) and DS_NEIRO_Y or DS_BTN_Y
        local ss_dy, ss_on = 0, true
        if SS_SEL and diff ~= DIFF_NEIRO then ss_dy, ss_on = SS_SEL:ring(p, diff) end
        if under and ss_on then draw_centered(self._id_btn_glow, sx, by + ss_dy, 168, 400, { fade = fade }) end   -- r3: tall
        if over then
            draw_centered_b((p == 1) and self._id_bubble_1p or self._id_bubble_2p, SEL_BASE_BALLOON,
                            sx + cursor_dx, DS_CURSOR_Y + bal_dy, 124, 124, { fade = fade * bal_a })
            if SS_SEL then SS_SEL:column_cursor(sx + cursor_dx, fade * bal_a) end
            if SS_SEL then SS_SEL:marker_label(p, sx + cursor_dx, DS_CURSOR_Y + bal_dy, fade * bal_a) end
        end
    end
end
