FailAnimation = {}
FailAnimation.__index = FailAnimation

-- Lumen action_result/fail: the pair of bachio fade in, slide apart, tumble
-- (rotating 30 deg) to the sides, drop and land lying down with a squash.
-- Bachio textures are 152x160; BOOM_GAP is the distance between the two puffs.
local W, H = 152, 160
local BOOM_GAP = 254
local TEXT_W, TEXT_H = 336, 88
-- resting offset (from the in pose top-left) once the bachio lie down
local LYING_X, LYING_Y = -192, -4

function FailAnimation.new(is_2p)
    local self = setmetatable({}, FailAnimation)

    self.is_2p = is_2p
    self.idx = is_2p and 1 or 0
    self.name = "in"
    self.frame = 0

    local function anim(id) return tex.get_animation(id, "game") end
    self.bachio_fade_in  = anim(46)
    self.pose_in         = anim(78)
    self.pose_fall       = anim(79)
    self.slide           = anim(80)
    self.tumble_x        = anim(81)
    self.tumble_y        = anim(82)
    self.drop            = anim(83)
    self.tilt            = anim(84)
    self.squash_in       = anim(85)
    self.squash_out      = anim(86)
    self.boom_fade_in    = anim(87)
    self.boom_fade_out   = anim(88)
    self.boom_scale      = anim(89)
    self.text_fade_in    = anim(90)
    self.wobble_tilt     = anim(91)
    self.wobble_x        = anim(92)
    self.wobble_y        = anim(93)

    self.anims = {
        self.bachio_fade_in, self.pose_in, self.pose_fall, self.slide, self.tumble_x,
        self.tumble_y, self.drop, self.tilt, self.squash_in, self.squash_out,
        self.boom_fade_in, self.boom_fade_out, self.boom_scale, self.text_fade_in,
        self.wobble_tilt, self.wobble_x, self.wobble_y,
    }
    for _, a in ipairs(self.anims) do a:start() end

    if not ((tex.ai_active and tex.ai_active()) or tex.current_screen() == "AI_GAME") then audio.play_sound("fail", "sound") end

    self.t_fail          = tex.get_texture("game/ending_anim/fail")
    self.t_bachio_boom   = tex.get_texture("game/ending_anim/bachio_boom")
    self.t_bachio_l_in   = tex.get_texture("game/ending_anim/bachio_l_in")
    self.t_bachio_l_fall = tex.get_texture("game/ending_anim/bachio_l_fall")
    self.t_bachio_r_in   = tex.get_texture("game/ending_anim/bachio_r_in")
    self.t_bachio_r_fall = tex.get_texture("game/ending_anim/bachio_r_fall")

    return self
end

function FailAnimation:update(current_ms)
    for _, a in ipairs(self.anims) do a:update(current_ms) end

    if self.pose_in.is_finished then
        self.name = "fall"
        self.frame = math.floor(self.pose_fall.attribute)
    else
        self.frame = math.floor(self.pose_in.attribute)
    end
end

-- side is -1 (left) or 1 (right); the right bachio mirrors the left one
function FailAnimation:draw_bachio(side)
    local falling = self.name == "fall"
    local t
    if side < 0 then
        t = falling and self.t_bachio_l_fall or self.t_bachio_l_in
    else
        t = falling and self.t_bachio_r_fall or self.t_bachio_r_in
    end

    local dx, dy, rotation, squash = self.slide.attribute, 0, 0, 0
    if falling then
        if self.frame == 0 then
            dx = self.tumble_x.attribute
            dy = self.tumble_y.attribute + self.drop.attribute
            rotation = self.tilt.attribute
        else
            dx, dy = LYING_X, LYING_Y
            squash = self.squash_in.attribute - self.squash_out.attribute
        end
    end

    -- the lying pose squashes down onto its bottom edge
    local params = {
        frame = self.frame,
        x = -side * dx,
        y = dy + squash,
        y2 = -squash,
        fade = self.bachio_fade_in.attribute,
        index = self.idx,
    }
    if rotation ~= 0 then
        params.rotation = -side * rotation
        -- raylib puts the origin point at x, y: add it back to keep the top-left
        params.origin = { W / 2, H / 2 }
        params.x = params.x + W / 2
        params.y = params.y + H / 2
    end
    tex.draw_texture(t, params)
end

function FailAnimation:draw()
    -- after the hold the text tilts 4 deg about its centre and settles 10 px lower
    tex.draw_texture(self.t_fail, {
        fade = self.text_fade_in.attribute,
        index = self.idx,
        x = self.wobble_x.attribute + TEXT_W / 2,
        y = self.wobble_y.attribute + TEXT_H / 2,
        rotation = self.wobble_tilt.attribute,
        origin = { TEXT_W / 2, TEXT_H / 2 },
    })

    self:draw_bachio(-1)
    self:draw_bachio(1)

    local boom_fade = math.min(self.boom_fade_in.attribute, self.boom_fade_out.attribute)
    for i = 0, 1 do
        tex.draw_texture(self.t_bachio_boom, {
            x = i * BOOM_GAP,
            scale = self.boom_scale.attribute,
            center = true,
            fade = boom_fade,
            index = self.idx,
        })
    end
end
