KinotakeResult = {}
KinotakeResult.__index = KinotakeResult

local S = tex.get_screen_scale()
local DIR = "kinotake_result/tally"
local F = 1000 / 60
local KINOKO, TAKENOKO = 0, 1
local WHITE, BLACK = { 255, 255, 255, 255 }, { 0, 0, 0, 255 }

-- AS state lengths (frames)
local FST_WAIT, TITLE, KOREMADE_IN, BAR_TO_FIRST, KOREMADE_AFTER = 60, 168, 120, 40, 90
local DON_IN, SHOW_POINT, BONUS_TITLE, SHOW_ICON, WAIT_ADD, ADD_BONUS = 90, 120, 90, 90, 60, 120
local DON_OUT, BAR_TO_CENTER, TOTAL_COUNTUP, BAR_TO_RESULT, END_WAIT = 60, 30, 150, 10, 300

local FRONT_RANGE = 480                       -- front line moves +-480 px about the centre
local BAR_LEFT, BAR_RIGHT, BAR_H = 120, 1160, 40 -- tug bar inside the header band
-- digit centres of the number sprites, rightmost first; comma slots after every third digit
local WHITE_SLOTS = { 396, 366.5, 337, 298, 268.5, 239, 198.5, 169, 139.5, 99, 69.5, 40, 0 }
local WHITE_COMMAS = { 318, 219, 119.5, 20 }
local GOLD_SLOTS = { 220, 182, 144, 86, 48, 10, -48, -86, -124, -181, -219 }
local GOLD_COMMAS = { 116.5, -17.55, -151.55 }
local TEAM_NUMBER = { [KINOKO] = { 165, 236 }, [TAKENOKO] = { 677, 236 } }
local CLOUD = { 281, 375 }
-- sprout centres (from the field centre (640, 360))
local TAKE_SPROUTS = {
    { 68, 40.75, 1 }, { -376.1, 18.7, 1 }, { 572.1, 88.75, 2 }, { 388.05, 60.75, 2 }, { -208.05, 80.1, 2 },
    { -538.15, 84.1, 2 }, { 218.05, 132.75, 1 }, { -54.05, 132.75, 1 }, { -386.1, 132.75, 2 }, { -248.1, 178.75, 1 },
    { 92, 206.75, 2 }, { 546.1, 224.75, 1 }, { 350, 232.75, 2 }, { -130.05, 238.15, 2 }, { -500.1, 224.75, 2 },
}
local KINO_SPROUTS = {
    { 510.05, -107.35, 1 }, { 222, -68.7, 1 }, { -120.1, -77.35, 1 }, { -254.1, -98.75, 2 }, { -536.2, -114.75, 2 },
    { 576.1, -41.35, 2 }, { 396.05, 45.25, 2 }, { -254.1, 26.7, 1 }, { 189.95, 80.7, 1 }, { -580.15, 67.3, 2 },
    { 558.05, 102.7, 1 }, { -502.2, 172.75, 1 }, { 546.1, 224.75, 2 }, { 336, 246.15, 1 }, { 56, 224.75, 2 },
    { -166.05, 232.75, 2 }, { -374.1, 246.15, 2 },
}
-- bonus icons: x out of the cloud, x when perched above it (from the panel centre (320, 504))
local ICON_X, ICON_PERCH_X = { -159.35, -35.1, 87.7 }, { -99.35, -35.1, 27.7 }

local function clamp01(v) return math.max(0.0, math.min(1.0, v)) end
local function ramp(t, at, len) return clamp01((t - at) / len) end
local function ease_in(u) return u * u end
local function ease_out(u) return u * (2 - u) end

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

local function play(name)
    if audio.has_sound(name) then audio.play_sound(name, name:find("vo_") and "voice" or "sound") end
end

local function ratio(t)
    local sum = t.kinoko + t.takenoko
    return sum > 0 and t.kinoko / sum or 0.5
end

function KinotakeResult.new(data)
    local self = setmetatable({}, KinotakeResult)
    self.tex = {}
    for _, key in ipairs({
        "field_take", "field_kino", "lose_filter", "front_line", "bar_kino", "bar_take", "sprout_take", "sprout_take2",
        "sprout_kino", "sprout_kino2", "band", "points_label", "tick", "emblem_kino", "emblem_take", "title_big",
        "title_small", "bonus_burst", "suspense", "lead_kino", "lead_kino_text", "lead_take", "lead_take_text",
        "lead_even", "lead_even_text", "panel_1p", "panel_2p", "label_kino", "label_take", "cloud", "icon_fever",
        "icon_duet", "icon_glow", "digits_white", "digits_gold", "poof", "icon_assist", "koremade",
    }) do
        local id = tex.get_texture(DIR .. "/" .. key) -- loads the folder, so before the info lookup
        local info = tex.get_texture_info(DIR:match("[^/]+$"), key) -- textures are keyed by their own folder
        self.tex[key] = { id = id, w = info and info.x2[1] or 0,
                          h = info and info.y2[1] or 0 }
    end
    self.players = {}
    self.bonus = false
    for _, p in ipairs(data.players or {}) do
        p.icons = {}
        if p.assist > 1 then p.icons[#p.icons + 1] = { tex = "icon_assist", frame = p.team * 4 + p.assist - 2 } end
        if p.duet then p.icons[#p.icons + 1] = { tex = "icon_duet" } end
        self.bonus = self.bonus or p.total > p.base
        self.players[#self.players + 1] = p
    end
    self.before, self.after = data.before, data.after
    self.caption = {}
    for line in tex.skin_text("kinotake_result_caption"):gmatch("[^\n]+") do
        self.caption[#self.caption + 1] = text.create_raw_text(line, math.floor(26 * S), WHITE, BLACK, false, 4, 2.0)
    end

    -- state start frames
    local t = { koremade = FST_WAIT + TITLE }
    t.title = FST_WAIT
    t.bar_first = t.koremade + KOREMADE_IN
    t.don_in = t.bar_first + BAR_TO_FIRST + KOREMADE_AFTER
    t.show_point = t.don_in + DON_IN
    t.bonus = t.show_point + SHOW_POINT
    t.icons = t.bonus + BONUS_TITLE
    t.add = t.icons + SHOW_ICON + WAIT_ADD
    t.don_out = self.bonus and t.add + ADD_BONUS or t.bonus
    t.semegiai = t.don_out + DON_OUT
    t.countup = t.semegiai + BAR_TO_CENTER
    t.final = t.countup + TOTAL_COUNTUP
    t.done = t.final + BAR_TO_RESULT + END_WAIT
    self.at = t
    local r = ratio(self.after)
    self.winner = math.abs(r - 0.5) < 1e-9 and -1 or (r > 0.5 and KINOKO or TAKENOKO)
    local rb = ratio(self.before)
    self.leader = math.abs(rb - 0.5) < 1e-9 and -1 or (rb > 0.5 and KINOKO or TAKENOKO)

    self.t0 = tex.get_current_ms()
    self.now = self.t0
    self.cue_f = -1
    if audio.has_sound("bgm") then audio.play_sound("bgm", "music") end
    return self
end

function KinotakeResult:frames() return (self.now - self.t0) / F end

function KinotakeResult:update(current_ms)
    self.now = current_ms
    local f, t = self:frames(), self.at
    local function cue(at, name) if at > self.cue_f and at <= f then play(name) end end
    cue(t.title, "se_hyoshigi")
    cue(t.title, "vo_shukei")
    cue(t.koremade, "se_hyoshigi2")
    cue(t.don_in, "se_donjump")
    if self.bonus then
        cue(t.bonus, "se_popup")
        cue(t.bonus, "vo_bonus")
        cue(t.icons, "se_itemjump")
        cue(t.add, "se_itemadd")
    end
    cue(t.don_out + 7, "se_beben")
    cue(t.countup, "se_gauge")
    if t.final > self.cue_f and t.final <= f then
        audio.stop_sound("se_gauge")
        play("se_cheer")
        play(self.winner == KINOKO and "vo_knlead" or self.winner == TAKENOKO and "vo_tklead" or "vo_draw")
    end
    self.cue_f = f
end

function KinotakeResult:skip()
    if self:frames() >= self.at.final or self:frames() < FST_WAIT then return false end
    self.t0 = self.now - self.at.final * F
    self.cue_f = self.at.final - 1
    audio.stop_sound("se_gauge")
    play("se_skip")
    return true
end

function KinotakeResult:is_done()
    if self:frames() < self.at.done then return false end
    audio.stop_sound("bgm")
    return true
end

-- nameplate of a seat: y offset and fade (the panel's slide)
function KinotakeResult:nameplate(seat)
    local dy, fade = self:panel_y(), ramp(self:frames(), self.at.don_in + 9, 30)
    if self:frames() >= self.at.don_out + 50 then fade = 0 end
    return dy * S, fade
end

function KinotakeResult:put(t, opts)
    opts = opts or {}
    local sx, sy = opts.sx or 1, opts.sy or opts.sx or 1
    tex.draw_texture(t.id, {
        x = t.w * (1 - sx) / 2 + (opts.dx or 0) * S, y = t.h * (1 - sy) / 2 + (opts.dy or 0) * S,
        x2 = t.w * (sx - 1), y2 = t.h * (sy - 1), fade = opts.fade, frame = opts.frame, mirror = opts.mirror,
    })
end

-- draws t centred on (cx, cy) at scale s
function KinotakeResult:put_at(t, cx, cy, s, fade, frame, sy)
    local w, h = t.w * s, t.h * (sy or s)
    tex.draw_texture(t.id, { x = cx * S - w / 2, y = cy * S - h / 2, x2 = w - t.w, y2 = h - t.h, fade = fade,
                             frame = frame })
end

function KinotakeResult:draw_number(digits, slots, commas, value, ox, oy, s, fade, comma_dy)
    local str = tostring(math.max(0, math.floor(value + 0.5)))
    if #str > #slots then str = string.rep("9", #slots) end
    for i = 1, #str do
        local d = tonumber(str:sub(#str - i + 1, #str - i + 1))
        self:put_at(digits, ox + slots[i] * s, oy, s, fade, d)
    end
    for i = 1, math.floor((#str - 1) / 3) do
        self:put_at(digits, ox + commas[i] * s, oy + (comma_dy or 0) * s, s, fade, 10)
    end
end

-- front line offset from the centre for a kinoko share r
local function front(r) return math.max(-FRONT_RANGE, math.min(FRONT_RANGE, (r - 0.5) * 2 * FRONT_RANGE)) end

function KinotakeResult:front_x(f)
    local t = self.at
    local first, last = front(ratio(self.before)), front(ratio(self.after))
    if f < t.bar_first then return 0 end
    if f < t.semegiai then return first * ease_out(ramp(f, t.bar_first, BAR_TO_FIRST)) end
    if f < t.final then
        -- neck and neck: back to the middle, then wobble while the totals count
        local back = first * (1 - ease_out(ramp(f, t.semegiai, BAR_TO_CENTER)))
        local wob = f >= t.countup and 60 * math.sin((f - t.countup) / 16 * math.pi * 2) or 0
        return back + wob
    end
    return last * ease_out(ramp(f, t.final, BAR_TO_RESULT))
end

function KinotakeResult:shown_totals(f)
    local t = self.at
    local u = f < t.countup and 0 or ramp(f, t.countup, TOTAL_COUNTUP)
    return self.before.kinoko + (self.after.kinoko - self.before.kinoko) * u,
        self.before.takenoko + (self.after.takenoko - self.before.takenoko) * u
end

-- sprout: grows up out of the ground, then hops
local function sprout_pose(u)
    if u < 30 then
        local dy = track(u, { { 0, 65.3 }, { 4, -78.75, "out" }, { 13, 0, "in" }, { 18, 21.6 }, { 23, 0 } })
        local sy = track(u, { { 0, 0.093 }, { 4, 1, "out" }, { 13, 1 }, { 14, 0.94 }, { 18, 0.7 }, { 19, 0.76 }, { 23, 1 } })
        return dy, sy
    end
    local d = 30 + (u - 30) % 70
    local dy = track(d, { { 30, 0 }, { 44, 25.5, "out" }, { 54, 25.5 }, { 55, -11.95 }, { 69, -108.45, "out" },
                          { 89, 28.8, "in" }, { 90, 23.55 }, { 100, 0, "out" } })
    local sy = track(d, { { 30, 1 }, { 44, 0.6, "out" }, { 54, 0.6 }, { 55, 0.744 }, { 69, 1.2, "out" },
                          { 89, 0.6, "in" }, { 90, 0.673 }, { 100, 1, "out" } })
    return dy, sy
end

function KinotakeResult:draw_sprouts(team, since, f)
    local list = team == KINOKO and KINO_SPROUTS or TAKE_SPROUTS
    local u = f - since
    if u < 0 then return end
    local dy, sy = sprout_pose(u)
    for _, p in ipairs(list) do
        local key = (team == KINOKO and "sprout_kino" or "sprout_take") .. (p[3] == 2 and "2" or "")
        self:put_at(self.tex[key], 640 + p[1], 360 + p[2] + dy, 1, 1, nil, sy)
    end
end

function KinotakeResult:draw_field(f)
    local tx, t = self.tex, self.at
    local split = 640 + self:front_x(f)
    -- the leader's sprouts during the standings, the winner's at the end
    local side = f >= t.final and self.winner or self.leader
    local since = f >= t.final and t.final or t.bar_first
    tex.draw_texture(tx.field_take.id)
    if side == TAKENOKO and f >= t.bar_first then self:draw_sprouts(TAKENOKO, since, f) end
    tex.begin_scissor(0, 0, split * S, tex.get_screen_height())
    tex.draw_texture(tx.field_kino.id)
    if side == KINOKO and f >= t.bar_first then self:draw_sprouts(KINOKO, since, f) end
    tex.end_scissor()
    if f >= t.final and self.winner >= 0 then
        tex.draw_texture(tx.lose_filter.id, { x = (self.winner == KINOKO and 640 or 0) * S,
                                              fade = ramp(f, t.final, BAR_TO_RESULT) })
    end
    tex.draw_texture(tx.front_line.id, { x = (split - 640) * S })
end

function KinotakeResult:draw_header(f)
    local tx, t = self.tex, self.at
    local fade = ramp(f, t.koremade + 10, 19)
    if fade <= 0 then return end
    self:put(tx.band, { fade = fade })
    local split = 640 + self:front_x(f) * (BAR_RIGHT - BAR_LEFT) / (2 * FRONT_RANGE)
    local kw, kh = split - BAR_LEFT, BAR_RIGHT - split
    tex.draw_texture(tx.bar_kino.id, { x = BAR_LEFT * S, x2 = kw * S - tx.bar_kino.w, fade = fade })
    tex.draw_texture(tx.bar_take.id, { x = split * S, x2 = kh * S - tx.bar_take.w, fade = fade })
    self:put(tx.points_label, { fade = fade })
    self:put(tx.points_label, { dx = 516, fade = fade })
    self:put(tx.tick, { fade = fade })
    self:put(tx.emblem_kino, { fade = fade })
    self:put(tx.emblem_take, { fade = fade })
    local kino, take = self:shown_totals(f)
    for team, v in pairs({ [KINOKO] = kino, [TAKENOKO] = take }) do
        local at = TEAM_NUMBER[team]
        self:draw_number(tx.digits_white, WHITE_SLOTS, WHITE_COMMAS, v, at[1], at[2], 1, fade, 10)
    end
end

function KinotakeResult:draw_title(f)
    local tx, t = self.tex, self.at
    local u = f - t.title
    if u >= 0 and u < TITLE then
        local s = u < 4 and 0.8 + 0.4 * ease_out(u / 4) or u < 10 and 1.2 - 0.2 * ease_in((u - 4) / 6) or 1
        self:put(tx.title_big, { sx = s, fade = 1 - ramp(u, TITLE - 5, 5) })
    end
    if f >= t.koremade then tex.draw_texture(tx.title_small.id) end
end

function KinotakeResult:draw_koremade(f)
    local tx, t = self.tex, self.at
    local u = f - t.koremade
    if u < 0 or f >= t.don_in then return end
    local fade = ramp(u, 0, 19) * (1 - ramp(f, t.don_in - 20, 20))
    tex.draw_texture(tx.koremade.id, { fade = fade })
    for i, line in ipairs(self.caption) do
        line:draw({ x = 376 * S, y = (446 + (i - 1) * 35.5) * S - line.height / 2, fade = fade })
    end
end

function KinotakeResult:panel_y()
    local f, t = self:frames(), self.at
    if f < t.don_in + 10 then return 318 end
    if f < t.don_out then return 318 * (1 - ramp(f, t.don_in + 10, 29)) end
    return 318 * ramp(f, t.don_out + 1, 39)
end

-- the player's cloud number: base, then base + bonus
function KinotakeResult:cloud_value(p, f)
    local t = self.at
    if f < t.show_point then return 0 end
    local v = p.base * ramp(f, t.show_point, 60)
    if self.bonus and f >= t.add + 14 then v = p.base + (p.total - p.base) * ramp(f, t.add + 14, 44) end
    return v
end

function KinotakeResult:draw_panel(p, f)
    local tx, t = self.tex, self.at
    local ox = p.seat == 2 and 640 or 0
    local dy = self:panel_y()
    if dy >= 318 then return end
    self:put(p.seat == 2 and tx.panel_2p or tx.panel_1p, { dy = dy })
    self:put(p.team == KINOKO and tx.label_kino or tx.label_take, { dx = ox, dy = dy })
    self:draw_number(tx.digits_white, WHITE_SLOTS, WHITE_COMMAS, p.mine, ox + 305.9, 668.3 + dy, 0.5, 1, 10)

    -- cloud: rises in, bumps as the bonus lands, then flies to the header
    local u = f - t.don_in
    if u < 41 then return end
    local cx, cy, s, fade = CLOUD[1] + ox, CLOUD[2] + dy - 30 * (1 - ramp(u, 41, 9)), 1, ramp(u, 41, 9)
    if self.bonus then
        local a = f - t.add
        if a >= 14 and a < 58 then s = 1.2 + 0.1 * math.abs(math.sin((a - 14) / 10 * math.pi)) end
        if a >= 58 then s = 1.2 - 0.2 * ramp(a, 58, 26) end
    end
    local o = f - t.don_out
    if o >= 7 then
        local k = ramp(o, 7, 23)
        cx, cy = cx + (640 - cx) * k, cy + (211 - cy) * k
        if o >= 30 then s, fade = 1.02 + 0.18 * ramp(o, 30, 10), 0.9 * (1 - ramp(o, 30, 10)) end
        if o >= 40 then return end
    end
    self:put_at(tx.cloud, cx, cy, s, fade)
    self:draw_number(tx.digits_gold, GOLD_SLOTS, GOLD_COMMAS, self:cloud_value(p, f), cx, cy, s, fade)
    if self.bonus then self:draw_icons(p, f, ox, dy) end
end

function KinotakeResult:draw_icons(p, f, ox, dy)
    local tx, t = self.tex, self.at
    local u, a = f - t.icons, f - t.add
    for i, icon in ipairs(p.icons) do
        local x, y, s, fade = ICON_X[i], -36.25, 1, 1
        if u < 0 then return end
        if u < 13 then
            local k = u / 13
            x, s = -36 + (ICON_X[i] + 36) * k, 1.2 * k
        elseif a < 0 then
            s = 1
        elseif a < 21 then
            y = track(a, { { 0, -36.25 }, { 8, 31.75, "out" }, { 16, -128 }, { 21, -128 } })
            fade = a < 17 and 1 or 1 - ramp(a, 17, 4)
        elseif a < 51 then
            fade = 0
        else
            local k = ramp(a, 51, 7)
            x, y, s, fade = ICON_PERCH_X[i], -138 - 60 * k, 0.5, k
            if f >= t.don_out then fade = 1 - ramp(f, t.don_out, 6) end
        end
        if fade > 0 then
            self:put_at(tx[icon.tex], 320 + ox + x, 504 + dy + y, s, fade, icon.frame)
        end
    end
end

function KinotakeResult:draw_bonus_burst(f)
    local t = self.at
    if not self.bonus then return end
    local u = f - t.bonus
    if u < 0 or u >= 50 then return end
    local s = u < 6 and 1.2 * u / 6 or u < 13 and 1.2 - 0.3 * ramp(u, 6, 7) or u < 20 and 0.9 + 0.1 * ramp(u, 13, 6) or 1
    self:put(self.tex.bonus_burst, { sx = s, fade = 1 - ramp(u, 37, 12) })
end

function KinotakeResult:draw_suspense(f)
    local t = self.at
    local u = f - t.semegiai
    if u < 0 or f >= t.final then return end
    self:put(self.tex.suspense, { fade = ramp(u, 0, 19) * (1 - ramp(f, t.final - 20, 20)) })
end

function KinotakeResult:draw_lead(f)
    local tx, t = self.tex, self.at
    local u = f - t.final
    if u < 0 then return end
    local key = self.winner == KINOKO and "lead_kino" or self.winner == TAKENOKO and "lead_take" or "lead_even"
    local dy = track(u, { { 0, 482 }, { 6, -89.6, "out" }, { 13, 0, "in" } })
    local sy = track(u, { { 0, 1 }, { 6, 1.2, "out" }, { 13, 1, "in" } })
    self:put(tx[key], { dy = dy, sx = 1, sy = sy, fade = ramp(u, 0, 6) })
    if u >= 6 then
        local ty = track(u, { { 6, 112 }, { 9, 0, "out" }, { 14, -82, "out" }, { 19, 10.5, "in" }, { 24, -6, "out" }, { 29, 0 } })
        self:put(tx[key .. "_text"], { dy = ty, fade = ramp(u, 6, 3) })
    end
end

function KinotakeResult:draw()
    local f = self:frames()
    self:draw_field(f)
    self:draw_header(f)
    self:draw_title(f)
    self:draw_koremade(f)
    for _, p in ipairs(self.players) do self:draw_panel(p, f) end
    self:draw_bonus_burst(f)
    self:draw_suspense(f)
    self:draw_lead(f)
end
