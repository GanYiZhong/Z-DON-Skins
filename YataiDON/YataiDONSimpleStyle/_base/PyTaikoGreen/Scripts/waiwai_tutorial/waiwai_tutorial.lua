local S = tex.get_screen_scale()
local F = 1000 / 60
local TARGET_X = 410
local LANE_Y = { 258, 434 }
local DRUM_Y = { 272, 448 }
local RED, BLUE = 1, 2
local WAIT_START, WAIT_FRAMES, LOOP_FROM = 1856, 300, 1817
local SKIP_HITS, SKIP_HOLD = 5, 30

WaiwaiTutorial = {}
WaiwaiTutorial.__index = WaiwaiTutorial

local function lerp(a, b, t) return a + (b - a) * t end
local function clamp01(t) return math.max(0, math.min(1, t)) end
local function seg(f, f0, f1, a, b) return lerp(a, b, clamp01((f - f0) / (f1 - f0))) end
local function ease_out(f, f0, f1, a, b) local t = clamp01((f - f0) / (f1 - f0)); return lerp(a, b, 1 - (1 - t) * (1 - t)) end
local function ease_in(f, f0, f1, a, b) local t = clamp01((f - f0) / (f1 - f0)); return lerp(a, b, t * t) end
local function tri(f, period) local t = (f % period) / period; return t < 0.5 and t * 2 or 2 - t * 2 end
local function swap(f, period, a, b) return (f % period) < period / 2 and a or b end

local DO, KO, KA, KAT, DON = "moji_do", "moji_ko", "moji_ka", "moji_katsu", "moji_don"
local function don(at, lanes, label, sync) return { at = at, lanes = lanes, label = label or DO, sync = sync } end
local function kat(at, lanes, label) return { at = at, lanes = lanes, label = label or KA, kat = true } end
local BOTH = { 1, 2 }
local SYNC_PATTERN = {
    don(0, BOTH), don(15, { 2 }), don(30, BOTH, DO, true),
    don(60, BOTH), don(75, { 1 }), don(90, BOTH, DO, true),
}

local CUTS = {
    { first = 0, last = 399, period = 120, travel = 119, hits = SYNC_PATTERN,
      clock = function(r) return 121 + r end },
    { first = 400, last = 811, period = 239, travel = 159, clock = function(r) return r - 400 end, hits = {
        don(159, BOTH, DON), don(194, { 2 }, DON), don(229, BOTH, DON),
        don(279, BOTH, DON), don(314, { 1 }, DON), don(349, BOTH, DON) } },
    { first = 812, last = 1061, period = 96, travel = 119, clock = function(r) return 114 + r - 812 end, hits = {
        don(23, { 1 }), don(34, { 1 }, KO), don(47, { 1 }),
        don(71, { 2 }), don(83, { 2 }, KO), don(95, { 2 }) } },
    { first = 1062, last = 1521, period = 119, travel = 119, hits = SYNC_PATTERN, clock = function(r)
        local l = 120 + r - 1062
        if l <= 209 then return l end
        return l <= 400 and 209 or l - 191
    end },
    { first = 1522, last = math.huge, period = 144, travel = 119, clock = function(r) return 79 + r - 1522 end, hits = {
        don(23, { 1 }), kat(35, { 1 }), don(47, { 1 }), kat(59, { 2 }, KAT), kat(71, { 1 }), don(83, { 1 }), kat(95, { 1 }),
        don(119, { 1 }), don(131, { 1 }, KO), don(143, { 1 }) } },
}

local RAYS = {
    { "ray_wide_green", -408, -326, 1.31, 1, 46 }, { "ray_wide_gold", -587, -426, 1, 1, 11 },
    { "ray_wide_gold", -483, -387, 0.6, 1, 30, 0.5 },
    { "ray_thin_teal", -427, -453, 1, 1.25, 32 }, { "ray_thin_yellow", -403, -436, 1, 1.25, 36 }, { "ray_thin_purple", -521, -496, 1, 1.25, 18 },
    { "ray_thin_cyan", -285, -304, 1, 1.25, 60 }, { "ray_thin_orange", -300, -329, 1, 1.25, 56 },
    { "ray_wide_cyan", -418, 558, 1.43, 1.49, 152 }, { "ray_wide_pink", -226, 365, 0.65, 1.46, 121 }, { "ray_wide_blue", -587, 441, 0.6, 1, -11, 0.5 },
    { "ray_thin_orange", -466, 489, 1, 1.25, -26 }, { "ray_thin_cyan", -453, 483, 1, 1.25, -28 }, { "ray_thin_yellow", -579, 526, 1, 1.25, -10 },
    { "ray_thin_teal", -285, 319, 1, 1.25, -60 }, { "ray_thin_purple", -342, 397, 1, 1.25, -47 },
}

local CUES = {
    { 0, "vo_title_1p" }, { 0, "vo_title_2p" }, { 0, "se_cheers1", "sound" }, { 410, "vo_gauge" }, { 430, "se_gaugeup1", "sound" },
    { 501, "se_popup", "sound" }, { 600, "se_gaugeup2", "sound" }, { 680, "se_gaugemax", "sound" },
    { 812, "vo_kakeai" }, { 1062, "vo_sync" }, { 1151, "se_popup", "sound" }, { 1296, "se_donjump", "sound" },
    { 1522, "vo_solo" }, { 1800, "vo_shime" }, { 1800, "se_cheers2", "sound" },
}

function WaiwaiTutorial.new()
    local self = setmetatable({}, WaiwaiTutorial)
    self.cache = {}
    self.f = 0
    self.fx = {}
    self.drum = { {}, {} }
    self.cut = nil
    self.next_cue = 1
    self.skips = 0
    self.skip_t = {}
    self.done_f = nil
    audio.play_sound("bgm", "music")
    return self
end

function WaiwaiTutorial:art(key)
    local t = self.cache[key]
    if not t then
        local info = tex.get_texture_info("movie", key)
        t = { id = tex.get_texture("waiwai_tutorial/movie/" .. key), w = info and info.x2[1] or 0, h = info and info.y2[1] or 0 }
        self.cache[key] = t
    end
    return t
end

function WaiwaiTutorial:D(key, cx, cy, o)
    local t = self:art(key)
    if not t.id then return end
    o = o or {}
    local a = o.a or 1
    if a <= 0 then return end
    local sx, sy = o.sx or o.s or 1, o.sy or o.s or 1
    local w, h = t.w * sx, t.h * sy
    local p = { x2 = (w - t.w) * S, y2 = (h - t.h) * S, fade = a,
                mirror = o.flip and "horizontal" or nil, blend = o.add and "additive" or nil }
    if o.rot then
        p.x, p.y, p.origin, p.rotation = cx * S, cy * S, { w / 2 * S, h / 2 * S }, o.rot
    else
        p.x, p.y = (cx - w / 2) * S, (cy - h / 2) * S
    end
    tex.draw_texture(t.id, p)
end

function WaiwaiTutorial:root()
    if self.f < WAIT_START then return self.f end
    return LOOP_FROM + (self.f - WAIT_START) % (WAIT_START - LOOP_FROM)
end

local function cut_at(f)
    for _, c in ipairs(CUTS) do
        if f >= c.first and f < c.last + 1 then return c end
    end
end

local function play(name, preset)
    if audio.has_sound(name) then audio.play_sound(name, preset or "voice") end
end

function WaiwaiTutorial:fire(h, lane, f)
    table.insert(self.fx, { t = f, lane = lane, kat = h.kat, sync = h.sync })
    local d = self.drum[lane]
    d.right = not d.right
    d.t, d.is_kat = f, h.kat

    if f >= 812 then play(h.kat and "se_kat" or "se_don", "sound") end
end

function WaiwaiTutorial:update(ms, kat_hits)
    self.f = ms / F
    local f = self.f
    while self.skips < kat_hits and self.skips < SKIP_HITS do
        self.skips = self.skips + 1
        self.skip_t[self.skips] = f
        if self.skips == SKIP_HITS then self.done_f = f + SKIP_HOLD end
    end
    if not self.done_f and f >= WAIT_START + WAIT_FRAMES then self.done_f = f end

    while CUES[self.next_cue] and CUES[self.next_cue][1] <= f do
        play(CUES[self.next_cue][2], CUES[self.next_cue][3])
        self.next_cue = self.next_cue + 1
    end

    local cut = cut_at(f)
    if cut ~= self.cut then
        self.cut = cut
        self.prev_n = cut.clock(f)
        return
    end
    local n = cut.clock(f)
    for _, h in ipairs(cut.hits) do
        local k = math.floor((self.prev_n - h.at) / cut.period) + 1
        local hit = h.at + k * cut.period
        while hit <= n do
            for _, lane in ipairs(h.lanes) do self:fire(h, lane, f) end
            k = k + 1
            hit = h.at + k * cut.period
        end
    end
    self.prev_n = n
    for i = #self.fx, 1, -1 do
        if f - self.fx[i].t > 40 then table.remove(self.fx, i) end
    end
end

function WaiwaiTutorial:is_finished()
    return self.done_f ~= nil and self.f >= self.done_f
end

-- ---------------------------------------------------------------- stage

local function pulse(f, period, lo)
    return lerp(lo, 1, tri(f, period))
end

function WaiwaiTutorial:speaker(f, x, y, flip)
    local beat = f % 40
    local s = beat < 3 and seg(beat, 0, 3, 1, 1.1) or seg(beat, 3, 10, 1.1, 1)
    self:D("speaker", x, y, { s = s, flip = flip })
    local ring = (f % 80) < 40 and "speaker_ring_yellow" or "speaker_ring_pink"
    local side = flip and -1 or 1
    self:D(ring .. "_0", x + 25 * side, y + 48, { s = seg(beat, 3, 19, 0.75, 3), a = seg(beat, 3, 19, 1, 0.1) })
    self:D(ring .. "_1", x + 28 * side, y - 52, { s = seg(beat, 3, 19, 0.75, 3), a = seg(beat, 3, 19, 1, 0.1) })
end

-- the three giant-screen images cross-fade over 9 frames
function WaiwaiTutorial:screens(f, y, images, hold, a)
    local count = #images
    local i = math.floor(f / hold) % count
    local into = f % hold
    self:D(images[i + 1], 640, y, { a = a })
    if into > hold - 9 then
        self:D(images[(i + 1) % count + 1], 640, y, { a = a * seg(into, hold - 9, hold, 0, 1) })
    end
end

function WaiwaiTutorial:stage_gold(f)
    local Y = 405
    self:D(swap(f, 80, "gold_banner_0", "gold_banner_1"), 640, Y + 219)
    self:D("stage_top_strip", 640, Y - 373)
    self:D(swap(f, 80, "gold_ceiling_0", "gold_ceiling_1"), 640, Y - 373)
    self:D("stage_back", 640, Y - 45)
    self:D(swap(f, 80, "gold_bulbs_0", "gold_bulbs_1"), 640, Y - 361)
    self:D("gold_spot_lamps", 80, Y - 385)
    self:D("gold_spot_lamps", 1200, Y - 385, { flip = true })
    self:D("gold_fringe", 640, Y - 344 + tri(f, 40) * 3)
    self:D("gold_line", 640, Y + 155)
    self:screens(f, Y + 215, { "gold_screen_0", "gold_screen_1", "gold_screen_2" }, 120, 1)
    self:D("gold_screen_glow", 640, Y + 215, { a = pulse(f, 40, 0.6) })
    self:D("stage_truss", 640, Y + 215)
    self:D("stage_beams", 640, Y + 189)
    self:D("stage_bulb_strings", 640, Y + 215)
    self:D("gold_lamps", 640, Y + 275)
    self:D("gold_lamps_glow", 640, Y + 275, { a = pulse(f, 20, 0.6) })
    self:D("stage_rail", 640, Y + 275)
    self:D("stage_canopy", 640, Y - 285)
    self:D("gold_rail_pattern", 640, Y + 291)
    self:D("gold_rail_line", 640, Y + 275)
    self:speaker(f, 26, Y + 255, false)
    self:speaker(f, 1254, Y + 255, true)
    self:D("crowd_back", 640, Y - 305 + tri(f, 40) * 5)
    self:D("crowd_mid", 640, Y - 273)
    self:D(swap(f, 40, "gold_crowd_front_0", "gold_crowd_front_1"), 640, Y - 315)
    self:D(swap(f, 40, "crowd_cheer_0", "crowd_cheer_1"), 640, Y - 313)
    self:D(swap(f, 40, "crowd_jump_0", "crowd_jump_1"), 640, Y - 293)
    self:D("stage_arch", 640, Y - 225)
    self:D("gold_arch_line", 640, Y - 257)
end

function WaiwaiTutorial:stage_blue(f, a)
    local function P(n, y, o) o = o or {}; o.a = a; self:D(n, o.x or 640, 360 + y, o) end
    P(swap(f, 80, "blue_ceiling_0", "blue_ceiling_1"), 264)
    P("stage_top_strip", -328)
    P("stage_back", 0)
    P("blue_bulbs", -316)
    P("blue_spot_lamps", -340, { x = 80 })
    P("blue_spot_lamps", -340, { x = 1200, flip = true })
    P("blue_line", 200)
    self:screens(f, 620, { "blue_screen_0", "blue_screen_1" }, 160, a)
    P("blue_screen_glow", 260)
    P("stage_truss", 260)
    P("stage_beams", 234)
    local lamp = swap(f, 160, "blue_lamps_0", "blue_lamps_1")
    P(lamp, 320, { x = 240 })
    P(lamp, 320, { x = 1040, flip = true })
    P("stage_rail", 320)
    P("stage_canopy", -240)
    P("blue_rail_line", 320)
    P("crowd_back", -260)
    P("crowd_mid", -228)
    P(swap(f, 40, "crowd_cheer_0", "crowd_cheer_1"), -268)
    P(swap(f, 40, "crowd_jump_0", "crowd_jump_1"), -248)
    P("stage_arch", -180)
end

function WaiwaiTutorial:dancer(f, x, base)
    local beat = f % 40
    local pose = (beat < 19 or beat >= 38) and "_0" or "_2"
    self:D(base .. pose, x, 624)
    if (beat >= 13 and beat < 21) or (beat >= 32) then self:D(base .. "_1", x, 624) end
end

function WaiwaiTutorial:rays(f, a)
    local sway = math.sin(f / 360 * math.pi * 2) * 4
    for _, r in ipairs(RAYS) do
        self:D(r[1], 640 + r[2], 360 + r[3], { sx = r[4], sy = r[5], rot = r[6] + sway, a = a * (r[7] or 1) })
        self:D(r[1], 640 - r[2], 360 - r[3], { sx = r[4], sy = r[5], rot = r[6] + sway + 180, a = a * (r[7] or 1) })
    end
end

-- ---------------------------------------------------------------- gauge

local function red_cell(self, i)
    self:D(i % 2 == 0 and "gauge_red_cell_0" or "gauge_red_cell_1", 810 + 15 * i, 165)
end

function WaiwaiTutorial:gauge_full()
    self:D("gauge_frame_clear", 872, 144)
    self:D("gauge_back", 872, 144)
    for _, x in ipairs({ 578, 728, 878 }) do self:D("gauge_red_block_10", x, 165) end
    for i = 10, 13 do red_cell(self, i) end
    self:D("gauge_yellow_block_5", 1055, 153)
    self:D("gauge_clear_text_lit", 1054, 142)
end

-- r = frames since the gauge cut began: the red part fills, a beat later it crosses the clear line, then goes rainbow
function WaiwaiTutorial:gauge_fill(r)
    if r < 200 then
        self:D("gauge_frame_red", 872, 144)
    elseif r < 280 then
        self:D("gauge_frame_clear", 872, 144)
    else
        self:D("gauge_frame_rainbow", 872, 144)
    end
    self:D("gauge_back", 872, 144)
    if r >= 280 then
        self:D("gauge_rainbow_" .. math.floor(r / 5) % 8, 882, 152)
        return
    end
    self:D("gauge_red_block_10", 578, 165)
    self:D("gauge_red_block_10", 728, 165)
    if r >= 75 then self:D("gauge_red_block_10", 878, 165) end
    for i = 0, 13 do
        if r >= 30 + i * 5 and (i >= 10 or r < 75) then red_cell(self, i) end
    end
    for i = 0, 15 do
        if r >= 200 + i * 5 then self:D(i % 2 == 0 and "gauge_yellow_cell_0" or "gauge_yellow_cell_1", 1025 + 15 * i, 153) end
    end
end

-- ---------------------------------------------------------------- lanes and notes

function WaiwaiTutorial:drum_face(lane)
    local y = DRUM_Y[lane]
    self:D("drum", 268, y)
    local d = self.drum[lane]
    if d.t then
        local age = self.f - d.t
        if age < 11 then
            local a = age < 7 and 1 or seg(age, 7, 10, 0.75, 0)
            local n = (d.is_kat and "drum_katsu_" or "drum_don_") .. (d.right and "right" or "left")
            self:D(n, 268, y, { a = a })
        end
    end
end

function WaiwaiTutorial:lanes()
    self:D("lane_back", 806, 272, { sx = 118.5 })
    self:D("lane_back", 806, 448, { sx = 118.5 })
    self:D("lane_target", TARGET_X, LANE_Y[RED], { a = 0.6, add = true })
    self:D("lane_target", TARGET_X, LANE_Y[BLUE], { a = 0.6, add = true })
    self:D("lane_1p_back", 168, 272)
    self:drum_face(RED)
    self:D("badge_1p", 34, 259)
    self:D("course_easy", 102, 259)
    self:D("lane_2p_back", 168, 448)
    self:drum_face(BLUE)
    self:D("badge_2p", 34, 435)
    self:D("course_normal", 102, 435)
end

function WaiwaiTutorial:note(h, lane, x, age, a)
    local y = LANE_Y[lane]
    if h.sync then
        self:D("sync_glow", x, y, { a = a * lerp(0.6, 1, tri(age, 40)) })
        local rail = lerp(-21, 12, tri(age, 40))
        local turned = lane == BLUE
        local dir = turned and -1 or 1
        self:D("sync_arm", x - 16 * dir, y + dir * (54 + rail), { a = a, rot = turned and 180 or nil })
        self:D("sync_arm", x + 16 * dir, y + dir * (54 - 9 - rail), { a = a, rot = turned and 180 or nil })
    end
    local base = h.kat and "katsu_" or "don_"
    self:D(base .. ((age % 40) < 20 and 0 or 1), x, y, { a = a })
end

function WaiwaiTutorial:notes(cut, r, a)
    local n = cut.clock(r)
    local px = 950 / cut.travel
    local list = {}
    for _, h in ipairs(cut.hits) do
        local hit = h.at + math.ceil((n - h.at) / cut.period) * cut.period
        while hit - cut.travel <= n do
            list[#list + 1] = { h = h, hit = hit }
            hit = hit + cut.period
        end
    end
    table.sort(list, function(p, q) return p.hit < q.hit end)
    for _, it in ipairs(list) do
        local x = TARGET_X + (it.hit - n) * px
        for _, lane in ipairs(it.h.lanes) do self:D(it.h.label, x + 1, LANE_Y[lane] + 81, { a = a }) end
    end
    for _, it in ipairs(list) do
        local x = TARGET_X + (it.hit - n) * px
        for _, lane in ipairs(it.h.lanes) do self:note(it.h, lane, x, it.hit - n, a) end
    end
end

function WaiwaiTutorial:effect(e)
    local age = self.f - e.t
    local y = LANE_Y[e.lane]
    if age < 30 then
        -- the struck note flies off towards the gauge / the bottom of the screen
        local t = age / 30
        local to_y = e.lane == RED and -89 or 779
        self:D(e.kat and "katsu_0" or "don_0", lerp(TARGET_X, 1150, t), lerp(y, to_y, t))
    end
    if e.sync and age < 19 then
        local px = age < 13 and seg(age, 0, 13, 51, 157) or seg(age, 13, 18, 157, 147)
        local py = age < 13 and seg(age, 0, 13, -18, 73) or seg(age, 13, 18, 73, 116)
        local s = seg(age, 0, 18, 1.27, 0.4)
        for k = 0, 7 do
            local ang = k * math.pi / 4
            self:D("sync_spark", TARGET_X + px * math.cos(ang) - py * math.sin(ang), y + px * math.sin(ang) + py * math.cos(ang), { s = s, add = true })
        end
    end
    if age < 9 then
        local ring = age < 3 and 0 or (age < 5 and 1 or (age < 7 and 2 or 3))
        self:D("hit_ring_" .. ring, TARGET_X, y, { s = seg(age, 0, 2, 0.4, 1), a = age < 7 and 1 or seg(age, 7, 9, 0.5, 0), add = true })
    end
    if age < 20 then
        local dy = age < 2 and seg(age, 0, 2, -45, -89) or seg(age, 2, 6, -89, -76)
        self:D("judge_good", TARGET_X, y + dy, { a = age < 2 and seg(age, 0, 2, 0.5, 1) or (age < 15 and 1 or seg(age, 15, 20, 0.8, 0)) })
    end
end

-- ---------------------------------------------------------------- cut overlays

local function fade_win(r, f0, f1, f2, f3)
    if r < f0 or r > f3 then return 0 end
    if r < f1 then return seg(r, f0, f1, 0, 1) end
    if r <= f2 then return 1 end
    return seg(r, f2, f3, 1, 0)
end

function WaiwaiTutorial:black(r, f0, f1, f2, f3)
    local a = fade_win(r, f0, f1, f2, f3)
    if a > 0 then self:D("black", 640, 360, { sx = 32, sy = 18, a = a }) end
end

function WaiwaiTutorial:gauge_callout(r)
    local a = fade_win(r, 400, 410, 693, 703)
    if a > 0 then
        self:D("gauge_mask", 640, 360, { a = a * 0.6 })
        self:D("gauge_callout_frame", 870, 150, { a = a })
    end
    if r >= 410 and r < 501 then
        -- the hand taps towards the clear line, then gives way to the bubble
        local tap = tri(r - 410, 40)
        self:D("hand_pointer", 1080 - 20 * tap, 260 - 26 * tap, { a = r < 491 and 1 or seg(r, 491, 500, 0.9, 0) })
    end
    if r < 501 or r > 703 then return end
    local l = r - 501
    local y = l < 10 and ease_out(l, 0, 9, 42, -15) or (l < 19 and seg(l, 10, 18, -15, 4) or (l < 22 and seg(l, 19, 21, 4, 0) or 0))
    local b = (l < 10 and seg(l, 0, 9, 0, 1) or 1) * (l < 116 and 1 or seg(l, 116, 124, 1, 0)) * fade_win(r, 400, 410, 693, 703)
    self:D("clear_bubble", 1010, 272 + y, { a = b })
    if (l >= 31 and l < 36) or (l >= 41 and l < 46) or (l >= 51 and l < 56) or (l >= 61 and l < 66) then
        self:D("clear_bubble_flash", 1010, 272, { a = b })
    end
    self:D("clear_bubble_text", 1010, 272 + y, { a = b })
end

function WaiwaiTutorial:mascots(r)
    if r < 812 or r > 1061 then return end
    self:D("mascot_don", 196, 532, { flip = true })
    self:D("mascot_katsu", 1124, 630)
end

-- l = the sync sprite's own frame
function WaiwaiTutorial:sync_cut(l)
    if l < 159 then return end
    local function caption(y)
        local x = l < 171 and ease_out(l, 159, 170, 1000, 595) or 595
        local s = l < 171 and 1.6 or seg(l, 171, 173, 1.4, 1)
        self:D("sync_caption", x, y, { s = s })
        if l >= 205 and (l - 205) % 60 < 40 then self:D("sync_caption_flash", 595, y) end
    end
    caption(544)
    caption(170)
    if l >= 209 and l <= 399 then
        self:D("sync_spotlight_mask", 640, 360, { a = 0.6 })
        self:D("sync_frame", 410, 346)
        self:D("sync_frame", 880, 346)
        local bob = 20 * tri(l - 209, 40)
        self:D("hand_pointer", 521 - bob, 440 - bob)
        local y = l < 218 and seg(l, 209, 217, 690, 560) or (l < 222 and seg(l, 218, 221, 567, 590) or 590)
        self:D("sync_bubble", 650, y)
    end
    if l >= 354 and l <= 426 then
        for side = -1, 1, 2 do
            local x, y, n
            if l <= 396 then
                n = side < 0 and "jump_up_don" or "jump_up_katsu"
                x = 640 + side * (l < 366 and ease_out(l, 354, 365, 760, 470) or 470)
                y = 360 + (l < 366 and ease_out(l, 354, 365, 256, -64) or (l < 387 and -66 or seg(l, 387, 396, -67, -97)))
            else
                n = side < 0 and "jump_fall_don" or "jump_fall_katsu"
                x = 640 + side * (l < 409 and 430 or ease_in(l, 409, 426, 430, 351))
                y = 360 + (l < 409 and 30 or ease_in(l, 409, 426, 30, 451))
            end
            self:D(n, x, y, { flip = side > 0 })
        end
    end
end

function WaiwaiTutorial:solo_cut(r)
    if r < 1562 then return end
    local a = seg(r, 1562, 1571, 0, 1)
    for _, x in ipairs({ 345, 505 }) do self:D("solo_star_small", x, 720, { a = a * pulse(r, 40, 0.7) }) end
    for _, x in ipairs({ 265, 425, 585 }) do self:D("solo_star_large", x, 720, { a = a * pulse(r + 20, 40, 0.7) }) end
    self:D("solo_ray", 340, 140, { a = a })
    local bubble_x = r < 1572 and ease_out(r, 1562, 1571, 1000, 586) or 586
    local beat = (r - 1580) % 60
    local bob = (r < 1580 or beat >= 40) and 0 or (beat < 10 and seg(beat, 0, 10, 0, 5) or (beat < 20 and seg(beat, 10, 20, 4, -5) or (beat < 30 and seg(beat, 20, 30, -4, 5) or seg(beat, 30, 40, 4.5, 0))))
    self:D("solo_bubble", bubble_x, 171 + bob, { a = r < 1572 and seg(r, 1562, 1571, 0.5, 1) or 1 })
    local dy = r < 1571 and seg(r, 1562, 1570, 915, 512) or (r < 1575 and seg(r, 1571, 1574, 519, 542) or (r < 1598 and 542 or 542 - 20 * tri(r - 1598, 40)))
    self:D("mascot_don", 196, dy, { flip = true })
end

function WaiwaiTutorial:title(r)
    if r < 396 then
        if r >= 41 then
            local a = r < 390 and 1 or seg(r, 390, 396, 0.85, 0)
            self:D("title_band", 640, 92, { sx = 32, sy = r < 46 and seg(r, 41, 46, 0.1, 1) or 1, a = a })
        end
        if r >= 15 then
            local s = r < 20 and seg(r, 15, 20, 1, 1.8) or (r < 26 and seg(r, 20, 26, 1.67, 0.95) or seg(r, 26, 30, 0.9, 1))
            local x = r < 390 and 150 or seg(r, 390, 395, 96, -173)
            self:D("two_player_badge", x, 117, { s = s, a = r < 390 and 1 or seg(r, 390, 395, 0.83, 0) })
        end
        if r >= 39 then
            local x = r < 47 and seg(r, 39, 46, 1600, 563) or seg(r, 47, 50, 569, 587)
            local a = r < 390 and 1 or seg(r, 390, 396, 1, 0)
            self:D("title_glow", x, 126, { a = a })
            if r >= 46 then self:D("title", x + 4, 132, { a = a }) end
        end
    elseif r >= 400 then
        self:D("title_glow", 245.9, 64, { s = 0.75 })
        self:D("title", 248.9, 68.5, { s = 0.75 })
    end
end

function WaiwaiTutorial:skip_ui(f)
    if self.f >= WAIT_START then return end
    local beat = f % 90
    local y = beat < 54 and 0 or (beat < 64 and ease_out(beat, 54, 63, -3.8, -20) or (beat < 73 and ease_in(beat, 64, 72, -19.75, 0) or (beat < 79 and ease_out(beat, 73, 78, -3, -10) or (beat < 84 and ease_in(beat, 79, 83, -9.6, 0) or 0))))
    self:D("skip_hint", 1114, 598 + 0.64 * y, { s = 0.64 })
    for i = 1, SKIP_HITS do
        local x = 1010 + 0.75 * (-11.25 + 76 * (i - 1))
        local hit = self.skip_t[i]
        if not hit then
            self:D("katsu_0", x, 639, { s = 0.75 })
        elseif f - hit < 12 then
            local age = f - hit
            self:D("katsu_0", x, 639, { s = 0.75 * (age < 7 and seg(age, 2, 6, 1.14, 1.4) or seg(age, 7, 11, 1.35, 0.1)) })
        end
    end
end

function WaiwaiTutorial:draw(ms)
    local f = self.f
    local r = self:root()
    self:stage_gold(f)
    local blue = fade_win(r, 389, 400, 600, 610)
    if blue > 0 then self:stage_blue(f, blue) end
    if r >= 1562 then
        -- the solo cut's floor spots sit behind the dancers
        local spot = seg(r, 1562, 1571, 0, 0.85)
        self:D("solo_spot", 388, 630, { a = spot })
        self:D("solo_spot", 468, 630, { a = spot, flip = true })
    end
    self:dancer(f, 850, "dancer_katsu")
    self:dancer(f, 430, "dancer_don")

    if r < 400 then
        self:rays(f, r < 390 and 1 or seg(r, 390, 399, 0.9, 0))
    elseif r >= 400 and r <= 811 then
        self:gauge_fill(r - 400)
    elseif r <= 1061 then
        self:D("black", 640, 360, { sx = 32, sy = 18, a = 0.7 })
    elseif r <= 1521 then
        self:rays(f, 1)
    end
    if r < 400 or r >= 812 then self:gauge_full() end

    self:lanes()

    local cut = self.cut or cut_at(f)
    local note_a = (r >= 395 and r < 400) and seg(r, 395, 399, 0.8, 0) or 1
    self:notes(cut, f, note_a)
    for _, e in ipairs(self.fx) do self:effect(e) end
    self:mascots(r)
    if r >= 1062 and r <= 1521 then self:sync_cut(120 + r - 1062) end

    self:gauge_callout(r)
    self:solo_cut(r)

    self:black(r, 801, 810, 813, 823)
    self:black(r, 1051, 1060, 1063, 1073)
    self:black(r, 1511, 1520, 1523, 1533)
    if r < 8 then self:D("black", 640, 360, { sx = 32, sy = 18, a = seg(r, 0, 8, 1, 0) }) end

    self:title(r)
    self:skip_ui(f)
end
