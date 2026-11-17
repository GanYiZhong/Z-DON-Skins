-- YataiDONSimpleStyle: the enso battle result board (engine battle_result_board.cpp, BATTLE_RESULT).
-- new(data) when the screen opens; begin(answer) once the server answered (answer = nil offline or when
-- the play was not recorded); update / draw every frame; decide() on Don (skip to the end, then leave);
-- is_done() ends the screen. One dialog over the zone's field: battle power, defeated, damage, the boss's
-- life, then (with an answer) the bond EXP meter, the chests, the new special move / reward / next stage.
local UI = require("global.ss_ui")
local BT = require("global.ss_battle")
local P, U = UI.P, UI.U
local ON_ACC = { color = UI.P.on_acc, outline = false }

BattleResultBoard = {}
BattleResultBoard.__index = BattleResultBoard

local DX, DW = 381, 1056
local ROW_H = 22 * U
local COUNT_MS, STEP_MS, LEVEL_MS, CHEST_MS = 600, 200, 700, 380
local AUTO_LEAVE_MS = 10000
local MOVE_UNLOCKS = { 0, 1, 2, 3, 5, 6, 7, 8, 9 }
local KIND_KEY = { song = "bt_reward_song", costume = "bt_reward_costume", title = "bt_reward_title" }

local function clamp01(v) return math.max(0, math.min(1, v)) end

local function play(name, preset)
    if audio.has_sound(name) then audio.play_sound(name, preset or "sound") end
end

function BattleResultBoard.new(data)
    local self = setmetatable({}, BattleResultBoard)
    BT.reset()
    self.data = data
    self.started = false
    self.played = {}
    self.momo = UI.Mascot.new({ role = "scene", char = "momo" })
    self.hoshi = UI.Mascot.new({ role = "scene", char = "hoshi" })
    play("battle_bgm", "music")
    return self
end

local function level_segments(before, after)
    local fill = function(s) return s.exp_next > 0 and s.exp / s.exp_next or 1 end
    if after.bond == before.bond then
        return { { level = before.bond, from = fill(before), to = fill(after) } }
    end
    local segs = { { level = before.bond, from = fill(before), to = 1, up = true } }
    for level = before.bond + 1, after.bond - 1 do
        segs[#segs + 1] = { level = level, from = 0, to = 1, up = true }
    end
    segs[#segs + 1] = { level = after.bond, from = 0, to = fill(after) }
    return segs
end

function BattleResultBoard:begin(answer)
    local d = self.data
    self.answer = answer
    self.start_ms = nil
    self.f = 0
    self.played = {}
    self.leaving = false
    local t = 300
    self.power_at = t; t = t + COUNT_MS + STEP_MS
    self.kills_at = t; t = t + COUNT_MS + STEP_MS
    self.damage_at = t; t = t + COUNT_MS + STEP_MS
    self.boss = answer and answer.boss or (d.boss and {
        hp_before = d.boss_hp, hp_after = math.max(0, d.boss_hp - d.damage), max = d.boss_hp_max }) or nil
    if self.boss then
        self.boss_at = t; t = t + COUNT_MS + 2 * STEP_MS
    end
    local msgs = {}
    if answer then
        self.segs = level_segments(answer.before, answer.after)
        self.exp_at = t; t = t + #self.segs * LEVEL_MS + STEP_MS
        self.chest_at = t
        t = t + #(answer.chests or {}) * CHEST_MS + #(answer.orb_chests or {}) * CHEST_MS + STEP_MS
        self.best = d.power > (answer.before.best_power or 0)
        if answer.after.moves > answer.before.moves then
            local id = MOVE_UNLOCKS[answer.after.moves] or 0
            msgs[#msgs + 1] = { key = "bt_new_move", name = BT.move_name(id) }
        end
        if answer.orb_reward then
            local o = answer.orb_reward
            msgs[#msgs + 1] = { key = "bt_reward_get",
                name = o.kind == "move" and BT.move_name(4) or o.name }
        end
        if answer.reward and answer.reward.kind ~= "" then
            local r = answer.reward
            msgs[#msgs + 1] = { key = "bt_reward_get", name = (UI.t(KIND_KEY[r.kind] or "") or "") .. "  " .. (r.name or "") }
        end
        if answer.after.stage > answer.before.stage then msgs[#msgs + 1] = { key = "bt_stage_open" } end
    else
        msgs[#msgs + 1] = { key = "bt_offline", quiet = true }
    end
    self.msgs = msgs
    self.msg_at = t
    t = t + #msgs * 900
    self.end_at = t
    self.deadline = t + AUTO_LEAVE_MS
    self.won = self.boss and self.boss.hp_before > 0 and self.boss.hp_after == 0
    -- the board grows with what it shows; the bottom strip holds the nameplate and the hint
    local h = 24 * U + 3 * (ROW_H + 3 * U)
    if self.boss then h = h + 24 * U end
    if self.segs then h = h + 23 * U end
    if answer and (#(answer.chests or {}) + #(answer.orb_chests or {})) > 0 then h = h + 36 * U end
    h = h + #msgs * 15 * U + 36 * U
    self.dh = math.ceil(h / U) * U
    self.dy = UI.grid(540 - self.dh / 2)
    self.started = true
end

function BattleResultBoard:decide()
    if self.leaving or not self.started then return false end
    if self.f < self.end_at then
        self.start_ms = self.now_ms - self.end_at
        self.f = self.end_at
        self.skipped = true
        return true
    end
    self.leaving = true
    return true
end

function BattleResultBoard:is_done()
    return self.leaving
end

function BattleResultBoard:once(key, at)
    if not self.played[key] and self.f >= at then
        self.played[key] = true
        return not self.skipped
    end
    return false
end

function BattleResultBoard:update(ms)
    self.now_ms = ms
    self.momo:update(ms)
    self.hoshi:update(ms)
    if not self.started then return end
    self.start_ms = self.start_ms or ms
    self.f = ms - self.start_ms
    for _, k in ipairs({ "power_at", "kills_at", "damage_at" }) do
        if self:once(k, self[k] + COUNT_MS) then play("se_gauge_kime") end
    end
    if self.boss and self:once("boss", self.boss_at + COUNT_MS) then
        if self.won then
            play("se_boss_win")
            self.momo:react("clear"); self.hoshi:react("clear")
        else
            self.momo:react("miss")
        end
    end
    if self.segs then
        for i, seg in ipairs(self.segs) do
            if seg.up and self:once("lvup" .. i, self.exp_at + i * LEVEL_MS) then
                play("se_lvup")
                self.momo:react("decide")
            end
        end
    end
    if self.answer then
        local n = #(self.answer.chests or {}) + #(self.answer.orb_chests or {})
        for i = 1, n do
            if self:once("chest" .. i, self.chest_at + (i - 1) * CHEST_MS) then play("se_treasure") end
        end
    end
    for i, m in ipairs(self.msgs or {}) do
        if not m.quiet and self:once("msg" .. i, self.msg_at + (i - 1) * 900) then
            play("se_reward_window")
            self.hoshi:react("decide")
        end
    end
    if self.f >= self.deadline then self.leaving = true end
end

function BattleResultBoard:draw_background()
    BT.draw_bg(self.data.stage or 1)
end

function BattleResultBoard:nameplate_pos()
    if not self.started then return nil end
    local DY, DH = self.dy, self.dh
    return { DX + 24, DY + DH - 27 * U - 24, 1 }
end

-- label left, a counting number right
function BattleResultBoard:count_row(y, key, value, at, extra)
    local ix, iw = DX + 8 * U, DW - 16 * U
    UI.frame(ix, y, iw, ROW_H, { fill = P.bg2, shadow = 0 })
    UI.draw_text(UI.text_key(key, 36), ix + 5 * U, y + ROW_H / 2, "l")
    local q = clamp01((self.f - at) / COUNT_MS)
    if self.f < at then return end
    UI.num(tostring(math.floor(value * q + 0.5)), ix + iw - 5 * U, y + ROW_H / 2, "xl", P.ink, 255, "r")
    if extra and q >= 1 then extra(ix, iw) end
end

function BattleResultBoard:draw()
    if not self.started then return end
    local DY, DH = self.dy, self.dh
    local d = self.data
    local x, y, w, h, done = UI.open_rect(DX, DY, DW, DH, self.f)
    if not x then return end
    local ix, iy, iw, ih = UI.frame(x, y, w, h, { fill = P.paper, border = 2 * U, shadow = 2 * U })
    if not done then return end
    -- title band: results, song number, stage
    UI.rect(ix, iy, iw, 20 * U, P.focus)
    UI.draw_text(UI.text_key("bt_result_title", 36, "ink"), ix + 5 * U, iy + 10 * U, "l")
    local stage_s = BT.stage_text(d.stage or 1) .. "  " .. BT.zone_text(d.stage or 1)
    UI.draw_text(UI.text(stage_s, 24, "ink"), ix + iw - 5 * U, iy + 10 * U, "r")
    if (d.song_number or 0) > 0 then
        local s = UI.text_key("bt_song_n", 24, "ink", d.song_number)
        UI.draw_text(s, ix + iw / 2, iy + 10 * U, "c")
    end
    local ry = iy + 24 * U
    self:count_row(ry, "bt_power", d.power or 0, self.power_at, function(rx, rw)
        if self.best then
            local s = UI.text_key("bt_new_best", 24, ON_ACC)
            local cw = math.ceil((s.width + 8 * U) / U) * U
            local cx = rx + rw / 2 - cw / 2 + 60
            UI.frame(cx, ry + 4 * U, cw, ROW_H - 8 * U, { fill = P.clear, shadow = 0 })
            UI.draw_text(s, cx + cw / 2, ry + ROW_H / 2, "c")
        end
    end)
    ry = ry + ROW_H + 3 * U
    self:count_row(ry, "bt_kills", d.kills or 0, self.kills_at)
    ry = ry + ROW_H + 3 * U
    self:count_row(ry, "bt_damage", d.damage or 0, self.damage_at)
    ry = ry + ROW_H + 3 * U
    -- the boss's life: from before to after
    if self.boss and self.f >= self.boss_at then
        local b = self.boss
        local q = clamp01((self.f - self.boss_at) / COUNT_MS)
        local hp = b.hp_before + (b.hp_after - b.hp_before) * q
        local frac = clamp01(hp / math.max(1, b.max))
        local name = UI.text(BT.boss_name(d.stage or 1), 24, { color = P.red_t, outline = false })
        UI.draw_text(name, DX + 13 * U, ry + 6 * U, "l")
        UI.pixbar(DX + 13 * U, ry + 12 * U, DW - 26 * U, 8 * U, frac, BT.hp_color(frac), 10)
        if q >= 1 then
            local key = self.won and "bt_boss_down" or "bt_boss_left"
            local fill = self.won and P.clear or P.bg3
            local s = UI.text_key(key, 24, self.won and ON_ACC or "ink")
            local cw = math.ceil((s.width + 8 * U) / U) * U
            UI.frame(DX + DW - 13 * U - cw, ry, cw, 11 * U, { fill = fill, shadow = 0 })
            UI.draw_text(s, DX + DW - 13 * U - cw / 2, ry + 5.5 * U, "c")
        end
        ry = ry + 24 * U
    end
    -- bond EXP meter
    if self.segs and self.f >= self.exp_at then
        local i = math.min(#self.segs, math.floor((self.f - self.exp_at) / LEVEL_MS) + 1)
        local seg = self.segs[i]
        local q = clamp01((self.f - self.exp_at - (i - 1) * LEVEL_MS) / LEVEL_MS)
        local fill = seg.from + (seg.to - seg.from) * q
        local level = seg.level + ((seg.up and q >= 1) and 1 or 0)
        UI.draw_text(UI.text_key("bt_bond", 24), DX + 13 * U, ry + 6 * U, "l")
        UI.num(tostring(level), DX + 13 * U + UI.label_width("bt_bond", 24) + 4 * U, ry + 6 * U, "m", P.ink, 255, "l")
        UI.pixbar(DX + 13 * U, ry + 12 * U, DW - 26 * U, 7 * U, fill, P.normal, 0)
        local ups = 0
        for _, s in ipairs(self.segs) do if s.up then ups = ups + 1 end end
        if ups > 0 and self.f >= self.exp_at + LEVEL_MS then
            local s = UI.text_key("bt_level_up", 24, ON_ACC)
            local cw = math.ceil((s.width + 8 * U) / U) * U
            UI.frame(DX + DW - 13 * U - cw, ry, cw, 11 * U, { fill = P.clear, shadow = 0 })
            UI.draw_text(s, DX + DW - 13 * U - cw / 2, ry + 5.5 * U, "c")
        end
        ry = ry + 23 * U
    end
    -- chests: gold then orb, each with its count
    if self.answer and self.f >= self.chest_at then
        local list = {}
        for _, n in ipairs(self.answer.chests or {}) do list[#list + 1] = { "chest", n } end
        for _, n in ipairs(self.answer.orb_chests or {}) do list[#list + 1] = { "orb", n } end
        for i, c in ipairs(list) do
            local at = self.chest_at + (i - 1) * CHEST_MS
            if self.f >= at then
                local cx = DX + 30 * U + (i - 1) * 150
                local open = self.f >= at + 200
                BT.draw_item(c[1] .. (open and "_open" or ""), cx, ry + 54)
                if open then
                    UI.num("+" .. tostring(c[2]), cx + 60, ry + 54, "m", P.ink, 255, "l")
                    UI.burst(cx, ry + 30, self.f - at - 200)
                end
            end
        end
        if #list > 0 then ry = ry + 36 * U end
    end
    -- messages (new move, reward, next stage; offline note)
    for i, m in ipairs(self.msgs or {}) do
        local at = self.msg_at + (i - 1) * 900
        if self.f >= at then
            local s = UI.text_key(m.key, 24, m.quiet and { color = P.text2, outline = false } or "ink")
            local line = m.name and UI.text(m.name, 24, "ink") or nil
            local tw = s.width + (line and (line.width + 6 * U) or 0)
            local cw = math.ceil((tw + 10 * U) / U) * U
            local cx = UI.grid(DX + DW / 2 - cw / 2)
            local my = ry + (i - 1) * 15 * U
            if my + 12 * U < DY + DH - 30 * U then
                if not m.quiet then UI.frame(cx, my, cw, 12 * U, { fill = P.bg2, shadow = 0 }) end
                UI.draw_text(s, cx + 5 * U, my + 6 * U, "l")
                if line then UI.draw_text(line, cx + 5 * U + s.width + 6 * U, my + 6 * U, "l") end
            end
        end
    end
    -- Momo and Hoshi beside the board
    self.hoshi:draw(1770, 1005, { mirror = true })
    self.momo:draw(1600, 1010, { mirror = true })
    if self.f >= self.end_at then
        UI.hint({ { "don", "bt_next" } }, { x1 = DX + DW - 8 * U, y1 = DY + DH - 6 * U })
    end
end
