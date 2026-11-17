-- YataiDONSimpleStyle: shared enso battle helpers (game/enso_battle.lua, song_select/battle_select.lua,
-- song_select/skill_picker.lua, battle_result/battle_result.lua). Logical 1920x1080 coordinates.
-- Sprites: Graphics/ss_battle/<subset>/<key> (ss/v2_battle.py), sizes in global/ss_battle_def.lua.
local UI = require("global.ss_ui")
local DEF = require("global.ss_battle_def")

local BT = { DEF = DEF }

BT.EX_STAGE = 11
BT.MOVES = 10          -- move ids 0..9; 10 = random, 11 = none (battle_match.h)

-- the engine's enemy set of a stage (battle_match.h battle_enemy_set): stages 1-2, 3-4, ..., 9-11
function BT.zone(stage)
    stage = math.max(1, math.floor(stage or 1))
    return math.min(math.floor((stage - 1) / 2), 4)
end

function BT.is_boss_stage(stage)
    return stage % 2 == 0 or stage == BT.EX_STAGE
end

-- "Stage 3" / "EX Stage"
function BT.stage_text(stage)
    if stage == BT.EX_STAGE then return UI.t("bt_stage_ex") or "EX" end
    return UI.t("bt_stage", stage) or ("Stage " .. stage)
end

function BT.zone_text(stage)
    return UI.t("bt_zone_" .. BT.zone(stage)) or ""
end

function BT.boss_key(stage)
    if DEF.BOSS_STAGES[stage] then return stage end
    if stage > 10 then return 11 end
    return math.max(2, stage + stage % 2)
end

function BT.boss_name(stage)
    return UI.t("bt_boss_" .. BT.boss_key(stage)) or ""
end

function BT.move_name(id)
    return UI.t("bt_move_" .. tostring(id)) or tostring(id)
end

-- move id -> accent colour (cut-in band, picker chips)
local MOVE_COL = { [0] = "pink", "clear", "hard", "mint", "gogo", "roll", "ka", "don", "ura", "oni", "bg3", "bg3" }
function BT.move_color(id)
    return UI.P[MOVE_COL[id] or "clear"] or UI.P.clear
end

-- ---------------------------------------------------------------- textures
local cache = {}
function BT.T(subset, key)
    local k = subset .. "/" .. key
    local t = cache[k]
    if t == nil then
        t = tex.get_texture("ss_battle/" .. k) or false
        cache[k] = t
    end
    return t or nil
end

function BT.reset()
    cache = {}
    UI.reset()
end

-- whole physical pixel
local function px(v) return UI.px(v) end

-- a creature, centred on cx, feet on `foot`; o.frame, o.mirror, o.dy (lift)
function BT.draw_mob(zone, kind, cx, foot, o)
    o = o or {}
    local row = DEF.MOB[zone] or DEF.MOB[0]
    kind = (row[kind + 1] and kind) or 0
    local w = row[kind + 1]
    local t = BT.T("mob", "z" .. zone .. "_" .. kind)
    if not t then return end
    -- the sprite's last design row is its margin: one cell under the feet
    local cell = w / 18
    tex.draw_texture(t, { frame = o.frame or 0, x = px(cx - w / 2), y = px(foot - w + cell - (o.dy or 0)),
        mirror = o.mirror and "horizontal" or nil })
end

function BT.mob_size(zone, kind)
    local row = DEF.MOB[zone] or DEF.MOB[0]
    return row[kind + 1] or row[1]
end

function BT.is_big(zone, kind)
    local row = DEF.MOB[zone] or DEF.MOB[0]
    return kind >= #row - (DEF.BIG[zone] or 1)
end

-- frame 0 / 1 idle, 2 hurt
function BT.draw_boss(stage, cx, foot, frame, dy)
    local t = BT.T("boss", "b" .. BT.boss_key(stage))
    if not t then return end
    local w = DEF.BOSS
    local cell = w / 42
    tex.draw_texture(t, { frame = frame or 0, x = px(cx - w / 2), y = px(foot - w + cell - (dy or 0)) })
end

function BT.draw_item(key, cx, cy, frame)
    local t = BT.T("item", key)
    if not t then return end
    local s = (key == "slash") and DEF.SLASH or (key == "star") and DEF.STAR or DEF.CHEST
    tex.draw_texture(t, { frame = frame or 0, x = px(cx - s / 2), y = px(cy - s / 2) })
end

function BT.draw_bg(stage)
    local t = BT.T("bg", "zone_" .. BT.zone(stage))
    if t then tex.draw_texture(t, { x = 0, y = 0 }) end
end

-- ---------------------------------------------------------------- chrome
-- a label + value panel: { x, y, w, h }, label key, value string, value digit size
function BT.stat_panel(x, y, w, h, label_key, value, size, accent)
    local ix, iy, iw, ih = UI.frame(x, y, w, h, { fill = UI.P.paper })
    if accent then UI.rect(ix, iy, 2 * UI.U, ih, accent) end
    UI.draw_text(UI.text_key(label_key, 24), ix + 4 * UI.U, iy + ih / 2, "l")
    UI.num(tostring(value), ix + iw - 3 * UI.U, iy + ih / 2, size or "l", UI.P.ink, 255, "r")
end

-- a number in a chip (paper, ink digits; gold chip for criticals): centred on cx, cy
function BT.num_chip(value, cx, cy, size, fill)
    local s = tostring(value)
    local w = math.ceil((UI.num_width(s, size) + 12 * UI.U) / UI.U) * UI.U
    local h = (size == "l") and 15 * UI.U or 11 * UI.U
    local x, y = UI.grid(cx - w / 2), UI.grid(cy - h / 2)
    local ix, iy, iw, ih = UI.frame(x, y, w, h, { fill = fill or UI.P.paper, notch = UI.U })
    local col = (fill and fill ~= UI.P.paper) and UI.P.on_acc or UI.P.ink
    UI.num(s, ix + iw / 2, iy + ih / 2, size, col, 255, "c")
end

-- a pixel meter with a frame, fill colour by ratio for the boss
function BT.hp_color(frac)
    if frac > 0.5 then return UI.P.normal end
    if frac > 0.2 then return UI.P.clear end
    return UI.P.don
end

return BT
