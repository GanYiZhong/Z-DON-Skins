"""v2 module `stage`: the gameplay background (bible 2.4 "festival stage"), replacing Nijiiro's
Scripts/background system (donbg / bg_normal / fever / dancers / footer / renda / chibi / collabs:
~1100 texture keys) with our own light 8-bit scene. None of Nijiiro's background art is ever loaded:
our Scripts/background/background.lua only loads Graphics/background/ss_stage.

Scene (logical 1920x1080; the HUD owns the lane band 276-540, in 2P 276-870):
  * one sky behind everything (sky token; paler cloud2 after a failed song), 3 pixel clouds in the
    top band that drift 1U every 500 ms (the only motion behind the notes)
  * 1P lower half: horizon checker at 714, cream backdrop, a wooden festival stage (x 552-1872, floor
    y 948) with two posts and a lantern rope at 561 (just under the HUD), the taiko, ground at 1014.
    Mascot k by role: Momo "scene" (k=9) drums at the taiko, Hoshi "menu" (k=6) stands beside her
    with a speech bubble (box y 648-714; Lua UI.bubble, text in the player's language). RESERVED_INFO (left of the stage) stays plain for the HUD.
  * GOGO: a 2-frame flame band on the horizon between the posts, behind the cast; the drummers keep
    drumming on every half beat.
  * clear (gauge over the norma line): the lanterns light up (one burst each); fail: lanterns go dark,
    the sky pales, Momo sits.
  * 2P / DAN: the bottom band is the same stage seen further away: deck on the ground line 1047, two
    posts, a lantern rope at 873 with small lanterns (lit like 1P), deco.TAIKO at 2U. Both mascots
    "menu" (k=6). 2P: Momo at the 1P drum, Hoshi at the 2P drum (no bubble). DAN: Hoshi + bubble left,
    Momo drums.
  * GAME_PRACTICE / AI_GAME: sky + clouds only (the practice HUD / second lane own the screen).
  * stagelux (10-29): the sky is a stepped ordered-dither gradient (Lua bands + UI.wipe checker rows) with
    four states (day / clear: warm horizon / GOGO: dusk / fail: pale) that sweep in band by band through
    the dither levels; two parallax cloud layers moving 1 phys px per 100 ms (near) / 200 ms (far);
    distant mountains + a festival town (yagura, pagoda, nobori, lantern strings) on the horizon whose
    lanterns light with the soul gauge (Nijiiro's dancer-count rule) and whose windows light at dusk;
    animated pixel fireworks (rise 3 + burst 8 frames, 100 ms each) during GOGO, sparser at a full
    (rainbow) gauge, and a salvo at a cleared song end. Fireworks only in free top-band slots (never
    behind the title or the gauge) and, in 2P, in the band sky right of the deck.

Everything is crisp, palette-only, on the U grid; the Lua (lua/stage/background/) draws it."""
from __future__ import annotations

import os
import shutil

import json

from . import deco, strings
from .atlas import OwnSubset, _save, phys_xy, resolve, subset_keys, subsets
from .style import C, U, Canvas, blank_l

NAME = "v2_stage"
OWNS = ["Graphics/background", "Scripts/background"]

W, H = 1920, 1080
INK, PAPER = C["ink"], C["paper"]

# ---------------------------------------------------------------- geometry (logical, all on U)
HORIZON_Y = 714            # 2-row checker 714..738 (cell 4U)
GROUND_Y = 1014            # 1P ground line (ink line + grass + bricks to the bottom)
FLOOR_Y = 948              # stage floor: the characters stand here
STAGE_X0, STAGE_X1 = 552, 1872
POST_W = 4 * U
POST_TOP = 549             # posts + rope sit just under the lane HUD (ends 540) so the k=9 Momo
ROPE_Y = 561               #   (art top 651) and the bubble (top 648) clear the lantern row (564-627)
N_LANTERNS = 10
LANTERN_CELL = 3 * U       # 5x7 cells -> 45x63
# mascot k by role (SCREEN_GUIDE_V2 2): 1P Momo "scene" (9), Hoshi "menu" (6); 2P / dan band "menu"
MOMO_CX = 840              # k=9: art 687..993 (drum_r bachi reach 993 and strike the taiko's rim)
TAIKO_CX = 1065            # deco.taiko 3U cells: 975..1155 x 768..948
HOSHI_CX = 1275            # k=6: art 1197..1365, head top ~756
# Hoshi's bubble (Lua UI.bubble, sized to the measured text, growing right from BUBBLE_X): box 648..714,
# 3-step tail tip at (1263, 747) just above Hoshi's ears (~756)
BUBBLE_H = 22 * U          # 66
BUBBLE_TAIL_H = 11 * U     # UI.bubble: box edge -> tip (D.BUBBLE.tail_h - 2U)
BUBBLE_X = HOSHI_CX - 16 * U       # 1227
BUBBLE_Y = 648
BUBBLE_TIP_X = BUBBLE_X + 12 * U   # 1263
# GOGO: the flame strip is a backdrop band behind the cast (base on the horizon checker, between the
# posts), never at the characters' feet
FLAME_X0 = STAGE_X0 + 8 * U + POST_W          # inside the posts
FLAME_X1 = STAGE_X1 - 8 * U - POST_W
FLAME_Y1 = HORIZON_Y + 8 * U                  # 738
FLAME_Y0 = FLAME_Y1 - 16 * U                  # 690
RESERVED_INFO = (48, 576, 528, 1002)   # x0, y0, x1, y1 kept plain for the HUD's info strip

# 2P / dan bottom band: the same stage seen further away. The deck floor is the band's ground line
# (G2_Y); the deck front fills the last 33 px; two posts carry a lantern rope at y 873 (below the 2P
# HUD, which owns 276-870). k=6 figures: art top ~849 (the 2P gauge ends at ~832).
G2_Y = 1047
D2_X0, D2_X1 = 708, 1500         # deck span: right of the 2P combo chip (x <= 690), left of the hint
D2_POST_TOP = 906                #   pill zone (x >= 1500, y 981-1023)
D2_ROPE_Y = 909
D2_LANTERN_CELL = 2 * U          # 30x42
N2_LANTERNS = 8
TAIKO2_CELL = 2 * U              # deco.TAIKO at 2U = 120: the 1P drum's proportion to a k=6 figure
P2_MOMO_CX, P2_TAIKO1_CX = 870, 1020
P2_HOSHI_CX, P2_TAIKO2_CX = 1230, 1380
DAN_HOSHI_CX = 960               # dan: Hoshi left of Momo, facing her; bubble over Hoshi
DAN_MOMO_CX, DAN_TAIKO_CX = 1185, 1335
DAN_BUBBLE_X = DAN_HOSHI_CX - 16 * U
DAN_BUBBLE_Y = 747               # box 747..813 (exam rows end ~718), tail tip 846 over Hoshi (~855)

CLOUDS = [("M", 600, 126), ("S", 1050, 150), ("M", 1380, 135)]   # x, y in the top band (1P)
CLOUDS_2P = []   # the 2P / dan band is the stage now: no cloud drifting behind the drums

# ---------------------------------------------------------------- Hoshi's lines (3-5 per state)
# The words live in ss/strings.py as say_<state>_<i> (ja / en / zh / ko); Lua draws them at run time with
# UI.bubble in the player's language. Only the key lists are generated here.
STATES = ("start", "combo_50", "combo_100", "combo_200", "combo_300", "combo_400", "combo_500",
          "combo_many", "gogo", "miss", "norma", "roll", "balloon", "clear", "full_combo", "donderful",
          "fail", "dan_next")


def line_keys():
    out = {}
    for state in STATES:
        keys = []
        while f"say_{state}_{len(keys)}" in strings.STRINGS:
            keys.append(f"say_{state}_{len(keys)}")
        if not 3 <= len(keys) <= 5:
            raise SystemExit(f"v2_stage: Hoshi state {state!r} has {len(keys)} lines in ss/strings.py (3-5)")
        out[state] = keys
    return out


COMBO_STEPS = (50, 100, 200, 300, 400, 500)

def _horizon(warm):
    cv = Canvas(W, 8 * U)
    # the horizon's sky row matches the bottom of the gradient: cloud2 by day / failed, glow once warm
    deco.horizon_dither(cv, 0, 0, W, top=C["glow"] if warm else C["cloud2"])
    return cv.result()


def _stage_1p():
    """Lower half of the 1P scene from POST_TOP to the bottom: backdrop, posts, rope, platform,
    taiko, ground. Transparent above the horizon checker (the sky is a Lua rect)."""
    y0 = POST_TOP
    cv = Canvas(W, H - y0)

    def r(x0, ya, x1, yb, col):
        cv.rect(x0, ya - y0, x1, yb - y0, col)

    r(0, HORIZON_Y + 8 * U, W, GROUND_Y, C["bg0"])          # cream backdrop under the checker
    _posts(r, (STAGE_X0 + 4 * U, STAGE_X1 - 4 * U - POST_W), POST_TOP, FLOOR_Y, POST_W)
    # rope between the post tops (lanterns are drawn by Lua so they can light up)
    rx0, rx1 = STAGE_X0 + 4 * U + POST_W + U, STAGE_X1 - 4 * U - POST_W - U
    r(rx0, ROPE_Y, rx1, ROPE_Y + U, INK)
    # platform: ink top line, plank face, ink line, front boards with wood2 seams
    r(STAGE_X0, FLOOR_Y, STAGE_X1, GROUND_Y, INK)
    r(STAGE_X0 + U, FLOOR_Y + U, STAGE_X1 - U, FLOOR_Y + 4 * U, C["wood"])
    r(STAGE_X0 + U, FLOOR_Y + 5 * U, STAGE_X1 - U, GROUND_Y, C["wood"])
    r(STAGE_X0 + U, FLOOR_Y + 5 * U, STAGE_X1 - U, FLOOR_Y + 6 * U, C["wood2"])
    for sx in range(STAGE_X0 + 20 * U, STAGE_X1 - U, 20 * U):
        r(sx, FLOOR_Y + 6 * U, sx + U, GROUND_Y, C["wood2"])
    # ground strip across the screen (the stage stands on it)
    gcv = Canvas(W, H - GROUND_Y)
    deco.ground(gcv, 0, 0, W, H - GROUND_Y)
    cv.paste(gcv.result(), 0, GROUND_Y - y0)
    # the taiko, standing on the stage floor beside Momo
    deco.taiko(cv, TAIKO_CX, FLOOR_Y - y0)
    return cv.result()


def _posts(r, xs, top, floor, w):
    """Wooden posts (ink outline, wood2 shade, ink cap) from `top` down to `floor`; r(x0, y0, x1, y1, col)."""
    for px0 in xs:
        r(px0 - U, top, px0 + w + U, floor, INK)
        r(px0, top + U, px0 + w, floor, C["wood"])
        r(px0 + w - U, top + U, px0 + w, floor, C["wood2"])
        r(px0 - 2 * U, top, px0 + w + 2 * U, top + 3 * U, INK)   # cap
        r(px0 - U, top + U, px0 + w + U, top + 2 * U, C["wood2"])


D2_POST_W = 3 * U
D2_POSTS = (D2_X0 + 3 * U, D2_X1 - 3 * U - D2_POST_W)
D2_ROPE = (D2_POSTS[0] + D2_POST_W + U, D2_POSTS[1] - U)


def _stage_2p(drums):
    """2P / dan bottom band: the 1P stage seen further away. Ground strip at G2_Y; over it the deck
    (ink floor line at G2_Y, plank face with seams down to the screen bottom), two posts and the lantern
    rope at D2_ROPE_Y (lanterns are Lua, so they light up like 1P), and deco.TAIKO at 2U on the deck."""
    y0 = D2_POST_TOP
    cv = Canvas(W, H - y0)

    def r(x0, ya, x1, yb, col):
        cv.rect(x0, ya - y0, x1, yb - y0, col)

    g = Canvas(W, H - G2_Y)
    deco.ground(g, 0, 0, W, H - G2_Y)
    cv.paste(g.result(), 0, G2_Y - y0)
    _posts(r, D2_POSTS, D2_POST_TOP, G2_Y, D2_POST_W)
    r(D2_ROPE[0], D2_ROPE_Y, D2_ROPE[1], D2_ROPE_Y + U, INK)
    # deck: ink outline, wood face, one wood2 rule, seams every 14U
    r(D2_X0, G2_Y, D2_X1, H, INK)
    r(D2_X0 + U, G2_Y + U, D2_X1 - U, H, C["wood"])
    r(D2_X0 + U, G2_Y + 4 * U, D2_X1 - U, G2_Y + 5 * U, C["wood2"])
    for sx in range(D2_X0 + 14 * U, D2_X1 - U, 14 * U):
        r(sx, G2_Y + 5 * U, sx + U, H, C["wood2"])
    for cx in drums:
        deco.taiko(cv, cx, G2_Y - y0, cell=TAIKO2_CELL)
    return cv.result()


def _lantern(state, cell=LANTERN_CELL):
    # off: unlit paper lanterns; lit (norma cleared): red with gold light; dark (failed): grey
    pal = dict(deco.LANTERN_PAL)
    if state == "lit":
        pal["W"] = C["clear"]
    elif state == "off":
        pal.update({"R": C["bg2"], "W": C["paper"], "G": C["line"]})
    else:
        pal.update({"R": C["line"], "W": C["bg3"], "G": C["mute"]})
    w, h = deco.size_of(deco.LANTERN, cell)
    cv = Canvas(w, h)
    deco.cells(cv, 0, 0, deco.LANTERN, pal, cell)
    return cv.result()


FLAME_CELL = 2 * U


def _flame(frame):
    """GOGO strip (16U tall, 2U cells, between the 1P posts on the horizon: behind the cast): 3 solid gogo-orange rows, then flame tongues whose upper
    cells turn gold and whose tips are checker-dithered. Two frames (tongues shift) toggled every
    200 ms by Lua."""
    w, h = FLAME_X1 - FLAME_X0, FLAME_Y1 - FLAME_Y0
    cv = Canvas(w, h)
    rows = h // FLAME_CELL                  # 8
    cols = w // FLAME_CELL
    shape = (8, 7, 5, 4, 5, 7, 6, 4, 3, 4, 6)
    for c in range(cols):
        hgt = shape[(c + frame * 3) % len(shape)]
        for rr in range(hgt):
            y = h - (rr + 1) * FLAME_CELL
            x = c * FLAME_CELL
            tip = rr >= hgt - 2
            if tip and (c + rr + frame) % 2:
                continue                     # dithered tip
            col = C["gogo"] if rr < max(3, hgt - 3) else C["clear"]
            cv.rect(x, y, x + FLAME_CELL, y + FLAME_CELL, col)
    return cv.result()


def _cloud(size):
    w, h = deco.size_of(deco.CLOUD_S if size == "S" else deco.CLOUD_M, deco.CLOUD_CELL)
    cv = Canvas(w, h)
    deco.cloud(cv, 0, 0, size)
    return cv.result()


# ---------------------------------------------------------------- stagelux: sky, scenery, fireworks
# Sky gradient: (y, token) stops; between two stops a 3-step checker ramp (UI.wipe levels 1/2/3, RAMP_ROW
# each) ends on the stop's y. Every y is a multiple of the wipe cell (6). The 1P lane hides 276..540 and
# the 2P lanes 276..870, so the top band and the low band are written separately.
RAMP_ROW = 12                                   # 2 wipe cells per level: both checker phases show
TOP_STOPS = {                                   # the top band (every layout), 0..276
    "day":   [(0, "sky_hi"), (90, "sky_mid"), (192, "sky")],
    "clear": [(0, "sky_mid"), (72, "sky"), (150, "glow")],
    "dusk":  [(0, "dusk0"), (102, "dusk1"), (210, "dusk2")],
    "fail":  [(0, "cloud2")],
}
LOW_STOPS = {                                   # (offset from the low band top, token)
    "day":   [(0, "sky"), (96, "cloud2")],
    "clear": [(0, "sky"), (42, "glow")],
    "dusk":  [(0, "dusk2"), (84, "glow")],
    "fail":  [(0, "cloud2")],
}
TOP_BAND_Y1 = 276
LOW_BAND = {"1p": (540, HORIZON_Y), "2p": (870, 1047)}


def sky_segments(state, layout):
    """[(y0, y1, base, over, level)]: a base fill plus an `over` checker at wipe level 1..3 (0 = none)."""
    segs = []

    def band(stops, y0, y1):
        prev = None
        for i, (y, tok) in enumerate(stops):
            ys = y0 + y
            ye = y0 + stops[i + 1][0] - 3 * RAMP_ROW if i + 1 < len(stops) else y1
            if prev is not None:
                for lv in (1, 2, 3):
                    a = ys - (4 - lv) * RAMP_ROW
                    segs.append((a, a + RAMP_ROW, prev, tok, lv))
            segs.append((ys, ye, tok, None, 0))
            prev = tok

    band(TOP_STOPS[state], 0, TOP_BAND_Y1)
    lo0, lo1 = LOW_BAND[layout]
    band(LOW_STOPS[state], lo0, lo1)
    for a, b, _, _, lv in segs:   # checker rows start on the wipe cell grid (6) so both phases show
        assert b > a and (lv == 0 or (a % 6 == 0 and b % 6 == 0)), (state, layout, a, b)
    return segs


# distant scenery: cells of U on a 640 x 40 grid (1920 x 120 logical), bottom row on the horizon
SC = U
SC_COLS, SC_ROWS = W // SC, 40
SCN_H = SC_ROWS * SC
YAGURA_C, PAGODA_C = 110, 556
SCENE_PAL = {   # state -> (mountain, snow cap, town)
    "day": ("sky_mid", "cloud2", "haze2"),
    "dusk": ("dusk1", "dusk2", "dusk_t"),
    "fail": ("sky", "cloud2", "sky_mid"),
}


def _mountain_cells():
    peaks = [(30, 20), (150, 31), (262, 18), (372, 27), (470, 21), (590, 33), (650, 16)]
    body, caps = set(), set()
    for c in range(SC_COLS):
        h = max(0, max(ph - abs(c - pc) // 2 for pc, ph in peaks))
        for r in range(h):
            body.add((c, r))
        if h >= 26:
            for r in range(h - 3, h):
                caps.add((c, r))
    return body, caps


def _seg_cells(c0, r0, c1, r1):
    n = max(abs(c1 - c0), abs(r1 - r0), 1)
    return {(round(c0 + (c1 - c0) * t / n), round(r0 + (r1 - r0) * t / n)) for t in range(n + 1)}


def _town():
    """(silhouette cells, lanterns [(c, r)] = bottom-left cell of a 2x2 lantern, window cells)."""
    town, wins = set(), set()

    def box(c0, r0, c1, r1):
        for c in range(max(0, c0), min(SC_COLS, c1)):
            for r in range(r0, r1):
                town.add((c, r))

    # houses: (col, width, wall rows); hip roofs with a 1-col eave; gaps let the mountains through
    houses = [(0, 14, 5), (16, 11, 7), (30, 16, 4), (48, 12, 6), (63, 10, 9), (76, 16, 5),
              (128, 14, 6), (144, 18, 4), (164, 12, 8), (190, 15, 5), (207, 11, 7), (220, 20, 4),
              (243, 13, 6), (258, 16, 5), (277, 10, 8), (290, 18, 4), (312, 12, 6), (327, 15, 5),
              (345, 11, 9), (358, 17, 4), (378, 13, 6), (394, 16, 5), (413, 10, 7), (426, 18, 4),
              (448, 14, 6), (465, 12, 5), (480, 16, 8), (499, 13, 4), (515, 15, 6), (532, 10, 5),
              (572, 14, 5), (588, 12, 7), (603, 16, 4), (622, 18, 6)]
    for c, w, hb in houses:
        box(c, 0, c + w, hb)
        box(c - 1, hb, c + w + 1, hb + 1)
        box(c, hb + 1, c + w, hb + 2)
        box(c + 2, hb + 2, c + w - 2, hb + 3)
        if w >= 12:
            box(c + 4, hb + 3, c + w - 4, hb + 4)
        if hb >= 4:                               # windows (lit at dusk): 1x1 cells every 4 cols
            for wc in range(c + 2, c + w - 2, 4):
                wins.add((wc, hb - 3))
                if hb >= 7:
                    wins.add((wc, hb - 6))
    # yagura (festival tower): two legs with X braces, platform, curtain box, roof, pole
    y = YAGURA_C
    box(y - 8, 0, y - 6, 18)
    box(y + 6, 0, y + 8, 18)
    for a, b in ((0, 9), (9, 18)):
        town.update(_seg_cells(y - 6, a, y + 6, b) | _seg_cells(y + 6, a, y - 6, b))
    box(y - 10, 18, y + 10, 20)
    box(y - 8, 20, y + 8, 24)
    box(y - 11, 24, y + 11, 25)
    box(y - 9, 25, y + 9, 26)
    box(y - 6, 26, y + 6, 27)
    box(y - 3, 27, y + 3, 28)
    box(y, 28, y + 1, 32)
    for c in range(y - 7, y + 7, 2):           # the curtain box's lantern band (lit at dusk)
        wins.add((c, 22))
    # pagoda (5 tiers) with a finial
    p = PAGODA_C
    for r0, half, rows, eave in ((0, 6, 5, 9), (7, 4, 4, 8), (12, 3, 4, 7), (17, 2, 3, 6), (21, 2, 2, 5)):
        box(p - half, r0, p + half + 1, r0 + rows - 1)
        box(p - eave, r0 + rows - 1, p + eave + 1, r0 + rows)
        box(p - eave + 1, r0 + rows, p + eave, r0 + rows + 1)
    box(p, 24, p + 1, 33)
    for r in (27, 29, 31):
        box(p - 1, r, p + 2, r + 1)
    for r in (2, 8, 13):
        wins.add((p, r + 1))
    # nobori banners: pole + a 2-col banner hanging from a crossbar
    for c in (176, 182, 236, 462, 468, 612):
        box(c, 0, c + 1, 17)
        box(c, 16, c + 3, 17)
        box(c + 1, 7, c + 3, 16)
    # lantern strings (catenaries): cord cells + a 2x2 lantern every 6 cols hanging under the cord
    strings = [((y - 10, 25), (4, 9), 3), ((y + 10, 25), (300, 10), 6),
               ((p - 9, 20), (380, 10), 5), ((p + 9, 20), (639, 9), 3)]
    lanterns = []
    for (c0, r0), (c1, r1), sag in strings:
        step = 1 if c1 > c0 else -1
        n = abs(c1 - c0)
        prev = None
        for i in range(n + 1):
            t = i / n
            c = c0 + i * step
            r = round(r0 + (r1 - r0) * t - sag * 4 * t * (1 - t))
            if prev is not None:
                town.update(_seg_cells(prev[0], prev[1], c, r))
            prev = (c, r)
            if 3 <= i <= n - 3 and i % 6 == 3:
                lanterns.append((c, r - 2))
                box(c, r - 2, c + 2, r)
    town = {(c, r) for c, r in town if 0 <= c < SC_COLS and 0 <= r < SC_ROWS}
    wins = {(c, r) for c, r in wins if (c, r) in town}
    return town, lanterns, wins


def _cells_img(cellsets):
    """[(cells, token)] -> a physical W x SCN_H image (row 0 = the bottom row)."""
    cv = Canvas(W, SCN_H)
    for cells_, tok in cellsets:
        col = C[tok]
        for c, r in cells_:
            y = SCN_H - (r + 1) * SC
            cv.rect(c * SC, y, (c + 1) * SC, y + SC, col)
    return cv.result()


N_LIGHT_STEPS = 8


def scenery():
    """{key: [frames]}: mount / town (day, dusk, fail), town_lights 0..8 (frame n = the lantern groups
    below n lit; the groups are interleaved so the lights spread over the whole town), town_win (dusk)."""
    mts, caps = _mountain_cells()
    town, lanterns, wins = _town()
    out = {"mount": [], "town": []}
    for st in ("day", "dusk", "fail"):
        m, cap, t = SCENE_PAL[st]
        out["mount"].append(_cells_img([(mts, m), (caps, cap)]))
        out["town"].append(_cells_img([(town, t)]))
    order = sorted(lanterns)
    frames = []
    for n in range(N_LIGHT_STEPS + 1):
        don, gold = set(), set()
        for k, (c, r) in enumerate(order):
            if (k * 3) % N_LIGHT_STEPS < n:
                cl = {(c, r), (c + 1, r), (c, r + 1), (c + 1, r + 1)}
                (don if k % 2 else gold).update(cl)
        frames.append(_cells_img([(don, "don"), (gold, "clear")]))
    out["town_lights"] = frames
    out["town_win"] = [_cells_img([(wins, "clear")])]
    return out


# clouds: near = deco S / M, far = thin streaks (2U cells); frame 0 day, 1 dusk
CLOUD_FAR = ["...XXXX.......",
             "XXXXXXXXXX.XXX"]
CLOUD_FAR_CELL = 2 * U
CLOUDS_FAR = [(240, 42), (780, 24), (1290, 60), (1680, 36)]
CLOUD_SPEED_MS = {"near": 100, "far": 200}      # ms per physical px: multiples of 20 / 16.7 / 8.3 ms


def _clouds2(size):
    rows = deco.CLOUD_S if size == "S" else deco.CLOUD_M
    out = []
    for pal in ({"X": C["cloud"], "S": C["cloud2"]}, {"X": C["dusk2"], "S": C["dusk1"]}):
        w, h = deco.size_of(rows, deco.CLOUD_CELL)
        cv = Canvas(w, h)
        deco.cells(cv, 0, 0, rows, pal, deco.CLOUD_CELL)
        out.append(cv.result())
    return out


def _cloud_far():
    out = []
    for tok in ("cloud2", "dusk1"):
        w, h = deco.size_of(CLOUD_FAR, CLOUD_FAR_CELL)
        cv = Canvas(w, h)
        deco.cells(cv, 0, 0, CLOUD_FAR, {"X": C[tok]}, CLOUD_FAR_CELL)
        out.append(cv.result())
    return out


# fireworks: rise 3 frames + burst 8 frames, 100 ms each (6 refreshes at 60 Hz, 5 harness steps)
FW_CELL = 2 * U               # 6 logical = 12 phys: reads at a glance, still 8-bit chunky
FW_R = 11                     # centre cell of the burst image
FW_W, FW_H = 23, 26           # burst image in cells (room for the late frames' drop)
FW_RISE_ROWS = 14
FW_MS = 100
FW_VARIANTS = (("clear", "paper"), ("gogo", "clear"), ("don", "clear"))   # (main, tip): accents only
FW_RADII = (1, 3, 5, 7, 8, 9, 10, 10)
FW_DROP = (0, 0, 0, 0, 1, 1, 2, 3)
# burst centres (cx, cy) on the U grid: free top-band sky between the portrait / combo bubble, the title
# plate and the gauge; 2P also the band sky right of the deck
FW_SLOTS = {
    "1p": [(870, 102), (1290, 150), (453, 204), (1062, 150)],
    "2p": [(870, 102), (1290, 150), (453, 150), (1062, 150), (1689, 939)],
}


def _fw_burst(main, tip):
    import math
    frames = []
    for f, (rad, drop) in enumerate(zip(FW_RADII, FW_DROP)):
        cl = {}
        if f == 0:
            for c, r in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
                cl[(c, r)] = "paper" if (c, r) == (0, 0) else main
        else:
            for k in range(16):
                a = k * math.pi / 8
                ca, sa = math.cos(a), math.sin(a)

                def put(r, tok):
                    cl[(round(ca * r), round(sa * r) + drop)] = tok
                if f <= 2:                    # 8 streaks shooting out, the 8 between only as sparks
                    if k % 2 == 0:
                        for r in range(max(1, rad - 3), rad + 1):
                            put(r, "paper" if r == rad else main)
                    elif f == 2:
                        put(rad - 1, tip)
                elif f == 3:
                    for r in range(rad - 2, rad + 1):
                        put(r, tip if r == rad else main)
                elif f == 4:
                    put(rad, tip)
                    put(rad - 3, main)
                elif f == 5:
                    put(rad, tip if k % 2 else main)
                    if k % 2 == 0:
                        put(rad - 2, main)
                elif f == 6:
                    if k % 2 == 0:
                        put(rad, main)
                elif k % 4 == 1:
                    put(rad, tip)
        cv = Canvas(FW_W * FW_CELL, FW_H * FW_CELL)
        for (c, r), tok in cl.items():
            x, y = (FW_R + c) * FW_CELL, (FW_R + r) * FW_CELL
            cv.rect(x, y, x + FW_CELL, y + FW_CELL, C[tok])
        frames.append(cv.result())
    return frames


def _fw_rise():
    frames = []
    for k in range(3):
        cv = Canvas(FW_CELL, FW_RISE_ROWS * FW_CELL)
        head = FW_RISE_ROWS - 1 - (3 + 5 * k)        # row from the top: climbs 5 cells a frame
        for dr, tok in ((0, "paper"), (1, "clear"), (3, "clear"), (5, "gogo")):
            r = head + dr
            if 0 <= r < FW_RISE_ROWS:
                cv.rect(0, r * FW_CELL, FW_CELL, (r + 1) * FW_CELL, C[tok])
        frames.append(cv.result())
    return frames


def _rgb(tok):
    c = C[tok]
    return f"{{ {c[0]}, {c[1]}, {c[2]} }}"


def _sky_lua():
    out = ["-- stagelux: sky gradient segments { y0, y1, base, over, level } per layout and state",
           "S.SKY = {"]
    for lay in ("1p", "2p"):
        out.append(f'    ["{lay}"] = {{')
        for st in ("day", "clear", "dusk", "fail"):
            out.append(f"        {st} = {{")
            for a, b, base, over, lv in sky_segments(st, lay):
                ov = _rgb(over) if over else "false"
                out.append(f"            {{ {a}, {b}, {_rgb(base)}, {ov}, {lv} }},")
            out.append("        },")
        out.append("    },")
    out.append("}")
    P = lambda t: "{ " + ", ".join(str(v) for v in t) + " }"   # noqa: E731
    out += [f"S.SCN_H = {SCN_H}",
            f"S.LIGHT_STEPS = {N_LIGHT_STEPS}",
            f"S.CLOUD_NEAR_MS, S.CLOUD_FAR_MS = {CLOUD_SPEED_MS['near']}, {CLOUD_SPEED_MS['far']}",
            "S.CLOUDS_FAR = { " + ", ".join(f"{{ {x}, {y} }}" for x, y in CLOUDS_FAR) + " }",
            f"S.CLOUD_FAR_W = {deco.size_of(CLOUD_FAR, CLOUD_FAR_CELL)[0]}",
            f"S.FW_MS, S.FW_R, S.FW_CELL, S.FW_VARIANTS = {FW_MS}, {FW_R * FW_CELL}, {FW_CELL}, {len(FW_VARIANTS)}",
            "S.FW_SLOTS = { " + ", ".join(f'["{k}"] = {{ ' + ", ".join(P(p) for p in v) + " }"
                                          for k, v in FW_SLOTS.items()) + " }"]
    return out


def _lua_data(path, line_keys):
    P = lambda t: "{ " + ", ".join(str(v) for v in t) + " }"   # noqa: E731
    lan_w, lan_h = deco.size_of(deco.LANTERN, LANTERN_CELL)
    rx0, rx1 = STAGE_X0 + 4 * U + POST_W + U, STAGE_X1 - 4 * U - POST_W - U

    def row(x0, x1, n, w, y):
        return [(int(x0 + (x1 - x0) * (i + 0.5) / n - w / 2) // U * U, y) for i in range(n)]

    lanterns = row(rx0, rx1, N_LANTERNS, lan_w, ROPE_Y + U)
    l2w, l2h = deco.size_of(deco.LANTERN, D2_LANTERN_CELL)
    lanterns2 = row(D2_ROPE[0], D2_ROPE[1], N2_LANTERNS, l2w, D2_ROPE_Y + U)
    out = ["-- GENERATED by ss/v2_stage.py: stage geometry (LOGICAL px) and Hoshi's line keys (ss/strings.py).",
           "local S = {}",
           f"S.W, S.H = {W}, {H}",
           f"S.HORIZON_Y, S.FLOOR_Y, S.GROUND_Y, S.POST_TOP = {HORIZON_Y}, {FLOOR_Y}, {GROUND_Y}, {POST_TOP}",
           f"S.MOMO_CX, S.TAIKO_CX, S.HOSHI_CX = {MOMO_CX}, {TAIKO_CX}, {HOSHI_CX}",
           f"S.BUBBLE_X, S.BUBBLE_Y, S.BUBBLE_H = {BUBBLE_X}, {BUBBLE_Y}, {BUBBLE_H}",
           f"S.BUBBLE_TIP = {{ {BUBBLE_TIP_X}, {BUBBLE_Y + BUBBLE_H + BUBBLE_TAIL_H} }}",
           f"S.FLAME_X, S.FLAME_Y = {FLAME_X0}, {FLAME_Y0}",
           f"S.LANTERN_W, S.LANTERN_H = {lan_w}, {lan_h}",
           "S.LANTERNS = { " + ", ".join(P(p) for p in lanterns) + " }",
           f"S.RESERVED_INFO = {P(RESERVED_INFO)}   -- x0, y0, x1, y1: the HUD's info strip",
           f"S.G2_Y, S.STAGE2_Y = {G2_Y}, {D2_POST_TOP}",
           f"S.P2_MOMO_CX, S.P2_HOSHI_CX = {P2_MOMO_CX}, {P2_HOSHI_CX}",
           f"S.DAN_MOMO_CX, S.DAN_HOSHI_CX = {DAN_MOMO_CX}, {DAN_HOSHI_CX}",
           f"S.DAN_BUBBLE_X, S.DAN_BUBBLE_Y = {DAN_BUBBLE_X}, {DAN_BUBBLE_Y}",
           f"S.DAN_BUBBLE_TIP = {{ {DAN_BUBBLE_X + 12 * U}, {DAN_BUBBLE_Y + BUBBLE_H + BUBBLE_TAIL_H} }}",
           f"S.LANTERN2_W, S.LANTERN2_H = {l2w}, {l2h}",
           "S.LANTERNS2 = { " + ", ".join(P(p) for p in lanterns2) + " }",
           "S.CLOUDS = { " + ", ".join(f'{{ "{s}", {x}, {y} }}' for s, x, y in CLOUDS) + " }",
           "S.CLOUDS_2P = { " + ", ".join(f'{{ "{s}", {x}, {y} }}' for s, x, y in CLOUDS_2P) + " }",
           "S.COMBO_STEPS = " + P(COMBO_STEPS)]
    out += _sky_lua()
    out.append("S.LINES = {")
    for state, keys in line_keys.items():
        out.append(f'    {state} = {{ ' + ", ".join(f'"{k}"' for k in keys) + " },")
    out += ["}", "return S", ""]
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out))


def blank_ancestor_background(G):
    """1x1 logical blanks for every ancestor key under Graphics/background/* (Nijiiro's donbg, bg_normal,
    fever, dancers, footer, renda, chibi, collabs: ~1100 keys). Our background.lua only loads
    background/ss_stage, and the bg_objects it still requires (enso_skip, ending, rank_badge) read
    game/* textures, so no script or engine code ever loads or measures these keys: they are blanked
    only so that no ancestor art can show if something did load them. Positions are kept."""
    n = 0
    for sub in subsets("background"):
        if sub == "ss_stage":
            continue
        d = f"{G}/background/{sub}"
        tj = {}
        for k in subset_keys("background", sub):
            g = resolve("background", sub, k)
            if g is None:
                continue
            e = g.entry[0] if isinstance(g.entry, list) else g.entry
            e = e if isinstance(e, dict) else {}
            _save(blank_l(1, 1), f"{d}/{k}.png", "crisp")
            tj[k] = phys_xy({"x": int(e.get("x", 0) * g.scale), "y": int(e.get("y", 0) * g.scale)})
            n += 1
        if tj:
            with open(f"{d}/texture.json", "w", encoding="utf-8", newline="\n") as f:
                json.dump(tj, f, ensure_ascii=False, indent=1)
                f.write("\n")
    return n


def build(ctx):
    st = OwnSubset(ctx.G, "background", "ss_stage")
    st.add("horizon", [_horizon(False), _horizon(True)])   # 0: cloud2 (day / fail), 1: glow (clear / dusk)
    for key, frames in scenery().items():
        st.add(key, frames)
    st.add("cloud_far", _cloud_far())
    st.add("fw_rise", _fw_rise())
    for i, (main, tip) in enumerate(FW_VARIANTS):
        st.add(f"fw_{i}", _fw_burst(main, tip))
    st.add("stage", [_stage_1p()])
    st.add("stage_2p", [_stage_2p((P2_TAIKO1_CX, P2_TAIKO2_CX))])
    st.add("stage_dan", [_stage_2p((DAN_TAIKO_CX,))])
    st.add("lantern", [_lantern(s) for s in ("off", "lit", "dark")])
    st.add("lantern_s", [_lantern(s, D2_LANTERN_CELL) for s in ("off", "lit", "dark")])
    st.add("flame", [_flame(0), _flame(1)])
    st.add("cloud_s", _clouds2("S"))                # 0 day, 1 dusk
    st.add("cloud_m", _clouds2("M"))
    n = st.write()
    n += blank_ancestor_background(ctx.G)

    # Lua: our background.lua (+ its data); copied from lua/stage/** (this module's NAME is v2_stage)
    sdir = os.path.join(ctx.scripts, "background")
    os.makedirs(sdir, exist_ok=True)
    _lua_data(os.path.join(sdir, "ss_stage_data.lua"), line_keys())
    src = os.path.join(ctx.here, "lua", "stage")
    for root, _, files in os.walk(src):
        for f in files:
            rel = os.path.relpath(os.path.join(root, f), src)
            dst = os.path.join(ctx.scripts, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(os.path.join(root, f), dst)
            n += 1
    return n + 1
