local M = {}

M.DURATION_MS = 2000

local function T(name)
    return tex.get_texture("song_select/oni_open/" .. name)
end

local function G(name)
    return tex.get_texture("song_select/global/" .. name)
end

local function lerp(a, b, u)
    return a + (b - a) * u
end

local function clamp01(u)
    return math.max(0, math.min(1, u))
end

local function seg(f, f0, f1, ease)
    local u = clamp01((f - f0) / (f1 - f0))
    if ease == "in" then
        return u * u
    elseif ease == "out" then
        return 1 - (1 - u) * (1 - u)
    end
    return u
end

local function draw_centred(t, w, h, sx, sy, rot, alpha, xo, frame)
    if not t or alpha <= 0 then return end
    tex.draw_texture(t, {
        frame = frame or 0,
        x = xo + w / 2, y = h / 2,
        x2 = w * (sx - 1), y2 = h * (sy - 1),
        origin = { w * sx / 2, h * sy / 2 },
        rotation = rot or 0,
        fade = alpha,
    })
end

local function glow(f, xo)
    if f < 1 or f > 118 then return end
    local s, a
    if f <= 10 then
        local u = seg(f, 1, 10, "out")
        s, a = lerp(2.174, 2.712, u), lerp(0, 0.3, u)
    elseif f <= 90 then
        s, a = lerp(2.712, 2.935, seg(f, 10, 90)), 0.3
    else
        local u = seg(f, 90, 118, "out")
        s, a = lerp(2.935, 3.19, u), lerp(0.3, 0, u)
    end
    draw_centred(T("glow"), 184, 184, s, s, 0, a, xo)
end

local function porthole(f, xo)
    if f < 1 or f > 118 then return end
    local s, a = 1, 0.488
    if f <= 20 then
        local u = seg(f, 1, 20, "in")
        s, a = lerp(1.2, 1, u), lerp(0, 0.488, u)
    elseif f > 110 then
        a = lerp(0.488, 0, seg(f, 110, 118))
    end
    draw_centred(T("porthole"), 360, 360, s, s, 0, a, xo)
end

-- sprite 567: tomoe spins one turn in 40 frames while its white copy fades out
local function tomoe_angle(t)
    if t <= 10 then return 90 * seg(t, 0, 10, "in") end
    if t <= 30 then return 90 + 180 * seg(t, 10, 30) end
    return 270 + 90 * seg(t, 30, 39, "out")
end

local function tomoe(f, xo)
    if f < 6 or f > 119 then return end
    if f <= 35 then
        local u = seg(f, 6, 35, "in")
        local s, a, t = lerp(2, 1, u), u, f - 6
        local rot = tomoe_angle(t)
        draw_centred(T("tomoe"), 360, 360, s, s, rot, a, xo)
        draw_centred(T("tomoe_white"), 360, 360, s, s, rot, a * lerp(1, 0, seg(t, 0, 30)), xo)
        return
    end
    local a = 0.5
    if f > 99 then a = lerp(0.477, 0, seg(f, 99, 119)) end
    draw_centred(T("tomoe"), 360, 360, 1, 1, 0, a, xo)
end

local function flames(f, xo)
    if f < 36 or f > 119 then return end
    local x, y, sx, sy, a
    if f <= 53 then
        local u = seg(f, 36, 53, "out")
        x, y = lerp(93.6, 7.45, u), lerp(-20, -428.75, u)
        sx, sy, a = lerp(1.8, 3.594, u), lerp(1.8, 3.993, u), lerp(0, 0.398, u)
    elseif f <= 69 then
        local u = seg(f, 53, 69, "in")
        x, y, sx, sy, a = 7.2, lerp(-430, -350, u), 3.6, lerp(4, 3.6, u), 0.398
    elseif f <= 89 then
        x, y, sx, sy, a = 7.2, -350, 3.6, 3.6, 0.398
    else
        local u = seg(f, 89, 119)
        x, y = lerp(7.4, 12.5, u), lerp(-358, -587.15, u)
        sx, sy, a = lerp(3.596, 3.491, u), lerp(3.629, 4.471, u), lerp(0.387, 0, u)
    end
    tex.draw_texture(T("flame"), {
        frame = math.floor((f - 36) / 4) % 12,
        x = xo + x, y = y,
        x2 = 96 * (sx - 1), y2 = 200 * (sy - 1),
        fade = a,
    })
end

function M.draw(elapsed_ms, xo)
    local f = elapsed_ms * 60 / 1000
    glow(f, xo)
    if f >= 110 then
        tex.draw_texture(G("background_diff"), { frame = 3, x = xo, fade = lerp(0, 0.5, seg(f, 110, 119)) })
    end
    porthole(f, xo)
    tomoe(f, xo)
    flames(f, xo)
    if f >= 36 and f <= 99 then
        local a = f <= 52 and lerp(0, 0.6, seg(f, 36, 52)) or lerp(0.6, 0, seg(f, 52, 99))
        tex.draw_texture(G("background_diff_highlight"), { frame = 3, x = xo, fade = a })
    end
    if f >= 35 and f <= 118 then
        local a = f <= 98 and seg(f, 35, 98) or lerp(1, 0, seg(f, 98, 118))
        draw_centred(T("oni_line"), 360, 360, 1, 1, 0, a, xo)
    end
end

return M
