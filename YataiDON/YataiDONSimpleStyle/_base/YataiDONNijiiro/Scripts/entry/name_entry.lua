-- Nijiiro name entry (entry/name_entry.nulm). Same flow as PyTaikoGreen's: three kana rings,
-- five name plates and a yes/no check, laid out per player panel (root 523: 1P x 498, 2P x 1422).
NameEntry = {}
NameEntry.__index = NameEntry

local MAX_LEN = 5
local PANEL_CX = { [false] = 498, [true] = 1422 }
local PLATE_Y, PLATE_STEP = 320, 120           -- sprite 196: plates at -240..240, y -210 from 521 (530)
local RING_Y = 651                             -- rings / centre plate at y 121 from 521
local RADII = { 210, 156, 90 }
local SLOT, BIG = 96, 128
local TITLE_Y = 205                            -- c520 box (cx-398, 142) 800 x 126
local ROT_MS = 83                              -- 480 left/right: 5 frames
local RING_MS = 150                            -- 521 ring zoom: 1.5 <-> 1 over 9 frames
local PREVIEW_A = 0.55                         -- next inner ring (449 children)
local PULSE_MS = 1000                          -- 477 yellow slot / 486 arrows loop
local FLASH_MS = 667                           -- 483 / 191 white ring fade
local BODY_IN, BODY_MS = 83, 167               -- 522 fade_in f5-15
local INPUT_MS = 250
local DIALOG_Y = 587                           -- 519 at y 57 from 521
local DIALOG_IN, DIALOG_MS = 100, 317          -- 519 f6-25
local BUTTON_DX, BUTTON_DY = 155, 16
local DECIDE_MS = 517                          -- 516 blink f61-91

local GLYPH_SIZE, LABEL_SIZE, GLYPH_OUTLINE = 54, 30, 6

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
    self.cx = PANEL_CX[is_2p == true]

    local function t(name) return tex.get_texture("entry/name_entry/" .. name) end
    local color = is_2p and "teal" or "red"
    self.slot        = t("plate_" .. color)
    self.slot_yellow = t("plate_yellow")
    self.slot_flash  = t("slot_flash")
    self.big         = t("big_" .. color)
    self.big_yellow  = t("big_yellow")
    self.big_flash   = t("big_flash")
    self.arrow       = t("arrow")
    self.mode_title  = t("mode_title")
    self.panel       = t("panel_" .. color)
    self.btn_base    = t("button_brown")
    self.btn_fill    = is_2p and t("button_brown") or t("button_orange")
    self.btn_glow    = t("button_glow")
    self.btn_outline = t("button_outline")
    self.btn_flash   = t("button_flash")

    local function label(key, size, outline)
        local s = tex.skin_text(key)
        if s == "" then return nil end
        return text.create_raw_text(s, size, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, outline, 0)
    end
    self.title        = label("entry_name_title", 54, 6)
    self.confirm_text = label("entry_name_confirm", 40, 5)
    self.hint_text    = label("entry_name_hint", 24, 3)
    self.yes_text     = label("entry_name_yes", 32, 0)
    self.no_text      = label("entry_name_no", 32, 0)

    self.glyph_cache = {}
    self.rows = {}
    for _, row in ipairs(ROWS[tex.language() == "ja" and "ja" or "latin"]) do
        local list = chars(row)
        self.rows[#self.rows + 1] = { str = list[1], chars = list }
    end
    self.rows[#self.rows + 1] = { str = tex.skin_text("entry_name_back"), label = true, action = "del" }
    self.rows[#self.rows + 1] = { str = tex.skin_text("entry_name_done"), label = true, action = "done" }

    self.name     = {}
    self.done     = false
    self.t0       = tex.get_current_ms()
    self.stage    = 1
    self.sel      = { 1, 1, 1 }
    self.rot, self.rot_t0 = 0, 0
    self.enter_t0 = { self.t0 + BODY_IN, 0, 0 }   -- ring zooms in (1.5 -> 1) when it becomes active
    self.leave_t0 = { 0, 0, 0 }                   -- ring zooms out (1 -> 1.5) when an inner one takes over
    self.flash_t0 = self.t0 + BODY_IN             -- white ring over the top slot
    self.plate_t0 = {}                            -- white ring over a plate when its char is set
    self.confirm  = nil                           -- { sel = 1 yes / 2 no, t0, decide_t0 }
    return self
end

function NameEntry:update(current_ms)
    local c = self.confirm
    if c and c.decide_t0 and current_ms - c.decide_t0 >= DECIDE_MS then self.done = true end
end

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
    for _, ch in ipairs(src) do list[#list + 1] = { str = ch, char = ch } end
    list[#list + 1] = { str = tex.skin_text("entry_name_back"), label = true, back = true }
    return list
end

function NameEntry:set_stage(stage)
    local now = tex.get_current_ms()
    if stage > self.stage then
        self.leave_t0[self.stage] = now
        self.sel[stage] = 1
    end
    self.stage = stage
    self.enter_t0[stage] = now
    self.rot = 0
    self.flash_t0 = now
end

function NameEntry:commit(ch)
    if #self.name < MAX_LEN then
        self.name[#self.name + 1] = ch
        self.plate_t0[#self.name] = tex.get_current_ms()
    end
    self:set_stage(1)
end

function NameEntry:input(action)
    local now = tex.get_current_ms()
    if now - self.t0 < INPUT_MS then return end
    local c = self.confirm
    if c then
        if c.decide_t0 then return end
        if action == 1 then c.sel = 1
        elseif action == 2 then c.sel = 2
        elseif action == 3 then
            if c.sel == 1 then c.decide_t0 = now else self.confirm = nil end
        end
        return
    end
    local items = self:ring(self.stage)
    local n = #items
    if action == 1 or action == 2 then
        local dir = action == 1 and -1 or 1
        self.sel[self.stage] = (self.sel[self.stage] - 1 + dir) % n + 1
        for s = self.stage + 1, 3 do self.sel[s] = 1 end
        self.rot, self.rot_t0 = dir, now   -- slots start one step off, glide in
        self.flash_t0 = now
        return
    end
    if action ~= 3 then return end

    local item = items[self.sel[self.stage]]
    if self.stage == 1 then
        if item.action == "done" then
            if #self.name == 0 then self.done = true else self.confirm = { sel = 1, t0 = now } end
        elseif item.action == "del" then
            if #self.name == 0 then self.done = true else self.name[#self.name] = nil end
        else
            self:set_stage(2)
        end
    elseif item.back then
        self:set_stage(self.stage - 1)
    elseif self.stage == 2 and self:ring(3) then
        self:set_stage(3)
    else
        self:commit(item.char)
    end
end

-- texture centred on (cx, cy) at `scale`; size = its unscaled width (height = h or size)
local function put(texture, size, cx, cy, o, h)
    o.x, o.y, o.center = cx - size / 2, cy - (h or size) / 2, true
    tex.draw_texture(texture, o)
end

-- kana or word label drawn as text, centred on (cx, cy); cached per string and size
function NameEntry:put_glyph(str, label, cx, cy, scale, fade)
    scale = math.floor(scale * 10 + 0.5) / 10 -- ring zooms would otherwise make a new text every frame
    local size = math.floor((label and LABEL_SIZE or GLYPH_SIZE) * scale + 0.5)
    local key = str .. "\0" .. size
    local t = self.glyph_cache[key]
    if not t then
        t = text.create_raw_text(str, size, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, GLYPH_OUTLINE, 0)
        self.glyph_cache[key] = t
    end
    t:draw({ x = cx - t.width / 2, y = cy - t.height / 2, fade = fade })
end

-- scale and alpha of a ring now (nil: hidden)
function NameEntry:ring_state(stage, now)
    if stage == self.stage then
        local e = clamp01((now - self.enter_t0[stage]) / RING_MS)
        return 1.5 - 0.5 * e, e
    elseif stage == self.stage + 1 then
        return 1.0, PREVIEW_A * clamp01((now - self.enter_t0[self.stage]) / RING_MS)
    elseif stage < self.stage then
        local k = clamp01((now - self.leave_t0[stage]) / RING_MS)
        if k >= 1 then return nil end
        return 1.0 + 0.5 * k, 1 - k
    end
    return nil
end

function NameEntry:draw_ring(stage, now)
    local items = self:ring(stage)
    if not items then return end
    local scale, alpha = self:ring_state(stage, now)
    if not scale or alpha <= 0.002 then return end
    local n = #items
    local radius = RADII[stage] * scale
    local sel = self.sel[stage]
    local active = stage == self.stage
    local rot = active and self.rot * (1 - clamp01((now - self.rot_t0) / ROT_MS)) or 0

    for i = 1, n do
        local ang = math.rad(-90 + (i - sel + rot) * 360 / n)
        local x = self.cx + math.cos(ang) * radius
        local y = RING_Y + math.sin(ang) * radius
        put(self.slot, SLOT, x, y, { scale = scale, fade = alpha })
        if active and i == sel then
            -- 477: yellow over the player colour, 1 -> 0 -> 1 every second
            local ph = ((now - self.t0) % PULSE_MS) / PULSE_MS
            local p = ph < 0.5 and (1 - ph * 2) or ((ph - 0.5) * 2)
            put(self.slot_yellow, SLOT, x, y, { scale = scale, fade = alpha * p })
        end
        self:put_glyph(items[i].str, items[i].label, x, y, scale, alpha)
    end

    if not active then return end
    local top_y = RING_Y - radius
    local fa = 1 - clamp01((now - self.flash_t0) / FLASH_MS)
    if fa > 0 then put(self.slot_flash, SLOT, self.cx, top_y, { fade = alpha * fa }) end
    -- 486: arrows either side of the top slot drift outward 63 -> 78, fading in the second half
    local ph = ((now - self.t0) % PULSE_MS) / PULSE_MS
    local dx = 63 + 15 * ph
    local aa = alpha * (ph < 0.5 and 1.0 or 0.965 * (1 - (ph - 0.5) * 2))
    put(self.arrow, 64, self.cx - dx, top_y, { fade = aa })
    put(self.arrow, 64, self.cx + dx, top_y, { fade = aa, mirror = "horizontal" })
end

function NameEntry:draw_confirm(now)
    local c = self.confirm
    local f = clamp01((now - c.t0 - DIALOG_IN) / DIALOG_MS)
    if f <= 0 then return end
    local cx = self.cx
    put(self.panel, 952, cx, DIALOG_Y, { fade = f }, 424)
    if self.confirm_text then
        self.confirm_text:draw({ x = cx - self.confirm_text.width / 2,
                                 y = DIALOG_Y - 134 - self.confirm_text.height / 2, fade = f })
    end
    if self.hint_text then
        self.hint_text:draw({ x = cx - self.hint_text.width / 2,
                              y = DIALOG_Y - 68 - self.hint_text.height / 2, fade = f })
    end

    local by = DIALOG_Y + BUTTON_DY
    local ph = ((now - c.t0) % PULSE_MS) / PULSE_MS
    local glow = 0.5 + 0.5 * math.cos(ph * 2 * math.pi)
    for i = 1, 2 do
        local bx = cx + (i == 1 and -BUTTON_DX or BUTTON_DX)
        put(self.btn_base, 312, bx, by, { fade = f }, 120)
        if i == c.sel then
            -- 508 sits under the button fill (518 depth 5 < 6/7): the glow shows as a halo
            put(self.btn_glow, 312, bx, by, { fade = f * glow }, 120)
            put(self.btn_outline, 312, bx, by, { fade = f }, 120)
        end
        put(self.btn_fill, 312, bx, by, { fade = f }, 120)
        local lbl = i == 1 and self.yes_text or self.no_text
        if lbl then lbl:draw({ x = bx - lbl.width / 2, y = by - lbl.height / 2, fade = f }) end
    end
    if c.decide_t0 then
        -- 516: white flash on the chosen button, three blinks
        local t = ((now - c.decide_t0) % 167) / 167
        local a = 0.75 * (1 - math.abs(t * 2 - 1))
        local bx = cx + (c.sel == 1 and -BUTTON_DX or BUTTON_DX)
        put(self.btn_flash, 312, bx, by, { fade = a }, 120)
    end
end

function NameEntry:draw()
    local now = tex.get_current_ms()
    local el = now - self.t0
    tex.draw_rect(0, 0, tex.get_screen_width(), tex.get_screen_height(), 0, 0, 0, math.floor(120 * clamp01(el / 150)))

    -- sprite 3: ネームエントリー slides in from -90, overshoots to +10, settles at 0
    if self.mode_title then
        local x
        if el < 250 then
            local u = clamp01(el / 250)
            x = -90 + 100 * (1 - (1 - u) * (1 - u))
        else
            x = 10 - 10 * clamp01((el - 250) / 67)
        end
        tex.draw_texture(self.mode_title, { x = x, y = -8, fade = clamp01(el / 250) })
    end

    local bf = clamp01((el - BODY_IN) / BODY_MS)
    if bf <= 0 then return end

    if self.title then
        self.title:draw({ x = self.cx - self.title.width / 2, y = TITLE_Y - self.title.height / 2, fade = bf })
    end

    for i = 1, MAX_LEN do
        local x = self.cx + (i - 3) * PLATE_STEP
        local ch = self.name[i]
        put(self.big, BIG, x, PLATE_Y, { fade = bf })
        if ch then
            put(self.big_yellow, BIG, x, PLATE_Y, { fade = bf })
            self:put_glyph(ch, false, x, PLATE_Y, 1, bf)
            local fa = 1 - clamp01((now - (self.plate_t0[i] or 0)) / FLASH_MS)
            if fa > 0 then put(self.big_flash, BIG, x, PLATE_Y, { fade = bf * fa }) end
        end
    end

    -- outer / preview rings first, the active one on top
    for stage = 1, 3 do
        if stage ~= self.stage then self:draw_ring(stage, now) end
    end
    self:draw_ring(self.stage, now)

    local cur = self:ring(self.stage)[self.sel[self.stage]]
    put(self.slot_yellow, SLOT, self.cx, RING_Y, { fade = bf })
    self:put_glyph(cur.str, cur.label, self.cx, RING_Y, 1, bf)

    if self.confirm then self:draw_confirm(now) end
end
