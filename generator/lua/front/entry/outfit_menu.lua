-- YataiDONSimpleStyle: the costume picker (Z-DON 2D outfits: objects/entry/zdon_outfit_menu.h; the engine owns
-- the input and the save, this only draws). One dialog at the stage centre: the title, the player's mascot at
-- scene size wearing the outfit under the cursor (cheers on every change), the outfit's name between ◀ ▶,
-- n / count (the entry screen draws the hint pill). Outfit 0 = the plain mascot; 1.. = D.MASCOT.outfits.
-- The outfit number carries the character too (UI.outfit_decode: Momo's outfits, then Hoshi's), so the
-- player picks the character by scrolling on; the name row reads 「character・outfit」.
local UI = require("global.ss_ui")
local P, U = UI.P, UI.U

OutfitMenu = {}
OutfitMenu.__index = OutfitMenu

local DLG = { 600, 168, 720, 600 }        -- x, y, w, h
local PREVIEW_FOOT = 600

function OutfitMenu.new(is_2p, count, current)
    local self = setmetatable({}, OutfitMenu)
    self.count = count
    self.index = current
    self.mascot = UI.Mascot.new({ char = "momo", role = "scene", beat = false, outfit = current })
    self.t0 = nil
    return self
end

function OutfitMenu:update(ms, index)
    self.ms = ms
    if self.t0 == nil then self.t0 = ms end
    if index ~= self.index then
        self.dir = (index > self.index) and 1 or -1
        self.index = index
        self.mascot.outfit = index
        self.mascot:react("decide")
    end
    self.mascot:update(ms)
end

local function outfit_key(o)
    local id = o > 0 and UI.D.MASCOT.outfits and UI.D.MASCOT.outfits[o]
    return id and ("outfit_" .. id) or "outfit_plain"
end

function OutfitMenu:draw(index)
    local x, y, w, h = DLG[1], DLG[2], DLG[3], DLG[4]
    local ix, iy, iw, ih = UI.chrome.dialog(x, y, w, h)
    -- title band
    UI.rect(ix, iy, iw, 18 * U, P.p1)
    UI.draw_text(UI.text_key("outfit_title", 36, "paper"), ix + iw / 2, iy + 9 * U, "c")
    -- the mascot on a little floor
    local cx = ix + iw / 2
    UI.rect(ix + 12 * U, PREVIEW_FOOT, iw - 24 * U, U, P.line)
    self.mascot:draw(cx, PREVIEW_FOOT)
    -- name row:  ◀  character・outfit  ▶
    local char, o = UI.outfit_decode(index)
    local ny = PREVIEW_FOOT + 30
    local name = UI.text((UI.t("chara_" .. char) or char) .. "・" .. (UI.t(outfit_key(o)) or ""), 36, "ink")
    UI.draw_text(name, cx, ny, "c")
    local half = math.max(120, (name and name.width or 0) / 2 + 40)
    local blink = (math.floor((self.ms or 0) / 400) % 2) == 0
    if blink then
        UI.draw_text(UI.text("◀", 36, "ink"), cx - half, ny, "c")
        UI.draw_text(UI.text("▶", 36, "ink"), cx + half, ny, "c")
    end
    UI.num(tostring(index + 1) .. "/" .. tostring(self.count), cx, ny + 46, "m", P.text2 or P.ink, 255, "c")
end
