"""The rest of the enso subsets: kusudama, dan_info, gauge_dan, practice, judge_counter,
ai_battle, gauge_ai. Same rules as ss/game.py: geometry follows the parent, every pixel is drawn here.

Nothing in this file imports ss/game.py (game.py imports us); the few shared pieces (note disk,
gauge masks, soul icon) are reached lazily through `_g()`."""
from __future__ import annotations

import math

from PIL import Image, ImageChops, ImageFilter

from .atlas import SubsetWriter, ref_bbox
from .style import C, Canvas, alpha, blank, hue, mix, pixbox

SCREEN = "game"
LANG = "ja"
OUTLINE = C["ink"]
INK, PAPER = C["ink"], C["paper"]


def set_lang(lang):
    global LANG
    LANG = lang


def _g():
    from . import game
    return game


# ================================================================== small helpers
def f_digits(size, color, weight=800, stroke=0, stroke_fill=None, dy=0.0):
    """One digit per frame (frame i = digit i), centred in its cell."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        cv.text(w / 2, h / 2 + dy, str(i % 10), size, color, weight=weight, stroke=stroke,
                stroke_fill=stroke_fill or C["paper"])
        return cv.result()
    return draw


def f_text(s, size, color, weight=800, anchor="mm", x=None, stroke=0, tracking=0.0, max_w=None):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        cv.text(w / 2 if x is None else x, h / 2 + 1, s, size, color, weight=weight, anchor=anchor,
                stroke=stroke, stroke_fill=C["paper"], tracking=tracking, max_w=max_w or w - 4)
        return cv.result()
    return draw


def f_fill(color):
    def draw(i, n, w, h):
        return Image.new("RGBA", (w, h), color)
    return draw


def eyes(cv, cx, cy, gap, r, col=None):
    col = col or C["ink"]
    cv.circle(cx - gap, cy, r, fill=col)
    cv.circle(cx + gap, cy, r, fill=col)


def smile(cv, cx, cy, w, col=None, lw=2.2):
    col = col or C["ink"]
    cv.arc(cx, cy - w * 0.3, w * 0.55, 30, 150, col, lw)


# ================================================================== dan intro doors (lane/dan_between_fusuma)
def f_fusuma(i, n, w, h):
    """One sliding door (the engine mirrors it for the other side): paper panel in an ink frame."""
    cv = Canvas(w, h)
    cv.rect(0, 0, w, h, C["ink"])
    cv.rect(4, 4, w, h - 4, C["paper"])
    cv.rect(16, 16, w - 16, h - 16, C["ink"])
    cv.rect(19, 19, w - 19, h - 19, C["bg2"])
    cv.rect(19, 19, w - 19, 25, C["bg3"])
    return cv.result()


# ================================================================== kusudama
KW, KH = 1448, 1240
KCX, KCY, KR = 724.0, 610.0, 238.0


def _dome_pts(R, n=40):
    """Upper half disc, flat side down, centred on the origin: arc 180..360 then the chord."""
    pts = []
    for k in range(n + 1):
        a = math.pi + math.pi * k / n
        pts.append((math.cos(a) * R, math.sin(a) * R))
    return pts


def _xf(pts, ang, pivot, to):
    ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    out = []
    for x, y in pts:
        x, y = x - pivot[0], y - pivot[1]
        out.append((x * ca - y * sa + to[0], x * sa + y * ca + to[1]))
    return out


def f_kusudama_ball(i, n, w, h):
    cv = Canvas(w, h, ss=2)
    rope = C["text2"]
    cx, cy, R = KCX, KCY, KR
    gold = C["kusu"]
    if i == 0:
        # closed ball hanging from a two-leg string
        ax, ay = cx, 6
        for sx in (-1, 1):
            cv.line([(ax, ay), (cx + sx * R * 0.66, cy - R * 0.76)], OUTLINE, 14)
        for sx in (-1, 1):
            cv.line([(ax, ay), (cx + sx * R * 0.66, cy - R * 0.76)], rope, 8)
        cv.circle(cx, cy, R + 8, fill=OUTLINE)
        cv.circle(cx, cy, R, fill=C["text"])
        cv.circle(cx, cy, R - R * 0.07, fill=gold)
        cv.rect(cx - R + 14, cy - 5, cx + R - 14, cy + 5, mix(gold, C["bg0"], 0.35))
        cv.circle(cx, cy - R * 0.97, 16, fill=C["don"])
        return cv.result()
    # open: two domes tilting away from the hinge, a banner and ribbons coming out
    ang = [0, 12, 20, 26, 28][i]
    ribbon_len = [0, 170, 360, 540, 600][i]
    banner_drop = [0, 60, 190, 340, 380][i]
    hinge_y = cy - 4
    for sx in (-1, 1):
        cv.line([(cx, 6), (cx + sx * R * 0.78, hinge_y - R * 0.42 - ang * 1.2)], OUTLINE, 14)
        cv.line([(cx, 6), (cx + sx * R * 0.78, hinge_y - R * 0.42 - ang * 1.2)], rope, 8)
    cols = [C["ka"], C["don"], C["roll"], C["normal"], C["ura"], C["oni"]]
    if ribbon_len:
        for k, col in enumerate(cols):
            t = (k - (len(cols) - 1) / 2)
            x0 = cx + t * 34
            pts = []
            for s in range(0, 21):
                u = s / 20
                yy = hinge_y + 20 + u * ribbon_len
                xx = x0 + t * 24 * u + math.sin(u * 6 + k) * 16 * u
                pts.append((xx, yy))
            cv.line(pts, OUTLINE, 28)
            cv.line(pts, col, 20)
    if banner_drop:
        bw, bh = 150, min(banner_drop + 40, 330)
        top = hinge_y + 30
        cv.rrect(cx - bw / 2 - 4, top - 4, cx + bw / 2 + 4, top + bh + 4, 10, fill=OUTLINE)
        cv.rrect(cx - bw / 2, top, cx + bw / 2, top + bh, 8, fill=C["text"])
        cv.rect(cx - bw / 2 - 10, top - 6, cx + bw / 2 + 10, top + 8, C["text2"])
        if bh > 150:
            cv.circle(cx, top + 92, 52, fill=C["don"])
            cv.text(cx, top + 94, "祝", 70, C["paper"], weight=900)
    for sx in (-1, 1):
        # pivot = the inner bottom corner of the dome, which stays at the hinge
        pv = (-sx * R, 0)
        for rr, col in ((R + 8, OUTLINE), (R, C["text"]), (R * 0.93, gold)):
            cv.poly(_xf(_dome_pts(rr), -sx * ang, pv, (cx + sx * 6, hinge_y)), col)
    return cv.result()


def _glow_disc(w, h, col, steps=((1.0, 40), (0.78, 70), (0.55, 110))):
    def draw(i, n, ww, hh):
        cv = Canvas(ww, hh, ss=2)
        cx, cy, R = ww / 2, hh / 2, min(ww, hh) / 2 - 2
        for f, a in steps:
            cv.circle(cx, cy, R * f, fill=alpha(col, a))
        return cv.result()
    return draw


def f_k_glow(i, n, w, h):
    cv = Canvas(w, h, ss=2)
    R = w / 2 - 4
    # a flat ring + two soft discs: the stage-by-stage glow around the ball
    cv.circle(w / 2, h / 2, R, fill=alpha(C["roll"], 26))
    cv.circle(w / 2, h / 2, R * 0.84, fill=alpha(C["roll"], 40))
    return cv.result()


def f_k_vignette(i, n, w, h):
    cv = Canvas(w, h, ss=1)
    # three flat rounded frames closing in from the edge
    for k, a in enumerate((90, 60, 36)):
        inset = k * 34
        m, d = cv.mask()
        d.rectangle([0, 0, w, h], fill=255)
        d.rounded_rectangle([inset + 34, inset + 34, w - inset - 34, h - inset - 34], radius=60, fill=0)
        cv.paint(m, alpha(C["roll"], a))
    return cv.result()


def f_k_lines(i, n, w, h):
    cv = Canvas(w, h, ss=1)
    cx, cy = w / 2, h / 2
    cnt = 36
    for k in range(cnt):
        a = (k + (0.5 if i % 2 else 0) + i * 0.17) / cnt * math.tau
        spread = 0.022
        r0, r1 = 330 + (k * 37 % 90), 1000
        p = [(cx + math.cos(a - spread) * r1, cy + math.sin(a - spread) * r1),
             (cx + math.cos(a + spread) * r1, cy + math.sin(a + spread) * r1),
             (cx + math.cos(a) * r0, cy + math.sin(a) * r0)]
        cv.poly(p, alpha(C["text"], 230))
    return cv.result()


def f_k_counter(i, n, w, h):
    cv = Canvas(w, h, ss=2)
    cv.text(w / 2, h / 2 + 8, str(i % 10), 215, C["text"], weight=900, stroke=8, stroke_fill=C["paper"])
    return cv.result()


def f_k_renda(i, n, w, h):
    cv = Canvas(w, h, ss=2)
    cv.text(w / 2, h / 2 + 2, "連打!!", 70, C["roll"], weight=900, stroke=6, stroke_fill=C["ink"], max_w=w - 12)
    return cv.result()


# --- the little ones that fly out of the popped ball: flat geometric friends, not characters
def _face(cv, cx, cy, s, left=False):
    eyes(cv, cx - (2 * s if left else -2 * s) * 0.0, cy, 7 * s, 3.2 * s)
    cv.arc(cx, cy + 2 * s, 7 * s, 20, 160, C["ink"], 2.2 * s)


def f_cotton(i, n, w, h):
    """A cloud: a few discs and a dark face. 0 = right side (sky), 1 = left side (coral)."""
    col = C["ka"] if i == 0 else C["p1"]
    cv = Canvas(w, h)
    cx, cy = w / 2, h / 2 + 4
    for dx, dy, r in ((-40, 8, 32), (40, 8, 32), (0, -22, 40), (-26, -14, 30), (26, -14, 30), (0, 20, 38)):
        cv.circle(cx + dx, cy + dy, r + 3, fill=OUTLINE)
    for dx, dy, r in ((-40, 8, 32), (40, 8, 32), (0, -22, 40), (-26, -14, 30), (26, -14, 30), (0, 20, 38)):
        cv.circle(cx + dx, cy + dy, r, fill=col)
    _face(cv, cx, cy - 2, 1.5)
    return cv.result()


def f_bell(i, n, w, h):
    """A bell tipping: frames 0-2 grey (right side), 3-5 gold (left side)."""
    st = i % 3
    col = C["text2"] if i < 3 else C["roll"]
    ang = [24, -34, 0][st]
    cv = Canvas(w, h)
    cx, cy = w / 2, h / 2 + 10
    ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))

    def T(x, y):
        return (cx + x * ca - y * sa, cy + x * sa + y * ca)
    dome = [T(-78 * math.cos(t) * 1.0, -80 * math.sin(t) + 20) for t in [k * math.pi / 24 for k in range(25)]]
    body = dome + [T(88, 26), T(88, 44), T(-88, 44), T(-88, 26)]
    cv.poly([(x, y) for x, y in body], OUTLINE)
    # inset face
    dome2 = [T(-72 * math.cos(t), -74 * math.sin(t) + 20) for t in [k * math.pi / 24 for k in range(25)]]
    body2 = dome2 + [T(80, 26), T(80, 38), T(-80, 38), T(-80, 26)]
    cv.poly(body2, col)
    tx, ty = T(0, -92)
    cv.circle(tx, ty, 12, fill=C["text"])
    bx, by = T(0, 56)
    cv.circle(bx, by, 15, fill=C["paper"])
    ex, ey = T(0, 0)
    eyes(cv, ex, ey, 20, 6.5)
    return cv.result()


def f_bird(i, n, w, h):
    """0-2: right side (coral), 3-5: left side (sky); the bird faces outward."""
    left = i >= 3
    st = i % 3
    col = C["ka"] if left else C["p1"]
    cv = Canvas(w, h)
    cx, cy = w / 2, h / 2 + 4
    d = -1 if left else 1
    cv.circle(cx, cy, 46, fill=OUTLINE)
    cv.circle(cx, cy, 43, fill=col)
    # wing: up / mid / down
    wy = [-26, -4, 20][st]
    cv.poly([(cx - d * 8, cy + 4), (cx - d * 58, cy + wy), (cx - d * 40, cy + 22)], OUTLINE)
    cv.poly([(cx - d * 12, cy + 4), (cx - d * 50, cy + wy + 2), (cx - d * 38, cy + 18)], mix(col, C["bg0"], 0.25))
    cv.poly([(cx + d * 38, cy - 8), (cx + d * 66, cy + 2), (cx + d * 38, cy + 12)], C["roll"])
    cv.circle(cx + d * 20, cy - 12, 5.5, fill=C["ink"])
    return cv.result()


def f_balloon_friend(i, n, w, h):
    """0-3: right side (gold), 4-7: left side (pink). The legs fold up as the pose advances."""
    left = i >= 4
    st = i % 4
    col = C["oni"] if left else C["roll"]
    cv = Canvas(w, h)
    cx, cy = w / 2, 74
    cv.circle(cx, cy, 50, fill=OUTLINE)
    cv.circle(cx, cy, 47, fill=col)
    cv.poly([(cx - 8, cy - 46), (cx, cy - 58), (cx + 8, cy - 46)], C["balloon"])
    eyes(cv, cx, cy - 6, 15, 5)
    cv.arc(cx, cy + 4, 11, 20, 160, C["ink"], 2.5)
    leg = [58, 40, 26, 16][st]
    for sx in (-1, 1):
        cv.line([(cx + sx * 16, cy + 46), (cx + sx * 16, cy + 46 + leg)], OUTLINE, 14)
        cv.line([(cx + sx * 16, cy + 46), (cx + sx * 16, cy + 46 + leg)], C["text"], 9)
    return cv.result()


def f_chick(i, n, w, h):
    st = i % 3
    cv = Canvas(w, h)
    cx, cy = w / 2, h / 2 + 2
    cv.circle(cx, cy, 52, fill=OUTLINE)
    cv.circle(cx, cy, 49, fill=C["roll"])
    wy = [8, -10, 14][st]
    for sx in (-1, 1):
        cv.poly([(cx + sx * 40, cy + 6), (cx + sx * 74, cy + wy), (cx + sx * 44, cy + 28)], OUTLINE)
        cv.poly([(cx + sx * 42, cy + 8), (cx + sx * 66, cy + wy + 2), (cx + sx * 44, cy + 24)],
                mix(C["roll"], C["bg0"], 0.2))
    eyes(cv, cx, cy - 8, 15, 5)
    cv.poly([(cx - 8, cy + 4), (cx + 8, cy + 4), (cx, cy + 16)], C["balloon"])
    return cv.result()


def build_kusudama(out):
    sw = SubsetWriter(out, SCREEN, "kusudama")
    sw.put("kusudama", f_kusudama_ball)
    sw.put("renda", f_k_renda)
    sw.put("counter", f_k_counter)
    sw.put("glow", f_k_glow)
    sw.put("lines", f_k_lines)
    sw.put("vignette", f_k_vignette)
    sw.put("cotton", f_cotton)
    sw.put("bell", f_bell)
    sw.put("bird", f_bird)
    sw.put("balloon", f_balloon_friend)
    sw.put("chick", f_chick)
    return sw.write()


# ================================================================== dan_info
# dan plate colours by dan_color (frame index): tinted dark plate + a full-colour edge
DAN_FRAME = [C["tower"], C["balloon"], C["text2"], C["don"], C["text2"], C["dan"], C["easy"]]


def f_dan_frame(i, n, w, h):
    col = DAN_FRAME[i % len(DAN_FRAME)]
    cv = Canvas(w, h)
    pixbox(cv, 2, 4, w - 6, h - 8, fill=col, border=INK, shadow=4, px=3)
    cv.rect(12, 14, w - 16, h - 18, INK)
    cv.rect(14, 16, w - 18, h - 20, mix(col, C["paper"], 0.78))
    return cv.result()


def f_exam_bg(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 0, 0, w - 3, h - 3, fill=C["paper"], border=INK, shadow=3, px=3)
    return cv.result()


def f_exam_ov1(i, n, w, h):
    cv = Canvas(w, h)
    cv.rect(15, 12, w - 15, h - 12, C["bg3"])
    return cv.result()


def f_exam_ov2(i, n, w, h):
    cv = Canvas(w, h)
    cv.rect(15, 12, w - 15, 14, INK)
    cv.rect(15, h - 14, w - 15, h - 12, INK)
    cv.rect(15, 12, 17, h - 12, INK)
    cv.rect(w - 17, 12, w - 15, h - 12, INK)
    return cv.result()


def f_exam_failed(i, n, w, h):
    cv = Canvas(w, h)
    cv.text(w / 2, h / 2 + 2, "達成失敗", 44, C["p1"], weight=900, stroke=4, stroke_fill=C["ink"], max_w=w - 8)
    return cv.result()


def f_bar_solid(color):
    def draw(i, n, w, h):
        return Image.new("RGBA", (w, h), color)
    return draw


def build_dan_info(out):
    sw = SubsetWriter(out, SCREEN, "dan_info")
    sw.put("frame", f_dan_frame)
    sw.put("exam_bg", f_exam_bg)
    sw.put("exam_overlay_1", f_exam_ov1)
    sw.put("exam_overlay_2", f_exam_ov2)
    sw.put("exam_failed", f_exam_failed)
    sw.put("exam_red", f_bar_solid(C["p1"]))
    sw.put("exam_gold", f_bar_solid(C["roll"]))
    sw.put("exam_max", f_bar_solid(C["normal"]))
    sw.put("exam_flash", f_bar_solid(C["paper"]))
    sw.put("total_notes_counter", f_digits(58, C["text"], weight=800))
    sw.put("value_counter", f_digits(30, C["text"], weight=800))
    return sw.write()


# ================================================================== gauge_dan / gauge_ai
def _dan_masks():
    """Dan groove (x 4..703 rows 26..55 frame, interior 8..700 x 30..52)."""
    return dict(x0=4, x1=704, y0=26, y1=56, ix0=8, ix1=700, iy0=30, iy1=52)


def f_dan_border(i, n, w, h):
    cv = Canvas(w, h, ss=2)
    cv.rect(0, 22, 872, h + 12, INK)
    cv.rect(862, 0, w + 12, h + 12, INK)
    cv.rect(3, 25, 872, h + 12, C["paper"])
    cv.rect(865, 3, w + 12, h + 12, C["paper"])
    return cv.result()


def f_dan_unfilled(pcol):
    def draw(i, n, w, h):
        g = _dan_masks()
        cv = Canvas(w, h, ss=2)
        cv.rect(g["x0"], g["y0"], g["x1"], g["y1"], INK)
        cv.rect(g["ix0"], g["iy0"], g["ix1"], g["iy1"], mix(C["bg3"], pcol, 0.14))
        return cv.result()
    return draw


def f_dan_overlay(i, n, w, h):
    g = _dan_masks()
    cv = Canvas(w, h, ss=1)
    for k in range(1, 50):
        x = int(round(g["ix0"] + k * (g["ix1"] - g["ix0"]) / 50))
        cv.rect(x, g["iy0"], x + 2, g["iy1"], alpha(INK, 190))
    return cv.result()


def f_dan_rainbow(i, n, w, h):
    # drawn at y 152 over a groove whose interior starts at absolute y 162: frame rows 10..31
    g = _dan_masks()
    im = blank(w, h)
    px = im.load()
    for x in range(g["ix0"], g["ix1"]):
        seg = int((x - g["ix0"]) * 50 / 692)
        c = hue(seg / 50 * 0.85 - i / n, s=0.55, v=1.0)
        for y in range(10, h):
            px[x, y] = c
    return im


def _soul_set(sw):
    G = _g()
    sw.put("tamashii", G.f_soul(C["clear"], INK))
    sw.put("tamashii_dark", G.f_soul(C["bg3"], C["text2"]))
    sw.put("tamashii_overlay", G.f_soul_overlay)
    sw.put("tamashii_fire", G.f_soul_fire)


def build_gauge_dan(out):
    G = _g()
    sw = SubsetWriter(out, SCREEN, "gauge_dan")
    sw.put("border", f_dan_border)
    sw.put("1p_unfilled", f_dan_unfilled(C["p1"]))
    sw.put("2p_unfilled", f_dan_unfilled(C["p2"]))
    sw.put("overlay", f_dan_overlay)
    sw.put("rainbow", f_dan_rainbow)
    sw.put("1p_bar", G.f_bar(C["p1"]))
    sw.put("2p_bar", G.f_bar(C["p2"]))
    sw.put("1p_bar_fade", G.f_glow(C["paper"]))
    sw.put("2p_bar_fade", G.f_glow(C["paper"]))
    _soul_set(sw)
    sw.put("hit_effect_circle", G.f_white_disk(36))
    sw.put("hit_effect_circle_big", G.f_white_disk(54))
    sw.put("hit_effect", G.f_gauge_burst)
    return sw.write()


def build_gauge_ai(out):
    """Same bars as the normal gauge (the parent's two share their geometry)."""
    G = _g()
    sw = SubsetWriter(out, SCREEN, "gauge_ai")
    for d in ("easy", "normal", "hard"):
        sw.put(f"1p_unfilled_{d}", G.f_unfilled(d, C["p1"]))
        sw.put(f"2p_unfilled_{d}", G.f_unfilled(d, C["p2"]))
        sw.put(f"overlay_{d}", G.f_overlay(d))
        sw.put(f"rainbow_{d}", G.f_rainbow(d))
    clear = "クリア" if LANG == "ja" else "CLEAR"
    sw.put("clear", G.f_clear_label(clear, C["clear"]))
    sw.put("clear_dark", G.f_clear_label(clear, C["mute"], lit=False))
    sw.put("1p_bar", G.f_bar(C["p1"]))
    sw.put("2p_bar", G.f_bar(C["p2"]))
    sw.put("bar_clear_top", G.f_bar(C["clear"]))
    sw.put("bar_clear_bottom", G.f_bar(C["clear"]))
    sw.put("bar_clear_transition", G.f_bar(C["clear"], 4, 48, 0, 10))
    for k in ("1p_bar_fade", "2p_bar_fade", "bar_clear_fade", "bar_clear_transition_fade"):
        sw.put(k, G.f_glow(C["paper"]))
    _soul_set(sw)

    def footer(i, n, w, h):
        cv = Canvas(w, h)
        pixbox(cv, 0, 4, w - 4, h - 8, fill=C["paper"], border=INK, shadow=3, px=3)
        return cv.result()
    sw.put("footer", footer)
    return sw.write()


# ================================================================== judge_counter
def f_jc_pills(i, n, w, h):
    cv = Canvas(w, h)
    for cy, lab, col in ((23, "良", C["gold_t"]), (60.5, "可", C["text2"]), (98, "不可", C["bad"])):
        pixbox(cv, 10, cy - 17, w - 6, cy + 17, fill=C["bg2"], border=INK, shadow=0, px=2)
        cv.text(66, cy + 1, lab, 24, col, weight=900)
    return cv.result()


def f_jc_roll(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 10, 3, w - 6, h - 3, fill=C["bg2"], border=INK, shadow=0, px=2)
    cv.text(66, h / 2 + 1, "連打", 24, C["gold_t"], weight=900)
    return cv.result()


def f_jc_bg(i, n, w, h):
    cv = Canvas(w, h)
    cv.rect(0, 0, w, h, C["paper"])
    cv.rect(w - 4, 0, w, h, INK)
    return cv.result()


def build_judge_counter(out):
    sw = SubsetWriter(out, SCREEN, "judge_counter")
    sw.put_blank("bg")   # drawn by the patched Lua (the texture is stretched, its edge would smear)
    sw.put("total_percent", f_text("たたけた率", 28, C["text"], x=8, anchor="lm", weight=800))
    sw.put("judgments", f_jc_pills)
    sw.put("drumrolls", f_jc_roll)
    sw.put("percent", f_text("%", 32, C["text"], weight=800))
    sw.put("counter", f_digits(34, C["text"], weight=800))
    return sw.write()


# ================================================================== practice
BTN_DON, BTN_KAT = "don", "ka"


def _glyph(cv, kind, cx, cy, col):
    if kind == "pause":
        cv.rect(cx - 20, cy - 24, cx - 6, cy + 24, col)
        cv.rect(cx + 6, cy - 24, cx + 20, cy + 24, col)
    elif kind == "play":
        cv.poly([(cx - 16, cy - 26), (cx + 24, cy), (cx - 16, cy + 26)], col)
    elif kind == "ff":
        cv.poly([(cx - 26, cy - 22), (cx, cy), (cx - 26, cy + 22)], col)
        cv.poly([(cx, cy - 22), (cx + 26, cy), (cx, cy + 22)], col)
    elif kind == "rw":
        cv.poly([(cx + 26, cy - 22), (cx, cy), (cx + 26, cy + 22)], col)
        cv.poly([(cx, cy - 22), (cx - 26, cy), (cx, cy + 22)], col)
    elif kind == "menu":
        for dy in (-18, 0, 18):
            cv.rect(cx - 26, cy + dy - 5, cx + 26, cy + dy + 5, col)
    elif kind == "ok":
        cv.rect(cx - 26, cy - 26, cx + 26, cy + 26, col)
        cv.rect(cx - 17, cy - 17, cx + 17, cy + 17, C["ink"])
    elif kind == "x":
        cv.line([(cx - 20, cy - 20), (cx + 20, cy + 20)], col, 9)
        cv.line([(cx + 20, cy - 20), (cx - 20, cy + 20)], col, 9)
    else:  # a single character
        cv.text(cx, cy + 2, kind, 58, col, weight=900)


def f_btn(side, label, glyph):
    col = C["don"] if side == BTN_DON else C["ka"]

    def draw(i, n, w, h):
        cv = Canvas(w, h)
        pixbox(cv, 2, 3, w - 7, h - 7, fill=col, border=INK, shadow=4, px=3)
        cv.text(w / 2 - 2, 25, label, 26, C["paper"], weight=900, max_w=w - 20, stroke=2.5, stroke_fill=INK)
        pixbox(cv, 14, 42, w - 19, h - 18, fill=C["ink"], border=INK, shadow=0, px=2)
        _glyph(cv, glyph, w / 2 - 2, (42 + h - 18) / 2, C["paper"])
        return cv.result()
    return draw


def f_large_drum(i, n, w, h):
    G = _g()
    cv = Canvas(w, h, ss=2)
    cx, cy, R = w / 2, 172.0, 162.0
    cv.rect(cx - R, cy, cx + R, h + 40, INK)
    cv.rect(cx - R + 4, cy, cx + R - 4, h + 40, C["bg3"])
    G.pdisc(cv, cx, cy, R + 6, INK, 6)
    G.pdisc(cv, cx, cy, R, C["bg3"], 6)
    G.pdisc(cv, cx, cy, R * 0.80 + 6, INK, 6)
    G.pdisc(cv, cx, cy, R * 0.80, C["bg0"], 6)
    cv.rect(cx - 2, cy - R * 0.80 + 18, cx + 2, cy + R * 0.80 - 18, alpha(INK, 90))
    return cv.result()


def f_large_hit(kind, side=None):
    def draw(i, n, w, h):
        G = _g()
        cv = Canvas(w, h, ss=2)
        cx, cy, R = w / 2, 172.0, 162.0
        if kind == "don":
            G.pdisc(cv, cx, cy, R * 0.80, C["don"], 6)
        else:
            G.pdisc(cv, cx, cy, R, C["ka"], 6)
            G.pdisc(cv, cx, cy, R * 0.80 + 12, (0, 0, 0, 0), 6)
            if side == "l":
                cv.rect(cx - 3, 0, w, h, (0, 0, 0, 0))
            else:
                cv.rect(0, 0, cx + 3, h, (0, 0, 0, 0))
        return cv.result()
    return draw


def f_playing(i, n, w, h):
    cv = Canvas(w, h)
    cv.text(w / 2, h / 2, "演奏中", 58, C["text2"], weight=900, max_w=w - 8)
    return cv.result()


def f_paused(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 10, 10, w - 14, h - 14, fill=C["paper"], border=INK, shadow=4, px=5)
    _glyph(cv, "pause", w / 2 - 2, h / 2 - 2, C["ink"])
    return cv.result()


def f_pbar_bg(i, n, w, h):
    # stretched 28x sideways by the engine: keep every column identical (ink rules top and bottom only)
    cv = Canvas(w, h, ss=1)
    cv.rect(0, 0, w, h, INK)
    cv.rect(0, 5, w, h - 5, C["bg3"])
    cv.rect(0, 5, w, 8, mix(C["bg3"], C["ink"], 0.12))
    return cv.result()


def f_pbar(i, n, w, h):
    cv = Canvas(w, h, ss=1)
    cv.rect(0, 0, w, h, C["clear"])
    cv.rect(0, 0, w, 2, alpha(C["paper"], 160))
    return cv.result()


def f_gogo_marker(i, n, w, h):
    G = _g()
    x0, y0, x1, y1 = ref_bbox("game", "practice", "gogo_marker.png")
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2 + 2
    cv = Canvas(w, h)
    cv.circle(cx, cy + 3, 17, fill=OUTLINE)
    G.flame(cv, cx, cy + 4, 12, alpha(C["gogo"], 255), 0.0)
    return cv.result()


def f_jump_progress(i, n, w, h):
    x0, y0, x1, y1 = ref_bbox("game", "practice", "jump_point_progress.png")
    cv = Canvas(w, h)
    cx = (x0 + x1) / 2
    cv.poly([(cx, y0), (x1 + 2, y1), (x0 - 2, y1)], OUTLINE)
    cv.poly([(cx, y0 + 5), (x1 - 3, y1 - 3), (x0 + 3, y1 - 3)], C["ka"])
    return cv.result()


def f_jump_arrow(i, n, w, h):
    x0, y0, x1, y1 = ref_bbox("game", "practice", "jump_point_arrow.png")
    cv = Canvas(w, h)
    cx = (x0 + x1) / 2
    cv.poly([(x0 - 2, y0), (x1 + 2, y0), (cx, y1 + 2)], OUTLINE)
    cv.poly([(x0 + 5, y0 + 5), (x1 - 5, y0 + 5), (cx, y1 - 8)], C["ka"])
    return cv.result()


def f_jump_editing(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 4, 4, w - 9, h - 9, fill=C["paper"], border=INK, shadow=5, px=4)
    cv.rect(10, 10, w - 15, 14, C["clear"])
    cv.text(w / 2 - 2, h / 2 + 2, "ジャンプポイントを設定", 44, C["text"], weight=800, max_w=w - 60)
    return cv.result()


def f_chip(label, fill, fg, size=17):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        pixbox(cv, 1, 1, w - 4, h - 4, fill=fill, border=INK, shadow=2, px=2)
        cv.text(w / 2 - 1, h / 2, label, size, fg, weight=800, max_w=w - 14)
        return cv.result()
    return draw


def f_menu_panel(i, n, w, h):
    cv = Canvas(w, h, ss=2)
    pixbox(cv, 2, 2, w - 8, h - 8, fill=C["paper"], border=INK, shadow=5, px=4)
    return cv.result()


def f_menu_bar(selected):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        if selected:
            pixbox(cv, 2, 2, w - 3, h - 3, fill=C["clear"], border=INK, shadow=0, px=4)
        else:
            pixbox(cv, 3, 3, w - 3, h - 3, fill=C["bg2"], border=INK, shadow=0, px=2)
        return cv.result()
    return draw


def f_menu_toggle(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 4, 14, w - 4, h - 14, fill=C["bg0"], border=INK, shadow=0, px=2)
    pixbox(cv, 8, h / 2 - 17, h / 2 + 24, h / 2 + 17, fill=C["p1"], border=INK, shadow=0, px=3)
    cv.rect(h / 2 + 4 + 36, h / 2 - 2, w - 22, h / 2 + 2, C["line"])
    return cv.result()


def f_menu_auto_label(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 6, 8, w - 9, h - 11, fill=C["roll"], border=INK, shadow=3, px=3)
    cv.text(w / 2, h / 2 + 1, "オート", 34, INK, weight=900)
    return cv.result()


def build_practice(out):
    sw = SubsetWriter(out, SCREEN, "practice")
    sw.put("progress_bar", f_pbar)
    sw.put("progress_bar_bg", f_pbar_bg)
    sw.put("gogo_marker", f_gogo_marker)
    sw.put("jump_point_progress", f_jump_progress)
    sw.put("jump_point_arrow", f_jump_arrow)
    sw.put("large_drum", f_large_drum)
    sw.put("large_drum_don", f_large_hit("don"))
    sw.put("large_drum_kat_l", f_large_hit("kat", "l"))
    sw.put("large_drum_kat_r", f_large_hit("kat", "r"))
    sw.put("playing", f_playing)
    sw.put("paused", f_paused)
    sw.put("pause_don", f_btn(BTN_DON, "一時停止", "pause"))
    sw.put("pause_kat", f_btn(BTN_KAT, "一時停止", "pause"))
    sw.put("resume_don", f_btn(BTN_DON, "再生", "play"))
    sw.put("menu_don", f_btn(BTN_DON, "メニュー", "menu"))
    sw.put("confirm", f_btn(BTN_DON, "決定", "ok"))
    sw.put("delete", f_btn(BTN_DON, "削除", "x"))
    sw.put("finish", f_btn(BTN_DON, "終了", "完"))
    sw.put("speed_l_kat", f_btn(BTN_KAT, "テンポ", "遅"))
    sw.put("speed_r_kat", f_btn(BTN_KAT, "テンポ", "速"))
    sw.put("skip_l_kat", f_btn(BTN_KAT, "早戻し", "rw"))
    sw.put("skip_r_kat", f_btn(BTN_KAT, "早送り", "ff"))
    sw.put("jump_point_editing", f_jump_editing)
    sw.put("bar_count", f_digits(21, C["text"], weight=800))
    sw.put("bar_count_bar", f_digits(17, C["text"], weight=800, stroke=1.5))
    sw.put("bar_divider", f_text("/", 21, C["text2"], weight=700))
    sw.put("dot", f_text(".", 21, C["text"], weight=900))
    sw.put("multiplier", f_text("倍", 18, C["text2"], weight=800))
    sw.put("bar_label", f_chip("小節", C["bg3"], C["text"], 16))
    sw.put("song_tempo", f_chip("曲テンポ", C["clear"], C["ink"], 15))
    sw.put("menu_panel", f_menu_panel)
    sw.put("menu_bar", f_menu_bar(False))
    sw.put("menu_bar_selected", f_menu_bar(True))
    sw.put("menu_button", f_menu_bar(False))
    sw.put("menu_button_selected", f_menu_bar(True))
    sw.put("menu_toggle", f_menu_toggle)
    sw.put("menu_auto_label", f_menu_auto_label)
    return sw.write()


# ================================================================== ai_battle (the engine has no scene for it yet)
def _ramp(a, b, i, n):
    return mix(a, b, i / max(1, n - 1))


def f_tile_lower(c0, c1):
    def draw(i, n, w, h):
        cv = Canvas(w, h, ss=2)
        cv.rect(3, 6, w - 3, h - 6, _ramp(c0, c1, i, n))
        return cv.result()
    return draw


def f_tile_upper(c0, c1):
    def draw(i, n, w, h):
        cv = Canvas(w, h, ss=2)
        col = _ramp(c0, c1, i, n)
        k = (i % 4 - 1.5) * 10
        cv.poly([(34 + k, 6), (w - 6 + k, 6), (w - 40 - k, h - 6), (6 - k, h - 6)], col)
        return cv.result()
    return draw


def f_hl_tile(i, n, w, h):
    cv = Canvas(w, h, ss=2)
    cv.rrect(4, 4, w - 4, h - 4, 6, outline=alpha(C["text"], 255), width=4)
    return cv.result()


def f_band_bg(i, n, w, h):
    cv = Canvas(w, h, ss=1)
    cv.rect(0, 0, w, h, C["bg1"])
    cv.rect(0, 0, w, 2, C["line"])
    cv.rect(0, h - 2, w, h, C["line"])
    return cv.result()


def f_band_outline(i, n, w, h):
    cv = Canvas(w, h, ss=1)
    for x in range(0, w, 80):
        cv.rect(x, 0, x + 1, h, alpha(C["line"], 110))
    for y in range(0, h, 46):
        cv.rect(0, y, w, y + 1, alpha(C["line"], 110))
    return cv.result()


def f_scoreboard(col):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        pixbox(cv, 2, 2, w - 6, h - 6, fill=C["paper"], border=INK, shadow=3, px=3)
        cv.rect(5, 5, w - 9, 9, col)
        for k, (lab, lc) in enumerate((("良", C["gold_t"]), ("可", C["text2"]), ("不可", C["bad"]), ("連打", C["gold_t"]))):
            cv.text(w / 2, 17 + k * 20, lab, 15, lc, weight=900)
        return cv.result()
    return draw


def f_diamond(fill, label=None, lc=None, outline=None):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        r = w / 2 - 3
        pts = [(w / 2, h / 2 - r), (w / 2 + r, h / 2), (w / 2, h / 2 + r), (w / 2 - r, h / 2)]
        cv.poly(pts, OUTLINE)
        s = 0.84
        cv.poly([(w / 2 + (x - w / 2) * s, h / 2 + (y - h / 2) * s) for x, y in pts], fill)
        if label:
            cv.text(w / 2, h / 2 + 1, label, 20, lc, weight=900)
        return cv.result()
    return draw


def f_sections(i, n, w, h):
    cv = Canvas(w, h)
    for k in range(4):
        cx = 26 + k * 46
        r = 20
        pts = [(cx, h / 2 - r), (cx + r, h / 2), (cx, h / 2 + r), (cx - r, h / 2)]
        cv.poly(pts, OUTLINE)
        cv.poly([(cx + (x - cx) * 0.8, h / 2 + (y - h / 2) * 0.8) for x, y in pts], C["bg3"])
    return cv.result()


def f_section_text(i, n, w, h):
    cv = Canvas(w, h)
    cv.text(w / 2, h / 2, f"{i + 1}区", 15, C["text"], weight=800, max_w=w - 2)
    return cv.result()


def f_pbar_ai(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 2, 8, w - 6, h - 10, fill=C["paper"], border=INK, shadow=3, px=3)
    cv.rect(12, 16, w - 12, h - 18, C["bg3"])
    return cv.result()


def build_ai_battle(out):
    sw = SubsetWriter(out, SCREEN, "ai_battle")
    sw.put("bg_upper", f_band_bg)
    sw.put("bg_lower", f_band_bg)
    sw.put("bg_outline_upper", f_band_outline)
    sw.put("red_tile_lower", f_tile_lower(C["p1"], C["roll"]))
    sw.put("blue_tile_lower", f_tile_lower(C["hard"], mix(C["p2"], C["text"], 0.6)))
    sw.put("highlight_tile_lower", f_hl_tile)
    sw.put("red_tile_upper", f_tile_upper(C["p1"], C["roll"]))
    sw.put("blue_tile_upper", f_tile_upper(C["hard"], mix(C["p2"], C["text"], 0.6)))
    sw.put("highlight_tile_upper", f_hl_tile)
    sw.put("scoreboard", f_scoreboard(C["p1"]))
    sw.put("scoreboard_ai", f_scoreboard(C["p2"]))
    sw.put("scoreboard_num", f_digits(18, C["text"], weight=800))
    sw.put_blank("lower_triangles_1")
    sw.put_blank("lower_triangles_2")
    sw.put("progress_bar", f_pbar_ai)
    sw.put("section_text", f_section_text)
    sw.put("sections", f_sections)
    sw.put("section_highlight_green", f_diamond(C["normal"]))
    sw.put("section_highlight_white", f_diamond(C["paper"]))
    sw.put("section_win", f_diamond(C["roll"], "勝", C["ink"]))
    sw.put("section_lose", f_diamond(C["bg3"], "負", C["text2"]))
    return sw.write()


# ------------------------------------------------------------------ build + parent Lua patches
def build_all(out):
    counts = {}
    for name, fn in [("kusudama", build_kusudama), ("dan_info", build_dan_info), ("gauge_dan", build_gauge_dan),
                     ("practice", build_practice), ("judge_counter", build_judge_counter),
                     ("ai_battle", build_ai_battle), ("gauge_ai", build_gauge_ai)]:
        counts[name] = fn(out)
    return counts


LUA_PATCHES = {
    "game/judge_counter.lua": [
        ("    tex.draw_texture(self.drumrolls)\n",
         "    tex.draw_texture(self.drumrolls)\n"
         "    if tex.current_screen() == \"GAME_PRACTICE\" then   -- SimpleStyle: Hoshi stands on a ground line\n"
         "        local UI = require(\"global.ss_ui\")\n"
         "        self.hoshi = self.hoshi or tex.get_texture(\"game/ss_hoshi/body\")\n"
         "        local gy = 702 * SKIN_S\n"
         "        UI.rect(10 * SKIN_S, gy, 316 * SKIN_S, 4 * SKIN_S, UI.P.ink)\n"
         "        for k = 0, 25 do UI.rect((10 + k * 12) * SKIN_S, gy + 4 * SKIN_S, 6 * SKIN_S, 6 * SKIN_S, UI.mix(UI.P.mint, UI.P.paper, 0.4)) end\n"
         "        for k = 0, 24 do UI.rect((16 + k * 12) * SKIN_S, gy + 10 * SKIN_S, 6 * SKIN_S, 6 * SKIN_S, UI.mix(UI.P.mint, UI.P.paper, 0.4)) end\n"
         "        self.n = (self.n or 0) + 1\n"
         "        local expr = (self.n % 200 < 8) and UI.D.MASCOT.expr.blink or UI.D.MASCOT.expr.idle\n"
         "        if self.hoshi then tex.draw_texture(self.hoshi, { frame = expr, x = 222 * SKIN_S, y = gy - 102 * SKIN_S }) end\n"
         "    end\n"),
        ("    tex.draw_texture(self.bg)\n",
         "    local UI = require(\"global.ss_ui\")   -- SimpleStyle: paper panel, ink right edge\n"
         "    UI.rect(0, 358 * SKIN_S, 331 * SKIN_S, 362 * SKIN_S, UI.P.paper)\n"
         "    UI.rect(331 * SKIN_S, 358 * SKIN_S, 3 * SKIN_S, 362 * SKIN_S, UI.P.ink)\n"),
        ("local ORANGE, WHITE = { 253, 161, 0, 255 }, { 255, 255, 255, 255 }",
         "local ORANGE, WHITE = { 255, 255, 255, 255 }, { 255, 255, 255, 255 }   -- the digit textures are baked ink on paper"),
    ],
    # 4+ digit combos (dan courses) ran past the player box's ink edge into the lane: tighten the
    # spacing (the 2 px ink outlines merge) and move the number left so it ends inside the box
    "game/combo.lua": [
        ("    local margin = gold and SKIN.margin.y or SKIN.margin.x\n",
         "    local margin = gold and SKIN.margin.y or SKIN.margin.x\n"
         "    local shift = 0   -- SimpleStyle: 4+ digits stay inside the player box\n"
         "    if #str >= 4 then margin = 31 * SKIN_S; shift = -(10 + (#str - 4) * 31) * SKIN_S end\n"),
        ("            frame = str:byte(i) - 48, x = -(#str * margin / 2) + (i - 1) * margin,\n",
         "            frame = str:byte(i) - 48, x = shift - (#str * margin / 2) + (i - 1) * margin,\n"),
        ("            tex.draw_texture(self.t_gleam, { color = color, x = g.x + i * margin,",
         "            tex.draw_texture(self.t_gleam, { color = color, x = shift + g.x + i * margin,"),
    ],
    "game/dan_game_draw.lua": [
        ("local WHITE, BLACK = { 255, 255, 255, 255 }, { 0, 0, 0, 255 }",
         "local WHITE, BLACK = { 58, 38, 51, 255 }, { 255, 255, 255, 255 }   -- SimpleStyle light: ink text, white outline"),
    ],
    "game/practice_menu.lua": [
        ("local WHITE, BLACK = { 255, 255, 255, 255 }, { 0, 0, 0, 255 }",
         "local WHITE, BLACK = { 58, 38, 51, 255 }, { 255, 255, 255, 255 }   -- SimpleStyle light: ink text, white outline"),
    ],
}
