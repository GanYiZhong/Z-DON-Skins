EntryInfo = {}
EntryInfo.__index = EntryInfo

local S = tex.get_screen_scale()
local F = 1000 / 60
local PAGE_MS = { 7500, 9100, 10500, 10500 }
local OPEN_F, CLOSE_F, CONTENT_OUT_F = 15, 10, 4
local PANEL_MIN = 0.008
local PANEL_W = 1280 * S
local TEXT_FADE_F, TEXT_SLIDE_F, TEXT_SLIDE = 10, 15, -182

local function clamp01(v) return math.max(0.0, math.min(1.0, v)) end
local function lerp(a, b, t) return a + (b - a) * t end

local PAGES = {
    { text = "text_1", slide = 79, items = {
        { k = "shot_1", fade = 173 },
        { k = "hand_1", fade = 173, bounce = true },
        { k = "art_1", pop = { 97, 107, 112, 0.2, 1.12 } },
        { k = "icons_1", pop = { 97, 107, 112, 0.2, 1.12 } },
    } },
    { text = "text_2", slide = 89, items = {
        { k = "bubble_2", pop = { 322, 333, 336, 0.3, 1.1 } },
        { k = "fan_2", fade = 181 },
        { coins = true, fade = 181 },
        { k = "bonus_2", pop = { 181, 192, 197, 0.2, 1.2 } },
        { k = "card_2", pop = { 110, 119, 125, 0.2, 1.2 } },
    } },
    { text = "text_3", slide = 179, items = {
        { k = "shop_3", fade = 179 },
        { cursor = true, fade = 179 },
        { k = "bubble_3b", pop = { 425, 436, 439, 0.3, 1.1 } },
        { k = "bubble_3a", pop = { 215, 226, 229, 0.3, 1.1 } },
    } },
    { text = "text_4", slide = 79, items = {
        { k = "season_spring", pop = { 97, 106, 112, 0.2, 1.2 } },
        { k = "season_summer", pop = { 120, 129, 135, 0.3, 1.2 } },
        { k = "season_autumn", pop = { 143, 152, 158, 0.3, 1.2 } },
        { k = "season_winter", pop = { 166, 175, 181, 0.3, 1.2 } },
        { sparks = 181 },
        { k = "note_4", fade = 211 },
    } },
}

-- x, start frame
local COINS = {
    { 0, 0 }, { 60, 8 }, { -110, 16 }, { -60, 24 }, { 110, 32 }, { 0, 36 }, { -100, 40 }, { 60, 43 },
    { -110, 50 }, { -60, 56 }, { 110, 64 }, { -100, 68 },
    { 100, 0 }, { -50, 6 }, { 20, 13 }, { 80, 18 }, { -100, 24 }, { 20, 29 },
    { 100, 36 }, { -50, 42 }, { 20, 49 }, { 80, 54 }, { -100, 60 }, { 20, 65 },
}
local COINS_LOOP, COIN_FALL_F, COIN_FALL = 100, 33, 140
local COINS_X, COINS_Y, COINS_SCALE = -35.9, -61.1, 1.3
local COIN_SPIN = { 0, 0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 2, 2, 2, 1, 1, 1, 1 }
local COIN_SPARKLES = { { -100, 80 }, { 50, 20 }, { -60, 0 }, { 20, 100 } }

local CURSOR_F = 15
local CURSOR = {
    { -209, -71.5 }, { -126, -71.5 }, { -43, -71.5 }, { 40, -71.5 }, { 123, -71.5 }, { 206, -71.5 },
    { -209, 18.5 }, { -126, 18.5 },
    { -209, 131.5 }, { -126, 131.5 }, { -43, 131.5 }, { 40, 131.5 },
}

-- start frame, x, y, peak scale; each grows for SPARK_GROW_F then fades for SPARK_FADE_F
local SPARKS = {
    { 0, 76, -64, 0.7 }, { 40, -70, -50, 0.8 }, { 83, -136, -18, 0.8 },
    { 18, -100, 26, 0.7 }, { 61, 90, 20, 0.7 }, { 95, 20, 26, 0.5 },
    { 5, 50, 20, 0.4 }, { 57, -50, 80, 0.5 }, { 87, 28, -90, 0.4 },
    { 31, 130, 10, 0.5 },
}
local SPARK_GROW_F, SPARK_FADE_F, SPARKS_LOOP = 18, 11, 124
-- root x, y, then scale per axis
local SPARK_GROUPS = { { 0, 15, 1.5, -1.5 }, { -384, 14, 1.2, -1.2 }, { 376, 41, -1.2, -1.2 } }

function EntryInfo.new()
    local self = setmetatable({}, EntryInfo)
    self.t = {}
    self.now = tex.get_current_ms()
    self.t0 = self.now
    self.page = nil -- nil: panel still opening
    audio.play_sound("info_page", "sound")
    return self
end

function EntryInfo:draw_tex(key, p)
    local t = self.t[key]
    if t == nil then
        t = tex.get_texture("entry/entry_info/" .. key) or false
        self.t[key] = t
    end
    if t then tex.draw_texture(t, p or {}) end
end

function EntryInfo:next_page()
    if self.page == #PAGE_MS then
        self.out_t0 = self.now
        return
    end
    self.page = (self.page or 0) + 1
    self.page_t0 = self.now
    if self.page > 1 then audio.play_sound("info_page", "sound") end
end

function EntryInfo:update(current_ms)
    self.now = current_ms
    if self.out_t0 then return end
    if not self.page then
        if self.now - self.t0 >= OPEN_F * F then self:next_page() end
    elseif self.now - self.page_t0 >= PAGE_MS[self.page] then
        self:next_page()
    end
end

function EntryInfo:input()
    if self.out_t0 or not self.page then return false end
    self:next_page()
    return true
end

function EntryInfo:is_done()
    return self.out_t0 ~= nil and self.now - self.out_t0 >= (CLOSE_F + 1) * F
end

function EntryInfo:draw_panel()
    local sx
    if self.out_t0 then
        sx = lerp(0.9, PANEL_MIN, clamp01((self.now - self.out_t0) / (CLOSE_F * F)))
    else
        sx = lerp(PANEL_MIN, 1, clamp01((self.now - self.t0) / (OPEN_F * F)))
    end
    self:draw_tex("panel", { x = PANEL_W * (1 - sx) / 2, x2 = -PANEL_W * (1 - sx) })
end

function EntryInfo:draw_coins(f, fade)
    f = f % COINS_LOOP
    for _, c in ipairs(COINS) do
        local u = f - c[2]
        if u >= 0 and u <= COIN_FALL_F then
            local spin = math.floor(u) % #COIN_SPIN
            self:draw_tex("coin", {
                center = true, scale = COINS_SCALE, frame = COIN_SPIN[spin + 1],
                mirror = spin >= 13 and "horizontal" or nil,
                x = (COINS_X + COINS_SCALE * c[1]) * S,
                y = (COINS_Y + COINS_SCALE * COIN_FALL * u / COIN_FALL_F) * S,
                fade = fade * clamp01(0.1 + 0.9 * u / 10),
            })
        end
    end
    local u = f % 10
    local spot = COIN_SPARKLES[math.floor(f / 10) % #COIN_SPARKLES + 1]
    local s = u < 4 and lerp(0.1, 1, u / 4) or lerp(1, 0.5, (u - 4) / 5)
    self:draw_tex("sparkle", {
        center = true, scale = COINS_SCALE * s,
        x = (COINS_X + COINS_SCALE * spot[1]) * S,
        y = (COINS_Y + COINS_SCALE * spot[2]) * S,
        fade = fade * (u < 4 and 1 or lerp(0.8, 0, (u - 4) / 5)),
    })
end

function EntryInfo:draw_sparks(f, fade)
    f = f % SPARKS_LOOP
    for _, g in ipairs(SPARK_GROUPS) do
        for _, sp in ipairs(SPARKS) do
            local u = f - sp[1]
            if u >= 0 and u <= SPARK_GROW_F + SPARK_FADE_F then
                local grow = clamp01(u / SPARK_GROW_F)
                self:draw_tex("sparkle", {
                    center = true, scale = lerp(0.1, sp[4], grow) * math.abs(g[3]),
                    x = (g[1] + g[3] * sp[2]) * S,
                    y = (g[2] + g[4] * sp[3]) * S,
                    fade = fade * (1 - clamp01((u - SPARK_GROW_F) / SPARK_FADE_F)),
                })
            end
        end
    end
end

function EntryInfo:draw_item(it, f, fade)
    local base = fade
    if it.fade then
        if f < it.fade then return end
        base = fade * clamp01((f - it.fade) / 15)
    end
    if it.coins then
        self:draw_coins(f - it.fade, base)
    elseif it.cursor then
        local c = CURSOR[math.floor((f - it.fade) / CURSOR_F) % #CURSOR + 1]
        self:draw_tex("cursor_3", { x = c[1] * S, y = c[2] * S, fade = base })
    elseif it.sparks then
        if f >= it.sparks then self:draw_sparks(f - it.sparks, fade) end
    elseif it.pop then
        local p = it.pop
        if f < p[1] then return end
        local s, a
        if f < p[2] then
            local t = (f - p[1]) / (p[2] - p[1])
            s, a = lerp(p[4], p[5], t), t
        else
            s, a = lerp(p[5], 1, clamp01((f - p[2]) / (p[3] - p[2]))), 1
        end
        self:draw_tex(it.k, { center = true, scale = s, fade = fade * a })
    else
        local y = 0
        if it.bounce then
            local b = (f - it.fade) % 50
            y = (b < 25 and b / 25 or (50 - b) / 25) * 20
        end
        self:draw_tex(it.k, { y = y * S, fade = base })
    end
end

function EntryInfo:draw()
    self:draw_panel()
    if not self.page then return end

    local fade = 1
    if self.out_t0 then
        fade = 0.75 * (1 - clamp01((self.now - self.out_t0) / (CONTENT_OUT_F * F)))
        if fade <= 0 then return end
    end

    self:draw_tex("pager", { fade = fade })
    self:draw_tex("pager_dot", { x = 30 * (self.page - 1) * S, fade = fade })

    local page = PAGES[self.page]
    local f = (self.now - self.page_t0) / F
    for _, it in ipairs(page.items) do self:draw_item(it, f, fade) end

    local t = clamp01((f - page.slide) / TEXT_SLIDE_F)
    local y = TEXT_SLIDE * (1 - (1 - t) * (1 - t))
    self:draw_tex(page.text, { y = y * S, fade = fade * clamp01(f / TEXT_FADE_F) })
end
