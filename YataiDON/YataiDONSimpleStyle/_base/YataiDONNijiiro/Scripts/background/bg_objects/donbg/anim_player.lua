-- Cabinet-faithful donbg band player.
-- Data: background/bg_data/donbg_anim/a_NN_Mp.lua; textures: donbga_NN_Mp/s<c>.png.
local DonBGAnim = {}
DonBGAnim.__index = DonBGAnim

local FRAME_MS = 1000.0 / 60.0   -- the band steps at 60 Hz
local ONE = string.byte("1")

-- name: a collab band ("b_001_1p": bg_data/donbg_anim/b_001_1p.lua, donbga_b_001_1p/);
-- nil for the default band picked by index
function DonBGAnim.new(index, player_num, path, name)
    local subset = name and ("donbga_" .. name) or string.format("donbga_%02d_%dp", index, player_num)
    name = name or string.format("a_%02d_%dp", index, player_num)
    local ok, data = pcall(require, "background/bg_data/donbg_anim/" .. name)
    if not ok or type(data) ~= "table" or not (data.normal or data.top) then return nil end
    local self = setmetatable({}, DonBGAnim)
    self.name = name
    self.path = path
    self.subset = subset
    tex.load_folder(path, self.subset)
    self.data = data
    self.ids = {}
    self.elapsed = 0
    self.last_ms = nil
    return self
end

function DonBGAnim:id_of(shape)
    local id = self.ids[shape]
    if id == nil then
        id = tex.get_texture(self.path .. "/" .. self.subset .. "/s" .. shape) or false
        self.ids[shape] = id
    end
    return id or nil
end

function DonBGAnim:update(current_ms)
    if self.last_ms then
        local dt = current_ms - self.last_ms
        if dt > 0 and dt < 500 then self.elapsed = self.elapsed + dt end
    end
    self.last_ms = current_ms
end

local ch = require("background/bg_objects/packed_channel")   -- number, per-frame table or packed string

-- draw one state with a global fade, the band's top-left at (0, y)
function DonBGAnim:draw_state(state, fade, y)
    local list = self.data[state]
    if not list or fade <= 0.002 then return end
    local frame = math.floor(self.elapsed / FRAME_MS)
    local shapes = self.data.shapes
    for k = 1, #list do
        local e = list[k]
        local i = (frame % e.period) + 1
        local a = ch(e.a, i)
        if a > 0.002 and e.on then
            if e.on:byte((frame % e.on_period) + 1) ~= ONE then a = 0 end
        end
        if a > 0.002 then
            local s = shapes[e.shape]
            local id = s and self:id_of(e.shape)
            if id then
                local sx, sy = ch(e.sx, i), ch(e.sy, i)
                -- mir: a mirroring placement; the texture flips inside its rect, so the
                -- origin moves to the other side of the png
                local mir = e.mir and ch(e.mir, i) == 1
                -- cr/cg/cb: the placement's colour multiply
                local col = e.cr and { ch(e.cr, i) * 255, ch(e.cg, i) * 255, ch(e.cb, i) * 255, 255 } or nil
                tex.draw_texture(id, {
                    color    = col,
                    x        = ch(e.tx, i),
                    y        = y + ch(e.ty, i),
                    x2       = s[1] * (sx - 1),
                    y2       = s[2] * (sy - 1),
                    origin   = { (mir and (s[1] - s[3]) or s[3]) * sx, s[4] * sy },
                    rotation = ch(e.rot, i),
                    fade     = a * fade,
                    mirror   = mir and "horizontal" or nil,
                })
            end
        end
    end
end

return DonBGAnim
