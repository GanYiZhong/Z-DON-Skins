local Timing = require("background/bg_objects/timing")
require("campaign/camera_failed")

MacPhoto = {}
MacPhoto.__index = MacPhoto

local S = tex.get_screen_scale()
local KEEP_S = 15
local REWARD_COSTUME = 43 -- チーズバーガー, worn
local EXTRA_COSTUME = 78 -- ダブルバーガーどん, unlocked too
local CAMERA = { 330, 63, 620, 459 }
local PHASE_MS = { intro = 1000, open = 1833, keep_out = 150, fadeout = 267 }
local NEXT_PHASE = { intro = "open", open = "keep", keep_out = "shoot" }
local SHOT_MS = 2717
local RESULT_SKIP_MS, RESULT_MS = 9267, 15050
local NOTICE_SKIP_MS, NOTICE_MS = 783, 6217
local TITLE_MS, LOOP_START_MS, LOOP_MS = 5917, 6883, 1200
local WHITE, BLACK = { 255, 255, 255, 255 }, { 0, 0, 0, 255 }

local CUES = {
    { "intro", 67, "mac_se_mdon_up" }, { "open", 0, "mac_se_open" }, { "keep", 0, "mac_vo_mdon2" },
    { "shoot", 500, "mac_vo_cheese" }, { "shoot", 2683, "mac_se_shutter" }, { "shoot", 4967, "mac_se_metamor" },
    { "notice", 0, "mac_se_notice" },
}
-- sparkles: ms after the title appears, centre x, y
local BURST = {
    { 0, 640, 14 }, { 0, 640, 118 }, { 50, 560, 22 }, { 50, 720, 22 }, { 100, 514, 126 }, { 100, 766, 126 },
    { 150, 416, 30 }, { 150, 864, 30 }, { 667, 640, 481 }, { 667, 640, 600 }, { 717, 537, 470 }, { 717, 743, 470 },
    { 767, 463, 586 }, { 767, 817, 586 }, { 817, 398, 452 }, { 817, 882, 452 },
}
local LOOP = {
    { 0, 468, 192 }, { 167, 438, 224 }, { 267, 875, 264 }, { 383, 814, 374 },
    { 483, 504, 411 }, { 617, 414, 300 }, { 667, 858, 222 }, { 683, 770, 162 },
}
local PAL_IDLE = { 0, 1, 0, 1, 2, 1 }

local function play(name)
    if audio.has_sound(name) then audio.play_sound(name, name:find("_vo_") and "voice" or "sound") end
end

local function clamp01(v) return math.max(0.0, math.min(1.0, v)) end
local function ramp(t, at, ms) return clamp01((t - at) / ms) end
local function draw(texture, opts) tex.draw_texture(texture, opts or {}) end

local function screen_rect(r, g, b, a)
    tex.draw_rect(0, 0, tex.get_screen_width(), tex.get_screen_height(), r, g, b, a)
end

local function lines(key, size)
    local out = {}
    for line in tex.skin_text(key):gmatch("[^\n]+") do
        out[#out + 1] = text.create_raw_text(line, math.floor(size * S), WHITE, BLACK, false, 5, 2.0)
    end
    return out
end

local function draw_lines(list, cx, cy, pitch, max_w, fade)
    for i, t in ipairs(list) do
        local y = (cy + (i - (#list + 1) / 2) * pitch) * S
        local scale = math.min(1, max_w * S / t.width)
        t:draw({ x = cx * S - t.width / 2, y = y - t.height / 2, scale = scale, fade = fade })
    end
end

-- grows in while fading in, then swells a little more while fading out
local function draw_sparkle(texture, cx, cy, t)
    if t < 0 or t >= 467 then return end
    local size, fade
    if t < 317 then
        size, fade = 13 + 64 * t / 317, 0.05 + 0.95 * t / 317
    else
        size, fade = 77 + 17 * (t - 317) / 150, 0.9 - 0.8 * (t - 317) / 150
    end
    draw(texture, { x = (cx - 48) * S, y = (cy - 48) * S, scale = size / 96, center = true, fade = fade })
end

function MacPhoto.new()
    local self = setmetatable({}, MacPhoto)
    self.tex = {}
    for _, key in ipairs({
        "bg", "bg_bright", "footer", "logo", "mecha", "body_outline", "body", "face", "shell_l_outline", "shell_l",
        "shell_r_outline", "shell_r", "stem_outline", "stem", "bracket_outline", "bracket", "cap_outline", "cap",
        "ring_outline", "ring", "ring_low_outline", "ring_low", "rod_outline", "rod", "pole_outline", "pole",
        "pole_lit", "haitsu", "cheese", "cheese_pose", "cheese_wink", "photo_bg", "photo_side", "glare", "cloud",
        "burger_katsu", "burger_don", "pose_title", "sparkle", "get_text", "note_1", "note_2", "pill", "notice",
        "pal_don", "pal_katsu", "smoke", "keep_box",
    }) do
        self.tex[key] = tex.get_texture("campaign/mac_photo/" .. key)
    end
    self.timer      = tex.get_texture("campaign/timer/timer")
    self.timer_glow = tex.get_texture("campaign/timer/timer_glow")
    self.digits     = tex.get_texture("campaign/timer/digits")
    self.pose_text   = lines("campaign_mac_pose", 42)
    self.reward_text = lines("campaign_mac_reward", 37)
    self.camera_open = camera.open()
    if audio.has_sound("mac_bgm") then audio.play_sound("mac_bgm", "music") end
    self.save_failed = false
    self.now = tex.get_current_ms()
    self:enter("intro")
    return self
end

function MacPhoto:moves(list, scale)
    local out = Timing.chain_moves(list, 1, scale or S)
    for _, m in ipairs(out) do self.anims[#self.anims + 1] = m end
    return out
end

function MacPhoto:enter(phase)
    if phase == "notice" then self.noticed = true end
    self.phase = phase
    self.t0 = self.now
    self.cue_t = -1
    self.anims = {}
    self.m = {}
    local m = self.m
    if phase == "failed" then
        self.fail = CameraFailed.new(self.now)
    elseif phase == "intro" then
        -- rises out of the floor, overshoots, then sinks into its slot
        m.mecha_y = self:moves({ { 267, -224, "out" }, { 117, 12, "in" }, { 283, 0 }, { 217, 76, "out" },
                                 { 100, -13, "in" } })
    elseif phase == "open" then
        m.shell_y   = self:moves({ { 167, -18, "out" }, { 50, 3, "in" } })
        m.shell_l_x = self:moves({ { 233, 0 }, { 183, -50, "out" }, { 67, 7, "in" } })
        m.shell_r_x = self:moves({ { 233, 0 }, { 183, 44, "out" }, { 67, -7, "in" } })
        local rise = { { 483, 0 }, { 250, -101, "out" }, { 67, 8, "in" } }
        m.mast_y = self:moves(rise)
        -- the head dips, then shoots to the top of the growing rod
        local dip = Timing.concat(rise, { { 67, 8, "in" }, { 17, 0 } })
        m.head_y = self:moves(Timing.concat(dip, { { 200, -497, "out" }, { 50, 9, "in" } }))
        m.ring_y = self:moves(Timing.concat(dip, { { 200, -32, "out" }, { 50, 9, "in" } }))
        m.rod_h  = self:moves({ { 883, 0 }, { 183, 390, "out" } })
        m.pole_l_x = self:moves({ { 1183, 0 }, { 217, -368, "in" }, { 50, 8, "out" } })
        m.pole_r_x = self:moves({ { 1183, 0 }, { 217, 352, "in" }, { 50, -8, "out" } })
    elseif phase == "shoot" then
        m.pal_x   = self:moves({ { 683, 0 }, { 883, -568, "out" } })
        m.pal_y   = self:moves({ { 683, 0 }, { 400, -142, "out" }, { 483, 46, "in" } })
        m.pal_rot = self:moves({ { 683, 0 }, { 883, -20, "out" } }, 1)
        m.haitsu_scale = self:moves({ { 667, 0 }, { 100, 30, "out" }, { 200, -10, "in" } }, 1)
        m.cheese_x = self:moves({ { 1333, 0 }, { 383, -248, "out" }, { 67, 0 }, { 167, 46, "in" },
                                  { 67, -11, "out" } })
        m.card_y = self:moves({ { 1933, 0 }, { 400, -306, "out" }, { 217, 20, "in" } })
        -- burgers crouch, jump apart and land in the corners
        m.burger_x = self:moves({ { 6200, 0 }, { 467, 156, "out" }, { 400, 154, "in" } })
        m.burger_y = self:moves({ { 6200, 0 }, { 467, -375, "out" }, { 400, 215, "in" } })
        m.burger_scale  = self:moves({ { 6200, 0 }, { 467, 10, "out" } }, 1)
        m.burger_squash = self:moves({ { 6017, 0 }, { 117, -19, "out" }, { 50, 19, "in" }, { 850, 0 },
                                       { 100, -20, "out" }, { 83, 20, "in" } })
    end
end

function MacPhoto:elapsed() return self.now - self.t0 end
function MacPhoto:waiting() return self.phase == "keep" end
function MacPhoto:after_result() return self.phase == "notice" or self.phase == "fadeout" end

function MacPhoto:seconds_left()
    if not self:waiting() then return KEEP_S end
    return math.max(0, KEEP_S - math.floor(self:elapsed() / 1000))
end

function MacPhoto:update(current_ms)
    self.now = current_ms
    if self.done then return end
    for _, a in ipairs(self.anims) do a:update(current_ms) end
    local t = self:elapsed()
    for _, cue in ipairs(CUES) do
        if cue[1] == self.phase and cue[2] > self.cue_t and cue[2] <= t then play(cue[3]) end
    end
    self.cue_t = t
    if self:waiting() then
        local s = self:seconds_left()
        if s < 10 and s ~= self.last_tick then
            self.last_tick = s
            play("mac_se_pixtsu")
        end
        if s == 0 then self:shoot() end
    elseif self.phase == "keep_out" and t >= PHASE_MS.keep_out and not self.camera_open then
        self:enter("failed") -- no camera, no photo
    elseif self.phase == "failed" then
        self.fail:update(current_ms)
        if self.fail:is_done() then
            self.done = true
            self:close()
        end
    elseif self.phase == "shoot" and t >= RESULT_MS then
        self:enter(self.save_failed and "notice" or "fadeout")
    elseif self.phase == "notice" and t >= NOTICE_MS then
        self:enter("fadeout")
    elseif self.phase == "fadeout" and t >= PHASE_MS.fadeout then
        self.done = true
        self:close()
    elseif NEXT_PHASE[self.phase] and t >= PHASE_MS[self.phase] then
        self:enter(NEXT_PHASE[self.phase])
    end
    local frozen = (self.phase == "shoot" and self:elapsed() >= SHOT_MS) or self:after_result()
    if self.camera_open and not frozen then camera.update() end
end

function MacPhoto:shoot()
    audio.stop_sound("mac_vo_mdon2")
    self:enter("keep_out")
end

function MacPhoto:close()
    audio.stop_sound("mac_bgm")
    if self.camera_open then
        camera.close()
        self.camera_open = false
    end
end

function MacPhoto:set_save_failed(failed) self.save_failed = failed end
function MacPhoto:is_done() return self.done == true end
function MacPhoto:get_reward() return self.fail and -1 or REWARD_COSTUME end
function MacPhoto:get_unlock() return self.fail and -1 or EXTRA_COSTUME end

function MacPhoto:input(action)
    if action ~= 3 or self.done then return false end
    local t = self:elapsed()
    if self:waiting() then
        self:shoot()
    elseif self.phase == "shoot" and t >= RESULT_SKIP_MS then
        self:enter(self.save_failed and "notice" or "fadeout")
    elseif self.phase == "notice" and t >= NOTICE_SKIP_MS then
        self:enter("fadeout")
    else
        return false
    end
    return true
end

function MacPhoto:draw_halves(texture, fade)
    draw(texture, { fade = fade })
    draw(texture, { x = -640 * S, fade = fade, mirror = "horizontal" })
end

-- the two pals mirror each other; they turn about their centre
function MacPhoto:draw_pals(frame, crouch, x, y, rot)
    local w, h = 128 * S, 104 * S
    for i, pal in ipairs({ self.tex.pal_don, self.tex.pal_katsu }) do
        local dir = i == 1 and 1 or -1
        draw(pal, { frame = frame, x = dir * x + w, y = y + h + crouch, y2 = -crouch, rotation = dir * rot,
                    origin = { w, h } })
    end
end

-- outlines first, then fills, like Lumen
function MacPhoto:draw_machine(t)
    local tx, m = self.tex, self.m
    local open = self.phase == "open"
    local sum = function(list) return open and Timing.sum(list) or 0 end
    local shell_y = open and 15 * S + sum(m.shell_y) or 0
    local shell_l = open and 43 * S + sum(m.shell_l_x) or 0
    local shell_r = open and -37 * S + sum(m.shell_r_x) or 0
    local mast_y = open and 93 * S + sum(m.mast_y) or 0
    local mast = not open or t >= 50
    local head = open and t >= 50 and t < 1133
    local launched = head and t >= 883
    local head_y = sum(m.head_y)
    local rod_h = 80 * S + sum(m.rod_h)

    local function parts(suffix)
        draw(tx["shell_l" .. suffix], { x = shell_l, y = shell_y })
        draw(tx["body" .. suffix])
        if mast then
            draw(tx["stem" .. suffix], { y = mast_y })
            draw(tx["bracket" .. suffix], { y = mast_y })
        end
        if head then
            draw(tx["cap" .. suffix], { y = 573 * S + head_y })
            draw(tx["ring" .. suffix], { y = 614 * S + head_y })
            draw(tx["ring" .. suffix], { y = 622 * S + sum(m.ring_y) })
            if launched then
                draw(tx["rod" .. suffix], { y = 532 * S - rod_h, y2 = rod_h - 8 * S })
            else
                draw(tx["ring_low" .. suffix], { y = 85 * S + head_y })
            end
        end
        draw(tx["shell_r" .. suffix], { x = shell_r, y = shell_y })
    end
    parts("_outline")
    parts("")
    if not open or t >= 1133 then
        -- they slide apart plain, then light up as the window opens
        local lit = open and ramp(t, 1583, 100) or 1
        if lit < 1 then
            local left = 264 * S + 360 * S + sum(m.pole_l_x)
            local right = 968 * S - 344 * S + sum(m.pole_r_x)
            for _, key in ipairs({ "pole_outline", "pole" }) do
                draw(tx[key], { x = left })
                draw(tx[key], { x = right })
            end
        end
        draw(tx.pole_lit, { x = 264 * S, fade = lit, mirror = "horizontal" })
        draw(tx.pole_lit, { x = 968 * S, fade = lit })
    end
    draw(tx.face)
end

function MacPhoto:draw_timer(fade)
    draw(self.timer_glow, { x = 151.4 * S, y = -236.7 * S, fade = fade * 0.3 })
    draw(self.timer, { x = 152.8 * S, y = -235.3 * S, fade = fade })
    local s = tostring(self:seconds_left())
    local pitch, scale = 34 * S, 0.8
    local left = 1175 * S - (#s * pitch) / 2 - (48 * S * scale - pitch) / 2
    for i = 1, #s do
        draw(self.digits, {
            frame = tonumber(s:sub(i, i)), x = left + (i - 1) * pitch, y = -225.5 * S, scale = scale, fade = fade,
        })
    end
end

function MacPhoto:draw_camera()
    camera.draw(CAMERA[1] * S, CAMERA[2] * S, CAMERA[3] * S, CAMERA[4] * S)
end

-- before the photo: the mecha-Don's frame with the camera behind it
function MacPhoto:draw_window(t)
    local tx, m = self.tex, self.m
    local phase = self.phase
    self:draw_camera()
    if phase == "failed" then self.fail:draw_window() end
    if phase == "shoot" then
        -- ハイッ, チーズ!! and the pose card sit in the camera window, under the frame
        if t >= 667 and t < 1167 then
            local scale = (80 + Timing.sum(m.haitsu_scale)) / 100
            draw(tx.haitsu, { scale = scale, center = true, fade = ramp(t, 667, 100) * (1 - ramp(t, 983, 183)) })
        end
        if t >= 1333 then draw(tx.cheese, { x = 214 * S + Timing.sum(m.cheese_x), fade = ramp(t, 1333, 383) }) end
        if t >= 1933 then draw(tx.cheese_pose, { y = 286 * S + Timing.sum(m.card_y) }) end
    end
    self:draw_halves(tx.bg)
    local bright = phase == "intro" and 1 or phase == "open" and 1 - ramp(t, 1583, 100) or 0
    if bright > 0 then self:draw_halves(tx.bg_bright, bright) end
    draw(tx.footer)

    if phase == "intro" then
        draw(tx.mecha, { y = 149 * S + Timing.sum(m.mecha_y) })
    else
        self:draw_machine(t)
    end

    if phase ~= "shoot" then
        self:draw_pals(PAL_IDLE[math.floor(self.now / 500) % #PAL_IDLE + 1], 0, 0, 0, 0)
    elseif t < 417 then
        self:draw_pals(0, 0, 0, 0, 0)
    elseif t < 683 then
        self:draw_pals(1, 20 * S * ramp(t, 417, 267), 0, 0, 0)
    elseif t < 1567 then
        self:draw_pals(2, 0, Timing.sum(m.pal_x), Timing.sum(m.pal_y), Timing.sum(m.pal_rot))
    end
    draw(tx.logo)

    if phase == "keep" or phase == "keep_out" then
        local fade = phase == "keep" and ramp(t, 0, 133) or 1 - ramp(t, 0, 150)
        -- the instruction blinks: out over a second (ease-in), back over a second (ease-out)
        local u = (t % 2000) / 1000
        local blink = phase == "keep" and (u < 1 and 1 - u * u or 1 - (2 - u) * (2 - u)) or 1
        draw(tx.keep_box, { fade = fade })
        draw_lines(self.pose_text, 640, 586, 57, 704, fade * blink)
        self:draw_timer(fade)
    end
    if phase == "shoot" and t >= 2500 then
        screen_rect(0, 0, 0, 255 * ramp(t, 2500, 133))
    end
    if phase == "failed" then self.fail:draw_overlay() end
end

function MacPhoto:draw_burgers(t)
    local m = self.m
    local live = self.phase == "shoot"
    local bx = live and Timing.sum(m.burger_x) or 310 * S
    local by = live and Timing.sum(m.burger_y) or -160 * S
    local scale = live and (90 + Timing.sum(m.burger_scale)) / 100 or 1
    local squash = live and Timing.sum(m.burger_squash) or 0
    local w, h = 352 * S * scale, 240 * S * scale
    -- they start side by side at the frame centre (x 640 -+ 156, y 484) and squash onto their bottom
    for i, burger in ipairs({ { self.tex.burger_katsu, 1, 930 }, { self.tex.burger_don, -1, -2 } }) do
        local cx = (640 + burger[2] * 156) * S + burger[2] * bx
        local bottom = 484 * S + by + h / 2
        draw(burger[1], {
            x = cx - w / 2 - burger[3] * S, y = bottom - (h + squash) - 205 * S,
            x2 = w - 352 * S, y2 = h + squash - 240 * S,
        })
    end
end

function MacPhoto:draw_smoke(t)
    local tx = self.tex
    if t < 5117 then
        local size = 128 + 592 * (t - 5000) / 117
        draw(tx.cloud, { x = (640 - size / 2) * S, y = (432 - size / 2) * S, x2 = (size - 320) * S,
                         y2 = (size - 320) * S })
        return
    end
    local step = math.min(2, math.floor((t - 5117) / 150))
    local fade = step == 2 and 1 - 0.89 * ramp(t, 5417, 150) or 1
    draw(tx.smoke, { frame = step, y = ({ 60, 39, 18 })[step + 1] * S, x2 = 400 * S, y2 = 400 * S, fade = fade })
end

-- after the photo: the polaroid, the burger costumes and the texts
function MacPhoto:draw_result(t, text_fade)
    local tx = self.tex
    self:draw_camera()
    if t < 5100 then draw(tx.cheese_wink, { fade = 1 - ramp(t, 5067, 33) }) end
    self:draw_halves(tx.bg)
    draw(tx.footer)
    draw(tx.photo_bg)
    self:draw_halves(tx.photo_side)
    draw(tx.glare, { fade = 0.5 })
    draw(tx.logo)
    if t < SHOT_MS + 467 then screen_rect(255, 255, 255, 255 * (1 - ramp(t, SHOT_MS, 467))) end

    draw(tx.pose_title, { fade = ramp(t, TITLE_MS, 317) * text_fade })
    draw(tx.get_text, { fade = ramp(t, 6583, 317) * text_fade })
    local labels = ramp(t, 7150, 183) * text_fade
    draw(tx.note_1, { fade = labels })
    draw(tx.note_2, { fade = labels })
    draw(tx.pill, { fade = labels })
    draw(tx.pill, { x = 962 * S, fade = labels })
    draw_lines(self.reward_text, 159, 510, 0, 280, labels)
    draw_lines(self.reward_text, 1121, 510, 0, 280, labels)

    if t >= 5100 then self:draw_burgers(t) end
    if t >= 5000 and t < 5567 then self:draw_smoke(t) end
    for _, s in ipairs(BURST) do draw_sparkle(tx.sparkle, s[2], s[3], t - TITLE_MS - s[1]) end
    if t >= LOOP_START_MS then
        local lt = (t - LOOP_START_MS) % LOOP_MS
        for _, s in ipairs(LOOP) do draw_sparkle(tx.sparkle, s[2], s[3], lt - s[1]) end
    end
end

function MacPhoto:draw()
    if self.done then return end
    screen_rect(0, 0, 0, 255)
    local t = self:elapsed()
    if self.phase == "shoot" and t >= SHOT_MS then
        self:draw_result(t, 1)
    elseif self:after_result() then
        -- the result stays up; when saving failed the notice replaces its texts
        local notice = self.phase == "notice"
        self:draw_result(RESULT_MS + t, notice and 1 - ramp(t, 0, 150) or self.noticed and 0 or 1)
        if self.noticed then draw(self.tex.notice, { fade = notice and ramp(t, 117, 133) or 1 }) end
        if self.phase == "fadeout" then screen_rect(0, 0, 0, 255 * ramp(t, 17, 183)) end
    else
        self:draw_window(t)
    end
end
