-- The combo counter on the lane: the number (stretching on every hit), the "COMBO" label, the
-- silver / gold digit tiers and, from 100, the three glimmers sweeping over the number.
-- The engine's Combo (combo.h) calls update every frame with the player's combo; this draws it.

local SKIN_S = tex.get_screen_scale()
local SKIN = {
    color_tiers = false,   -- silver digits from 50 combo
    margin = { x = 29 * SKIN_S, y = 34 * SKIN_S },   -- digit spacing below / from 100 combo
    glimmer = {
        { x = 225 * SKIN_S, y = 210 * SKIN_S },
        { x = 200 * SKIN_S, y = 230 * SKIN_S },
        { x = 250 * SKIN_S, y = 230 * SKIN_S },
    },
}

Combo = {}
Combo.__index = Combo

local TOTAL_TIME = 250
local CYCLE_TIME = TOTAL_TIME * 2
local WHITE = { 255, 255, 255 }

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
    local lang = tex.language()
    if lang ~= self.lang then
        self.lang = lang
        self.t_combo     = tex.get_texture("combo/combo_" .. lang)
        self.t_combo_100 = tex.get_texture("combo/combo_100_" .. lang)
    end

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
    tex.draw_texture(gold and self.t_combo_100 or self.t_combo, { y = y })
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
