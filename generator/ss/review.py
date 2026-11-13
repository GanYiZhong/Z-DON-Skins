"""Review sheets of the core kit (build.py --mockups): mockups/v2_chrome.png, mockups/v2_mascot_frames.png,
mockups/v2_identity.png (hint pill, course identity, wipe steps, sit_fail at k=9).
Drawn with the real chrome/deco/mascot code at the build density, so what you see is what ships."""
from __future__ import annotations

import os

from . import chrome, course, deco, mascot
from .style import C, U, Canvas


def chrome_sheet(path):
    W, H = 1920, 1080
    cv = Canvas(W, H, bg=C["bg0"])
    deco.sky(cv, 0, 0, W, 180)
    deco.cloud(cv, 150, 45, "M")
    deco.cloud(cv, 1500, 75, "S")
    deco.lanterns(cv, 600, 1320, 168, n=6)
    # left column: the five variants
    chrome.dialog(cv, 60, 240, 600, 540, title="リトライしますか？")
    cv.text(84, 336, "ドンで決定　カッでえらぶ", 24, C["ink"], anchor="lm")
    chrome.button(cv, 96, 420, 324, 483, "はい", state="focused")
    chrome.cursor(cv, 72, 451)
    chrome.button(cv, 348, 420, 564, 483, "いいえ")
    chrome.panel(cv, 660, 270, 1110, 540, plate_text="リザルト", plate_accent=C["p1"])
    for i, (lbl, col, n) in enumerate((("良", C["clear"], "812"), ("可", C["mint"], "34"), ("不可", C["hard"], "3"))):
        y = 351 + i * 39
        chrome.chip(cv, 690, y, 834, None, lbl, accent=col, edge=True)
        cv.text(1068, y + 13, n, 36, C["ink"], anchor="rm")
    chrome.pixbar(cv, 690, 474, 1068, 501, 0.73, C["p1"], segs=10)
    chrome.plate(cv, 1170, 240, 1560, 294, "曲をえらぶ", accent=C["don"])
    for i, (t, a) in enumerate((("かんたん", C["easy"]), ("おに", C["oni"]), ("真打", C["clear"]), ("1曲目", C["bg3"]))):
        chrome.chip(cv, 1170 + i * 168, 330, 1320 + i * 168, None, t, accent=a)
    chrome.button(cv, 1170, 390, 1410, 453, "ふつう")
    chrome.button(cv, 1440, 390, 1680, 453, "おされた", state="pressed")
    for f in range(4):
        deco.sparkle_burst(cv, 1230 + f * 120, 510, f)
    # bottom: stage
    ground_y = 900
    deco.taiko(cv, 960, ground_y)
    mascot.paste(cv, "momo", "drum_l", 9, 735, ground_y)
    mascot.paste(cv, "hoshi", "turn", 9, 1185, ground_y, mirror=True)
    w = chrome.bubble_width("ドンとこい！")
    chrome.bubble(cv, 1320, 570, 1320 + w, 648, tail_x=1356, text="ドンとこい！", tail="steps")
    deco.ground(cv, 0, ground_y, W, H)
    deco.pixdisc(cv, 210, 750, 20, C["paper"], inner_ring=(C["clear"], 1))
    cv.text(210, 738, "128", 48, C["ink"])
    cv.text(210, 780, "コンボ", 18, C["ink"])
    deco.pixtext(cv, 1470, 720, "GAME OVER", cell=2 * U, fill=C["don"], shadow=U)
    cv.text(60, 1050, "SimpleStyle v2 core kit: chrome / deco / mascot (logical 1920x1080, U = 3)", 18, C["ink"],
            anchor="lm")
    cv.result().save(path)


def identity_sheet(path):
    """Core v2 fix kit: the hint pill, the course identity (glyphs, chips, plates, crowns, rank badges),
    the wipe steps and sit_fail at k=9 (mockups/v2_identity.png)."""
    W, H = 1920, 1080
    cv = Canvas(W, H, bg=C["bg0"])
    cv.text(30, 30, "SimpleStyle v2 core identity kit (logical 1920x1080, U = 3)", 24, C["ink"], anchor="lm")
    # course glyphs s / l, chips, plates
    for i in range(5):
        x = 60 + i * 180
        course.glyph(cv, x + 15, 96, i, U)
        course.glyph(cv, x + 90, 96, i, 2 * U)
        course.chip(cv, x, 147, None, i)
        cv.text(x, 195, course.name(i), 18, C["text2"], anchor="lm")
    course.plate(cv, 960, 69, 1290, 4)
    course.plate(cv, 1320, 69, 1650, 3)
    # crowns: none / clear x5 / fc / dfc at cell U and 2U
    kinds = [("none", None)] + [("clear", i) for i in range(5)] + [("fc", None), ("dfc", None)]
    for j, (k, c) in enumerate(kinds):
        x = 60 + j * 108
        course.crown(cv, x, 249, k, c, U)
        course.crown(cv, x, 285, k, c, 2 * U)
        cv.text(x, 345, k if c is None else f"clear {course.KEYS[c]}", 18, C["text2"], anchor="lm")
    # all-good = gold crown (ink jewels) + the 全良 chip; fc = gold crown (paper jewels)
    x = 60 + 8 * 108
    course.crown(cv, x, 285, "dfc", None, 2 * U)
    cw, chh = course.crown_size(2 * U)
    course.zenryo_chip(cv, x + (cw - course.ZENRYO_W) // 2, 285 + chh + U)
    cv.text(x, 345 + 30, "dfc + zenryo_chip", 18, C["text2"], anchor="lm")
    # rank badges s / l
    for t in range(7):
        x = 60 + t * 150
        cv.paste(course.rank_badge(t, 11, 36), x, 390)
        cv.paste(course.rank_badge(t, 21, 48), x, 480)
    # hint pills (the footer rule anchors them bottom-right)
    chrome.hint(cv, [("ka", "えらぶ"), ("don", "決定")], x1=1860, y1=300)
    chrome.hint(cv, [("ka", "えらぶ"), ("don", "決定"), (None, "ESC もどる")], x1=1860, y1=366)
    chrome.hint(cv, [("don", "決定")], x1=1860, y1=432)
    # wipe steps 1..3 over a panel (checker cells 2U)
    bayer = [[0, 2], [3, 1]]
    for lvl in (1, 2, 3):
        x0 = 1200 + (lvl - 1) * 210
        chrome.panel(cv, x0, 480, x0 + 180, 600)
        for yy in range(480, 606, 6):
            for xx in range(x0, x0 + 186, 6):
                if bayer[(yy // 6) % 2][(xx // 6) % 2] < lvl:
                    cv.rect(xx, yy, xx + 6, yy + 6, C["sky"])
        cv.text(x0, 627, f"wipe level {lvl}", 18, C["text2"], anchor="lm")
    # sit_fail at k=9 (scene), next to idle
    ground = 1032
    deco.ground(cv, 0, ground, W, H)
    for i, (ch, e) in enumerate((("momo", "idle"), ("momo", "sit_fail"), ("hoshi", "idle"), ("hoshi", "sit_fail"))):
        mascot.paste(cv, ch, e, "scene", 240 + i * 330, ground)
    chrome.hint(cv, [("ka", "えらぶ"), ("don", "決定")])
    cv.result().save(path)


def write_all(mock_dir):
    os.makedirs(mock_dir, exist_ok=True)
    chrome_sheet(os.path.join(mock_dir, "v2_chrome.png"))
    mascot.frames_sheet(os.path.join(mock_dir, "v2_mascot_frames.png"), k=6)
    identity_sheet(os.path.join(mock_dir, "v2_identity.png"))
