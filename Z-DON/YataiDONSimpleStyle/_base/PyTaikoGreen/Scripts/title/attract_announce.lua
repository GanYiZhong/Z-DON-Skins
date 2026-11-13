AttractAnnounce = {}
AttractAnnounce.__index = AttractAnnounce

local S = tex.get_screen_scale()
local DIR = "title/announce"
local F = 1000 / 60
local CYCLE_F = 180
local DON_TOP, DON_ANCHOR = 541, 661 -- the don squashes about its placement origin, below the art

local function ease_in(u) return u * u end
local function ease_out(u) return 1 - (1 - u) * (1 - u) end
local function lerp(a, b, u) return a + (b - a) * u end
local function ramp(f, at, len) return math.max(0, math.min(1, (f - at) / len)) end

-- hop of the don (90 f, twice per cycle): y-scale and lift
local function don_hop(f)
    if f < 8 then return lerp(1, 0.925, ease_in(f / 7)), 0 end
    if f < 15 then local u = ease_out((f - 8) / 6) return lerp(0.945, 1, u), lerp(-1.55, -5.9, u) end
    if f < 30 then return 1, lerp(-6.7, -18, (f - 15) / 14) end
    if f < 50 then local u = ease_in((f - 30) / 19) return lerp(1, 0.916, u), lerp(-17.95, 0, u) end
    if f < 60 then return lerp(0.932, 1, ease_out((f - 50) / 9)), 0 end
    return 1, 0
end

-- caption alpha: fades in 20 f, holds, fades out 20 f within its 90 f half
local function caption_fade(f) return ramp(f, 0, 19) * (1 - ramp(f, 70, 20)) end

-- mode: "campaign" | "tournament"
function AttractAnnounce.new(mode)
    local self = setmetatable({}, AttractAnnounce)
    self.mode = mode
    self.tex = {}
    for _, key in ipairs({ "campaign_plate", "campaign_don", "campaign_text_0", "campaign_text_1", "taikai_kit" }) do
        local id = tex.get_texture(DIR .. "/" .. key) -- loads the folder, so before the info lookup
        local info = tex.get_texture_info(DIR:match("[^/]+$"), key) -- textures are keyed by their own folder
        self.tex[key] = { id = id, h = info and info.y2[1] or 0 }
    end
    self.t0 = nil
    self.f = 0
    return self
end

function AttractAnnounce:update(current_ms)
    self.t0 = self.t0 or current_ms
    self.f = ((current_ms - self.t0) / F) % CYCLE_F
end

function AttractAnnounce:draw(fade)
    fade = fade or 1
    local tx = self.tex
    if self.mode == "tournament" then
        tex.draw_texture(tx.taikai_kit.id, { fade = fade })
        return
    end
    tex.draw_texture(tx.campaign_plate.id, { fade = 0.488 * fade })
    local half = self.f % 90
    local sy, dy = don_hop(half)
    local don = tx.campaign_don
    tex.draw_texture(don.id, {
        y = (DON_ANCHOR - (DON_ANCHOR - DON_TOP) * sy - DON_TOP + dy) * S, y2 = don.h * (sy - 1), fade = fade,
    })
    local text = self.f < 90 and tx.campaign_text_0 or tx.campaign_text_1
    tex.draw_texture(text.id, { fade = caption_fade(half) * fade })
end
