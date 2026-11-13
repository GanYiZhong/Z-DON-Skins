-- YataiDON-HSS override of PyTaikoGreen/background/bg_objects/fever.lua: bounce total_distance 50*screen_scale
local FEVER_EDGE_MS = 29000 / 60

local BaseFever = {}
BaseFever.__index = BaseFever

function BaseFever.new(index, bpm, path)
    local self = setmetatable({}, BaseFever)
    self.name = "fever_" .. index
    self.path = path or "background"
    tex.load_folder(self.path, "fever/" .. self.name)
    local half_beat = (60000 / bpm) / 2
    self.bounce_up = anim.move(half_beat, {total_distance = 50 * tex.get_screen_scale(), ease_out = "quadratic"})
    self.bounce_down = anim.move(half_beat, {total_distance = 50 * tex.get_screen_scale(), ease_in = "quadratic", delay = half_beat})
    self._id_overlay_l = tex.get_texture(self.path .. "/" .. self.name .. "/overlay_l")
    self._id_overlay_r = tex.get_texture(self.path .. "/" .. self.name .. "/overlay_r")
    self._id_overlay   = tex.get_texture(self.path .. "/" .. self.name .. "/overlay")
    self.active = false
    self.edge_fade = anim.fade(FEVER_EDGE_MS, {initial_opacity = 0.0, final_opacity = 0.0})
    return self
end

function BaseFever:start()
    if self.active then return end
    self.active = true
    local from = self.edge_fade and self.edge_fade.attribute or 0.0
    self.edge_fade = anim.fade(FEVER_EDGE_MS, {initial_opacity = from, final_opacity = 1.0})
    self.edge_fade:start()
    self.bounce_up:start()
    self.bounce_down:start()
end

-- Falling edge (`fever_normal`); re-arms start().
function BaseFever:stop()
    if not self.active then return end
    self.active = false
    local from = self.edge_fade and self.edge_fade.attribute or 1.0
    self.edge_fade = anim.fade(FEVER_EDGE_MS, {initial_opacity = from, final_opacity = 0.0})
    self.edge_fade:start()
end

function BaseFever:is_visible()
    if self.active then return true end
    return (self.edge_fade.attribute or 0) > 0.001 and not self.edge_fade.is_finished
end

function BaseFever:alpha()
    if self.active and self.edge_fade.is_finished then return 1.0 end
    return self.edge_fade.attribute or 0.0
end

function BaseFever:update(current_time_ms, bpm)
    self.edge_fade:update(current_time_ms)
    self.bounce_up:update(current_time_ms)
    self.bounce_down:update(current_time_ms)
    if self.bounce_down.is_finished then
        local half_beat = (60000 / bpm) / 2
        self.bounce_up = anim.move(half_beat, {total_distance = 50 * tex.get_screen_scale(), ease_out = "quadratic"})
        self.bounce_down = anim.move(half_beat, {total_distance = 50 * tex.get_screen_scale(), ease_in = "quadratic", delay = half_beat})
        self.bounce_up:start()
        self.bounce_down:start()
    end
end

function BaseFever:destroy()
    tex.unload_folder(self.path, "fever/" .. self.name)
end

local Fever0 = setmetatable({}, {__index = BaseFever})
Fever0.__index = Fever0

function Fever0.new(index, bpm, path)
    local self = setmetatable({}, Fever0)
    local base = BaseFever.new(index, bpm, path)
    for k, v in pairs(base) do self[k] = v end
    return self
end

function Fever0:draw()
    local a = self:alpha()
    if a <= 0.001 then return end
    local y = self.bounce_down.attribute - self.bounce_up.attribute
    -- fail soft when the folder shipped no art
    if self._id_overlay_l then tex.draw_texture(self._id_overlay_l, {y = y, fade = a}) end
    if self._id_overlay_r then tex.draw_texture(self._id_overlay_r, {y = y, fade = a}) end
end

-- Fever1 and Fever2 share the same draw as Fever0
local Fever1 = setmetatable({}, {__index = Fever0})
Fever1.__index = Fever1
function Fever1.new(index, bpm, path)
    local self = setmetatable({}, Fever1)
    local base = BaseFever.new(index, bpm, path)
    for k, v in pairs(base) do self[k] = v end
    return self
end
function Fever1:draw() Fever0.draw(self) end

local Fever2 = setmetatable({}, {__index = Fever0})
Fever2.__index = Fever2
function Fever2.new(index, bpm, path)
    local self = setmetatable({}, Fever2)
    local base = BaseFever.new(index, bpm, path)
    for k, v in pairs(base) do self[k] = v end
    return self
end
function Fever2:draw() Fever0.draw(self) end

local Fever3 = setmetatable({}, {__index = BaseFever})
Fever3.__index = Fever3

function Fever3.new(index, bpm, path)
    local self = setmetatable({}, Fever3)
    local base = BaseFever.new(index, bpm, path)
    for k, v in pairs(base) do self[k] = v end
    return self
end

function Fever3:draw()
    local a = self:alpha()
    if a <= 0.001 then return end
    -- fail soft on a missing fever folder
    if not self._id_overlay then return end
    local y = self.bounce_down.attribute - self.bounce_up.attribute
    tex.draw_texture(self._id_overlay, {y = y, fade = a})
end

local FeverAnim = require("background/bg_objects/fever_anim")

local Fever = {}
Fever.Base = BaseFever
Fever.Anim = FeverAnim
Fever.Fever0 = Fever0
Fever.Fever1 = Fever1
Fever.Fever2 = Fever2
Fever.Fever3 = Fever3

-- The cabinet's random pool holds two crowds, fever_effect1 and fever_effect2
-- (fever_effect0 exists but is never drawn from). When their exported movie data
-- is present that pool is the whole choice; otherwise the four flat overlays.
local ANIM_POOL = { 1, 2 }

local function anim_ready(path)
    if (path or "background") ~= "background" then return false end
    for _, n in ipairs(ANIM_POOL) do
        if not FeverAnim.available(n) then return false end
    end
    return true
end

function Fever.variant_count(path)
    if anim_ready(path) then return #ANIM_POOL end
    return 4
end

function Fever.create(index, bpm, path)
    if anim_ready(path) then
        local crowd = FeverAnim.new(ANIM_POOL[(index % #ANIM_POOL) + 1], bpm, path)
        if crowd then return crowd end
    end
    local map = {Fever0, Fever1, Fever2, Fever3}
    return map[(index % 4) + 1].new(index % 4, bpm, path)
end

return Fever
