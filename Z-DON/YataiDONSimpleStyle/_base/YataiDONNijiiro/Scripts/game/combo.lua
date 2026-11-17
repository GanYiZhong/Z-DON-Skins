local SKIN = {
    color_tiers = true,   -- silver digits from 50 combo
    margin = { x = 52, y = 52 },
    label = { x = 400, y = 153, size = 28, outline = 4.25 },   -- centre of the label
    glimmer = {
        { x = 337.5, y = 315 },
        { x = 300, y = 345 },
        { x = 375, y = 345 },
    },
}

Combo = {}
Combo.__index = Combo

local TOTAL_TIME = 250
local CYCLE_TIME = TOTAL_TIME * 2
local WHITE = { 255, 255, 255 }
local LABEL_FILL, LABEL_RIM = { 255, 255, 255, 255 }, { 40, 20, 10, 255 }

function Combo.new(combo, current_ms)
    local self = setmetatable({}, Combo)
    self.combo = combo
    self.stretch = tex.get_animation(5, true)
    self.glimmer_fade = { 1, 1, 1 }
    self.glimmer_y = { 0, 0, 0 }
    self.start_times = {
        current_ms,
        current_ms - (2 / 3) * CYCLE_TIME,
        current_ms - (4 / 3) * CYCLE_TIME,
    }
    self.t_counter      = tex.get_texture("combo/counter")
    self.t_counter_gold = tex.get_texture("combo/counter_gold")
    self.t_counter_100  = tex.get_texture("combo/counter_100")
    self.t_gleam        = tex.get_texture("combo/gleam")
    local l = SKIN.label
    self.label = text.create_raw_text(tex.skin_text("combo_label"), l.size, LABEL_FILL, LABEL_RIM, false,
                                      l.outline, 2.0, 1.0)
    return self
end

function Combo:update(ms, combo)
    if combo ~= self.combo then
        self.combo = combo
        self.stretch:start()
    end
    self.stretch:update(ms)

    for i = 1, 3 do
        local elapsed = (ms - self.start_times[i]) % CYCLE_TIME
        if elapsed <= TOTAL_TIME then
            self.glimmer_y[i] = -math.floor(elapsed / 16.67)
            local fade_start = TOTAL_TIME - 164
            self.glimmer_fade[i] = elapsed >= fade_start and 1 - (elapsed - fade_start) / 164 or 1
        else
            self.glimmer_y[i] = 0
            self.glimmer_fade[i] = 0
        end
    end
end

function Combo:draw(y)
    if self.combo < 3 then return end
    local str = tostring(self.combo)
    local tiers = SKIN.color_tiers
    local gold = self.combo >= 100
    local silver = tiers and self.combo >= 50 and self.combo < 100

    local digits = self.t_counter
    if gold then
        digits = self.t_counter_gold or self.t_counter_100 or self.t_counter
    elseif silver then
        digits = self.t_counter_100 or self.t_counter
    end

    local margin = gold and SKIN.margin.y or SKIN.margin.x
    local stretch = self.stretch.attribute
    local l = SKIN.label
    self.label:draw({ x = l.x - self.label.width / 2, y = y + l.y - self.label.height / 2 })
    for i = 1, #str do
        tex.draw_texture(digits, {
            frame = str:byte(i) - 48, x = -(#str * margin / 2) + (i - 1) * margin,
            y = y - stretch, y2 = stretch,
        })
    end

    if not gold then return end
    for j = 1, 3 do
        local g = SKIN.glimmer[j]
        local color = { WHITE[1], WHITE[2], WHITE[3], 255 * self.glimmer_fade[j] }
        for i = 0, #str - 1 do
            tex.draw_texture(self.t_gleam, { color = color, x = g.x + i * margin, y = y + g.y + self.glimmer_y[j] })
        end
    end
end
