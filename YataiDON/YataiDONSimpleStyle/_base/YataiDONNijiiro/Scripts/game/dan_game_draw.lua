local SKIN = {
    dan_game_hori_name = { x = 1800, y = 735, width = 200 },
    dan_game_exam_border_text = { x = 500, y = 621, font_size = 36, outline = 2.666667 },
}
local WHITE, BLACK = { 255, 255, 255, 255 }, { 0, 0, 0, 255 }

local JP_THRESHOLD = {
    dan_exam_text_more        = "%s 以上",
    dan_exam_text_less        = "%s 未満",
    dan_exam_text_gauge       = "%s ％以上",
    dan_exam_text_gauge_less  = "%s ％未満",
}

local function exam_threshold_text(exam_type, range, num)
    local gauge, less = exam_type == "gauge", range == "less"
    local key = gauge and (less and "dan_exam_text_gauge_less" or "dan_exam_text_gauge")
                       or (less and "dan_exam_text_less" or "dan_exam_text_more")
    local fmt = tex.skin_text(key)
    if fmt == "" then fmt = JP_THRESHOLD[key] end
    fmt = fmt:gsub("%%%%", "\1")
    return (fmt:gsub("%%s", tostring(num)):gsub("\1", "%%"))
end

local function pad_for(outline, scale)
    return math.floor(outline * scale) + 2
end

local EXAM_ICON_PATHS = {
    gauge = "exam_gauge", combo = "exam_combo", hit = "exam_hit", judgebad = "exam_judgebad",
    judgegood = "exam_judgegood", judgeperfect = "exam_judgeperfect", score = "exam_score",
    renda = "exam_roll",
}

DanGameDraw = {}
DanGameDraw.__index = DanGameDraw

function DanGameDraw.new(title)
    local self = setmetatable({}, DanGameDraw)
    local function T(name) return tex.get_texture("game/dan_info/" .. name) end
    local names = {
        "exam_bg", "exam_overlay_1", "exam_overlay_2", "exam_fail", "exam_failed", "exam_less",
        "exam_more", "exam_percent", "exam_badge", "exam_frame_back_all", "exam_frame_front_all",
        "exam_border_counter", "value_counter", "exam_sub_bg", "exam_sub_track", "exam_sub_front",
        "exam_sub_chip", "exam_sub_counter", "total_notes", "rank_plate", "frame",
    }
    self.t = {}
    for _, n in ipairs(names) do self.t[n] = T(n) end

    self.icons = {}
    for exam_type, name in pairs(EXAM_ICON_PATHS) do
        self.icons[exam_type] = T(name)
    end
    self.fill_bar = {}
    for _, n in ipairs({ "exam_sub_red", "exam_red", "exam_sub_gold", "exam_gold", "exam_sub_max",
                         "exam_max", "exam_sub_rainbow", "exam_rainbow", "exam_rainbow_all",
                         "exam_sub_down80", "exam_down80" }) do
        self.fill_bar[n] = T(n)
    end

    self.captions = {}
    self.threshold = {}
    self.infos = {}
    local ds = tex.get_skin_config("dan_select_title")
    self.hori_name = text.create_raw_text(title, ds and ds.font_size or 40, WHITE, BLACK, false)
    return self
end

function DanGameDraw:info(name)
    local c = self.infos[name]
    if c == nil then
        c = tex.get_texture_info("dan_info", name) or false
        self.infos[name] = c
    end
    return c
end

function DanGameDraw:threshold_caption(info, size, outline)
    local key = tostring(info.exam_type) .. "\31" .. tostring(info.exam_range) .. "\31" .. tostring(info.red_value)
    local c = self.threshold[key]
    if not c then
        c = self:caption(exam_threshold_text(info.exam_type, info.exam_range, info.red_value), size, outline)
        self.threshold[key] = c
    end
    return c
end

function DanGameDraw:digit_counter(digits, margin_x, t, index, y, x_offset)
    x_offset = x_offset or 0
    local n = #digits
    for j = 1, n do
        tex.draw_texture(t, { frame = digits:byte(j) - 48, x = -(n - j + 1) * margin_x + x_offset,
                              y = y, index = index })
    end
end

function DanGameDraw:caption(s, size, outline)
    local key = s .. "\31" .. size .. "\31" .. math.floor(outline * 100)
    local c = self.captions[key]
    if not c then
        c = text.create_raw_text(s, size, WHITE, BLACK, false, outline)
        self.captions[key] = c
    end
    return c
end

function DanGameDraw:fill(state, w, fy, sub, all, frame_ms)
    if w <= 0 or state == "empty" then return end
    local fb = self.fill_bar
    local rb = sub and "exam_sub_rainbow" or "exam_rainbow"
    if not sub and all and fb.exam_rainbow_all then rb = "exam_rainbow_all" end
    local d80  = sub and "exam_sub_down80" or "exam_down80"
    local up50 = sub and "exam_sub_red"    or "exam_red"
    local up80 = sub and "exam_sub_gold"   or "exam_gold"
    local p100 = sub and "exam_sub_max"    or "exam_max"
    if state == "max" and fb[rb] then
        local rb_tex = fb[rb]
        local info = self:info(rb)
        local th, tw = info.height, info.width
        local perd = tw * 0.5
        local ph = perd - math.fmod(frame_ms / 1000.0 * (perd * 60.0 / 80.0), perd)
        local avail = tw - ph
        if w <= avail then
            tex.draw_texture(rb_tex, { y = fy, x2 = w, src = { x = ph, y = 0, width = w, height = th } })
        else
            tex.draw_texture(rb_tex, { y = fy, x2 = avail, src = { x = ph, y = 0, width = avail, height = th } })
            tex.draw_texture(rb_tex, { x = avail, y = fy, x2 = w - avail,
                                       src = { x = 0, y = 0, width = w - avail, height = th } })
        end
        return
    end
    local id = p100
    if state == "up_50" then id = up50
    elseif state == "up_80" then id = up80
    elseif state == "down_80" then id = fb[d80] and d80 or up80 end
    tex.draw_texture(fb[id], { y = fy, x2 = w })
end

function DanGameDraw:exam_row(info, y, song_index, frame_ms)
    local t = self.t
    self.dei = self.dei or tex.get_skin_config("game_dan_exam_info") or tex.get_skin_config("dan_select_exam_info")
    local dei = self.dei
    local border_margin = 26
    local value_margin = 56

    tex.draw_texture(t.exam_bg, { y = y })
    tex.draw_texture(t.exam_badge, { frame = info.gothrough and 0 or 1 + math.min(song_index, 2), y = y })

    local all = info.gothrough
    tex.draw_texture(all and t.exam_frame_back_all or t.exam_overlay_1, { y = y })

    local bar_full = all and 972 or dei.width

    if info.failed then
        if t.exam_fail then tex.draw_texture(t.exam_fail, { y = y, x2 = bar_full }) end
    else
        self:fill(info.bar_state, bar_full * info.progress, y, false, all, frame_ms)
    end

    tex.draw_texture(all and t.exam_frame_front_all or t.exam_overlay_2, { y = y })

    local icon = self.icons[info.exam_type]
    if icon then tex.draw_texture(icon, { y = y }) end

    local bt = SKIN.dan_game_exam_border_text
    local cap, bt_ol
    bt_ol = 4.0 / tex.get_screen_scale()
    if bt then
        if bt.outline >= 0 then bt_ol = bt.outline end
        cap = self:threshold_caption(info, bt.font_size > 0 and bt.font_size or 36, bt_ol)
    end
    if cap then
        local pad = pad_for(bt_ol, tex.get_screen_scale())
        cap:draw({ x = bt.x - cap.width + pad, y = bt.y - pad + y })
    else
        if info.exam_range == "less" then tex.draw_texture(t.exam_less, { y = y })
        elseif info.exam_range == "more" then tex.draw_texture(t.exam_more, { y = y }) end

        local gauge_shift = 0
        if info.exam_type == "gauge" then
            tex.draw_texture(t.exam_percent, { y = y, index = 0 })
            gauge_shift = -48
        end
        self:digit_counter(tostring(info.red_value), border_margin, t.exam_border_counter, 0, y, gauge_shift)
    end

    if info.failed then
        tex.draw_texture(t.exam_failed, { y = y })
    else
        local vl = { x = 528 }
        local live = tostring(info.counter_value)
        if vl then
            local vc = self:info("value_counter")
            local json_x = (vc and vc.x[1]) or 920.0
            for j = 1, #live do
                tex.draw_texture(t.value_counter, { frame = live:byte(j) - 48,
                                                    x = vl.x + (j - 1) * value_margin - json_x, y = y })
            end
            if info.exam_type == "gauge" then
                local pc = self:info("exam_percent")
                local pjson = (pc and pc.x[2]) or 944.0
                tex.draw_texture(t.exam_percent, { x = vl.x + #live * value_margin - pjson, y = y, index = 1 })
            end
        else
            self:digit_counter(live, value_margin, t.value_counter, 0, y)
            if info.exam_type == "gauge" then tex.draw_texture(t.exam_percent, { y = y, index = 1 }) end
        end
    end

    if not all then
        local sub_pitch  = 50.0
        local sub_margin = 20.0
        local sub_full = 234.0
        for j = 0, 1 do
            local sy = y + j * sub_pitch
            tex.draw_texture(t.exam_sub_bg, { y = sy })
            if j < info.song_count then   -- not reached yet: stub only
                tex.draw_texture(t.exam_sub_track, { y = sy })
                self:fill(info.song_state[j + 1], sub_full * info.song_progress[j + 1], sy, true, all, frame_ms)
                tex.draw_texture(t.exam_sub_front, { y = sy })
                tex.draw_texture(t.exam_sub_chip, { frame = j, y = sy })
                self:digit_counter(tostring(info.song_value[j + 1]), sub_margin, t.exam_sub_counter, 0, sy)
            end
        end
    end
end

function DanGameDraw:draw(s)
    local t = self.t
    tex.draw_texture(t.total_notes, {})

    self.dei = self.dei or tex.get_skin_config("game_dan_exam_info") or tex.get_skin_config("dan_select_exam_info")
    local offset_y = self.dei.y
    local slot = 0
    for _, info in ipairs(s.rows) do
        if info.exam_type ~= "gauge" then
            if slot >= 3 then break end
            self:exam_row(info, slot * offset_y, s.song_index, s.frame_ms)
            slot = slot + 1
        end
    end

    if s.dan_rank >= 0 then
        tex.draw_texture(t.rank_plate, { frame = s.dan_rank })
    else
        tex.draw_texture(t.frame, { frame = s.dan_color })
        local hn = SKIN.dan_game_hori_name
        local h = self.hori_name
        h:draw({ x = hn.x - h.width / 2.0, y = hn.y, x2 = math.min(h.width, hn.width) - h.width })
    end
end
