-- YataiDONSimpleStyle: the enso battle special-move picker (engine skill_picker.cpp). Don on the "special
-- move" slot of the course select opens it; the rims change the current slot's move, Don decides it, and
-- after the third slot it closes. A dialog on the left: title, "n / total" (the shown move's number among
-- the unlocked ones), three slot rows (decided rows plain, the current one focused with blinking arrows,
-- the rest muted); a colour tab marks each move.
local UI = require("global.ss_ui")
local BT = require("global.ss_battle")
local P, U = UI.P, UI.U

BattleSkillPicker = {}
BattleSkillPicker.__index = BattleSkillPicker

local X, Y, W, H = 24, 228, 600, 318
local ROW_Y0, ROW_H, ROW_GAP = 99, 54, 15
local CLOSE_MS = 150

function BattleSkillPicker.new(data)
    local self = setmetatable({}, BattleSkillPicker)
    BT.reset()
    self.side = data.player == 2 and 2 or 1
    self.state = nil
    return self
end

function BattleSkillPicker:open(ms, slots, number, total)
    self.state = "open"
    self.open_ms, self.move_ms = ms, -1e9
    self.slots = { slots[1], slots[2], slots[3] }
    self.slot, self.number, self.total = 1, number, total
    self.dir = 0
end

function BattleSkillPicker:move(ms, slot, move, number, dir)
    self.slots[slot + 1], self.number = move, number
    self.move_ms, self.dir = ms, dir
end

function BattleSkillPicker:decide(ms, slot, next_number)
    self.slot, self.number = slot + 2, next_number
    if self.slot > 3 then
        self.state, self.close_ms = "closing", ms
    end
end

function BattleSkillPicker:draw(ms)
    if not self.state then return end
    if self.state == "closing" and ms - self.close_ms >= CLOSE_MS then
        self.state = nil
        return
    end
    local x0 = self.side == 2 and (1920 - X - W) or X
    local x, y, w, h, done = UI.open_rect(x0, Y, W, H, ms - self.open_ms)
    if self.state == "closing" then
        local f = math.floor((ms - self.close_ms) / 50)
        local k = f == 0 and 0.66 or 0.33
        local hh = math.floor(H * k / U) * U
        x, y, w, h, done = x0, UI.grid(Y + (H - hh) / 2), W, hh, false
    end
    if not x then return end
    local ix, iy, iw, ih = UI.frame(x, y, w, h, { fill = P.paper, border = 2 * U, shadow = 2 * U })
    if not done then return end
    -- title band + counter
    UI.rect(ix, iy, iw, 17 * U, P.focus)
    UI.draw_text(UI.text_key("bt_pick_title", 36, "ink"), ix + 4 * U, iy + 17 * U / 2, "l")
    if (self.total or 0) > 0 then
        local s = tostring(math.min(self.number or 0, 99)) .. "/" .. tostring(math.min(self.total, 99))
        UI.num(s, ix + iw - 4 * U, iy + 17 * U / 2, "m", P.ink, 255, "r")
    end
    -- the three slots
    for i = 1, 3 do
        local ry = y + ROW_Y0 + (i - 1) * (ROW_H + ROW_GAP)
        local lx = ix + 4 * U
        UI.draw_text(UI.text_key("bt_slot", 24, { color = P.text2, outline = false }, i), lx, ry + ROW_H / 2, "l")
        local bx, bw = ix + 40 * U, iw - 66 * U
        local state = (i == self.slot) and "focused" or "normal"
        local bix, biy, biw, bih = UI.chrome.button(bx, ry, bw, ROW_H, state)
        local id = self.slots[i]
        local muted = i > self.slot
        local col = muted and P.mute or P.ink
        if id ~= nil and id < BT.MOVES then UI.rect(bix, biy, 2 * U, bih, BT.move_color(id)) end
        local shift = 0
        if i == self.slot and ms - self.move_ms < 100 then shift = -self.dir * 2 * U end
        UI.draw_text(UI.text(BT.move_name(id), 24, { color = col, outline = false }), bix + biw / 2 + shift,
            biy + bih / 2, "c")
        if i == self.slot and UI.blink_on(ms - self.move_ms, 400) then
            -- ◀ ▶ pixel arrows
            for side = -1, 1, 2 do
                local axx = side < 0 and (bx - 4 * U) or (bx + bw + 2 * U)
                local acy = UI.grid(ry + ROW_H / 2)
                for k = 0, 2 do
                    local hgt = (3 - k) * 2 - 1
                    local colx = side < 0 and (axx + (2 - k) * U) or (axx + k * U)
                    UI.rect(colx, acy - (hgt * U - U) / 2, U, hgt * U, P.ink)
                end
            end
        end
    end
end
