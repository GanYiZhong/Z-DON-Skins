-- Timing helpers for the backgrounds. Lengths are multiples of
-- `unit` ms: a beat (60000 / bpm) for things that follow the song, 1 for plain ms.

-- Pure-Lua stand-ins for anim.move and anim.texture_change: the same math, the same start
-- clock and the same fields (start, update, attribute, is_finished), without a C++ call per
-- update or attribute read. For objects that run anims every frame (chibis, the don band).
local LuaMove = {}
LuaMove.__index = LuaMove

local function new_lua_move(duration, distance, delay, ease, loop)
    return setmetatable({ duration = duration, distance = distance, delay = delay, ease = ease,
                          loop = loop or false, attribute = 0, is_finished = false }, LuaMove)
end

-- anim.move(duration, opts) for the options it has: total_distance, delay, loop and quadratic
-- ease_in / ease_out
local MOVE_OPTS = { total_distance = true, delay = true, loop = true, ease_in = true, ease_out = true }

local function move_lua(duration, opts)
    opts = opts or {}
    for k in pairs(opts) do
        if not MOVE_OPTS[k] then error("move_lua: unsupported option " .. tostring(k), 2) end
    end
    for _, k in ipairs({ "ease_in", "ease_out" }) do
        if opts[k] ~= nil and opts[k] ~= "quadratic" then error("move_lua: only quadratic eases", 2) end
    end
    local distance = opts.total_distance or 0
    if math.type(distance) ~= "integer" then -- anim.move's int total_distance, as sol converts it
        distance = distance < 0 and -math.floor(-distance + 0.5) or math.floor(distance + 0.5)
    end
    local ease = opts.ease_in and "in" or opts.ease_out and "out" or nil
    return new_lua_move(duration, distance, opts.delay or 0, ease, opts.loop)
end

function LuaMove:start()
    self.start_ms = tex.get_current_ms()
    self.is_finished = false
    self.attribute = 0
end

function LuaMove:update(current_time_ms)
    if not self.start_ms then return end
    if self.loop and self.is_finished then self:start() end
    local elapsed = current_time_ms - self.start_ms
    if elapsed < self.delay then
        self.attribute = 0
    elseif elapsed >= self.delay + self.duration then
        self.attribute = self.distance
        self.is_finished = true
    else
        local p = (elapsed - self.delay) / self.duration
        if self.ease == "in" then p = p * p elseif self.ease == "out" then p = p * (2 - p) end
        self.attribute = self.distance * p
    end
end

local LuaFrames = {}
LuaFrames.__index = LuaFrames

local function new_lua_frames(duration, textures, opts)
    return setmetatable({ duration = duration, textures = textures, delay = opts and opts.delay or 0,
                          loop = opts and opts.loop or false, attribute = textures[1] and textures[1][3] or 0,
                          is_finished = false }, LuaFrames)
end

function LuaFrames:start()
    self.start_ms = tex.get_current_ms()
    self.is_finished = false
end

function LuaFrames:update(current_time_ms)
    if not self.start_ms then return end
    if self.loop and self.is_finished then self:start() end
    local elapsed = current_time_ms - self.start_ms
    if elapsed < self.delay then return end
    local t = elapsed - self.delay
    if t <= self.duration then
        -- frame_steps' intervals (start, end] run back to back, so at most one holds t; walk a
        -- cursor forward instead of scanning them all, back to the first when t goes back
        local tx, i, n = self.textures, self.cursor or 1, #self.textures
        if i > n or tx[i][1] >= t then i = 1 end
        while i <= n and tx[i][2] < t do i = i + 1 end
        if i <= n and tx[i][1] < t then self.attribute = tx[i][3] end
        self.cursor = i
    else
        self.is_finished = true
    end
end

local function new_cpp_move(duration, distance, delay, ease)
    return anim.move(duration, {
        total_distance = distance,
        delay = delay,
        ease_in = ease == "in" and "quadratic" or nil,
        ease_out = ease == "out" and "quadratic" or nil,
    })
end

local function chain(moves, unit, scale, new_move)
    local out, at = {}, 0
    for _, m in ipairs(moves) do
        local length, distance, ease = m[1], m[2], m[3]
        if distance ~= 0 then
            local move = new_move(length * unit, math.floor(distance * scale), at, ease)
            move:start()
            table.insert(out, move)
        end
        at = at + length * unit
    end
    return out
end

-- Moves { length, distance, ease } run back to back (distance 0 is a hold); the offset
-- they describe is the sum of their attributes
local function chain_moves(moves, unit, scale)
    return chain(moves, unit, scale, new_cpp_move)
end

local function chain_moves_lua(moves, unit, scale)
    return chain(moves, unit, scale, new_lua_move)
end

local function frame_steps(steps, unit)
    local textures, t = {}, 0
    for _, step in ipairs(steps) do
        table.insert(textures, { t, t + step[2] * unit, step[1] })
        t = t + step[2] * unit
    end
    return textures, t
end

-- Frames { index, length } shown back to back
local function frame_change(steps, unit, opts)
    local textures, t = frame_steps(steps, unit)
    return anim.texture_change(t, textures, opts)
end

local function frame_change_lua(steps, unit, opts)
    local textures, t = frame_steps(steps, unit)
    return new_lua_frames(t, textures, opts)
end

local function sum(moves)
    local total = 0
    for _, m in ipairs(moves) do total = total + m.attribute end
    return total
end

local function concat(...)
    local out = {}
    for _, t in ipairs({ ... }) do
        for _, v in ipairs(t) do table.insert(out, v) end
    end
    return out
end

-- Ambient loop: `build()` returns a table of one-shot anims (or lists of them) that is
-- rebuilt every `period` ms, so several anims stay in step without each looping alone
local Loop   = {}
Loop.__index = Loop

function Loop.new(period, build)
    return setmetatable({ period = period, build = build }, Loop)
end

function Loop:update(current_time_ms)
    if not self.t0 or current_time_ms - self.t0 >= self.period then
        self.t0 = current_time_ms
        self.anims = self.build()
    end
    for _, a in pairs(self.anims) do
        if a.update then
            a:update(current_time_ms)
        else
            for _, m in ipairs(a) do m:update(current_time_ms) end
        end
    end
end

-- Pose tables: { beat, frame, x, y, to = { x, y, ease, sx =, sy =, scale =, alpha =, rot = },
-- sx =, sy =, scale =, alpha =, rot =, mirror = true, blend =, key =, hide = true }. A pose holds from its
-- beat until the next one (or the table's `length`), gliding `to` the given values on the way
-- if it has one. x, y left out keep the previous pose's (nil if none has them). pose_at(poses, t) is the pose at beat t
-- (nil before the first and from a `hide` pose). Eases match anim's quadratic ease_in/ease_out.
local EASE = {
    ["in"]  = function(p) return p * p end,
    ["out"] = function(p) return p * (2 - p) end,
}

local function lerp(a, b, k) return b == nil and a or (a or 0) + (b - (a or 0)) * k end

local function pose_at(poses, t)
    local x, y
    for i, p in ipairs(poses) do
        x, y = p[3] or x, p[4] or y
        local next_p = poses[i + 1]
        local finish = next_p and next_p[1] or poses.length or math.huge
        if t < p[1] then return nil end
        if t < finish then
            if p.hide then return nil end
            local at = { frame = p[2], x = x, y = y, key = p.key, mirror = p.mirror, blend = p.blend,
                         sx = p.sx or p.scale or 1, sy = p.sy or p.scale or 1, alpha = p.alpha or 1, rot = p.rot or 0 }
            local to = p.to
            if to then
                local k = (t - p[1]) / (finish - p[1])
                k = EASE[to[3]] and EASE[to[3]](k) or k
                at.x, at.y = lerp(x, to[1], k), lerp(y, to[2], k)
                at.sx, at.sy = lerp(at.sx, to.sx or to.scale, k), lerp(at.sy, to.sy or to.scale, k)
                at.alpha, at.rot = lerp(at.alpha, to.alpha, k), lerp(at.rot, to.rot, k)
            end
            return at
        end
        if p.to then x, y = p.to[1] or x, p.to[2] or y end
    end
    return nil
end

-- Steps { frame, beats } played back to back (any number of phrases) as a pose table. A step
-- can carry pose fields too: { frame, beats, x =, y =, to =, sy =, ... }
local function steps(...)
    local out, beat = {}, 0
    for _, phrase in ipairs({ ... }) do
        for _, s in ipairs(phrase) do
            local pose = { beat, s[1], s.x, s.y }
            for k, v in pairs(s) do
                if type(k) ~= "number" and k ~= "x" and k ~= "y" then pose[k] = v end
            end
            table.insert(out, pose)
            beat = beat + s[2]
        end
    end
    out.length = beat
    return out
end

return {
    pose_at      = pose_at,
    steps        = steps,
    chain_moves  = chain_moves,
    frame_change = frame_change,
    chain_moves_lua  = chain_moves_lua,
    frame_change_lua = frame_change_lua,
    move_lua         = move_lua,
    sum          = sum,
    concat       = concat,
    Loop         = Loop,
}
