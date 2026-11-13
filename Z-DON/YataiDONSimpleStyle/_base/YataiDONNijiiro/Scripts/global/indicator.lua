-- Control-guide panel (drum + arrows) shown while a screen asks for input.

Indicator = {}
Indicator.__index = Indicator

Indicator.State = {
    SKIP   = 0,
    SIDE   = 1,
    SELECT = 2,
    WAIT   = 3,
}

require("global/guide_panel")

function Indicator.new(state)
    local self = setmetatable({}, Indicator)
    self.state = state
    self.panel = GuidePanel.new()
    return self
end

-- { x, y } of the indicator on a screen
function Indicator:screen_pos(screen)
    if screen == "dan_select" then return { -2000, 0 } end
    return { -2000, 1 }
end

function Indicator:update(current_ms) end

__hss_costume_panel = __hss_costume_panel or {}
__hss_entry_guide = __hss_entry_guide or nil     -- { ms, phase = "side" | "mode", count } from the entry scripts

local dd_ok, dan_doors = pcall(require, "song_select/dan_doors")

function Indicator:draw(x, y, fade)
    fade = fade or 1.0
    if dd_ok and not dan_doors.drawn_this_frame() and dan_doors.draw() then return end
    -- costume menu hides the guide (its title box overlaps this panel)
    local now = tex.get_current_ms()
    for _, t in pairs(__hss_costume_panel) do
        if now - t < 100 then return end
    end
    -- entry phases (from entry.lua): TaikoSelect hides the guide, multi-board ModeSelect shows "all"
    local g = __hss_entry_guide
    local show_all = false
    if g and now - g.ms < 100 then
        if g.phase == "side" then return end
        show_all = (g.phase == "mode") and (g.count or 1) > 1
    end
    local loop = GuidePanel.Loop.DECIDE
    if (y or 0) >= 1 or show_all then
        if (y or 0) >= 1 then y = y - 1 end
        loop = GuidePanel.Loop.ALL
    end
    self.panel:draw(loop, x, y, fade)
end

-- DAN_SELECT's top draw slot: plays the shutter's open half.
function Indicator:draw_top()
    if dd_ok then dan_doors.draw_open() end
end
