-- YataiDONSimpleStyle: the Z-DON AI battle (tex.ai_battle, src/objects/game/zdon_ai.h; absent on upstream
-- engines and outside an AI battle, where both draws do nothing).
--   AI.draw_game()   the section scoreboard, top centre of GAME_2P (player 1's score counter draws it):
--                    "AI对战", one pip per section (open: paper, 2U frame; won: 1P red / AI blue / draw grey;
--                    to come: bg3), the open section's points 1P : AI
--   AI.draw_result() the match banner, top centre of RESULT_2P under the song title (player 1's board):
--                    the result chip (win gold / lose red / draw grey), the pips, sections won 1P - AI
--   AI.p2_char()     "robo" in an AI battle (the 2P lane's character, stage and result), else "hoshi"
--   AI.draw_select() the AI song select (AI_SELECT, from the entry board) tag with the opponent's level, top left
local UI = require("global.ss_ui")
local P = UI.P
local U = UI.U

local AI = {}

-- the 2P side's character: the AI robot in an AI battle (GAME_2P / RESULT_2P), else Hoshi
function AI.p2_char()
    if tex.ai_active and tex.ai_active() then return "robo" end
    return "hoshi"
end

local PIP, GAP = 8 * U, 2 * U

local function battle()
    if not tex.ai_battle then return nil end
    return tex.ai_battle()
end

local function pips_width(b)
    return b.count * (PIP + GAP) - GAP
end

local function draw_pips(b, x, cy, live)
    local y = UI.grid(cy - PIP / 2)
    for i, s in ipairs(b.sections) do
        local px = x + (i - 1) * (PIP + GAP)
        local open = live and i == b.section
        local fill = P.bg3
        if open then fill = P.paper
        elseif s.winner == 0 then fill = P.p1
        elseif s.winner == 1 then fill = P.p2
        elseif s.winner == 2 then fill = P.line end
        UI.frame(px, y, PIP, PIP, { fill = fill, border = open and 2 * U or U, shadow = 0, notch = 0 })
    end
end

-- "12 : 10" with the 1P number red and the AI number blue; returns its width (draw = false: measure)
local function draw_pair(a, b, x, cy, size, draw)
    local sa, sb = tostring(a), tostring(b)
    local colon = UI.text(":", 24, "ink")
    local cw = colon and colon.width or 2 * U
    local w = UI.num_width(sa, size) + 2 * U + cw + 2 * U + UI.num_width(sb, size)
    if draw then
        local px = x + UI.num(sa, x, cy, size, P.p1, 255, "l") + 2 * U
        px = px + UI.draw_text(colon, px, cy, "l") + 2 * U
        UI.num(sb, px, cy, size, P.p2, 255, "l")
    end
    return w
end

local GAME_CX, GAME_Y, GAME_H = 1080, 12, 20 * U
function AI.draw_game()
    local b = battle()
    if not b then return end
    local head = UI.text_key("ai_battle", 24, "ink")
    local tag_p, tag_ai = UI.text("1P", 18, "ink"), UI.text("AI", 18, "ink")
    local lp = b.finished and b.wins_p or b.live_p
    local la = b.finished and b.wins_ai or b.live_ai
    local pair_w = draw_pair(lp, la, 0, 0, "m", false)
    local w = 5 * U + head.width + 4 * U + pips_width(b) + 6 * U + tag_p.width + 2 * U + pair_w + 2 * U +
              tag_ai.width + 5 * U
    w = math.ceil(w / U) * U
    local ix, iy, iw, ih = UI.chrome.panel(UI.grid(GAME_CX - w / 2), GAME_Y, w, GAME_H, P.paper)
    -- the AI's mood: a 1U strip along the top (gold: it leads the section and eases off, blue: it trails
    -- and tightens up)
    if b.state == 1 then UI.rect(ix, iy, iw, U, P.clear)
    elseif b.state == 2 then UI.rect(ix, iy, iw, U, P.p2) end
    local cy = iy + ih / 2
    local x = ix + 4 * U
    x = x + UI.draw_text(head, x, cy, "l") + 4 * U
    draw_pips(b, x, cy, not b.finished)
    x = x + pips_width(b) + 6 * U
    x = x + UI.draw_text(tag_p, x, cy, "l") + 2 * U
    draw_pair(lp, la, x, cy, "m", true)
    x = x + pair_w + 2 * U
    UI.draw_text(tag_ai, x, cy, "l")
end

-- AI.draw_select(): the AI song select's tag, top left (clear of the course select window): "AI对战" + the
-- opponent's level chip
local SEL_X, SEL_Y, SEL_H = 24, 18, 18 * U
function AI.draw_select()
    if not tex.ai_level then return end
    local head = UI.text_key("ai_battle", 24, "ink")
    local lv = UI.text("AI Lv." .. tostring(tex.ai_level()), 24, "ink")
    local cw = math.ceil((lv.width + 8 * U) / U) * U
    local w = math.ceil((5 * U + head.width + 4 * U + cw + 3 * U) / U) * U
    local ix, iy, iw, ih = UI.chrome.panel(SEL_X, SEL_Y, w, SEL_H, P.paper)
    UI.draw_text(head, ix + 4 * U, iy + ih / 2, "l")
    local cx, cy, cww, chh = UI.chrome.chip(ix + iw - 2 * U - cw, iy + 2 * U, cw, ih - 4 * U, P.p2, false)
    UI.draw_text(lv, cx + cww / 2, cy + chh / 2, "c")
end

local RES_CX, RES_Y, RES_H = 960, 114, 20 * U
function AI.draw_result()
    local b = battle()
    if not b or not b.finished then return end
    local key, fill = "ai_draw", P.line
    if b.result == "win" then key, fill = "ai_win", P.clear
    elseif b.result == "lose" then key, fill = "ai_lose", P.bad end
    local word = UI.text_key(key, 24, "ink")
    local head = UI.text_key("ai_battle", 18, "ink")
    local pair_w = draw_pair(b.wins_p, b.wins_ai, 0, 0, "m", false)
    local cw = math.ceil((word.width + 8 * U) / U) * U
    local w = 3 * U + cw + 4 * U + head.width + 4 * U + pips_width(b) + 6 * U + pair_w + 5 * U
    w = math.ceil(w / U) * U
    local ix, iy, iw, ih = UI.chrome.panel(UI.grid(RES_CX - w / 2), RES_Y, w, RES_H, P.paper)
    local cy = iy + ih / 2
    local x = ix + 2 * U
    local cx, cyy, cww, chh = UI.chrome.chip(x, iy + 2 * U, cw, ih - 4 * U, fill, false)
    UI.draw_text(word, cx + cww / 2, cyy + chh / 2, "c")
    x = x + cw + 4 * U
    x = x + UI.draw_text(head, x, cy, "l") + 4 * U
    draw_pips(b, x, cy, false)
    x = x + pips_width(b) + 6 * U
    draw_pair(b.wins_p, b.wins_ai, x, cy, "m", true)
end

return AI
