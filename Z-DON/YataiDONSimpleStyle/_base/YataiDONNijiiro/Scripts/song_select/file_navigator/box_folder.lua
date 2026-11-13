-- FolderBox rendering (genre kanban), split out of song_select.lua. Shared helpers and
-- the wheel/folder animation state come from box_base.

local base = require("song_select/file_navigator/box_base")

local folder_leg = base.folder_leg
local BOARD_W = base.BOARD_W
local CAP_H = base.CAP_H
local CEN_CLOSED_H, CEN_OPEN_H = base.CEN_CLOSED_H, base.CEN_OPEN_H
local FOLDER_CLOSE_MS, STALE_TIMER_MS = base.FOLDER_CLOSE_MS, base.STALE_TIMER_MS
local draw_board, draw_glow, glow_pulse = base.draw_board, base.draw_glow, base.glow_pulse
local draw_title = base.draw_title
local outline, board_outline = base.outline, base.board_outline
local box_id = base.box_id
local go_get, leg_f, box_fade, fly_offset = base.go_get, base.leg_f, base.box_fade, base.fly_offset
local is_decided = base.is_decided
local wheel_open_t, wheel_close_step = base.wheel_open_t, base.wheel_close_step
local folder_open_timeline, folder_close_timeline = base.folder_open_timeline, base.folder_close_timeline

-- Event/search folders are matched by display name (the engine folds DEFAULT/RECOMMENDED/
-- FAVORITE/DAN/DIFFICULTY into genre frame 0).
local EVENT_FOLDER_NAMES = { ["ドドンと！新曲祭り！"] = true, ["New Songs"] = true, ["New"] = true,
                             ["おすすめ曲"] = true, ["Recommended"] = true, ["推薦歌曲"] = true }
local SORT_FOLDER_NAMES  = { ["曲検索"] = true, ["Search Song"] = true, ["搜尋歌曲"] = true,
                             ["むずかしさで探す"] = true, ["Difficulty Sort"] = true, ["難易度排序"] = true,
                             ["むずかしさからえらぶ"] = true, ["Diff Sort"] = true }
local FOLDER_FRAME_EVENT, FOLDER_FRAME_SORT, FOLDER_FRAME_DANI = 11, 12, 10

-- The tutorial folder (GENRE:TUTORIAL, genre index 0) is a howto board: the recent
-- board's colours with its own characters (box_chara frame 10).
local GENRE_TUTORIAL = 0
local FOLDER_FRAME_HOWTO, CHARA_FRAME_HOWTO = 9, 10

local function is_tutorial(box)
    return box.genre_index ~= nil and box:genre_index() == GENRE_TUTORIAL
end

local SORT_COLLECTIONS  = { SEARCH = true, DIFFICULTY = true }
local EVENT_COLLECTIONS = { NEW = true, RECOMMENDED = true }

local function folder_frame(box)
    local n = box.text_name
    if n and EVENT_FOLDER_NAMES[n] then return FOLDER_FRAME_EVENT, true end
    local col = box.collection
    if col and col ~= "" then
        if EVENT_COLLECTIONS[col] then return FOLDER_FRAME_EVENT, true end
        if SORT_COLLECTIONS[col]  then return FOLDER_FRAME_SORT, false end
    end
    if box.kind and box:kind() == "dan" then return FOLDER_FRAME_DANI, false end
    if n and SORT_FOLDER_NAMES[n]  then return FOLDER_FRAME_SORT, false end
    if is_tutorial(box) then return FOLDER_FRAME_HOWTO, false end
    return box:genre_frame(), false
end

-- instance_board_pattern: 960x120 strip centred on the board, y follows the title
-- The cabinet's genre-folder intro lines (wordlist folder_intro_*, wordlist column order ja en tw ko cn) for a genre folder whose
-- box.def carries no explanation (strict round 8: the arcade's open genre box shows it; genre ref frame 1..8 = pops, anime,
-- game, namco, classic, variety, kids, vocaloid)
local GENRE_INTRO = {
    [1] = { "ポップスの曲をあつめたよ！", "A collection of POP songs!", "收集了流行音樂的歌曲哦！", "POP 곡을 모아봤어!", "流行音乐都在这里哦！" },   -- folder_intro_pops: ja, en, zh-TW, ko, zh-CN
    [2] = { "アニメの曲をあつめたよ！", "A collection of Anime songs!", "收集了卡通動畫音樂的歌曲哦！", "애니메이션 곡을 모아봤어!", "动漫音乐都在这里哦！" },   -- folder_intro_anime: ja, en, zh-TW, ko, zh-CN
    [3] = { "ゲームミュージックの曲をあつめたよ！", "A collection of Game Music songs!", "收集了遊戲音樂的歌曲哦！", "게임 음악 곡을 모아봤어!", "游戏音乐都在这里哦！" },   -- folder_intro_game: ja, en, zh-TW, ko, zh-CN
    [4] = { "ナムコオリジナルの曲をあつめたよ！", "A collection of NAMCO Original songs!", "收集了NAMCO原創音樂的歌曲哦！", "남코 오리지널 곡을 모아봤어!", "南梦宫原创音乐都在这里哦！" },   -- folder_intro_namco: ja, en, zh-TW, ko, zh-CN
    [5] = { "クラシックの曲をあつめたよ！", "A collection of Classical songs!", "收集了古典音樂的歌曲哦！", "클래식 곡을 모아봤어!", "古典音乐都在这里哦！" },   -- folder_intro_classic: ja, en, zh-TW, ko, zh-CN
    [6] = { "バラエティの曲をあつめたよ！", "A collection of Variety songs!", "收集了綜合音樂的歌曲哦！", "버라이어티 곡을 모아봤어!", "综合音乐都在这里哦！" },   -- folder_intro_variety: ja, en, zh-TW, ko, zh-CN
    [7] = { "キッズの曲をあつめたよ！", "A collection of Kids' songs!", "收集了兒童音樂的歌曲哦！", "어린이 음악 곡을 모아봤어!", "儿童音乐都在这里哦！" },   -- folder_intro_kids: ja, en, zh-TW, ko, zh-CN
    [8] = { "ボーカロイド™の曲をあつめたよ！", "A collection of VOCALOID™ Music songs!", "收集了VOCALOID™ Music的歌曲哦！", "VOCALOID™ Music 곡을 모아봤어!", "博歌乐 音乐都在这里哦！" },   -- folder_intro_vocaloid: ja, en, zh-TW, ko, zh-CN
}
local INTRO_ZH = 3
local function genre_intro_lines(box, frame)
    if box.collection ~= nil and box.collection ~= "" then return nil end
    local row = GENRE_INTRO[frame]
    if not row then return nil end
    local lang = tex.language()
    local idx = (type(lang) == "string") and ((lang:find("^ja") and 1) or (lang:find("^en") and 2) or (lang:find("^ko") and 4)
        or ((lang:find("^zh") or lang == "tw" or lang == "cn") and INTRO_ZH)) or nil
    local s = idx and row[idx]
    if not s or s == "" then return nil end
    local out = {}
    for part in (s .. "\n"):gmatch("(.-)\n") do out[#out + 1] = part end
    return out
end

function SongSelect:draw_pattern(bx, by, p, fade)
    if not self._id_pattern then return end
    tex.draw_texture(self._id_pattern, { x = bx - 480, y = by - 94 * p - 60, fade = fade })
end

-- The genre board title, re-made at the skin_config folder_box_name size.
local FOLDER_TITLE_SIZE = 54
function SongSelect:folder_title(box)
    local key = box.text_name
    if not key or key == "" then return box:name() end
    local ff = folder_frame(box)
    local scale = base.title_scale()
    if scale < 1 then scale = 0.95 end   -- arcade genre bars: ~51 px brush face (measured vs direct feed)
    key = ff .. "\0" .. scale .. "\0" .. key
    local t = self._folder_titles[key]
    if t == nil then
        t = text.create_raw_text(box.text_name, math.floor(FOLDER_TITLE_SIZE * scale + 0.5), { 255, 255, 255, 255 },
                                 board_outline(ff), false, outline(7.5), 2.0)
        self._folder_titles[key] = t or false
    end
    return t or box:name()
end

function SongSelect:draw_folder_board(box, pb, ch_alpha, ch_off, ta, glow_a)
    local bx, by = box:box_x(), box:box_y()
    local fdx, fdy = fly_offset(box); bx, by = bx + fdx, by + fdy   -- wheel fly-in
    local cen_h = CEN_CLOSED_H + (CEN_OPEN_H - CEN_CLOSED_H) * pb
    local fade = box_fade(box)
    local frame, has_pattern = folder_frame(box)

    -- the genre board furls/unfurls horizontally across the folder transition
    local ltitle = 1.0
    local lf = (box:draw_state() == "open" or is_decided(box)) and leg_f() or nil
    if lf then
        local sx, ba = go_get("genre_board_sx", lf, 1), go_get("genre_board_sx", lf, 2)
        if sx and ba then
            if ba <= 0.0 then return end   -- the board is not on screen
            if sx < 1.0 then               -- furl / unfurl: the open slab alone
                draw_board(self._id_bar_folder, frame, bx, by, CEN_OPEN_H,
                           fade * ba, false, sx)
                return
            end
            ch_alpha = math.min(ch_alpha, go_get("genre_chara_a", lf, 1) or 1.0)
            ta       = math.min(ta,       go_get("genre_intro_a", lf, 1) or 1.0)
            ltitle   = go_get("genre_title_a", lf, 1) or 1.0
        end
    end

    if glow_a > 0 then draw_glow(self._id_glow, bx, by, cen_h, fade * glow_a * glow_pulse()) end
    -- closed folder = bar_genre, open folder = folder_graphic (title band on top)
    if pb <= 0.0 then
        draw_board(self._id_bar_genre, frame, bx, by, cen_h, fade)
    else
        draw_board(self._id_bar_folder, frame, bx, by, cen_h, fade, pb >= 1.0)
        if pb < 1.0 then draw_board(self._id_bar_genre, frame, bx, by, cen_h, fade * (1.0 - pb)) end
    end
    if has_pattern then self:draw_pattern(bx, by, pb, fade) end

    if box:has_box_texture() then
        -- a library-supplied box.png is fitted (aspect kept, shrink only) into the board rect
        if ch_alpha > 0 then
            box:draw_box_texture({ cx = bx, cy = by,
                                   max_w = BOARD_W, max_h = CAP_H * 2 + CEN_OPEN_H,
                                   fade = fade * ch_alpha })
        end
        -- title drawn after the art, matching the cabinet's depth order
        draw_title(self:folder_title(box), bx, by - 94 * pb, fade * ltitle)
        return
    end

    -- characters: texture has L at x=510 and R at x=1410
    if ch_alpha > 0 then
        local slide = 450.0 - ch_off
        local gframe = is_tutorial(box) and CHARA_FRAME_HOWTO or box:genre_frame()
        tex.draw_texture(self._id_box_chara, { frame = gframe, x = bx - 960 + slide, y = by - 240, x2 = 960 - 1920, fade = fade * ch_alpha,
                                               src = { x = 0, y = 0, width = 960, height = 480 } })
        tex.draw_texture(self._id_box_chara, { frame = gframe, x = bx - slide, y = by - 240, x2 = 960 - 1920, fade = fade * ch_alpha,
                                               src = { x = 960, y = 0, width = 960, height = 480 } })
    end
    -- title rises to y-94 when open; the box explanation lines stand in for the intro text
    draw_title(self:folder_title(box), bx, by - 94 * pb, fade * ltitle)
    if ta > 0 then
        local lines = {}
        for _, l in ipairs(box:explanation() or {}) do
            if l ~= "" then lines[#lines + 1] = l end
        end
        if #lines == 0 then lines = genre_intro_lines(box, frame) or lines end
        -- folders without an explanation show their song count, as before
        local n = box.tja_count
        if #lines == 0 and n and n > 0 then lines[1] = tostring(n) .. " songs" end
        for i, l in ipairs(lines) do
            local ckey = frame .. "\0" .. l
            local label = self._count_cache[ckey]
            if not label then
                label = text.create_raw_text(l, 32, { 255, 255, 255, 255 }, board_outline(frame), false, outline(4.0), 2.0, 1.0, "FOT-Seurat_Pro_B.otf")
                self._count_cache[ckey] = label
            end
            draw_title(label, bx, by + (49 + (i - (#lines + 1) / 2) * 36) * pb, fade * ta, BOARD_W - 120)
        end
    end
end

function SongSelect:draw_folder_closed(box)
    local key = "f\0" .. box_id(box)
    local e = wheel_close_step(key, FOLDER_CLOSE_MS, STALE_TIMER_MS)
    if e then
        local pb, ch_alpha, ch_off, ta = folder_close_timeline(e)
        self:draw_folder_board(box, pb, ch_alpha, ch_off, ta, pb)
        return
    end
    self:draw_folder_board(box, 0.0, 0.0, 340.0, 0.0, 0.0)
end

function SongSelect:draw_folder_open(box)
    -- remember the decided board: the engine removes it from the wheel while its songs
    -- load, and draw_overlays keeps drawing it until it has furled away
    folder_leg.last_open_id, folder_leg.last_open_box = box_id(box), box
    if is_decided(box) then
        self._dec_frame = self._frame_no
        self:draw_folder_board(box, 1.0, 1.0, 440.0, 1.0, 1.0)
        return
    end
    local key = "f\0" .. box_id(box)
    local t = wheel_open_t(key)
    if t == nil then     -- 508 ms pre-growth hold: fully closed
        self:draw_folder_board(box, 0.0, 0.0, 340.0, 0.0, 0.0)
        return
    end
    local pb, ch_alpha, ch_off, ta = folder_open_timeline(t)
    self:draw_folder_board(box, pb, ch_alpha, ch_off, ta, pb)
end

return { folder_frame = folder_frame }
