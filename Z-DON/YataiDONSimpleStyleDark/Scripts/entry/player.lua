-- YataiDONSimpleStyle v2: one joined player on the entry screen. No 3D character and no join cloud:
-- the player's mascot (1P Momo, 2P Hoshi; both already on the stage) cheers with the event sparkle
-- burst over its head (entry.lua draws the burst from SS_ENTRY.join). Nameplate positions as Nijiiro.
EntryPlayer = {}
EntryPlayer.__index = EntryPlayer

local JOIN_MS = 500          -- the "cloud" (join reaction) length the engine waits for

function EntryPlayer.new(side)
    local self = setmetatable({}, EntryPlayer)
    self.side = (side == 0) and 0 or 1
    self.t0 = nil
    self.hold = false
    self.done = false
    return self
end

function EntryPlayer:nameplate_indicator_pos()
    if self.side == 0 then return { 14, 910, 0, 0 } end
    return { 1494, 910, 0, 0 }
end

function EntryPlayer:start_animations(hold_cloud)
    self.t0 = tex.get_current_ms()
    self.hold = hold_cloud and true or false
    SS_ENTRY = SS_ENTRY or {}
    SS_ENTRY.join = SS_ENTRY.join or {}
    SS_ENTRY.join[self.side] = self.t0
    local m = (self.side == 0) and SS_ENTRY.momo or SS_ENTRY.hoshi
    if m then
        -- polish: the joined mascot cheers, then turns to the player and stands ready, hopping 1 sprite
        -- px on every beat (120 BPM from the join) until the screen ends
        m:react("decide")
        m:react("turn", 0)
        m.beat_on, m.bpm, m.beat0 = true, 120, self.t0 + 500
    end
end

function EntryPlayer:update(current_ms)
    self.now = current_ms
    if self.t0 and not self.hold and current_ms - self.t0 >= JOIN_MS then self.done = true end
end

-- no character to place (disable_chara_3d): returning nothing skips the engine's chara draw
function EntryPlayer:draw_drum_back() return nil end

function EntryPlayer:draw_drum_front() end

function EntryPlayer:is_cloud_finished() return self.done end

function EntryPlayer:get_nameplate_fade()
    if not self.t0 then return 0 end
    -- alpha policy: the nameplate pops in (no translucent ramp)
    return (((self.now or self.t0) - self.t0) >= 100) and 1 or 0
end

function EntryPlayer:finish_cloud()
    self.hold = false
end
