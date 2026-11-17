-- A collab pack's drumroll effect: each hit spawns one of the movie's effectparts clips at a
-- random spot and replays it frame by frame (bg_data/renda_anim/<name>.lua, rendaa_<name>/).
-- Same interface as RendaController (add_renda / update / draw / destroy).
local FRAME_MS  = 1000.0 / 60.0
local POOL_SIZE = 10
local SPAWN_Y0, SPAWN_Y1 = 560, 1000

local RendaClip = {}
RendaClip.__index = RendaClip

function RendaClip.available(name)
    local ok, data = pcall(require, "background/bg_data/renda_anim/" .. name)
    return ok and type(data) == "table" and data.parts ~= nil and #data.parts > 0
end

-- optional y_offset: the 2P band's second instance sits at y = game_2p_offset.y
function RendaClip.new(path, name, y_offset)
    local ok, data = pcall(require, "background/bg_data/renda_anim/" .. name)
    if not ok or type(data) ~= "table" or not data.parts or #data.parts == 0 then return nil end
    local self = setmetatable({}, RendaClip)
    self.path = path or "background"
    self.subset = "rendaa_" .. name
    self.data = data
    self.y_offset = y_offset or 0
    self.ids = {}
    self.live = {}            -- slot -> {part, x0, y0, frames}
    self.rr = 0
    self.spawned_this_frame = false
    self.last_ms = nil
    tex.load_folder(self.path, self.subset)
    return self
end

function RendaClip:id_of(shape)
    local id = self.ids[shape]
    if id == nil then
        id = tex.get_texture(self.path .. "/" .. self.subset .. "/s" .. shape) or false
        self.ids[shape] = id
    end
    return id or nil
end

function RendaClip:add_renda()
    if self.spawned_this_frame then return end
    self.spawned_this_frame = true
    local part = self.data.parts[math.random(1, #self.data.parts)]
    -- the clips move relative to where the game drops them: a part that travels left
    -- enters from the right edge, one that travels right from the left, one that stays
    -- put pops up anywhere on the lane band
    local x0
    if part.dx < -1 then x0 = math.random(1700, 2100)
    elseif part.dx > 1 then x0 = math.random(-180, 220)
    else x0 = math.random(200, 1720) end
    local slot = (self.rr % POOL_SIZE) + 1
    self.rr = self.rr + 1
    self.live[slot] = { part = part, x0 = x0, y0 = math.random(SPAWN_Y0, SPAWN_Y1), frames = 0 }
end

function RendaClip:update(current_ms)
    self.spawned_this_frame = false
    local dt = 0
    if self.last_ms then
        dt = current_ms - self.last_ms
        if dt < 0 or dt > 500 then dt = 0 end
    end
    self.last_ms = current_ms
    for slot = 1, POOL_SIZE do
        local r = self.live[slot]
        if r then
            r.frames = r.frames + dt / FRAME_MS
            if r.frames >= #r.part.frames then self.live[slot] = nil end
        end
    end
end

local draw_params = {}
local draw_origin = {}
draw_params.origin = draw_origin

function RendaClip:draw()
    local shapes = self.data.shapes
    local params = draw_params
    local origin = draw_origin
    for slot = 1, POOL_SIZE do
        local r = self.live[slot]
        local row = r and r.part.frames[math.floor(r.frames) + 1]
        if row then
            for k = 1, #row do
                local e = row[k]
                local s = shapes[e[1]]
                local id = s and self:id_of(e[1])
                if id then
                    local sx, sy = e[4], e[5]
                    local mir = e[8] == 1
                    origin[1] = (mir and (s[1] - s[3]) or s[3]) * sx
                    origin[2] = s[4] * sy
                    params.x        = r.x0 + e[2]
                    params.y        = r.y0 + e[3] + self.y_offset
                    params.x2       = s[1] * (sx - 1)
                    params.y2       = s[2] * (sy - 1)
                    params.rotation = e[6]
                    params.fade     = e[7]
                    params.mirror   = mir and "horizontal" or nil
                    tex.draw_texture(id, params)
                end
            end
        end
    end
end

function RendaClip:destroy()
    tex.unload_folder(self.path, self.subset)
end

return RendaClip
