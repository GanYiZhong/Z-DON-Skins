"""Dan result textures (Graphics/dan_result), part of module "result". Light 8-bit look: ink-bordered
pixboxes with hard shadows, pixbar gauge, pixel mascots (Momo + Hoshi) on the promotion overlay."""
from __future__ import annotations

from PIL import Image

from . import mascot
from .atlas import SubsetWriter
from .result import (GOLD, INK, PAPER, STAR, TXT, chip, cloud, digit_set, f_bar, f_cap, f_flat,
                     f_soul, f_soul_fire, label_box, pgrid, pglyph, sparkle)
from .style import C, COURSES, Canvas, alpha, blank, hexc, hue, mix, pixbox

SCREEN = "dan_result"
GENRE = [C["ka"], C["balloon"], C["text2"], C["oni"], C["normal"], C["roll"], C["ura"], C["gogo"]]


# ====================================================================== background
def f_bg4(i, n, w, h):
    cv = Canvas(w, h)
    cv.rect(0, 0, w, h, C["bg0"])
    cv.rect(0, 360, w, 460, C["sky"])                 # sky band behind the header (screen y 0..100)
    for j, y in enumerate(range(460, 472, 4)):
        if j < 2:
            for x in range(0, w, 8):
                xs = x + (4 if j % 2 else 0)
                cv.rect(xs, y, xs + 4, y + 4, C["sky"])
    # no ink seam at screen y 357..363 (the tile is drawn twice, half a screen apart): it ran behind
    # the panels as an orphan rule
    return cv.result()


def f_footer4(i, n, w, h):
    cv = Canvas(w, h)
    cv.rect(0, 0, w, 72, INK)
    cv.rect(0, 0, w, 6, C["dan"])
    cv.rect(0, 6, w, 9, PAPER)
    cv.rect(0, 72, w, 144, C["sky"])
    cloud(cv, 112, 84, 4)
    cloud(cv, 166, 112, 3)
    return cv.result()


def f_result_text(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 6, 4, w - 12, 62, fill=PAPER, shadow=4, px=3)
    cv.rect(9, 7, 57, 59, C["dan"])
    pgrid(cv, 21, 23, STAR, 5, {"#": INK})
    cv.text(72, 34, "段位道場　結果発表", 36, TXT, anchor="lm", max_w=w - 100)
    return cv.result()


def f_genre(i, n, w, h):
    col = GENRE[i % len(GENRE)]
    cv = Canvas(w, h)
    pixbox(cv, 0, 12, w - 8, 184, fill=PAPER, shadow=4, px=3)
    cv.rect(3, 15, 27, 181, col)
    cv.rect(27, 15, 30, 181, INK)
    for x in range(44, w - 40, 12):
        cv.rect(x, 99, x + 6, 101, C["line"])
    return cv.result()


def f_2_bg(i, n, w, h):
    cv = Canvas(w, h)
    cv.rect(0, 0, w, h, C["bg0"])
    cv.rect(0, 0, w, 3, INK)
    cv.rect(0, h - 3, w, h, INK)
    return cv.result()


def f_divider(i, n, w, h):
    cv = Canvas(w, h)
    for x in range(0, w, 12):
        cv.rect(x, 19, x + 6, 21, C["line"])
    return cv.result()


def f_pullout(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 8, 2, 64, h - 8, fill=C["bg3"], shadow=4, px=3)
    cv.rect(30, 24, 42, h - 24, mix(C["dan"], C["bg3"], 0.2))
    return cv.result()


def build_background(out):
    w = SubsetWriter(out, SCREEN, "background")
    w.put("background_4p", f_bg4)
    w.put("footer_4p", f_footer4)
    w.put("result_text", f_result_text)
    w.put("genre_banner", f_genre)
    w.put("result_2_bg", f_2_bg)
    w.put("result_2_divider", f_divider)
    w.put("result_2_pullout", f_pullout)
    return w.write()


# ====================================================================== congrats / shoudan
def f_plate(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 16, 30, w - 28, h - 36, fill=C["dan"], shadow=8, px=6)
    cv.rect(30, 44, w - 42, 48, PAPER)
    cv.rect(30, h - 54, w - 42, h - 50, PAPER)
    cv.text(w / 2 - 6, h / 2 - 2, "達人", 120, INK, max_w=w - 120)
    return cv.result()


def f_panel(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 0, 0, w - 10, h - 10, fill=PAPER, shadow=8, px=6)
    pixbox(cv, 20, 20, 330, 74, fill=C["dan"], shadow=4, px=3)
    cv.text(175, 48, "昇段だ!", 36, INK)
    return cv.result()


def f_glow(i, n, w, h):
    """A rim of gold checkers around the panel (no blur)."""
    cv = Canvas(w, h)
    for y in range(0, h, 12):
        for x in range(((y // 12) % 2) * 12, w, 24):
            cv.rect(x, y, x + 12, y + 12, alpha(C["dan"], 255))
    im = cv.result()
    im.paste((0, 0, 0, 0), (48, 48, w - 48, h - 48))
    return im


def f_fire_small(i, n, w, h):
    """Spark ring around the soul icon, tighter than the single-player one so it never reaches the
    result digits just below the gauge."""
    import math
    cx, cy = 85.0, 190.0
    cv = Canvas(w, h)
    k = i / n
    for j in range(12):
        a = (j / 12 + k / 12) * math.tau
        r = 44 + (4 if j % 2 == i % 2 else 0)
        x, y = int(cx + math.cos(a) * r) // 3 * 3, int(cy + math.sin(a) * r) // 3 * 3
        s = 6 if j % 2 == i % 2 else 3
        cv.rect(x - s // 2 - 2, y - s // 2 - 2, x + s // 2 + 5, y + s // 2 + 5, INK)
        cv.rect(x - s // 2, y - s // 2, x + s // 2 + 3, y + s // 2 + 3, GOLD)
    return cv.result()


def f_spark(i, n, w, h):
    cv = Canvas(w, h)
    sparkle(cv, w / 2 - 2 + 4, h / 2 - 2 + 4, 4, INK)
    sparkle(cv, w / 2 - 2, h / 2 - 2, 4, GOLD)
    return cv.result()


# the promotion popups' mascots: 34 cells x 7 px, feet on the frame's bottom edge, centred; the Lua patch
# in result.py (_SS_POPUP_MASCOTS) puts the frame's bottom centre on an ink floor line
POPUP_MASCOT = 238


def f_mascot(concept, expr):
    def draw(i, n, w, h):
        im = mascot.sized(concept, expr, POPUP_MASCOT)   # whole-pixel scale
        out = blank(w, h)
        # the lowest opaque row (some poses keep a 1-cell margin under the feet) lands on the bottom edge
        out.alpha_composite(im, ((w - im.width) // 2, h - im.getchannel("A").getbbox()[3]))
        return out
    return draw


def f_drum(col):
    """A short drum in the frame's top 90 px: the Lua parks the frame at screen y 557, so the whole drum
    sits above the engine's bottom bar (y 648) instead of running off the screen."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        pixbox(cv, 6, 30, w - 14, 84, fill=col, shadow=6, px=6)
        pixbox(cv, 6, 4, w - 14, 42, fill=PAPER, shadow=0, px=6)
        cv.rect(20, 20, w - 28, 26, C["bg3"])
        for x in range(36, w - 40, 60):                       # pixel studs on the body
            cv.rect(x, 56, x + 6, 62, INK)
        return cv.result()
    return draw


GLYPHS = "一二三四五六七八九十初級段玄名超達人"


def f_glyph(i, n, w, h):
    cv = Canvas(w, h)
    cv.text(w / 2, h / 2 + 4, GLYPHS[i], 192, GOLD, stroke=9, stroke_fill=INK)
    return cv.result()


def build_overlays(out):
    n = 0
    w = SubsetWriter(out, SCREEN, "congrats")
    w.put("plate", f_plate)
    n += w.write()
    w = SubsetWriter(out, SCREEN, "shoudan")
    w.put("panel", f_panel)
    w.put("glow", f_glow)
    w.put("spark", f_spark)
    w.put("mascot_a", f_mascot(mascot.MAIN, "clear"))
    w.put("mascot_b", f_mascot(mascot.BUDDY, "good"))
    w.put("drum_red", f_drum(C["don"]))
    w.put("drum_blue", f_drum(C["ka"]))
    w.put("glyph", f_glyph)
    n += w.write()
    return n


# ====================================================================== result info
def f_diff_pill(i, n, w, h):
    col = C[COURSES[i][0]]
    cv = Canvas(w, h)
    pixbox(cv, 0, 4, w - 7, 40, fill=col, shadow=4, px=3)
    pglyph(cv, 30, 22, i, PAPER if i == 4 else INK, u=6, k=0.45)
    return cv.result()


def f_songnum(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 2, 6, w - 8, 56, fill=GOLD, shadow=4, px=3)
    cv.text(w / 2 - 3, 31, f"{i + 1}曲目", 36, INK, max_w=w - 28)
    return cv.result()


def f_emblem(i, n, w, h):
    cols = ["#A67C52", "#C9763D", "#4A5368", "#D9483B", "#6F7FA3", "#B8841A", "#7A6A4F"]
    cv = Canvas(w, h)
    pixbox(cv, 4, 4, w - 12, h - 12, fill=hexc(cols[i % 7]), shadow=6, px=4)
    cv.rect(14, 14, w - 22, 17, alpha(PAPER, 170))
    cv.rect(14, h - 25, w - 22, h - 22, alpha(PAPER, 170))
    return cv.result()


def f_exam_header(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 0, 4, w - 6, h - 10, fill=C["dan"], shadow=4, px=3)
    cv.text((w - 6) / 2, h / 2 - 3, "達成条件", 24, INK)
    return cv.result()


def f_score_box(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 0, 0, w - 6, h - 8, fill=C["bg0"], shadow=4, px=3)
    cv.text(w - 30, h / 2 - 3, "点", 24, INK)
    return cv.result()


def f_star(ch, size):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        if ch == "★":
            pgrid(cv, w / 2 - 7, h / 2 - 7, STAR, 3, {"#": INK})
        else:
            cv.text(w / 2, h / 2 + 1, ch, size, INK)
        return cv.result()
    return draw


def build_info(out, R=None):
    w = SubsetWriter(out, SCREEN, "result_info")
    w.put("song_num", f_songnum)
    w.put("difficulty", f_diff_pill)
    w.put("diff_star", f_star("★", 24))
    w.put("diff_x", f_star("×", 24))
    w.put("diff_num", digit_set(24, TXT, dy=0.5))
    w.put("good", chip("良", GOLD, w_chip=54))
    w.put("ok", chip("可", C["mint"], w_chip=54))
    w.put("bad", chip("不可", C["sky"], w_chip=54))
    w.put("drumroll", label_box("連打数", 24, INK))
    w.put("max_combo", label_box("最大コンボ", 24, INK))
    w.put("max_hits", label_box("叩けた数", 24, INK))
    w.put("exam_header", f_exam_header)
    w.put("score_box", f_score_box)
    w.put("score_counter", digit_set(36, TXT, dy=0.5, shadow=C["bg3"]))
    w.put("counter", digit_set(24, TXT))
    # moved left from Green's x 99 so the plate no longer covers the first "1曲目" tab (the Lua patch
    # moves the dan name with it: result.EMBLEM_X)
    w.put("dan_emblem", f_emblem, entry={"x": R["EMBLEM_X"] if R else 20, "y": 98})
    return w.write()


# ====================================================================== exam rows
STROKE = dict(stroke=2, stroke_fill=alpha(PAPER, 255))


def f_row_under(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 0, 0, w - 6, h - 6, fill=PAPER, shadow=4, px=3)
    cv.rect(12, 10, w - 18, h - 16, INK)
    cv.rect(14, 12, w - 20, h - 18, C["bg3"])
    return cv.result()


def f_row_over(i, n, w, h):
    return blank(w, h)


def f_label_stroke(text, size=24, align="l"):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        x = 4 if align == "l" else w - 4
        cv.text(x, h / 2 + 1, text, size, TXT, anchor="lm" if align == "l" else "rm", max_w=w - 8, **STROKE)
        return cv.result()
    return draw


def f_failed(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 0, 6, w - 6, h - 10, fill=PAPER, shadow=4, px=3)
    cv.text((w - 6) / 2, h / 2 - 2, "達成失敗", 36, C["red_t"])
    return cv.result()


def stamp(text, col, band=None):
    """A square pixel stamp: ink frame, inner frame in `col`, big text in `col` (never rotated).
    `band`: a fill colour for a wider inner frame (ink-edged), so gold and red passes read apart at a glance."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        # top edge 16 px lower than the frame allows, so the stamp clears the dan plate above it
        pixbox(cv, 30, 56, w - 40, h - 48, fill=PAPER, shadow=10, px=9)
        if band is not None:
            cv.rect(45, 71, w - 55, h - 63, INK)
            cv.rect(48, 74, w - 58, h - 66, band)
            cv.rect(57, 83, w - 67, h - 75, INK)
            cv.rect(60, 86, w - 70, h - 78, PAPER)
        else:
            for (a, b, c, d) in ((48, 74, w - 58, 79), (48, h - 71, w - 58, h - 66), (48, 74, 53, h - 66),
                                 (w - 63, 74, w - 58, h - 66)):
                cv.rect(a, b, c, d, col)
        cv.text(w / 2 - 5, h / 2 + 4, text, 108 if len(text) == 2 else 84, col, max_w=w - 170)
        return cv.result()
    return draw


def _stroke_digits(size):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        cv.text(w / 2, h * 0.54, str(i), size, TXT, **STROKE)
        return cv.result()
    return draw


def build_exam(out):
    w = SubsetWriter(out, SCREEN, "exam_info")
    w.put("exam_bg", f_flat(C["bg3"]))
    w.put("exam_overlay_1", f_row_under)
    w.put("exam_overlay_2", f_row_over)
    w.put("exam_max", f_bar(C["ka"], 0, 72))
    w.put("exam_gold", f_bar(GOLD, 0, 72))
    w.put("exam_red", f_bar(C["don"], 0, 72))
    w.put("exam_failed", f_failed)
    for k, t in (("exam_combo", "コンボ数"), ("exam_drumroll", "連打数"), ("exam_gauge", "魂ゲージ"),
                 ("exam_hit", "叩けた数"), ("exam_judgebad", "不可の数"), ("exam_judgegood", "可の数"),
                 ("exam_judgeperfect", "良の数"), ("exam_score", "スコア")):
        w.put(k, f_label_stroke(t))
    w.put("exam_combo_text", f_label_stroke("コンボ", 24))
    w.put("exam_less", f_label_stroke("未満", 24, "r"))
    w.put("exam_more", f_label_stroke("以上", 24, "r"))
    w.put("exam_percent", f_label_stroke("%", 24))
    w.put("exam_unit_hit", f_label_stroke("打", 24))
    w.put("exam_unit_score", f_label_stroke("点", 24))
    w.put("value_counter", _stroke_digits(36))
    w.put("fail", stamp("不合格", C["blue_t"]))
    w.put("gold_clear", stamp("合格", C["gold_t"], band=GOLD))
    w.put("red_clear", stamp("合格", C["red_t"], band=C["don"]))
    return w.write()


# ====================================================================== dan gauge (exam % bar)
def f_dan_unfilled(pcol):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        cv.rect(5, 25, 707, 55, INK)
        cv.rect(8, 28, 704, 52, mix(pcol, PAPER, 0.78))
        return cv.result()
    return draw


def f_dan_overlay(i, n, w, h):
    cv = Canvas(w, h, ss=1)
    lines = Image.new("L", (w, h), 0)
    px = lines.load()
    for x in range(8, 704):
        if (x - 8) % 8 >= 6:
            for y in range(28, 52):
                px[x, y] = 255
    cv.paint(lines, alpha(INK, 70))
    return cv.result()


def f_dan_rainbow(i, n, w, h):
    out = blank(w, h)
    grad = Image.new("RGBA", (w, h))
    px = grad.load()
    for x in range(w):
        c = hue((x // 16) * 16 / 700 * 0.85 - i / n, s=0.50, v=1.0)
        for y in range(h):
            px[x, y] = c
    m = Image.new("L", (w, h), 0)
    m.paste(255, (8, 4, 704, 28))
    out.paste(grad, (0, 0), m)
    return out


def build_gauge(out):
    w = SubsetWriter(out, SCREEN, "gauge")
    w.put("1p_unfilled", f_dan_unfilled(C["p1"]))
    w.put("2p_unfilled", f_dan_unfilled(C["p2"]))
    w.put("1p_bar", f_bar(C["p1"], 0, 24))
    w.put("2p_bar", f_bar(C["p2"], 0, 24))
    w.put("overlay", f_dan_overlay)
    w.put("rainbow", f_dan_rainbow)
    w.put("footer", f_cap)
    w.put("tamashii", f_soul(GOLD, INK))
    w.put("tamashii_dark", f_soul(C["bg3"], C["mute"]))
    w.put("tamashii_overlay", f_flat((0, 0, 0, 0)))   # the dan screen draws it at full alpha
    w.put("tamashii_fire", f_fire_small)
    return w.write()


def build(ctx, R=None):
    out = ctx.G
    n = 0
    n += build_background(out)
    n += build_overlays(out)
    n += build_info(out, R)
    n += build_exam(out)
    n += build_gauge(out)
    return n
