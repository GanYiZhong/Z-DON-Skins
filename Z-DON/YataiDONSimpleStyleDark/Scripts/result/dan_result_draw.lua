-- YataiDONSimpleStyle v2: dan result (draw side only; the engine owns input, sounds and the page /
-- stamp / promotion timeline, exactly like Nijiiro's dan_result_draw.lua). Draws only
-- Graphics/dan_result/ss textures + core Lua chrome, on Nijiiro's geometry:
--   left column: dan plate (dan accent), the 合格 / 不合格 stamp, Momo on the floor line, nameplate
--   board 339..1860 x 90..1011: page 1 = one row panel per song, page 2 = score box, totals, exam rows
--   overlays: promotion (昇段) and congrats on the festival stage, Momo + Hoshi cheering
-- Motion is the bible's: rows / windows open in 3 frames (50 ms), the stamp drops in 3 frames with a
-- 1U settle, sparkle bursts only on the pass events. All coordinates LOGICAL (1920x1080).
local UI = require("global.ss_ui")
local W = require("result.ss_result_ui")    -- run-time word chrome (player's language)
local FX = require("result.ss_result_fx")   -- polish: fireworks, slam, landing ring, party loop
local P = UI.P
local U = UI.U

local FRAME_MS = 1000.0 / 60.0
local GAUGE_UNIT_MS = 3 * (1000.0 / 120.0)
local GAUGE_NUMIN_MS = 10 * FRAME_MS + 500.0


local SONG_X, SONG_Y0, SONG_PITCH, SONG_W, SONG_H = 381, 132, 276, 1437, 246
local EXAM_X, EXAM_Y0, EXAM_GAP, EXAM_W, EXAM_H = 393, 345, 13, 1413, 141
-- exam rows grow to fill the board (r3: 3 rows used to leave its bottom fifth empty): row height =
-- the board's free height split over the rows, between EXAM_H (4 rows) and EXAM_H_MAX; the content
-- keeps its top-row chip and centres the bar / value block in the extra height
local EXAM_BOTTOM, EXAM_H_MAX = 915, 201   -- 915: clear of the engine nameplate (x <= 425, y 930+)
local STAMP_XY = { 18, 321 }
local STAMP_W, STAMP_H = 300, 207            -- the stamp's own box (landing ring)
-- overlay (昇段 / congrats) fireworks: free sky left / right of the dialog (408..1512 x 150..450)
local OV_FW_SLOTS = { { 204, 186 }, { 1716, 168 }, { 297, 378 }, { 1620, 384 }, { 168, 300 }, { 1782, 291 } }
local FLOOR = 921
-- exam type -> label key (ss/strings.py)
local EXAM_KEY = { gauge = "dan_ex_gauge", judgeperfect = "dan_ex_good", judgegood = "dan_ex_ok",
                   judgebad = "dan_ex_bad", renda = "dan_ex_roll", score = "dan_ex_score", hit = "dan_ex_hit",
                   combo = "dan_ex_combo" }
local RAINBOW = { P.oni, P.easy, P.clear, P.normal, P.hard, P.ura }   -- core course.RAINBOW6 order

local function T(k) return tex.get_texture("dan_result/ss/" .. k) end

local function open_p(t)
    if t < 0 then return 0 end
    if t < 50 then return 1 / 3 end
    if t < 100 then return 2 / 3 end
    return 1
end

local function drop_dy(t)
    if t < 0 then return nil end
    if t < 50 then return -6 * U end
    if t < 100 then return -3 * U end
    if t < 150 then return U end
    return 0
end

local function exam_threshold_text(exam_type, range, num)
    local gauge = exam_type == "gauge"
    local less = range == "less"
    local key = gauge and (less and "dan_exam_text_gauge_less" or "dan_exam_text_gauge")
                       or (less and "dan_exam_text_less" or "dan_exam_text_more")
    local fmt = tex.skin_text(key):gsub("%%%%", "\1")
    if fmt == "" then fmt = UI.t(less and "dan_fmt_less" or "dan_fmt_more") or "%s" end
    local out = fmt:gsub("%%s", tostring(num)):gsub("\1", "%%")
    -- "70 ％以上" (engine / Nijiiro format: space + full-width ％) reads as a double space in the
    -- pixel font: the number and its percent sign belong together ("70%以上")
    out = out:gsub(" ?\239\188\133", "%%"):gsub(" %%", "%%")
    return out
end

-- block score digits (5x7 glyphs, 42 x 54 frames, pitch 36), right-aligned at `right`
local function block_num(t, str, right, y)
    if not t then return end
    local n = #str
    for i = 1, n do
        tex.draw_texture(t, { frame = tonumber(str:sub(i, i)) or 0, x = right - 42 - (n - i) * 36, y = y })
    end
end

DanResultDraw = {}
DanResultDraw.__index = DanResultDraw

function DanResultDraw.new(rd, prev_arrival, prev_best_score, best_score_show, gauge_exam, gauge_value, gauge_border)
    local self = setmetatable({}, DanResultDraw)
    UI.reset()
    self.rd = rd
    self.prev_arrival = prev_arrival
    self.prev_best_score = prev_best_score
    self.best_score_show = best_score_show
    self.gauge_exam = gauge_exam
    self.gauge_value = gauge_value
    self.gauge_border = gauge_border
    self.celebrating, self.congrats_showing = false, false

    -- stamp / gokaku resolve to the per-language sheets (stamp_<lang>, gokaku_<lang>)
    for _, k in ipairs({ "board", "plate", "song_row", "scorebox", "score_digit", "totals", "exam_row",
                         "stamp", "soul", "stage", "dialog", "gokaku" }) do
        self["t_" .. k] = T(k)
    end
    self.fw = FX.textures("dan_result/ss")

    local r = rd.odai_result
    if r > 0 then
        self.stamp_frame = (r >= 4 and 3 or 0) + ((r - 1) % 3)
        self.passed = true
    elseif r == 0 then
        self.stamp_frame = 6
    else
        local any_failed = false
        for _, ed in ipairs(rd.exam_data) do if ed.failed then any_failed = true end end
        self.stamp_frame = any_failed and 6 or 0
        self.passed = not any_failed
    end

    -- engine text: paper with a 1U ink outline (titles), ink (small values on paper)
    self.title = UI.text(rd.dan_title, 48, "ink")      -- ink on the plate's paper (no outline)
    self.title_big = UI.text(rd.dan_title, 48, "ink")
    self.song_names = {}
    for i, song in ipairs(rd.songs) do
        local t = song.song_title
        if song.hidden and song.unreached and prev_arrival < i then t = "？？？？？？" end
        self.song_names[i] = UI.text(t, 36, "paper")
    end
    self.caps = {}
    local n = math.max(1, #rd.exams)
    local h = math.floor((EXAM_BOTTOM - EXAM_Y0 - (n - 1) * EXAM_GAP) / n / U) * U
    self.exam_h = math.max(EXAM_H, math.min(EXAM_H_MAX, h))
    self.exam_dy = math.floor((self.exam_h - EXAM_H) / 2 / U) * U
    self.momo = UI.Mascot.new({ char = "momo", role = "scene", beat = false })
    self.hoshi = UI.Mascot.new({ char = "hoshi", role = "scene", beat = false })
    return self
end

function DanResultDraw:caption(s, size)
    local c = self.caps[s .. size]
    if not c then
        c = UI.text(s, size, "ink")
        self.caps[s .. size] = c
    end
    return c
end

-- ---------------------------------------------------------------- left column
function DanResultDraw:draw_left(now)
    if self.t_plate then tex.draw_texture(self.t_plate, { x = 39, y = 57 }) end
    UI.draw_text(UI.text_key("dan_dojo", 36, "ink"), 177, 84, "c")    -- in the plate's dan band
    local t = self.title
    if t then
        local w = math.min(t.width, 246)
        t:draw({ x = UI.px(177 - w / 2), y = UI.px(195 - t.height / 2), x2 = w - t.width })
    end
end

-- ---------------------------------------------------------------- page 1: song rows
function DanResultDraw:draw_page1(now)
    local on_page = now - self.page1_start_ms
    for i, song in ipairs(self.rd.songs) do
        local land = (i <= 3) and ({ 40, 65, 90 })[i] * FRAME_MS or (90 + (i - 3) * 25) * FRAME_MS
        local y = SONG_Y0 + (i - 1) * SONG_PITCH
        local p = open_p(on_page - land)
        if p > 0 and i <= 3 then
            if p < 1 then
                UI.frame(SONG_X, y, SONG_W, UI.grid(SONG_H * p), {})
            else
                tex.draw_texture(self.t_song_row, { x = SONG_X, y = y })
                local pw = W.plate(UI.t("dan_song_" .. i) or tostring(i), SONG_X - U, y - U, P.dan)
                local cx = SONG_X + pw + 6 * U
                local c = math.min(math.max(song.selected_difficulty, 0), 4)
                local cw = UI.label_width("course" .. c, 18, "ink")
                cw = math.max(126, math.ceil((cw + 10 * U) / U) * U)
                local ix, iy, iw, ih = UI.chrome.chip(cx, y + 4 * U, cw, W.CH, UI.course.color(c), true)
                UI.draw_text(UI.text(UI.course.name(c), 18, "ink"), ix + iw / 2, iy + ih / 2, "c")
                local lx = cx + cw + 4 * U
                UI.label("level", lx, y + 4 * U + W.CH / 2, P.gold_t, 255, "l")
                UI.num(tostring(song.diff_level), lx + 21, y + 4 * U + W.CH / 2, "m", P.ink, 255, "l")
                local nm = self.song_names[i]
                if nm then
                    local w = math.min(nm.width, SONG_W - 48)
                    nm:draw({ x = UI.px(SONG_X + 8 * U), y = UI.px(y + 99 - nm.height / 2), x2 = w - nm.width })
                end
                local JK = { { "good", P.good }, { "ok", P.ok }, { "bad", P.bad }, { "dan_ex_roll", P.roll } }
                for k, jk in ipairs(JK) do
                    W.chip(jk[1], SONG_X + 135 + (k - 1) * 317, y + 180, 120, jk[2], true)
                end
                if song.unreached then
                    W.chip("dan_unreached", SONG_X + 135 + 317 + 140, y + 180, nil, P.bg3, false)
                else
                    local vals = { song.good, song.ok, song.bad, song.drumroll }
                    for k = 1, 4 do
                        UI.num(tostring(vals[k]), SONG_X + 135 + (k - 1) * 317 + 288, y + 195, "l", P.ink, 255, "r")
                    end
                end
            end
        end
    end
end

-- ---------------------------------------------------------------- page 2
function DanResultDraw:draw_gauge_row(rx, ry, on_page)
    local cur = self.gauge_value
    local landed = true
    if not self.page2_skipped and on_page < self.totals_start + self.gauge_value * GAUGE_UNIT_MS then
        cur = math.min(self.gauge_value, math.max(0, (on_page - self.totals_start) / GAUGE_UNIT_MS))
        landed = false
    end
    local CELL, N = 18, 50
    local gx, gy, gh = rx + 390, ry + 45, 51
    local norma = math.floor(self.gauge_border / 2)
    local cells = math.floor(cur / 2)
    local clear = cur >= self.gauge_border and self.gauge_border > 0
    local full = landed and self.gauge_value >= 100
    UI.rect(gx, gy, N * CELL + 2 * U, gh, P.ink)
    UI.rect(gx + U, gy + U, N * CELL, gh - 2 * U, P.bg3)
    if norma > 0 then UI.rect(gx + U + norma * CELL, gy + U, (N - norma) * CELL, gh - 2 * U, P.line) end
    for i = 0, cells - 1 do
        local c = full and RAINBOW[math.floor(i * 6 / N) + 1] or (i >= norma and P.clear or P.p1)
        UI.rect(gx + U + i * CELL, gy + U, CELL - U, gh - 2 * U, c)
    end
    UI.rect(gx + U + norma * CELL - U, gy - U, U, gh + 2 * U, P.ink)
    W.soul_cap(self.t_soul, full and 2 or ((clear and landed) and 1 or 0), gx + N * CELL + 2 * U + 4 * U, gy + 1)
    local numin = self.page2_skipped or
        on_page >= self.totals_start + self.gauge_value * GAUGE_UNIT_MS + (GAUGE_NUMIN_MS - 500.0)
    if numin then
        UI.num(tostring(self.gauge_value) .. "%", rx + 18, ry + 102, "xl", full and P.gold_t or P.ink, 255, "l")
    end
end

local function fill_col(state)
    if state == "up_50" then return P.p1 end
    if state == "failed" then return P.mute end
    return P.clear
end

function DanResultDraw:draw_bar(x, y, w, h, frac, state)
    UI.rect(x, y, w, h, P.ink)
    UI.rect(x + U, y + U, w - 2 * U, h - 2 * U, P.bg3)
    local fw = math.floor((w - 2 * U) * math.max(0, math.min(1, frac)) / U) * U
    if fw > 0 and state ~= "empty" then
        UI.rect(x + U, y + U, fw, h - 2 * U, fill_col(state))
        if state == "max" then UI.rect(x + U, y + U, fw, U, P.paper) end
    end
end

function DanResultDraw:draw_exams(on_page)
    local rd = self.rd
    for i, exam in ipairs(rd.exams) do
        local ed = rd.exam_data[i]
        local row = self.rows[i] or { land = 0, fill0 = 0, filld = 0, numin = 0 }
        if ed and on_page >= row.land then
            local ry0 = EXAM_Y0 + (i - 1) * (self.exam_h + EXAM_GAP)
            local rx = EXAM_X
            local p = open_p(on_page - row.land)
            if p < 1 and not self.page2_skipped then
                UI.frame(rx, ry0, EXAM_W, UI.grid(self.exam_h * p), {})
            else
                UI.chrome.panel(rx, ry0, EXAM_W, self.exam_h)
                W.chip(EXAM_KEY[exam.type] or "dan_ex_score", rx + 6 * U, ry0 + 5 * U, nil, P.dan, false)
                local ry = ry0 + self.exam_dy      -- the bar / value block, centred in the taller row
                local frac = 1.0
                if not self.page2_skipped and row.filld > 0 then
                    frac = math.max(0.0, math.min(1.0, (on_page - row.fill0) / row.filld))
                end
                local numin = self.page2_skipped or on_page >= row.numin
                local gauge_row = (i - 1 == self.gauge_exam)
                local cap = self:caption(exam_threshold_text(exam.type, exam.range, exam.red), 24)
                if gauge_row then
                    self:draw_gauge_row(rx, ry, on_page)
                    cap:draw({ x = UI.px(rx + 372 - cap.width), y = UI.px(ry0 + 5 * U + W.CH / 2 - cap.height / 2) })
                elseif exam.gothrough then
                    local pr = ed.progress
                    if exam.range == "less" then pr = 1.0 - (1.0 - pr) * frac else pr = pr * frac end
                    local st = ed.failed and "failed" or ed.bar_state
                    if frac < 1.0 then
                        local g = math.floor(pr * 100)
                        st = g <= 0 and "empty" or g <= 49 and "up_50" or g <= 99 and "up_80" or "up_100"
                    end
                    self:draw_bar(rx + 390, ry + 45, 1005, 51, pr, st)
                    cap:draw({ x = UI.px(rx + 372 - cap.width), y = UI.px(ry + 102 - cap.height / 2) })
                    if numin then
                        -- "less than" exams count down (counter_value = red - count): 还剩 N, as in play
                        local nx = rx + 18
                        if exam.range == "less" then
                            nx = nx + UI.draw_text(UI.text_key("balloon_left", 24, "ink"), nx, ry + 102, "l") + 3 * U
                        end
                        UI.num(tostring(ed.counter_value), nx, ry + 102, "xl",
                            ed.bar_state == "max" and P.gold_t or P.ink, 255, "l")
                        if ed.failed then
                            W.chip("dan_failed", rx + 390 + 420, ry + 57, nil, P.bad, false, "paper")
                        end
                    end
                else
                    local reach = 0
                    for _, s in ipairs(rd.songs) do if not s.unreached then reach = reach + 1 end end
                    if reach <= 0 then reach = math.max(1, ed.song_count + 1) end
                    reach = math.min(reach, 3)
                    for j = 1, reach do
                        local sx = rx + 390 + (j - 1) * 336
                        W.chip("dan_song_" .. j, sx, ry + 4 * U, nil, P.bg3, false)
                        local sp = ed.song_progress[j]
                        if exam.range == "less" then sp = 1.0 - (1.0 - sp) * frac else sp = sp * frac end
                        local sst = ed.song_state[j]
                        if frac < 1.0 then
                            local g = math.floor(sp * 100)
                            sst = g <= 0 and "empty" or g <= 49 and "up_50" or g <= 99 and "up_80" or "up_100"
                        end
                        self:draw_bar(sx, ry + 48, 318, 39, sp, sst)
                        local red = (#exam.song_red > 0) and exam.song_red[j] or exam.red
                        local sc = self:caption(exam_threshold_text(exam.type, exam.range, red), 18)
                        sc:draw({ x = UI.px(sx + 318 - sc.width), y = UI.px(ry + 111 - sc.height / 2) })
                        if numin then UI.num(tostring(ed.song_value[j]), sx, ry + 111, "l", P.ink, 255, "l") end
                    end
                    cap:draw({ x = UI.px(rx + 372 - cap.width), y = UI.px(ry + 102 - cap.height / 2) })
                end
            end
        end
    end
end

function DanResultDraw:draw_page2(now)
    local rd = self.rd
    local on_page = now - self.page_start_ms
    if not self.p2_t0 then self.p2_t0 = now end
    local p = open_p(now - self.p2_t0)
    if p < 1 then
        UI.frame(381, 120, 1437, UI.grid(870 * p), {})
        return
    end
    tex.draw_texture(self.t_scorebox, { x = 459, y = 135 })
    W.chip("score", 459 + 3 * U, 135 + 3 * U, nil, P.paper, false)
    tex.draw_texture(self.t_totals, { x = 933, y = 135 })
    local TK = { { { "good", P.good }, { "ok", P.ok }, { "bad", P.bad } },
                 { { "dan_ex_roll", P.roll }, { "dan_ex_combo", P.clear }, { "dan_ex_hit", P.dan } } }
    for c = 1, 2 do
        for r = 1, 3 do
            local it = TK[c][r]
            W.chip(it[1], 933 + 18 + (c - 1) * 432, 135 + 18 + (r - 1) * 54 + 3, 150, it[2], true)
        end
    end

    local tg, tok, tb, tdr = 0, 0, 0, 0
    for _, s in ipairs(rd.songs) do
        tg = tg + s.good; tok = tok + s.ok; tb = tb + s.bad; tdr = tdr + s.drumroll
    end
    local landed = self.page2_skipped or on_page >= self.totals_end
    if landed or on_page >= self.totals_start then
        local k = 1
        if not landed then
            local d = math.max(1, self.totals_end - self.totals_start)
            k = math.floor(12 * (on_page - self.totals_start) / d) / 12
        end
        local function v(n) return tostring(math.floor(n * k)) end
        local cols = { { tg, tok, tb }, { tdr, rd.max_combo, tg + tok + tb + tdr } }
        for c = 1, 2 do
            for r = 1, 3 do
                UI.num(v(cols[c][r]), 933 + 18 + (c - 1) * 432 + 396, 135 + 18 + (r - 1) * 54 + 18, "l", P.ink, 255, "r")
            end
        end
        block_num(self.t_score_digit, v(rd.score), 459 + 441 - 15, 189)
        if self.best_score_show and landed then
            local bw = W.best_banner(459, 300)
            UI.num("+" .. tostring(rd.score - self.prev_best_score), 459 + bw - 6, 300 + W.CH / 2, "s", P.ink, 255, "r")
        end
    end

    self:draw_exams(on_page)

    -- the stamp: 3-frame drop with a 1U settle, a burst on a pass; Momo reacts as it lands
    local st = on_page - self.stamp_at
    local dy = FX.slam(st, 24 * U)
    if dy and self.t_stamp then
        tex.draw_texture(self.t_stamp, { frame = self.stamp_frame, x = STAMP_XY[1], y = STAMP_XY[2] + dy })
        -- frames 1 / 4 = full combo, 2 / 5 = 全良: the gold chip under the stamp (gold, ink text)
        local v = (self.stamp_frame < 6) and (self.stamp_frame % 3) or 0
        if v > 0 then
            local key = v == 1 and "full_combo" or "zenryo"
            local w = W.chip_w(key)
            W.chip(key, STAMP_XY[1] + UI.grid((306 - w) / 2), STAMP_XY[2] + dy + 228, nil, P.clear, false)
        end
        FX.ring(STAMP_XY[1], STAMP_XY[2], STAMP_W, STAMP_H, st - 150, self.passed and P.clear or P.ink)
        if self.passed then
            UI.burst(STAMP_XY[1] + 150, STAMP_XY[2] + 30, st - 150)
            UI.burst(STAMP_XY[1] + 18, STAMP_XY[2] + STAMP_H - 18, st - 216)
            UI.burst(STAMP_XY[1] + STAMP_W - 18, STAMP_H + STAMP_XY[2] - 18, st - 283)
        end
        if st >= 150 and not self.reacted then
            self.reacted = true
            if self.passed then
                self.momo:flash("cheer", 600); self.momo:hop(); self.momo:set_mood("clear")
                self.hop2 = now + 250
                self.party_at = now + 900
            else
                self.momo:react("fail")
            end
        end
    end
    if self.hop2 and now >= self.hop2 then self.hop2 = nil; self.momo:hop() end
end

-- ---------------------------------------------------------------- overlays
function DanResultDraw:draw_overlay_scene(now, t0, title_key, body)
    local t = now - t0
    if self.t_stage then tex.draw_texture(self.t_stage, {}) end
    -- fireworks over the stage sky from the cheer: a salvo of 6, then one every 900 ms
    FX.show(self.fw, t, 600, OV_FW_SLOTS, 6, 200, 900)
    local p = open_p(t)
    local dx, dy, dw, dh = 408, 150, 1104, 300
    if p < 1 then
        UI.frame(dx, dy, dw, UI.grid(dh * p), { border = 2 * U, shadow = 2 * U })
    elseif self.t_dialog then
        tex.draw_texture(self.t_dialog, { x = dx, y = dy })
        -- the title in the dialog's gold band (2U border + 16U band: centre y dy + 6 + 24)
        UI.draw_text(UI.text_key(title_key, 36, "ink"), dx + dw / 2, dy + 2 * U + 8 * U, "c")
        local tt = self.title_big
        if tt then tt:draw({ x = UI.px(960 - tt.width / 2), y = UI.px(258 - tt.height / 2) }) end
        if body then body(t) end
    end
    -- the pair cheers on the stage floor
    if self.ov_t0 ~= t0 then
        self.ov_t0 = t0
        self.ov_cheer = nil
        self.momo:react("reset"); self.momo:set_mood(nil)
    end
    if t >= 600 and not self.ov_cheer then
        self.ov_cheer = true
        self.momo:flash("cheer", 800); self.momo:hop()
        self.hoshi:flash("cheer", 800); self.hoshi:hop()
        self.ov_hop2 = now + 250
    end
    if self.ov_hop2 and now >= self.ov_hop2 then self.ov_hop2 = nil; self.momo:hop(); self.hoshi:hop() end
    local pt = t - 1500
    self.momo:draw(570, 909, { expr = pt >= 0 and FX.party(self.momo, pt, false) or nil })
    self.hoshi:draw(1350, 909, { expr = pt >= 0 and FX.party(self.hoshi, pt, true) or nil })
    UI.burst(570, 570, t - 600)
    UI.burst(1350, 570, t - 666)
end

function DanResultDraw:draw_celebration(now)
    self:draw_overlay_scene(now, self.celebrate_start_ms, "dan_promo", function(t)
        local dy = drop_dy(t - 500)
        if dy and self.t_gokaku then
            tex.draw_texture(self.t_gokaku, { x = 795, y = 297 + dy })
            UI.burst(960, 360, t - 650)
        end
    end)
end

function DanResultDraw:draw_congrats(now)
    self:draw_overlay_scene(now, self.congrats_start_ms, "dan_congrats", function(t)
        local c = UI.text_key("dan_top", 36, "ink")
        c:draw({ x = UI.px(960 - c.width / 2), y = UI.px(360 - c.height / 2) })
    end)
end

function DanResultDraw:draw_nosave()
    if not self.rd.skipped or self.congrats_showing or self.celebrating then return end
    -- bg3 panel (609 x 42, or wider for a long line), right edge fixed at 1860
    local t = UI.text_key("dan_nosave", 24, "ink")
    local w = math.max(609, math.ceil((UI.label_width("dan_nosave", 24, "ink") + 12 * U) / U) * U)
    UI.chrome.panel(1860 - w, 21, w, 42, P.bg3)
    UI.draw_text(t, 1860 - w / 2, 21 + 21, "c")
end

function DanResultDraw:draw(s)
    local now = s.now
    self.page_start_ms = s.page_start_ms
    self.page1_start_ms = s.page1_start_ms
    self.page2_skipped = s.page2_skipped
    self.totals_start = s.totals_start
    self.totals_end = s.totals_end
    self.rows = s.rows
    self.stamp_at = s.stamp_at
    self.celebrating = s.celebrating
    self.celebrate_start_ms = s.celebrate_start_ms
    self.congrats_showing = s.congrats_showing
    self.congrats_start_ms = s.congrats_start_ms
    self.momo:update(now)
    self.hoshi:update(now)

    if s.congrats_showing then
        self:draw_congrats(now)
    elseif s.celebrating then
        self:draw_celebration(now)
    else
        if self.t_board then tex.draw_texture(self.t_board, { x = 339, y = 90 }) end
        self:draw_left(now)
        if s.page2_fade > 0 then self:draw_page2(now) else self:draw_page1(now) end
        local pt = (self.party_at and not (s.congrats_showing or s.celebrating)) and (now - self.party_at) or -1
        self.momo:draw(177, FLOOR, { expr = pt >= 0 and FX.party(self.momo, pt, false) or nil })
    end
    self:draw_nosave()
    if s.fade_out > 0 then
        UI.wipe(UI.dither(s.fade_out), P.ink)   -- dither steps, no translucent dim
    end
end

-- the engine's 3D character never shows (our mascots stand in)
function DanResultDraw:chara_pos() return { -4000, -4000, 1.0 } end

function DanResultDraw:nameplate_pos()
    if self.congrats_showing or self.celebrating then return { 763.0, 921.0, 1.0 } end
    return nil
end
