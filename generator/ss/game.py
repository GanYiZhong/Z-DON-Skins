"""Enso (gameplay) textures: Graphics/game/<subset>."""
from __future__ import annotations

import math
import random

from PIL import Image, ImageFilter

from .atlas import SubsetWriter, green_json, key_info, ref_bbox
from .style import C, Canvas, alpha, blank, ease_out, hue, mix, pixbar, pixbox
from . import game_rest

SCREEN = "game"
LANG = "ja"  # texts without an engine language variant (judgements, moji, branch plates)

OUTLINE = C["ink"]   # flat notes: ink separation outline
INK, PAPER = C["ink"], C["paper"]


def pdisc(cv: Canvas, cx, cy, r, fill, px=3):
    """8-bit disc: scanline blocks `px` thick, on whole pixels (never anti-aliased)."""
    cx, cy, r = round(cx), round(cy), round(r)
    for dy in range(-r, r, px):
        yc = abs(dy + px / 2)
        dx = round(math.sqrt(max(0.0, r * r - yc * yc)) / px) * px
        if dx:
            cv.rect(cx - dx, cy + dy, cx + dx, cy + dy + px, fill)


def pbadge(cv: Canvas, cx, cy, r, fill, px=3):
    """Pixel disc with an ink border (1 block)."""
    pdisc(cv, cx, cy, r + px, INK, px)
    pdisc(cv, cx, cy, r, fill, px)


def inktext(cv: Canvas, x, y, s, size, fill, weight=900, stroke=3.0, **kw):
    """Fill + ink outline text (readable on any light background)."""
    cv.text(x, y, s, size, fill, weight=weight, stroke=stroke, stroke_fill=INK, **kw)


def pixel_burst(cv: Canvas, cx, cy, r0, r1, n, col, size, rot=0.0):
    """n square pixels flying outwards between r0 and r1 (snapped to a 3 px grid)."""
    for k in range(n):
        a = k / n * math.tau + rot
        d = (r0 + r1) / 2 if r0 == r1 else r0 + (r1 - r0) * (0.5 + 0.5 * math.sin(k * 2.3))
        x, y = round((cx + math.cos(a) * d) / 3) * 3, round((cy + math.sin(a) * d) / 3) * 3
        cv.rect(x - size / 2, y - size / 2, x + size / 2, y + size / 2, col)


# ================================================================== notes
def note_disk(cv: Canvas, cx, cy, r, fill, rim=None, ring_w=None):
    """The basic SimpleStyle note: ink separation outline, white rim, flat colour face."""
    rim = rim or C["paper"]
    ring_w = ring_w if ring_w is not None else r * 0.15
    cv.circle(cx, cy, r + 2, fill=OUTLINE)
    cv.circle(cx, cy, r, fill=rim)
    cv.circle(cx, cy, r - ring_w, fill=fill)


SMALL = (64.5, 65.0, 36.0)   # centre x, centre y, radius inside a 128x128 frame
BIG = (65.0, 65.0, 54.0)


def f_note(color, big=False):
    cx, cy, r = BIG if big else SMALL

    def draw(i, n, w, h):
        cv = Canvas(w, h)
        note_disk(cv, cx, cy, r, color)
        return cv.result()
    return draw


def f_roll_body(big):
    _, cy, r = BIG if big else SMALL
    rw = r * 0.15

    def draw(i, n, w, h):
        cv = Canvas(w, h)
        # a band; the engine stretches it horizontally between head and tail
        cv.rect(-2, cy - r - 2, w + 2, cy + r + 2, OUTLINE)
        cv.rect(-2, cy - r, w + 2, cy + r, C["paper"])
        cv.rect(-2, cy - r + rw, w + 2, cy + r - rw, C["roll"])
        return cv.result()
    return draw


def f_roll_tail(big):
    _, cy, r = BIG if big else SMALL

    def draw(i, n, w, h):
        cv = Canvas(w, h)
        note_disk(cv, 0, cy, r, C["roll"])
        return cv.result()
    return draw


def f_body8(i, n, w, h):
    return f_roll_body(i == 1)(i, n, w, h)


BALLOON_HEAD_CX = 76.0  # head sits 12 px right (game_balloon_offset) of the frame centre


def f_balloon_head(i, n, w, h):
    cx, cy, r = BALLOON_HEAD_CX, SMALL[1], SMALL[2]
    cv = Canvas(w, h)
    cv.rect(cx + r - 4, cy - 5, w + 1, cy + 5, OUTLINE)
    cv.rect(cx + r - 4, cy - 3, w + 1, cy + 3, C["text"])
    note_disk(cv, cx, cy, r, C["balloon"])
    return cv.result()


def f_balloon_tail(i, n, w, h):
    """notes/10: the string and the balloon itself, right of the head."""
    cy = SMALL[1]
    cv = Canvas(w, h)
    bx, br = 58.0, 29.0
    cv.rect(-1, cy - 5, bx - br + 4, cy + 5, OUTLINE)
    cv.rect(-1, cy - 3, bx - br + 4, cy + 3, C["text"])
    # knot
    cv.poly([(bx - br - 7, cy - 8), (bx - br + 3, cy), (bx - br - 7, cy + 8)], OUTLINE)
    cv.poly([(bx - br - 5, cy - 5), (bx - br + 2, cy), (bx - br - 5, cy + 5)], C["text"])
    note_disk(cv, bx, cy, br, mix(C["balloon"], C["text"], 0.18), ring_w=4)
    # tiny flat highlight
    cv.circle(bx + 9, cy - 10, 5, fill=alpha(C["text"], 120))
    return cv.result()


def f_kusudama(i, n, w, h):
    cx, cy, r = BIG
    cv = Canvas(w, h)
    note_disk(cv, cx, cy, r, C["kusu"])
    # seam + two halves: a ball, not a face
    cv.pieslice(cx, cy, r - r * 0.15, 180, 360, mix(C["kusu"], C["don"], 0.35))
    cv.rect(cx - r + 8, cy - 3, cx + r - 8, cy + 3, C["text"])
    cv.circle(cx, cy, 9, fill=C["text"])
    cv.circle(cx, cy, 5, fill=C["kusu"])
    return cv.result()


def f_barline(i, n, w, h):
    cv = Canvas(w, h)
    col = alpha(C["text"], 120) if i == 0 else alpha(C["roll"], 235)
    cv.rect(3, 3, 5, h - 3, col)
    return cv.result()


MOJI = {
    "ja": ["ドン", "ド", "コ", "カッ", "カ", "ドン(大)", "カッ(大)", "連打ー", "連打(大)ー", "ふうせん", "ーっ!!", "くすだま"],
    "en": ["DON", "DO", "KO", "KA", "KA", "DON!", "KA!", "ROLL", "ROLL!", "BALLOON", "!!", "KUSUDAMA"],
}


def f_moji(i, n, w, h):
    cv = Canvas(w, h)
    s = MOJI[LANG][i]
    cv.text(w / 2, h / 2 + 1, s, 17, C["text2"], weight=700, max_w=w - 8)
    return cv.result()


def f_moji_mid(i, n, w, h):
    cv = Canvas(w, h)
    cv.rect(0, h / 2 - 0.5, w, h / 2 + 1.5, alpha(C["text2"], 160))
    return cv.result()


def build_notes(out):
    sw = SubsetWriter(out, SCREEN, "notes")
    sw.put("0", f_barline)
    sw.put("1", f_note(C["don"]))
    sw.put("2", f_note(C["ka"]))
    sw.put("3", f_note(C["don"], True))
    sw.put("4", f_note(C["ka"], True))
    sw.put("5", f_note(C["roll"]))
    sw.put("6", f_note(C["roll"], True))
    sw.put("7", f_balloon_head)
    sw.put("8", f_body8)
    sw.put("9", f_kusudama)
    sw.put("10", f_balloon_tail)
    sw.put("drumroll_tail", f_roll_tail(False))
    sw.put("drumroll_big_tail", f_roll_tail(True))
    sw.put("moji", f_moji)
    sw.put("moji_drumroll_mid", f_moji_mid)
    sw.put("moji_drumroll_mid_big", f_moji_mid)
    return sw.write()


# ================================================================== lane
def f_lane_bg(i, n, w, h):
    im = blank(w, h)
    px = im.load()
    for y in range(h):
        if y < 6 or 140 <= y < 142 or y >= 170:
            c = C["bg0"]
        elif y < 8 or 138 <= y < 140:
            c = INK
        elif y < 138:
            c = C["bg2"]
        else:
            c = C["bg1"]
        for x in range(w):
            px[x, y] = c
    return im


def f_lane_cover(accent):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        cv.rect(0, 0, 332, h, C["bg0"])
        # 8-bit window (its left notch is off-screen); a hard ink shadow ends before the lane
        pixbox(cv, -6, 6, 322, 168, fill=C["paper"], border=INK, shadow=4, px=3)
        cv.rect(0, 9, 12, 165, accent)                       # player accent stripe
        cv.rect(12, 9, 15, 165, INK)
        return cv.result()
    return draw


def f_score_cover(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, -10, 2, w - 4, h - 6, fill=C["bg2"], border=INK, shadow=0, px=2)
    return cv.result()


def f_hit_circle(i, n, w, h):
    cv = Canvas(w, h)
    cx = cy = 72
    cv.circle(cx, cy, 47, fill=alpha(C["bg0"], 90))
    cv.ring(cx, cy, 48, 46, alpha(INK, 90))
    cv.circle(cx, cy, 37, fill=alpha(C["bg0"], 160))
    cv.ring(cx, cy, 38, 36, alpha(INK, 170))
    return cv.result()


def f_lane_hit(colors):
    def draw(i, n, w, h):
        im = blank(w, h)
        c = colors[i]
        px = im.load()
        for x in range(w):
            t = x / (w - 1)
            a = int(70 * (1 - t) ** 1.6)
            for y in range(h):
                px[x, y] = (c[0], c[1], c[2], a)
        return im
    return draw


DRUM_C = (56.0, 58.0)
DRUM_R_FACE, DRUM_R_RIM = 39.0, 50.0


def f_drum(i, n, w, h):
    cv = Canvas(w, h)
    cx, cy = DRUM_C
    pdisc(cv, cx, cy, DRUM_R_RIM + 3, INK)
    pdisc(cv, cx, cy, DRUM_R_RIM, C["bg3"])
    pdisc(cv, cx, cy, DRUM_R_FACE + 3, INK)
    pdisc(cv, cx, cy, DRUM_R_FACE, C["bg0"])
    cv.rect(cx - 1.5, cy - DRUM_R_FACE + 6, cx + 1.5, cy + DRUM_R_FACE - 6, alpha(INK, 90))
    return cv.result()


def f_drum_hit(kind, side):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        cx, cy = DRUM_C
        if kind == "don":
            pdisc(cv, cx, cy, DRUM_R_FACE, C["don"])
        else:
            pdisc(cv, cx, cy, DRUM_R_RIM, C["ka"])
            pdisc(cv, cx, cy, DRUM_R_FACE + 3, (0, 0, 0, 0))
        # keep one half; leave a 3px seam in the middle
        if side == "l":
            cv.rect(cx - 1, 0, w, h, (0, 0, 0, 0))
        else:
            cv.rect(0, 0, cx + 2, h, (0, 0, 0, 0))
        return cv.result()
    return draw


def f_player_icon(label, color):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        pbadge(cv, w / 2, h / 2, w / 2 - 6, color)
        inktext(cv, w / 2, h / 2 + 1, label, 22, C["paper"], stroke=2.5)
        return cv.result()
    return draw


def f_auto(label):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        pixbox(cv, 6, 5, w - 10, h - 9, fill=C["roll"], border=INK, shadow=3, px=3)
        cv.text(w / 2 - 2, h / 2 - 1, label, 18, INK, weight=900, tracking=1.5 if label.isascii() else 0)
        return cv.result()
    return draw


DIFFS = [("easy", "かんたん", "EASY"), ("normal", "ふつう", "NORMAL"), ("hard", "むずかしい", "HARD"),
         ("oni", "おに", "ONI"), ("ura", "おに裏", "URA"), ("tower", "タワー", "TOWER"), ("dan", "段位", "DAN")]


def diff_glyph(cv, cx, cy, r, i):
    """A tiny geometric emblem per difficulty: 1-4 dots for easy..oni, a ring for ura, bars for tower/dan."""
    col = C["paper"]
    if i <= 3:
        k = i + 1
        sp = r * 0.55
        for j in range(k):
            x = cx + (j - (k - 1) / 2) * sp
            cv.circle(x, cy, r * 0.17, fill=col)
    elif i == 4:
        cv.ring(cx, cy, r * 0.5, r * 0.32, col)
        cv.circle(cx, cy, r * 0.14, fill=col)
    elif i == 5:
        for j in range(3):
            ww = r * (0.9 - j * 0.25)
            yy = cy + r * 0.35 - j * r * 0.33
            cv.rect(cx - ww / 2, yy - r * 0.11, cx + ww / 2, yy + r * 0.11, col)
    else:
        cv.rect(cx - r * 0.45, cy - r * 0.45, cx + r * 0.45, cy + r * 0.45, col)
        cv.rect(cx - r * 0.25, cy - r * 0.25, cx + r * 0.25, cy + r * 0.25, C[DIFFS[6][0]])


def f_lane_diff(i, n, w, h):
    key, ja, en = DIFFS[i]
    cv = Canvas(w, h)
    cx, cy, r = w / 2 + 3, 25, 19
    pbadge(cv, cx, cy, r - 3, C[key])
    diff_glyph(cv, cx, cy, r, i)
    cv.text(cx, 54, ja if LANG == "ja" else en, 13, C["text"], weight=800, max_w=w - 8)
    return cv.result()


MODS = {"mod_shinuchi": "真", "mod_abekobe": "逆", "mod_baisaku": "×2", "mod_sanbai": "×3",
        "mod_yonbai": "×4", "mod_detarame": "乱", "mod_kimagure": "気", "mod_doron": "隠"}


def f_mod(label):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        pixbox(cv, 6, 6, w - 8, h - 8, fill=C["bg3"], border=INK, shadow=2, px=2)
        cv.text(w / 2 - 1, h / 2, label, 17 if len(label) == 1 else 14, C["text"], weight=900)
        return cv.result()
    return draw


def f_digits(size, color, stroke=0, weight=800, stroke_fill=None, dy=0.0):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        cv.text(w / 2, h / 2 + dy, str(i % 10), size, color, weight=weight, stroke=stroke,
                stroke_fill=stroke_fill or C["paper"])
        return cv.result()
    return draw


def f_timer(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 3, 9, w - 6, h - 12, fill=C["paper"], border=INK, shadow=3, px=2)
    return cv.result()


def f_ai_lane_bg(i, n, w, h):
    cv = Canvas(w, h, bg=C["bg2"])
    return cv.result()


def f_fill(color):
    def draw(i, n, w, h):
        return Image.new("RGBA", (w, h), color)
    return draw


def build_lane(out):
    sw = SubsetWriter(out, SCREEN, "lane")
    sw.put("lane_background", f_lane_bg)
    sw.put("ai_lane_background", f_ai_lane_bg)
    sw.put("lane_hit_effect", f_lane_hit([C["don"], C["ka"], C["roll"]]))
    sw.put("lane_hit_circle", f_hit_circle)
    sw.put("dan_between_fill", f_fill(C["bg2"]))
    sw.put("dan_between_fusuma", game_rest.f_fusuma)
    sw.put("1p_lane_cover", f_lane_cover(C["p1"]))
    sw.put("2p_lane_cover", f_lane_cover(C["p2"]))
    sw.put("dan_lane_cover", f_lane_cover(C["dan"]))
    sw.put("ai_lane_cover", f_lane_cover(C["text2"]))
    sw.put("lane_score_cover", f_score_cover)
    sw.put("drum", f_drum)
    for k in ("don", "kat"):
        for s in ("l", "r"):
            sw.put(f"drum_{k}_{s}", f_drum_hit("don" if k == "don" else "kat", s))
    sw.put("auto_icon_en", f_auto("AUTO"))
    sw.put("auto_icon_ja", f_auto("オート"))
    sw.put("1p_icon", f_player_icon("1P", C["p1"]))
    sw.put("2p_icon", f_player_icon("2P", C["p2"]))
    sw.put("lane_difficulty", f_lane_diff)
    sw.put("score_number", f_digits(28, C["text"], weight=700, dy=4))
    for k, lab in MODS.items():
        sw.put(k, f_mod(lab))
    sw.put("timer", f_timer)
    return sw.write()


# ================================================================== hit effects / judgements
JUDGE = {"ja": {"good": "良", "ok": "可", "bad": "不可"}, "en": {"good": "GOOD", "ok": "OK", "bad": "BAD"}}


JUDGE_FILL = {"good": C["roll"], "ok": C["paper"], "bad": C["ka"]}


def f_judge(kind):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        s = JUDGE[LANG][kind]
        inktext(cv, w / 2, h / 2 + 1, s, 36 if LANG == "ja" else 26, JUDGE_FILL[kind], stroke=4.5, max_w=w - 8)
        return cv.result()
    return draw


def pring(cv, cx, cy, r, th, col, px=3):
    """Pixel ring: outer disc in `col`, inner disc erased."""
    pdisc(cv, cx, cy, r, col, px)
    pdisc(cv, cx, cy, max(0, r - th), (0, 0, 0, 0), px)


def f_flash(color, r):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        pring(cv, w / 2, h / 2, r + 3, 6, alpha(color, 240))
        pdisc(cv, w / 2, h / 2, r - 3, alpha(color, 90))
        return cv.result()
    return draw


def f_outer_ring(color, r0):
    def draw(i, n, w, h):
        t = i / max(1, n - 1)
        cv = Canvas(w, h)
        r = r0 + 34 * ease_out(t)
        th = max(3, round(6 - 3 * t))
        pring(cv, w / 2, h / 2, r, th, alpha(color, int(235 - 120 * t)))
        # 12 square pixels riding the ring
        sz = max(3, round(6 - 3 * t))
        pixel_burst(cv, w / 2, h / 2, r + 10, r + 10, 12, alpha(color, int(220 - 120 * t)), sz, t * 0.3)
        return cv.result()
    return draw


def f_rays(color, n_rays=16, r0=72, r1=100, w0=4.0):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        for k in range(n_rays):
            a = k / n_rays * math.tau
            c, s = math.cos(a), math.sin(a)
            for d in (r0, (r0 + r1) / 2, r1):
                x, y = round((w / 2 + c * d) / 3) * 3, round((h / 2 + s * d) / 3) * 3
                cv.rect(x - 3, y - 3, x + 3, y + 3, color)
        return cv.result()
    return draw


def f_particles(color, count=10, spread=0.42, seed=1):
    """Flat square pixels flying out and shrinking (used for several explosion sheets)."""
    rnd = random.Random(seed)
    parts = [(rnd.random() * math.tau, 0.55 + rnd.random() * 0.45, 2.5 + rnd.random() * 3.5) for _ in range(count)]

    def draw(i, n, w, h):
        t = i / max(1, n - 1)
        cv = Canvas(w, h)
        R = min(w, h) * spread
        for a, sp, sz in parts:
            d = R * ease_out(t) * sp
            s = sz * (1 - t * 0.85)
            if s > 0.6:
                x, y = round((w / 2 + math.cos(a) * d) / 3) * 3, round((h / 2 + math.sin(a) * d) / 3) * 3
                q = max(2, round(s)) * 1.5
                cv.rect(x - q, y - q, x + q, y + q, alpha(color, int(255 * (1 - t ** 2))))
        return cv.result()
    return draw


def f_rings(colors, max_r_frac=0.45):
    def draw(i, n, w, h):
        t = i / max(1, n - 1)
        cv = Canvas(w, h)
        R = min(w, h) * max_r_frac
        for j, col in enumerate(colors):
            tt = max(0.0, t - j * 0.12)
            r = R * ease_out(tt)
            if r < 4:
                continue
            th = max(3, round(6 * (1 - tt)))
            pring(cv, w / 2, h / 2, r + th / 2, th, alpha(col, int(255 * (1 - tt))))
        return cv.result()
    return draw


def build_hit_effect(out):
    sw = SubsetWriter(out, SCREEN, "hit_effect")
    for k in ("good", "ok", "bad"):
        sw.put(f"judge_{k}", f_judge(k))
    gold, white = C["roll"], C["paper"]
    sw.put("hit_effect_good", f_flash(gold, 44))
    sw.put("hit_effect_ok", f_flash(white, 44))
    sw.put("hit_effect_good_big", f_flash(gold, 60))
    sw.put("hit_effect_ok_big", f_flash(white, 60))
    sw.put("outer_good", f_outer_ring(gold, 52))
    sw.put("outer_ok", f_outer_ring(white, 52))
    sw.put("outer_good_big", f_outer_ring(gold, 66))
    sw.put("outer_ok_big", f_outer_ring(white, 66))
    sw.put("outer_effect_good", f_rays(alpha(gold, 230)))
    sw.put("outer_effect_ok", f_rays(alpha(white, 220)))
    sw.put("explosion", f_particles(gold, 14))
    sw.put("firework", f_rings([gold, C["don"], C["ka"]]))
    return sw.write()


# ================================================================== gauge
def gauge_geom(diff):
    """Measured from the parent's masks: the x where the clear zone steps up (unfilled) and
    where the base plate steps up (border)."""
    uf = f"1p_unfilled_{diff}.png"
    from .atlas import GREEN_G
    with Image.open(f"{GREEN_G}/game/gauge/{uf}") as im:
        a = im.convert("RGBA").getchannel("A")
        step = next(x for x in range(a.width) if a.getpixel((x, 16)) > 0)
    with Image.open(f"{GREEN_G}/game/gauge/border_{diff}.png") as im:
        a = im.convert("RGBA").getchannel("A")
        bstep = next(x for x in range(a.width) if a.getpixel((x, 3)) > 0)
    return step, bstep


def groove_mask(cv: Canvas, step, inset=0):
    """L mask of the gauge groove: low part x 8..step rows 38..60, clear part step..704 rows 16..60."""
    m, d = cv.mask()
    S = cv.ss
    d.rectangle([(8 + inset) * S, (38 + inset) * S, (step + 1) * S, (60 - inset) * S], fill=255)
    d.rectangle([(step - 0) * S, (16 + inset) * S, (704 - inset) * S, (60 - inset) * S], fill=255)
    return m


GAUGE_SEGS = 50   # the soul gauge is 50 steps wide


def f_unfilled(diff, pcol):
    step, _ = gauge_geom(diff)

    def draw(i, n, w, h):
        cv = Canvas(w, h, ss=2)
        # ink frame: stepped silhouette of the groove, 4 px thick
        cv.rect(4, 34, step + 6, 64, INK)
        cv.rect(step - 4, 12, 708, 64, INK)
        low = mix(C["bg3"], pcol, 0.14)
        cv.rect(8, 38, step + 1, 60, low)
        cv.rect(step, 16, 704, 60, mix(C["clear"], C["paper"], 0.72))
        # the clear threshold: an ink post where the groove steps up
        cv.rect(step - 1, 16, step + 2, 60, INK)
        return cv.result()
    return draw


def f_border(diff):
    _, bstep = gauge_geom(diff)

    def draw(i, n, w, h):
        cv = Canvas(w, h, ss=2)
        # a white 8-bit plate behind the gauge (ink edge top/left; the right/bottom run off the frame)
        xl = 138   # the plate starts just before the bar (the parent's runs on to the lane's left edge)
        cv.rect(xl, 22, w + 12, h + 12, INK)
        cv.rect(bstep, 0, w + 12, h + 12, INK)
        cv.rect(xl + 3, 25, w + 12, h + 12, C["paper"])
        cv.rect(bstep + 3, 3, w + 12, h + 12, C["paper"])
        return cv.result()
    return draw


def f_overlay(diff):
    step, _ = gauge_geom(diff)

    def draw(i, n, w, h):
        cv = Canvas(w, h, ss=1)
        g = groove_mask(cv, step)
        lines = Image.new("L", (w, h), 0)
        px = lines.load()
        for k in range(1, GAUGE_SEGS):
            x0 = int(round(8 + k * 696 / GAUGE_SEGS))
            for x in (x0, x0 + 1):
                for y in range(h):
                    px[x, y] = 255
        from PIL import ImageChops
        cv.paint(ImageChops.multiply(g, lines), alpha(INK, 190))
        return cv.result()
    return draw


def f_rainbow(diff):
    step, _ = gauge_geom(diff)

    def draw(i, n, w, h):
        cv = Canvas(w, h, ss=1)
        grad = Image.new("RGBA", (w, h))
        px = grad.load()
        for x in range(w):
            seg = int(max(0, x - 8) * GAUGE_SEGS / 696)   # one flat colour per step
            c = hue(seg / GAUGE_SEGS * 0.85 - i / n, s=0.55, v=1.0)
            for y in range(h):
                px[x, y] = c
        g = groove_mask(cv, step)
        out = blank(w, h)
        out.paste(grad, (0, 0), g)
        return out
    return draw


def f_solid_rows(color, y0, y1, x0=0, x1=None):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        cv.rect(x0, y0, x1 if x1 is not None else w, y1, color)
        return cv.result()
    return draw


def f_bar(color, y0=2, y1=24, x0=0, x1=None):
    """A gauge fill: flat colour with a 1-block white highlight on top."""
    def draw(i, n, w, h):
        cv = Canvas(w, h, ss=2)
        xe = x1 if x1 is not None else w
        cv.rect(x0, y0, xe, y1, color)
        cv.rect(x0, y0, xe, y0 + 4, alpha(C["paper"], 120))
        return cv.result()
    return draw


def f_glow(color):
    """Leading edge of a bar: a hard white block (8-bit: no blur)."""
    def draw(i, n, w, h):
        cv = Canvas(w, h, ss=2)
        cv.rect(6, 8, w - 6, h - 8, C["paper"])
        return cv.result()
    return draw


def f_clear_label(text, color, lit=True):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        pixbox(cv, 2, 2, w - 6, h - 6, fill=C["roll"] if lit else C["bg3"], border=INK, shadow=3, px=2)
        cv.text(w / 2 - 2, h / 2 - 1, text, 14, INK if lit else C["text2"], weight=900, max_w=w - 16,
                tracking=0.5 if text.isascii() else 0)
        return cv.result()
    return draw


def soul_shape(cv: Canvas, cx, cy, r, col, inner=None):
    """Soul icon: an 8-bit badge (ink border) with the character 魂 on it."""
    pbadge(cv, cx, cy, r - 3, col)
    if inner is not None:
        cv.text(cx, cy + 1, "魂", r * 1.05, inner, weight=900)


def f_soul(col, inner):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        soul_shape(cv, 36, 32, 25, col, inner)
        return cv.result()
    return draw


def f_soul_overlay(i, n, w, h):
    cv = Canvas(w, h)
    pdisc(cv, 36, 32, 25, alpha(C["paper"], 235))
    return cv.result()


def flame(cv: Canvas, cx, cy, size, col, sway):
    """A flat flame: teardrop body + tip, `sway` bends the tip (-1..1)."""
    m, d = cv.mask()
    S = cv.ss
    r = size
    d.ellipse([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], fill=255)
    tipx, tipy = cx + r * 0.9 + sway * r * 0.35, cy - r * 2.3
    d.polygon([((cx - r * 0.98) * S, (cy - r * 0.15) * S), (tipx * S, tipy * S),
               ((cx + r * 0.98) * S, (cy + r * 0.1) * S)], fill=255)
    cv.paint(m, col)


def f_soul_fire(i, n, w, h):
    # centre of the parent's flame body (frame-local), measured once
    # rainbow-gauge halo behind the soul: two flat discs that breathe frame by frame
    cx, cy = 85.0, 190.0
    cv = Canvas(w, h)
    k = 0.5 + 0.5 * math.sin(i / n * math.tau)
    pdisc(cv, cx, cy, 70 + 8 * k, alpha(C["gogo"], 90))
    pdisc(cv, cx, cy, 56 + 4 * k, alpha(C["roll"], 150))
    pring(cv, cx, cy, 78 + 8 * k, 6, alpha(C["roll"], 200))
    return cv.result()


def f_white_disk(r):
    def draw(i, n, w, h):
        cx, cy = SMALL[0], SMALL[1]
        cv = Canvas(w, h)
        pdisc(cv, cx, cy, r, (255, 255, 255, 255))
        return cv.result()
    return draw


def f_gauge_burst(i, n, w, h):
    """gauge/hit_effect: white, tinted by the engine. 0: dot, 1: bigger dot, 2: ring of dots."""
    cv = Canvas(w, h)
    c = (255, 255, 255, 255)
    if i == 0:
        pdisc(cv, w / 2, h / 2, 18, c)
    elif i == 1:
        pring(cv, w / 2, h / 2, 30, 9, c)
    else:
        pring(cv, w / 2, h / 2, 60, 6, c)
    return cv.result()


def build_gauge(out):
    sw = SubsetWriter(out, SCREEN, "gauge")
    for d in ("easy", "normal", "hard"):
        sw.put(f"border_{d}", f_border(d))
        sw.put(f"1p_unfilled_{d}", f_unfilled(d, C["p1"]))
        sw.put(f"2p_unfilled_{d}", f_unfilled(d, C["p2"]))
        sw.put(f"overlay_{d}", f_overlay(d))
        sw.put(f"rainbow_{d}", f_rainbow(d))
    sw.put("clear_en", f_clear_label("CLEAR", C["clear"]))
    sw.put("clear_ja", f_clear_label("クリア", C["clear"]))
    sw.put("clear_dark_en", f_clear_label("CLEAR", C["mute"], lit=False))
    sw.put("clear_dark_ja", f_clear_label("クリア", C["mute"], lit=False))
    sw.put("1p_bar", f_bar(C["p1"]))
    sw.put("2p_bar", f_bar(C["p2"]))
    sw.put("bar_clear_top", f_bar(C["clear"]))
    sw.put("bar_clear_bottom", f_bar(C["clear"]))
    sw.put("bar_clear_transition", f_bar(C["clear"], 4, 48, 0, 10))
    sw.put("1p_bar_fade", f_glow(C["paper"]))
    sw.put("2p_bar_fade", f_glow(C["paper"]))
    sw.put("bar_clear_fade", f_glow(C["paper"]))
    sw.put("bar_clear_transition_fade", f_glow(C["paper"]))
    sw.put("tamashii", f_soul(C["clear"], INK))
    sw.put("tamashii_dark", f_soul(C["bg3"], C["text2"]))
    sw.put("tamashii_overlay", f_soul_overlay)
    sw.put("tamashii_fire", f_soul_fire)
    sw.put("hit_effect_circle", f_white_disk(36))
    sw.put("hit_effect_circle_big", f_white_disk(54))
    sw.put("hit_effect", f_gauge_burst)
    return sw.write()


# ================================================================== combo
def f_label(text, size, color, weight=800, tracking=0.0):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        cv.text(w / 2, h / 2, text, size, color, weight=weight, max_w=w - 4, tracking=tracking,
                stroke=2, stroke_fill=C["paper"])
        return cv.result()
    return draw


def f_label_chip(text, size, fill, tracking=0.0):
    """The combo label on a solid chip (ink border, ink text): legible on both halves of the combo disc."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        pixbox(cv, 6, 6, w - 8, h - 6, fill=fill, border=INK, shadow=2, px=2)
        cv.text(w / 2 - 1, h / 2 - 0.5, text, size, INK, weight=900, max_w=w - 20, tracking=tracking)
        return cv.result()
    return draw


def f_digits_gold(size):
    """100+ combo: gold digits in an ink outline (gold is a fill colour only)."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        inktext(cv, w / 2, h / 2, str(i % 10), size, C["roll"], stroke=3.5)
        return cv.result()
    return draw


def f_announce_bg(color):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        pixbox(cv, 41, 22, 325, 106, fill=C["paper"], border=INK, shadow=5, px=3)
        cv.rect(44, 25, 322, 37, color)          # player colour band on top
        cv.rect(44, 37, 322, 40, INK)
        return cv.result()
    return draw


def f_announce_num(i, n, w, h):
    cv = Canvas(w, h)
    cv.text(w / 2, h / 2, f"{(i + 1) * 100}", 48, C["text"], weight=900, stroke=2, stroke_fill=C["paper"])
    return cv.result()


def f_gleam(i, n, w, h):
    """A four-armed pixel sparkle."""
    cv = Canvas(w, h)
    cx, cy = round(w / 2), round(h / 2)
    for col, k in ((INK, 3), (C["roll"], 0)):
        cv.rect(cx - 9 - k, cy - 3 - k, cx + 9 + k, cy + 3 + k, col)
        cv.rect(cx - 3 - k, cy - 9 - k, cx + 3 + k, cy + 9 + k, col)
    cv.rect(cx - 3, cy - 3, cx + 3, cy + 3, C["paper"])
    return cv.result()


def build_combo(out):
    sw = SubsetWriter(out, SCREEN, "combo")
    sw.put("counter", f_digits(44, C["text"], stroke=2.5, weight=900))
    sw.put("counter_100", f_digits_gold(44))
    # the label sits on the cream/blue disc: ink text on a solid chip (paper; gold from 100 combo)
    sw.put("combo_en", f_label_chip("COMBO", 12, PAPER, tracking=0.5))
    sw.put("combo_ja", f_label_chip("コンボ", 14, PAPER))
    sw.put("combo_100_en", f_label_chip("COMBO", 12, C["clear"], tracking=0.5))
    sw.put("combo_100_ja", f_label_chip("コンボ", 14, C["clear"]))
    sw.put_blank("gleam")   # no glimmer sweep: minimal motion
    sw.put("announce_bg_1p", f_announce_bg(C["p1"]))
    sw.put("announce_bg_2p", f_announce_bg(C["p2"]))
    sw.put("announce_text", f_label("コンボ" if LANG == "ja" else "COMBO", 20, C["text2"]))
    sw.put("announce_number", f_announce_num)
    sw.put("announce_add", f_digits(48, C["text"], weight=900))
    return sw.write()


# ================================================================== balloon / drumroll counters
def chunky(w, h, k, fn):
    """Draw at 1/k size without anti-aliasing, then scale up with nearest-neighbour: chunky pixel art
    for curves (arcs, rings)."""
    cv = Canvas(w // k + 1, h // k + 1, ss=1)
    fn(cv)
    return cv.result().resize((cv.w * k, cv.h * k), Image.NEAREST).crop((0, 0, w, h))


def f_bubble(w0, h0, body, tail_left=True, label=None, steps=3):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        x0, y0, x1, y1 = body
        tx = round((x0 + (x1 - x0) * 0.2) / 3) * 3
        # stepped tail pointing down-left toward the lane
        for k in range(steps):
            ya, yb = y1 - 3 + k * 6, y1 + 3 + k * 6
            cv.rect(tx - k * 6, ya, tx + 36 - k * 12, yb + 3, INK)
        pixbox(cv, x0, y0, x1, y1, fill=C["paper"], border=INK, shadow=4, px=3)
        for k in range(steps):
            ya, yb = y1 - 3 + k * 6, y1 + 3 + k * 6
            cv.rect(tx - k * 6 + 3, ya, tx + 33 - k * 12, yb, C["paper"])
        if label:
            cv.text((x0 + x1) / 2, y1 - 19, label, 18, C["gold_t"], weight=900)
        return cv.result()
    return draw


def f_pop(i, n, w, h):
    """balloon/pop: 0-5 inflate, 6 burst ring, 7 flash."""
    cv = Canvas(w, h)
    cx, cy = 140, 112
    if i <= 5:
        r = 16 + i * 9
        cv.rect(cx - r - 22, cy - 3, cx - r + 2, cy + 3, INK)
        note_disk(cv, cx, cy, r, mix(C["balloon"], C["roll"], i / 5), ring_w=3 + i * 0.4)
    elif i == 6:
        pring(cv, cx, cy, 72, 6, alpha(C["roll"], 235))
        pixel_burst(cv, cx, cy, 82, 82, 12, C["roll"], 9)
        pixel_burst(cv, cx, cy, 82, 82, 12, INK, 3)
    else:
        pring(cv, cx, cy, 88, 3, alpha(INK, 150))
    return cv.result()


def f_arc(i, n, w, h):
    cols = [C["don"], C["balloon"], C["roll"], C["normal"], C["ka"], C["ura"]]

    def fn(cv):
        k = 4
        cx, cy = w / 2 / k, (h + 120) / k
        for j, col in enumerate(cols):
            r = (440 - j * 16) / k
            cv.arc(cx, cy, r, 195, 345, alpha(col, 215), 3)
    return chunky(w, h, 4, fn)


def build_balloon(out):
    sw = SubsetWriter(out, SCREEN, "balloon")
    sw.put("bubble", f_bubble(176, 160, (6, 8, 170, 128)))
    sw.put("counter", f_digits(56, C["text"], weight=900, stroke=3, stroke_fill=C["paper"]))
    sw.put("pop", f_pop)
    sw.put("rainbow", f_arc)
    sw.put("explosion", f_particles(C["roll"], 16, seed=3))
    return sw.write()


def build_drumroll_counter(out):
    sw = SubsetWriter(out, SCREEN, "drumroll_counter")
    # a compact bubble (the number is centred on it) whose tail stops above the gauge plate
    sw.put("bubble", f_bubble(304, 188, (66, 10, 240, 142), label="連打" if LANG == "ja" else "ROLL", steps=2))
    sw.put("counter", f_digits(56, C["text"], weight=900, stroke=3, stroke_fill=C["paper"]))
    return sw.write()


# ================================================================== branch / gogo / song info
BRANCH = {"ja": {"normal": "普通譜面", "expert": "玄人譜面", "master": "達人譜面",
                 "level_up": "▲ レベルアップ", "level_down": "▼ レベルダウン"},
          "en": {"normal": "NORMAL", "expert": "EXPERT", "master": "MASTER",
                 "level_up": "▲ LEVEL UP", "level_down": "▼ LEVEL DOWN"}}


def f_branch_plate(kind):
    col = C["br_" + kind]

    def draw(i, n, w, h):
        cv = Canvas(w, h)
        pixbox(cv, 4, 6, w - 8, h - 10, fill=col, border=INK, shadow=3, px=3)
        inktext(cv, w / 2 - 2, h / 2 - 2, BRANCH[LANG][kind], 21, C["paper"], stroke=3, max_w=w - 34)
        return cv.result()
    return draw


def f_level(kind):
    col = C["normal"] if kind == "level_up" else C["hard"]

    def draw(i, n, w, h):
        cv = Canvas(w, h)
        pixbox(cv, 6, 8, w - 9, h - 12, fill=col, border=INK, shadow=3, px=3)
        inktext(cv, w / 2 - 1, h / 2 - 2, BRANCH[LANG][kind], 16, C["paper"], stroke=2.5, max_w=w - 34)
        return cv.result()
    return draw


def build_branch(out):
    sw = SubsetWriter(out, SCREEN, "branch")
    for k in ("normal", "expert", "master"):
        sw.put(k, f_branch_plate(k))
    sw.put("expert_bg", f_solid_rows(alpha(C["br_expert"], 70), 6, 136))
    sw.put("master_bg", f_solid_rows(alpha(C["br_master"], 70), 6, 136))
    sw.put("level_up", f_level("level_up"))
    sw.put("level_down", f_level("level_down"))
    return sw.write()


def f_gogo_lane(i, n, w, h):
    im = blank(w, h)
    px = im.load()
    c = C["gogo"]
    for x in range(w):
        t = x / (w - 1)
        a = int(70 + 40 * (1 - t))
        for y in range(h):
            px[x, y] = (c[0], c[1], c[2], a)
    return im


def f_gogo_fire(i, n, w, h):
    """Around the judge circle: a ring of short pixel flames that turns frame by frame."""
    cx, cy = 77.0, 197.0  # judge-circle centre inside the frame (lane x 413 - 336, y 73 + 124)
    cv = Canvas(w, h)
    rot = i / n * math.tau / 12
    for k in range(12):
        a = k / 12 * math.tau + rot - math.pi / 2
        reach = 92 + 8 * math.sin(i / n * math.tau * 2 + k)
        c, s_ = math.cos(a), math.sin(a)
        col = C["gogo"] if k % 2 == 0 else C["roll"]
        d = 66
        while d <= reach:
            x, y = round((cx + c * d) / 3) * 3, round((cy + s_ * d) / 3) * 3
            q = 6 if d < reach - 8 else 3
            cv.rect(x - q - 1.5, y - q - 1.5, x + q + 1.5, y + q + 1.5, alpha(INK, 200))
            cv.rect(x - q, y - q, x + q, y + q, alpha(col, 240))
            d += 9
    pring(cv, cx, cy, 63, 3, alpha(C["gogo"], 200))
    return cv.result()


def f_gogo_burst(i, n, w, h):
    """gogo start: a pixel streak rising from the bottom then bursting into squares."""
    cv = Canvas(w, h)
    t = i / max(1, n - 1)
    cx = round(w / 2)
    top = h * 0.85 - h * 0.6 * ease_out(min(1.0, t * 2.2))
    if t < 0.45:
        wd = max(3, round(9 * (1 - t) / 3) * 3 // 2 * 2)
        cv.rect(cx - wd / 2 - 3, top, cx + wd / 2 + 3, h * 0.92, INK)
        cv.rect(cx - wd / 2, top, cx + wd / 2, h * 0.92, alpha(C["roll"], 235))
        cv.rect(cx - 9, top - 9, cx + 9, top + 9, INK)
        cv.rect(cx - 6, top - 6, cx + 6, top + 6, C["paper"])
    else:
        tt = (t - 0.45) / 0.55
        for k in range(14):
            a = k / 14 * math.tau
            d = 20 + 90 * ease_out(tt)
            x, y = round((cx + math.cos(a) * d) / 3) * 3, round((top + math.sin(a) * d) / 3) * 3
            q = max(1.5, 7 * (1 - tt))
            col = alpha(C["gogo"] if k % 2 else C["roll"], int(255 * (1 - tt)))
            cv.rect(x - q, y - q, x + q, y + q, col)
    return cv.result()


def build_gogo(out):
    sw = SubsetWriter(out, SCREEN, "gogo_time")
    sw.put("lane_effect", f_gogo_lane)
    sw.put("fire", f_gogo_fire)
    sw.put("explosion", f_gogo_burst)
    return sw.write()


GENRE_TEMPLATE = (60, 103, 0, 255)   # the engine's colour-transform source: replaced by the genre colour


def f_genre(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 1, 1, w - 4, h - 4, fill=GENRE_TEMPLATE, border=INK, shadow=3, px=3)
    return cv.result()


def build_song_info(out):
    sw = SubsetWriter(out, SCREEN, "song_info")
    sw.put("genre", f_genre)
    return sw.write()


# ================================================================== ending (clear / FC / fail)
END_TEXT = {"ja": {"clear": "クリア成功", "fail": "クリア失敗", "fc": "フルコンボ!!"},
            "en": {"clear": "CLEAR", "fail": "FAILED", "fc": "FULL COMBO!"}}


def f_end_text(kind, highlight=False, chars=None):
    col = {"clear": C["roll"], "fail": C["ka"], "fc": C["roll"]}[kind]

    def draw(i, n, w, h):
        cv = Canvas(w, h)
        s_ = END_TEXT[LANG][kind] if chars is None else chars[i]
        fill = C["paper"] if highlight else col
        cv.text(w / 2 + 3, h / 2 + 4, s_, h * 0.66, INK, weight=900, stroke=5, stroke_fill=INK, max_w=w - 12)   # hard drop shadow
        cv.text(w / 2, h / 2, s_, h * 0.66, fill, weight=900, stroke=5, stroke_fill=INK, max_w=w - 12)
        return cv.result()
    return draw


def f_end_overlay(i, n, w, h):
    cv = Canvas(w, h)
    cv.text(w / 2, h / 2, END_TEXT[LANG]["fc"], h * 0.66, alpha(C["roll"], 200), weight=900, stroke=9,
            stroke_fill=alpha(C["roll"], 200), max_w=w - 12)
    return cv.result()


def f_confetti(i, n, w, h):
    cols = [C["don"], C["ka"], C["roll"], C["normal"], C["oni"]]
    cv = Canvas(w, h)
    if n == 1 and w > h * 2:  # a strip of 5 pieces
        k = 5
        for j in range(k):
            x0 = j * w / k
            cv.rect(x0 + w / k * 0.25 - 1, h * 0.2 - 1, x0 + w / k * 0.75 + 1, h * 0.8 + 1, INK)
            cv.rect(x0 + w / k * 0.25, h * 0.2, x0 + w / k * 0.75, h * 0.8, cols[j])
    else:
        cv.rect(w * 0.25 - 1, h * 0.2 - 1, w * 0.75 + 1, h * 0.8 + 1, INK)
        cv.rect(w * 0.25, h * 0.2, w * 0.75, h * 0.8, cols[i % len(cols)])
    return cv.result()


def build_ending(out):
    sw = SubsetWriter(out, SCREEN, "ending_anim")
    for k in ("bachio_l_in", "bachio_r_in", "bachio_l_fall", "bachio_r_fall", "bachio_l_out", "bachio_r_out",
              "bachio_boom", "fan_l", "fan_r"):
        sw.put_blank(k)
    sw.put("clear", f_end_text("clear"))
    sw.put("clear_highlight", f_end_text("clear", True))
    chars = list(END_TEXT[LANG]["clear"]) if LANG == "ja" else ["C", "L", "E", "A", "R"]
    sw.put("clear_separated", f_end_text("clear", False, chars))
    sw.put("clear_separated_highlight", f_end_text("clear", True, chars))
    sw.put("fail", f_end_text("fail"))
    sw.put("full_combo", f_end_text("fc"))
    sw.put("full_combo_highlight", f_end_text("fc", True))
    sw.put("full_combo_overlay", f_end_overlay)
    sw.put("sparkle", f_gleam)
    sw.put("confetti", f_confetti)
    return sw.write()


def build_hoshi(out):
    """Hoshi (the husky buddy) for the lower half of the play screen: 102 px = 34 cells x 3 px."""
    from .atlas import OwnSubset
    from . import mascot
    sub = OwnSubset(out, SCREEN, "ss_hoshi")
    sub.add("body", [mascot.sized(mascot.BUDDY, e, 102) for e in mascot.EXPR])
    return sub.write()


def build_all(out_graphics):
    counts = {}
    for name, fn in [("notes", build_notes), ("lane", build_lane), ("hit_effect", build_hit_effect),
                     ("gauge", build_gauge), ("combo", build_combo), ("balloon", build_balloon),
                     ("drumroll_counter", build_drumroll_counter), ("branch", build_branch),
                     ("gogo_time", build_gogo), ("song_info", build_song_info), ("ending_anim", build_ending)]:
        counts[name] = fn(out_graphics)
    counts.update(game_rest.build_all(out_graphics))
    counts["ss_hoshi"] = build_hoshi(out_graphics)
    return counts


# ------------------------------------------------------------------ module contract (build.py)
from .luapatch import GAME_LUA_PATCHES  # noqa: E402

LUA_PATCHES = {**GAME_LUA_PATCHES, **game_rest.LUA_PATCHES}

NAME = "game"
OWNS = ["Graphics/game", "Scripts/background", "Scripts/game"]


def configure(ctx):
    global LANG
    LANG = ctx.lang
    game_rest.set_lang(ctx.lang)


def build(ctx):
    return sum(build_all(ctx.G).values())
