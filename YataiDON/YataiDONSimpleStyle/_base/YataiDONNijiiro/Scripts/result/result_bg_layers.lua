-- Animated 1P result backdrop: sky halves, Mt Fuji and drifting cloud bars, plus
-- a white header band, all driven by the exported result_bg timeline.

local anim = require("anim/sampler")

local ResultBgLayers = {}
ResultBgLayers.__index = ResultBgLayers

local LOOP    = 720          -- frames, sprite 83 / 87
local FUJI_LOOP = 90         -- frames, huji_1p_l_mc (sprite 86), clear state only
local MS_TO_F = 0.06         -- 60 fps

-- depth, cloud texture index, y, scale (|sx| == sy for every one of them), mirror, source width
-- (only a mirrored layer needs it -- and for both of those the base and clear bakes are the same
-- width), arcade track name, frame-0 tx, frame-0 alpha
local LAYERS = {
    { 3,  0,  162.60, 1.0,  false, 592, "#67@3",  1705.70, 0 },
    { 4,  1,  905.25, 1.0,  false, 960, "#69@4",  1240.00, 0 },
    { 5,  1,  934.00, 1.2,  true,  960, "#69@5",  1106.30, 0 },
    { 6,  2,  622.00, 1.0,  false, 840, "#71@6",  1382.90, 1 },
    { 7,  3,  873.25, 1.0,  false, 824, "#73@7",  -272.10, 1 },
    { 8,  4,  873.25, 1.0,  false, 800, "#75@8",   668.65, 0 },
    { 9,  5,  595.25, 1.0,  false, 848, "#77@9",   468.00, 0 },
    { 10, 6,  -17.70, 1.0,  false, 616, "#79@10", 1645.00, 1 },
    { 11, 2,   75.10, 0.6,  true,  840, "#71@11",  346.40, 0 },
    { 12, 6,  214.30, 1.0,  false, 616, "#79@12",  767.80, 1 },
    { 13, 7,  400.75, 1.0,  false, 600, "#81@13", -190.35, 0 },
}

local FUJI_X       = 583.00      -- shape 65, base
local FUJI_Y       = 280.00
local FUJI_CLEAR_X = 584.65      -- shape 84 inside huji_1p_l_mc, clear
local FUJI_H       = 800
local FUJI_TRACK   = "huji_1p_l_mc/#84@0"

function ResultBgLayers.new(player_num)
    local self = setmetatable({}, ResultBgLayers)
    self.player_num = player_num
    self.two_player = (player_num == 3)
    self.t0 = nil
    self.fuji_t0 = nil

    if self.two_player then
        -- 2P: single baked plate (no clouds or Fuji) + header
        self.t_bg     = tex.get_texture("result/background/background_2p")
        self.t_header = tex.get_texture("result/background/bg_header")
        return self
    end

    self.t_sky        = tex.get_texture("result/background/background_1p")
    self.t_sky_clear  = tex.get_texture("result/background/bg_sky_clear")
    self.t_fuji       = tex.get_texture("result/background/bg_fuji")
    self.t_fuji_clear = tex.get_texture("result/background/bg_fuji_clear")
    self.t_header     = tex.get_texture("result/background/bg_header")
    self.t_cloud, self.t_cloud_clear = {}, {}
    for i = 0, 7 do
        self.t_cloud[i]       = tex.get_texture("result/background/bg_cloud_" .. i)
        self.t_cloud_clear[i] = tex.get_texture("result/background/bg_cloud_clear_" .. i)
    end

    -- FAIL SOFT: `anim.safe` returns a NULL clip whose readers return nil, so a missing or
    -- malformed table degrades to the LAYERS constants instead of raising.
    self.clip = anim.safe("anim/result_bg")
    self.fuji = anim.safe("anim/result_bg_fuji")
    return self
end

-- arcade frame of the 720-frame loop, from the engine clock
function ResultBgLayers:frame()
    local ms = tex.get_current_ms()
    if not self.t0 then self.t0 = ms end
    return math.fmod((ms - self.t0) * MS_TO_F, LOOP)
end

-- Mt Fuji runs on its own clock, zeroed when the clear state fires.
function ResultBgLayers:fuji_frame(clear)
    if clear <= 0 then
        self.fuji_t0 = nil          -- re-arm: the next clear starts from rest again
        return 0
    end
    local ms = tex.get_current_ms()
    if not self.fuji_t0 then self.fuji_t0 = ms end
    -- monotonic; the sampler parks it on frame 89 (FUJI_LOOP - 1) forever after.
    return (ms - self.fuji_t0) * MS_TO_F
end

local function draw_cloud(id, w, x, y, scale, mirror, a)
    if not id or a <= 0.004 then return end
    local left = mirror and (x - w * scale) or x
    tex.draw_texture(id, {
        x = left, y = y, scale = scale, fade = a,
        mirror = mirror and "horizontal" or nil,
    })
end

-- `fade` multiplies everything (the screen-entry wipe); `clear` is 0..1, the success cross-fade.
function ResultBgLayers:draw(fade, clear)
    fade  = fade or 1.0
    clear = clear or 0.0
    if fade <= 0 then return end

    if self.two_player then
        if self.t_bg then tex.draw_texture(self.t_bg, { fade = fade }) end
        if self.t_header then tex.draw_texture(self.t_header, { fade = fade }) end
        return
    end

    local f = self:frame()

    -- 1. sky.  Base: shape 3 at x=0 and mirrored at x=960.  Clear: shape 5 (gold, a different
    --    atlas) the other way round -- x=960 upright, x=0 mirrored.
    if self.t_sky then
        tex.draw_texture(self.t_sky, { index = 0, fade = fade })
        tex.draw_texture(self.t_sky, { index = 1, fade = fade, mirror = "horizontal" })
    end
    if clear > 0 and self.t_sky_clear then
        tex.draw_texture(self.t_sky_clear, { index = 0, fade = fade * clear })
        tex.draw_texture(self.t_sky_clear, { index = 1, fade = fade * clear, mirror = "horizontal" })
    end

    -- 2. Mt Fuji, pulsing only in the clear state (a 90-frame one-shot, held at the end).
    if self.t_fuji and clear < 1.0 then
        tex.draw_texture(self.t_fuji, { x = FUJI_X, y = FUJI_Y, fade = fade * (1.0 - clear) })
    end
    if clear > 0 and self.t_fuji_clear then
        local ty, sy = self.fuji:at(FUJI_TRACK, self:fuji_frame(clear))
        ty = ty or FUJI_Y
        sy = sy or 1.0
        tex.draw_texture(self.t_fuji_clear, {
            x = FUJI_CLEAR_X, y = ty, y2 = FUJI_H * sy - FUJI_H, fade = fade * clear,
        })
    end

    -- 3. the eleven cloud bars, driven off the one exported table for both states.
    for i = 1, #LAYERS do
        local L = LAYERS[i]
        local idx, y, scale, mirror, w, track = L[2], L[3], L[4], L[5], L[6], L[7]
        local tx, a = self.clip:at(track, f)
        tx = tx or L[8]
        a  = a  or L[9]
        if clear < 1.0 then
            draw_cloud(self.t_cloud[idx], w, tx, y, scale, mirror, fade * a * (1.0 - clear))
        end
        if clear > 0 then
            draw_cloud(self.t_cloud_clear[idx], w, tx, y, scale, mirror, fade * a * clear)
        end
    end

    -- 4. header band, drawn last (above the clouds).
    if self.t_header then tex.draw_texture(self.t_header, { fade = fade }) end
end

return ResultBgLayers
