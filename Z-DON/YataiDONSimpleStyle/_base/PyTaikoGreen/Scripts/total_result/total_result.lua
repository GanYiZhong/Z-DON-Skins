TotalResult = {}
TotalResult.__index = TotalResult

local S = tex.get_screen_scale()
local DIR = "total_result/tally"
local F = 1000 / 60
local BLACK = { 0, 0, 0, 255 }
local WHITE = { 255, 255, 255, 255 }

local PANEL_X = { 48, 658 }         -- ResultPanel origin per seat
local PANEL_Y = 187
local PRESENT_X = { 353, 655 }      -- PresentPanel
local PRESENT_Y = 610
local BOX_X = { 236, 846 }          -- OpenBox
local BOX_Y = 400
local AD_DX = { 0, 610 }

local TITLES_PER_PAGE = 8
-- AS constants (frames)
local TITLE_INTRO, SLIDE_LEN, SKIP_FROM = 165, 234, 36
local FADE_IN, POP_LEN, WAIT_AFTER, GATHER, BETWEEN = 25, 58, 30, 19, 90
local METER_FULL, BOX_LEN, FULL_LEN = 118, 100, 100
local OPEN_LEN, ITEM_HOLD, ITEM_OUT = 155, 180, 18
local AD_CARDS = { 209, 180, 180, 182, 180, 260 }
-- server present type (music, tone, dress, head, body) -> art frame (dress, music, tone, head, body)
local ART_FRAME = { [0] = 1, [1] = 2, [2] = 0, [3] = 3, [4] = 4 }

local function clamp01(v) return math.max(0.0, math.min(1.0, v)) end
local function ramp(t, at, len) return clamp01((t - at) / len) end
local function ease_in(u) return u * u end
local function ease_out(u) return u * (2 - u) end
local function lerp(a, b, u) return a + (b - a) * u end

local function play(name)
    if audio.has_sound(name) then audio.play_sound(name, name:find("vo_") and "voice" or "sound") end
end

function TotalResult.new(data)
    local self = setmetatable({}, TotalResult)
    self.tex = {}
    self.draw_icon = data.draw_icon
    self.month = data.month or 1
    self.seats = {}
    self.any_data = false
    for seat = 1, 2 do
        local p = data.players[seat]
        local s = { seat = seat, data = p ~= nil, gifts = 0, opened = 0 }
        if p then
            self.any_data = true
            s.songs, s.titles, s.presents = p.songs, p.titles, p.presents
            s.cur, s.aim, s.full = p.current, p.aim, p.aim < 0
            s.title_pages = math.ceil(#s.titles / TITLES_PER_PAGE)
            s.song_sum = 0
            for _, song in ipairs(s.songs) do
                s.song_sum = s.song_sum + song.points
                song.text = text.create_raw_text(song.title, math.floor(24 * S), WHITE, BLACK, false, 4, 1.0)
            end
            for _, title in ipairs(s.titles) do
                title.text = text.create_raw_text(title.name, math.floor(18 * S), WHITE, BLACK, false, 3, 1.0)
            end
            for _, gift in ipairs(s.presents) do
                gift.text = text.create_raw_text(gift.name, math.floor(32 * S), WHITE, BLACK, false, 4, 1.0)
            end
            s.next_present, s.left = 1, 0
            s.meter = s.full and "full_idle" or "idle"
        end
        self.seats[seat] = s
    end
    self.state, self.t0 = "intro", tex.get_current_ms()
    self.page, self.done = 0, false
    self.f = 0
    play("vo_call")
    if audio.has_sound("bgm") then audio.play_sound("bgm", "music") end
    return self
end

function TotalResult:t(key)
    local t = self.tex[key]
    if not t then
        local id = tex.get_texture(DIR .. "/" .. key)
        local info = tex.get_texture_info(DIR:match("[^/]+$"), key)
        t = { id = id, w = info and info.x2[1] or 0, h = info and info.y2[1] or 0 }
        self.tex[key] = t
    end
    return t
end

-- top-left at (x, y), scale sx/sy
function TotalResult:put(key, x, y, opts)
    local t = self:t(key)
    opts = opts or {}
    local sx, sy = opts.sx or 1, opts.sy or opts.sx or 1
    tex.draw_texture(t.id, { x = x * S, y = y * S, x2 = t.w * (sx - 1), y2 = t.h * (sy - 1), fade = opts.fade,
                             frame = opts.frame, mirror = opts.mirror })
end

-- centred on (cx, cy)
function TotalResult:mid(key, cx, cy, s, fade, frame, sy)
    local t = self:t(key)
    local w, h = t.w * s, t.h * (sy or s)
    tex.draw_texture(t.id, { x = cx * S - w / 2, y = cy * S - h / 2, x2 = w - t.w, y2 = h - t.h, fade = fade,
                             frame = frame })
end

-- right-aligned; rightmost digit's left edge at x
function TotalResult:digits(key, value, x, y, pitch, fade)
    local str = tostring(math.max(0, math.floor(value)))
    for i = 1, #str do
        self:put(key, x - (i - 1) * pitch, y, { frame = tonumber(str:sub(#str - i + 1, #str - i + 1)), fade = fade })
    end
end

function TotalResult:go(state)
    self.state, self.t0, self.f = state, tex.get_current_ms(), 0
end

-- meter: "mount" fills at METER_FULL frames per bar; reaching the aim opens the next gift, then goes on
function TotalResult:mount(s, add)
    if not s.data or s.full then return end
    s.left, s.meter, s.tick = add, "mount", 0
end

local function meter_busy(s) return s.data and (s.meter == "mount" or s.meter == "box" or s.meter == "full") end

function TotalResult:reach_aim(s)
    s.cur = math.max(0, s.cur - s.aim)
    local gift = s.presents[s.next_present]
    s.next_present = s.next_present + 1
    if gift then
        s.gifts = s.gifts + 1
        s.gift_f = self.clock
        play("se_gohobi")
        play("vo_gohobi_get")
        s.aim = gift.next_aim
    end
    if s.aim < 0 then
        s.meter, s.full, s.box_f = "full", true, self.clock
        play("se_popup")
    else
        s.meter, s.box_f = "box", self.clock
    end
end

function TotalResult:update_meter(s)
    if not s.data then return end
    if s.meter == "mount" then
        local step = math.min(s.left, s.aim / METER_FULL)
        s.cur, s.left = s.cur + step, s.left - step
        if s.tick % 10 == 0 then play("se_pt") end
        s.tick = s.tick + 1
        if s.cur >= s.aim and s.left > 0 then
            audio.stop_sound("se_pt")
            self:reach_aim(s)
        elseif s.left <= 0 then
            audio.stop_sound("se_pt")
            play("don")
            s.meter = "idle"
        end
    elseif s.meter == "box" and self.clock - s.box_f >= BOX_LEN then
        s.meter, s.tick = s.left > 0 and "mount" or "idle", 0
    elseif s.meter == "full" and self.clock - s.box_f >= FULL_LEN then
        s.meter = "full_idle"
    end
end

-- finish a mount at once (Don pressed)
function TotalResult:settle_meter(s)
    if not s.data or s.full then return end
    audio.stop_sound("se_pt")
    while s.left > 0 and not s.full do
        local need = s.aim - s.cur
        if s.left < need then
            s.cur, s.left = s.cur + s.left, 0
        else
            s.left = s.left - need
            self:reach_aim(s)
        end
    end
    if s.meter ~= "full" then s.meter = s.full and "full_idle" or "idle" end
end

function TotalResult:gifts_pending()
    for _, s in ipairs(self.seats) do
        if s.data and s.opened < #s.presents then return true end
    end
    return false
end

function TotalResult:has_titles()
    for _, s in ipairs(self.seats) do
        if s.data and #s.titles > 0 then return true end
    end
    return false
end

function TotalResult:update(current_ms)
    if self.done then return end
    local dt = current_ms - self.t0
    self.f = dt / F
    self.clock = current_ms / F
    local f, st = self.f, self.state
    for _, s in ipairs(self.seats) do self:update_meter(s) end
    if st == "intro" then
        if f >= TITLE_INTRO then
            self:go("slide")
            play("se_doncho")
            self.vo_said = false
        end
    elseif st == "slide" then
        if f >= 30 and not self.vo_said then
            self.vo_said = true
            play("vo_shukei")
        end
        if f >= SLIDE_LEN then
            self:go(self.any_data and "music_in" or "ad_only")
        end
    elseif st == "ad_only" then
        if f >= AD_CARDS[1] + AD_CARDS[2] then self:go("close") end
    elseif st == "music_in" then
        if f >= FADE_IN then self:go("music_pop") end
    elseif st == "music_pop" then
        if f >= POP_LEN + WAIT_AFTER then self:go("music_gather") end
    elseif st == "music_gather" then
        if f >= GATHER + WAIT_AFTER then
            for _, s in ipairs(self.seats) do self:mount(s, s.data and s.song_sum or 0) end
            self:go("music_mount")
            play("se_song_count")
        end
    elseif st == "music_mount" or st == "title_mount" then
        if not (meter_busy(self.seats[1]) or meter_busy(self.seats[2])) then
            self:go(st == "music_mount" and "music_out" or "title_out")
        end
    elseif st == "music_out" then
        if f >= BETWEEN then
            if self:has_titles() then
                self.page = 0
                play("vo_shogo")
                self:go("title_in")
            else
                self:go("panel_out")
            end
        end
    elseif st == "title_in" then
        if f == 0 or not self.shogo_page or self.shogo_page ~= self.page then
            self.shogo_page = self.page
            play("se_shogo_get")
        end
        if f >= POP_LEN + WAIT_AFTER then self:go("title_gather") end
    elseif st == "title_gather" then
        if f >= GATHER + WAIT_AFTER then
            for _, s in ipairs(self.seats) do self:mount(s, self:page_sum(s)) end
            self:go("title_mount")
        end
    elseif st == "title_out" then
        if f >= BETWEEN then
            self.page = self.page + 1
            if self:page_exists() then self:go("title_in") else self:go("panel_out") end
        end
    elseif st == "panel_out" then
        if f >= BETWEEN + 10 then
            if self:gifts_pending() then
                play("vo_gohoubi")
                self:go("reward_in")
            else
                self:go("close")
            end
        end
    elseif st == "reward_in" then
        if f >= 19 + 60 then self:open_next() end
    elseif st == "reward_open" then
        if f >= OPEN_LEN + ITEM_HOLD + ITEM_OUT then self:open_next() end
    elseif st == "reward_out" then
        if f >= 15 then self:go("close") end
    elseif st == "close" then
        if f >= 30 then
            self.done = true
            audio.stop_sound("bgm")
        end
    end
end

function TotalResult:open_next()
    if not self:gifts_pending() then
        self:go("reward_out")
        return
    end
    for _, s in ipairs(self.seats) do
        if s.data and s.opened < #s.presents then
            s.opened = s.opened + 1
            s.showing = s.presents[s.opened]
            s.first_open = s.opened == 1
            s.gifts = math.max(0, s.gifts - 1)
        else
            s.showing = nil
        end
    end
    self.gohobi_detail, self.gohobi_content = false, false
    self:go("reward_open")
end

function TotalResult:page_titles(s)
    local out = {}
    local first = self.page * TITLES_PER_PAGE
    for i = first + 1, math.min(first + TITLES_PER_PAGE, #s.titles) do out[#out + 1] = s.titles[i] end
    return out
end

function TotalResult:page_sum(s)
    if not s.data then return 0 end
    local sum = 0
    for _, title in ipairs(self:page_titles(s)) do sum = sum + title.points end
    return sum
end

function TotalResult:page_exists()
    for _, s in ipairs(self.seats) do
        if s.data and self.page < s.title_pages then return true end
    end
    return false
end

-- Don: jumps the part that is playing to its end; returns whether it took
function TotalResult:skip()
    local st = self.state
    if st == "intro" then
        self:go("slide")
        play("se_doncho")
        self.vo_said = false
        return true
    elseif st == "slide" and self.f >= SKIP_FROM then
        self:go(self.any_data and "music_in" or "ad_only")
        return true
    elseif st == "ad_only" then
        self:go("close")
        return true
    elseif st == "music_in" or st == "music_pop" or st == "music_gather" then
        for _, s in ipairs(self.seats) do
            self:mount(s, s.data and s.song_sum or 0)
            self:settle_meter(s)
        end
        self:go("music_out")
        return true
    elseif st == "title_in" or st == "title_gather" then
        for _, s in ipairs(self.seats) do
            self:mount(s, self:page_sum(s))
            self:settle_meter(s)
        end
        self:go("title_out")
        return true
    elseif st == "music_mount" or st == "title_mount" then
        for _, s in ipairs(self.seats) do self:settle_meter(s) end
        return true
    elseif st == "reward_open" and self.f < OPEN_LEN then
        self.t0 = tex.get_current_ms() - OPEN_LEN * F
        return true
    end
    return false
end

function TotalResult:is_done() return self.done end

-- nameplates fade in as the curtain rises, out as it comes down
function TotalResult:nameplate()
    local st = self.state
    if st == "intro" then return 0 end
    if st == "slide" then return ramp(self.f, 9, 27) end
    if st == "close" then return 1 - ramp(self.f, 0, 15) end
    return 1
end

-- ---------------------------------------------------------------- drawing

function TotalResult:draw_curtain_y()
    local st, f = self.state, self.f
    if st == "intro" then return 364 end
    if st == "slide" then
        if f < 6 then return lerp(364, 370, ramp(f, 0, 6)) end
        if f < 51 then return lerp(342, -265, ease_out(ramp(f, 7, 44))) end
        return lerp(-265, -258, ramp(f, 51, 5))
    end
    if st == "close" then return lerp(-258, 364, ease_out(ramp(f, 0, 30))) end
    return -258
end

function TotalResult:draw_curtain()
    local y = self:draw_curtain_y() - 372 -- stripes' top on screen
    for i = 0, 10 do
        local key = (i % 2 == 0) and "stripe_red" or "stripe_white"
        self:put(key, -20 + i * 120, y, { sx = 15, sy = 1 })
    end
end

function TotalResult:draw_intro_title()
    local st, f = self.state, self.f
    local X = { 167, 317, 465, 617, 772, 927 }
    if st == "intro" then
        for i = 1, 6 do
            local u = ramp(f, (i - 1) * 8, 10)
            if u > 0 then
                local s = lerp(1.6, 1, ease_out(u))
                self:mid("title_shadow", X[i] + 100, 378, s, u, i - 1)
                self:mid("title_red", X[i] + 100, 378, s, u, i - 1)
            end
        end
    elseif st == "slide" then
        if f < 36 then
            -- big title shrinks into the small plaque
            local u = ease_in(ramp(f, 10, 26))
            local s = lerp(1, 0.34, u)
            for i = 1, 6 do
                local cx = lerp(X[i] + 100, 187 + (i - 0.5) * 53, u)
                local cy = lerp(378, 48 + 40, u)
                self:mid("title_shadow", cx, cy, s, 1, i - 1)
                self:mid("title_red", cx, cy, s, 1, i - 1)
            end
        end
        if f >= 30 and f < 206 then
            local cloud_s = f < 45 and lerp(0.9, 1.05, ramp(f, 30, 15)) or lerp(1.05, 1, ramp(f, 45, 15))
            self:mid("cloud", 642, 338, cloud_s, ramp(f, 30, 16) * (1 - ramp(f, 193, 13)))
        end
        if f >= 36 then
            self:put("title_small", 187, 48, { fade = 1 - ramp(f, 208, 26) })
        end
    end
end

function TotalResult:draw_chip()
    local st, f = self.state, self.f
    local key
    if st == "music_in" or st == "music_pop" or st == "music_gather" or st == "music_mount" or st == "music_out" then
        key = "chip_total"
    elseif st == "title_in" or st == "title_gather" or st == "title_mount" or st == "title_out" then
        key = "chip_title"
    end
    if not key then return end
    local u = (st == "music_in" or (st == "title_in" and self.page == 0)) and ramp(f, 0, 22) or 1
    self:put(key, lerp(636, 201, ease_out(u)), 48, { fade = u })
end

function TotalResult:panel_alpha()
    local st, f = self.state, self.f
    if st == "music_in" then return ramp(f, 0, FADE_IN) end
    if st == "panel_out" then return 1 - ramp(f, BETWEEN, 10) end
    if st == "intro" or st == "slide" or st:find("reward") or st == "close" or st == "ad_only" then return 0 end
    return 1
end

-- pop of a point ball with its number; returns scale, alpha
local function ball_pose(f)
    if f < 30 then return 0, 0 end
    if f < 44 then return lerp(0.24, 1.1, ease_out(ramp(f, 30, 14))), 1 end
    if f < 58 then return lerp(1.1, 1, ease_in(ramp(f, 44, 14))), 1 end
    return 1, 1
end

function TotalResult:draw_ball(value, x, y, s, fade)
    if s <= 0 or fade <= 0 then return end
    local cx, cy = x + 48, y + 48
    self:mid("ball", cx, cy, s, fade)
    self:mid("ball_shine", cx, cy - 0.8 * s, s, fade)
    local str = tostring(value)
    local w = (#str * 20 + 8.8) * s
    for i = 1, #str do
        local dx = -w / 2 + (i - 1) * 20 * s + 14.4 * s
        self:mid("digits_ball", cx + dx, cy, 1.2 * s, fade, tonumber(str:sub(i, i)))
    end
end

function TotalResult:draw_sum_bar(s, px, top, label_key, value, a)
    self:put("sum_bar", px + 14, top, { fade = a })
    self:put(label_key, px + 108, top + 9, { fade = a })
    self:digits("digits_black", value, px + 386, top + 12, 24, a)
end

local SONG_TOPS = { { -13 }, { -23, 57 }, { -33, 37, 107 }, { -43, 17, 77, 137 } }
local SUM_TOPS = { 137, 157, 187, 197 }

function TotalResult:draw_music(s)
    local st, f = self.state, self.f
    local a = self:panel_alpha()
    if st == "music_out" then a = 1 - ramp(f, BETWEEN - 15, 15) end
    if a <= 0 or not (st:find("music")) then return end
    local px = PANEL_X[s.seat]
    local n = math.min(#s.songs, 4)
    if n == 0 then return end
    local first = #s.songs - n
    local gather = st == "music_gather" and ramp(f, 0, GATHER) or ((st == "music_mount" or st == "music_out") and 1 or 0)
    local pop = st == "music_pop" and f or ((st == "music_in") and 0 or 999)
    local sum = 0
    for i = 1, n do
        local top = SONG_TOPS[n][i]
        local song = s.songs[first + i]
        self:put("song_bar", px + 14, PANEL_Y + top, { fade = a })
        self:put("badge", px + 17, PANEL_Y + top, { frame = i - 1, fade = a })
        song.text:draw({ x = (px + 280) * S - song.text.width / 2, y = (PANEL_Y + top + 32) * S - song.text.height / 2,
                         fade = a })
        local bs, ba = ball_pose(pop)
        local bx, by = px + 477, PANEL_Y + top - 17
        if gather > 0 then
            bx, by = lerp(bx, px + 278, gather), lerp(by, PANEL_Y + 270, gather)
            ba = 1 - gather
        end
        self:draw_ball(song.points, bx, by, bs, ba * a)
    end
    if pop >= 30 then sum = s.song_sum * ramp(pop, 30, 28) end
    self:draw_sum_bar(s, px, PANEL_Y + SUM_TOPS[n], "sum_label", sum, a)
end

function TotalResult:draw_titles(s)
    local st, f = self.state, self.f
    if not st:find("title") then return end
    local titles = self:page_titles(s)
    if #titles == 0 then return end
    local px, py = PANEL_X[s.seat] + 30, PANEL_Y + 20
    local a = 1
    if st == "title_in" then a = ramp(f, 0, 15) end
    if st == "title_out" then a = 1 - ramp(f, BETWEEN - 15, 15) end
    local gather = st == "title_gather" and ramp(f, 0, GATHER) or ((st == "title_mount" or st == "title_out") and 1 or 0)
    local pop = st == "title_in" and f or 999
    for i, title in ipairs(titles) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local bx, by = px + col * 260, py - 45 + row * 55
        self:put("board", bx, by, { fade = a })
        self:put("board_new", bx, by, { fade = a * (0.5 + 0.5 * math.sin((self.clock or 0) / 30 * math.pi)) })
        title.text:draw({ x = (bx + 128) * S - title.text.width / 2, y = (by + 24) * S - title.text.height / 2, fade = a })
        local bs, ba = ball_pose(pop)
        local tx, ty = bx + 192.2, by - 10.8 -- draw_ball centres on +48; rest centre is (240, 37) of the board
        if gather > 0 then
            tx, ty = lerp(tx, PANEL_X[s.seat] + 105, gather), lerp(ty, PANEL_Y + 296, gather)
            ba = 1 - gather
        end
        self:draw_ball(title.points, tx, ty, bs * 0.4, ba * a)
    end
    local sum = pop >= 30 and self:page_sum(s) * ramp(pop, 30, 28) or (st == "title_in" and 0 or self:page_sum(s))
    self:draw_sum_bar(s, px - 30, PANEL_Y + 197, "sum_label_title", sum, a)
end

function TotalResult:draw_meter(s, a)
    if a <= 0 then return end
    local mx, my = PANEL_X[s.seat] + 195, PANEL_Y + 276
    self:put("meter_base", mx + 15, my + 20, { fade = a })
    local u = (s.full or s.aim <= 0) and 1 or clamp01(s.cur / s.aim)
    -- the arcade's `rainbow` clip only plays once the track has ended
    if s.full then
        local frame = math.floor((self.clock or 0) / 5) % 8
        self:put("meter_fill", mx + 15, my + 18, { frame = frame, fade = a })
    end
    local marker = 17.95 + 231.05 * u
    if u < 1 then
        self:put("meter_cover", mx + marker, my + 20, { sx = (249 - marker) / 8, sy = 1, fade = a })
    end
    self:put("meter_marker", mx + marker - 2.5, my + 16, { fade = a })
    -- above the bar: its window is what cuts the 96 px tall fill down to the 64 px bar
    self:put("meter_panel", mx - 35, my + 2, { fade = a })
    self:put("meter_arrow", mx + marker - 21.5, my - 14, { fade = a })
    local box_f = s.box_f and (self.clock - s.box_f) or 999
    if s.full and s.meter ~= "box" then
        self:mid("meter_face", mx + 288, my + 52, 1, a)
        local fa = s.meter == "full" and ramp(box_f, 0, 50) or 1
        self:put("full_bar", mx + 19, my + 74, { sx = 28.75, sy = 4.375, fade = fa * a })
        self:put("full_text", mx, my + 71, { fade = fa * a })
        local pop = s.meter == "full" and ramp(box_f, 0, 20) * (1 - ramp(box_f, FULL_LEN - 15, 15)) or 0
        if pop > 0 then self:mid("full_popup", mx + 288, my + 37, lerp(0.8, 1, pop), pop) end
    else
        local pop = s.meter == "box" and box_f or 999
        local scale = pop < 24 and lerp(1, 1.5, ease_out(ramp(pop, 0, 14))) or 1
        local shown = pop < 39 and (1 - ramp(pop, 39, 5)) or (pop >= 80 and ramp(pop, 80, 15) or (pop == 999 and 1 or 0))
        if pop >= 80 and pop < 110 then
            self:mid("meter_gift", mx + 288, my + 52 + lerp(40, 0, ease_out(ramp(pop, 80, 15))), 1, shown * a)
        else
            self:mid("meter_gift", mx + 288, my + 52, scale, shown * a)
        end
        if pop < 39 then
            local burst = pop < 15 and ramp(pop, 0, 15) or (1 - ramp(pop, 15, 15))
            self:mid("gift_white", mx + 288, my + 52, lerp(1, 1.6, ease_out(ramp(pop, 0, 15))), burst * a)
        end
        self:put("meter_slash", mx + 115, my + 71, { fade = a })
        self:digits("digits_red", s.cur, mx + 88, my + 71, 24, a)
        self:digits("digits_black", s.aim, mx + 214, my + 71, 24, a)
    end
end

function TotalResult:draw_present_panel(s)
    if s.gifts <= 0 and not s.gift_f then return end
    local a = self.state == "close" and 1 - ramp(self.f, 0, 15) or 1
    if a <= 0 then return end
    local px = PRESENT_X[s.seat]
    self:put("present_panel", px, PRESENT_Y, { fade = a })
    if s.gifts > 10 then
        self:put("gift", px + 64, PRESENT_Y + 18, { fade = a })
        self:put("times", px + 124, PRESENT_Y + 36, { fade = a })
        self:digits("digits_present", math.min(s.gifts, 99), px + 174, PRESENT_Y + 36, 20, a)
    else
        for i = 0, s.gifts - 1 do
            -- bottom row first from the right, like the BoxIcon depths
            local col, row = 4 - (i % 5), i < 5 and 1 or 0
            self:mid("gift", px + 46 + col * 45, PRESENT_Y + 30 + row * 44, 0.3, a)
        end
    end
end

function TotalResult:draw_reward(s)
    if not s.showing then return end
    local f, x, y = self.f, BOX_X[s.seat], BOX_Y
    local gift = s.showing
    -- the first box flies in over 30 f; each next one is already there
    local fly = s.first_open and ease_out(ramp(f, 0, 30)) or 1
    local bs = lerp(0.5, 1, fly)
    local dx, dy = lerp(205, 0, fly) * (1 - fly), lerp(180, 0, fly) * (1 - fly)
    local out = f >= OPEN_LEN + ITEM_HOLD and ramp(f, OPEN_LEN + ITEM_HOLD, ITEM_OUT) or 0
    local at = f - 30 -- box clock: closed, squash, then open at 81
    local text_at = s.first_open and at or f + 60
    if text_at >= 141 then
        local a = ramp(text_at, 141, 15) * (1 - out)
        if not self.gohobi_content then
            self.gohobi_content = true
            play("se_gohobi_content")
        end
        self:put("reward_plate", x - 200, y - 240, { fade = a })
        self:put("reward_title", x - 92, y - 317, { frame = ART_FRAME[gift.type], fade = a })
        if gift.text then
            gift.text:draw({ x = (x + 100) * S - gift.text.width / 2, y = (y - 236 + 25) * S - gift.text.height / 2,
                             fade = a })
        end
    end
    local key = "box_closed"
    if at >= 27 then key = "box_squash" end
    if not s.first_open or at >= 81 then key = "box_open" end
    local squash = (at >= 22 and at < 34) and 0.9 or 1
    self:mid(key, x + 100 + dx, y + 100 + dy, bs, 1 - out, nil, bs * squash)
    if at >= 81 or not s.first_open then
        local u = s.first_open and ramp(at, 81, 22) or ramp(f, 0, 22)
        local icon_y = lerp(y + 10, y - 180, ease_out(u))
        local icon_s = lerp(0.5, 1, ease_out(u))
        local cx, cy = x + 100, icon_y + 100
        self:mid("reward_glow", cx, cy, icon_s * 1.1, (1 - out) * 0.65)
        self:mid("reward_icon", cx, cy, icon_s, 1 - out, ART_FRAME[gift.type])
        self.draw_icon(gift.icon, cx * S, cy * S, 120 * icon_s * S, 1 - out)
        if s.first_open and at >= 81 and not self.gohobi_detail then
            self.gohobi_detail = true
            play("se_gohobi_detail")
        end
        local smoke = s.first_open and at or (f + 81)
        if smoke >= 81 and smoke < 117 then
            local stage = smoke < 98 and 0 or (smoke < 104 and 1 or (smoke < 110 and 2 or 3))
            local grow = smoke < 91 and lerp(0.1, 0.83, ease_out(ramp(smoke, 81, 10))) or 1
            self:mid("smoke", x + 100, y + 110 - (smoke - 81) * 0.8, grow, 1 - ramp(smoke, 110, 7), stage)
        end
    end
end

function TotalResult:draw_heading()
    local st, f = self.state, self.f
    if st == "reward_in" or st == "reward_open" or st == "reward_out" then
        local a = st == "reward_in" and ramp(f, 0, 19) or (st == "reward_out" and 1 - ramp(f, 0, 15) or 1)
        self:mid("heading_reward", 640, 77, 0.8 + 0.2 * ((st == "reward_in") and ramp(f, 0, 9) or 1), a)
    end
end

-- no-card panel: the arcade loops six cards; art rests are kept, motion is a fade
function TotalResult:draw_ad_card(i, dx, a)
    if i == 1 then
        self:put("ad_touch", 195 + dx, 356, { fade = a })
        self:put("ad_or", 316 + dx, 259, { fade = a })
        self:put("ad_phone", 381 + dx, 163, { sx = 1.13, fade = a })
        self:put("ad_card", 104 + dx, 205, { fade = a })
    elseif i == 2 then
        self:put("ad_stage", 55 + dx, 131, { fade = a })
        self:put("ad_hand", 413 + dx, 406, { fade = a })
    elseif i == 3 then
        self:mid("ad_rays", 335 + dx, 363, 1, a)
        local month = (self.month - 6) % 12
        local costume = math.min(month, 10)
        self:put("ad_month", 155 + dx, 108, { frame = costume, fade = a })
        self:put("ad_month_name", 155 + dx, 440, { frame = costume, fade = a })
        self:put("ad_now", 53 + dx, 163, { sx = 0.6, fade = a })
    elseif i == 4 then
        self:put("ad_bana", 251 + dx, 398, { fade = a })
        self:put("ad_don_a", 450 + dx, 174, { fade = a })
        self:put("ad_don_b", 66 + dx, 179, { fade = a })
        self:put("ad_don_c", 414 + dx, 297, { fade = a })
        self:put("ad_don_d", 99 + dx, 294, { fade = a })
        self:put("ad_don_main", 231 + dx, 207, { fade = a })
        self:put("ad_kisekae", 191 + dx, 173, { fade = a })
    elseif i == 5 then
        self:put("ad_flower", 55 + dx, 131, { fade = a })
        self:put("ad_phone2", 345 + dx, 234, { fade = a })
        self:put("ad_card2", 76 + dx, 262, { sx = 1.16, fade = a })
        self:put("ad_fun", 153 + dx, 168, { fade = a })
    else
        self:put("ad_lines", 55 + dx, 131, { fade = a })
        self:put("ad_boy", 66 + dx, 249, { fade = a })
        self:put("ad_girl", 420 + dx, 215, { fade = a })
        self:put("ad_getit", 189 + dx, 219, { fade = a })
    end
end

function TotalResult:draw_ad(s)
    local st = self.state
    if st == "intro" or st == "slide" then return end
    if st == "close" and self.f >= 15 then return end
    local dx = AD_DX[s.seat]
    local a = st == "close" and 1 - ramp(self.f, 0, 15) or 1
    self:put("ad_panel", 55 + dx, 131, { fade = a })
    local total = 0
    for _, len in ipairs(AD_CARDS) do total = total + len end
    local clock = (self.clock or 0) % total
    for i, len in ipairs(AD_CARDS) do
        if clock < len then
            local fade = ramp(clock, 0, 15) * (1 - ramp(clock, len - 15, 15))
            self:draw_ad_card(i, dx, a * fade)
            break
        end
        clock = clock - len
    end
    self:put("ad_footer", (s.seat == 1 and 265 or 671), 491, { fade = a })
    self:put("ad_mascot", (s.seat == 1 and 62 or 1092), 485, { fade = a })
end

function TotalResult:draw()
    self:put("bg", 0, 0, { sx = 160, sy = 1 })
    local st = self.state
    if st ~= "intro" then self:put("footer", 0, 577) end
    local pa = self:panel_alpha()
    for _, s in ipairs(self.seats) do
        if s.data then
            if pa > 0 then self:put("panel_back", (s.seat == 1 and 55 or 665), 131, { fade = pa * 0.5 }) end
            self:draw_music(s)
            self:draw_titles(s)
            self:draw_meter(s, pa)
        else
            self:draw_ad(s)
        end
    end
    for _, s in ipairs(self.seats) do
        if s.data then self:draw_present_panel(s) end
    end
    self:draw_curtain()
    self:draw_chip()
    self:draw_heading()
    for _, s in ipairs(self.seats) do self:draw_reward(s) end
    self:draw_intro_title()
end
