local S = tex.get_screen_scale()
local DIR, SUB = "waiwai_game/effect", "effect"
local F = 1000 / 60

WaiwaiGame = {}
WaiwaiGame.__index = WaiwaiGame


local VARIANT = { breath = "breath", p1 = "blue", p2 = "red" }
-- the two lane sets: line y, text y, band y
local SETS = { { 186, 170, 272 }, { 532, 544, 446 } }
local HOLD_MS = 1000

local function lerp(a, b, t) return a + (b - a) * t end
local function clamp01(t) return math.max(0, math.min(1, t)) end
local function seg(f, f0, f1, a, b) return lerp(a, b, clamp01((f - f0) / (f1 - f0))) end
local function ease_out(f, f0, f1, a, b) local t = clamp01((f - f0) / (f1 - f0)); return lerp(a, b, 1 - (1 - t) * (1 - t)) end
local function ease_in(f, f0, f1, a, b) local t = clamp01((f - f0) / (f1 - f0)); return lerp(a, b, t * t) end


local GAUGE_Y = 176
local GAUGE_RED, GAUGE_MAX = 34, 50

local function gauge_cells(point)
    local out = {}
    local function put(name, dx) out[#out + 1] = { name, dx } end
    local red, yellow = math.min(point, GAUGE_RED), math.max(point - GAUGE_RED, 0)
    local tens = math.floor(red / 10)
    for k = 0, tens - 1 do put("gauge_red_block_10", 150 * k) end
    local i = tens * 10
    if red - i >= 5 then
        put("gauge_red_block_5", 150 * tens)
        i = i + 5
    end
    local function run(first, last, a, b)
        for j = first, last do
            if (j - first) % 2 == 0 then put(a, 15 * j) else put(b, 15 * (j - 1)) end
        end
    end
    run(i, red - 1, "gauge_red_cell_0", "gauge_red_cell_1")
    local fives = math.floor(yellow / 5)
    for k = 0, fives - 1 do put("gauge_yellow_block_5", 75 * k) end
    i = fives * 5
    run(i, yellow - 1, "gauge_yellow_cell_0", "gauge_yellow_cell_1")
    return out
end

function WaiwaiGame.new()
    local self = setmetatable({}, WaiwaiGame)
    tex.load_folder("waiwai_game", SUB)
    self.cache = {}
    self.title = tex.get_texture(DIR .. "/title")
    self.start_frames = tex.get_texture(DIR .. "/synchro_start")
    self.clear_frames = tex.get_texture(DIR .. "/clear_effects")
    self.started, self.ended = nil, nil
    self.cut = nil
    self.gauge_tex = {}
    self.point = 0
    self.fever, self.fever_t = false, nil
    return self
end

function WaiwaiGame:gauge_part(name, dx, fade)
    local t = self.gauge_tex[name]
    if not t then
        t = tex.get_texture(DIR .. "/" .. name)
        self.gauge_tex[name] = t
    end
    tex.draw_texture(t, { x = (dx or 0) * S, y = GAUGE_Y * S, fade = fade })
end

function WaiwaiGame:set_gauge(point)
    self.point = point
    local fever = point >= GAUGE_MAX
    if fever ~= self.fever then
        self.fever, self.fever_t = fever, tex.get_current_ms()
    end
end

function WaiwaiGame:fever_alpha(now)
    if not self.fever_t then return 0 end
    local f = (now - self.fever_t) / F
    if self.fever then return seg(f, 0, 9, 0, 1) end
    return seg(f, 0, 7, 0.855, 0)
end

function WaiwaiGame:draw_gauge(now)
    local cleared = self.point > GAUGE_RED
    local rainbow = self:fever_alpha(now)
    self:gauge_part(cleared and "gauge_frame_clear" or "gauge_frame_red")
    if rainbow > 0 then self:gauge_part("gauge_frame_rainbow", 0, rainbow) end
    self:gauge_part("gauge_back")
    for _, c in ipairs(gauge_cells(self.point)) do self:gauge_part(c[1], c[2]) end

    if rainbow > 0 then self:gauge_part("gauge_rainbow_" .. math.floor(now / F / 5) % 8, 0, rainbow) end
    self:gauge_part(cleared and "gauge_clear_text_lit" or "gauge_clear_text")
end

function WaiwaiGame:t(part)
    local t = self.cache[part]
    if not t then
        local key = "cut_in_" .. part
        local info = tex.get_texture_info(SUB, key)
        t = { id = tex.get_texture(DIR .. "/" .. key), w = info and info.x2[1] or 0, h = info and info.y2[1] or 0 }
        self.cache[part] = t
    end
    return t
end

-- centred on (cx, cy), separate x / y scale
function WaiwaiGame:mid(part, cx, cy, sx, sy, fade)
    local t = self:t(part)
    if not t.id or fade <= 0 or sx <= 0 then return end
    local w, h = t.w * sx, t.h * sy
    tex.draw_texture(t.id, { x = (cx - w / 2) * S, y = (cy - h / 2) * S, x2 = (w - t.w) * S, y2 = (h - t.h) * S, fade = fade })
end

function WaiwaiGame:cut_in(variant)
    self.cut = { v = VARIANT[variant] or VARIANT.breath, t0 = tex.get_current_ms() }
end

local function cut_frame(ms)
    local in_ms = 28 * F
    if ms < in_ms then return 5 + ms / F end
    ms = ms - in_ms
    if ms < HOLD_MS then return 33 + (ms / F) % 10 end
    return 43 + (ms - HOLD_MS) / F
end

function WaiwaiGame:draw_cut_set(v, set, f, hold_ms)
    local line_y, text_y, band_y = set[1], set[2], set[3]
    -- blurred band sweeping across
    local bx, bsx, bsy, ba
    if f < 18 then
        bx, bsx, bsy, ba = ease_out(f, 5, 17, 1600, 920), seg(f, 5, 17, 2, 3), seg(f, 5, 17, 1, 1.04), seg(f, 5, 17, 0.4, 0.9)
    elseif f < 22 then
        bx, bsx, bsy, ba = seg(f, 18, 21, 889.9, 800), 3, 1.04, 0.85
    elseif f < 33 then
        bx, bsx, bsy, ba = seg(f, 22, 32, 768.8, 456), seg(f, 22, 32, 2.909, 2), seg(f, 22, 32, 1.036, 1), seg(f, 22, 32, 0.77, 0)
    end
    if bx then self:mid(v .. "_band", bx, band_y, bsx, bsy, ba) end
    -- line and text
    local lx, lsx = 812, 1
    local tx, ts, ta = 595, 1, 1
    if f < 18 then
        lx, lsx = ease_out(f, 5, 17, 1280, 812), seg(f, 5, 17, 0.004, 1)
    elseif f >= 43 then
        lx, lsx = seg(f, 43, 52, 812, 1280), seg(f, 43, 52, 1, 0.004)
    end
    if f < 17 then
        tx, ts = ease_out(f, 5, 16, 1000, 595), 1.6
    elseif f < 20 then
        ts = seg(f, 17, 19, 1.4, 1)
    elseif f >= 33 and f < 43 then
        -- text breathes 1 -> .95 -> 1 over the first 20 frames of the loop
        local lf = (f - 33) % 20
        ts = lf < 10 and seg(lf, 0, 9, 1, 0.95) or seg(lf, 10, 19, 0.95, 1)
    elseif f >= 43 then
        tx, ta = ease_in(f, 43, 53, 595, 200), seg(f, 43, 53, 1, 0)
    end
    local line_a = 1
    if f >= 33 and f < 43 then line_a = lerp(1, 0.8, 0.5 - 0.5 * math.cos(hold_ms / 650 * math.pi)) end
    self:mid(v .. "_line", lx, line_y, lsx, 1, line_a)
    -- shockwave copy of the text at 24-32
    if f >= 24 and f < 33 then
        local ws, wa
        if f < 27 then ws, wa = seg(f, 24, 26, 1.05, 1.179), seg(f, 24, 26, 1, 0.742)
        elseif f < 31 then ws, wa = seg(f, 27, 30, 1.243, 1.436), seg(f, 27, 30, 0.613, 0.23)
        else ws, wa = 1.5, 0.102 end
        self:mid(v .. "_text", 595, text_y, ws, ws, wa)
    end
    if ta > 0 then self:mid(v .. "_text", tx, text_y, ts, ts, ta) end
end

function WaiwaiGame:update(ms, state)
    local now = tex.get_current_ms()
    if not self.started and ms >= 0 then
        self.started = now
        self:cut_in("breath")
    end
    if state == 1 and not self.ended then self.ended = now end
end

function WaiwaiGame:draw(ms)
    local now = tex.get_current_ms()
    if self.title then tex.draw_texture(self.title, {}) end
    self:draw_gauge(now)
    if self.started then
        local f = (now - self.started) / F
        if f < 58 then
            tex.draw_texture(self.start_frames, { frame = math.min(28, math.floor(f / 2)), blend = "additive" })
        end
    end
    if self.cut then
        local t = now - self.cut.t0
        local f = cut_frame(t)
        if f < 54 then
            for _, set in ipairs(SETS) do self:draw_cut_set(self.cut.v, set, f, math.max(0, t - 28 * F)) end
        else
            self.cut = nil
        end
    end
    if self.ended then
        local f = (now - self.ended) / F
        if f < 56 then
            tex.draw_texture(self.clear_frames, { frame = math.min(27, math.floor(f / 2)), blend = "additive" })
        end
    end
end
