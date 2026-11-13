-- IDOLiSH7 backgrounds (i7id7, i7natsu, i7rev, i7tri): one stage, one transition, one dance
-- routine and the same chibi, don band and drumroll motion; each collab gives its member
-- count (from its art), its dancers and their slots. I7.background(path, spec) makes the class.
local DonBGBase       = require("background/bg_objects/donbg/base")
local Fever           = require("background/bg_objects/fever")
local Dancer          = require("background/bg_objects/dancer")
local RendaController = require("background/bg_objects/renda")
local ChibiController = require("background/bg_objects/chibi")
local BaseChibi       = require("background/bg_objects/chibi/base")
local ChibiWave       = require("background/bg_objects/chibi/wave")
local Timing          = require("background/bg_objects/timing")

local pose_at, steps, chain_moves, sum = Timing.pose_at, Timing.steps, Timing.chain_moves, Timing.sum

-- A value in thousandths that eases from wherever it is to a target (fade in/out envelopes)
local function envelope(current, moves, unit)
    return { offset = current, moves = chain_moves(moves, unit, 1) }
end
local function env_value(env) return env.offset + sum(env.moves) end
local function env_update(env, current_time_ms)
    for _, m in ipairs(env.moves) do m:update(current_time_ms) end
end

-- Beats since the background was made, re-anchored when the bpm changes so it doesn't jump
local function new_clock(bpm) return { beats = 0, beat = 60000 / bpm } end
local function clock_update(c, current_time_ms, bpm)
    if c.last then c.beats = c.beats + (current_time_ms - c.last) / c.beat end
    c.last = current_time_ms
    if bpm then c.beat = 60000 / bpm end
end

-- Don band: the IDOLiSH7 strip scrolls one tile left every 21.3 s (ambient); the clear set
-- fades in and out over 0.2 beats
local DONBG = { fade = 0.2, layers = { { key = "background", ms = 21333 } } }

-- Stage, shared by both backgrounds: the equalizer behind the stage flips between its two
-- frames every beat, the screen shows each member for 4 beats with the next one fading in
-- over the last 0.2, and the glow round the screen dims to 60% and back every beat
local MEMBER_BEATS, MEMBER_FADE = 4, 0.2
local GLOW = { { 0, 0, 0, 0, to = { 0, 0, alpha = 0.6 } }, { 0.55, 0, alpha = 0.6, to = { 0, 0, alpha = 1 } }, length = 1 }

local function draw_members(ids, members, t)
    local member = math.floor(t / MEMBER_BEATS) % members
    tex.draw_texture(ids.members, { frame = member })
    local into = t % MEMBER_BEATS - (MEMBER_BEATS - MEMBER_FADE)
    if into > 0 then
        tex.draw_texture(ids.members, { frame = (member + 1) % members, fade = into / MEMBER_FADE })
    end
    tex.draw_texture(ids.glow, { fade = pose_at(GLOW, t % GLOW.length).alpha })
    tex.draw_texture(ids.rig)
end

local function load_ids(path, name, keys)
    local ids = {}
    for _, key in ipairs(keys) do ids[key] = tex.get_texture(path .. "/" .. name .. "/" .. key) or 0 end
    return ids
end

local function member_count(name)
    local info = tex.get_texture_info(name, "members")
    return info and info.frame_count or 1
end

local BGNormal   = {}
BGNormal.__index = BGNormal

function BGNormal.new(path, clock)
    local self = setmetatable({}, BGNormal)
    self.path  = path
    self.name  = "bg_0"
    self.clock = clock
    tex.load_folder(path, "bg_normal/" .. self.name)
    self.members = member_count(self.name)
    self.ids = load_ids(path, self.name, { "equalizer", "background", "members", "glow", "rig", "rim" })
    return self
end

function BGNormal:draw()
    local t = self.clock.beats
    tex.draw_texture(self.ids.equalizer, { frame = math.floor(t) % 2 })
    tex.draw_texture(self.ids.background)
    draw_members(self.ids, self.members, t)
    tex.draw_texture(self.ids.rim)
end

function BGNormal:destroy() tex.unload_folder(self.path, "bg_normal/" .. self.name) end

-- Clear background: the stage is redrawn gold over the normal one. Half a beat in, the
-- gold stage, the light strings either side, the gold floor and two beams fade in; at
-- three quarters of a beat the lights come up (the gold equalizer, the footlights over the
-- blue rim, the spotlights and two streams of falling confetti). Losing clear drops the
-- lights over a quarter beat, then the gold stage fades a moment later. Timed in beats.
local STAGE_IN, LIGHTS_IN   = { { 0.45, 0 }, { 0.3, 1 } }, { { 0.75, 0 }, { 0.25, 1 } }
local STAGE_OUT, LIGHTS_OUT = { { 0.3, 0 }, { 0.2, -1 } }, { { 0.25, -1 } }
-- the footlights' glow dims every beat, the beams pulse every two; the lights' loops start
-- when they come up, the beams' with the stage
local LIGHTS_AT, BEAMS_AT = 0.75, 0.475
local LAMP_GLOW = { { 0, 0, 0, 0, to = { 0, 0, alpha = 0.6 } }, { 0.25, 0, alpha = 0.64, to = { 0, 0, alpha = 1 } },
                    { 0.5, 0 }, length = 1 }
local BEAM      = { { 0, 0, 0, 0, alpha = 0.8 }, { 1, 0, alpha = 0.8, to = { 0, 0, "out", alpha = 0.7 } },
                    { 1.5, 0, alpha = 0.7, to = { 0, 0, alpha = 0.8 } }, length = 2 }
-- Confetti: each stream has three lanes (texture.json "confetti" indices) falling down-left;
-- a new pass starts every `every` beats and takes three times that to fall, so three are on
-- screen once the first has fallen. Stream A falls at 75% size and 70% opacity, each lane a
-- pair of pieces, one turned a quarter.
local CONFETTI_HALF = 164
local CONFETTI = {
    { first = 0, every = 5, dx = -370, dy = 969, size = 0.75, alpha = 0.7 },
    { first = 3, every = 5, dx = -370, dy = 969, size = 0.75, alpha = 0.7, rotation = 90 },
    { first = 6, every = 4, dx = -320, dy = 1040, size = 1, alpha = 1 },
}
local CONFETTI_LANES = 3
-- spotlights on the top bar, turned a quarter (the right ones also flipped); texture.json has
-- each one's unturned top-left
local SPOT_HALF  = { 80, 72 }
local SPOT_FLIPS = { false, false, true, true }

local BGFever   = {}
BGFever.__index = BGFever

function BGFever.new(path, clock)
    local self = setmetatable({}, BGFever)
    self.path  = path
    self.name  = "bg_fever_0"
    self.clock = clock
    tex.load_folder(path, "bg_fever/" .. self.name)
    self.members = member_count(self.name)
    self.ids = load_ids(path, self.name, { "equalizer", "background", "members", "glow", "rig", "rays", "rim", "lamps",
        "lamp_glow", "floor_gold", "beam", "confetti", "light_bar", "spotlight" })
    self.stage  = envelope(0, {}, 1)
    self.lights = envelope(0, {}, 1)
    return self
end

local function scaled(moves, target)
    local out = {}
    for i, m in ipairs(moves) do out[i] = { m[1], m[2] * target } end
    return out
end

function BGFever:start()
    local beat = self.clock.beat
    local stage, lights = env_value(self.stage), env_value(self.lights)
    self.stage  = envelope(stage, scaled(STAGE_IN, 1000 - stage), beat)
    self.lights = envelope(lights, scaled(LIGHTS_IN, 1000 - lights), beat)
    self.t0     = self.clock.beats
end

function BGFever:stop()
    local beat = self.clock.beat
    local stage, lights = env_value(self.stage), env_value(self.lights)
    self.stage  = envelope(stage, scaled(STAGE_OUT, stage), beat)
    self.lights = envelope(lights, scaled(LIGHTS_OUT, lights), beat)
end

function BGFever:update(current_time_ms)
    env_update(self.stage, current_time_ms)
    env_update(self.lights, current_time_ms)
end

function BGFever:draw_confetti(t, fade)
    local scale = tex.get_screen_scale()
    for _, stream in ipairs(CONFETTI) do
        local laps, u = math.floor(t / stream.every), (t % stream.every) / stream.every
        local half = stream.rotation and CONFETTI_HALF * stream.size * scale or 0
        for pass = 0, math.min(laps, 2) do
            local p = (pass + u) / 3
            for lane = 0, CONFETTI_LANES - 1 do
                tex.draw_texture(self.ids.confetti, {
                    index    = stream.first + lane,
                    x        = math.floor(stream.dx * p * scale) + half,
                    y        = math.floor(stream.dy * p * scale) + half,
                    fade     = fade * stream.alpha,
                    rotation = stream.rotation,
                    origin   = stream.rotation and { half, half } or nil,
                })
            end
        end
    end
end

function BGFever:draw()
    local stage, lights = env_value(self.stage) / 1000, env_value(self.lights) / 1000
    if stage <= 0 and lights <= 0 then return end
    local ids, t = self.ids, self.clock.beats
    local ft = t - (self.t0 or t)
    local lt, bt = math.max(0, ft - LIGHTS_AT), math.max(0, ft - BEAMS_AT)
    if lights > 0 then tex.draw_texture(ids.equalizer, { frame = math.floor(lt) % 2, fade = lights }) end
    tex.draw_texture(ids.background, { fade = stage })
    draw_members(ids, self.members, t)
    for i = 0, 1 do
        tex.draw_texture(ids.rays, { index = i, fade = stage, mirror = i == 1 and "horizontal" or nil })
    end
    tex.draw_texture(ids.rim, { fade = 1 - lights })
    if lights > 0 then
        local glow = lights * pose_at(LAMP_GLOW, lt % LAMP_GLOW.length).alpha
        for i = 0, 1 do
            local mirror = i == 1 and "horizontal" or nil
            tex.draw_texture(ids.lamps, { index = i, fade = lights, mirror = mirror })
            tex.draw_texture(ids.lamp_glow, { index = i, fade = glow, mirror = mirror })
        end
    end
    tex.draw_texture(ids.floor_gold, { fade = stage })
    local beam = stage * pose_at(BEAM, bt % BEAM.length).alpha
    for i = 0, 1 do
        tex.draw_texture(ids.beam, { index = i, fade = beam, mirror = i == 1 and "horizontal" or nil })
    end
    if lights <= 0 then return end
    self:draw_confetti(lt, lights)
    for i = 0, 1 do
        tex.draw_texture(ids.light_bar, { index = i, fade = lights, mirror = i == 1 and "horizontal" or nil })
    end
    local scale = tex.get_screen_scale()
    local ox, oy = SPOT_HALF[1] * scale, SPOT_HALF[2] * scale
    for i, flip in ipairs(SPOT_FLIPS) do
        tex.draw_texture(ids.spotlight, {
            index = i - 1, x = ox, y = oy, origin = { ox, oy }, rotation = 90,
            mirror = flip and "vertical" or nil, fade = lights,
        })
    end
end

function BGFever:destroy() tex.unload_folder(self.path, "bg_fever/" .. self.name) end

-- Dancers: the members on fixed slots. They pop in and out with no entrance and all
-- follow one 4-beat routine on the group's clock: a dip on every off-beat, and once a bar a
-- hop that switches pose with a sparkle by the head. Half of them hop on the first beat and
-- switch back on the fourth, the other half answer: switch on the second, hop on the third.
-- Timed in beats; poses are offsets from Lumen's dancer origin (bottom centre, texture.json y 692).
local function dip(frame)
    return { { frame, 0.25, to = { nil, 2, nil, sy = 0.981 } }, { frame, 0.25, y = 2, sy = 0.981, to = { nil, 0, nil, sy = 1 } } }
end
-- up from the dip, then down past the pose change, landing with a squash
local function hop(from, to, height)
    return {
        { from, 0.25,  y = 2, to = { nil, -height } },
        { from, 0.325, y = 1 - height, to = { nil, -2.5 } },
        { to,   0.15,  y = -1.6, to = { nil, 0 } },
        { to,   0.275, y = 0, to = { nil, 0, nil, sy = 0.981 } },
        { to,   0.25,  sy = 0.981, to = { nil, 0, nil, sy = 1 } },
    }
end
local function hold(frame, beats) return { { frame, beats } } end

local function routine(x, hop_first)
    local start = { { 0, 0.5, x = x, y = 0 } }
    if hop_first then
        return steps(start, { dip(0)[1] }, hop(0, 1, 14), hold(1, 0.5), dip(1), hold(1, 0.325), hold(0, 0.175),
            dip(0))
    end
    return steps(start, dip(0), hold(0, 0.325), hold(1, 0.175), dip(1), hold(1, 0.5), { dip(1)[1] }, hop(1, 0, 16))
end

-- a sparkle pops up, grows and fades as it drifts: { from, mid, to } offsets from the origin
local function sparkle(at, path, size, mirror)
    local s = size or 1
    local from, mid, to = path[1], path[2], path[3]
    return {
        { 0, 0, from[1], from[2], hide = true },
        { at, 0, scale = 0.07 * s, alpha = 0, mirror = mirror, to = { from[1], from[2], scale = 0.85 * s, alpha = 1 } },
        { at + 0.075, 0, scale = 0.85 * s, mirror = mirror, to = { mid[1], mid[2], scale = s } },
        { at + 0.225, 0, scale = s, mirror = mirror, to = { to[1], to[2], scale = 1.11 * s, alpha = 0 } },
        { at + 0.5, 0, hide = true },
        length = 4,
    }
end
-- one dancer: x offset of its images, whether it hops first, and its sparkles
-- ({ path = { from, mid, to }, size, at, mirror, origin }); `look` is the collab's image
-- origin and sparkle size and pivot
local function member(look, m)
    local dance = { routine(m.x or 0, m.hop_first) }
    for _, s in ipairs(m.sparks) do
        local layer = sparkle(s.at or (m.hop_first and 1.45 or 3.325), s.path, s.size, s.mirror)
        local o = s.origin or look.spark_origin
        layer.key, layer.origin = "_spark", s.mirror and { look.spark_size - o[1], o[2] } or o
        table.insert(dance, layer)
    end
    return { origin = look.origin, enter = { beats = 0 }, dance = dance }
end

-- Chibis for good hits: one of the twelve hops in and bobs across, the same motion as A3's
local CHIBI_MOTION = {
    key  = "1",
    hop  = { from = { -418, 0 }, peak = { -335, -47 }, up = 0.3 },
    run  = { y = -3 },
    wave = { first = -12, height = 22, beats = 0.5 },
}
local CHIBIS = {}
for frame = 0, 11 do
    CHIBIS[frame + 1] = setmetatable({ first = frame }, { __index = CHIBI_MOTION })
end

-- Drumroll: the default flight up-right, one flight time per picture
local RENDA = { ms = { 2083, 1950, 2250, 1733, 2000 } }

-- Background

local I7Background = {}
I7Background.__index = I7Background

function I7Background:init(player_num, bpm)
    local spec, path    = self.spec, self.path
    self.clock          = new_clock(bpm)
    self.donbg          = DonBGBase.new(1, player_num, path, DONBG)
    self.bg_normal      = BGNormal.new(path, self.clock)
    self.bg_fever       = BGFever.new(path, self.clock)
    self.fever          = Fever.create(math.random(0, 3), bpm, "background")
    self.max_dancers    = #spec.centers
    self.dancer         = Dancer.BaseDancerGroup.new(0, bpm, self.max_dancers, path, spec.class)
    self.dancer.spawn_positions = spec.spawns
    local by_index = {}
    for _, d in ipairs(self.dancer.dancers) do by_index[d.index] = d end
    for i, index in ipairs(spec.join) do self.dancer.dancers[i] = by_index[index] end
    self.renda          = RendaController.new(path, 0, RENDA)
    self.chibi          = ChibiController.new(bpm, path, 1)
    self.is_clear       = false
    self.is_rainbow     = false
    self.last_milestone = 1
end

function I7Background:update(current_ms, bpm)
    clock_update(self.clock, current_ms, bpm)
    self.donbg:update(current_ms, bpm)
    self.bg_fever:update(current_ms)
    self.fever:update(current_ms, bpm)
    self.dancer:update(current_ms, bpm)
    self.renda:update(current_ms)
    self.chibi:update(current_ms, bpm)
end

function I7Background:add_chibi(player_num)
    BaseChibi.add(self.chibi, CHIBIS[math.random(#CHIBIS)], self.path, player_num, ChibiWave)
end

function I7Background:handle_good(player_num) self:add_chibi(player_num) end

function I7Background:handle_ok(player_num) self:add_chibi(player_num) end

function I7Background:handle_bad(player_num) self.chibi:add_chibi(player_num, true) end

function I7Background:handle_drumroll(player_num) self.renda:add_renda() end

function I7Background:handle_balloon(player_num) self.renda:add_renda() end

function I7Background:handle_gauge(player_num, progress, is_clear, is_rainbow)
    self.donbg:set_clear(is_clear)
    if is_clear and not self.is_clear then self.bg_fever:start() end
    if not is_clear and self.is_clear then self.bg_fever:stop() end
    if is_rainbow and not self.is_rainbow then self.fever:start() end
    if not is_rainbow and self.is_rainbow then self.fever:stop() end
    self.is_clear   = is_clear
    self.is_rainbow = is_rainbow

    local current_milestone
    if is_clear then
        current_milestone = self.max_dancers
    else
        current_milestone = math.min(self.max_dancers - 1, math.floor(progress * self.max_dancers))
    end
    if current_milestone > self.last_milestone then
        for _ = 1, current_milestone - self.last_milestone do self.dancer:add_dancer() end
        self.last_milestone = current_milestone
    elseif current_milestone < self.last_milestone then
        for _ = 1, self.last_milestone - current_milestone do self.dancer:leave_dancer() end
        self.last_milestone = current_milestone
    end
end

function I7Background:draw_back()
    self.bg_normal:draw()
    self.bg_fever:draw()
    self.donbg:draw()
    self.renda:draw()
    self.dancer:draw_slots(self.spec.centers, self.spec.draw)
    self.fever:draw()
    self.chibi:draw()
end

function I7Background:draw_fore() end

function I7Background:destroy()
    self.donbg:destroy()
    self.bg_normal:destroy()
    self.bg_fever:destroy()
    self.fever:destroy()
    self.dancer:destroy()
    self.renda:destroy()
    self.chibi:destroy()
end

-- spec: look = { origin, spark_origin, spark_size } and dancers = { [index] = member } (see
-- member), centers = slot x's left to right, spawns = slots (0-based) in joining order, join =
-- dancer indices in joining order, draw = slots back to front
local function background(path, spec)
    local look, specs = spec.look, {}
    for i, m in pairs(spec.dancers) do specs[i] = member(look, m) end
    spec.class = Dancer.define(specs)
    local cls = setmetatable({ path = path, spec = spec }, { __index = I7Background })
    cls.__index = cls
    cls.new = function(player_num, bpm)
        local self = setmetatable({}, cls)
        self:init(player_num, bpm)
        return self
    end
    return cls
end

return { background = background }
