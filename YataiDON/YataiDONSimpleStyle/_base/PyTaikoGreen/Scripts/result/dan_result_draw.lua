local SKIN_S = tex.get_screen_scale()
local SKIN = {
    dan_result_info_height = { y = 191 * SKIN_S },
    dan_result_song_name = { x = 1230 * SKIN_S, y = 122 * SKIN_S, width = 700 * SKIN_S, font_size = math.floor(32 * SKIN_S) },
    dan_result_diff_num_margin = { x = 12 * SKIN_S },
    dan_result_hori_name = { x = 267 * SKIN_S, y = 126 * SKIN_S, width = 275 * SKIN_S },
}
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

local function pen_count(subset, name)
    local info = tex.get_texture_info(subset, name)
    return info and #info.x or 1
end

local function ease_out(u)
    u = math.max(0.0, math.min(1.0, u))
    return 1.0 - (1.0 - u) * (1.0 - u)
end

local PULLOUT_FRAMES = 28.0

local STAMP_SETTLE = { {36, 0.95}, {39, 1.04}, {44, 1.048}, {48, 0.99}, {52, 1.0} }
local function stamp_pose(t)
    if t < 36.0 then
        local u = t / 36.0
        return 3.0 - 2.05 * u ^ 1.8, u ^ 1.67
    end
    for k = 1, #STAMP_SETTLE - 1 do
        local a, b = STAMP_SETTLE[k], STAMP_SETTLE[k + 1]
        if t < b[1] then return a[2] + (b[2] - a[2]) * (t - a[1]) / (b[1] - a[1]), 1.0 end
    end
    return 1.0, 1.0
end

DanResultDraw = {}
DanResultDraw.__index = DanResultDraw

function DanResultDraw.new(rd, prev_arrival, prev_best_score, best_score_show,
                            gauge_exam, gauge_value, gauge_border)
    local self = setmetatable({}, DanResultDraw)
    self.rd = rd
    self.prev_arrival = prev_arrival
    self.gauge_exam = gauge_exam
    self.gauge_value = gauge_value
    self.gauge_border = gauge_border

    local function T(path) return tex.get_texture("dan_result/" .. path) end

    self.t_genre_banner = T("background/genre_banner")
    self.t_result_2_bg = T("background/result_2_bg")
    self.t_result_2_divider = T("background/result_2_divider")
    self.t_result_2_pullout = T("background/result_2_pullout")

    self.t_song_num = T("result_info/song_num")
    self.t_difficulty = T("result_info/difficulty")
    self.t_diff_star = T("result_info/diff_star")
    self.t_diff_x = T("result_info/diff_x")
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
    self.t_exam_header = T("result_info/exam_header")
    self.t_dan_emblem = T("result_info/dan_emblem")

    self.t_exam_bg = T("exam_info/exam_bg")
    self.t_exam_overlay_1 = T("exam_info/exam_overlay_1")
    self.t_exam_overlay_2 = T("exam_info/exam_overlay_2")
    self.t_exam_max = T("exam_info/exam_max")
    self.t_exam_gold = T("exam_info/exam_gold")
    self.t_exam_red = T("exam_info/exam_red")
    self.t_value_counter = T("exam_info/value_counter")
    self.t_exam_less = T("exam_info/exam_less")
    self.t_exam_more = T("exam_info/exam_more")
    self.t_exam_percent = T("exam_info/exam_percent")
    self.t_exam_failed = T("exam_info/exam_failed")
    self.t_sd_panel = T("shoudan/panel")
    self.t_sd_glow = T("shoudan/glow")
    self.t_sd_spark = T("shoudan/spark")
    self.t_sd_mascot_a = T("shoudan/mascot_a")
    self.t_sd_mascot_b = T("shoudan/mascot_b")
    self.t_sd_glyph = T("shoudan/glyph")
    self.t_sd_drum_red = T("shoudan/drum_red")
    self.t_sd_drum_blue = T("shoudan/drum_blue")
    self.t_cg_plate = T("congrats/plate")
    self.t_cg_board = T("congrats/board")
    self.t_cg_flash = T("congrats/flash")
    self.t_cg_don = T("congrats/don")
    self.t_cg_text = T("congrats/text")
    self.t_cg_title = T("congrats/title")
    self.t_sr_page = T("staffroll/page")
    self.t_exam_unit_hit = T("exam_info/exam_unit_hit")
    self.t_exam_unit_score = T("exam_info/exam_unit_score")
    self.t_exam_combo_text = T("exam_info/exam_combo_text")
    self.t_exam_fail = T("exam_info/fail")
    self.t_gold_clear = T("exam_info/gold_clear")
    self.t_red_clear = T("exam_info/red_clear")

    self.vpen = pen_count("exam_info", "value_counter") > 1 and 1 or 0
    self.ppen = pen_count("exam_info", "exam_percent") > 1 and 1 or 0

    self.exam_icons = {
        gauge = T("exam_info/exam_gauge"), combo = T("exam_info/exam_combo"),
        hit = T("exam_info/exam_hit"), judgebad = T("exam_info/exam_judgebad"),
        judgegood = T("exam_info/exam_judgegood"), judgeperfect = T("exam_info/exam_judgeperfect"),
        score = T("exam_info/exam_score"), renda = T("exam_info/exam_drumroll"),
    }

    self.g_unfilled = T("gauge/1p_unfilled")
    self.g_bar = T("gauge/1p_bar")
    self.g_overlay = T("gauge/overlay")
    self.g_rainbow = T("gauge/rainbow")
    self.g_footer = T("gauge/footer")
    self.g_tamashii = T("gauge/tamashii")
    self.g_tamashii_dark = T("gauge/tamashii_dark")
    self.g_tamashii_overlay = T("gauge/tamashii_overlay")
    self.g_fire = T("gauge/tamashii_fire")

    local r = rd.odai_result
    if r > 0 then
        self.t_clear_variant = (r >= 4) and self.t_gold_clear or self.t_red_clear
    end

    local failed = (r == 0)
    if r < 0 then
        for _, ed in ipairs(rd.exam_data) do if ed.failed then failed = true break end end
    end
    if failed and not rd.skipped then
        local reached_all = true
        for _, song in ipairs(rd.songs) do if song.unreached then reached_all = false break end end
        self.t_message = T(reached_all and "message/fail_near" or "message/fail_far")
    end

    local dan_title_cfg = tex.get_skin_config("dan_select_title")
    local font_size = dan_title_cfg.font_size
    self.hori_name = text.create_raw_text(rd.dan_title, font_size,
                                          {255,255,255,255}, {0,0,0,255}, false,
                                          dan_title_cfg.outline >= 0 and dan_title_cfg.outline or 5.0)

    local sn_cfg = SKIN.dan_result_song_name
    local song_font_size = (sn_cfg.font_size and sn_cfg.font_size > 0) and sn_cfg.font_size or font_size
    local song_outline = (sn_cfg.outline and sn_cfg.outline >= 0) and sn_cfg.outline or 5.0
    self.song_names = {}
    for i, song in ipairs(rd.songs) do
        local title = song.song_title
        if song.hidden and song.unreached and prev_arrival < i then
            title = "？？？？？？"
        end
        self.song_names[i] = text.create_raw_text(title, song_font_size,
                                                   {255,255,255,255}, {0,0,0,255}, false, song_outline)
    end

    return self
end

function DanResultDraw:draw_digit_counter(digits, margin_x, id, index, y, fade, scale, x_off, roll_t)
    x_off = x_off or 0.0
    roll_t = roll_t or -1.0
    local n = #digits
    for j = 1, n do
        local r = n - j
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
    local margin = 22 * tex.get_screen_scale()

    for i, song in ipairs(self.rd.songs) do
        local y = (i - 1) * height
        local land
        if i <= 3 then
            land = ({40, 65, 90})[i] * FRAME_MS
        else
            land = 90 * FRAME_MS + (i - 3) * 25 * FRAME_MS
        end
        if now < land then goto continue end
        local sx = slide_offset(now - land)

        local rf = song.unreached and 0.45 or 1.0

        tex.draw_texture(self.t_genre_banner, {frame = song.genre_index, x = sx, y = y, fade = rf})

        local sn_name = self.song_names[i]
        if sn_name then
            local sn = SKIN.dan_result_song_name
            local tw = sn_name.width
            local draw_w = (sn.width and sn.width > 0) and math.min(tw, sn.width) or tw
            sn_name:draw({x = sn.x + sx - draw_w, y = y + sn.y - sn_name.height / 2.0, x2 = draw_w - tw})
        end

        tex.draw_texture(self.t_song_num, {frame = i - 1, x = sx, y = y, fade = rf})
        tex.draw_texture(self.t_difficulty, {frame = song.selected_difficulty, x = sx, y = y, fade = rf})
        tex.draw_texture(self.t_diff_star, {x = sx, y = y, fade = rf})
        tex.draw_texture(self.t_diff_x, {x = sx, y = y, fade = rf})

        local lv = tostring(song.diff_level)
        local dm = SKIN.dan_result_diff_num_margin.x
        for j = 1, #lv do
            tex.draw_texture(self.t_diff_num, {frame = tonumber(lv:sub(j, j)),
                                               x = sx + (j - 1) * dm, y = y, fade = rf})
        end

        local function draw_stat(icon, val, idx)
            tex.draw_texture(icon, {x = sx, y = y, fade = rf})
            if song.unreached then return end
            local sv = tostring(val)
            local n = #sv
            for k = 1, n do
                local ch = sv:sub(n - k + 1, n - k + 1)
                tex.draw_texture(self.t_counter, {frame = tonumber(ch),
                                                  x = sx - (k - 1) * margin, y = y, index = idx})
            end
        end
        draw_stat(self.t_good, song.good, 0)
        draw_stat(self.t_ok, song.ok, 1)
        draw_stat(self.t_bad, song.bad, 2)
        draw_stat(self.t_drumroll, song.drumroll, 3)
        ::continue::
    end
end

local ROW_S = 0.9
local ROW_X = 384.0
local ROW_TOPS = { { 451.6 }, { 410.0, 486.8 }, { 378.8, 458.0, 537.2 } }
local BAR_X, BAR_Y, BAR_W = 15.0, 12.0, 929.0
local LIVE_U, LIVE_Y = 161.0, 14.0          -- live number: units digit left edge, pitch 25 towards the left
local LIVE_PITCH = 25.0
local LIVE_UNIT_X, LIVE_UNIT_Y = 187.0, 20.4
local FAILED_X, FAILED_Y = 331.0, 8.4
local BORDER_Y = 34.0
local MORE_X = 872.0
-- right-hand group per exam type: label x = l0 - step * digits, border units digit left edge u, digit pitch,
-- unit mark (a172 % / a181 / a183) drawn right of the digits.
local ROW_TYPES = {
    gauge        = { icon = "gauge",        l0 = 710.5, step = 24, u = 820.5, pitch = 24, unit = "percent", unit_x = 845.5, unit_y = 41.7, more_x = 871.5, live = "percent" },
    judgeperfect = { icon = "judgeperfect", l0 = 761.0, step = 24, u = 846.0, pitch = 24 },
    judgegood    = { icon = "judgegood",    l0 = 761.0, step = 25, u = 846.0, pitch = 25 },
    judgebad     = { icon = "judgebad",     l0 = 732.0, step = 25, u = 846.0, pitch = 25 },
    combo        = { icon = "combo",        l0 = 740.5, step = 25, u = 845.5, pitch = 25, more_x = 871.5, live = "combo_text" },
    renda        = { icon = "renda",        l0 = 734.0, step = 25, u = 821.0, pitch = 25, unit = "hit", unit_x = 847.0, unit_y = 40.6, live = "hit" },
    hit          = { icon = "hit",          l0 = 684.0, step = 25, u = 820.0, pitch = 25, unit = "hit", unit_x = 846.0, unit_y = 40.6, live = "hit" },
    score        = { icon = "score",        l0 = 593.0 + 25 * 7, step = 25, u = 821.0, pitch = 25, unit = "score", unit_x = 847.1, unit_y = 41.6, live = "score" },
}

local GAUGE_X, GAUGE_Y = 489.4, 107.2
local GAUGE_S = 0.9
local GAUGE_BAR_DX, GAUGE_BAR_DY = 7.2, 25.2
local GAUGE_BAR_W = 696.0 * GAUGE_S
local GAUGE_CAP_X = 1119.1
local GAUGE_ICON_X, GAUGE_ICON_Y = 1122.7, 105.4

function DanResultDraw:draw_gauge(fade, now)
    local on_page = now - self.page_start_ms
    local cur = self.gauge_value
    local landed = true
    if not self.page2_skipped and on_page < self.totals_start + self.gauge_value * GAUGE_UNIT_MS then
        cur = math.max(0.0, (on_page - self.totals_start) / GAUGE_UNIT_MS)
        if cur > self.gauge_value then cur = self.gauge_value end
        landed = false
    end
    local clear = cur >= self.gauge_border and self.gauge_border > 0
    local w = GAUGE_BAR_W * (cur / 100.0)
    local s = GAUGE_S

    tex.draw_texture(self.g_unfilled, {x = GAUGE_X, y = GAUGE_Y, scale = s, fade = fade})
    if w > 0 then
        tex.draw_texture(self.g_bar, {x = GAUGE_X + GAUGE_BAR_DX, y = GAUGE_Y + GAUGE_BAR_DY, scale = s, x2 = w, fade = fade})
        if clear and self.g_rainbow then
            local frame = math.floor(tex.get_current_ms() / 50.0) % 8
            tex.draw_texture(self.g_rainbow, {frame = frame, x = GAUGE_X + GAUGE_BAR_DX, y = GAUGE_Y + 24.0 * s,
                                              scale = s, x2 = w, fade = fade})
        end
    end
    tex.draw_texture(self.g_overlay, {x = GAUGE_X, y = GAUGE_Y, scale = s, fade = fade})
    tex.draw_texture(self.g_footer, {x = GAUGE_CAP_X, y = GAUGE_Y, scale = s, fade = fade})

    local fever = self.gauge_value >= 100 and landed
    tex.draw_texture((clear and landed) and self.g_tamashii or self.g_tamashii_dark,
                     {x = GAUGE_ICON_X, y = GAUGE_ICON_Y, scale = s, fade = fade})
    tex.draw_texture(self.g_tamashii_overlay, {x = GAUGE_ICON_X, y = GAUGE_ICON_Y, scale = s, fade = fade})
    if fever and self.g_fire then
        local frame = math.floor(tex.get_current_ms() / 50.0) % 8
        tex.draw_texture(self.g_fire, {frame = frame, x = GAUGE_ICON_X - 46.8, y = GAUGE_ICON_Y - 131.4,
                                       scale = s, fade = fade})
    end
end

-- No exam_rainbow/exam_down80 tiers in this skin: only up_50 / up_80 / max.
function DanResultDraw:draw_exam_fill(state, w, x, y, fade)
    if w <= 0 or state == "empty" then return end
    local id = self.t_exam_max
    if state == "up_50" then id = self.t_exam_red
    elseif state == "up_80" or state == "down_80" then id = self.t_exam_gold
    end
    tex.draw_texture(id, {x = x, y = y, scale = ROW_S, x2 = w, fade = fade})
end

function DanResultDraw:draw_exam_info(fade, now)
    local rd = self.rd
    local on_page = now - self.page_start_ms
    local count = math.min(#rd.exams, 3)
    if count == 0 then return end
    local tops = ROW_TOPS[count]
    local S = ROW_S

    for i, exam in ipairs(rd.exams) do
        local ed = rd.exam_data[i]
        local top = tops[i]
        if not ed or not top then goto continue end

        local row = self.rows[i] or {land = 0, fill0 = 0, filld = 0, numin = 0}
        if on_page < row.land then goto continue end

        local frac = 1.0
        if not self.page2_skipped and row.filld > 0 then
            frac = math.max(0.0, math.min(1.0, (on_page - row.fill0) / row.filld))
        end
        local row_numin = self.page2_skipped or on_page >= row.numin

        local function put(id, nx, ny, extra)
            local p = extra or {}
            p.x = ROW_X + nx * S
            p.y = top + ny * S
            p.scale = S
            p.fade = p.fade or fade
            tex.draw_texture(id, p)
        end
        -- digits right-aligned: units digit left edge ux, pitch towards the left
        local function number(str, ux, ny, pitch, pen)
            local n = #str
            for k = 1, n do
                put(self.t_value_counter, ux - (n - k) * pitch, ny,
                    {frame = tonumber(str:sub(k, k)), index = pen})
            end
        end

        put(self.t_exam_overlay_1, 0, 0)

        local p = ed.progress
        if exam.range == "less" then p = 1.0 - (1.0 - p) * frac else p = p * frac end
        local bs = ed.bar_state
        if frac < 1.0 then
            local g = math.floor(p * 100.0)
            bs = g <= 0 and "empty" or g <= 49 and "up_50" or g <= 99 and "up_80" or "up_100"
        end
        self:draw_exam_fill(bs, BAR_W * p * S, ROW_X + BAR_X * S, top + BAR_Y * S, fade)

        put(self.t_exam_overlay_2, 0, 0)

        local def = ROW_TYPES[exam.type] or ROW_TYPES.judgeperfect
        local function unit(kind, nx, ny, pen)
            if kind == "percent" then put(self.t_exam_percent, nx, ny, {index = pen})
            elseif kind == "hit" then put(self.t_exam_unit_hit, nx, ny)
            elseif kind == "score" then put(self.t_exam_unit_score, nx, ny)
            elseif kind == "combo_text" then put(self.t_exam_combo_text, nx, ny) end
        end

        -- live number + its unit on the left
        if row_numin then
            local cur_str = tostring(ed.counter_value)
            number(cur_str, LIVE_U, LIVE_Y, LIVE_PITCH, self.vpen)
            if def.live then unit(def.live, LIVE_UNIT_X, LIVE_UNIT_Y, self.ppen) end
        end

        -- border value group on the right
        local red_str = tostring(exam.red)
        local n = #red_str
        local label_x = def.l0 - def.step * n
        if def.icon == "score" then label_x = 593.0 + 25.0 * (7 - n) end
        put(self.exam_icons[def.icon], label_x, BORDER_Y)
        number(red_str, def.u, BORDER_Y, def.pitch, 0)
        if def.unit then unit(def.unit, def.unit_x, def.unit_y, 0) end
        if exam.range == "less" then
            put(self.t_exam_less, def.more_x or MORE_X, BORDER_Y)
        elseif exam.range == "more" then
            put(self.t_exam_more, def.more_x or MORE_X, BORDER_Y)
        end

        if ed.failed and row_numin then
            put(self.t_exam_bg, 0, 0, {fade = fade * 0.69})
            put(self.t_exam_failed, FAILED_X, FAILED_Y)
        end
        ::continue::
    end
end


function DanResultDraw:draw_page2(fade, now)
    local rd = self.rd
    local on_page = now - self.page_start_ms

    local pu = self.page2_skipped and 1.0 or math.min(1.0, on_page / (PULLOUT_FRAMES * FRAME_MS))
    local pa = (fade > 0) and ease_out(pu) or 0.0
    local px = 1022.0 * (1.0 - pu) * (1.0 - pu)
    tex.draw_texture(self.t_result_2_bg, {x = px, fade = pa})
    for i = 0, 3 do
        tex.draw_texture(self.t_result_2_divider, {x = i * 240 + px, fade = pa})
    end
    tex.draw_texture(self.t_result_2_pullout, {x = px, fade = pa})

    tex.draw_texture(self.t_dan_emblem, {frame = rd.dan_color})
    if self.hori_name then
        local hn = SKIN.dan_result_hori_name
        self.hori_name:draw({
            x = hn.x - self.hori_name.width / 2.0,
            y = hn.y,
            x2 = math.min(self.hori_name.width, hn.width) - self.hori_name.width,
        })
    end

    local margin = 22 * tex.get_screen_scale()
    local score_margin = 23 * tex.get_screen_scale()

    local total_good, total_ok, total_bad, total_dr = 0, 0, 0, 0
    for _, s in ipairs(rd.songs) do
        total_good = total_good + s.good; total_ok = total_ok + s.ok
        total_bad = total_bad + s.bad; total_dr = total_dr + s.drumroll
    end

    local totals_landed = self.page2_skipped or on_page >= self.totals_end
    local roll_t = totals_landed and -1.0 or (on_page - self.totals_start)
    if totals_landed or on_page >= self.totals_start then
        local function draw_total(icon, total, idx_counter)
            tex.draw_texture(icon, {fade = fade, index = 1})
            self:draw_digit_counter(tostring(total), margin, self.t_counter, idx_counter, 0.0, fade, 1.0, margin, roll_t)
        end
        draw_total(self.t_good, total_good, 4)
        draw_total(self.t_ok, total_ok, 5)
        draw_total(self.t_bad, total_bad, 6)
        draw_total(self.t_drumroll, total_dr, 7)

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

    tex.draw_texture(self.t_exam_header, {fade = fade})

    tex.draw_texture(self.t_score_box, {fade = fade})
    if totals_landed or on_page >= self.totals_start then
        self:draw_digit_counter(tostring(rd.score), score_margin, self.t_score_counter, 0, 0.0, fade, 1.0, score_margin, roll_t)
    end

    if self.gauge_exam >= 0 and self.g_unfilled then self:draw_gauge(fade, now) end
    self:draw_exam_info(fade, now)

end

-- Clear/fail stamp: drawn by the screen after the chara so it sits above it.
function DanResultDraw:draw_stamp(fade, now)
    local rd = self.rd
    local t = (now - self.page_start_ms - self.stamp_at) / FRAME_MS
    if t < 0 then return end
    local sc, a = stamp_pose(t)

    local id
    if rd.odai_result >= 0 then
        id = (rd.odai_result == 0) and self.t_exam_fail or self.t_clear_variant
    else
        local any_failed = false
        for _, ed in ipairs(rd.exam_data) do if ed.failed then any_failed = true break end end
        id = any_failed and self.t_exam_fail or self.t_red_clear
    end
    if id then tex.draw_texture(id, {center = true, scale = sc, fade = fade * a}) end
end

local POP_CX, POP_CY = 636.0, 329.0
local SPARKS = {
    {-352, -202, 10}, {448, -182, 10}, {378, -102, 10},
    {-422, -2, 30}, {188, -152, 30}, {-252, 138, 30},
    {226, 36, 50}, {-272, -102, 50}, {276, -222, 50},
}

-- glyph frames: 0..9 = 一..十, 10 初, 11 級, 12 段, 13 玄, 14 名, 15 超, 16 達, 17 人
local function rank_glyphs(di)
    if di <= 0 then return 10, 11 end
    if di <= 10 then return 10 - di, 11 end
    if di == 11 then return 10, 12 end
    if di <= 20 then return di - 11, 12 end
    return 13 + math.min(di - 21, 3), 17
end

local DRUM_X = 482.3
local CHARA_ON_DRUM = {dx = 165.0, dy = 45.0, scale = 1.0}

local function drum_y(f)
    return 737.0 + (557.0 - 737.0) * ease_out(math.min(1.0, math.max(0.0, (f - 1.0) / 14.0)))
end

local function put_c(id, ox, oy, extra, cx, cy)
    local p = extra or {}
    p.x = (cx or POP_CX) + ox
    p.y = (cy or POP_CY) + oy
    p.center = true
    tex.draw_texture(id, p)
end

function DanResultDraw:draw_sparks(f, cx, cy)
    for _, sp in ipairs(SPARKS) do
        local u = ((f - sp[3]) % 60.0) / 60.0
        local a = (f >= sp[3]) and ((u < 0.55) and (u / 0.55) or ((1.0 - u) / 0.45)) or 0.0
        a = a * 0.96
        if a > 0.01 then
            put_c(self.t_sd_spark, sp[1], sp[2], {scale = 1.0 + 0.19 * a, fade = a}, cx, cy)
        end
    end
end

function DanResultDraw:draw_mascots(f, t0, cx, cy)
    if f < t0 then return end
    local u = (f - t0) / 30.0
    local drift = math.max(0.0, math.min(1.0, (f - t0 - 30.0) / 19.0))
    local ya = 570.0 + (76.4 - 570.0) * ease_out(u) + 3.6 * drift
    local yb = 400.0 + (-93.6 - 400.0) * ease_out(u) + 3.6 * drift
    put_c(self.t_sd_mascot_a, -360, ya, nil, cx, cy)
    put_c(self.t_sd_mascot_b, 100, yb, nil, cx, cy)
end

function DanResultDraw:draw_celebration(s)
    local f = (s.now - s.celebrate_start_ms) / FRAME_MS
    local rd = self.rd

    put_c(self.t_sd_panel, -561, -251.5)
    if rd.dan_index >= 0 then
        local shown = math.min(rd.dan_index, math.floor(f / 2.0))
        local l, r = rank_glyphs(shown)
        put_c(self.t_sd_glyph, -232, -46, {frame = l})
        put_c(self.t_sd_glyph, 8, -46, {frame = r})
    end
    if f < 40.0 then
        local u = f / 40.0
        put_c(self.t_sd_glow, -561, -251.5, {scale = 1.0 + 0.5 * u, fade = 1.0 - u})
    end
    self:draw_sparks(f)
    self:draw_mascots(f, 40.0)

    -- drum (sprite 1214 red / 1217 blue): rises from the bottom over f1-15 (ease-out) and holds
    if f >= 1.0 then
        local y = drum_y(f)
        local drum = (rd.player_num == 2) and self.t_sd_drum_blue or self.t_sd_drum_red
        put_c(drum, 0, 0, nil, 482.3, y)
    end
end

local PLATE_FADE_AT, STAFFROLL_AT = 249 + 240, 249 + 240 + 30 + 120

local function lerp_keys(keys, f)
    if f <= keys[1][1] then return keys[1][2] end
    for k = 1, #keys - 1 do
        local a, b = keys[k], keys[k + 1]
        if f < b[1] then return a[2] + (b[2] - a[2]) * (f - a[1]) / (b[1] - a[1]) end
    end
    return keys[#keys][2]
end

local PLATE_SCALE = { {74, 4.273}, {114, 1.0}, {119, 1.1}, {123, 1.0} }
local GHOST_SCALE = { {92, 4.28}, {116, 1.0}, {120, 1.1}, {123, 1.0} }
local GHOST_ALPHA = { {92, 0.0}, {116, 0.449}, {120, 0.449}, {123, 0.0} }
local FLASH_SCALE = { {114, 1.0}, {119, 1.1}, {123, 1.0} }
local FLASH_ALPHA = { {114, 0.0}, {119, 1.0}, {123, 0.809}, {124, 0.777}, {149, 0.0} }

local function drop_in(keys, f)
    if f >= keys[2][1] then return lerp_keys(keys, f) end
    local u = (f - keys[1][1]) / (keys[2][1] - keys[1][1])
    return keys[1][2] + (keys[2][2] - keys[1][2]) * u * u
end

function DanResultDraw:draw_plate_tatsujin(f)
    local a = 1.0
    if f >= PLATE_FADE_AT then a = math.max(0.0, 1.0 - (f - PLATE_FADE_AT) / 30.0) end
    if a <= 0 then return end
    put_c(self.t_cg_board, -561, -252, {fade = a})
    if f < 40.0 then
        local u = f / 40.0
        put_c(self.t_sd_glow, -561, -251.5, {scale = 1.0 + 0.5 * u, fade = (1.0 - u) * a})
    end
    if f >= 123.0 then
        local y = 6.0
        if f < 155.0 then
            y = -544.0 + 550.0 * (f - 123.0) / 31.0
        elseif f < 163.0 then
            y = 6.0 - 20.0 * math.sin(math.pi * (f - 154.0) / 8.0)
        end
        put_c(self.t_cg_don, 252, y - 180, {fade = math.min(1.0, (f - 123.0) / 31.0) * a})
    end
    if f >= 72.0 then
        local u = math.min(1.0, (f - 74.0) / 40.0)
        put_c(self.t_cg_plate, -212, -128, {scale = drop_in(PLATE_SCALE, f), fade = math.max(0.0, u * u) * a})
    end
    if f >= 92.0 and f < 123.0 then
        put_c(self.t_cg_plate, -212, -128, {scale = drop_in(GHOST_SCALE, f), fade = lerp_keys(GHOST_ALPHA, f) * a})
    end
    if f >= 114.0 and f < 149.0 then
        put_c(self.t_cg_flash, -212, -128, {scale = lerp_keys(FLASH_SCALE, f), fade = lerp_keys(FLASH_ALPHA, f) * a})
    end
    if f >= 165.0 then
        local u = math.min(1.0, (f - 165.0) / 84.0)
        put_c(self.t_cg_text, -350, 100, {fade = u * u * a})
        put_c(self.t_cg_title, -468, -180, {fade = u * u * a})
    end
end

local STAFFROLL_PAGES = 5
function DanResultDraw:draw_staffroll(f)
    local t = f - STAFFROLL_AT
    for page = 0, STAFFROLL_PAGES - 1 do
        local hold = (page == 0) and 360 or 210
        if t < 30 + hold + 30 then
            local a = (t < 30) and (t / 30) or ((t < 30 + hold) and 1.0 or (1.0 - (t - 30 - hold) / 30))
            if t >= 0 then tex.draw_texture(self.t_sr_page, {frame = page, fade = a}) end
            return
        end
        t = t - (30 + hold + 30)
    end
end

function DanResultDraw:draw_congrats(s)
    local f = (s.now - s.congrats_start_ms) / FRAME_MS
    self:draw_plate_tatsujin(f)
    if self.t_sr_page then self:draw_staffroll(f) end
end

function DanResultDraw:draw_message(fade, now)
    if not self.t_message then return end
    local f = (now - self.page_start_ms - self.voice_at) / FRAME_MS - 18.0
    if f <= 0 then return end
    tex.draw_texture(self.t_message, {fade = fade * math.min(1.0, f / 20.0)})
end

function DanResultDraw:draw_overlay(s)
    if s.congrats_showing then
        self:draw_congrats(s)
    elseif s.celebrating then
        self:draw_celebration(s)
    else
        self:draw_stamp(s.page2_fade, s.now)
        self:draw_message(s.page2_fade, s.now)
        return
    end
    tex.draw_rect(0, 0, tex.get_screen_width(), tex.get_screen_height(), 0, 0, 0, math.floor(s.fade_out * 255))
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
    self.popup_up = s.celebrating or s.congrats_showing
    self.celebrate_f = s.celebrating and (s.now - s.celebrate_start_ms) / FRAME_MS or nil
    self.congrats_up = s.congrats_showing

    if not s.congrats_showing then
        self:draw_page1(now - self.page1_start_ms)
        self:draw_page2(s.page2_fade, now)
    end

    tex.draw_rect(0, 0, tex.get_screen_width(), tex.get_screen_height(), 0, 0, 0, math.floor(s.fade_out * 255))
end

function DanResultDraw:chara_pos()
    if self.celebrate_f and self.celebrate_f >= 1.0 then
        return {DRUM_X + CHARA_ON_DRUM.dx, drum_y(self.celebrate_f) + CHARA_ON_DRUM.dy, CHARA_ON_DRUM.scale}
    end
    if self.popup_up then return {-2000.0, -2000.0, 1.0} end
    return nil
end

function DanResultDraw:nameplate_pos()
    if self.congrats_up then return {-2000.0, -2000.0, 0.0} end
    return nil
end
