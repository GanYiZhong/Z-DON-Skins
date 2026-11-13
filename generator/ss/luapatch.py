"""Parent (PyTaikoGreen) Lua scripts we copy and patch at build time. Each patch is an exact
(old, new) string pair; the build fails loudly if the parent ever changes the target text, so
engine-side updates of the parent are noticed on the next build."""

GAME_LUA_PATCHES = {
    "game/score_counter.lua": [
        ("local POPUP_COLOR = { { 254, 102, 0 }, { 84, 250, 238 } }",
         "local POPUP_COLOR = { { 255, 90, 78 }, { 61, 182, 227 } }   -- SimpleStyle p1 / p2"),
        # one popup at a time: stacked popups of the flat digits read as a garbled number
        ("    local str = tostring(math.max(math.floor(value), 0))\n",
         "    local str = tostring(math.max(math.floor(value), 0))\n"
         "    -- SimpleStyle: the newest popup replaces the others (the counter catches up at once)\n"
         "    if #self.popups > 0 then self.popups = {}; self:set_count(self.ss_latest or self.score) end\n"),
        ("function ScoreCounter:update(ms, score)\n",
         "function ScoreCounter:update(ms, score)\n    self.ss_latest = score\n"),
    ],
}
