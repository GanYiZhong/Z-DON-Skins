-- YataiDONSimpleStyle v2 standalone: copied from the nearest ancestor at build time (ss/v2_standalone.py), colours in our ink
ResultBasin = {}
ResultBasin.__index = ResultBasin

local FLY_START_MS = 1100
local FLY_END_MS   = FLY_START_MS + 617
local HALF_W, HALF_H = 100, 52

function ResultBasin.new(is_2p)
    local self = setmetatable({}, ResultBasin)

    self.is_2p = is_2p
    self.t0    = nil
    self.landed = false

    self.fade_in    = tex.get_animation(25, "result")
    self.scale_in   = tex.get_animation(26, "result")
    self.scale_fix  = tex.get_animation(27, "result")
    self.fall       = tex.get_animation(28, "result")
    self.fly_x      = tex.get_animation(29, "result")
    self.fly_y      = tex.get_animation(30, "result")
    self.fly_rot    = tex.get_animation(31, "result")
    self.fly_scale  = tex.get_animation(32, "result")
    self.flash_size = tex.get_animation(33, "result")
    self.flash_fade = tex.get_animation(34, "result")
    self.anims = { self.fade_in, self.scale_in, self.scale_fix, self.fall, self.fly_x,
                   self.fly_y, self.fly_rot, self.fly_scale, self.flash_size, self.flash_fade }
    for _, a in ipairs(self.anims) do a:start() end

    self.t_basin = tex.get_texture("result/basin/basin")
    self.t_flash = tex.get_texture("result/basin/flash")

    return self
end

function ResultBasin:update(current_ms)
    self.t0 = self.t0 or current_ms
    self.t  = current_ms - self.t0
    if not self.landed and self.t >= FLY_START_MS then
        self.landed = true
        audio.play_sound("crash", "sound")
    end
    for _, a in ipairs(self.anims) do a:update(current_ms) end
end

function ResultBasin:draw()
    if not self.t or not self.t_basin then return end
    local t     = self.t
    local p_idx = self.is_2p and 1 or 0

    if t >= FLY_END_MS then return end
    local flying = t >= FLY_START_MS
    local s = flying and self.fly_scale.attribute
        or (self.scale_in.is_finished and self.scale_fix.attribute or self.scale_in.attribute)
    local params = {
        scale  = s, center = true, index = p_idx,
        x      = flying and self.fly_x.attribute or 0,
        y      = -90 + self.fall.attribute + (flying and self.fly_y.attribute or 0),
        fade   = self.fade_in.attribute,
        origin = { HALF_W * s, HALF_H * s },
        rotation = flying and self.fly_rot.attribute or 0,
    }
    tex.draw_texture(self.t_basin, params)

    if flying and self.t_flash and self.flash_fade.attribute > 0 then
        tex.draw_texture(self.t_flash, { scale = self.flash_size.attribute, center = true,
                                         fade = self.flash_fade.attribute, index = p_idx })
    end
end
