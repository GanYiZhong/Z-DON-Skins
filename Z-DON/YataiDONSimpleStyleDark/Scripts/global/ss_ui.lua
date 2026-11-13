-- YataiDONSimpleStyle v2 shared Lua helpers: palette, grid, tabular digits, labels, rect chrome,
-- the sparkle burst and the pixel Mascot (Momo / Hoshi).    local UI = require("global.ss_ui")
-- Every coordinate here is LOGICAL (1920x1080). Textures (Graphics/global/ss_ui, Graphics/ss_mascot/*)
-- are physical (x D.DENSITY) and the engine reports them in logical units.
-- Geometry, palette and labels come from the generated global/ss_def.lua (ss/ui.py).
--
-- Core rules (SCREEN_GUIDE_V2.md):
--   * mascot size by ROLE: UI.Mascot.new({ role = "scene" }) (UI.K = tiny 3, menu 6, portrait 6, scene 9)
--   * ALPHA: pixel textures are drawn at alpha 1 or not at all. Route every fade through UI.solid(a)
--     (or UI.tex); screen-level fades are UI.wipe dither steps, window opens are UI.open_rect frames.
--   * engine text is created with UI.text (ink, or paper + 1U ink outline), never #000000 outlines
--   * one hint pill: UI.hint(items), bottom-right footer; one course identity: UI.course.*

local D = require("global.ss_def")
local UI = { D = D, P = D.P, U = D.U }

-- Z-DON comfort mode (skin_config "ss_comfort": {"x": 1}): the motion that can make players dizzy goes soft.
-- Fades instead of on / off pops, no blinking, no beat hops, plain fades instead of checker wipes, a still
-- floor pattern and smoothly drifting clouds. The pixel art itself is unchanged.
do
    local c = tex and tex.get_skin_config and tex.get_skin_config("ss_comfort")
    UI.COMFORT = c ~= nil and (c.x or 0) ~= 0
end

-- true while a blinking item (cursor, prompt) is shown: on / off every `ms` (400), always on in comfort mode
function UI.blink_on(elapsed_ms, ms)
    if UI.COMFORT then return true end
    return math.floor((elapsed_ms or 0) / (ms or 400)) % 2 == 0
end

-- mascot k by role (logical px per sprite px): the one table every screen uses
UI.K = { tiny = D.MASCOT.k.tiny, menu = D.MASCOT.k.menu, portrait = D.MASCOT.k.portrait, scene = D.MASCOT.k.scene }

-- warnings go to latest.log through tex.log (spdlog info "[lua] [ss_ui] warning: ..."); Lua print only
-- reaches stdout, which the engine does not log. run_cap.sh greps them.
local warned = {}
local function warn_once(key, msg)
    if warned[key] then return end
    warned[key] = true
    local line = "[ss_ui] warning: " .. msg
    if tex and tex.log then tex.log(line) else print(line) end
end
UI.warn_once = warn_once

local cache = {}
local function T(name)
    local t = cache[name]
    if t == nil then
        t = tex.get_texture("global/" .. name) or false
        cache[name] = t
    end
    return t or nil
end
UI.T = T

-- a mascot sprite at baked scale k: Graphics/ss_mascot/k<k>_<name>, a folder no screen loads; the engine loads
-- it on this first request (and prefetches it with the screen next time), so only drawn sprites take memory
local function TM(k, name)
    local key = "ss_mascot/k" .. k .. "_" .. name
    local t = cache[key]
    if t == nil then
        t = tex.get_texture(key .. "/" .. name) or false
        cache[key] = t
    end
    return t or nil
end
UI.TM = TM

-- texture handles go stale when the screen's folders are reloaded: call once per screen (in new())
function UI.reset() cache = {} end

-- whole physical pixel (pixel art must land on the physical grid)
function UI.px(v) return math.floor(v * D.DENSITY) / D.DENSITY end
-- floor to the chrome grid
function UI.grid(v) return math.floor(v / D.U) * D.U end

function UI.rgba(c, a) return { c[1], c[2], c[3], a or 255 } end

function UI.mix(a, b, t)
    return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

function UI.rect(x, y, w, h, c, a)
    if w <= 0 or h <= 0 then return end
    tex.draw_rect(x, y, w, h, c[1], c[2], c[3], a or 255)
end

-- smooth shapes: notes / lane only (everything else is pixel chrome)
function UI.rrect(x, y, w, h, r, c, a, line_w, line_c, line_a)
    local f = math.min(1.0, (2 * r) / math.max(1, math.min(w, h)))
    tex.draw_rounded_rect(x, y, w, h, f, UI.rgba(c, a or 255), line_w or 0,
        line_c and UI.rgba(line_c, line_a or 255) or { 0, 0, 0, 0 })
end

function UI.circle(cx, cy, r, c, a)
    tex.draw_rounded_rect(cx - r, cy - r, r * 2, r * 2, 1.0, UI.rgba(c, a), 0, { 0, 0, 0, 0 })
end

function UI.ring(cx, cy, r, th, c, a)
    tex.draw_rounded_rect(cx - r, cy - r, r * 2, r * 2, 1.0, { 0, 0, 0, 0 }, th, UI.rgba(c, a))
end

-- ---------------------------------------------------------------- rect chrome (ss/chrome.py specs)
-- notched rectangle: the four corner squares (n x n) stay empty
local function notched(x, y, w, h, n, c, a)
    if n > 0 then
        UI.rect(x + n, y, w - 2 * n, h, c, a)
        UI.rect(x, y + n, n, h - 2 * n, c, a)
        UI.rect(x + w - n, y + n, n, h - 2 * n, c, a)
    else
        UI.rect(x, y, w, h, c, a)
    end
end
UI.notched = notched

-- the one chrome primitive: hard shadow, notched border, flat fill. All values multiples of D.U.
-- o = { fill, border (px), shadow (px), notch (px), border_c, a }
function UI.frame(x, y, w, h, o)
    o = o or {}
    local U = D.U
    local b, s, n = o.border or U, o.shadow or U, o.notch or U
    local a = o.a or 255
    x, y = UI.grid(x), UI.grid(y)
    if s > 0 then notched(x + s, y + s, w, h, n, D.P.ink, a) end
    notched(x, y, w, h, n, o.border_c or D.P.ink, a)
    UI.rect(x + b, y + b, w - 2 * b, h - 2 * b, o.fill or D.P.paper, a)
    return x + b, y + b, w - 2 * b, h - 2 * b      -- inner rect
end

local U = D.U
UI.chrome = {
    dialog = function(x, y, w, h, a) return UI.frame(x, y, w, h, { border = 2 * U, shadow = 2 * U, a = a }) end,
    panel = function(x, y, w, h, fill, a) return UI.frame(x, y, w, h, { fill = fill, a = a }) end,
    -- state: "normal" | "focused" | "pressed"
    button = function(x, y, w, h, state, a)
        if state == "pressed" then
            return UI.frame(x + U, y + U, w, h, { fill = D.P.bg2, shadow = 0, a = a })
        elseif state == "focused" then
            return UI.frame(x, y, w, h, { fill = D.P.focus, border = 2 * U, a = a })
        end
        return UI.frame(x, y, w, h, { fill = D.P.bg2, a = a })
    end,
    -- edge = true: bg3 fill + 1U accent left edge; else accent fill
    chip = function(x, y, w, h, accent, edge, a)
        if edge then
            local ix, iy, iw, ih = UI.frame(x, y, w, h, { fill = D.P.bg3, shadow = 0, notch = 0, a = a })
            UI.rect(ix, iy, U, ih, accent or D.P.clear, a)
            return ix + U, iy, iw - U, ih
        end
        return UI.frame(x, y, w, h, { fill = accent or D.P.bg3, shadow = 0, notch = 0, a = a })
    end,
}

-- segmented meter: 1U ink frame, groove, fill snapped to whole U, 1U dividers on U columns
function UI.pixbar(x, y, w, h, frac, fill, segs, groove)
    x, y = UI.grid(x), UI.grid(y)
    UI.rect(x, y, w, h, D.P.ink)
    local ix, iy, iw, ih = x + U, y + U, w - 2 * U, h - 2 * U
    UI.rect(ix, iy, iw, ih, groove or D.P.bg3)
    local fw = math.floor(iw * math.max(0, math.min(1, frac)) / U) * U
    UI.rect(ix, iy, fw, ih, fill)
    for i = 1, (segs or 0) - 1 do
        UI.rect(ix + math.floor(iw * i / segs / U + 0.5) * U, iy, U, ih, D.P.ink)
    end
end

-- ---------------------------------------------------------------- digits and labels
function UI.num_width(s, size)
    local g = D.DIGIT[size]
    local w = 0
    for i = 1, #s do w = w + (g.adv[s:sub(i, i)] or g.w) end
    return w
end

-- tabular digits; size "s" | "m" | "l" | "xl" (18/24/36/48); align "l" | "r" | "c"; y = cell centre
function UI.num(s, x, y, size, color, a, align)
    s = tostring(s)
    local t = T("ss_ui/digits_" .. size)
    if not t then return 0 end
    local g = D.DIGIT[size]
    local w = UI.num_width(s, size)
    local px = x
    if align == "r" then px = x - w elseif align == "c" then px = x - w / 2 end
    local col = UI.rgba(color or D.P.ink, a or 255)
    local y0 = UI.px(y - g.h / 2)
    for i = 1, #s do
        local ch = s:sub(i, i)
        local idx = D.CHARS:find(ch, 1, true)
        local adv = g.adv[ch] or g.w
        if idx then
            tex.draw_texture(t, { frame = idx - 1, x = UI.px(px - (g.w - adv) / 2), y = y0, color = col })
        end
        px = px + adv
    end
    return w
end

-- a fixed label; y = vertical centre. Two forms:
--   UI.label(key, role_size, style) -> a cached OutlinedText of UI.t(key) (dynamic, player's language)
--   UI.label(key, x, y, color, a, align) -> draws it (18 px, tinted `color`), returns its width. Dynamic
--     when ss/strings.py has the key, else the baked ss_ui/labels frame (build --lang).
-- The third argument tells them apart (a number = the draw form).
function UI.label(key, x, y, color, a, align)
    if type(y) ~= "number" then return UI.text_key(key, x, y) end
    local s = UI.t(key)
    if s then
        if UI.solid(a) == 0 then return 0 end
        local t = UI.text(s, 18, { color = color or D.P.ink, outline = false })
        return UI.draw_text(t, x, y, align)
    end
    local t = T("ss_ui/labels")
    local l = D.LABEL[key]
    if not t or not l then return 0 end
    local px = x
    if align == "r" then px = x - l.w elseif align == "c" then px = x - l.w / 2 end
    tex.draw_texture(t, { frame = l.frame, x = UI.px(px), y = UI.px(y - D.LABEL_H / 2),
        color = UI.rgba(color or D.P.ink, a or 255) })
    return l.w
end

-- the event sparkle burst (bible 2.4): call every frame with the ms since the event; draws frames
-- 0..3 (66 ms each) centred on (cx, cy), then nothing. Returns false once finished.
function UI.burst(cx, cy, since_ms)
    if since_ms < 0 then return true end
    local f = math.floor(since_ms / D.BURST.ms)
    if f >= D.BURST.frames then return false end
    local t = T("ss_ui/burst")
    if t then
        local h = D.BURST.size / 2
        tex.draw_texture(t, { frame = f, x = UI.px(cx - h), y = UI.px(cy - h) })
    end
    return true
end

-- ---------------------------------------------------------------- alpha policy (core rule)
-- Pixel textures are drawn at alpha 1 or not at all: a half-alpha pixel is a blend, i.e. an off-palette
-- colour on screen. Fades become steps:
--   UI.solid(a)   -> 1 or 0 (a in 0..1, or 0..255 when > 1; nil = 1); threshold 0.5. For `fade =` / alpha.
--   UI.dither(a)  -> wipe level 0..4 (0 nothing, 1..3 = 25/50/75 % checker, 4 solid) for screen fades.
--   UI.tex(t, p)  -> tex.draw_texture with p.fade snapped by UI.solid (skips the draw at 0). Mutates p.
function UI.solid(a)
    if a == nil then return 1 end
    if a > 1 then a = a / 255 end
    if UI.COMFORT then return math.max(0, math.min(1, a)) end -- comfort: a real fade
    return (a >= 0.5) and 1 or 0
end

function UI.dither(a)
    if a == nil then return 4 end
    if a > 1 then a = a / 255 end
    return math.max(0, math.min(4, math.floor(a * 4 + 0.5)))
end

function UI.tex(t, p)
    if not t then return end
    p = p or {}
    if p.fade ~= nil then
        p.fade = UI.solid(p.fade)
        if p.fade == 0 then return end
    end
    tex.draw_texture(t, p)
end

-- the checker-dither wipe (bible 2.7): level 0 nothing, 1..3 = 25 / 50 / 75 % dither, 4 = solid.
-- color = D.P.<token> (default sky). y0 / y1 limit it to a band of rows (default the whole screen).
function UI.wipe(level, color, y0, y1)
    if UI.COMFORT then -- comfort: an even veil (alpha level / 4), no checker pattern
        level = math.max(0, math.min(4, level or 0))
        if level <= 0 then return end
        local c = color or D.P.sky
        y0, y1 = y0 or 0, y1 or tex.get_screen_height()
        tex.draw_rect(0, y0, tex.get_screen_width(), y1 - y0, c[1], c[2], c[3], math.floor(255 * level / 4 + 0.5))
        return
    end
    level = math.floor(level or 0)
    if level <= 0 then return end
    local c = color or D.P.sky
    y0, y1 = y0 or 0, y1 or tex.get_screen_height()
    if level >= 4 then
        tex.draw_rect(0, y0, tex.get_screen_width(), y1 - y0, c[1], c[2], c[3], 255)
        return
    end
    local t = T("ss_ui/wipe")
    if not t then return end
    local col = { c[1], c[2], c[3], 255 }
    local cell = D.WIPE.cell
    local r = math.floor(y0 / cell)
    for y = r * cell, y1 - 1, cell do
        tex.draw_texture(t, { frame = (level - 1) * 2 + (r % 2), x = 0, y = y, color = col })
        r = r + 1
    end
end

-- wipe timing: wipe_in(t) = 1, 2, 3 then 4 (solid); wipe_out(t) = 3, 2, 1 then 0; `step` ms per level (50)
function UI.wipe_in(t, step)
    step = step or 50
    if t < 0 then return 0 end
    if UI.COMFORT then return math.min(4, t / step + 1) end -- comfort: continuous (UI.wipe fades)
    return math.min(4, math.floor(t / step) + 1)
end

function UI.wipe_out(t, step)
    step = step or 50
    if t < 0 then return 4 end
    if UI.COMFORT then return math.max(0, 3 - t / step) end
    return math.max(0, 3 - math.floor(t / step))
end

-- window open (bible 2.7): 3 frames (33 / 66 / 100 % height, 50 ms each) around the vertical centre.
-- Returns x, y, w, h, done (nil before since_ms 0). Draw the window into that rect at alpha 1.
function UI.open_rect(x, y, w, h, since_ms)
    if since_ms < 0 then return nil end
    local f = math.floor(since_ms / 50)
    local k = (f >= 2) and 1 or ((f == 1) and 0.66 or 0.33)
    local hh = math.floor(h * k / D.U) * D.U
    local yy = UI.grid(y + (h - hh) / 2)
    return x, yy, w, hh, f >= 2
end

-- ---------------------------------------------------------------- engine text (ink outline, never #000000)
-- UI.text(str, size, style) -> a cached OutlinedText. size = the text ROLE size 18 | 24 | 36 | 48, the same
-- numbers as baked text; it is created at the engine size D.TEXT_ENGINE[size] (24 / 32 / 48 / 64: the
-- engine's em is 0.75 x its font size, so this renders exactly like baked text, whole font pixels).
-- Other sizes warn once and are passed to the engine unchanged.
-- style: "ink" (default: ink, no outline; text on paper / cream / chips)
--        "paper" (paper + 1U ink outline; text on saturated fills, sky, scene)
--        "on_ink" (paper, no outline; text on ink bars)
--        or { color = D.P.<token>, outline = true | false } (the outline is always ink, 1U)
-- The outline colour is always D.P.ink and the thickness is passed explicitly (the engine default is 5).
-- Outline thickness: the engine multiplies it by screen_scale (width / 1280 = 1.5) and the density, so a
-- 1U (3 logical) ring is D.TEXT_OUTLINE = 2 engine units.
local TEXT_SIZES = D.TEXT_ENGINE
local text_cache = {}
local text_pad = {}      -- OutlinedText -> logical pad on each side (engine: (int)outline_phys + 2 phys)
local STYLES = { ink = { "ink", false }, paper = { "n_rim", true }, on_ink = { "n_rim", false },
                 on_acc = { "on_acc", false } }

local function style_of(style)
    if type(style) == "table" then return style.color or D.P.ink, style.outline == true end
    local s = STYLES[style or "ink"]
    if not s then
        warn_once("style" .. tostring(style), "UI.text style '" .. tostring(style) .. "' unknown; using ink")
        s = STYLES.ink
    end
    return D.P[s[1]] or D.P.ink, s[2]
end

function UI.text(str, size, style)
    str = tostring(str or "")
    size = size or 24
    if not TEXT_SIZES[size] then warn_once("text" .. size, "UI.text size " .. size .. " is not 18/24/36/48") end
    local col, outline = style_of(style)
    local key = str .. "|" .. size .. "|" .. col[1] .. "," .. col[2] .. "," .. col[3] .. "|" .. (outline and 1 or 0)
    local t = text_cache[key]
    if t == nil then
        local th = outline and D.TEXT_OUTLINE or 0
        t = text.create_raw_text(str, TEXT_SIZES[size] or size, UI.rgba(col), UI.rgba(D.P.shade), false, th, 0) or false
        if t then
            local ph = math.floor(th * D.SCREEN_SCALE * D.DENSITY) + 2
            text_pad[t] = ph / D.DENSITY
        end
        text_cache[key] = t
    end
    return t or nil
end

-- ---------------------------------------------------------------- localised strings (ss/strings.py)
-- UI.t(key, ...) -> the string in the player's language (tex.language(): ja / en / zh / ko), falling back
-- ja -> en (tex.skin_text). Looks up the skin's own `ss_<key>` (ss/strings.py, in our text_config.json),
-- then the bare key (engine / Nijiiro text_config entries such as course_name_0). nil when neither exists.
-- Extra arguments replace {0}, {1}, ... ("retry_rule" -> UI.t("retry_rule", 10)).
local t_cache, t_lang = {}, nil
function UI.lang()
    return (tex and tex.language and tex.language()) or "ja"
end

function UI.t(key, ...)
    if key == nil then return nil end
    local lang = UI.lang()
    if lang ~= t_lang then t_cache, t_lang = {}, lang end
    local s = t_cache[key]
    if s == nil then
        s = tex.skin_text and tex.skin_text("ss_" .. key) or ""
        if s == "" and tex.skin_text then s = tex.skin_text(key) end
        if s == "" then s = false end
        t_cache[key] = s
    end
    if not s then return nil end
    if select("#", ...) > 0 then
        local args = { ... }
        s = s:gsub("{(%d+)}", function(i) local v = args[tonumber(i) + 1]; return v ~= nil and tostring(v) or "" end)
    end
    return s
end

-- a localised string as a cached OutlinedText (role size 18/24/36/48, style as UI.text). A key with no
-- string draws the key itself (and warns once), so a missing translation is visible, never blank.
function UI.text_key(key, size, style, ...)
    local s = UI.t(key, ...)
    if not s then
        warn_once("tkey:" .. tostring(key), "UI.text_key: no string '" .. tostring(key) .. "' (ss/strings.py)")
        s = tostring(key)
    end
    return UI.text(s, size, style)
end

-- the ink (advance) width of a string at a role size: the same number as Python Canvas.text_width, so
-- chrome sized from it matches baked chrome. The OutlinedText box is this + 2 x pad (outline + 1 px).
function UI.text_width(str, size, style)
    local t = UI.text(str, size, style)
    if not t then return 0 end
    return t.width - 2 * (text_pad[t] or 0)
end

function UI.label_width(key, size, style, ...)
    local t = UI.text_key(key, size or 18, style, ...)
    if not t then return 0 end
    return t.width - 2 * (text_pad[t] or 0)
end

function UI.text_pad(t) return text_pad[t] or 0 end

-- draw an OutlinedText on whole px; y = vertical centre; align "l" | "c" | "r"; vis = alpha (snapped)
function UI.draw_text(t, x, y, align, vis)
    if not t or t.width == nil then return 0 end
    if UI.solid(vis) == 0 then return t.width end
    local px = x
    if align == "c" then px = x - t.width / 2 elseif align == "r" then px = x - t.width end
    t:draw({ x = math.floor(px + 0.5), y = math.floor(y - t.height / 2 + 0.5) })
    return t.width
end

-- ---------------------------------------------------------------- the hint pill (one style, one place)
-- UI.hint(items, opts): items = { { "ka", "h_select" }, { "don", "h_decide" }, { nil, "h_esc_back" } }
--   icon "don" (face lit) | "ka" (rim lit) | nil.
--   label = a string KEY (ss/strings.py: h_select h_decide h_back h_option h_change h_start h_esc_back, or
--   any other key): drawn as engine text, 18 px paper, in the player's language (UI.t). A label that is
--   not a key is drawn as written (raw string). The baked ss_ui/labels frames are the last fallback only.
--   Position (fix1029): bottom CENTRE. The bar is centred on opts.cx (default D.HINT.cx = 960, the screen
--   centre) with its bottom edge on opts.y1 (default D.HINT.y1 = 1020, the footer rule above the bottom
--   band). opts.x1 (legacy) anchors the right edge instead. opts.vis: alpha (snapped: no fades).
-- The bar sizes itself to the measured labels, so a longer translation widens it on both sides.
-- Returns x, y, w, h of the bar (shadow excluded), or nil when hidden.
local HD = D.HINT

-- label -> OutlinedText (nil = use the baked label frame); cached through UI.text
local function hint_text(lbl)
    local s = UI.t(lbl)
    if s then return UI.text(s, HD.size, "on_ink") end
    if D.LABEL[lbl] then return nil end
    return UI.text(lbl, HD.size, "on_ink")
end

local function hint_label_w(lbl)
    local t = hint_text(lbl)
    if t then return t.width end
    return D.LABEL[lbl].w
end

function UI.hint_width(items)
    local w = 2 * HD.pad
    for i, it in ipairs(items) do
        if i > 1 then w = w + HD.sep end
        if it[1] then w = w + HD.icon + HD.gap end
        w = w + hint_label_w(it[2])
    end
    return math.ceil(w / D.U) * D.U
end

-- double-draw guard: two pills at one anchor in one frame stack (the settings F1 bug). A second draw at
-- the same anchor within 2 ms (same frame: frames are >= 4 ms apart; the fixed-step test clock does not
-- move inside a frame) warns once per screen + anchor.
local hint_last = {}
local function hint_items_str(items)
    local s = {}
    for _, it in ipairs(items) do s[#s + 1] = (it[1] and (it[1] .. " ") or "") .. tostring(it[2]) end
    return table.concat(s, " / ")
end

function UI.hint(items, opts)
    opts = opts or {}
    if UI.solid(opts.vis) == 0 then return nil end
    local w = UI.hint_width(items)
    local y1 = opts.y1 or HD.y1
    local x1 = opts.x1 or ((opts.cx or HD.cx or 960) + w / 2)
    local anchor = (opts.x1 and ("x1=" .. opts.x1) or ("cx=" .. (opts.cx or HD.cx or 960))) .. "," .. y1
    local now = tex.get_current_ms and tex.get_current_ms() or 0
    local last = hint_last[anchor]
    if last and math.abs(now - last.ms) < 2 then
        local scr = tex.current_screen and tex.current_screen() or "?"
        local key = "hint2:" .. scr .. ":" .. anchor
        if not warned[key] then
            warn_once(key, "UI.hint drawn twice at (" .. anchor .. ") in one frame on " .. scr .. ": ["
                .. hint_items_str(last.items) .. "] then [" .. hint_items_str(items) .. "]; one pill per screen")
        end
    end
    if last then last.ms, last.items = now, items else hint_last[anchor] = { ms = now, items = items } end
    local x, y = UI.grid(x1 - w), UI.grid(y1 - HD.h)
    UI.frame(x, y, w, HD.h, { fill = D.P.hint_bg })
    local drum = T("ss_ui/hint_drum")
    local cx, cy = x + HD.pad, y + HD.h / 2
    for i, it in ipairs(items) do
        if i > 1 then cx = cx + HD.sep end
        if it[1] then
            if drum then
                tex.draw_texture(drum, { frame = (it[1] == "ka") and 1 or 0, x = UI.grid(cx),
                                         y = UI.grid(cy - HD.icon / 2) })
            end
            cx = cx + HD.icon + HD.gap
        end
        local t = hint_text(it[2])
        if t then
            cx = cx + UI.draw_text(t, cx, cy, "l")
        else
            cx = cx + UI.label(it[2], cx, cy, D.P.n_rim)
        end
    end
    return x, y, w, HD.h
end

-- ---------------------------------------------------------------- the speech bubble (chrome.bubble, dynamic)
-- UI.bubble(s, tip_x, tip_y, opts): a speech bubble sized to its MEASURED text, with the readable 3-step
-- tail (chrome.bubble_tail: 18U / 12U / 6U steps, 3U tall, 2U ink sides) whose tip is at (tip_x, tip_y):
-- the speaker's mouth row. s = a string key (UI.t) or a raw string. The box is a dialog without a title
-- (2U ink border, 2U hard shadow, 1U notch, paper), text 36 px ink centred.
--   opts.dir "down" (default: box above the tip) | "up" (box below the tip)
--   opts.cx   box centre x (default tip_x; clamped so the tail stays inside the box and the box on screen)
--   opts.size role size (36 default; 24 for small bubbles). A text wider than D.BUBBLE.max_w drops to 24.
--   opts.h    box height (default D.BUBBLE.h = 26U); opts.vis alpha (snapped); opts.args format args
-- Width = text + 2 x D.BUBBLE.pad + 4U, ceiled to U, at most D.BUBBLE.max_w (540) = chrome.bubble_width.
-- Returns x, y, w, h of the box (shadow and tail excluded).
local BB = D.BUBBLE
function UI.bubble_width(s, size)
    local str = UI.t(s) or tostring(s)
    local tw = UI.text_width(str, size or 36)
    return math.min(BB.max_w, math.ceil((tw + 2 * BB.pad + 4 * U) / U) * U)
end

-- the steps tail on the box edge `edge` (bottom edge, or the top edge when up), axis tx. off / col_only:
-- the shadow pass (outer shape only, shifted). Mirrors chrome.bubble_tail exactly.
local function bubble_tail(tx, edge, up, off, col_only)
    local function r(xa, ya, xb, yb, c)
        if up then ya, yb = 2 * edge - yb, 2 * edge - ya end
        UI.rect(xa + off, ya + off, xb - xa, yb - ya, c)
    end
    local top = edge + 2 * U
    local w0 = BB.tail[1]
    r(tx - w0 / 2, edge, tx + w0 / 2, top, D.P.ink)
    for i, w in ipairs(BB.tail) do
        local ya = top + (i - 1) * 3 * U
        r(tx - w / 2, ya, tx + w / 2, ya + 3 * U, D.P.ink)
    end
    if col_only then return end
    for i = 1, #BB.tail - 1 do
        local iw = BB.tail[i] - 4 * U
        local ya = (i == 1) and (edge - 2 * U) or (top + (i - 1) * 3 * U)
        r(tx - iw / 2, ya, tx + iw / 2, top + i * 3 * U, D.P.paper)
    end
end

function UI.bubble(s, tip_x, tip_y, opts)
    opts = opts or {}
    if UI.solid(opts.vis) == 0 then return nil end
    local str = UI.t(s, (table.unpack or unpack)(opts.args or {})) or tostring(s)
    local size = opts.size or 36
    local tw = UI.text_width(str, size)
    if size > 24 and tw + 2 * BB.pad + 4 * U > BB.max_w then
        size = 24
        tw = UI.text_width(str, size)
    end
    local w = math.min(BB.max_w, math.ceil((tw + 2 * BB.pad + 4 * U) / U) * U)
    local h = opts.h or BB.h
    local up = opts.dir == "up"
    local half = BB.tail[1] / 2 + 2 * U            -- the widest step stays inside the 2U border
    local tx = UI.grid(tip_x)
    local cx = opts.cx or tip_x
    cx = math.max(tx - w / 2 + half, math.min(tx + w / 2 - half, cx))
    local x = UI.grid(cx - w / 2)
    local sw = tex.get_screen_width and tex.get_screen_width() or 1920
    x = math.max(0, math.min(sw - w - 2 * U, x))
    tx = math.max(x + half, math.min(x + w - half, tx))
    local reach = BB.tail_h - 2 * U                 -- box edge -> tip (the 2U shadow is extra)
    local y = up and UI.grid(tip_y + reach) or UI.grid(tip_y - reach - h)
    local edge = up and y or (y + h)
    bubble_tail(tx, edge, up, 2 * U, true)          -- tail shadow
    UI.frame(x, y, w, h, { border = 2 * U, shadow = 2 * U, notch = U, fill = D.P.paper })
    bubble_tail(tx, edge, up, 0, false)
    UI.draw_text(UI.text(str, size, "ink"), x + w / 2, y + h / 2, "c")
    return x, y, w, h
end

-- ---------------------------------------------------------------- one course identity (ss/course.py)
-- course: engine index 0..4 or "easy" | "normal" | "hard" | "oni" | "ura". Baked in global/ss_course.
UI.course = {}
local CO = D.COURSE
local function course_i(c)
    if type(c) == "number" then return math.max(0, math.min(4, math.floor(c))) end
    for i, k in ipairs(CO.keys) do if k == c then return i - 1 end end
    return 0
end
UI.course.index = course_i
function UI.course.color(c) return D.P[CO.keys[course_i(c) + 1]] end
-- the course name in the player's language (ss/strings.py course0..4), else the build-language name
function UI.course.name(c)
    local i = course_i(c)
    return UI.t("course" .. i) or CO.names[i + 1]
end

-- glyph centred on (cx, cy); size "s" (30) | "l" (60); returns the size
function UI.course.glyph(c, cx, cy, size)
    size = size or "s"
    local t = T("ss_course/glyph_" .. size)
    local s = CO.glyph[size]
    if t then tex.draw_texture(t, { frame = course_i(c), x = UI.grid(cx - s / 2), y = UI.grid(cy - s / 2) }) end
    return s
end

-- the course chip (edge style, D.COURSE.chip.w x h) with its top-left at (x, y); returns w, h.
-- The baked chip is chrome only; the course name is engine text in the player's language (18 px ink).
-- A name wider than the chip widens it (drawn as UI.chrome.chip, same look) to text + 6U.
function UI.course.chip(c, x, y)
    local i = course_i(c)
    x, y = UI.grid(x), UI.grid(y)
    local name = UI.course.name(i)
    local tw = UI.text_width(name, 18)
    local w, h = CO.chip.w, CO.chip.h
    local ix, iy, iw, ih
    if tw + 6 * U > w - 3 * U then
        w = math.ceil((tw + 9 * U) / U) * U
        ix, iy, iw, ih = UI.chrome.chip(x, y, w, h, UI.course.color(i), true)
    else
        local t = T("ss_course/chip")
        if t then tex.draw_texture(t, { frame = i, x = x, y = y }) end
        ix, iy, iw, ih = x + 2 * U, y + U, w - 3 * U, h - 2 * U    -- inner rect right of the 1U course edge
    end
    UI.draw_text(UI.text(name, 18), ix + iw / 2, iy + ih / 2, "c")
    return w, h
end

-- the 全良 chip (gold, 1U ink border, 18 px ink text; at least D.COURSE.zenryo.w wide, wider for a longer
-- translation) with its top-left at (x, y); draw it next to / under a "dfc" crown where there is room.
-- Returns w, h
function UI.course.zenryo(x, y)
    x, y = UI.grid(x), UI.grid(y)
    local t = UI.text_key("zenryo", 18)
    local tw = UI.label_width("zenryo", 18)
    local w, h = math.max(CO.zenryo.w, math.ceil((tw + 6 * U) / U) * U), CO.zenryo.h
    local ix, iy, iw, ih = UI.chrome.chip(x, y, w, h, D.P.focus, false)
    UI.draw_text(t, ix + iw / 2, iy + ih / 2, "c")
    return w, h
end

-- crown centred on (cx, cy): kind "none" | "clear" (course colour) | "fc" (gold, paper jewels) | "dfc"
-- (all-good / 全良: gold, ink jewels; add UI.course.zenryo), or 0..3; size "s" (33 x 21) | "m" (66 x 42).
-- "none" draws nothing. No rainbow on a crown (bible 2.3: gauge + 極 ring only).
local CROWN_KINDS = { [0] = "none", [1] = "clear", [2] = "fc", [3] = "dfc" }
function UI.course.crown(kind, c, cx, cy, size)
    if type(kind) == "number" then kind = CROWN_KINDS[kind] end
    if kind == nil or kind == "none" then return end
    size = size or "s"
    local f = CO.crown_frame[kind]
    if f == nil then return end
    if kind == "clear" then f = f + course_i(c) end
    local t = T("ss_course/crown_" .. size)
    local d = CO.crown[size]
    if t then tex.draw_texture(t, { frame = f, x = UI.grid(cx - d.w / 2), y = UI.grid(cy - d.h / 2) }) end
end

-- score-rank badge, tier 0..6 = iki iki iki / miyabi x3 / kiwami (Nijiiro's score_rank frames),
-- centred on (cx, cy); size "s" (75: HUD, song select) | "l" (135: result)
function UI.course.rank(tier, cx, cy, size)
    if tier == nil or tier < 0 then return end
    size = size or "s"
    local t = T("ss_course/rank_" .. size)
    local s = CO.rank[size]
    if t then tex.draw_texture(t, { frame = math.min(6, tier), x = UI.grid(cx - s / 2), y = UI.grid(cy - s / 2) }) end
end

-- ---------------------------------------------------------------- the mascot
-- Momo (main / 1P) or Hoshi (buddy / 2P), pixel sprites at a baked scale k (logical px per sprite px:
-- D.MASCOT.k.tiny = 3, menu / portrait = 6, scene = 9). Drawn at scale 1 on whole pixels, never
-- squashed; motion = whole-sprite-px hops and frame swaps (bible 2.6 / 2.7).
local Mascot = {}
Mascot.__index = Mascot
UI.Mascot = Mascot

local MM = D.MASCOT
local live = setmetatable({}, { __mode = "k" })   -- every mascot, so two never blink together

-- schedule the next blink 3000-4200 ms out, at least 400 ms away from every other mascot's
local function schedule_blink(self, from)
    local t = from + 3000 + self:rand(1200)
    for _ = 1, 4 do
        local clash = false
        for o in pairs(live) do
            if o ~= self and math.abs(o.next_blink - t) < 400 then clash = true end
        end
        if not clash then break end
        t = t + 400
    end
    self.next_blink = t
end

-- resolve a role name ("tiny" | "menu" | "portrait" | "scene") or a raw k to a logical k.
-- A raw k still works but warns once per value: pick the role, the role decides the k.
local function k_of(role, k, where)
    if role ~= nil then
        local v = UI.K[role]
        if v then return v end
        warn_once("role" .. tostring(role), where .. ": unknown mascot role '" .. tostring(role) ..
            "' (tiny | menu | portrait | scene); using menu")
        return UI.K.menu
    end
    if k ~= nil then
        if type(k) == "string" and UI.K[k] then return UI.K[k] end
        warn_once("k" .. tostring(k), where .. ": raw k=" .. tostring(k) ..
            "; pass role = tiny | menu | portrait | scene instead")
        return k
    end
    return nil
end
UI.mascot_k = function(role) return k_of(role, nil, "UI.mascot_k") end

-- opts.role "tiny" | "menu" | "portrait" | "scene" (UI.K; default "menu"). opts.k (raw, deprecated: warns once)
-- opts.char "momo" | "hoshi" (default the main character; opts.buddy = true -> the buddy)
-- opts.beat = false: no beat hop (menus); opts.seed: blink randomness
function Mascot.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Mascot)
    self.char = opts.char or (opts.buddy and MM.buddy) or MM.main
    -- Z-DON 2D outfits: opts.outfit = an outfit number (UI.outfit_decode: the character and its outfit);
    -- unset, a "momo" mascot is the player's seat and a "hoshi" mascot the other seat, each showing that
    -- seat's pick (tex.outfit), read at every draw (see seat_pick)
    self.outfit = opts.outfit
    self.auto_outfit = opts.outfit == nil and (self.char == "momo" or self.char == "hoshi")
    self.role = opts.role
    self.k = k_of(opts.role, opts.k, "Mascot.new") or UI.K.menu
    self.beat_on = opts.beat ~= false
    self.ms = 0
    self.bpm = 120
    self.beat0 = 0
    self.mood = nil          -- persistent: "sad" | "gogo" | "clear" | "sit_fail"
    self.flash_expr, self.flash_until = nil, -1
    self.hop_until = -1
    self.facing = 0          -- 0 front, 1 right (turn frame), -1 left (turn frame mirrored)
    self.drum_side = 0
    -- per-character LCG so two characters never blink together
    self.rng = opts.seed or (self.char == "hoshi" and 7919 or 104729)
    self.next_blink = 0
    schedule_blink(self, -1500)
    live[self] = true
    return self
end

-- outfit number (skin_config zdon_outfits) -> character, outfit: 0..n-1 Momo, n..2n-1 Hoshi (n = plain + outfits)
function UI.outfit_decode(o)
    local n = 1 + #(MM.outfits or {})
    o = o or 0
    if o >= n then return "hoshi", o - n end
    return "momo", o
end

local function other(char) return (char == "hoshi") and "momo" or "hoshi" end

-- what a seat shows: the player's seat wears the player's pick; the other seat wears 2P's pick when two
-- play, else the other character, plain (two players on the same character: both show it)
local function seat_pick(seat)
    if not tex.outfit then return seat, 0 end
    local pn = tex.player_num and tex.player_num() or 1
    -- two players: player_num TWO_PLAYER, or a *_2P screen (GAME_2P etc. keep player_num at one seat);
    -- an AI battle's 2P is the robot, so the other seat stays the buddy
    local scr = tex.current_screen and tex.current_screen() or ""
    local ai = tex.ai_active and tex.ai_active()
    local two = (pn == 3 or scr:sub(-3) == "_2P") and not ai
    local main = (pn == 2 and not two) and 2 or 1
    if seat == "momo" then return UI.outfit_decode(tex.outfit(main)) end
    if two then return UI.outfit_decode(tex.outfit(2)) end
    return other((UI.outfit_decode(tex.outfit(main)))), 0
end

-- the character and outfit this mascot shows now
function Mascot:look()
    if self.outfit ~= nil then return UI.outfit_decode(self.outfit) end
    if self.auto_outfit then return seat_pick(self.char) end
    return self.char, 0
end

-- the atlas entry for this mascot now (<char> or <char>_<outfit id>) and its character
function Mascot:tex_name()
    local char, o = self:look()
    local id = o > 0 and MM.outfits and MM.outfits[o]
    return id and (char .. "_" .. id) or char, char
end

function Mascot:rand(n)
    self.rng = (self.rng * 1103515245 + 12345) % 2147483648
    return self.rng % (n + 1)
end

-- ms: screen time; bpm, beat0_ms (time of a downbeat) only matter for the beat hop
function Mascot:update(ms, bpm, beat0_ms)
    self.ms = ms
    if bpm and bpm > 0 then self.bpm = bpm end
    if beat0_ms then self.beat0 = beat0_ms end
    if ms >= self.next_blink + 120 then schedule_blink(self, ms) end
end

function Mascot:flash(expr, dur)
    self.flash_expr = expr
    self.flash_until = self.ms + (dur or 250)
end

function Mascot:set_mood(m) self.mood = m end
function Mascot:face(dir) self.facing = dir or 0 end
function Mascot:hop() self.hop_until = self.ms + 100 end

-- bible 2.6 reaction table + menu verbs:
--   "hit" | "don" | "ka"  drum_l / drum_r alternate (100 ms)    "combo"  cheer (600 ms)
--   "miss"  sad (800 ms; call on a miss streak)                  "gogo" / "gogo_end"  GOGO mood on / off
--   "clear"  clear (stays; draw UI.burst next to it)             "fail"  sit_fail (stays)
--   "move"  1-sprite-px hop (cursor move)    "decide"  cheer (500 ms)    "turn", dir  face -1 / 0 / 1
--   "reset"  back to idle, facing front
function Mascot:react(name, arg)
    if name == "hit" or name == "don" or name == "ka" then
        self.drum_side = 1 - self.drum_side
        self:flash(self.drum_side == 1 and "drum_l" or "drum_r", 100)
    elseif name == "combo" then self:flash("cheer", 600)
    elseif name == "miss" then self:flash("sad", 800)
    elseif name == "gogo" then self.mood = "gogo"
    elseif name == "gogo_end" then if self.mood == "gogo" then self.mood = nil end
    elseif name == "clear" then self.mood = "clear"
    elseif name == "fail" then self.mood = "sit_fail"
    elseif name == "move" then self:hop()
    elseif name == "decide" then self:flash("cheer", 500); self:hop()
    elseif name == "turn" then self.facing = arg or 0
    elseif name == "reset" then self.mood, self.facing, self.flash_until = nil, 0, -1
    end
end

-- the frame to show now and whether it is mirrored
function Mascot:current_expr()
    local m = self.mood
    if m == "clear" or m == "sit_fail" then return m end
    if self.flash_expr and self.ms < self.flash_until then return self.flash_expr end
    if m then return m end
    if self.facing ~= 0 then return "turn" end
    local b = self.ms - self.next_blink
    if b >= 0 and b < 60 then return "blink_half" end
    if b >= 60 and b < 120 then return "blink" end
    if math.floor(self.ms / 500) % 2 == 1 then return "idle1" end
    return "idle"
end

-- hop height in sprite px: 1 for 100 ms on each beat (2 on the downbeat during GOGO), 1 after react("move")
function Mascot:hop_px(expr)
    if UI.COMFORT then return 0 end -- comfort: the characters stay on the ground
    if self.ms < self.hop_until then return 1 end
    if not self.beat_on or expr == "sit_fail" or expr == "sad" then return 0 end
    local beat_ms = 60000 / self.bpm
    local t = self.ms - self.beat0
    if t < 0 then return 0 end
    local n = math.floor(t / beat_ms)
    if t - n * beat_ms >= 100 then return 0 end
    if self.mood == "gogo" and n % 4 == 0 then return 2 end
    return 1
end

-- cx: centre x, foot: the ground line y. opts.expr (force a frame), opts.role (or the deprecated opts.k),
-- opts.fade (snapped by UI.solid: drawn fully or not at all), opts.still (no hop), opts.mirror (true = face
-- the other way)
function Mascot:draw(cx, foot, opts)
    opts = opts or {}
    if UI.solid(opts.fade) == 0 then return end
    local k = k_of(opts.role, opts.k, "Mascot:draw") or self.k
    local kb, scale = k, 1
    local name, char = self:tex_name()
    local baked = false
    for _, b in ipairs(MM.k_baked) do if b == k then baked = true end end
    if not baked then
        -- not baked: the largest baked scale that divides k (drawn scaled; avoid, it filters)
        kb = MM.k_baked[1]
        for _, b in ipairs(MM.k_baked) do if k % b == 0 then kb = b end end
        scale = k / kb
    end
    local t = TM(kb, name) or TM(kb, char)
    if not t then return end
    local expr = opts.expr or self:current_expr()
    local frame = MM.expr[expr] or 0
    local hop = opts.still and 0 or self:hop_px(expr)
    local S = MM.cells * k
    local x0 = math.floor(cx - S / 2)
    local y0 = math.floor(foot - MM.foot[char] * k) - hop * k
    local mirror = opts.mirror
    if self.facing < 0 and expr == "turn" then mirror = not mirror end
    tex.draw_texture(t, { frame = frame, x = x0, y = y0, scale = scale,
        mirror = mirror and "horizontal" or nil })
end

return UI
