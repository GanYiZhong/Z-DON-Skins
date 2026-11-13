FCAnimation = {}
FCAnimation.__index = FCAnimation

-- Lumen action_result/fullcombo: the clear letters pop up and flash, the bachio pair
-- slide out, crouch and hop to the far sides while the "full combo" text rises over
-- them, fans open behind it and confetti shoots from the fans. After the intro the
-- bachio keep hopping, sparkles twinkle and the text flashes (all looping).
-- Times are Lumen frames (1/60 s). Lane-local centres are relative to (806, 73);
-- offsets from the bachio json base follow clear_animation.lua.
local FRAME_MS = 1000 / 60
local PIECE_X = { 0, 59, 118, 185, 256 }
local PIECE_START, PIECE_STEP = 20, 3          -- frames
local PIECE_POP = 15
local OUT_POSES = { { -233, 1 }, { -204, -20 }, { -204, -20 }, { -212, 1 } }
local IN_REST = { -1, 1 }
local HOP_START = 59                            -- frame the bachio leave the out poses
local SECOND_HOP, LOOP_FRAMES = 231, 100       -- crouch-and-hop that repeats every 100 f
local TEXT_APPEAR, VOICE_AT = 89, 89
local FLASH_LOOP = 220                          -- sprite 120 loops f220..439

-- track: {frame, value, ease}; ease ("o" out / "i" in) shapes the segment ending at the key
local function track(f, keys)
    if f <= keys[1][1] then return keys[1][2] end
    for i = 2, #keys do
        local k0, k1 = keys[i - 1], keys[i]
        if f <= k1[1] then
            local p = (f - k0[1]) / (k1[1] - k0[1])
            if k1[3] == "o" then p = 1 - (1 - p) * (1 - p)
            elseif k1[3] == "i" then p = p * p end
            return k0[2] + (k1[2] - k0[2]) * p
        end
    end
    return keys[#keys][2]
end

-- the left bachio's centre x/y and squash (bottom edge pinned) after it leaves the out poses
local HOP_X = { { 59, -241 }, { 76, -241 }, { 97, -351.7, "o" }, { 118, -440, "i" } }
local HOP_Y = {
    { 59, 8 }, { 67, 16.9, "o" }, { 73, 17 }, { 75, 13 }, { 77, -6.55 }, { 78, -20.5 }, { 97, -135, "o" },
    { 118, 8, "i" }, { 119, 12.2 }, { 121, 15.5 }, { 123, 12.15 }, { 124, 8 }, { 126, 6 }, { 128, 8 },
}
local HOP_D = {
    { 59, 1 }, { 67, 0.889 }, { 73, 0.887 }, { 75, 0.938 }, { 76, 1 }, { 118, 1 }, { 119, 0.941 },
    { 121, 0.894 }, { 123, 0.941 }, { 124, 1 }, { 126, 1.025 }, { 128, 1 },
}
-- the repeating hop, frames counted from SECOND_HOP
local HOP2_X = { { 0, -440 }, { 29, -437.7, "o" }, { 45, -440, "i" } }
local HOP2_Y = {
    { 0, 10.25 }, { 5, 16.3 }, { 11, 16.5 }, { 14, 11.75 }, { 15, 8 }, { 29, -17.65, "o" },
    { 45, 8, "i" }, { 46, 10.15 }, { 49, 16.5 }, { 51, 12.3 }, { 52, 10.1 }, { 53, 8 },
}
local HOP2_D = {
    { 0, 0.972 }, { 5, 0.896 }, { 11, 0.894 }, { 14, 0.954 }, { 15, 1 }, { 45, 1 }, { 46, 0.973 },
    { 48, 0.92 }, { 49, 0.894 }, { 50, 0.92 }, { 51, 0.947 }, { 52, 0.973 }, { 53, 1 },
}

-- the text and its glow share one vertical path and squash
local TEXT_Y = { { 89, -15 }, { 102, 0, "i" }, { 103, 2.3 }, { 105, 7 }, { 106, 4.7 }, { 108, 0 } }
local TEXT_D = { { 102, 1 }, { 103, 0.939 }, { 105, 0.818 }, { 106, 0.879 }, { 108, 1 } }
local GLOW_Y = { { 66, 0 }, { 80, -15, "o" }, { 89, -15 }, { 102, 0, "i" } }
local GLOW_A = { { 66, -1 }, { 80, 1, "o" }, { 89, 1 }, { 102, 0, "i" } }
local ADD_A = { { 66, 0 }, { 80, 1, "o" }, { 89, 1 }, { 102, 0.5, "i" }, { 105, 0.25 }, { 108, 0 } }
local OVERLAY_IN = { { 89, 0 }, { 102, 1, "i" } }

-- sparkles (sprite 51): { start frame, x, y }; the ones from f220 repeat every 100 f
local SPARKLES = {
    { 66, -30, -45 }, { 66, 30, 45 }, { 69, 75, -45 }, { 69, -75, 45 }, { 72, -120, -45 }, { 72, 120, 45 },
    { 75, -165, 45 }, { 75, 165, -45 }, { 77, -306, -7 }, { 77, 306, -7 }, { 78, -210, -45 }, { 78, 210, 45 },
    { 80, -340, 7 }, { 80, 340, 7 }, { 83, -382, -20 }, { 83, 382, -20 }, { 83, -262, 43 }, { 83, 262, 43 },
    { 89, -236, -24 }, { 89, 236, -24 }, { 92, -360, 31 }, { 92, 360, 31 }, { 108, -212, 0 },
    { 116, 55.35, 44.35 }, { 119, -270, -7 }, { 119, 270, -7 }, { 123, -66.65, -46.65 }, { 130, -112, 44.35 },
    { 134, -340, 7 }, { 134, 340, 7 }, { 138, 212.35, 18 }, { 145, 136.35, -46.65 }, { 149, -280, -38 },
    { 149, 280, -38 }, { 155, -212, 0 }, { 166, -262, 43 }, { 166, 262, 43 }, { 183, -236, -24 },
    { 183, 236, -24 }, { 200, -360, 31 }, { 200, 360, 31 },
}
local SPARKLES_LOOP = {  -- from f220, period 100
    { 220, -270, -7 }, { 220, 270, -7 }, { 235, -340, 7 }, { 235, 340, 7 }, { 250, -280, -38 },
    { 250, 280, -38 }, { 267, -262, 43 }, { 267, 262, 43 }, { 284, -236, -24 }, { 284, 236, -24 },
    { 301, -360, 31 }, { 301, 360, 31 },
}
-- sparkles of sprite 120 (period 220 from f255 and f350), 8 f apart
local SPARKLES_FLASH = {
    { -202, -21 }, { -141.65, 26.35 }, { -62.65, -16.65 }, { 22, 18.35 }, { 87.35, -34.65 },
    { 146.35, 24.35 }, { 175, -37 },
}
local FLASH_SPARKLE_STARTS = { 255, 350 }

-- confetti (sprite 118): one piece every 3.33 f from f120, shot out of each fan; the path
-- (frame, x, y from the launch point) is shared by the five colours' own arcs
local CONFETTI_START, CONFETTI_STEP, CONFETTI_LIFE = 120, 100 / 30, 70
local EMITTER = { 315, 14 }
local CONFETTI_OFFSETS = {
    { 20, -70 }, { 40, -55 }, { -20, -86 }, { 2, -87 }, { 24, -57 }, { -40, -90 }, { -40, -95 },
    { -60, -126 }, { -38, -67 }, { -36, -117 }, { -50, -70 }, { -40, -65 }, { -40, -86 },
    { -58, -87 }, { -56, -57 },
}
local CONFETTI_PATHS = {
    { { 0, 7.2, 65 }, { 3, 33.5, 30.4 }, { 7, 68.4, -3.4 }, { 10, 93.1, -20.1 }, { 14, 123.9, -28.9 },
      { 20, 145.9, -22.1 }, { 30, 169.4, 6.1 }, { 40, 183.6, 45.2 }, { 50, 191.7, 91.4 }, { 62, 195, 153.6 },
      { 75, 206.4, 227.4 } },
    { { 0, 5.9, 67 }, { 3, 32.7, 45.8 }, { 7, 60, 17.3 }, { 10, 78.3, -0.9 }, { 14, 102.6, -16.6 },
      { 20, 129.7, -13.5 }, { 30, 140.4, 17.9 }, { 40, 139.6, 55 }, { 50, 135.9, 95 }, { 62, 133.6, 148.6 },
      { 75, 137.2, 214.4 } },
    { { 0, 4.8, 66.6 }, { 3, 17.8, 43 }, { 7, 39.3, 19.5 }, { 10, 58.7, 11.1 }, { 14, 82.3, 7.8 },
      { 20, 108.6, 11.4 }, { 30, 132.1, 32.4 }, { 40, 148.3, 65.8 }, { 50, 163.4, 105.9 }, { 62, 187.7, 157.5 },
      { 75, 219.9, 216.9 } },
    { { 0, 5.9, 67 }, { 3, 24.2, 38.7 }, { 7, 58.2, 16 }, { 10, 82.8, 5.2 }, { 14, 112.7, -2.5 },
      { 20, 148.2, 1.8 }, { 30, 167.5, 27.2 }, { 40, 161.9, 65.7 }, { 50, 146.8, 107.3 }, { 62, 132.9, 164.1 },
      { 75, 136.4, 236.1 } },
    { { 0, 5.9, 67 }, { 3, 25.7, 40.2 }, { 7, 55.3, 14.1 }, { 10, 77.5, 0.6 }, { 14, 105.6, -9.7 },
      { 20, 139.8, -5.5 }, { 30, 160.3, 14.6 }, { 40, 173.9, 45.2 }, { 50, 179.4, 83 }, { 62, 181.4, 135.3 },
      { 75, 191.8, 196.6 } },
}

local function path_at(path, f)
    for i = 2, #path do
        local a, b = path[i - 1], path[i]
        if f <= b[1] then
            local p = (f - a[1]) / (b[1] - a[1])
            return a[2] + (b[2] - a[2]) * p, a[3] + (b[3] - a[3]) * p
        end
    end
    local last = path[#path]
    return last[2], last[3]
end

function FCAnimation.new(is_2p, donderful)
    local self = setmetatable({}, FCAnimation)

    self.is_2p = is_2p
    self.idx = is_2p and 1 or 0
    self.name = "in"
    self.frame = 0
    self.start_ms = nil
    self.now = 0
    self.voice_played = false
    self.dx, self.dy, self.dh = IN_REST[1], IN_REST[2], 0

    local has_dfc_tex = donderful
        and tex.get_texture("game/ending_donderful/full_combo") ~= nil
        and tex.get_texture("game/ending_donderful/full_combo_highlight") ~= nil
        and tex.get_texture("game/ending_donderful/full_combo_overlay") ~= nil

    local subset = has_dfc_tex and "ending_donderful/" or "ending_anim/"
    self.combo_tex           = tex.get_texture("game/" .. subset .. "full_combo")
    self.combo_highlight_tex = tex.get_texture("game/" .. subset .. "full_combo_highlight")
    self.combo_overlay_tex   = tex.get_texture("game/" .. subset .. "full_combo_overlay")

    self.has_panel = has_dfc_tex and tex.get_texture("game/ending_donderful/background") ~= nil
    self.panel_tex = self.has_panel and tex.get_texture("game/ending_donderful/background") or nil
    self.panel_fade_in = anim.fade(250, { initial_opacity = 0.0, final_opacity = 1.0, delay = TEXT_APPEAR * FRAME_MS })

    local has_dfc_sound = donderful and audio.has_sound("donderful_combo")
    self.combo_sound = has_dfc_sound and "donderful_combo" or "full_combo"
    self.combo_voice = (donderful and audio.has_sound("donderful_combo_voice")) and "donderful_combo_voice" or "full_combo_voice"

    local function game_anim(id) return tex.get_animation(id, "game") end
    self.bachio_fade_in = game_anim(46)
    self.pose_in        = game_anim(94)
    self.pose_out       = game_anim(95)
    self.slide          = game_anim(96)
    self.overshoot      = game_anim(97)
    self.settle         = game_anim(98)
    self.highlight_in   = game_anim(99)
    self.highlight_out  = anim.fade(200, { initial_opacity = 1.0, final_opacity = 0.0, delay = 73 * FRAME_MS })
    self.anims = {
        self.bachio_fade_in, self.pose_in, self.pose_out, self.slide, self.overshoot, self.settle,
        self.highlight_in, self.highlight_out, self.panel_fade_in,
    }
    -- the highlight of the letters fades in over f61-72 like the clear animation's, and out over f73-85
    self.piece_fade, self.piece_rise, self.piece_fall = {}, {}, {}
    for i = 1, 5 do
        local delay = (PIECE_START + (i - 1) * PIECE_STEP) * FRAME_MS
        self.piece_fade[i] = anim.fade(167, { initial_opacity = 0.0, final_opacity = 1.0, delay = delay, ease_out = "quadratic" })
        self.piece_rise[i] = anim.move(167, { total_distance = PIECE_POP, delay = delay, ease_out = "quadratic" })
        self.piece_fall[i] = anim.move(150, { total_distance = PIECE_POP, delay = delay + 167, ease_in = "quadratic" })
        for _, a in ipairs({ self.piece_fade[i], self.piece_rise[i], self.piece_fall[i] }) do
            self.anims[#self.anims + 1] = a
        end
    end
    for _, a in ipairs(self.anims) do a:start() end

    if not (tex.ai_active and tex.ai_active()) then audio.play_sound(self.combo_sound, "sound") end   -- AI battle: the cabinet is silent here (Tl7g8XXXvAM 4:20-4:25)

    self.t_fan_l           = tex.get_texture("game/ending_anim/fan_l")
    self.t_fan_r           = tex.get_texture("game/ending_anim/fan_r")
    self.t_clear_separated = tex.get_texture("game/ending_anim/clear_separated")
    self.t_clear_sep_hl    = tex.get_texture("game/ending_anim/clear_separated_highlight")
    self.t_bachio_l_in     = tex.get_texture("game/ending_anim/bachio_l_in")
    self.t_bachio_l_out    = tex.get_texture("game/ending_anim/bachio_l_out")
    self.t_bachio_r_in     = tex.get_texture("game/ending_anim/bachio_r_in")
    self.t_bachio_r_out    = tex.get_texture("game/ending_anim/bachio_r_out")
    self.t_sparkle         = tex.get_texture("game/ending_anim/sparkle")
    self.t_confetti        = tex.get_texture("game/ending_anim/confetti")

    return self
end

-- the left bachio's centre (cx, cy) and height factor d at frame f
local function hop_state(f)
    if f >= SECOND_HOP then
        local p = (f - SECOND_HOP) % LOOP_FRAMES
        if p <= 53 then
            return track(p, HOP2_X), track(p, HOP2_Y), track(p, HOP2_D)
        end
        return -440, 8, 1
    elseif f > 128 then
        return -440, 8, 1
    end
    return track(f, HOP_X), track(f, HOP_Y), track(f, HOP_D)
end

function FCAnimation:update(current_ms)
    self.start_ms = self.start_ms or current_ms
    self.now = current_ms - self.start_ms
    for _, a in ipairs(self.anims) do a:update(current_ms) end

    local f = self.now / FRAME_MS
    self.f = f

    if not self.voice_played and f >= VOICE_AT then
        self.voice_played = true
        if not (tex.ai_active and tex.ai_active()) then audio.play_sound(self.combo_voice, "voice") end
    end

    if f >= HOP_START then
        self.name = "hop"
        local cx, cy, d = hop_state(f)
        -- json base is 701, 187: the left bachio's top-left is (730 + cx, 261 + cy - 80 d) - 701/187 in lane terms
        self.dx = 29 + cx
        self.dy = 74 + cy - 80 * d
        self.dh = 160 * (d - 1)
    elseif self.pose_in.is_finished then
        self.name = "out"
        local step = math.floor(self.pose_out.attribute) + 1
        self.dx, self.dy, self.dh = OUT_POSES[math.min(step, 4)][1], OUT_POSES[math.min(step, 4)][2], 0
        self.frame = step
    else
        self.name = "in"
        self.frame = math.floor(self.pose_in.attribute)
        if self.frame == 0 then
            self.dx, self.dy = IN_REST[1], IN_REST[2]
        else
            self.dx = self.slide.attribute + self.overshoot.attribute - self.settle.attribute
            self.dy = IN_REST[2]
        end
        self.dh = 0
    end
end

function FCAnimation:draw_bachio(side)
    local t, frame
    if self.name == "in" or (self.name == "out" and self.frame == 1) then
        t = side < 0 and self.t_bachio_l_in or self.t_bachio_r_in
        frame = self.name == "in" and self.frame or 0
    else
        t = side < 0 and self.t_bachio_l_out or self.t_bachio_r_out
        frame = self.name == "hop" and 3 or self.frame - 2
    end
    tex.draw_texture(t, {
        frame = frame,
        x = -side * self.dx,
        y = self.dy,
        y2 = self.dh,
        fade = self.bachio_fade_in.attribute,
        index = self.idx,
    })
end

local function sparkle_params(age)       -- age in frames, 0..20
    if age < 0 or age >= 20 then return nil end
    local scale = 0.2 + 0.8 * math.min(age / 10, 1)
    local fade = age <= 10 and 1.0 or 0.891 * (1 - (age - 11) / 9)
    return scale, math.max(fade, 0)
end

function FCAnimation:draw_sparkle(x, y, age)
    local scale, fade = sparkle_params(age)
    if not scale then return end
    tex.draw_texture(self.t_sparkle, { x = x, y = y, scale = scale, center = true, fade = fade, index = self.idx })
end

function FCAnimation:draw_sparkles(f)
    for _, s in ipairs(SPARKLES) do self:draw_sparkle(s[2], s[3], f - s[1]) end
    if f >= 220 then
        for _, s in ipairs(SPARKLES_LOOP) do
            self:draw_sparkle(s[2], s[3], (f - s[1]) % LOOP_FRAMES)
        end
        local lf = (f - FLASH_LOOP) % 220 + FLASH_LOOP
        for _, start in ipairs(FLASH_SPARKLE_STARTS) do
            for k, s in ipairs(SPARKLES_FLASH) do
                self:draw_sparkle(s[1], s[2], lf - start - (k - 1) * 8)
            end
        end
    end
end

function FCAnimation:draw_confetti(f)
    if f < CONFETTI_START then return end
    local newest = math.floor((f - CONFETTI_START) / CONFETTI_STEP)
    for i = math.max(0, newest - math.ceil(CONFETTI_LIFE / CONFETTI_STEP)), newest do
        local age = f - CONFETTI_START - i * CONFETTI_STEP
        if age >= 0 and age < CONFETTI_LIFE then
            local kind = i % 5
            local off = CONFETTI_OFFSETS[i % 15 + 1]
            local px, py = path_at(CONFETTI_PATHS[kind + 1], age)
            local fade = age <= 50 and 1.0 or 0.949 * (1 - (age - 51) / 19)
            for side = -1, 1, 2 do
                tex.draw_texture(self.t_confetti, {
                    frame = kind,
                    x = side * (EMITTER[1] - off[1] - px) + 16,
                    y = EMITTER[2] + off[2] + py + 16,
                    rotation = (age * FRAME_MS) * 0.72,
                    origin = { 16, 16 },
                    fade = math.max(fade, 0),
                    index = self.idx,
                })
            end
        end
    end
end

function FCAnimation:draw()
    -- Z-DON AI battle: the cabinet shows only the battle emblem, no fans / bachio (footage Tl7g8XXXvAM 4:28)
    if tex.ai_active and tex.ai_active() then return end
    local f = self.f or 0

    self:draw_confetti(f)

    -- letters, then their highlight; both are gone once the text takes over
    if f < 73 then
        for i = 5, 1, -1 do
            local pop = self.piece_rise[i].attribute - self.piece_fall[i].attribute
            tex.draw_texture(self.t_clear_separated, {
                frame = i - 1,
                x = PIECE_X[i],
                y = -pop,
                y2 = pop,
                fade = self.piece_fade[i].attribute,
                index = self.idx,
            })
        end
    end
    if f >= 61 then
        for i = 5, 1, -1 do
            local pop = f < 73 and (self.piece_rise[i].attribute - self.piece_fall[i].attribute) or 0
            tex.draw_texture(self.t_clear_sep_hl, {
                frame = i - 1,
                x = PIECE_X[i],
                y = -pop,
                y2 = pop,
                fade = f < 73 and self.highlight_in.attribute or self.highlight_out.attribute,
                index = self.idx,
            })
        end
    end

    if f >= TEXT_APPEAR then
        if self.has_panel then
            tex.draw_texture(self.panel_tex, { fade = self.panel_fade_in.attribute, index = self.idx })
        end
    end

    local text_y = f >= TEXT_APPEAR and track(f, TEXT_Y) or 0
    local text_d = track(f, TEXT_D)
    local text_h = 128 * (text_d - 1)
    local text_top = text_y + 64 * (1 - text_d)
    if f >= TEXT_APPEAR then
        -- additive overlay pulses every 20 frames (0.8 -> 1 -> 0.8) once it has faded in
        local phase = (f - TEXT_APPEAR) % 20
        local pulse = phase <= 10 and (0.801 + 0.199 * phase / 10) or (0.977 - 0.176 * (phase - 11) / 8)
        tex.draw_texture(self.combo_overlay_tex, {
            y = text_top, y2 = text_h,
            fade = track(f, OVERLAY_IN) * pulse,
            index = self.idx,
        })
        tex.draw_texture(self.combo_tex, { y = text_top, y2 = text_h, index = self.idx })
    end

    -- rising glow (f66-108) and the looping flash from f220
    local glow_y, glow_a, add_a = 0, 0, 0
    if f >= 66 and f <= 108 then
        glow_y, glow_a, add_a = track(f, GLOW_Y), math.max(track(f, GLOW_A), 0), track(f, ADD_A)
        if f > 102 then glow_a, glow_y = 0, text_top end
    elseif f >= FLASH_LOOP then
        local p = (f - FLASH_LOOP) % 220
        glow_a = p <= 15 and p / 15 or (p <= 30 and 0.934 * (1 - (p - 16) / 14) or 0)
        add_a = glow_a
    end
    local glow_h = (f > 102 and f <= 108) and text_h or 0
    if glow_a > 0 then
        tex.draw_texture(self.combo_highlight_tex, { y = glow_y, y2 = glow_h, fade = math.min(glow_a, 1), index = self.idx })
    end
    if add_a > 0 then
        tex.draw_texture(self.combo_overlay_tex, { y = glow_y, y2 = glow_h, fade = math.min(add_a, 1), index = self.idx })
    end

    -- fans: open from f70, then flap every 3 frames from f118
    if f >= 70 then
        local fan_frame
        if f < 77 then fan_frame = 0
        elseif f < 79 then fan_frame = 1
        elseif f < 80 then fan_frame = 2
        elseif f < 81 then fan_frame = 3
        elseif f < 118 then fan_frame = 4
        else fan_frame = (math.floor((f - 118) / 3) % 2 == 0) and 5 or 4 end
        local fan_fade = math.min((f - 70) / 4, 1)
        tex.draw_texture(self.t_fan_l, { frame = fan_frame, fade = fan_fade, index = self.idx })
        tex.draw_texture(self.t_fan_r, { frame = fan_frame, fade = fan_fade, index = self.idx })
    end

    self:draw_sparkles(f)

    self:draw_bachio(-1)
    self:draw_bachio(1)
end
