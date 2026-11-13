-- Plays a cabinet movie's sprite from its own data: one small image per shape and a row per movie frame for each
-- placement (Scripts/global/ai_fx_*.lua, generated). Between two movie frames everything is interpolated, so an
-- effect runs at the display's rate and costs a handful of small textures instead of hundreds of baked frames.
local M = {}

-- def: the data; frame: movie frame (fractional); get(name) -> { t = texture, w, h } or nil
-- ox, oy: the sprite's origin on the screen; s: scale; fade: multiplies every alpha
-- only: optional function(name) -> true for the pieces to draw (lettering between them, as the movie's depths)
function M.draw(def, frame, get, ox, oy, s, fade, only)
    s, fade = s or 1, fade or 1
    local i0 = math.floor(frame)
    local u = frame - i0
    for _, p in ipairs(def.pieces) do
        local idx = i0 - p.f + 1
        local a, c
        if p.static then
            if idx >= 1 and idx <= p.n then a, c = p.r[1], p.r[1] end
        else
            a = p.r[idx]
            c = p.r[idx + 1] or a
        end
        if a and only and not only(p.t) then a = nil end
        if a then
            -- a piece that jumps or flips between two frames is not blended across it
            if math.abs(c[1] - a[1]) + math.abs(c[2] - a[2]) > 120 or (c[4] < 0) ~= (a[4] < 0) then c = a end
            local al = (a[6] + (c[6] - a[6]) * u) * fade
            local t = al > 0.004 and get(p.t)
            if t then
                local sx = a[3] + (c[3] - a[3]) * u
                local sy = a[4] + (c[4] - a[4]) * u
                local rot = a[5] + (((c[5] - a[5] + 180) % 360) - 180) * u
                local bb = p.bb
                local asy = math.abs(sy)
                local ory = ((sy < 0) and bb[4] or -bb[3]) * asy * s
                tex.draw_texture(t.t, { x = ox + s * (a[1] + (c[1] - a[1]) * u), y = oy + s * (a[2] + (c[2] - a[2]) * u),
                                        scale = 0, x2 = (bb[2] - bb[1]) * sx * s, y2 = (bb[4] - bb[3]) * asy * s,
                                        origin = { -bb[1] * sx * s, ory }, rotation = rot, fade = al,
                                        blend = p.a and "additive" or nil, mirror = (sy < 0) and "vertical" or nil })
            end
        end
    end
end

return M
