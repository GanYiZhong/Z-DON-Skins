KusudamaCounter = {}
KusudamaCounter.__index = KusudamaCounter

local FRAME_MS = 1000.0 / 60.0
local RED, WHITE, BLACK = { 230, 20, 30, 255 }, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function ramp(t, t0, t1, a, b, e)
    if t1 <= t0 then return b end
    local p = clamp((t - t0) / (t1 - t0), 0, 1)
    if e == "in" then p = p * p
    elseif e == "out" then p = p * (2 - p) end
    return a + (b - a) * p
end

-- 0 -> 1 -> 0 with a half period of `half` ms
local function tri(t, half)
    local u = (t % (half * 2)) / half
    return u <= 1 and u or 2 - u
end

-- Fade in over `in_ms`, out from `out0` to `out1`
local function envelope(t, in_ms, out0, out1)
    return math.min(ramp(t, 0, in_ms, 0, 1), ramp(t, out0, out1, 1, 0))
end

-- Ball size at rest and at the peak of a hit pulse, per stage (count * 6 / total)
local STAGE_REST     = {[0] = 1.0, 1.0, 1.02, 1.02, 1.04, 1.06}
local STAGE_PEAK     = {[0] = 1.01, 1.02, 1.04, 1.051, 1.071, 1.113}
-- Layer strength per stage: soft vignette, glow over the ball, speed lines
local STAGE_VIGNETTE = {[0] = 0.0, 0.1, 0.2, 0.4, 0.6, 0.8}
local STAGE_GLOW     = {[0] = 0.0, 0.0, 0.1, 0.2, 0.4, 1.0}
local STAGE_LINES    = {[0] = 0.0, 0.2, 0.4, 0.6, 0.8, 1.0}

-- Ball centre: texture.json y + move attribute at rest + half the image
local REST_MOVE = 472.0
local POP_SCALE = 1.06
local MISS_FALL_START = 11 * FRAME_MS
local MISS_FALL_END = 25 * FRAME_MS
local MISS_FALL_DISTANCE = 1150.0

-- Mascots that fly out of the popped ball; t is ms since each was placed (5 frames after the pop)
local function cotton_pose(t)
    return ramp(t, 0, 1000, 0, 250, "in"), ramp(t, 0, 1000, 0, -302, "in"),
           ramp(t, 0, 983, 1, 1.6, "in") * (0.9 + 0.1 * tri(t, 233.3)),
           envelope(t, 117, 883, 983), 0
end
local function bell_pose(t)
    local first = t < 608
    return first and ramp(t, 0, 600, 52, 417) or ramp(t, 617, 1000, 425, 664),
           first and ramp(t, 0, 600, 38, -232) or ramp(t, 617, 1000, -232, -66),
           ramp(t, 0, 983, 1, 1.6, "in"), envelope(t, 100, 867, 983),
           t < 550 and 0 or (t < 617 and 1 or 2)
end
local function bird_pose(t)
    local first = t < 175
    return first and ramp(t, 0, 167, 66, 169) or ramp(t, 183, 983, 180, 579, "out"),
           first and ramp(t, 0, 167, 46, 19) or ramp(t, 183, 983, 19, 312, "out"),
           first and ramp(t, 0, 167, 1, 1.113) or ramp(t, 183, 983, 1.126, 2, "out"),
           envelope(t, 100, 867, 1000),
           t < 267 and 0 or 1 + (math.floor((t - 267) / 50) % 2)
end
local function balloon_pose(t)
    local first = t < 125
    return first and ramp(t, 0, 117, 84, 146, "in") or ramp(t, 133, 1000, 157, 356, "in"),
           first and ramp(t, 0, 117, 117, 78, "in") or ramp(t, 133, 1000, 79, 590, "in"),
           ramp(t, 0, 1000, 1, 2, "in"), envelope(t, 83, 917, 1017),
           t < 233 and 0 or (t < 317 and 1 or (t < 383 and 2 or 3))
end
local function chick_pose(t)
    return 0, t < 325 and ramp(t, 0, 317, -36, -206, "out") or ramp(t, 333, 1000, -204, -118),
           ramp(t, 0, 1000, 1, 2, "out"), envelope(t, 100, 900, 1017),
           t < 333 and 0 or 1 + (math.floor((t - 333) / 50) % 2)
end

local function draw_pose(texture, left, left_frame, x, y, scale, alpha, frame)
    if alpha <= 0 then return end
    tex.draw_texture(texture, {
        frame = frame + (left and left_frame or 0), scale = scale, center = true,
        x = left and -x or x, y = y, fade = alpha,
    })
end

function KusudamaCounter.new(total)
    local self = setmetatable({}, KusudamaCounter)
    self.total = total
    self.count = 0
    self.stage = 0
    self.now = 0
    self.pop_ms = 0
    self.miss_ms = 0
    self.is_popped = false
    self.is_missed = false

    self.move          = tex.get_animation(11)
    self.renda_move    = tex.get_animation(13)
    self.renda_fade_in = tex.get_animation(14)
    self.stretch       = tex.get_animation(15)
    self.breathing     = tex.get_animation(16)
    self.renda_breathe = tex.get_animation(17)
    self.open          = tex.get_animation(19)
    self.renda_fade_out = tex.get_animation(20)
    self.fade_out      = tex.get_animation(21)

    self.move:start()
    self.renda_move:start()
    self.renda_fade_in:start()
    self.open:reset()
    self.renda_fade_out:reset()
    self.fade_out:reset()

    self.t_kusudama = tex.get_texture("game/kusudama/kusudama")
    -- "連打!!" as text so it follows the language; black rim under a white-outlined red fill
    self.renda_cfg = tex.get_skin_config("kusudama_renda")
    local label, fs = tex.skin_text("kusudama_renda"), self.renda_cfg.font_size
    self.renda_rim  = text.create_raw_text(label, fs, BLACK, BLACK, false, fs * 0.22)
    self.renda_text = text.create_raw_text(label, fs, RED, WHITE, false, fs * 0.1)
    self.t_counter  = tex.get_texture("game/kusudama/counter")

    -- Effect layers (glows, speed lines, mascots); only used when the skin has all of them
    self.fx = true
    for _, key in ipairs({"glow", "lines", "vignette", "cotton", "bell", "bird", "balloon", "chick"}) do
        local t = tex.get_texture("game/kusudama/" .. key)
        self[key] = t
        if not t then self.fx = false end
    end
    return self
end

-- Skins with the effect layers keep the counter on screen while the ball falls after a failed kusudama.
function KusudamaCounter:miss(current_ms)
    if not self.fx or self.is_popped or self.is_missed then return end
    self.is_missed = true
    self.miss_ms = current_ms
end

function KusudamaCounter:update_count(count)
    if self.count == count then return end
    self.count = count
    if self.total > 0 then self.stage = math.min(5, count * 6 // self.total) end
    self.stretch:start()
    self.breathing:start()
    if count == self.total then
        self.is_popped = true
        self.pop_ms = self.now
        self.open:start()
        self.renda_fade_out:start()
        self.fade_out:start()
    end
end

function KusudamaCounter:update(current_ms, count)
    self.now = current_ms
    self.move:update(current_ms)
    self.renda_move:update(current_ms)
    self.renda_fade_in:update(current_ms)
    self.renda_fade_out:update(current_ms)
    self.fade_out:update(current_ms)
    self.stretch:update(current_ms)
    self.breathing:update(current_ms)
    if self.renda_move.is_finished and not self.renda_breathe.is_started then
        self.renda_breathe:start()
    end
    self.renda_breathe:update(current_ms)
    self.open:update(current_ms)
    self:update_count(count)
end

function KusudamaCounter:has_popped() return self.is_popped end
function KusudamaCounter:has_missed() return self.is_missed end

function KusudamaCounter:is_finished()
    if self.is_missed then return self.now - self.miss_ms >= MISS_FALL_END end
    return self.fade_out.is_finished
end

function KusudamaCounter:draw_mascots(pop_t)
    local t = pop_t - 5 * FRAME_MS
    if t < 0 then return end
    for _, left in ipairs({false, true}) do
        draw_pose(self.cotton,  left, 1, cotton_pose(t))
        draw_pose(self.bell,    left, 3, bell_pose(t))
        draw_pose(self.bird,    left, 3, bird_pose(t))
        draw_pose(self.balloon, left, 4, balloon_pose(t))
    end
    draw_pose(self.chick, false, 0, chick_pose(t))
end

function KusudamaCounter:draw_fx()
    local now = self.now
    local popped, missed = self.is_popped, self.is_missed
    local pop_t = popped and now - self.pop_ms or 0
    local miss_t = missed and now - self.miss_ms or 0
    local stage = self.stage
    local rest = popped and POP_SCALE or STAGE_REST[stage]
    local scale = rest
    if not popped and not missed then
        local pulse = clamp((self.breathing.attribute - 1.0) / 0.05, 0, 1)
        scale = rest + (STAGE_PEAK[stage] - rest) * pulse
    end
    local fall = missed and ramp(miss_t, MISS_FALL_START, MISS_FALL_END, 0, MISS_FALL_DISTANCE, "in") or 0
    local y = self.move.attribute + fall
    local dy = y - REST_MOVE  -- ball centre follows the drop
    local live = missed and ramp(miss_t, 0, 10 * FRAME_MS, 1, 0) or 1.0
    local glow_pulse = 1.0 - 0.5 * tri(now, 250)
    local vignette_pulse = 0.4 - 0.2 * tri(now, 250)

    if popped then
        tex.draw_texture(self.vignette, { fade = vignette_pulse * ramp(pop_t, 933, 1083, 1, 0) })
    elseif STAGE_VIGNETTE[stage] > 0 then
        tex.draw_texture(self.vignette, { fade = STAGE_VIGNETTE[stage] * vignette_pulse * live })
    end
    if not missed and not popped then
        tex.draw_texture(self.glow, { scale = scale, center = true, y = dy, fade = glow_pulse })
    end
    tex.draw_texture(self.t_kusudama, { frame = math.floor(self.open.attribute), scale = scale, center = true, y = y, fade = self.fade_out.attribute })
    if popped then
        tex.draw_texture(self.glow, {
            scale = ramp(pop_t, 0, 333, 1, 1.4), center = true, y = dy,
            fade = ramp(pop_t, 0, 333, 1, 0) * glow_pulse,
        })
        self:draw_mascots(pop_t)
    elseif STAGE_GLOW[stage] > 0 then
        tex.draw_texture(self.glow, {
            scale = scale, center = true, y = dy,
            fade = STAGE_GLOW[stage] * glow_pulse * live,
        })
    end
    local lines = popped and ramp(pop_t, 950, 1083, 1, 0) or STAGE_LINES[stage] * live
    if lines > 0 then
        tex.draw_texture(self.lines, { frame = math.floor(now / 50) % 3, fade = 0.3 * lines })
    end
end

function KusudamaCounter:draw_counter()
    if not self.move.is_finished or self.is_popped then return end
    local remaining = math.max(0, self.total - self.count)
    if remaining == 0 then return end
    local digits = tostring(remaining)
    local margin = 160 * tex.get_screen_scale()
    local total_width = #digits * margin
    local stretch = self.stretch.attribute
    for i = 1, #digits do
        tex.draw_texture(self.t_counter, {
            frame = tonumber(digits:sub(i, i)),
            x = -(total_width / 2) + (i - 1) * margin,
            y = -stretch, y2 = stretch,
        })
    end
end

function KusudamaCounter:draw()
    local renda_fade = math.min(self.renda_fade_in.attribute, self.renda_fade_out.attribute)
    if self.fx then
        self:draw_fx()
        if self.is_missed then return end
    else
        tex.draw_texture(self.t_kusudama, {
            frame = math.floor(self.open.attribute), scale = self.breathing.attribute, center = true,
            y = self.move.attribute, fade = self.fade_out.attribute,
        })
    end
    local dy = self.renda_move.attribute + self.renda_breathe.attribute
    for _, t in ipairs({ self.renda_rim, self.renda_text }) do
        t:draw({ x = self.renda_cfg.x - t.width / 2, y = self.renda_cfg.y + dy - t.height / 2, fade = renda_fade })
    end
    self:draw_counter()
end

return KusudamaCounter
