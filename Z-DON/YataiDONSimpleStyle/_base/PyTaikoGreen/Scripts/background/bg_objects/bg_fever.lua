local BGFeverBase = {}
BGFeverBase.__index = BGFeverBase

function BGFeverBase.new(index, path)
    local self = setmetatable({}, BGFeverBase)
    self.name = "bg_fever_" .. index
    self.path = path or "background"
    tex.load_folder(self.path, "bg_fever/" .. self.name)
    self.transitioned = false
    return self
end

function BGFeverBase:start() end
function BGFeverBase:update(current_time_ms) end
function BGFeverBase:draw() end

function BGFeverBase:destroy()
    tex.unload_folder(self.path, "bg_fever/" .. self.name)
end

-- BGFever0: expanding tiles with wave orbiting a circle (animations 28-30)
local BGFever0 = setmetatable({}, {__index = BGFeverBase})
BGFever0.__index = BGFever0

function BGFever0.new(index, path)
    local self = setmetatable({}, BGFever0)
    local base = BGFeverBase.new(index, path)
    for k, v in pairs(base) do self[k] = v end

    self.screen_scale = tex.get_screen_scale()
    self.screen_height = tex.get_screen_height()

    self.wait = 0
    self.bg_tiles = {}

    -- Copies of anim 29/30 with increasing delays for corner/footer/mountain/overlay
    -- anim 29: move 133ms, distance 360, ease_out quadratic
    -- anim 30: move 133ms, distance 160, ease_in quadratic, delay=133
    self.corner_move_up   = anim.move(133, {total_distance = 360, ease_out = "quadratic"})
    self.corner_move_down = anim.move(133, {total_distance = 160, ease_in = "quadratic", delay = 133})
    self.footer_move_up   = anim.move(133, {total_distance = 360, ease_out = "quadratic", delay = 100})
    self.footer_move_down = anim.move(133, {total_distance = 160, ease_in = "quadratic", delay = 233})
    self.mountain_move_up   = anim.move(133, {total_distance = 360, ease_out = "quadratic", delay = 200})
    self.mountain_move_down = anim.move(133, {total_distance = 160, ease_in = "quadratic", delay = 333})
    self.overlay_move_up   = anim.move(133, {total_distance = 360, ease_out = "quadratic", delay = 300})
    self.overlay_move_down = anim.move(133, {total_distance = 160, ease_in = "quadratic", delay = 433})

    self.wave_spin = tex.get_animation(28, "background")
    self.bg_move = tex.get_animation(16, "background")

    local bg_info = tex.get_texture_info(self.name, "background")
    self.bg_width = bg_info and bg_info.width or 0
    local wave_info = tex.get_texture_info(self.name, "wave")
    self.wave_origin = {
        (wave_info and wave_info.width or 0) / 2,
        (wave_info and wave_info.height or 0) / 2
    }

    self.circle = {
        center_x = 100 * self.screen_scale,
        center_y = 130 * self.screen_scale,
        radius   = 200 * self.screen_scale
    }

    self._id_bg       = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "background") or 0
    self._id_mountain = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "mountain") or 0
    self._id_wave     = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "wave") or 0
    self._id_footer   = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "footer") or 0
    self._id_corner   = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "corner") or 0
    self._id_overlay  = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "overlay") or 0

    return self
end

function BGFever0:_get_wave_position()
    local normalized = (self.wave_spin.attribute % 180) / 180.0
    local angle = normalized * 2 * math.pi
    local x = self.circle.center_x + math.cos(angle) * self.circle.radius
    local y = self.circle.center_y + math.sin(angle) * self.circle.radius
    return x, y
end

function BGFever0:_new_tile()
    local expansion = anim.move(166 * self.screen_scale, {
        total_distance = math.floor(self.screen_height / 2)
    })
    expansion:start()
    return {expansion = expansion}
end

function BGFever0:start()
    self.corner_move_up:start()
    self.corner_move_down:start()
    self.footer_move_up:start()
    self.footer_move_down:start()
    self.mountain_move_up:start()
    self.mountain_move_down:start()
    self.overlay_move_up:start()
    self.overlay_move_down:start()
end

function BGFever0:update(current_time_ms)
    if #self.bg_tiles < 20 and current_time_ms >= self.wait + 66 then
        table.insert(self.bg_tiles, self:_new_tile())
        self.wait = current_time_ms
    end
    for _, tile in ipairs(self.bg_tiles) do
        tile.expansion:update(current_time_ms)
    end
    self.corner_move_up:update(current_time_ms)
    self.corner_move_down:update(current_time_ms)
    self.footer_move_up:update(current_time_ms)
    self.footer_move_down:update(current_time_ms)
    self.mountain_move_up:update(current_time_ms)
    self.mountain_move_down:update(current_time_ms)
    self.overlay_move_up:update(current_time_ms)
    self.overlay_move_down:update(current_time_ms)
    self.wave_spin:update(current_time_ms)

    local fully_expanded = self.overlay_move_down.is_finished and #self.bg_tiles == 20
    if fully_expanded and not self.transitioned then
        self.bg_move:restart()
    end
    self.transitioned = fully_expanded
    if self.transitioned then
        self.bg_move:update(current_time_ms)
    end
end

function BGFever0:draw()
    local bg_width = self.bg_width
    local sh = self.screen_height

    for i, tile in ipairs(self.bg_tiles) do
        local exp = tile.expansion.attribute
        tex.draw_texture(self._id_bg, {
            frame = (i - 1) % 10,
            x = ((i - 1) * bg_width) - self.bg_move.attribute,
            y = sh / 2 + (sh / 4 - exp / 2),
            y2 = -sh / 2 + exp
        })
    end

    local corner_y = -self.corner_move_up.attribute + self.corner_move_down.attribute
    local footer_y = -self.footer_move_up.attribute + self.footer_move_down.attribute
    local mountain_y = -self.mountain_move_up.attribute + self.mountain_move_down.attribute
    local overlay_y = self.overlay_move_up.attribute - self.overlay_move_down.attribute

    tex.draw_texture(self._id_mountain, {y = mountain_y})
    local wave_x, wave_y = self:_get_wave_position()
    tex.draw_texture(self._id_wave, {x = wave_x, y = wave_y, origin = self.wave_origin})
    tex.draw_texture(self._id_footer,  {y = footer_y})
    tex.draw_texture(self._id_corner,  {y = corner_y})
    tex.draw_texture(self._id_overlay, {y = overlay_y})
end

-- BGFever1: ship swooping in (animations 19-23)
local BGFever1 = setmetatable({}, {__index = BGFeverBase})
BGFever1.__index = BGFever1

function BGFever1.new(index, path)
    local self = setmetatable({}, BGFever1)
    local base = BGFeverBase.new(index, path)
    for k, v in pairs(base) do self[k] = v end

    self.fadein = tex.get_animation(19, "background")
    self.bg_texture_change = tex.get_animation(20, "background")
    self.ship_rotation = tex.get_animation(21, "background")
    self.move_in = tex.get_animation(22, "background")

    local ship_info = tex.get_texture_info(self.name, "ship")
    self.ship_origin = {
        (ship_info and ship_info.width or 0) / 2,
        (ship_info and ship_info.height or 0) / 2
    }

    self._id_bg       = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "background") or 0
    self._id_footer_3 = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "footer_3") or 0
    self._id_footer_1 = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "footer_1") or 0
    self._id_footer_2 = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "footer_2") or 0
    self._id_bird     = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "bird") or 0
    self._id_ship     = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "ship") or 0
    return self
end

function BGFever1:start()
    self.fadein:start()
    self.move_in:start()
end

function BGFever1:update(current_time_ms)
    self.fadein:update(current_time_ms)
    self.bg_texture_change:update(current_time_ms)
    self.ship_rotation:update(current_time_ms)
    self.move_in:update(current_time_ms)
    self.transitioned = self.move_in.is_finished
end

function BGFever1:draw()
    local move = self.move_in.attribute
    local fade = self.fadein.attribute
    local spin = self.ship_rotation.attribute

    tex.draw_texture(self._id_bg,       {frame = self.bg_texture_change.attribute, fade = fade})
    tex.draw_texture(self._id_footer_3, {y = move, fade = fade})
    tex.draw_texture(self._id_footer_1, {y = move, fade = fade})
    tex.draw_texture(self._id_footer_2, {y = move, fade = fade})
    tex.draw_texture(self._id_bird, {index = 0, x = move, mirror = "horizontal", y = spin * 180})
    tex.draw_texture(self._id_bird, {index = 1, x = -move, y = spin * 180})
    tex.draw_texture(self._id_ship, {
        x = self.ship_origin[1],
        y = self.ship_origin[2] + move,
        origin = self.ship_origin,
        rotation = spin * 100,
        center = true
    })
end

-- BGFever2: fish orbiting a circle (animations 19-20, 24-28)
local BGFever2 = setmetatable({}, {__index = BGFeverBase})
BGFever2.__index = BGFever2

function BGFever2.new(index, path)
    local self = setmetatable({}, BGFever2)
    local base = BGFeverBase.new(index, path)
    for k, v in pairs(base) do self[k] = v end

    self.screen_scale = tex.get_screen_scale()

    self.fadein = tex.get_animation(19, "background")
    self.move_in = tex.get_animation(24, "background")
    self.footer_move_up = tex.get_animation(26, "background")
    self.bird_tc = tex.get_animation(20, "background")
    self.overlay_tc = tex.get_animation(25, "background")
    self.circle_rotate = tex.get_animation(27, "background")
    self.fish_spin = tex.get_animation(28, "background")

    self.circle = {
        center_x = 500 * self.screen_scale,
        center_y = 300 * self.screen_scale,
        radius   = 300 * self.screen_scale
    }
    self.num_fish = 8
    self.fish_spacing = (2 * math.pi) / self.num_fish
    self.fish_phase_offsets = {}
    for i = 0, self.num_fish - 1 do
        self.fish_phase_offsets[i + 1] = i * self.fish_spacing
    end

    local wave_info = tex.get_texture_info(self.name, "wave")
    self.wave_origin = {
        (wave_info and wave_info.width or 0) / 2,
        (wave_info and wave_info.height or 0) / 2
    }
    local fish_info = tex.get_texture_info(self.name, "fish")
    self.fish_origin = {
        (fish_info and fish_info.width or 0) / 2,
        (fish_info and fish_info.height or 0) / 2
    }
    local circle_info = tex.get_texture_info(self.name, "circle")
    self.circle_origin = {
        (circle_info and circle_info.width or 0) / 2,
        (circle_info and circle_info.height or 0) / 2
    }

    self._id_bg       = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "background") or 0
    self._id_overlay  = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "overlay") or 0
    self._id_circle   = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "circle") or 0
    self._id_wave     = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "wave") or 0
    self._id_fish     = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "fish") or 0
    self._id_footer_2 = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "footer_2") or 0
    self._id_footer_1 = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "footer_1") or 0
    self._id_bird     = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "bird") or 0
    return self
end

function BGFever2:_get_main_position(spin_value, multiplier)
    multiplier = multiplier or 1.0
    local normalized = ((spin_value * multiplier) % 360) / 360.0
    local angle = normalized * 2 * math.pi
    local x = self.circle.center_x + math.cos(angle) * self.circle.radius
    local y = self.circle.center_y + math.sin(angle) * self.circle.radius
    return x, y
end

function BGFever2:_get_small_position(spin_value, multiplier)
    multiplier = multiplier or 1.0
    local normalized = ((spin_value * multiplier) % 360) / 360.0
    local angle = normalized * 2 * math.pi
    local x = self.circle.center_x + math.cos(angle) * 20
    local y = self.circle.center_y + math.sin(angle) * 20
    return x, y
end

function BGFever2:_get_fish_pos_and_rot(spin_value, phase_offset)
    local angle_deg = spin_value + math.deg(phase_offset)
    local normalized = (angle_deg % 360) / 360.0
    local angle = normalized * 2 * math.pi
    local x = self.circle.center_x + math.cos(angle) * self.circle.radius
    local y = self.circle.center_y + math.sin(angle) * self.circle.radius
    local rotation = math.deg(angle + math.pi / 2)
    return x, y, rotation
end

function BGFever2:start()
    self.fadein:start()
    self.move_in:start()
    self.footer_move_up:start()
end

function BGFever2:update(current_time_ms)
    self.fadein:update(current_time_ms)
    self.move_in:update(current_time_ms)
    self.bird_tc:update(current_time_ms)
    self.overlay_tc:update(current_time_ms)
    self.footer_move_up:update(current_time_ms)
    self.circle_rotate:update(current_time_ms)
    self.fish_spin:update(current_time_ms)
    self.transitioned = self.move_in.is_finished
end

function BGFever2:draw()
    local fade = self.fadein.attribute
    local spin = self.fish_spin.attribute
    local sc = self.screen_scale

    tex.draw_texture(self._id_bg,      {x = -self.move_in.attribute})
    tex.draw_texture(self._id_overlay, {frame = self.overlay_tc.attribute, fade = fade})
    tex.draw_texture(self._id_circle,  {
        x = self.circle_origin[1], y = self.circle_origin[2],
        fade = fade, origin = self.circle_origin, rotation = self.circle_rotate.attribute
    })

    local wave_x, wave_y = self:_get_main_position(spin, 2.0)
    tex.draw_texture(self._id_wave, {x = wave_x, y = wave_y, fade = fade, origin = self.wave_origin})

    for j = 0, 1 do
        for _, phase in ipairs(self.fish_phase_offsets) do
            local fx, fy, frot = self:_get_fish_pos_and_rot(spin, phase)
            tex.draw_texture(self._id_fish, {
                x = fx, y = fy, fade = fade,
                origin = self.fish_origin, rotation = frot, index = j
            })
        end
    end

    local fw_x, fw_y = self:_get_small_position(spin, 3.0)
    for i = 0, 2 do
        tex.draw_texture(self._id_footer_2, {
            x = fw_x + (i * 600 * sc), y = fw_y,
            fade = fade, origin = self.wave_origin
        })
    end
    for i = 0, 2 do
        tex.draw_texture(self._id_footer_1, {x = i * 450, y = -self.footer_move_up.attribute})
    end
    tex.draw_texture(self._id_bird, {frame = self.bird_tc.attribute, index = 0, x = -self.move_in.attribute})
    tex.draw_texture(self._id_bird, {frame = self.bird_tc.attribute, index = 1, x = -self.move_in.attribute})
end

-- BGFever3: scrolling tiled background (animations 15-18)
local BGFever3 = setmetatable({}, {__index = BGFeverBase})
BGFever3.__index = BGFever3

function BGFever3.new(index, path)
    local self = setmetatable({}, BGFever3)
    local base = BGFeverBase.new(index, path)
    for k, v in pairs(base) do self[k] = v end

    self.vertical_move = tex.get_animation(15, "background")
    self.horizontal_move = tex.get_animation(16, "background")
    self.bg_texture_move = tex.get_animation(17, "background")

    local bg_info = tex.get_texture_info(self.name, "background")
    self.bg_width = bg_info and bg_info.width or 0
    local o2_info = tex.get_texture_info(self.name, "overlay_2")
    self.o2_width = o2_info and o2_info.width or 0

    self._id_bg        = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "background") or 0
    self._id_overlay_1 = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "overlay_1") or 0
    self._id_overlay_2 = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "overlay_2") or 0
    return self
end

function BGFever3:start()
    self.bg_texture_move:start()
end

function BGFever3:update(current_time_ms)
    self.bg_texture_move:update(current_time_ms)
    if self.bg_texture_move.is_finished and not self.transitioned then
        self.transitioned = true
        self.vertical_move:restart()
        self.horizontal_move:restart()
    end
    if self.transitioned then
        self.vertical_move:update(current_time_ms)
        self.horizontal_move:update(current_time_ms)
    end
end

function BGFever3:draw()
    local bg_width = self.bg_width
    local y = self.bg_texture_move.attribute

    for i = 0, bg_width * 12, bg_width do
        tex.draw_texture(self._id_bg, {x = i, y = y})
    end

    tex.draw_texture(self._id_overlay_1, {y = -self.vertical_move.attribute - y})

    tex.draw_texture(self._id_overlay_2, {x = -self.horizontal_move.attribute, y = y})
    tex.draw_texture(self._id_overlay_2, {x = self.o2_width - self.horizontal_move.attribute, y = y})
end

local BGFever = {}
BGFever.Base = BGFeverBase

function BGFever.create(index, path)
    local map = {BGFever0, BGFever1, BGFever2, BGFever3}
    return map[index + 1].new(index, path)
end

return BGFever
