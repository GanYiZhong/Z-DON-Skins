-- Renda: the drumroll notes. Every hit sends notes flying dx, dy px in a
-- straight line from a random spot, one of the folder's pictures at that picture's speed,
-- optionally spinning `spin` degrees over the flight. The spawn area (x, y + their ranges,
-- on top of the texture.json position) comes from the game rather than the data, so those
-- are picked by eye.
-- spec (optional, over the default for the index): ms (flight per picture, cycled), kinds
-- ({ frame, ms } pairs instead of ms), dx, dy, spin, x, x_range, y, y_range, per_hit, glow (a texture
-- in the renda folder drawn additively under each note, frame for frame)

local DEFAULT = { per_hit = 1, x = 0, x_range = 0, y = 0, y_range = 0, dy = 0 }
local LIMIT   = 25

-- the default drumrolls (renda_0..2), by index
local SPECS = {
    [0] = { ms = { 2000, 2083, 1950, 2250, 1733, 2000 }, dx = 2060, dy = -1300, x_range = 500, y_range = 20 },
    [1] = { ms = { 2000 }, dx = 2060, spin = 720, y_range = 200 },
    [2] = { ms = { 2000 }, dx = 1560, dy = -1648, x_range = 500, y_range = 20 },
}

local RendaController   = {}
RendaController.__index = RendaController

-- Miku and GUMI: two notes a hit flying straight across from the right edge, each one of
-- the five pictures at one of two speeds
RendaController.ACROSS = {
    kinds = {
        { 0, 1333 }, { 0, 2000 }, { 1, 1667 }, { 1, 2000 }, { 2, 2333 },
        { 2, 2000 }, { 3, 1667 }, { 3, 2000 }, { 4, 1333 }, { 4, 2000 },
    },
    dx = -2060, dy = 0, x = 1280, x_range = 200, y = 384, y_range = 288, per_hit = 2,
}

function RendaController.new(path, index, spec)
    local self = setmetatable({}, RendaController)
    self.path  = path or "background"
    index      = index or math.random(0, 2)
    self.name  = "renda_" .. index
    local base = SPECS[index] or SPECS[0]
    local function get(k)
        local v = spec and spec[k]
        if v == nil then v = base[k] end
        if v == nil then v = DEFAULT[k] end
        return v
    end
    for _, k in ipairs({ "dx", "dy", "spin", "x", "x_range", "y", "y_range", "per_hit" }) do self[k] = get(k) end
    tex.load_folder(self.path, "renda")
    local info  = tex.get_texture_info("renda", self.name) or {}
    self.width  = info.width or 0
    self.height = info.height or 0
    self.kinds  = spec and spec.kinds
    if not self.kinds then
        local ms = get("ms")
        self.kinds = {}
        for f = 0, (info.frame_count or 1) - 1 do
            table.insert(self.kinds, { f, ms[f % #ms + 1] })
        end
    end
    -- some collabs have no drumroll picture; asking for a missing one logs a load error
    self._id   = info.width and tex.get_texture(self.path .. "/renda/" .. self.name) or 0
    self._id_glow = spec and spec.glow and tex.get_texture(self.path .. "/renda/" .. spec.glow) or nil
    self.notes = {}
    return self
end

function RendaController:add_renda()
    local scale = tex.get_screen_scale()
    local function move(ms, distance)
        local m = anim.move(ms, { total_distance = math.floor(distance * scale) })
        m:start()
        return m
    end
    if self._id == 0 then return end
    for _ = 1, self.per_hit do
        if #self.notes >= LIMIT then return end
        local kind = self.kinds[math.random(#self.kinds)]
        table.insert(self.notes, {
            frame = kind[1],
            x     = math.floor((self.x + math.random(0, self.x_range)) * scale),
            y     = math.floor((self.y + math.random(0, self.y_range)) * scale),
            move  = move(kind[2], self.dx),
            rise  = self.dy ~= 0 and move(kind[2], self.dy) or nil,
            spin  = self.spin and anim.move(kind[2], { total_distance = self.spin }) or nil,
        })
        local note = self.notes[#self.notes]
        if note.spin then note.spin:start() end
    end
end

function RendaController:update(current_time_ms)
    for i = #self.notes, 1, -1 do
        local note = self.notes[i]
        note.move:update(current_time_ms)
        if note.rise then note.rise:update(current_time_ms) end
        if note.spin then note.spin:update(current_time_ms) end
        if note.move.is_finished then table.remove(self.notes, i) end
    end
end

function RendaController:draw()
    for _, note in ipairs(self.notes) do
        local x = note.x + note.move.attribute
        local y = note.y + (note.rise and note.rise.attribute or 0)
        if note.spin then
            -- spins about its centre
            local ox, oy = self.width / 2, self.height / 2
            tex.draw_texture(self._id, { frame = note.frame, x = x + ox, y = y + oy,
                origin = { ox, oy }, rotation = note.spin.attribute })
        else
            if self._id_glow then
                tex.draw_texture(self._id_glow, { frame = note.frame, x = x, y = y })
            end
            tex.draw_texture(self._id, { frame = note.frame, x = x, y = y })
        end
    end
end

function RendaController:destroy() tex.unload_folder(self.path, "renda") end

return RendaController
