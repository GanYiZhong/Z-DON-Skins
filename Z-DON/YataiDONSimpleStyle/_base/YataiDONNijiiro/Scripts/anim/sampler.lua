-- Sampler for the exported clip tables: lerp between kept frames, clamp to the ends.

local M = {}

local Track = {}
Track.__index = Track

local Clip = {}
Clip.__index = Clip

local FPS_MS = 60.0 / 1000.0     -- ms -> arcade frames

function M.frames(ms) return ms * FPS_MS end
function M.ms(frames) return frames / FPS_MS end

-- per-clip converters honour the table's own fps field
function Clip:frames(ms)  return ms * (self.fps or 60) / 1000.0 end
function Clip:msof(frames) return frames * 1000.0 / (self.fps or 60) end

-- binary search: the last row whose frame is <= f
local function seek(rows, f)
    local lo, hi = 1, #rows
    if f <= rows[lo][1] then return lo end
    if f >= rows[hi][1] then return hi end
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        -- upper-biased midpoint: must decrement hi or the loop never shrinks
        if rows[mid][1] <= f then lo = mid else hi = mid - 1 end
    end
    return lo
end

-- unpack is `table.unpack` in 5.2+; fall back to the global otherwise
local tunpack = table.unpack
if tunpack == nil then tunpack = unpack end

function Clip:at(name, f)
    local rows = self.tracks[name]
    if not rows or #rows == 0 then return nil end
    local n = #rows
    local i = seek(rows, f)
    local a = rows[i]
    if i >= n or f <= a[1] then return tunpack(a, 2, #a) end
    local b = rows[i + 1]
    local u = (f - a[1]) / (b[1] - a[1])
    local out = {}
    for k = 2, #a do out[k - 1] = a[k] + (b[k] - a[k]) * u end
    return tunpack(out, 1, #out)
end

-- one named field of one track, by the name the exporter wrote into `fields`
function Clip:get(name, f, field)
    local idx = self.index[field]
    if not idx then return nil end
    local rows = self.tracks[name]
    if not rows or #rows == 0 then return nil end
    local n = #rows
    local i = seek(rows, f)
    local a = rows[i]
    if i >= n or f <= a[1] then return a[idx + 1] end
    local b = rows[i + 1]
    local u = (f - a[1]) / (b[1] - a[1])
    return a[idx + 1] + (b[idx + 1] - a[idx + 1]) * u
end

function Clip:label(name)  return self.labels and self.labels[name] end
function Clip:has(name)    return self.tracks[name] ~= nil end
function Clip:first()      return self.range[1] end
function Clip:last()       return self.range[2] end

-- M.safe returns the real clip or this NULL clip (readers return nil / empty range).
-- Trap: files here must not share a stem with any screen script (flat indexing, first wins).
local NULL = {}
NULL.__index = NULL
function NULL:at()    return nil end
function NULL:get()   return nil end
function NULL:label() return nil end
function NULL:has()   return false end
function NULL:first() return 0 end
function NULL:last()  return 0 end
function NULL:frames(ms) return ms * FPS_MS end   -- keep NULL's interface complete
function NULL:msof(frames) return frames / FPS_MS end
M.NULL = setmetatable({}, NULL)

-- never raises: returns the clip, or the NULL clip if the table is missing or malformed
function M.safe(path)
    local ok, clip = pcall(M.load, path)
    if ok and clip and clip.tracks and clip.fields and clip.range then return clip end
    return M.NULL
end

local cache = {}

-- `path` is a require() path, e.g. "anim/folder_board".
function M.load(path)
    local c = cache[path]
    if c then return c end
    local data = require(path)
    data.index = {}
    for i, name in ipairs(data.fields) do data.index[name] = i end
    setmetatable(data, Clip)
    cache[path] = data
    return data
end

return M
