-- YataiDONSimpleStyle v2: the score on the lane cover, the add-score popup, and the player portrait.
-- The engine's ScoreCounter (score_counter.h) calls update every frame with the player's score and
-- add_popup whenever points are earned. Interface kept from Nijiiro's script.
--
-- Score: tabular pixel digits (UI.num xl, 48 px ink) right-aligned in the score panel.
-- Popup (bible 2.7): "+300" in 24 px ink on a paper chip, rising 2U over 3 frames, holding 300 ms,
-- then gone (no fade, no float). The newest popup replaces the previous one.
-- Hits (add_popup) also drive the portrait mascot (game/ss_play.lua).

local UI = require("global.ss_ui")
local AI = require("global.ss_ai")
local Play = require("game/ss_play")
local P = UI.P
local U = UI.U

ScoreCounter = {}
ScoreCounter.__index = ScoreCounter

local SCORE_RIGHT = 285        -- right edge of the digits (screen x)
local SCORE_CY = 38            -- digit centre below the lane top (score panel 12..60)
local POP_STEP_MS = 50         -- one rise step per 50 ms (3 frames at 60 fps)
local POP_HOLD_MS = 300

-- the song title band (ss/v2_game.py TITLE_*): the engine draws the title (white, outline 0) right-
-- aligned at x 1854, centre y 54, squeezed to 840 px at most; this ink band sits behind it.
-- The band is sized to the title as the ENGINE draws it (song_info.cpp: OutlinedText at the skin's
-- font size with the default 2 px letter spacing, which UI.text does not use), plus 2U slack and 4U
-- padding a side, and right-anchored on the same edge as the text.
local TITLE_RIGHT, TITLE_CY, TITLE_MAX = 1854, 54, 840
local BAND_H = 22 * U
local BAND_PAD, BAND_SLACK = 4 * U, 2 * U
local TITLE_ENGINE_SIZE = UI.D.TEXT_ENGINE[36]
local measured = {}

local function title_width(str)
    if str == nil or str == "" then return nil end
    local w = measured[str]
    if w == nil then
        local t = text.create_raw_text(str, TITLE_ENGINE_SIZE, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 0)
        w = (t and t.width and t.width > 0) and t.width or false
        measured[str] = w
    end
    return w or nil
end

local function band_width(str)
    local w = math.min(TITLE_MAX, title_width(str) or TITLE_MAX)
    return math.ceil((w + BAND_SLACK + 2 * BAND_PAD) / U) * U
end

function ScoreCounter.new(is_2p, player_num)
    local self = setmetatable({}, ScoreCounter)
    self.is_2p = is_2p
    self.player_num = player_num
    self.score = 0
    self.shown = 0
    self.t_cover = tex.get_texture("lane/lane_score_cover")
    self.cover_info = tex.get_texture_info("lane", "lane_score_cover")
    self.hit_info = tex.get_texture_info("lane", "lane_hit_circle")
    self.lane_info = tex.get_texture_info("lane", "lane_background")
    self.popup = nil
    UI.reset()
    Play.reset(player_num)
    local scr = string.upper(tostring(tex.current_screen() or ""))
    self.solo = (scr == "GAME") and not is_2p
    -- the title band: drawn once (player 1's counter), not in practice (no song info there) nor in
    -- the tutorial (its own overlay holds that corner, and the cabinet shows no song name there)
    self.title_band = (player_num == 1 or not is_2p) and scr ~= "GAME_PRACTICE" and scr ~= "TUTORIAL"
        and scr ~= ""
    if self.title_band then
        -- in dan, tex.song_title() is the course name; the song on screen comes from our
        -- dan_between.lua (DanBetween:start gets each song's title) through _G.SS_DAN_TITLE
        self.dan = scr == "GAME_DAN"
        if self.dan then
            self.band_for = _G.SS_DAN_TITLE      -- nil until the first song starts: the full band
        else
            self.band_for = tex.song_title and tex.song_title() or ""
        end
        self.band_w = band_width(self.band_for)
        self.genre_info = tex.get_texture_info("song_info", "genre")
    end
    return self
end

-- Z-DON (src/libs/zdon_lua.cpp; absent on upstream engines, where both draws do nothing) -----------------
-- FAST / SLOW: a chip on the moji strip under the hit circle for 400 ms after a hit off by more than the
-- engine's threshold (blue FAST = early, orange SLOW = late). The score counter draws after the notes, so
-- the chip is never covered by the next note's label.
local MOJI_CY = 232.5                  -- moji strip 213..252 (ss/v2_game.py ROW_MOJI), lane-local
local TIMING_SHOW_MS = 400
local ROW_BOT_INK = 252                 -- the lane's bottom ink band 252..258 (ss/v2_game.py), lane-local
-- play, 2P and dan (practice has its own bar); the bar lives inside each lane's bottom ink band
local PROGRESS_SCREENS = { GAME = true, GAME_2P = true, GAME_DAN = true }

function ScoreCounter:draw_hit_timing(y)
    if not tex.last_hit then return end
    local off, at, good, _, mark = tex.last_hit(self.player_num)
    if not off then return end
    local age = tex.get_current_ms() - at
    -- mark: the threshold from [general] zdon_hit_timing_show (half the good window by default)
    if age < 0 or age > TIMING_SHOW_MS or math.abs(off) <= (mark or good * 0.5) then return end
    local hc = self.hit_info
    if not (hc and hc.x and hc.x[1]) then return end
    local late = off > 0
    self.fs_text = self.fs_text or { fast = UI.text_key("fast", 18, "on_ink"), slow = UI.text_key("slow", 18, "ink") }
    local t = late and self.fs_text.slow or self.fs_text.fast
    local w = math.ceil((t.width + 6 * U) / U) * U
    local h = 10 * U
    local hop = (age < 50) and U or 0           -- one 1U hop on the first frames
    local x = UI.grid(hc.x[1] + hc.width / 2 - w / 2)
    local cy = y + MOJI_CY - hop
    local ix, iy, iw, ih = UI.chrome.chip(x, UI.grid(cy - h / 2), w, h, late and P.easy or P.p2, false)
    UI.draw_text(t, ix + iw / 2, iy + ih / 2, "c")
end

-- the song progress bar, inside the lane's 2U bottom ink band (so it needs no room of its own: 2P and
-- dan lanes have none under them): the played part in the player's colour on the top 1U row, GOGO
-- sections in gold on the bottom 1U row, the ink band itself as the track
function ScoreCounter:draw_progress(y)
    if not tex.song_progress then return end
    if not PROGRESS_SCREENS[string.upper(tostring(tex.current_screen() or ""))] then return end
    local pos, len, gogo = tex.song_progress(self.player_num)
    if not pos or len <= 0 then return end
    local li = self.lane_info
    if not (li and li.x and li.x[1]) then return end
    -- lane_background is an 8 px strip the engine stretches to the screen's right edge
    local x0, x1 = li.x[1] + 2 * U, tex.get_screen_width() - 2 * U
    local by = y + ROW_BOT_INK
    local w = x1 - x0
    local function px(ms) return x0 + w * math.max(0, math.min(1, ms / len)) end
    UI.rect(x0, by, UI.grid(px(pos) - x0), U, self.player_num == 2 and P.p2 or P.p1)
    for _, g in ipairs(gogo or {}) do
        local a, b = UI.grid(px(g[1])), UI.grid(px(g[2]))
        UI.rect(a, by + U, math.max(U, b - a), U, P.clear)
    end
end

function ScoreCounter:set_count(score)
    self.score = score
end

function ScoreCounter:add_popup(value, limited)
    local v = math.max(math.floor(value), 0)
    if v <= 0 then return end
    self.popup = { str = "+" .. tostring(v), t0 = tex.get_current_ms() }
    Play.hit(self.player_num, v, limited)
end

function ScoreCounter:update(ms, score)
    self.ms = ms
    self:set_count(score)
    -- the counter steps up toward the score in at most 4 frames (no smooth roll, no jitter)
    if self.shown ~= self.score then
        local d = self.score - self.shown
        if d > 0 and d > 40 then
            self.shown = self.shown + math.max(10, math.floor(d / 2 / 10) * 10)
        else
            self.shown = self.score
        end
    end
    if self.popup and ms - self.popup.t0 > 3 * POP_STEP_MS + POP_HOLD_MS then self.popup = nil end
end

function ScoreCounter:draw_title()
    if self.dan and _G.SS_DAN_TITLE ~= self.band_for then
        self.band_for = _G.SS_DAN_TITLE
        self.band_w = band_width(self.band_for)
    end
    local x1 = TITLE_RIGHT + BAND_PAD
    UI.frame(x1 - self.band_w, TITLE_CY - BAND_H / 2, self.band_w, BAND_H,
             { fill = P.hint_bg, border = U, shadow = U, border_c = P.ink })
    -- the genre plate's 1U ink frame + hard shadow (ss/v2_game.py build_song_info): the engine then
    -- draws song_info/genre (recoloured to the genre colour by its shader) inside it, and the genre name
    local g = self.genre_info
    if g and g.x and g.x[1] then
        UI.frame(g.x[1] - U, g.y[1] - U, g.width + 2 * U, g.height + 2 * U, { fill = P.ink, notch = 0 })
    end
end

function ScoreCounter:draw(y)
    Play.current = self.player_num
    if self.title_band then
        self:draw_title()
        AI.draw_game()            -- Z-DON AI battle: the section scoreboard (nothing otherwise)
    end
    -- 2P: Nijiiro mirrors the cover to the box bottom; ours is drawn upright, 1U-step clear of the
    -- cover's bottom ink row
    local p2_offset = self.is_2p and (tex.get_skin_config("game_score_counter_2p_y_offset").y - 3 * U) or 0
    if self.is_2p then
        tex.draw_texture(self.t_cover, { y = y + p2_offset })
        -- the cover's 2U accent strip is 1P red (ss/v2_game.py f_score_cover): 2P repaints it blue
        local c = self.cover_info
        if c and c.x and c.x[1] then
            UI.rect(c.x[1] + U, c.y[1] + y + p2_offset + U, 2 * U, 14 * U, P.p2)
        end
    else
        tex.draw_texture(self.t_cover, { y = y })
    end
    local cy = y + SCORE_CY + p2_offset
    UI.num(tostring(math.max(self.shown, 0)), SCORE_RIGHT, cy, "xl", P.ink, 255, "r")

    local p = self.popup
    if p then
        local age = (self.ms or tex.get_current_ms()) - p.t0
        local rise = math.min(2, math.floor(age / POP_STEP_MS)) * U
        local w = UI.num_width(p.str, "m") + 6 * U
        local h = 9 * U
        local px = SCORE_RIGHT + 3 * U - w
        -- 1P: below the score panel; 2P (mirrored cover): above it
        local py = self.is_2p and (cy - 42 - h + 2 * U - rise) or (cy + 33 - rise)
        -- the chip lands gold while it rises (3 frames, 50 ms), then settles to paper
        UI.chrome.chip(px, py, w, h, (age < 3 * POP_STEP_MS) and P.clear or P.paper, false)
        UI.num(p.str, px + w / 2, py + h / 2, "m", P.ink, 255, "c")
    end

    self:draw_hit_timing(y)
    self:draw_progress(y)

    -- (the hit rays are baked into the engine's hit_effect_*, drawn under the notes)
    Play.draw_portrait(self.player_num, y, self.is_2p)
    if self.solo then Play.draw_info(self.player_num) end
end
