local S = tex.get_screen_scale()
local DIR, SUB = "waiwai_song_select/panels", "panels"
local F = 1000 / 60

WaiwaiSongSelect = {}
WaiwaiSongSelect.__index = WaiwaiSongSelect

local shown_notice = false
local INPUT_LOCK, PAGE1_FRAMES, PAGE2_FRAMES = 60, 180, 240

local function lerp(a, b, t) return a + (b - a) * t end
local function clamp01(t) return math.max(0, math.min(1, t)) end
local function seg(f, f0, f1, a, b) return lerp(a, b, clamp01((f - f0) / (f1 - f0))) end

function WaiwaiSongSelect.new()
    local self = setmetatable({}, WaiwaiSongSelect)
    tex.load_folder("waiwai_song_select", SUB)
    self.cache = {}
    self.dons = 0
    if not shown_notice then
        local now = tex.get_current_ms()
        self.page, self.page_t0, self.notice_t0 = 1, now, now

        audio.stop_sound("voice_enter")
        audio.play_sound("voice_waiwai_title_1p", "voice")
        audio.play_sound("voice_waiwai_title_2p", "voice")
    end
    shown_notice = true
    return self
end

function WaiwaiSongSelect:t(key)
    local t = self.cache[key]
    if not t then
        local info = tex.get_texture_info(SUB, key)
        t = { id = tex.get_texture(DIR .. "/" .. key), w = info and info.x2[1] or 0, h = info and info.y2[1] or 0 }
        self.cache[key] = t
    end
    return t
end

-- centred on (cx, cy) at scale s
function WaiwaiSongSelect:mid(key, cx, cy, s, fade)
    local t = self:t(key)
    if not t.id or fade <= 0 then return end
    local w, h = t.w * s, t.h * s
    tex.draw_texture(t.id, { x = (cx - w / 2) * S, y = (cy - h / 2) * S, x2 = (w - t.w) * S, y2 = (h - t.h) * S, fade = fade })
end

local function pop_scale(f)
    if f < 9 then return seg(f, 0, 8, 0.75, 1.5) end
    if f < 13 then return seg(f, 9, 12, 1.35, 0.9) end
    if f < 16 then return seg(f, 13, 15, 0.967, 1.1) end
    if f < 20 then return seg(f, 16, 19, 1.062, 0.95) end
    if f < 24 then return seg(f, 20, 23, 0.962, 1) end
    return 1
end

function WaiwaiSongSelect:next_page(now)
    self.page, self.page_t0 = self.page + 1, now
    if self.page == 3 then audio.play_sound("voice_enter", "voice") end
end

function WaiwaiSongSelect:update(ms, dons)
    local pressed = dons > self.dons
    self.dons = dons
    if not self.page then return end
    local count = (ms - self.page_t0) / F
    if self.page == 3 then
        if count >= INPUT_LOCK then self.page = nil end
        return
    end
    if count < INPUT_LOCK then return end
    if pressed then audio.play_sound("don", "sound") end
    if pressed or count >= (self.page == 1 and PAGE1_FRAMES or PAGE2_FRAMES) then self:next_page(ms) end
end

function WaiwaiSongSelect:is_finished()
    return self.page == nil
end

function WaiwaiSongSelect:draw_notice(now)
    local count = (now - self.page_t0) / F

    local f
    if self.page == 1 then f = math.min(count, 33)
    elseif self.page == 2 then f = math.min(34 + count, 51)
    else f = math.min(52 + count, 58) end
    if f >= 58 then return end
    local s = pop_scale(f)
    local out = f >= 52 and seg(f, 52, 57, 0.832, 0) or 1
    self:mid("notice_bubble", 640, 340, s, out)
    if f < 38 then
        self:mid("notice_page_1", 640, 340, s, f < 34 and 1 or seg(f, 34, 37, 0.75, 0))
        -- "new!" tag bobs on a 50 frame loop
        local lf = ((now - self.notice_t0) / F) % 50
        local y = lf < 25 and seg(lf, 0, 24, 0, -10) or seg(lf, 25, 49, -9.6, 0)
        local a = f < 31 and seg(f, 24, 30, 0, 1) or (f < 34 and 1 or seg(f, 34, 37, 0.75, 0))
        if f >= 24 then self:mid("new_tag", 996, 306 + y, 1, a) end
    else
        self:mid("notice_page_2", 640, 340, s, f < 43 and seg(f, 38, 42, 0, 1) or out)
        -- the arrow nudges twice every 80 frames
        local lf = self.page == 2 and (count - 4) % 80 or 79
        local dx, dy = 0, 0
        if lf < 5 then dx, dy = seg(lf, 0, 4, 0, 14), seg(lf, 0, 4, 0, 4)
        elseif lf < 9 then dx, dy = seg(lf, 5, 8, 10.5, 0), seg(lf, 5, 8, 3, 0)
        elseif lf < 13 then dx, dy = seg(lf, 9, 12, 3.5, 14), seg(lf, 9, 12, 1, 4)
        elseif lf < 17 then dx, dy = seg(lf, 13, 16, 10.5, 0), seg(lf, 13, 16, 3, 0) end
        self:mid("notice_arrow_bubble", 394 + dx, 394 + dy, 1, f < 43 and seg(f, 38, 42, 0, 1) or out)
    end
end

function WaiwaiSongSelect:draw(ms)
    if self.page then self:draw_notice(tex.get_current_ms()) end
end
