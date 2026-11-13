-- YataiDONSimpleStyle v2: the dan exam HUD (engine DanGameLua: DanGameDraw.new(title), :draw(state)).
-- A compact layout that ends at y 852 (the stage module's dan strip and Hoshi's bubble live below):
--   exam rows (up to 3, gauge exams excluded: the gauge has its own callout) at x 120-1596,
--   each a panel: exam chip + threshold, a segmented meter with the live value, per-song mini meters;
--   the rank plate (or the course frame with the dan title) and the remaining-notes chip at the right.
-- Chrome is drawn with the shared rect chrome (UI.chrome / UI.pixbar); the plates are baked in
-- game/ss_dan (no words); every word is engine text in the player's language (ss/strings.py dan_*),
-- with its chip / stamp sized to it; numbers are the tabular pixel digits. Meters never scroll or
-- sweep (bible 2.3).

local UI = require("global.ss_ui")
local P = UI.P
local U = UI.U

DanGameDraw = {}
DanGameDraw.__index = DanGameDraw

local X0, X1 = 120, 1596
local Y0, ROW_H, PITCH = 558, 30 * U, 33 * U
local PLATE_X, PLATE_Y = 1620, 558
local BAR_X0 = 513

local STATE_COL = { up_50 = P.don, up_80 = P.clear, down_80 = P.gogo }
local RAINBOW = { P.oni, P.easy, P.clear, P.normal, P.hard, P.ura }

local function T(name) return tex.get_texture("game/ss_dan/" .. name) end

-- exam type -> label key; rank_<i> (engine dan_rank) -> rank key (ss/v2_game.py DAN_RANKS order)
local EXAM_KEYS = { gauge = "dan_ex_gauge", combo = "dan_ex_combo", hit = "dan_ex_hit", judgebad = "dan_ex_bad",
                    judgegood = "dan_ex_ok", judgeperfect = "dan_ex_good", score = "dan_ex_score",
                    renda = "dan_ex_roll" }
local RANK_KEYS = { "dan_kyu_5", "dan_kyu_4", "dan_kyu_3", "dan_kyu_2", "dan_kyu_1", "dan_shodan", "dan_2",
                    "dan_3", "dan_4", "dan_5", "dan_6", "dan_7", "dan_8", "dan_9", "dan_10", "dan_kuroto",
                    "dan_meijin", "dan_chojin", "dan_tatsujin", "dan_sousaku", "dan_gaiden", "dan_shokyu",
                    "dan_kyu_10", "dan_kyu_9", "dan_kyu_8", "dan_kyu_7", "dan_kyu_6" }
local BADGE_KEYS = { [0] = "dan_all_songs", "dan_song_1", "dan_song_2", "dan_song_3" }

local function ink_w(t) return t and (t.width - 2 * UI.text_pad(t)) or 0 end
local function up_u(v) return math.ceil(v / U) * U end

-- plate words (ss/v2_game.py dan_plate): 段位道場 centred in the cap, the rank / title in the chip
local CAP_CX, CAP_CY = 135, 24
local CHIP_CX, CHIP_CY, CHIP_IN = 138, 103.5, 204

-- the largest role size <= size whose ink fits max_w
local function fit_key(key, size, max_w, style)
    local sizes = { 48, 36, 24, 18 }
    local t
    for _, s in ipairs(sizes) do
        if s <= size then
            t = UI.text_key(key, s, style)
            if ink_w(t) <= max_w then return t end
        end
    end
    return t
end

function DanGameDraw.new(title)
    local self = setmetatable({}, DanGameDraw)
    UI.reset()
    self.t = {}
    self.title = UI.text(title, 36, "ink")   -- role 36 (engine 48), ink on the plate's bg3 rank chip
    return self
end

function DanGameDraw:tx(name)
    local t = self.t[name]
    if t == nil then
        t = T(name) or false
        self.t[name] = t
    end
    return t or nil
end

function DanGameDraw:img(name, x, y)
    local t = self:tx(name)
    if t then tex.draw_texture(t, { x = x, y = y }) end
    return t
end

local function info_w(self, name)
    local i = tex.get_texture_info("ss_dan", name)
    return i and i.width or 0, i and i.height or 0
end

-- a meter: ink frame, bg3 groove, the state fill (rainbow = 6 flat blocks), 10 ink segment dividers
local function meter(x, y, w, h, state, frac, failed)
    x, y = UI.grid(x), UI.grid(y)
    UI.rect(x, y, w, h, P.ink)
    local ix, iy, iw, ih = x + U, y + U, w - 2 * U, h - 2 * U
    UI.rect(ix, iy, iw, ih, P.bg3)
    frac = math.max(0, math.min(1, frac or 0))
    local fw = math.floor(iw * frac / U) * U
    if failed then
        UI.rect(ix, iy, iw, ih, P.line)
    elseif state == "max" then
        local bw = math.floor(iw / 6 / U) * U
        for k = 0, 5 do
            local bx = ix + k * bw
            UI.rect(bx, iy, (k == 5) and (ix + iw - bx) or bw, ih, RAINBOW[k + 1])
        end
    elseif state ~= "empty" and fw > 0 then
        UI.rect(ix, iy, fw, ih, STATE_COL[state] or P.clear)
    end
    for i = 1, 9 do
        UI.rect(ix + math.floor(iw * i / 10 / U + 0.5) * U, iy, U, ih, P.ink)
    end
end

function DanGameDraw:exam_row(info, y, song_index)
    local all = info.gothrough
    local ix, iy, iw, ih = UI.chrome.panel(X0, y, X1 - X0, ROW_H, P.paper)
    -- exam chip + the song badge + threshold
    local cx, cy, cw, ch = UI.chrome.chip(ix + 3 * U, iy + 3 * U, 108 * U, 12 * U, P.dan, true)
    local key = EXAM_KEYS[info.exam_type]
    if key then UI.draw_text(fit_key(key, 24, cw - 4 * U, "ink"), cx + 2 * U, cy + ch / 2, "l") end
    -- the song badge: a chip sized to its word (at least 30U), 18 px ink
    local bkey = BADGE_KEYS[all and 0 or (1 + math.min(song_index, 2))]
    local bt = UI.text_key(bkey, 18, "ink")
    local bw0 = math.max(30 * U, up_u(ink_w(bt) + 8 * U))
    local bx0, by0 = ix + 3 * U, iy + 17 * U
    UI.chrome.chip(bx0, by0, bw0, 10 * U, all and P.dan or P.bg3)
    UI.draw_text(bt, bx0 + bw0 / 2, by0 + 10 * U / 2, "c")
    local thr = tostring(info.red_value)
    local tx = math.max(ix + 36 * U, bx0 + bw0 + 3 * U)
    local ty = iy + 22 * U
    local w = UI.num(thr, tx, ty, "l", P.ink, 255, "l")
    tx = tx + w + U
    if info.exam_type == "gauge" then
        local pw = info_w(self, "pct")
        self:img("pct", tx, ty - 18)
        tx = tx + pw
    end
    UI.draw_text(UI.text_key(info.exam_range == "less" and "dan_less" or "dan_more", 24, "ink"), tx, ty, "l")

    -- the meter + live value
    local bx = BAR_X0
    local bw = all and (X1 - 3 * U - 54 * U - bx) or 600
    local by = iy + 6 * U
    meter(bx, by, bw, 18 * U, info.bar_state, info.progress, info.failed)
    local val = tostring(info.counter_value)
    local vx = bx + bw + 51 * U
    if info.failed then
        -- the failed stamp: a don-red dialog sized to the word, 48 px paper with the ink outline
        local ft = UI.text_key("dan_failed", 48, "paper")
        local fw, fh = up_u(ink_w(ft) + 16 * U), 26 * U
        local fx, fy = UI.grid(bx + bw / 2 - (fw + 2 * U) / 2), UI.grid(by + 9 * U - (fh + 2 * U) / 2)
        UI.frame(fx, fy, fw, fh, { fill = P.don, border = 2 * U, shadow = 2 * U })
        UI.draw_text(ft, fx + fw / 2, fy + fh / 2, "c")
    else
        local nw = UI.num(val, vx, by + 9 * U, "xl", P.ink, 255, "r")
        -- a "less than" exam counts DOWN (the engine's counter_value = red - count): label it 还剩 so
        -- "10" next to "10 未満" reads as the budget left, not as 10 misses
        if info.exam_range == "less" then
            UI.draw_text(UI.text_key("balloon_left", 24, "ink"), vx - nw - 3 * U, by + 9 * U, "r")
        end
    end

    -- per-song mini meters (songs reached so far)
    if not all then
        local sx = vx + 6 * U
        local sw = X1 - 6 * U - sx - 30 * U
        for j = 0, 2 do
            local sy = iy + 3 * U + j * 8 * U
            UI.num(tostring(j + 1), sx, sy + 3 * U, "s", (j < info.song_count) and P.ink or P.mute, 255, "l")
            if j < info.song_count then
                meter(sx + 6 * U, sy, sw, 6 * U, info.song_state[j + 1], info.song_progress[j + 1], false)
                UI.num(tostring(info.song_value[j + 1]), X1 - 6 * U, sy + 3 * U, "s", P.ink, 255, "r")
            else
                UI.rect(sx + 6 * U, sy + 3 * U, sw, U, P.line)
            end
        end
    end
end

function DanGameDraw:draw(s)
    local slot = 0
    for _, info in ipairs(s.rows) do
        if info.exam_type ~= "gauge" then
            if slot >= 3 then break end
            self:exam_row(info, Y0 + slot * PITCH, s.song_index)
            slot = slot + 1
        end
    end
    -- the plate: rank art, or the course colour with the dan title (engine text, ink outline)
    local rank_key = s.dan_rank and s.dan_rank >= 0 and RANK_KEYS[s.dan_rank + 1]
    if rank_key then
        self:img("rank_" .. s.dan_rank, PLATE_X, PLATE_Y)
        UI.draw_text(fit_key(rank_key, 48, CHIP_IN, "ink"), PLATE_X + CHIP_CX, PLATE_Y + CHIP_CY, "c")
    else
        self:img("frame_" .. math.max(0, math.min(6, s.dan_color or 0)), PLATE_X, PLATE_Y)
        local h = self.title
        if h then
            local maxw = 210
            local x2 = math.min(h.width, maxw) - h.width
            h:draw({ x = PLATE_X + 135 - math.min(h.width, maxw) / 2, y = PLATE_Y + 105 - h.height / 2, x2 = x2 })
        end
    end
    UI.draw_text(fit_key("dan_dojo", 24, 246, "ink"), PLATE_X + CAP_CX, PLATE_Y + CAP_CY, "c")
    -- remaining notes chip under the plate
    local rx, ry = PLATE_X, PLATE_Y + 57 * U
    local ix, iy, iw, ih = UI.chrome.chip(rx, ry, 90 * U, 18 * U, P.bg3, true)
    UI.draw_text(fit_key("dan_notes_left", 18, iw - 2 * U, "ink"), ix + U, iy + 6 * U, "l")
    UI.num(tostring(s.remaining_notes or 0), ix + iw - 2 * U, iy + ih - 6 * U, "l", P.ink, 255, "r")
end
