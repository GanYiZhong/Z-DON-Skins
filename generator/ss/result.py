"""Module "result": Graphics/result (7 subsets), Graphics/dan_result (6 subsets), Scripts/result.

Light 8-bit look (LIGHT8_GUIDE.md): every window is an ink-bordered pixbox with a hard drop shadow,
the gauge is a segmented pixbar, crowns are pixel-art badges (rasterised on a 6 px grid), the
mascots (Momo + Hoshi) stand on a floor in the lower half and never overlap the panels.
Dan result lives in ss/result_dan.py (called from build())."""
from __future__ import annotations

import math

from PIL import Image, ImageDraw, ImageFilter

from .atlas import OwnSubset, SubsetWriter
from .style import C, COURSES, Canvas, alpha, blank, crown_pts, hexc, hue, mix, pixbox

NAME = "result"
OWNS = ["Graphics/result", "Graphics/dan_result", "Scripts/result"]
SCREEN = "result"
LANG = "ja"
INK = C["ink"]
PAPER = C["paper"]
TXT = INK
SILVER = hexc("#C9CFDA")
GOLD = C["clear"]


def configure(ctx):
    global LANG
    LANG = ctx.lang


# ====================================================================== helpers
def tint(im, color):
    """Replace the colour of an RGBA image, keep its alpha."""
    out = Image.new("RGBA", im.size, color[:3] + (255,))
    out.putalpha(im.getchannel("A"))
    return out


def digit_set(size, color, weight=800, dy=0.0, shadow=None):
    """Frame drawer for a 0-9 digit strip: every digit centred in its own fixed cell (tabular).
    `shadow` = colour of a hard 2 px drop shadow (8-bit)."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        if shadow:
            cv.text(w / 2 + 2, h * 0.54 + dy + 2, str(i), size, shadow, weight=weight)
        cv.text(w / 2, h * 0.54 + dy, str(i), size, color, weight=weight)
        return cv.result()
    return draw


def label_box(text, size, color, weight=800, align="l", pad=4, tracking=0.0):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        x = pad if align == "l" else (w - pad if align == "r" else w / 2)
        cv.text(x, h / 2 + 1, text, size, color, weight=weight, anchor={"l": "lm", "r": "rm", "c": "mm"}[align],
                max_w=w - 2 * pad, tracking=tracking)
        return cv.result()
    return draw


def chip(text, fill, w_chip=58, size=24):
    """Ink-outlined notched chip with ink text (fill is a bright colour)."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        pixbox(cv, 2, 2, 2 + w_chip, h - 4, fill=fill, shadow=3, px=2)
        cv.text(2 + w_chip / 2, h / 2 - 1, text, size, INK, weight=900, max_w=w_chip - 4)
        return cv.result()
    return draw


# ---- pixel pieces -----------------------------------------------------------
def cloud(cv, x, y, k=4, col=None):
    """Pixel cloud, 14 x 4 cells."""
    col = col or PAPER
    rows = ["....XXXX......",
            "..XXXXXXXX.XX.",
            ".XXXXXXXXXXXXX",
            "XXXXXXXXXXXXXX"]
    for j, r in enumerate(rows):
        for i, c in enumerate(r):
            if c == "X":
                cv.rect(x + i * k, y + j * k, x + (i + 1) * k, y + (j + 1) * k, col)


def pgrid(cv, x, y, rows, cell, cols):
    """Draw a character grid (one char = one cell) with a colour map."""
    for j, r in enumerate(rows):
        for i, ch in enumerate(r):
            c = cols.get(ch)
            if c is not None:
                cv.rect(x + i * cell, y + j * cell, x + (i + 1) * cell, y + (j + 1) * cell, c)


STAR = ["..#..",
        ".###.",
        "#####",
        ".###.",
        ".#.#."]

FLAME = ["...#...",
         "..###..",
         "..###..",
         ".#####.",
         "#######",
         "###.###",
         "###.###",
         ".#####.",
         "..###.."]


def pix_disc(cv, cx, cy, r, cell, fill):
    """Disc made of `cell`-px squares, centred on a cell boundary at (cx, cy)."""
    n = int(r / cell) + 1
    for gy in range(-n, n):
        for gx in range(-n, n):
            if (gx + 0.5) ** 2 + (gy + 0.5) ** 2 <= (r / cell) ** 2:
                cv.rect(cx + gx * cell, cy + gy * cell, cx + (gx + 1) * cell, cy + (gy + 1) * cell, fill)


def pglyph(cv, cx, cy, i, col, u=12, k=1.0):
    """Course glyph as square pixels: 1-4 blocks easy..oni, square ring = ura, bars = tower, block = dan."""
    cx, cy = int(cx), int(cy)
    f = lambda v: int(round(v * k))
    if i <= 3:
        m = i + 1
        sp = u + f(10)
        x0 = cx - ((m - 1) * sp + u) // 2
        for j in range(m):
            cv.rect(x0 + j * sp, cy - u // 2, x0 + j * sp + u, cy + u // 2, col)
    elif i == 4:
        cv.rect(cx - f(18), cy - f(18), cx + f(18), cy + f(18), col)
        cv.rect(cx - f(10), cy - f(10), cx + f(10), cy + f(10), C["paper"])
        cv.rect(cx - f(4), cy - f(4), cx + f(4), cy + f(4), col)
    elif i == 5:
        for j in range(3):
            ww = f(36 - j * 10)
            cv.rect(cx - ww // 2, cy + f(12 - j * 12 - 5), cx + ww // 2, cy + f(12 - j * 12 + 5), col)
    else:
        cv.rect(cx - f(15), cy - f(15), cx + f(15), cy + f(15), col)
        cv.rect(cx - f(7), cy - f(7), cx + f(7), cy + f(7), C["dan"])


def ras_mask(w, h, pts, cell):
    """Polygon rasterised on a `cell`-px grid: an L mask of (w, h)."""
    gw, gh = w // cell + 2, h // cell + 2
    m = Image.new("L", (gw, gh), 0)
    ImageDraw.Draw(m).polygon([(x / cell, y / cell) for x, y in pts], fill=255)
    return m.resize((gw * cell, gh * cell), Image.NEAREST).crop((0, 0, w, h))


def paste_mask(out, mask, color):
    solid = Image.new("RGBA", out.size, color[:3] + (255,))
    solid.putalpha(mask)
    out.alpha_composite(solid)


# ====================================================================== background
def sky_band(cv, y0, y1, x_clouds=True, dither=True):
    cv.rect(0, y0, cv.w, y1, C["sky"])
    if dither:
        # checker step from sky into the cream paper
        for j, y in enumerate(range(y1, y1 + 12, 4)):
            for x in range(0, cv.w, 8):
                xs = x + (4 if j % 2 else 0)
                if j < 2:
                    cv.rect(xs, y, xs + 4, y + 4, C["sky"])


def f_bg(player):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        cv.rect(0, 0, w, h, C["bg0"])
        if player == 1:
            # rows 360..720 = the player's panel half (screen y 0..360): a sky band over cream
            sky_band(cv, 360, 460)
            cv.rect(0, 717, w, 720, INK)                 # seam (ink), screen y 357..360
            # rows 0..360 = the mascots' stage (screen y 360..720)
            cv.rect(0, 0, w, 3, INK)
            for j, y in enumerate(range(3, 15, 4)):
                if j < 2:
                    for x in range(0, w, 8):
                        xs = x + (4 if j % 2 else 0)
                        cv.rect(xs, y, xs + 4, y + 4, C["bg3"])
            # ground strip the mascots stand on: screen y 612..636 (ends above the bottom bar at 648)
            gy = 252
            cv.rect(0, gy, w, gy + 24, INK)
            cv.rect(0, gy + 3, w, gy + 21, C["mint"])
            for y in range(gy + 7, gy + 21, 8):
                for x in range(0, w, 16):
                    xs = x + (8 if (y // 8) % 2 else 0)
                    cv.rect(xs, y, xs + 8, y + 4, mix(C["mint"], C["ink"], 0.10))
        else:
            cv.rect(0, 0, w, 3, INK)
            for j, y in enumerate(range(3, 15, 4)):
                if j < 2:
                    for x in range(0, w, 8):
                        xs = x + (4 if j % 2 else 0)
                        cv.rect(xs, y, xs + 4, y + 4, C["bg3"])
        return cv.result()
    return draw


def f_deco(i, n, w, h):
    """Stage decoration (1280 x 260 = screen y 360..620; the bg tile is only 256 px wide and repeats):
    clouds, sparkles, bushes, flowers and a flag, with the feet line at y = 252 (screen 612)."""
    cv = Canvas(w, h)
    gy = 252
    for cx_, cy_, ck in ((150, 44, 4), (1090, 70, 3), (380, 112, 3), (930, 150, 4)):
        cloud(cv, cx_, cy_, ck, C["sky"])
    for sx, sy in ((90, 150), (1180, 168), (1020, 30), (300, 20), (680, 20), (230, 110)):
        sparkle(cv, sx, sy, 2, mix(C["clear"], C["bg0"], 0.35))
    # bushes, flowers and a signpost on the ground
    blocks = ((12, 24, 36, 6), (6, 18, 42, 6), (0, 12, 48, 12))   # x0, top, x1, height (above the ground)
    for bx in (36, 132, 1096, 1192):
        for grow, col in ((3, INK), (0, C["mint"])):
            for x0, top, x1, hh in blocks:
                cv.rect(bx + x0 - grow, gy - top - grow, bx + x1 + grow, gy - top + hh + grow * (0 if top == 12 else 0), col)
        cv.rect(bx + 9, gy - 12, bx + 15, gy - 6, mix(C["mint"], C["ink"], 0.18))
        cv.rect(bx + 30, gy - 18, bx + 36, gy - 12, mix(C["mint"], C["ink"], 0.18))
    for fx, col in ((99, C["pink"]), (190, GOLD), (1081, C["pink"]), (1170, GOLD)):
        cv.rect(fx - 3, gy - 21, fx + 9, gy, INK)
        cv.rect(fx, gy - 18, fx + 6, gy, C["mint"])
        cv.rect(fx - 6, gy - 30, fx + 12, gy - 18, INK)
        cv.rect(fx - 3, gy - 27, fx + 9, gy - 21, col)
    # two small pixel taiko drums on the ground
    for dx in (300, 954):
        cv.rect(dx - 3, gy - 57, dx + 87, gy, INK)
        cv.rect(dx, gy - 54, dx + 84, gy - 36, PAPER)                 # drum head
        cv.rect(dx, gy - 36, dx + 84, gy - 3, C["p1"])                # body
        cv.rect(dx, gy - 36, dx + 84, gy - 33, INK)
        for k in range(1, 4):
            cv.rect(dx + k * 21 - 3, gy - 30, dx + k * 21, gy - 6, mix(C["p1"], C["paper"], 0.45))
        cv.rect(dx + 30, gy - 48, dx + 54, gy - 42, C["p1"])          # the don mark on the head
    # a pixel flag post
    cv.rect(1226, gy - 66, 1232, gy, INK)
    cv.rect(1232, gy - 66, 1262, gy - 48, INK)
    cv.rect(1232, gy - 63, 1259, gy - 51, GOLD)
    return cv.result()



def f_footer(player):
    acc = C["p1"] if player == 1 else C["p2"]

    def draw(i, n, w, h):
        cv = Canvas(w, h)
        # rows 0..72: the bottom bar (screen y 648..720): ink with an accent edge
        cv.rect(0, 0, w, 72, INK)
        cv.rect(0, 0, w, 6, acc)
        cv.rect(0, 6, w, 9, PAPER)
        # rows 72..144: the header band (screen y 0..72): sky with pixel clouds
        cv.rect(0, 72, w, 144, C["sky"])
        cloud(cv, 112, 84, 4)
        cloud(cv, 206 - 40, 112, 3)
        return cv.result()
    return draw


def f_flat(color):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        cv.rect(0, 0, w, h, color)
        return cv.result()
    return draw


def title_plate(text, accent, size, w_text=200, lang_ja=True, plate_w=220):
    """Header title: a paper pixbox with an accent block + pixel star."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        pixbox(cv, 12, 5, plate_w, 63, fill=PAPER, shadow=4, px=3)
        cv.rect(15, 8, 63, 60, accent)
        pgrid(cv, 27, 24, STAR, 5, {"#": INK})
        cv.text(76, 35, text, size, TXT, weight=900, anchor="lm", max_w=plate_w - 86)
        return cv.result()
    return draw


def build_background(out):
    w = SubsetWriter(out, SCREEN, "background")
    w.put("background_1p", f_bg(1))
    w.put("background_2p", f_bg(2))
    w.put("footer_1p", f_footer(1))
    w.put("footer_2p", f_footer(2))
    # mood tint over the stage: flat, faded by the engine (x0.4); clear = none, fail = a dim wash
    stage = {"x": 0, "y": 360, "x2": 1280, "y2": 360}
    w.put("gradient_clear", f_flat((0, 0, 0, 0)), entry=stage)
    w.put("gradient_fail", f_flat(mix(C["ink"], C["sky"], 0.75)), entry=stage)
    w.put("result_text_ja", title_plate("成績発表", GOLD, 36))
    w.put("result_text_en", title_plate("Results", GOLD, 36))
    return w.write()


# ====================================================================== score panel
def f_panel(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 0, 0, w - 5, h - 5, fill=PAPER, shadow=4, px=3)
    # dashed divider under the gauge row
    for x in range(24, w - 30, 12):
        cv.rect(x, 80, x + 6, 82, C["line"])
    return cv.result()


def f_difficulty(i, n, w, h):
    """Drawn 1:1 (the build clears Green's x2/y2 so the engine does not rescale it)."""
    cv = Canvas(w, h)
    col = C[COURSES[i][0]]
    pixbox(cv, 26, 2, 176, 152, fill=col, shadow=5, px=3)
    pixbox(cv, 39, 15, 163, 136, fill=C["paper"], shadow=0, px=3)
    pglyph(cv, 66, 34, i, col, u=6, k=0.75)
    pixbox(cv, 32, 134, 170, 166, fill=col, shadow=4, px=3)
    name = COURSES[i][1] if LANG == "ja" else COURSES[i][2]
    cv.text(101, 147, name, 24, PAPER if i == 4 else INK, weight=900, max_w=124)
    return cv.result()


def f_score_box(shinuchi, lang):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        pixbox(cv, 0, 0, 250, 67, fill=C["bg0"], shadow=4, px=3)
        cv.text(w - 28, 36, "点" if lang == "ja" else "pts", 24 if lang == "ja" else 24, INK,
                weight=900, anchor="mm")
        if shinuchi:
            pixbox(cv, 10, 62, 104, 84, fill=GOLD, shadow=3, px=2)
            cv.text(57, 73, "真打" if lang == "ja" else "TRUE", 12, INK, weight=900)
        return cv.result()
    return draw


def f_high_score(lang):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        pixbox(cv, 6, 2, 248, 63, fill=GOLD, shadow=4, px=3)
        cv.text(128, 15, "自己ベスト更新!" if lang == "ja" else "NEW PERSONAL BEST", 24, INK,
                weight=900, max_w=216)
        # pixel up-arrow
        pgrid(cv, 54, 40, ["..#..", ".###.", "#####", "..#..", "..#.."], 3, {"#": INK})
        cv.text(204, 45, "点" if lang == "ja" else "pts", 12 if lang != "ja" else 24, INK, weight=900)
        return cv.result()
    return draw


def f_mod(label, fill, size=20):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        pixbox(cv, 3, 3, w - 6, h - 6, fill=fill, shadow=3, px=2)
        cv.text(w / 2 - 1, h / 2 - 1, label, size, INK, weight=900, max_w=w - 16)
        return cv.result()
    return draw


def build_score(out):
    w = SubsetWriter(out, SCREEN, "score")
    w.put("overlay", f_panel)
    from .atlas import green_json
    ent = [{k: v for k, v in e.items() if k not in ("x2", "y2")} for e in green_json(SCREEN, "score")["difficulty"]]
    w.put("difficulty", f_difficulty, entry=ent)
    w.put("judge_good", chip("良", GOLD))
    w.put("judge_ok", chip("可", C["mint"]))
    w.put("judge_bad", chip("不可", C["sky"]))
    w.put("judge_num", digit_set(30, TXT, shadow=C["bg3"]))
    for lang in ("ja", "en"):
        w.put(f"max_combo_{lang}", label_box("最大コンボ" if lang == "ja" else "MAX COMBO", 24, INK))
        w.put(f"drumroll_{lang}", label_box("連打数" if lang == "ja" else "ROLL", 24, INK))
        w.put(f"score_{lang}", f_score_box(False, lang))
        w.put(f"score_shinuchi_{lang}", f_score_box(True, lang))
        w.put(f"high_score_{lang}", f_high_score(lang))
    w.put("score_num", digit_set(36, TXT, dy=0.5, shadow=C["bg3"]))
    w.put("high_score_num", digit_set(24, TXT, dy=-2))
    for k, t in (("doron", "ド"), ("abekobe", "逆"), ("kimagure", "気"), ("detarame", "乱")):
        w.put(f"mod_{k}", f_mod(t, C["bg3"]))
    w.put("mod_baisaku", f_mod("×2", GOLD, 24))
    w.put("mod_sanbai", f_mod("×3", GOLD, 24))
    w.put("mod_yonbai", f_mod("×4", GOLD, 24))
    return w.write()


# ====================================================================== crowns + message
CELL = 6


def crown_lr(kind, ox, oy):
    """The crown as a low-res (one pixel per 6 px cell) RGBA image, outline included, plus its mask."""
    gw = gh = 152 // CELL + 1
    base = ras_mask(gw, gh, [(ox + x, oy + y) for x, y in
                              [(0, 13), (0, 3), (5, 7.5), (8.5, 0), (12, 7.5), (17, 3), (17, 13)]], 1)
    big = base.filter(ImageFilter.MaxFilter(3))
    lr = Image.new("RGBA", (gw, gh), (0, 0, 0, 0))
    bp, gp, lp = base.load(), big.load(), lr.load()
    if kind == "white":
        for y in range(gh):
            for x in range(gw):
                if gp[x, y]:
                    lp[x, y] = PAPER
        return lr
    body = {"clear": SILVER, "fc": GOLD}.get(kind)
    lit = mix(body, PAPER, 0.55) if body else None
    drk = mix(body, INK, 0.30) if body else None
    for y in range(gh):
        for x in range(gw):
            if gp[x, y] and not bp[x, y]:
                lp[x, y] = INK
            if not bp[x, y]:
                continue
            if kind == "dfc":
                band = (x - ox) * 6 // 17
                c = hue(band / 6 * 0.85, 0.55, 1.0)
                c2 = mix(c, PAPER, 0.5)
                c3 = mix(c, INK, 0.28)
            else:
                c, c2, c3 = body, lit, drk
            col = c
            if not (x > 0 and bp[x - 1, y - 1]) if y > 0 else True:
                col = c2
            if x + 1 >= gw or y + 1 >= gh or not bp[x + 1, y + 1]:
                col = c3
            lp[x, y] = col
    # base band: an ink line + jewels
    for x in range(ox, ox + 17):
        lp[x, oy + 10] = INK
    for jx, jc in ((ox + 3, C["don"]), (ox + 8, PAPER), (ox + 13, C["ka"])):
        lp[jx, oy + 11] = jc
    return lr


def f_crown(kind):
    def draw(i, n, w, h):
        ox, oy = 4, 5        # grid origin: the 17 x 13 cell crown sits inside the 152 px frame
        lr = crown_lr(kind, ox, oy)
        out = blank(w, h)
        big = lr.resize((lr.width * CELL, lr.height * CELL), Image.NEAREST)
        # centre: crown is 17 cells wide (102 px)
        out.alpha_composite(big, ((w - 17 * CELL) // 2 - ox * CELL, (h - 13 * CELL) // 2 - oy * CELL - 2))
        return out
    return draw


def sparkle(cv, x, y, arm, col):
    c = 4
    x, y = int(x // c * c), int(y // c * c)
    cv.rect(x - c, y - c, x + 2 * c, y + 2 * c, col)
    for k in range(1, arm + 1):
        cv.rect(x + k * c + c - c, y, x + (k + 1) * c, y + c, col)
        cv.rect(x - k * c, y, x - (k - 1) * c, y + c, col)
        cv.rect(x, y + k * c, x + c, y + (k + 1) * c, col)
        cv.rect(x, y - k * c, x + c, y - (k - 1) * c, col)


def f_gleam(i, n, w, h):
    cv = Canvas(w, h)
    x, y, r = [(104, 38, 10), (112, 30, 22), (100, 40, 14)][i % 3]
    sparkle(cv, x, y, max(1, int(r // 5)), PAPER)
    return cv.result()


def f_message(i, n, w, h):
    texts = [("失敗…", ["もう少し", "がんばろう!"]), ("あと少し!", ["惜しかった!"]),
             ("クリア!", ["上手に演奏", "できました!"]), ("クリア!!", ["大成功!"])]
    main, subs = texts[i]
    edge = [C["bad"], C["ka"], GOLD, GOLD][i]
    head_col = PAPER if i < 2 else INK
    cv = Canvas(w, h)
    # staircase tail (ink, then paper inside)
    for k in range(5):
        cv.rect(206 + k * 6, 162 + k * 6, 258 - k * 6 + 3, 168 + k * 6, INK)
    for k in range(4):
        cv.rect(212 + k * 6, 160 + k * 6, 252 - k * 6, 166 + k * 6, PAPER)
    pixbox(cv, 14, 18, 296, 162, fill=PAPER, shadow=5, px=3)
    cv.rect(17, 21, 293, 78, edge)
    cv.rect(17, 78, 293, 81, INK)
    cv.rect(212, 159, 252, 165, PAPER)
    cv.text(155, 50, main, 48, head_col, weight=900, max_w=250)
    ys = 108 if len(subs) == 2 else 118
    for k, s in enumerate(subs):
        cv.text(155, ys + k * 28, s, 24, INK, weight=900, max_w=250)
    return cv.result()


def build_crown(out):
    w = SubsetWriter(out, SCREEN, "crown")
    w.put("crown_clear", f_crown("clear"))
    w.put("crown_fc", f_crown("fc"))
    w.put("crown_dfc", f_crown("dfc"))
    w.put("crown_fade", f_crown("white"))
    w.put("gleam", f_gleam)
    w.put("message", f_message)
    return w.write()


# ====================================================================== gauge (pixbar look)
def gauge_geom(diff):
    from .atlas import GREEN_G
    with Image.open(f"{GREEN_G}/result/gauge/1p_unfilled_{diff}.png") as im:
        a = im.convert("RGBA").getchannel("A")
        step = next(x for x in range(a.width) if a.getpixel((x, 16)) > 0)
    return step


def groove_mask(cv, step, inset=0):
    m, d = cv.mask()
    S = cv.ss
    d.rectangle([(8 + inset) * S, (38 + inset) * S, (step + 1) * S, (60 - inset) * S], fill=255)
    d.rectangle([step * S, (16 + inset) * S, (704 - inset) * S, (60 - inset) * S], fill=255)
    return m


def f_unfilled(diff, pcol):
    step = gauge_geom(diff)

    def draw(i, n, w, h):
        cv = Canvas(w, h)
        # ink frame = the groove grown by 3 px, then a hard 3 px shadow underneath
        for dx, dy, col in ((0, 3, INK), (0, 0, INK)):
            cv.rect(5 + dx, 35 + dy, step + 4 + dx, 63 + dy, col)
            cv.rect(step - 3 + dx, 13 + dy, 707 + dx, 63 + dy, col)
        groove = mix(pcol, PAPER, 0.78)
        cv.rect(8, 38, step + 1, 60, groove)
        cv.rect(step, 16, 704, 60, mix(GOLD, PAPER, 0.62))      # the clear zone
        cv.rect(step - 1, 16, step + 2, 60, INK)                 # clear threshold marker
        return cv.result()
    return draw


def f_overlay_g(diff):
    step = gauge_geom(diff)

    def draw(i, n, w, h):
        from PIL import ImageChops
        cv = Canvas(w, h, ss=1)
        g = groove_mask(cv, step)
        lines = Image.new("L", (w, h), 0)
        px = lines.load()
        for x in range(8, 704):
            if (x - 8) % 8 >= 6:
                for y in range(h):
                    px[x, y] = 255
        cv.paint(ImageChops.multiply(g, lines), alpha(INK, 70))
        return cv.result()
    return draw


def f_rainbow_g(diff):
    step = gauge_geom(diff)

    def draw(i, n, w, h):
        cv = Canvas(w, h, ss=1)
        grad = Image.new("RGBA", (w, h))
        px = grad.load()
        for x in range(w):
            q = (x // 16) * 16
            c = hue(q / 700 * 0.85 - i / n, s=0.50, v=1.0)
            for y in range(h):
                px[x, y] = c
        g = groove_mask(cv, step)
        out = blank(w, h)
        out.paste(grad, (0, 0), g)
        return out
    return draw


def f_bar(color, y0=2, y1=24):
    """One 8 px gauge cell: flat colour, light top rows, dark bottom rows."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        cv.rect(0, y0, w, y1, color)
        cv.rect(0, y0, w, y0 + 6, mix(color, PAPER, 0.40))
        cv.rect(0, y1 - 3, w, y1, mix(color, INK, 0.25))
        return cv.result()
    return draw


def f_flash_bar(i, n, w, h):
    cv = Canvas(w, h)
    cv.rect(4, 6, w - 4, h - 6, alpha(PAPER, 235))
    return cv.result()


def f_clear_label(text, color):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        cv.text(w / 2, h / 2, text, 12, color, weight=900, max_w=w - 4, tracking=0.5 if text.isascii() else 0)
        return cv.result()
    return draw


def soul_icon(cv, cx, cy, body, flame, edge=INK):
    """Pixel soul: ink-outlined disc with a flame, 3 px cells (centre must be a cell boundary)."""
    cx, cy = (int(cx) // 3) * 3, (int(cy) // 3) * 3
    pix_disc(cv, cx, cy, 25, 3, edge)
    pix_disc(cv, cx, cy, 19, 3, body)
    pix_disc(cv, cx - 3, cy - 3, 12, 3, mix(body, PAPER, 0.35))
    pix_disc(cv, cx, cy, 19, 3, body) if False else None
    pgrid(cv, cx - 10 - 1, cy - 14, FLAME, 3, {"#": flame})


def f_soul(col, inner):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        soul_icon(cv, 36, 33, col, INK if col == GOLD else inner)
        return cv.result()
    return draw


def f_soul_overlay(i, n, w, h):
    cv = Canvas(w, h)
    pix_disc(cv, 36, 33, 25, 3, PAPER)
    return cv.result()


def f_soul_fire(i, n, w, h):
    cx, cy = 85.0, 190.0
    cv = Canvas(w, h)
    k = i / n
    for j in range(12):
        a = (j / 12 + k / 12) * math.tau
        r = 67 + (5 if j % 2 == i % 2 else 0)
        x, y = int(cx + math.cos(a) * r) // 3 * 3, int(cy + math.sin(a) * r) // 3 * 3
        s = 9 if j % 2 == i % 2 else 6
        cv.rect(x - s // 2 - 2, y - s // 2 - 2, x + s // 2 + 5, y + s // 2 + 5, INK)
        cv.rect(x - s // 2, y - s // 2, x + s // 2 + 3, y + s // 2 + 3, GOLD)
    return cv.result()


def f_cap(i, n, w, h):
    """End cap behind the soul icon (sits over the right end of the groove)."""
    cv = Canvas(w, h)
    pixbox(cv, 0, 6, w - 4, h - 4, fill=C["bg0"], shadow=3, px=3)
    return cv.result()


def build_gauge(out):
    w = SubsetWriter(out, SCREEN, "gauge")
    for d in ("easy", "normal", "hard"):
        w.put(f"border_{d}", f_flat((0, 0, 0, 0)))
        w.put(f"1p_unfilled_{d}", f_unfilled(d, C["p1"]))
        w.put(f"2p_unfilled_{d}", f_unfilled(d, C["p2"]))
        w.put(f"overlay_{d}", f_overlay_g(d))
        w.put(f"rainbow_{d}", f_rainbow_g(d))
    # the engine draws CLEAR over the filled (gold / rainbow) zone: ink text on the bright fill
    w.put("clear_en", f_clear_label("CLEAR", INK))
    w.put("clear_ja", f_clear_label("クリア", INK))
    w.put("clear_dark_en", f_clear_label("CLEAR", INK))
    w.put("clear_dark_ja", f_clear_label("クリア", INK))
    w.put("1p_bar", f_bar(C["p1"]))
    w.put("2p_bar", f_bar(C["p2"]))
    w.put("bar_clear_top", f_bar(GOLD))
    w.put("bar_clear_bottom", f_bar(GOLD))
    w.put("bar_clear_transition", f_bar(GOLD, 4, 48))
    for k in ("1p_bar_fade", "2p_bar_fade", "bar_clear_fade", "bar_clear_transition_fade"):
        w.put(k, f_flash_bar)
    w.put("tamashii", f_soul(GOLD, INK))
    w.put("tamashii_dark", f_soul(C["bg3"], C["mute"]))
    w.put("tamashii_overlay", f_soul_overlay)
    w.put("tamashii_fire", f_soul_fire)
    w.put("footer", f_cap)
    return w.write()


BUBBLE_W, BUBBLE_H = 264, 126
BUBBLE_TEXT = {
    "ja": [("つぎは", "がんばろう!"), ("やったね!", "クリア!"), ("フルコンボ!", "すごい!")],
    "en": [("Next time!", "You got this!"), ("Nice job!", "Cleared!"), ("Full Combo!", "Amazing!")],
}


def f_bubble(i):
    """Hoshi's result speech bubble (0 fail, 1 clear, 2 full combo): pixbox + staircase tail to the lower left."""
    w, h = BUBBLE_W, BUBBLE_H
    cv = Canvas(w, h)
    pixbox(cv, 0, 0, w - 8, 93, fill=PAPER, shadow=4, px=3)
    edge = [C["sky"], C["mint"], GOLD][i]
    cv.rect(3, 3, w - 11, 18, edge)
    cv.rect(3, 18, w - 11, 21, INK)
    for k in range(3):
        cv.rect(24 + k * 6, 90 + k * 6, 60 - k * 6, 96 + k * 6, INK)
    for k in range(3):
        cv.rect(27 + k * 6, 87 + k * 6, 57 - k * 6 - (6 if k == 2 else 0), 93 + k * 6, PAPER)
    lines = BUBBLE_TEXT["en" if LANG == "en" else "ja"][i]
    cv.text((w - 8) / 2, 44, lines[0], 24, INK, weight=900, max_w=w - 36)
    cv.text((w - 8) / 2, 71, lines[1], 24, INK, weight=900, max_w=w - 36)
    return cv.result()


# ====================================================================== bottom (mascots are drawn by Lua)
def build_bottom(out):
    w = SubsetWriter(out, SCREEN, "bottom")
    for k in ("flowers", "chara_0", "chara_1", "chara_center"):
        w.put_blank(k)
    n = w.write()
    # Hoshi (the buddy) beside Momo: 4 expression frames at 6 px per sprite pixel, whole-pixel scaling
    from . import mascot
    hs = OwnSubset(out, SCREEN, "ss_buddy")
    hs.add("hoshi", [mascot.sized(mascot.BUDDY, e, 192) for e in ("idle", "good", "sad", "combo")])
    hs.add("bubble", [f_bubble(i) for i in range(3)])
    hs.add("deco", [f_deco(0, 1, 1280, 260)])
    return n + hs.write()


# ====================================================================== basin (a tub that drops on a bad fail)
def f_basin(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 44, 30, w - 48, h - 8, fill=C["sky"], shadow=4, px=3)
    cv.rect(47, 33, w - 51, 39, mix(C["sky"], PAPER, 0.5))
    pixbox(cv, 4, 4, w - 8, 34, fill=C["bg3"], shadow=4, px=3)
    pixbox(cv, 16, 11, w - 20, 27, fill=C["bg2"], shadow=0, px=2)
    return cv.result()


def f_flash(i, n, w, h):
    cv = Canvas(w, h)
    sparkle(cv, w / 2 - 2, h / 2 - 2, max(1, int(min(w, h) / 2 // 4) - 2), PAPER)
    return cv.result()


def build_basin(out):
    w = SubsetWriter(out, SCREEN, "basin")
    w.put("basin", f_basin)
    w.put("flash", f_flash)
    return w.write()


# ====================================================================== retry ("Revive!" burst)
def f_burst(color):
    def draw(i, n, w, h):
        # a quarter of a 12-point burst (rasterised on an 8 px grid) whose centre is this frame's bottom-right corner
        cx, cy = w, h
        out = blank(w, h)
        for rr, col in ((336, INK), (318, color)):
            pts = []
            for k in range(48):
                a = math.pi + k * math.pi / 24
                r = rr if k % 2 == 0 else rr * 0.78
                pts.append((cx + math.cos(a) * r * 1.35, cy + math.sin(a) * r))
            paste_mask(out, ras_mask(w, h, pts, 8), col)
        return out
    return draw


def f_retry_text(s, size):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        cv.text(w / 2, h / 2, s, size, PAPER, weight=900, max_w=w - 24, stroke=5, stroke_fill=INK)
        return cv.result()
    return draw


def build_retry(out):
    w = SubsetWriter(out, SCREEN, "retry")
    w.put("burst_revive", f_burst(C["balloon"]))
    w.put("text_revive_ja", f_retry_text("復活連打", 110))
    w.put("burst_more", f_burst(GOLD))
    w.put("text_more_ja", f_retry_text("もう1曲あそべるよ!", 66))
    return w.write()


# ====================================================================== Lua patches
BOTTOM = "result/bottom_characters.lua"
PLAYER = "result/result_player.lua"

_SS_DRAW = '''
-- SimpleStyle: Momo (+ Hoshi) stand on the floor of the lower half, below the panels.
local UI = require("global.ss_ui")
function BottomCharacters:ss_draw()
    if self.t_deco then tex.draw_texture(self.t_deco, { x = 0, y = 360 }) end
    -- only the slide-in/out moves the characters: Green's bounces would lift them off the ground
    local y = -self.move_up.attribute + self.move_down.attribute
    local st = self.state
    local expr = "idle"
    if st == 2 then expr = "combo" elseif st == 1 then expr = "clear" elseif st == 0 then expr = "fail" end
    local ms = tex.get_current_ms()
    local foot = FOOT_BASE + y
    self.ss_m:update(ms, 120)
    self.ss_m:draw(MOMO_X, foot, 1.0, { expr = expr })
    if self.t_buddy then
        local f = 0
        if expr == "fail" then f = 2 elseif expr == "combo" then f = 3 elseif expr == "clear" then f = 1 end
        local hop = 0
        if st ~= nil and st >= 1 and (ms % 480) < 120 then hop = 6 end
        tex.draw_texture(self.t_buddy, { frame = f, x = HOSHI_X - 96, y = foot - HOSHI_DY - hop })
        if self.t_bubble and st ~= nil and st >= 0 and st <= 2 and y <= -343 + 4 then
            -- fixed at the resting position, so it never rides the characters' bounce into the panel
            tex.draw_texture(self.t_bubble, { frame = st, x = HOSHI_X + 72, y = FOOT_BASE - 343 - HOSHI_DY - 52 })
        end
    end
end
'''

DAN_DRAW = "result/dan_result_draw.lua"
EMBLEM_X = 20        # dan plate x (Green 99): its right edge now ends left of the song-number tabs (x 330)
# Momo below the clear/fail stamp (which ends near y 438) and above the nameplate (y 585): she stands on
# an ink ground line at y 572, hidden while the promotion popups cover the screen
_SS_DAN_MASCOT = '''    if not self.popup_up then
        local S = SKIN_S
        local gy = 572 * S
        UI.rect(24 * S, gy, 282 * S, 3 * S, UI.P.ink)
        for k = 0, 22 do UI.rect((24 + k * 12) * S, gy + 3 * S, 6 * S, 3 * S, UI.P.bg3) end
        local expr = "idle"
        if self.stamp_at and (now - self.page_start_ms) >= self.stamp_at and self.page2_fade_seen then
            expr = "clear"
            for _, ed in ipairs(self.rd.exam_data) do if ed.failed then expr = "fail" break end end
        end
        if s.page2_fade > 0 then self.page2_fade_seen = true end
        self.ss_m:update(now, 120)
        self.ss_m:draw(165 * S, gy + 6 * S, 0.5 * S, { expr = expr })   -- +6: feet rest on the line (measured)
    end
'''

# promotion popups (shoudan / congrats): Green slid two 560x640 frames up from below the screen, which left
# the characters cut off by the bottom bar. Ours stand fully visible on ink floor lines inside the shoudan
# panel (x 81..1181, y 83..564), left and right of the rank glyphs (x 404..868) and clear of the rising
# drum (x 482..802). They drop in by whole sprite pixels (7 px steps) instead of sliding.
_SS_POPUP_MASCOTS = '''function DanResultDraw:draw_mascots(f, t0, cx, cy)
    if f < t0 then return end
    local S = SKIN_S
    local foot = 540 * S
    local u = math.min(1.0, (f - t0) / 12.0)
    local drop = math.floor((1.0 - u) * 4 + 0.5) * 7 * S
    local fade = math.min(1.0, (f - t0) / 6.0)
    for _, m in ipairs({ { self.t_sd_mascot_a, 240 }, { self.t_sd_mascot_b, 1030 } }) do
        local x = m[2] * S
        -- the floor: an ink line with a checker row under it (legible on the panel and on the dimmed screen)
        local a = math.floor(255 * fade)
        tex.draw_rect(x - 126 * S, foot, 252 * S, 4 * S, UI.P.ink[1], UI.P.ink[2], UI.P.ink[3], a)
        for k = 0, 20 do
            local c = (k % 2 == 0) and UI.P.bg3 or UI.P.paper
            tex.draw_rect(x + (k * 12 - 126) * S, foot + 4 * S, 12 * S, 6 * S, c[1], c[2], c[3], a)
        end
        tex.draw_rect(x - 126 * S, foot + 10 * S, 252 * S, 2 * S, UI.P.ink[1], UI.P.ink[2], UI.P.ink[3], a)
        tex.draw_texture(m[1], { x = x - 280 * S, y = foot - 640 * S - drop, fade = fade })
    end
end
'''

HOSHI_DY = 212
FOOT_BASE = 983     # resting foot y = FOOT_BASE - 343 (Green's move-in animation settles at -343)
MOMO_X = 560
HOSHI_X = 770

LUA_PATCHES = {
    BOTTOM: [
        ("BottomCharacters.__index = BottomCharacters\n",
         "BottomCharacters.__index = BottomCharacters\n"
         f"local FOOT_BASE, MOMO_X, HOSHI_X, HOSHI_DY = {FOOT_BASE}, {MOMO_X}, {HOSHI_X}, {HOSHI_DY}\n" + _SS_DRAW),
        ("    self.flower_index = 0\n",
         "    UI.reset()\n    self.ss_m = UI.Mascot.new()\n"
         "    self.t_buddy = tex.get_texture(\"result/ss_buddy/hoshi\")\n"
         "    self.t_bubble = tex.get_texture(\"result/ss_buddy/bubble\")\n"
         "    self.t_deco = tex.get_texture(\"result/ss_buddy/deco\")\n    self.flower_index = 0\n"),
        ("function BottomCharacters:draw()\n",
         "function BottomCharacters:draw()\n    do return self:ss_draw() end\n"),
    ],
    PLAYER: [
        # ink text with a white outline on the sky band (WHITE = fill, BLACK = outline); the last song of a
        # limited session gets a gold outline
        ("local WHITE, BLACK, RED = { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, { 255, 0, 0, 255 }",
         "local WHITE, BLACK, RED = { 58, 38, 51, 255 }, { 255, 255, 255, 255 }, { 245, 178, 30, 255 }"),
        # the score panel is an opaque pixbox: no 75 % alpha
        ("tex.draw_texture(self.t_overlay, { color = { 255, 255, 255, 192 }, index = p_idx })",
         "tex.draw_texture(self.t_overlay, { index = p_idx })"),
    ],
    DAN_DRAW: [
        # the dan plate moved left (result_dan.EMBLEM_X) so it no longer covers the "1曲目" tab
        ("dan_result_hori_name = { x = 267 * SKIN_S",
         "dan_result_hori_name = { x = (267 - 99 + EMBLEM_X) * SKIN_S"),
        ("local SKIN_S = tex.get_screen_scale()\n",
         "local SKIN_S = tex.get_screen_scale()\n"
         f"local EMBLEM_X = {EMBLEM_X}\n"
         "local UI = require(\"global.ss_ui\")   -- SimpleStyle: Momo on a ground line in the left column\n"),
        ("    local self = setmetatable({}, DanResultDraw)\n",
         "    local self = setmetatable({}, DanResultDraw)\n"
         "    UI.reset()\n    self.ss_m = UI.Mascot.new()\n"),
        ("    self:draw_page2(s.page2_fade, now)\n",
         "    self:draw_page2(s.page2_fade, now)\n" + _SS_DAN_MASCOT),
        # promotion popups: our draw_mascots (defined after Green's, so it wins)
        ("function DanResultDraw:draw_celebration(s)\n",
         _SS_POPUP_MASCOTS + "\nfunction DanResultDraw:draw_celebration(s)\n"),
    ],
}


# ====================================================================== build
def build(ctx):
    out = ctx.G
    n = 0
    n += build_background(out)
    n += build_score(out)
    n += build_crown(out)
    n += build_gauge(out)
    n += build_bottom(out)
    n += build_basin(out)
    n += build_retry(out)
    try:
        from . import result_dan
        n += result_dan.build(ctx, globals())
    except ImportError:
        pass
    return n
