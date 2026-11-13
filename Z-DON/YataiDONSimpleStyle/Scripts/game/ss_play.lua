-- YataiDONSimpleStyle v2: shared play-screen state and the player portrait.
-- The engine has no game-state queries for skins, so the game scripts report what they see here:
--   score_counter.lua  hits (add_popup), the lane y and side of each player (draw)
--   combo.lua          combo changes (milestones, misses)
--   *_animation.lua    the ending (clear / full combo / fail)
-- and the background script (another module) may publish _G.SS_GAME = { bpm =, beat0 =, gogo = { [1]=, [2]= } }
-- from its update / handle_gogo callbacks; without it the portrait simply skips the beat hop / GOGO.
--
-- Portrait (bible 2.6): Momo (1P) / Hoshi (2P) at k = 6 inside a 72U x 72U panel, standing on the
-- panel's inner floor; 1P above its lane cover, 2P below its lane. All motion frame-based, integer px.

local UI = require("global.ss_ui")
local P = UI.P
local U = UI.U

local Play = {}

local players = {}

local PANEL = 72 * U            -- 216
local PANEL_X = 10 * U          -- 30

local function now() return tex.get_current_ms() end

function Play.player(n)
    local p = players[n]
    if not p then
        p = {
            n = n,
            mascot = nil,
            lane_y = nil,
            is_2p = n == 2,
            combo = 0,
            miss_run = 0,
            burst_at = -1e9,
            ending = nil,
            screen_id = nil,
        }
        players[n] = p
    end
    return p
end

-- a new song screen resets the state (scripts are re-created per screen; the module is cached)
function Play.reset(n)
    players[n] = nil
    if n == 1 then Play.exact = nil end
end

local function shared()
    local g = rawget(_G, "SS_GAME")
    return type(g) == "table" and g or nil
end

local function ensure_mascot(p)
    if not p.mascot then
        UI.reset()
        p.mascot = UI.Mascot.new({ char = (p.n == 2) and require("global.ss_ai").p2_char() or "momo",
                                   role = "portrait" })
    end
    return p.mascot
end

-- events --------------------------------------------------------------------------------------
-- value / limited: ScoreCounter:add_popup's arguments. The engine pops exactly base_score for a 良,
-- 10*floor(base/20) for a 可 and 100 (limited) per drumroll hit, so the values tell the judgements
-- apart (counted per value; the base is the largest limited value seen).
function Play.hit(n, value, limited)
    local p = Play.player(n)
    if value and limited then
        p.vals = p.vals or {}
        p.vals[value] = (p.vals[value] or 0) + 1
    end
    -- the hit burst: 100 = a drumroll / balloon / kusudama hit (sparks); a limited value is a note:
    -- 良 pays the base (the largest note value seen), 可 about half of it. Unlimited values other than
    -- 100 are bonuses (GEN3 combo / balloon), no burst.
    if value == 100 then
        p.hit_kind, p.hit_t = "roll", now()
    elseif value and limited then
        if value >= (p.top or 0) then p.top = value end
        p.hit_kind, p.hit_t = (value * 4 < p.top * 3) and "ok" or "good", now()
    end
    local m = ensure_mascot(p)
    p.miss_run = 0
    if m.mood == "sad" then m.mood = nil end
    if not p.ending then m:react("hit") end
end

function Play.combo(n, combo)
    local p = Play.player(n)
    local m = ensure_mascot(p)
    local prev = p.combo
    p.combo = combo
    if combo == 0 and prev >= 10 then
        p.miss_run = p.miss_run + 1
        if not p.ending then m:react("miss") end
    end
    if combo > (p.max_combo or 0) then p.max_combo = combo end
    if combo == 0 and prev >= 10 then
    elseif combo > prev and combo >= 50 and (combo % 50 == 0) then
        if not p.ending then m:react("combo") end
        p.burst_at = now()
    end
end

function Play.ending(n, kind)
    local p = Play.player(n)
    local m = ensure_mascot(p)
    p.ending = kind
    if kind == "fail" then
        m:react("fail")
    else
        m:react("clear")
        p.burst_at = now()
    end
end

function Play.stats(n)
    local p = Play.player(n)
    -- exact counts when the engine runs a JudgeCounter (judge-counter setting): judge_counter.lua
    local e = Play.exact
    if e and n == 1 then return e.good, e.ok, e.roll, p.max_combo or 0 end
    local vals = p.vals or {}
    local base = 0
    for v, _ in pairs(vals) do
        if v ~= 100 and v > base then base = v end
    end
    if base == 0 and vals[100] and not p.has_roll then base = 0 end
    local good = base > 0 and (vals[base] or 0) or 0
    local okv = 10 * math.floor(base / 20)
    local ok = (base > 0 and okv ~= base and okv ~= 100) and (vals[okv] or 0) or 0
    local roll = vals[100] or 0
    return good, ok, roll, p.max_combo or 0
end

-- the live record panel, 1P GAME only: the stage module leaves (48, 576)-(528, 1002) free for it and
-- its ground line is y 1014 (the panel stands on it with its 1U shadow)
local INFO_X, INFO_W, INFO_FOOT = 48, 480, 1011
local ROW = 13 * U
-- rows: a chip sized to its label (edge style: bg3 + 1U accent), the value right-aligned; every
-- value of the panel shares one right edge and sits on its row's chip centre line
function Play.draw_info(n)
    local good, ok, roll, maxc = Play.stats(n)
    local rows = 5
    local h = rows * ROW + 5 * U
    local y = INFO_FOOT - h
    local ix, iy, iw, ih = UI.chrome.panel(INFO_X, y, INFO_W, h, P.paper)
    local vx = ix + iw - 4 * U
    local function row(k, key, accent, value)
        local ry = iy + 3 * U + k * ROW
        local lw = UI.label_width(key, 18)       -- the label in the player's language (run-time text)
        if lw <= 0 then lw = (UI.D.LABEL[key] and UI.D.LABEL[key].w) or 54 end
        local cw = math.ceil((lw + 6 * U) / U) * U
        local cx, cy, _, ch = UI.chrome.chip(ix + 3 * U, ry + U, cw, 10 * U, accent, true)
        UI.label(key, cx + 2 * U, cy + ch / 2, P.ink, 255, "l")
        if value then UI.num(tostring(value), vx, cy + ch / 2, "l", P.ink, 255, "r") end
        return cx + cw, cy + ch / 2
    end
    row(0, "good", P.clear, good)
    row(1, "ok", P.line, ok)
    row(2, "roll", P.roll, roll)
    row(3, "maxcombo", P.p1, maxc)
    local cx1, cy = row(4, "acc", P.clear, nil)
    local total = good + ok
    local frac = total > 0 and good / total or 0
    local pct = tostring(math.floor(frac * 100 + 0.5)) .. "%"
    local nw = UI.num_width(pct, "l")
    local bx = UI.grid(cx1 + 4 * U)
    local bw = math.floor((vx - nw - 3 * U - bx) / U) * U
    UI.pixbar(bx, cy - 3 * U, bw, 6 * U, frac, P.clear, 10)
    UI.num(pct, vx, cy, "l", P.ink, 255, "r")
end

-- draw ----------------------------------------------------------------------------------------
-- The hit ring around the hit circle, after Nijiiro's outer ring (game/ss_hit good / ok: 4 frames, roll: 3 frames; 33.3 ms per frame,
-- i.e. 2 display frames each at 60 fps), centred on the hit circle (lane_hit_circle 510,2 + 108:
-- x 618, lane y + 110). The engine's judge position can move (#JPOSSCROLL); the burst stays on the
-- default circle. Drawn from the score counter (draw_overlays: over the notes and the judgement mark).
local BURST_MS = 33.33
local HIT_CX, HIT_DY = 618, 110
local burst_tex = {}
local BURST_FRAMES = { good = 4, ok = 4, roll = 3 }

function Play.draw_burst(n, lane_y)
    local p = players[n]
    if not p or not p.hit_t then return end
    local f = math.floor((now() - p.hit_t) / BURST_MS)
    local kind = p.hit_kind
    if kind == "roll" then return end   -- Nijiiro shows nothing extra on drumroll / balloon hits
    if f < 0 or f >= BURST_FRAMES[kind] then return end
    local t = burst_tex[kind]
    if t == nil then
        t = tex.get_texture("game/ss_hit/" .. kind) or false
        burst_tex[kind] = t
    end
    if not t then return end
    local info = burst_tex[kind .. "_w"]
    if not info then
        local i = tex.get_texture_info("ss_hit", kind)
        info = (i and i.width) or 288
        burst_tex[kind .. "_w"] = info
    end
    tex.draw_texture(t, { frame = f, x = HIT_CX - info / 2, y = lane_y + HIT_DY - info / 2 })
end

-- lane_y: the player's lane top (score_counter draw y); is_2p: below-lane layout
function Play.draw_portrait(n, lane_y, is_2p)
    local p = Play.player(n)
    p.lane_y, p.lane_ms = lane_y, now()
    local m = ensure_mascot(p)
    local t = now()
    local g = shared()
    local bpm, beat0 = nil, nil
    if g then
        bpm, beat0 = g.bpm, g.beat0
        local gogo = g.gogo and g.gogo[n]
        if gogo and m.mood ~= "gogo" and not p.ending then m:react("gogo")
        elseif not gogo and m.mood == "gogo" then m:react("gogo_end") end
    end
    m.beat_on = bpm ~= nil
    m:update(t, bpm, beat0)

    local x = PANEL_X
    local y = is_2p and (lane_y + 92 * U) or (lane_y - 76 * U)
    local ix, iy, iw, ih = UI.chrome.panel(x, y, PANEL, PANEL, P.bg2)
    -- floor: a 2U strip in the player colour under the feet (GOGO: a 2-frame gogo/gold dither)
    local floor_y = iy + ih - 2 * U
    local accent = is_2p and P.p2 or P.p1
    if m.mood == "gogo" then
        local ph = UI.COMFORT and 0 or math.floor(t / 133) % 2   -- comfort mode: a still checker
        for c = 0, iw / U - 1 do
            local col = ((c + ph) % 2 == 0) and P.gogo or P.clear
            UI.rect(ix + c * U, floor_y, U, U, col)
            UI.rect(ix + c * U, floor_y + U, U, U, ((c + ph) % 2 == 0) and P.clear or P.gogo)
        end
    else
        UI.rect(ix, floor_y, iw, 2 * U, accent)
    end
    UI.rect(ix, floor_y - U, iw, U, P.ink)
    m:draw(ix + iw / 2, floor_y - U)
    -- the event burst (combo milestone / clear) beside the head
    local since = t - p.burst_at
    if since >= 0 and since < 600 then
        UI.burst(ix + iw - 9 * U, iy + 12 * U, since)
        UI.burst(ix + 9 * U, iy + 21 * U, since - 133)
    end
end

-- 2P nameplate colour (owner 10-29: 1P red, 2P blue). The engine builds each in-game Nameplate with
-- global_data.player_num (player.cpp Player::Player), so in a 2P song both plates are "1P" (red badge).
-- The 2P plate is the one drawn at or below the 2P lane top (nameplate game_p2 = lane y + 7; the 1P
-- plate sits inside the 1P box, above the 2P lane): on GAME_2P such a plate is shown as 2P (blue badge,
-- 2P word). The plate object is the engine's; only its badge fields change, once.
-- (promote to v2_meta / an engine fix: pass player_num to Nameplate in Player::Player)
if Nameplate and Nameplate.draw and not Nameplate.ss_2p_wrapped then
    local base_draw = Nameplate.draw
    Nameplate.ss_2p_wrapped = true
    Nameplate.draw = function(self, x, y, fade)
        if self.player_num == 1 and not self.ss_side then
            local scr = string.upper(tostring(tex.current_screen and tex.current_screen() or ""))
            local p2 = players[2]
            if scr == "GAME_2P" and p2 and p2.lane_y and now() - (p2.lane_ms or -1e9) < 500 then
                if y >= p2.lane_y then
                    self.player_num = 2
                    self.pnum_tex = tex.get_texture("global/nameplate/2p")
                end
                self.ss_side = true
            end
        end
        return base_draw(self, x, y, fade)
    end
end

return Play
