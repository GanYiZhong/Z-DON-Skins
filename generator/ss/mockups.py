"""Static direction mockups (PIL composites) for screens not yet built: song select, result.
Also the palette / component swatch sheet. Uses the same drawing helpers and the real
enso note art from the built skin so everything reads as one system."""
from __future__ import annotations

import math
import os

from PIL import Image

from .style import C, Canvas, alpha, blank, mix, P, font
from . import game

W, H = 1280, 720


def vtext(cv: Canvas, x, y_top, s, size, fill, weight=800, max_h=None, gap=0.0):
    """Vertical (top-to-bottom) text centred on x, one glyph per row."""
    step = size * (1.04 + gap)
    if max_h and step * len(s) > max_h:
        step = max_h / len(s)
        size = min(size, step / 1.04)
    for k, ch in enumerate(s):
        if ch in "ーー":
            cv.rect(x - 1.5, y_top + k * step + step * 0.2, x + 1.5, y_top + k * step + step * 0.8, fill)
            continue
        cv.text(x, y_top + k * step + step / 2, ch, size, fill, weight=weight)


GENRES = [("ポップス", "#4FB0E8"), ("アニメ", "#FF8A3D"), ("ボーカロイド", "#3FC4B4"),
          ("どうよう", "#FFC23D"), ("バラエティ", "#7BD389"), ("クラシック", "#C9A15A"),
          ("ゲームミュージック", "#9B6BF2"), ("ナムコオリジナル", "#FF5A4E")]

SONGS = [
    ("夜明けのパレード", "ポップス", 0), ("Flat Horizon", "ポップス", 0), ("ひだまりスケッチ", "アニメ", 1),
    ("星屑ランナー", "アニメ", 1), ("Signal Lights", "ボーカロイド", 2), ("さくら坂", "どうよう", 3),
    ("Prism Engine", "バラエティ", 4), ("交響のかけら", "クラシック", 5), ("8-bit Comet", "ゲームミュージック", 6),
    ("太鼓の朝", "ナムコオリジナル", 7),
]


def header(cv, title, sub):
    cv.rect(0, 0, W, 64, C["bg1"])
    cv.rect(0, 64, W, 66, C["line"])
    cv.rect(0, 0, 8, 64, C["p1"])
    cv.text(32, 33, title, 28, C["text"], weight=900, anchor="lm")
    cv.text(32 + cv.text_width(title, 28, 900) + 16, 35, sub, 15, C["text2"], weight=700, anchor="lm",
            tracking=2)


def footer(cv, hints):
    cv.rect(0, H - 52, W, H, C["bg1"])
    cv.rect(0, H - 54, W, H - 52, C["line"])
    # nameplate pill
    cv.capsule(20, H - 44, 300, H - 8, C["bg2"])
    cv.circle(38, H - 26, 12, fill=C["p1"])
    cv.text(38, H - 25, "1P", 10, C["bg0"], weight=900)
    cv.text(58, H - 32, "どんちゃん", 15, C["text"], weight=800, anchor="lm")
    cv.text(58, H - 15, "Donder Debut!", 10, C["text2"], weight=700, anchor="lm")
    x = W - 24
    for key, lab in reversed(hints):
        tw = cv.text_width(lab, 14, 700)
        cv.text(x, H - 26, lab, 14, C["text2"], weight=700, anchor="rm")
        x -= tw + 8
        kw = max(26, cv.text_width(key, 12, 900) + 14)
        cv.rrect(x - kw, H - 38, x, H - 14, 6, fill=C["bg3"])
        cv.text(x - kw / 2, H - 25, key, 12, C["text"], weight=900)
        x -= kw + 22


def diff_row(cv, x, y, w, i, level, crown=None, selected=False):
    key = game.DIFFS[i][0]
    name = {"easy": "かんたん", "normal": "ふつう", "hard": "むずかしい", "oni": "おに", "ura": "おに裏"}[key]
    if selected:
        cv.rrect(x - 4, y - 4, x + w + 4, y + 56, 14, fill=None, outline=C[key], width=3)
    cv.rrect(x, y, x + w, y + 52, 10, fill=C["bg2"])
    cv.circle(x + 28, y + 26, 17, fill=C[key])
    game.diff_glyph(cv, x + 28, y + 26, 17, i)
    cv.text(x + 56, y + 26, name, 18, C["text"], weight=800, anchor="lm")
    # level as 10 pips
    for k in range(10):
        px = x + 170 + k * 15
        cv.circle(px, y + 26, 5, fill=C[key] if k < level else C["bg3"])
    cv.text(x + w - 54, y + 27, f"★{level}", 15, C["text2"], weight=800, anchor="rm")
    if crown:
        col = {"clear": C["text2"], "fc": C["good"], "dfc": C["ka"]}[crown]
        cx, cy = x + w - 26, y + 26
        cv.poly([(cx - 12, cy + 8), (cx - 12, cy - 6), (cx - 6, cy), (cx, cy - 10), (cx + 6, cy),
                 (cx + 12, cy - 6), (cx + 12, cy + 8)], col)


def song_select():
    cv = Canvas(W, H, bg=C["bg0"])
    header(cv, "曲をえらぶ", "SONG SELECT")
    # genre filter chips
    x = 32
    for g, hc in GENRES[:6]:
        tw = cv.text_width(g, 14, 800) + 28
        sel = g == "アニメ"
        chip = tuple(int(hc.lstrip("#")[j:j + 2], 16) for j in (0, 2, 4)) + (255,)
        cv.capsule(x, 82, x + tw, 112, chip if sel else C["bg2"])
        cv.text(x + tw / 2, 97, g, 14, C["bg0"] if sel else C["text2"], weight=800)
        x += tw + 10
    # song cards: a horizontal strip of tall cards; the selected one opens into a panel
    sel_idx = 3
    cw, gap, top, bot = 64, 10, 132, 600
    cards_x0 = 40
    x = cards_x0
    for k, (title, genre, gi) in enumerate(SONGS):
        hc = tuple(int(GENRES[gi][1].lstrip("#")[j:j + 2], 16) for j in (0, 2, 4)) + (255,)
        if k == sel_idx:
            pw = 520
            cv.rrect(x, top, x + pw, bot, 18, fill=C["bg1"])
            cv.rrect(x, top, x + pw, top + 10, 5, fill=hc)
            cv.rect(x, top + 5, x + pw, top + 10, hc)
            cv.text(x + 28, top + 44, genre, 14, hc, weight=800, anchor="lm", tracking=1)
            cv.text(x + 28, top + 80, title, 34, C["text"], weight=900, anchor="lm")
            cv.text(x + 28, top + 114, "Sample Artist  ·  BPM 172", 15, C["text2"], weight=700, anchor="lm")
            levels = [3, 5, 7, 9]
            crowns = ["fc", "fc", "clear", None]
            for j in range(4):
                diff_row(cv, x + 24, top + 150 + j * 66, pw - 48, j, levels[j], crowns[j], selected=(j == 3))
            cv.text(x + 28, bot - 40, "ハイスコア  1,004,320", 16, C["text2"], weight=800, anchor="lm")
            x += pw + gap
            continue
        dist = abs(k - sel_idx)
        cv.rrect(x, top + 18, x + cw, bot - 18, 14, fill=C["bg1"])
        cv.rrect(x, top + 18, x + cw, top + 26, 4, fill=hc)
        cv.rect(x, top + 22, x + cw, top + 26, hc)
        vtext(cv, x + cw / 2, top + 44, title, 22, C["text"] if dist <= 2 else C["text2"], max_h=bot - top - 120)
        cv.circle(x + cw / 2, bot - 44, 10, fill=alpha(hc, 255))
        x += cw + gap
    # scroll hint arrows
    cv.text(18, (top + bot) / 2, "‹", 40, C["mute"], weight=400)
    cv.text(W - 18, (top + bot) / 2, "›", 40, C["mute"], weight=400)
    footer(cv, [("F/J", "決定"), ("D/K", "選択"), ("ESC", "もどる")])
    return cv.result()


def result():
    cv = Canvas(W, H, bg=C["bg0"])
    header(cv, "成績発表", "RESULT")
    cv.text(W - 32, 33, "夜明けのパレード", 22, C["text"], weight=900, anchor="rm")
    # main panel
    x0, y0, x1, y1 = 40, 92, 840, 520
    cv.rrect(x0, y0, x1, y1, 20, fill=C["bg1"])
    cv.rect(x0, y0 + 20, x0 + 6, y1 - 20, C["p1"])
    # difficulty + crown
    cv.circle(x0 + 64, y0 + 62, 26, fill=C["oni"])
    game.diff_glyph(cv, x0 + 64, y0 + 62, 26, 3)
    cv.text(x0 + 104, y0 + 52, "おに", 22, C["text"], weight=900, anchor="lm")
    cv.text(x0 + 104, y0 + 78, "★ 9", 15, C["text2"], weight=800, anchor="lm")
    # gauge
    gx0, gx1, gy = x0 + 220, x1 - 40, y0 + 52
    cv.rrect(gx0, gy, gx1, gy + 22, 6, fill=C["bg0"])
    clear_x = gx0 + (gx1 - gx0) * 0.8
    cv.rect(gx0 + 4, gy + 4, gx1 - 4, gy + 18, mix(C["p1"], C["bg0"], 0.8))
    cv.rect(gx0 + 4, gy + 4, clear_x, gy + 18, C["p1"])
    cv.rect(clear_x, gy + 4, gx1 - 70, gy + 18, C["clear"])
    for k in range(int((gx1 - gx0 - 8) / 8)):
        cv.rect(gx0 + 4 + k * 8 + 7, gy + 4, gx0 + 4 + k * 8 + 8, gy + 18, alpha(C["bg0"], 60))
    cv.text(clear_x + 4, gy + 34, "クリア", 12, C["clear"], weight=800, anchor="lm")
    # score
    cv.text(x0 + 40, y0 + 150, "SCORE", 14, C["text2"], weight=800, anchor="lm", tracking=3)
    cv.text(x0 + 36, y0 + 205, "1,004,320", 72, C["text"], weight=900, anchor="lm")
    cv.text(x0 + 420, y0 + 214, "点", 24, C["text2"], weight=800, anchor="lm")
    # judgement table
    rows = [("良", "good", 873), ("可", "ok", 12), ("不可", "bad", 1)]
    rows2 = [("最大コンボ", 885), ("連打数", 146)]
    ty = y0 + 280
    for k, (lab, key, v) in enumerate(rows):
        cy = ty + k * 42
        cv.rrect(x0 + 40, cy - 16, x0 + 100, cy + 16, 8, fill=C["bg2"])
        cv.text(x0 + 70, cy, lab, 17, C[key], weight=900)
        cv.text(x0 + 300, cy, f"{v}", 26, C["text"], weight=800, anchor="rm")
    for k, (lab, v) in enumerate(rows2):
        cy = ty + k * 42
        cv.text(x0 + 400, cy, lab, 17, C["text2"], weight=800, anchor="lm")
        cv.text(x1 - 48, cy, f"{v}", 26, C["text"], weight=800, anchor="rm")
    # crown / rank card
    rx0, ry0, rx1, ry1 = 870, 92, 1240, 520
    cv.rrect(rx0, ry0, rx1, ry1, 20, fill=C["bg1"])
    cx, cy = (rx0 + rx1) / 2, ry0 + 160
    cv.circle(cx, cy, 96, fill=C["bg2"])
    cv.ring(cx, cy, 96, 90, C["good"])
    cv.poly([(cx - 52, cy + 30), (cx - 52, cy - 22), (cx - 26, cy + 2), (cx, cy - 42), (cx + 26, cy + 2),
             (cx + 52, cy - 22), (cx + 52, cy + 30)], C["good"])
    cv.rect(cx - 52, cy + 36, cx + 52, cy + 46, C["good"])
    cv.text(cx, ry0 + 300, "フルコンボ", 30, C["good"], weight=900)
    cv.text(cx, ry0 + 336, "FULL COMBO", 13, C["text2"], weight=800, tracking=4)
    cv.capsule(cx - 110, ry0 + 372, cx + 110, ry0 + 408, C["bg2"])
    cv.text(cx, ry0 + 390, "自己ベスト更新  +12,400", 14, C["text"], weight=800)
    # bottom strip: a quiet row of past-play dots
    cv.text(40, 560, "これまでの成績", 14, C["text2"], weight=800, anchor="lm")
    for k in range(10):
        col = [C["mute"], C["text2"], C["good"]][min(2, k // 4)]
        cv.circle(220 + k * 30, 560, 9, fill=col if k < 8 else C["bg3"])
    footer(cv, [("F/J", "つぎへ"), ("ESC", "もどる")])
    return cv.result()


def swatch():
    cv = Canvas(1600, 1290, bg=C["bg0"])
    cv.text(40, 48, "YataiDON SimpleStyle", 34, C["text"], weight=900, anchor="lm")
    cv.text(40, 86, "flat · dark slate · one accent per job", 16, C["text2"], weight=700, anchor="lm", tracking=1)
    groups = [
        ("Neutrals", ["bg0", "bg1", "bg2", "bg3", "line", "mute", "text2", "text"]),
        ("Notes", ["don", "ka", "roll", "balloon"]),
        ("Judgement / gauge", ["good", "ok", "bad", "p1", "p2", "clear", "gogo"]),
        ("Difficulty", ["easy", "normal", "hard", "oni", "ura", "tower", "dan"]),
        ("Branch", ["br_normal", "br_expert", "br_master"]),
    ]
    y = 130
    for gname, keys in groups:
        cv.text(40, y + 10, gname, 16, C["text2"], weight=800, anchor="lm")
        x = 40
        y += 30
        for k in keys:
            cv.rrect(x, y, x + 150, y + 70, 10, fill=C[k], outline=C["line"], width=1.5)
            cv.text(x + 4, y + 88, k, 13, C["text"], weight=800, anchor="lm")
            cv.text(x + 4, y + 106, P[k].upper(), 12, C["text2"], weight=700, anchor="lm")
            x += 168
        y += 130
    out = cv.result()
    # component strip: the real built note art
    return out


def components(skin_graphics):
    """Pull frames from the built skin into one strip (shows the actual textures)."""
    from PIL import ImageDraw
    import json
    strip = blank(1600, 300)
    strip.paste(C["bg2"], (0, 0, 1600, 300))
    notes = Image.open(f"{skin_graphics}/game/notes/notes_atlas.png")
    tj = json.load(open(f"{skin_graphics}/game/notes/texture.json", encoding="utf-8"))
    x = 20
    for k in ["1", "2", "3", "4", "5", "6", "7", "9"]:
        cx, cy, w, h = tj[k]["crop"][0]
        fr = notes.crop((cx, cy, cx + w, cy + h))
        strip.alpha_composite(fr, (x, 20))
        if k == "7":
            ox, oy, ow, oh = tj["10"]["crop"][0]
            strip.alpha_composite(notes.crop((ox, oy, ox + ow, oy + oh)), (x + 128, 20))
            x += 128
        x += 120
    # a drumroll: head + stretched body + tail
    b = tj["8"]["crop"][0]
    body = notes.crop((b[0], b[1], b[0] + b[2], b[1] + b[3])).resize((260, 128))
    t = tj["drumroll_tail"]["crop"][0]
    tail = notes.crop((t[0], t[1], t[0] + t[2], t[1] + t[3]))
    hcrop = tj["5"]["crop"][0]
    head = notes.crop((hcrop[0], hcrop[1], hcrop[0] + 128, hcrop[1] + 128))
    strip.alpha_composite(body, (84, 160))
    strip.alpha_composite(tail, (84 + 260, 160))
    strip.alpha_composite(head, (20, 160))
    lane = Image.open(f"{skin_graphics}/game/lane/drum.png")
    strip.alpha_composite(lane, (480, 160))
    for j, f in enumerate(["drum_don_l", "drum_kat_r"]):
        strip.alpha_composite(Image.open(f"{skin_graphics}/game/lane/{f}.png"), (480, 160))
    hc = Image.open(f"{skin_graphics}/game/lane/lane_hit_circle.png")
    strip.alpha_composite(hc, (620, 150))
    for j, k in enumerate(["good", "ok", "bad"]):
        strip.alpha_composite(Image.open(f"{skin_graphics}/game/hit_effect/judge_{k}.png"), (790 + j * 96, 200))
    soul = Image.open(f"{skin_graphics}/game/gauge/tamashii.png")
    strip.alpha_composite(soul, (1090, 190))
    strip.alpha_composite(Image.open(f"{skin_graphics}/game/gauge/tamashii_dark.png"), (1170, 190))
    for j, k in enumerate(["normal", "expert", "master"]):
        strip.alpha_composite(Image.open(f"{skin_graphics}/game/branch/{k}.png"), (1250, 150 + j * 48))
    return strip


def write_all(skin_graphics, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    song_select().convert("RGB").save(f"{out_dir}/mock_song_select.png")
    result().convert("RGB").save(f"{out_dir}/mock_result.png")
    sw = swatch()
    comp = components(skin_graphics)
    sw.alpha_composite(comp, (0, 990))
    # difficulty emblems on the swatch
    ld = Image.open(f"{skin_graphics}/game/lane/lane_difficulty.png")
    for j in range(7):
        sw.alpha_composite(ld.crop((0, j * 64, 88, j * 64 + 64)), (760 + j * 100, 320))
    sw.convert("RGB").save(f"{out_dir}/swatch.png")
