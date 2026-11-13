local FRAME_MS = 1000 / 60
local INFO_MS = 10000
local INFO_FADE_MS = 20 * FRAME_MS
local GACHA_FRAMES = 835

local CUES = {
    { 11, "machine_down" }, { 60, "mdon_eye" }, { 93, "mdon_rotate" }, { 113, "capsule_down" }, { 117, "mdon_open" },
    { 168, "capsule_jump" }, { 189, "mdon_close" }, { 225, "machine_up" }, { 255, "capsule_fall" },
    { 297, "capsule_bowan" }, { 297, "capsule_light" }, { 297, "capsule_roll" }, { 297, "capsule_burst" },
    { 520, "capsule_flash" }, { 545, "get_jingle" }, { 598, "vo_get" },
}

local function play(name)
    audio.play_sound("gacha_" .. name, "attract_mode")
end

local function ease_in(t)
    return t * t
end

local function ease_out(t)
    return 1 - (1 - t) * (1 - t)
end

local function linear(t)
    return t
end

local function track(f, keys)
    local v = nil
    for _, k in ipairs(keys) do
        if f < k[1] then
            return v
        end
        if f <= k[2] then
            local t = k[2] > k[1] and (f - k[1]) / (k[2] - k[1]) or 1
            return k[3] + (k[4] - k[3]) * (k[5] or linear)(t)
        end
        v = k[4]
    end
    return v
end

local DON_FRAMES = {
    { 93, 1 }, { 96, 2 }, { 99, 3 }, { 102, 4 }, { 105, 5 }, { 108, 6 }, { 111, 0 }, { 117, 7 }, { 120, 8 },
    { 123, 9 }, { 126, 10 }, { 129, 11 }, { 132, 10 }, { 189, 9 }, { 192, 8 }, { 195, 7 }, { 198, 0 }, { 201, 7 },
    { 204, 0 },
}
local function don_frame(f)
    local frame = 0
    for _, e in ipairs(DON_FRAMES) do
        if f < e[1] then
            return frame
        end
        frame = e[2]
    end
    return frame
end

local function progress(f, f0, f1)
    return math.max(0, math.min(1, (f - f0) / (f1 - f0)))
end

local function texture(name)
    return tex.get_texture("title/gacha/" .. name)
end

local function size(name)
    local info = tex.get_texture_info("gacha", name)
    return info.x2[1], info.y2[1]
end

local function draw_centered(t, w, h, cx, cy, params)
    local sx = params.scale or 1
    local sy = sx * (params.squash or 1)
    tex.draw_texture(t, {
        x = cx,
        y = cy,
        x2 = w * (sx - 1),
        y2 = h * (sy - 1),
        origin = { w * sx / 2, h * sy / 2 },
        rotation = params.rotation or 0,
        fade = params.fade or 1,
    })
end

local function spin_angle(f, f0, start)
    return start - 9 * (f - f0)
end

local Capsule = {}
Capsule.__index = Capsule

function Capsule.new(small)
    local self = setmetatable({}, Capsule)
    local ball = small and "capsule_small" or "capsule"
    local shine = small and "shine_small" or "shine"
    self.t_ball = texture(ball)
    self.t_shine = texture(shine)
    self.ball_w, self.ball_h = size(ball)
    self.shine_w, self.shine_h = size(shine)
    self.visible = false
    return self
end

function Capsule:set(cx, cy, scale, rotation, squash)
    self.visible = true
    self.cx = cx
    self.cy = cy
    self.scale = scale
    self.rotation = rotation
    self.squash = squash
end

function Capsule:draw()
    if not self.visible then
        return
    end
    draw_centered(self.t_ball, self.ball_w, self.ball_h, self.cx, self.cy, {
        scale = self.scale,
        rotation = self.rotation,
        squash = self.squash,
    })
    draw_centered(self.t_shine, self.shine_w, self.shine_h, self.cx - 10 * self.scale, self.cy - 14 * self.scale, {
        scale = self.scale,
        fade = 0.602,
    })
end

local GachaDon = {}
GachaDon.__index = GachaDon

function GachaDon.new()
    local self = setmetatable({}, GachaDon)
    self.t_stand = texture("stand")
    self.t_don = texture("don")
    self.t_don_face = texture("don_face")
    self.t_don_lid = texture("don_lid")
    self.visible = true
    self.frame = 0
    self.x = 0
    self.drop = 0
    self.face_visible = false
    self.lid_visible = false
    return self
end

function GachaDon:update(f)
    self.visible = f < 255
    self.frame = don_frame(f)
    self.x = track(f, {
        { 57, 60, -0.75, -3 },
        { 61, 64, -2.25, 0 },
        { 210, 215, 0.65, 4 },
        { 216, 221, 3.15, -1 },
        { 222, 225, -1, -1 },
    }) or 0
    self.drop = track(f, { { 226, 254, 0, 440, ease_in } }) or 0
    self.face_visible = f >= 96 and f < 99
    self.lid_visible = f >= 132 and f < 176
end

function GachaDon:draw()
    if not self.visible then
        return
    end
    tex.draw_texture(self.t_stand, { y = self.drop })
    tex.draw_texture(self.t_don, { frame = self.frame, x = self.x, y = self.drop })
end

function GachaDon:draw_face()
    if self.face_visible then
        tex.draw_texture(self.t_don_face)
    end
end

function GachaDon:draw_lid()
    if self.lid_visible then
        tex.draw_texture(self.t_don_lid)
    end
end

local GachaGlobe = {}
GachaGlobe.__index = GachaGlobe

function GachaGlobe.new()
    local self = setmetatable({}, GachaGlobe)
    self.t_globe = texture("globe")
    self.t_hose_ring = texture("hose_ring")
    self.back_visible = false
    self.ring_visible = false
    self.front_visible = false
    return self
end

function GachaGlobe:update(f)
    self.back_visible = f >= 10 and f < 105
    if self.back_visible then
        self.back_frame = f >= 100 and 1 or 0
        self.back_x = track(f, { { 49, 53, 2, 10 }, { 54, 59, 6.95, 0, ease_out } }) or 0
        self.back_y = track(f, { { 10, 48, -570, 4, ease_out }, { 49, 53, 3.2, 0 } })
    end

    local shake_x = track(f, { { 206, 212, 0, 10, ease_out }, { 213, 218, 9.85, 5, ease_in } })
    local shake_y = track(f, { { 219, 225, 1.35, 5, ease_out }, { 226, 254, 4.3, -575, ease_in } }) or 0
    self.ring_visible = f >= 105 and f < 254
    self.ring_x = f < 206 and -2 or shake_x
    self.ring_y = shake_y

    self.front_visible = f >= 105 and f < 255
    self.front_frame = f < 206 and 2 or 0
    self.front_x = f < 206 and 0 or shake_x
    self.front_y = f < 206 and 0 or shake_y
end

function GachaGlobe:draw_back()
    if self.back_visible then
        tex.draw_texture(self.t_globe, { frame = self.back_frame, x = self.back_x, y = self.back_y })
    end
end

function GachaGlobe:draw_ring()
    if self.ring_visible then
        tex.draw_texture(self.t_hose_ring, { x = self.ring_x, y = self.ring_y })
    end
end

function GachaGlobe:draw_front()
    if self.front_visible then
        tex.draw_texture(self.t_globe, { frame = self.front_frame, x = self.front_x, y = self.front_y })
    end
end

local CapsuleRun = {}
CapsuleRun.__index = CapsuleRun

function CapsuleRun.new()
    local self = setmetatable({}, CapsuleRun)
    self.hose = Capsule.new(true)
    self.out = Capsule.new(false)
    self.fly = Capsule.new(false)
    return self
end

function CapsuleRun:update(f)
    self.hose.visible = false
    self.out.visible = false
    self.fly.visible = false

    if f >= 113 and f < 120 then
        local t = (f - 113) / 6
        self.hose:set(847.7 + 2.9 * t, 357.05 + 43.85 * t, 1.5, spin_angle(f, 113, 0))
    elseif f >= 120 and f < 140 then
        local t = ease_in((f - 120) / 19)
        self.hose:set(848.8 - 106.55 * t, 408.2 + 70.8 * t, 1.5, spin_angle(f, 113, 0))
    end

    if f >= 139 and f < 154 then
        local t = (f - 139) / 14
        self.out:set(690.5 - 102.15 * t, 489.5 + 47.2 * t, 1.4 + 0.093 * t, spin_angle(f, 139, 135))
    elseif f >= 154 and f < 168 then
        local y = track(f, { { 154, 164, 186.5, 190.5, ease_out }, { 165, 167, 190.2, 188 } })
        local squash = track(f, { { 154, 164, 1, 0.9, ease_out }, { 165, 167, 0.911, 1 } })
        self.out:set(583.5, 357 + y, 1.5, 0, squash)
    end

    if f >= 168 and f < 233 then
        local t = ease_out(progress(f, 168, 228))
        self.fly:set(583.4 - 147.6 * t, 544.95 - 633.4 * t, 1.5 + 0.5 * t, spin_angle(f, 168, 0))
    end
end

local Sparkles = {}
Sparkles.__index = Sparkles

local SPARKLE_CENTERS = { { 518, 506 }, { 602, 507 } }

function Sparkles.new()
    local self = setmetatable({}, Sparkles)
    self.t_sparkle = texture("sparkle")
    self.w, self.h = size("sparkle")
    self.visible = false
    return self
end

function Sparkles:update(f)
    self.visible = f >= 60 and f < 100
    local t = (f - 60) / 19
    if t <= 1 then
        self.scale = 0.1 + 0.9 * t
        self.fade = t
    else
        self.scale = 1.025 + 0.475 * (t - 1)
        self.fade = math.max(0, 0.949 * (2 - t))
    end
end

function Sparkles:draw()
    if not self.visible then
        return
    end
    for _, center in ipairs(SPARKLE_CENTERS) do
        draw_centered(self.t_sparkle, self.w, self.h, center[1], center[2], {
            scale = self.scale,
            fade = self.fade,
        })
    end
end

local BigCapsule = {}
BigCapsule.__index = BigCapsule

function BigCapsule.new()
    local self = setmetatable({}, BigCapsule)
    self.t_capsule = texture("big_capsule")
    self.t_shine = texture("big_shine")
    self.w, self.h = size("big_capsule")
    self.visible = false
    return self
end

function BigCapsule:update(f)
    self.visible = f >= 255 and f < 297
    self.y = track(f, {
        { 255, 284, -500, 0, ease_in },
        { 285, 290, 2.45, 8, ease_out },
        { 291, 295, 7.7, 0, ease_in },
    }) or 0
    self.squash = track(f, { { 285, 290, 0.969, 0.9, ease_out }, { 291, 295, 0.904, 1, ease_in } }) or 1
end

function BigCapsule:draw()
    if not self.visible then
        return
    end
    tex.draw_texture(self.t_capsule, {
        y = self.y + self.h / 2 * (1 - self.squash),
        y2 = self.h * (self.squash - 1),
    })
    tex.draw_texture(self.t_shine, { y = self.y })
end

local Cloud = {}
Cloud.__index = Cloud

function Cloud.new()
    local self = setmetatable({}, Cloud)
    self.t_cloud = texture("cloud")
    self.visible = false
    return self
end

function Cloud:update(f)
    self.visible = f >= 296 and f < 320
    if f < 303 then
        self.frame = 0
    elseif f < 308 then
        self.frame = 1
    elseif f < 314 then
        self.frame = 2
    else
        self.frame = 3
    end
    self.scale = track(f, { { 296, 302, 0.1, 1.1 } })
    self.y = track(f, { { 303, 307, 0, -10 }, { 308, 313, -10, -20 }, { 314, 319, -20, -30 } }) or 0
    self.fade = track(f, { { 296, 302, 0, 1 }, { 314, 319, 1, 0 } })
end

function Cloud:draw()
    if self.visible then
        tex.draw_texture(self.t_cloud, {
            frame = self.frame,
            center = true,
            scale = self.scale,
            y = self.y,
            fade = self.fade,
        })
    end
end

local Flash = {}
Flash.__index = Flash

function Flash.new()
    local self = setmetatable({}, Flash)
    self.t_rays = texture("rays")
    self.w, self.h = size("rays")
    self.visible = false
    return self
end

function Flash:update(f)
    self.visible = f >= 297 and f < 540
    self.rotation = 0
    self.fade = 1
    if f < 303 then
        self.scale = 0.335 + (f - 297) * 1.11
        self.fade = (f - 297) / 6
    elseif f <= 520 then
        local t = (f - 303) / 217
        self.scale = 7 - 6 * t
        self.rotation = 360 * t
    elseif f < 530 then
        self.scale = 1 + (f - 520) * 0.6
    else
        self.scale = 7
        self.fade = math.max(0, 1 - (f - 530) / 9)
    end
end

function Flash:draw()
    if self.visible then
        draw_centered(self.t_rays, self.w, self.h, 638, 231, {
            scale = self.scale,
            rotation = self.rotation,
            fade = self.fade,
        })
    end
end

local Prize = {}
Prize.__index = Prize

function Prize.new(frame)
    local self = setmetatable({}, Prize)
    self.frame = frame
    self.t_rays = texture("rays")
    self.rays_w, self.rays_h = size("rays")
    self.t_prize = texture("prize")
    self.t_frame = texture("frame")
    self.t_prize_name = texture("prize_name")
    self.t_label = texture("label")
    self.t_get = texture("get")
    self.t_message = texture("message")
    return self
end

function Prize:update(f)
    self.rays_visible = f >= 528
    self.rays_rotation = 180 + 360 * ((f - 528) % 386) / 386
    self.prize_visible = f >= 530

    self.panel_visible = f >= 545
    self.panel_y = track(f, { { 545, 552, 100, 0, ease_out } })
    self.panel_fade = track(f, { { 545, 552, 0, 1, ease_out } })

    self.get_visible = f >= 598
    self.get_y = track(f, { { 598, 605, 55, -25, ease_out }, { 606, 610, -24, 0, ease_in } })
    self.get_fade = track(f, { { 598, 605, 0, 1, ease_out } })

    self.message_visible = f >= 760
end

function Prize:draw_message()
    if self.message_visible then
        tex.draw_texture(self.t_message)
    end
end

function Prize:draw()
    if self.rays_visible then
        draw_centered(self.t_rays, self.rays_w, self.rays_h, 640, 219, { rotation = self.rays_rotation })
    end
    if self.prize_visible then
        tex.draw_texture(self.t_prize, { frame = self.frame })
    end
end

function Prize:draw_panel()
    if not self.panel_visible then
        return
    end
    tex.draw_texture(self.t_frame, { y = self.panel_y, fade = self.panel_fade })
    tex.draw_texture(self.t_prize_name, { frame = self.frame, y = self.panel_y, fade = self.panel_fade })
    tex.draw_texture(self.t_label, { y = self.panel_y, fade = self.panel_fade })
end

function Prize:draw_get()
    if self.get_visible then
        tex.draw_texture(self.t_get, { y = self.get_y, fade = self.get_fade })
    end
end

local GachaScene = {}
GachaScene.__index = GachaScene

function GachaScene.new(prize_frame)
    local self = setmetatable({}, GachaScene)
    self.t_background = texture("background")
    self.t_vignette = texture("vignette")
    self.don = GachaDon.new()
    self.globe = GachaGlobe.new()
    self.capsules = CapsuleRun.new()
    self.sparkles = Sparkles.new()
    self.big_capsule = BigCapsule.new()
    self.cloud = Cloud.new()
    self.flash = Flash.new()
    self.prize = Prize.new(prize_frame)
    self.f = 0
    return self
end

function GachaScene:update(f)
    self.f = f
    self.vignette_fade = track(f, { { 249, 255, 0, 1 } })
    self.don:update(f)
    self.globe:update(f)
    self.capsules:update(f)
    self.sparkles:update(f)
    self.big_capsule:update(f)
    self.cloud:update(f)
    self.flash:update(f)
    self.prize:update(f)
end

function GachaScene:draw()
    tex.draw_texture(self.t_background)
    if self.vignette_fade then
        tex.draw_texture(self.t_vignette, { fade = self.vignette_fade })
    end
    self.big_capsule:draw()
    self.prize:draw_message()
    self.prize:draw()
    self.flash:draw()
    self.cloud:draw()
    self.prize:draw_panel()
    self.don:draw()
    self.globe:draw_back()
    self.capsules.out:draw()
    self.don:draw_face()
    self.sparkles:draw()
    self.prize:draw_get()
    self.don:draw_lid()
    self.globe:draw_ring()
    self.capsules.hose:draw()
    self.globe:draw_front()
    self.capsules.fly:draw()

    if self.f >= 829 then
        tex.draw_rect(0, 0, 1280, 720, 0, 0, 0, 255)
    elseif self.f < 20 then
        tex.draw_rect(0, 0, 1280, 720, 0, 0, 0, 255 * (1 - self.f / 19))
    end
end

TournamentAttract = {}
TournamentAttract.__index = TournamentAttract

function TournamentAttract.new(current_ms)
    local self = setmetatable({}, TournamentAttract)
    self.now = current_ms
    self.t_info = texture("info")
    self.t_banner = texture("banner")
    self.t_banner_glow = texture("banner_glow")
    self:set_phase("title")
    return self
end

function TournamentAttract:set_phase(phase)
    self.phase = phase
    self.phase_ms = self.now
    self.cue = 1
    if phase == "title" and not self.bgm_started then

        self.bgm_started = true
        play("bgm")
        play("vo_start")
    end
end

function TournamentAttract:close()
    audio.stop_sound("gacha_bgm")
end

function TournamentAttract:update(current_ms)
    self.now = current_ms
    local elapsed = current_ms - self.phase_ms
    if self.phase == "title" and elapsed >= 2 * INFO_MS then
        self:set_phase("done")
    elseif self.phase == "gacha" then
        local f = elapsed / FRAME_MS
        while CUES[self.cue] and CUES[self.cue][1] <= f do
            play(CUES[self.cue][2])
            self.cue = self.cue + 1
        end
        self.gacha:update(f)
        if f >= GACHA_FRAMES then
            self:set_phase("title")
        end
    end
end

function TournamentAttract:can_spin()
    return self.phase == "title"
end

function TournamentAttract:spin(puchichara_id)

    self.gacha = GachaScene.new(math.max(0, math.min(14, puchichara_id - 49)))
    self:set_phase("gacha")
end

function TournamentAttract:is_finished()
    return self.phase == "done"
end

function TournamentAttract:draw_title()
    local elapsed = self.now - self.phase_ms
    tex.draw_texture(self.t_info, { frame = 0 })
    if elapsed >= INFO_MS then
        tex.draw_texture(self.t_info, { frame = 1, fade = math.min(1, (elapsed - INFO_MS) / INFO_FADE_MS) })
    end
    tex.draw_texture(self.t_banner)
    if math.floor(elapsed / FRAME_MS) % 20 < 9 then
        tex.draw_texture(self.t_banner_glow)
    end
end

function TournamentAttract:draw()
    if self.phase == "title" then
        self:draw_title()
    elseif self.phase == "gacha" then
        self.gacha:draw()
    end
end
