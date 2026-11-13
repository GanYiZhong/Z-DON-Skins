require("game/gauge")

AIBattleOverlay = {}
AIBattleOverlay.__index = AIBattleOverlay

local DIR = "ai_battle/"
local TILES = 19
local TILE_WIDTH = 72
local SECTIONS = 5

local GAUGE_SCALE = 0.5
local GAUGE_X, GAUGE_Y = 10, 15


local S = tex.get_screen_scale()
local FRAME_MS = 1000 / 60

-- A triangle wave between 0 and 1.
local function flash(ms, period)
    return 1 - math.abs(2 * ((ms % period) / period) - 1)
end

-- Linear value of a {frame, value} key list; outside the keys it holds the end value.
local function track(f, keys)
    if f <= keys[1][1] then return keys[1][2] end
    for i = 2, #keys do
        local k0, k1 = keys[i - 1], keys[i]
        if f <= k1[1] then
            return k0[2] + (k1[2] - k0[2]) * (f - k0[1]) / (k1[1] - k0[1])
        end
    end
    return keys[#keys][2]
end

-- Fades in and out over `length` frames: the stage flash the Lumen sprites share.
local function blink(f, length)
    if f < 0 or f > length then return 0 end
    return 1 - math.abs(2 * f / length - 1)
end

function AIBattleOverlay.new()
    local self = setmetatable({}, AIBattleOverlay)
    self.ids = {}
    self.sizes = {}
    self:reset()
    return self
end

function AIBattleOverlay:id(key)
    self.ids[key] = self.ids[key] or tex.get_texture(key)
    return self.ids[key]
end

function AIBattleOverlay:reset()
    self.wins = {}
    self.section = 0
    self.section_count = SECTIONS
    self.event = nil      -- latest section result: { won, start }
    self.final = nil      -- match result: { won, full_combo, start }
    self.start_ms = nil
    self.phase = 1
    self.phase_start = nil
    self.played = {}
    self.flame_tier = {}
end

function AIBattleOverlay:set_section_result(section, won)
    self.wins[section] = won
    self.event = { won = won, section = section }
end

function AIBattleOverlay:set_match_result(won, full_combo)
    self.final = { won = won, full_combo = full_combo }
end

function AIBattleOverlay:spr(key, cx, cy, o)
    o = o or {}
    local info = self.sizes[key]
    if not info then
        info = tex.get_texture_info("ai_battle", key)
        self.sizes[key] = info
    end
    local sx, sy = o.sx or o.s or 1, o.sy or o.s or 1
    local w, h = info.width * S, info.height * S
    tex.draw_texture(self:id(DIR .. key), {
        x = cx * S, y = cy * S,
        x2 = w * (sx - 1), y2 = h * (sy - 1),
        origin = { w * sx * (o.ax or 0.5), h * sy * (o.ay or 0.5) },
        rotation = o.rot or 0,
        fade = o.fade or 1,
        frame = o.frame or 0,
        mirror = o.mirror,
        blend = o.add and "additive" or nil,
    })
end

-- Z-DON (Green): draw `key` with its top left at (x, y) + the shape origin (Z-DON's own ai_battle art, cut from
-- Green's ghost shapes; origins as Scripts/global/ai_battle.lua ORIGIN)
local ZORIGIN = {
    timer_frame = { -104, -20 }, timer_bar = { -4, -8 }, timer_fill = { -4, -8 }, timer_label = { -12, -20 },
}
function AIBattleOverlay:zat(key, x, y, o)
    o = o or {}
    local org = ZORIGIN[key] or { 0, 0 }
    tex.draw_texture(self:id(DIR .. key), {
        x = (x + org[1]) * S, y = (y + org[2]) * S, x2 = o.x2, frame = o.frame or 0, fade = o.fade or 1,
    })
end

function AIBattleOverlay:zinfo(key)
    local info = self.sizes[key]
    if not info then
        info = tex.get_texture_info("ai_battle", key)
        self.sizes[key] = info
    end
    return info
end

local function stamp(event, ms)
    if event and not event.start then event.start = ms end
end

function AIBattleOverlay:cue(name, preset, frame, at, tag)
    local key = name .. (tag or "")
    if frame >= (at or 0) and not self.played[key] then
        self.played[key] = true
        name = "ai_battle_" .. name
        if audio.has_sound(name) then audio.play_sound(name, preset) end
    end
end

function AIBattleOverlay:event_frame(ms)
    if not self.event or not self.event.start then return nil end
    local f = (ms - self.event.start) / FRAME_MS
    return f < 179 and f or nil
end

local function pattern_phase(section, count)
    if section >= count - 1 then return 3 end
    return section >= count // 2 and 2 or 1
end

local COLUMNS = {
    { "pattern_column_triangle", 358, 0, 289, 814, 440 }, { "pattern_column_triangle", 1136, 0, 244, 439, 813 },
    { "pattern_column_wave", 852, 0, 299, 441, 812 }, { "pattern_column_wave", 1206, 0, 165, 811, 438 },
    { "pattern_column_wave", 73, 0, 236, 440, 809 }, { "pattern_column_wave", 499, 82, 136, 441, 812 },
    { "pattern_column_maze", 923, 58, 185, 811, 440 }, { "pattern_column_triangle", 640, 0, 299, 438, 811 },
    { "pattern_column_diamond", 568, 24, 259, 814, 438 }, { "pattern_column_diamond", 287, 24, 170, 437, 813 },
    { "pattern_column_diamond", 993, 55, 211, 437, 811 },
}

local QUADS = {
    { 0, 71, 133, { 40, 133, 216 }, 0.4 }, { 1, 589, 73, { 40, 158 }, 0.8 }, { 2, 835, 50, { 82, 201 }, 0.3 },
    { 3, 1047, 104, { 40, 223 }, 0.3 }, { 4, 454, 134, { 48, 191 }, 0.2 }, { 5, 708, 169, { 130, 259 }, 0.4 },
    { 6, 949, 134, { 245 }, 0.3 }, { 7, 444, 48, { 91 }, 0.2 }, { 8, 1257, 169, { 73, 258 }, 0.3 },
    { 9, 754, 101, { 139 }, 0.2 }, { 10, 321, 75, { 153, 248 }, 0.4 },
}
local LINES = { "line_upper_1", "line_upper_2", "line_upper_3", "line_upper_4", "line_upper_5" }
local LINE_Y = { 161, 133, 103, 75, 47 }

function AIBattleOverlay:draw_patterns(ms)
    local phase = self.phase
    local since = (ms - (self.phase_start or ms)) / FRAME_MS
    local fade_in = math.min(since / 20, 1)
    local scroll = (ms % 8500) / 8500 * 1152
    local first = phase == 1 and 0.5 or (phase == 2 and 0.5 * (1 - math.min(since / 50, 1)) or 0)
    local second = phase == 2 and 0.5 * fade_in or (phase == 3 and 0.5 * (1 - math.min(since / 50, 1)) or 0)
    if first > 0 then
        tex.draw_texture(self:id(DIR .. "lower_triangles_1"), { y = scroll, fade = first })
    end
    if second > 0 then
        tex.draw_texture(self:id(DIR .. "lower_triangles_2"), { y = scroll, fade = second })
    end
    if phase < 2 then return end

    local f = (ms / FRAME_MS) % 480
    local rise = {
        { "pattern_swirl", 545, f - 73, 196 }, { "pattern_triangle", 239, f - 10, 200 },
        { "pattern_flower", 818, f, 135 }, { "pattern_triangle", 839, f - 267, 187 },
        { "pattern_triangle", 257, f - 311, 168 },
    }
    for _, r in ipairs(rise) do
        if r[3] >= 0 and r[3] <= r[4] then
            local p = r[3] / r[4]
            self:spr(r[1], r[2], 794 - 324 * p, {
                rot = (r[2] < 640 and 1 or -1) * 70 * p, fade = math.min(1 - p, fade_in), add = true,
            })
        end
    end
    if phase < 3 then return end

    local g = (ms / FRAME_MS) % 300
    self:spr("pattern_sprinkle", 642, 384 + 475 * g / 300, { fade = fade_in, add = true })
    self:spr("pattern_sprinkle", 642, 384 + 475 * ((g + 150) % 300) / 300, { fade = fade_in, add = true })
    for _, c in ipairs(COLUMNS) do
        local p = g - c[3]
        if p >= 0 and p <= c[4] then
            self:spr(c[1], c[2], c[5] + (c[6] - c[5]) * p / c[4], { fade = fade_in, add = true })
        end
    end
    for _, q in ipairs(QUADS) do
        for _, start in ipairs(q[4]) do
            local a = blink(g - start, 40)
            if a > 0 then self:spr("flash_quad", q[2], q[3], { frame = q[1], fade = a * q[5], add = true }) end
        end
    end
    for i, key in ipairs(LINES) do
        local a = math.max(blink(g, 40), 0.7 * blink(g - 40 - 4 * i, 20))
        if a > 0 then self:spr(key, 640, LINE_Y[i], { fade = a, add = true }) end
    end
    for i, y in ipairs({ 698, 650, 603, 553 }) do
        local a = math.max(blink(g, 40), 0.7 * blink(g - 36 - 4 * i, 20), 0.7 * blink(g - 125 - 4 * i, 20))
        if a > 0 then self:spr("line_lower", 640, y, { fade = a, add = true }) end
    end
    if since < 110 then
        for i, x in ipairs({ 429, 641, 1066, 216, 499, 851, 1207, 74 }) do
            local h = since - (i - 1) * 8
            local a = blink(h, 60)
            if a > 0 then
                self:spr(i % 2 == 0 and "flash_tile_narrow" or "flash_tile_wide", x, 628, { fade = a, add = true })
                self:spr(i % 2 == 0 and "flash_triangle_white" or "flash_triangle_yellow", x, 628 + 30 * (h / 60), {
                    s = 0.8 * (1 - 0.8 * h / 60), rot = 45 * h / 60, fade = a, add = true,
                })
            end
        end
    end
end

function AIBattleOverlay:draw_back(ms, territory)
    stamp(self.event, ms)
    stamp(self.final, ms)
    self.start_ms = self.start_ms or ms

    local since_start = (ms - self.start_ms) / FRAME_MS
    self:cue("se_enter", "sound", since_start)
    self:cue("vo_begin", "voice", since_start, 45)
    local event = self.event
    if event and event.start then
        local f = (ms - event.start) / FRAME_MS
        if not self.final then
            self:cue(event.won and "vo_section_win" or "vo_section_lose", "voice", f, 0, event.section)
        end
        self:cue(event.won and "se_section_win" or "se_section_lose", "sound", f, 10, event.section)
    end

    local phase = pattern_phase(self.section, self.section_count)
    if phase ~= self.phase then
        self.phase, self.phase_start = phase, ms
    end

    local red = math.min(math.max(1, territory + 10), TILES - 1)
    local showing_highlight = true
    local upper = "bg_upper"
    local back_fade
    local since_end
    if self.final and self.final.start then
        local f = (ms - self.final.start) / FRAME_MS
        since_end = f
        showing_highlight = false
        red = self.final.won and math.min(f // 1 + 1, TILES) or math.max(TILES - f // 1 - 1, 0)
        upper = self.final.won and "bg_final_upper" or "bg_lose_upper"
        back_fade = 1 - math.min(f / 5, 1)
    else
        local f = self:event_frame(ms)
        if f then
            showing_highlight = false
            red = self.event.won and math.min(f // 2 + 1, TILES) or math.max(TILES - f // 2 - 1, 0)
            upper = self.event.won and "bg_win_upper" or "bg_lose_upper"
            back_fade = 1 - math.min(f / 5, 1)
        end
    end
    red = math.floor(red)
    local blue = TILES - red
    local highlight = flash(ms, 332)

    tex.draw_texture(self:id(DIR .. "bg_lower"))
    for i = 0, red - 1 do
        tex.draw_texture(self:id(DIR .. "red_tile_lower"), { frame = i, x = i * TILE_WIDTH })
    end
    for i = 0, blue - 1 do
        tex.draw_texture(self:id(DIR .. "blue_tile_lower"), { frame = i, x = (TILES - 1 - i) * TILE_WIDTH })
    end
    self:draw_patterns(ms)
    if showing_highlight then
        tex.draw_texture(self:id(DIR .. "highlight_tile_lower"), { x = red * TILE_WIDTH, fade = highlight })
    end

    tex.draw_texture(self:id(DIR .. upper))
    if back_fade and back_fade > 0 then
        tex.draw_texture(self:id(DIR .. "bg_upper"), { fade = back_fade })
    end
    for i = 0, red - 1 do
        tex.draw_texture(self:id(DIR .. "red_tile_upper"), { frame = i, index = i })
    end
    for i = 0, blue - 1 do
        tex.draw_texture(self:id(DIR .. "blue_tile_upper"), { frame = i, index = TILES - 1 - i })
    end
    tex.draw_texture(self:id(DIR .. "bg_outline_upper"))
    if showing_highlight then
        local params = { frame = red - 1, index = red - 1, fade = highlight }
        if red > 9 then
            params.frame = TILES - red
            params.mirror = "horizontal"
        end
        tex.draw_texture(self:id(DIR .. "highlight_tile_upper"), params)
    end

    if self.final and self.final.won and since_end then
        local a = math.min(math.max(since_end - 18, 0) / 26, 1)
        self:spr("final_glow_lower", 640, 628, { fade = a })
        self:spr("final_glow_upper", 640, 94, { fade = a })
        self:spr("final_wreath", 640, 110, { fade = a, add = true })
        local h = since_end - 18
        if h >= 0 and h <= 26 then
            self:spr("final_wreath_flash", 640, 110, { s = 1 + 1.5 * h / 26, fade = 1 - h / 26 })
        end
    end

    -- Z-DON (Green): the flames burn behind the Don and the AI (cabinet: both stand in front of the clash, direct feed
    -- Tl7g8XXXvAM); upstream drew them from draw_clash, after the characters, which washed both out
    if not self.final and not self:event_frame(ms) then
        local border = self:border_x(territory)
        self:draw_flames(ms, border, territory + 9, 1)
        self:draw_flames(ms, border, territory + 9, -1)
    else
        self.flame_tier = {}
    end

    local intro = (ms - self.start_ms) / FRAME_MS
    if intro < 60 then
        for side = 1, 2 do
            local base = side == 1 and 151 or 1129
            for i = 0, 11 do
                local h = intro - i * 2
                if h >= 0 and h < 24 then
                    self:spr("trail_quad", base + (side == 1 and 1 or -1) * (i - 6) * 42, 106 - 8 * ((i % 4) - 2), {
                        frame = i, fade = 0.4 * (1 - h / 24), mirror = side == 2 and "horizontal" or nil,
                    })
                end
            end
        end
    end
end

-- Z-DON (Green): the section timer is Z-DON's (Green's ghost "time" shapes: frame, 150 px bar, fill, "N区" labels) at
-- the spot measured on the direct feed (264,174: its black frame joins the score plate under it), not upstream's
-- rect bar a few px higher and 20 px further left
local TIMER_X, TIMER_Y, TIMER_W = 264, 174, 150

function AIBattleOverlay:draw_timer(section, section_count, progress)
    if section >= section_count then return end
    self:zat("timer_frame", TIMER_X, TIMER_Y)
    local bar = self:zinfo("timer_bar")
    self:zat("timer_bar", TIMER_X - TIMER_W / 2 + 4, TIMER_Y, { x2 = (TIMER_W - bar.width) * S })
    if progress > 0 then
        local fill = self:zinfo("timer_fill")
        self:zat("timer_fill", TIMER_X - TIMER_W / 2 + 4, TIMER_Y, { x2 = (TIMER_W * progress - fill.width) * S })
    end
    self:zat("timer_label", TIMER_X - 87, TIMER_Y, { frame = section })
    if section < section_count - 1 then
        self:zat("timer_label", TIMER_X + 87, TIMER_Y, { frame = section + 1 })
    end
end

function AIBattleOverlay:draw_front(ms, section, section_count, progress)
    self:draw_timer(section, section_count, progress)
    self.section, self.section_count = section, section_count
    if section == section_count - 1 and not self.final then
        local won, lost = 0, 0
        for i = 0, section - 1 do
            if self.wins[i] == true then won = won + 1 elseif self.wins[i] == false then lost = lost + 1 end
        end
        self:cue(won > lost and "vo_reach_win" or (won < lost and "vo_reach_lose" or "vo_reach_draw"), "voice", 0)
    end
    -- 3 section songs use only the right three slots of the 5 slot row
    local slot_base = section_count == 3 and 2 or 0
    tex.draw_texture(self:id(DIR .. (section_count == 3 and "sections_three" or "sections")))
    if section < section_count then
        tex.draw_texture(self:id(DIR .. "section_highlight_green"), { index = slot_base + section })
        tex.draw_texture(self:id(DIR .. "section_highlight_white"), { index = slot_base + section, fade = flash(ms, 700) })
    end
    for i = 0, SECTIONS - 1 do
        if self.wins[i] ~= nil then
            tex.draw_texture(self:id(DIR .. (self.wins[i] and "section_win" or "section_lose")), { index = slot_base + i })
        end
    end
end

-- Mid-height x of the territory border at each red tile count; the upper band's tiles fan out, so not even.
local BORDER_X = { 135, 193, 256, 316, 376, 436, 495, 553, 612, 667, 722, 783, 842, 903, 963, 1022, 1083, 1142 }

-- Each side's flame grows through four tiers. A tier's clock restarts when it is entered, so the opening
-- flare plays once and then only the part's loop repeats. x and y in a layer are the image's centre,
-- measured from the flame's origin with +x towards the opponent. { key, from frame, to frame, ... }.
local function fire_tier_2(first, second, sparks, spark_x, wisps, wisps_x)
    return {
        intro = 20, loop = 28,
        { first, 0, 19, sx = { 0.1, 1.2 }, x = { 93, -16 } },
        { first, 20, 26, sx = { 0.8, 1 }, x = { 26, 5 } },
        { second, 27, 33, sx = { 0.8, 1 }, x = { 26, 5 } },
        { first, 34, 40, sx = { 0.8, 1 }, x = { 26, 5 } },
        { second, 41, 47, sx = { 0.8, 1 }, x = { 26, 5 } },
        { sparks, 0, 14, sx = { 0.05, 0.6 }, x = { spark_x, -14 } },
        { sparks, 15, 19, sx = 0.6, x = { -23, -59 }, a = { 0.8, 0 } },
        { wisps, 20, 41, sx = { 0.2, 1.5 }, x = wisps_x, y = 1, a = { 1, 0 } },
    }
end

local function small_horn(key, x, y, flip)
    return {
        start = 20, loop = 14, x = x, y = y, flip = flip,
        { key, 0, 9, s = { 1, 1.19 }, rot = { 0, -8 }, x = { -2, -26 }, y = { 0, -19 }, a = { 1, 0 }, n = 2 },
    }
end

local PLAYER_HORN = {
    loop = 15, normal = true,
    { "player_horn", 0, 9, sx = { 0.69, 0.88 }, x = { 137, 125 }, y = { -58, -69 }, a = { 0.28, 0.6 }, n = 2 },
    { "player_horn", 10, 14, sx = { 0.9, 1 }, x = { 123, 117 }, y = { -71, -77 }, a = { 0.48, 0 }, n = 2 },
}
local AI_HORN = {
    loop = 20, normal = true,
    { "ai_horn", 0, 14, sx = { 0.44, 0.85 }, x = { 151, 126 }, y = { -58, -64 }, a = { 0.28, 0.6 }, n = 2 },
    { "ai_horn", 15, 19, sx = { 0.88, 1 }, x = { 125, 118 }, y = { -67, -78 }, a = { 0.48, 0 }, n = 2 },
}

local function placed(part, fields)
    local placement = setmetatable(fields, { __index = part })
    for i, layer in ipairs(part) do placement[i] = layer end
    return placement
end

-- The opening stream of sparks and the big flame's flare are the same on both sides at the top tier.
local function fire_tier_4(large, burst, sparks, n, opening_burst)
    local part = {
        intro = 20, loop = 20,
        { burst, 20, 24, s = { 1, 1.2 }, x = { 19, -14 }, n = n },
        { burst, 30, 34, sx = { 0.8, 1.12 }, sy = { 1.2, 1.39 }, x = { 49, -3 }, a = { 1, 0.2 }, n = n },
        { large, 25, 29, s = { 1, 1.2 }, x = { 16, -16 }, n = n },
        { large, 35, 39, sx = { 0.6, 1 }, sy = 1.2, x = { 82, 16 }, n = n },
        { large, 0, 4, sx = { 0.1, 1 }, x = { 162, 27 }, n = n },
        { large, 5, 14, s = { 1.02, 1.2 }, x = { 24, -4 }, n = n },
        { large, 15, 19, sx = { 1.22, 1.29 }, sy = 1.2, x = { -7, -20 }, a = { 0.8, 0 }, n = n },
        { sparks, 0, 4, sx = { 0.1, 1 }, x = { 156, 27 } },
        { sparks, 5, 14, x = { 16, -83 } },
        { sparks, 15, 19, sx = { 1.02, 1.08 }, x = { -88, -105 }, a = { 0.8, 0 } },
    }
    if opening_burst then
        part[#part + 1] = { burst, 0, 19, x = 19, n = n }
    end
    return part
end

local function spark_flash(key)
    return {
        loop = 60,
        { key, 0, 4, sx = { 0.1, 1 }, x = { 156, 0 } },
        { key, 5, 9, s = { 1.03, 1.13 }, x = { -24, -122 } },
        { key, 10, 14, s = { 1.15, 1.2 }, x = { -134, -183 }, a = { 0.8, 0 } },
    }
end

local PLAYER_STREAK = {
    loop = 20, normal = true,
    { "player_streak", 1, 5, sx = { 0.28, 1 }, sy = { 0.47, 1 }, x = { 125, 0 }, y = { -23, 0 } },
    { "player_streak", 6, 12, sx = { 1.03, 1.2 }, x = { -15, -106 }, y = 1 },
    { "player_streak", 13, 19, sx = 1.2, x = { -112, -149 }, y = 1, a = { 0.86, 0 } },
}
local AI_STREAK = {
    loop = 20,
    { "ai_streak", 0, 5, sx = { 0.28, 1 }, sy = { 0.47, 1 }, x = { 88, -132 }, y = { -27, -8 } },
    { "ai_streak", 6, 11, sx = { 1.03, 1.17 }, x = { -138, -171 }, y = -8 },
    { "ai_streak", 12, 19, sx = 1.2, x = { -178, -193 }, y = -7, a = { 1, 0 } },
}

local PLAYER_FLAMES = {
    { x = -32, y = 101, {
        loop = 19,
        { "player_small", 0, 4, s = { 0.9, 1 }, x = { -46, -53 }, frame = 0 },
        { "player_mid_1", 5, 10, sx = { 0.54, 0.62 }, sy = { 1, 1.15 }, x = -60 },
        { "player_small", 11, 14, x = -54.5, frame = 1 },
        { "player_small_end", 15, 18 },
    } },
    { x = -134, y = 101, small_horn("player_horn_small", 67, -41),
        small_horn("player_horn_small", 67, 49, true),
        fire_tier_2("player_mid_2", "player_mid_1", "player_sparks", 96, "player_wisps", { 81, -48 }) },
    { x = -211, y = 91, placed(PLAYER_HORN, { x = -35, y = 8, s = 1.2, normal = false }),
        placed(PLAYER_HORN, { x = -43, y = 21, s = 1.2, flip = true, normal = false }), {
        intro = 20, loop = 20, x = -35, s = 1.2,
        { "player_medium_1", 20, 23, sx = { 0.6, 0.68 }, x = { 79, 67 } },
        { "player_medium_1", 24, 25, sx = { 0.7, 0.5 }, x = 63, a = { 1, 0 } },
        { "player_medium_1", 30, 33, sx = { 0.6, 0.68 }, x = { 79, 67 } },
        { "player_medium_1", 34, 35, sx = { 0.7, 0.5 }, x = 63, a = { 1, 0 } },
        { "player_medium_2", 4, 16, sx = { 1, 1.14 }, x = { 16, -4 } },
        { "player_medium_2", 17, 19, sx = { 1.16, 1.19 }, x = { -7, -13 }, a = { 0.67, 0 } },
        { "player_medium_2", 25, 29, sx = { 0.6, 0.7 }, x = { 80, 63 } },
        { "player_medium_2", 35, 39, sx = { 0.6, 0.7 }, x = { 80, 63 } },
        { "player_medium_2", 0, 16, sx = { 0.1, 1.14 }, x = { 162, -4 }, ease = true },
        { "player_medium_2", 17, 19, sx = { 1.16, 1.19 }, x = { -7, -13 }, a = { 0.67, 0 } },
        { "player_wisps_wide", 20, 29, sx = { 0.09, 1.24 }, x = { 165, -15 }, y = 10, a = { 1, 0 } },
        { "player_sparks", 0, 4, sx = { 0.1, 1 }, x = { 156, 16 } },
        { "player_sparks", 5, 16, x = { 7, -94 } },
        { "player_sparks", 17, 19, sx = { 1.02, 1.05 }, x = { -99, -107 }, a = { 0.67, 0 } },
    } },
    { x = -210, y = 91,
        placed(PLAYER_STREAK, { x = -18, y = 84 }), placed(PLAYER_STREAK, { x = -19, y = -61, flip = true }),
        placed(PLAYER_HORN, { x = -29, y = 10, s = 1.2 }),
        placed(PLAYER_HORN, { x = -29, y = 18, sx = 1.2, sy = 1.08, flip = true }),
        fire_tier_4("player_large", "player_burst", "player_sparks", 1), spark_flash("player_sparks") },
}

local AI_FLAMES = {
    { x = 41, y = 101, {
        loop = 19,
        { "ai_small", 11, 14, x = -50.5, frame = 2 },
        { "ai_small", 0, 4, s = { 0.9, 1 }, x = { -46, -53 }, frame = 0, n = 3 },
        { "ai_small", 5, 10, sx = { 0.54, 0.62 }, sy = { 1, 1.15 }, x = { -29, -37 }, frame = 1, n = 3 },
        { "ai_small_end", 15, 18, n = 3 },
    } },
    { x = -63, y = 101, small_horn("ai_horn_small", 66, -41),
        small_horn("ai_horn_small", 66, 49, true),
        fire_tier_2("ai_mid_1", "ai_mid_2", "ai_sparks", 94, "ai_wisps", { 84, 24 }) },
    { x = -138, y = 91, placed(AI_HORN, { x = -33, y = 8, s = 1.2 }),
        placed(AI_HORN, { x = -33, y = 20, s = 1.2, flip = true }), {
        intro = 20, loop = 20, x = -38, s = 1.2,
        { "ai_medium_1", 20, 23, sx = { 0.6, 0.68 }, x = { 83, 70 } },
        { "ai_medium_1", 24, 25, sx = { 0.7, 0.5 }, x = { 66, 63 }, a = { 1, 0 } },
        { "ai_medium_1", 30, 33, sx = { 0.6, 0.68 }, x = { 83, 70 } },
        { "ai_medium_1", 34, 35, sx = { 0.7, 0.5 }, x = { 66, 63 }, a = { 1, 0 } },
        { "ai_medium_2", 0, 16, sx = { 0.1, 1.14 }, x = { 162, -4 }, ease = true },
        { "ai_medium_2", 17, 19, sx = { 1.16, 1.19 }, x = { -7, -13 }, a = { 0.67, 0 } },
        { "ai_medium_2", 25, 29, sx = { 0.6, 0.7 }, x = { 82, 67 } },
        { "ai_medium_2", 35, 39, sx = { 0.6, 0.7 }, x = { 82, 67 } },
        { "player_sparks", 0, 4, sx = { 0.1, 1 }, x = { 156, 16 } },
        { "player_sparks", 5, 16, x = { 7, -94 } },
        { "player_sparks", 17, 19, sx = { 1.02, 1.05 }, x = { -99, -107 }, a = { 0.67, 0 } },
        { "ai_wisps_wide", 20, 34, sx = { 0.09, 1.24 }, x = { 169, 33 }, y = 10, a = { 1, 0 } },
    } },
    { x = -145, y = 91,
        placed(AI_STREAK, { x = 45, y = 81 }), placed(AI_STREAK, { x = 46, y = -59, flip = true }),
        placed(AI_HORN, { x = -29, y = 18, s = 1.2 }),
        placed(AI_HORN, { x = -29, y = 18, sx = 1.2, sy = 1.08, flip = true }),
        fire_tier_4("ai_large", "ai_burst", "ai_sparks", 2, true), spark_flash("ai_sparks") },
}

-- The player's section-winning shot: one flare, not a whole flame tier.
local PLAYER_SHOT = {
    { "player_large", 0, 16, sx = { 0.1, 1.3 }, x = { 145, -54 }, ease = true },
    { "player_large", 17, 19, sx = { 1.33, 1.4 }, x = { -60, -72 }, a = { 0.67, 0 } },
    { "player_sparks", 0, 4, sx = { 0.1, 1 }, x = { 139, 0 } },
    { "player_sparks", 5, 14, x = { -12, -115 } },
    { "player_sparks", 15, 19, x = { -127, -173 }, a = { 0.8, 0 } },
}

local function player_flame_tier(position)
    if position <= 3 then return 1 end
    if position <= 7 then return 2 end
    return position <= 13 and 3 or 4
end

local function ai_flame_tier(position)
    if position <= 2 then return 4 end
    if position <= 10 then return 3 end
    return position <= 14 and 2 or 1
end

local function sweep(value, p, default)
    if type(value) == "table" then return value[1] + (value[2] - value[1]) * p end
    return value or default
end

local function part_clock(part, f)
    f = f - (part.start or 0)
    if f < 0 then return nil end
    local intro = part.intro or 0
    if not part.loop or f < intro then return f end
    return intro + (f - intro) % part.loop
end

function AIBattleOverlay:draw_flame_part(part, f, origin, y, dir, alpha)
    f = part_clock(part, f)
    if not f then return end
    local px, py = part.x or 0, part.y or 0
    local psx, psy = part.sx or part.s or 1, part.sy or part.s or 1
    local ydir = part.flip and -1 or 1
    for _, l in ipairs(part) do
        if f >= l[2] and f < l[3] + 1 then
            local p = l[3] > l[2] and math.min((f - l[2]) / (l[3] - l[2]), 1) or 1
            if l.ease then p = 1 - (1 - p) * (1 - p) end
            local rot = sweep(l.rot, p, 0)
            local mirror
            if dir < 0 and part.flip then
                rot = rot + 180
            elseif dir < 0 then
                mirror, rot = "horizontal", -rot
            elseif part.flip then
                mirror, rot = "vertical", -rot
            end
            for _ = 1, l.n or 1 do
                self:spr("flame_" .. l[1], origin + dir * (px + psx * sweep(l.x, p, 0)),
                    y + py + ydir * psy * sweep(l.y, p, 0), {
                    sx = sweep(l.sx or l.s, p, 1) * psx, sy = sweep(l.sy or l.s, p, 1) * psy,
                    rot = rot, frame = l.frame, fade = sweep(l.a, p, 1) * alpha,
                    mirror = mirror, add = not part.normal,
                })
            end
        end
    end
end

function AIBattleOverlay:draw_flames(ms, border, position, dir)
    local tier = dir > 0 and player_flame_tier(position) or ai_flame_tier(position)
    local entered = self.flame_tier[dir]
    if not entered or entered.tier ~= tier then
        entered = { tier = tier, start = ms }
        self.flame_tier[dir] = entered
    end
    local spec = (dir > 0 and PLAYER_FLAMES or AI_FLAMES)[tier]
    local f = (ms - entered.start) / FRAME_MS
    for _, part in ipairs(spec) do
        self:draw_flame_part(part, f, border + dir * spec.x, spec.y, dir, 1)
    end
end

function AIBattleOverlay:border_x(territory)
    return BORDER_X[math.min(math.max(1, territory + 10), TILES - 1)]
end

function AIBattleOverlay:draw_blast(f, border, dir)
    if f < 23 or f >= 32 then return end
    local p = math.min((f - 23) / 5, 1)
    local alpha = f < 29 and 1 or 0.67 * (1 - (f - 29) / 3)
    if dir > 0 then
        local x = -41 + (border - 140 + 41) * p
        self:draw_flame_part(PLAYER_SHOT, f - 23, x, 81, 1, alpha)
    else
        local x = 1164 + (border + 110 - 1164) * p
        for _, part in ipairs(AI_FLAMES[4]) do
            self:draw_flame_part(part, f - 23, x, 101, -1, alpha)
        end
    end
end

local FLAME_Y = 100

function AIBattleOverlay:draw_impact(f, x)
    local h = f - 31
    if h < 0 or h > 60 then return end
    local p = h / 60
    self:spr("burst_lightning", x, FLAME_Y, { s = 0.8 + 0.5 * math.min(h / 11, 1), fade = 1 - math.min(h / 11, 1), add = true })
    self:spr("burst_rays", x, FLAME_Y, { s = 0.1 + 0.9 * p, rot = 120 * p, fade = 0.63 * (1 - p), add = true })
    for i = 0, 3 do
        local a = i * math.pi / 2 + 0.7
        self:spr("burst_star", x + math.cos(a) * 130 * p, FLAME_Y + math.sin(a) * 90 * p, {
            s = 1 - p, fade = 1 - p, add = true,
        })
    end
end

local SPARKS = {
    { "spark_yellow_small", -70, 53, 50, -60, 90 }, { "spark_yellow", -87, -43, -60, -133, 80 },
    { "spark_purple", -165, -85, -132, -50, 90 }, { "spark_pink_small", -66, -20, 30, 40, 80 },
    { "spark_white", -82, 103, 40, 60, 80 },
}

function AIBattleOverlay:draw_sparks(f, x, y, scale)
    for _, s in ipairs(SPARKS) do
        if f >= 0 and f <= s[6] then
            local p = f / s[6]
            self:spr(s[1], x + (s[2] + (s[4] - s[2]) * p) * scale, y + (s[3] + (s[5] - s[3]) * p) * scale, {
                s = scale * (1.2 - 0.9 * p), rot = 360 * p, fade = math.min(p * 4, 1 - p), add = true,
            })
        end
    end
end

function AIBattleOverlay:draw_rising(f)
    if f < 0 or f > 180 then return end
    local p = f / 179
    local fade = math.min(1, (1 - p) * 4)
    self:spr("rising_emblems_1", 209, 859 - 259 * p, { fade = fade, add = true })
    self:spr("rising_emblems_2", 1039, 855 - 256 * p, { fade = fade, add = true })
    self:spr("rising_emblems_1", 209, 227 - 154 * p, { fade = fade, add = true, mirror = "horizontal" })
    self:spr("rising_emblems_2", 1039, 296 - 196 * p, { fade = fade, add = true, mirror = "horizontal" })
    for _, spot in ipairs({ { 524, 625 }, { 948, 120 }, { 448, 120 } }) do
        for i = 0, 2 do
            local a = i * 2.1 + spot[1]
            self:spr("rising_triangle", spot[1] + math.cos(a) * 95 * p, spot[2] + math.sin(a) * 60 * p, {
                s = 0.75 - 0.5 * p, rot = 360 * p, fade = fade, add = true,
            })
        end
        self:spr("rising_outline", spot[1], spot[2], { s = 0.5, rot = 360 * p, fade = fade, add = true })
    end
    self:draw_sparks(f % 100, 924, 574, 0.8)
    self:draw_sparks(f % 100, 355, 574, 0.8)
end

function AIBattleOverlay:draw_clash(ms, territory, angry)
    local border = self:border_x(territory)
    local event_f = self:event_frame(ms)
    if event_f and not self.final then
        self:draw_blast(event_f, border, self.event.won and 1 or -1)
        self:draw_impact(event_f, self.event.won and 1200 or 80)
        if self.event.won then self:draw_rising(event_f) end
    elseif self.final and self.final.start and self.final.won then
        self:draw_rising((ms - self.final.start) / FRAME_MS)
    end
    if angry and not self.final then
        local f = (ms / FRAME_MS) % 20
        local x = border + 79
        self:spr("emotion_angry", x, 50, { s = 1 + 0.1 * flash(f, 20) })
        if f >= 9 then
            local h = (f - 9) / 10
            self:spr("emotion_angry_flash", x, 50, { s = 1.1 + 0.4 * h, fade = 1 - h })
        end
    end
end

function AIBattleOverlay:draw_section_result(ms)
    local event = self.event
    if not event or not event.start then return end
    local f = (ms - event.start) / FRAME_MS - 4
    if f < 0 or f > 104 then return end
    local key = event.won and "result_win" or "result_lose"
    local CX, CY = 403, 93
    if f <= 95 then
        local frame = 0
        if f >= 55 and f < 75 then frame = math.min(1 + (f - 55) // 4, 5) end
        if f < 75 then
            self:spr(key, CX, CY, { s = track(f, { { 0, 2.714 }, { 16, 1 } }), frame = math.floor(frame) })
        else
            local h = (f - 75) / 9
            self:spr(key, CX, CY)
            if h <= 1 then
                self:spr(key .. "_flash", CX, CY, { s = 1 + 2 * h, fade = 1 - h, add = true })
            end
        end
    else
        local h = (f - 96) / 8
        self:spr(key, CX - 120 * h, CY, { s = 1 - 0.7 * h, fade = 1 - h })
    end
end

function AIBattleOverlay:draw_section_pops(ms)
    local event = self.event
    if not event or not event.start or not event.won then return end
    local h = ((ms - event.start) / FRAME_MS - 104) / 12
    if h < 0 or h > 1 then return end
    local slot = (self.section_count == 3 and 2 or 0) + event.section
    local x = 190 + slot * 31
    local y = slot % 2 == 0 and 111 or 126
    self:spr("section_pop", x, y, { s = 0.8 + 0.6 * h, fade = 1 - h, add = true })
end

function AIBattleOverlay:draw_circuit(f)
    if f > 68 then return end
    local fade = f < 50 and 1 or (68 - f) / 18
    for side = 1, 2 do
        local dir = side == 1 and 1 or -1
        local mirror = side == 2 and "horizontal" or nil
        local x0 = side == 1 and 200 or 1077
        local y0 = side == 1 and 376 or 336
        self:spr("finish_circuit", x0 + dir * 94, y0, { mirror = mirror, fade = fade * 0.9 })
        for i, streak in ipairs({ { 3, 434, 200, -15 }, { 23, 411, 330, -121 }, { 35, 308, 100, -172 } }) do
            local h = (f - streak[1]) / 20
            if h >= 0 and h <= 1 then
                self:spr("finish_streak", x0 + dir * (streak[2] + (streak[3] - streak[2]) * h), y0 + dir * streak[4], {
                    sx = 2.5 * (1 - h) + 0.2, fade = fade, mirror = mirror, add = true,
                })
                self:spr("finish_dot", x0 + dir * (streak[2] + (streak[3] - streak[2]) * h), y0 + dir * streak[4], {
                    s = 1 + h, fade = fade * (1 - h), add = true,
                })
            end
            if i == 3 and f >= 46 then
                self:spr("finish_dot", x0 + dir * 12, y0 - dir * 33, {
                    s = 1 + (f - 46) / 20, fade = fade * (1 - (f - 46) / 20), add = true,
                })
            end
        end
    end
end

local function dim(alpha)
    tex.draw_rect(0, 0, 1280 * S, 720 * S, 0, 0, 0, 255 * alpha)
end

function AIBattleOverlay:draw_finish(f)
    local CX, CY = 640, 360
    dim(math.min(f / 124, 1) * 0.5)
    self:draw_circuit(f)
    local h = f - 4
    if h >= 0 and h <= 40 then
        local p = h / 40
        self:spr("finish_ring_flash", CX, CY, { s = 0.1 + 1.9 * p, rot = 270 * p, fade = 1 - p * p })
    end
    if h >= 0 and h <= 8 then
        self:spr("finish_disc", CX, CY, { s = 0.5 + 1.136 * h / 8, fade = 1 - h / 8 })
    end
    if f <= 12 then
        self:spr("finish_dot", CX, CY, { s = 1 + 10 * f / 12, fade = 1 - f / 12 })
    end
    local g = f - 27 -- ring, disc and logo arrive
    if g < 0 then return end
    local glow_phase = (f % 400) / 400
    self:spr("finish_glow", CX, CY, {
        s = 1 + 0.2 * flash(f, 120), fade = math.min(g / 60, 1) * track(f % 400, { { 0, 0 }, { 75, 0.2 }, { 120, 0 }, { 400, 0 } }),
    })
    local settle = math.min(g / 96, 1)
    self:spr("finish_ring_dashed", CX, CY, {
        s = 0.1 + 0.9 * math.min(g / 40, 1), rot = (f < 125 and -90 * (1 - settle) or 360 * glow_phase),
    })
    if f >= 37 then
        self:spr("finish_ring", CX, CY, {
            s = track(f - 37, { { 0, 0.4 }, { 40, 1 } }), rot = (f < 125 and 80 * (1 - settle) or -360 * glow_phase),
        })
    end
    if g <= 20 then
        self:spr("finish_disc", CX, CY, { s = track(g, { { 0, 0.7 }, { 12, 1.152 }, { 20, 0.85 } }) })
    elseif f <= 41 + 27 then
        self:spr("finish_disc", CX, CY, { s = 0.85 + 0.95 * (g - 20) / 21, fade = 1 - (g - 20) / 21 })
    end
    local pulse = f < 125 and 1 or 1 - 0.05 * flash(f, 60)
    self:spr("finish_logo", CX, CY - 2, {
        s = track(f - 27, { { 0, 0.8 }, { 14, 1.2 }, { 30, 1 } }) * pulse, fade = math.min(g / 14, 1),
    })
end

function AIBattleOverlay:draw_win(f)
    local LAUREL_X, LAUREL_Y = 634, 351
    local BATTLE_X, BATTLE_Y = 628, 264
    local TEXT_X, TEXT_Y = 631, 430
    local grow = track(f, { { 0, 3 }, { 20, 1 } })
    self:spr("win_laurel", LAUREL_X, LAUREL_Y, { s = grow, fade = math.min(f / 20, 1) })
    local flash_f = (f - 42)
    if flash_f >= 0 and flash_f <= 40 then
        self:spr("win_laurel_flash", LAUREL_X, LAUREL_Y, { s = 1 + flash_f / 40, fade = 1 - flash_f / 40, add = true })
    elseif f > 149 and (f - 149) % 128 >= 64 then
        self:spr("win_laurel_flash", LAUREL_X, LAUREL_Y, { fade = blink(((f - 149) % 128) - 64, 64), add = true })
    end
    local ray = f - 40
    if ray >= 0 and ray <= 90 then
        local p = ray / 90
        self:spr("fc_rays", LAUREL_X, LAUREL_Y + 76, { rot = -90 * p, fade = 0.63 * (1 - p), add = true })
        self:spr("fc_rays", LAUREL_X, LAUREL_Y + 76, { rot = 90 * p, fade = 0.63 * (1 - p), add = true })
    end
    if f >= 20 then
        self:spr("win_text", TEXT_X, TEXT_Y, { s = track(f, { { 20, 3 }, { 40, 1 } }), fade = math.min((f - 20) / 20, 1) })
        self:spr("win_battle_text", BATTLE_X, BATTLE_Y, { fade = math.min((f - 20) / 5, 1) })
    end
    if f >= 60 then
        self:spr("win_shadow", TEXT_X + 1, TEXT_Y, { fade = track(f, { { 60, 0.8 }, { 72, 0 } }) })
    end
    for i, b in ipairs({ { 343, -175 }, { 444, 159 }, { 66, 507 }, { -571, -163 }, { -778, 150 }, { -493, 488 } }) do
        self:draw_sparks(f - 42 - (i % 3) * 5, 803 + b[1], 270 + b[2], 0.87)
    end
    if f >= 73 then
        for i, star in ipairs({ { 638, 346 }, { 963, 400 }, { 613, 330 }, { 650, 250 } }) do
            local a = ((f - 73 + i * 14) % 75) / 40
            if a <= 1 then
                self:spr("win_star", star[1], star[2], {
                    s = track(a, { { 0, 0.6 }, { 1, 1.3 } }), fade = blink(a, 1), add = true,
                })
            end
        end
    end
end

function AIBattleOverlay:draw_full_combo(f)
    local CX, CY = 640, 360
    local loop = f <= 250 and f or 130 + (f - 130) % 120
    self:spr("fc_glow", CX, CY - 20, { fade = track(loop, { { 0, 0 }, { 129, 0.99 }, { 130, 0.99 } }), add = true })
    if loop >= 40 then
        local p = math.min((loop - 40) / 90, 1)
        self:spr("fc_rays", CX, CY, { rot = -180 * p, fade = 0.63 * (1 - p), add = true })
        self:spr("fc_rays", CX, CY, { rot = 180 * p, fade = 0.63 * (1 - p), add = true })
    end
    if f >= 22 then
        local h = math.min((f - 22) / 48, 1)
        self:spr("fc_emblem", CX, CY, { s = 0.1 + 1.1 * h, fade = 1 - h })
    end
    local text_scale = track(f, { { 0, 3 }, { 40, 1 } })
    self:spr("fc_text", 636, 348, { s = text_scale, fade = math.min(f / 40, 1) })
    if f >= 40 and f <= 70 then
        local h = (f - 40) / 30
        self:spr("fc_text_flash", 636, 348, { s = 1 + 2 * h, fade = 1 - h, add = true })
    end
    if loop >= 130 and loop <= 199 then
        self:spr("fc_text_flash", 636, 348, { fade = 0.5 * blink(loop - 130, 69), add = true })
    end
    for i, b in ipairs({ { 1175, 73 }, { 1276, 407 }, { 898, 755 }, { 261, 85 }, { 54, 398 }, { 339, 736 } }) do
        self:draw_sparks(loop - 42 - (i % 3) * 5, b[1], b[2], 0.87)
    end
    if loop >= 40 then
        for i, star in ipairs({ { 440, 294 }, { 941, 384 }, { 604, 406 }, { 780, 284 } }) do
            local a = ((loop - 40 + i * 14) % 69) / 40
            if a <= 1 then self:spr("win_star", star[1], star[2], { s = 0.6 + 0.7 * a, fade = blink(a, 1), add = true }) end
        end
    end
end

function AIBattleOverlay:draw_finale(ms)
    self:draw_section_result(ms)
    self:draw_section_pops(ms)
    local final = self.final
    if not final or not final.start then return end
    local f = (ms - final.start) / FRAME_MS
    local start_length = final.won and 149 or 125
    self:cue(final.won and "se_win_laurel" or "se_lose_beam", "sound", f)
    self:cue(final.won and "vo_last_win" or "vo_last_lose", "voice", f)
    self:cue(final.won and "se_win_logo" or "se_lose_logo", "sound", f, final.won and 25 or 4)
    if final.full_combo then
        self:cue("se_full_combo_logo", "sound", f, start_length + 22)
        self:cue("se_full_combo_spark", "sound", f, start_length + 40)
    end
    if final.full_combo and f >= start_length then
        self:draw_full_combo(f - start_length)
    elseif final.won then
        self:draw_win(f)
    else
        self:draw_finish(f)
    end
end

-- Z-DON (Green): the AI lane's "AIどん" plate (ai_player_name at Z-DON's measured -64,368; the engine leaves out the
-- lane's own plate / auto marker, Player::use_upai_lane) and the genre pill under the bottom-right title (ai_song_info
-- 4..18 at 1154,693; tex.upai_song: the engine moves the title / counter there and leaves the pill to the skin).
-- Drawn with the AI's board, after the lanes
local AI_PLATE_X, AI_PLATE_Y = -64, 368
local GENRE_PILL_X, GENRE_PILL_Y = 1154, 693

function AIBattleOverlay:draw_stage_extras()
    if not tex.upai_song then return end
    local genre, title_alpha = tex.upai_song()
    if genre == nil then return end
    self:zat("ai_plate", AI_PLATE_X, AI_PLATE_Y)
    if genre >= 0 and genre <= 7 and (title_alpha or 0) > 0 then
        local info = self:zinfo("genre_pill")
        tex.draw_texture(self:id(DIR .. "genre_pill"), {
            x = (GENRE_PILL_X - info.width / 2) * S, y = (GENRE_PILL_Y - info.height / 2) * S, frame = genre,
            fade = title_alpha,
        })
    end
end

function AIBattleOverlay:draw_scoreboard(is_ai, good, ok, bad, drumroll)
    if is_ai then self:draw_stage_extras() end
    tex.draw_texture(self:id(DIR .. (is_ai and "scoreboard_ai" or "scoreboard")))
    local digit = self:id(DIR .. "scoreboard_num")
    local margin = 8
    for row, counter in ipairs({ good, ok, bad, drumroll }) do
        local digits = tostring(counter)
        local width = #digits * margin
        for i = 1, #digits do
            tex.draw_texture(digit, {
                frame = tonumber(digits:sub(i, i)),
                x = -(width // 2) + (i - 1) * margin,
                index = (row - 1) + (is_ai and 4 or 0),
            })
        end
    end
end

AIGauge = setmetatable({}, { __index = Gauge })
AIGauge.__index = AIGauge

function AIGauge.new(is_2p, dan, string_diff)
    local opts = { folder = "gauge_ai", scale = GAUGE_SCALE, footer = true, no_border = true }
    return setmetatable(Gauge.new(is_2p, dan, string_diff, opts), AIGauge)
end

function AIGauge:blit(t, mirror, x, y, ...)
    return Gauge.blit(self, t, mirror, (x or 0) + GAUGE_X / GAUGE_SCALE, y + GAUGE_Y, ...)
end

function AIGauge:draw(_, ...)
    return Gauge.draw(self, 0, ...)
end
