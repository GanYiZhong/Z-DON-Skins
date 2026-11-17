-- YataiDONSimpleStyle: the enso battle song select card (engine battle_select_info.cpp, BATTLE_SELECT).
-- A dialog on the left: the mode title, the stage and its zone (two of its creatures, or the boss's
-- name and life), the bond level and its EXP meter, the best battle power, the stones toward the next
-- special move and, during the orb event, the orbs. Offline (no server answer) the engine passes the
-- defaults (bond 1, stage 1), which read fine as they are.
local UI = require("global.ss_ui")
local BT = require("global.ss_battle")
local P, U = UI.P, UI.U
local ON_ACC = { color = UI.P.on_acc, outline = false }

BattleSelectInfo = {}
BattleSelectInfo.__index = BattleSelectInfo

local X, Y, W = 24, 252, 375
local ROW = 16 * U

local function clamp01(v) return math.max(0, math.min(1, v)) end

function BattleSelectInfo.new(data)
    local self = setmetatable({}, BattleSelectInfo)
    BT.reset()
    self.data = data
    self.start_ms = nil
    return self
end

-- label left, value right on one row; returns the next row's y
local function row(ix, iw, y, key, value, size)
    UI.draw_text(UI.text_key(key, 24), ix + 3 * U, y + ROW / 2, "l")
    UI.num(tostring(value), ix + iw - 3 * U, y + ROW / 2, size or "m", P.ink, 255, "r")
    return y + ROW
end

function BattleSelectInfo:height()
    local d = self.data
    local h = 15 * U            -- title band
    h = h + ROW + 3 * U         -- stage
    h = h + ((d.boss_hp_max or 0) > 0 and (ROW + 10 * U) or 40 * U)   -- boss life / creatures
    h = h + ROW + 6 * U + 3 * U -- bond + meter
    h = h + ROW                 -- best power
    h = h + ROW                 -- stones
    if (d.orb_cost or -1) > 0 or d.orbs_done then h = h + ROW end
    return h + 6 * U
end

-- while the course select is open this card steps aside (the course select's own row has the special-move
-- column: song_select/file_navigator/box_song.lua, tools/patch_battle_course_select.py)
local function course_open()
    return SS_SEL ~= nil and SS_SEL.course_open ~= nil and SS_SEL:course_open()
end

function BattleSelectInfo:draw(ms)
    if course_open() then
        self.start_ms = nil
        return
    end
    self.start_ms = self.start_ms or ms
    local t = ms - self.start_ms
    local d = self.data
    local h = math.ceil(self:height() / U) * U
    local x, y, w, hh, done = UI.open_rect(X, Y, W, h, t - 100)
    if not x then return end
    local ix, iy, iw, ih = UI.frame(x, y, w, hh, { fill = P.paper, border = 2 * U, shadow = 2 * U })
    if not done then return end
    -- title band
    UI.rect(ix, iy, iw, 13 * U, P.focus)
    UI.draw_text(UI.text_key("bt_mode", 24, "ink"), ix + iw / 2, iy + 13 * U / 2, "c")
    local cy = iy + 15 * U
    -- stage + zone
    local stage = d.stage or 1
    UI.draw_text(UI.text(BT.stage_text(stage), 24, "ink"), ix + 3 * U, cy + ROW / 2, "l")
    UI.draw_text(UI.text(BT.zone_text(stage), 24, { color = P.text2, outline = false }), ix + iw - 3 * U,
        cy + ROW / 2, "r")
    cy = cy + ROW
    UI.rect(ix + 3 * U, cy + U, iw - 6 * U, U, P.line)
    cy = cy + 3 * U
    if (d.boss_hp_max or 0) > 0 then
        local frac = clamp01((d.boss_hp or 0) / d.boss_hp_max)
        UI.draw_text(UI.text(BT.boss_name(stage), 24, { color = P.red_t, outline = false }), ix + 3 * U,
            cy + ROW / 2, "l")
        cy = cy + ROW
        UI.pixbar(ix + 3 * U, cy, iw - 6 * U, 7 * U, frac, BT.hp_color(frac), 10)
        cy = cy + 10 * U
    else
        -- two of the zone's creatures, bobbing
        local z = BT.zone(stage)
        local f = math.floor(t / 400) % 2
        BT.draw_mob(z, 0, ix + iw * 0.3, cy + 37 * U, { frame = f })
        BT.draw_mob(z, 1, ix + iw * 0.7, cy + 37 * U, { frame = 1 - f })
        cy = cy + 40 * U
    end
    -- bond level + EXP meter
    cy = row(ix, iw, cy, "bt_bond", d.bond or 1, "m")
    local exp_next = d.exp_next or -1
    local fill = exp_next > 0 and clamp01((d.exp or 0) / exp_next) or 1
    UI.pixbar(ix + 3 * U, cy, iw - 6 * U, 6 * U, fill, P.normal, 0)
    cy = cy + 9 * U
    cy = row(ix, iw, cy, "bt_best", math.min(d.best_power or 0, 99999), "m")
    -- stones toward the next special move
    if (d.move_cost or -1) < 0 then
        UI.draw_text(UI.text_key("bt_all_moves", 24, { color = P.gold_t, outline = false }), ix + iw / 2,
            cy + ROW / 2, "c")
        cy = cy + ROW
    else
        cy = row(ix, iw, cy, "bt_stones", tostring(math.min(d.stones or 0, 999)) .. "/" ..
            tostring(math.min(d.move_cost, 999)), "m")
    end
    if (d.orb_cost or -1) > 0 then
        row(ix, iw, cy, "bt_orbs", tostring(math.min(d.orbs or 0, 999)) .. "/" .. tostring(math.min(d.orb_cost, 999)), "m")
    elseif d.orbs_done then
        UI.draw_text(UI.text_key("bt_orbs", 24, { color = P.gold_t, outline = false }), ix + iw / 2, cy + ROW / 2, "c")
    end
end
