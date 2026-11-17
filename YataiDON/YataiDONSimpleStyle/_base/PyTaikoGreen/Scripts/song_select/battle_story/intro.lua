local Intro = {}
Intro.__index = Intro

local S = tex.get_screen_scale()
local WHITE = { 255, 255, 255, 255 }
local BLACK = { 0, 0, 0, 255 }
local INK = { 32, 32, 32, 255 }
local LEFT, RIGHT, DECIDE = 1, 2, 3

local INPUT_WAIT = 30
local EXPLAIN_AT = 6
-- the story waits at each line for N * READ_FRAMES (Lumen loops 10 frames, `bai` times per N)
local READ_FRAMES = 20
local STORY_END, WORLD_AT = 370, 329
-- story lines stay clear of the art at the sides
local STORY_WIDTH = 700
local THEMES = {
    blue = { title = { 30, 140, 230, 255 }, dot = { 79, 172, 255, 255 }, tab_right = 452 },
    pink = { title = { 170, 60, 200, 255 }, dot = { 200, 90, 220, 255 }, tab_right = 535 },
}
-- scenes without a story open on the world with twinkles: { fades in first, scale, x, y }
local LEAD_END, TWINKLE_AT, TWINKLE_X, TWINKLE_Y = 142, 36, 642.4, 360.2
local TWINKLES = {
    { true, 1, 217.65, 67.95 }, { true, 0.727, -185, 188.4 }, { true, 0.455, -176.6, 37.9 },
    { true, 0.424, -17.9, 32.75 }, { true, 0.606, -221.15, -74.25 }, { true, 0.424, -185.9, -277.25 },
    { true, 0.424, 421.1, -295.25 }, { false, 0.333, 444.2, -277.75 }, { true, 0.303, 546.85, -309.95 },
    { false, 0.342, 609.25, -197.7 }, { true, 0.303, 104.9, -270.95 }, { true, 0.152, -210.55, -321.8 },
    { false, 0.364, -300.5, -301.6 }, { true, 0.364, -372.45, -298.6 }, { false, 0.303, -424.05, -268.95 },
    { true, 0.242, -592.6, -242.3 }, { false, 0.727, -603.95, -208.55 }, { true, 0.273, -569.3, 66.85 },
    { false, 0.183, -337.2, 137.35 }, { false, 1, -201.35, 61.95 }, { false, 0.636, 190.15, 190.9 },
    { false, 0.364, 187.5, 32.4 }, { false, 0.364, -137.5, 228.35 }, { false, 0.364, -195.5, -103.6 },
    { false, 0.424, -109.9, -290.25 },
}
local DOT_STEP, DOT_Y, DOT_SIZE = 25, 608, 13
local TAB_LIGHT = { 0, 90, 180, 255 }
local DOT_OFF = { 183, 194, 208, 255 }
local PILL_Y, PILL_H = 641, 36
local ARROW_X, ARROW_Y = 96, 370
-- { texture, motion, scale, x, y } around the card's sparkle origin
local SPARKLES = {
    { "rules_sparkle_purple", "fade", 0.465, -415.95, 132 }, { "rules_sparkle_purple", "fade", 0.756, 343.6, -145.5 },
    { "rules_sparkle_teal", nil, 1, 416.35, 57.35 }, { "rules_sparkle_teal", nil, 0.581, 286.35, -121.6 },
    { "rules_sparkle_teal", nil, 0.605, -416.6, -77.65 }, { "rules_sparkle_teal", nil, 1, -359.6, 97.35 },
    { "rules_sparkle_blue", "glow", 0.721, 395, -104.05 }, { "rules_sparkle_blue", "glow", 1, -323.95, -124.95 },
    { "rules_sparkle_blue", "glow", 0.651, 361, 112.9 }, { "rules_sparkle_blue", "glow", 0.465, -437, 34 },
}

local function clamp01(v) return math.max(0, math.min(1, v)) end
local function lerp(a, b, u) return a + (b - a) * clamp01(u) end

local function fitted(story, str, size, color, outline, thickness, width)
    local t
    repeat
        t = story.text(str, size, color, outline, thickness)
        size = size - 1
    until t.width <= width * S or size < 12
    return t
end

local function rows_of(story, str, size, color, outline, thickness)
    local rows = {}
    for row in (str .. "\n"):gmatch("(.-)\n") do
        rows[#rows + 1] = story.text(row, size, color, outline, thickness)
    end
    return rows
end

local function draw_rows(rows, cx, cy, gap, fade)
    local top = cy * S - (#rows - 1) * gap * S / 2
    for i, r in ipairs(rows) do
        r:draw({ x = cx * S - r.width / 2, y = top + (i - 1) * gap * S - r.height / 2, fade = fade })
    end
end

function Intro:story_frame(f)
    if self.skip_at then return WORLD_AT + f - self.skip_at end
    local l = f
    for _, h in ipairs(self.holds) do
        if l <= h[1] then return l end
        if l <= h[1] + h[2] then return h[1] end
        l = l - h[2]
    end
    return l
end

function Intro.new(story, scene)
    local self = setmetatable({}, Intro)
    self.story, self.scene = story, scene
    local s = scene.story
    if s then
        self.holds = {}
        for _, h in ipairs(s.holds) do self.holds[#self.holds + 1] = { h[1], h[2] * READ_FRAMES } end
        self.lines = {}
        for i, line in ipairs(s.lines) do
            local str = story.pick(line.text)
            self.lines[i] = fitted(story, str, line.size or 38, WHITE, { 20, 20, 40, 255 }, 5, STORY_WIDTH)
        end
    end
    self.pages = {}
    for i, page in ipairs(scene.pages or {}) do self.pages[i] = self:make_page(page) end
    self.hint_page = story.text(tex.skin_text("battle_story_page"), 20, WHITE)
    self.hint_end = story.text(tex.skin_text("battle_story_end"), 20, WHITE)
    self.page = 0
    self.page_at = 0
    self.ended = false
    story:music(scene.bgm or "main")
    return self
end

function Intro:make_page(page)
    local st = self.story
    local theme = THEMES[page.theme or "blue"]
    local p = { def = page, theme = theme, texts = {} }
    if page.title then
        p.title = rows_of(st, st.pick(page.title), 64, theme.title, WHITE, 6)
    end
    if page.tab_span then
        local span = page.tab_span
        p.tab = fitted(st, st.pick(page.tab), 24, WHITE, TAB_LIGHT, 4, span[2] - span[1])
    elseif page.tab then
        p.tab = fitted(st, st.pick(page.tab), 22, theme.title, WHITE, 3, theme.tab_right - 160)
    end
    if page.header then p.header = fitted(st, st.pick(page.header), 42, WHITE, BLACK, 5, 1000) end
    for i, item in ipairs(page.items or {}) do
        if item.text then
            local light = item.style == "light"
            local color, outline = light and WHITE or (item.color or INK), light and BLACK or (item.outline or INK)
            local thickness = light and 3 or (item.thickness or 1)
            if item.width then
                p.texts[i] = { fitted(st, st.pick(item.text), item.size or 24, color, outline, thickness, item.width) }
            else
                p.texts[i] = rows_of(st, st.pick(item.text), item.size or 24, color, outline, thickness)
            end
        end
    end
    return p
end

function Intro:update(f)
    if not self.explained and f >= EXPLAIN_AT then
        self.explained = true
        self.story.sound("vo_explain", "voice")
    end
    local page = self.pages[self.page]
    local cue = page and page.def.sound
    if cue and not page.sounded and f - self.page_at >= cue[1] then
        page.sounded = true
        self.story.sound(cue[2])
    end
    if self.page ~= 0 then return end
    if self.holds and self:story_frame(f) >= STORY_END or not self.holds and f >= LEAD_END then self:turn(1, f) end
end

function Intro:turn(n, f)
    self.page, self.page_at = n, f
end

function Intro:input(action, f)
    if f - self.page_at < INPUT_WAIT then return end
    if self.page == 0 then
        if not self.holds then
            self:turn(1, f)
        elseif not self.skip_at and self:story_frame(f) < WORLD_AT then
            self.skip_at = f
        end
        return
    end
    local last = self.page == #self.pages
    if action == DECIDE and last then
        self.ended = true
        audio.play_sound("don", "sound")
    elseif action == LEFT and self.page > 1 then
        self:turn(self.page - 1, f)
        audio.play_sound("ka", "sound")
    elseif action == RIGHT and not last then
        self:turn(self.page + 1, f)
        audio.play_sound("ka", "sound")
    end
end

function Intro:done()
    return self.ended
end

function Intro:draw_story(f)
    local st, s = self.story, self.scene.story
    local l = self:story_frame(f)
    st:put("prologue_frame", 0, 0)
    for i, line in ipairs(s.lines) do
        local fade = clamp01((l - line.at) / 30)
        if fade > 0 then draw_rows({ self.lines[i] }, line.x or 640, line.y, 0, fade) end
    end
    for _, pic in ipairs(s.pics) do
        local fade = clamp01((l - pic.at) / 28)
        if fade > 0 then st:put(pic.key, 0, 0, { fade = fade }) end
    end
    if l >= WORLD_AT then
        local u = (l - WORLD_AT) / (STORY_END - WORLD_AT)
        st:put("prologue_world", 0, lerp(10, 0, u), { fade = clamp01(u) })
    end
end

function Intro:draw_lead(f)
    self.story:put("prologue_world", 0, 0)
    if f < TWINKLE_AT then return end
    for _, t in ipairs(TWINKLES) do
        local c = (f - TWINKLE_AT) % 120
        local fade = c <= 60 and c / 60 or 1 - (c - 61) / 58
        if not t[1] then fade = 1 - fade end
        self.story:put("twinkle", TWINKLE_X + t[3], TWINKLE_Y + t[4], { at = true, s = t[2], fade = fade })
    end
end

function Intro:draw_sparkles(origin, f)
    local st = self.story
    for _, s in ipairs(SPARKLES) do
        local c = f % 100
        local fade = 1
        if s[2] == "fade" then
            fade = c <= 50 and 1 - c / 50 or lerp(0.02, 1, (c - 51) / 48)
        elseif s[2] == "glow" then
            fade = c <= 50 and lerp(0.4, 1, c / 50) or lerp(0.99, 0.4, (c - 51) / 48)
        end
        st:put(s[1], origin[1] + s[4], origin[2] + s[5], { at = true, s = s[3], fade = fade })
    end
end

-- page frame: plays once, then repeats loop = { from, to }
local function page_frame(def, f)
    local loop = def.loop
    if not loop or f <= loop[2] then return f end
    return loop[1] + (f - loop[1]) % (loop[2] - loop[1] + 1)
end

function Intro:draw_page(f)
    local st = self.story
    local page = self.pages[self.page]
    local def, theme = page.def, page.theme
    local pf = page_frame(def, f - self.page_at)
    st:put("prologue_world", 0, 0)
    st:put(def.panel, 0, 0)
    if page.title then draw_rows(page.title, 640, def.title_y or 365, 78) end
    if def.sparkles then self:draw_sparkles(def.sparkles, f - self.page_at) end
    if page.tab then
        local span = def.tab_span or { 136, theme.tab_right, 89 }
        local t = page.tab
        t:draw({ x = (span[1] + span[2]) / 2 * S - t.width / 2, y = span[3] * S - t.height / 2 })
    end
    if page.header then
        local h = page.header
        h:draw({ x = 640 * S - h.width / 2, y = 167 * S - h.height / 2 })
    end
    for i, item in ipairs(def.items or {}) do
        local shown = pf >= item.at and (not item.to or pf <= item.to)
        if shown then
            local fade = item.fade and clamp01((pf - item.at) / item.fade) or 1
            if item.dim then fade = lerp(1, item.dim, (pf - item.at) / item.fade) end
            if item.wave then fade = 0.7 + 0.3 * math.cos((pf / 60 + item.wave) * 2 * math.pi) end
            if item.pop then
                self:draw_pop(f - self.page_at - item.at)
            elseif item.key then
                local dx = item.slide and lerp(item.slide, 0, (pf - item.at) / item.fade) or 0
                st:put(item.key, (item.dx or 0) + dx, 0, { fade = fade, s = item.scale })
            end
            if page.texts[i] then self:draw_text(item, page.texts[i], fade) end
        end
    end
    self:draw_dots(theme)
    self:draw_hint()
    self:draw_arrows(f)
end

-- icon = { key, scale }: drawn left of the text, the pair centred on x
function Intro:draw_text(item, rows, fade)
    local x = item.x
    if item.icon then
        local w = self.story:size("battle_story", item.icon[1]) * item.icon[2]
        local left = x - (w + 8 + rows[1].width / S) / 2
        self.story:put(item.icon[1], left + w / 2, item.y, { at = true, s = item.icon[2], fade = fade })
        x = left + w + 8 + rows[1].width / S / 2
    end
    draw_rows(rows, x, item.y, item.gap or 30, fade)
end

-- the treasure chest on the magic stone panel: jumps, opens and gives a stone (+1); t = frames since it appeared
function Intro:draw_pop(t)
    local st = self.story
    if t < 41 then
        local dy, s = 0, 1
        if t > 34 then
            dy, s = lerp(-17.65, 2.35, (t - 35) / 5), lerp(1.034, 0.977, (t - 35) / 5)
        elseif t > 20 then
            dy, s = lerp(-1.2, -21.65, (t - 21) / 13), lerp(1.003, 1.045, (t - 21) / 13)
        end
        st:put("stones_pop_chest", 0, dy, { s = s })
        return
    end
    local glow = t <= 113 and lerp(1, 0.578, (t - 41) / 72) or t <= 165 and lerp(0.586, 1, (t - 114) / 51)
        or lerp(0.992, 0.578, (t - 166) / 56)
    st:put("stones_pop_glow", 0, 0, { fade = glow })
    st:put("stones_pop_open", 0, 0)
    if t >= 46 then
        local y = t <= 78 and lerp(8, -8, (t - 46) / 32) or t <= 170 and -8 - 6 * (1 - (1 - (t - 79) / 91) ^ 2)
            or lerp(-14, -11, (t - 171) / 51)
        st:put("stones_pop_plus", 0, y, { fade = clamp01((t - 46) / 32) })
    end
end

function Intro:draw_dots(theme)
    for i = 1, #self.pages do
        local c = i == self.page and theme.dot or DOT_OFF
        local x = 640 + DOT_STEP * (i - (#self.pages + 1) / 2) - DOT_SIZE / 2
        tex.draw_rounded_rect(x * S, (DOT_Y - DOT_SIZE / 2) * S, DOT_SIZE * S, DOT_SIZE * S, 1, c, 0, c)
    end
end

function Intro:draw_hint()
    local last = self.page == #self.pages
    local icon, gap = 40, 8
    local parts = { { "hint_rim", self.hint_page } }
    if last then parts[2] = { "hint_face", self.hint_end } end
    local w = 0
    for _, p in ipairs(parts) do w = w + (icon + gap) * S + p[2].width + 16 * S end
    w = w + 8 * S
    local x = 640 * S - w / 2
    tex.draw_rounded_rect(x, (PILL_Y - PILL_H / 2) * S, w, PILL_H * S, 1, BLACK, 0, BLACK)
    x = x + 10 * S
    for _, p in ipairs(parts) do
        self.story:put(p[1], x / S + icon / 2, PILL_Y, { at = true, s = icon / 55 })
        x = x + (icon + gap) * S
        p[2]:draw({ x = x, y = PILL_Y * S - p[2].height / 2 })
        x = x + p[2].width + 16 * S
    end
end

function Intro:draw_arrows(f)
    local c = f % 60
    local dx, fade = -29.65 * c / 29, 1
    if c >= 30 then dx, fade = -30 - 10 * (c - 30) / 29, 0.965 * (1 - (c - 30) / 29) end
    if self.page > 1 then self.story:put("page_arrow", ARROW_X + dx, ARROW_Y, { at = true, fade = fade }) end
    if self.page < #self.pages then
        self.story:put("page_arrow", 1280 - ARROW_X - dx, ARROW_Y, { at = true, fade = fade, mirror = true })
    end
end

function Intro:draw(f)
    if self.page == 0 then
        if self.holds then self:draw_story(f) else self:draw_lead(f) end
    else
        self:draw_page(f)
    end
end

return Intro
