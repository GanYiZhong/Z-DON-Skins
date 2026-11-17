BattleSkillPicker = {}
BattleSkillPicker.__index = BattleSkillPicker

local S = tex.get_screen_scale()
local FRAME_MS = 1000 / 60
local DIR = "song_select/enso_battle/"

local SIDE_X = { 0, 850 }
local SIDE_Y = { 0, -8 }
local PANEL_DROP = 648
local PARTNER_DROP = 637
local SLIDE_IN = { hold = 3, rise = 17, settle = 22, overshoot = -59 }
local PARTNER_IN = { hold = 6, rise = 18, settle = 24, overshoot = -94 }
local SLIDE_OUT_FRAMES = 20
local PARTNER = { 93.5, 227 }
local BOB_FRAMES = 35
local ROW_Y = { 583, 631, 679 }
local ROW_X, NAME_X, LABEL_X = 230, 223, 74
local ARROW_X = { 113.6, 349.5 }
local ARROW_DRIFT, ARROW_FRAMES = 9, 89
local NAME_SHIFT, NAME_FRAMES = 20, 9
local COUNTER_Y, CURRENT_ONES_X, TOTAL_FIRST_X, DIGIT_STEP = 363.5, 198, 228.5, 14

local function clamp01(v) return math.max(0, math.min(1, v)) end
local function lerp(a, b, t) return a + (b - a) * clamp01(t) end
local function triangle(f, period) return 1 - math.abs(2 * (f % period) / period - 1) end

local function rise(f, track, drop)
    if f < track.hold then return drop end
    if f < track.rise then return lerp(drop, track.overshoot, (f - track.hold) / (track.rise - track.hold)) end
    return lerp(track.overshoot, 0, (f - track.rise) / (track.settle - track.rise))
end

-- the cursor outline fades in over 60 frames, holds, and fades out by 179
local function outline_fade(f)
    f = f % 179
    if f < 60 then return f / 60 end
    if f < 120 then return 1 end
    return 1 - (f - 120) / 59
end

function BattleSkillPicker.new(data)
    local self = setmetatable({}, BattleSkillPicker)
    self.ids, self.sizes = {}, {}
    self.side = data.player == 2 and 2 or 1
    self.state = nil
    tex.load_folder("song_select", "enso_battle")
    return self
end

function BattleSkillPicker:put(key, cx, cy, o)
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
        fade = o.fade or 1,
    })
end

function BattleSkillPicker:open(ms, slots, number, total)
    self.state = "open"
    self.open_ms, self.cursor_ms = ms, ms
    self.slots = { slots[1], slots[2], slots[3] }
    self.slot, self.number, self.total = 1, number, total
    self.change = nil
end

function BattleSkillPicker:move(ms, slot, move, number, dir)
    local i = slot + 1
    self.change = { slot = i, from = self.slots[i], dir = dir, ms = ms }
    self.slots[i], self.number = move, number
end

function BattleSkillPicker:decide(ms, slot, next_number)
    self.slot, self.number, self.cursor_ms, self.change = slot + 2, next_number, ms, nil
    if self.slot > #ROW_Y then
        self.state, self.close_ms = "closing", ms
    end
end

function BattleSkillPicker:draw_counter(x, y)
    local n, total = math.min(self.number, 99), math.min(self.total, 99)
    self:put("skill_digits", x + CURRENT_ONES_X, y + COUNTER_Y, { frame = n % 10 })
    if n >= 10 then self:put("skill_digits", x + CURRENT_ONES_X - DIGIT_STEP, y + COUNTER_Y, { frame = n // 10 }) end
    self:put("skill_slash", x + 214.5, y + COUNTER_Y)
    if total >= 10 then
        self:put("skill_digits", x + TOTAL_FIRST_X, y + COUNTER_Y, { frame = total // 10 })
        self:put("skill_digits", x + TOTAL_FIRST_X + DIGIT_STEP, y + COUNTER_Y, { frame = total % 10 })
    else
        self:put("skill_digits", x + TOTAL_FIRST_X, y + COUNTER_Y, { frame = total })
    end
end

function BattleSkillPicker:draw_name(i, x, y, ms)
    local c = self.change
    local t = c and c.slot == i and (ms - c.ms) / FRAME_MS / NAME_FRAMES or 1
    if t < 1 then
        self:put("skill_name", x + NAME_X - NAME_SHIFT * c.dir * t, y + ROW_Y[i], { frame = c.from, fade = 1 - t })
        self:put("skill_name", x + NAME_X + NAME_SHIFT * c.dir * (1 - t), y + ROW_Y[i],
            { frame = self.slots[i], fade = t })
    else
        self:put("skill_name", x + NAME_X, y + ROW_Y[i], { frame = self.slots[i] })
    end
end

function BattleSkillPicker:draw_rows(x, y, ms)
    local cursor_f = (ms - self.cursor_ms) / FRAME_MS
    for i, row_y in ipairs(ROW_Y) do
        self:put("skill_slot_label", x + LABEL_X, y + row_y, { frame = i - 1 })
        if i < self.slot then
            self:put("skill_row", x + ROW_X, y + row_y, { fade = 0.6 })
        else
            self:put("skill_row_open", x + ROW_X, y + row_y)
            self:put("skill_row_cursor", x + ROW_X, y + row_y, { fade = outline_fade(cursor_f) })
        end
        if i == self.slot then
            local drift = ARROW_DRIFT * (cursor_f % ARROW_FRAMES) / ARROW_FRAMES
            local fade = 1 - (cursor_f % ARROW_FRAMES) / ARROW_FRAMES
            self:put("skill_arrow", x + ARROW_X[1] - drift, y + row_y, { mirror = "horizontal", fade = fade })
            self:put("skill_arrow", x + ARROW_X[2] + drift, y + row_y, { fade = fade })
        end
        self:draw_name(i, x, y, ms)
    end
end

function BattleSkillPicker:draw(ms)
    if not self.state then return end
    local f = (ms - self.open_ms) / FRAME_MS
    local panel_dy, partner_dy, fade = rise(f, SLIDE_IN, PANEL_DROP), rise(f, PARTNER_IN, PARTNER_DROP), 1
    if self.state == "closing" then
        local t = (ms - self.close_ms) / FRAME_MS / SLIDE_OUT_FRAMES
        if t >= 1 then
            self.state = nil
            return
        end
        panel_dy, partner_dy, fade = PANEL_DROP * t * t, PARTNER_DROP * t * t, 1 - t
    end
    local x, y = SIDE_X[self.side], SIDE_Y[self.side]
    local mirror = self.side == 2 and "horizontal" or nil
    local px = x + (self.side == 2 and 308.5 or PARTNER[1])
    local bob = triangle(f, BOB_FRAMES)
    local py = y + PARTNER[2] + partner_dy
    self:put("partner_body", px, py + 3 * bob, { sy = 1 - 0.04 * bob, mirror = mirror, fade = fade })
    self:put("partner_front", px, py + 3 * bob - 1, { sy = 1 - 0.04 * bob, mirror = mirror, fade = fade })

    y = y + panel_dy
    self:put("skill_panel_top", x + 213, y + 281)
    self:put("skill_panel_body", x + 213, y + 544, { sy = 57.75 })
    self:put("skill_title", x + 212, y + 330)
    self:put("skill_badge", x + 70, y + 330, { frame = self.side - 1 })
    self:draw_counter(x, y)
    self:draw_rows(x, y, ms)
    local shown = self.slots[math.min(self.slot, #ROW_Y)]
    self:put("skill_preview", x + 213, y + 464, { frame = shown })
end
