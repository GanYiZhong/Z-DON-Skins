-- Arcade control_guide panel (plate + drum + sticks), drawn from the layered Lumen clip
-- (control_guide.nulm sprite 88). Shared by Indicator, entry and song_select.

local sampler = require("anim/sampler")
local clip = sampler.load("anim/guide_layers")

local PILL_TEX, PILL_W, PILL_H = "guide_57", 216, 72   -- the 決定 pill (guide_65 is its blink); label is skin text
local BLINK_TEX = "guide_65"
-- Large guide (control_guide sprite 48 in sprite 90's `center` state): the same motion as sprite 88 at twice the
-- size, so the small layer tracks are reused doubled with the 2x crops in global/guide_large. Sprite-88 space is
-- the small crop space shifted by (-167, -151); sprite 48 sits at (0, 40) in sprite 90 at the screen centre.
-- upstream's guide_large art (d472f9f) is not on its LFS server yet: the large guide stays off until the files exist
local HAS_LARGE = false   -- set true once Graphics/global/guide_large has its art and texture.json
local LARGE_ORIGIN_X, LARGE_ORIGIN_Y = -167, -151
local LARGE_CX, LARGE_CY = 960, 580
local LARGE_BLINK_PAD = 8   -- the large blink crop (c24) is 448x160, 8 px wider each side than 2x guide_65
local ARCADE_FPS = 60
local ALL_LEN, DECIDE_START, DECIDE_LEN = 420, 420, 230   -- Lumen loops: both sticks, then 決定

GuidePanel = {}
GuidePanel.__index = GuidePanel
GuidePanel.has_large = HAS_LARGE

GuidePanel.Loop = { ALL = 1, DECIDE = 2 }

function GuidePanel.new()
    local self  = setmetatable({}, GuidePanel)
    self.plate  = tex.get_texture("global/indicator/guide_plate")
    self.layers = {}
    for i, path in ipairs(clip.order) do
        local m = clip.meta[path]
        self.layers[i] = { path = path, tex = tex.get_texture("global/indicator/" .. m.tex),
                           large = HAS_LARGE and tex.get_texture("global/guide_large/" .. m.tex) or nil,
                           mirror = m.mirror and "horizontal" or "none", pill = (m.tex == PILL_TEX),
                           pad = (m.tex == BLINK_TEX) and LARGE_BLINK_PAD or 0 }
    end
    self.t0     = tex.get_current_ms()
    self.decide = text.create_raw_text(tex.skin_text("guide_decide_label"), 24, { 30, 30, 30, 255 },
                                       { 30, 30, 30, 255 }, false, 0, 1.0, "FOT-Seurat_Pro_B.otf")
    return self
end

function GuidePanel:frame(loop)
    local f = (tex.get_current_ms() - self.t0) * ARCADE_FPS / 1000
    if loop == GuidePanel.Loop.ALL then
        return f % ALL_LEN
    end
    return DECIDE_START + f % DECIDE_LEN
end

function GuidePanel:draw(loop, x, y, fade)
    local f = self:frame(loop)
    x, y, fade = x or 0, y or 0, fade or 1.0
    tex.draw_texture(self.plate, { x = x, y = y, fade = fade })
    for _, l in ipairs(self.layers) do
        local tx, ty, sc, rot, a = clip:at(l.path, f)
        if a and a > 0.002 then
            tex.draw_texture(l.tex, { x = x + tx, y = y + ty, scale = sc, rotation = rot,
                                      origin = { 0, 0 }, mirror = l.mirror, fade = a * fade })
            if l.pill then
                self.decide:draw({ x = x + tx + PILL_W / 2 - self.decide.width / 2,
                                   y = y + 12 + ty + PILL_H / 2 - self.decide.height / 2, fade = a * fade })
            end
        end
    end
end

-- the drum and sticks of the large guide, scaled by `scale` about its origin (the panel is drawn by the caller)
function GuidePanel:draw_large(loop, scale, fade)
    local f = self:frame(loop)
    if not self.decide_large then
        self.decide_large = text.create_raw_text(tex.skin_text("guide_decide_label"), 48, { 30, 30, 30, 255 },
                                                 { 30, 30, 30, 255 }, false, 0, 1.0, "FOT-Seurat_Pro_B.otf")
    end
    for _, l in ipairs(self.layers) do
        local tx, ty, sc, rot, a = clip:at(l.path, f)
        if a and a > 0.002 and l.large then
            local k = 2 * scale
            local px = LARGE_CX + k * (tx + LARGE_ORIGIN_X)
            local py = LARGE_CY + k * (ty + LARGE_ORIGIN_Y)
            tex.draw_texture(l.large, { x = px - l.pad * sc * scale, y = py - l.pad * sc * scale, scale = sc * scale,
                                        rotation = rot, origin = { 0, 0 }, mirror = l.mirror, fade = a * fade })
            if l.pill then
                local d = self.decide_large
                d:draw({ x = px + k * PILL_W / 2 - d.width / 2, y = py + k * PILL_H / 2 - d.height / 2, fade = a * fade })
            end
        end
    end
end

return GuidePanel
