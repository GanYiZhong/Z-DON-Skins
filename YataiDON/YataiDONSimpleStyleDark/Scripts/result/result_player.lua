-- YataiDONSimpleStyle v2: result board (1P / 2P). Same engine contract as Nijiiro's result_player
-- (fade_in_started, reveal_end_ms, count_up_*), but every value lands at once and this script runs
-- its own staged reveal on the bible's motion grid (2.7):
--   board opens in 3 frames (50 ms each) -> gauge fills cell by cell -> score counts up in steps ->
--   judge rows tick in 100 ms apart -> medal (score rank) drops with a sparkle burst -> crown drops ->
--   the mascots cheer (or sit) and the bubble opens.
-- Draws only Graphics/result/ss textures and core Lua chrome. All coordinates LOGICAL (1920x1080).
local UI = require("global.ss_ui")
local AI = require("global.ss_ai")
local DEF = require("result.ss_result_def")
local P = UI.P
local U = UI.U

ResultPlayer = {}
ResultPlayer.__index = ResultPlayer

local OFF2 = 957
local GX0, GY0, GH, G_CELL, G_CELLS = 72, 246, 42, 15, 50
local SB = { 72, 330, 498, 438 }
local JX1, JY0 = 906, 330       -- judge rows; pitch DEF.pitch_s (1P) / DEF.pitch_t (2P)
-- 141 x 156: core rank badge (135) + ribbon; badge centre +72, +66. 1P sits lower (taller rows)
local MEDAL_XY = { s = { 84, 486 }, t = { 84, 441 } }
local CROWN_XY = { s = { 300, 507 }, t = { 300, 462 } }   -- 132 x 102: core crown (3U cells) + chip
-- 1P festival stage group, centred in the free space right of the board (x 936..1920)
local STAGE_CX = 1428
local MOMO_X, HOSHI_X = STAGE_CX - 240, STAGE_CX + 240
local DIGIT_W, DIGIT_PITCH = 42, 36

local OPEN_MS = 50            -- one window-open frame
local GAUGE_WAIT, GAUGE_CELL_MS = 100, 20
local LAND_WAIT = 150         -- gauge done -> values requested from the engine
local SCORE_STEPS, SCORE_STEP_MS = 12, 50
local T_ROWS, ROW_MS = 700, 100
local T_MEDAL, T_CROWN, T_CHEER = 1250, 1500, 1800
local T_DIST, DIST_CELL_MS = 1200, 10   -- 1P judge breakdown bar: after the last row, one cell per 10 ms
-- polish (celebration): 1P pass = the big crown slams into the sky over the stage at T_CROWN, the
-- mascots cheer under it, then it pops and hands off to the board's crown slot at T_HANDOFF; fireworks
-- from the cheer; the party loop (cheer / clear every 500 ms) after it
local T_HANDOFF, T_PARTY = 2700, 2700
local ROW_STEPS = 3                     -- each judge value counts up in 3 steps of 50 ms
local CB_CX, CB_Y = STAGE_CX, 132       -- big crown: centre x, top y (sky, above the clouds' band)
-- firework burst centres in the free sky right of the board (clear of the title, the big crown and its
-- label band, and the 2曲目 chip)
-- (y >= 207: a burst is 66 px in radius, so it never reaches a long title / subtitle line, y <= 138).
-- The centre slots come 5th / 6th: their bursts open after the sky crown has handed off.
local FW_SLOTS = { { 1083, 213 }, { 1779, 207 }, { 1131, 360 }, { 1743, 354 }, { 1428, 228 }, { 1287, 300 } }

-- Z-DON timing panel (tex.hit_offsets, src/libs/zdon_lua.cpp): 1P mode, in the sky between the side
-- firework slots (the centre slots are left out while it is up), after the sky crown hands off
local FW_SIDE = { FW_SLOTS[1], FW_SLOTS[2], FW_SLOTS[3], FW_SLOTS[4] }
local TP_X, TP_Y, TP_W, TP_H = 1206, 150, 444, 276
local T_TIMING = T_HANDOFF + 200
local TP_BINS = 25                      -- odd: the centre bin holds 0 ms

local RAINBOW = { P.oni, P.easy, P.clear, P.normal, P.hard, P.ura }   -- core course.RAINBOW6 order
local RANKS = { 500000, 600000, 700000, 800000, 900000, 950000, 1000000 }
local SPEEDS = { 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 25, 30, 35, 40 }

local function T(k) return tex.get_texture("result/ss/" .. k) end

-- hit offsets -> histogram bins over +-ok window (outliers into the end bins), mean, spread (std dev)
local function timing_stats(offs, good, ok)
    local bins, n, sum = {}, #offs, 0
    for i = 1, TP_BINS do bins[i] = 0 end
    local half = (TP_BINS - 1) / 2
    for _, v in ipairs(offs) do
        sum = sum + v
        local b = math.floor(v / ok * half + 0.5)
        b = math.max(-half, math.min(half, b))
        bins[b + half + 1] = bins[b + half + 1] + 1
    end
    local mean = sum / n
    local var = 0
    for _, v in ipairs(offs) do var = var + (v - mean) ^ 2 end
    local peak = 1
    for i = 1, TP_BINS do peak = math.max(peak, bins[i]) end
    return { bins = bins, peak = peak, mean = mean, sd = math.sqrt(var / n), good = good, ok = ok }
end

local function signed(v)
    local r = math.floor(v + 0.5)
    return ((r > 0) and "+" or "") .. tostring(r)
end
local function info(k) return tex.get_texture_info("ss", k) end

-- run-time word chrome (player's language): result/ss_result_ui.lua
local W = require("result.ss_result_ui")
local FX = require("result.ss_result_fx")
local chip, chip_w, soul_cap, best_banner = W.chip, W.chip_w, W.soul_cap, W.best_banner

-- score -> rank tier 0..6 (粋 粋 粋 雅 雅 雅 極, the core rank badge), nil below 500k
local function tier_of(score)
    local r = 0
    for i, t in ipairs(RANKS) do if score >= t then r = i end end
    return r > 0 and (r - 1) or nil
end

-- 3-frame drop with a 1U settle (bible 2.7 stamp drop): y offset at ms since the event
local function drop_dy(t)
    if t < 0 then return nil end
    if t < 50 then return -6 * U end
    if t < 100 then return -3 * U end
    if t < 150 then return U end
    return 0
end

-- window-open fraction: 1/3, 2/3, 1 over 3 frames
local function open_p(t)
    if t < 0 then return 0 end
    if t < OPEN_MS then return 1 / 3 end
    if t < 2 * OPEN_MS then return 2 / 3 end
    return 1
end


function ResultPlayer.new(player_num, is_2p, has_2p, gauge_length, difficulty, selected_difficulty,
                          crown_type, score_diff, score_method, mod_display, mod_inverse, mod_random, mod_speed)
    local self = setmetatable({}, ResultPlayer)
    UI.reset()
    self.t0 = tex.get_current_ms()
    self.player_num, self.is_2p, self.has_2p = player_num, is_2p, has_2p
    self.off = is_2p and OFF2 or 0
    self.lay = has_2p and "t" or "s"
    self.pitch = has_2p and DEF.pitch_t or DEF.pitch_s
    self.gauge_length = gauge_length
    self.gauge_cells = math.floor(gauge_length * G_CELLS / 87 + 1e-4)
    self.course = math.min(math.max(selected_difficulty, 0), 4)
    self.crown_type = crown_type
    self.score_diff = score_diff
    self.score_method = score_method

    local d = math.min(math.max(difficulty, 0), 3)
    local ART = { [0] = 0, [1] = 1, [2] = 1, [3] = 2 }
    local NORMA = { [0] = 6000, [1] = 7000, [2] = 7000, [3] = 8000 }
    self.clear_pt = ({ 30, 35, 40 })[ART[d] + 1]
    if gauge_length == 87 then self.gauge_state = 2
    elseif gauge_length / 87.0 * 10000.0 >= NORMA[d] - 0.5 then self.gauge_state = 1
    else self.gauge_state = 0 end

    local pn = (player_num == 2) and 2 or 1
    self.pn = pn
    self.pcol = pn == 2 and P.p2 or P.p1
    self.seat_c = has_2p and (is_2p and "_r" or "_l") or "_c"
    self.seat_lr = is_2p and "_r" or "_l"

    -- engine contract: values land at once (we stage them ourselves), engine count sounds muted
    self.count_up_instant = true
    self.count_up_row_ms = 0
    self.count_up_score_ms = 0
    self.count_up_row_sound = "ss_none"
    self.count_up_score_sound = "ss_none"
    self.count_up_sound_1p_only = true
    self.fade_in_started = false
    self.reveal_end_ms = 0

    self.score, self.good, self.ok, self.bad, self.max_combo, self.total_drumroll = "", "", "", "", "", ""
    self.gauge_shown = 0

    self.t_board = T((has_2p and "board_t_p" or "board_s_p") .. pn)
    self.t_digit = T("score_digit")
    self.t_medal = T("medal_p" .. pn)
    self.t_crown = T("crown")
    self.t_soul = T("soul")
    self.t_crown_big = T("crown_big")
    self.fw = FX.textures("result/ss")

    -- option chips (arcade order: speed, doron, abekobe, random): speed = baked digits chip, the
    -- others are word chips drawn at run time (string keys)
    self.options = {}
    if mod_speed > 10 then
        local best, bi = 1e9, 1
        for i, s in ipairs(SPEEDS) do
            if math.abs(s - mod_speed) < best then best, bi = math.abs(s - mod_speed), i end
        end
        local i = info("opt_speed")
        table.insert(self.options, { t = T("opt_speed"), frame = bi - 1, w = i and i.width or 90 })
    end
    if mod_display then table.insert(self.options, { key = "opt_doron" }) end
    if mod_inverse then table.insert(self.options, { key = "opt_inverse" }) end
    if mod_random == 1 then table.insert(self.options, { key = "opt_kimagure" })
    elseif mod_random == 2 then table.insert(self.options, { key = "opt_detarame" }) end

    local timing = tex.timing_offset(player_num)
    -- timing offset chip only when there is a value ("-- ms" = no data: hidden)
    if timing and tostring(timing):find("%d") then self.timing_text = UI.text(timing, 18, "ink") end

    -- Z-DON: every hit's offset -> the timing panel (1P mode only); the saved best before this play ->
    -- the best chip when this play did not beat it (tex.* absent on upstream engines: neither shows)
    if tex.hit_offsets then
        local offs, good, ok = tex.hit_offsets(player_num)
        if offs and #offs > 0 then self.timing = timing_stats(offs, good, ok) end
    end
    -- 1P mode: the sky panel; 2P mode: a compact one in the board's mascot window, on the side away from
    -- the mascot (1P board: right of Momo, 2P board: left of Hoshi), above the speech bubble (y 735)
    if has_2p then
        self.tp = { x = is_2p and (69 + OFF2) or 330, y = 621, w = 576, h = 105, compact = true }
    else
        self.tp = { x = TP_X, y = TP_Y, w = TP_W, h = TP_H }
    end
    self.best = (tex.best_score and tex.best_score(player_num)) or 0

    -- message line: 0 miss, 1 near, 2 clear, 3 soul gauge full, 4 full combo, 5 all good
    if self.gauge_state == 0 then
        self.line = (gauge_length > 87 * 0.3) and 1 or 0
    elseif crown_type == 2 then self.line = 5
    elseif crown_type == 1 then self.line = 4
    elseif self.gauge_state == 2 then self.line = 3
    else self.line = 2 end
    self.passed = self.gauge_state >= 1
    self.big = self.passed and not has_2p          -- 1P pass: the sky crown slam + fireworks

    -- mascots: 1P mode = both on the festival stage (Momo drums the taiko, Hoshi faces her);
    -- 2P mode = this player's own mascot in its board's stage compartment
    if not has_2p then
        self.stage = "c"
        self.momo = UI.Mascot.new({ char = "momo", role = "scene", beat = false })
        self.hoshi = UI.Mascot.new({ char = "hoshi", role = "scene", beat = false })
        self.momo:react("turn", 1)
        self.hoshi:react("turn", -1)
        self.speaker = self.hoshi
    else
        self.stage = is_2p and "r" or "l"
        local ch = is_2p and AI.p2_char() or "momo"
        self.own = UI.Mascot.new({ char = ch, role = "menu", beat = false })   -- 2P band: menu k (a scene k
        -- mascot is taller than the 291 px compartment and would be cut by its top edge)
        self.speaker = self.own
    end
    -- the speaker's bubble (UI.bubble, sized to the line in the player's language, 24 px, 66 tall).
    -- tip = the tail tip; box: 1P stage = tail 60 px from the box's right end, over Hoshi's head;
    -- 2P = tail near the box's outer end (left board: left end, right board: right end)
    local key = "res_bub_" .. self.line
    local w = UI.bubble_width(key, 24)
    local tip_y = 543 + DEF.bubble_h + 33
    if not has_2p then
        self.bub = { key = key, w = w, tx = HOSHI_X, ty = tip_y, x = HOSHI_X + 60 - w, y = 543 }
    elseif is_2p then
        self.bub = { key = key, w = w, tx = 1557, ty = 735 + DEF.bubble_h + 33, x = 1557 + 6 * U - w, y = 735 }
    else
        self.bub = { key = key, w = w, tx = 345 + 6 * U, ty = 735 + DEF.bubble_h + 33, x = 345, y = 735 }
    end
    return self
end

-- the time of a stage (ms since the score landed), or nil before
function ResultPlayer:since(t)
    if not self.S then return nil end
    return self.now - (self.S + t)
end

function ResultPlayer:update(current_ms, fade_in_finished, score, good, ok, bad, max_combo, total_drumroll, is_skipped)
    self.now = current_ms
    self.score, self.good, self.ok, self.bad = score, good, ok, bad
    self.max_combo, self.total_drumroll = max_combo, total_drumroll

    if is_skipped and not self.skipped then
        self.skipped = true
        if self.count_loop_on then
            self.count_loop_on = false
            audio.stop_sound("count_up_loop" .. self.seat_c)
        end
    end

    -- gauge: after the board is open, one cell per 20 ms
    if fade_in_finished and not self.g0 then self.g0 = current_ms + GAUGE_WAIT end
    if self.g0 and not self.gauge_done then
        local e = current_ms - self.g0
        if self.skipped then
            self.gauge_shown = self.gauge_cells
        elseif e > 0 then
            if not self.count_loop_on and self.gauge_cells > 0 then
                self.count_loop_on = true
                audio.play_sound("count_up_loop" .. self.seat_c, "sound", true)
            end
            self.gauge_shown = math.min(self.gauge_cells, math.floor(e / GAUGE_CELL_MS))
        end
        -- the moment the fill reaches the norma (クリア chip lights): one burst on the chip
        if not self.clear_hit and self.gauge_state >= 1 and self.gauge_shown >= self.clear_pt - 1 then
            self.clear_hit = self.skipped and -1e9 or current_ms
        end
        if self.gauge_shown >= self.gauge_cells and (e > 0 or self.skipped) then
            self.gauge_done = true
            self.land_at = current_ms + (self.skipped and 0 or LAND_WAIT)
            if self.count_loop_on then
                self.count_loop_on = false
                audio.stop_sound("count_up_loop" .. self.seat_c)
            end
            if self.gauge_state == 2 then
                audio.play_sound("achieve_tamashii" .. self.seat_lr, "sound")
                self.full_hit = self.skipped and -1e9 or current_ms
            end
        end
    end
    if self.land_at and current_ms >= self.land_at then self.fade_in_started = true end

    -- the score is the engine's last field: the reveal clock starts when it is in
    if self.score ~= "" and not self.S then
        self.S = current_ms
        self.score_n = math.floor(tonumber(self.score) or 0)
        self.rank = tier_of(self.score_n)
    end
    if self.S and self.skipped and not self.skip_settled then
        self.skip_settled = true
        self.S = math.min(self.S, current_ms - T_CHEER - 200)     -- every stage already played
        self.silent = true
    end

    -- staged events (sounds + mascot reactions), each once
    if self.S then
        local s = current_ms - self.S
        self.ev = self.ev or {}
        local function once(name, at, fn)
            if s >= at and not self.ev[name] then self.ev[name] = true; fn() end
        end
        once("score", SCORE_STEPS * SCORE_STEP_MS, function()
            if not self.silent and self.player_num == 1 then audio.play_sound("don_big", "sound") end
        end)
        for r = 0, 4 do
            once("row" .. r, T_ROWS + r * ROW_MS, function()
                if not self.silent and self.player_num == 1 then audio.play_sound("count_stop", "sound") end
                local drummer = self.momo or self.own
                if not self.silent and drummer and self.momo then drummer:react("hit") end
            end)
        end
        once("medal", T_MEDAL, function()
            if self.rank and not self.silent then audio.play_sound("scorerank" .. self.seat_c, "sound") end
        end)
        once("crown", T_CROWN, function()
            if self.passed then
                local colours = { [0] = "silver", [1] = "gold", [2] = "rainbow" }
                audio.play_sound("crown_" .. (colours[self.crown_type] or "silver") .. self.seat_c, "sound")
                if self.crown_type == 1 or self.crown_type == 2 then
                    audio.play_sound("full_combo_voice_" .. self.pn .. "p", "voice")
                end
            end
        end)
        once("cheer", T_CHEER, function()
            local voices = { [0] = "max_fail_voice_", [1] = "fail_voice_", [2] = "clear_voice_", [3] = "max_clear_voice_" }
            local vf = self.gauge_state == 2 and 3 or (self.passed and 2 or (self.line == 1 and 1 or 0))
            audio.play_sound(voices[vf] .. self.pn .. "p", "voice")
            if self.passed then audio.play_sound("atmos_clear" .. self.seat_c, "sound") end
            self:cheer()
            self.reveal_end_ms = current_ms
        end)
        once("hop2", T_CHEER + 250, function()
            if self.passed then
                if self.momo then self.momo:hop(); self.hoshi:hop() else self.own:hop() end
            end
        end)
    end

    if self.momo then self.momo:update(current_ms); self.hoshi:update(current_ms) end
    if self.own then self.own:update(current_ms) end
end

function ResultPlayer:cheer()
    local m = self.momo or self.own
    if self.passed then
        if self.momo then
            self.momo:react("turn", 0); self.momo:flash("cheer", 600); self.momo:hop()
            self.hoshi:react("turn", 0); self.hoshi:flash("cheer", 600); self.hoshi:hop()
            self.momo:set_mood("clear")
        else
            m:flash("cheer", 600); m:hop(); m:set_mood("clear")
        end
    else
        m:react("turn", 0)
        m:react("fail")
        if self.hoshi then self.hoshi:react("turn", -1) end
    end
end

-- ---------------------------------------------------------------- drawing
function ResultPlayer:draw()
    local now = tex.get_current_ms()
    self.now = now
    local o = self.off
    local tall = self.has_2p
    local bw, bh = 936 - 42, (tall and DEF.board_t_y1 or DEF.board_s_y1) - 180

    -- board window open (3 frames), then the baked board
    local p = open_p(now - self.t0)
    if p <= 0 then return end
    if p < 1 then
        UI.frame(42 + o, 180, bw, UI.grid(bh * p), {})
        return
    end
    if self.t_board then tex.draw_texture(self.t_board, { x = 42 + o, y = 180 }) end
    local plate_w = W.course_plate(self.course, 39 + o, 177)

    -- judge row chips (edge style, 144 wide or the label's width) and the breakdown strip's chips
    local JROWS = { { "good", P.good }, { "ok", P.ok }, { "bad", P.bad }, { "dan_ex_roll", P.roll },
                    { "dan_ex_combo", P.clear } }
    for r, jr in ipairs(JROWS) do
        local top = JY0 + self.pitch * (r - 1)
        chip(jr[1], 528 + o, top + UI.grid((self.pitch - W.CH) / 2), DEF.judge_chip_w, jr[2], true)
    end
    if not tall then
        chip("judge_breakdown", 72 + o, DEF.dist_row_y, nil, P.paper, false)
        local DIST = { { "good", P.clear }, { "ok", P.ok }, { "bad", P.bad } }
        for j, it in ipairs(DIST) do
            chip(it[1], DEF.dist_slots[j] + o, DEF.dist_row_y, DEF.dist_chip_w, it[2], true)
        end
    end

    -- header row: option chips after the plate, timing + 1P/2P chips on the right
    local x = math.max(330 + o, 39 + o + plate_w + 2 * U)
    for _, op in ipairs(self.options) do
        if op.t then
            tex.draw_texture(op.t, { frame = op.frame, x = x, y = 186 })
            x = x + op.w + U
        elseif op.key then
            x = x + chip(op.key, x, 186, nil, P.bg3, false) + U
        end
    end
    local pkey = self.pn == 2 and "player_2p" or "player_1p"
    local pw = chip_w(pkey, "paper")
    local px = 921 + o - pw
    chip(pkey, px, 186, nil, self.pcol, false, "paper")
    if self.timing_text then
        local tw = UI.grid(self.timing_text.width) + 8 * U
        local tx = px - U - tw
        UI.chrome.chip(tx, 186, tw, W.CH, nil, false)
        UI.draw_text(self.timing_text, tx + 4 * U, 186 + W.CH / 2, "l")
    end

    -- score box label (paper chip on the player-colour box)
    chip(self.score_method and "score_shinuchi" or "score", SB[1] + 9 + o, SB[2] + 9, nil, P.paper, false)

    local s = self.S and (now - self.S) or nil
    if s then
        -- score: counts up in 12 steps of 50 ms
        local k = math.min(SCORE_STEPS, math.floor(s / SCORE_STEP_MS) + 1)
        local v = math.floor(self.score_n * k / SCORE_STEPS / 10) * 10
        if k >= SCORE_STEPS then v = self.score_n end
        self:draw_score(tostring(v), o)
        -- the score lands: a 2-frame gold ring steps out of the box + one burst on the digits
        local land = s - (SCORE_STEPS - 1) * SCORE_STEP_MS
        FX.ring(SB[1] + o, SB[2], SB[3] - SB[1], SB[4] - SB[2], land, P.clear)
        UI.burst(SB[3] - 12 - 66 + o, 405, land)

        -- judge rows tick in 100 ms apart
        local vals = { self.good, self.ok, self.bad, self.total_drumroll, self.max_combo }
        for r = 0, 4 do
            local rt = s - (T_ROWS + r * ROW_MS)
            if rt >= 0 and vals[r + 1] ~= "" then
                -- counts up in ROW_STEPS steps of 50 ms (the drum hit lands on the first step)
                local str, n = vals[r + 1], tonumber(vals[r + 1])
                local k = math.floor(rt / 50) + 1
                if n and k < ROW_STEPS then str = tostring(math.floor(n * k / ROW_STEPS)) end
                UI.num(str, JX1 + o, JY0 + self.pitch * r + self.pitch / 2, "l", P.ink, 255, "r")
            end
        end
        if not tall then self:draw_dist(s) end

        -- new best banner (opens when the count-up ends)
        if self.score_diff > 0 then
            local bp = open_p(s - SCORE_STEPS * SCORE_STEP_MS)
            if bp >= 1 then
                local bw = best_banner(72 + o, 294, s - SCORE_STEPS * SCORE_STEP_MS - 400)
                UI.num("+" .. tostring(self.score_diff), 72 + o + bw - 6, 294 + W.CH / 2, "s", P.on_acc, 255, "r")
            elseif bp > 0 then
                UI.frame(72 + o, 294, 426, UI.grid(W.CH * bp) + U, { fill = P.clear, shadow = 0, notch = 0 })
            end
        elseif self.best > 0 and s >= SCORE_STEPS * SCORE_STEP_MS then
            -- Z-DON: not a new best: the saved best and this play's distance to it (bg3 chip, same slot)
            local ix, iy, iw, ih = UI.frame(72 + o, 294, 426, W.CH + U, { fill = P.bg3, shadow = 0, notch = 0 })
            local lw = UI.draw_text(UI.text_key("res_best", 18, "ink"), ix + 3 * U, iy + ih / 2, "l")
            UI.num(tostring(self.best), ix + 3 * U + lw + 3 * U, iy + ih / 2, "s", P.ink, 255, "l")
            UI.num(signed((self.score_n or 0) - self.best), ix + iw - 3 * U, iy + ih / 2, "s", P.ink, 255, "r")
        end

        -- medal (score rank): 3-frame drop, 1U settle, one sparkle burst
        if self.rank and self.t_medal then
            local dy = drop_dy(s - T_MEDAL)
            if dy then
                local mx, my = MEDAL_XY[self.lay][1] + o, MEDAL_XY[self.lay][2]
                tex.draw_texture(self.t_medal, { frame = self.rank, x = mx, y = my + dy })
                UI.burst(mx + 72, my + 66, s - T_MEDAL - 150)
            end
        end
        -- crown: course colour on clear, gold on full combo
        if self.passed and self.t_crown then
            local tc = self.big and T_HANDOFF or T_CROWN      -- 1P: after the sky crown hands off
            local dy = drop_dy(s - tc)
            if dy then
                local f = self.crown_type >= 1 and (4 + self.crown_type) or self.course
                local cx, cy = CROWN_XY[self.lay][1] + o, CROWN_XY[self.lay][2] + dy
                tex.draw_texture(self.t_crown, { frame = f, x = cx, y = cy })
                -- the chip under the crown: clear = course colour + outlined paper text, gold = ink text
                local key, fill, st = "clear", UI.course.color(self.course), "paper"
                if self.crown_type == 1 then key, fill, st = "full_combo", P.clear, "on_acc"
                elseif self.crown_type == 2 then key, fill, st = "zenryo", P.clear, "on_acc" end
                local w = chip_w(key, st)
                chip(key, UI.grid(cx + (132 - w) / 2), cy + 102 - W.CH - U, nil, fill, false, st)
                if self.big then UI.burst(cx + 66, cy + 39, s - tc - 100) end
            end
        end
    end

    self:draw_stage(s)
    self:draw_timing(s)
    if self.player_num == 1 then AI.draw_result() end   -- Z-DON AI battle: the match banner
end

-- the timing panel: header chip + average / spread, the histogram (good window shaded, 0 ms rule, gold
-- bars inside the good window, 可 grey outside), FAST / SLOW under its ends. Opens in 3 frames.
-- Compact (2P mode): no chip; FAST, average / spread, SLOW on one header row, shorter bars.
function ResultPlayer:draw_timing(s)
    local tm, g = self.timing, self.tp
    if not tm or not s or not g then return end
    local p = open_p(s - T_TIMING)
    if p <= 0 then return end
    if p < 1 then
        UI.frame(g.x, g.y, g.w, UI.grid(g.h * p), {})
        return
    end
    local ix, iy, iw, ih = UI.chrome.panel(g.x, g.y, g.w, g.h, P.paper)
    if not g.compact then chip("res_timing", ix + 3 * U, iy + 3 * U, nil, P.clear, true) end
    if not tm.head then
        tm.head = UI.text((UI.t("res_avg") or "") .. " " .. signed(tm.mean) .. " ms   " ..
                          (UI.t("res_spread") or "") .. " " .. string.format("%d", math.floor(tm.sd + 0.5)) ..
                          " ms", 18, "ink")
    end
    local hx0, hx1 = ix + 6 * U, ix + iw - 6 * U
    local bw = math.floor((hx1 - hx0) / TP_BINS / U) * U
    local gx0 = UI.grid((hx0 + hx1) / 2 - bw * TP_BINS / 2)
    local base, top
    if g.compact then
        local hy = iy + 2 * U + W.CH / 2
        UI.draw_text(tm.head, ix + iw / 2, hy, "c")
        -- FAST / SLOW at the panel's inner edges (not the histogram's): the 24 px head is 300-370 wide
        UI.draw_text(UI.text_key("fast", 18, { color = P.p2 }), hx0, hy, "l")
        UI.draw_text(UI.text_key("slow", 18, { color = P.easy }), hx1, hy, "r")
        base, top = iy + ih - 3 * U, iy + 12 * U
    else
        -- the head (average / spread, up to ~370 wide) goes on its own row under the chip
        UI.draw_text(tm.head, ix + 6 * U, iy + 3 * U + W.CH + 3 * U + 12, "l")
        base, top = iy + ih - 12 * U, iy + 26 * U
    end
    local hh = base - top
    local half = (TP_BINS - 1) / 2
    local gb = math.floor(tm.good / tm.ok * half + 0.5)       -- bins inside the good window: |b| <= gb
    UI.rect(gx0 + (half - gb) * bw, top, (2 * gb + 1) * bw, hh, P.bg3)
    for i = 1, TP_BINS do
        local c = tm.bins[i]
        if c > 0 then
            local h = math.max(U, UI.grid(hh * c / tm.peak))
            local b = i - 1 - half
            UI.rect(gx0 + (i - 1) * bw + U, base - h, bw - U, h, (math.abs(b) <= gb) and P.clear or P.ok)
        end
    end
    UI.rect(gx0, base, bw * TP_BINS, U, P.ink)
    UI.rect(gx0 + half * bw + UI.grid(bw / 2) - U, top, U, hh, P.ink)
    if not g.compact then
        UI.draw_text(UI.text_key("fast", 18, { color = P.p2 }), gx0, base + 6 * U, "l")
        UI.draw_text(UI.text_key("slow", 18, { color = P.easy }), gx0 + bw * TP_BINS, base + 6 * U, "r")
    end
end

-- 1P judge breakdown: a 55-cell bar split by the 良 (gold, as the judge mark) / 可 / 不可 shares (cumulative rounding, so the
-- cells always add up), filled left to right one cell per 10 ms after the last judge row; the legend
-- values (one decimal, %) land with the last cell. Frame, groove, label and legend chips are baked.
function ResultPlayer:draw_dist(s)
    local g, k, b = tonumber(self.good) or 0, tonumber(self.ok) or 0, tonumber(self.bad) or 0
    local t = g + k + b
    if t <= 0 or s < T_DIST then return end
    local D = DEF.dist_bar
    local o = self.off
    local bx, by, n, cp, bh = D[1] + o, D[2], D[3], D[4], D[5]
    local c1 = math.floor(n * g / t + 0.5)
    local c2 = math.floor(n * (g + k) / t + 0.5)
    local shown = math.min(n, math.floor((s - T_DIST) / DIST_CELL_MS) + 1)
    for i = 0, shown - 1 do
        local c = (i < c1) and P.clear or ((i < c2) and P.ok or P.bad)
        UI.rect(bx + U + i * cp, by + U, cp - U, bh - 2 * U, c)
    end
    if shown >= n then
        -- accuracy (良 + 可 / 2 over all judged notes) between the label chip and the legend
        local acc = string.format("%.2f%%", 100 * (g + 0.5 * k) / t)
        local lx = 72 + o + chip_w("judge_breakdown") + 3 * U
        local lw = UI.draw_text(UI.text_key("res_accuracy", 18, "ink"), lx, DEF.dist_row_y + W.CH / 2, "l")
        UI.num(acc, lx + lw + 2 * U, DEF.dist_row_y + W.CH / 2, "m", P.ink, 255, "l")
        local vals = { g, k, b }
        for j = 1, 3 do
            local pct = string.format("%.1f%%", 100 * vals[j] / t)
            UI.num(pct, DEF.dist_slots[j] + DEF.dist_slot_w + o, DEF.dist_row_y + W.CH / 2, "m", P.ink, 255, "r")
        end
    end
end

function ResultPlayer:draw_score(str, o)
    if not self.t_digit then return end
    local right = SB[3] - 12 + o
    local n = #str
    for i = 1, n do
        local d = tonumber(str:sub(i, i)) or 0
        local x = right - DIGIT_W - (n - i) * DIGIT_PITCH
        tex.draw_texture(self.t_digit, { frame = d, x = x, y = 378 })
    end
end

-- crown kind -> the 1P celebration: fireworks salvo size / gap / repeat period (nil = salvo only)
function ResultPlayer:fw_plan()
    if self.crown_type == 2 then return 6, 200, 1000 end
    if self.crown_type == 1 or self.gauge_state == 2 then return 5, 250, 1500 end
    return 3, 250, nil
end

-- the sky crown slam (1P pass): big crown + word band, slams in at T_CROWN, pops at T_HANDOFF
function ResultPlayer:draw_sky_crown(s)
    local t = s - T_CROWN
    if t < 0 or s >= T_HANDOFF + 300 or not self.t_crown_big then return end
    local cw, ch = DEF.crown_big[1], DEF.crown_big[2]
    local x0 = UI.grid(CB_CX - cw / 2)
    if s >= T_HANDOFF then            -- the pop: one burst where it was, the board crown takes over
        UI.burst(CB_CX, CB_Y + ch / 2, s - T_HANDOFF)
        return
    end
    local dy = FX.slam(t, 36 * U)
    local f = self.crown_type >= 1 and (4 + self.crown_type) or self.course
    tex.draw_texture(self.t_crown_big, { frame = f, x = x0, y = CB_Y + dy })
    if t >= 150 then
        UI.burst(x0 + 6 * U, CB_Y + 9 * U, t - 150)
        UI.burst(x0 + cw - 6 * U, CB_Y + 9 * U, t - 216)
    end
    -- the word band under it: gold + ink (full combo / zenryo) or course colour + outlined paper (clear)
    local key, fill, st = "clear", UI.course.color(self.course), "paper"
    if self.crown_type == 1 then key, fill, st = "full_combo", P.clear, "on_acc"
    elseif self.crown_type == 2 then key, fill, st = "zenryo", P.clear, "on_acc" end
    local bp = open_p(t - 150)
    if bp <= 0 then return end
    local bw = math.ceil((UI.label_width(key, 48, st) + 24 * U) / U) * U
    local by = CB_Y + ch + 4 * U
    local bx = UI.grid(CB_CX - bw / 2)
    local bh = 22 * U
    if bp < 1 then
        UI.frame(bx, by, bw, UI.grid(bh * bp), { fill = fill, border = 2 * U, shadow = 2 * U })
        return
    end
    UI.frame(bx, by, bw, bh, { fill = fill, border = 2 * U, shadow = 2 * U })
    UI.draw_text(UI.text_key(key, 48, st), CB_CX, by + bh / 2, "c")
end

function ResultPlayer:draw_stage(s)
    local cheer = s and s >= T_CHEER
    if self.big and s then
        local n, gap, period = self:fw_plan()
        FX.show(self.fw, s, T_CHEER, self.timing and FW_SIDE or FW_SLOTS, n, gap, period)
        self:draw_sky_crown(s)
    end
    -- the party loop: a passing mascot alternates cheer / clear every 500 ms (hop on each cheer)
    local party = (s and self.passed) and (s - T_PARTY) or -1
    if self.momo then
        local fail_t = (s and not self.passed) and (s - T_PARTY) or -1
        if fail_t >= 0 then   -- fail: Hoshi keeps facing Momo and steps in place once a second
            local beat = math.floor(fail_t / 1000)
            if self.hoshi._party_beat ~= beat then self.hoshi._party_beat = beat; self.hoshi:hop() end
        end
        self.momo:draw(MOMO_X, 927, { expr = party >= 0 and FX.party(self.momo, party, false) or nil })
        self.hoshi:draw(HOSHI_X, 927, { expr = party >= 0 and FX.party(self.hoshi, party, true) or nil })
        if cheer and self.passed then UI.burst(MOMO_X, 600, s - T_CHEER) end
    else
        local x = self.is_2p and 1716 or 204
        self.own:draw(x, 900, { expr = party >= 0 and FX.party(self.own, party, self.is_2p) or nil })
        if cheer and self.passed then UI.burst(x, 600, s - T_CHEER) end
    end
    -- the speaker's bubble opens in 3 frames once the mascots react
    if cheer then
        local b = self.bub
        local bp = open_p(s - T_CHEER - 100)
        if bp >= 1 then
            UI.bubble(b.key, b.tx, b.ty, { size = 24, h = DEF.bubble_h, cx = b.x + b.w / 2 })
        elseif bp > 0 then
            UI.frame(b.x, b.y, b.w, UI.grid(DEF.bubble_h * bp), { border = 2 * U, shadow = 2 * U })
        end
    end
end

-- soul gauge: 50 cells of 15 (12 fill + 3 groove), norma tick, クリア chip, soul disc
function ResultPlayer:draw_gauge()
    if open_p(tex.get_current_ms() - self.t0) < 1 then return end
    local o = self.off
    local x0, y0 = GX0 + o, GY0
    UI.rect(x0, y0, G_CELLS * G_CELL + 2 * U, GH, P.ink)
    UI.rect(x0 + U, y0 + U, G_CELLS * G_CELL, GH - 2 * U, P.bg3)
    local cp = self.clear_pt
    UI.rect(x0 + U + (cp - 1) * G_CELL, y0 + U, (G_CELLS - cp + 1) * G_CELL, GH - 2 * U, P.line)
    local shown = self.gauge_shown
    local full = self.gauge_state == 2 and shown >= G_CELLS
    for i = 0, shown - 1 do
        local c
        if full then c = RAINBOW[math.floor(i * 6 / G_CELLS) + 1]
        elseif i >= cp - 1 then c = P.clear
        else c = self.pcol end
        UI.rect(x0 + U + i * G_CELL, y0 + U, G_CELL - U, GH - 2 * U, c)
    end
    -- norma tick (1U ink, 1U past the frame) and its chip
    local tx = x0 + U + (cp - 1) * G_CELL - U
    UI.rect(tx, y0 - U, U, GH + 2 * U, P.ink)
    local lit = self.gauge_state >= 1 and shown >= cp - 1
    chip("clear", tx, y0 - W.CH, nil, lit and P.clear or P.bg3, false)
    local sx = x0 + G_CELLS * G_CELL + 2 * U + 4 * U
    soul_cap(self.t_soul, full and 2 or (lit and 1 or 0), sx, y0 - U)
    -- events: the fill reaching the norma, the gauge maxing out (one burst each)
    local now = tex.get_current_ms()
    if self.clear_hit then UI.burst(tx + 6 * U, y0 - W.CH + 13, now - self.clear_hit) end
    if self.full_hit then UI.burst(sx + 24, y0 - U + 24, now - self.full_hit) end
end

function ResultPlayer:chara_pos() return { -4000, -4000, 1.0 } end

function ResultPlayer:nameplate_pos()
    return { self.is_2p and 1509 or 2, 922 }
end

-- song number chip (top right) and title / subtitle over the sky: paper text, 1U ink outline (UI.text)

function ResultPlayer:draw_song_info(inf)
    local fmt = tex.skin_text("song_num")
    if fmt == "" then fmt = "{0}" end
    local num = UI.text((fmt:gsub("{0}", tostring(inf.number))), 24, "ink")
    if not num then return end
    local limit = tex.song_limit()
    local w = UI.grid(num.width) + 9 * U
    local cx = 1893 - w
    local last = limit > 0 and limit == inf.number
    UI.chrome.chip(cx, 24, w, 36, last and P.don or P.paper, false)
    num:draw({ x = UI.px(cx + (w - num.width) / 2), y = UI.px(42 - num.height / 2) })

    local title = UI.text(inf.title, 48, "paper")
    if not title then return end
    local tw = math.min(title.width, 1530)
    title:draw({ x = UI.px(960 - tw / 2), y = UI.px(78 - title.height / 2), x2 = tw - title.width })
    if inf.subtitle ~= "" and UI.text(inf.subtitle, 24, "paper") then
        local sub = UI.text(inf.subtitle, 24, "paper")
        local sw = math.min(sub.width, 1530)
        sub:draw({ x = UI.px(960 - sw / 2), y = UI.px(126 - sub.height / 2), x2 = sw - sub.width })
    end
end
