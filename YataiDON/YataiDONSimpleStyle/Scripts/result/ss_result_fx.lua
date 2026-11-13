-- YataiDONSimpleStyle v2: result celebration effects (result_player.lua + dan_result_draw.lua).
--   * pixel fireworks: a rising shell (3 frames) then a burst (7 frames), 100 ms per frame, frame swaps
--     only, drawn at alpha 1. STATELESS: every launch is a pure function of the reveal clock, so a skip
--     (which moves the clock) shows the right state at once and nothing piles up.
--   * the party loop: after the cheer, a passing mascot alternates cheer / clear every 500 ms with a
--     1-sprite-px hop on each cheer beat (bible 2.7 cadence); the buddy answers on the off beat.
--   * slam(t): the big 3-frame drop (bigger than the 1U-settle stamp drop) for crowns and stamps.
-- All coordinates LOGICAL (1920x1080).
local UI = require("global.ss_ui")
local DEF = require("result.ss_result_def")
local U = UI.U

local FX = {}

local FW_MS = 100
local RISE_F, BURST_F = 3, 7
FX.FW_LIFE = (RISE_F + BURST_F) * FW_MS

-- textures of one screen folder ("result/ss" or "dan_result/ss")
function FX.textures(prefix)
    local t = { rise = tex.get_texture(prefix .. "/fw_rise"), burst = {} }
    for i = 0, DEF.fw_variants - 1 do t.burst[i] = tex.get_texture(prefix .. "/fw_" .. i) end
    return t
end

-- one shell at (cx, cy), `t` ms after its launch, variant v
function FX.shell(tx, t, cx, cy, v)
    if not tx or t < 0 then return end
    local f = math.floor(t / FW_MS)
    local cell = DEF.fw_cell
    if f < RISE_F then
        if tx.rise then
            tex.draw_texture(tx.rise, { frame = f, x = cx, y = cy - cell })
        end
    elseif f < RISE_F + BURST_F then
        local b = tx.burst[v % DEF.fw_variants]
        if b then
            tex.draw_texture(b, { frame = f - RISE_F, x = cx - DEF.fw_r, y = cy - DEF.fw_r })
        end
    end
end

-- a show: `salvo` shells every `gap` ms from t0 over the slots in order, then (period ~= nil) one shell
-- every `period` ms forever, cycling the slots. s = the clock (same base as t0).
function FX.show(tx, s, t0, slots, salvo, gap, period)
    if not s or s < t0 then return end
    local n = #slots
    local function fire(i, at)
        local sl = slots[i % n + 1]
        -- a deterministic 1-step jitter on the U grid so a slot never repeats the same spot
        local dx = ((i * 7) % 3 - 1) * 4 * U
        local dy = ((i * 5) % 3 - 1) * 3 * U
        FX.shell(tx, s - at, sl[1] + dx, sl[2] + dy, i)
    end
    for i = 0, salvo - 1 do
        local at = t0 + i * gap
        if s >= at and s - at < FX.FW_LIFE then fire(i, at) end
    end
    if period then
        local base = t0 + salvo * gap
        if s >= base then
            local k = math.floor((s - base) / period)
            for j = math.max(0, k - 1), k do
                local at = base + j * period
                if s - at < FX.FW_LIFE then fire(salvo + j, at) end
            end
        end
    end
end

-- the party loop frame for a mascot `t` ms into the loop; off = true answers on the off beat.
-- Returns the expression and calls m:hop() once on every cheer beat.
function FX.party(m, t, off)
    if t < 0 then return nil end
    local beat = math.floor(t / 500) + (off and 1 or 0)
    local cheer = beat % 2 == 0
    if cheer and m._party_beat ~= beat then
        m._party_beat = beat
        m:hop()
    end
    return cheer and "cheer" or "clear"
end

-- the slam: 3 frames of 50 ms from `h` above, a 2U overshoot, then rest. nil before the event.
function FX.slam(t, h)
    if t < 0 then return nil end
    h = h or 30 * U
    if t < 50 then return -h end
    if t < 100 then return -UI.grid(h * 0.4) end
    if t < 150 then return 2 * U end
    return 0
end

-- the landing ring: a rectangle outline (w x h around the box) stepping out 2 frames, alpha 1
function FX.ring(x, y, w, h, t, c)
    if t < 0 or t >= 100 then return end
    local o = (t < 50) and 2 * U or 5 * U
    local th = (t < 50) and 2 * U or U
    x, y, w, h = x - o, y - o, w + 2 * o, h + 2 * o
    UI.rect(x, y, w, th, c)
    UI.rect(x, y + h - th, w, th, c)
    UI.rect(x, y + th, th, h - 2 * th, c)
    UI.rect(x + w - th, y + th, th, h - 2 * th, c)
end

-- the glint sweep over a bar (x, y, w, h): two paper columns crossing it in 12 steps of 50 ms, then a
-- rest; one pass every `period` ms. Draw it between the bar's fill and its text.
function FX.glint(x, y, w, h, t, period)
    if t < 0 then return end
    local step = math.floor((t % (period or 1600)) / 50)
    if step >= 12 then return end
    local span = w + 6 * U
    local gx = x - 6 * U + UI.grid(span * step / 11)
    local function col(cx, cw)
        local a, b = math.max(x, cx), math.min(x + w, cx + cw)
        if b > a then UI.rect(a, y, b - a, h, UI.P.paper) end
    end
    col(gx, 2 * U)
    col(gx + 4 * U, U)
end

return FX
