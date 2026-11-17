-- The normal song select's left player board (arcade common/player_board.nulm, measured on direct-feed footage):
--   * the record board: oni + ura record counters (ranks, crowns), the same art and counters as the AI select's
--     board (ai_battle.lua draw_player_board; this file keeps its own copy so the AI branch stays untouched)
--   * the "personal best" panel under it lives in score_history.lua (the ScoreHistory override)
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

local open = { last = -1e9 }
local rec = { ms = -1e9 }

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
end

return PlayerBoard
