local UI = require("global.ss_ui")
local SKIN = {
    dan_yellow_box_offset = { x = 0, y = 110 },   -- the song rows' step (also in dan_select_base)
}
-- DAN_SELECT paint surface: selection cursor breathing loop and arrow chips,
-- sampled from the cabinet's own clips. The dan boxes themselves are drawn by the
-- dan_select_base.lua (this skin's copy of the parent's script from before upstream dropped
-- the exam grid and its options), which is loaded first and extended here.

-- the parent skin's copy of this script: the second match on package.path (the first is this file)
local function load_parent(name)
    local seen = false
    for tmpl in package.path:gmatch("[^;]+") do
        local chunk = loadfile((tmpl:gsub("%?", name)))
        if chunk then
            if seen then return chunk end
            seen = true
        end
    end
end
local function load_own(name)
    for tmpl in package.path:gmatch("[^;]+") do
        local chunk = loadfile((tmpl:gsub("%?", name)))
        if chunk then return chunk end
    end
end
local parent = load_own("dan_select/dan_select_base") or load_parent("dan_select/dan_select")
if parent then parent() end
if not DanSelect then
    DanSelect = {}
    DanSelect.__index = DanSelect
end
local parent_new = DanSelect.new

local ok, anim = pcall(require, "anim/sampler")
if not ok then anim = { safe = function()
    local n = {}
    n.at = function() return nil end; n.get = function() return nil end
    n.label = function() return nil end; n.has = function() return false end
    n.first = function() return 0 end;  n.last = function() return 0 end
    return n
end } end

local CUR = anim.safe("anim/dan_cursor")
local ARW = anim.safe("anim/dan_arrow")
local ARW_OFF = ARW:label("arrow_off") or 61

-- No real clip data at all -> no draw_cursor: the engine draws the cursor from its
-- inline tables (the boxes are still drawn by the parent's DanSelect).
local HAS_CLIPS = CUR:has("#259@0") or ARW:has("#261@0")

function DanSelect.new()
    local self = parent_new and parent_new() or setmetatable({}, DanSelect)
    self.t_cursor  = tex.get_texture("dan_select/box/cursor")
    self.t_arrow_r = tex.get_texture("dan_select/box/arrow_r")
    self.t_arrow_l = tex.get_texture("dan_select/box/arrow_l")
    return self
end

-- pos: selected chip x (the textures' own json positions carry the rest);
-- now_ms: engine clock; moved_ms: ms since the last ribbon step (-1 = never);
-- y: how far the selected chip has dropped (see draw_box below).
local function draw_cursor(self, pos, now_ms, moved_ms, y)
    y = y or 0
    if self.t_cursor then
        local f = (now_ms * 0.06) % 60
        local a = CUR:get("#259@0", f, "a") or 1
        tex.draw_texture(self.t_cursor, { x = pos, y = y })
    end
    if moved_ms and moved_ms >= 0 then
        local f = moved_ms * 0.06
        if f <= (ARW_OFF - 1) then
            local drift = ARW:get("#261@0", f, "tx") or 0
            local a     = ARW:get("#261@0", f, "a") or 0
            if a > 0 then
                if self.t_arrow_r then
                    tex.draw_texture(self.t_arrow_r, { x = pos, y = y, fade = UI.solid(a) })
                end
                if self.t_arrow_l then
                    tex.draw_texture(self.t_arrow_l, { x = pos, y = y, fade = UI.solid(a) })
                end
            end
        end
    end
end

if HAS_CLIPS then DanSelect.draw_cursor = draw_cursor end

-- The level is the cabinet's own art, one "star + number" image per level
-- (yellow_box/difficulty_level, frames 1..10 and 10+), in place of the parent's star and
-- level digits, which are held back.
local function draw_level(level, x, y, f)
    local id = tex.get_texture("dan_select/yellow_box/difficulty_level")
    if not id or level < 1 then return end
    tex.draw_texture(id, { frame = math.min(level, 11) - 1, x = x, y = y, fade = UI.solid(f) })
end

-- The course rows are set as the cabinet's: the song title alone (no subtitle line), and the
-- exam values with narrow digits beside full-width 以上/未満 and a little room between them.
-- The skin has one font, so each text is cut into runs of ASCII and of everything else, each
-- run made on its own and scaled as it is drawn, the runs butted together. The parent is handed
-- the box through a view whose song_subtitle_text gives nothing and whose song_title_text gives
-- such a title, and the captions it makes for the exam values are made the same way. Only CJK
-- languages are rescaled; the skin's font for the others is narrow already.
local function cjk_language()
    local l = tex.language() or ""
    return l:find("^ja") or l:find("^zh") or l:find("^ko") or l == "tw" or l == "cn"
end
local TITLE_CJK = { latin = 1, cjk = 1, sy = 1, dy = 0, max_w = 1080 }
local VALUE_CJK = { latin = 0.85, cjk = 1.0, sy = 1.0, dy = 0, gap = 8 }
local TITLE_PLAIN = { latin = 1, cjk = 1, sy = 1, dy = 0, max_w = 1080 }
local VALUE_PLAIN = { latin = 1, cjk = 1, sy = 1, dy = 0 }

local function runs_of(str)
    local runs, cur, ascii = {}, {}, nil
    for ch in str:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        local a = ch:byte() < 128
        if ascii ~= nil and a ~= ascii then
            runs[#runs + 1] = { text = table.concat(cur), ascii = ascii }
            cur = {}
        end
        cur[#cur + 1] = ch
        ascii = a
    end
    if #cur > 0 then runs[#runs + 1] = { text = table.concat(cur), ascii = ascii } end
    return runs
end

-- create: text.create_raw_text as it was before any wrapping. The parts' sizes are read when
-- they are used, since a text's texture (and size) may still be building when it is made.
local function mixed_text(create, str, size, color, outline_color, outline, spacing, style)
    local pad = math.floor((outline or 0) * tex.get_screen_scale()) + 2
    local parts = {}
    for _, r in ipairs(runs_of(str)) do
        parts[#parts + 1] = { t = create(r.text, size, color, outline_color, false, outline, spacing),
                              sx = r.ascii and style.latin or style.cjk }
    end
    local function layout()
        local function span(k)
            local x = 0
            for n, q in ipairs(parts) do
                q.x = x
                local next_sx = parts[n + 1] and parts[n + 1].sx * k or 0
                x = x + (q.t.width - pad) * q.sx * k - pad * next_sx
                if parts[n + 1] then x = x + (style.gap or 0) * k end
            end
            local last = parts[#parts]
            return last and (last.x + last.t.width * last.sx * k) or 0
        end
        local k, w = 1, span(1)
        if style.max_w and w > style.max_w then
            k = style.max_w / w
            w = span(k)
        end
        local h = 0
        for _, q in ipairs(parts) do h = math.max(h, q.t.height) end
        return k, w, h * style.sy
    end
    return setmetatable({
        text = str,
        draw = function(_, p)
            local k = layout()
            for _, q in ipairs(parts) do
                local sx = q.sx * k
                q.t:draw({ x = p.x + q.x, y = (p.y or 0) + style.dy, fade = UI.solid(p.fade),
                           x2 = q.t.width * (sx - 1), y2 = q.t.height * (style.sy - 1) })
            end
        end,
    }, {
        __index = function(_, key)
            if key == "width" then local _, w = layout(); return w end
            if key == "height" then local _, _, h = layout(); return h end
        end,
    })
end

local title_cache = {}   -- by string, size and outline: texts are built once, not per frame
local raw_create = text.create_raw_text   -- the engine's, before draw_dan_open wraps it

local function course_view(box)
    local titles = {}
    return setmetatable({}, {
        __index = function(_, k)
            if k == "song_subtitle_text" then return function() return nil end end
            if k == "song_title_text" then
                return function(_, i)
                    if titles[i] == nil then
                        local t = box:song_title_text(i)
                        local ok, str = pcall(function() return t and t.text end)
                        local td = tex.get_skin_config("dan_select_title")
                        if t and ok and type(str) == "string" and str ~= "" and td then
                            local ol = td.outline >= 0 and td.outline or 5
                            local key = str .. "\0" .. td.font_size .. "\0" .. ol
                            title_cache[key] = title_cache[key]
                                or mixed_text(raw_create, str, td.font_size,
                                              { 58, 38, 51, 255 }, { 58, 38, 51, 255 }, 0, 2,
                                              cjk_language() and TITLE_CJK or TITLE_PLAIN)
                            titles[i] = title_cache[key]
                        else
                            titles[i] = t or false   -- an engine without OutlinedText.text
                        end
                    end
                    return titles[i] or nil
                end
            end
            local v = box[k]
            if type(v) == "function" then
                return function(_, ...) return v(box, ...) end
            end
            return v
        end,
    })
end

-- The clear stamps are the cabinet's six (box/clear_mark and yellow_box/clear_mark, frames
-- 0..5 = red pass, full combo, all good, gold pass, full combo, all good), picked by the
-- saved record's rank (2..7). An engine without box.record_rank only gives clear_mark
-- (1 passed, 2 rank 7), which maps to frames 0 and 5.
local function stamp_frame(box)
    local ok, rank = pcall(function() return box.record_rank end)
    if ok and type(rank) == "number" then
        return rank >= 2 and math.min(rank, 7) - 2 or nil
    end
    if box.clear_mark == 1 then return 0 end
    if box.clear_mark == 2 then return 5 end
    return nil
end

-- The parent also draws global/bg_header, bg_footer and footer; this skin only has the background.
-- Dan box ribbon: { centre x, spacing between boxes, extra gap left of the selection, extra gap right }
function DanSelect:ribbon()
    return { 960, 69, 0, 0 }
end

local SSM = require("global.ss_meta")
function DanSelect:draw_back()
    local bg = tex.get_texture("dan_select/global/bg")
    if bg then tex.draw_texture(bg) end
    SSM.dan_momo_draw()
end

-- The course's clear stamp (yellow_box/clear_mark) sits over the dan plate and Don, as the
-- cabinet's stamp_detail does (it is above don_1p). The parent draws it with the box, under
-- both, so it is held back there and drawn with the title, which the engine draws after
-- the chara and the nameplate.
local parent_open = DanSelect.draw_dan_open
local held_stamp   -- shared: the boxes and the title can be drawn through different instances
if parent_open then
    function DanSelect:draw_dan_open(box)
        local stamp = tex.get_texture("dan_select/yellow_box/clear_mark")
        local level = tex.get_texture("dan_select/yellow_box/difficulty_level")
        local hide = {}
        if level then
            for _, n in ipairs({ "difficulty_star", "difficulty_num", "difficulty_x", "difficulty_ura" }) do
                local t = tex.get_texture("dan_select/yellow_box/" .. n)
                if t then hide[#hide + 1] = t end
            end
        end
        local draw = tex.draw_texture
        tex.draw_texture = function(id, p)
            if id == stamp then return end
            for _, t in ipairs(hide) do   -- handles compare with ==, not as table keys
                if id == t then return end
            end
            return draw(id, p)
        end
        local create = text.create_raw_text
        text.create_raw_text = function(str, size, color, outline_color, vertical, outline, spacing, ...)
            if vertical or type(str) ~= "string" then   -- only the exam value captions
                return raw_create(str, size, color, outline_color, vertical, outline, spacing, ...)
            end
            return mixed_text(raw_create, str, size, color, outline_color, outline, spacing,
                              cjk_language() and VALUE_CJK or VALUE_PLAIN)
        end
        local ok, err = pcall(parent_open, self, course_view(box))
        text.create_raw_text = create
        tex.draw_texture = draw
        if not ok then error(err, 0) end
        local f = box.open_fade.attribute
        local off = SKIN.dan_yellow_box_offset or { x = 0, y = 0 }
        if level then
            for i = 0, box:song_count() - 1 do
                draw_level(box:song_level(i), i * (off.x or 0), i * (off.y or 0), f)
            end
        end
        local sf = stamp and stamp_frame(box)
        if sf then held_stamp = { id = stamp, frame = sf, fade = UI.solid(f) } end
    end

    function DanSelect:draw_title()
        local s = held_stamp
        held_stamp = nil
        if s then tex.draw_texture(s.id, { frame = s.frame, fade = UI.solid(s.fade) }) end
    end
end

-- The back entry is one more chip in the top strip (back/folder, laid out like box/folder);
-- the parent's opening board is its own layout, so nothing opens under it here.
-- Its label comes from skin_config dan_back_label, so it follows the language setting. It is set
-- like the dan chip names (black, no outline: dan_chip_name_black), vertical for CJK and
-- across, squeezed to the chip, for other languages.
local CJK = { ja = true, zh = true, ko = true, tw = true, cn = true }
local back_label
local BACK_ACROSS_SIZE = 0.7   -- size of a label set across, against dan_back_label.font_size
local function get_back_label()
    if back_label == nil then
        local cfg = tex.get_skin_config("dan_back_label")
        if not cfg then back_label = false; return false end
        local lang = tex.language()
        local vertical = CJK[lang] or CJK[lang:sub(1, 2)] or false
        -- a word set across has only the chip's width, so it takes a smaller size than the
        -- vertical labels rather than being squeezed hard
        local size = vertical and cfg.font_size or math.floor(cfg.font_size * BACK_ACROSS_SIZE + 0.5)
        back_label = {
            cfg      = cfg,
            vertical = vertical,
            main     = raw_create(tex.skin_text("dan_back_label"), size,
                                  { 58, 38, 51, 255 }, { 58, 38, 51, 255 }, vertical, 0, 2),
        }
    end
    return back_label
end

local function draw_back_label(bx, fade, y)
    local label = get_back_label()
    if not label then return end
    local cfg, main = label.cfg, label.main
    local sx, sy = 1, 1
    if label.vertical then
        sy = math.min(1, cfg.height / main.height)
    else
        sx = math.min(1, cfg.width / main.width)   -- width: chip face less the border
    end
    local w, h = main.width * sx, main.height * sy
    main:draw({ x = bx + cfg.x - w / 2, y = cfg.y + (cfg.height - h) / 2 + y,
                x2 = w - main.width, y2 = h - main.height, fade = UI.solid(fade) })
end

-- The selected chip drops below the strip, as the cabinet's does, easing there and back.
-- Only draw_cursor (called after every box) is told where the cursor is, so the boxes are
-- held back in draw_box and drawn from draw_cursor.
local SELECTED_DROP = 21
local DROP_MS = 60                -- time constant of the ease
local drop = {}                   -- chip key -> current drop
local held_boxes = {}
local last_ms

local function chip_key(box)
    return box.is_back and "\0back" or box.text_name
end

local function chip_drop(box)
    return drop[chip_key(box)] or 0
end

local function draw_chip_name(box, bx, y, fade)
    local name = box:chip_name()
    if not name then return end
    local nb = tex.get_skin_config("dan_select_chip_name") or { x = 0, y = 0 }
    name:draw({
        x = bx + nb.x - name.width / 2,
        y = nb.y + y,
        y2 = math.min(name.height, nb.height or name.height) - name.height,
        fade = UI.solid(fade),
    })
end

-- the chip as the parent draws it (folder, stamp, name), at its drop
function DanSelect:draw_dan_closed(box)
    local bx, fade, y = box:box_x(), box.fade.attribute, chip_drop(box)
    local id = tex.get_texture("dan_select/box/folder")
    if id then tex.draw_texture(id, { frame = box.dan_color, x = bx, y = y, fade = UI.solid(fade) }) end
    local sf = stamp_frame(box)
    local mark = sf and tex.get_texture("dan_select/box/clear_mark")
    if mark then tex.draw_texture(mark, { frame = sf, x = bx, y = y, fade = UI.solid(fade) }) end
    draw_chip_name(box, bx, y, fade)
end

function DanSelect:draw_back_box(box)
    local bx, fade, y = box:box_x(), box.fade.attribute, chip_drop(box)
    local id = tex.get_texture("dan_select/back/folder")
    if id then tex.draw_texture(id, { x = bx, y = y, fade = UI.solid(fade) }) end
    draw_back_label(bx, fade, y)
end

-- The cursor's glow goes over the chip, its emblem and name (they grey under it, as on the
-- cabinet) but not over the clear stamp, which is drawn again on top of it.
local function draw_chip_front(box)
    if box.is_back then return end
    local sf = stamp_frame(box)
    local mark = sf and tex.get_texture("dan_select/box/clear_mark")
    if mark then
        tex.draw_texture(mark, { frame = sf, x = box:box_x(), y = chip_drop(box),
                                 fade = UI.solid(box.fade.attribute) })
    end
end

local parent_draw_box = DanSelect.draw_box
function DanSelect:draw_box(box)
    held_boxes[#held_boxes + 1] = box
end

local cursor_parent = DanSelect.draw_cursor
function DanSelect:draw_cursor(pos, now_ms, moved_ms)
    SSM.dan_momo_cursor(moved_ms)
    local boxes = held_boxes
    held_boxes = {}
    local k = last_ms and math.min(1, math.max(0, now_ms - last_ms) / DROP_MS) or 1
    last_ms = now_ms
    local selected
    for _, box in ipairs(boxes) do
        local key = chip_key(box)
        local is_sel = math.abs(box:box_x() - pos) < 1
        if is_sel then selected = box end
        local d = drop[key] or 0
        d = d + ((is_sel and SELECTED_DROP or 0) - d) * k
        drop[key] = (math.abs(d) >= 0.05) and d or nil
    end
    -- draw every box even if one fails, then report the first failure
    local err
    for _, box in ipairs(boxes) do
        local ok, e = pcall(parent_draw_box, self, box)
        if not ok and not err then err = e end
    end
    if err then error(err, 0) end
    local y = selected and chip_drop(selected) or 0
    if cursor_parent then
        cursor_parent(self, pos, now_ms, moved_ms, y)
    elseif self.t_cursor then
        tex.draw_texture(self.t_cursor, { x = pos, y = y })
    end
    if selected then draw_chip_front(selected) end
    return true
end

-- Each exam's 自己ベスト row, as on the cabinet: a white pill under the value with the label
-- on its left and the saved best on its right (box:exam_best / exam_song_best). With no best
-- (a course never played, or an engine without them) the row is not drawn at all, pill
-- included. The gauge box gets yellow_box/exam_gauge_best_pill, the right-hand boxes
-- yellow_box/exam_best_pill, one per song segment. The boxes are walked as the parent's
-- draw_exam_grid walks them.
local BEST_GAUGE = { x = 10, y = 116, w = 301 }   -- exam_gauge_best_pill, from the box
local BEST_RIGHT = { x = 11, y = 86, w = 317 }    -- exam_best_pill, from the box (+ seg dx)
local BEST_H = 31
local BEST_LABEL_X, BEST_VALUE_R = 8, 14          -- label from the pill's left, value from its right

local best_texts = {}
local function best_text(key, str, font_size)
    font_size = font_size or (tex.get_skin_config(key) or {}).font_size
    if not font_size or str == nil or str == "" then return nil end
    local k = key .. "\0" .. str
    if best_texts[k] == nil then
        best_texts[k] = raw_create(str, font_size, { 58, 38, 51, 255 }, { 58, 38, 51, 255 },
                                   false, 0, 1) or false
    end
    return best_texts[k] or nil
end

local function call(box, name, ...)
    local ok, fn = pcall(function() return box[name] end)
    if not ok or type(fn) ~= "function" then return nil end
    local ok2, v = pcall(fn, box, ...)
    return ok2 and v or nil
end

local function draw_best_row(pill, value, etype, px, py, pw, f)
    if value == nil then return end
    if pill then tex.draw_texture(pill, { x = px, y = py, fade = UI.solid(f) }) end
    local label = best_text("dan_exam_best_label", tex.skin_text("dan_exam_best_label"))
    if label then
        label:draw({ x = px + BEST_LABEL_X, y = py + (BEST_H - label.height) / 2, fade = UI.solid(f) })
    end
    local str = tostring(value) .. (etype == "gauge" and " %" or "")
    local t = best_text("dan_exam_best_value", str, 26)
    if t then
        t:draw({ x = px + pw - BEST_VALUE_R - t.width, y = py + (BEST_H - t.height) / 2, fade = UI.solid(f) })
    end
end

local parent_grid = DanSelect.draw_exam_grid
if parent_grid then
    function DanSelect:draw_exam_grid(box, f)
        parent_grid(self, box, f)
        local pill = tex.get_texture("dan_select/yellow_box/exam_best_pill")
        local gauge_pill = tex.get_texture("dan_select/yellow_box/exam_gauge_best_pill")
        local gb = tex.get_skin_config("dan_exam_gauge_box") or { x = 436, y = 610 }
        local sb = tex.get_skin_config("dan_exam_score_box") or { x = 769, y = 610, height = 132 }
        local sg = tex.get_skin_config("dan_exam_seg") or { width = 327 }
        local pitch = (sb.height and sb.height > 0) and sb.height or 132
        local seg_dx = (sg.width and sg.width > 0) and sg.width or 327
        local right_row, gauge_used = 0, false
        for i = 0, box:exam_count() - 1 do
            local etype = box:exam_type(i)
            local left = (etype == "gauge" and not gauge_used)
            if left then gauge_used = true end
            if left then
                draw_best_row(gauge_pill, call(box, "exam_best", i), etype,
                              gb.x + BEST_GAUGE.x, gb.y + BEST_GAUGE.y, BEST_GAUGE.w, f)
            elseif right_row < 3 then
                local by = sb.y + pitch * right_row
                local gothrough = box:exam_gothrough(i)
                local segs = gothrough and 1 or math.min(box:song_count(), 3)
                for k = 0, segs - 1 do
                    local px = sb.x + BEST_RIGHT.x + seg_dx * k
                    local py = by + BEST_RIGHT.y
                    local v = gothrough and call(box, "exam_best", i) or call(box, "exam_song_best", i, k)
                    draw_best_row(pill, v, etype, px, py, BEST_RIGHT.w, f)
                end
                right_row = right_row + 1
            end
        end
    end
end

local ss_new = DanSelect.new
function DanSelect.new(...)
    local s = ss_new(...)
    SSM.dan_reset()
    return s
end
-- SimpleStyle: Momo cheers once when the confirm box opens. polish_meta: the box opens and closes as a
-- window (UI.open_rect: 33 / 66 / 100 % height, 50 ms steps) instead of popping in at the fade's midpoint.
local ss_confirm = DanSelect.draw_confirm
local CONF_X, CONF_Y, CONF_W, CONF_H = 264, 239, 1386, 504     -- confirm_box/bg's dialog (ss/v2_meta.py)
local conf = { open = nil, close = nil, shown = false }
function DanSelect:draw_confirm(f, index)
    SSM.dan_momo_confirm(f)
    local now = tex.get_current_ms()
    local on = UI.solid(f or 0) == 1
    if on and not conf.shown then conf.open, conf.close = now, nil end
    if not on and conf.shown then conf.close = now end
    conf.shown = on
    local since
    if on and conf.open and now - conf.open < 100 then since = now - conf.open end
    if not on and conf.close and now - conf.close < 100 then since = 99 - (now - conf.close) end
    if since then
        UI.wipe(1, UI.D.P.ink)
        local x, y, w, h = UI.open_rect(CONF_X, CONF_Y, CONF_W, CONF_H, since)
        if x then UI.chrome.dialog(x, y, w, h) end
        return
    end
    if ss_confirm then return ss_confirm(self, f, index) end
end

-- ===================================================================== SimpleStyle round 2
-- Course chips: core's course chip (UI.course.chip, one course identity) left of each song title.
local P = UI.D.P
local PLATE_CHIP_X, PLATE_CHIP_Y = 258, 294   -- the rank chip centre (ss/v2_meta.py PLATE_CHIP_C)
local ss_open = DanSelect.draw_dan_open
if ss_open then
    function DanSelect:draw_dan_open(box)
        ss_open(self, box)
        if UI.solid(box.open_fade.attribute) == 0 then return end
        local off = SKIN.dan_yellow_box_offset or { x = 0, y = 110 }
        for i = 0, box:song_count() - 1 do
            UI.course.chip(box:song_difficulty(i), 525 + i * (off.x or 0), 249 + i * (off.y or 110))
        end
        -- the frame plate (no rank plate): the course name in ink on the rank chip, 48 -> 36 -> 24 px
        local rank = tonumber(box.dan_rank) or -1
        if rank < 0 and box.dan_title and box.dan_title ~= "" then
            local t
            for _, sz in ipairs({ 48, 36, 24 }) do
                t = UI.text(box.dan_title, sz)
                if t and t.width <= 198 then break end
            end
            UI.draw_text(t, PLATE_CHIP_X, PLATE_CHIP_Y, "c")
        end
    end
end

-- The exam grid laid out across the frame (x 417..1782, y 594..957): one panel per exam, gauge
-- first; 1 exam = the whole width, 2 = two columns, 3 = 2 + 1 full row, 4 = 2 x 2. A panel holds its
-- name tab on its top edge, one value per song segment (全体 / 1曲目..), a gauge bar for the soul gauge
-- and the saved best. Values are engine text through UI.text (ink, whole pixels).
local EX = { x0 = 435, x1 = 1764, y0 = 630, y1 = 939, gap = 18 }
local FR = { x = 417, y = 594, w = 1365, h = 363 }   -- the exam frame (yellow_box/exam_frame)
local EXAM_KEY = { gauge = "exam_gauge", combo = "exam_combo", hit = "exam_hit", judgebad = "exam_judgebad",
                   judgegood = "exam_judgegood", judgeperfect = "exam_judgeperfect", score = "exam_score",
                   renda = "exam_roll" }
local EXAM_LABEL = { gauge = "dan_ex_gauge", combo = "dan_ex_combo", hit = "dan_ex_hit", judgebad = "dan_ex_bad",
                     judgegood = "dan_ex_ok", judgeperfect = "dan_ex_good", score = "dan_ex_score",
                     renda = "dan_ex_roll" }
local U = UI.U
local function ytex(name) return tex.get_texture("dan_select/yellow_box/" .. name) end
local function header_word()   -- 合格条件 on the yellow_box/exam_header tab (270 x 36 at 420, 561)
    UI.draw_text(SSM.fit_key("dan_conditions", 252, { 24, 18 }), 420 + 135, 561 + 18, "c")
end
local function call_opt(box, name, ...)
    local ok, fn = pcall(function() return box[name] end)
    if not ok or type(fn) ~= "function" then return nil end
    local ok2, v = pcall(fn, box, ...)
    return ok2 and v or nil
end
local function grid(v) return math.floor(v / UI.U) * UI.U end
-- "85 ％以上" (engine / Nijiiro format: space + full-width ％) reads as a double space in the pixel
-- font: the number and its percent sign belong together ("85%以上"), the dan result's
-- exam_threshold_text join
local function pct_join(s)
    s = tostring(s or "")
    return (s:gsub(" ?\239\188\133", "%%"):gsub(" +%%", "%%"))
end
-- the 合格条件 tab (yellow_box/exam_header: drawn at y 561, 36 tall) ends on the frame rule; a lone
-- exam's name tab (33 tall) sits on the same baseline
local TAB_Y = 561 + 36 - 36

local function exam_panel(box, i, x, y, w, h, tab_dx, tab_y)
    UI.chrome.panel(x, y, w, h)
    local etype = box:exam_type(i)
    local key = EXAM_KEY[etype]
    local pill = key and ytex(key)
    if pill then
        local px, py = x + (tab_dx or 18), tab_y or (y - 18)
        tex.draw_texture(pill, { x = px, y = py })
        -- the exam name: engine text, 24 px ink on the 228 x 33 tab (18 px when a translation is longer)
        local lk = EXAM_LABEL[etype]
        if lk then UI.draw_text(SSM.fit_key(lk, 204, { 24, 18 }), px + 5 * U, py + 18, "l") end
    end
    local gothrough = box:exam_gothrough(i)
    local segs = gothrough and 1 or math.max(1, math.min(box:song_count(), 3))
    local sw = grid((w - 12) / segs)
    local big = (segs == 1 and h >= 150)
    local cy = y + math.floor(h / 2)
    if etype == "gauge" and h >= 150 then cy = y + math.floor(h * 0.4) end
    local best_label = tex.skin_text("dan_exam_best_label")
    for k = 0, segs - 1 do
        local sx = x + 6 + k * sw
        local scx = sx + math.floor(sw / 2)
        local labelled = (etype ~= "gauge")
        if labelled then
            -- 全体 / 1曲目..: a line chip sized to the label (at least the old 87 px), 18 px ink
            local lk = gothrough and "dan_total" or ("dan_song_" .. (k + 1))
            local cw = math.max(87, math.ceil((UI.label_width(lk, 18) + 6 * U) / U) * U)
            local ix, iy, iw, ih = UI.chrome.chip(grid(scx - cw / 2), y + 24, cw, 36, P.line, false)
            UI.draw_text(UI.text_key(lk, 18), ix + iw / 2, iy + ih / 2, "c")
        end
        local cap = pct_join(gothrough and box:exam_caption(i) or box:exam_song_caption(i, k))
        local vy = labelled and (cy + 12) or cy
        UI.draw_text(UI.text(cap, big and 48 or 36), scx, vy, "c")
        local best = gothrough and call_opt(box, "exam_best", i) or call_opt(box, "exam_song_best", i, k)
        if best ~= nil and best_label then
            local s = best_label .. " " .. tostring(best) .. (etype == "gauge" and "%" or "")
            UI.draw_text(UI.text(s, 18, { color = P.text2 }), scx, y + h - 24, "c")
        end
    end
    if etype == "gauge" and h >= 150 then
        -- the soul gauge with the norma marked: fill to the required %, 10 segments
        local red = tonumber(box:exam_red(i)) or 0
        local bw = math.min(grid(w - 96), 720)
        UI.pixbar(grid(x + (w - bw) / 2), cy + 42, bw, 27, red / 100, P.clear, 10, P.bg3)
        local gold = tonumber(call_opt(box, "exam_gold", i))
        if gold and h >= 240 then   -- a whole-row gauge panel also states the gold pass
            UI.draw_text(UI.text_key("dan_gold_more", 24, { color = P.gold_t }, tostring(gold)),
                         x + math.floor(w / 2), cy + 108, "c")
        end
    end
end

function DanSelect:draw_exam_grid(box, f)
    if UI.solid(f) == 0 then return end
    local list = {}
    for i = 0, box:exam_count() - 1 do
        if #list < 4 then list[#list + 1] = i end
    end
    local n = #list
    -- one exam: that exam's panel IS the frame (no panel-in-panel); its name tab sits on the frame's
    -- top edge right of the 合格条件 tab (x 420..830)
    local frame = (n ~= 1) and ytex("exam_frame")
    if frame then tex.draw_texture(frame) end
    -- engine text made here is plain: draw_dan_open has wrapped create_raw_text for its captions
    local wrapped = text.create_raw_text
    text.create_raw_text = raw_create
    if n == 1 then
        local ok1, err1 = pcall(exam_panel, box, list[1], FR.x, FR.y, FR.w, FR.h, 432, TAB_Y)
        local header = ytex("exam_header")
        if header then tex.draw_texture(header); header_word() end
        text.create_raw_text = wrapped
        if not ok1 then error(err1, 0) end
        return
    end
    local header = ytex("exam_header")
    if header then tex.draw_texture(header); header_word() end
    local rows = (n <= 2) and 1 or 2
    local ph = grid((EX.y1 - EX.y0 - EX.gap * (rows - 1)) / rows)
    local fw = EX.x1 - EX.x0
    local hw = grid((fw - EX.gap) / 2)
    local ok, err = pcall(function()
        for idx, i in ipairs(list) do
            local r = (idx <= 2) and 0 or 1
            local first = (r == 0) and 1 or 3
            local in_row = math.min(2, n - first + 1)
            if n == 1 then in_row = 1 end
            local c = idx - first
            local w = (in_row == 1) and fw or hw
            local x = EX.x0 + c * (hw + EX.gap)
            local y = EX.y0 + r * (ph + EX.gap)
            exam_panel(box, i, x, y, w, ph)
        end
    end)
    text.create_raw_text = wrapped
    if not ok then error(err, 0) end
end

-- ===================================================================== SimpleStyle: dynamic text
-- The words of every dan select texture are engine text in the player's language (SCREEN_GUIDE_V2 §11):
-- the textures are chrome only and these labels draw the words right after the texture, whichever
-- script draws it (SSM.with_labels hooks tex.draw_texture while a DanSelect draw method runs).
-- Positions are frame-local (ss/v2_meta.py); x, y = the texture's drawn top-left.
local RANK_KEYS = { "dan_kyu_5", "dan_kyu_4", "dan_kyu_3", "dan_kyu_2", "dan_kyu_1", "dan_shodan", "dan_2", "dan_3", "dan_4", "dan_5", "dan_6", "dan_7", "dan_8", "dan_9", "dan_10", "dan_kuroto", "dan_meijin", "dan_chojin", "dan_tatsujin", "dan_sousaku", "dan_gaiden", "dan_shokyu", "dan_kyu_10", "dan_kyu_9", "dan_kyu_8", "dan_kyu_7", "dan_kyu_6" }   -- yellow_box/rank_plate frames
local function seal_col(frame) return ((frame or 0) < 3) and P.red_t or P.gold_t end
local function plate_words(x, y, rank)
    UI.draw_text(SSM.fit_key("dan_dojo", 252, { 36, 24 }), x + 138, y + 36, "c")
    local key = rank and RANK_KEYS[rank + 1]
    if key then UI.draw_text(SSM.fit_key(key, 198, { 48, 36, 24 }), x + 141, y + 123, "c") end
    UI.draw_text(UI.text_key("dan_unplayed", 36, { color = P.mute }), x + 138, y + 372, "c")
end
local function at(key, x, y, size, style, align, dx, dy)
    UI.draw_text(UI.text_key(key, size, style), x + dx, y + dy, align or "c")
end
local DAN_LABELS = SSM.label_set({
    { "dan_select/box/clear_mark", "box", "clear_mark", function(x, y, p)
        at("dan_pass_mark", x, y, 18, { color = seal_col(p.frame) }, "c", 39, 24)
    end },
    { "dan_select/yellow_box/clear_mark", "yellow_box", "clear_mark", function(x, y, p)
        local fr = p.frame or 0
        at("dan_pass", x, y, 48, { color = seal_col(fr) }, "c", 147, 111)
        if fr % 3 ~= 0 then   -- the フルコンボ / 全良 chip under the seal, sized to the word
            local key = (fr % 3 == 1) and "full_combo" or "zenryo"
            local cw = math.ceil((UI.label_width(key, 18) + 8 * U) / U) * U
            local ix, iy, iw, ih = UI.chrome.chip(grid(x + 147 - cw / 2), y + 204, cw, 36, P.paper, false)
            UI.draw_text(UI.text_key(key, 18), ix + iw / 2, iy + ih / 2, "c")
        end
    end },
    { "dan_select/yellow_box/song_label", "yellow_box", "song_label", function(x, y, p)
        -- text24: the 24 px 曲目 word needs more room under the number: the box is redrawn 84 high (the baked
        -- 75 x 75 box is covered), number at y 28, word at y 62
        UI.chrome.panel(x, y, 75, 84)
        UI.draw_text(UI.text(tostring((p.frame or 0) + 1), 36), x + 37.5, y + 28, "c")
        UI.draw_text(SSM.fit_key("dan_song_label", 69, { 24 }), x + 37.5, y + 62, "c")
    end },
    { "dan_select/yellow_box/hidden_title", "yellow_box", "hidden_title", function(x, y)
        at("dan_hidden_title", x, y, 36, { color = P.mute }, "l", 6, 30)
    end },
    { "dan_select/yellow_box/total_notes", "yellow_box", "total_notes", function(x, y)
        UI.draw_text(SSM.fit_key("dan_total_notes", 282, { 24, 18 }), x + 0, y + 19.5, "l")
    end },
    { "dan_select/yellow_box/rank_plate", "yellow_box", "rank_plate", function(x, y, p) plate_words(x, y, p.frame or 0) end },
    { "dan_select/yellow_box/frame", "yellow_box", "frame", function(x, y) plate_words(x, y, nil) end },
    { "dan_select/confirm_box/bg", "confirm_box", "bg", function(x, y)
        at("dan_dojo", x, y, 36, nil, "c", 693, 30)
    end },
    { "dan_select/confirm_box/confirmation_text", "confirm_box", "confirmation_text", function(x, y)
        at("dan_confirm", x, y, 36, nil, "c", 323.5, 34.5)
    end },
    { "dan_select/confirm_box/yes", "confirm_box", "yes", function(x, y) at("dan_yes", x, y, 36, nil, "c", 72.5, 17.5) end },
    { "dan_select/confirm_box/no", "confirm_box", "no", function(x, y) at("dan_no", x, y, 36, nil, "c", 86.5, 17.5) end },
})
for name, fn in pairs(DanSelect) do
    if type(fn) == "function" and name:sub(1, 5) == "draw_" then
        DanSelect[name] = function(...) return SSM.with_labels(DAN_LABELS, fn, ...) end
    end
end
