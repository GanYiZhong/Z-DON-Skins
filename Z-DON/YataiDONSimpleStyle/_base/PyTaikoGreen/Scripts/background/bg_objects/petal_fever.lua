local Timing = require("background/bg_objects/timing")

local chain_moves, sum = Timing.chain_moves, Timing.sum

-- Clear background with falling petals (A3, Touken Ranbu): drawn over the normal one, which
-- stays underneath. A haze fades in over `haze_in` beats; a beat in, the petal streams fade in
-- over half a beat. Losing clear fades the haze out over `haze_out` beats and the petals over
-- `petals_out`. Transitions in beats.
-- Each stream is three tiles (texture.json indices `first`.. of its `key`) drifting by
-- `dx`, `dy` over a `flight` (ms); a new pass starts every half flight, so two are on screen.
-- `warm` streams start with both passes showing (Lumen places the second at frame 0);
-- `fade_out` fades a pass over the second half of its flight; `rotation` turns each tile
-- about its centre (`half` px in).
-- spec: { path, haze = { key, blend }, haze_in, haze_out, petals_out, streams }

-- A value in thousandths that eases from wherever it is to a target (fade in/out envelopes)
local function envelope(current, moves, unit)
    return { offset = current, moves = chain_moves(moves, unit, 1) }
end
local function env_value(env) return env.offset + sum(env.moves) end
local function env_update(env, current_time_ms)
    for _, m in ipairs(env.moves) do m:update(current_time_ms) end
end

local PETALS_IN = { { 1, 0 }, { 0.5, 1000 } }
local TILES     = 3

local PetalFever   = {}
PetalFever.__index = PetalFever

function PetalFever.new(bpm, spec)
    local self = setmetatable({}, PetalFever)
    self.spec  = spec
    self.name  = "bg_fever_0"
    tex.load_folder(spec.path, "bg_fever/" .. self.name)
    local function id(key) return tex.get_texture(spec.path .. "/" .. self.name .. "/" .. key) or 0 end
    self._id_haze = id(spec.haze.key)
    self._ids     = {}
    for i, stream in ipairs(spec.streams) do self._ids[i] = id(stream.key) end
    self.beat     = 60000 / bpm
    self.haze     = envelope(0, {}, 1)
    self.petals   = envelope(0, {}, 1)
    self.streams  = {}
    return self
end

local function new_pass(stream, delay)
    local half = anim.move(stream.flight / 2, { total_distance = 1000, delay = delay })
    half:start()
    return half
end

function PetalFever:start()
    local haze, petals = env_value(self.haze), env_value(self.petals)
    self.haze   = envelope(haze, { { self.spec.haze_in, 1000 - haze } }, self.beat)
    self.petals = envelope(petals, { PETALS_IN[1], { PETALS_IN[2][1], 1000 - petals } }, self.beat)
    -- the streams start over as the petals begin to fade in
    for i, stream in ipairs(self.spec.streams) do
        self.streams[i] = { half = new_pass(stream, PETALS_IN[1][1] * self.beat), laps = stream.warm and 1 or 0 }
    end
end

function PetalFever:stop()
    local haze, petals = env_value(self.haze), env_value(self.petals)
    self.haze   = envelope(haze, { { self.spec.haze_out, -haze } }, self.beat)
    self.petals = envelope(petals, { { self.spec.petals_out, -petals } }, self.beat)
end

function PetalFever:update(current_time_ms, bpm)
    if bpm then self.beat = 60000 / bpm end
    env_update(self.haze, current_time_ms)
    env_update(self.petals, current_time_ms)
    for i, s in pairs(self.streams) do
        s.half:update(current_time_ms)
        if s.half.is_finished then
            s.half = new_pass(self.spec.streams[i])
            s.laps = s.laps + 1
            s.half:update(current_time_ms)
        end
    end
end

function PetalFever:draw_stream(i, opacity, scale)
    local stream, s = self.spec.streams[i], self.streams[i]
    -- pass 0 is in the first half of its flight, pass 1 (once there is one) in the second
    for pass = 0, math.min(s.laps, 1) do
        local p = (pass * 1000 + s.half.attribute) / 2000
        local fade = opacity * (stream.alpha or 1)
        if stream.fade_out and p > 0.5 then fade = fade * (1 - p) * 2 end
        local origin = stream.rotation and stream.half * scale or 0
        for t = 0, TILES - 1 do
            tex.draw_texture(self._ids[i], {
                index    = (stream.first or 0) + t,
                x        = math.floor(stream.dx * p * scale) + origin,
                y        = math.floor(stream.dy * p * scale) + origin,
                fade     = fade,
                blend    = stream.blend,
                rotation = stream.rotation,
                origin   = stream.rotation and { origin, origin } or nil,
            })
        end
    end
end

function PetalFever:draw()
    local haze = env_value(self.haze) / 1000
    if haze > 0 then tex.draw_texture(self._id_haze, { fade = haze, blend = self.spec.haze.blend }) end
    local petals = env_value(self.petals) / 1000
    if petals <= 0 then return end
    local scale = tex.get_screen_scale()
    for i in ipairs(self.spec.streams) do
        if self.streams[i] then self:draw_stream(i, petals, scale) end
    end
end

function PetalFever:destroy()
    tex.unload_folder(self.spec.path, "bg_fever/" .. self.name)
end

return PetalFever
