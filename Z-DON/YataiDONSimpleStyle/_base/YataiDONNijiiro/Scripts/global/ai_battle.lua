-- AI battle (Z-DON: tex.ai_battle, src/objects/game/zdon_ai.h). Engines without it draw nothing.
-- The art is the cabinet's own AI-battle set (Graphics/{song_select,game,result}/ai_battle). skin_config
-- "zdon_ai_arena" makes the engine leave the AI's stage to this file (no AI character / plate, no character in
-- the game, no AI course mark or gauge).
--   AIB.draw_game_bg()  GAME_2P (Background:draw_back): the arena above and below the lanes (tug-of-war tiles)
--                       and the AI robot
--   AIB.draw_game()     GAME_2P, drawn by the AI lane's score counter (which draws no score): the AI plate, the
--                       judge boards (1P top left, AI on its panel), the section icons (to come = dark diamond,
--                       open = pulsing green, closed = pops in as gold "勝" / the silver AI face; the crown at
--                       the end) and the section timer with its "n区" label
--   AIB.draw_result()   RESULT_2P, instead of the AI's board: the VS panel (a tab and an icon per section), and
--                       0.3 s after the player's board has counted up the emblem (win: rays, glow, laurel and
--                       the "battle won" lettering; loss: the silver AI diamond and "battle lost")
--   AIB.draw_select_bg() / AIB.draw_select()   AI_SELECT: the cabinet's AI song select room / the player
--                       board (oni + ura record, the song's best), the AI robot and plate, its tension balloon
--                       and the wins plate (total, wins to the next reward)
--   AIB.draw_result_bg()  RESULT_2P of an AI battle: the cabinet's win (warm) / lose (cool) backdrop
-- All positions are 1080p pixels (the cabinet's AI movies are 1920x1080 too: their placements are used as is).
local AIB = {}

-- Off until an engine really keeps this data: the select's record board and wins plate, the result's win count
-- and the reward / title windows. Turning it on still needs the engine's tex.record_counts / ai_wins / ai_next_reward.
local SHOW_PROGRESS = false

local LANG_FRAME = { ja = 0, en = 1, ko = 2, tw = 3, zh = 4 }   -- jp en kr tw cn sets

local function lang_frame()
    local ok, l = pcall(function() return tex.language() end)
    return (ok and LANG_FRAME[l]) or 0
end

-- textures of the current screen's ai_battle subset (fetched again when the screen changes)
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

-- draw centred on (cx, cy) at scale s
local function put(name, cx, cy, s, fade, frame, rot)
    local t = tx(name)
    if not t then return end
    s = s or 1.0
    if rot then
        local w, h = t.w * s, t.h * s
        tex.draw_texture(t.t, { x = cx, y = cy, scale = s, fade = fade, frame = frame, rotation = rot,
                                origin = { w / 2, h / 2 } })
    else
        tex.draw_texture(t.t, { x = cx - t.w / 2, y = cy - t.h / 2, center = true, scale = s, fade = fade,
                                frame = frame })
    end
end

-- frame of the baked cabinet-text art (tx_*): 0 ja, 1 en, 2 ko, 3 cn_tw, 4 cn_cn.  The Traditional build maps zh to 3.
local function tx_lang_frame()
    local f = lang_frame()
    if f == 4 then f = 3 end
    return f
end

local function battle()
    if tex.ai_battle then return tex.ai_battle() end
    return AIB.up   -- YataiDON's own AI battle: global/ai_overlay.lua and ai_section_result keep this current
end

local text_cache = {}
local function txt(s, size, color, outline, th)
    local key = s .. "|" .. size .. "|" .. table.concat(color, ",")
    local t = text_cache[key]
    if t == nil then
        t = text.create_raw_text(s, size, color, outline or { 0, 0, 0, 255 }, false, th or 0, 1.0) or false
        text_cache[key] = t
    end
    return t or nil
end

local function draw_text_at(t, x, y, align)
    if not t then return end
    local dx = (align == "c") and (x - t.width / 2) or ((align == "r") and (x - t.width) or x)
    t:draw({ x = math.floor(dx + 0.5), y = math.floor(y - t.height / 2 + 0.5) })
end

local function skin_str(key, fallback)
    local s = tex.skin_text(key)
    if s == nil or s == "" then return fallback end
    return s
end

local function ease_out(t) t = math.max(0, math.min(1, t)); return 1 - (1 - t) * (1 - t) end

local function crown_name(b)
    if b.wins_p == b.count then return "crown_rainbow" end
    return (b.result == "win") and "crown_gold" or "crown_silver"
end

-- strip geometry: icon i of n, centred on cx
local function strip_xy(i, n, cx, cy, step, up, down)
    local x = cx + (i - (n + 1) / 2) * step
    local y = cy + ((i % 2 == 1) and up or down)
    return x, y
end

------------------------------------------------------------------------------------------------ game
-- The cabinet's AI battle stage (enso_ai/enso_enshutsu): the skin_config entry "zdon_ai_arena" tells the engine
-- to leave out the characters and the AI lane's plate / course mark; this draws instead
--   * the arena (ai_enso_panel: mc_bg + mc_enso_effect) above and below the lanes: its tiles are a tug of war,
--     columns 1p_0..1p_18 red from the left = the player's share of the open section's points
--   * the AI (white robot) over the top band, the AI plate on the AI lane's panel
--   * the judge boards (score_board: 1P 124,162 / AI 124,707), the section icons (section_result_icon, the
--     cabinet's 720p stage at 1:1, top left) and the section timer with its "n区" label (section_timer 400,291)
local F = 0.99
local STRIP_X0, STRIP_CY = 277, 192
local STEP, UP, DOWN = 46.5, -11.5, 11.5   -- the slots of the cabinet's strip art (sec_strip_*)
local POP_MS, SETTLE_MS = 180, 420
local BOARD_S = 1.0
local BOARD_P = { 128, 166 }
local BOARD_AI = { 128, 711 }
local ROWS = { -43, -17.5, 8, 33.5 }           -- 良 可 不可 連打 (board-centred, cabinet px)
local TIMER_CX, TIMER_CY = 400, 291
local TX_SECR = { [2] = { 427, 264 }, [3] = { 428, 264 }, [4] = { 426, 264 }, [5] = { 428, 264 } }   -- top-left of the right "n区" art (stage px)
local TX_SEC = { [1] = { 308, 264 }, [2] = { 308, 264 }, [3] = { 308, 264 }, [4] = { 308, 264 }, [5] = { 308, 264 } }   -- top-left of the baked "n区" art (stage px)
local FILL_X, FILL_Y, FILL_W, FILL_H = 304, 287, 192, 24
local ARENA_BOT_Y = 806
local ROBOT_X, ROBOT_Y, ROBOT_S = 960, 112, 0.3
local PLATE_X, PLATE_Y, PLATE_S = 161, 598, 1.0   -- strict audit (MBAZD6xA1D8 1080p): the white plate spans 8..309 x 566..623

-- the section-win diamond (sec_win_big: section_result_icon win_mc 4..118, every 3rd frame at 60 fps, the sprite's
-- origin at 70,220 of the crop; the cabinet's 720p art at 0.92 here as the strip icons)
local BIGW_S, BIGW_OX, BIGW_OY = 1.15, 70, 220
local BIGW_X, BIGW_Y = 393, 155      -- the sprite origin in the stage: the diamond (180 px right of it) centres at 600,155 (direct feed MBAZD6xA1D8)
local BIGW_MS, BIGW_SMALL_MS = 1900, 1500
local G = { done = {}, sig = nil, first_ms = nil, k = 9, k_ms = nil, closed = 0 }
-- a section closing (ai_enso_panel mc_win_section / mc_lose_section): the tiles sweep to all red (won) / all blue
-- (lost) in 38 frames and stay so to the effect's end (184 frames); a won section also plays the confetti over
-- the top band (section_win_effect_mc, 180 frames, 15 fps here, stored at half size)
local SWEEP_MS, HOLD_MS = 633, 3067
local CONFETTI_FPS, CONFETTI_S = 15, 2.0
-- the AI's emotion icon (mc_emotion_icon "angry", 20 frames looping) while the player leads the section by
-- emotion_high points, until the lead is back to emotion_low (AiEnsoGameManager)
local EMO_HIGH, EMO_LOW = 6, 0
local EMO_S = 0.42
-- the two in the arena (ai_enso_panel don_move_mc / ai_don_move_mc / don_eff_move_mc / ai_eff_move_mc, placed at
-- 960,152): at tug index k (labels don_0..don_18) the clash is at 960 + CLASH_X[k], the player's Don 110 px to its
-- left, the AI 110 px to its right. Each side's clash flame is a collision_effect clip picked by k (the player's
-- grows as it pushes, the AI's shrinks), looping from frame 20 (xs: whole) at 60 fps; the AI's is mirrored
local CLASH_X = { [0] = -842, -758, -679, -581, -484, -386, -289, -192, -96, 0, 96, 192, 289, 386, 484, 581, 679,
                  758, 842 }
local ARENA_Y, DUEL_GAP = 152, 110
-- crop origin (the clip's 0,0 in the PNG), frame count, loop start
local CLASH = {
    l_p = { 832, 254, 40, 20 }, m_p = { 816, 217, 40, 20 }, s_p = { 378, 175, 48, 20 }, xs_p = { 174, 169, 19, 0 },
    l_ai = { 832, 254, 40, 20 }, m_ai = { 816, 217, 40, 20 }, s_ai = { 377, 175, 48, 20 }, xs_ai = { 174, 180, 19, 0 },
}
local function clash_p(k) return (k <= 3 and "xs_p") or (k <= 7 and "s_p") or (k <= 13 and "m_p") or "l_p" end
local function clash_ai(k) return (k <= 2 and "l_ai") or (k <= 10 and "m_ai") or (k <= 14 and "s_ai") or "xs_ai" end
-- the opening (don_ready): the arena's tiles slide in from both sides (mc_enso_effect ready_effect, 60 frames,
-- stored at 30 fps), the two jump in over frames 29..47 from 1290 px out on an arc (y -257 at frame 32)
local READY_MS, JUMP0, JUMP1 = 1000, 29, 47
local JUMP = { { 29, -1290, -1290 }, { 32, -498.3, -257 }, { 35, -397.7, -233.7 }, { 38, -304.4, -189.85 },
               { 41, -219.95, -131.6 }, { 44, -147.35, -59.4 }, { 47, -110, 0 } }
local ROBOT_DY = -8
local DON_DY, DON_ROT, DON_S = 85, 35, 0.58
-- the winner's run (ai_enso_panel mc_don_attack win_section_N / mc_aidon_attack win_section_N: 37 frames at 60 fps,
-- x / y from the clip origin 960,152): windup away from the tug, the dash through the loser, the hop back to the middle
local DON_WIN = {
    [18] = { x = {736,716,658,561,424,249,35,-219,-511,-842,-846,-850,-854,-858,-862,-866,-870,-874,-878,-882,-548,-215,119,452,786,783,775,761,752,724,676,554,413,255,76,-120,0},
           y = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-2,-5,-14,-25,-36,-47,-56,-60,-46,0} },
    [17] = { x = {652,634,578,486,357,191,-12,-252,-528,-842,-846,-850,-854,-858,-862,-866,-870,-874,-878,-882,-565,-248,68,385,702,700,695,686,677,652,610,550,473,379,213,31,0},
           y = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-2,-5,-13,-24,-36,-47,-56,-59,-47,0} },
    [16] = { x = {-842,-846,-850,-854,-858,-862,-866,-870,-874,-878,-882,-581,-280,21,322,623,620,609,592,586,565,529,478,412,329,232,121,0},
           y = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,2,-2,-11,-25,-40,-54,-64,-66,-51,0} },
    [15] = { x = {475,459,410,329,215,68,-110,-322,-566,-842,-846,-850,-854,-858,-862,-866,-870,-874,-878,-882,-601,-319,-38,244,525,522,512,496,491,475,445,402,346,277,138,-10,0},
           y = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,2,-2,-13,-27,-43,-57,-68,-67,-49,0} },
    [14] = { x = {378,363,318,242,137,1,-164,-360,-586,-842,-846,-850,-854,-858,-862,-866,-870,-874,-878,-882,-620,-358,-96,166,428,428,428,428,422,408,382,345,297,237,110,-27,0},
           y = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-4,-14,-26,-40,-53,-61,-58,-43,0} },
    [13] = { x = {280,266,225,155,58,-66,-219,-399,-606,-842,-846,-850,-854,-858,-862,-866,-870,-874,-878,-882,-640,-397,-155,88,330,329,326,321,317,306,289,262,225,178,67,-50,0},
           y = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-3,-10,-23,-37,-48,-53,-53,-43,0} },
    [12] = { x = {183,170,132,69,-19,-133,-273,-437,-627,-842,-846,-850,-854,-858,-862,-866,-870,-874,-878,-882,-659,-436,-213,10,233,234,238,243,241,235,222,202,173,136,38,-65,0},
           y = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-2,-5,-12,-23,-34,-42,-45,-42,-30,0} },
    [11] = { x = {86,75,40,-17,-97,-200,-326,-475,-647,-842,-846,-850,-854,-858,-862,-866,-870,-874,-878,-882,-678,-475,-271,-68,136,136,136,136,136,135,132,126,116,101,24,-58,-140},
           y = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-2,-3,-6,-8,-13,-22,-33,-45,-54,-50,-31} },
    [10] = { x = {-286,-352,-437,-544,-671,-818,-986,-1175,-1384,-1613,-1672,-1732,-1792,-1851,-1911,-1970,-2030,-2089,-2149,-2209,-2079,-1950,-1820,-1691,-1561,-1605,-1594,-1582,-1571,-1577,-1584,-1594,-1606,-1622,-1635,-1645,-1652},
           y = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-15,-29,-42,-52,-53,-44,-31,-16} },
    [9] = { x = {-106,-115,-142,-188,-251,-333,-433,-551,-688,-842,-846,-850,-854,-858,-862,-866,-870,-874,-878,-882,-717,-552,-386,-221,-56,-52,-42,-24,0,0,0,0,0,0,0,0,0},
           y = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0} },
}
local AI_WIN = {
    [0] = { x = {-736,-720,-670,-588,-474,-326,-146,67,313,592,596,600,604,608,612,616,620,624,628,632,357,83,-192,-466,-741,-748,-755,-762,-677,-590,-505,-363,-221,-78,64,205,0},
           y = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-2,-24,-39,-49,-56,-60,-58,-48,-30,0} },
    [1] = { x = {-652,-637,-591,-514,-406,-268,-99,101,331,592,596,600,604,608,612,616,620,624,628,632,365,98,-168,-435,-702,-699,-691,-677,-669,-644,-602,-543,-467,-374,-207,-25,0},
           y = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-2,-5,-8,-15,-26,-37,-48,-56,-59,-47,0} },
    [2] = { x = {-573,-559,-516,-444,-343,-213,-55,132,348,592,596,600,604,608,612,616,620,624,628,632,381,130,-121,-372,-623,-618,-604,-581,-574,-554,-518,-468,-403,-322,-169,-4,0},
           y = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-2,-4,-7,-16,-28,-42,-55,-64,-65,-51,0} },
    [3] = { x = {-475,-462,-422,-356,-264,-146,-1,170,368,592,596,600,604,608,612,616,620,624,628,632,401,169,-62,-294,-525,-519,-500,-469,-464,-447,-418,-378,-325,-259,-124,21,0},
           y = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-2,-7,-16,-19,-26,-37,-50,-62,-69,-66,-47,0} },
    [4] = { x = {-378,-366,-330,-270,-186,-79,53,209,388,592,596,600,604,608,612,616,620,624,628,632,420,208,-4,-216,-428,-428,-428,-428,-422,-408,-382,-345,-297,-237,-107,32,0},
           y = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-4,-14,-26,-40,-53,-61,-58,-43,0} },
    [5] = { x = {-280,-269,-237,-183,-108,-11,108,248,409,592,596,600,604,608,612,616,620,624,628,632,440,247,55,-138,-330,-329,-326,-321,-317,-306,-289,-262,-225,-178,-65,54,0},
           y = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-3,-10,-23,-37,-48,-53,-53,-43,0} },
    [6] = { x = {-183,-173,-145,-97,-30,56,161,286,429,592,596,600,604,608,612,616,620,624,628,632,459,286,113,-60,-233,-234,-238,-244,-242,-236,-224,-203,-174,-137,-36,69,0},
           y = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-3,-11,-22,-33,-41,-45,-42,-30,0} },
    [7] = { x = {-86,-78,-53,-11,48,123,215,324,450,592,596,600,604,608,612,616,620,624,628,632,478,325,171,18,-136,-136,-136,-137,-138,-136,-133,-127,-117,-102,-23,62,146},
           y = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,-1,-2,-5,-6,-12,-21,-32,-44,-54,-50,-32} },
    [8] = { x = {10,17,39,75,125,190,269,362,470,592,596,600,604,608,612,616,620,624,628,632,498,363,229,94,-40,-51,-63,-74,-86,-79,-72,-63,-50,-34,-21,-11,-5},
           y = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-15,-29,-42,-52,-53,-44,-31,-16} },
}
local WIN_HIT = 24             -- frame of the run where the dash hits the loser
local STREAK_A = { [19] = 1, [20] = 1, [21] = 1, [22] = 1, [23] = 1, [24] = 1, [25] = 0.67, [26] = 0.33 }
local KNOCK_V, KNOCK_A = 600, 6000 -- the loser's flight after the hit: px/s and px/s^2 (direct feed MBAZD6xA1D8 0:49.5-0:50)
local STREAK_CX, STREAK_CY, STREAK_W = 300, 190, 420   -- sec_streak: the art's origin in its crop

local function lerp_k(tbl, k)
    local i = math.max(0, math.min(17, math.floor(k)))
    local f = math.max(0, math.min(1, k - i))
    return tbl[i] + (tbl[i + 1] - tbl[i]) * f
end

local function clash_frame(side, name, now)
    local st = G[side]
    if not st or st.name ~= name then st = { name = name, t0 = now }; G[side] = st end
    local c = CLASH[name]
    local f = math.floor((now - st.t0) / (1000 / 60))
    if f >= c[3] then f = c[4] + (f - c[4]) % (c[3] - c[4]) end
    return f
end

local function draw_clash(name, f, cx, cy, mirror)
    local t = tx("clash_" .. name)
    if not t then return end
    local c = CLASH[name]
    if mirror then
        tex.draw_texture(t.t, { x = cx - (t.w - c[1]), y = cy - c[2], frame = f, mirror = "horizontal", blend = "additive" })
    else
        tex.draw_texture(t.t, { x = cx - c[1], y = cy - c[2], frame = f, blend = "additive" })   -- collision_effect_*: blend 8
    end
end

local function draw_board(name, counts, cx, cy)
    put(name, cx, cy, BOARD_S)
    put("board_label", cx - 42 * BOARD_S, cy - 4 * BOARD_S, BOARD_S, nil, tx_lang_frame())   -- centred on the pills (x 20..117 of the 220x142 board)
    local now, st, digit = tex.get_current_ms(), G[name], tx("board_digit")
    if not st then st = { v = {}, t = {} }; G[name] = st end
    if not digit then return end
    for r = 1, 4 do
        local v = math.max(0, math.floor((counts and counts[r]) or 0))
        if st.v[r] and v > st.v[r] then st.t[r] = now end
        st.v[r] = v
        -- a count going up stretches like the score (animation 4, text_stretch: 2..12 px over 50 ms, back in 116 ms), scaled to these smaller digits
        local e, stretch = st.t[r] and (now - st.t[r]) or 1e9, 0
        if e <= 50 then stretch = (2 + e / 5) * 0.6
        elseif e <= 166 then stretch = math.max(0, 12 - 2 * (math.floor((e - 50) / 16.57) + 1)) * 0.6 end
        local s = tostring(v)
        if #s > 4 then s = "9999" end
        for k = 0, #s - 1 do
            local d = s:byte(#s - k) - 48
            -- strict audit (MBAZD6xA1D8 @24 s / @100 s): the counts are centred on cx + 52, 15 px apart (not right-aligned at 76)
            -- whole pixels (the art is 19x23); each digit's white body put on rows 3..18 of its cell
            local dy = ("1211001111"):byte(d + 1) - 49
            tex.draw_texture(digit.t, { x = math.floor(cx + 52 + 15 * ((#s - 1) / 2 - k)) - 9,
                                        y = math.floor(cy + ROWS[r]) - 11 + dy - stretch, y2 = stretch, frame = d })
        end
    end
end

function AIB.active()
    if tex.ai_active then return tex.ai_active() end
    return AIB.up ~= nil and AIB.up.screen == "AI_GAME" and tex.current_screen() == "AI_GAME"
end

-- an AI battle's result: on either engine
function AIB.plain_result()
    if tex.ai_active then return tex.ai_active() end
    return AIB.up ~= nil and AIB.up.screen == "AI_RESULT" and tex.current_screen() == "AI_RESULT"
end

-- The arena's moving layers (ai_enso_panel mc_enso_effect loop_01..03; timings as Green's ai_battle overlay, 720p x 1.5):
-- phase 1 drifting triangles, 2 another set and rising shapes, 3 (last section) sprinkles, columns, flashes and lines
do
    local SC, FM = 1.5, 1000 / 60
    local QW = { flash_quad = 152 }
    local function spr(key, cx, cy, o)
        local t = tx(key)
        if not t then return end
        o = o or {}
        local s = SC * (o.s or 1)
        local w, h = (QW[key] or t.w) * s, t.h * s
        tex.draw_texture(t.t, { x = cx * SC, y = cy * SC, scale = s, origin = { w / 2, h / 2 }, rotation = o.rot or 0,
                                fade = o.fade or 1, frame = o.frame or 0, blend = o.add and "additive" or nil })
    end
    local function blink(f, n)
        if f < 0 or f > n then return 0 end
        return 1 - math.abs(2 * f / n - 1)
    end
    local COLUMNS = {
        { "pattern_column_triangle", 358, 0, 289, 814, 440 }, { "pattern_column_triangle", 1136, 0, 244, 439, 813 },
        { "pattern_column_wave", 852, 0, 299, 441, 812 }, { "pattern_column_wave", 1206, 0, 165, 811, 438 },
        { "pattern_column_wave", 73, 0, 236, 440, 809 }, { "pattern_column_wave", 499, 82, 136, 441, 812 },
        { "pattern_column_maze", 923, 58, 185, 811, 440 }, { "pattern_column_triangle", 640, 0, 299, 438, 811 },
        { "pattern_column_diamond", 568, 24, 259, 814, 438 }, { "pattern_column_diamond", 287, 24, 170, 437, 813 },
        { "pattern_column_diamond", 993, 55, 211, 437, 811 },
    }
    -- the upper floor's tile flashes (panel_flash_mc, inside gage_effect_pattern_mc: they run in every phase)
    local QUADS = {
        { 0, 71, 133, { 40, 133, 216 }, 0.4 }, { 1, 589, 73, { 40, 158 }, 0.8 }, { 2, 835, 50, { 82, 201 }, 0.3 },
        { 3, 1047, 104, { 40, 223 }, 0.3 }, { 4, 454, 134, { 48, 191 }, 0.2 }, { 5, 708, 169, { 130, 259 }, 0.4 },
        { 6, 949, 134, { 245 }, 0.3 }, { 7, 444, 48, { 91 }, 0.2 }, { 8, 1257, 169, { 73, 258 }, 0.3 },
        { 9, 754, 101, { 139 }, 0.2 }, { 10, 321, 75, { 153, 248 }, 0.4 },
    }
    local LINE_Y = { 161, 133, 103, 75, 47 }
    function AIB.draw_arena_fx(ms, closed, count, k, highlight)
        local phase = (closed >= count - 1) and 3 or ((closed >= count // 2) and 2 or 1)
        if phase ~= G.fx_phase then G.fx_phase, G.fx_t0 = phase, ms end
        local since = (ms - G.fx_t0) / FM
        local fade_in = math.min(since / 20, 1)
        local cycle = (ms / FM) % 300
        for _, q in ipairs(QUADS) do
            for _, start in ipairs(q[4]) do
                local a = blink(cycle - start, 40)
                if a > 0 then spr("flash_quad", q[2], q[3], { frame = q[1], fade = a * q[5], add = true }) end
            end
        end
        if phase >= 3 then
            for i, y in ipairs(LINE_Y) do
                local a = math.max(blink(cycle, 40), 0.7 * blink(cycle - 40 - 4 * i, 20))
                if a > 0 then spr("line_upper_" .. i, 640, y, { fade = a, add = true }) end
            end
        end
        local scroll = (ms % 8500) / 8500 * 1152
        local first = phase == 1 and 0.5 or (phase == 2 and 0.5 * (1 - math.min(since / 50, 1)) or 0)
        local second = phase == 2 and 0.5 * fade_in or (phase == 3 and 0.5 * (1 - math.min(since / 50, 1)) or 0)
        local t1, t2 = tx("lower_triangles_1"), tx("lower_triangles_2")
        if t1 and first > 0 then
            tex.draw_texture(t1.t, { y = (144 + scroll) * SC, scale = SC, fade = first })
            tex.draw_texture(t1.t, { y = (-432 + scroll) * SC, scale = SC, fade = first })   -- wraps: the sheets are 576 apart
        end
        if t2 and second > 0 then
            tex.draw_texture(t2.t, { y = (-432 + scroll) * SC, scale = SC, fade = second })
            tex.draw_texture(t2.t, { y = (144 + scroll) * SC, scale = SC, fade = second })
        end
        if phase >= 2 then
            local f = (ms / FM) % 480
            local rise = { { "pattern_swirl", 545, f - 73, 196 }, { "pattern_triangle", 239, f - 10, 200 },
                           { "pattern_flower", 818, f, 135 }, { "pattern_triangle", 839, f - 267, 187 },
                           { "pattern_triangle", 257, f - 311, 168 } }
            for _, r in ipairs(rise) do
                if r[3] >= 0 and r[3] <= r[4] then
                    local p = r[3] / r[4]
                    spr(r[1], r[2], 794 - 324 * p, { rot = (r[2] < 640 and 1 or -1) * 70 * p, fade = math.min(1 - p, fade_in), add = true })
                end
            end
        end
        if phase >= 3 then
            local g = (ms / FM) % 300
            spr("pattern_sprinkle", 642, 384 + 475 * g / 300, { fade = fade_in, add = true })
            spr("pattern_sprinkle", 642, 384 + 475 * ((g + 150) % 300) / 300, { fade = fade_in, add = true })
            for _, c in ipairs(COLUMNS) do
                local p = g - c[3]
                if p >= 0 and p <= c[4] then spr(c[1], c[2], c[5] + (c[6] - c[5]) * p / c[4], { fade = fade_in, add = true }) end
            end
            -- the top band's flashes and lines sit under the cabinet's opaque upper floor: only the lower ones show
            for i, y in ipairs({ 698, 650, 603, 553 }) do
                local a = math.max(blink(g, 40), 0.7 * blink(g - 36 - 4 * i, 20), 0.7 * blink(g - 125 - 4 * i, 20))
                if a > 0 then spr("line_lower", 640, y, { fade = a, add = true }) end
            end
            if since < 110 then
                for i, x in ipairs({ 429, 641, 1066, 216, 499, 851, 1207, 74 }) do
                    local h = since - (i - 1) * 8
                    local a = blink(h, 60)
                    if a > 0 then
                        spr(i % 2 == 0 and "flash_tile_narrow" or "flash_tile_wide", x, 628, { fade = a, add = true })
                        spr(i % 2 == 0 and "flash_triangle_white" or "flash_triangle_yellow", x, 628 + 30 * (h / 60),
                            { s = 0.8 * (1 - 0.8 * h / 60), rot = 45 * h / 60, fade = a, add = true })
                    end
                end
            end
        end
        local hl = highlight and tx("highlight_tile_lower")
        if hl then
            local p = (ms % 332) / 332
            -- this skin's floor tiles are 106 px apart (the boundary tile of frame k spans 53 + 106 (k - 1) .. + 117)
            tex.draw_texture(hl.t, { x = 34 + 106 * (k - 1), y = 512 * SC, scale = SC, fade = 1 - math.abs(2 * p - 1) })
        end
    end
end

-- the loading card is up this frame: the floor's opening starts just after it (arcade: 150 ms into the game's fade-in end)
function AIB.card_up() G.card_ms = tex.get_current_ms() end

-- the arena and the AI, under the lanes (Background:draw_back); false: not an AI battle / no art
function AIB.draw_game_bg()
    if not AIB.active() or not tx("arena_top") then return false end
    local b = battle()
    local target = 9
    if b and b.tug and not b.finished then target = b.tug
    elseif b and b.finished then target = (b.result == "win") and 17 or 1 end
    local now = tex.get_current_ms()
    local dt = G.k_ms and math.max(0, now - G.k_ms) or 0
    G.k_ms = now
    -- sections closed since the last frame start the sweep (a restart / new song: none closed)
    local closed, last = 0, nil
    for _, sec in ipairs(b and b.sections or {}) do
        if sec.winner >= 0 then closed = closed + 1; last = sec end
    end
    if closed < G.closed then G.closed, G.sweep = closed, nil end
    if closed > G.closed and last then
        G.closed = closed
        G.sweep = { t0 = now, from = G.k, to = (last.winner == 0) and 18 or 0, win = last.winner == 0,
                    who = last.winner }
    end
    local sw = G.sweep
    if sw and now - sw.t0 < HOLD_MS then
        local t = now - sw.t0
        G.k = sw.from + (sw.to - sw.from) * math.min(1, t / SWEEP_MS)
    else
        local step = dt * 0.012                     -- 12 columns a second
        if math.abs(target - G.k) <= step then G.k = target
        elseif target > G.k then G.k = G.k + step else G.k = G.k - step end
    end
    local k = math.max(0, math.min(18, math.floor(G.k + 0.5)))
    -- the opening, from the stage's first frame (again for a new song / a restart: the section signature changes)
    local rsig = b and (tostring(b.count) .. ":" .. tostring(b.sections[1] and b.sections[1].end_ms)) or "-"
    if not G.ready_ms or (b and G.ready_sig ~= rsig and G.ready_sig ~= "-") then G.ready_ms = now end
    G.ready_sig = rsig
    if G.card_ms and now - G.card_ms < 200 then G.ready_ms = now + 150 end
    local age = now - G.ready_ms
    -- the match's end (mc_main win_total / lose_total): the floor sweeps to gold with the laurel (won) or to blue
    -- (lost) over win_btl_bg / lose_btl_bg (32 / 25 frames at 30 fps, then held)
    local total = b and b.finished and not b.skipped and tx("total_win_top") and ((b.result == "win") and "win" or "lose") or nil
    if total then G.total_ms = G.total_ms or now else G.total_ms = nil end
    if total then
        local n = (total == "win") and 32 or 25
        -- stored at 30 fps: two neighbouring frames blended (the tiles only change colour)
        local fl = (now - G.total_ms) * 30 / 1000
        local f = math.min(n - 1, math.floor(fl))
        local top, bot = tx("total_" .. total .. "_top").t, tx("total_" .. total .. "_bot").t
        tex.draw_texture(top, { x = 0, y = 0, frame = f })
        tex.draw_texture(bot, { x = 0, y = ARENA_BOT_Y, frame = f })
        if f < n - 1 then
            tex.draw_texture(top, { x = 0, y = 0, frame = f + 1, fade = fl - f })
            tex.draw_texture(bot, { x = 0, y = ARENA_BOT_Y, frame = f + 1, fade = fl - f })
        end
    elseif age < READY_MS and tx("arena_rdy_top") then
        local fl = math.max(0, age * 30 / 1000)
        local f = math.min(29, math.floor(fl))
        local top, bot = tx("arena_rdy_top").t, tx("arena_rdy_bot").t
        tex.draw_texture(top, { x = 0, y = 0, frame = f })
        tex.draw_texture(bot, { x = 0, y = ARENA_BOT_Y, frame = f })
        if f < 29 then   -- 30 fps art: the next frame blended over it
            tex.draw_texture(top, { x = 0, y = 0, frame = f + 1, fade = fl - f })
            tex.draw_texture(bot, { x = 0, y = ARENA_BOT_Y, frame = f + 1, fade = fl - f })
        end
    else
        tex.draw_texture(tx("arena_top").t, { x = 0, y = 0, frame = k })
        if tx("arena_bot") then tex.draw_texture(tx("arena_bot").t, { x = 0, y = ARENA_BOT_Y, frame = k }) end
    end
    -- the floor's flashes, patterns and boundary light wait for its opening (user report, arcade capture MBAZD6xA1D8)
    if not total and b and age >= READY_MS then AIB.draw_arena_fx(now, closed, b.count, k, not (sw and now - sw.t0 < HOLD_MS)) end
    -- the lanes end at 804 and the floor art starts at 806: nothing else draws these two rows, so without this
    -- they keep the previous frames' pixels (a line of specks). Black, like the band under the lanes.
    local gap = tx("arena_bot")
    if gap then
        tex.draw_texture(gap.t, { x = 0, y = ARENA_BOT_Y - 2, y2 = 2 - gap.h, color = { 0, 0, 0, 255 },
                                  src = { x = 0, y = 0, width = gap.w, height = 2 } })
    end
    if sw and sw.win then
        -- section_win_effect_mc from its own tracks, placed at the stage's centre; frames 5..184
        local f = 5 + (now - sw.t0) * 0.06
        if f < 184 then require("global.lumen_tracks").draw(require("global.ai_fx_conf"), f, tx, 960, 540) end
    end
    -- the duel: where the two stand (the opening's jump, then the tug) and the clash between them
    local fr60 = age * 60 / 1000
    local dx, dy, show = nil, 0, true
    if fr60 <= JUMP0 then
        show = false
    elseif fr60 < JUMP1 then
        for i = 1, #JUMP - 1 do
            local a, c = JUMP[i], JUMP[i + 1]
            if fr60 <= c[1] then
                local t = (fr60 - a[1]) / (c[1] - a[1])
                dx = a[2] + (c[2] - a[2]) * t
                dy = a[3] + (c[3] - a[3]) * t
                break
            end
        end
    end
    local clash_x = 960 + lerp_k(CLASH_X, G.k)
    local don_x = dx and (960 + dx) or (clash_x - DUEL_GAP)
    local ai_x = dx and (960 - dx) or (clash_x + DUEL_GAP)
    local don_rot, ai_dy, don_dy = DON_ROT, 0, 0
    local bob = 4 * math.sin(now / 420)
    local seq = not AIB.up and sw and sw.who and sw.who <= 1 and now - sw.t0 < HOLD_MS and not total and sw or nil
    if seq then
        -- a section won: the winner's run from the data (windup away, the dash through the loser, the hop back), the
        -- loser flung off the stage after the hit
        seq.n = seq.n or ((seq.who == 0) and math.max(9, math.min(18, math.floor(seq.from + 0.5)))
                          or math.max(0, math.min(8, math.floor(seq.from + 0.5))))
        local tr = (seq.who == 0) and DON_WIN[seq.n] or AI_WIN[seq.n]
        local j = math.floor((now - seq.t0) * 60 / 1000)
        local jj = math.min(j, #tr.x - 1) + 1
        local wx, wy = 960 + tr.x[jj], tr.y[jj]
        local prev = tr.x[math.max(1, jj - 1)]
        local lx0 = 960 + lerp_k(CLASH_X, seq.from) + ((seq.who == 0) and DUEL_GAP or -DUEL_GAP)
        local lx, ly = lx0, 0
        if j >= WIN_HIT then
            local dt = (now - seq.t0) / 1000 - WIN_HIT / 60
            local fly = KNOCK_V * dt + KNOCK_A * dt * dt
            lx = lx0 + ((seq.who == 0) and fly or -fly)
            ly = -260 * dt * (1 - dt)
        end
        local sa = STREAK_A[j]
        local st = sa and tx("sec_streak")
        if st then
            local fx = (j >= WIN_HIT) and (960 + tr.x[WIN_HIT + 1]) or wx
            if seq.who == 0 then
                tex.draw_texture(st.t, { x = fx - STREAK_CX, y = ARENA_Y + 10 - STREAK_CY, fade = sa })
            else
                tex.draw_texture(st.t, { x = fx - (STREAK_W - STREAK_CX), y = ARENA_Y + 10 - STREAK_CY, fade = sa,
                                         mirror = "horizontal" })
            end
        end
        if seq.who == 0 then
            don_x, ai_x, don_dy, ai_dy = wx, lx, wy, ly
            don_rot = (tr.x[jj] < prev) and -DON_ROT or DON_ROT
        else
            ai_x, don_x, ai_dy, don_dy = wx, lx, wy, ly
        end
        if lx < -200 or lx > 2120 then
            if seq.who == 0 then ai_x = 99999 else don_x = 99999 end
        end
        G.rejoin = nil
        G.seq_end = now
    elseif G.seq_end then
        -- the sequence is over: the two step back in on the opening's arc
        G.rejoin = now
        G.seq_end = nil
    end
    if G.rejoin then
        local f = JUMP0 + (now - G.rejoin) * 60 / 1000
        if f >= JUMP1 then G.rejoin = nil else fr60 = f end
    end
    if AIB.up then
        -- YataiDON stands its own 3D Dons at border_x (global/ai_overlay.lua) and asks for the flames after them
        AIB.up.clash_x = (show and not dx) and clash_x or nil
        AIB.up.flame_x = (show and not dx and not total and not (sw and now - sw.t0 < HOLD_MS)) and clash_x or nil
    elseif show then
        if G.rejoin and not seq then
            for i = 1, #JUMP - 1 do
                local a, c = JUMP[i], JUMP[i + 1]
                if fr60 <= c[1] then
                    local t = (fr60 - a[1]) / (c[1] - a[1])
                    local rx = a[2] + (c[2] - a[2]) * t
                    local ry = a[3] + (c[3] - a[3]) * t
                    don_x, ai_x, don_dy, ai_dy = clash_x + rx, clash_x - rx, ry, ry
                    break
                end
            end
        end
        if not (tex.ai_draw_rival and tex.ai_draw_rival(ai_x, ARENA_Y + ai_dy + dy + DON_DY, DON_S, -don_rot)) then
            put("robot", ai_x, ARENA_Y + ai_dy + dy + ROBOT_DY + bob, ROBOT_S)
        end
        if tex.ai_draw_don then tex.ai_draw_don(don_x, ARENA_Y + don_dy + dy + DON_DY, DON_S, don_rot) end
        -- the flames lie over the two (ai_enso_panel mc_main: don_eff_move_mc depth 9, ai_eff_move_mc 10, the characters 7, 8)
        if not dx and not total and not (sw and now - sw.t0 < HOLD_MS) and not G.rejoin then
            local kp = math.max(0, math.min(18, math.floor(G.k + 0.5)))
            local np, na = clash_p(kp), clash_ai(kp)
            draw_clash(np, clash_frame("cp", np, now), clash_x, ARENA_Y, false)
            draw_clash(na, clash_frame("ca", na, now), clash_x, ARENA_Y, true)
        end
    end
    G.ai_x = ai_x
    if b and not b.finished then
        local lead = (b.live_p or 0) - (b.live_ai or 0)
        if not G.angry and lead >= EMO_HIGH then G.angry = now
        elseif G.angry and lead <= EMO_LOW then G.angry = nil end
    else
        G.angry = nil
    end
    if G.angry then
        local f = math.floor((now - G.angry) / (1000 / 60)) % 20
        put("emotion", (G.ai_x or 1070) + 64, ARENA_Y - 77 + bob, EMO_S, nil, f)
    end
    return true
end

-- the match's end over the stage (enso_ai/enso/result ai_battle_result preprocess_mc at 960,540: win_mc "バトル勝利"
-- laurel, 155 frames; lose_mc "バトル終了" ring on the circuit, 125 frames), from frame 5, then held (its own
-- fade-out). The language-free layer is stored at half size, 15 fps (end_<kind>_base, full screen); the lettering is
-- the language sprite's own shape (end_win_tx1 / tx2, end_lose_tx: frames ja en ko tw) placed per 30 fps frame from
-- the node's transform { x, y, scale, alpha } (data frames 5, 7, ...; c = the shape's centre in it)
local END_FRAMES = { win = 78, lose = 63 }
local END_LANG = { [0] = 0, 1, 2, 3, 3 }
local END_WIN_TX1 = { c = { 0, 0 }, k = { {-18,-144,1.000,0.000}, {-18,-144,1.000,0.000}, {-18,-144,1.000,0.000}, {-18,-144,1.000,0.000}, {-18,-144,1.000,0.000}, {-18,-144,1.000,0.000}, {-18,-144,1.000,0.000}, {-18,-144,1.000,0.000}, {-18.1,-144.1,1.000,0.199}, {-18.1,-144.1,1.000,0.602}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000}, {-18,-144,1.000,1.000} } }
local END_WIN_TX2 = { c = { 0, 0 }, k = { {-13.5,105,3.000,0.000}, {-13.5,105,3.000,0.000}, {-13.5,105,3.000,0.000}, {-13.5,105,3.000,0.000}, {-13.5,105,3.000,0.000}, {-13.5,105,3.000,0.000}, {-13.5,105,3.000,0.000}, {-13.5,105,3.000,0.000}, {-13.5,105,3.000,0.000}, {-13.5,105,3.000,0.000}, {-13.5,105,3.000,0.000}, {-13.5,105,2.982,0.008}, {-13.5,105,2.927,0.031}, {-13.5,105,2.836,0.074}, {-13.5,105,2.709,0.133}, {-13.5,105,2.545,0.207}, {-13.5,105,2.345,0.297}, {-13.5,105,2.109,0.406}, {-13.6,105,1.836,0.527}, {-13.6,105,1.527,0.668}, {-13.6,105,1.182,0.828}, {-13.5,105,0.800,1.000}, {-13.5,105,0.958,1.000}, {-13.5,105,1.077,1.000}, {-13.5,105,1.156,1.000}, {-13.4,105,1.195,1.000}, {-13.5,105,1.198,1.000}, {-13.4,105,1.178,1.000}, {-13.5,105,1.138,1.000}, {-13.4,105,1.079,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000}, {-13.5,105,1.000,1.000} } }
local END_LOSE_TX = { c = { 0, 0 }, k = { {0,0,0.800,0.000}, {0,0,0.800,0.000}, {0,0,0.800,0.000}, {0,0,0.800,0.000}, {0,0,0.800,0.000}, {0,0,0.800,0.000}, {0,0,0.800,0.000}, {0,0,0.800,0.000}, {0,0,0.800,0.000}, {0,0,0.800,0.000}, {0,0,0.800,0.000}, {0,0,0.800,0.000}, {0,0,0.884,0.289}, {0,0,1.022,0.602}, {0,0,1.121,0.824}, {0,0,1.180,0.957}, {0,0,1.200,1.000}, {0,0,1.152,1.000}, {0,0,1.008,1.000}, {0,-1.1,0.936,1.000}, {0,-2.5,0.984,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,-3,1.000,1.000}, {0,0,0.800,0.000}, {0,0,0.800,0.000}, {0,0,0.800,0.000} } }
local END_TX = { win = { { "end_win_tx2", END_WIN_TX2 }, { "end_win_tx1", END_WIN_TX1 } },
                 lose = { { "end_lose_tx", END_LOSE_TX } } }

local END_HOLD = 3250          -- ms from the last section's end to the emblem (direct feed MBAZ: 153.0 -> 156.25); = skin_config zdon_ai_end_hold
local END_LOSE_S = 1.0         -- the data's own size (the lettering then equals the Green skin's end_over)
local END_WIN_OUT = 2300       -- ms: the win cut-in fades out (the cabinet's full combo / donderful banner follows)
local function draw_end(b, now)
    if not b.finished or b.skipped then G.end_ms = nil; return end   -- a skipped song goes straight to the result
    G.end_ms = G.end_ms or (now + END_HOLD)
    local kind = (b.result == "win") and "win" or "lose"
    local el = now - G.end_ms
    if el < 0 then return end   -- the last section's flash runs first (engine zdon_ai_end_hold)
    -- the loss ring is held to the result (the data's last frames are its own fade-out: not used)
    local f = math.min((kind == "lose") and 59 or (END_FRAMES[kind] - 1), math.floor(el * 30 / 1000))
    local S = (kind == "lose") and END_LOSE_S or 1.0
    local fade = (kind == "win") and (1 - math.max(0, math.min(1, (el - END_WIN_OUT) / 300))) or 1.0
    if fade <= 0 then return end
    -- win_mc / lose_mc without the language layers, from their own tracks (the ring is held before its fade-out)
    local mf = math.min(5 + el * 0.06, (kind == "lose") and 123 or 159)
    local LT = require("global.lumen_tracks")
    local def = require((kind == "win") and "global.ai_fx_endw" or "global.ai_fx_endl")
    -- lose_center_mc: the white burst (#137, depth 5) lies over the lettering (depth 4)
    local BURST = "lt_endl_137_0"
    LT.draw(def, mf, tx, 960, 540, S, fade, function(n) return n ~= BURST end)
    for _, part in ipairs(END_TX[kind]) do
        local ks = part[2].k
        local k0, k1 = ks[math.min(#ks, f + 1)], ks[math.min(#ks, f + 2)]
        if k0 and k1 then
            -- the keys are 30 fps: blended to the display's rate
            local u = el * 30 / 1000 - f
            if u >= 1 then u = 0 end   -- held on its last frame (the data's own fade-out is not used)
            local kx, ky, sc, al = k0[1] + (k1[1] - k0[1]) * u, k0[2] + (k1[2] - k0[2]) * u, k0[3] + (k1[3] - k0[3]) * u, k0[4] + (k1[4] - k0[4]) * u
            if al > 0 then
                put(part[1], 960 + S * (kx + part[2].c[1] * sc), 540 + S * (ky + part[2].c[2] * sc), sc * S, al * fade,
                    END_LANG[lang_frame()])
            end
        end
    end
    if kind == "lose" then LT.draw(def, mf, tx, 960, 540, S, fade, function(n) return n == BURST end) end
end


-- after the win cut-in the cabinet goes straight to its own full combo banner (ai_battle_result postprocess_mc:
-- dondaful_loop_mc "ドンダフルコンボ!!" for an all-good play, fullcombo_loop_mc "フルコンボ!!" otherwise; no fans, no
-- clear banner before it). Data frames 5.. at 60 fps, stored every 2nd frame: the ray burst (ban_*_fx, half size, full
-- screen), the spark band after it (ban_dd_sp) and the lettering (ban_*_tx1 / tx2, per language) placed from the
-- node's transform { x, y, scale, alpha, blend } (BAN_*: k[i] = data frame 5 + 2 * (i - 1))
local BAN_DD_TX1 = { c = { 0, 0 }, k = { {-16.2,0,3.000,0.000,0}, {-16.2,0,3.000,0.000,0}, {-16.2,0,3.000,0.000,0}, {-16.1,0,2.995,0.004,0}, {-15.9,0,2.959,0.020,0}, {-15.3,0,2.886,0.051,0}, {-14.6,0,2.772,0.102,0}, {-13.6,0,2.619,0.168,0}, {-12.2,0,2.429,0.250,0}, {-10.6,0,2.200,0.348,0}, {-8.8,0,1.934,0.465,0}, {-6.6,0,1.629,0.598,0}, {-4.2,0,1.286,0.746,0}, {-1.6,0,0.905,0.910,0}, {-0.1,0,0.708,1.000,0}, {-0.1,0,0.775,1.000,0}, {0,0,0.908,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0}, {0,0,1.000,1.000,0} } }
local BAN_DD_TX2 = { c = { 0, 0 }, k = { {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0,0,1.067,0.965,8}, {0,0,1.200,0.898,8}, {0,0,1.333,0.832,8}, {0,0,1.467,0.766,8}, {0,0,1.600,0.699,8}, {0,0,1.733,0.633,8}, {0,0,1.867,0.566,8}, {0,0,2.000,0.500,8}, {0,0,2.133,0.434,8}, {0,0,2.267,0.367,8}, {0,0,2.400,0.301,8}, {0,0,2.533,0.234,8}, {0,0,2.667,0.168,8}, {0,0,2.800,0.102,8}, {0,0,2.933,0.035,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0,0,3.000,0.000,8}, {0.3,0,1.000,0.051,8}, {0.2,0,1.000,0.148,8}, {0.2,0,1.000,0.250,8}, {0.1,0,1.000,0.352,8}, {0.1,0,1.000,0.449,8}, {0,0,1.000,0.492,8}, {0,0,1.000,0.473,8}, {0.1,0,1.000,0.457,8}, {0.1,0,1.000,0.441,8}, {0.1,0,1.000,0.422,8}, {0.1,0,1.000,0.406,8}, {0.1,0,1.000,0.391,8}, {0.1,0,1.000,0.371,8}, {0.1,0,1.000,0.355,8}, {0.1,0,1.000,0.340,8}, {0.1,0,1.000,0.320,8}, {0.1,0,1.000,0.305,8}, {0.1,0,1.000,0.289,8}, {0.1,0,1.000,0.270,8}, {0.1,0,1.000,0.254,8}, {0.1,0,1.000,0.238,8}, {0.1,0,1.000,0.219,8}, {0.2,0,1.000,0.203,8}, {0.2,0,1.000,0.188,8}, {0.2,0,1.000,0.168,8}, {0.2,0,1.000,0.152,8}, {0.2,0,1.000,0.137,8}, {0.2,0,1.000,0.117,8}, {0.2,0,1.000,0.102,8}, {0.2,0,1.000,0.086,8}, {0.2,0,1.000,0.066,8}, {0.2,0,1.000,0.051,8}, {0.3,0,1.000,0.035,8}, {0.3,0,1.000,0.016,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8}, {0.3,0,1.000,0.000,8} } }
local BAN_FC_TX1 = { c = { 0, 0 }, k = { {-22.2,-18,3.000,0.000,0}, {-18.6,-18,2.982,0.008,0}, {-8,-17.9,2.927,0.031,0}, {-0.3,-18,2.764,0.105,0}, {-1,-18,2.518,0.219,0}, {-1.7,-18,2.273,0.328,0}, {-2.4,-18,2.027,0.441,0}, {-3,-18.1,1.782,0.555,0}, {-3.7,-18.1,1.536,0.664,0}, {-4.4,-18,1.291,0.777,0}, {-5,-18.1,1.045,0.887,0}, {-5.7,-18,0.800,1.000,0}, {-5.7,-18,0.958,1.000,0}, {-5.7,-18.1,1.077,1.000,0}, {-5.7,-18.1,1.156,1.000,0}, {-5.7,-18.1,1.195,1.000,0}, {-5.7,-18,1.198,1.000,0}, {-5.7,-18,1.178,1.000,0}, {-5.7,-18,1.138,1.000,0}, {-5.7,-17.9,1.079,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0}, {-5.7,-18,1.000,1.000,0} } }
local BAN_FC_TX2 = { c = { 0, 0 }, k = { {-5.7,-18,1.000,0.000,8}, {-5.7,-18,1.000,0.000,8}, {-5.7,-18,1.000,0.000,8}, {-5.7,-18,1.000,0.000,8}, {-5.7,-18,1.000,0.000,8}, {-5.7,-18,1.000,0.000,8}, {-5.7,-18,1.000,0.000,8}, {-5.7,-18,1.000,0.000,8}, {-5.7,-18,1.000,0.000,8}, {-5.7,-18,1.000,0.000,8}, {-5.7,-18,1.000,0.000,8}, {-5.7,-18,1.000,0.000,8}, {-5.7,-18,1.000,0.000,8}, {-5.7,-18,1.000,0.000,8}, {-5.7,-18,1.000,0.000,8}, {-5.7,-18,1.000,0.000,8}, {-5.7,-18,1.000,0.000,8}, {-5.7,-18,1.000,0.000,8}, {-5.7,-18,1.000,0.000,8}, {-5.7,-18,1.000,0.000,8}, {-5.7,-18,1.000,1.000,8}, {-5.7,-18,1.133,0.934,8}, {-5.7,-18,1.267,0.867,8}, {-5.7,-18,1.400,0.801,8}, {-5.7,-18,1.533,0.734,8}, {-5.7,-18,1.667,0.668,8}, {-5.7,-18,1.800,0.602,8}, {-5.7,-18,1.933,0.535,8}, {-5.7,-18,2.067,0.465,8}, {-5.7,-18,2.200,0.398,8}, {-5.7,-18,2.333,0.332,8}, {-5.7,-18,2.467,0.266,8}, {-5.7,-18,2.600,0.199,8}, {-5.7,-18,2.733,0.133,8}, {-5.7,-18,2.867,0.066,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.7,-18,3.000,0.000,8}, {-5.8,-18.1,1.000,0.051,8}, {-5.8,-18.1,1.000,0.148,8}, {-5.8,-18.1,1.000,0.250,8}, {-5.8,-18.1,1.000,0.352,8}, {-5.8,-18.1,1.000,0.449,8}, {-5.8,-18.1,1.000,0.492,8}, {-5.8,-18.1,1.000,0.473,8}, {-5.8,-18.1,1.000,0.457,8}, {-5.8,-18.1,1.000,0.441,8}, {-5.8,-18.1,1.000,0.422,8}, {-5.8,-18.1,1.000,0.406,8}, {-5.8,-18.1,1.000,0.391,8}, {-5.8,-18.1,1.000,0.371,8}, {-5.8,-18.1,1.000,0.355,8}, {-5.8,-18.1,1.000,0.340,8}, {-5.8,-18.1,1.000,0.320,8}, {-5.8,-18.1,1.000,0.305,8}, {-5.8,-18.1,1.000,0.289,8}, {-5.8,-18.1,1.000,0.270,8}, {-5.8,-18.1,1.000,0.254,8}, {-5.8,-18.1,1.000,0.238,8}, {-5.8,-18.1,1.000,0.219,8} } }

local BAN = {
    dd = { tx1 = BAN_DD_TX1, tx2 = BAN_DD_TX2, fx = "ban_dd_fx", fx0 = 15, fxn = 54, sp = "ban_dd_sp", sp0 = 69, spn = 25 },
    fc = { tx1 = BAN_FC_TX1, tx2 = BAN_FC_TX2, fx = "ban_fc_fx", fx0 = 11, fxn = 61 },
}
local BAN_T = 2500            -- ms after the cut-in's start (the cut-in's own 2.5 s, direct feed MBAZ 156.0 -> 158.5)

local function draw_banner(b, now)
    if not (b.finished and b.result == "win") or b.skipped then return end
    local jp = b.judge_p
    if b.full_combo == false or not jp or (b.full_combo == nil and (jp[3] or 0) > 0) then return end   -- a full combo only
    local el = now - (G.end_ms or now) - BAN_T
    if el < 0 then return end
    local kind = ((b.total_ok or jp[2] or 0) == 0) and "dd" or "fc"
    local d = BAN[kind]
    if tex.ai_active and G.ban_snd ~= G.end_ms then   -- (YataiDON: global/ai_overlay.lua plays the AI battle's own) the banner's own SE + voice (footage 7ifN: a sharp cue 2.6 s after the cut-in's)
        G.ban_snd = G.end_ms
        local base = (kind == "dd") and "donderful_combo" or "full_combo"
        if audio.has_sound(base) then audio.play_sound(base, "sound") end
        if audio.has_sound(base .. "_voice") then audio.play_sound(base .. "_voice", "voice") end
    end
    local k = math.floor(el * 30 / 1000)
    -- the rays and sparks: dondaful_loop_mc / fullcombo_loop_mc without the lettering, from their own tracks
    require("global.lumen_tracks").draw(require((kind == "dd") and "global.ai_fx_band" or "global.ai_fx_banf"), 5 + el * 0.06, tx, 960, 540)
    for _, key in ipairs({ "tx1", "tx2" }) do
        local part = d[key]
        local r = part.k[math.min(#part.k, k + 1)]
        if r and r[4] > 0 then
            put("ban_" .. kind .. "_" .. key, 960 + r[1], 540 + r[2], r[3], r[4], END_LANG[lang_frame()])
        end
    end
end

-- Background:draw_fore, after both lanes: the end cut-ins and their dim lie over the lanes' combo numbers too
function AIB.draw_game_fore()
    if not AIB.active() then return end
    local b = battle()
    if not b then return end
    local now = tex.get_current_ms()
    draw_end(b, now)
    draw_banner(b, now)
end

-- YataiDON's own AI battle: what global/ai_overlay.lua and ai_section_result feed in
function AIB.up_begin()
    AIB.up = { screen = "AI_GAME", count = 0, section = 1, sections = {}, tug = 9, finished = false, wins_p = 0,
               judge_p = { 0, 0, 0, 0 }, judge_ai = { 0, 0, 0, 0 }, live_p = 0, live_ai = 0, progress = 0 }
    G.done, G.sig, G.first_ms, G.k, G.k_ms, G.closed, G.sweep = {}, nil, nil, 9, nil, 0, nil
    G.ready_ms, G.ready_sig, G.end_ms, G.total_ms, G.angry, G.fx_phase = nil, nil, nil, nil, nil, nil
end

function AIB.up_progress(section, count, progress)
    local up = AIB.up
    if up.count ~= count then
        up.count, up.sections = count, {}
        for i = 1, count do up.sections[i] = { winner = -1 } end
    end
    up.section, up.progress = math.min(section + 1, count), progress
end

function AIB.up_section(section, won)
    local sec = AIB.up.sections[section + 1]
    if sec then sec.winner = won and 0 or 1 end
    if won then AIB.up.wins_p = AIB.up.wins_p + 1 end
end

function AIB.up_finish(won, full_combo)
    AIB.up.finished, AIB.up.result, AIB.up.full_combo = true, won and "win" or "lose", full_combo
end

function AIB.up_territory(territory) AIB.up.tug = math.max(0, math.min(18, 9 + territory)) end
function AIB.up_angry(angry) AIB.up.live_p = angry and EMO_HIGH or EMO_LOW end
function AIB.up_clash_x() return AIB.up.clash_x end
function AIB.up_ready_age(now) return G.ready_ms and (now - G.ready_ms) or -1 end

function AIB.up_flames(now)
    local x = AIB.up.flame_x
    if not x then return end
    local kp = math.max(0, math.min(18, math.floor(G.k + 0.5)))
    local np, na = clash_p(kp), clash_ai(kp)
    draw_clash(np, clash_frame("cp", np, now), x, ARENA_Y, false)
    draw_clash(na, clash_frame("ca", na, now), x, ARENA_Y, true)
end

function AIB.up_result(sections, won)
    local list = {}
    for i, s in ipairs(sections) do
        local all = s.good + s.ok + s.bad   -- as the cabinet (AiEnsoGameManager): no bad = full combo, over 70% hit = clear
        local crown = (s.bad > 0) and (((s.good + s.ok) / all > 0.7) and 1 or 0) or ((s.ok > 0) and 2 or 3)
        list[i] = { winner = s.won and 0 or 1, good = s.good, ok = s.ok, bad = s.bad, roll = s.drumroll, crown = crown, score = 0 }
    end
    AIB.up = { screen = "AI_RESULT", finished = true, result = won and "win" or "lose", count = #list, sections = list }
end

-- the detail page: YataiDON keeps no per section score, so the total is shared out by each section's judges
-- (a good is worth one note, an ok half of one, a roll hit 100)
function AIB.up_section_scores(total)
    local up, weight, rolls = AIB.up, 0, 0
    for _, s in ipairs(up.sections) do weight, rolls = weight + s.good + s.ok / 2, rolls + s.roll * 100 end
    local note = (weight > 0) and math.max(0, total - rolls) / weight or 0
    for _, s in ipairs(up.sections) do
        s.score = math.floor((note * (s.good + s.ok / 2) + s.roll * 100) / 10 + 0.5) * 10
    end
end

-- the server's best play of each section, when it answered
function AIB.up_bests(bests)
    local better = false
    for i, s in ipairs(AIB.up.sections) do
        local b = bests[i]
        if b then
            s.best = { score = 0, good = b.good, ok = b.ok, bad = b.bad, roll = b.drumroll }
            if s.good ~= b.good then better = better or s.good > b.good
            elseif s.ok ~= b.ok then better = better or s.ok > b.ok
            elseif s.bad ~= b.bad then better = better or s.bad < b.bad
            else better = better or s.roll > b.drumroll end
        end
    end
    AIB.up.new_best = better
end

-- drawn by the AI lane's score counter (after its lane, so the AI board sits on its panel)
function AIB.draw_game()
    local b = battle()
    put("ai_plate", PLATE_X, PLATE_Y, PLATE_S)
    draw_text_at(txt(skin_str("ai_name", "AI"), 36, { 255, 255, 255, 255 }, { 30, 30, 30, 255 }, 3.5),
                 PLATE_X, PLATE_Y, "c")
    if not b then return end
    local now = tex.get_current_ms()
    -- a new song (or a restart): forget the pops
    local sig = tostring(b.count) .. ":" .. tostring(b.sections[1] and b.sections[1].end_ms)
    if G.sig ~= sig or (b.section == 1 and b.live_p == 0 and b.live_ai == 0 and next(G.done)) then
        G.done, G.sig, G.first_ms = {}, sig, nil
    end

    draw_board("board_don", b.judge_p, BOARD_P[1], BOARD_P[2])
    draw_board("board_ai", b.judge_ai, BOARD_AI[1], BOARD_AI[2])

    local n = b.count
    local strip = tx((n <= 3) and "sec_strip_3" or "sec_strip_5")
    if strip then
        put((n <= 3) and "sec_strip_3" or "sec_strip_5", STRIP_X0 + ((n <= 3) and 47 or 94), STRIP_CY + 4.5, 1.0)
    end
    for i, s in ipairs(b.sections) do
        local x = STRIP_X0 + (i - 1) * STEP
        local y = STRIP_CY + ((i % 2 == 1) and UP or DOWN)
        if not strip then put("pending", x, y, 64 * F / 230) end
        if s.winner >= 0 then
            G.done[i] = G.done[i] or now
            local age = now - G.done[i]
            local win = s.winner == 0
            if s.winner == 2 then
                put("flash", x, y, F, 0.45)
            else
                local big = win
                if big and age < BIGW_MS then
                    -- the cabinet's win diamond (section_result_icon win_mc: 勝 pops in big, flips to a blank gold
                    -- diamond, flashes, is the 勝 again and fades) at its own spot over the arena, from its own tracks
                    require("global.lumen_tracks").draw(require("global.ai_fx_secw"), math.min(118, 4 + age * 0.06), tx, BIGW_X, BIGW_Y, BIGW_S)
                end
                -- the strip's own icon: dark while the big one plays, then it pops in and settles
                local a = big and (age - BIGW_SMALL_MS) or age
                if a < 0 then
                    -- nothing: the pending diamond under it
                elseif a < SETTLE_MS then
                    -- pops in at 1.5x the icon (from 0.6x), then shrinks back to it; the glow fades out
                    local k = (a < POP_MS) and (0.6 + 0.9 * ease_out(a / POP_MS))
                              or (1.5 - 0.5 * ease_out((a - POP_MS) / (SETTLE_MS - POP_MS)))
                    put(win and "win_glow" or "lose_glow", x, y, 72 * F / 268 * k * 1.1, 1 - a / SETTLE_MS)
                    put(win and "win_big" or "lose_big", x, y, 72 * F / 268 * k)
                else
                    put(win and "win" or "lose", x, y, F)
                end
            end
        elseif not b.finished and i == b.section then
            local p = 0.5 + 0.5 * math.sin(now / 160)
            put("now_glow", x, y, F * 1.15, 0.35 + 0.4 * p)
            put("now", x, y, F, 0.75 + 0.25 * p)
        end
    end
    -- the crown waits for the last section's big win diamond to go (direct feed MBAZD6xA1D8 154.5 -> 155.0)
    local last_big = b.sections[n] and b.sections[n].winner == 0 and G.done[n] and now - G.done[n] < BIGW_SMALL_MS
    if b.finished and not last_big then
        -- 1:1 art, right of the last icon (direct feed MBAZD6xA1D8 155.5: centre 624,145 with five sections)
        put(crown_name(b), STRIP_X0 + (n - 1) * STEP + 161, STRIP_CY - 47, 1.0)
    end

    -- the section timer: the open section's progress, its name on the left
    if not b.finished and (b.progress or tex.song_progress) then
        local pos = (not b.progress) and tex.song_progress(1)
        local s = b.sections[b.section]
        if (pos or b.progress) and s then
            local frac = b.progress
            if not frac then
                local start = (b.section > 1) and b.sections[b.section - 1].end_ms or (G.first_ms or pos)
                G.first_ms = G.first_ms or pos
                frac = math.max(0, math.min(1, (pos - start) / math.max(1, s.end_ms - start)))
            end
            -- section_timer progressbar_mc (lumen_anim_dump): ONE 8x24 shape (timer_fill) stretched and tinted by the movie's own
            -- colour transforms: the track 192 px at (304, 287) tinted (94,94,94); the fill from x = 308, 3.68 px per step of
            -- 50 (labels num_0..num_50), green (0,255,0) for steps 1..33, nothing at 34, then the yellow warning (255,255,0)
            -- from step 35 on whose alpha is a triangle wave over 18 frames at 60 fps (a = |t mod 18 - 9| / 9). The black
            -- rounded housing (timer_frame, its hole transparent) is drawn over the bar's ends.
            local fill = tx("timer_fill")
            if fill then
                tex.draw_texture(fill.t, { x = FILL_X, y = FILL_Y, x2 = FILL_W - fill.w, y2 = FILL_H - fill.h,
                                           color = { 94, 94, 94, 255 } })
                local step = math.floor(frac * 50 + 1e-6)
                if step < 35 then G.warn_t0 = nil end
                if step >= 1 and step ~= 34 then
                    local col, a = { 0, 255, 0, 255 }, 1.0
                    if step >= 35 then
                        col = { 255, 255, 0, 255 }
                        -- direct feed MBAZD6xA1D8 41-48 s (60 fps): the pulse period is 19 frames (not 18), 0 -> 1 -> 0, its
                        -- first trough 4 frames after the fill passes step 35
                        if not G.warn_t0 then G.warn_t0 = now end
                        a = 1 - math.abs((((now - G.warn_t0) * 0.06) - 4) % 19 - 9.5) / 9.5
                    end
                    tex.draw_texture(fill.t, { x = FILL_X + 4, y = FILL_Y, x2 = 3.68 * step - fill.w,
                                               y2 = FILL_H - fill.h, color = col, fade = a })
                end
            end
            put("timer_frame", TIMER_CX, TIMER_CY, 1.0)
            -- the cabinet's own "n区" lettering (section_timer section_text, ai_section_n, rendered with the glyph atlases:
            -- tx_sec1..5, frame = language), drawn at the movie's stage position; font text when the art is missing
            local sl = (b.section >= 1 and b.section <= 5) and tx("tx_sec" .. tostring(b.section))
            if sl then
                local o = TX_SEC[b.section]
                tex.draw_texture(sl.t, { x = o[1], y = o[2], frame = tx_lang_frame() })
                -- the right end of the bar names the next section (section_tx_02_mc, right aligned)
                local nr = (b.section < b.count) and tx("tx_secr" .. tostring(b.section + 1))
                if nr then tex.draw_texture(nr.t, { x = TX_SECR[b.section + 1][1], y = TX_SECR[b.section + 1][2], frame = tx_lang_frame() }) end
            else
                local label = (skin_str("ai_section", "{0}"):gsub("{0}", tostring(b.section)))
                draw_text_at(txt(label, 18, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, 3), 306, TIMER_CY - 22, "l")
            end
        end
    end
end

------------------------------------------------------------------------------------------------ result
-- RESULT_2P of an AI battle: the AI's half is the cabinet's VS panel (result_ai_section, ai_mc at 1414,595),
-- run the way AiResultSectionMain.lua does:
--   * simple view: "VS.AIどん" over the top with the AI's head, one tab per section; the section icons come in
--     one after another (win_in / lose_in, 15 frames each, se "section")
--   * a second after the last one, once the player's board has counted up, the battle emblem (win: rays, glow,
--     laurel, "battle won"; loss: the silver AI diamond) at the panel's foot (battle_win_mc 1415,787), se win / lose
--   * then the win-count window (main "win"): total wins (counts up on a win after 4 s), the wins to the next
--     reward (counts down 2 s later), then the window's shine (se number_window_shine; the "achieved" voice when
--     a reward is reached). The reward itself is not given (Z-DON has none)
--   * kat (tex.ai_battle().detail): the detail view, one card per section with its badge, crown, score, judges
--     and, on a new best play, the gains over the best play's section (best score plate, count plus / minus)
-- The cards, plates and digits are the cabinet's (rendered by the tlb harness, digits hidden: frames = languages).
local PANEL_X, PANEL_Y = 1414, 595
local SEC_CX, SEC_STEP = 1414, 154   -- section_3 154 apart; section_5 157.5 (simple_mc_n at -315, -158, 0, 158, 315)
local TX_TAB = { [3] = { [1] = { 1220, 297 }, [2] = { 1372, 367 }, [3] = { 1526, 297 } }, [5] = { [1] = { 1059, 297 }, [2] = { 1214, 367 }, [3] = { 1372, 297 }, [4] = { 1529, 367 }, [5] = { 1687, 297 } } }   -- top-left of the baked tab art (stage px)
local SEC_TAB_Y = { 311, 381 }                     -- odd / even sections
local SEC_ICON_Y = { 446, 510 }
local SEC_ICON_S = 0.62
local EMB_X, EMB_Y, EMB_S = 1415, 797, 1.0   -- arcade capture MBAZD6xA1D8: the plate is 370 px wide, centre (1415, 827)
local EMB_GROW = 220
-- direct-feed result clips (inBBd4tbOQE, BRvDlveUY0I, 0vjiSUv61i4): the VS panel comes in 1.85 s after the player's
-- board is done, all section icons flip together (one section SE) 0.55 s later, the emblem 0.75 s after that; the
-- win window opens 3.85 s after the emblem, its total changes 1.95 s later, the next reward 1.0 s and the shine 1.0 s after that
local PANEL_AFTER_MS = 1783
local ICON_IN_MS, ICON_FIRST_MS, ICON_WAIT_MS = 0, 457, 750
local WIN_AFTER_MS = 3850                          -- the AI's motion between the emblem and the win count
local WIN_FADE_MS, WIN_TOTAL_MS, WIN_NEXT_MS, WIN_FLASH_MS = 250, 1700, 1000, 1000
-- detail cards (stage px): section_5 / section_3 first card, 177 apart; everything else card-relative
local CARD_X = { [5] = 966, [3] = 1143 }
local CARD_Y, CARD_STEP = 267, 177
local D = {
    badge = { 20, 51 }, crown = { 103, 63 }, best = { 11, 129 },
    plus = { { 117, 190 }, { 117, 225 }, { 117, 262 }, { 117, 297 } },
    score = { 142, 169, 16 }, count = { 161, 216, 14, 36 }, best_d = { 154, 143, 9 }, plate = { 159, 197, 8, 36 },
}
-- the window as the cabinet authors it (top left 502,713; digits right-aligned at 792, 28.4 apart, total y 791,
-- next y 857), moved into the VS panel's free bottom-left corner at WIN_S (Nijiiro's player board fills the
-- cabinet's spot)
local WIN_SRC = { 502, 713 }
local WIN_POS, WIN_S = { 502, 713 }, 1.0   -- round 3a: direct feed inBBd4tbOQE 0:11 / BRvDlveUY0I: the window sits in the player board's bottom right (body x520..829, y732..877)
local WIN_DIGIT_X, WIN_STEP, WIN_TOTAL_Y, WIN_NEXT_Y = 792, 28.4, 791, 857
local function win_xy(x, y)
    return WIN_POS[1] + (x - WIN_SRC[1]) * WIN_S, WIN_POS[2] + (y - WIN_SRC[2]) * WIN_S
end
-- the wins that hand out the AI battle rewards (datatable reward, ai_battle wins)
local REWARD_WINS = { 1, 2, 10, 25, 50, 75, 100, 125, 150, 175, 200, 250, 300, 350, 400, 500, 600, 765, 876, 1000,
                      2000, 3000, 4000, 5000, 10000 }
local R = { t0 = nil, last = -1e9 }

local function sfx(name, preset)
    if not tex.ai_active then   -- YataiDON's sound names for the result (Sounds/ai_section_result)
        name = ({ ai_section = "se_section_mark", ai_win = "se_logo_win", ai_lose = "se_logo_lose" })[name] or name
    end
    if audio and audio.has_sound and audio.has_sound(name) then audio.play_sound(name, preset or "sound") end
end

-- digits of v right-aligned from slot 1 at (x, y), step apart (textures are 80x80 around the glyph's origin)
local function digits(name, v, x, y, step, max_digits, sc)
    local t = tx(name)
    if not t then return end
    sc = sc or 1
    local s = tostring(math.max(0, math.floor(v or 0)))
    if #s > max_digits then s = string.rep("9", max_digits) end
    for k = 1, #s do
        tex.draw_texture(t.t, { x = x - step * sc * (k - 1) - 40 * sc, y = y - 40 * sc, scale = sc,
                                frame = s:byte(#s - k + 1) - 48 })
    end
end

local function next_reward(wins)
    for _, w in ipairs(REWARD_WINS) do
        if w > wins then return w - wins end
    end
    return 0
end

-- The reward windows (N52). When a win reaches a reward's total (next_reward(wins - 1) == 1) the cabinet follows the
-- win window with a second window on the player's board: "reward get", a rainbow wagara plate with the reward's
-- category pill, its name and a "next" button, popping in over the Don and the bubble, and out again to the red
-- wagara panel. Direct feed inBBd4tbOQE (60 fps; the win window opens at 9.86 s, shine 13.88): wagara_window_open
-- 15.42 + number_window_open 15.82 (asset match 0.46 / 0.58), the plate fades in from 15.45, the name at 15.9, the
-- button at 16.3, the plate leaves 22.0-22.4. The last reward adds the gold "complete" window: wagara_window_open
-- 23.99 + number_window_open 24.38 (0.62 / 0.54). Times below are from the win window's opening.
-- Z-DON hands out no reward: the plate shows what the cabinet would (name text from the wordlist, see ai_rewards.lua).
local RWD = require("global.ai_rewards")
local RW_WAGARA_MS, RW_NUMBER_MS = 5560, 5960
local RW_NAME_MS, RW_BUTTON_MS = 6040, 6450
local RW_CLOSE_MS, RW_CLOSE_FADE_MS = 12100, 400
local RW_DONE_WAGARA_MS, RW_DONE_NUMBER_MS = 14130, 14520
local RW_CX, RW_CY, RW_S = 480, 784, 1.0       -- the plate's centre and scale (807 x 264 px in the feed, art 858 x 312)

local function rw_text(t)
    local l = tex.language and tex.language() or "ja"
    return t[l] or t.ja or ""
end

-- the reward reached by this win, or nil
local function reward_reached(b)
    if not SHOW_PROGRESS or b.result ~= "win" or not tex.ai_wins or not tex.ai_next_reward then return nil end   -- no reward system: no title window
    local wins = tex.ai_wins()
    if next_reward(math.max(0, wins - 1)) ~= 1 then return nil end
    return RWD.rewards[wins], (tex.ai_next_reward and tex.ai_next_reward() or 1) == 0
end

local function rw_put(name, x, y, s, a, rot, color)
    if not color then return put(name, x, y, s, a, nil, rot) end
    local t = tx(name)
    if not t then return end
    tex.draw_texture(t.t, { x = x - t.w / 2, y = y - t.h / 2, center = true, scale = s, fade = a, color = color })
end

local function rw_once(key, fn)
    R.cue = R.cue or {}
    if not R.cue[key] then R.cue[key] = true; fn() end
end

function AIB.draw_result_front()
    local b = battle()
    if not b or not b.finished or not R.win_ms then return end
    local item, last = reward_reached(b)
    if not item then return end
    local now = tex.get_current_ms()
    local age = now - R.win_ms
    if age < RW_WAGARA_MS then return end
    rw_once("rw_wagara", function() sfx("ai_wagara_window_open") end)
    if age >= RW_NUMBER_MS then rw_once("rw_number", function() sfx("ai_number_window_open") end) end

    -- the reward plate
    local close = age - RW_CLOSE_MS
    if close < RW_CLOSE_FADE_MS then
        local t = age - RW_WAGARA_MS
        local a = math.min(1, t / 150)
        local k = 1 + 0.18 * (1 - ease_out(t / 300))
        if close > 0 then a = a * (1 - close / RW_CLOSE_FADE_MS) end
        rw_put("rw_win", RW_CX, RW_CY, RW_S * k, a)
        local nt = age - RW_NAME_MS
        if nt >= 0 then
            local na = math.min(1, nt / 150) * ((close > 0) and (1 - close / RW_CLOSE_FADE_MS) or 1)
            -- the flowers and triangles that burst out of the name (reward_panel_ai), then fade
            local sp = math.max(0, 1 - nt / 900) * na
            if sp > 0 then
                local sx = 230 + 40 * ease_out(nt / 600)
                rw_put("rw_spark_a", RW_CX - sx, RW_CY - 10, 1.0, sp, -nt * 0.02)
                rw_put("rw_spark_b", RW_CX + sx, RW_CY - 10, 1.0, sp, nt * 0.02)
            end
            rw_put("rw_pill", RW_CX, 713, 1.36, na, nil, { 22, 140, 30, 255 })
            draw_text_at(txt(rw_text(item.label), 20, { 255, 255, 255, 255 }, { 22, 140, 30, 255 }, 0), RW_CX, 713, "c")
            draw_text_at(txt(rw_text(item.name), 46, { 70, 175, 50, 255 }, { 255, 255, 255, 255 }, 5), RW_CX, 765, "c")
            local bt = age - RW_BUTTON_MS
            if bt >= 0 then
                local ba = math.min(1, bt / 150) * ((close > 0) and (1 - close / RW_CLOSE_FADE_MS) or 1)
                rw_put("rw_btn_glow", RW_CX, 835, 1.0, ba * (0.55 + 0.45 * math.sin(bt / 160)))
                rw_put("rw_btn", RW_CX, 835, 1.0, ba)
                draw_text_at(txt(rw_text(RWD.next_label), 26, { 50, 25, 0, 255 }, { 255, 255, 255, 0 }, 0), RW_CX, 835, "c")
                local ss = math.max(0, 1 - bt / 700) * ba
                if ss > 0 then
                    rw_put("rw_star", RW_CX - 395, 880, 1.0, ss, bt * 0.05)
                    rw_put("rw_star", RW_CX + 395, 880, 1.0, ss, -bt * 0.05)
                end
            end
        end
    end

    -- the last reward: the gold "complete" window (wagara)
    if last and age >= RW_DONE_WAGARA_MS - 800 then
        if age >= RW_DONE_WAGARA_MS then rw_once("rw_done_wagara", function() sfx("ai_wagara_window_open") end) end
        local t = age - (RW_DONE_WAGARA_MS - 800)
        local a = math.min(1, t / 300)
        rw_put("rw_win_gold", RW_CX, RW_CY, RW_S, a)
        rw_put("rw_rays", RW_CX, RW_CY + 40, 0.9, a * 0.8)
        rw_put("rw_caption", RW_CX, RW_CY - 70, 0.95, a)
        draw_text_at(txt(rw_text(RWD.complete), 40, { 235, 40, 40, 255 }, { 255, 255, 255, 255 }, 5), RW_CX, RW_CY - 75, "c")
        if age >= RW_DONE_NUMBER_MS then rw_once("rw_done_number", function() sfx("ai_number_window_open") end) end
    end
end

local function draw_detail(b)
    local n = b.count
    local x0 = CARD_X[n] or CARD_X[5]
    for i, sec in ipairs(b.sections) do
        local x, y = x0 + (i - 1) * CARD_STEP, CARD_Y
        local card = tx("detail_card_" .. i)
        if card then tex.draw_texture(card.t, { x = x, y = y, frame = lang_frame() }) end
        local bd = tx("detail_badge")
        if bd and sec.winner >= 0 then
            tex.draw_texture(bd.t, { x = x + D.badge[1], y = y + D.badge[2], frame = (sec.winner == 0) and 0 or 1 })
        end
        local cr = tx("detail_crown")
        if cr and (sec.crown or 0) > 0 then
            tex.draw_texture(cr.t, { x = x + D.crown[1], y = y + D.crown[2], frame = math.min(3, sec.crown) - 1 })
        end
        digits("rd_score", sec.score, x + D.score[1], y + D.score[2], D.score[3], 7)
        local counts = { sec.good, sec.ok, sec.bad, sec.roll }
        for r = 1, 4 do
            digits("rd_count", counts[r], x + D.count[1], y + D.count[2] + D.count[4] * (r - 1), D.count[3], 4)
        end
        -- a new best play: what each section gained over the best play's (AiResultSectionMain SetSectionDeteil)
        local best = sec.best
        if b.new_best and best then
            if best.score ~= 0 and best.score < sec.score then
                local bp = tx("detail_best")
                if bp then tex.draw_texture(bp.t, { x = x + D.best[1], y = y + D.best[2], frame = lang_frame() }) end
                digits("rd_best", sec.score - best.score, x + D.best_d[1], y + D.best_d[2], D.best_d[3], 7)
            end
            local olds = { best.good, best.ok, best.bad, best.roll }
            for r = 1, 4 do
                local old, now = olds[r], counts[r]
                local more_is_better = (r == 1 or r == 4)
                local gain = more_is_better and (now - old) or (old - now)
                if old ~= 0 and gain > 0 then
                    local pt = tx("detail_plus_" .. r)
                    if pt then
                        tex.draw_texture(pt.t, { x = x + D.plus[r][1], y = y + D.plus[r][2],
                                                 frame = more_is_better and 0 or 1 })
                    end
                    digits("rd_plate", gain, x + D.plate[1], y + D.plate[2] + D.plate[4] * (r - 1), D.plate[3], 4)
                end
            end
        end
    end
end

local function draw_win_count(b, age)
    if not tex.ai_wins then return end
    local win = b.result == "win"
    local now_wins = math.max(0, tex.ai_wins())
    local before = win and math.max(0, now_wins - 1) or now_wins
    local need_before = next_reward(before)
    local shown_total, shown_next = before, need_before
    if win and age >= WIN_FADE_MS + WIN_TOTAL_MS then shown_total = now_wins end
    if win and age >= WIN_FADE_MS + WIN_TOTAL_MS + WIN_NEXT_MS then shown_next = math.max(0, need_before - 1) end
    local w = tx("win_window")
    if not w then return end
    if age >= RW_WAGARA_MS and reward_reached(b) then return end   -- the reward window takes its place
    local a = math.min(1, age / WIN_FADE_MS)
    tex.draw_texture(w.t, { x = WIN_POS[1], y = WIN_POS[2], scale = WIN_S, frame = lang_frame(), fade = a })
    if a < 1 then return end
    local x, y = win_xy(WIN_DIGIT_X, WIN_TOTAL_Y)
    digits("rw_total", math.min(999999, shown_total), x, y, WIN_STEP, 6, WIN_S)
    if need_before > 0 then
        x, y = win_xy(WIN_DIGIT_X, WIN_NEXT_Y)
        digits("rw_next", shown_next, x, y, WIN_STEP, 4, WIN_S)
        local lx = win_xy(WIN_SRC[1] + 30, WIN_NEXT_Y)
        draw_text_at(txt(skin_str("ai_next_reward", ""), 15, { 60, 60, 60, 255 }, { 255, 255, 255, 255 }, 0),
                     lx, y, "l")
    end
    -- the shine (normal_flash)
    local fl = age - (WIN_FADE_MS + WIN_TOTAL_MS + WIN_NEXT_MS + WIN_FLASH_MS)
    if fl >= 0 and fl < 600 then
        local k = WIN_S * (1 + 0.06 * ease_out(fl / 600))
        tex.draw_texture(w.t, { x = WIN_POS[1] - w.w * (k - WIN_S) / 2, y = WIN_POS[2] - w.h * (k - WIN_S) / 2,
                                scale = k, frame = lang_frame(), fade = 0.5 * (1 - fl / 600) })
    end
end

-- The credit's last AI song (tex.ai_battle().play_all, the engine's song_limit): the cabinet's play-all window
-- (result_ai_playall, AiResultPlayAllMain.lua) over the whole result: one row per song of the credit with its
-- score, crown, score rank and per section score and crown; the rows come in one after another
local PA_WIN = { 14, 4 }
local PA_LABEL_X, PA_LABEL_Y = 739, { 279, 197, 110, 79 }   -- the window's "best score" label, by song count
local PA_BASE_X = 262
local PA_BASE_Y = { { 441 }, { 358, 561 }, { 254, 457, 660 }, { 176, 372, 568, 764 } }
local PA = { crown = { 509, 81 }, rank = { 365, 71 }, score = { 289, 141, 36 }, title = { 630, 27 },
             sec_crown = { 661, 85 }, sec_score = { 731, 166, 14 }, sec_step = 122 }
local PA_FADE_MS, PA_ROW_MS = 250, 180
local SCORE_RANKS = { 500000, 600000, 700000, 800000, 900000, 950000, 1000000 }   -- 粋 white .. 極

local function song_crown(song)
    if not song.cleared then return 0 end
    if song.bad == 0 and song.ok == 0 then return 3 end
    if song.bad == 0 then return 2 end
    return 1
end

local function score_rank(score)
    local r = 0
    for k, v in ipairs(SCORE_RANKS) do if score >= v then r = k end end
    return r
end

local function draw_play_all(age)
    local songs = tex.ai_credit and tex.ai_credit() or {}
    local n = math.min(4, #songs)
    if n == 0 then return end
    local first = #songs - n + 1
    local w = tx("pa_window_" .. n)
    local a = math.min(1, age / PA_FADE_MS)
    -- the cabinet's play-all runs over the AI select room (dummy_bg = ai_song_select_bg)
    local bg = tx("pa_bg")
    if bg then tex.draw_texture(bg.t, { x = 0, y = 0, fade = a }) end
    if w then tex.draw_texture(w.t, { x = PA_WIN[1], y = PA_WIN[2], fade = a }) end
    local lb = tx("pa_label")
    if lb then tex.draw_texture(lb.t, { x = PA_LABEL_X, y = PA_LABEL_Y[n], frame = lang_frame(), fade = a }) end
    for i = 1, n do
        local song = songs[first + i - 1]
        local ra = math.max(0, math.min(1, (age - PA_FADE_MS - PA_ROW_MS * (i - 1)) / PA_ROW_MS))
        if ra <= 0 then break end
        local x, y = PA_BASE_X, PA_BASE_Y[n][i]
        local secs = song.sections or {}
        local base = tx("pa_base_" .. ((#secs <= 3) and 3 or 5))
        if base then tex.draw_texture(base.t, { x = x, y = y, frame = lang_frame(), fade = ra }) end
        if ra >= 1 then
            draw_text_at(txt(song.title or "", 26, { 255, 255, 255, 255 }, { 0, 90, 90, 255 }, 3),
                         x + PA.title[1], y + PA.title[2], "c")
            local c = song_crown(song)
            local ct = tx("pa_crown")
            if ct and c > 0 then tex.draw_texture(ct.t, { x = x + PA.crown[1], y = y + PA.crown[2], frame = c - 1 }) end
            local r = score_rank(song.score or 0)
            local rt = tx("pa_rank")
            if rt and r > 0 then tex.draw_texture(rt.t, { x = x + PA.rank[1], y = y + PA.rank[2], frame = r - 1 }) end
            digits("pa_song_digit", song.score, x + PA.score[1], y + PA.score[2], PA.score[3], 7)
            for j, sec in ipairs(secs) do
                local dx = PA.sec_step * (j - 1)
                local sc = tx("pa_sec_crown")
                if sc and (sec.crown or 0) > 0 then
                    tex.draw_texture(sc.t, { x = x + PA.sec_crown[1] + dx, y = y + PA.sec_crown[2],
                                             frame = math.min(3, sec.crown) - 1 })
                end
                digits("pa_sec_digit", sec.score, x + PA.sec_score[1] + dx, y + PA.sec_score[2], PA.sec_score[3], 7)
            end
        end
    end
end

-- ready: the player's board has finished counting up (its rank plate is out); the emblem waits for it
function AIB.draw_result(ready)
    local b = battle()
    if not b or not b.finished then return end
    if b.play_all then
        local now = tex.get_current_ms()
        R.pa = R.pa or now
        R.last = now
        draw_play_all(now - R.pa)
        return
    end
    local now = tex.get_current_ms()
    if now - R.last > 1000 then R = { t0 = now, last = now, cue = {} } end   -- a new result screen
    R.last = now
    if ready and not R.rd then R.rd = now end
    if not R.rd or now - R.rd < PANEL_AFTER_MS then return end   -- the AI's half waits for the player's board
    local age = now - R.rd - PANEL_AFTER_MS
    local function once(key, fn) if not R.cue[key] then R.cue[key] = true; fn() end end

    -- result_ai_section main "in" (frames 5..19, ai_mc about 1414,595): y scale 1 -> 1.35 at f12 -> 1, alpha 0 -> 0.54 -> 1
    local inf = age * 60 / 1000
    local pa, sy = 1, 1
    if inf < 7 then pa, sy = 0.54 * inf / 7, 1 + 0.35 * inf / 7
    elseif inf < 14 then pa, sy = 0.54 + 0.46 * (inf - 7) / 7, 1.35 - 0.35 * (inf - 7) / 7 end
    local function vy(y) return PANEL_Y + (y - PANEL_Y) * sy end
    local function sput(name, cx, cy, s, a)
        local t = tx(name)
        if not t then return end
        local w, h = t.w * s, t.h * s * sy
        tex.draw_texture(t.t, { x = cx - w / 2, y = vy(cy) - h / 2, scale = 0, x2 = w, y2 = h, fade = a })
    end
    local function label(s, size, th, cx, cy)
        local t = txt(s, size, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, th)
        if t then t:draw({ x = math.floor(cx - t.width / 2 + 0.5), y = math.floor(vy(cy) - t.height / 2 + 0.5), fade = pa }) end
    end
    sput("panel", PANEL_X, PANEL_Y, 1, pa)
    do   -- tx_versus (size 34, border 4): black lettering on a white rim
        local t = txt(skin_str("ai_versus", "VS. AI"), 34, { 0, 0, 0, 255 }, { 255, 255, 255, 255 }, 4)
        if t then t:draw({ x = math.floor(PANEL_X - 2 - t.width / 2 + 0.5), y = math.floor(vy(238) - t.height / 2 + 0.5), fade = pa }) end
    end
    sput("robot", 1755, 207, 0.295, pa)

    local n = b.count
    if b.detail then
        draw_detail(b)
    else
        for i, sec in ipairs(b.sections) do
            local x = SEC_CX + (i - (n + 1) / 2) * ((n >= 5) and 157.5 or SEC_STEP)
            local row = (i % 2 == 1) and 1 or 2
            sput("sec_tab", x, SEC_TAB_Y[row], 1, pa)
            -- the tab lettering (result_ai_section tx_section: size 22, border 2.5): white on a black rim
            label((skin_str("ai_section", "{0}"):gsub("{0}", tostring(i))), 22, 3, x, SEC_TAB_Y[row] + 3)
            local y = SEC_ICON_Y[row]
            local t_in = age - (ICON_FIRST_MS + ICON_IN_MS * (i - 1))
            -- result_ai_section simple_mc (256 px at 1:1): the dark base, then win_in (frames 5..19: the icon
            -- 1.5x -> 1x fading in to frame 10, a 1.1x bounce to 16, the white flash grows to 1.2x and fades from
            -- 13) or lose_in (frames 26..39: the icon fades in)
            sput("sec_base", x, y, 1.0, pa)
            if t_in >= 0 and sec.winner >= 0 then
                once("sec", function() sfx("ai_section") end)
                local f = t_in * 60 / 1000 + 5
                if sec.winner == 0 then
                    local sc, a = 1, 1
                    if f < 10 then sc, a = 1.5 - 0.1 * (f - 5), 0.2 * (f - 5)
                    elseif f < 13 then sc = 1 + 0.1 * (f - 10) / 3
                    elseif f < 16 then sc = 1.1 - 0.1 * (f - 13) / 3 end
                    put("sec_win", x, y, sc, a)
                    if f < 13 then put("sec_flash", x, y, sc, a)
                    elseif f < 19 then put("sec_flash", x, y, 1.1 + 0.1 * (f - 13) / 6, 1 - (f - 13) / 6) end
                else
                    put("sec_lose", x, y, 1.0, math.max(0, math.min(1, (f - 6) / 13)))
                end
            end
        end
    end

    if not ready or b.result == "draw" then return end
    local icons_done = ICON_FIRST_MS + ICON_IN_MS * n + ICON_WAIT_MS
    R.emb = R.emb or math.max(age, icons_done)
    local e = age - R.emb
    if e < 0 then return end
    once("emblem", function() sfx(b.result == "win" and "ai_win" or "ai_lose") end)
    local s = EMB_S * (1.8 - 0.8 * ease_out(e / EMB_GROW))
    local a = math.min(1, e / 120)
    if b.result == "win" then
        -- battle_win_mc at 1415,787, by depth: halo 0, laurel 1, spokes 2, flying triangles 3..8, rays 9, lettering 10, sparkles 12..15
        local FX = require("global.ai_result_fx_data")
        local efr = e * 60 / 1000
        if efr >= 259 then efr = 20 + (efr - 20) % 239 end
        -- the tracks hold every movie frame; between two frames everything is interpolated (rotation the short way, a
        -- restart of a flying piece is not blended)
        local function sample(t)
            local i = math.floor(efr)
            local u = efr - i
            local p, q = t[math.min(#t, i + 1)], t[math.min(#t, i + 2)]
            if not p then return nil end
            if math.abs(q[1] - p[1]) + math.abs(q[2] - p[2]) > 80 then q = p end
            return p[1] + (q[1] - p[1]) * u, p[2] + (q[2] - p[2]) * u, p[3] + (q[3] - p[3]) * u, p, q, u
        end
        local function piece(tr)
            local pt = tx(tr.tex)
            if not pt then return end
            local x, y, sc, p, q, u = sample(tr.k)
            if not x then return end
            local al = p[5] + (q[5] - p[5]) * u
            if al > 0.004 then
                local w, h = pt.w * sc, pt.h * sc
                local rot = p[4] + (((q[4] - p[4] + 180) % 360) - 180) * u
                tex.draw_texture(pt.t, { x = 1415 + x, y = 787 + y, scale = sc, rotation = rot, origin = { w / 2, h / 2 },
                                         fade = al, blend = tr.add and "additive" or nil })
            end
        end
        for _, tr in ipairs(FX.emblem) do if tr.depth == 0 then piece(tr) end end
        -- the laurel (#293) fades in over frames 9..20 with a small swell to 1.058 at 17
        local ifr = e * 60 / 1000
        if ifr >= 9 then
            local ls = (ifr < 17 and 1 + 0.00725 * (ifr - 9)) or (ifr < 20 and 1.058 - 0.0193 * (ifr - 17)) or 1
            put("laurel", EMB_X, 787 + 14 * ls, ls, math.min(1, (ifr - 9) / 11))
        end
        for _, tr in ipairs(FX.emblem) do if tr.depth >= 2 then piece(tr) end end
        -- the lettering (win_mc): 1 -> 2 fading in to frame 5, down to 0.85 at 9, up to 1.087 at 17, settling at 20
        local ts, ta = 1, 1
        if ifr < 5 then ts, ta = 1 + 0.2 * ifr, ifr / 5
        elseif ifr < 9 then ts = 2 - 0.2875 * (ifr - 5)
        elseif ifr < 17 then ts = 0.85 + 0.0296 * (ifr - 9)
        elseif ifr < 20 then ts = 1.087 - 0.029 * (ifr - 17) end
        put("win_text", EMB_X, 787 - 5 * ts, ts, ta, lang_frame())
        if ifr >= 9 and ifr < 17 and tx("em_flash") then   -- win_flash: the white silhouette grows and fades
            put("em_flash", EMB_X, 787 - 5 * ts, 0.85 + 0.12 * (ifr - 9), 0.5 * (1 - (ifr - 9) / 8), math.min(3, lang_frame()))
        end
        -- battle_win_mc's four sparkles (sprite 290 at 1415,787; "in" to frame 20, then its loop to 258)
        local sp_t = tx("em_spark")
        if sp_t then
            -- each is one star whose alpha pulses over 60 frames (sprite 290), inside its own track's alpha
            local curve = FX.spark_alpha
            for _, tr in ipairs(FX.spark) do
                local x, y, sc, p, q, u = sample(tr)
                if x then
                    local inner = p[5] + u
                    local i0 = math.floor(inner) % 60
                    local v = curve[i0 + 1] + (curve[(i0 + 1) % 60 + 1] - curve[i0 + 1]) * (inner - math.floor(inner))
                    local al = (p[4] + (q[4] - p[4]) * u) * v
                    if al > 0.004 then
                        local w = 200 * sc
                        tex.draw_texture(sp_t.t, { x = 1415 + x - w / 2, y = 787 + y - w / 2, scale = 0, x2 = w, y2 = w, fade = al * a })
                    end
                end
            end
        end
    else
        -- battle_lose_mc (1415,787 at 1:1): "in" 13 frames, then the ring's loop (480 frames, stored every 4th)
        -- under the language's lettering (lose_mc, its own fade-in over 20 frames); the crop's origin is 459,400
        local f = e * 60 / 1000
        -- the ring from the movie's own tracks: "in" to 13, then a 480-frame loop
        require("global.lumen_tracks").draw(require("global.ai_fx_lemb"), (f < 13) and f or (13 + (f - 13) % 479), tx, PANEL_X + 1, 787)
        local lt = tx("lemb_tx_" .. ({ [0] = "ja", "en", "ko", "tw", "tw" })[lang_frame()])
        if lt then tex.draw_texture(lt.t, { x = PANEL_X + 1 - 459, y = 787 - 400, frame = math.min(20, math.floor(f)) }) end
    end

    -- the win count (AiResultSectionMain UpdateTotalWinCount); nothing here (window, sounds) without the engine's count
    if not SHOW_PROGRESS or not tex.ai_wins then return end
    local w = e - WIN_AFTER_MS
    if w < 0 then return end
    once("win_open", function() sfx("ai_number_window_open") end)
    R.win_ms = R.win_ms or (tex.get_current_ms() - w)
    if b.result == "win" then
        if w >= WIN_FADE_MS + WIN_TOTAL_MS then once("win_total", function() sfx("count_stop") end) end
        if w >= WIN_FADE_MS + WIN_TOTAL_MS + WIN_NEXT_MS and tex.ai_wins then
            once("win_next", function() sfx("count_stop") end)
        end
    end
    if w >= WIN_FADE_MS + WIN_TOTAL_MS + WIN_NEXT_MS + WIN_FLASH_MS then
        once("win_shine", function()
            sfx("ai_number_window_shine")
            local wins = tex.ai_wins and tex.ai_wins() or 0
            if b.result == "win" and tex.ai_next_reward and next_reward(math.max(0, wins - 1)) == 1 then
                sfx("aivoice_achieve_number", "voice")
            end
        end)
    end
    draw_win_count(b, w)
end

------------------------------------------------------------------------------------------------ select
do
-- The AI select room moves (ai_song_select_bg): the wall's grid pulses and the shapes drift across it, under the
-- room's frame. select_base / select_grid / select_frame are select_bg split into those layers; the shapes are in
-- 1280x720 stage units. Without the layers: the flat select_bg.
local SEL_S, SEL_LOOP = 1.5, 460
local SEL_SHEET, SEL_SPARK, SEL_TRI = { 367, 88 }, { 53, 53 }, { 72, 62 }
local SEL_SPARK_P, SEL_TRI_P = { 240, 0.7 }, { 120, 0.75 }
local SEL_SHAPES = {
    { key = "shapes", pivot = SEL_SHEET, add = true, f = { 0, 364 }, x = { 825, 970 }, y = { 538, 232 }, a = { 0, 0.83 }, rot = { 0, -13 } },
    { key = "shapes", pivot = SEL_SHEET, add = true, f = { 364, 438 }, x = { 970, 989 }, y = { 232, 192 }, a = { 0.83, 0 }, rot = { -13, -15 } },
    { key = "sparkle", pivot = SEL_SPARK, pulse = SEL_SPARK_P, add = true, f = { 0, 459 }, x = { -57, 325 }, y = { 344, 154 }, a = { 0, 1 }, rot = { 0, 360 } },
    { key = "shapes", pivot = SEL_SHEET, add = true, f = { 0, 316 }, x = { 597, 682 }, y = { 356, 135 }, a = { 0, 1 }, rot = { 0, 0 } },
    { key = "triangle_pattern", pivot = SEL_TRI, pulse = SEL_TRI_P, add = true, f = { 0, 381 }, x = { -52, 152 }, y = { 563, 117 }, a = { 0, 1 }, rot = { 0, 360 } },
    { key = "triangle_white", pivot = SEL_TRI, f = { 180, 459 }, x = { 918, 1075 }, y = { 558, 187 }, a = { 1, 0 }, rot = { 0, 360 } },
    { key = "sparkle", pivot = SEL_SPARK, pulse = SEL_SPARK_P, f = { 82, 459 }, x = { 489, 713 }, y = { 401, 140 }, a = { 0, 1 }, rot = { 0, 720 } },
    { key = "sparkle", pivot = SEL_SPARK, pulse = SEL_SPARK_P, add = true, f = { 16, 327 }, x = { 1092, 1354 }, y = { 548, 350 }, a = { 1, 1 }, rot = { 0, 360 } },
}

local function sel_lerp(r, t) return r[1] + (r[2] - r[1]) * t end
local function sel_pulse(frame, period, low)
    local t = math.abs(2 * (frame % period) / period - 1)
    return low + (1 - low) * t
end

function AIB.draw_select_bg()
    local base, grid, room = tx("select_base"), tx("select_grid"), tx("select_frame")
    if not (base and grid and room) then
        if not tx("select_bg") then return false end
        put("select_bg", 960, 540)
        return true
    end
    local frame = (tex.get_current_ms() * 0.06) % SEL_LOOP
    tex.draw_texture(base.t, { x = 0, y = 0 })
    tex.draw_texture(grid.t, { x = 0, y = 0, fade = sel_pulse(frame, 240, 0.35) })
    for _, s in ipairs(SEL_SHAPES) do
        local t = (frame >= s.f[1] and frame <= s.f[2]) and tx(s.key)
        if t then
            local u = (frame - s.f[1]) / (s.f[2] - s.f[1])
            local fade = sel_lerp(s.a, u)
            if s.pulse then fade = fade * sel_pulse(frame - s.f[1], s.pulse[1], s.pulse[2]) end
            tex.draw_texture(t.t, { x = sel_lerp(s.x, u) * SEL_S, y = sel_lerp(s.y, u) * SEL_S, scale = SEL_S,
                                    origin = { s.pivot[1] * SEL_S, s.pivot[2] * SEL_S },
                                    rotation = sel_lerp(s.rot, u), fade = fade, blend = s.add and "additive" or nil })
        end
    end
    tex.draw_texture(room.t, { x = 0, y = 0 })
    return true
end
end

-- the box under the cursor (song_select.lua draw_box): what the player board shows of it
local focus = { ms = -1e9 }
function AIB.set_focus(box, kind)
    local now = tex.get_current_ms()
    if focus.ms == now then return end
    focus.ms = now
    if kind ~= "song" or not box.best_score then
        focus.seen = now
        focus.song = false
        return
    end
    local path = box.path and box:path() or ""
    local gap = now - (focus.seen or -1e9) > 1000
    focus.seen = now
    if focus.song and focus.path == path and not gap then return end
    focus.song, focus.path, focus.t0 = true, path, now
    focus.crowns_oni = box.ai_section_crowns and box:ai_section_crowns(3) or {}
    focus.crowns_ura = box.ai_section_crowns and box:ai_section_crowns(4) or {}
    focus.oni, focus.ura = box:best_score(3), box:best_score(4)
    focus.has_ura = box.has_ura and box:has_ura() or false
    local st = box.chart_stats and box:chart_stats(3)
    focus.sections = (st and st.notes and st.notes >= 200) and 5 or 3   -- zdon_ai.cpp: 5 sections from 200 notes
end

-- The player board, the cabinet's own (CHN05 common_ai_songselect/ai_song_select_player_board, placed by
-- ai_song_select_main_genre's playerinfo_instance_1 at 20,312), set up the way the cabinet's
-- ai_song_select_player_info.lua does:
--   * the record board (player_board_instance, bg "oniura": the oni + ura record): counters num_kiwami /
--     num_miyabi_1..3 / num_iki_1..3 / num_crown_1..3, each up to 4 of the board's digits centred on the
--     counter (labels bs_1..bs_4: digit i of k at x + 7(k-1) - 14(i-1))
--   * under it, while a song is under the cursor: the best score (bestscore_instance, 8 digits right-aligned
--     from 273,303, 20 apart) and the section crowns (crown_section, section_3 / section_5 by the song's
--     sections, section board oni / oniura; on a song with ura the two courses take turns every 1.5 s like
--     the cabinet's). No section crowns are recorded: they stay "none".
-- pboard_top / pboard_bot_<sec>_<level> are the cabinet board rendered by the tlb harness with its digits
-- hidden (frames = ja en ko tw cn: the title and the section names are the cabinet's own lettering).
local PB_X, PB_Y = 20, 312
local PB_BOT_Y = 240                                -- pboard_bot's top in board coords
local DIGIT_O = 40                                  -- digit textures are 80x80 around the sprite's origin
local PB_COUNTERS = {                               -- {x, y} in board coords; ranks 1..7 then crowns 1..3
    rank = { { 89, 113 }, { 181, 113 }, { 279, 113 }, { 89, 75 }, { 181, 75 }, { 279, 75 }, { 279, 36 } },
    crown = { { 89, 156 }, { 181, 156 }, { 279, 156 } },
}
local BEST_X, BEST_Y, BEST_STEP = 273, 303, 20
local URA_SWAP_MS = 1500
local rec_cache = { ms = -1e9 }

local function record_counts()
    local now = tex.get_current_ms()
    if not tex.record_counts then return nil end
    if now - rec_cache.ms > 5000 or now < rec_cache.ms then   -- a play since: refresh
        rec_cache.v = tex.record_counts(1, 3)
        rec_cache.ms = now
    end
    return rec_cache.v
end

local function draw_counter(v, cx, cy)
    local s = tostring(math.max(0, math.min(9999, math.floor(v or 0))))
    local k = #s
    for i = 1, k do
        local x = cx + 7 * (k - 1) - 14 * (i - 1)
        local t = tx("pboard_digit")
        if t then
            tex.draw_texture(t.t, { x = PB_X + x - DIGIT_O, y = PB_Y + cy - DIGIT_O, frame = s:byte(k - i + 1) - 48 })
        end
    end
end

-- main_instance "defalut_open" (frames 43..49): the record board flips open around its centre (x 159),
-- scale x per frame; the select's first frame starts it
local PB_OPEN = { 0.02, 0.05, 0.13, 0.27, 0.46, 0.7, 1 }
local PB_CX = 159
local pb_open = { last = -1e9 }

local function draw_player_board()
    if not SHOW_PROGRESS or not tex.record_counts then return end   -- an engine without the record counts shows no board at all
    local top = tx("pboard_top")
    if not top then return end
    local now = tex.get_current_ms()
    if now - pb_open.last > 1000 then pb_open.t0 = now end
    pb_open.last = now
    local of = math.floor((now - pb_open.t0) / (1000 / 60)) + 1
    if of <= #PB_OPEN then
        local sx = PB_OPEN[of]
        tex.draw_texture(top.t, { x = PB_X + PB_CX * (1 - sx), y = PB_Y, x2 = top.w * sx - top.w })
        return
    end
    tex.draw_texture(top.t, { x = PB_X, y = PB_Y })
    local c = record_counts()
    if c then
        for i, p in ipairs(PB_COUNTERS.rank) do draw_counter(c.ranks[i], p[1], p[2]) end
        for i, p in ipairs(PB_COUNTERS.crown) do draw_counter(c.crowns[i], p[1], p[2]) end
    end

    local now = tex.get_current_ms()
    if not (focus.song and now - focus.ms < 200) then return end
    local ura = focus.has_ura and (math.floor((now - focus.t0) / URA_SWAP_MS) % 2 == 1)
    local bot = tx("pboard_bot_" .. focus.sections .. (ura and "_oniura" or "_oni"))
    if bot then tex.draw_texture(bot.t, { x = PB_X, y = PB_Y + PB_BOT_Y, frame = lang_frame() }) end
    local s = tostring(math.max(0, math.min(99999999, (ura and focus.ura or focus.oni) or 0)))
    local sd = tx("pboard_sdigit")
    if sd then
        for i = 1, #s do
            tex.draw_texture(sd.t, { x = PB_X + BEST_X - BEST_STEP * (i - 1) - DIGIT_O, y = PB_Y + BEST_Y - DIGIT_O,
                                     frame = s:byte(#s - i + 1) - 48 })
        end
    end
    local crowns = (ura and focus.crowns_ura or focus.crowns_oni) or {}
    local ct = tx("pboard_crown")
    if ct then
        local n = focus.sections
        for i = 1, n do
            local c = crowns[i] or 0
            if c > 0 then
                local x = 165 + 53 * (i - (n + 1) / 2)
                tex.draw_texture(ct.t, { x = PB_X + x - DIGIT_O, y = PB_Y + 352 - DIGIT_O, frame = math.min(3, c) })
            end
        end
    end
end

-- the tension balloon (cabinet placement: balloon 1770,590; bars from x 1721.5 every 31.675, y 601;
-- the name tab top-left, the word in the body), the wins plate (win_count: 1735,371; 合計勝利数 and the wins
-- left to the next reward, digits right-aligned at 1849), the AI itself (the robot) and its plate
local TENSION_WORDS = 5
local REWARD_EVERY = 5
function AIB.draw_select(hide_board)
    if not (tex.ai_level or AISupportMenu) then return end
    if not hide_board then draw_player_board() end

    -- idle sway (0vjiSUv61i4 t=36-40, 15 fps tracking of the visor): a 1.0 s cycle, a hop to the right
    -- (+6 px at 1280, 0.2-0.4 s), rest, then a hop to the left (-7 px, 0.67-0.87 s), each lifting 4 px and tilting
    local ph = (tex.get_current_ms() % 1000) / 1000
    local function bump(a, b)
        if ph < a or ph > b then return 0 end
        return math.sin(math.pi * (ph - a) / (b - a))
    end
    local br, bl = bump(0.2, 0.4), bump(0.67, 0.87)
    if tex.ai_active and not tex.get_option("ai_select_chara_3d") then   -- else the engine draws the 3D AI Don
        put("robot", 1692 + 12 * br - 14 * bl, 766 - 10 * (br + bl), 0.68, nil, nil, 3 * br - 3 * bl)
    end
    put("ai_plate", 1703, 962)   -- strict round 8: ROI vs 0vjiSUv61i4 @54/@36 was +5,+6
    draw_text_at(txt(skin_str("ai_name", "AI"), 34, { 255, 255, 255, 255 }, { 30, 30, 30, 255 }, 3.5), 1703, 960, "c")

    local cond = tex.ai_condition and tex.ai_condition() or (tex.ai_level and tex.ai_level()) or AIB.up_tension or 3
    local lit = math.max(1, math.min(TENSION_WORDS, cond))
    -- strict round 8 (0vjiSUv61i4 @36/@54, state-matched ROI): the plate sits +5,+5 from the cabinet-movie placement,
    -- the lit bars +1,+1, their glow +2 down; the unlit slots are baked into the plate art (drawing tension_bar at
    -- fade 0.25 over them was a ghost copy)
    put("tension", 1775, 595)
    for k = 1, 5 do
        local x = 1721.5 + (k - 1) * 31.675
        if k <= lit then
            put("tension_glow", x, 603, 1.0, 0.8)
            put("tension_bar", x + 1, 602, 1.0, 1.0)
        end
    end
    -- the cabinet's own lettering (ai_song_select_tension text fields rendered with the wordlist + glyph atlases,
    -- tx_name / tx_w0..4 frames = language), drawn at the movie's own position (top-left = stage x, y)
    local TXO = { name = { 1679, 526 }, [1] = { 1719, 546 }, [2] = { 1747, 547 }, [3] = { 1702, 546 },
                  [4] = { 1759, 547 }, [5] = { 1721, 546 } }   -- round 9: re-baked with the clips moved off the panel (full glyphs)
    local tn, tw = tx("tx_name"), tx("tx_w" .. tostring(lit - 1))
    if tn and tw then
        tex.draw_texture(tn.t, { x = TXO.name[1], y = TXO.name[2], frame = tx_lang_frame() })
        local word_dy = ({ [0] = 6, 3, 11, 12 })[tx_lang_frame()] or 0   -- each language's lettering centred in the black band
        tex.draw_texture(tw.t, { x = TXO[lit][1], y = TXO[lit][2] + word_dy, frame = tx_lang_frame() })
    else
        draw_text_at(txt(skin_str("ai_tension_name", ""), 20, { 20, 40, 40, 255 }), 1714, 542, "c")
        local word = skin_str("ai_tension_" .. tostring(lit), "")
        draw_text_at(txt(word, 30, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, 3), 1786, 572, "c")
    end

    if SHOW_PROGRESS and tex.ai_wins and tex.ai_next_reward then   -- the plate shows both numbers: neither without the engine's data
        local wins = math.max(0, math.min(999999, tex.ai_wins()))
        put("wins_plate2", 1735, 371)
        local twl = tx("tx_total")   -- the cabinet's own "Total Wins" lettering (win_count text_total_wins), stage x, y
        if twl then
            tex.draw_texture(twl.t, { x = 1597, y = 313, frame = tx_lang_frame() })
        else
            draw_text_at(txt(skin_str("ai_total_wins", "WINS"), 22, { 255, 255, 255, 255 }, { 0, 70, 60, 255 }, 3),
                         1590, 318, "l")
        end
        local s = tostring(wins)
        for k = 0, #s - 1 do
            put("wins_digit", 1849 - 25.4 * k, 352, 1.0, nil, s:byte(#s - k) - 48)
        end
        -- strict round 9 (A6): the text field record (win_count char 50/52): font.ttf brush face, size 18, outline 2.4, fill white
        -- (style table 255,255,255). The cabinet's default outline colour is a renderer constant that is not extracted;
        -- the dark teal is measured from the direct feed (0vjiSUv61i4 @54).
        draw_text_at(txt(skin_str("ai_next_reward", ""), 18, { 255, 255, 255, 255 }, { 6, 66, 52, 255 }, 2.4),
                     1590, 392, "l")   -- y -8: measured vs the feed panel (round 9)
        local need = tex.ai_next_reward and tex.ai_next_reward() or 0
        s = (need > 0) and tostring(math.min(9999, need)) or ""
        for k = 0, #s - 1 do
            put("wins_digit", 1849 - 25.4 * k, 418, 0.8, nil, s:byte(#s - k) - 48)
        end
    end
end

------------------------------------------------------------------------------------------------ result bg
function AIB.draw_result_bg()
    if not AIB.plain_result() then return false end
    local b = battle()
    if not b or not b.finished then return false end
    local name = (b.result == "lose") and "bg_lose" or "bg_win"
    if not tx(name) then return false end
    local won = name == "bg_win"
    local base, pat, tri = tx(won and "bgfx_base" or "bgfx_base_l"), tx("bgfx_a"), tx("bgfx_tri")
    if base and pat and tri then
        -- result_ai_bg bg_win_mc (716 frames: the gradient, two sheets of patterns rising, a few big triangles turning)
        -- / bg_lose_mc (755 frames: the gradient, three sheets of patterns sliding); the loop starts with the screen
        local FX = require("global.ai_result_fx_data")
        tex.draw_texture(base.t, { x = 0, y = 0, scale = 0, x2 = 1920, y2 = 1080 })
        local now = tex.get_current_ms()
        if not G.bg_last or now - G.bg_last > 1000 then G.bg_t0 = now end
        G.bg_last = now
        local fr = ((now - G.bg_t0) * 0.06) % (won and 716 or 755) / 6
        local i0 = math.floor(fr)
        local u = fr - i0
        for _, tr in ipairs(won and FX.bg or FX.bg_lose) do
            local n = #tr.k
            local a, c = tr.k[i0 % n + 1], tr.k[(i0 + 1) % n + 1]
            local jump = math.abs(c[2] - a[2]) > 300 or math.abs(c[1] - a[1]) > 300   -- the sheet wraps: no blend across it
            local function mix(v, m) return jump and a[v] or (a[v] + (c[v] - a[v]) * m) end
            local x, y, s, al = 960 + mix(1, u), 540 + mix(2, u), mix(3, u), mix(5, u)
            if al > 0.004 then
                if tr.kind == 6 then
                    -- sprite 6: the same sheet placed twice, each with its own 120-frame alpha; continuous, no frame swaps
                    local sh = FX.sheets
                    local g = (fr * 6) % 120
                    local g0 = math.floor(g)
                    local gu = g - g0
                    local function curve(t) return t[g0 + 1] + (t[(g0 + 1) % 120 + 1] - t[g0 + 1]) * gu end
                    local la = 1 - (1 - curve(sh.a)) * (1 - curve(sh.b))
                    local ty = tr.flip and (y - sh.oy - sh.h) or (y + sh.oy)
                    tex.draw_texture(pat.t, { x = x - 960, y = ty, scale = 0, x2 = 1920, y2 = sh.h, fade = al * la, blend = "additive",
                                              mirror = tr.flip and "vertical" or nil })
                else
                    local w, h = FX.tri.w * s, FX.tri.h * s
                    local rot = a[4] + (((c[4] - a[4] + 180) % 360) - 180) * u   -- turning through +-180 takes the short way
                    local rad = math.rad(rot)
                    local ox, oy = FX.tri.ox * s, FX.tri.oy * s
                    tex.draw_texture(tri.t, { x = x + ox * math.cos(rad) - oy * math.sin(rad), y = y + ox * math.sin(rad) + oy * math.cos(rad),
                                              scale = s, rotation = rot, origin = { w / 2, h / 2 }, fade = al, blend = "additive" })
                end
            end
        end
    else
        put(name, 960, 540)
    end
    put("chip_plate", 1635 + 140, 8 + 32)   -- the song-count plate the full-screen AI result background replaces (strict audit)
    return true
end

-- this file and game/ai_battle.lua share the script name "ai_battle": whichever the engine runs, the overlay is defined
if not tex.ai_battle then require("global.ai_overlay") end

return AIB
