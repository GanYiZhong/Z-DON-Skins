local SKIN_S = tex.get_screen_scale()
local SKIN = {
    dan_game_hori_name = { x = 148 * SKIN_S, y = 392 * SKIN_S, width = 275 * SKIN_S },
    dan_total_notes_margin = { x = 46 * SKIN_S },
    dan_game_exam_border_text = { x = 1232 * SKIN_S, y = 409 * SKIN_S, font_size = math.floor(32 * SKIN_S), outline = 4 },
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

-- Lumen row tops (minus the first 3-row top) for 1, 2 and 3 exam rows.
local ROW_OFFSETS = { { 91 }, { 39, 135 }, { 0, 99, 198 } }

DanGameDraw = {}
DanGameDraw.__index = DanGameDraw

function DanGameDraw.new(title)
    local self = setmetatable({}, DanGameDraw)
    local function T(name) return tex.get_texture("game/dan_info/" .. name) end
    -- Labels, thresholds and live values are engine text; only the plates, bars and digits are art.
    self.t = {}
    for _, n in ipairs({ "exam_bg", "exam_overlay_1", "exam_overlay_2", "exam_fail", "exam_failed",
                         "total_notes_counter", "frame", "exam_flash" }) do
        self.t[n] = T(n)
    end
    self.bars = { exam_red = T("exam_red"), exam_gold = T("exam_gold"), exam_max = T("exam_max") }

    self.captions = {}
    self.live = {}
    self.fx = {}
    local ds = tex.get_skin_config("dan_select_title")
    self.hori_name = text.create_raw_text(title, ds and ds.font_size or 40, WHITE, BLACK, false)
    return self
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

-- Engine-drawn threshold phrase ("100 以上"), right-aligned at dan_game_exam_border_text.
local UNIT_CHAR = { hit = "打", renda = "打", score = "点" }
local LIVE_UNIT = { gauge = "％", combo = "コンボ", hit = "打", renda = "打", score = "点" }

-- Live value as engine text number right-aligned at dan_game_exam_value_text.x, unit mark after it.
-- Re-rendered only when the string changes (one cache slot per row part).
function DanGameDraw:live_caption(slot, str, size, outline)
    local c = self.live[slot]
    if not c or c.str ~= str then
        -- first sight is not a change: only later updates pop
        c = { str = str, cap = text.create_raw_text(str, size, WHITE, BLACK, false, outline),
              changed = c and tex.get_current_ms() or nil }
        self.live[slot] = c
    end
    return c.cap, c.changed
end

-- Lumen digit pop: 1.0 -> 1.15 in 33 ms, back to 1.0 in 100 ms.
local function pop_scale(changed)
    if not changed then return 1.0 end
    local t = tex.get_current_ms() - changed
    if t < 33 then return 1.0 + 0.15 * t / 33 end
    if t < 133 then return 1.15 - 0.15 * (t - 33) / 100 end
    return 1.0
end

function DanGameDraw:draw_live_text(info, y, slot)
    local s = tex.get_screen_scale()
    local vt = { x = 490 * s, y = 384 * s }
    local ol = 4.0
    local size = math.floor(32 * s)
    local pad = pad_for(ol, tex.get_screen_scale())
    local num, changed = self:live_caption(slot, tostring(info.counter_value), size, ol)
    num:draw({ x = vt.x - num.width + pad, y = vt.y - pad + y, scale = pop_scale(changed), center = true })
    local unit = LIVE_UNIT[info.exam_type]
    if unit then
        local u = self:live_caption(slot + 10, unit, size, ol)
        u:draw({ x = vt.x + 4 - pad, y = vt.y - pad + y })
    end
end

function DanGameDraw:border_caption(info)
    local bt = SKIN.dan_game_exam_border_text
    local ol = bt.outline >= 0 and bt.outline or 4.0 / tex.get_screen_scale()
    local unit = UNIT_CHAR[info.exam_type] or ""
    local cap = self:caption(exam_threshold_text(info.exam_type, info.exam_range, info.red_value .. unit),
                             bt.font_size > 0 and bt.font_size or 36, ol)
    local pad = pad_for(ol, tex.get_screen_scale())
    return cap, bt.x - cap.width + pad, bt.y - pad
end

-- Exam type label ("コンボ数") right-aligned just left of the threshold phrase.
function DanGameDraw:draw_label(info, x, y)
    local str = tex.skin_text("dan_exam_label_" .. info.exam_type)
    if str == "" then return end
    local s = tex.get_screen_scale()
    local lc = { x = 8 * s, y = 409 * s }
    local ol = 4.0
    local cap = self:caption(str, math.floor(32 * s), ol)
    local pad = pad_for(ol, tex.get_screen_scale())
    cap:draw({ x = x - lc.x - cap.width + pad, y = lc.y - pad + y })
end

-- White strip over the bar. On a colour change (red -> gold -> max): alpha 0 -> 0.98 in 83 ms, out over
-- 883 ms. While cleared (max) a slow glow loops: 0 -> 0.35 in 433 ms, out over 450 ms, every 1000 ms.
function DanGameDraw:bar_flash(info, y, slot)
    local fx = self.fx[slot]
    local now = tex.get_current_ms()
    if not fx then
        fx = { bar = info.bar_texture, start = nil }
        self.fx[slot] = fx
    elseif fx.bar ~= info.bar_texture then
        fx.bar, fx.start = info.bar_texture, now
    end
    local a = 0.0
    if fx.start then
        local t = now - fx.start
        if t < 83 then a = 0.98 * t / 83
        elseif t < 966 then a = 0.98 * (1.0 - (t - 83) / 883)
        else fx.start = nil end
    end
    if fx.bar == "exam_max" then
        local t = now % 1000
        local g
        if t < 433 then g = 0.352 * (1.0 - (1.0 - t / 433) ^ 2)
        elseif t < 883 then g = 0.352 * (1.0 - (t - 433) / 450) ^ 2
        else g = 0.0 end
        a = math.max(a, g)
    end
    if a > 0.0 and info.bar_width > 0 then
        tex.draw_texture(self.t.exam_flash, { y = y, x2 = info.bar_width, fade = a })
    end
end

function DanGameDraw:exam_row(info, y, slot)
    local t = self.t
    tex.draw_texture(t.exam_bg, { y = y })
    tex.draw_texture(t.exam_overlay_1, { y = y })
    local bar = self.bars[info.bar_texture]
    if info.failed then
        if t.exam_fail then tex.draw_texture(t.exam_fail, { y = y, x2 = info.bar_width }) end
    elseif bar then
        tex.draw_texture(bar, { y = y, x2 = info.bar_width })
    end
    if not info.failed then self:bar_flash(info, y, slot) end
    local cap, cx, cy = self:border_caption(info)
    self:draw_label(info, cx, y)
    cap:draw({ x = cx, y = cy + y })
    tex.draw_texture(t.exam_overlay_2, { y = y })
    if info.failed then
        tex.draw_texture(t.exam_failed, { y = y })
    else
        self:draw_live_text(info, y, slot)
    end
end

function DanGameDraw:draw(s)
    local t = self.t
    local tn = tex.get_skin_config("dan_game_total_notes_text")
    local str = tex.skin_text("dan_game_total_notes_text")
    if str ~= "" then
        local ol = tn.outline >= 0 and tn.outline or 4.0 / tex.get_screen_scale()
        local cap = self:caption(str, tn.font_size > 0 and tn.font_size or 36, ol)
        cap:draw({ x = tn.x - cap.width / 2.0, y = tn.y, x2 = math.min(cap.width, tn.width) - cap.width })
    end
    self:digit_counter(tostring(s.remaining_notes), SKIN.dan_total_notes_margin.x,
                       t.total_notes_counter, 0, 0)

    local rows = {}
    for _, info in ipairs(s.rows) do
        if info.exam_type ~= "gauge" and #rows < 3 then rows[#rows + 1] = info end
    end
    for slot, info in ipairs(rows) do
        self:exam_row(info, ROW_OFFSETS[#rows][slot], slot)
    end

    tex.draw_texture(t.frame, { frame = s.dan_color })
    local hn = SKIN.dan_game_hori_name
    local h = self.hori_name
    h:draw({ x = hn.x - h.width / 2.0, y = hn.y, x2 = math.min(h.width, hn.width) - h.width })
end
