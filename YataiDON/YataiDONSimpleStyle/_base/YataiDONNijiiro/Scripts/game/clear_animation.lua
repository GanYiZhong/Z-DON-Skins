ClearAnimation = {}
ClearAnimation.__index = ClearAnimation

-- Lumen action_result/success: the bachio pair fades in, slides out and settles
-- while the five letters pop up one after another; the highlight flashes over
-- the letters, the whole word replaces them and sparkles loop over it.
-- Offsets are from the bachio textures' json top-left (the right bachio mirrors x).
local PIECE_X = { 0, 59, 118, 185, 256 }      -- letter lefts from the first letter
local PIECE_START, PIECE_STEP = 333.33, 50   -- ms
local PIECE_RISE, PIECE_FALL, PIECE_POP = 167, 150, 15
-- in pose frame 0, then out frames 0..3 (the last one rests): dx, dy
local OUT_POSES = {
    { -233, 1 }, { -204, -20 }, { -204, -20 }, { -212, 1 }, { -212, 1 },
}
local IN_REST = { -1, 1 }
-- sparkles loop with sprite 52 (95 frames) from 1783 ms, one every 83.33 ms
local SPARKLE_LOOP, SPARKLE_START, SPARKLE_STEP = 1583.33, 1783.33, 83.33
local SPARKLES = {
    { -1.65, -48.65 }, { 120.35, -48.65 }, { -121.65, -48 }, { -79.65, 48 },
    { 156.35, 33.35 }, { -161.65, 30 }, { 68.35, 48 },
}

function ClearAnimation.new(is_2p)
    local self = setmetatable({}, ClearAnimation)

    self.is_2p = is_2p
    self.idx = is_2p and 1 or 0
    self.draw_clear_full = false
    self.name = "in"
    self.frame = 0
    self.start_ms = nil
    self.dx, self.dy = IN_REST[1], IN_REST[2]

    local function game_anim(id) return tex.get_animation(id, "game") end
    self.bachio_fade_in      = game_anim(46)
    self.pose_in             = game_anim(94)
    self.pose_out            = game_anim(95)
    self.slide               = game_anim(96)
    self.overshoot           = game_anim(97)
    self.settle              = game_anim(98)
    self.highlight_fade_in   = game_anim(99)
    self.highlight_fade_out  = game_anim(100)
    self.anims = {
        self.bachio_fade_in, self.pose_in, self.pose_out, self.slide, self.overshoot,
        self.settle, self.highlight_fade_in, self.highlight_fade_out,
    }

    self.piece_fade, self.piece_rise, self.piece_fall = {}, {}, {}
    for i = 1, 5 do
        local delay = PIECE_START + (i - 1) * PIECE_STEP
        self.piece_fade[i] = anim.fade(PIECE_RISE, { initial_opacity = 0.0, final_opacity = 1.0, delay = delay, ease_out = "quadratic" })
        self.piece_rise[i] = anim.move(PIECE_RISE, { total_distance = PIECE_POP, delay = delay, ease_out = "quadratic" })
        self.piece_fall[i] = anim.move(PIECE_FALL, { total_distance = PIECE_POP, delay = delay + PIECE_RISE, ease_in = "quadratic" })
        for _, a in ipairs({ self.piece_fade[i], self.piece_rise[i], self.piece_fall[i] }) do
            self.anims[#self.anims + 1] = a
        end
    end
    for _, a in ipairs(self.anims) do a:start() end

    if not ((tex.ai_active and tex.ai_active()) or tex.current_screen() == "AI_GAME") then audio.play_sound("clear", "sound") end

    self.t_clear           = tex.get_texture("game/ending_anim/clear")
    self.t_clear_separated = tex.get_texture("game/ending_anim/clear_separated")
    self.t_clear_sep_hl    = tex.get_texture("game/ending_anim/clear_separated_highlight")
    self.t_clear_highlight = tex.get_texture("game/ending_anim/clear_highlight")
    self.t_bachio_l_in     = tex.get_texture("game/ending_anim/bachio_l_in")
    self.t_bachio_l_out    = tex.get_texture("game/ending_anim/bachio_l_out")
    self.t_bachio_r_in     = tex.get_texture("game/ending_anim/bachio_r_in")
    self.t_bachio_r_out    = tex.get_texture("game/ending_anim/bachio_r_out")
    self.t_sparkle         = tex.get_texture("game/ending_anim/sparkle")

    return self
end

function ClearAnimation:update(current_ms)
    self.start_ms = self.start_ms or current_ms
    self.now = current_ms - self.start_ms
    for _, a in ipairs(self.anims) do a:update(current_ms) end

    -- the highlight has covered the letters: the whole word takes over
    if self.highlight_fade_in.is_finished then
        self.draw_clear_full = true
    end

    if self.pose_in.is_finished then
        self.name = "out"
        local step = math.floor(self.pose_out.attribute) + 1
        self.frame = step
        self.dx, self.dy = OUT_POSES[step][1], OUT_POSES[step][2]
    else
        self.name = "in"
        self.frame = math.floor(self.pose_in.attribute)
        if self.frame == 0 then
            self.dx, self.dy = IN_REST[1], IN_REST[2]
        else
            self.dx = self.slide.attribute + self.overshoot.attribute - self.settle.attribute
            self.dy = IN_REST[2]
        end
    end
end

function ClearAnimation:draw_bachio(side)
    -- out step 1 is the in pose's first frame, steps 2..5 are out frames 0..3
    local t, frame
    if self.name == "in" or self.frame == 1 then
        t = side < 0 and self.t_bachio_l_in or self.t_bachio_r_in
        frame = self.name == "in" and self.frame or 0
    else
        t = side < 0 and self.t_bachio_l_out or self.t_bachio_r_out
        frame = self.frame - 2
    end
    tex.draw_texture(t, {
        frame = frame,
        x = -side * self.dx,
        y = self.dy,
        fade = self.bachio_fade_in.attribute,
        index = self.idx,
    })
end

function ClearAnimation:draw_sparkles()
    if not self.now then return end
    for k, s in ipairs(SPARKLES) do
        local t = self.now - SPARKLE_START - (k - 1) * SPARKLE_STEP
        if t >= 0 then
            t = t % SPARKLE_LOOP
            if t < 333.33 then
                local grow = math.min(t / 166.67, 1)
                tex.draw_texture(self.t_sparkle, {
                    x = s[1],
                    y = s[2],
                    scale = 0.2 + 0.8 * grow,
                    center = true,
                    fade = t < 183.33 and 1.0 or 0.89 * (1 - (t - 183.33) / 150),
                    index = self.idx,
                })
            end
        end
    end
end

function ClearAnimation:draw()
    if tex.ai_active and tex.ai_active() then return end   -- Z-DON AI battle: the emblem only
    if self.draw_clear_full then
        tex.draw_texture(self.t_clear, { index = self.idx })
        tex.draw_texture(self.t_clear_highlight, {
            fade = self.highlight_fade_out.attribute,
            index = self.idx,
        })
        self:draw_sparkles()
    else
        for i = 5, 1, -1 do
            local j = i - 1
            local pop = self.piece_rise[i].attribute - self.piece_fall[i].attribute
            local params = {
                frame = j,
                x = PIECE_X[i],
                y = -pop,
                y2 = pop,
                fade = self.piece_fade[i].attribute,
                index = self.idx,
            }
            tex.draw_texture(self.t_clear_separated, params)
            tex.draw_texture(self.t_clear_sep_hl, {
                frame = j,
                x = PIECE_X[i],
                y = -pop,
                y2 = pop,
                fade = math.min(self.highlight_fade_in.attribute, self.piece_fade[i].attribute),
                index = self.idx,
            })
        end
    end

    self:draw_bachio(-1)
    self:draw_bachio(1)
end
