-- AI battle in Green's look (Z-DON: tex.ai_battle / tex.ai_rank, src/objects/game/zdon_ai.h). Engines without
-- them draw nothing. The art is Green's own "ghost" set (System 357 data/lumendata/packed/ghost, exported by the
-- scratchpad green_ai tools into Graphics/{game,song_select,result}/ai_battle); positions are Green's 1280x720
-- stage, as its movies place them.
--   AIB.draw_game_bg()  GAME_2P (Background:draw_back): the arena above and below the lanes (ai_enso_bg: mc_bg
--                       enso_bg + the tug-of-war tiles 1p_0..1p_18); the section sweep at a section's end
--   AIB.draw_game()     GAME_2P, from the AI lane's score counter: the judge boards (score_board), the section
--                       icons (section_win_icon) and the section timer (time)
--   AIB.draw_result(ready) / AIB.draw_select() ... (below)
local AIB = {}
local S = tex.get_screen_scale()   -- Green is laid out at 1280x720

local T, T_screen = {}, nil
local function tx(name)
    local scr = tex.current_screen and tex.current_screen() or ""
    if scr ~= T_screen then T, T_screen = {}, scr end
    local t = T[name]
    if t == nil then
        t = tex.get_texture("ai_battle/" .. name) or false
        local info = t and tex.get_texture_info("ai_battle", name)
        T[name] = t and { t = t, w = info and info.width or 0, h = info and info.height or 0 } or false
        t = T[name]
    end
    return t or nil
end

-- textures cut from Green shapes carry the shape's top left relative to its anchor (green_ai/game_meta.json)
local ORIGIN = {
    board_don = { -52, -48 }, board_ai = { -52, -48 }, board_digit = { -8, -12 },
    sec_base = { -24, -24 }, sec_pulse = { -24, -24 }, sec_win = { -24, -24 }, sec_glow = { -28, -28 },
    sec_lose = { -24, -24 }, sec_win_big = { -92, -88 }, sec_lose_big = { -92, -88 },
    sec_lose_glow = { -100, -95.5 },
    timer_frame = { -104, -20 }, timer_bar = { -4, -8 }, timer_fill = { -4, -8 }, timer_full = { -4, -8 },
    timer_label = { -12, -20 },
}

-- draw texture `name` anchored at (x, y) (its shape origin), scale s about the anchor
local function at(name, x, y, opts)
    local t = tx(name)
    if not t then return end
    opts = opts or {}
    local o = ORIGIN[name] or { 0, 0 }
    local s = opts.scale or 1
    tex.draw_texture(t.t, { x = (x + o[1] * s) * S, y = (y + o[2] * s) * S, scale = s, fade = opts.fade,
                            frame = opts.frame })
end

local function battle()
    if not tex.ai_battle then return nil end
    return tex.ai_battle()
end

local function ease_out(t) t = math.max(0, math.min(1, t)); return 1 - (1 - t) * (1 - t) end

function AIB.active()
    return tex.ai_active ~= nil and tex.ai_active()
end

------------------------------------------------------------------------------------------------ game
local TOP_H, BOT_Y = 184, 530
-- a section closing: the tiles sweep to all red (won) / all blue (lost) and stay so (the arena's
-- win_ku / lose_ku), then follow the next section
local SWEEP_MS, HOLD_MS = 633, 3067
-- the duel at the boundary (footage hi/topbands.png): aura scale / centre line, the Don's and robot's distance from
-- the boundary, the Don's scale and turn (tex.ai_draw_don)
local AURA_S, AURA_Y = 1.35, 95
local GENRE_PILL = { 1154, 693 }   -- strict audit round 15: was -6,-3 off the direct feed
local centered
-- round 16: DON_S 0.58 -> 0.52, measured on the feed's clean sample f164 (green face 34 x 43 vs ours 41 x 49, hat tip to
-- feet 149 vs 165 px: 0.83 .. 0.91 of ours; the other band frames are flash-washed)
local DON_GAP, DON_S, DON_ROT = 70, 0.52, 35
local G = { k = 9, k_ms = nil, closed = 0 }

function AIB.draw_game_bg()
    if not AIB.active() or not tx("arena_top") then return false end
    local b = battle()
    local target = 9
    if b and b.tug and not b.finished then target = b.tug
    elseif b and b.finished then target = (b.result == "win") and 18 or 0 end
    local now = tex.get_current_ms()
    local dt = G.k_ms and math.max(0, now - G.k_ms) or 0
    G.k_ms = now
    local closed, last = 0, nil
    for _, sec in ipairs(b and b.sections or {}) do
        if sec.winner >= 0 then closed = closed + 1; last = sec end
    end
    if closed < G.closed then G.closed, G.sweep = closed, nil end
    if closed > G.closed and last then
        G.closed = closed
        G.sweep = { t0 = now, from = G.k, to = (last.winner == 0) and 18 or 0 }
    end
    local sw = G.sweep
    if sw and now - sw.t0 < HOLD_MS then
        G.k = sw.from + (sw.to - sw.from) * math.min(1, (now - sw.t0) / SWEEP_MS)
    else
        local step = dt * 0.012
        if math.abs(target - G.k) <= step then G.k = target
        elseif target > G.k then G.k = G.k + step else G.k = G.k - step end
    end
    local k = math.max(0, math.min(18, math.floor(G.k + 0.5)))
    tex.draw_texture(tx("arena_top").t, { x = 0, y = 0, frame = k })
    if tx("arena_bot") then tex.draw_texture(tx("arena_bot").t, { x = 0, y = BOT_Y * S, frame = k }) end
    -- the AI (mc_aidon_position: the arena only anchors the AI don, which pushes at the tiles' red / blue
    -- boundary, x 58 + 67.9 k); its "angry" state (ghosttuning emotionofs_threshigh / threslow of the level:
    -- player ahead by 6, calm again at 5) shakes it, Green's own emotion is the 3D don's face
    local robot = tx("robot")
    if robot and b then
        local lead = (b.live_p or 0) - (b.live_ai or 0)
        local hi, lo = b.emotion_high or 6, b.emotion_low or 2
        if not G.angry and lead >= hi and not b.finished then G.angry = true
        elseif G.angry and (lead <= lo or b.finished) then G.angry = false end
        local bx = 58 + 67.9 * G.k + 62
        local shake = G.angry and 3 * math.sin(now / 30) or 0
        local bob = 3 * math.sin(now / 420)
        local rs = 0.42
        -- footage (hi/topbands.png): the player's Don (Z-DON's own, tex.ai_draw_don: feet in screen px) and the
        -- robot face each other ~140 px apart at the boundary (cx), each in its flame aura (orange from the left,
        -- blue mirrored from the right, fronts meeting at cx), speed lines behind and a white flash between them
        -- the duel stays on screen (footage: the clash never leaves x ~560..1000 however far the tiles go)
        local cx = math.max(560, math.min(1000, bx - 6))
        local fl = math.floor(now / 50) % 3
        local pulse = 0.92 + 0.08 * math.sin(now / 60)
        -- the lunge (ai_enso_bg mc_don_attack / mc_aidon_attack: each tug step is its own attack state, the pusher
        -- thrusts into the clash while the other recoils): when the tug moves a step, that side leaps ~34 px
        -- and back in 260 ms, the impact flares, the other side is shoved back 10 px
        local ks = math.max(0, math.min(18, math.floor(G.k + 0.5)))
        if G.lk and ks ~= G.lk and not b.finished then G.lunge = { t0 = now, dir = (ks > G.lk) and 1 or -1 } end
        G.lk = ks
        local lu, ldir = 0, 0
        if G.lunge then
            local u = (now - G.lunge.t0) / 260
            if u < 1 then lu, ldir = math.sin(math.pi * u), G.lunge.dir else G.lunge = nil end
        end
        local don_off = (ldir == 1) and 34 * lu or ((ldir == -1) and -10 * lu or 0)
        local ai_off = (ldir == -1) and -34 * lu or ((ldir == 1) and 10 * lu or 0)
        local function aura(name, front_x, mirror)
            local t = tx(name)
            if not t then return end
            local s2 = AURA_S * pulse
            local x = mirror and front_x or (front_x - 342 * s2)
            tex.draw_texture(t.t, { x = x * S, y = (AURA_Y - 110 * s2) * S, scale = s2, frame = fl,
                                    mirror = mirror and "horizontal" or nil })
        end
        local sweeping = G.sweep and now - G.sweep.t0 < SWEEP_MS + 600
        if not b.finished and not sweeping then
            local lines = tx("clash_lines")
            if lines then
                tex.draw_texture(lines.t, { x = (cx - 160 - 344 * 1.6) * S, y = (AURA_Y - 48 * 1.6) * S, scale = 1.6,
                                            fade = 0.8 })
            end
            aura("aura_o", cx + 18, false)
            aura("aura_b", cx - 18, true)
            local glow = tx("clash_glow")
            if glow then
                local gs = 0.55 * pulse * (1 + 0.6 * lu)
                tex.draw_texture(glow.t, { x = (cx - 360 * gs) * S, y = (AURA_Y - 360 * gs) * S, scale = gs })
            end
            local rays = tx("clash_rays")
            if rays then
                local k = 0.30 * pulse * (1 + 0.5 * lu)
                tex.draw_texture(rays.t, { x = (cx - 570 * k) * S, y = (AURA_Y - 570 * k) * S, scale = k })
            end
            if tex.ai_draw_don then tex.ai_draw_don((cx - DON_GAP + don_off) * S, 168 * S, DON_S, DON_ROT) end
        end
        tex.draw_texture(robot.t, { x = (cx + DON_GAP - robot.w * rs / 2 + shake + ai_off) * S,
                                    y = (100 - robot.h * rs / 2 + bob) * S, scale = rs })
    end
    AIB.draw_section_flash(now)
    return true
end

-- a section the player won: a white / yellow burst over the arena bands, the arena's triangle layers flickering over
-- it (footage Tl7g8XXXvAM 213.3-215.4 s: bright yellow tiles, pink flowers and triangles all across the arena)
local FLASH_MS = 2100
function AIB.draw_section_flash(now)
    local sw = G.sweep
    if not sw or sw.to ~= 18 then return end
    local t = now - sw.t0
    if t < 0 or t > FLASH_MS then return end
    local fade = (t < 150) and (t / 150) or math.max(0, 1 - (t - 400) / (FLASH_MS - 400))
    fade = math.min(1, fade)
    -- (no full-width bands: direct-feed footage Tl7g8XXXvAM 213-215 s shows only the arena tile states and the flash clusters)
    -- the burst's pink flower + red hexagon / fan hexagon + yellow flower + swirl clusters (ai_enso_bg sprite 369, shapes
    -- 349 / 351, 480x280 each): they rise into the bands in 12 frames, drift up slowly and fade at the end; the
    -- top band's pair is turned upside down. Positions from lumen_anim_dump_green (60 fps)
    do
        local f = t * 0.06
        local yb, yt
        if f < 12 then
            yb = f < 6 and (859 - 21 * f) or (732 - 10.7 * (f - 6))
            yt = f < 6 and (227 - 12.7 * f) or (151 - 6.5 * (f - 6))
        else
            yb = 668 - 0.43 * (f - 12)
            yt = 112 - 0.2 * (f - 12)
        end
        local al = math.min(1, math.max(0, (FLASH_MS - t) / 400))
        for k, name in ipairs({ "flash_a", "flash_b" }) do
            local ft = tx(name)
            if ft then
                local cx = (k == 1) and 209 or 1039
                tex.draw_texture(ft.t, { x = (cx - 240) * S, y = (yb - 140) * S, scale = S, fade = al })
                tex.draw_texture(ft.t, { x = (cx - 240) * S, y = (yt - 140) * S, scale = S, fade = al,
                                         mirror = "vertical" })
            end
        end
    end
    local frame_a = math.floor(t / 90) % 2
    local tri = tx((frame_a == 0) and "lower_triangles_1" or "lower_triangles_2")
    if tri then
        tex.draw_texture(tri.t, { x = 0, y = (BOT_Y - 30) * S, scale = S, fade = 0.9 * fade })
        tex.draw_texture(tri.t, { x = 0, y = (TOP_H - tri.h + 30) * S, scale = S, fade = 0.9 * fade,
                                  mirror = "vertical" })
    end
end

-- judge boards (score_board: 1P board 96,108 in the top band; the AI's at 98,481 on the AI lane's obi), rows
-- 良 可 不可 連打 at -25/-8/+9/+26, three digits from +23 leftwards 10 apart
local BOARD_DON = { 97, 108 }
local BOARD_AI = { 99, 481 }   -- inside the AI lane's obi (zdon_ai_lane: the circuit obi has room)
local ROWS = { -25, -8, 9, 26 }
local function draw_board(name, counts, x, y)
    at(name, x, y)
    for r = 1, 4 do
        local s = tostring(math.max(0, math.min(999, math.floor((counts and counts[r]) or 0))))
        for k = 0, #s - 1 do
            at("board_digit", x + 23 - 10 * k, y + ROWS[r], { frame = s:byte(#s - k) - 48 })
        end
    end
end

-- section icons (section_win_icon: mc_icon at 209,-15; the 5 / 3 slot strip at 165,82, icons alternating
-- y 112 / 127 from x 199 every 31: sections left to right); the open one pulses, a closed one shows 勝 or the
-- AI's face, popping in big first
local STRIP = { 165, 82 }
local ICON_X0, ICON_STEP, ICON_Y = 199, 31, { 112, 127 }
local POP_MS = 900
local done = {}

local function draw_icons(b, now)
    local n = b.count
    local first = (n == 3) and 3 or 1                 -- the 3-section layout uses the right three slots
    local strip = tx((n == 3) and "sec_strip_3" or "sec_strip_5")
    if strip then tex.draw_texture(strip.t, { x = STRIP[1] * S, y = STRIP[2] * S }) end
    for i, sec in ipairs(b.sections) do
        local slot = first + i - 1
        local x, y = ICON_X0 + ICON_STEP * (slot - 1), ICON_Y[(slot % 2 == 1) and 1 or 2]
        at("sec_base", x, y)
        if sec.winner >= 0 then
            done[i] = done[i] or now
            local age = now - done[i]
            -- the cabinet's own timeline (section_win_icon sprite 35 = win_effect, 60 fps, anchored at 412,95): the big icon
            -- shrinks 2.71 -> 1.0 in frames 4..10, holds at 1.0 (170 px, direct feed Tl7g8XXXvAM agrees) until frame 100,
            -- then slides 17 px / frame to the left shrinking 0.1 / frame and fades out by frame 107
            local fr = 4 + age * 0.06
            if fr <= 107 then
                local big = (sec.winner == 0) and "sec_win_big" or "sec_lose_big"
                local sc, dx, al = 1, 0, 1
                if fr < 10 then sc = 2.71 - (2.71 - 1) * (fr - 4) / 6
                elseif fr > 100 then
                    local u = fr - 100
                    sc, dx, al = 1 - 0.1 * u, -17.14 * u, 1 - 0.1429 * u
                end
                at(big, 412 + dx, 95, { scale = sc, fade = al })
            end
            at((sec.winner == 0) and "sec_win" or "sec_lose", x, y)
        elseif not b.finished and i == b.section then
            local p = 0.5 + 0.5 * math.sin(now / 160)
            at("sec_pulse", x, y, { fade = 0.2 + 0.5 * p })
        end
    end
end

-- the section timer (time: at 264,174; frame, a 150 px bar, the fill growing from its left; the open section's
-- name left, the next one's right; the last section shows its name only)
local TIMER = { 264, 174 }
local BAR_W = 150
local first_ms
local function draw_timer(b)
    if b.finished or not tex.song_progress then return end
    local pos = tex.song_progress(1)
    local s = b.sections[b.section]
    if not pos or not s then return end
    first_ms = first_ms or pos
    local start = (b.section > 1) and b.sections[b.section - 1].end_ms or first_ms
    local frac = math.max(0, math.min(1, (pos - start) / math.max(1, s.end_ms - start)))
    at("timer_frame", TIMER[1], TIMER[2])
    local bar = tx("timer_bar")
    if bar then
        tex.draw_texture(bar.t, { x = (TIMER[1] - BAR_W / 2) * S, y = (TIMER[2] - 8) * S, x2 = BAR_W * S - bar.w })
    end
    local fill = tx("timer_fill")
    if fill and frac > 0 then
        tex.draw_texture(fill.t, { x = (TIMER[1] - BAR_W / 2) * S, y = (TIMER[2] - 8) * S,
                                   x2 = BAR_W * frac * S - fill.w })
    end
    at("timer_label", TIMER[1] - 87, TIMER[2], { frame = b.section - 1 })
    if b.section < b.count then
        at("timer_label", TIMER[1] + 87, TIMER[2], { frame = b.section })
    end
end

-- the AI's plate (ai_player_name: "AIどん"), at the AI lane's top left (the movie's 0,0 on the lane)
local PLATE_X, PLATE_Y, PLATE_S = -64, 368, 1.0   -- round 14: multi-scale edge match vs feed (9 frames): ours was 0.9x and 37 px right, 10 px up

function AIB.draw_game()
    at("ai_plate", PLATE_X, PLATE_Y, { scale = PLATE_S })
    local b = battle()
    if not b then return end
    local now = tex.get_current_ms()
    if b.section == 1 and b.live_p == 0 and b.live_ai == 0 and next(done) then done, first_ms = {}, nil end
    draw_board("board_don", b.judge_p, BOARD_DON[1], BOARD_DON[2])
    draw_board("board_ai", b.judge_ai, BOARD_AI[1], BOARD_AI[2])
    draw_icons(b, now)
    draw_timer(b)
    -- the genre pill under the title (ai_song_info 4..18; footage hi/br_zoom.png), shown while the title is
    local g = b.genre or -1   -- 0 J-POP, anime, vocaloid, children, variety, classical, game, 7 namco original
    if g >= 0 and g <= 7 and (b.title_alpha or 0) > 0 then
        centered("genre_pill", GENRE_PILL[1], GENRE_PILL[2], g, 1, b.title_alpha)
    end
    -- the end of play (battle_result; footage Tl7g8XXXvAM 4:28): "バトル 勝利" on the laurel over the lanes, or
    -- "バトル 終了" when the AI won; shapes centred on their anchors (end_*: laurel -480,-400, バトル -172,-80,
    -- 勝利 -212,-124, 終了 -208,-208)
    -- the cabinet's battle emblem lands 4.5 s after the last note (footage 4:21-4:26: the song ends, silence, the
    -- emblem, 0.6 s later the voice: the engine delays the cue, skin_config zdon_ai_end_delay)
    if not b.finished then G.end_ms = nil
    elseif not G.end_ms then G.end_ms = now + 4500 end
    if b.finished and now >= G.end_ms then
        local e = now - G.end_ms
        if b.result == "win" then
            -- the cabinet's own timeline (battle_result.lm sprite 76, 149 frames at 60 fps, then the 128-frame loop of
            -- sprite 27): the laurel zooms in from 3x, バトル fades in, 勝利 slams in from 3x and bounces, then the
            -- additive shimmer / sparkles / ring. Objects {shape, x, y, scale, alpha}; positions are the movie's,
            -- the three static shapes keep the anchors measured on the feed (バトル +6, +25)
            local TL = require("global/ai_battle_end_tl")
            local fi = math.floor(e * 0.06)
            local list = (fi < #TL.intro) and TL.intro[fi + 1] or TL.loop[((fi - #TL.intro) % #TL.loop) + 1]
            local NAME = { [14] = { "end_laurel", -480, -400, 0, 0 }, [16] = { "end_battle", -172, -80, 6, 25 },
                           [18] = { "end_win", -212, -124, 0, 0 }, [24] = { "end_shimmer", -420, -320, 0, 0, true },
                           [20] = { "end_spark", -48, -48, 0, 0, true }, [36] = { "end_ring", -570, -570, 0, 0, true } }
            for _, o in ipairs(list) do
                local n = NAME[o[1]]
                local t = n and tx(n[1])
                if t then
                    local k = o[4]
                    tex.draw_texture(t.t, { x = (o[2] + n[4] + n[2] * k) * S, y = (o[3] + n[5] + n[3] * k) * S, scale = k,
                                            fade = o[5], blend = (n[6] or o[6] == 1) and "add" or nil })
                elseif o[1] >= 43 and o[1] <= 74 then
                    -- round 19: confetti triangles / dots (battle_result sprite 53, shapes 43..51, 74), centred, rotating
                    local u = tx("end_cf" .. o[1])
                    if u then
                        local k, cx, cy = o[4], o[2], o[3]
                        local par = { scale = k, fade = o[5], blend = "add" }
                        if math.abs(o[7]) > 0.05 then
                            par.x, par.y = cx * S, cy * S
                            par.origin = { u.w * k * S / 2, u.h * k * S / 2 }
                            par.rotation = o[7]
                        else
                            par.x, par.y = (cx - u.w * k / 2) * S, (cy - u.h * k / 2) * S
                        end
                        tex.draw_texture(u.t, par)
                    end
                end
            end
        else
            local k = 1.0 * (1 + 0.4 * (1 - ease_out(e / 250)))
            local f = math.min(1, e / 150)
            local t = tx("end_over")
            if t then tex.draw_texture(t.t, { x = (634 + -208 * k) * S, y = (361 + -208 * k) * S, scale = k, fade = f }) end
        end
    end
end

-- the AI play's soul gauge (gage_don_1p at 0.4, top left: footage hi/top_zoom.png): the lower bar fills red up to
-- the clear point, yellow after it; rainbow when full; クリア / 魂 lit once cleared. Shape origin -356,-32
-- (712x64): cells x 8..708, bar rows 36..60. True = drawn (the AI's own gauge is not shown)
local GA = { 152, 30, 0.4 }
-- three gauge movies (gage_don_1p_easy / normal / hard), picked by the clear fraction the engine passes (0.58 / 0.68 /
-- 0.78 of the bar). Movie coordinates (stage 1280 wide, shape tx / ty), drawn at 0.4: X(xm) = 7.8 + (xm - 483) * 0.4,
-- Y(ym) = 11.6 + (ym + 56) * 0.4 (fitted on the direct feed: bar rows 28..35, left edge 11). pre = texture prefix,
-- base = base / sep ty, mk = clear mark tx (ty -28), sx / sy = soul tx, ty
local GV = {
    { c = 0.58, pre = "ge_", base = -22.35, mk = 926, sx = 1244.2, sy = -18 },
    { c = 0.68, pre = "g_", base = -25.65, mk = 996, sx = 1241.7, sy = -21.3 },
    { c = 0.78, pre = "gh_", base = -24, mk = 1066, sx = 1242.1, sy = -19.5 },
}
function AIB.draw_ai_gauge(is_2p, points, max_points, clear_points, is_clear, is_rainbow, rainbow_frac)
    if not tx("g_base") then return false end
    if is_2p then return true end
    local s = 0.4
    local max = math.max(1, max_points or 1)
    local f = math.max(0, math.min(1, (points or 0) / max))
    local c = math.max(0, math.min(1, (clear_points or max) / max))
    local v = GV[2]
    for _, g in ipairs(GV) do if math.abs(g.c - c) < math.abs(v.c - c) then v = g end end
    local function X(xm) return 7.8 + (xm - 483) * s end
    local function Y(ym) return 11.6 + (ym + 56) * s end
    local function put(name, xm, ym, frame, fade)
        local t = tx(name)
        if t then tex.draw_texture(t.t, { x = X(xm) * S, y = Y(ym) * S, scale = s, frame = frame, fade = fade }) end
    end
    local btop = v.base - 32
    put(v.pre .. "base", 483, btop)
    if is_rainbow then
        put("g_rainbow", 483, -57.65, math.floor(rainbow_frac or 0) % 8)
    else
        -- the movie's own fill (sprite 51): shape 29 (8x24, red) stretched from x 491 to the clear point (y -20..4); past
        -- it shapes 46 (y -22, h 26) and 34 (y -42, h 24), both yellow, from 10 px after the clear point to x 1187
        local function fill(name, xm, ym, w, h)
            local t = tx(name)
            if t and w > 0 then
                tex.draw_texture(t.t, { x = X(xm) * S, y = Y(ym) * S, x2 = w * s * S - t.w, y2 = h * s * S - t.h })
            end
        end
        local wv = 700 * v.c
        fill("g_fill_red", 491, -20, wv * math.min(f, c) / math.max(c, 1e-6), 24)
        if f > c then
            local w = (f - c) / math.max(1e-6, 1 - c) * (696 - wv - 10)
            fill("g_fill_yel_up", 491 + wv + 10, -42, w, 24)
            fill("g_fill_yel", 491 + wv + 10, -22, w, 26)
        end
    end
    put(v.pre .. "sep", 483, btop, nil, 0.148)   -- the movie places the separators at alpha 0.148
    put(v.pre .. (is_clear and "clear" or "clear_dark"), v.mk - 28, -40)
    put(v.pre .. (is_clear and "soul" or "soul_dark"), v.sx - 36, v.sy - 32)
    return true
end

------------------------------------------------------------------------------------------------ select
-- AI_SELECT: Green's rank panel (ghost/rank_panel ai_rank_panel: mc_main at 0,-8) on the left: the rank
-- ("ランク N", big digits; rank 11 = the "ランク10+" plate), the points to the next rank, the total wins and
-- the wins to the next reward. Digit slots measured from the movie (digits blanked / not blanked).
local RANK_PANEL, WINS_PANEL = { 137, 179 }, { 136, 263 }
local rank_cache = { ms = -1e9 }

centered = function(name, cx, cy, frame, s, fade)
    local t = tx(name)
    if not t then return end
    s = s or 1
    tex.draw_texture(t.t, { x = (cx - t.w * s / 2) * S, y = (cy - t.h * s / 2) * S, scale = s, frame = frame,
                            fade = fade })
end

-- v right-aligned: digit k from the right centred at x0 - step * k
local function number(name, v, x0, y, step, s, max_digits)
    local str = tostring(math.max(0, math.floor(v or 0)))
    if #str > max_digits then str = string.rep("9", max_digits) end
    for k = 0, #str - 1 do
        centered(name, x0 - step * k, y, str:byte(#str - k) - 48, s)
    end
end

-- Green's total-wins rewards (ghostinfo winningparam: the wins each is acquired at, subid = index; the get /
-- next plates aibattle/reward/totalwins get / next are indexed by subid)
local WINS_AT = { 0, 1, 3, 5, 10, 20, 25, 30, 40, 50, 55, 60, 70, 80, 85, 90, 100, 125, 150, 175, 200, 225, 250,
                  275, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 765, 800, 850, 876, 900, 950, 1000, 1100,
                  1200, 1300, 1400, 1500, 1600, 1700, 1765, 1800, 1876, 1900, 2000, 2222, 3000, 3333, 4000, 4444,
                  5000, 5555, 6000, 6666, 7000, 7650, 7777, 8000, 8760, 8888, 9000, 9999 }

-- wins -> the subid acquired at exactly `wins` (nil if none), the next subid still ahead (nil past the last)
local function reward_step(wins)
    local hit
    for i = 2, #WINS_AT do
        if WINS_AT[i] == wins then hit = i - 1 end
        if WINS_AT[i] > wins then return hit, i - 1 end
    end
    return hit, nil
end

local function rank_info()
    local now = tex.get_current_ms()
    if tex.ai_rank and (now - rank_cache.ms > 3000 or now < rank_cache.ms) then
        rank_cache.v, rank_cache.ms = tex.ai_rank(), now
    end
    return rank_cache.v
end

-- points a rank needs (ghostinfo rankparam acquired), to turn a stored points value into "points to the next rank"
local RANK_AT = { 0, 1, 8, 15, 30, 45, 60, 75, 90, 105, 120, 150 }
-- pre = { rank, points, wins }: the values from before this play (the result's panels show them until the emblem
-- is in: footage Tl7g8XXXvAM 4:43-4:46 "ランク 0 / 次ランクまで 1 ポイント / 合計勝利数 0 / 1 勝")
function AIB.draw_rank_panels(x, y, pre)
    x, y = x or 0, y or 0
    local r = rank_info()
    if not r then return end
    if pre then
        r = { rank = pre.rank, next = (pre.rank + 2 <= #RANK_AT) and math.max(0, RANK_AT[pre.rank + 2] - pre.points) or 0 }
    end
    local top = r.next == 0
    centered(top and "rank_panel_max" or "rank_panel", RANK_PANEL[1] + x, RANK_PANEL[2] + y)
    if not top then
        if r.rank >= 10 then
            number("rank_bdigit", r.rank, 193.5 + x, 147.5 + y, 32.5, 0.5, 2)
        else
            number("rank_bdigit", r.rank, 177 + x, 147.5 + y, 32.5, 0.5, 1)
        end
        number("rank_sdigit", r.next, 175.5 + x, 198 + y, 15.5, 0.8, 3)
    end
    local wins = pre and pre.wins or (tex.ai_wins and tex.ai_wins() or 0)
    local _, nxt = reward_step(wins)
    local need = nxt and (WINS_AT[nxt + 1] - wins) or 0
    centered(need > 0 and "wins_panel" or "wins_panel_max", WINS_PANEL[1] + x, WINS_PANEL[2] + y)
    number("rank_wdigit", wins, 217.6 + x, 252.5 + y, 19.2, 0.8, 5)
    if need > 0 then number("rank_sdigit", need, 193 + x, 286 + y, 16, 0.8, 3) end
end

-- the AI room (common_bg) instead of the genre background (SongSelect:draw_background)
function AIB.draw_select_bg()
    -- real footage (ref_real Tl7g8XXXvAM 1:58-2:06): the AI select keeps the genre background; the AI room is
    -- the cut-ins' backdrop only
    do return false end
    local t = tx("select_bg")
    if not t then return false end
    tex.draw_texture(t.t, { x = 0, y = 0, scale = S })
    return true
end

-- the rank-up conditions (ai_rankup_todo rank_r: the next rank's minimum stars per course; the cabinet's top
-- left, here under the "曲をえらぶ" label), the AI's condition (tension: very_low .. very_high = condition
-- 1..5, at 872,575) and the AI itself (the robot with its "AIどん" plate) at the bottom right
local TODO = { 3, 8 }   -- footage: the very top left
local TENSION = { 872, 575 }
local ROBOT = { 1145, 505, 0.8 }   -- footage: the robot stands at the bottom right, ~250 px wide
-- the course-first stage (skin_config zdon_ai_diff_first, the engine's tex.ai_diff_stage() = the cursor; footage
-- Tl7g8XXXvAM 1:50-1:58): a red board over the genre background, tall columns: back, easy, normal, hard, oni, the
-- recommended course, the last one; the cursor's column is yellow
local DIFF_LABELS = {
    ja = { "もどる", "かんたん", "ふつう", "むずかしい", "おに", "おすすめのむずかしさ", "前回あそんだむずかしさ" },
    zh = { "返回", "簡單", "普通", "困難", "魔王", "推薦的難度", "上次遊玩的難度" },
    en = { "Back", "Easy", "Normal", "Hard", "Oni", "Recommended", "Last played" },
}
-- page 1 (round 5): Green's own art only. Every piece is a shape or a sprite render of ghost_song_select.lm (ids in
-- strict/green_audit.md, Round 5), placed where the direct feed Tl7g8XXXvAM t=114 has it (template-matched, <= 1 px)
local C1 = {   -- top left of each column's bbox: back pill (sprite 1003), easy 1000, normal 993, hard 986, oni 979, rec 1008, last 1013
    { "back", 303, 139 }, { "easy", 387, 108 }, { "normal", 485, 113 }, { "hard", 584, 108 }, { "oni", 685, 104 },
    { "rec", 785, 141 }, { "last", 885, 141 },
}
local PLATE_FADE   -- round 20: set while the column info plate fades in (feed: 10.5 frames, alpha only)
local function c1(name, x, y, fade)
    local t = tx(name)
    if t then tex.draw_texture(t.t, { x = x * S, y = y * S, fade = fade or PLATE_FADE }) end
    return t
end
-- round 20: the board opens from the shelf's pink box (feed Tl7g8XXXvAM 112.45 s, idx 35..49 at 59.94 fps): the board
-- texture grows from the box rect (x 464..814, y 237..366) to its own (x 242..1038, y 32..574), x linearly over 11
-- frames and y over 14.5 frames, translucent first, the columns ghosted on it; the screen dim ramps 0 -> full over the
-- same 14 frames. The dim sits UNDER the Don, the robot and the rank plates (sprite 2036 draws backshadow 1021 at depth 9,
-- the dons 865 / 863 at 10 / 11): those stay lit in the feed (chara x0.94, robot x0.77, plate x0.76; bg strips x0.3).
local DISS = { X0 = 464, X1 = 814, Y0 = 237, Y1 = 366, FX = 11, FY = 14.5, A0 = 0.75, DIM = 0.7, FLOOR = 0.40, DELAY = 4.2 }
local HOLES = { { 0, 0, 480, 50 }, { 0, 45, 240, 195 }, { 0, 380, 230, 650 }, { 1020, 430, 1280, 660 }, { 1090, 0, 1280, 130 } }
local SOFT = { { 0, 45, 240, 195, 0.2 }, { 1020, 430, 1280, 660, 0.2 }, { 0, 0, 480, 50, 0.12 } }
local FLOORS = { { 0, 600, 430, 720 }, { 850, 600, 1280, 720 }, { 430, 620, 850, 720 } }
local function rects_minus(list, h)
    local out = {}
    for _, r in ipairs(list) do
        local x0, y0, x1, y1 = r[1], r[2], r[3], r[4]
        if h[3] <= x0 or h[1] >= x1 or h[4] <= y0 or h[2] >= y1 then
            out[#out + 1] = r
        else
            if h[2] > y0 then out[#out + 1] = { x0, y0, x1, h[2] } end
            if h[4] < y1 then out[#out + 1] = { x0, h[4], x1, y1 } end
            local ya, yb = math.max(y0, h[2]), math.min(y1, h[4])
            if h[1] > x0 then out[#out + 1] = { x0, ya, h[1], yb } end
            if h[3] < x1 then out[#out + 1] = { h[3], ya, x1, yb } end
        end
    end
    return out
end
local function dim_screen(u)
    local d = tx("c1_dim")
    if not d then return end
    local function fill(r, a)
        tex.draw_texture(d.t, { x = r[1] * S, y = r[2] * S, x2 = (r[3] - r[1]) * S - d.w, y2 = (r[4] - r[2]) * S - d.h, fade = a })
    end
    local bg = { { 0, 0, 1280, 720 } }
    for _, h in ipairs(HOLES) do bg = rects_minus(bg, h) end
    for _, f in ipairs(FLOORS) do bg = rects_minus(bg, f) end
    for _, r in ipairs(bg) do fill(r, DISS.DIM * u) end
    -- the rank plate, the robot and the top bar are drawn above the shadow in the feed but still read x0.75 / x0.77 / x0.87
    for _, h in ipairs(SOFT) do fill(h, h[5] * u) end
    for _, f in ipairs(FLOORS) do
        local fr = { f }
        for _, h in ipairs(HOLES) do fr = rects_minus(fr, h) end
        for _, r in ipairs(fr) do fill(r, DISS.FLOOR * u) end
    end
end
-- skin key zdon_ai_board_dissolve (Green arcade flow only; Nijiiro has no such key)
function AIB.dissolve_on()
    local k = tex.get_skin_config("zdon_ai_board_dissolve")
    return AIB.arcade_flow() and k ~= nil and (k.x or 0) ~= 0
end

function AIB.draw_columns(cursor, fr)
    -- sprite 1021 (backshadow 1015, board 1018, the columns): board at 243,36
    local d = tx("c1_dim")
    if fr and AIB.dissolve_on() then
        fr = fr - DISS.DELAY   -- the feed's rect starts 6.5 frames after the key, 3 frames after the engine opens the window
        if fr < 0 then return end
        local ux, uy = math.min(1, fr / DISS.FX), math.min(1, fr / DISS.FY)
        dim_screen(uy)
        local bt = tx("c1_board")
        local bx0, by0, bx1, by1 = 242, 32, 242 + (bt and bt.w or 796), 32 + (bt and bt.h or 542)
        local x0 = DISS.X0 + (bx0 - DISS.X0) * ux
        local x1 = DISS.X1 + (bx1 - DISS.X1) * ux
        local y0 = DISS.Y0 + (by0 - DISS.Y0) * uy
        local y1 = DISS.Y1 + (by1 - DISS.Y1) * uy
        local a = DISS.A0 + (1 - DISS.A0) * uy
        local sx, sy = (x1 - x0) / (bx1 - bx0), (y1 - y0) / (by1 - by0)
        local function cs(name, x, y, fade)
            local t = tx(name)
            if not t then return end
            tex.draw_texture(t.t, { x = (x0 + (x - bx0) * sx) * S, y = (y0 + (y - by0) * sy) * S,
                                    x2 = t.w * sx * S - t.w, y2 = t.h * sy * S - t.h, fade = fade })
        end
        cs("c1_board", 242, 32, a)
        for i = 0, 6 do
            local c = C1[i + 1]
            cs("c1_col_" .. c[1] .. (cursor == i and "_s" or "_n"), c[2], c[3], a * a)
        end
        if uy >= 1 then AIB.draw_diff_info(cursor) end
        return
    end
    -- the level panel's first state (decide_course) is on the lit board in the feed (t=128-129 s): no screen dim then
    if fr and AIB.arcade_flow() then
        dim_screen(1)
    elseif d then
        tex.draw_texture(d.t, { x = 0, y = 0, x2 = 1280 * S - d.w, y2 = 720 * S - d.h, fade = 0.8 })
    end
    c1("c1_board", 242, 32)
    for i = 0, 6 do
        local c = C1[i + 1]
        c1("c1_col_" .. c[1] .. (cursor == i and "_s" or "_n"), c[2], c[3])
    end
    AIB.draw_diff_info(cursor)
end

-- ---------------------------------------------------------------------------------------- song board (G7)
-- text helper: cached raw text, drawn centred on cx (virtual 1280x720)
local RT = {}
local function rtext(str, size, fill, outline, ow)
    local key = str .. "|" .. size .. "|" .. fill[1] .. fill[2] .. fill[3] .. "|" .. (outline and outline[1] or 0)
    local t = RT[key]
    if t == nil then
        t = text.create_raw_text(str, math.floor(size * S), fill, outline or { 0, 0, 0, 0 }, false, ow or 3) or false
        RT[key] = t
    end
    return t
end
local function rdraw(str, size, fill, outline, cx, y, ow, left)
    local t = rtext(str, size, fill, outline, ow)
    if not t then return 0 end
    local x = left and cx or (cx - t.width / 2)
    t:draw({ x = math.floor(x * S), y = math.floor(y * S) })
    return t.width
end
local COURSE_NAMES = {
    ja = { "かんたん", "ふつう", "むずかしい", "おに", "おに" },
    zh = { "簡單", "普通", "困難", "魔王", "魔王" },
    en = { "Easy", "Normal", "Hard", "Oni", "Oni" },
}
local COL_NAMES = {
    ja = { [5] = "おすすめのむずかしさ", [6] = "前回あそんだむずかしさ" },
    zh = { [5] = "推薦的難度", [6] = "上次遊玩的難度" },
    en = { [5] = "Recommended", [6] = "Last played" },
}
local function course_name(c)
    local lang = (tex.language and tex.language() or "ja"):sub(1, 2)
    return (COURSE_NAMES[lang] or COURSE_NAMES.ja)[(c or 3) + 1]
end
-- the right info panel of the course columns (footage x 1013..1273, y 155..455): shapes 675 (red body), 680 (pink plate,
-- 全 / 曲, the two crowns, / and 個), the caption 759 / 757 (recommended / last), the course picture 706..712, the
-- star 520 and the digit sets 705 (level), 1291 (counts), all of Green's ghost_song_select
local function num(set, v, x_last, y, step)
    local str = tostring(v)
    for k = #str, 1, -1 do
        c1("c1_" .. set .. "_" .. str:sub(k, k), x_last - (#str - k) * step, y)
    end
end
function AIB.draw_diff_info(cursor)
    local info = tex.ai_diff_info and tex.ai_diff_info()
    local dc = cursor or (tex.ai_diff_stage and tex.ai_diff_stage())
    if not info or not dc then return end
    PLATE_FADE = nil
    if AIB.dissolve_on() then
        -- feed idx 72..83: the plate fades in over ~10.5 frames on its first appearance (alpha only), the content switches
        -- of the later column moves are instant
        local now = tex.get_current_ms()
        if not AIB._pl_last or now - AIB._pl_last > 120 then AIB._pl_t0 = now end
        AIB._pl_last = now
        local u = (now - AIB._pl_t0) * 0.06 / 10.5
        if u < 1 then PLATE_FADE = math.max(0.02, u) end
    end
    c1("c1_pan_body", 1013, 155)
    c1("c1_pan_ov", 1013, 155)
    if dc >= 5 then
        c1(dc == 5 and "c1_cap_rec" or "c1_cap_last", 1014, 156)
        -- the star and the times sign are font text on the cabinet (no shape carries them): the engine font stands in
        local t1 = rtext("\xE2\x98\x85 ", 44, { 232, 28, 100, 255 }, { 0, 0, 0, 255 }, 4)
        if t1 then t1:draw({ x = math.floor(1112 * S), y = math.floor(207 * S) }) end
        local t2 = rtext("\xC3\x97 ", 36, { 0, 0, 0, 255 }, { 0, 0, 0, 255 }, 1)
        if t2 then t2:draw({ x = math.floor(1150 * S), y = math.floor(214 * S) }) end
        local lv = tostring(info.level)
        for k = 1, #lv do c1("c1_dl_" .. lv:sub(k, k), 1172 + (k - 1) * 27 + (#lv == 1 and 13 or 0), 217) end
    end
    c1("c1_pic_" .. math.max(0, math.min(3, info.course or 3)), 1030, 197)
    num("db", info.count, 1134, 281, 27)
    num("dg", info.clear, 1129, 319, 27)
    num("dg", info.fc, 1131, 367, 27)
    local cs = tostring(info.count)
    for k = 1, #cs do
        c1("c1_ds_" .. cs:sub(k, k), 1176 + (k - 1) * 14, 342)
        c1("c1_ds_" .. cs:sub(k, k), 1176 + (k - 1) * 14, 390)
    end
    PLATE_FADE = nil
end

-- vertical title glyphs of the board (one raw text per character)
local BG = {}
local function board_char(c, size, fill, outline)
    local key = c .. "|" .. size .. "|" .. fill[1] .. fill[2] .. fill[3] .. "|" .. outline[1] .. "," .. outline[2] .. "," .. outline[3] .. "," .. (outline[4] or 255)
    local t = BG[key]
    if t == nil then
        t = text.create_raw_text(c, math.floor(size * S), fill, outline, false, 3) or false
        BG[key] = t
    end
    return t
end
-- vertical text: every glyph stacked upright (text objects cannot be turned); Latin letters sit closer
local function vtext(str, cx, y, size, step, fill, outline, maxy, alpha)
    for ch in str:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        local st = (#ch == 1) and step * 0.74 or step
        if y + st > maxy then break end
        local t = board_char(ch, size, fill, outline)
        if t then t:draw({ x = math.floor((cx - t.width / 2) * S), y = math.floor(y * S), fade = alpha }) end
        y = y + st
    end
end

-- page 0 of the AI select (skin_config zdon_ai_page0; direct feed Tl7g8XXXvAM t=110.5-112.5, tex.ai_diff_stage() = -1):
-- the genre shelf (the engine's own, behind) with the "choose by difficulty" box in the focused slot: a red box
-- x 453..828 / y 108..563 under a tab (480..795, 50..108) with the title, the three vertical lines of help text on the
-- right, the star pillar between blue arrows and the four little course mascots under it
local P0_TXT = {
    ja = { "むずかしさからえらぶ", { "すきなむずかしさと", "★の数から", "曲をえらべるよ!!" } },
    zh = { "從難度選擇", { "從喜歡的難度與", "★的數量", "來選曲吧!!" } },
    en = { "Choose by difficulty", { "Pick a song by", "its difficulty", "and its stars!!" } },
}
-- Green's own art (ghost_song_select shapes: tab 1153/1155, face 1621 + bars 1615/1617, title 1206, help text 1364,
-- star pillar + arrows + mascots + bell 1366), cut by the green_lm tools and placed where the direct feed
-- Tl7g8XXXvAM t=111 has them (template-matched, error <= 1 px); only ja has the baked title and help text
local P0 = {
    tab = { 480, 55 }, box = { 443, 94 }, title = { 487, 56 }, help = { 654, 123 }, pillar = { 468, 183 },
}
local function p0_tx(name, fade)
    local t = tx(name)
    if t then
        local o = P0[name:sub(4)]
        tex.draw_texture(t.t, { x = o[1] * S, y = o[2] * S, fade = fade })
    end
    return t
end
-- the box in the focused slot; content = opacity of the pillar and the help text (1 normal, 0 emptied), tab_on
-- draws the tab with its title
local function p0_box(content, rect_a)
    local lang = (tex.language and tex.language() or "ja"):sub(1, 2)
    local TX = P0_TXT[lang] or P0_TXT.ja
    p0_tx("p0_tab")
    p0_tx("p0_box")
    if lang == "ja" and tx("p0_title") then
        p0_tx("p0_title")
    else
        rdraw(TX[1], #TX[1] > 30 and 24 or 30, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, 638, 62, 4)
    end
    if content > 0 then
        p0_tx("p0_pillar", content)
        if lang == "ja" and tx("p0_help") then
            p0_tx("p0_help", content)
        else
            local cols = { 780, 737, 694 }
            for i, line in ipairs(TX[2]) do
                vtext(line, cols[i], 128 + (i == 2 and 12 or 0), 34, 35, { 255, 255, 255, 255 }, { 20, 20, 20, 255 }, 540)
            end
        end
    end
end
-- the board / box rectangles of the transitions (footage 30 fps: the box squeezes into a band, then grows into the
-- board: band x 458..819 / y 227..367 at 112.53 -> board 243..1037 / 36..572 at 112.77)
local BAND = { 458, 227, 361, 140 }
local BOARD = { 243, 36, 794, 536 }
local function lerp_rect(p)
    local r = {}
    for i = 1, 4 do r[i] = BAND[i] + (BOARD[i] - BAND[i]) * p end
    return r
end
local function red_rect(r, a)
    -- the flat red slice of Green's band (shape 1599, 8 x 560) stretched to the rectangle
    local t = tx("c2_red")
    if t then
        tex.draw_texture(t.t, { x = r[1] * S, y = r[2] * S, x2 = r[3] * S - t.w, y2 = r[4] * S - t.h, fade = a })
    end
end
local function track_phase(dc, board)
    local now = tex.get_current_ms()
    local prev = AIB._p0_prev
    if prev == -1 and dc and dc >= 0 then AIB._p0_open = now end        -- shelf box -> course columns
    if prev and prev >= 0 and not dc and board then AIB._p12 = now end           -- columns -> song list (through the box)
    if not board then AIB._p12 = nil end
    AIB._p0_prev = dc or (board and -9 or nil)
    return now
end
function AIB.draw_diff_stage(cursor)
    local now = track_phase(cursor, false)
    if cursor >= 0 then AIB._last_dc = cursor end
    if cursor == -2 then return end              -- the shelf is focused elsewhere
    if cursor < 0 then
        AIB._p0_open = nil
        p0_box(1)
        return
    end
    local p = AIB._p0_open and (now - AIB._p0_open) / 267 or 1
    if p < 1 then
        -- footage 112.50-112.77: a frame of the box, the band (opaque), then a growing translucent red rectangle
        if p < 0.125 then
            p0_box(1)
        else
            p0_box(0.6 * (1 - p))
            local q = (p - 0.125) / 0.875
            if q > 0.4 then AIB.draw_columns(cursor) end
            red_rect(lerp_rect(q), q < 0.4 and 1 or 0.8 * (1 - (q - 0.4) / 0.6) + 0.1)
        end
        return
    end
    AIB.draw_columns(cursor)
end

-- page 2, the course-filtered song board (tex.ai_board(); footage Tl7g8XXXvAM t=116-127). Green's own art only, every piece
-- a ghost_song_select.lm shape or sprite render (ids in strict/green_audit.md, Rounds 5 and 6):
--   band 1599 / 1839 / 1841, header sprite 1216, strips 1615 + 1613 + 1617 + 1619, cursor card = sprite 674 (song_name_detail)
--   frames 1..30 (the widening), lanes = 1028 / 1046 / 1053 / 1063 + stars 1030 + crowns 529 / 531 / 527 + the course icons
--   996 / 989 / 982 / 971 (scale 0.7), crowns on the strips = sprite 1740, arrows 1964, the arena behind the widening card
--   = 1944 + 1946 + 1958, back pill = sprite 1003.
-- The titles, subtitles and lane labels are font text on the cabinet; the engine font stands in (outline = the genre colour
-- the shelf uses, passed by the engine as item.outline).
-- zdon_ai_p23 (Green): the engine holds the chosen card (b.jump = ms since it landed, the don came ~300 ms earlier) and the
-- feed's page 2 -> 3 sequence runs: lanes 0-1.5 s, lanes fade, band + strips into the arena (1.6-1.9 s), the card widens
-- (2.0-2.6 s, sprite 674 frames 1 -> 15 -> 30), then the engine opens the course board.
local STRIP_RIM = { [-1] = 350, [1] = 850 }   -- rim-left of the first strip each side, pitch 100
local CARD_FRAMES = { 1, 4, 7, 10, 13, 15, 18, 21, 24, 27, 30 }
local CARD_OFF = {   -- bbox of each frame's render relative to the sprite origin (593, 93) and its size
    [1] = { -144, 10, 380 }, [4] = { -189, 10, 470 }, [7] = { -234, 10, 560 }, [10] = { -279, 10, 650 },
    [13] = { -324, 10, 740 }, [15] = { -354, 10, 800 }, [18] = { -354, -2, 800 }, [21] = { -354, -14, 800 },
    [24] = { -354, -26, 800 }, [27] = { -354, -45, 814 }, [30] = { -354, -50, 815 },
}
local function ramp(t, a, b) return math.max(0, math.min(1, (t - a) / (b - a))) end
function AIB.draw_song_board()
    local b = tex.ai_board and tex.ai_board()
    if not b then return end
    local t = b.jump and (b.jump + 300) or nil
    local lane_a, rest_a, arena_a, fidx = 1, 1, 0, 1
    if t then
        lane_a = 1 - ramp(t, 1500, 1650)
        rest_a = 1 - ramp(t, 1600, 1900)
        arena_a = ramp(t, 1600, 1900)
        fidx = 1 + math.floor(ramp(t, 2000, 2600) * (#CARD_FRAMES - 1) + 0.5)
    end
    if arena_a > 0 then c1("c3_arena", 0, 0, arena_a) end
    if rest_a > 0 then
        c1("c2_band", 0, 23, rest_a)
        local lv = math.max(1, math.min(10, b.level or 1))
        local course = math.max(0, math.min(3, b.course or 3))
        c1("c2_hd_" .. (course * 10 + lv - 1), (course == 2) and 511 or 512, 37, rest_a)
        for k = 7, 1, -1 do
            for _, sgn in ipairs({ -1, 1 }) do
                local it = b.items[sgn * k]
                if it then
                    local rim = STRIP_RIM[sgn] + sgn * (k - 1) * 100
                    if rim > -90 and rim < 1290 then
                        if it.back then
                            c1("c1_col_back_n", rim + 39 - 31, 139, rest_a)
                        else
                            c1("c2_strip", rim - 7, 95, rest_a)
                            if it.crown and it.crown > 0 then
                                c1(it.crown >= 2 and "c2_crown_gold" or "c2_crown_silver", rim + 19, 77, rest_a)
                            end
                            local o = it.outline or { 96, 48, 140 }
                            vtext(it.title, rim + 40, 135, 36, 35.5, { 255, 255, 255, 255 }, { o[1], o[2], o[3], 255 }, 560, rest_a)
                        end
                    end
                end
            end
        end
        c1("c2_arrow", 362, 280, rest_a)
        local ar = tx("c2_arrow")
        if ar then tex.draw_texture(ar.t, { x = 814 * S, y = 280 * S, mirror = "horizontal", fade = rest_a }) end
    end
    local cur = b.items[0]
    if cur then
        local f = CARD_FRAMES[fidx]
        local o = CARD_OFF[f]
        local cx0, cy0 = 593 + o[1], 93 + o[2]
        c1("c3_card_" .. f, cx0, cy0)
        if cur.back then
            c1("c1_col_back_s", 640 - 31, 139)
        else
            local right = cx0 + o[3] - 1
            local oc = cur.outline or { 20, 20, 20 }
            vtext(cur.title, right - 56, 138, 44, 38, { 255, 255, 255, 255 }, { 20, 20, 20, 255 }, 560)
            if cur.sub and cur.sub ~= "" then
                vtext(cur.sub, right - 101, 282, 28, 25, { 255, 255, 255, 255 }, { 20, 20, 20, 255 }, 560)
            end
            if lane_a > 0 and fidx == 1 then
                for k = 0, 3 do
                    local x = 458 + 60 * k
                    L = cur.levels and cur.levels[k + 1] or -1
                    local a = (L and L > 0) and lane_a or lane_a * 0.4
                    c1("c3_lane_" .. k, x, 210, a)
                    local ic = tx("c3_icon_" .. k)
                    if ic then
                        tex.draw_texture(ic.t, { x = (x + 6) * S, y = 216 * S, scale = 0.7, fade = a })
                    end
                    local cr = "c3_crown_o"
                    if k == (b.course or 3) and cur.crown and cur.crown > 0 then
                        cr = cur.crown >= 2 and "c3_crown_g" or "c3_crown_s"
                    end
                    c1(cr, x + 16, 178, (cr == "c3_crown_o") and a * 0.4 or a)
                    for i = 0, math.min(10, L or 0) - 1 do
                        c1("c3_star", x + 16, 490 - 17 * i, a)
                    end
                end
            end
        end
    end
end


-- page 1 -> page 2 (footage 114.9-116.2): the columns squeeze into the band, the shelf box comes back, its content fades
-- out, the empty box waits (tab and title stay), then it grows into the song list
function AIB.draw_board_page(t)
    if t >= 1250 then AIB.draw_song_board() return end
    if t < 130 then
        local q = t / 130
        AIB.draw_columns(AIB._last_dc or 5)
        red_rect(lerp_rect(1 - q), 0.85)
    elseif t < 350 then
        p0_box(1 - (t - 130) / 220)
    elseif t < 950 then
        p0_box(0)
    else
        local q = (t - 950) / 300
        p0_box(0)
        red_rect(lerp_rect(q), 0.85)
    end
end

-- the pages (box / columns / song board and their transitions): drawn from SongSelect:draw_footer, i.e. above the shelf
-- and below the Don, as on the cabinet (the Don stands in front of the board); the panels follow in draw_select
-- Z-DON strict: the native Diff Sort box title in AI_SELECT is the arcade's official title art
-- (ghost_song_select shape 1206 "むずかしさからえらぶ"), same place as the "Diff Sort" text.
local native_title_max = 0
function AIB.draw_native_title(open_anim, fade)
    if not tex.zdon_ai_select() then return false end
    local ns = tex.get_skin_config("zdon_ai_native_sort")
    if not (ns and (ns.x or 0) ~= 0) then return false end
    local lang = (tex.language and tex.language() or "ja"):sub(1, 2)
    if lang ~= "ja" then return false end
    local t = tx("p0_title")
    if not t then return false end
    native_title_max = math.max(native_title_max, open_anim)
    tex.draw_texture(t.t, { x = P0.title[1] * S, y = P0.title[2] * S + (native_title_max - open_anim), fade = fade })
    if AIB.arcade_flow() then AIB.draw_native_help(native_title_max - open_anim, fade) end
    return true
end

-- round 9: skin_config zdon_ai_arcade_flow (Green, AI_SELECT only). The engine's own Diff Sort window (STATE_DIFF_SORTING)
-- keeps the logic; this is the arcade's presentation of it: the course columns (back, easy, normal, hard, oni, the
-- recommended one, the last one) as the sort window, the red band + "course x level" header over the filtered list.
function AIB.arcade_flow()
    if not tex.zdon_ai_select() then return false end
    local k = tex.get_skin_config("zdon_ai_arcade_flow")
    return k ~= nil and (k.x or 0) ~= 0
end

function AIB.draw_sort_window(w)
    if not AIB.arcade_flow() then return false end
    local b = w:box()
    -- frames (60 fps) since the sort window was first drawn in this open
    local now = tex.get_current_ms()
    if not AIB._sw_last or now - AIB._sw_last > 120 then AIB._sw_t0 = now end
    AIB._sw_last = now
    AIB.draw_columns(b < 0 and 0 or (b <= 3 and b + 1 or (b == 4 and 5 or 6)), (now - AIB._sw_t0) * 0.06)
    return true
end

-- the filtered list's band and header (behind the shelf boxes): sprite/shape renders of ghost_song_select.lm
function AIB.draw_list_band()
    if not AIB.arcade_flow() then return false end
    local v = tex.ai_sort_view and tex.ai_sort_view()
    if not v then return false end
    c1("c2_band", 0, 23)
    local lv = math.max(1, math.min(10, v.level or 1))
    local course = math.max(0, math.min(3, v.course or 3))
    c1("c2_hd_" .. (course * 10 + lv - 1), (course == 2) and 511 or 512, 37)
    return true
end

-- round 10: the filtered list's tall strips in place of the shelf boxes (AI_SELECT, zdon_ai_arcade_flow, list open).
-- Official art: strip = ghost_song_select shapes 1615 + 1613 (stretched) + 1617 + star layer 1619 (alpha 0.5, the recipe
-- of sprite 1631 frame 180), crowns sprite 1740, cursor card sprite 674 frame 61 with the lane pillars 1028/1046/1053/1063
-- and stars 1030. The shelf's own animation moves the boxes (pitch 100, 133 ms cubic, as the feed's 8 frame slide).
function AIB.list_mode()
    if not AIB.arcade_flow() then return false end
    return tex.ai_sort_view ~= nil and tex.ai_sort_view() ~= nil
end

local STRIP_DX, STRIP_Y = 0, 95
local function strip_face(x, y, fade)
    local l, m, r, st = tx("c2_s_l"), tx("c2_s_m"), tx("c2_s_r"), tx("c2_s_star")
    if not (l and m and r and st) then return false end
    tex.draw_texture(m.t, { x = (x + 29) * S, y = y * S, x2 = 32 * S - m.w, fade = fade })
    tex.draw_texture(l.t, { x = x * S, y = y * S, fade = fade })
    tex.draw_texture(r.t, { x = (x + 61) * S, y = y * S, fade = fade })
    tex.draw_texture(st.t, { x = (x + 15) * S, y = (y + 16) * S, x2 = 62 * S - st.w, y2 = 440 * S - st.h,
                             fade = 0.5 * (fade or 1) })
    return true
end

-- a closed song box of the list: the strip, its crown, the vertical title in the genre outline colour
function AIB.draw_list_strip(box, bx, fade)
    if not AIB.list_mode() then return false end
    local x = bx / S + STRIP_DX
    if not strip_face(x, STRIP_Y, fade) then return false end
    local v = tex.ai_sort_view()
    local info = box:course_info(math.max(0, math.min(3, v.course or 3)))
    if info and info.has_score and info.crown and info.crown > 0 then
        c1(info.crown >= 2 and "c2_crown_gold" or "c2_crown_silver", x + 26, 77, fade)
    end
    local o = box:fore_color() or { r = 96, g = 48, b = 140 }
    vtext(box.text_name or "", x + 47, 135, 36, 35.5, { 255, 255, 255, 255 }, { o.r or 96, o.g or 48, o.b or 140, 255 }, 560, fade)
    return true
end

-- the open (cursor) box of the list: the official card with its four lane pillars (sprite 674 frame 61, shapes 1028 /
-- 1046 / 1053 / 1063, stars 1030, crowns 531 / 529 / 527) and the vertical title; before the shelf's open animation starts
-- the cursor is a plain strip
local CARD_DX = -145
function AIB.draw_list_card(box, bx, open_fade)
    if not AIB.list_mode() then return false end
    local fade = 1
    if open_fade <= 0.02 then
        return AIB.draw_list_strip(box, bx, fade)
    end
    local x0 = bx / S + CARD_DX
    c1("c2_card", x0, 103, fade)
    local v = tex.ai_sort_view()
    local o = { 20, 20, 20, 255 }
    local right = x0 + 380 - 1
    vtext(box.text_name or "", right - 56, 138, 44, 38, { 255, 255, 255, 255 }, o, 560, fade)
    local sub = box.text_subtitle or ""
    if sub ~= "" then vtext(sub, right - 101, 282, 28, 25, { 255, 255, 255, 255 }, o, 560, fade) end
    for k = 0, 3 do
        local info = box:course_info(k)
        local L = (info and info.has_course) and info.level or 0
        local a = (L > 0) and fade or fade * 0.4
        local x = x0 + 9 + 60 * k
        c1("c3_lane_" .. k, x, 210, a)
        local ic = tx("c3_icon_" .. k)
        if ic then tex.draw_texture(ic.t, { x = (x + 6) * S, y = 216 * S, scale = 0.7, fade = a }) end
        local cr = "c3_crown_o"
        if info and info.has_score and info.crown and info.crown > 0 then
            cr = info.crown >= 2 and "c3_crown_g" or "c3_crown_s"
        end
        c1(cr, x + 16, 178, (cr == "c3_crown_o") and a * 0.4 or a)
        for i = 0, math.min(10, L) - 1 do c1("c3_star", x + 16, 490 - 17 * i, a) end
    end
    return true
end

-- the list's back box (a column "back" pill, no strip behind it, sprite 1003 frames 9 / 19) and the shelf's folder boxes
-- (not on the arcade list: nothing is drawn)
function AIB.draw_list_back(box, bx, open)
    if not AIB.list_mode() then return false end
    local x = bx / S + (open and (CARD_DX + 160) or 15)
    c1(open and "c1_col_back_s" or "c1_col_back_n", x, 139)
    return true
end

-- the list's arrows: official shape 1964 (core pixels), (362, 280) and mirrored at (814, 280)
function AIB.draw_list_arrows(fade, drift)
    if not AIB.list_mode() then return false end
    local ar = tx("c2_arrow")
    if not ar then return false end
    tex.draw_texture(ar.t, { x = (362 - drift) * S, y = 280 * S, fade = fade })
    tex.draw_texture(ar.t, { x = (814 + drift) * S, y = 280 * S, mirror = "horizontal", fade = fade })
    return true
end

-- round 16: page 0 (course-first box) arrows = the cabinet's own loop, ghost_song_select sprite 1970 (shape 1964 at
-- (640 -/+ 220, 360 - 20), 60-frame loop at 60 fps: 0.5 px per frame outwards, alpha 1 -> 0.09 linear, then restart).
-- Feed blob x 402 / 827 = phase 8 (texture left 364); the PyTaiko pulse swept 369..404 and never got there.
function AIB.draw_p0_arrows()
    if not AIB.arcade_flow() then return false end
    local ar = tx("c2_arrow")
    if not ar then return false end
    local p = math.floor(tex.get_current_ms() * 0.06) % 60
    local a = 1 - p * 0.0168
    local d = 0.5 * p
    tex.draw_texture(ar.t, { x = (368 - d) * S, y = 281 * S, fade = a })
    tex.draw_texture(ar.t, { x = (808 + d) * S, y = 281 * S, mirror = "horizontal", fade = a })
    return true
end

-- round 16: the shelf strip of the new-song folder carries the cabinet's "shin" tag (ghost_song_select shape 1707, the
-- feature board's icon bubble; centre 889,60 on the feed's strip at x 844). The feed tints it green with its colour_change
-- shader; the art is drawn as it is in the data (no recolour).
function AIB.draw_shelf_tag(name, bx)
    if not AIB.arcade_flow() or AIB.list_mode() then return end
    if not name or not name:find("新曲", 1, true) then return end
    local t = tx("tag_new")
    if t then tex.draw_texture(t.t, { x = bx - 7 * S, y = 8 * S }) end
end

-- the help text of the page-0 box (shape 1364, ja only; the other languages keep the engine's box without it)
function AIB.draw_native_help(dy, fade)
    local lang = (tex.language and tex.language() or "ja"):sub(1, 2)
    if lang ~= "ja" then return end
    local t = tx("p0_help")
    if t then tex.draw_texture(t.t, { x = P0.help[1] * S, y = P0.help[2] * S + dy, fade = fade }) end
end

function AIB.draw_stage()
    local dc = tex.ai_diff_stage and tex.ai_diff_stage()
    local board = tex.ai_board and tex.ai_board()
    if dc then
        AIB.draw_diff_stage(dc)
    else
        track_phase(nil, board)
    end
    if board then AIB.draw_board_page(AIB._p12 and tex.get_current_ms() - AIB._p12 or 1e9) end
end

-- page 1: the feed darkens the floor (red / teal plates) under the dim too; the footer texture is drawn after the stage,
-- so the floor gets its own dim here (the bottom pill and the 1P plate, drawn later, stay bright as in the feed)
function AIB.draw_floor_dim()
    local dc = tex.ai_diff_stage and tex.ai_diff_stage()
    if not dc or dc < 0 then return end
    local d = tx("c1_dim")
    if not d then return end
    local function dim(x, y, w, h)
        tex.draw_texture(d.t, { x = x * S, y = y * S, x2 = w * S - d.w, y2 = h * S - d.h, fade = 0.8 })
    end
    dim(0, 600, 430, 120)
    dim(850, 600, 430, 120)
    dim(430, 620, 420, 100)
end

-- strict green8b: AI_SELECT-only draw offsets (Green skin_config zdon_ai_off_<name> {x, y} in 1280x720 px)
function AIB.sel_off(name)
    if not tex.zdon_ai_select() then return 0, 0 end
    local o = tex.get_skin_config("zdon_ai_off_" .. name)
    if not o then return 0, 0 end
    return (o.x or 0) * S, (o.y or 0) * S
end

-- strict round 12: the level step's pillars panel (Green AI select, zdon_ai_arcade_flow). Official art: ghost_song_select
-- sprite 361 (support_course) state select_lv, shapes 312/314/317 (panel + glow), 307 (1P badge), 344..350 etc. = one
-- baked pillar per star level 1..13 (mascot, fill, "レベル n" digits), 320 (cursor strip), 354 (arrows), 359 (banner).
-- Position: the settled panel origin (222, 579) measured on the direct feed (frame t=129 s, MSE 1161 over the panel);
-- slide / fade: sprite 362 frames 10..30 in (25 px per frame from below, overshoot at 24, settles at 30) and 40..59 out.
local LVP = { first = nil, X = 222, Y_MAIN = 579, PX = { -117, -39, 38, 116 }, SLIDE0 = 579 + 356 }
local LV_IN_TY = { [10] = -24.9, [11] = -49.8, [12] = -74.6, [13] = -99.5, [14] = -124.3, [15] = -149.2, [16] = -174.1,
    [17] = -198.9, [18] = -223.8, [19] = -248.7, [20] = -273.6, [21] = -298.4, [22] = -323.2, [23] = -348.1,
    [24] = -373, [25] = -370.1, [26] = -367.4, [27] = -364.5, [28] = -361.6, [29] = -358.9, [30] = -356 }
local LV_INTRO_MS = 4000
local LV_IN_A = { [10] = 0.199, [11] = 0.398, [12] = 0.602, [13] = 0.801 }
local LV_OUT_A = { [55] = 0.801, [56] = 0.602, [57] = 0.398, [58] = 0.199 }
-- round 14: the panel belongs to the course board (feed t=127-131): the engine (song_select/player.cpp) opens it on a
-- don at a course of the board; p.lit = decide_course (board lit), else select_lv (board dimmed, 1P badge, strip, arrows)
-- round 14: the AI select's song counter is white text with a black outline and no pill (feed t=111-129), the same text
-- the result header uses; the engine skips its pill in the arcade flow (SongSelectScreen::draw_overlays)
local CNT = { x = 991, y = 26, size = 44 }
function AIB.draw_song_counter()
    if not AIB.arcade_flow() or not tex.song_number then return false end
    local fmt = tex.skin_text and tex.skin_text("song_num") or ""
    if fmt == "" then fmt = "{0}" end
    rdraw((fmt:gsub("{0}", tostring(tex.song_number()))), CNT.size, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, CNT.x, CNT.y, 5, true)
    return true
end

-- the select_lv state dims the board and the floor to 0.67 (feed t=129 vs t=128: board, tabs, floor x0.65-0.70; the rank
-- panels, the rank-up plate, the ranking panel, the robot, the counter and the timer stay bright), and the dim stays
-- while the panel slides out until the loading card (t=131). Drawn first in draw_select, under those widgets.
function AIB.draw_level_dim()
    if not AIB.arcade_flow() or not tex.ai_level_panel then return end
    local p = tex.ai_level_panel()
    if not p or p.lit then return end
    local d = tx("c1_dim")
    if d then tex.draw_texture(d.t, { x = 0, y = 0, x2 = 1280 * S - d.w, y2 = 720 * S - d.h, fade = 0.33 }) end
end

function AIB.draw_level_panel()
    if not AIB.arcade_flow() or not tex.ai_level_panel then return end
    local p = tex.ai_level_panel()
    if not p then LVP.first = nil; return end
    local now = tex.get_current_ms()
    local ty, alpha
    if p.out then
        local f = math.floor(39 + p.out * 60 / 1000)
        if f >= 59 then return end
        if f < 40 then f = 40 end
        ty = -356 + 17.8 * (f - 39)
        alpha = f >= 55 and (LV_OUT_A[f] or 0) or 1
    else
        local f = math.floor(9 + p.ms * 60 / 1000)
        if f < 10 then return end
        f = math.min(f, 30)
        ty = LV_IN_TY[f]
        alpha = LV_IN_A[f] or 1
    end
    local top = p.top or 4
    local lv = math.max(1, math.min(top, p.level or 1))
    if not LVP.first or LVP.course ~= p.course then LVP.course = p.course; LVP.first = math.max(1, math.min(lv, top - 3)) end
    if lv < LVP.first then LVP.first = lv elseif lv > LVP.first + 3 then LVP.first = lv - 3 end
    local ox, oy = LVP.X, LVP.SLIDE0 + ty
    local function draw(name, x, y)
        local t = tx(name)
        if t then tex.draw_texture(t.t, { x = x * S, y = y * S, fade = alpha }) end
    end
    -- state "decide_course" (sprite 361 labels decide_course .. to_select_lv; feed t=128-129 s): the panel shows shape 305
    -- (header "えらべる むずかしさのレベル"), no 1P badge, no cursor strip, no arrows; the first level move (or 4 s)
    -- leaves for the "select_lv" state (shape 317 + 1P badge + strip + arrows; feed t=130-131 s)
    local intro = p.lit and not p.out
    if intro then draw("lvx_intro", ox - 232, oy - 258) else draw("lv_panel", ox - 230, oy - 258) end
    for k = 0, 3 do
        local l = LVP.first + k
        local cx = ox + LVP.PX[k + 1]
        if l == lv and not intro then draw("lv_strip", cx - 1 - 35, oy - 7 - 153) end
        draw("lv_p" .. l, cx - 42, oy - 19.5 - 122)
    end
    if not intro then
        if LVP.first > 1 then draw("lv_arrow_l", ox - 170 - 25, oy - 10 - 25) end
        if LVP.first + 3 < top then draw("lv_arrow_r", ox + 170 - 25, oy - 10 - 25) end
    end
    draw("lv_banner", ox - 2 - 172, oy + 121 - 20)
end

function AIB.draw_select(state)
    AIB.draw_level_dim()
    local dc = tex.ai_diff_stage and tex.ai_diff_stage()
    local r = rank_info()
    local todo = tx("rankup_todo")
    if todo and r then
        local tdx, tdy = AIB.sel_off("rankup")
        tex.draw_texture(todo.t, { x = TODO[1] * S + tdx, y = TODO[2] * S + tdy, frame = math.max(0, math.min(11, r.rank)) })
    end
    local pdx, pdy = AIB.sel_off("panels")
    AIB.draw_rank_panels(pdx / S, 6 + pdy / S)
    AIB.draw_level_panel()
    local robot = tx("robot")
    if robot then
        local bob = 4 * math.sin(tex.get_current_ms() / 420)
        tex.draw_texture(robot.t, { x = (ROBOT[1] - robot.w * ROBOT[3] / 2) * S,
                                    y = (ROBOT[2] - robot.h * ROBOT[3] / 2 + bob) * S, scale = ROBOT[3] })
    end
    local ten = tx("zdon_tension")   -- tension.png without upstream's crop (song_select/ai_battle)
    if ten and tex.ai_condition then
        local c = math.max(1, math.min(5, tex.ai_condition()))
        tex.draw_texture(ten.t, { x = TENSION[1] * S, y = TENSION[2] * S, frame = c - 1 })
    end
end

------------------------------------------------------------------------------------------------ result
-- RESULT_2P of an AI battle, in the place of the 2P board (the lower half, where the cabinet's AI result has
-- these, result_section: section marks from 116,485 every 128 (y 485 / 539), 3 sections from 300; the battle
-- emblem (total_result "バトル勝利" / the AI's face) at 678,300; the rank and wins panels where win_board sits);
-- the background is result_bg's win / lose (drawn from ResultBackground:draw)
local MARK_X0 = { [5] = 116, [3] = 300 }
local MARK_STEP, MARK_Y = 128, { 485, 539 }
local MARK_S = 1.0   -- strict audit: direct feed diamonds are 175 px wide (200 px slot at 0.87..1.0), was 0.7
-- footage (Tl7g8XXXvAM, 10 fps, t 283-287): the marks stay black while the score counts up; 1.8 s after the count-up
-- ends all of them turn at once (285.3-285.5), the emblem lands 1.0 s later (286.4)
local MARK_FIRST_MS, MARK_EVERY_MS, EMBLEM_MS = 1750, 0, 897   -- round 19: the score row ends 20 frames later, marks -20; round 20: emblem -20 more (measured onset: feed T0+544, ours was +564)
local PILL_LEAD_MS = -753   -- the pills / notes keep their round 18 time   -- round 18: marks +17 frames, emblem +40 (60 fps feed measurement)
-- after the 1P side has counted its score up (footage: the cut-ins come ~20 s into the result)
local OVERLAY_AFTER_MS, OVERLAY_MS, OVERLAY_FADE_MS = 6500, 3800, 250   -- footage: first cut-in 290.5 s, count-up ended 283.5 s
local EMBLEM = { win = { 678, 300 }, lose = { 680, 293 } }
local RR = { t0 = nil, last = -1e9, played = {} }

-- result sounds, each once per result screen (result/ai: section, win, lose, fanfare; result/aivoice: ...)
local function once(key, name, preset)
    if RR.played[key] then return end
    RR.played[key] = true
    if audio and audio.has_sound and audio.has_sound(name) then audio.play_sound(name, preset or "sound") end
end

function AIB.draw_result_bg()
    if not AIB.active() then return false end
    local b = battle()
    if not b or not b.finished then return false end
    local t = tx((b.result == "lose") and "bg_lose" or "bg_win")
    if not t then return false end
    tex.draw_texture(t.t, { x = 0, y = 0, scale = S })
    return true
end

-- the detail view (AiResultSectionMain SwitchSection, the engine flips b.detail on a kat): result_section's cards
-- (205, 168x256) where its section5 / section3 sprites put them, each with the section's small mark (207 / 209 at
-- +37,-76) and the player's 良 / 可 / 不可 / 連打数 (rows at -2, 31, 64, 97; small digits 23..41 right-aligned at +57)
local draw_detail, draw_footer
local DETAIL_CARDS = {
    [5] = { { 168, 510 }, { 328, 536 }, { 488, 510 }, { 648, 536 }, { 808, 510 } },
    [3] = { { 322.1, 510 }, { 510.5, 528 }, { 699, 510 } },
}
local DETAIL_ROWS = { -2, 31, 64, 97 }
draw_detail = function(b)
    local pos = DETAIL_CARDS[b.count]
    if not pos or not tx("det_card") then return false end
    for i, sec in ipairs(b.sections) do
        local p = pos[i]
        if p then
            centered("det_card", p[1], p[2])
            if sec.winner >= 0 then centered((sec.winner == 0) and "det_win" or "det_lose", p[1] + 37, p[2] - 76) end
            local vals = { sec.good, sec.ok, sec.bad, sec.roll }
            for r = 1, 4 do
                local v = tostring(math.max(0, math.min(9999, math.floor(vals[r] or 0))))
                for k = 0, #v - 1 do
                    centered("det_digit", p[1] + 57 - 13 * k, p[2] + DETAIL_ROWS[r], v:byte(#v - k) - 48)
                end
            end
        end
    end
    return true
end

-- the footer prompts once the cut-ins are over (footage 4:50: "(rim) フチでくわしく表示 (face) 面でおわり")
draw_footer = function(b, now)
    if RR.pages and not RR.pages.done_ms then return end
    -- strict audit (round 2): measured on direct feed t=288: circles 48 px at x 810 / 1052, y 687; texts centred 928 / 1133
    centered("hint_rim", 810, 687, nil, 0.94)
    -- strict green8b: the visible text runs 850-1007 (157 px) and 1085-1180; the art has uneven padding, so the boxes
    -- sit at 929 (scale 0.955) and 1170 to put the visible texts there
    centered(b.detail and "hint_back_text" or "hint_detail_text", 929, 687, nil, 0.955)
    centered("hint_rim", 1052, 687, nil, 0.94)
    -- round 16: the cabinet's own loop (result_section sprite 289: circles 283 / 286, 120 frames at 60 fps): the rim
    -- circle's two kat halves (279) rise 0 -> 1 over frames 0..29 and fall to 0 by 59, its arrows (281) fade 1 -> 0
    -- over 0..59 while sliding 7 px outwards, the don circle's red overlay (284) follows the halves; frames 60..119
    -- are the plain circles (feed f184..f192: overlays at every even second, plain at every odd one)
    local ph = tex.get_skin_config("zdon_ai_indicator_phase")
    if ph and (ph.x or 0) ~= 0 and tex.get_texture("ai_battle/hint_kat") then
        local f = ((now - RR.t0) % 2000) * 0.06
        local a = 0
        if f < 29 then a = f / 29 elseif f < 59 then a = 1 - (f - 29) / 30 end
        local aa = (f < 59) and (1 - f / 59) or 0
        local mv = 7 * math.min(f, 59) / 59
        local k = 0.94
        local function at(name, cx, cy, mirror, alpha)   -- cx, cy = the texture's centre
            local t = tx(name)
            if not t or alpha <= 0 then return end
            tex.draw_texture(t.t, { x = (cx - t.w * k / 2) * S, y = (cy - t.h * k / 2) * S, scale = k,
                                    mirror = mirror and "horizontal" or nil, fade = alpha })
        end
        if a > 0 then
            at("hint_kat", 810 - 12 * k, 687, false, a)
            at("hint_kat", 810 + 12 * k, 687, true, a)
            centered("hint_red", 1052, 687, nil, 0.94, a)
        end
        if aa > 0 then
            at("hint_arrow", 810 - (27 + mv) * k, 687, false, aa)
            at("hint_arrow", 810 + (27 + mv) * k, 687, true, aa)
        end
    else
        centered("hint_red", 1052, 687, nil, 0.94)
    end
    centered("hint_end2_text", 1172, 687, nil, 1.08)
end

function AIB.draw_result()
    local b = battle()
    if not b or not b.finished then return end
    local now = tex.get_current_ms()
    if now - RR.last > 1000 then RR.t0, RR.played, RR.pages, RR.revealed_ms = now, {}, nil, nil end
    RR.last = now
    -- the marks and the emblem follow the end of the score count-up (b.revealed); a safety net for a result that
    -- never reports it
    if b.revealed and not RR.revealed_ms then RR.revealed_ms = now end
    -- the safety net latches (a late real reveal must not take the marks back)
    if not RR.revealed_ms and (now - RR.t0) > 14000 then RR.revealed_ms = RR.t0 + 12000 end
    local age = RR.revealed_ms and (now - RR.revealed_ms) or -1e6
    local n = b.count
    if b.detail and draw_detail(b) then
        draw_footer(b, now)
        return
    end
    for i, sec in ipairs(b.sections) do
        local x = (MARK_X0[n] or MARK_X0[5]) + MARK_STEP * (i - 1)
        local y = MARK_Y[(i % 2 == 1) and 1 or 2]
        centered((i % 2 == 1) and "slot_a" or "slot_b", x, y, nil, MARK_S)
        local t_in = age - (MARK_FIRST_MS + MARK_EVERY_MS * (i - 1))
        if t_in >= 0 and sec.winner >= 0 then
            once("sec" .. i, "ai_section")
            local k = (t_in < 200) and (1.5 - 0.5 * ease_out(t_in / 200)) or 1
            centered((sec.winner == 0) and "mark_win" or "mark_lose", x, y, nil, MARK_S * k)
        end
    end
    -- "N区" over every mark, on top of all the diamonds (they overlap; footage Tl7g8XXXvAM 4:50: the 3-section
    -- layout numbers its own sections 1..3)
    for i = 1, #b.sections do
        local x = (MARK_X0[n] or MARK_X0[5]) + MARK_STEP * (i - 1)
        local y = MARK_Y[(i % 2 == 1) and 1 or 2]
        centered("sec_label", x + 1, y - 68, math.min(4, i - 1), 1.2)
    end
    local e = age - (MARK_FIRST_MS + MARK_EVERY_MS * n + EMBLEM_MS)
    if e >= 0 then
        local key = (b.result == "lose") and "lose" or "win"
        -- the voice keeps its audio-matched time (round 20 moved the emblem 20 frames earlier: EMBLEM_MS 1230 -> 897)
        if e >= 1230 - 897 then once("emblem", (key == "win") and "ai_win" or "ai_lose") end
        local t = tx("emblem_" .. key)
        if t and tex.get_skin_config("zdon_green_strict") and tx("emb_231") then
            -- round 19: the cabinet's own emblem timeline (result_section.lm sprite 272 "in", then the badge sprite 258 /
            -- 270 with its halo, rays and sparks), anchored at (889, 502) like the static emblem
            local TL = require("global/ai_battle_emblem_tl")
            local fi = math.floor(e * 0.06)
            local pre = (key == "win") and TL.win_in or TL.lose_in
            local main = (key == "win") and TL.win_main or TL.lose_main
            local loop = (key == "win") and TL.win_loop or TL.lose_loop
            local list
            if fi < #pre then
                list = pre[fi + 1]
            elseif fi - #pre < #main then
                list = main[fi - #pre + 1]
            else
                list = loop[((fi - #pre - #main) % #loop) + 1]
            end
            for _, o in ipairs(list) do
                local u = tx("emb_" .. o[1])
                if u then
                    local k = o[4]
                    local cx, cy = 889 + o[2], 502 + o[3]
                    local par = { scale = k, fade = o[5], blend = (o[6] == 1) and "add" or nil }
                    if math.abs(o[7]) > 0.05 then
                        par.x, par.y = cx * S, cy * S
                        par.origin = { u.w * k * S / 2, u.h * k * S / 2 }
                        par.rotation = o[7]
                    else
                        par.x, par.y = (cx - u.w * k / 2) * S, (cy - u.h * k / 2) * S
                    end
                    tex.draw_texture(u.t, par)
                end
            end
        elseif t then
            local s = 1.4 - 0.4 * ease_out(e / 250)
            local cx, cy = EMBLEM[key][1] + t.w / 2, EMBLEM[key][2] + t.h / 2
            tex.draw_texture(t.t, { x = (cx - t.w * s / 2) * S, y = (cy - t.h * s / 2) * S, scale = s,
                                    fade = math.min(1, e / 150) })
        end
    end
    -- the rank and wins panels; once the emblem is in, a rank up / a reward got replace them with the cabinet's
    -- tags "ランクアップ！" / "ごほうびゲット！" (footage 4:50, result_section 164 / 166 / 169 at 1160,440 / 520)
    local wins_now = tex.ai_wins and tex.ai_wins() or 0
    local got_now = reward_step(wins_now)
    local tags = {}
    if b.rank and b.rank > (b.rank_before or b.rank) then tags[#tags + 1] = "tag_rankup" end
    if b.result == "win" and got_now then tags[#tags + 1] = "tag_reward" end
    -- the notes above them (footage: "新 この曲で初バトル勝利", "難 条件の難易度をこえて勝利"; a win below the
    -- course's minimum: "ランクアップ条件未達成"), result_section 178 / 175 / 172 at 1160,343 / 372
    local notes = {}
    if b.first_win then notes[#notes + 1] = "note_first" end
    if b.bonus_high then notes[#notes + 1] = "note_high" end
    if b.result == "win" and (b.rank_gain or 0) == 0 and (b.rank or 0) < 11 then notes[#notes + 1] = "note_unmet" end
    local pe = e + PILL_LEAD_MS
    if pe >= 300 then
        -- round 14: multi-scale edge match vs feed f190: the notes are 1.0x (ours was 0.83x), centres (1170, 345) / (1151, 379)
        local NOTE_AT = { note_first = { 1170, 345, 1.0 }, note_high = { 1151, 379, 1.0 } }
        for k, name in ipairs(notes) do
            local at = NOTE_AT[name] or { 1160, 343 + 29 * (k - 1), 0.83 }
            centered(name, at[1], at[2], nil, at[3])
        end
    end
    if pe >= 300 and #tags > 0 and tx("tag_bg") then
        for k, name in ipairs(tags) do
            local ty = 440 + 80 * (k - 1)
            local sc = 1.0 * (1 + 0.3 * (1 - ease_out((pe - 300 - 150 * (k - 1)) / 250))) -- strict round 11: feed pills are ~1.15x (state-matched f190)
            if pe - 300 >= 150 * (k - 1) then
                centered("tag_bg", 1160, ty, nil, sc)
                centered(name, 1160, ty, nil, sc)
            end
        end
    else
        AIB.draw_rank_panels(1023, 290, b.rank_before and { rank = b.rank_before, points = b.points_before or 0,
            wins = math.max(0, wins_now - (b.result == "win" and 1 or 0)) } or nil)
    end
    if #tags == 0 and b.rank_gain and b.rank_gain > 0 and text and text.create_raw_text then
        local label = string.format("+%d", b.rank_gain)
        if b.rank > (b.rank_before or b.rank) then label = label .. "  RANK UP!" end
        local t = text.create_raw_text(label, 22, { 255, 255, 255, 255 }, { 0, 90, 70, 255 }, false, 3, 1.0)
        if t then t:draw({ x = math.floor((1270 - t.width) * S), y = math.floor(384 * S) }) end
    end
    -- the cut-ins follow the score count-up (b.revealed: the result's players are done), OVERLAY_AFTER_MS later
    local since = RR.revealed_ms and (now - RR.revealed_ms) or -1
    if since >= OVERLAY_AFTER_MS and e >= 1230 - 897 then AIB.draw_result_overlays(b, since - OVERLAY_AFTER_MS) end
    -- strict audit (round 2): the footer prompts are up from the start of the result (direct feed Tl7g8XXXvAM t=277.5-291)
    -- and only the cut-in pages take them away (draw_footer)
    draw_footer(b, now)
end

-- after the emblem, the cabinet's cut-ins in turn (then the remind, below): the rank up (rankup: the "ランク" board with the new rank and
-- its title plate "AIバトルランク：N") and the total-wins reward (reward reward_in: "合計 N 勝達成", the reward
-- got, "次のごほうび [plate] まで N 勝", or "すべてのごほうびをゲットした！" past the last)
local function digits(name, v, cx, cy, step, s, fade)
    local str = tostring(v)
    local x0 = cx + step * (#str - 1) / 2
    for k = 0, #str - 1 do centered(name, x0 - step * k, cy, str:byte(#str - k) - 48, s, fade) end
end

local function anchored(name, x, y, frame, fade, scale)
    local t = tx(name)
    if t then tex.draw_texture(t.t, { x = x * S, y = y * S, frame = frame, fade = fade, scale = scale }) end
end

-- rankup.lm shapes (rk_*: top left relative to the anchor); the board, "ランク" and the big number at 736,212
-- (0..9, "10", "10+"); page 1: the title got in the ごほうびゲット box (plate at 638,448); page 2: the white box at
-- 640,440 with "つぎのランクまで N ポイント" (N at 700,354), the next rank's conditions (pill + stars at 640,430: rank
-- r shows ghostinfo row r+1; rank 10: the task folder) and the help lines
local RK_HEAD = { [0] = 0, 0, 0, 1, 1, 2, 2, 3, 3, 3 }
-- strict green17: the robot on the rank / reward / remind pages is its own sprite on the movie's path (rankup.lm sprite 195
-- = reward.lm 141 = remind.lm 84, shape 193 / 141 / 84 = result/ai_battle/robot, 296x256, anchored at its bottom centre:
-- 181.3,720 on the rank page, 193,721.5 on the reward page, 193,721.45 on remind). Per frame (60 fps) the movie's world
-- offset dy of the anchor and its y scale sy (lumen_anim_dump); rank / reward loop every 250 frames (hop at 80..120),
-- remind plays 500. The page backgrounds no longer carry the robot.
local RB_RANK = {[80]={-0.25,0.9766},[81]={-0.5,0.9531},[82]={-0.75,0.9297},[83]={-1,0.9062},[84]={-0.8,0.9297},[85]={-0.5,0.9531},[86]={-0.3,0.9766},[88]={-10.15,1.0054},[89]={-20.3,1.0108},[90]={-30.45,1.0162},[91]={-40.6,1.0216},[92]={-50.75,1.027},[93]={-60.9,1.0325},[94]={-71.05,1.0379},[95]={-81.2,1.0433},[96]={-91.35,1.0487},[97]={-101.5,1.0541},[98]={-111.65,1.0595},[99]={-121.8,1.0649},[100]={-131.95,1.0703},[101]={-122.55,1.0653},[102]={-113.05,1.0603},[103]={-103.65,1.0553},[104]={-94.25,1.0502},[105]={-84.8,1.0452},[106]={-75.4,1.0402},[107]={-65.9,1.0352},[108]={-56.55,1.0301},[109]={-47.15,1.0251},[110]={-37.65,1.0201},[111]={-28.25,1.0151},[112]={-18.85,1.0101},[113]={-9.4,1.005},[115]={-0.25,0.9766},[116]={-0.5,0.9531},[117]={-0.75,0.9297},[118]={-1,0.9062},[119]={-0.65,0.9375},[120]={-0.35,0.9688}}
local RB_REMIND = {[1]={-0.25,0.9766},[2]={-0.5,0.9531},[3]={-0.75,0.9297},[4]={-1,0.9062},[5]={-0.8,0.9297},[6]={-0.5,0.9531},[7]={-0.3,0.9766},[9]={-14.65,1.0078},[10]={-29.3,1.0156},[11]={-44,1.0234},[12]={-58.65,1.0312},[13]={-73.3,1.0391},[14]={-87.95,1.0469},[15]={-102.65,1.0547},[16]={-117.3,1.0625},[17]={-131.95,1.0703},[18]={-118.75,1.0633},[19]={-105.5,1.0562},[20]={-92.35,1.0492},[21]={-79.15,1.0422},[22]={-65.95,1.0352},[23]={-52.8,1.0281},[24]={-39.6,1.0211},[25]={-26.35,1.0141},[26]={-13.2,1.0071},[28]={-0.25,0.9766},[29]={-0.5,0.9531},[30]={-0.75,0.9297},[31]={-1,0.9062},[32]={-0.65,0.9375},[33]={-0.35,0.9688},[173]={-0.25,0.9766},[174]={-0.5,0.9531},[175]={-0.75,0.9297},[176]={-1,0.9062},[177]={-0.8,0.9297},[178]={-0.5,0.9531},[179]={-0.3,0.9766},[181]={-14.65,1.0078},[182]={-29.3,1.0156},[183]={-44,1.0234},[184]={-58.65,1.0312},[185]={-73.3,1.0391},[186]={-87.95,1.0469},[187]={-102.65,1.0547},[188]={-117.3,1.0625},[189]={-131.95,1.0703},[190]={-118.75,1.0633},[191]={-105.5,1.0562},[192]={-92.35,1.0492},[193]={-79.15,1.0422},[194]={-65.95,1.0352},[195]={-52.8,1.0281},[196]={-39.6,1.0211},[197]={-26.35,1.0141},[198]={-13.2,1.0071},[200]={-0.25,0.9766},[201]={-0.5,0.9531},[202]={-0.75,0.9297},[203]={-1,0.9062},[204]={-0.65,0.9375},[205]={-0.35,0.9688},[345]={-0.25,0.9766},[346]={-0.5,0.9531},[347]={-0.75,0.9297},[348]={-1,0.9062},[349]={-0.8,0.9297},[350]={-0.5,0.9531},[351]={-0.3,0.9766},[353]={-14.65,1.0078},[354]={-29.3,1.0156},[355]={-44,1.0234},[356]={-58.65,1.0312},[357]={-73.3,1.0391},[358]={-87.95,1.0469},[359]={-102.65,1.0547},[360]={-117.3,1.0625},[361]={-131.95,1.0703},[362]={-118.75,1.0633},[363]={-105.5,1.0562},[364]={-92.35,1.0492},[365]={-79.15,1.0422},[366]={-65.95,1.0352},[367]={-52.8,1.0281},[368]={-39.6,1.0211},[369]={-26.35,1.0141},[370]={-13.2,1.0071},[372]={-0.25,0.9766},[373]={-0.5,0.9531},[374]={-0.75,0.9297},[375]={-1,0.9062},[376]={-0.65,0.9375},[377]={-0.35,0.9688}}
local RB_T, RB_FADE = 0, 1   -- ms since the page came up (set by draw_result_overlays)
local function draw_page_robot(kind)
    local t = tx("robot")
    if not t then return end
    local path, n, ax, ay = RB_RANK, 250, 193, 721.5
    if kind == "rank" then ax, ay = 181.3, 720
    elseif kind == "remind" then path, n, ay = RB_REMIND, 500, 721.45 end
    local f = math.floor(math.max(0, RB_T) * 0.06) % n
    local e = path[f]
    local dy, sy = 0, 1
    if e then dy, sy = e[1], e[2] end
    tex.draw_texture(t.t, { x = (ax - 148) * S, y = (ay + dy - 256 * sy) * S, y2 = t.h * S * (sy - 1), fade = RB_FADE or 1 })
end

local function draw_rankup_page(b, page, fade)
    centered("rankup_bg", 640, 360, nil, 1, fade)
    RB_FADE = fade
    draw_page_robot("rank")
    local k = math.min(11, b.rank)
    -- 10 / 10+ are single-image textures (a frame of rk_big is cut to the 192 px of its first frame)
    if k >= 10 then anchored("rk_big" .. k, 736 - 176 * 0.78, 212 - 108 * 0.78, nil, fade, 0.78)
    else anchored("rk_big", 736 - 96 * 0.78, 212 - 112 * 0.78, k, fade, 0.78) end
    if page == 1 then
        -- strict audit round 15: the rank page's ごほうびゲット box is 1.12x of the reward screen's (label + body, template match vs
        -- the direct feed Tl7g8XXXvAM t=299 at 1.12, top left 248,323)
        anchored("reward_get_bg", 248, 323, nil, fade, 1.12)
        if b.rank >= 1 then centered("rankup_name", 634, 450, math.min(10, b.rank - 1), 1, fade) end
        return
    end
    local r = rank_info()
    -- rank 10+ (direct feed SdL9xArD87Y 7-15 s): the second page is the "最強のドンだーになった！" banner over the board
    if b.rank >= 11 and tx("rk_strong") then
        centered("rk_strong", 640, 416, nil, 1, fade)
        return
    end
    if not r or r.next <= 0 then return end
    anchored("rk_box", 640 - 340, 440 - 136, nil, fade)
    anchored("rk_next_text", 640 - 276, 354 - 32, nil, fade)
    local v = tostring(r.next)
    for d = 0, #v - 1 do
        centered("rk_sdigit", 700 + 22 * (#v - 1) - 44 * d, 354, v:byte(#v - d) - 48, 1, fade)
    end
    if b.rank <= 9 then
        anchored("rk_head", 640 - 288, 430 - 60, RK_HEAD[b.rank], fade)
        anchored("rk_row", 640 - 288, 430 - 30, b.rank, fade)
    else
        anchored("rk_row", 640 - 288, 430 - 60, 10, fade)
    end
    anchored("rk_note", 640 - 327, 440 + 55, nil, fade)
end

local function draw_reward(wins, got, nxt, fade)
    centered("reward_board", 640, 360, nil, 1, fade)
    RB_FADE = fade
    draw_page_robot("reward")
    digits("reward_digit", wins, 617, 222, 100, 1.0, fade)   -- footage: ~135 px tall
    anchored("reward_get_bg", 640 - 352, 366 - 100, nil, fade)
    anchored("reward_get", 317, 331, got, fade)
    if nxt then
        anchored("reward_next_bar", 615 - 276, 490 - 40, nil, fade)
        anchored("reward_next", 499, 461, nxt, fade)
        local need = tostring(WINS_AT[nxt + 1] - wins)
        for k = 0, #need - 1 do centered("reward_sdigit", 941 - 32 * k, 490, need:byte(#need - k) - 48, 1, fade) end
        anchored("reward_win_kanji", 995 - 24, 492 - 24, nil, fade)
    else
        anchored("reward_all", 639 - 340, 489 - 48, nil, fade)
    end
end

-- remind (sprite 73 at 640,360): the panel frames at 574,240 / 668,478, "つぎのランクまで N ポイント 達成で
-- [the next rank's title] ゲット！" and "つぎの合計勝利数ごほうびまで N 勝 達成で [the next reward] ゲット！"
local function draw_remind(wins, nxt, fade)
    centered("remind_bg", 640, 360, nil, 1, fade)
    RB_FADE = fade
    draw_page_robot("remind")
    local r = rank_info()
    if r and r.next > 0 then
        anchored("remind_frame", 574 - 376, 240 - 136, nil, fade)
        anchored("remind_rank_text", 574 - 376, 210 - 44, nil, fade)
        anchored("remind_theme", 732 - 322, 308 - 52, math.min(10, r.rank), fade)
        local v = tostring(r.next)
        for k = 0, #v - 1 do centered("reward_sdigit", 696 - 30 * k, 207, v:byte(#v - k) - 48, 0.8, fade) end
    end
    if nxt then
        anchored("remind_frame", 668 - 376, 478 - 136, nil, fade)
        anchored("remind_wins_text", 668 - 376, 448 - 44, nil, fade)
        anchored("reward_next", 504, 488, nxt, fade)
        local v = tostring(WINS_AT[nxt + 1] - wins)
        for k = 0, #v - 1 do centered("reward_sdigit", 889 - 30 * k, 445, v:byte(#v - k) - 48, 0.8, fade) end
    end
end

-- the pages turn on a kat (フチでページきりかえ) and end on a don (面でおわり) through tex.ai_pages, which also holds the
-- result's own input and timeout while they show; without input a page turns after PAGE_AUTO_MS
local PAGE_AUTO_MS = 8000
function AIB.draw_result_overlays(b, t)
    local list = {}
    if b.rank and b.rank > (b.rank_before or b.rank) and tx("rankup_bg") then
        list[#list + 1] = "rankup"
        list[#list + 1] = "rankup2"
    end
    local wins = tex.ai_wins and tex.ai_wins() or 0
    local got, nxt = reward_step(wins)
    if b.result == "win" and got and tx("reward_board") then list[#list + 1] = "reward" end
    -- real footage (ref_real Tl7g8XXXvAM 4:50-5:18): a rank up / reward ends the cut-ins; "つぎの目標" otherwise
    -- a plain loss shows none: direct feed uWAL-I14RFU stays on the result for 35 s+ without the page
    if #list == 0 and b.result ~= "lose" and tx("remind_bg") then list[#list + 1] = "remind" end
    local now = tex.get_current_ms()
    local P = RR.pages
    if not P then
        P = { page = 1, t0 = now, steps = 0 }
        RR.pages = P
    end
    if not P.done_ms then
        local steps, finished = 0, false
        if tex.ai_pages then steps, finished = tex.ai_pages(true) end
        if steps > P.steps then P.page, P.steps, P.t0 = P.page + (steps - P.steps), steps, now
        elseif now - P.t0 >= PAGE_AUTO_MS then P.page, P.t0 = P.page + 1, now end
        if finished or P.page > #list then
            P.done_ms = now
            if tex.ai_pages then tex.ai_pages(false) end
        end
    end
    local out = P.done_ms and (now - P.done_ms) or 0
    if out >= OVERLAY_FADE_MS then return end
    local i = math.min(P.page, #list)
    local kind = list[i]
    if not kind then return end
    local lt = now - P.t0
    local fade = math.max(0, math.min(1, lt / OVERLAY_FADE_MS, 1 - out / OVERLAY_FADE_MS))
    -- the AI room behind the cut-ins (real footage: opaque, the result fades out under it)
    local bg_fade = math.max(0, math.min(1, t / OVERLAY_FADE_MS, 1 - out / OVERLAY_FADE_MS))
    local lab = tx("lab_bg")
    if lab then tex.draw_texture(lab.t, { x = 0, y = 0, scale = S, fade = bg_fade }) end
    if kind == "rankup" then
        once("rankup", "ai_fanfare")
        -- direct feed Tl7g8XXXvAM (fanfare 293.43, voice 295.46) and SdL9xArD87Y (10 -> 10+: fanfare 0.34, voice 2.38,
        -- asset match 0.39 with rankup, 0.11 with rank_max): the voice follows the fanfare by 2.04 s
        if lt >= 2040 then once("rankup_v", "aivoice_rankup", "voice") end
    elseif kind == "rankup2" then
        once("rankup2", "aivoice_remind", "voice")
    elseif kind == "reward" then
        -- footage Tl7g8XXXvAM: the fanfare as the wins page comes in (308.7 s), the reward voice 2.6 s later
        once("reward_f", "ai_fanfare")
        if lt >= 2600 then once("reward", nxt and "aivoice_reward" or "aivoice_reward_all", "voice") end
    else
        once("remind", "aivoice_remind", "voice")
    end
    RB_T = lt
    if kind == "rankup" or kind == "rankup2" then draw_rankup_page(b, (kind == "rankup") and 1 or 2, fade)
    elseif kind == "reward" then draw_reward(wins, got, nxt, fade)
    else draw_remind(wins, nxt, fade) end
    -- the page's prompt (footage: "(rim) フチでページきりかえ" while pages remain, "(face) 面でおわり" on the last)
    -- strict green10: measured +1,-3 against the feed (f200), moved -1,+3
    local FX, FY = -1, 3
    if i < #list then
        centered("hint_rim", 730 + FX, 616 + FY, nil, 1, fade)
        centered("hint_next_text", 890 + FX, 616 + FY, nil, 1, fade)
    else
        centered("hint_red", 780 + FX, 616 + FY, nil, 1, fade)
        centered("hint_end_text", 915 + FX, 616 + FY, nil, 1, fade)
    end
end

return AIB
