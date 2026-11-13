-- The normal song select's left player board (arcade common/player_board.nulm, measured on direct-feed footage):
--   * the record board: oni + ura record counters (ranks, crowns), the same art and counters as the AI select's
--     board (ai_battle.lua draw_player_board; this file keeps its own copy so the AI branch stays untouched)
--   * under it, while a song is under the cursor: the "personal best" panel (gold ribbon, the course mark and
--     the best score)
-- OFF unless skin_config has a "player_board_on" entry: direct-feed captures of the same player show the board in
-- some stages (olN28yIMfpw, 3-az5OZbHtw) and not in others (TajqEDSGlAs), so the default follows the latter.
-- The board is drawn at 0.95 of the AI select's size (310 x 179 px at 1080p on the cabinet).
PlayerBoard = {}

local S = 0.95
local OX, OY = 28.8, 313.0                 -- screen position of the top texture's top-left
local DIGIT_O = 40                         -- digit textures are 80x80 around the sprite's origin
local COUNTERS = {                         -- {x, y} in top-texture coords; ranks 1..7 then crowns 1..3
    rank = { { 89, 113 }, { 181, 113 }, { 279, 113 }, { 89, 75 }, { 181, 75 }, { 279, 75 }, { 279, 36 } },
    crown = { { 89, 156 }, { 181, 156 }, { 279, 156 } },
}
local PANEL_CX, PANEL_CY = 186.5, 621.0
local BEST_RIGHT, BEST_Y, BEST_STEP = 282.0, 631.0, 19.0
local ICON_X, ICON_Y = 80.0, 630.0
local TITLE_CX, TITLE_CY = 185.0, 602.5
local URA_SWAP_MS = 1500

-- main_instance "defalut_open": the record board flips open around its centre, scale x per frame
local OPEN = { 0.02, 0.05, 0.13, 0.27, 0.46, 0.7, 1 }
local TOP_CX = 166

local T = {}
local function tx(name)
    local t = T[name]
    if t == nil then
        local id = tex.get_texture("player_board/" .. name)
        local info = id and tex.get_texture_info("player_board", name)
        t = id and { t = id, w = info and info.width or 0, h = info and info.height or 0 } or false
        T[name] = t
    end
    return t or nil
end

local function enabled()
    if T.on == nil then T.on = tex.get_skin_config("player_board_on") ~= nil end
    return T.on
end

local focus = { ms = -1e9 }
local open = { last = -1e9 }
local rec = { ms = -1e9 }
local title

-- the box under the cursor (song_select.lua draw_box)
function PlayerBoard.set_focus(box, kind)
    if not enabled() then return end
    local now = tex.get_current_ms()
    if focus.ms == now then return end
    focus.ms = now
    if kind ~= "song" or not box.best_score then
        focus.seen, focus.song = now, false
        return
    end
    local path = box.path and box:path() or ""
    local gap = now - (focus.seen or -1e9) > 1000
    focus.seen = now
    if focus.song and focus.path == path and not gap then return end
    focus.song, focus.path, focus.t0 = true, path, now
    focus.oni, focus.ura = box:best_score(3), box:best_score(4)
    focus.has_ura = box.has_ura and box:has_ura() or false
end

local function record_counts()
    local now = tex.get_current_ms()
    if not tex.record_counts then return nil end
    if now - rec.ms > 5000 or now < rec.ms then   -- a play since: refresh
        rec.v = tex.record_counts(1, 3)
        rec.ms = now
    end
    return rec.v
end

local function draw_counter(v, cx, cy)
    local s = tostring(math.max(0, math.min(9999, math.floor(v or 0))))
    local k = #s
    local t = tx("digit")
    if not t then return end
    for i = 1, k do
        local x = cx + 7 * (k - 1) - 14 * (i - 1)
        tex.draw_texture(t.t, { x = OX + S * x - DIGIT_O, y = OY + S * cy - DIGIT_O, center = true, scale = S,
                                frame = s:byte(k - i + 1) - 48 })
    end
end

local function put(name, cx, cy, frame)
    local t = tx(name)
    if not t then return end
    tex.draw_texture(t.t, { x = cx - t.w / 2, y = cy - t.h / 2, center = true, scale = S, frame = frame })
end

function PlayerBoard.draw()
    if not enabled() then return end
    local top = tx("top")
    if not top then return end
    local now = tex.get_current_ms()
    if now - open.last > 1000 then open.t0 = now end
    open.last = now
    local of = math.floor((now - open.t0) / (1000 / 60)) + 1
    if of <= #OPEN then
        local sx = OPEN[of]
        tex.draw_texture(top.t, { x = OX + S * TOP_CX * (1 - sx), y = OY, scale = S, x2 = (top.w * sx - top.w) * S })
        return
    end
    tex.draw_texture(top.t, { x = OX, y = OY, scale = S })
    local c = record_counts()
    if c then
        for i, p in ipairs(COUNTERS.rank) do draw_counter(c.ranks[i], p[1], p[2]) end
        for i, p in ipairs(COUNTERS.crown) do draw_counter(c.crowns[i], p[1], p[2]) end
    end

    if not (focus.song and now - focus.ms < 200) then return end
    local ura = focus.has_ura and (math.floor((now - focus.t0) / URA_SWAP_MS) % 2 == 1)
    put("best_panel", PANEL_CX, PANEL_CY)
    put("best_icon", ICON_X, ICON_Y, ura and 4 or 3)
    if title == nil then
        local s = tex.skin_text("pboard_best")
        title = (s and s ~= "") and text.create_raw_text(s, 18, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false,
                                                         3.0 / tex.get_screen_scale(), 1.0) or false
    end
    if title then
        title:draw({ x = math.floor(TITLE_CX - title.width / 2 + 0.5), y = math.floor(TITLE_CY - title.height / 2 + 0.5) })
    end
    local s = tostring(math.max(0, math.min(99999999, (ura and focus.ura or focus.oni) or 0)))
    local sd = tx("sdigit")
    if sd then
        for i = 1, #s do
            tex.draw_texture(sd.t, { x = BEST_RIGHT - BEST_STEP * (i - 1) - DIGIT_O, y = BEST_Y - DIGIT_O, center = true,
                                     scale = S, frame = s:byte(#s - i + 1) - 48 })
        end
    end
end

return PlayerBoard
