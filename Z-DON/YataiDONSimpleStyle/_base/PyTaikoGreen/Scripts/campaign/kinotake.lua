require("entry/campaign_menu")
require("campaign/smart_scan")

Kinotake = {}
Kinotake.__index = Kinotake

local S = tex.get_screen_scale()
local DIR = "campaign/kinotake"
local F = 1000 / 60
local LEFT, RIGHT, DECIDE = 1, 2, 3
local KINOKO, TAKENOKO = 0, 1
local COSTUME = { [KINOKO] = 101, [TAKENOKO] = 102 } -- the package scan's prize
local TEAM_COSTUME = { [KINOKO] = 105, [TAKENOKO] = 106 } -- ちびどん, for joining a team

local TITLE_F = 229
local CURSOR_X = { [KINOKO] = -150, [TAKENOKO] = 145 }
local SIDE_WAIT_F, SIDE_FADE_F, MOVE_F = 60, 20, 5
local SIDE_SELECT_MS = 20000
local BALLOON_WAIT_F, BALLOON_F = 120, 129
local GIFT_F = 220

local function clamp01(v) return math.max(0.0, math.min(1.0, v)) end
local function ramp(t, at, len) return clamp01((t - at) / len) end
local function ease_in(u) return u * u end
local function ease_out(u) return u * (2 - u) end

-- { frame, value, ease of the segment ending here } -> value at frame f
local function track(f, keys)
    if f <= keys[1][1] then return keys[1][2] end
    for i = 2, #keys do
        local a, b = keys[i - 1], keys[i]
        if f < b[1] then
            local u = (f - a[1]) / (b[1] - a[1])
            if b[3] == "out" then u = ease_out(u) elseif b[3] == "in" then u = ease_in(u) end
            return a[2] + (b[2] - a[2]) * u
        end
    end
    return keys[#keys][2]
end

local function play(name, kind)
    if audio.has_sound(name) then audio.play_sound(name, kind or (name:find("_vo_") and "voice" or "sound")) end
end

function Kinotake.new(seats)
    local self = setmetatable({}, Kinotake)
    self.tex = {}
    for _, key in ipairs({
        "bg", "cover", "logo", "banner", "logo_flash", "banner_flash", "burst_l", "burst_r", "copyright", "board",
        "cloud_kinoko", "cloud_takenoko", "frame_1p", "frame_2p", "half_1p", "half_2p", "glow", "glow_half",
        "bubble_1p", "bubble_2p", "bubble_1p_duet", "bubble_2p_duet", "flash", "flash_1p_duet", "flash_2p_duet",
        "balloon", "gift_note", "gift_kid", "gift_kinoko", "gift_takenoko",
    }) do
        local id = tex.get_texture(DIR .. "/" .. key) -- loads the folder, so before the info lookup
        local info = tex.get_texture_info(DIR:match("[^/]+$"), key) -- textures are keyed by their own folder
        self.tex[key] = { id = id, w = info and info.x2[1] or 0,
                          h = info and info.y2[1] or 0 }
    end
    self.seats = {}
    for _, p in ipairs(seats or { 1 }) do self.seats[#self.seats + 1] = p end
    self.cursors = {}
    self.team = {}
    self.reward = -1
    self.now = tex.get_current_ms()
    play("kinotake_bgm", "music")
    self:enter("title")
    return self
end

-- draws `t` scaled by sx / sy about its centre, moved by dx / dy (unscaled pixels)
function Kinotake:put(t, opts)
    opts = opts or {}
    local sx, sy = opts.sx or 1, opts.sy or opts.sx or 1
    tex.draw_texture(t.id, {
        x = t.w * (1 - sx) / 2 + (opts.dx or 0) * S, y = t.h * (1 - sy) / 2 + (opts.dy or 0) * S,
        x2 = t.w * (sx - 1), y2 = t.h * (sy - 1), fade = opts.fade, mirror = opts.mirror,
    })
end

function Kinotake:enter(phase)
    self.phase = phase
    self.t0 = self.now
    self.cue_f = -1
    if phase == "select" then
        self.menu = CampaignMenu.new({ "kinotake", "recog", "skip" }, {
            dir = DIR, sound = "kinotake_vo_sel_which",
            voices = { kinotake = "kinotake_vo_sel_which", recog = "kinotake_vo_sel_recog" },
        })
        play("kinotake_se_tsuzumi")
    elseif phase == "recog" then
        self.recog_team = math.random(0, 1)
        self.reward = COSTUME[self.recog_team]
        local function k(key) return DIR .. "/" .. key end
        self.scan = SmartScan.new("v3c", {
            tex = {
                bg = k("bg"), title_bg = k("cover"), side = k("recog_side"), guide = k("recog_guide"),
                keep_box = k("recog_keep_box"), recog_keep_text = k("recog_keep_text"), prize = k("prize"),
                flowers_kinoko = k("flowers_kinoko"), flowers_takenoko = k("flowers_takenoko"),
            },
            skip_title = true, gift_ms = GIFT_F * F, draw_gift = function(_, t) self:draw_gift(t) end,
            keep_tex = "recog_keep_text", flowers = { "flowers_kinoko", "flowers_takenoko" },
            prize = self.recog_team, prize_text = "kinotake_costume_" .. self.recog_team, reward = self.reward,
            bgm = false, sounds = { smart_vo_campaign = false, smart_vo_moraeru = "kinotake_vo_exp_recog" },
        })
    elseif phase == "side" then
        for i, p in ipairs(self.seats) do
            local index = self.recog_team or (i == 1 and KINOKO or TAKENOKO)
            self.cursors[i] = { player = p, index = index, from = index, moved = -MOVE_F * F }
        end
        self.all_decided = nil
        self.side_t0 = self.now
        play("kinotake_vo_which")
    elseif phase == "balloon" then
        play("kinotake_vo_entered")
    end
end

function Kinotake:frames() return (self.now - self.t0) / F end

function Kinotake:cue(f, name)
    if f > self.cue_f and f <= self:frames() then play(name) end
end

function Kinotake:update(current_ms)
    self.now = current_ms
    if self.done then return end
    local f = self:frames()
    if self.phase == "title" then
        self:cue(1, "kinotake_se_popup")
        self:cue(35, "kinotake_se_logoshine")
        self:cue(54, "kinotake_vo_title")
        self:cue(100, "kinotake_se_popup")
        self:cue(170, "kinotake_se_popup")
        if f >= TITLE_F then self:enter("select") end
    elseif self.phase == "select" then
        self.menu:update(current_ms)
        if self.menu:is_done() then
            local choice = self.menu:get_choice()
            if choice == "skip" then self:finish() else self:enter(choice == "recog" and "recog" or "side") end
        end
    elseif self.phase == "recog" then
        self.scan:update(current_ms)
        if self.scan:is_done() then
            if self.scan:failed() then self.recog_team, self.reward = nil, -1 end -- no camera: pick a side as usual
            self:enter("side")
        end
    elseif self.phase == "side" then
        if self.menu then self.menu:update(current_ms) end
        if not self.all_decided and current_ms - self.t0 >= (SIDE_WAIT_F + SIDE_FADE_F) * F + SIDE_SELECT_MS then
            for _, c in ipairs(self.cursors) do self:decide(c) end
        end
        if self.all_decided and current_ms - self.all_decided >= BALLOON_WAIT_F * F then self:enter("balloon") end
    elseif self.phase == "balloon" then
        self:cue(19, "kinotake_se_breakout")
        if f >= BALLOON_F then self:finish() end
    end
    self.cue_f = f
end

function Kinotake:finish()
    self.done = true
    self:close()
end

function Kinotake:close()
    audio.stop_sound("kinotake_bgm")
    if self.scan then self.scan:close() end
end

function Kinotake:cursor_of(player)
    for _, c in ipairs(self.cursors) do
        if c.player == player then return c end
    end
end

function Kinotake:decide(c)
    if c.decided then return end
    c.decided = self.now
    self.team[c.player] = c.index
    for _, o in ipairs(self.cursors) do
        if not o.decided then return end
    end
    self.all_decided = self.now
end

function Kinotake:input(action, player)
    if self.done then return false end
    if self.phase == "select" then
        return self.menu:input(action)
    elseif self.phase == "recog" then
        return action == DECIDE and self.scan:input(action)
    elseif self.phase ~= "side" or self:frames() < SIDE_WAIT_F + SIDE_FADE_F or self.all_decided then
        return false
    end
    local c = self:cursor_of(player or self.seats[1]) or self.cursors[1]
    if not c or c.decided or self.now - c.moved < MOVE_F * F then return false end
    if action == DECIDE then
        self:decide(c)
        return true
    end
    local to = action == LEFT and KINOKO or TAKENOKO
    if to == c.index then return false end
    c.from, c.index, c.moved = c.index, to, self.now
    return true
end

function Kinotake:is_done() return self.done == true end
function Kinotake:get_team(player) return self.team[player] or -1 end
function Kinotake:get_reward() return self.reward end
function Kinotake:get_unlock(player) return TEAM_COSTUME[self.team[player]] or -1 end

function Kinotake:draw_backdrop()
    tex.draw_texture(self.tex.cover.id)
    tex.draw_texture(self.tex.bg.id)
end

function Kinotake:draw_title(f)
    local tx = self.tex
    self:draw_backdrop()
    local lift = track(f, { { 0, 700 }, { 20, 118.15, "out" }, { 25, 135, "in" }, { 75, 135 }, { 87, 0, "out" } })
    self:put(tx.logo, { dy = lift })
    self:put(tx.banner, { dy = lift })
    if f >= 25 and f < 54 then
        local s, a = 1, ramp(f, 25, 10)
        if f >= 36 then
            local u = ease_out(ramp(f, 36, 18))
            s, a = 1.328 + 2.872 * u, 0.9 * (1 - u)
        end
        self:put(tx.logo_flash, { dy = lift, sx = s, fade = a })
        self:put(tx.banner_flash, { dy = lift, sx = s, fade = a })
    end
    for _, b in ipairs({ { tx.burst_l, 74 }, { tx.burst_r, 145 } }) do
        local u = f - b[2]
        if u >= 0 then
            local dy = track(u, { { 0, 548.15 }, { 13, -16.85, "out" }, { 21, 9, "in" }, { 26, 0 } })
            local sy = track(u, { { 13, 1 }, { 21, 0.95, "in" }, { 26, 1 } })
            self:put(b[1], { dy = dy, sy = sy, sx = 1 })
        end
    end
    tex.draw_texture(tx.copyright.id, { fade = ramp(f, 87, 6) })
end

function Kinotake:draw_gift(t)
    local tx, f = self.tex, t / F
    local out = 1 - ramp(f, 214, 5)
    self:put(tx.gift_note, { fade = ramp(f, 10, 9) * out })
    if f >= 5 then
        local dy = track(f, { { 4, 490 }, { 15, -44.05, "out" }, { 23, -11.4, "in" }, { 28, 7.65, "out" }, { 32, 0, "in" } })
        self:put(tx.gift_kid, { dy = dy, fade = out })
    end
    -- the boxes pop up, then breathe out of step
    for i, b in ipairs({ { tx.gift_kinoko, 10 }, { tx.gift_takenoko, 11 } }) do
        local u = f - b[2]
        if u >= 0 then
            local dy = track(u, { { 0, 498 }, { 9, -8 }, { 13, 0 } })
            local p = u < 14 and 0 or ((u - 14) % 40) / 40
            local s = p < 0.5 and p * 2 or 1 - (p - 0.5) * 2
            if i == 1 then s = 0.95 + 0.05 * s else s = 1 - 0.05 * s end
            self:put(b[1], { dy = dy, sx = s, fade = out })
        end
    end
end

function Kinotake:draw_cloud(t, f)
    local p = (f % 40)
    local s = p < 17 and 1 + 0.05 * ease_out(p / 17) or p < 24 and 1.05 or 1.05 - 0.05 * ease_in((p - 24) / 16)
    self:put(t, { sx = s })
end

function Kinotake:draw_cursor(c, f, duet)
    local tx = self.tex
    local wait = SIDE_WAIT_F
    if f < wait then return end
    local fade = ramp(f, wait, SIDE_FADE_F)
    local moved = (self.now - c.moved) / (MOVE_F * F)
    local x = CURSOR_X[c.from] + (CURSOR_X[c.index] - CURSOR_X[c.from]) * clamp01(moved)
    local flash = 0
    if c.decided then
        local d = (self.now - c.decided) / F
        flash = ramp(d, 0, 15)
        fade = fade * (1 - ramp(d, 16, 13))
        if fade <= 0 then return end
    end
    local p1 = c.player == 1
    local suffix = p1 and "1p" or "2p"
    local frame = duet and tx["half_" .. suffix] or tx["frame_" .. suffix]
    local bubble = duet and tx["bubble_" .. suffix .. "_duet"] or tx["bubble_" .. suffix]
    local flash_tex = duet and tx["flash_" .. suffix .. "_duet"] or tx.flash
    self:put(bubble, { dx = x, fade = fade })
    if flash > 0 then self:put(flash_tex, { dx = x, fade = fade * flash }) end
    self:put(frame, { dx = x, fade = fade })
    -- white rim glow: in 467 ms, out 500 ms, every 2 s
    local g = ((self.now - self.side_t0) % 2000)
    local glow = g < 467 and 0.58 * g / 467 or g < 967 and 0.6 * (1 - (g - 467) / 500) or 0
    self:put(duet and tx.glow_half or tx.glow, { dx = x, fade = fade * glow,
                                                   mirror = duet and p1 and "horizontal" or nil })
end

function Kinotake:draw_side()
    local tx = self.tex
    local f = (self.now - self.side_t0) / F
    self:draw_backdrop()
    self:put(tx.board)
    self:draw_cloud(tx.cloud_kinoko, f)
    self:draw_cloud(tx.cloud_takenoko, f)
    local a, b = self.cursors[1], self.cursors[2]
    local duet = a and b and a.index == b.index
    for i = #self.cursors, 1, -1 do self:draw_cursor(self.cursors[i], f, duet) end
    if self.menu then self.menu:draw_hint(1) end
end

function Kinotake:draw_balloon(f)
    local s, a = 1, 1
    if f < 19 then
        s, a = 2 - f / 19, f / 19
    elseif f < 23 then
        s = 1.013 + 0.037 * ramp(f, 20, 3)
    elseif f < 29 then
        s = 1.042 - 0.042 * ramp(f, 24, 5)
    end
    self:put(self.tex.balloon, { sx = s, fade = a })
    if f >= 65 then
        tex.draw_rect(0, 0, tex.get_screen_width(), tex.get_screen_height(), 0, 0, 0, 255 * ramp(f, 65, 60))
    end
end

function Kinotake:draw()
    if self.done then return end
    local f = self:frames()
    if self.phase == "title" then
        self:draw_title(f)
    elseif self.phase == "select" then
        self:draw_backdrop()
        self.menu:draw()
    elseif self.phase == "recog" then
        self.scan:draw()
    elseif self.phase == "side" then
        self:draw_side()
    elseif self.phase == "balloon" then
        self:draw_side()
        self:draw_balloon(f)
    end
end
