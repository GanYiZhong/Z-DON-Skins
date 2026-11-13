"""Smoke module: proves the v2 pipeline end to end (ancestor geometry, density, crisp chrome, crop ->
frame folder, a Green-sourced key at x1.5, a patched ancestor script). Screen agents replace it:
game/lane belongs to the game agent, who should delete this module when taking the subset over."""
from __future__ import annotations

from . import chrome
from .atlas import SubsetWriter
from .style import C, COURSES, U, Canvas

NAME = "smoke"
OWNS = ["Graphics/game/lane", "Graphics/game/ai_battle", "Scripts/game/score_counter.lua"]

LUA_PATCHES = {
    "game/score_counter.lua": [
        ("local POPUP_COLOR = { { 254, 102, 0 }, { 84, 250, 238 } }",
         "local POPUP_COLOR = { { 232, 69, 58 }, { 47, 134, 214 } }   -- SimpleStyle p1 / p2"),
    ],
}


def _score_cover(i, n, w, h):
    # Nijiiro 304x52: the score sits on it; a plain panel with a 1U accent edge on the left
    cv = Canvas(w, h)
    x1, y1 = chrome.fit(w, h, U)
    b = chrome.panel(cv, 0, 0, x1, y1, fill=C["paper"])
    cv.rect(b.ix0, b.iy0, b.ix0 + 2 * U, b.iy1, C["p1"])
    return cv.result()


def _difficulty(i, n, w, h):
    # Nijiiro 132x96 x7 (course of the player): a chip per course, centred
    cv = Canvas(w, h)
    key, ja, _ = COURSES[min(i, len(COURSES) - 1)]
    x0, y0 = 3 * U, (h // 2 - 6 * U) // U * U
    chrome.chip(cv, x0, y0, (w - 3 * U) // U * U, y0 + 12 * U, ja, accent=C[key], size=18)
    return cv.result()


def _scoreboard(i, n, w, h):
    return chrome.image(w, h, chrome.panel)


def build(ctx):
    lane = SubsetWriter(ctx.G, "game", "lane")
    lane.put("lane_score_cover", _score_cover)
    lane.put("lane_difficulty", _difficulty)
    ai = SubsetWriter(ctx.G, "game", "ai_battle")
    ai.put("scoreboard", _scoreboard)
    return lane.write() + ai.write()
