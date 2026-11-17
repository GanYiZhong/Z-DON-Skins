BattleSelectInfo = {}
BattleSelectInfo.__index = BattleSelectInfo

local S = tex.get_screen_scale()
local FRAME_MS = 1000 / 60
local DIR = "song_select/enso_battle/"
local WHITE = { 255, 255, 255, 255 }
local BLACK = { 0, 0, 0, 255 }

local SLIDE_FRAMES, SLIDE_FROM = 18, -202
local BOB_FRAMES = 35
local CARD = { { 101, 357 }, { 1184, 356 } }
local PARTNER = { { 93, 535 }, { 1202, 535 } }
local EXP_FULL_SCALE = 1.192
local EXP_FULL_WIDTH = 104 * EXP_FULL_SCALE
local STAGE_NAME_WIDTH = 140
local BOSS_LIFE_RIGHT, BOSS_LIFE_WIDTH = 696.3, 136
local TOKEN_X, TOKEN_Y = 431, 660
-- during the Maou event the stones token moves up for the orbs token below it
local EVENT_STONES_DY, EVENT_ORBS_DY = -14, 24
local EX_STAGE = 11
local CURRENT_ONES_X = { 427, 433, 440 }
local GOAL_ONES_X = { 473.5, 478.5, 485.5 }

local function clamp01(v) return math.max(0, math.min(1, v)) end
local function triangle(f, period) return 1 - math.abs(2 * (f % period) / period - 1) end

function BattleSelectInfo.new(data)
    local self = setmetatable({}, BattleSelectInfo)
    self.ids, self.sizes = {}, {}
    self.data = data
    self.start_ms = nil
    tex.load_folder("song_select", "enso_battle")
    self.partner_name = text.create_text("battle_partner_amitie", WHITE, BLACK, false, 3)
    self.stage_name = text.create_text("battle_stage_" .. data.stage, WHITE, BLACK, false, 3)
    return self
end

function BattleSelectInfo:put(key, cx, cy, o)
    o = o or {}
    local id = self.ids[key]
    if id == nil then
        id = tex.get_texture(DIR .. key)
        self.ids[key] = id
        self.sizes[key] = tex.get_texture_info("enso_battle", key)
    end
    local info = self.sizes[key]
    if not info then return end
    local sx, sy = o.sx or 1, o.sy or 1
    local w, h = info.width * S, info.height * S
    tex.draw_texture(id, {
        x = cx * S, y = cy * S,
        x2 = w * (sx - 1), y2 = h * (sy - 1),
        origin = { w * sx * 0.5, h * sy * 0.5 },
        frame = o.frame or 0,
        mirror = o.mirror,
    })
end

function BattleSelectInfo:digits(key, value, ones_x, y, step)
    value = math.max(0, math.floor(value))
    local x = ones_x
    repeat
        self:put(key, x, y, { frame = value % 10 })
        value = value // 10
        x = x - step
    until value == 0
end

local function digit_count(value)
    return #tostring(math.max(0, math.floor(value)))
end

local function draw_label(label, cx, cy, max_width)
    local squash = max_width and math.max(0, label.width - max_width * S) or 0
    label:draw({ x = cx * S - (label.width - squash) / 2, y = cy * S - label.height / 2, x2 = -squash })
end

function BattleSelectInfo:draw_partner(f)
    local d = self.data
    local side = d.player == 2 and 2 or 1
    local slide = SLIDE_FROM * (1 - clamp01(f / SLIDE_FRAMES)) * (side == 2 and -1 or 1)
    local bob = triangle(f, BOB_FRAMES)
    local px, py = PARTNER[side][1] + slide, PARTNER[side][2]
    local mirror = side == 2 and "horizontal" or nil
    self:put("partner_body", px, py + 3 * bob, { sy = 1 - 0.037 * bob, mirror = mirror })
    self:put("partner_front", px, py + 5 * bob, { mirror = mirror })

    local cx, cy = CARD[side][1] + slide, CARD[side][2]
    self:put("card", cx, cy, { frame = side - 1 })
    draw_label(self.partner_name, cx, cy - 55, 116)
    self:digits("card_digits", d.bond, cx + (d.bond < 10 and 29 or 35), cy - 27, 13)
    local fill = d.exp_next > 0 and clamp01(d.exp / d.exp_next) or 1
    self:put("exp_back", cx, cy - 7)
    if fill > 0 then
        self:put("exp_fill", cx - 60.7 + EXP_FULL_WIDTH * fill / 2, cy - 7.7, { sx = EXP_FULL_SCALE * fill })
    end
    self:put("exp_frame", cx, cy - 7)
    self:digits("card_digits", math.min(d.best_power, 99999), cx + 27, cy + 43, 13.5)
end

function BattleSelectInfo:draw_stage()
    local d = self.data
    local boss = d.boss_hp_max > 0
    self:put(boss and "stage_box_boss" or "stage_box", 640, 653)
    self:put("stage_thumb", 732, 652, { frame = d.stage - 1 })
    if d.stage == EX_STAGE then
        self:put("stage_ex", 530.8, 658.3)
    else
        self:digits("stage_digits", d.stage, d.stage < 10 and 531.8 or 540.8, 658.3, 19)
    end
    draw_label(self.stage_name, 627, boss and 646.3 or 657.3, STAGE_NAME_WIDTH)
    if not boss then return end
    local life = clamp01(d.boss_hp / d.boss_hp_max)
    self:put("boss_life_back", 627.9, 661.3)
    if life > 0 then
        local colour = life > 0.65 and 0 or life > 0.32 and 1 or 2
        self:put("boss_life_fill", BOSS_LIFE_RIGHT - BOSS_LIFE_WIDTH * life / 2, 663.2, { sx = life, frame = colour })
    end
    self:put("boss_life_frame", 627.8, 661.3)
end

function BattleSelectInfo:draw_token(kind, count, cost, y)
    if cost < 0 then
        self:put(kind .. "_complete", TOKEN_X, y)
        return
    end
    count, cost = math.min(count, 999), math.min(cost, 999)
    self:put(kind .. "_token", TOKEN_X, y)
    self:digits("card_digits", count, CURRENT_ONES_X[digit_count(count)], y - 1, 14)
    self:put("token_slash", 452.5, y)
    self:digits("token_digits", cost, GOAL_ONES_X[digit_count(cost)], y, 12)
end

function BattleSelectInfo:draw(ms)
    self.start_ms = self.start_ms or ms
    local f = (ms - self.start_ms) / FRAME_MS
    self:draw_stage()
    local d = self.data
    if d.orb_cost > 0 or d.orbs_done then
        self:draw_token("stone", d.stones, d.move_cost, TOKEN_Y + EVENT_STONES_DY)
        self:draw_token("orb", d.orbs, d.orbs_done and -1 or d.orb_cost, TOKEN_Y + EVENT_ORBS_DY)
    else
        self:draw_token("stone", d.stones, d.move_cost, TOKEN_Y)
    end
    self:draw_partner(f)
end
