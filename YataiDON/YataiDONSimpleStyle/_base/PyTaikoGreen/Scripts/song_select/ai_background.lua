local M = {}

local LOOP = 460
local SHEET_PIVOT = { 367, 88 } -- the sheet turns about a point off its centre
local SPARKLE_PIVOT = { 53, 53 }
local TRIANGLE_PIVOT = { 72, 62 }

local SPARKLE_PULSE = { period = 240, low = 0.7 }
local TRIANGLE_PULSE = { period = 120, low = 0.75 }

local SHAPES = {
    { key = "shapes", pivot = SHEET_PIVOT, add = true, f = { 0, 364 }, x = { 825, 970 }, y = { 538, 232 }, a = { 0, 0.83 }, rot = { 0, -13 } },
    { key = "shapes", pivot = SHEET_PIVOT, add = true, f = { 364, 438 }, x = { 970, 989 }, y = { 232, 192 }, a = { 0.83, 0 }, rot = { -13, -15 } },
    { key = "sparkle", pivot = SPARKLE_PIVOT, pulse = SPARKLE_PULSE, add = true, f = { 0, 459 }, x = { -57, 325 }, y = { 344, 154 }, a = { 0, 1 }, rot = { 0, 360 } },
    { key = "shapes", pivot = SHEET_PIVOT, add = true, f = { 0, 316 }, x = { 597, 682 }, y = { 356, 135 }, a = { 0, 1 }, rot = { 0, 0 } },
    { key = "triangle_pattern", pivot = TRIANGLE_PIVOT, pulse = TRIANGLE_PULSE, add = true, f = { 0, 381 }, x = { -52, 152 }, y = { 563, 117 }, a = { 0, 1 }, rot = { 0, 360 } },
    { key = "triangle_white", pivot = TRIANGLE_PIVOT, f = { 180, 459 }, x = { 918, 1075 }, y = { 558, 187 }, a = { 1, 0 }, rot = { 0, 360 } },
    { key = "sparkle", pivot = SPARKLE_PIVOT, pulse = SPARKLE_PULSE, f = { 82, 459 }, x = { 489, 713 }, y = { 401, 140 }, a = { 0, 1 }, rot = { 0, 720 } },
    { key = "sparkle", pivot = SPARKLE_PIVOT, pulse = SPARKLE_PULSE, add = true, f = { 16, 327 }, x = { 1092, 1354 }, y = { 548, 350 }, a = { 1, 1 }, rot = { 0, 360 } },
}

local function lerp(range, t) return range[1] + (range[2] - range[1]) * t end

-- Triangle wave from 1 down to `low` and back over `period` frames.
local function pulse(frame, period, low)
    local t = math.abs(2 * (frame % period) / period - 1)
    return low + (1 - low) * t
end

function M.new()
    tex.load_folder("song_select", "ai_battle")
    local id = {}
    local function texture(key)
        id[key] = id[key] or tex.get_texture("song_select/ai_battle/" .. key)
        return id[key]
    end

    return function()
        local frame = (tex.get_current_ms() * 0.06) % LOOP
        tex.draw_texture(texture("background"))
        tex.draw_texture(texture("background_overlay"), { fade = pulse(frame, 240, 0.35) })
        for _, s in ipairs(SHAPES) do
            if frame >= s.f[1] and frame <= s.f[2] then
                local t = (frame - s.f[1]) / (s.f[2] - s.f[1])
                local fade = lerp(s.a, t)
                if s.pulse then fade = fade * pulse(frame - s.f[1], s.pulse.period, s.pulse.low) end
                tex.draw_texture(texture(s.key), {
                    x = lerp(s.x, t), y = lerp(s.y, t), origin = s.pivot, rotation = lerp(s.rot, t),
                    fade = fade, blend = s.add and "additive" or nil,
                })
            end
        end
        tex.draw_texture(texture("background_overlay_2"))
    end
end

return M
