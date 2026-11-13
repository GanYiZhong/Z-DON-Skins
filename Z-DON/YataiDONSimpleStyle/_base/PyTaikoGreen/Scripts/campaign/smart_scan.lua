local Timing = require("background/bg_objects/timing")
require("campaign/camera_failed")

SmartScan = {}
SmartScan.__index = SmartScan

local S = tex.get_screen_scale()
local DIR = "campaign/smart_scan"
local PHASE_MS = { title = 3267, gift = 3583, open = 967, keep_out = 150, fadeout = 1033 }
local NEXT_PHASE = { title = "gift", gift = "open", open = "keep" }
local TITLE_OUT_MS, TITLE_END_MS = 3183, 3400
local KEEP_S = 30

local FOUND_MS = 5000
local LOCKON_MS, SUCCESS_MS, PRESENT_MS, END_MS, FADEOUT_MS = 33, 2433, 4417, 7750, 12200
local CAMERA = { 334, 66, 612, 452 }
local WHITE, BLACK = { 255, 255, 255, 255 }, { 0, 0, 0, 255 }

local PRIZES = { v3c = { 0, 1, 2, 3, 4, 5, 6, 7 }, korokoro = { 8 }, chao = { 9 } }
local COSTUME = { [0] = 25, 26, 27, 28, 29, 30, 31, 35, 64, 65 }

local CUES = {
    { "title", 0, "smart_vo_campaign" }, { "gift", 150, "smart_vo_moraeru" }, { "gift", 150, "smart_se_popup" },
    { "open", 0, "smart_se_boardslide" }, { "open", 483, "smart_se_frame" }, { "keep", 0, "smart_vo_advice" },
    { "success", 0, "mac_se_shutter" }, { "success", 33, "smart_se_lockon" }, { "success", 1117, "smart_se_hit" },
    { "success", 1550, "smart_se_hit" }, { "success", 1700, "smart_se_hit" }, { "success", 1867, "smart_se_hit" },
    { "success", 2117, "smart_se_hit" }, { "success", 2433, "smart_vo_success" },
    { "success", 2433, "smart_se_success" }, { "success", 4683, "smart_se_itembound" },
    { "success", 5850, "mac_se_metamor" }, { "success", 7117, "smart_vo_kisekaeget" },
}
-- sparkle bursts around the lock-on: ms, offset from the window centre, scale
-- rings close in one after another: start, gone (ms into the lock-on)
local RINGS = { { 33, 817 }, { 200, 983 }, { 367, 1000 } }
local BURSTS = { { 1550, 91, -106, 1 }, { 1700, -134, 30, 1.2 }, { 1867, 54, 106, 1.5 }, { 2117, -77, -134, 0.8 } }
-- twinkles around the present: ms into the present, offset from (540, 494), scale
local TWINKLES = {
    { 1450, -416, -230, 1 }, { 1450, -338, -14, 1.22 }, { 1450, 492, -314, 1.21 }, { 1450, 636, -92, 1 },
    { 1817, 530, -54, 1 }, { 1817, -299, -159, 1.22 }, { 1817, -377, -314, 1.21 }, { 1817, 672, -243, 1 },
    { 2167, -299, -53, 1 }, { 2167, -477, -139, 1.3 }, { 2167, 589, -421, 1.33 }, { 2167, 542, -166, 1 },
    { 2167, -426, -433, 1.45 }, { 2167, 672, -275, 1.29 },
}

local function play(name)
    if audio.has_sound(name) then audio.play_sound(name, name:find("_vo_") and "voice" or "sound") end
end

local function clamp01(v) return math.max(0.0, math.min(1.0, v)) end
local function ramp(t, at, ms) return clamp01((t - at) / ms) end
local function ease_in(u) return u * u end
local function ease_out(u) return u * (2 - u) end

local function screen_rect(r, g, b, a)
    tex.draw_rect(0, 0, tex.get_screen_width(), tex.get_screen_height(), r, g, b, a)
end

-- draws `texture` scaled by sx / sy about its centre, moved by dx / dy (unscaled pixels)
local function draw(texture, opts)
    opts = opts or {}
    local sx, sy = opts.sx or 1, opts.sy or opts.sx or 1
    if sx == 1 and sy == 1 then
        tex.draw_texture(texture.id, { x = (opts.dx or 0) * S, y = (opts.dy or 0) * S, fade = opts.fade,
                                       frame = opts.frame, mirror = opts.mirror })
        return
    end
    local w, h = texture.w, texture.h
    tex.draw_texture(texture.id, {
        x = w * (1 - sx) / 2 + (opts.dx or 0) * S, y = h * (1 - sy) / 2 + (opts.dy or 0) * S,
        x2 = w * (sx - 1), y2 = h * (sy - 1), fade = opts.fade, frame = opts.frame, mirror = opts.mirror,
    })
end

local function lines(key, size)
    local out = {}
    for line in tex.skin_text(key):gmatch("[^\n]+") do
        out[#out + 1] = text.create_raw_text(line, math.floor(size * S), WHITE, BLACK, false, 5, 2.0)
    end
    return out
end

-- left: left edge (nil centres on cx)
local function draw_lines(list, cx, cy, pitch, max_w, fade, left)
    for i, t in ipairs(list) do
        local y = (cy + (i - (#list + 1) / 2) * pitch) * S
        local scale = math.min(1, max_w * S / t.width)
        local x = left and left * S or cx * S - t.width * scale / 2
        t:draw({ x = x, y = y - t.height * scale / 2, scale = scale, fade = fade })
    end
end

function SmartScan.new(id, opts)
    local self = setmetatable({}, SmartScan)
    opts = opts or {}
    self.opts = opts
    self.id = PRIZES[id] and id or "v3c"
    self.tex = {}
    local function load(name, key)
        local dir = DIR
        local path = opts.tex and opts.tex[name]
        if path then dir, key = path:match("^(.*)/([^/]+)$") end
        local id = tex.get_texture(dir .. "/" .. key) -- loads the folder, so before the info lookup
        local info = tex.get_texture_info(dir:match("[^/]+$"), key) -- textures are keyed by their own folder
        self.tex[name] = { id = id, w = info and info.x2[1] or 0,
                           h = info and info.y2[1] or 0 }
    end
    for _, key in ipairs({
        "bg", "title_bg", "gift_note", "scroll", "guide_text", "frame", "window", "skip_label", "keep_box", "ring",
        "rays", "stars", "stars_white", "flash", "success_text", "don_jump", "box", "box_open", "box_empty", "poof",
        "flowers", "sparkle", "name_bar", "get_text", "prize", "smoke",
    }) do
        load(key, key)
    end
    for _, key in ipairs({ "title", "gift", "side", "guide" }) do load(key, key .. "_" .. self.id) end
    if self.id ~= "v3c" then load("deco", "deco_" .. self.id) end
    for name in pairs(opts.tex or {}) do
        if not self.tex[name] then load(name, name) end
    end
    self.timer      = tex.get_texture("campaign/timer/timer")
    self.timer_glow = tex.get_texture("campaign/timer/timer_glow")
    self.digits     = tex.get_texture("campaign/timer/digits")
    self.keep_text  = lines("campaign_smart_keep", 39)
    self.keep_alt   = lines("campaign_smart_keep_alt", 39)
    local pool = PRIZES[self.id]
    self.prize = opts.prize or pool[math.random(#pool)]
    self.prize_name = lines(opts.prize_text or ("campaign_smart_prize_" .. self.prize), 32)
    self.camera_open = camera.open()
    self.bgm = opts.bgm == nil and "smart_bgm" or opts.bgm -- false: the caller owns the music
    if self.bgm and audio.has_sound(self.bgm) then audio.play_sound(self.bgm, "music") end
    self.now = tex.get_current_ms()
    self:enter(opts.skip_title and "gift" or "title")
    return self
end

function SmartScan:moves(list, scale)
    local out = Timing.chain_moves(list, 1, scale or S)
    for _, m in ipairs(out) do self.anims[#self.anims + 1] = m end
    return out
end

function SmartScan:enter(phase)
    self.phase = phase
    self.t0 = self.now
    self.cue_t = -1
    if phase == "failed" then self.fail = CameraFailed.new(self.now) end
    if phase == "fadeout" or phase == "failed" then return end -- the success scene keeps moving under the fade
    self.anims = {}
    self.m = {}
    local m = self.m
    if phase == "open" then
        m.side_y   = self:moves({ { 183, -560, "out" } })
        m.scroll_y = self:moves({ { 183, 566, "out" } })
    elseif phase == "success" then
        local s = SUCCESS_MS
        m.jump_y = self:moves({ { s, 0 }, { 383, -482 }, { 617, 0 }, { 150, 34 }, { 167, -34 }, { 17, 0 },
                                { 317, -722 } })
        m.jump_scale = self:moves({ { s, 0 }, { 383, 24 }, { 100, -10 } }, 1)
        -- the gift drops into the window bottom, bounces, then opens
        local p = PRESENT_MS
        m.box_y = self:moves({ { p, 0 }, { 267, 696 }, { 83, 6, "out" }, { 100, -6, "in" } })
        m.icon_y = self:moves({ { p + 1450, 0 }, { 350, -210, "out" }, { 383, -10 } })
        m.icon_scale = self:moves({ { p + 1450, 0 }, { 350, 50, "out" } }, 1)
        m.flowers_y = self:moves({ { p + 1450, 0 }, { 350, -250 } })
    end
end

function SmartScan:elapsed() return self.now - self.t0 end

function SmartScan:seconds_left()
    if self.phase == "keep_out" then return self.left_at_out end
    if self.phase ~= "keep" then return KEEP_S end
    return math.max(0, KEEP_S - math.floor(self:elapsed() / 1000))
end

function SmartScan:update(current_ms)
    self.now = current_ms
    if self.done then return end
    for _, a in ipairs(self.anims) do a:update(current_ms) end
    local t = self:elapsed()
    for _, cue in ipairs(CUES) do
        if cue[1] == self.phase and cue[2] > self.cue_t and cue[2] <= t then
            local name = cue[3]
            if self.opts.sounds and self.opts.sounds[name] ~= nil then name = self.opts.sounds[name] end
            if name then play(name) end
        end
    end
    self.cue_t = t
    if self.phase == "keep" and t >= FOUND_MS then
        self:found()
    elseif self.phase == "keep_out" and t >= PHASE_MS.keep_out then
        self:enter("failed")
    elseif self.phase == "failed" then
        self.fail:update(current_ms)
        if self.fail:is_done() then
            self.done = true
            self:close()
        end
    elseif self.phase == "success" and t >= FADEOUT_MS then
        self:enter("fadeout")
    elseif self.phase == "fadeout" and t >= PHASE_MS.fadeout then
        self.done = true
        self:close()
    elseif NEXT_PHASE[self.phase] and t >= (self.phase == "gift" and self.opts.gift_ms or PHASE_MS[self.phase]) then
        self:enter(NEXT_PHASE[self.phase])
    end
    if self.camera_open and (self.phase == "open" or self.phase == "keep") then camera.update() end
end

-- without a camera nothing can be found: the shutter comes down instead
function SmartScan:found()
    audio.stop_sound("smart_vo_advice")
    self.left_at_out = self:seconds_left()
    self:enter(self.camera_open and "success" or "keep_out")
end

function SmartScan:close()
    if self.bgm then audio.stop_sound(self.bgm) end
    if self.camera_open then
        camera.close()
        self.camera_open = false
    end
end

function SmartScan:is_done() return self.done == true end
function SmartScan:failed() return self.fail ~= nil end
function SmartScan:get_reward()
    if self.fail then return -1 end
    return self.opts.reward or COSTUME[self.prize]
end

function SmartScan:input(action)
    if action ~= 3 or self.done then return false end
    if self.phase == "keep" then
        self:found()
    elseif self.phase == "success" and self:elapsed() >= END_MS then
        self:enter("fadeout")
    else
        return false
    end
    return true
end

function SmartScan:draw_title(t)
    local tx = self.tex
    local out = ramp(t, TITLE_OUT_MS, TITLE_END_MS - TITLE_OUT_MS)
    local deco_fade = 0.93 * (1 - out)
    if out == 0 then deco_fade = 1 end
    if self.id == "korokoro" then
        local d = tx.deco
        draw(d, { fade = deco_fade })
        draw(d, { dx = 640, fade = deco_fade, mirror = "horizontal" })
        draw(d, { dy = 360, fade = deco_fade, mirror = "vertical" })
        draw(d, { dx = 640, dy = 360, fade = deco_fade, mirror = "both" })
    elseif self.id == "chao" then
        draw(tx.deco, { fade = deco_fade })
        draw(tx.deco, { dx = 640, fade = deco_fade, mirror = "horizontal" })
    end
    local fade, scale = ramp(t, 0, 167), 1.1 - 0.1 * ramp(t, 0, 167)
    if out > 0 then fade, scale = 0.93 * (1 - out), 1.007 + 0.093 * out end
    draw(tx.title, { sx = scale, fade = fade })
end

function SmartScan:draw_gift(t)
    if self.opts.draw_gift then return self.opts.draw_gift(self, t) end
    local tx = self.tex
    local fade = ramp(t, 167, 150) * (1 - ramp(t, 3500, 83))
    draw(tx.gift, { fade = fade })
    if self.id == "v3c" then draw(tx.gift_note, { fade = fade }) end
end

-- left side panel, board and guide picture (open onwards)
function SmartScan:draw_boards(t, fade)
    local tx, m = self.tex, self.m
    local open = self.phase == "open"
    local side_y = open and 560 * S + Timing.sum(m.side_y) or 0
    local scroll_y = open and -566 * S + Timing.sum(m.scroll_y) or 0
    tex.draw_texture(tx.side.id, { y = side_y, fade = fade })
    tex.draw_texture(tx.scroll.id, { y = scroll_y, fade = fade })
    local text_fade, pic_fade = 1, 1
    if open then text_fade, pic_fade = ramp(t, 183, 300), ramp(t, 200, 283) end
    if not self.opts.keep_tex then draw(tx.guide_text, { fade = fade * text_fade }) end
    draw(tx.guide, { fade = fade * pic_fade })
end

function SmartScan:draw_timer(fade)
    local s = tostring(self:seconds_left())
    tex.draw_texture(self.timer_glow, { x = 141.4 * S, y = -236.7 * S, fade = 0.3 * fade })
    tex.draw_texture(self.timer, { x = 142.8 * S, y = -235.3 * S, fade = fade })
    draw(self.tex.skip_label, { fade = fade })
    local left = #s == 1 and 1140 or 1118
    for i = 1, #s do
        tex.draw_texture(self.digits, { frame = tonumber(s:sub(i, i)), x = (left + (i - 1) * 44) * S,
                                        y = (67 - 292.5) * S, fade = fade })
    end
end

function SmartScan:draw_keep(t)
    local tx = self.tex
    local fade = self.phase == "keep_out" and 1 - ramp(t, 0, 150) or ramp(t, 0, 150)
    draw(tx.window)
    draw(tx.keep_box, { fade = fade })
    -- the two instructions cross-fade on a 4 s loop
    local u = t < 150 and 0 or (t - 150) % 4000
    local a = u < 83 and 1 or u < 1000 and 1 - ease_in((u - 83) / 917) or u < 3000 and 0 or (u - 3000) / 1000
    local b = u < 1000 and 0 or u < 2000 and (u - 1000) / 1000 or u < 3000 and 1 - (u - 2000) / 1000 or 0
    if self.opts.keep_tex then
        draw(tx[self.opts.keep_tex], { fade = fade })
    else
        draw_lines(self.keep_text, 0, 616.5, 46, 700, fade * a, 289)
        draw_lines(self.keep_alt, 641, 618.5, 0, 700, fade * b)
    end
    self:draw_timer(fade)
end

function SmartScan:draw_lockon(t)
    local tx = self.tex
    for _, r in ipairs(RINGS) do
        local u = ease_in(clamp01((t - r[1]) / 617))
        if t >= r[1] and t < r[2] then draw(tx.ring, { sx = 2 - 1.2 * u, fade = u }) end
    end
    if t >= 1083 and t < 1150 then draw(tx.ring, { sx = 0.8 + 0.2 * ramp(t, 1083, 67), fade = 1 - ramp(t, 1083, 67) }) end
    if t >= 1000 and t < 1083 then draw(tx.ring, { sx = 0.8 - 0.05 * ramp(t, 1000, 83), fade = 1 - ramp(t, 1000, 83) }) end
    if t >= 1083 and t < 1650 then
        local u = ease_out(ramp(t, 1083, 567))
        draw(tx.rays, { sx = 0.75 + 0.75 * u, fade = 1 - u })
    end
    if t >= 1200 and t < 1500 then draw(tx.stars, { sx = 1 + 0.5 * ramp(t, 1200, 300), fade = 1 - ramp(t, 1200, 300) }) end
    if t >= 1350 and t < 1550 then draw(tx.stars, { sx = 0.5 + 0.7 * ramp(t, 1350, 200), fade = 1 - ramp(t, 1350, 200) }) end
    if t >= 1483 and t < 1667 then
        draw(tx.stars_white, { sx = 0.75 + 0.25 * ramp(t, 1483, 183), fade = 0.75 * (1 - ramp(t, 1483, 183)) })
    end
    for _, b in ipairs(BURSTS) do
        local s = t - b[1] + LOCKON_MS
        if s >= 0 and s < 333 then
            local dx, dy = b[2], b[3]
            local u = clamp01(s / 233)
            draw(tx.flash, { dx = dx, dy = dy, sx = b[4] * (0.244 + 0.756 * u), fade = 1 - u })
            local v = clamp01((s - 67) / 233)
            if s >= 67 then draw(tx.stars_white, { dx = dx, dy = dy, sx = b[4] * (0.294 + 0.706 * v), fade = 1 - v }) end
        end
    end
end

function SmartScan:draw_success_text(t)
    local tx, m = self.tex, self.m
    local u = t - SUCCESS_MS
    if u < 0 or u >= 1650 then return end
    if u < 1467 then
        local scale, fade
        if u < 367 then
            scale, fade = 0.222 + 0.855 * ease_out(u / 367), 0.79 * u / 367
        else
            scale, fade = 1.079 - 0.079 * ramp(u, 367, 116), 0.79 + 0.21 * ramp(u, 367, 116)
        end
        draw(tx.success_text, { sx = scale, fade = fade * (1 - ramp(u, 1333, 134)) })
    end
    local scale = 0.86 + Timing.sum(m.jump_scale) / 100
    local squash = u >= 1000 and u < 1317 and 1 - 0.035 * (u < 1167 and ramp(u, 1000, 150) or 1 - ramp(u, 1167, 150))
    draw(tx.don_jump, { dy = 482 + Timing.sum(m.jump_y) / S, sx = scale, sy = scale * (squash or 1) })
end

function SmartScan:draw_present(t)
    local tx, m = self.tex, self.m
    local u = t - PRESENT_MS
    if u < 0 then return end
    local flowers_dy = 250 + Timing.sum(m.flowers_y) / S
    if u >= 1450 then
        local fl = self.opts.flowers
        if fl then
            draw(tx[fl[1]], { dy = flowers_dy })
            draw(tx[fl[2]], { dy = flowers_dy })
        else
            draw(tx.flowers, { dy = flowers_dy })
            draw(tx.flowers, { dx = 760, dy = flowers_dy, mirror = "horizontal" })
        end
    end
    for _, s in ipairs(TWINKLES) do
        local v = u - s[1]
        if v >= 0 and v < 1000 then
            local fade = v < 467 and ease_in(v / 467) or 1 - ease_out(clamp01((v - 467) / 467))
            draw(tx.sparkle, { dx = 540 + s[2] - 32, dy = 494 + s[3] - 32, sx = s[4], fade = fade })
        end
    end

    -- the box squashes on landing and again before it opens
    local box_dy = -696 + Timing.sum(m.box_y) / S
    local sx, sy = 1, 1
    if u < 250 then sx, sy = 0.95 + 0.044 * u / 250, 1.22 - 0.194 * u / 250
    elseif u < 367 then local k = ease_out(ramp(u, 250, 100)); sx, sy = 1 + 0.16 * k, 1.013 - 0.108 * k
    elseif u < 467 then local k = ramp(u, 367, 100); sx, sy = 1.107 - 0.107 * k, 0.987 + 0.163 * k - 0.15 * ramp(u, 400, 67)
    elseif u >= 650 and u < 733 then local k = ramp(u, 650, 67); sx, sy = 1 + 0.16 * k, 1 - 0.095 * k
    end
    if u < 733 then
        draw(tx.box, { dy = box_dy, sx = sx, sy = sy })
    elseif u < 1450 then
        draw(tx.box_open, { dy = 3 * ease_in(ramp(u, 867, 567)), sx = 0.93 + 0.07 * ramp(u, 733, 117),
                            sy = 1 - 0.05 * ease_in(ramp(u, 867, 567)) })
    else
        local k = u < 1600 and ease_out(ramp(u, 1450, 150)) or 1 - ease_in(ramp(u, 1617, 133))
        draw(tx.box_empty, { dy = -11.4 * k, sy = 1 + 0.156 * k })
    end

    if u >= 1450 then
        draw(tx.prize, { frame = self.prize, dy = 220 + Timing.sum(m.icon_y) / S,
                         sx = 0.5 + Timing.sum(m.icon_scale) / 100 })
    end
    if u >= 1450 and u < 1733 then
        local k = ease_out(ramp(u, 1450, 267))
        draw(tx.poof, { dy = 40 * (1 - k), sx = 0.1 + 0.9 * k, fade = k })
    elseif u >= 1733 and u < 2033 then
        local step = math.min(2, math.floor((u - 1733) / 100))
        local dy = step < 2 and -(u - 1733) / 10 or -20 - 19 * ramp(u, 1933, 100)
        draw(tx.smoke, { frame = step, dy = dy, fade = step == 2 and 1 - ramp(u, 1933, 100) or 1 })
    end
    if u >= 2200 then
        draw(tx.name_bar)
        draw_lines(self.prize_name, 647, 481, 0, 330, 1)
    end
    if u >= 2717 then draw(tx.get_text, { dy = -20 * (1 - ramp(u, 2717, 100)), fade = ramp(u, 2717, 100) }) end
end

function SmartScan:draw()
    if self.done then return end
    screen_rect(0, 0, 0, 255)
    local tx = self.tex
    local phase, t = self.phase, self:elapsed()
    local windowed = phase == "open" or phase == "keep" or phase == "success" or phase == "fadeout"
    if windowed then
        camera.draw(CAMERA[1] * S, CAMERA[2] * S, CAMERA[3] * S, CAMERA[4] * S)
    elseif phase == "failed" then
        self.fail:draw_window()
    end
    draw(tx.bg)
    if phase == "title" or phase == "gift" or (phase == "open" and t < 850) then
        draw(tx.title_bg, { fade = phase == "open" and 1 - ramp(t, 750, 100) or 1 })
    end
    if phase == "title" then
        self:draw_title(t)
    elseif phase == "gift" then
        if not self.opts.skip_title and t < TITLE_END_MS - PHASE_MS.title then self:draw_title(PHASE_MS.title + t) end
        self:draw_gift(t)
    elseif phase == "open" or phase == "keep" or phase == "keep_out" or phase == "failed" then
        self:draw_boards(t, 1)
        draw(tx.frame, { fade = phase == "open" and ramp(t, 500, 233) or 1 })
        if phase == "keep" or phase == "keep_out" then self:draw_keep(t) end
        if phase == "failed" then self.fail:draw_overlay() end
    else
        local st = phase == "success" and t or FADEOUT_MS + t
        if st < 150 then self:draw_boards(st, 1 - st / 150) end
        draw(tx.frame)
        if st >= LOCKON_MS and st < SUCCESS_MS + 50 then self:draw_lockon(st - LOCKON_MS) end
        self:draw_success_text(st)
        self:draw_present(st)
        if phase == "fadeout" then screen_rect(0, 0, 0, 255 * ramp(t, 17, 950)) end
    end
end
