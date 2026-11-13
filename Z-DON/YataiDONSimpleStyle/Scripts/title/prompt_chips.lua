-- YataiDONSimpleStyle v2: the two start signs on the title (centred on x = W/4 and 3W/4, where title.cpp
-- prints its hit_taiko_to_start prompt). The engine's prompt is white with a fixed 4 px black outline,
-- which clogged the CJK strokes on the paper sign, so ss/v2_front.py parks it off screen and the signs
-- carry their own words: [hint drum][1P / 2P tag] 敲打太鼓开始！ in ink, 36 px, in the player's language.
-- The words blink with the engine's animation 14 (the prompt's hard blink); the sign, drum and tag stay.
-- Panel: 1U ink border, 1U shadow, 1U notch, 4U padding. Numbers: ss/v2_front.py PROMPT_*.
local UI = require("global.ss_ui")

local U = UI.U
local Y0, Y1 = 948, 1014                  -- snap(PROMPT_Y + 10.5 - 4U), snap(PROMPT_Y + 54 + 4U)
local CX = { 480, 1440 }                  -- the engine's prompt centres (W/4, 3W/4)
local PAD, ICON = 4 * U, 10 * U           -- padding; the hint drum (8U) + 2U gap
local TAG_W, TAG_H, GAP = 18 * U, 11 * U, 3 * U   -- text24: "1P" is now 24 px: 3U inner padding each side

local function snap(v) return math.floor(v / U + 0.5) * U end

local PromptChips = {}
local cache_s, cache_t
local tags = {}
local blink

local function words(s)
    if s ~= cache_s then
        cache_s, cache_t = s, UI.text(s, 36, "ink")
    end
    return cache_t
end

-- polish: the hint drum on each chip taps along: it hops 1U for 100 ms every 400 ms (the attract show's
-- beat, 150 BPM), from the absolute clock so it never skips at the warning <-> attract switch
local TAP_EVERY, TAP_MS = 400, 100

function PromptChips.draw(now)
    local s = UI.t("title_start")
    if not s then return end
    local t = words(s)
    if not t or not t.width then return end
    if blink == nil then
        local ok, a = pcall(tex.get_animation, 14, "title")
        blink = ok and a or false
    end
    local vis = blink and blink.attribute or 1
    local drum = UI.T("ss_ui/hint_drum")
    local cy = (Y0 + Y1) / 2
    for i, cx in ipairs(CX) do
        local inner = ICON + TAG_W + GAP + t.width
        local x0 = snap(cx - inner / 2 - PAD)
        local x1 = snap(cx + inner / 2 + PAD)
        UI.chrome.panel(x0, Y0, x1 - x0, Y1 - Y0, UI.P.paper)
        local x = x0 + PAD
        if drum then
            local hop = (now and (now % TAP_EVERY) < TAP_MS) and U or 0
            tex.draw_texture(drum, { frame = 0, x = x, y = snap(cy - 4 * U) - hop })
        end
        x = x + ICON
        tags[i] = tags[i] or UI.text(i .. "P", 18, "on_ink")
        local ix, iy, iw, ih = UI.chrome.chip(x, snap(cy - TAG_H / 2), TAG_W, TAG_H, i == 2 and UI.P.p2 or UI.P.p1)
        UI.draw_text(tags[i], ix + iw / 2, iy + ih / 2, "c")
        UI.draw_text(t, x + TAG_W + GAP, cy, "l", vis)
    end
end

return PromptChips
