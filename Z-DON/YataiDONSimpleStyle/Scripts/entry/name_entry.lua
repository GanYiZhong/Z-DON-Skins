-- YataiDONSimpleStyle v2: the name picker (EntryScreen NAME_ENTRY; objects/entry/name_entry.cpp loads
-- class NameEntry from this file). The engine shows it only after an ONLINE login registered a fresh
-- account (scenes/entry.cpp finish_login -> begin_name_entry); offline / in the hidden test mode it never
-- appears. Same interaction as PyTaikoGreen's picker (three kana rings: row -> kana -> variant; もどる /
-- けってい on the outer ring; a yes / no confirm), drawn in our own chrome: one dialog with a gold title
-- band, five name slots, square buttons on the U grid, engine text through UI.text (role sizes, ink).
-- Pixel art at alpha 1 only: the screen dim is the checker wipe, windows open with UI.open_rect, the
-- only the active ring is shown (no translucent dimmed rings), nothing is scaled.
-- Coordinates: logical 1920x1080; the 1P picker is centred on the left half, the 2P one on the right.
local UI = require("global.ss_ui")

NameEntry = {}
NameEntry.__index = NameEntry

local U = UI.U
local P = UI.P
local MAX_LEN = 5
local HALF_W = 960
local DLG_W, DLG_Y, DLG_H = 864, 186, 759     -- the picker dialog (outer border edge); y 186 clears
                                              -- the global top bar (indicators, credit timer: y <= 180)
local BAND_H = 16 * U                          -- gold title band (+ 1U ink rule)
local SLOT, SLOT_STEP, SLOT_Y = 26 * U, 30 * U, 252
local RING_CY = 636
local RADII = { 258, 180, 93 }   -- 78 px buttons; ring 3 clears the 90 px centre
local ITEM = 26 * U                            -- 78: a ring button
local CENTER = 30 * U                          -- 90: the current choice in the middle
local ROT_MS = 83                              -- one step of ring rotation (positions snap to U)
local BODY_START = 2667                        -- input / body wait for the voice line (as Green)
local CONFIRM_W, CONFIRM_H = 576, 210
local BTN_W, BTN_H, BTN_DX = 168, 60, 120
local BLINK = 400

local function chars(s)
    local out = {}
    for c in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do out[#out + 1] = c end
    return out
end

local ROWS = {
    "あいうえお", "かきくけこ", "さしすせそ", "たちつてと", "なにぬねの",
    "はひふへほ", "まみむめも", "やゆよ", "らりるれろ", "わゐゑをんゎ", "～ー？！",
}
-- base char followed by its other forms
local VARIANTS = {}
for _, group in ipairs({
    "あぁ", "いぃ", "うぅ", "えぇ", "おぉ",
    "かが", "きぎ", "くぐ", "けげ", "こご",
    "さざ", "しじ", "すず", "せぜ", "そぞ",
    "ただ", "ちぢ", "つづっ", "てで", "とど",
    "はばぱ", "ひびぴ", "ふぶぷ", "へべぺ", "ほぼぽ",
    "やゃ", "ゆゅ", "よょ", "わゎ",
}) do
    local list = chars(group)
    VARIANTS[list[1]] = list
end

local function clamp01(v) return math.max(0.0, math.min(1.0, v)) end

function NameEntry.new(is_2p)
    local self = setmetatable({}, NameEntry)
    UI.reset()
    self.is_2p = is_2p
    self.cx = is_2p and (HALF_W + HALF_W / 2) or (HALF_W / 2)
    self.accent = is_2p and P.p2 or P.p1
    self.cursor = tex.get_texture("entry/ss_front/cursor")

    self.title = UI.text(tex.skin_text("entry_name_title"), 36, "ink")
    self.tag = UI.text(is_2p and "2P" or "1P", 24, "paper")
    self.confirm_text = UI.text(tex.skin_text("entry_name_confirm"), 36, "ink")
    self.yes_text = UI.text(tex.skin_text("entry_name_yes"), 24, "ink")
    self.no_text = UI.text(tex.skin_text("entry_name_no"), 24, "ink")

    self.rows = {}
    for _, row in ipairs(ROWS) do
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
    self.confirm = nil         -- { sel = 1 yes / 2 no, t0 } while asking
    self.rot, self.rot_t0 = 0, 0
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

-- a square button of size s centred on (cx, cy) with its kana (36) or word label (18)
local function item_box(str, label, cx, cy, s, kind)
    local x, y = UI.grid(cx - s / 2), UI.grid(cy - s / 2)
    UI.chrome.button(x, y, s, s, kind)
    UI.draw_text(UI.text(str, label and 18 or 36, "ink"), x + s / 2, y + s / 2, "c")
end

function NameEntry:draw_ring(stage, now)
    local items = self:ring(stage)
    if not items then return end
    local n = #items
    local radius = RADII[stage]
    local sel = self.sel[stage]
    local rot = self.rot * (1 - clamp01((now - self.rot_t0) / ROT_MS))
    for i = 1, n do
        local ang = math.rad(-90 + (i - sel + rot) * 360 / n)
        local x = self.cx + math.cos(ang) * radius
        local y = RING_CY + math.sin(ang) * radius
        item_box(items[i].str, items[i].label, x, y, ITEM, i == sel and "focused" or "normal")
    end
end

function NameEntry:draw_confirm(now)
    local c = self.confirm
    local x0, y0 = UI.grid(self.cx - CONFIRM_W / 2), UI.grid(RING_CY - CONFIRM_H / 2)
    local x, y, w, h, open = UI.open_rect(x0, y0, CONFIRM_W, CONFIRM_H, now - c.t0)
    if not x then return end
    UI.chrome.dialog(x, y, w, h)
    if not open then return end
    UI.draw_text(self.confirm_text, self.cx, y0 + 18 * U, "c")
    local by = y0 + CONFIRM_H - 12 * U - BTN_H
    for i = 1, 2 do
        local bx = UI.grid(self.cx + (i == 1 and -BTN_DX or BTN_DX) - BTN_W / 2)
        local on = i == c.sel
        UI.chrome.button(bx, by, BTN_W, BTN_H, on and "focused" or "normal")
        UI.draw_text(i == 1 and self.yes_text or self.no_text, bx + BTN_W / 2, by + BTN_H / 2, "c")
        -- the ▶ before the selected button, blinking 400 / 400 like the entry boards
        if on and self.cursor and UI.blink_on(now - c.t0, BLINK) then
            local ci = tex.get_texture_info("ss_front", "cursor")
            local cw = (ci and ci.x2 and ci.x2[1]) or 27
            local chh = (ci and ci.y2 and ci.y2[1]) or 27
            tex.draw_texture(self.cursor, { x = bx - cw - 2 * U, y = UI.grid(by + BTN_H / 2 - chh / 2) })
        end
    end
end

function NameEntry:draw()
    local now = tex.get_current_ms()
    local el = now - self.t0

    -- the stage behind dims with the checker wipe (no translucent rect), 50 ms per step
    UI.wipe(math.min(2, UI.wipe_in(el)), P.ink)

    local dx = UI.grid(self.cx - DLG_W / 2)
    local x, y, w, h, open = UI.open_rect(dx, DLG_Y, DLG_W, DLG_H, el)
    if not x then return end
    local ix, iy, iw = UI.chrome.dialog(x, y, w, h)
    if not open then return end

    -- title band: the player cell (1P red / 2P blue) and the title, 36 px ink on gold
    UI.rect(ix, iy, iw, BAND_H, P.clear)
    UI.rect(ix, iy + BAND_H, iw, U, P.ink)
    UI.rect(ix, iy, BAND_H, BAND_H, self.accent)
    UI.rect(ix + BAND_H, iy, U, BAND_H, P.ink)
    UI.draw_text(self.tag, ix + BAND_H / 2, iy + BAND_H / 2, "c")
    UI.draw_text(self.title, self.cx + BAND_H / 2, iy + BAND_H / 2, "c")
    if el < BODY_START then return end

    -- five name slots: filled = paper with the kana, the next free one = gold, the rest bg3
    local filled = #self.name
    for i = 1, MAX_LEN do
        local sx = UI.grid(self.cx + (i - 3) * SLOT_STEP - SLOT / 2)
        local c = self.name[i]
        local fill = c and P.paper or (i == filled + 1 and P.clear or P.bg3)
        UI.chrome.panel(sx, SLOT_Y, SLOT, SLOT, fill)
        if c then UI.draw_text(UI.text(c, 36, "ink"), sx + SLOT / 2, SLOT_Y + SLOT / 2, "c") end
    end

    -- only the active ring: square buttons on concentric rings collide at the diagonals, and a dimmed
    -- (translucent) preview ring is not allowed; the centre shows the current choice
    self:draw_ring(self.stage, now)

    local cur = self:ring(self.stage)[self.sel[self.stage]]
    item_box(cur.str, cur.label, self.cx, RING_CY, CENTER, "focused")

    if self.confirm then self:draw_confirm(now) end
end
