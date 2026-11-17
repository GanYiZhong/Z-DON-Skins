local Reward = {}
Reward.__index = Reward

local S = tex.get_screen_scale()
local WHITE = { 255, 255, 255, 255 }
local BLACK = { 0, 0, 0, 255 }
local DECIDE = 3
local HEADLINE = { ja = { "新しい", "ごほうびを", "ゲット!" }, en = { "New", "reward", "unlocked!" } }
local HEADLINE_FILL, HEADLINE_LINE = { 255, 205, 30, 255 }, { 60, 25, 0, 255 }
local KINDS = { song = { ja = "楽曲", en = "Song" }, costume = { ja = "きぐるみ", en = "Costume" },
    title = { ja = "称号", en = "Title" } }
local NAME_FILL = { 255, 255, 99, 255 }
local CARD_LINE = { 40, 30, 30, 255 }
-- the beam effects loop over these frames once they have played through
local LOOP_AT, LOOP_LEN = 70, 150
local PANEL_AT = 34
-- the player can finish from here
local REWARD_HOLD, CARD_HOLD = 184, 50
local BEAM_X, BEAM_Y = 757, 347
local PANEL_X, PANEL_Y = 638, 366
-- light streaks crossing the band each loop: from, to, brightest at, y, x from, x to, x-scale from, to, y-scale
local STREAKS = {
    { 118, 146, 132, 202, 93, 1960, 0.23, 1.37, 0.47 },
    { 145, 197, 171, 514, 221, 2022, 0.52, 1.64, 0.46 },
    { 185, 215, 200, 231, -255, 1754, 0.52, 1.27, 0.15 },
}
-- sparkles around the panel: start frame in its 140-frame cycle, scale, offset from the panel group
local SPARKLES = {
    { 0, 0.6, 285.85, -10.8 }, { 9, 1.2, -211.1, 112.85 }, { 29, 1.145, 246.5, 99.95 }, { 60, 1, -227.3, -20.35 },
    { 46, 1, 205.65, 89.75 }, { 19, 0.9, -137.45, 11.6 }, { 46, 1, 213.65, -138.25 }, { 19, 1.145, -244.2, -121.85 },
    { 60, 0.6, 337.65, 41.55 }, { 46, 1, 79.65, -35.35 }, { 19, 1.145, -79.15, -30.3 }, { 46, 1, 354.65, -93.25 },
    { 19, 1.145, -383.85, -2.75 },
}
-- bond max twinkles: scale, offset from (642, 360), second phase
local TWINKLES = {
    { 0.727, -185, 188.4 }, { 0.455, -176.6, 37.9 }, { 0.424, -17.9, 32.75 }, { 0.606, -221.15, -74.25 },
    { 0.424, -185.9, -277.25 }, { 0.424, 421.1, -295.25 }, { 0.333, 444.2, -277.75, true },
    { 0.303, 546.85, -309.95 }, { 0.342, 609.25, -197.7, true }, { 0.303, 104.9, -270.95 },
    { 0.152, -210.55, -321.8 }, { 0.364, -300.5, -301.6, true }, { 0.364, -372.45, -298.6 },
    { 0.303, -424.05, -268.95, true }, { 0.242, -592.6, -242.3 }, { 0.727, -603.95, -208.55, true },
    { 0.273, -569.3, 66.85 }, { 0.183, -337.2, 137.35, true }, { 0.364, -137.5, 228.35, true },
    { 0.364, -195.5, -103.6, true }, { 0.424, -109.9, -290.25, true },
}

local function clamp01(v) return math.max(0, math.min(1, v)) end
local function lerp(a, b, u) return a + (b - a) * clamp01(u) end
-- 0 -> 1 -> 0 over `period` frames
local function tri(f, period) local u = f % period / period return 1 - math.abs(2 * u - 1) end

local function rows(story, str, size, fill, line, thickness, width)
    local out = {}
    for row in (str .. "\n"):gmatch("(.-)\n") do
        local s, t = size
        repeat
            t = story.text(row, s, fill, line, thickness)
            s = s - 2
        until t.width <= width * S or s < 20
        out[#out + 1] = t
    end
    return out
end

local function draw_centred(t, x, y, fade)
    t:draw({ x = x * S - t.width / 2, y = y * S - t.height / 2, fade = fade })
end

function Reward.new(story, scene)
    local self = setmetatable({}, Reward)
    self.story, self.scene = story, scene
    local pick = story.pick
    if scene.message then
        self.lines = rows(story, pick(scene.message), 46, WHITE, CARD_LINE, 5, 640)
        self.hold, self.sounds = CARD_HOLD, { { 0, "vo_bond_max" } }
    else
        self.words = {}
        for i, w in ipairs(pick(HEADLINE)) do
            self.words[i] = story.text(w, 54, HEADLINE_FILL, HEADLINE_LINE, 5)
        end
        self.kind = story.text(pick(KINDS[scene.reward]), 28, WHITE, BLACK, 3)
        self.name = rows(story, pick(scene.name), 34, NAME_FILL, BLACK, 4, 330)[1]
        self.hold, self.sounds = REWARD_HOLD, { { 0, "se_reward_beam" }, { 20, "se_reward_flash" } }
    end
    self.hint = story.text(tex.skin_text("battle_story_end"), 20, WHITE)
    self.ended, self.sounded = false, 0
    story:music(scene.bgm or "main")
    return self
end

function Reward:update(f)
    for i = self.sounded + 1, #self.sounds do
        if f < self.sounds[i][1] then break end
        self.story.sound(self.sounds[i][2])
        self.sounded = i
    end
end

function Reward:input(action, f)
    if action == DECIDE and f >= self.hold then
        self.ended = true
        audio.play_sound("don", "sound")
    end
end

function Reward:done()
    return self.ended
end

-- the purple band slides in, a white beam flips in and bursts into a flash, then a glow pulses with streaks
function Reward:draw_beam(f)
    local st = self.story
    local lf = f < LOOP_AT + LOOP_LEN and f or LOOP_AT + (f - LOOP_AT) % LOOP_LEN
    local u = f / 6
    local band = { at = true, sx = lerp(1.193, 10, u) * 1.632, sy = 3.01, fade = clamp01(u) }
    st:put("reward_band", BEAM_X + lerp(-1439, 0, u), BEAM_Y, band)
    band.fade = band.fade * (lf < LOOP_AT and lerp(1, 0.6, (lf - 21) / 49) or lerp(0.6, 1, tri(lf - LOOP_AT, LOOP_LEN)))
    st:put("reward_band", BEAM_X + lerp(-1439, 0, u), BEAM_Y, band)
    if f <= 38 then
        local x, sx, sy, fade = 0, 1, 0.23, 0.9
        if f <= 9 then
            x, sx, sy, fade = lerp(-1432, 0, f / 9), lerp(0.13, 1, f / 9), lerp(3.3, 0.23, f / 9), f / 10
        elseif f >= 20 then
            local v = clamp01((f - 20) / 10)
            sy = f <= 30 and lerp(0.77, 19, v * v) or lerp(19.9, 26.3, (f - 31) / 7)
            fade = f <= 30 and 1 or lerp(0.89, 0.11, (f - 31) / 7)
        end
        st:put("reward_beam", BEAM_X + x, BEAM_Y + 9, { at = true, sx = sx * 1.632, sy = sy, fade = fade, add = f >= 20 })
    end
    if lf >= LOOP_AT then
        local g = 1 - tri(lf - LOOP_AT, LOOP_LEN)
        st:put("reward_glow", BEAM_X, BEAM_Y - lerp(4.6, 13.9, g),
            { at = true, sx = 25, sy = (0.15 + 1.35 * g) * 4.634, fade = 0.8 * g })
    end
    if f >= LOOP_AT then
        for _, s in ipairs(STREAKS) do
            if lf >= s[1] and lf <= s[2] then
                local v = (lf - s[1]) / (s[2] - s[1])
                local fade = lf <= s[3] and (lf - s[1]) / (s[3] - s[1]) or 1 - (lf - s[3]) / (s[2] - s[3])
                st:put("reward_streak", lerp(s[5], s[6], v), s[4], { at = true, sx = lerp(s[7], s[8], v), sy = s[9],
                    fade = fade })
            end
        end
    end
end

function Reward:draw_panel(f)
    local st = self.story
    local pf = f - PANEL_AT
    local fade = clamp01(pf / 7)
    local breath = tri(pf, 140)
    st:put("reward_shadow", PANEL_X + 11, PANEL_Y + 1,
        { at = true, sx = 1.293 + 0.546 * breath, sy = 1 + 0.278 * breath, fade = fade })
    st:put("reward_panel", PANEL_X, PANEL_Y + 37, { at = true, fade = fade })
    draw_centred(self.kind, PANEL_X, PANEL_Y - 12, fade)
    draw_centred(self.name, PANEL_X, PANEL_Y + 47, fade)
    local cycle = pf % 140
    for _, s in ipairs(SPARKLES) do
        local v = cycle - s[1]
        if v >= 0 and v < 80 then
            local k = 1 - math.abs(v - 39) / 40
            st:put("reward_sparkle", PANEL_X + s[3], PANEL_Y + s[4],
                { at = true, s = s[2] * lerp(0.435, 1.196, k), fade = fade * k })
        end
    end
    -- the three words hop in turn
    local gap, w = 8 * S, 0
    for _, t in ipairs(self.words) do w = w + t.width end
    w = w + gap * (#self.words - 1)
    local x, hop = 646 * S - w / 2, pf % 130
    for i, t in ipairs(self.words) do
        local at = ({ 0, 22, 40 })[i]
        local dy = (hop >= at and hop <= at + 20) and -7.5 * tri(hop - at, 21) or 0
        t:draw({ x = x, y = (292 + dy) * S - t.height / 2, fade = fade })
        x = x + t.width + gap
    end
end

function Reward:draw_card(f)
    local st = self.story
    st:put("ending_art", 0, 0)
    local fade = clamp01((f - 36) / 14)
    if f < 36 then return end
    st:put("bond_max_panel", 640, 491, { at = true, fade = fade })
    for i, t in ipairs(self.lines) do
        draw_centred(t, 640, 491 + (i - (#self.lines + 1) / 2) * 62, fade)
    end
    for _, t in ipairs(TWINKLES) do
        local k = tri(f - 36, 120)
        st:put("twinkle", 642 + t[2], 360 + t[3], { at = true, s = t[1], fade = t[4] and 1 - k or k })
    end
end

function Reward:draw(f)
    local sc, st = self.scene, self.story
    if sc.message then
        self:draw_card(f)
    else
        st:backdrop(sc.backdrop)
        if sc.tint ~= false then st:put("reward_tint", 639, 360, { at = true, sx = 160.75 }) end
        self:draw_beam(f)
        if f >= PANEL_AT then self:draw_panel(f) end
    end
    if f >= self.hold then st:draw_hint(self.hint) end
end

return Reward
