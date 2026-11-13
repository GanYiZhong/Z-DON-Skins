local move = require("background/bg_objects/timing").move_lua

local BGNormalBase = {}
BGNormalBase.__index = BGNormalBase

function BGNormalBase.new(index, path)
    local self = setmetatable({}, BGNormalBase)
    self.name = "bg_" .. index
    self.path = path or "background"
    tex.load_folder(self.path, "bg_normal/" .. self.name)
    self._id_bg = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "background") or 0
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
    self._id_overlay = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "overlay") or 0
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
    self._id_center       = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "center") or 0
    self._id_overlay      = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "overlay") or 0
    self._id_lamps        = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "lamps") or 0
    self._id_light_orange = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "light_orange") or 0
    self._id_light_red    = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "light_red") or 0
    self._id_light_green  = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "light_green") or 0
    self._id_light_yellow = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "light_yellow") or 0
    self._id_side_l       = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "side_l") or 0
    self._id_side_l_2     = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "side_l_2") or 0
    self._id_side_r       = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "side_r") or 0
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
    tex.draw_texture(self._id_side_r)
end

-- Index 3: cherry blossoms with turtle and petals (animations 11, 12, 13)
local function new_petal(screen_scale, screen_width, screen_height)
    local spawn_point
    repeat
        spawn_point = math.random(0, math.floor(screen_width))
    until spawn_point < 260 or spawn_point > 540

    local duration = math.random(1400, 2000)
    local dist_x = math.random(math.floor(-300 * screen_scale), math.floor(300 * screen_scale))

    local petal = {
        spawn_point = spawn_point,
        move_x = move(duration, {total_distance = dist_x}),
        move_y = move(duration, {total_distance = math.floor(screen_height / 2)})
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
    self.turtle_move = tex.get_animation(12, "background")
    self.turtle_change = tex.get_animation(13, "background")
    self.screen_scale = tex.get_screen_scale()
    self.screen_width = tex.get_screen_width()
    self.screen_height = tex.get_screen_height()
    self.petals = {}
    for _ = 1, 5 do
        table.insert(self.petals, new_petal(self.screen_scale, self.screen_width, self.screen_height))
    end
    self._id_chara  = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "chara") or 0
    self._id_turtle = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "turtle") or 0
    self._id_overlay= tex.get_texture(self.path .. "/" .. self.name .. "/" .. "overlay") or 0
    self._id_petal  = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "petal") or 0
    return self
end

function BGNormal3:update(current_time_ms)
    self.flicker:update(current_time_ms)
    self.turtle_move:update(current_time_ms)
    self.turtle_change:update(current_time_ms)
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
    tex.draw_texture(self._id_chara)
    tex.draw_texture(self._id_turtle, {
        frame = self.turtle_change.attribute,
        x = self.turtle_move.attribute
    })
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

function BGNormal4.new(index, path)
    local self = setmetatable({}, BGNormal4)
    local base = BGNormalBase.new(index, path)
    for k, v in pairs(base) do self[k] = v end
    self.flicker = tex.get_animation(14, "background")
    self._id_paper_lamp   = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "paper_lamp") or 0
    self._id_light_overlay= tex.get_texture(self.path .. "/" .. self.name .. "/" .. "light_overlay") or 0
    self._id_overlay      = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "overlay") or 0
    self._id_lamp_overlay = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "lamp_overlay") or 0
    self._id_lamp         = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "lamp") or 0
    return self
end

function BGNormal4:update(current_time_ms)
    self.flicker:update(current_time_ms)
end

function BGNormal4:draw()
    local f = self.flicker.attribute
    tex.draw_texture(self._id_bg)
    for i = 0, 9 do
        tex.draw_texture(self._id_paper_lamp, {frame = 9 - i, index = i})
    end
    for i = 0, 9 do
        tex.draw_texture(self._id_light_overlay, {index = i, fade = f})
    end
    tex.draw_texture(self._id_overlay,      {fade = 0.75})
    tex.draw_texture(self._id_lamp_overlay, {index = 0, fade = 0.75})
    tex.draw_texture(self._id_lamp_overlay, {index = 1, fade = 0.75})
    tex.draw_texture(self._id_lamp, {index = 0})
    tex.draw_texture(self._id_lamp, {index = 1})
end

local BGNormal = {}
BGNormal.Base = BGNormalBase
BGNormal.BGNormal2 = BGNormal2

function BGNormal.create(index, path)
    local map = {BGNormal01, BGNormal01, BGNormal2, BGNormal3, BGNormal4}
    return map[index + 1].new(index, path)
end

return BGNormal
