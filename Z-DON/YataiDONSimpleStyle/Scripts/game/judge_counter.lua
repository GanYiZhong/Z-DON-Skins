-- YataiDONSimpleStyle v2: the judge counter (engine JudgeCounter, judge_counter.h: new(), draw(good, ok,
-- bad, drumrolls)). The engine creates it in practice and, with the judge-counter setting, in 1P play.
--   GAME_PRACTICE: the stats panel in the left column under the header row (Nijiiro 1920 layout,
--                  replaces Green's x1.5 geometry): 精度 big, 良 / 可 / 不可 count + share, 連打.
--   other screens: nothing drawn (1P play has the live record panel, game/ss_play.lua, which uses these
--                  exact counts when they exist).
-- Chrome, labels and digits come from global.ss_ui (no letter-spaced cell digits).

local UI = require("global.ss_ui")
local Play = require("game/ss_play")
local P = UI.P
local U = UI.U

JudgeCounter = {}
JudgeCounter.__index = JudgeCounter

local X, Y, W = 6, 591, 486        -- panel (left column under the 曲テンポ / 小節 row)
local ROW = 22 * U                 -- 66
local TOP = 30 * U                 -- 90: the 精度 row
-- the practice stage (ss/v2_game.py PR_*): drum stations at x 880 / 1540, faces from y 612; the
-- progress bar row at y 546 (27 high). Both are engine textures drawn after this panel.
local STATIONS = { 880, 1540 }
local CHIP_Y = 576                 -- a tab hanging from the bar frame; 2U clear of the face top (609)
local BAR = { x = 501, y = 546, w = 1335, h = 27 }

function JudgeCounter.new()
    local self = setmetatable({}, JudgeCounter)
    self.practice = string.upper(tostring(tex.current_screen() or "")) == "GAME_PRACTICE"
    if self.practice then
        self.pn = (tex.player_num and tex.player_num() == 2) and 2 or 1
        self.pn_text = UI.text(self.pn .. "P", 18, "ink")
        local i = tex.get_texture_info("practice", "progress_bar_bg")
        if i and i.x and i.x[1] then
            self.bar = { x = i.x[1], y = i.y[1], w = (i.x2[1] or 0) > 0 and i.x2[1] or i.width,
                         h = (i.y2[1] or 0) > 0 and i.y2[1] or i.height }
        else
            self.bar = BAR
        end
    end
    return self
end

-- under the engine's practice textures: the progress bar's ink frame (1U + hard shadow; the bar and
-- its fill draw inside it) and the player's chip over the player's drum station (the station whose
-- cards are さいかい / もどる / すすむ when paused; the other one holds 一時停止 / メニュー)
function JudgeCounter:draw_stage()
    local b = self.bar
    UI.frame(b.x - U, b.y - U, b.w + 2 * U, b.h + 2 * U, { fill = P.bg3, border = U, shadow = U, notch = 0 })
    local t = self.pn_text
    local tw = t and t.width or 2 * U
    local cw = math.ceil((tw + 8 * U) / U) * U
    local cx = STATIONS[self.pn]
    local x = UI.grid(cx - cw / 2)
    local ix, iy, iw, ih = UI.chrome.chip(x, CHIP_Y, cw, 10 * U, self.pn == 2 and P.p2 or P.p1, false)
    UI.draw_text(t, ix + iw / 2, iy + ih / 2, "c")
end

local function pct(v, total)
    return tostring(math.floor(v / total * 100 + 0.5)) .. "%"
end

function JudgeCounter:draw(good, ok, bad, drumrolls)
    good, ok, bad, drumrolls = good or 0, ok or 0, bad or 0, drumrolls or 0
    Play.exact = { good = good, ok = ok, bad = bad, roll = drumrolls }
    if not self.practice then return end
    self:draw_stage()
    local total = good + ok + bad
    local t1 = math.max(total, 1)
    local h = TOP + 4 * ROW + 9 * U
    local ix, iy, iw, ih = UI.chrome.panel(X, Y, W, h, P.paper)
    local vx = ix + iw - 4 * U          -- the share column's right edge
    local cx_col = ix + 66 * U          -- the count column's right edge

    local function chip(key, accent, y0)
        local lw = UI.label_width(key, 18)       -- the label in the player's language (run-time text)
        if lw <= 0 then lw = (UI.D.LABEL[key] and UI.D.LABEL[key].w) or 54 end
        local cw = math.ceil((lw + 6 * U) / U) * U
        local cx, cy, _, ch = UI.chrome.chip(ix + 3 * U, y0, cw, 10 * U, accent, true)
        UI.label(key, cx + 2 * U, cy + ch / 2, P.ink, 255, "l")
        return cy + ch / 2
    end

    -- 精度 (良 + 可 share): the big number, with a 10-segment meter under it
    local acc = (good + ok) / t1
    local cy = chip("acc", P.clear, iy + 3 * U)
    UI.num(pct(good + ok, t1), vx, iy + 12 * U, "xl", P.ink, 255, "r")
    UI.pixbar(ix + 3 * U, iy + 21 * U, iw - 6 * U, 6 * U, acc, P.clear, 10)
    UI.rect(ix, iy + TOP - U, iw, U, P.line)

    local rows = {
        { "good", P.clear, good, true },
        { "ok", P.line, ok, true },
        { "bad", P.bad, bad, true },
        { "roll", P.roll, drumrolls, false },
    }
    for k, r in ipairs(rows) do
        local y0 = iy + TOP + (k - 1) * ROW + 6 * U
        cy = chip(r[1], r[2], y0)
        UI.num(tostring(r[3]), cx_col, cy, "l", P.ink, 255, "r")
        if r[4] then UI.num(pct(r[3], t1), vx, cy, "m", P.text2 or P.ink, 255, "r") end
    end
    self:draw_loop()
end

-- Z-DON section loop (tex.practice_loop, src/scenes/game_practice.cpp): a sky panel over the lane's middle:
-- "区段循环  第N轮  小节 A-B", then the last finished pass's 良 / 可 / 不可. Upstream engines: nothing.
local LOOP_CX, LOOP_Y1 = 960, 264      -- centred on the screen, bottom 4U above the lane (276)
function JudgeCounter:draw_loop()
    if not tex.practice_loop then return end
    local active, a, b, passes, lg, lo, lb = tex.practice_loop()
    if active == nil then return end
    local function n(v) return string.format("%d", math.floor((v or 0) + 0.5)) end
    local pass = (UI.t("pr_pass") or "%d"):gsub("%%d", n(passes + 1))
    local head = (UI.t("pr_loop") or "") .. "   " .. pass .. "   " .. (UI.t("pr_bar") or "") .. " " ..
                 n(a + 1) .. "-" .. n(b + 1)
    local th = UI.text(head, 24, "ink")
    local tl
    if lg then
        tl = UI.text((UI.t("pr_last") or "") .. "   " .. (UI.t("good") or "") .. " " .. n(lg) .. "   " ..
                     (UI.t("ok") or "") .. " " .. n(lo) .. "   " .. (UI.t("bad") or "") .. " " .. n(lb), 24, "ink")
    end
    local w = math.ceil((math.max(th.width, tl and tl.width or 0) + 12 * U) / U) * U
    local h = tl and 24 * U or 13 * U
    local ix, iy, iw, ih = UI.chrome.panel(UI.grid(LOOP_CX - w / 2), LOOP_Y1 - h, w, h,
                                           active and P.paper or P.bg3)
    UI.rect(ix, iy, 2 * U, ih, active and P.clear or P.line)
    UI.draw_text(th, ix + iw / 2 + U, iy + 6 * U, "c")
    if tl then UI.draw_text(tl, ix + iw / 2 + U, iy + 17 * U, "c") end
end
