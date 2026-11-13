-- Ranking panel (Lumen enso_result sprite 351): top 3 local scores for the chart, shown only when
-- this play placed. Its row loops a white flash and two sparkles (sprite 318 'jump').
ResultRanking = {}
ResultRanking.__index = ResultRanking

local S = tex.get_screen_scale()
local FRAME_MS = 1000 / 60
local ROW_DY = { 0, 70, 144 }        -- bar tops below row 1
local BADGE_DY = { 0, 1, 0 }
local ROW_DELAY = { 217, 150, 83 }   -- rows rise bottom first
local DIGITS, DIGIT_PITCH = 7, 17
local NAME_X, NAME_Y, NAME_W = 56, 7, 140
local SPARKLE_DX, SPARKLE_DY = 212, 54

local function ease_out(u) return 1 - (1 - u) * (1 - u) end
local function clamp01(u) return math.max(0, math.min(1, u)) end

function ResultRanking.new(ranking, difficulty, is_2p)
    if not ranking or not ranking.entries or ranking.rank_in == nil or ranking.rank_in < 0 then return nil end
    local self = setmetatable({}, ResultRanking)
    self.idx = is_2p and 1 or 0
    self.diff = math.max(0, math.min(difficulty, 4))
    self.rank_in = ranking.rank_in + 1
    self.rows = {}
    for i = 1, 3 do
        local e = ranking.entries[i]
        if e then
            self.rows[i] = {
                score = tostring(math.floor(e.score)),
                name = text.create_raw_text(e.name, math.floor(18 * S), { 0, 0, 0, 255 }, { 0, 0, 0, 0 }, false, 0),
            }
        end
    end
    self.t_panel = tex.get_texture("result/ranking/panel")
    self.t_bar = tex.get_texture("result/ranking/bar")
    self.t_badge = tex.get_texture("result/ranking/badge")
    self.t_digits = tex.get_texture("result/ranking/digits")
    self.t_unit = tex.get_texture("result/ranking/unit")
    self.t_flash = tex.get_texture("result/ranking/flash")
    self.t_sparkle = tex.get_texture("result/ranking/sparkle")
    return self
end

function ResultRanking:update(current_ms)
    self.t0 = self.t0 or current_ms
    self.t = current_ms - self.t0
end

-- panel: 0.8 -> 1.05 with a fade-in (100 ms ease-out), back to 1.0 (83 ms ease-in)
function ResultRanking:panel_scale()
    local t = self.t
    if t < 100 then return 0.8 + 0.25 * ease_out(t / 100), t / 100 end
    local u = clamp01((t - 100) / 83)
    return 1.05 - 0.05 * u * u, 1
end

-- row: rises from +23.65 to 12 px above rest (150 ms ease-out, fading in), settles (133 ms ease-in)
function ResultRanking:row_offset(i)
    local t = self.t - ROW_DELAY[i]
    if t < 0 then return 0, 0 end
    if t < 150 then
        local u = ease_out(t / 150)
        return 23.65 - 35.65 * u, 0.191 + 0.809 * u
    end
    local u = clamp01((t - 150) / 133)
    return -12 + 12 * u * u, 1
end

-- sparkle (sprite 317, 30 frames): grows 0.2 -> 0.8, then 0.83 -> 1.2 fading out
local function sparkle(s)
    if s < 15 then return 0.2 + 0.6 * s / 15, 1 end
    local u = (s - 15) / 15
    return 0.827 + 0.373 * u, 0.934 * (1 - u)
end

function ResultRanking:draw_jump(dy, fade)
    -- 'jump' starts at frame 10 of a 70-frame loop
    local f = math.fmod(self.t / FRAME_MS + 10, 70)
    if f < 10 then return end
    local flash = f <= 40 and (f - 10) / 30 or 0.965 * (1 - (f - 41) / 28)
    tex.draw_texture(self.t_flash, { y = dy, fade = clamp01(flash) * fade, index = self.idx })
    local second = f >= 40
    local scale, alpha = sparkle(second and f - 40 or f - 10)
    local sy = second and SPARKLE_DY or 0
    for side = 0, 1 do
        tex.draw_texture(self.t_sparkle, {
            x = side * SPARKLE_DX * S, y = dy + (side == 1 and SPARKLE_DY - sy or sy) * S,
            scale = scale, center = true, fade = alpha * fade, index = self.idx,
        })
    end
end

function ResultRanking:draw()
    if not self.t or not self.t_panel then return end
    local scale, panel_fade = self:panel_scale()
    tex.draw_texture(self.t_panel, { frame = self.diff, scale = scale, center = true, fade = panel_fade, index = self.idx })

    for i = 3, 1, -1 do
        local off, fade = self:row_offset(i)
        if fade > 0 then
            local dy = (ROW_DY[i] + off) * S
            tex.draw_texture(self.t_bar, { frame = i - 1, y = dy, fade = fade, index = self.idx })
            if i == self.rank_in then self:draw_jump(dy, fade) end
            tex.draw_texture(self.t_badge, { frame = (i - 1) * 5 + self.diff, y = dy + BADGE_DY[i] * S, fade = fade, index = self.idx })
            local row = self.rows[i]
            if row then
                local str = row.score
                for k = 1, #str do
                    local d = tonumber(str:sub(k, k)) or 0
                    tex.draw_texture(self.t_digits, {
                        frame = d, x = (DIGITS - #str + k - 1) * DIGIT_PITCH * S, y = dy, fade = fade, index = self.idx,
                    })
                end
                tex.draw_texture(self.t_unit, { y = dy, fade = fade, index = self.idx })
                local info = tex.get_texture_info("ranking", "bar")
                if info then
                    local w = math.min(row.name.width, NAME_W * S)
                    row.name:draw({
                        x = info.x[self.idx + 1] + NAME_X * S, y = info.y[self.idx + 1] + NAME_Y * S + dy,
                        x2 = w - row.name.width, fade = fade,
                    })
                end
            end
        end
    end
end
