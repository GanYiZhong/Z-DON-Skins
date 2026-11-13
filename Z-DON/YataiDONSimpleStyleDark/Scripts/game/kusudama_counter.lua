-- YataiDONSimpleStyle v2: the kusudama (engine KusudamaCounter: new(total), update(ms, count),
-- miss(ms), draw(), has_popped(), has_missed(), is_finished(), fx).
-- A pixel kusudama (game/ss_kusudama) drops in over 8 frames, shakes 1U on every hit, its seam opens one
-- cell per sixth of the hits; at the last hit it splits (the halves fly apart and fall), confetti in
-- the course hues rains for a second and two sparkle bursts play. A miss drops the whole ball.
-- Frame-based, integer pixels, no scaling.

local UI = require("global.ss_ui")
local P = UI.P
local U = UI.U

KusudamaCounter = {}
KusudamaCounter.__index = KusudamaCounter

local F = 1000.0 / 60.0
local CX, REST_Y = 960, 342          -- ball centre at rest
local DROP_FRAMES = 8
local POP_MS, MISS_MS = 1100, 25 * F
local CONFETTI = { P.oni, P.easy, P.clear, P.normal, P.hard, P.ura }

local function T(name) return tex.get_texture("game/ss_kusudama/" .. name) end

function KusudamaCounter.new(total)
    local self = setmetatable({}, KusudamaCounter)
    self.total = math.max(1, total)
    self.count = 0
    self.stage = 0
    self.now = nil
    self.t0 = nil
    self.hit_ms = -1e9
    self.is_popped, self.is_missed = false, false
    self.fx = true
    self.t_ball, self.t_l, self.t_r = T("ball"), T("half_l"), T("half_r")
    self.t_digits, self.t_burst = T("digits"), T("burst")
    local bi = tex.get_texture_info("ss_kusudama", "ball")
    self.bw, self.bh = bi and bi.width or 192, bi and bi.height or 222
    return self
end

function KusudamaCounter:miss(current_ms)
    if self.is_popped or self.is_missed then return end
    self.is_missed = true
    self.miss_ms = current_ms
end

function KusudamaCounter:update(current_ms, count)
    self.now = current_ms
    self.t0 = self.t0 or current_ms
    if count ~= self.count then
        if count > self.count then self.hit_ms = current_ms end
        self.count = count
        self.stage = math.min(5, count * 6 // self.total)
        if count >= self.total and not self.is_popped then
            self.is_popped = true
            self.pop_ms = current_ms
        end
    end
end

function KusudamaCounter:has_popped() return self.is_popped end
function KusudamaCounter:has_missed() return self.is_missed end

function KusudamaCounter:is_finished()
    if self.is_missed then return self.now - self.miss_ms >= MISS_MS end
    return self.is_popped and self.now - self.pop_ms >= POP_MS
end

-- ball centre y by frame: drops in from above the screen in whole U steps
function KusudamaCounter:ball_y()
    local f = math.floor((self.now - self.t0) / F)
    if f >= DROP_FRAMES then return REST_Y end
    return REST_Y - (DROP_FRAMES - f) * 18 * U
end

function KusudamaCounter:draw()
    if not self.now then return end
    local by = self:ball_y()
    local bx = CX
    local top_off = self.bh - self.bw / 2 - U    -- the frame's ball centre from its top (cord above)
    if self.is_missed then
        local f = math.floor((self.now - self.miss_ms) / F)
        by = by + f * f * U
    end
    if self.is_popped then
        local f = math.floor((self.now - self.pop_ms) / F)
        -- halves fly apart 4U per frame and fall with gravity
        local dx = math.min(f, 24) * 4 * U
        local dy = math.floor(f * f / 6) * U
        if self.t_l then tex.draw_texture(self.t_l, { x = bx - self.bw / 2 - dx, y = by - top_off + dy }) end
        if self.t_r then tex.draw_texture(self.t_r, { x = bx - self.bw / 2 + dx, y = by - top_off + dy }) end
        -- confetti: 36 squares from the seam, deterministic
        for i = 0, 35 do
            local a = (i * 37) % 360
            local vx = math.cos(math.rad(a)) * (3 + i % 4)
            local vy = -math.abs(math.sin(math.rad(a))) * (4 + i % 3)
            local x = math.floor((bx + vx * f * 2) / U) * U
            local y = math.floor((by + vy * f * 2 + f * f * 0.35) / U) * U
            if f < 60 and y < 1080 then
                UI.rect(x - U, y - U, 4 * U, 4 * U, P.ink)
                UI.rect(x, y, 2 * U, 2 * U, CONFETTI[i % 6 + 1])
            end
        end
        if self.t_burst then
            for k, o in ipairs({ { -120, -60, 0 }, { 120, -30, 8 } }) do
                local t = math.floor((f - o[3]) / 4)
                if t >= 0 and t < 4 then
                    tex.draw_texture(self.t_burst, { frame = t, x = bx + o[1] - 31, y = by + o[2] - 31 })
                end
            end
        end
        return
    end
    local shake = (self.now - self.hit_ms < 2 * F) and U or 0
    if self.t_ball then
        tex.draw_texture(self.t_ball, { frame = self.stage, x = bx - self.bw / 2 + shake, y = by - top_off })
    end
    -- the counter: hits left, over the hint (連打で わろう! in the player's language) on a dialog sized
    -- to the text (16U wider than the words, 20U tall)
    if not self.is_missed then
        local ry = by + self.bw / 2 + 4 * U
        local t = UI.text_key("kusudama_hint", 36, "ink")
        local rw = math.floor(((t and t.width - 2 * UI.text_pad(t) or 0) + 16 * U) / U) * U
        local rx = math.floor((CX - (rw + 2 * U) / 2) / U) * U
        UI.chrome.dialog(rx, ry + 30 * U, rw, 20 * U)
        UI.draw_text(t, rx + rw / 2, ry + 30 * U + 10 * U, "c")
        local left = tostring(math.max(0, self.total - self.count))
        local dw = 21 * U
        local x0 = math.floor((CX - #left * dw / 2) / U) * U
        for i = 1, #left do
            tex.draw_texture(self.t_digits, { frame = left:byte(i) - 48, x = x0 + (i - 1) * dw, y = ry })
        end
    end
end
