NameEntry = {}
NameEntry.__index = NameEntry

local MAX_LEN = 5
local PANEL_W = 640
local RING_Y = 403
local RADII = { 140, 104, 60 }
local ROT_MS = 83     -- one step of ring rotation
local OPEN_MS = 150   -- ring fade/scale in
local DIM = 0.35      -- outer rings while an inner one is active
local PLATE_Y, PLATE_STEP, PLATE_SCALE = 168, 80, 0.8

local SLIDE_FROM, SLIDE_START, SLIDE_MS = 551, 33, 317
local BODY_START, BODY_FADE_MS = 2667, 300
-- box size includes the 16 px transparent margin of the frame slices (visible panel 528 x 154 at y 218)
local CONFIRM_Y, CONFIRM_W, CONFIRM_H = 202, 560, 186
local BUTTON_DX, BUTTON_Y = 128, 315
local BOX_KEYS = { "box_top_left", "box_top_right", "box_bottom_left", "box_bottom_right",
                   "box_top", "box_bottom", "box_left", "box_right", "box_center" }
local BANNER_CY = 65   -- vertical centre of the pill inside the 128px banner texture

local GLYPH_SIZE, LABEL_SIZE = 34, 20   -- kana / word-label font sizes on a 64 px plate

local function chars(s)
    local out = {}
    for c in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do out[#out + 1] = c end
    return out
end


-- kana for Japanese, Latin letters for every other language (picked per entry, so a language change applies)
local ROWS = {
    ja = {
        "あいうえお", "かきくけこ", "さしすせそ", "たちつてと", "なにぬねの",
        "はひふへほ", "まみむめも", "やゆよ", "らりるれろ", "わゐゑをんゎ", "～ー？！",
    },
    latin = { "ABCDE", "FGHIJ", "KLMNO", "PQRST", "UVWXY", "Z-.!?", "01234", "56789" },
}
-- base char followed by its other forms
local VARIANTS = {}
local groups = {
    "あぁ", "いぃ", "うぅ", "えぇ", "おぉ",
    "かが", "きぎ", "くぐ", "けげ", "こご",
    "さざ", "しじ", "すず", "せぜ", "そぞ",
    "ただ", "ちぢ", "つづっ", "てで", "とど",
    "はばぱ", "ひびぴ", "ふぶぷ", "へべぺ", "ほぼぽ",
    "やゃ", "ゆゅ", "よょ", "わゎ",
}
for c in ("ABCDEFGHIJKLMNOPQRSTUVWXYZ"):gmatch(".") do groups[#groups + 1] = c .. c:lower() end
for _, group in ipairs(groups) do
    local list = chars(group)
    VARIANTS[list[1]] = list
end

local function clamp01(v) return math.max(0.0, math.min(1.0, v)) end

function NameEntry.new(is_2p)
    local self = setmetatable({}, NameEntry)
    self.is_2p = is_2p
    self.cx = is_2p and (PANEL_W + PANEL_W / 2) or (PANEL_W / 2)

    self.glyph_cache  = {}
    self.plate_red    = tex.get_texture("entry/name_entry/plate_red")
    self.plate_yellow = tex.get_texture("entry/name_entry/plate_yellow")
    self.big_red      = tex.get_texture("entry/name_entry/big_red")
    self.big_yellow   = tex.get_texture("entry/name_entry/big_yellow")
    self.mode_title   = tex.get_texture("entry/global/name_entry")
    self.btn_red      = tex.get_texture("entry/name_entry/button_red")
    self.btn_yellow   = tex.get_texture("entry/name_entry/button_yellow")
    self.btn_outline  = tex.get_texture("entry/name_entry/button_outline")
    self.arrow        = tex.get_texture("entry/name_entry/arrow")
    self.box = {}
    local suffix = is_2p and "_2p" or "_1p"
    for _, key in ipairs(BOX_KEYS) do self.box[key] = tex.get_texture("entry/costume_select/" .. key .. suffix) end
    self.suffix = suffix
    local function label(key, size)
        return text.create_raw_text(tex.skin_text(key), size, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 5, 2.0)
    end
    self.confirm_text, self.yes_text, self.no_text = label("entry_name_confirm", 32), label("entry_name_yes", 36), label("entry_name_no", 36)
    self.banner       = tex.get_texture("entry/name_entry/banner_" .. (is_2p and "2p" or "1p"))
    self.title        = text.create_raw_text(tex.skin_text("entry_name_title"), 36, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 5, 2.0)

    self.rows = {}
    for _, row in ipairs(ROWS[tex.language() == "ja" and "ja" or "latin"]) do
        local list = chars(row)
        self.rows[#self.rows + 1] = { str = list[1], chars = list }
    end
    self.rows[#self.rows + 1] = { str = tex.skin_text("entry_name_back"), label = true, action = "del" }
    self.rows[#self.rows + 1] = { str = tex.skin_text("entry_name_done"), label = true, action = "done" }

    self.name  = {}
    self.done  = false
    self.t0    = tex.get_current_ms()
    self.stage = 1
    self.sel   = { 1, 1, 1 }   -- selected slot per ring
    self.body_fade = 0
    self.confirm = nil   -- { sel = 1 yes / 2 no, t0 } while asking
    self.rot, self.rot_t0 = 0, 0
    self.open_t0 = { self.t0, 0, 0 }
    return self
end

function NameEntry:update(current_ms) end

function NameEntry:is_done() return self.done end
function NameEntry:get_name() return table.concat(self.name) end

-- items of a ring; ring 2 and 3 follow the selection of the ring outside them (nil: none)
function NameEntry:ring(stage)
    if stage == 1 then return self.rows end
    local src
    if stage == 2 then
        src = self.rows[self.sel[1]].chars
    else
        local outer = self:ring(2)
        local item = outer and outer[self.sel[2]]
        src = item and item.char and VARIANTS[item.char]
        if src and #src < 2 then src = nil end
    end
    if not src then return nil end
    local list = {}
    for _, c in ipairs(src) do list[#list + 1] = { str = c, char = c } end
    list[#list + 1] = { str = tex.skin_text("entry_name_back"), label = true, back = true }
    return list
end

function NameEntry:enter(stage)
    self.stage = stage
    self.sel[stage] = 1
    self.rot = 0
    self.open_t0[stage] = tex.get_current_ms()
end

function NameEntry:commit(c)
    if #self.name < MAX_LEN then self.name[#self.name + 1] = c end
    self.stage = 1
    self.rot = 0
end

function NameEntry:input(action)
    if tex.get_current_ms() - self.t0 < BODY_START then return end
    if self.confirm then
        if action == 1 then self.confirm.sel = 1
        elseif action == 2 then self.confirm.sel = 2
        elseif action == 3 then
            if self.confirm.sel == 1 then self.done = true else self.confirm = nil end
        end
        return
    end
    local items = self:ring(self.stage)
    local n = #items
    if action == 1 or action == 2 then
        local dir = action == 1 and -1 or 1
        self.sel[self.stage] = (self.sel[self.stage] - 1 + dir) % n + 1
        for s = self.stage + 1, 3 do self.sel[s] = 1 end
        self.rot, self.rot_t0 = dir, tex.get_current_ms()   -- slots start one step off, glide in
        return
    end
    if action ~= 3 then return end

    local item = items[self.sel[self.stage]]
    if self.stage == 1 then
        if item.action == "done" then
            if #self.name == 0 then self.done = true else self.confirm = { sel = 1, t0 = tex.get_current_ms() } end
        elseif item.action == "del" then
            if #self.name == 0 then self.done = true else self.name[#self.name] = nil end
        else
            self:enter(2)
        end
    elseif item.back then
        self.stage = self.stage - 1
        self.rot = 0
    elseif self.stage == 2 and self:ring(3) then
        self:enter(3)
    else
        self:commit(item.char)
    end
end

-- texture centred on (cx, cy); the engine positions by top-left and `center` only scales about the middle
local function put(texture, size, cx, cy, o, h)
    o.x, o.y, o.center = cx - size / 2, cy - (h or size) / 2, true
    tex.draw_texture(texture, o)
end

-- kana or word label drawn as text, centred on (cx, cy); texts are cached per string and size
function NameEntry:put_glyph(str, label, cx, cy, scale, fade)
    local size = math.floor((label and LABEL_SIZE or GLYPH_SIZE) * scale + 0.5)
    local key = str .. size
    local t = self.glyph_cache[key]
    if not t then
        t = text.create_raw_text(str, size, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 4, 0)
        self.glyph_cache[key] = t
    end
    t:draw({ x = cx - t.width / 2, y = cy - t.height / 2, fade = fade })
end

function NameEntry:draw_ring(stage, now)
    local items = self:ring(stage)
    if not items then return end
    local n = #items
    local radius = RADII[stage]
    local sel = self.sel[stage]
    local active = stage == self.stage

    -- inactive rings (outer ones and the preview of the next) stay dimmed; a ring brightens when entered
    local alpha = DIM
    if active then alpha = DIM + (1.0 - DIM) * (stage == 1 and 1 or clamp01((now - self.open_t0[stage]) / OPEN_MS)) end
    local rot = 0
    if active then rot = self.rot * (1 - clamp01((now - self.rot_t0) / ROT_MS)) end

    alpha = alpha * self.body_fade
    for i = 1, n do
        local ang = math.rad(-90 + (i - sel + rot) * 360 / n)
        local x = self.cx + math.cos(ang) * radius
        local y = RING_Y + math.sin(ang) * radius
        local top = i == sel
        local s = (top and 1.15 or 1.0) * (stage == 3 and 0.85 or 1.0)
        put(top and self.plate_yellow or self.plate_red, 64, x, y, { scale = s, fade = alpha })
        self:put_glyph(items[i].str, items[i].label, x, y, s, alpha)
    end
end

-- one piece of the frame, stretched from its texture.json size to w x h (nil = unchanged)
local function box_piece(texture, name, x, y, w, h)
    local info = tex.get_texture_info("costume_select", name)
    local base_w = (info.x2 and info.x2[1]) or info.width
    local base_h = (info.y2 and info.y2[1]) or info.height
    tex.draw_texture(texture, { x = x - info.x[1], y = y - info.y[1], x2 = w and (w - base_w) or 0, y2 = h and (h - base_h) or 0 })
end

function NameEntry:draw_confirm(now)
    local c = self.confirm
    local f = clamp01((now - c.t0) / OPEN_MS)
    tex.draw_rect(0, 0, tex.get_screen_width(), tex.get_screen_height(), 0, 0, 0, math.floor(100 * f))

    local x, y = self.cx - CONFIRM_W / 2, CONFIRM_Y
    local far_x, far_y = x + CONFIRM_W - 64, y + CONFIRM_H - 64
    local cw, ch = CONFIRM_W - 128, CONFIRM_H - 128
    local b, sfx = self.box, self.suffix
    -- the frame pieces take no fade, so the panel pops in under the dim
    box_piece(b.box_top_left,     "box_top_left"     .. sfx, x,      y)
    box_piece(b.box_top_right,    "box_top_right"    .. sfx, far_x,  y)
    box_piece(b.box_bottom_left,  "box_bottom_left"  .. sfx, x,      far_y)
    box_piece(b.box_bottom_right, "box_bottom_right" .. sfx, far_x,  far_y)
    box_piece(b.box_top,          "box_top"          .. sfx, x + 64, y,     cw)
    box_piece(b.box_bottom,       "box_bottom"       .. sfx, x + 64, far_y, cw)
    box_piece(b.box_left,         "box_left"         .. sfx, x,      y + 64, nil, ch)
    box_piece(b.box_right,        "box_right"        .. sfx, far_x,  y + 64, nil, ch)
    box_piece(b.box_center,       "box_center"       .. sfx, x + 64, y + 64, cw, ch)

    self.confirm_text:draw({ x = self.cx - self.confirm_text.width / 2, y = y + 56 - self.confirm_text.height / 2 })

    -- the selected button is yellow with an outline; the other one stays red
    local sel = c.sel
    for i = 1, 2 do
        local bx = self.cx + (i == 1 and -BUTTON_DX or BUTTON_DX)
        local on = i == sel
        put(on and self.btn_yellow or self.btn_red, 256, bx, BUTTON_Y, {}, 80)
        if on then put(self.btn_outline, 256, bx, BUTTON_Y, {}, 80) end
        local label = i == 1 and self.yes_text or self.no_text
        label:draw({ x = bx - label.width / 2, y = BUTTON_Y - label.height / 2 })
    end

    -- arrow just off the centre drifts toward the unselected button (Lumen sprites 36 / 88, 1000 ms loop)
    local ph = ((now - c.t0) % 1000) / 1000
    local a = ph < 0.5 and 1.0 or (0.965 * (1 - (ph - 0.5) * 2))
    local ax = self.cx + (sel == 1 and (8 + 10 * ph) or -(13 + 10 * ph))
    put(self.arrow, 48, ax, BUTTON_Y, { fade = a, mirror = sel == 1 and "horizontal" or nil })
end

function NameEntry:draw()
    local now = tex.get_current_ms()
    local el = now - self.t0
    local t = clamp01(el / OPEN_MS)
    local bf = clamp01((el - BODY_START) / BODY_FADE_MS)
    self.body_fade = bf

    tex.draw_rect(0, 0, tex.get_screen_width(), tex.get_screen_height(), 0, 0, 0, math.floor(120 * t))

    -- "Name Entry" mode title, top left (Lumen ModeTitle 962): slides in over 300 ms while fading in
    local mt = clamp01(el / 300)
    tex.draw_texture(self.mode_title, { x = -90 * (1 - mt), fade = clamp01(el / 250) })

    -- the pill sits behind the name plates; its title text is what fades out
    local slide = clamp01((el - SLIDE_START) / SLIDE_MS)
    local dx = (self.is_2p and 1 or -1) * SLIDE_FROM * (1 - slide)
    tex.draw_texture(self.banner, { x = self.cx - 256 + dx, y = PLATE_Y - BANNER_CY })
    if bf < 1 then
        self.title:draw({ x = self.cx - self.title.width / 2 + dx, y = PLATE_Y - self.title.height / 2, fade = 1 - bf })
    end
    if bf <= 0 then return end

    for i = 1, MAX_LEN do
        local x = self.cx + (i - 3) * PLATE_STEP
        local c = self.name[i]
        put(c and self.big_yellow or self.big_red, 96, x, PLATE_Y, { scale = PLATE_SCALE, fade = bf })
        if c then self:put_glyph(c, false, x, PLATE_Y, PLATE_SCALE * 1.25, bf) end
    end

    -- inactive rings first so the active one is drawn over them
    for stage = 1, math.min(self.stage + 1, 3) do
        if stage ~= self.stage then self:draw_ring(stage, now) end
    end
    self:draw_ring(self.stage, now)

    local cur = self:ring(self.stage)[self.sel[self.stage]]
    put(self.plate_yellow, 64, self.cx, RING_Y, { fade = bf })
    self:put_glyph(cur.str, cur.label, self.cx, RING_Y, 1, bf)

    if self.confirm then self:draw_confirm(now) end
end
