-- YataiDONSimpleStyle v2 (polish): the small shared effects of the front screens (title loop + entry).
--   Clouds: the sky band's pixel clouds drift right, 1U every 150 ms (steady), wrapping at the screen
--     edges. Positions come from the absolute clock, so the warning <-> attract switch never moves them.
--   Pops: a small don / ka note jumps off the drum on a hit: 5 positions, 50 ms each (250 ms), then gone.
--     Events only (bible: no static sparkles); drawn at alpha 1.
-- Textures (ss/v2_front.py add_fx): <screen>/ss_front/cloud_m, cloud_s, pop (frame 0 don, 1 ka).
-- Logical 1920x1080.
local UI = require("global.ss_ui")

local U = UI.U
local FX = {}

-- ---------------------------------------------------------------- drifting clouds
local Clouds = {}
Clouds.__index = Clouds
FX.Clouds = Clouds

local STEP_MS = 150                     -- one 1U step every 150 ms (20 px/s)

-- screen: "title" | "entry"; list: { { x, y, "M" | "S" }, ... } (positions at clock 0)
function Clouds.new(screen, list)
    local self = setmetatable({}, Clouds)
    self.t = { M = tex.get_texture(screen .. "/ss_front/cloud_m"), S = tex.get_texture(screen .. "/ss_front/cloud_s") }
    self.w = { M = 162, S = 108 }
    self.list = list
    return self
end

function Clouds:draw(now)
    local sw = 1920
    local shift = math.floor(now / STEP_MS) * U
    for _, c in ipairs(self.list) do
        local t = self.t[c[3]]
        if t then
            local w = self.w[c[3]]
            local span = sw + w
            local x = (c[1] + w + shift) % span - w      -- wraps: leaves on the right, enters on the left
            tex.draw_texture(t, { x = x, y = c[2] })
        end
    end
end

-- ---------------------------------------------------------------- note pops
local Pops = {}
Pops.__index = Pops
FX.Pops = Pops

local POP_MS = 50
local POP_D = 36                         -- the pop texture's logical size (2 * (POP_R + 1) * U)
local DX = { 0, 9, 18, 24, 27 }          -- per 50 ms step, outward (decelerating, whole U)
local DY = { 0, -24, -42, -54, -60 }

function Pops.new(screen)
    local self = setmetatable({}, Pops)
    self.t = tex.get_texture(screen .. "/ss_front/pop")
    self.live = {}
    return self
end

-- kind 0 don (red), 1 ka (blue); x, y = the centre at launch; dir -1 left / 1 right
function Pops:emit(kind, x, y, dir, now)
    local l = self.live
    if #l >= 6 then table.remove(l, 1) end
    l[#l + 1] = { kind = kind, x = x, y = y, dir = dir, t0 = now }
end

function Pops:draw(now)
    if not self.t then return end
    local keep = {}
    for _, p in ipairs(self.live) do
        local f = math.floor((now - p.t0) / POP_MS) + 1
        if f >= 1 and f <= #DY then
            tex.draw_texture(self.t, { frame = p.kind, x = math.floor(p.x + p.dir * DX[f] - POP_D / 2),
                                       y = math.floor(p.y + DY[f] - POP_D / 2) })
            keep[#keep + 1] = p
        elseif f < 1 then
            keep[#keep + 1] = p
        end
    end
    self.live = keep
end

function Pops:clear() self.live = {} end

return FX
