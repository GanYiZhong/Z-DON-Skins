-- YataiDON-HSS override of PyTaikoGreen/background/bg_objects/dancer.lua: Dancer0_4 bounce 20*sc; dancer spacing from info.x2[1]
-- BaseDancer: single dancer that starts off-screen and bounces in, then loops
local BaseDancer = {}
BaseDancer.__index = BaseDancer

function BaseDancer.new(name, index, bpm, path)
    local self = setmetatable({}, BaseDancer)
    self.name = name
    self.index = index
    self.bpm = bpm
    self.path = path or "background"
    self.is_started = false
    local base_path = self.path .. "/" .. self.name .. "/" .. tostring(self.index)
    self.t_start = tex.get_texture(base_path .. "_start")
    self.t_loop = tex.get_texture(base_path .. "_loop")

    local tex_info = tex.get_texture_info(self.name, tostring(self.index) .. "_loop")
    local frame_count = (tex_info and tex_info.frame_count) or 1
    self.keyframes = {}
    for i = 0, frame_count - 1 do
        table.insert(self.keyframes, i)
    end

    local duration = (60000 / bpm) / 2
    local total_duration = duration * #self.keyframes
    local textures = {}
    for i, frame_idx in ipairs(self.keyframes) do
        table.insert(textures, { duration * (i - 1), duration * i, frame_idx })
    end
    self.texture_change = anim.texture_change(total_duration, textures, { loop = true })
    self.texture_change:start()

    return self
end

function BaseDancer:start()
    self.is_started = true
    local screen_scale = tex.get_screen_scale()
    local duration = 60000 / self.bpm

    self.s_bounce_up = anim.move(duration / 2, {
        start_position = math.floor(-200 * screen_scale),
        total_distance = math.floor(350 * screen_scale),
        ease_out = "quadratic",
        delay = 500
    })
    self.s_bounce_down = anim.move(duration / 2, {
        total_distance = math.floor(140 * screen_scale),
        ease_in = "quadratic",
        delay = duration / 2 + 500
    })

    local start_info = tex.get_texture_info(self.name, tostring(self.index) .. "_start")
    local s_frame_count = (start_info and start_info.frame_count) or 1
    local s_keyframes = {}
    for i = 0, s_frame_count - 1 do
        table.insert(s_keyframes, i)
    end
    local start_textures = {}
    for i, frame_idx in ipairs(s_keyframes) do
        table.insert(start_textures, { (duration / #s_keyframes) * (i - 1), (duration / #s_keyframes) * i, frame_idx })
    end
    self.s_texture_change = anim.texture_change(duration, start_textures, { delay = 500 })
    self.s_texture_change:start()
    self.s_bounce_up:start()
    self.s_bounce_down:start()
end

function BaseDancer:update(current_time_ms, bpm)
    self.texture_change:update(current_time_ms)
    if self.is_started then
        self.s_texture_change:update(current_time_ms)
        self.s_bounce_up:update(current_time_ms)
        self.s_bounce_down:update(current_time_ms)
    end
    if bpm and bpm ~= self.bpm then
        self.bpm = bpm
        local duration = (60000 / bpm) / 2
        local total_duration = duration * #self.keyframes
        local textures = {}
        for i, frame_idx in ipairs(self.keyframes) do
            table.insert(textures, { duration * (i - 1), duration * i, frame_idx })
        end
        self.texture_change = anim.texture_change(total_duration, textures, { loop = true })
        self.texture_change:start()
    end
end

function BaseDancer:draw(x)
    if not self.is_started then return end
    local y = -self.s_bounce_up.attribute + self.s_bounce_down.attribute
    if not self.s_texture_change.is_finished then
        tex.draw_texture(self.t_start, {
            frame = self.s_texture_change.attribute, x = x, y = y
        })
    else
        tex.draw_texture(self.t_loop, {
            frame = self.texture_change.attribute, x = x
        })
    end
end

-- Dancer0_4: dancer 4 in group 0, has a bouncing object on top
local Dancer0_4 = setmetatable({}, { __index = BaseDancer })
Dancer0_4.__index = Dancer0_4

function Dancer0_4.new(name, index, bpm, path)
    local self = setmetatable({}, Dancer0_4)
    local base = BaseDancer.new(name, index, bpm, path)
    for k, v in pairs(base) do self[k] = v end

    self.keyframes = {}
    for i = 0, 53 do
        table.insert(self.keyframes, i)
    end

    local duration = (60000 / bpm) / 2
    local total_duration = duration * #self.keyframes
    local textures = {}
    for i, frame_idx in ipairs(self.keyframes) do
        table.insert(textures, { duration * (i - 1), duration * i, frame_idx })
    end
    self.texture_change = anim.texture_change(total_duration, textures, { loop = true })
    self.texture_change:start()

    self.bounce_up = anim.move(duration, {
        total_distance = 20 * tex.get_screen_scale(), ease_out = "quadratic", delay = duration * 2
    })
    self.bounce_down = anim.move(duration, {
        total_distance = 20 * tex.get_screen_scale(), ease_in = "quadratic", delay = duration * 3
    })
    self.bounce_up:start()
    self.bounce_down:start()
    self._id_4_start = tex.get_texture(self.path .. "/" .. self.name .. "/4_start") or 0
    self._id_4_loop  = tex.get_texture(self.path .. "/" .. self.name .. "/4_loop") or 0
    return self
end

function Dancer0_4:update(current_time_ms, bpm)
    BaseDancer.update(self, current_time_ms, bpm)
    self.bounce_up:update(current_time_ms)
    self.bounce_down:update(current_time_ms)
    if self.bounce_down.is_finished then
        self.bounce_up:restart()
        self.bounce_down:restart()
    end
end

function Dancer0_4:draw(x)
    if not self.is_started then return end
    local sy = -self.s_bounce_up.attribute + self.s_bounce_down.attribute
    local screen_scale = tex.get_screen_scale()
    if not self.s_texture_change.is_finished then
        tex.draw_texture(self._id_4_start, {
            frame = 7, x = x, y = (-50 * screen_scale) + sy
        })
        tex.draw_texture(self._id_4_start, {
            frame = self.s_texture_change.attribute, x = x, y = sy
        })
    else
        local attr = self.texture_change.attribute
        local by = -self.bounce_up.attribute + self.bounce_down.attribute
        if attr >= 0 and attr <= 3 then
            tex.draw_texture(self._id_4_loop, { frame = 54, x = x, y = by })
        elseif attr >= 5 and attr <= 8 then
            tex.draw_texture(self._id_4_loop, { frame = 56, x = x, y = by })
        elseif attr == 4 then
            tex.draw_texture(self._id_4_loop, { frame = 55, x = x, y = by })
        end
        tex.draw_texture(self._id_4_loop, { frame = attr, x = x })
    end
end

-- DancerPoof: dancer with a poof animation on spawn
local DancerPoof = setmetatable({}, { __index = BaseDancer })
DancerPoof.__index = DancerPoof

function DancerPoof.new(name, index, bpm, path)
    local self = setmetatable({}, DancerPoof)
    local base = BaseDancer.new(name, index, bpm, path)
    for k, v in pairs(base) do self[k] = v end

    local duration = 60000 / bpm
    local poof_keyframes = {}
    for i = 0, 6 do
        table.insert(poof_keyframes, { (duration / 7) * i, (duration / 7) * (i + 1), i })
    end
    self.poof_texture_change = anim.texture_change(duration, poof_keyframes, { delay = 250 })
    self.poof_texture_change:start()
    self._id_poof = tex.get_texture(self.path .. "/" .. self.name .. "/poof") or 0
    return self
end

function DancerPoof:update(current_time_ms, bpm)
    BaseDancer.update(self, current_time_ms, bpm)
    self.poof_texture_change:update(current_time_ms)
end

function DancerPoof:draw(x)
    BaseDancer.draw(self, x)
    if not self.poof_texture_change.is_finished then
        tex.draw_texture(self._id_poof, { x = x, frame = self.poof_texture_change.attribute })
    end
end

-- DancerPoof2: like DancerPoof but uses per-index poof texture
local DancerPoof2 = setmetatable({}, { __index = DancerPoof })
DancerPoof2.__index = DancerPoof2

function DancerPoof2.new(name, index, bpm, path)
    local self = setmetatable({}, DancerPoof2)
    local base = DancerPoof.new(name, index, bpm, path)
    for k, v in pairs(base) do self[k] = v end
    self.t_poof = tex.get_texture(self.path .. "/" .. self.name .. "/" .. tostring(self.index) .. "_poof")
    return self
end

function DancerPoof2:draw(x)
    if not self.is_started then return end
    local sy = -self.s_bounce_up.attribute + self.s_bounce_down.attribute
    if not self.s_texture_change.is_finished then
        tex.draw_texture(self.t_start, {
            frame = self.s_texture_change.attribute, x = x, y = sy
        })
    else
        tex.draw_texture(self.t_loop, {
            frame = self.texture_change.attribute, x = x
        })
    end
    if not self.poof_texture_change.is_finished then
        tex.draw_texture(self.t_poof, {
            x = x, frame = self.poof_texture_change.attribute
        })
    end
end

-- BaseDancerGroup: manages a pool of dancers spread across the screen
local BaseDancerGroup = {}
BaseDancerGroup.__index = BaseDancerGroup

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

function BaseDancerGroup.new(index, bpm, max_dancers, path, dancer_class)
    local self = setmetatable({}, BaseDancerGroup)
    dancer_class = dancer_class or BaseDancer
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
        table.insert(self.dancers, dancer_class.new(self.name, variant_idx, bpm, self.path))
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
        self.needs_initial_dancer = false
        self:add_dancer()
    end
    for _, dancer in ipairs(self.dancers) do
        dancer:update(current_time_ms, bpm)
    end
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

    self._widths = self._widths or {}
    local dancer_width = self._widths[first_dancer.index]
    if not dancer_width then
        local info = tex.get_texture_info(self.name, tostring(first_dancer.index) .. "_loop")
        dancer_width = info and info.x2[1] or 0
        self._widths[first_dancer.index] = dancer_width
    end

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

function BaseDancerGroup:destroy()
    tex.unload_folder(self.path, "dancer/" .. self.name)
end

-- DancerGroup0: index 0 uses BaseDancers 0-3 + Dancer0_4 at position 4
local DancerGroup0 = setmetatable({}, { __index = BaseDancerGroup })
DancerGroup0.__index = DancerGroup0

function DancerGroup0.new(index, bpm, max_dancers, path)
    local self = setmetatable({}, DancerGroup0)
    self.name = "dancer_" .. index
    self.active_count = 0
    self.path = path or "background"
    tex.load_folder(self.path, "dancer/" .. self.name)
    self.spawn_positions = { 2, 1, 3, 0, 4 }
    self.active_dancers = {}
    self.max_dancers = max_dancers
    self.dancers = {
        BaseDancer.new(self.name, 0, bpm, self.path),
        BaseDancer.new(self.name, 1, bpm, self.path),
        BaseDancer.new(self.name, 2, bpm, self.path),
        BaseDancer.new(self.name, 3, bpm, self.path),
        Dancer0_4.new(self.name, 4, bpm, self.path)
    }
    for i = #self.dancers, 2, -1 do
        local j = math.random(1, i)
        self.dancers[i], self.dancers[j] = self.dancers[j], self.dancers[i]
    end
    self.needs_initial_dancer = true
    return self
end

-- DancerGroupPoof1: uses DancerPoof
local DancerGroupPoof1 = setmetatable({}, { __index = BaseDancerGroup })
DancerGroupPoof1.__index = DancerGroupPoof1

function DancerGroupPoof1.new(index, bpm, max_dancers, path)
    return BaseDancerGroup.new(index, bpm, max_dancers, path, DancerPoof)
end

-- DancerGroupPoof2: uses DancerPoof2
local DancerGroupPoof2 = setmetatable({}, { __index = BaseDancerGroup })
DancerGroupPoof2.__index = DancerGroupPoof2

function DancerGroupPoof2.new(index, bpm, max_dancers, path)
    return BaseDancerGroup.new(index, bpm, max_dancers, path, DancerPoof2)
end

-- Reference cabinet dancers: a single playhead per troupe, replayed at
-- BEAT_FRAMES per beat.
local BEAT_FRAMES   = 40
local ARCADE_GROUPS = 6
local PHRASE        = 80

local ArcadeDancer   = {}
ArcadeDancer.__index = ArcadeDancer

function ArcadeDancer.new(group_name, variant, vd, path)
    local self = setmetatable({}, ArcadeDancer)
    self.vd    = vd
    self.tex   = tex.get_texture((path or "background") .. "/" .. group_name .. "/" .. tostring(variant) .. "_loop") or 0
    self.state = "idle"
    self.enter = 0 -- group frame the `in` hop starts on
    self.join  = 0 -- group frame it joins the shared loop on
    self.exit  = 0 -- group frame the `out` segment starts on
    return self
end

-- smallest f >= g with (f - dance) a whole number of phrases
local function phrase_at_or_after(g, dance)
    return dance + math.ceil((g - dance) / PHRASE) * PHRASE
end

function ArcadeDancer:begin_enter(g)
    self.join  = phrase_at_or_after(g + PHRASE, self.vd.dance)
    self.enter = self.join - PHRASE
    self.state = "in"
end

function ArcadeDancer:begin_leave(g)
    if self.state == "idle" or self.state == "out" then return end
    if self.state == "in" and g < self.join then
        -- earned and un-earned again before it ever landed: it simply never arrives
        self.state = "idle"
        return
    end
    self.exit  = phrase_at_or_after(g, self.vd.dance)
    self.state = "out"
end

-- The one place a frame number is produced; everything is a pure function of the
-- group's clock `g`, so two slots in the same state are on the same frame.
function ArcadeDancer:frame_at(g)
    local vd = self.vd
    local st = self.state
    if st == "idle" then return nil end
    if st == "in" then
        if g < self.enter then return nil end -- earned, still waiting for the phrase
        return g - self.enter
    end
    local span = vd.out - vd.dance
    if st == "out" and g >= self.exit then
        local f = vd.out + (g - self.exit)
        if f >= vd.n then return nil end
        return f
    end
    return vd.dance + (g - vd.dance) % span
end

local function find_key(keys, f)
    local lo, hi = 1, #keys
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if keys[mid][1] <= f then lo = mid else hi = mid - 1 end
    end
    return keys[lo]
end

local arcade_params = {}
local arcade_origin = {}
arcade_params.origin = arcade_origin

function ArcadeDancer:draw(px, py, g)
    local f = self:frame_at(g)
    if not f then return end
    local vd  = self.vd
    local row = find_key(vd.keys, math.floor(f))[2]
    -- child-skin textures are loaded at scale 1.0, so every coordinate here is in
    -- the child's own 1920x1080 space (do NOT multiply by tex.get_screen_scale())
    for i = 1, #row do
        local d  = row[i]
        local sx, sy = d[4], d[5]
        -- every frame keeps its own origin, which `origin` supplies per draw
        local o  = vd.o[d[1] + 1]
        -- d[8] = 1: a mirroring placement (collab rigs); the frame flips inside its
        -- rect, so the origin moves to the other side of the png
        local mir = d[8] == 1
        arcade_origin[1] = (mir and (vd.w - o[1]) or o[1]) * sx
        arcade_origin[2] = o[2] * sy
        arcade_params.frame    = d[1]
        arcade_params.x        = px + d[2]
        arcade_params.y        = py + d[3]
        arcade_params.x2       = vd.w * (sx - 1)
        arcade_params.y2       = vd.h * (sy - 1)
        arcade_params.rotation = d[6]
        arcade_params.fade     = d[7]
        arcade_params.mirror   = mir and "horizontal" or nil
        tex.draw_texture(self.tex, arcade_params)
    end
end

local ArcadeDancerGroup   = {}
ArcadeDancerGroup.__index = ArcadeDancerGroup

-- index: a default troupe (0..5), or a collab pack's troupe name ("b_001", whose data is
-- `fixed`: slot i always shows variant i - 1, as many slots as the movie has positions)
function ArcadeDancerGroup.new(index, bpm, max_dancers, path)
    local self = setmetatable({}, ArcadeDancerGroup)
    if type(index) == "string" then
        self.name = index
    else
        self.name = "dancer_" .. (index % ARCADE_GROUPS)
    end
    self.path  = path or "background"
    self.data  = require("background/dancer_data/" .. self.name)
    tex.load_folder(self.path, "dancer/" .. self.name)

    -- pos0..pos4 on the cabinet are centre, left, right, far-left, far-right
    self.max_dancers = max_dancers or 5
    self.min_dancers = 3
    if self.data.fixed then
        self.max_dancers = #self.data.pos
        self.min_dancers = 1
    end
    self.now         = nil
    self.gframe      = 0 -- the troupe's single playhead
    self.active      = 0
    self.slots       = {}

    local nvar = 0
    for _ in pairs(self.data.variants) do nvar = nvar + 1 end
    -- a fixed troupe has one member per position, as many as the movie has dancers
    if self.data.fixed and nvar < self.max_dancers then self.max_dancers = nvar end
    local pick = {}
    for v = 0, nvar - 1 do pick[#pick + 1] = v end
    if not self.data.fixed then
        for i = #pick, 2, -1 do
            local j = math.random(1, i)
            pick[i], pick[j] = pick[j], pick[i]
        end
    end
    for i = 1, self.max_dancers do
        local v = pick[((i - 1) % nvar) + 1]
        self.slots[i] = ArcadeDancer.new(self.name, v, self.data.variants[v], self.path)
    end
    self.needs_initial = true
    return self
end

function ArcadeDancerGroup:add_dancer()
    if self.active >= self.max_dancers then return end
    self.active = self.active + 1
    self.slots[self.active]:begin_enter(self.gframe)
end

function ArcadeDancerGroup:remove_dancer()
    if self.active <= (self.min_dancers or 1) then return end
    self.slots[self.active]:begin_leave(self.gframe)
    self.active = self.active - 1
end

-- Set the absolute troupe count; grows/shrinks slot by slot.
function ArcadeDancerGroup:set_dancer_count(n)
    local lo = self.min_dancers or 1
    if n < lo then n = lo elseif n > self.max_dancers then n = self.max_dancers end
    while self.active < n do self:add_dancer() end
    while self.active > n do self:remove_dancer() end
end

function ArcadeDancerGroup:update(current_time_ms, bpm)
    if self.now == nil then self.now = current_time_ms end
    local dt = current_time_ms - self.now
    if dt < 0 then dt = 0 end
    self.now = current_time_ms

    -- one advance, one clock; BPM changes retime the whole troupe at once
    local frame_ms = (60000 / ((bpm and bpm > 0) and bpm or 120)) / BEAT_FRAMES
    self.gframe    = self.gframe + dt / frame_ms

    if self.needs_initial then
        self.needs_initial = false
        -- gframe is still 0, so all three get enter = 0 / join = dance and hop in together
        self:set_dancer_count(self.min_dancers or 1)
    end

    local g = self.gframe
    for i = 1, self.max_dancers do
        local d = self.slots[i]
        if d.state == "in" and g >= d.join then
            d.state = "dance"
        elseif d.state == "out" and g >= d.exit + (d.vd.n - d.vd.out) then
            d.state = "idle"
        end
    end
end

function ArcadeDancerGroup:draw()
    local pos = self.data.pos
    local py  = self.data.posy
    local g   = self.gframe
    -- far dancers first so the centre one ends up in front
    for i = self.max_dancers, 1, -1 do
        local d = self.slots[i]
        if d and d.state ~= "idle" then d:draw(pos[i] or 960, py, g) end
    end
end

function ArcadeDancerGroup:destroy()
    tex.unload_folder(self.path, "dancer/" .. self.name)
end

-- Factory: maps dancer index 0-20 to the appropriate group class
local Dancer = {}
Dancer.Base = BaseDancer
Dancer.BaseDancerGroup = BaseDancerGroup
Dancer.ArcadeDancerGroup = ArcadeDancerGroup

function Dancer.create(index, bpm, path, max_dancers)
    max_dancers = max_dancers or 5
    -- the normal gameplay backdrop uses the arcade rig; collab backdrops keep the parent's classes
    if (path or "background") == "background" then
        return ArcadeDancerGroup.new(index, bpm, max_dancers, path)
    end
    local map = {
        DancerGroup0, DancerGroup0, DancerGroup0,
        BaseDancerGroup, BaseDancerGroup, BaseDancerGroup,
        BaseDancerGroup,
        DancerGroupPoof1, DancerGroupPoof1,
        BaseDancerGroup, BaseDancerGroup, BaseDancerGroup,
        DancerGroupPoof2, DancerGroupPoof2,
        BaseDancerGroup, BaseDancerGroup,
        DancerGroupPoof2,
        BaseDancerGroup, BaseDancerGroup, BaseDancerGroup, BaseDancerGroup
    }
    local cls = map[index + 1]
    return cls.new(index, bpm, max_dancers, path)
end

return Dancer
