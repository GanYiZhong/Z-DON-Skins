AIIntro = {}
AIIntro.__index = AIIntro

local S = tex.get_screen_scale()
local F = 1000 / 60
local LEFT, RIGHT, DECIDE = 1, 2, 3
local SKIP_WAIT, FORCED_SKIP = 30, 1200
local INPUT_WAIT = 60
local OUT_FRAMES = 30
local OX, OY = 640, 324

local function clamp01(v) return math.max(0, math.min(1, v)) end
local function ramp(f, at, len) return clamp01((f - at) / len) end
local function lerp(a, b, u) return a + (b - a) * u end

-- rows: { from, to, scale_from, scale_to, y_from, y_to }
local function track(rows, f)
    if rows then
        for _, r in ipairs(rows) do
            if f <= r[2] then
                local u = r[2] > r[1] and clamp01((f - r[1]) / (r[2] - r[1])) or 1
                return lerp(r[3], r[4], u), lerp(r[5], r[6], u)
            end
        end
    end
    return 1, 0
end

local DON_HOP = {
    { 0, 3, 1, 0.988, 0, 2 }, { 4, 6, 0.992, 1, 1.3, 0 }, { 7, 16, 1, 1, -7.8, -78 }, { 17, 27, 1, 1, -70.9, 0 },
    { 28, 30, 0.996, 0.988, 0.65, 2 }, { 31, 33, 0.992, 1, 1.3, 0 },
}
local DON_JUMP = { { 0, 2, 1, 0.987, 0, 4 }, { 3, 12, 0.98, 0.998, 6, -140 }, { 13, 23, 1, 1, -156, -14 } }
local AIDON_HOP = {
    { 0, 3, 1, 0.965, 0, 7 }, { 4, 9, 0.983, 1.075, -18, -144 }, { 10, 15, 1.057, 0.965, -119, 7 },
    { 16, 19, 0.974, 1, 5, 0 },
}
local AIDON_TRIPLE = {
    { 0, 3, 1, 0.965, 0, 7 }, { 4, 9, 0.983, 1.075, -18, -144 }, { 10, 15, 1.057, 0.965, -119, 7 },
    { 16, 25, 0.974, 1.075, 5, -144 }, { 26, 31, 1.057, 0.965, -119, 7 },
    { 32, 39, 0.974, 1.075, 5, -144 }, { 40, 45, 1.057, 0.965, -119, 7 }, { 46, 49, 0.974, 1, 5, 0 },
}
local MAKINA_HOP = { { 0, 9, 1, 1, 0, -30 }, { 10, 19, 1, 1, -27, 0 } }
local MAKINA_DOUBLE = {
    { 0, 9, 1, 1, 0, -30 }, { 10, 19, 1, 1, -27, 0 }, { 20, 28, 1, 1, -3, -30 }, { 29, 38, 1, 1, -27, 0 },
}
local AIDON_BIG_JUMP = {
    { 0, 79, 1, 1, 0, 0 }, { 80, 83, 0.977, 0.906, -0.25, -1 }, { 84, 87, 0.93, 1, -0.8, 0 },
    { 88, 100, 1.005, 1.07, -10, -132 }, { 101, 114, 1.065, 1, -122.5, 0 },
    { 115, 118, 0.977, 0.906, -0.25, -1 }, { 119, 121, 0.938, 1, -0.65, 0 },
}

local PHRASES = {
    { bubble = "bubble_don", line = "line_don_where", se = "se_absurd", don = { "don_idle", DON_HOP }, bgm = true },
    { bubble = "bubble_aidon", line = "line_aidon_awake", aidon = AIDON_HOP },
    { bubble = "bubble_makina", line = "line_makina_hello", se = "se_norm", vo = "vo_makina_hello", makina = { "open", MAKINA_HOP } },
    { bubble = "bubble_don", line = "line_don_dream", se = "se_absurd" },
    { bubble = "bubble_makina", line = "line_makina_not_dream", se = "se_norm", makina = { "smile", MAKINA_DOUBLE } },
    { bubble = "bubble_makina", line = "line_makina_future", se = "se_norm", makina = { "blink" } },
    { bubble = "bubble_makina", line = "line_makina_sudden", se = "se_norm" },
    { bubble = "bubble_makina", line = "line_makina_challenge", se = "se_norm" },
    { bubble = "bubble_don", line = "line_don_strongest", se = "se_don_jump", don = { "don_cheer", DON_JUMP } },
    { bubble = "bubble_makina", line = "line_makina_yes", se = "se_norm", don = { "don_idle" }, makina = { "glad", MAKINA_HOP } },
    { bubble = "bubble_makina", line = "line_makina_learning", se = "se_norm" },
    { bubble = "bubble_makina", line = "line_makina_close_battle", se = "se_norm" },
    { bubble = "bubble_don", line = "line_don_confident", se = "se_norm", don = { "don_cheer", DON_JUMP } },
    { bubble = "bubble_aidon", line = "line_aidon_greeting", se = "se_norm", vo = "vo_aidon_thanks", aidon = AIDON_TRIPLE },
    { bubble = "bubble_makina", line = "line_makina_lets_go", se = "se_norm", vo = "vo_makina_thanks", makina = { "glad", MAKINA_HOP }, stop_bgm = true },
}

local PAGE_END = { [0] = 0, 168, 183, 319, 0, 88, 209 }
local LAST_PAGE = 6
local DUEL_FRAMES = { 0, 1, 2, 3, 2, 1 }

-- bright = starts lit, fades out first
local SPARKLES = {
    { "sparkle_green", -111, -198, true }, { "sparkle_green", 226, 202, true }, { "sparkle_yellow", -261, 179 },
    { "sparkle_green", 247, -203 }, { "sparkle_blue", -258, -142 }, { "sparkle_pink", 350, -171, true },
    { "sparkle_pink", -329, -8 }, { "sparkle_pink", 305, 146 }, { "sparkle_yellow_small", -332, -176, true },
    { "sparkle_yellow_small", -373, 131, true }, { "sparkle_yellow_small", 365, 27 }, { "sparkle_blue_small", 150, 142, true, 1.2 },
}

function AIIntro.new()
    local self = setmetatable({}, AIIntro)
    tex.load_folder("song_select", "ai_intro")
    self.ids, self.sizes = {}, {}
    self.draw_background = require("song_select/ai_background").new()
    self.hint_page = text.create_text("ai_intro_hint_page", { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 5, 2)
    self.hint_end = text.create_text("ai_intro_hint_end", { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 5, 2)
    self.now = tex.get_current_ms()
    self.mode = "story"
    self.story_t0 = self.now
    self.don = { "don_idle" }
    self:show_phrase(1)
    return self
end

function AIIntro:frame_since(ms)
    return (self.now - ms) / F
end

function AIIntro:play(name, preset)
    name = "ai_intro_" .. name
    if audio.has_sound(name) then audio.play_sound(name, preset or (name:find("_vo_") and "voice" or "sound")) end
end

function AIIntro:show_phrase(n)
    local p = PHRASES[n]
    self.phrase, self.phrase_t0 = n, self.now
    if p.don then self.don, self.don_t0 = p.don, self.now end
    if p.aidon then self.aidon, self.aidon_t0 = p.aidon, self.now end
    if p.makina then self.makina, self.makina_t0 = p.makina, self.now end
    if p.se then self:play(p.se) end
    if p.vo then self:play(p.vo) end
    if p.bgm then audio.play_sound("ai_intro_story_bgm", "music", true) end
    if p.stop_bgm then audio.stop_sound("ai_intro_story_bgm") end
end

function AIIntro:start_tutorial()
    self.mode = "tutorial"
    self.tutorial_t0 = self.now
    self:play("vo_rule")
    audio.play_sound("ai_intro_tutorial_bgm", "music", true)
    self:show_page(0)
end

function AIIntro:show_page(n)
    self.page, self.page_t0, self.rankup_played = n, self.now, false
end

function AIIntro:page_frame()
    return math.min(self:frame_since(self.page_t0), PAGE_END[self.page])
end

function AIIntro:next_phrase()
    if self.phrase < #PHRASES then
        self:show_phrase(self.phrase + 1)
        return
    end
    audio.play_sound("don", "sound")
    self:start_tutorial()
end

function AIIntro:update(current_ms)
    self.now = current_ms
    if self.mode == "story" then
        if self:frame_since(self.phrase_t0) >= FORCED_SKIP then self:next_phrase() end
    elseif self.mode == "tutorial" and self.page == 5 and not self.rankup_played and self:page_frame() >= PAGE_END[5] then
        self.rankup_played = true
        self:play("vo_rankup")
    end
end

function AIIntro:input_story(action)
    if self:frame_since(self.phrase_t0) < SKIP_WAIT then return end
    local last = self.phrase == #PHRASES
    if (action == DECIDE) == last then self:next_phrase() end
end

function AIIntro:input_tutorial(action)
    if self:frame_since(self.tutorial_t0) < INPUT_WAIT then return end
    if action == DECIDE then
        if self.page == LAST_PAGE then
            audio.play_sound("don", "sound")
            audio.stop_sound("ai_intro_tutorial_bgm")
            self.mode, self.out_t0 = "out", self.now
        end
        return
    end
    local ended = self:page_frame() >= PAGE_END[self.page]
    if action == LEFT and self.page == 0 then return end
    if action == RIGHT and self.page == LAST_PAGE and ended then return end
    audio.play_sound("kat", "sound")
    if not ended then
        self.page_t0 = self.now - PAGE_END[self.page] * F -- first hit finishes the page's animation
    else
        self:show_page(self.page + (action == LEFT and -1 or 1))
    end
end

function AIIntro:input(action)
    if self.mode == "story" then
        self:input_story(action)
    elseif self.mode == "tutorial" then
        self:input_tutorial(action)
    end
end

function AIIntro:is_done()
    return self.mode == "out" and self:frame_since(self.out_t0) >= OUT_FRAMES
end

function AIIntro:put(key, cx, cy, o)
    o = o or {}
    local id = self.ids[key]
    if id == nil then
        id = tex.get_texture("song_select/ai_intro/" .. key)
        self.ids[key] = id
        self.sizes[key] = tex.get_texture_info("ai_intro", key)
    end
    local info = self.sizes[key]
    if not info then return end
    local sx, sy = o.sx or o.s or 1, o.sy or o.s or 1
    local w, h = info.width * S, info.height * S
    tex.draw_texture(id, {
        x = cx * S, y = cy * S,
        x2 = w * (sx - 1), y2 = h * (sy - 1),
        origin = { w * sx * 0.5, h * sy * 0.5 },
        fade = o.fade or 1,
        frame = o.frame or 0,
        mirror = o.mirror,
        blend = o.add and "additive" or nil,
    })
end

function AIIntro:board(key, x, y, o)
    self:put(key, OX + x, OY + y, o)
end

local function draw_hint_text(hint, cx, cy, fade)
    hint:draw({ x = (cx - hint.width / (2 * S)) * S, y = (cy - hint.height / (2 * S)) * S, fade = fade })
end

-- drum with blinking rims; sides = "left", "right", "both"
function AIIntro:draw_rim_hint(ox, oy, f, sides, no_left_arrow)
    local fade = ramp(f, 45, 14)
    if fade <= 0 then return end
    local g = (f - 45) % 120
    local glow = g < 30 and g / 30 or math.max(1 - (g - 30) / 30, 0)
    local arrow = clamp01(1 - g / 60)
    local dx = clamp01(g / 60) * 7
    local cx, cy = ox - 132 + 28, oy - 29 + 28
    self:put("drum_rim", cx, cy, { fade = fade })
    if sides ~= "right" then
        self:put("drum_rim_glow", cx - 12, cy, { fade = fade * glow })
        if not no_left_arrow then self:put("drum_rim_arrow", cx - 27 - dx, cy, { fade = fade * arrow }) end
    end
    if sides ~= "left" then
        self:put("drum_rim_glow", cx + 12, cy, { fade = fade * glow, mirror = "horizontal" })
        self:put("drum_rim_arrow", cx + 27 + dx, cy, { fade = fade * arrow, mirror = "horizontal" })
    end
    draw_hint_text(self.hint_page, ox + 52, oy - 2, fade)
end

function AIIntro:draw_decide_hint(ox, oy, f)
    local fade = ramp(f, 9, 15)
    if fade <= 0 then return end
    local g = (f - 9) % 60
    local blink = g < 30 and 1 - g / 30 or (g - 30) / 30
    local flash = (f - 9) % 120
    flash = flash < 30 and flash / 30 or (flash < 60 and 1 - (flash - 30) / 30 or 0)
    self:put("hint_glow", ox + 120, oy - 3, { fade = fade * blink })
    self:put("hint_glow_round", ox - 43, oy - 1, { fade = fade * blink })
    draw_hint_text(self.hint_end, ox + 87, oy - 1, fade) -- the baked text sits left of its glow atlas
    self:put("drum_decide", ox - 43, oy - 1, { fade = fade })
    self:put("drum_decide_flash", ox - 43, oy - 1, { fade = fade * flash })
end

function AIIntro:draw_story()
    local OY_S = 326
    local p = PHRASES[self.phrase]
    local don_d, don_y = track(self.don[2], self:frame_since(self.don_t0))
    self:put(self.don[1], 327, 302 + don_y, { sy = don_d })
    if self.aidon then
        local d, y = track(self.aidon, self:frame_since(self.aidon_t0))
        self:put("aidon", 870, 312 + y, { sy = d })
    end
    if self.makina then
        local f = self:frame_since(self.makina_t0)
        local _, y = track(self.makina[2], f)
        local key = "makina_open"
        if self.makina[1] == "smile" then
            key = "makina_smile"
        elseif self.makina[1] == "glad" then
            key = f < 175 and "makina_glad" or "makina_open"
        elseif self.makina[1] == "blink" then
            local b = f % 182
            key = (b >= 173 and b < 181) and "makina_blink" or "makina_open"
        end
        self:put(key, 1074, OY_S - 36 + y)
    end
    self:put(p.bubble, 640, OY_S + 216)
    self:put(p.line, 640, OY_S + 219)
    local f = self:frame_since(self.phrase_t0)
    if self.phrase == #PHRASES then
        self:draw_decide_hint(993, 671, f)
    else
        self:draw_rim_hint(993, 668, self:frame_since(self.story_t0), "both", true)
    end
end

local function sparkle_alpha(f, bright)
    local g = f % 120
    local up = g <= 60 and g / 60 or 1 - (g - 60) / 60
    return bright and 1 - up or up
end

function AIIntro:draw_sparkles(ox, oy, f)
    for _, s in ipairs(SPARKLES) do
        self:board(s[1], ox + s[2], oy + s[3], { fade = sparkle_alpha(f, s[4]), s = s[5] })
    end
end

function AIIntro:draw_duel(x, y, f)
    self:board("duel", x, y, { frame = DUEL_FRAMES[math.floor(f / 4) % 6 + 1] })
end

function AIIntro:draw_burst(key, x, y, f, fade)
    if f >= 9 then return end
    local s = lerp(0.4, 1, clamp01(f))
    local a = f < 7 and 1 or lerp(0.5, 0, clamp01(f - 7))
    local frame = f < 3 and 0 or (f < 5 and 1 or (f < 7 and 2 or 3))
    self:board(key, x, y, { frame = frame, s = s, fade = a * fade, add = true })
end

function AIIntro:draw_hit_text(key, x, y, f, big, fades)
    local from, peak, settle_from, rest = -45, -79, -75.75, -66
    if not big then from, peak, settle_from, rest = -35, -59, -55.75, -46 end
    local ty, a
    if f < 2 then
        ty, a = lerp(from, peak, clamp01(f)), lerp(0.5, 1, clamp01(f))
    elseif f < 6 then
        ty, a = lerp(settle_from, rest, (f - 2) / 3), 1
    else
        ty, a = rest, 1
    end
    if fades and f >= 29 then a = lerp(0.832, 0, clamp01((f - 29) / 5)) end
    self:board(key, x, y + ty, { fade = a })
end

function AIIntro:draw_note(y, f, at, stop)
    if f < at or f > stop + 3 then return end
    if f <= stop then
        self:board("note_don", lerp(361, -95, (f - at) / (stop - at)), y)
    else
        local u = (f - stop - 1) / 2
        self:board("note_don", lerp(-109, -137, u), y, { fade = lerp(0.668, 0, u) })
    end
end

function AIIntro:draw_note_label(y, f, at, stop)
    if f < at or f > stop + 3 then return end
    if f <= stop then
        self:board("note_label", lerp(361, -95, (f - at) / (stop - at)), y)
    else
        local u = (f - stop - 1) / 2
        self:board("note_label", lerp(-109, -137, u), y, { fade = lerp(0.668, 0, u) })
    end
end

function AIIntro:draw_flash(key, x, y, f, at)
    local t = f - at
    if t < 0 or t > 19 then return end
    self:board(key, x, y, { fade = t < 3 and 1 or lerp(0.941, 0, (t - 3) / 16) })
end

function AIIntro:draw_flying_note(f, at)
    local t = f - at
    if t < 0 or t >= 40 then return end
    local x, y
    if t <= 28 then
        local u = t / 28
        x, y = lerp(-136, 326, u), lerp(-62, -271, u)
    elseif t <= 30 then
        local u = clamp01(t - 29)
        x, y = lerp(344.5, 363, u), -270.5
    else
        x, y = 363, -270.5
    end
    self:board("note_don", x, y + 55.5, { fade = 0.398 })
end

function AIIntro:draw_page_1(f)
    self:board("panel", 0, 0)
    self:board(f < 74 and "lane_even" or (f < 135 and "lane_ahead_1" or "lane_ahead_2"), 0, 0)
    self:draw_duel(f < 74 and 2 or (f < 135 and 81 or 242), -92.65, f)
    self:draw_flying_note(f, 56)
    self:draw_flying_note(f, 116)
    if f >= 56 and f <= 96 then
        self:draw_burst("burst_gold", -137, -6.85, f - 56, 1)
        self:draw_hit_text("text_good_big", -137, -6.85, f - 56, true)
        self:draw_burst("burst_gray", -137, 98.65, f - 56, 0.301)
        self:draw_hit_text("text_ok", -137, 98.65, f - 56, false, true)
    elseif f >= 116 then
        self:draw_burst("burst_gold", -137, -6.85, f - 116, 1)
        self:draw_hit_text("text_good_big", -137, -6.85, math.min(f - 116, 34), true)
        self:draw_hit_text("text_bad_small", -137, 98.65, math.min(f - 116, 34), false)
    end
    self:draw_flash("spirit_gold", -136.7, -6.45, f, 116)
    self:draw_flash("spirit_gold", -136.7, -6.45, f, 56)
    self:draw_flash("spirit_silver", -136.7, 98.5, f, 56)
    self:draw_note(-6.45, f, 0, 51)
    self:draw_note(99.1, f, 0, 51)
    self:draw_note(-6.45, f, 60, 113)
    self:draw_note(99.1, f, 60, 113)
    if f >= 53 then self:board("bubble_good", -253, -142) end
    if f >= 156 then
        local t = f - 156
        local s, a
        if t < 4 then
            s, a = lerp(2, 1.25, clamp01(t / 3)), lerp(0.5, 0.875, clamp01(t / 3))
        elseif t < 9 then
            s, a = lerp(1, 1.293, (t - 4) / 4), 1
        else
            s, a = lerp(1.22, 1, clamp01((t - 9) / 3)), 1
        end
        self:board("text_ahead", 153, 82, { s = s, fade = a })
    end
end

function AIIntro:draw_page_2(f)
    self:board("panel", 0, 0)
    self:board(f < 74 and "lane_even" or (f < 135 and "lane_behind_1" or "lane_behind_2"), 0, 0)
    self:draw_duel(f < 74 and 4 or (f < 135 and -73 or -238), -92, f)
    if f >= 56 and f <= 96 then
        self:draw_hit_text("text_bad_big", -137, -6.85, f - 56, true)
        self:draw_burst("burst_gray", -137, 98.65, f - 56, 0.301)
        self:draw_hit_text("text_ok", -137, 98.65, f - 56, false, true)
    elseif f >= 116 then
        self:draw_hit_text("text_bad_big", -137, -6.85, math.min(f - 116, 34), true)
        self:draw_burst("burst_gold", -137, 98.65, f - 116, 1)
        self:draw_hit_text("text_good_small", -137, 98.65, math.min(f - 116, 34), false)
    end
    self:draw_flash("spirit_silver", -136.7, -6.45, f, 56)
    self:draw_flash("spirit_gold", -136.7, 98.5, f, 116)
    self:draw_flash("spirit_gold", -136.7, 98.5, f, 56)
    self:draw_note_label(42.35, f, 0, 53)
    self:draw_note_label(147.9, f, 0, 53)
    self:draw_note_label(42.35, f, 60, 113)
    self:draw_note_label(147.9, f, 60, 113)
    self:draw_note(-6.45, f, 0, 53)
    self:draw_note(99.1, f, 0, 53)
    self:draw_note(-6.45, f, 60, 113)
    self:draw_note(99.1, f, 60, 113)
    if f >= 53 then self:board("bubble_miss", -243, -142) end
    if f >= 170 then self:board("text_behind", 180, 58, { fade = ramp(f, 170, 13) }) end
end

function AIIntro:draw_blink(key, x, y, f, at, on, cycle)
    if f < at then return end
    local g = math.floor(f - at) % cycle
    if g < on or g == cycle - 1 then self:board(key, x, y) end
end

function AIIntro:draw_page_3(f)
    self:board("panel_sections", 0, 0)
    self:board("lane_section", 0, 61.05)
    self:draw_blink("frame_section", -182, -23, f, 150, 20, 40)
    self:board("duel_small", 0, -31.1)
    self:board("text_section_reward", 0, -188)
    if f >= 79 then self:board("bubble_sections", -61, -149) end
    if f >= 184 then self:board("text_more_wins", -242, 185) end
    if f >= 264 then
        local t = f - 264
        local s, a = 1, 1
        if t < 6 then
            s, a = lerp(3, 1.333, t / 5), lerp(0, 0.832, t / 5)
        elseif t < 15 then
            local u = (t - 6) % 4 / 2
            s = u <= 1 and lerp(1, 1.03, u) or lerp(1.03, 1, u - 1)
        end
        self:board("banner_battle_win", 136, 173, { s = s, fade = a })
    end
end

function AIIntro:draw_page_5(f)
    self:board("panel", 0, 0)
    self:board("text_rank_means", 0, -188)
    self:board("shot_song_select", 206, 71)
    self:draw_blink("frame_section", 82, 2, f, 39, 20, 40)
    if f >= 88 then self:board("rank_panel", -157, 14) end
end

function AIIntro:draw_page_6(f)
    self:board("panel", 0, 0)
    self:board("text_rank_needs", 0, -188)
    self:board("shot_song_select", 189, -10)
    self:draw_blink("frame_rank", 108, -132, f, 39, 19, 40)
    if f >= 149 then
        self:board("text_in_addition", 0, 208)
        self:board("text_needed", 0, 208)
    end
    if f >= 181 then
        local u = clamp01((f - 181) / 4)
        local s = lerp(1.429, 1, u)
        self:board("badge_soul_clear", lerp(56, 0, u), 208, { s = s })
    end
    if f >= 205 then
        local u = clamp01((f - 205) / 4)
        local s = lerp(1.429, 1, u)
        self:board("badge_battle_win", lerp(-40.5, 0, u), 208, { s = s })
    end
    if f >= 100 then self:board("bubble_difficulty", -98, -17) end
end

function AIIntro:draw_page(f, t)
    local dot_x = { [0] = -63, -42, -21, 0, 21, 42, 63 }
    self:board("page_dot", dot_x[self.page], 282)
    if self.page == 0 or self.page == 4 then
        self:board("title_glow", 0, 0)
        local shift_x = self.page == 0 and 4 or 0
        self:draw_sparkles(shift_x, self.page == 0 and 0.5 or 0, t)
        self:board(self.page == 0 and "title_battle" or "title_rank", 0, 0)
    else
        self["draw_page_" .. self.page](self, f)
    end
end

function AIIntro:draw_tutorial_chara(t)
    self:put("shadow_makina", 1164.3, 704, { fade = 0.199 })
    self:put("shadow_aidon", 142, 705, { fade = 0.199 })
    local d, y = track(AIDON_BIG_JUMP, t % 250)
    self:put("aidon_big", 143.35, 720 - 128 * d + y, { sy = d })
    local m = t % 500
    local frame, x = 0, 0
    if m >= 499 then
        frame, x = 4, 3
    elseif m >= 274 then
        frame, x = 3, 3
    elseif m >= 184 then
        frame, x = 2, 3
    elseif (m >= 66 and m <= 72) or (m >= 127 and m <= 133) then
        frame = 1
    end
    self:put("makina_teacher", 1132.3 + x, 489.9, { frame = frame })
end

function AIIntro:draw_arrows(t)
    local a = t % 60
    local dx, fade
    if a < 30 then
        dx, fade = 29.65 * a / 29, 1
    else
        local u = (a - 30) / 29
        dx, fade = lerp(30, 40, u), lerp(0.965, 0, u)
    end
    if self.page > 0 then self:put("page_arrow", 96 - dx, 250, { fade = fade }) end
    if self.page < LAST_PAGE then
        self:put("page_arrow", 1182.9 + dx, 250, { fade = fade, mirror = "horizontal" })
    end
end

function AIIntro:draw_tutorial()
    local t = self:frame_since(self.tutorial_t0)
    local f = self:page_frame()
    self:put("board", OX, OY)
    self:draw_page(f, t)
    self:draw_tutorial_chara(t)
    if t >= INPUT_WAIT then self:draw_arrows(t) end
    if self.page == 0 then
        self:draw_rim_hint(898, 652, t, "right")
    elseif self.page == LAST_PAGE then
        self:draw_rim_hint(639, 648, t, "left")
        self:draw_decide_hint(898, 646, t)
    else
        self:draw_rim_hint(898, 652, t, "both")
    end
end

function AIIntro:draw()
    self.draw_background()
    if self.mode == "story" then
        self:draw_story()
        return
    end
    self:draw_tutorial()
    if self.mode == "out" then
        local a = clamp01(self:frame_since(self.out_t0) / OUT_FRAMES)
        tex.draw_rect(0, 0, tex.get_screen_width(), tex.get_screen_height(), 0, 0, 0, math.floor(255 * a))
    end
end
