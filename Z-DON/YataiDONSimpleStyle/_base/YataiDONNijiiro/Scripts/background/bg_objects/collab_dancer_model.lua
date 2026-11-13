-- Collab dancer-count model: troupe size = clamp(floor(4r + 1), 1, max), where
-- r = gauge / clear_point, grown/shrunk against a BaseDancerGroup-shaped object.
local CollabDancerModel = {}
CollabDancerModel.__index = CollabDancerModel

local GAUGE_MAX     = 87.0
local CLEAR_STARTS  = { 52, 60, 69 }          -- easy / normal / hard+oni
local CLEAR_DEFAULT = 69 / GAUGE_MAX

function CollabDancerModel.new(max_dancers)
    return setmetatable({ max = max_dancers, clear_progress = nil }, CollabDancerModel)
end

-- Returns the absolute troupe size for this frame.
function CollabDancerModel:target(progress, is_clear, clear_progress)
    if clear_progress and clear_progress > 0 then
        self.clear_progress = clear_progress
    elseif is_clear and not self.clear_progress then
        local p = progress or 0
        for _, cs in ipairs(CLEAR_STARTS) do
            if p < cs / GAUGE_MAX + 0.0005 then
                self.clear_progress = cs / GAUGE_MAX
                break
            end
        end
        self.clear_progress = self.clear_progress or CLEAR_DEFAULT
    end

    local cp = self.clear_progress or CLEAR_DEFAULT
    local r  = (progress or 0) / cp
    local n  = math.floor(4 * r + 1)
    -- honour the engine's one-gauge-unit-early is_clear flip so the full troupe
    -- and the クリア state arrive on the same frame
    if is_clear then n = self.max end
    if n < 1 then n = 1 elseif n > self.max then n = self.max end
    return n
end

-- Drives a dancer group to the target count: one with set_count (the parent's A3 troupe) is
-- told the count; a BaseDancerGroup-shaped one is grown, and shrunk with leave_dancer (the
-- dancer walks off) where it has one.
function CollabDancerModel:apply(group, progress, is_clear, clear_progress)
    local n = self:target(progress, is_clear, clear_progress)
    if group.set_count then group:set_count(n) return end
    local cur = group.active_count or 0
    if cur <= 0 then return end
    for _ = 1, n - cur do group:add_dancer() end
    local leave = group.leave_dancer or group.remove_dancer
    for _ = 1, cur - n do leave(group) end
end

return CollabDancerModel
