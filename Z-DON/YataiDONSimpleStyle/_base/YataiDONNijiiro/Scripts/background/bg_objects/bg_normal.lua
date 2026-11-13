-- YataiDON-HSS override of PyTaikoGreen/background/bg_objects/bg_normal.lua: petal spawn band 260/540 *screen_scale
local BGNormalBase = {}
BGNormalBase.__index = BGNormalBase

function BGNormalBase.new(index, path)
    local self = setmetatable({}, BGNormalBase)
    self.name = "bg_" .. index
    self.path = path or "background"
    tex.load_folder(self.path, "bg_normal/" .. self.name)
    self._id_bg = tex.get_texture(self.path .. "/" .. self.name .. "/background") or 0
    return self
end

function BGNormalBase:update(current_time_ms) end

function BGNormalBase:draw()
    tex.draw_texture(self._id_bg)
end

function BGNormalBase:destroy()
    tex.unload_folder(self.path, "bg_normal/" .. self.name)
end

-- Index 0 and 1: background + flicker overlay (animation 9)
local BGNormal01 = setmetatable({}, {__index = BGNormalBase})
BGNormal01.__index = BGNormal01

function BGNormal01.new(index, path)
    local self = setmetatable({}, BGNormal01)
    local base = BGNormalBase.new(index, path)
    for k, v in pairs(base) do self[k] = v end
    self.flicker = tex.get_animation(9, "background")
    self._id_overlay = tex.get_texture(self.path .. "/" .. self.name .. "/overlay") or 0
    return self
end

function BGNormal01:update(current_time_ms)
    self.flicker:update(current_time_ms)
end

function BGNormal01:draw()
    tex.draw_texture(self._id_bg)
    tex.draw_texture(self._id_overlay, {fade = self.flicker.attribute})
end

-- Index 2: stadium lights with flicker (animation 10)
local BGNormal2 = setmetatable({}, {__index = BGNormalBase})
BGNormal2.__index = BGNormal2

function BGNormal2.new(index, path)
    local self = setmetatable({}, BGNormal2)
    local base = BGNormalBase.new(index, path)
    for k, v in pairs(base) do self[k] = v end
    self.flicker = tex.get_animation(10, "background")
    self._id_center       = tex.get_texture(self.path .. "/" .. self.name .. "/center") or 0
    self._id_overlay      = tex.get_texture(self.path .. "/" .. self.name .. "/overlay") or 0
    self._id_lamps        = tex.get_texture(self.path .. "/" .. self.name .. "/lamps") or 0
    self._id_light_orange = tex.get_texture(self.path .. "/" .. self.name .. "/light_orange") or 0
    self._id_light_red    = tex.get_texture(self.path .. "/" .. self.name .. "/light_red") or 0
    self._id_light_green  = tex.get_texture(self.path .. "/" .. self.name .. "/light_green") or 0
    self._id_light_yellow = tex.get_texture(self.path .. "/" .. self.name .. "/light_yellow") or 0
    self._id_side_l       = tex.get_texture(self.path .. "/" .. self.name .. "/side_l") or 0
    self._id_side_l_2     = tex.get_texture(self.path .. "/" .. self.name .. "/side_l_2") or 0
    return self
end

function BGNormal2:update(current_time_ms)
    self.flicker:update(current_time_ms)
end

function BGNormal2:draw()
    local f = self.flicker.attribute
    tex.draw_texture(self._id_bg)
    tex.draw_texture(self._id_center)
    tex.draw_texture(self._id_overlay)
    tex.draw_texture(self._id_lamps, {index = 0})
    tex.draw_texture(self._id_lamps, {index = 1, mirror = "horizontal"})
    tex.draw_texture(self._id_light_orange, {index = 0, fade = f})
    tex.draw_texture(self._id_light_orange, {index = 1, fade = f})
    tex.draw_texture(self._id_light_red,    {fade = f})
    tex.draw_texture(self._id_light_green,  {fade = f})
    tex.draw_texture(self._id_light_orange, {index = 2, fade = f})
    tex.draw_texture(self._id_light_yellow, {index = 0, fade = f})
    tex.draw_texture(self._id_light_yellow, {index = 1, fade = f})
    tex.draw_texture(self._id_side_l)
    tex.draw_texture(self._id_side_l_2)
end

-- Index 3: cherry blossoms with petals (animation 11)
local function new_petal(screen_scale, screen_width, screen_height)
    local spawn_point
    repeat
        spawn_point = math.random(0, math.floor(screen_width))
    until spawn_point < 260 * screen_scale or spawn_point > 540 * screen_scale

    local duration = math.random(1400, 2000)
    local dist_x = math.random(math.floor(-300 * screen_scale), math.floor(300 * screen_scale))

    local petal = {
        spawn_point = spawn_point,
        move_x = anim.move(duration, {total_distance = dist_x}),
        move_y = anim.move(duration, {total_distance = math.floor(screen_height / 2)})
    }
    petal.move_x:start()
    petal.move_y:start()
    return petal
end

local BGNormal3 = setmetatable({}, {__index = BGNormalBase})
BGNormal3.__index = BGNormal3

function BGNormal3.new(index, path)
    local self = setmetatable({}, BGNormal3)
    local base = BGNormalBase.new(index, path)
    for k, v in pairs(base) do self[k] = v end
    self.flicker = tex.get_animation(11, "background")
    self.screen_scale = tex.get_screen_scale()
    self.screen_width = tex.get_screen_width()
    self.screen_height = tex.get_screen_height()
    self.petals = {}
    for _ = 1, 5 do
        table.insert(self.petals, new_petal(self.screen_scale, self.screen_width, self.screen_height))
    end
    self._id_overlay= tex.get_texture(self.path .. "/" .. self.name .. "/overlay") or 0
    self._id_petal  = tex.get_texture(self.path .. "/" .. self.name .. "/petal") or 0
    return self
end

function BGNormal3:update(current_time_ms)
    self.flicker:update(current_time_ms)
    for i = #self.petals, 1, -1 do
        local petal = self.petals[i]
        petal.move_x:update(current_time_ms)
        petal.move_y:update(current_time_ms)
        if petal.move_y.is_finished then
            table.remove(self.petals, i)
            table.insert(self.petals, new_petal(self.screen_scale, self.screen_width, self.screen_height))
        end
    end
end

function BGNormal3:draw()
    tex.draw_texture(self._id_bg)
    tex.draw_texture(self._id_overlay)
    for _, petal in ipairs(self.petals) do
        tex.draw_texture(self._id_petal, {
            x = petal.spawn_point + petal.move_x.attribute,
            y = self.screen_height / 2 + petal.move_y.attribute,
            fade = 0.75
        })
    end
end

-- Index 4: paper lanterns with flicker (animation 14)
local BGNormal4 = setmetatable({}, {__index = BGNormalBase})
BGNormal4.__index = BGNormal4

local GLOW_HALF_MS = 25000 / 60  -- 25 cabinet frames

function BGNormal4.new(index, path)
    local self = setmetatable({}, BGNormal4)
    local base = BGNormalBase.new(index, path)
    for k, v in pairs(base) do self[k] = v end
    self.glow_phase_ms = 0
    self.glow_last_ms  = nil
    self._id_light_overlay= tex.get_texture(self.path .. "/" .. self.name .. "/light_overlay") or 0
    self._id_overlay      = tex.get_texture(self.path .. "/" .. self.name .. "/overlay") or 0
    self._id_lamp_overlay = tex.get_texture(self.path .. "/" .. self.name .. "/lamp_overlay") or 0
    self._id_lamp         = tex.get_texture(self.path .. "/" .. self.name .. "/lamp") or 0
    return self
end

function BGNormal4:update(current_time_ms)
    if self.glow_last_ms then
        local dt = current_time_ms - self.glow_last_ms
        if dt > 0 then
            self.glow_phase_ms = (self.glow_phase_ms + dt) % (2 * GLOW_HALF_MS)
        end
    end
    self.glow_last_ms = current_time_ms
end

-- {scale, mirrored}   index 0..9 == texture.json light_overlay entry 0..9
local BG4_GLOW = {
    {0.95, true}, {1.25, true}, {1.00, true}, {1.15, true}, {0.90, true},
    {0.90, false}, {1.10, false}, {1.05, false}, {1.25, false}, {1.00, false},
}

function BGNormal4:draw()
    tex.draw_texture(self._id_bg)
    local p = self.glow_phase_ms / GLOW_HALF_MS       -- 0..2
    if p > 1 then p = 2 - p end                        -- triangle 0..1..0
    local ga = 0.5 - p * (0.5 - 0.164)                 -- 0.5 dim to 0.164, back
    if ga < 0 then ga = 0 elseif ga > 1 then ga = 1 end
    for i = 0, 9 do
        local g = BG4_GLOW[i + 1]
        tex.draw_texture(self._id_light_overlay, {
            index = i, fade = ga, scale = g[1],
            mirror = g[2] and "horizontal" or "none",
        })
    end
    -- shape 8 (the eave glow) and shape 3 (the stone-lantern glows) are additive at
    -- full alpha on the cabinet, not 0.75 alpha-blended.
    tex.draw_texture(self._id_overlay)
    tex.draw_texture(self._id_lamp_overlay, {index = 0})
    tex.draw_texture(self._id_lamp_overlay, {index = 1})
    tex.draw_texture(self._id_lamp, {index = 0})
    tex.draw_texture(self._id_lamp, {index = 1})
end

local BGNormal = {}
BGNormal.Base = BGNormalBase
BGNormal.BGNormal2 = BGNormal2

-- Exact replay of the cabinet movie when bg_data/bg_anim/bg_N.lua is exported;
-- the hand-built classes below stay as the fallback.
local ok_anim, BGAnim = pcall(require, "background/bg_objects/bg_anim")
if not ok_anim or type(BGAnim) ~= "table" then BGAnim = nil end

local BGNormalAnim = {}
BGNormalAnim.__index = BGNormalAnim
-- name: a collab pack's backdrop ("b_001_n"); nil for the default bg_<index>
function BGNormalAnim.new(index, path, name)
    name = name or ("bg_" .. index)
    local anim = BGAnim.new(name, path)
    if not anim then return nil end
    return setmetatable({ anim = anim, name = name }, BGNormalAnim)
end
function BGNormalAnim:update(current_time_ms) self.anim:update(current_time_ms) end
function BGNormalAnim:draw() self.anim:draw(1.0) end
function BGNormalAnim:destroy() self.anim:destroy() end

function BGNormal.create(index, path)
    if BGAnim and (path or "background") == "background" and BGAnim.available("bg_" .. index) then
        local obj = BGNormalAnim.new(index, path)
        if obj then return obj end
    end
    local map = {BGNormal01, BGNormal01, BGNormal2, BGNormal3, BGNormal4}
    return map[index + 1].new(index, path)
end

-- a collab pack's backdrop, replayed from its exported movie; nil when it is missing
function BGNormal.create_named(name, path)
    if not BGAnim then return nil end
    return BGNormalAnim.new(nil, path, name)
end

return BGNormal
