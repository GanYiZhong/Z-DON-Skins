local Timing = require("background/bg_objects/timing")
local pose_at = Timing.pose_at

local BaseDancer = {}
BaseDancer.__index = BaseDancer

local DEFAULT_KEY = { enter = "start", dance = "loop", leave = "end" }

-- a part is either one layer (a pose table) or a list of layers
-- a part's `beats` ends its layers, so a last pose's `to` glide finishes on time
local function layers(part)
    if not part then return {} end
    local list = (type(part[1]) == "table" and type(part[1][1]) == "number") and { part } or part
    for _, layer in ipairs(list) do layer.length = layer.length or part.beats end
    return list
end

function BaseDancer.new(cls, name, index, bpm, path)
    local self   = setmetatable({}, cls)
    self.name    = name
    self.index   = index
    self.path    = path
    self.spec    = cls.specs[index] or cls.specs.default
    if self.spec.plain then -- not ported yet: step through the loop frames every half beat
        local info = tex.get_texture_info(name, index .. "_loop")
        local frames = {}
        for f = 0, (info and info.frame_count or 1) - 1 do frames[#frames + 1] = { f, 0.5 } end
        self.spec = { enter = { beats = 0 }, dance = Timing.steps(frames) }
    end
    self.state   = nil -- nil (hidden), "enter", "dance", "leave"
    self.beat    = 60000 / bpm
    self.ids     = {}
    self.parts   = {
        enter = layers(self.spec.enter),
        dance = layers(self.spec.dance),
        leave = layers(self.spec.leave),
    }
    return self
end

function BaseDancer:texture(key)
    if key == "start" or key == "loop" or key == "end" then key = self.index .. "_" .. key end
    if key:sub(1, 1) == "_" then key = self.index .. key end -- this dancer's own, e.g. "_poof"
    if not self.ids[key] then
        self.ids[key] = { id = tex.get_texture(self.path .. "/" .. self.name .. "/" .. key) or 0,
                          info = tex.get_texture_info(self.name, key) }
    end
    return self.ids[key]
end

function BaseDancer:play(state, now)
    self.state, self.t0 = state, now
end

function BaseDancer:start() self.start_now = true end

function BaseDancer:leave()
    if self.spec.leave then self.leave_now = true else self.state = nil end
end

function BaseDancer:update(current_time_ms, bpm)
    local now = current_time_ms
    if bpm then
        local beat = 60000 / bpm
        if self.t0 and beat ~= self.beat then -- keep our place in the part at the new tempo
            self.t0 = now - (now - self.t0) / self.beat * beat
        end
        self.beat = beat
    end
    if self.start_now then self.start_now = nil; self:play("enter", now) end
    if self.leave_now then self.leave_now = nil; self:play("leave", now) end
    self.now = now
    if not self.state then return end
    local t = (now - self.t0) / self.beat
    if self.state == "enter" and t >= self.spec.enter.beats then
        self:play("dance", now)
    elseif self.state == "leave" and t >= self.spec.leave.beats then
        self.state = nil
    end
end

-- beats into the current part; the routine follows the group's clock
function BaseDancer:part_time()
    if self.state == "dance" then
        local t = self.group and self.group:dance_clock(self.now, self.beat) or (self.now - self.t0) / self.beat
        local period = self.parts.dance[1].length or self.spec.dance.beats
        return t % period
    end
    return (self.now - self.t0) / self.beat
end

local NO_AT, NO_ORIGIN = { 0, 0 }, { 0, 0 }

-- where the dancer's origin sits in `key`'s images: spec.origin, or its entry for that key
function BaseDancer:origin(key)
    local o = self.spec.origin or NO_ORIGIN
    return o[key] or o
end

-- draw_texture reads these straight away, so every dancer shares one pair
local PARAMS, ORIGIN = {}, { 0, 0 }
-- x: where the group puts this dancer's routine (left edge of its loop texture)
function BaseDancer:draw(x)
    if not self.state then return end
    local t, at = self:part_time(), self.spec.at or NO_AT
    local move = self.spec[self.state].move and pose_at(self.spec[self.state].move, t)
    local mx, my = move and move.x or 0, move and move.y or 0
    local msy, mrot = move and move.sy or 1, move and move.rot or 0
    for _, layer in ipairs(self.parts[self.state]) do
        local pose = pose_at(layer, t)
        if pose then
            local tx = self:texture(pose.key or layer.key or DEFAULT_KEY[self.state])
            local info = tx.info
            if info and info.width then
                local w, h, sy = info.width, info.height, pose.sy * msy
                local W, H = w * math.abs(pose.sx), h * sy
                local o = layer.origin or self:origin(pose.key or layer.key or DEFAULT_KEY[self.state])
                ORIGIN[1], ORIGIN[2] = o[1] * math.abs(pose.sx), o[2] * sy
                PARAMS.frame    = pose.frame
                PARAMS.x        = x + self:origin("loop")[1] + (pose.x or at[1]) - at[1] + mx
                PARAMS.y        = (pose.y or at[2]) + my
                PARAMS.x2       = W - w
                PARAMS.y2       = H - h
                PARAMS.origin   = ORIGIN
                PARAMS.rotation = pose.rot + mrot
                PARAMS.mirror   = (pose.mirror or pose.sx < 0) and "horizontal" or nil
                PARAMS.fade     = pose.alpha
                PARAMS.blend    = (pose.blend == nil and layer.blend or pose.blend) or nil
                PARAMS.color    = nil   -- donbg's dark wrapper may have set one
                tex.draw_texture(tx.id, PARAMS)
            end
        end
    end
end

-- A dancer class for BaseDancerGroup from specs (by dancer index, or `default`)
local function define(specs)
    local cls = setmetatable({ specs = specs }, { __index = BaseDancer })
    cls.__index = cls
    cls.new = function(...) return BaseDancer.new(cls, ...) end
    return cls
end

local PLAIN = define({ default = { plain = true } })

-- BaseDancerGroup: manages a pool of dancers spread across the screen
local BaseDancerGroup = {}
BaseDancerGroup.__index = BaseDancerGroup

local INITIAL_DANCER_DELAY_MS = 800

local function get_variant_count(dancer_name)
    local keys = tex.get_texture_keys(dancer_name)
    if not keys then return 1 end
    local variants = {}
    for _, key in ipairs(keys) do
        local num = tonumber(key:match("^(%d+)"))
        if num then variants[num] = true end
    end
    local count = 0
    for _ in pairs(variants) do count = count + 1 end
    return math.max(1, count)
end

-- dancer_class: a class from Dancer.define; collabs not ported yet get the plain dancer
function BaseDancerGroup.new(index, bpm, max_dancers, path, dancer_class)
    local self = setmetatable({}, BaseDancerGroup)
    dancer_class = dancer_class or PLAIN
    self.name = "dancer_" .. index
    self.active_count = 0
    self.path = path or "background"
    tex.load_folder(self.path, "dancer/" .. self.name)
    -- center(2), left(1), right(3), far-left(0), far-right(4) — 0-indexed
    self.spawn_positions = { 2, 1, 3, 0, 4 }
    self.active_dancers = {}
    self.max_dancers = max_dancers

    local variant_count = get_variant_count(self.name)
    self.dancers = {}
    for i = 1, max_dancers do
        local variant_idx = (i - 1) % variant_count
        local dancer = dancer_class.new(self.name, variant_idx, bpm, self.path)
        dancer.group = self
        table.insert(self.dancers, dancer)
    end

    -- Shuffle dancers
    for i = #self.dancers, 2, -1 do
        local j = math.random(1, i)
        self.dancers[i], self.dancers[j] = self.dancers[j], self.dancers[i]
    end

    self.needs_initial_dancer = true
    return self
end

function BaseDancerGroup:add_dancer()
    if self.active_count < #self.dancers and self.active_count < #self.spawn_positions then
        self.active_count = self.active_count + 1
        local position = self.spawn_positions[self.active_count] + 1 -- convert to 1-indexed
        local dancer = self.dancers[self.active_count]
        self.active_dancers[position] = dancer
        dancer:start()
    end
end

function BaseDancerGroup:remove_dancer()
    if self.active_count > 1 then
        local position = self.spawn_positions[self.active_count] + 1
        self.active_dancers[position] = nil
        self.active_count = self.active_count - 1
    end
end

function BaseDancerGroup:update(current_time_ms, bpm)
    if self.needs_initial_dancer then
        self.initial_dancer_ms = self.initial_dancer_ms or current_time_ms + INITIAL_DANCER_DELAY_MS
        if current_time_ms >= self.initial_dancer_ms then
            self.needs_initial_dancer = false
            self:add_dancer()
        end
    end
    for _, dancer in ipairs(self.dancers) do
        dancer:update(current_time_ms, bpm)
    end
end

-- texture info of a dancer variant's loop images (fixed once the folder is loaded)
function BaseDancerGroup:loop_info(index)
    local cache = self.loop_infos
    if not cache then cache = {}; self.loop_infos = cache end
    local info = cache[index]
    if info == nil then
        info = tex.get_texture_info(self.name, tostring(index) .. "_loop") or false
        cache[index] = info
    end
    return info or nil
end

function BaseDancerGroup:draw()
    local screen_width = tex.get_screen_width()
    local num_dancers = self.max_dancers

    local first_dancer = nil
    for i = 1, num_dancers do
        local d = self.active_dancers[i]
        if d then
            first_dancer = d; break
        end
    end
    if not first_dancer then return end

    local info = self:loop_info(first_dancer.index)
    local dancer_width = info and info.width or 0

    local available_space = screen_width - (num_dancers * dancer_width)
    local spacing = available_space / (num_dancers + 1)

    for i = 1, num_dancers do
        local dancer = self.active_dancers[i]
        if dancer then
            local x_pos = math.floor(spacing + (i - 1) * (dancer_width + spacing))
            dancer:draw(x_pos)
        end
    end
end

-- Draws dancers on fixed slot centres instead of even spacing
function BaseDancerGroup:draw_slots(centers, order)
    local screen_scale = tex.get_screen_scale()
    for _, i in ipairs(order) do
        local dancer = self.active_dancers[i]
        if dancer then
            local info = self:loop_info(dancer.index)
            dancer:draw(math.floor(centers[i] * screen_scale - info.width / 2))
        end
    end
end

-- Beats since the first dancer started dancing: the routine's shared clock, so dancers that
-- join later dance in step with the rest. Re-anchored when the bpm changes so it doesn't jump.
function BaseDancerGroup:dance_clock(now, beat)
    local c = self.clock
    if not c then
        c = { t0 = now, beat = beat }
        self.clock = c
    elseif c.beat ~= beat then
        c.t0, c.beat = now - (now - c.t0) / c.beat * beat, beat
    end
    return (now - c.t0) / beat
end

-- Like remove_dancer, but the dancer stays in its slot to play its exit
function BaseDancerGroup:leave_dancer()
    if self.active_count > 1 then
        self.active_dancers[self.spawn_positions[self.active_count] + 1]:leave()
        self.active_count = self.active_count - 1
    end
end

function BaseDancerGroup:destroy()
    tex.unload_folder(self.path, "dancer/" .. self.name)
end

local SETS = require("background/bg_objects/dancer/sets")

local Dancer = {}
Dancer.Base = BaseDancer
Dancer.BaseDancerGroup = BaseDancerGroup
Dancer.define = define
Dancer.Plain = PLAIN

-- The default dancer sets (dancer_0..20), from the hand-written specs in dancer/sets.lua
function Dancer.create(index, bpm, path, max_dancers)
    return BaseDancerGroup.new(index, bpm, max_dancers or 5, path, define(SETS[index]))
end

return Dancer
