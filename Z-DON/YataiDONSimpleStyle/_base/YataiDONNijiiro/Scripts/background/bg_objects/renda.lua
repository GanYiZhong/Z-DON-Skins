-- YataiDON-HSS override of PyTaikoGreen/background/bg_objects/renda.lua: Renda1 origin from x2[1]/y2[1]; frame from frame_count
-- The three roll effects (birds / shuriken / arrow), replayed as a fixed
-- round-robin pool of at most POOL_SIZE live pieces.
local FRAME_MS   = 1000.0 / 60.0
local LIFE       = 120
local SPAWN_X0, SPAWN_X1 = 6, 1100
local SPAWN_Y0, SPAWN_Y1 = 540, 1020

local BaseRenda = {}
BaseRenda.__index = BaseRenda

function BaseRenda.new(index, vx, vy, spin, path)
    local self = setmetatable({}, BaseRenda)
    self.name = "renda_" .. index
    self.path = path or "background"
    self.vx, self.vy, self.spin = vx, vy, spin or 0
    self.x0 = math.random(SPAWN_X0, SPAWN_X1)
    self.y0 = math.random(SPAWN_Y0, SPAWN_Y1)
    self.frames = 0
    self.last_ms = nil
    local info = tex.get_texture_info("renda", self.name)
    self.frame = math.random(0, ((info and info.frame_count) or 1) - 1)
    self.w = (info and info.x2 and info.x2[1]) or 0
    self.h = (info and info.y2 and info.y2[1]) or 0
    self._id = tex.get_texture(self.path .. "/renda/" .. self.name)  -- nil = missing
    return self
end

function BaseRenda:update(current_time_ms)
    if self.last_ms then
        local dt = current_time_ms - self.last_ms
        if dt > 0 and dt < 500 then self.frames = self.frames + dt / FRAME_MS end
    end
    self.last_ms = current_time_ms
end

function BaseRenda:finished()
    return self.frames >= LIFE
end

function BaseRenda:draw(y_offset)
    if not self._id or self:finished() then return end
    local f = self.frames
    local cx = self.x0 + self.vx * f
    local cy = self.y0 + self.vy * f + (y_offset or 0)
    if self.spin ~= 0 then
        tex.draw_texture(self._id, {
            frame = self.frame, x = cx, y = cy,
            origin = { self.w * 0.5, self.h * 0.5 }, rotation = self.spin * f,
        })
    else
        tex.draw_texture(self._id, { frame = self.frame, x = cx - self.w * 0.5, y = cy - self.h * 0.5 })
    end
end

local Renda0 = setmetatable({}, {__index = BaseRenda})
Renda0.__index = Renda0
function Renda0.new(index, path) return setmetatable(BaseRenda.new(index, 17.3, -10.9, nil, path), Renda0) end

local Renda1 = setmetatable({}, {__index = BaseRenda})
Renda1.__index = Renda1
function Renda1.new(index, path) return setmetatable(BaseRenda.new(index, 17.3, 0, -6, path), Renda1) end

local Renda2 = setmetatable({}, {__index = BaseRenda})
Renda2.__index = Renda2
function Renda2.new(index, path) return setmetatable(BaseRenda.new(index, 13.1, -13.8, nil, path), Renda2) end

local POOL_SIZE = 10

local RendaController = {}
RendaController.__index = RendaController

-- optional y_offset: the 2P band's second renda instance sits at y = game_2p_offset.y
function RendaController.new(path, index, y_offset)
    local self = setmetatable({}, RendaController)
    self.rendas = {}          -- slot -> live effect (holes allowed)
    self.rr = 0               -- round-robin counter
    self.spawned_this_frame = false
    self.path = path or "background"
    self.index = (index ~= nil) and index or math.random(0, 2)
    self.y_offset = y_offset or 0
    tex.load_folder(self.path, "renda")
    return self
end

function RendaController:add_renda()
    -- at most one spawn per frame
    if self.spawned_this_frame then return end
    self.spawned_this_frame = true
    local classes = {Renda0, Renda1, Renda2}
    local cls = classes[self.index + 1]
    local slot = (self.rr % POOL_SIZE) + 1
    self.rr = self.rr + 1
    self.rendas[slot] = cls.new(self.index, self.path)   -- replace in slot
end

function RendaController:update(current_time_ms)
    self.spawned_this_frame = false
    for slot = 1, POOL_SIZE do
        local r = self.rendas[slot]
        if r then
            r:update(current_time_ms)
            if r:finished() then
                self.rendas[slot] = nil
            end
        end
    end
end

function RendaController:draw()
    for slot = 1, POOL_SIZE do
        local r = self.rendas[slot]
        if r then r:draw(self.y_offset) end
    end
end

function RendaController:destroy()
    tex.unload_folder(self.path, "renda")
end

return RendaController
