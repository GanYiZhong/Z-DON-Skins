local SKIN = {
    score_info_counter_margin = { x = 28, width = 21 },
    dan_result_info_height = { y = 276 },
    dan_result_song_name = { x = 632, y = 192.5, width = 1126, font_size = 40, outline = -1 },
    dan_result_diff_num_margin = { x = 16 },
    dan_result_hori_name = { x = 204, y = 317, width = 240 },
}
-- Dan result draw-side (1:1 port of dan_result.cpp's drawing). Reads state only;
-- the engine owns input, sound, and page2 timing.

local FRAME_MS = 1000.0 / 60.0
local DIGIT_ROLL_MS = 500.0
local GAUGE_UNIT_MS = 3 * (1000.0 / 120.0)
local GAUGE_NUMIN_MS = 10 * FRAME_MS + 500.0

local SLIDE_MS = 22 * FRAME_MS
local SLIDE_DIST = 1600.0
local SLIDE_BREAK_AT = 5.0 / 22.0
local SLIDE_BREAK_X = 35.0

local function slide_offset(t)
    if t <= 0 then return SLIDE_DIST end
    if t >= SLIDE_MS then return 0.0 end
    local p = t / SLIDE_MS
    if p <= SLIDE_BREAK_AT then
        return SLIDE_DIST + (SLIDE_BREAK_X - SLIDE_DIST) * (p / SLIDE_BREAK_AT)
    end
    return SLIDE_BREAK_X * (1.0 - (p - SLIDE_BREAK_AT) / (1.0 - SLIDE_BREAK_AT))
end

-- di == rd.dan_index. Returns nil, nil if there is no glyph pair for it.
local function shoudan_glyphs(di)
    if di == 0 then return 10, 11 end                          -- 初級
    if di >= 1 and di <= 10 then return 10 - di, 11 end          -- 十級..一級
    if di == 11 then return 10, 12 end                          -- 初段
    if di >= 12 and di <= 20 then return di - 11, 12 end         -- 二段..十段
    if di >= 21 and di <= 24 then return di - 8, 17 end          -- 玄人..達人
    return nil, nil
end

-- "%s 以上" style skin_text, %s substituted, %% -> %. Mirrors exam_threshold_text
-- in src/objects/game/exam_caption.h (dan_info.lua already uses the same idiom).
local function exam_threshold_text(exam_type, range, num)
    local gauge = exam_type == "gauge"
    local less  = range == "less"
    local key = gauge and (less and "dan_exam_text_gauge_less" or "dan_exam_text_gauge")
                       or (less and "dan_exam_text_less"       or "dan_exam_text_more")
    local fmt = tex.skin_text(key):gsub("%%%%", "\1")
    return fmt:gsub("%%s", tostring(num)):gsub("\1", "%%")
end

-- preferred is "exam_info/exam_gauge" etc (relative to the dan_result screen);
-- falls back to folder/exam_drumroll for skins carrying only the older name.
local function exam_icon_id(preferred, folder)
    local t = tex.get_texture("dan_result/" .. preferred)
    if t then return t end
    return tex.get_texture("dan_result/" .. folder .. "/exam_drumroll") or t
end

local function pad_for(outline, scale)
    return math.floor(outline * scale) + 2
end

DanResultDraw = {}
DanResultDraw.__index = DanResultDraw

function DanResultDraw.new(rd, prev_arrival, prev_best_score, best_score_show,
                            gauge_exam, gauge_value, gauge_border)
    local self = setmetatable({}, DanResultDraw)
    self.rd = rd
    self.prev_arrival = prev_arrival
    self.prev_best_score = prev_best_score
    self.best_score_show = best_score_show
    self.gauge_exam = gauge_exam
    self.gauge_value = gauge_value
    self.gauge_border = gauge_border

    -- transient per-frame results other methods read after :draw() runs
    self.congrats_showing = false
    self.celebrating = false
    self.plate_fade = 1.0

    local function T(path) return tex.get_texture("dan_result/" .. path) end

    self.t_p1_bg = T("background/dan_result_p1_bg")
    self.t_p1_board = T("background/dan_result_p1_board")
    self.t_genre_banner = T("background/genre_banner")
    self.t_result_2_bg = T("background/result_2_bg")
    self.t_song_num = T("result_info/song_num")
    self.t_difficulty = T("result_info/difficulty")
    self.t_diff_star = T("result_info/diff_star")
    self.t_diff_num = T("result_info/diff_num")
    self.t_good = T("result_info/good")
    self.t_ok = T("result_info/ok")
    self.t_bad = T("result_info/bad")
    self.t_drumroll = T("result_info/drumroll")
    self.t_counter = T("result_info/counter")
    self.t_max_combo = T("result_info/max_combo")
    self.t_max_hits = T("result_info/max_hits")
    self.t_score_box = T("result_info/score_box")
    self.t_score_counter = T("result_info/score_counter")
    self.t_rank_plate = T("result_info/rank_plate")
    self.t_dan_emblem = T("result_info/dan_emblem")
    self.t_nosave = T("result_info/nosave")
    self.t_exam_bg = T("exam_info/exam_bg")
    self.t_exam_badge = T("exam_info/exam_badge")
    self.t_exam_overlay_1 = T("exam_info/exam_overlay_1")
    self.t_exam_overlay_2 = T("exam_info/exam_overlay_2")
    self.t_exam_border_counter = T("exam_info/exam_border_counter")
    self.t_value_counter = T("exam_info/value_counter")
    self.t_value_counter_max = T("exam_info/value_counter_max")
    self.t_exam_sub_bg = T("exam_info/exam_sub_bg")
    self.t_exam_sub_front = T("exam_info/exam_sub_front")
    self.t_exam_sub_counter = T("exam_info/exam_sub_counter")
    self.t_exam_sub_counter_max = T("exam_info/exam_sub_counter_max")
    self.t_exam_less = T("exam_info/exam_less")
    self.t_exam_more = T("exam_info/exam_more")
    self.t_exam_percent = T("exam_info/exam_percent")
    self.t_exam_fail = T("exam_info/fail")
    self.t_gold_clear = T("exam_info/gold_clear")
    self.t_red_clear = T("exam_info/red_clear")
    self.t_bestscore_pill = T("bestscore/pill")
    self.t_bestscore_num = T("bestscore/num")
    self.t_bestscore_glow = T("bestscore/glow")
    self.t_congrats_bg = T("congrats/bg")

    self.border_id = self.t_exam_border_counter or self.t_value_counter
    self.has_border_digits = self.t_exam_border_counter ~= nil

    -- "pen" (multi-position draw index) counts, resolved once from the actual
    -- texture geometry, matching the original's id->x.size() > 1 check.
    local function pen_count(subset, name)
        local info = tex.get_texture_info(subset, name)
        return info and #info.x or 1
    end
    self.sub_pen = pen_count("exam_info", "exam_less") > 1 and 1 or 0
    self.sub_bd_pen = pen_count("exam_info", self.has_border_digits and "exam_border_counter" or "value_counter") > 1 and 1 or 0
    self.vpen = pen_count("exam_info", "value_counter") > 1 and 1 or 0
    self.ppen = pen_count("exam_info", "exam_percent") > 1 and 1 or 0

    local exam_icon_paths = {
        gauge = "exam_info/exam_gauge", combo = "exam_info/exam_combo",
        hit = "exam_info/exam_hit", judgebad = "exam_info/exam_judgebad",
        judgegood = "exam_info/exam_judgegood", judgeperfect = "exam_info/exam_judgeperfect",
        score = "exam_info/exam_score", renda = "exam_info/exam_roll",
    }
    self.exam_icons = {}
    for exam_type, path in pairs(exam_icon_paths) do
        self.exam_icons[exam_type] = exam_icon_id(path, "exam_info")
    end

    self.exam_fill_bar = {
        ["exam_info/exam_sub_red"]  = T("exam_info/exam_sub_red"),
        ["exam_info/exam_red"]      = T("exam_info/exam_red"),
        ["exam_info/exam_sub_gold"] = T("exam_info/exam_sub_gold"),
        ["exam_info/exam_gold"]     = T("exam_info/exam_gold"),
        ["exam_info/exam_sub_max"]  = T("exam_info/exam_sub_max"),
        ["exam_info/exam_max"]      = T("exam_info/exam_max"),
    }
    for _, name in ipairs({"exam_info/exam_sub_rainbow", "exam_info/exam_rainbow",
                           "exam_info/exam_sub_down80", "exam_info/exam_down80"}) do
        local t = T(name)
        if t then self.exam_fill_bar[name] = t end
    end

    self.tamashii = {}
    for _, name in ipairs({"base", "norma", "fill_clear", "fill_1p", "overlay", "flame",
                           "tamashii_dark", "tamashii_lit", "fever_glow", "marker",
                           "num_max", "num_clear", "num_noclear",
                           "pct_max", "pct_clear", "pct_noclear"}) do
        local t = T("tamashii/" .. name)
        if t then self.tamashii[name] = t end
    end

    local r = rd.odai_result
    local bg_key = (r == 2 or r == 5) and "shoudan/bg_g" or (r == 3 or r == 6) and "shoudan/bg_r" or "shoudan/bg_w"
    self.t_shoudan_bg = T(bg_key)
    self.t_shoudan_text = T(r > 3 and "shoudan/text_gold" or "shoudan/text_white")
    self.t_congrats_text = T(rd.dan_index == 24 and "congrats/text_02" or "congrats/text_01")

    self.t_unreached = T("result_info/unreached_" .. tex.language()) or T("result_info/unreached")

    if r > 0 then
        local gold = r >= 4
        local sub = gold and (r - 3) or r          -- 1 plain, 2 FC, 3 全良
        local base = gold and "exam_info/gold_clear" or "exam_info/red_clear"
        local variant = sub > 1 and T(base .. "_0" .. sub) or nil
        self.t_clear_variant = variant or (gold and self.t_gold_clear or self.t_red_clear)
    end

    -- text/caption objects: built once, session data is fixed for the screen's life
    local dan_title_cfg = tex.get_skin_config("dan_select_title")
    local font_size = dan_title_cfg.font_size
    self.hori_name = text.create_raw_text(rd.dan_title, font_size,
                                          {255,255,255,255}, {0,0,0,255}, false,
                                          dan_title_cfg.outline >= 0 and dan_title_cfg.outline or 5.0)

    local sn_cfg = SKIN.dan_result_song_name
    local song_font_size = sn_cfg.font_size > 0 and sn_cfg.font_size or font_size
    local song_outline = sn_cfg.outline >= 0 and sn_cfg.outline or 5.0
    self.song_names = {}
    for i, song in ipairs(rd.songs) do
        local title = song.song_title
        if song.hidden and song.unreached and prev_arrival < i then
            title = "？？？？？？"
        end
        self.song_names[i] = text.create_raw_text(title, song_font_size,
                                                   {255,255,255,255}, {0,0,0,255}, false, song_outline)
    end

    self.caption_cache = {}
    self.nosave_text = nil

    return self
end

function DanResultDraw:caption(s, size, outline)
    if s == "" or size <= 0 then return nil end
    local key = s .. "\31" .. size .. "\31" .. math.floor(outline * 100)
    local c = self.caption_cache[key]
    if not c then
        c = text.create_raw_text(s, size, {255,255,255,255}, {0,0,0,255}, false, outline)
        self.caption_cache[key] = c
    end
    return c
end

function DanResultDraw:draw_digit_counter(digits, margin_x, id, index, y, fade, scale, x_off, roll_t)
    x_off = x_off or 0.0
    roll_t = roll_t or -1.0
    local n = #digits
    for j = 1, n do
        local r = n - j                       -- position from the right (0 = ones)
        local frame = tonumber(digits:sub(j, j))
        if roll_t >= 0.0 then
            if roll_t < r * DIGIT_ROLL_MS then goto continue end
            if roll_t < (r + 1) * DIGIT_ROLL_MS then
                frame = math.floor(roll_t / 83.0 + r) % 10
            end
        end
        local x = x_off - (n - j + 1) * margin_x
        tex.draw_texture(id, {frame = frame, scale = scale, x = x, y = y, fade = fade, index = index})
        ::continue::
    end
end

function DanResultDraw:draw_page1(now)
    local height = SKIN.dan_result_info_height.y
    local margin = SKIN.score_info_counter_margin.x
    local on_page = now - self.page1_start_ms

    for i, song in ipairs(self.rd.songs) do
        local y = (i - 1) * height
        local land
        if i <= 3 then
            land = ({40, 65, 90})[i] * FRAME_MS
        else
            land = 90 * FRAME_MS + (i - 3) * 25 * FRAME_MS
        end
        if on_page < land then goto continue end
        local sx = slide_offset(on_page - land)

        local rf = song.unreached and 0.45 or 1.0

        tex.draw_texture(self.t_genre_banner, {frame = song.genre_index, x = sx, y = y, fade = rf})

        local sn_name = self.song_names[i]
        if sn_name then
            local sn = SKIN.dan_result_song_name
            local tw = sn_name.width
            local draw_w = sn.width > 0 and math.min(tw, sn.width) or tw
            sn_name:draw({x = sn.x + sx, y = y + sn.y, x2 = draw_w - tw})
        end

        tex.draw_texture(self.t_song_num, {frame = i - 1, x = sx, y = y, fade = rf})
        tex.draw_texture(self.t_difficulty, {frame = song.selected_difficulty, x = sx, y = y, fade = rf})
        tex.draw_texture(self.t_diff_star, {x = sx, y = y, fade = rf})

        local lv = tostring(song.diff_level)
        local dm = SKIN.dan_result_diff_num_margin.x
        local lead = 9 * (#lv - 1)
        for j = 1, #lv do
            tex.draw_texture(self.t_diff_num, {frame = tonumber(lv:sub(j, j)),
                                               x = sx - lead + (j - 1) * dm, y = y})
        end

        local function draw_stat(icon, val, idx)
            tex.draw_texture(icon, {x = sx, y = y, fade = rf})
            if song.unreached then return end
            local sv = tostring(val):reverse()
            for j = 1, #sv do
                tex.draw_texture(self.t_counter, {frame = tonumber(sv:sub(j, j)),
                                                  x = sx - (j - 1) * margin, y = y, index = idx})
            end
        end
        draw_stat(self.t_good, song.good, 0)
        draw_stat(self.t_ok, song.ok, 1)
        draw_stat(self.t_bad, song.bad, 2)
        draw_stat(self.t_drumroll, song.drumroll, 3)
        if song.unreached and self.t_unreached then
            tex.draw_texture(self.t_unreached, {x = sx, y = y})
        end
        ::continue::
    end
end

function DanResultDraw:draw_gauge_row(y, fade, now, scale)
    local on_page = now - self.page_start_ms
    local border_cells = math.floor(self.gauge_border / 2)

    local cur = self.gauge_value
    local landed = true
    if not self.page2_skipped and on_page < self.totals_start + self.gauge_value * GAUGE_UNIT_MS then
        cur = math.max(0.0, (on_page - self.totals_start) / GAUGE_UNIT_MS)
        if cur > self.gauge_value then cur = self.gauge_value end
        landed = false
    end
    local cells = math.floor(cur / 2)
    local clear = cur >= self.gauge_border and self.gauge_border > 0

    local T = self.tamashii

    tex.draw_texture(T.base, {scale = scale, y = y, fade = fade})
    if border_cells > 0 then
        tex.draw_texture(T.norma, {scale = scale, y = y, x2 = scale * 21.0 * border_cells, fade = fade})
    end
    if cells > 0 then
        tex.draw_texture(clear and T.fill_clear or T.fill_1p,
                         {scale = scale, y = y, x2 = scale * 21.0 * cells, fade = fade})
    end
    tex.draw_texture(T.overlay, {scale = scale, y = y, fade = fade})

    local numin = self.page2_skipped or
                 on_page >= self.totals_start + self.gauge_value * GAUGE_UNIT_MS + (GAUGE_NUMIN_MS - 500.0)
    if numin then
        local pal = self.gauge_value >= 100 and "max" or clear and "clear" or "noclear"
        local s = tostring(self.gauge_value)
        local n = #s + 1                          -- digits + %
        local pitch = 34.0 * scale
        local numtex = T["num_" .. pal]
        local pcttex = T["pct_" .. pal]
        for k = 0, n - 1 do
            local dx = (k - (n - 1) / 2.0) * pitch
            if k < n - 1 then
                tex.draw_texture(numtex, {frame = tonumber(s:sub(k + 1, k + 1)), scale = scale, x = dx, y = y, fade = fade})
            else
                tex.draw_texture(pcttex, {scale = scale, x = dx, y = y, fade = fade})
            end
        end
    end

    local fever = self.gauge_value >= 100 and landed
    if fever and T.flame then
        local t0 = self.page2_skipped and 0.0 or (self.totals_start + self.gauge_value * GAUGE_UNIT_MS)
        local f = 20.0 + math.max(0.0, on_page - t0) / FRAME_MS
        local flame_a = math.min(1.0, (f - 20.0) / 4.0)
        local cel = f < 29.0 and 0 or (math.floor((f - 29.0) / 3.0)) % 8
        tex.draw_texture(T.flame, {frame = cel, scale = scale, y = y, fade = fade * flame_a})
        local tick = (math.floor((f - 29.0) / 2.0)) % 2 == 0
        tex.draw_texture((f >= 29.0 and tick) and T.tamashii_dark or T.tamashii_lit,
                         {scale = scale, y = y, fade = fade})
        if f >= 24.0 and (f < 29.0 or tick) and T.fever_glow then
            tex.draw_texture(T.fever_glow, {scale = scale, y = y, fade = fade * 0.6})
        end
    else
        tex.draw_texture((clear and landed) and T.tamashii_lit or T.tamashii_dark,
                         {scale = scale, y = y, fade = fade})
    end
    tex.draw_texture(T.marker, {scale = scale, x = scale * 21.0 * border_cells, y = y, fade = fade})
end

function DanResultDraw:draw_exam_fill(state, w, rx, ry, sc, fd, sub)
    if w <= 0 or state == "empty" then return end
    local rb   = sub and "exam_info/exam_sub_rainbow" or "exam_info/exam_rainbow"
    local d80  = sub and "exam_info/exam_sub_down80"  or "exam_info/exam_down80"
    local up50 = sub and "exam_info/exam_sub_red"     or "exam_info/exam_red"
    local up80 = sub and "exam_info/exam_sub_gold"    or "exam_info/exam_gold"
    local p100 = sub and "exam_info/exam_sub_max"     or "exam_info/exam_max"
    local rb_tex = self.exam_fill_bar[rb]
    if state == "max" and rb_tex then
        local info = tex.get_texture_info("exam_info", sub and "exam_sub_rainbow" or "exam_rainbow")
        local th = info.height
        local perd = info.width * 0.5           -- two periods
        local ph = perd - (tex.get_current_ms() / 1000.0 * (perd * 60.0 / 80.0)) % perd
        local sw = w / sc                         -- source width, tile units
        local avail = 2.0 * perd - ph
        if sw <= avail then
            tex.draw_texture(rb_tex, {scale = sc, x = rx, y = ry, x2 = w, fade = fd,
                                      src = {x = ph, y = 0.0, width = sw, height = th}})
        else
            tex.draw_texture(rb_tex, {scale = sc, x = rx, y = ry, x2 = avail * sc, fade = fd,
                                      src = {x = ph, y = 0.0, width = avail, height = th}})
            tex.draw_texture(rb_tex, {scale = sc, x = rx + avail * sc, y = ry, x2 = (sw - avail) * sc, fade = fd,
                                      src = {x = 0.0, y = 0.0, width = sw - avail, height = th}})
        end
        return
    end
    local id = p100
    if state == "up_50" then id = up50
    elseif state == "up_80" then id = up80
    elseif state == "down_80" then id = self.exam_fill_bar[d80] and d80 or up80
    end
    tex.draw_texture(self.exam_fill_bar[id], {scale = sc, x = rx, y = ry, x2 = w, fade = fd})
end

function DanResultDraw:draw_exam_info(fade, now, scale)
    scale = scale or 1.0
    local rd = self.rd
    local on_page = now - self.page_start_ms
    local dei = { x = 52, y = 154, width = 972 }
    local offset_y = dei.y * scale
    local margin = dei.x * scale

    local sub_pitch = 465 * scale
    local sub_full = 324
    local sub_margin = 27 * scale

    local border_id = self.border_id
    local border_pitch = (self.has_border_digits and 26.0 or margin) * scale
    local sub_border_scale = 20.0 / 36.0

    local function digits_left(s, x0, y0, pitch, id, index, sc)
        for k = 1, #s do
            tex.draw_texture(id, {frame = tonumber(s:sub(k, k)), scale = sc, x = x0 + (k - 1) * pitch,
                                  y = y0, fade = fade, index = index})
        end
    end

    for i, exam in ipairs(rd.exams) do
        local ed = rd.exam_data[i]
        if not ed then goto continue end
        local y = (i - 1) * offset_y

        local row = self.rows[i] or {land = 0, fill0 = 0, filld = 0, numin = 0}
        if on_page < row.land then goto continue end

        local frac = 1.0
        if not self.page2_skipped and row.filld > 0 then
            frac = math.max(0.0, math.min(1.0, (on_page - row.fill0) / row.filld))
        end
        local row_numin = self.page2_skipped or on_page >= row.numin

        tex.draw_texture(self.t_exam_bg, {scale = scale, y = y, fade = fade})

        local tamashii_row = (i - 1 == self.gauge_exam) and self.tamashii.base ~= nil

        if tamashii_row then
            self:draw_gauge_row(y, fade, now, scale)
        elseif exam.gothrough then
            tex.draw_texture(self.t_exam_badge, {frame = 0, scale = scale, y = y, fade = fade})
            tex.draw_texture(self.t_exam_overlay_1, {scale = scale, y = y, fade = fade})

            local p = ed.progress
            if exam.range == "less" then p = 1.0 - (1.0 - p) * frac else p = p * frac end
            local bar_w = dei.width * p * scale
            local bs = ed.bar_state
            if frac < 1.0 then
                local g = math.floor(p * 100.0)
                bs = g <= 0 and "empty" or g <= 49 and "up_50" or g <= 99 and "up_80" or "up_100"
            end
            self:draw_exam_fill(bs, bar_w, 0.0, y, scale, fade, false)
        else
            local reach = 0
            for _, s in ipairs(rd.songs) do if not s.unreached then reach = reach + 1 end end
            if reach <= 0 then reach = math.max(1, ed.song_count + 1) end
            reach = math.min(reach, 3)
            for j = 1, reach do
                local sx = (j - 1) * sub_pitch
                tex.draw_texture(self.t_exam_badge, {frame = j, scale = scale, x = sx, y = y, fade = fade})
                tex.draw_texture(self.t_exam_sub_bg, {scale = scale, x = sx, y = y, fade = fade})
                local sp = ed.song_progress[j]
                if exam.range == "less" then sp = 1.0 - (1.0 - sp) * frac else sp = sp * frac end
                local sbs = ed.song_state[j]
                if frac < 1.0 then
                    local g = math.floor(sp * 100.0)
                    sbs = g <= 0 and "empty" or g <= 49 and "up_50" or g <= 99 and "up_80" or "up_100"
                end
                self:draw_exam_fill(sbs, sub_full * sp, sx, y, scale, fade, true)
                tex.draw_texture(self.t_exam_sub_front, {scale = scale, x = sx, y = y, fade = fade})

                local sbt = { x = 850, y = 468, font_size = 20, outline = 7 / 3 }
                local scap = nil
                local sbt_ol = 3.5 / tex.get_screen_scale()
                if sbt then
                    if sbt.outline >= 0 then sbt_ol = sbt.outline end
                    local song_red = (#exam.song_red > 0) and exam.song_red[j] or exam.red
                    scap = self:caption(exam_threshold_text(exam.type, exam.range, song_red),
                                       sbt.font_size > 0 and sbt.font_size or 20, sbt_ol)
                end
                if scap then
                    local pad = pad_for(sbt_ol, tex.get_screen_scale())
                    scap:draw({x = sbt.x + sx - scap.width + pad, y = sbt.y - pad + y, fade = fade})
                else
                    local song_red = (#exam.song_red > 0) and exam.song_red[j] or exam.red
                    local bs2 = tostring(song_red)
                    digits_left(bs2, sx, y, border_pitch * sub_border_scale, border_id, self.sub_bd_pen, scale * sub_border_scale)
                    local after = sx + #bs2 * border_pitch * sub_border_scale + 8.0 * scale * sub_border_scale
                    if exam.range == "less" then
                        tex.draw_texture(self.t_exam_less, {scale = scale * sub_border_scale, x = after, y = y, fade = fade, index = self.sub_pen})
                    elseif exam.range == "more" then
                        tex.draw_texture(self.t_exam_more, {scale = scale * sub_border_scale, x = after, y = y, fade = fade, index = self.sub_pen})
                    end
                end
                if row_numin then
                    local smax = frac >= 1.0 and ed.song_state[j] == "max" and self.t_exam_sub_counter_max
                    digits_left(tostring(ed.song_value[j]), sx, y, sub_margin,
                               smax and self.t_exam_sub_counter_max or self.t_exam_sub_counter, 0, scale)
                end
            end
        end

        local icon = self.exam_icons[exam.type]
        if icon then tex.draw_texture(icon, {scale = scale, y = y, fade = fade}) end

        if exam.gothrough or tamashii_row then
            local red_str = tostring(exam.red)

            local csc = tamashii_row and (25.0 / 36.0) or 1.0
            local gap1 = 4.0 * scale * csc
            local gap2 = 10.0 * scale * csc
            local cap_w = #red_str * border_pitch * csc
            if exam.type == "gauge" then cap_w = cap_w + gap1 + 31.0 * scale * csc end
            if exam.range == "less" or exam.range == "more" then cap_w = cap_w + gap2 + 70.0 * scale * csc end
            local cap_dx, cap_dy = 0.0, 0.0
            if tamashii_row then
                cap_dx = scale * (21.0 * math.floor(self.gauge_border / 2) + 52.0) - cap_w * 0.5
                cap_dy = 52.0 * scale
            end

            local bt = tamashii_row and { x = 498, y = 460, font_size = 25, outline = 7 / 3 }
                                     or { x = 772, y = 420, font_size = 36, outline = 8 / 3 }
            local capt = nil
            local bt_ol = 4.0 / tex.get_screen_scale()
            if bt then
                if bt.outline >= 0 then bt_ol = bt.outline end
                capt = self:caption(exam_threshold_text(exam.type, exam.range, exam.red),
                                    bt.font_size > 0 and bt.font_size or (tamashii_row and 25 or 36), bt_ol)
            end
            if capt then
                local pad = pad_for(bt_ol, tex.get_screen_scale())
                local cx = tamashii_row
                    and (bt.x + scale * (21.0 * math.floor(self.gauge_border / 2) + 52.0) - capt.width * 0.5)
                    or (bt.x - capt.width + pad)
                capt:draw({x = cx, y = bt.y - pad + y, fade = fade})
            else
                digits_left(red_str, cap_dx, y + cap_dy, border_pitch * csc, border_id, 0, scale * csc)
                local after = cap_dx + #red_str * border_pitch * csc
                if exam.type == "gauge" then
                    tex.draw_texture(self.t_exam_percent, {scale = scale * csc, x = after + gap1, y = y + cap_dy, fade = fade})
                    after = after + gap1 + 31.0 * scale * csc
                end
                after = after + gap2
                if exam.range == "less" then
                    tex.draw_texture(self.t_exam_less, {scale = scale * csc, x = after, y = y + cap_dy, fade = fade})
                elseif exam.range == "more" then
                    tex.draw_texture(self.t_exam_more, {scale = scale * csc, x = after, y = y + cap_dy, fade = fade})
                end
            end

            if not tamashii_row then
                tex.draw_texture(self.t_exam_overlay_2, {scale = scale, y = y, fade = fade})
                if row_numin then
                    local cur_str = tostring(ed.counter_value)
                    local vmax = frac >= 1.0 and ed.bar_state == "max" and self.t_value_counter_max
                    digits_left(cur_str, 0.0, y, margin, vmax and self.t_value_counter_max or self.t_value_counter, self.vpen, scale)
                    if exam.type == "gauge" then
                        tex.draw_texture(self.t_exam_percent, {scale = scale, x = #cur_str * margin + 6.0 * scale, y = y, fade = fade, index = self.ppen})
                    end
                end
            end
        end
        ::continue::
    end
end

function DanResultDraw:draw_page2(fade, now)
    local rd = self.rd
    local on_page = now - self.page_start_ms

    tex.draw_texture(self.t_result_2_bg, {fade = fade})

    if rd.dan_rank >= 0 then
        tex.draw_texture(self.t_rank_plate, {frame = rd.dan_rank})
    else
        tex.draw_texture(self.t_dan_emblem, {frame = rd.dan_color})
        if self.hori_name then
            local hn = SKIN.dan_result_hori_name
            self.hori_name:draw({
                x = hn.x - self.hori_name.width / 2.0,
                y = hn.y,
                x2 = math.min(self.hori_name.width, hn.width) - self.hori_name.width,
            })
        end
    end

    local margin = SKIN.score_info_counter_margin.x

    local total_good, total_ok, total_bad, total_dr = 0, 0, 0, 0
    for _, s in ipairs(rd.songs) do
        total_good = total_good + s.good; total_ok = total_ok + s.ok
        total_bad = total_bad + s.bad; total_dr = total_dr + s.drumroll
    end

    local totals_landed = self.page2_skipped or on_page >= self.totals_end
    local roll_t = totals_landed and -1.0 or (on_page - self.totals_start)
    if totals_landed or on_page >= self.totals_start then
        local function draw_total(icon, idx_icon, total, idx_counter)
            tex.draw_texture(icon, {fade = fade, index = idx_icon})
            self:draw_digit_counter(tostring(total), margin, self.t_counter, idx_counter, 0.0, fade, 1.0, margin, roll_t)
        end
        draw_total(self.t_good, 1, total_good, 4)
        draw_total(self.t_ok, 1, total_ok, 5)
        draw_total(self.t_bad, 1, total_bad, 6)
        draw_total(self.t_drumroll, 1, total_dr, 7)

        tex.draw_texture(self.t_max_combo, {fade = fade})
        self:draw_digit_counter(tostring(rd.max_combo), margin, self.t_counter, 8, 0.0, fade, 1.0, margin, roll_t)

        local total_hits = total_good + total_ok + total_bad + total_dr
        tex.draw_texture(self.t_max_hits, {fade = fade})
        self:draw_digit_counter(tostring(total_hits), margin, self.t_counter, 9, 0.0, fade, 1.0, margin, roll_t)
    else
        tex.draw_texture(self.t_good, {fade = fade, index = 1})
        tex.draw_texture(self.t_ok, {fade = fade, index = 1})
        tex.draw_texture(self.t_bad, {fade = fade, index = 1})
        tex.draw_texture(self.t_drumroll, {fade = fade, index = 1})
        tex.draw_texture(self.t_max_combo, {fade = fade})
        tex.draw_texture(self.t_max_hits, {fade = fade})
    end

    tex.draw_texture(self.t_score_box, {fade = fade})
    local sm = 46
    if totals_landed or on_page >= self.totals_start then
        self:draw_digit_counter(tostring(rd.score), sm, self.t_score_counter, 0, 0.0, fade, 1.0, sm, roll_t)
    end

    if self.best_score_show then
        self:draw_best_score(fade, on_page)
    end

    self:draw_exam_info(fade, now)

    if on_page < self.stamp_at then return end

    if rd.odai_result >= 0 then
        local r = rd.odai_result
        if r == 0 then
            tex.draw_texture(self.t_exam_fail, {fade = fade})
        else
            tex.draw_texture(self.t_clear_variant, {fade = fade})
        end
    else
        local any_failed = false
        for _, ed in ipairs(rd.exam_data) do if ed.failed then any_failed = true break end end
        local all_gold = not any_failed and #rd.exams > 0 and #rd.exam_data > 0
        if all_gold then
            for _, ed in ipairs(rd.exam_data) do
                if ed.tier < 2 then all_gold = false break end
            end
        end
        if any_failed then
            tex.draw_texture(self.t_exam_fail, {fade = fade})
        elseif all_gold then
            tex.draw_texture(self.t_gold_clear, {fade = fade})
        else
            tex.draw_texture(self.t_red_clear, {fade = fade})
        end
    end
end

function DanResultDraw:draw_best_score(fade, on_page)
    if not self.t_bestscore_pill then return end
    local rd = self.rd

    local f = self.page2_skipped and 52.0 or (5.0 + math.max(0.0, on_page - self.totals_start) / FRAME_MS)
    if f > 52.0 then f = 52.0 end
    if f < 5.0 then return end

    local K = {
        {5, 24, 0}, {6, 7.45, 0.36}, {7, -5.4, 0.64}, {8, -14.6, 0.84},
        {9, -20.1, 0.96}, {10, -21.95, 1}, {11, -20.55, 1}, {12, -16.4, 1},
        {13, -9.5, 1}, {14, 0, 1}, {18, 7, 1}, {19, 4.5, 1}, {20, 2.5, 1},
        {21, 1.1, 1}, {22, 0.3, 1}, {23, 0, 1}, {52, 0, 1},
    }
    local ty, a = 0, 1
    for i = 1, #K - 1 do
        if f >= K[i][1] and f <= K[i + 1][1] then
            local u = (f - K[i][1]) / (K[i + 1][1] - K[i][1])
            ty = K[i][2] + (K[i + 1][2] - K[i][2]) * u
            a  = K[i][3] + (K[i + 1][3] - K[i][3]) * u
            break
        end
    end

    tex.draw_texture(self.t_bestscore_pill, {y = ty, fade = fade * a})

    local na = math.max(0.0, math.min(1.0, (f - 18.0) / 3.0))
    if na > 0.0 and self.t_bestscore_num then
        local s = tostring(rd.score - self.prev_best_score)
        for i = 1, #s do
            local digit = tonumber(s:sub(#s - i + 1, #s - i + 1))
            tex.draw_texture(self.t_bestscore_num, {frame = digit, x = -((i - 1) * 14.17), y = ty, fade = fade * na})
        end
    end

    if f >= 23.0 and f < 34.0 and self.t_bestscore_glow then
        local u = (f - 23.0) / 11.0
        tex.draw_texture(self.t_bestscore_glow, {scale = 1.0 + 0.6 * u, center = true, y = ty, fade = fade * (1.0 - u)})
    end
end

function DanResultDraw:draw_celebration(now)
    local rd = self.rd
    local on_cel = now - self.celebrate_start_ms
    local fF = on_cel / FRAME_MS

    if self.t_shoudan_bg then tex.draw_texture(self.t_shoudan_bg, {}) end

    if self.t_shoudan_text then
        local tt = self.t_shoudan_text
        local ll, lr = shoudan_glyphs(rd.dan_index)
        local named = rd.dan_index >= 0 and ll ~= nil
        local quads = {
            {frame = ll, x = 0.0, t0 = 35.0},
            {frame = lr, x = 332.0, t0 = 35.0},
            {frame = 18, x = 664.0, t0 = 63.0},
            {frame = 19, x = 996.0, t0 = 63.0},
        }
        for _, q in ipairs(quads) do
            if q.frame and not (not named and q.x < 600.0) then
                if fF >= q.t0 then
                    local pop = fF < q.t0 + 7.0 and (1.5 - 0.5 * ((fF - q.t0) / 7.0)) or 1.0
                    tex.draw_texture(tt, {frame = q.frame, scale = pop, center = true, x = q.x})
                    local e0 = q.t0 + 7.0
                    if fF >= e0 and fF < e0 + 6.0 then
                        local u = (fF - e0) / 6.0
                        tex.draw_texture(tt, {frame = q.frame, scale = 1.0 + 0.25 * u, center = true, x = q.x, fade = 1.0 - u})
                    end
                    if fF >= 110.0 and fF < 133.0 then
                        local u = (fF - 110.0) / 23.0
                        tex.draw_texture(tt, {frame = q.frame, scale = 1.0 + 0.96 * u, center = true, x = q.x, fade = 1.0 - u})
                    end
                end
            end
        end
    end

    self.plate_fade = math.max(0.0, math.min(1.0, (fF - 21.0) / 8.0))
end

function DanResultDraw:draw_congrats(now)
    local fF = (now - self.congrats_start_ms) / FRAME_MS

    if self.t_shoudan_bg then tex.draw_texture(self.t_shoudan_bg, {}) end

    local bg_fade = math.min(1.0, fF / 19.0)
    if self.t_congrats_bg then tex.draw_texture(self.t_congrats_bg, {fade = bg_fade}) end

    if self.t_congrats_text then
        local lang = tex.language()
        local frame = 0
        if lang:sub(1, 2) == "en" then frame = 1
        elseif lang:sub(1, 2) == "ko" then frame = 2
        elseif lang:sub(1, 2) == "zh" then frame = 3
        end
        local tf = math.max(0.0, math.min(1.0, (fF - 20.0) / 14.0))
        if tf > 0.0 then
            tex.draw_texture(self.t_congrats_text, {frame = frame, fade = tf})
        end
    end
end

-- Top-right notice of a skipped run: the plate from the skin (result_info/nosave)
-- with the skin's text for the language, centred on the plate.
function DanResultDraw:draw_nosave_banner()
    local rd = self.rd
    if not rd.skipped or self.congrats_showing or self.celebrating then return end
    if not self.t_nosave then return end

    tex.draw_texture(self.t_nosave, {})

    if not self.nosave_text then
        local s = tex.skin_text("dan_result_nosave")
        if s == "" then s = "今回の挑戦は記録されません" end
        self.nosave_text = text.create_raw_text(s, 24,
                                                 {255,255,255,255}, {0,0,0,0}, false, 0.0)
    end

    local info = tex.get_texture_info("result_info", "nosave")
    local cx = info.x[1] + info.width / 2.0
    local cy = info.y[1] + info.height / 2.0
    self.nosave_text:draw({x = cx - self.nosave_text.width / 2.0, y = cy - self.nosave_text.height / 2.0})
end

function DanResultDraw:draw(s)
    local now = s.now
    self.page_start_ms = s.page_start_ms
    self.page1_start_ms = s.page1_start_ms
    self.page2_skipped = s.page2_skipped
    self.totals_start = s.totals_start
    self.totals_end = s.totals_end
    self.rows = s.rows
    self.stamp_at = s.stamp_at
    self.voice_at = s.voice_at
    self.celebrating = s.celebrating
    self.celebrate_start_ms = s.celebrate_start_ms
    self.congrats_showing = s.congrats_showing
    self.congrats_start_ms = s.congrats_start_ms

    tex.draw_texture(self.t_p1_bg, {})
    tex.draw_texture(self.t_p1_board, {})

    if s.congrats_showing then
        self:draw_congrats(now)
    elseif s.celebrating then
        self:draw_celebration(now)
    else
        self:draw_page1(now)
        self:draw_page2(s.page2_fade, now)
    end

    self:draw_nosave_banner()
    tex.draw_rect(0, 0, tex.get_screen_width(), tex.get_screen_height(), 0, 0, 0, math.floor(s.fade_out * 255))
end

-- {x, y, scale}, or nil to let the caller use its own skin-config default.
function DanResultDraw:chara_pos()
    if self.congrats_showing or self.celebrating then
        return {927.0, 923.0, 1.0}
    end
    return nil
end

-- {x, y, fade}, or nil to let the caller use its own skin-config default.
function DanResultDraw:nameplate_pos()
    if self.congrats_showing then
        return {763.0, 912.0, 1.0}
    end
    if self.celebrating then
        return {763.0, 912.0, self.plate_fade}
    end
    return nil
end
