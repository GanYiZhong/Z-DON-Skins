-- SimpleStyle v2: the hint pill. A thin wrapper over core's one hint pill (UI.hint: ink bar, hint drum,
-- bottom-centre footer rule), keeping Nijiiro's GuidePanel API for Indicator (engine: entry players,
-- dan select, settings, song select). Nijiiro's callers pass x, y = 0, 0: the position is the footer
-- rule, so x / y are ignored; the fade is snapped (shown or hidden).
--
-- Exactly one pill per screen. ITEMS[screen] states each screen's own hint:
--   a table  -> that hint, whatever loop the caller asked for;
--   false    -> nothing (the screen script draws its own UI.hint, so the Indicator's would stack);
--   absent   -> the caller's loop: ALL = [rim] えらぶ [face] 決定, DECIDE = [face] 決定.
-- A second draw of the same pill in the same frame (two joined entry players) is skipped.
local UI = require("global.ss_ui")

GuidePanel = {}
GuidePanel.__index = GuidePanel
GuidePanel.Loop = { ALL = 1, DECIDE = 2 }

local ITEMS_ALL = { { "ka", "h_select" }, { "don", "h_decide" } }
local ITEMS_DECIDE = { { "don", "h_decide" } }

local ITEMS = {
    -- settings: the engine asks for ALL; ESC leaves the screen (front no longer bakes a pill)
    SETTINGS = { { "ka", "h_select" }, { "don", "h_decide" }, { nil, "h_esc_back" } },
    -- dan select: the engine asks for DECIDE, but ◀ ▶ course selection is live
    DAN_SELECT = ITEMS_ALL,
    -- the song select family draws its own pill (song_select/ss_sel.lua M:draw_hint, per state and
    -- 2P anchor); the Indicator's ALL pill would stack on it (2P) or show in search / dan states
    SONG_SELECT = false, SONG_SELECT_2P = false, PRACTICE_SELECT = false, AI_SELECT = false,
    RECORD_SELECT = false,
    -- ENTRY: absent = the caller's loop (DECIDE after a join, ALL on the multi-board mode select);
    -- front's entry.lua draws its own DECIDE pill only before anyone joins
}

local last_ms, last_items = nil, nil

function GuidePanel.new()
    return setmetatable({}, GuidePanel)
end

function GuidePanel:draw(loop, x, y, fade)
    local scr = tex.current_screen and tex.current_screen() or ""
    local items = ITEMS[scr]
    if items == false then return end
    if items == nil then
        items = (loop == GuidePanel.Loop.ALL) and ITEMS_ALL or ITEMS_DECIDE
    end
    local now = tex.get_current_ms()
    if now == last_ms and items == last_items then return end
    if UI.hint(items, { vis = fade or 1.0 }) then last_ms, last_items = now, items end
end

return GuidePanel
