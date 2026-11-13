"""Song select, the secondary panels (light 8-bit): option (modifier) and sound (neiro) panels, the
leaderboard, the star-sort (diff_sort) window, the AI-battle level picker and the dan transition.
Part of the song_select module (same OWNS)."""
from __future__ import annotations

import math

from PIL import Image

from . import mascot
from .atlas import SubsetWriter, dir_frames, key_info, ref_bbox
from .song_select import (CHEV, CROWN, I_BACK, I_NOTE, I_STAR, INK, PAPER, pcloud, pdisc, pemblem, pgrid, pgrid_c,
                          pframe, plate, pring, tint)
from .style import C, COURSES, Canvas, alpha, blank, hexc, hue, mix, pixbox, pixdither, vtext

SCREEN = "song_select"


def gb(sub, key, i=0):
    """Where Green's art sits in frame i of a key (alpha bbox), for placement only."""
    fname, crops, is_dir = key_info(SCREEN, sub, key)
    if is_dir:
        fr = dir_frames(SCREEN, sub, key)
        return ref_bbox(SCREEN, sub, f"{key}/{fr[min(i, len(fr) - 1)][0]}", thresh=40)
    return ref_bbox(SCREEN, sub, fname, crop=tuple(crops[min(i, len(crops) - 1)]) if crops else None, thresh=40)


def card(fill=None, line=None, shadow=0, px=3, box=None, sub=None, key=None, ring=None, notch=True):
    """A pixbox window (line = border colour, default ink) or, with line=None, a flat rect; with
    ring=<colour> and no fill, only a selection ring (ink + colour)."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        b = box or (gb(sub, key, i) if sub else (0, 0, w, h))
        x0, y0, x1, y1 = b
        if ring is not None:
            pframe(cv, (x0, y0, x1, y1), ring, 3, 4, 3)
        elif line is None:
            cv.rect(x0, y0, x1, y1, fill)
        else:
            pixbox(cv, x0, y0, x1, y1, fill, line, shadow=shadow, px=px, notch=notch)
        return cv.result()
    return draw


def text_img(s, size=24, col=None, weight=900, box=None, sub=None, key=None, align="m", vertical=False):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        x0, y0, x1, y1 = box or (gb(sub, key, i) if sub else (0, 0, w, h))
        st = s[i] if isinstance(s, (list, tuple)) else s
        c = col or INK
        if vertical:
            vtext(cv, (x0 + x1) / 2, y0 + 4, st, min(size, (x1 - x0) * 0.8), c, weight=weight, max_h=y1 - y0 - 8)
        else:
            x = {"l": x0 + 4, "m": (x0 + x1) / 2, "r": x1 - 4}[align]
            cv.text(x, (y0 + y1) / 2 + 1, st, size, c, weight=weight, anchor=align + "m", max_w=x1 - x0 - 8)
        return cv.result()
    return draw


def digits(size, col=None, chars="0123456789", weight=800):
    """Tabular digits, one per crop. Default white: the engine tints them (leaderboard); the
    untinted counters pass INK."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        cv.text(w / 2, h / 2 + 1, chars[i], size, col or (255, 255, 255, 255), weight=weight)
        return cv.result()
    return draw


def player_badge(label, color):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        plate(cv, 6, 6, w - 9, h - 9, color, shadow=3)
        cv.text((w - 3) / 2, h / 2, label, 24, PAPER, weight=900)
        return cv.result()
    return draw


def blue_arrow(i, n, w, h):
    cv = Canvas(w, h)
    pgrid_c(cv, w * 0.5, h * 0.5, CHEV, 4, C["ka"], ow=2)
    return cv.result()


# ------------------------------------------------------------------ modifier (演奏オプション)
MOD_ICON = {
    "mod_auto": ("A", "ka", PAPER), "mod_baisaku": ("×2", "clear", INK), "mod_sanbai": ("×3", "gogo", INK),
    "mod_yonbai": ("×4", "don", PAPER), "mod_doron": ("", "bg3", INK), "mod_abekobe": ("", "bg3", INK),
    "mod_kimagure": ("?", "ura", PAPER), "mod_detarame": ("??", "oni", INK),
}


def mod_icon(key):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        label, col, fg = MOD_ICON[key]
        plate(cv, 6, 6, 40, 40, C[col], shadow=2, px=2)
        cx, cy = 22, 22
        if key == "mod_doron":   # dotted ring = hidden notes
            for k in range(8):
                a = math.radians(k * 45)
                px_, py_ = int(cx + math.cos(a) * 9), int(cy + math.sin(a) * 9)
                cv.rect(px_ - 2, py_ - 2, px_ + 2, py_ + 2, INK)
        elif key == "mod_abekobe":   # swap: a don square and a ka square
            cv.rect(11, 16, 21, 26, INK)
            cv.rect(13, 18, 19, 24, C["don"])
            cv.rect(24, 20, 34, 30, INK)
            cv.rect(26, 22, 32, 28, C["ka"])
        else:
            cv.text(cx + 0.5, cy + 1, label, 12 if len(label) > 1 else 24, fg, weight=900)
        return cv.result()
    return draw


def build_modifier(G, lang):
    w = SubsetWriter(G, SCREEN, "modifier")
    # header text sits on the top tab (Green bakes it into the texture, Japanese only)
    w.put("top", lambda i, n, ww, hh: _top_with_title(ww, hh, "演奏オプション" if lang == "ja" else "Options"))
    w.put("bottom", card(PAPER, INK, shadow=4, box=(26, -30, 433, 110)))
    w.put("background", _side_walls)
    w.put("mod_bg", _mod_row(False))
    w.put("mod_bg_highlight", _mod_row(True))
    w.put("mod_box", card(C["bg3"], INK, px=2, box=(6, 6, 40, 40)))
    for k in MOD_ICON:
        w.put(k, mod_icon(k))
    w.put("1p", player_badge("1P", C["p1"]))
    w.put("2p", player_badge("2P", C["p2"]))
    w.put("blue_arrow", blue_arrow)
    return w.write()


def _side_walls(i, n, w, h):
    """The stretched middle of the option window: paper with ink side walls and the hard shadow."""
    cv = Canvas(w, h)
    cv.rect(26, -20, 433, 84, INK)
    cv.rect(29, -20, 430, 84, PAPER)
    cv.rect(433, -20, 437, 84, INK)
    return cv.result()


def _top_with_title(w, h, title):
    cv = Canvas(w, h)
    pixbox(cv, 26, 25, 433, 140, PAPER, INK, shadow=0, px=3)
    cv.rect(29, 28, 430, 92, C["sky"])
    pcloud(cv, 48, 36, 2)
    pcloud(cv, 372, 52, 2)
    cv.rect(29, 92, 430, 95, INK)
    cv.rect(433, 28, 437, 140, INK)
    cv.text(231, 60, title, 24, INK, weight=900, max_w=230)
    return cv.result()


def _mod_row(hl):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        if hl:
            pixbox(cv, 10, 4, 390, 52, C["clear"], INK, shadow=0, px=3)
        else:
            pixbox(cv, 10, 6, 390, 50, C["bg2"], INK, shadow=0, px=2)
        pixbox(cv, 186, 11, 384, 45, PAPER, INK, shadow=0, px=2, notch=False)
        return cv.result()
    return draw


# ------------------------------------------------------------------ neiro (音色)
def build_neiro(G, lang):
    w = SubsetWriter(G, SCREEN, "neiro")

    def bg(i, n, ww, hh):
        cv = Canvas(ww, hh)
        pixbox(cv, 26, 18, 433, 375, PAPER, INK, shadow=4, px=3)
        cv.rect(29, 21, 430, 84, C["sky"])
        pcloud(cv, 48, 30, 2)
        cv.rect(29, 84, 430, 87, INK)
        cv.text(231, 52, "音色をかえる" if lang == "ja" else "Sounds", 24, INK, weight=900, max_w=230)
        pdisc(cv, 231, 232, 108, 6, INK)
        pdisc(cv, 231, 232, 102, 6, C["bg2"])
        return cv.result()
    w.put("background", bg)
    w.put("1p", player_badge("1P", C["p1"]))
    w.put("2p", player_badge("2P", C["p2"]))
    w.put("divisor", text_img("/", 24, INK, box=(0, 0, 24, 32)))
    w.put("counter", digits(24, INK))

    def note(i, n, ww, hh):
        cv = Canvas(ww, hh)
        cell = max(4, min(ww, hh) // 9)
        pgrid_c(cv, ww / 2, hh / 2, I_NOTE, cell, C["oni"], ow=max(2, cell // 2))
        return cv.result()
    w.put("music_note", note)
    w.put("blue_arrow", blue_arrow)
    return w.write()


# ------------------------------------------------------------------ leaderboard (score history)
def build_leaderboard(G, lang):
    w = SubsetWriter(G, SCREEN, "leaderboard")

    def folder_card(box, tab):
        def draw(i, n, ww, hh):
            cv = Canvas(ww, hh)
            x0, y0, x1, y1 = box
            tx0, tx1 = tab
            pixbox(cv, x0, y0 + 40, x1, y1, PAPER, INK, shadow=4, px=3)
            pixbox(cv, tx0, y0, tx1, y0 + 60, PAPER, INK, shadow=0, px=3)
            cv.rect(tx0 + 3, y0 + 40, tx1 - 3, y0 + 61, PAPER)   # open the tab into the body
            return cv.result()
        return draw
    w.put("background", folder_card((17, 2, 288, 171), (60, 230)))
    w.put("background_2", folder_card((9, 13, 280, 355), (50, 220)))

    def bar(accent, label=None, dark=False, fg=INK):
        def draw(i, n, ww, hh):
            cv = Canvas(ww, hh)
            pixbox(cv, 0, 2, 239, 38, INK if dark else C["bg2"], INK, shadow=0, px=2)
            aw = 58 if label else 10
            cv.rect(2, 4, aw, 36, INK)
            cv.rect(2, 4, aw - 2, 36, accent)
            if label:
                cv.text(29, 21, label, 24, fg, weight=900)
            return cv.result()
        return draw
    w.put("normal", bar(C["clear"]))
    w.put("normal_ura", bar(C["ura"]))
    w.put("shinuchi", bar(C["clear"], "真打", dark=True))
    w.put("shinuchi_ura", bar(C["ura"], "真打", dark=True, fg=PAPER))
    w.put("pts", text_img("点", 24, (255, 255, 255, 255), box=(0, 0, 32, 32)))
    w.put("counter", digits(24, (255, 255, 255, 255)))

    def diff(i, n, ww, hh):
        cv = Canvas(ww, hh)
        pemblem(cv, 16, 16, 14, i)
        return cv.result()
    w.put("difficulty", diff)

    def ura(i, n, ww, hh):
        cv = Canvas(ww, hh)
        plate(cv, 2, 2, 29, 29, C["ura"], shadow=0, px=2)
        cv.text(15.5, 16.5, "裏", 12, PAPER, weight=900)
        return cv.result()
    w.put("ura", ura)
    w.put("judge_good", text_img("良", 24, C["good"], box=(0, 0, 40, 40)))
    w.put("judge_ok", text_img("可", 24, C["ok"], box=(0, 0, 40, 40)))
    w.put("judge_bad", text_img("不可", 24, C["bad"], box=(0, 0, 64, 40)))
    w.put("judge_drumroll", text_img("連打数", 24, C["gold_t"], box=(60, 0, 160, 40), align="r"))
    w.put("judge_num", digits(24, INK))
    return w.write()


# ------------------------------------------------------------------ diff_sort (★ sort window)
def build_diff_sort(G, lang):
    w = SubsetWriter(G, SCREEN, "diff_sort")
    w.put("background", card(PAPER, INK, shadow=5, box=(2, 2, 790, 534)))
    for lg in ("ja", "en"):
        w.put("back_" + lg, _vbutton("もどる" if lg == "ja" else "Back"))
    w.put("back_outline", card(ring=C["p1"], box=(9, 8, 72, 312)))
    w.put("box", card(C["bg2"], INK, shadow=4, box=(2, 2, 79, 372)))
    w.put("box_highlight", card(tint(C["clear"], 0.55), INK, shadow=4, box=(2, 2, 79, 372)))
    w.put("box_outline", card(ring=C["p1"], box=(1, 0, 83, 378)))

    def box_diff(i, n, ww, hh):
        cv = Canvas(ww, hh)
        pemblem(cv, 43, 28, 24, i)
        return cv.result()
    w.put("box_diff", box_diff)
    names = [c[1] for c in COURSES[:4]] + ["おに(裏)", "前回あそんだむずかしさ"]
    w.put("box_text", text_img(names, 36, INK, box=(20, 20, 65, 360), vertical=True))
    w.put("box_text_highlight", text_img(names, 36, INK, box=(20, 20, 65, 360), vertical=True))
    w.put("star_select_text", text_img("★の数をえらんでね！", 36, INK, box=(10, 4, 446, 58)))
    w.put("star_select_prompt", text_img("このむずかしさでいい？", 36, INK, box=(10, 4, 446, 58)))
    limits = ["★1〜★5", "★1〜★7", "★1〜★8", "★1〜★10", "★1〜★10"]
    w.put("star_limit", text_img(limits, 24, C["text2"], box=(0, 0, 370, 44)))

    def level_box(i, n, ww, hh):
        cv = Canvas(ww, hh)
        plate(cv, 2, 2, 560, 184, C["bg2"], shadow=4)
        pixbox(cv, 28, 86, 538, 150, PAPER, INK, shadow=0, px=2)
        for k in range(10):
            x = 58 + k * 47
            cv.rect(x - 7, 111, x + 7, 125, INK)
            cv.rect(x - 5, 113, x + 5, 123, C["bg3"])
        return cv.result()
    w.put("level_box", level_box)

    def diff(i, n, ww, hh):
        cv = Canvas(ww, hh)
        pemblem(cv, 40, 35, 26, i)
        cv.text(80, 36, COURSES[i][1] if i < 4 else "おに(裏)", 36, INK, weight=900, anchor="lm", max_w=220)
        return cv.result()
    w.put("diff", diff)
    nums = [2, 1, 3, 4, 5, 6, 7, 8, 9, 10]

    def star_num(i, n, ww, hh):
        cv = Canvas(ww, hh)
        pgrid_c(cv, 26, 31, I_STAR, 4, C["clear"], ow=2)
        cv.text(48, 32, str(nums[i]), 36, INK, weight=900, anchor="lm")
        return cv.result()
    w.put("star_num", star_num)

    def star(i, n, ww, hh):
        cv = Canvas(ww, hh)
        pgrid_c(cv, ww / 2, hh / 2, I_STAR, 5, C["clear"], ow=3)
        return cv.result()
    w.put("star", star)

    def pongos(i, n, ww, hh):
        """Green shows four little characters here: our two pixel mascots in three moods."""
        im = blank(ww, hh)
        for k, (cc, e) in enumerate(((mascot.MAIN, "good"), (mascot.BUDDY, "idle"), (mascot.MAIN, "combo"))):
            m = mascot.sized(cc, e, 96)
            im.alpha_composite(m, (20 + k * 88 + 8, 4 + 8))
        return im
    w.put("pongos", pongos)
    w.put("small_box", card(C["bg2"], INK, shadow=4, box=(2, 2, 200, 92)))
    w.put("small_box_highlight", card(tint(C["clear"], 0.55), INK, shadow=4, box=(2, 2, 200, 92)))
    w.put("small_box_outline", card(ring=C["p1"], box=(2, 2, 204, 96)))
    sb = ["★の数を\nえらびなおす", "決定", "むずかしさを\nえらびなおす"]
    w.put("small_box_text", _multiline(sb, INK))
    w.put("small_box_text_highlight", _multiline(sb, INK))
    w.put("stat_bg_1p", _stat_bg(C["p1"]))
    w.put("stat_bg_2p", _stat_bg(C["p2"]))

    def stat_overlay(i, n, ww, hh):
        cv = Canvas(ww, hh)
        pixbox(cv, 15, 53, 223, 92, C["bg3"], INK, shadow=0, px=2, notch=False)
        cv.text(40, 128, "全", 24, C["text2"], weight=900)
        cv.text(200, 128, "曲", 24, C["text2"], weight=900)
        for k, kind in enumerate(("fc", "clear")):
            y = 180 + k * 46
            pgrid_c(cv, 36, y, CROWN, 3, C["clear"] if kind == "fc" else hexc("#C9CFDA"), ow=2)
            cv.text(140, y, "/", 24, C["text2"], weight=800)
            cv.text(212, y, "個", 12, C["text2"], weight=800)
        return cv.result()
    w.put("stat_overlay", stat_overlay)
    w.put("stat_num", digits(36, INK))
    w.put("stat_num_small", digits(12, INK))
    w.put("stat_num_star", digits(36, INK))

    def stat_diff(i, n, ww, hh):
        cv = Canvas(ww, hh)
        pemblem(cv, 43, 43, 28, i)
        return cv.result()
    w.put("stat_diff", stat_diff)

    def starx(i, n, ww, hh):
        cv = Canvas(ww, hh)
        pgrid_c(cv, 30, 43, I_STAR, 4, C["clear"], ow=2)
        cv.text(60, 46, "×", 24, INK, weight=900)
        return cv.result()
    w.put("stat_starx", starx)
    w.put("stat_recommend", text_img("おすすめのむずかしさ", 24, C["text2"], box=(17, 14, 223, 48)))
    w.put("stat_prev", text_img("前回あそんだむずかしさ", 24, C["text2"], box=(14, 14, 225, 48)))

    def arrow(i, n, ww, hh):
        cv = Canvas(ww, hh)
        pgrid_c(cv, ww / 2, hh / 2, CHEV, 4, C["clear"], ow=2)
        return cv.result()
    w.put("arrow", arrow)
    return w.write()


def _stat_bg(col):
    def draw(i, n, ww, hh):
        cv = Canvas(ww, hh)
        pixbox(cv, 2, 2, 238, 278, PAPER, INK, shadow=4, px=3)
        pring(cv, (5, 5, 235, 275), 4, col, 0)
        return cv.result()
    return draw


def _vbutton(label):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        plate(cv, 12, 10, 66, 308, PAPER, shadow=4)
        cv.rect(21, 21, 59, 59, INK)
        cv.rect(24, 24, 56, 56, C["bg3"])
        pgrid_c(cv, 40, 40, I_BACK, 3, INK)
        vtext(cv, 39, 72, label, 24, INK, weight=800, max_h=230)
        return cv.result()
    return draw


def _multiline(labels, col):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        lines = labels[i].split("\n")
        for k, ln in enumerate(lines):
            y = h / 2 + (k - (len(lines) - 1) / 2) * 30
            cv.text(w / 2, y, ln, 24, col, weight=900, max_w=w - 30)
        return cv.result()
    return draw


# ------------------------------------------------------------------ ai_battle (level picker)
SUBDIFF_LEVELS = {"subdiff_easy": [1], "subdiff_normal": [2, 3, 4, 5], "subdiff_hard": [6, 7, 8, 9],
                  "subdiff_oni": [10, 11, 12, 13]}
SUBDIFF_DEFAULT = {"subdiff_easy": 0, "subdiff_normal": 3, "subdiff_hard": 3, "subdiff_oni": 3}


def build_ai_battle(G, lang):
    w = SubsetWriter(G, SCREEN, "ai_battle")

    def bg(i, n, ww, hh):
        cv = Canvas(ww, hh, ss=1)
        cv.rect(0, 0, ww, hh, C["bg0"])
        cv.rect(0, 0, ww, 112, C["sky"])
        pixdither(cv, 0, 112, ww, 120, C["sky"], 4)
        for off in range(0, ww, 640):
            pcloud(cv, off + 60, 22, 4)
            pcloud(cv, off + 380, 50, 3)
        dot = mix(C["bg0"], C["line"], 0.5)
        for y in range(160, hh, 48):
            for x in range(24 + (y // 48 % 2) * 24, ww, 48):
                cv.rect(x, y, x + 3, y + 3, dot)
        return cv.result()
    w.put("background", bg)
    w.put_blank("background_overlay")
    w.put("background_overlay_2", bg)

    def box(title):
        def draw(i, n, ww, hh):
            cv = Canvas(ww, hh)
            plate(cv, 22, 29, 433, 396, PAPER, shadow=4)
            if title:
                cv.rect(25, 32, 430, 90, C["sky"])
                cv.rect(25, 90, 430, 93, INK)
                cv.text(228, 62, title, 24, INK, weight=900, max_w=380)
            return cv.result()
        return draw
    w.put("box_1", box("えらべるむずかしさのレベル" if lang == "ja" else "Levels you can choose"))
    w.put("box_2", box(None))
    w.put("box_bg_blur", card(alpha(C["bg0"], 170), None, box=(15, 13, 447, 400)))
    w.put("bottom_text", text_img("「いつもの」以外では王冠は記録されません", 12, C["text2"], box=(0, 0, 344, 40)))
    w.put("subdiff_select_text", text_img("むずかしさのレベルをえらぶ", 24, INK, box=(0, 0, 334, 46)))

    def selector(i, n, ww, hh):
        cv = Canvas(ww, hh)
        pframe(cv, (3, 11, 67, 306), C["p1"], 3, 4, 3)
        return cv.result()
    w.put("subdiff_selector", selector)
    for key, levels in SUBDIFF_LEVELS.items():
        ci = ["subdiff_easy", "subdiff_normal", "subdiff_hard", "subdiff_oni"].index(key)
        w.put(key, _subdiff(ci, levels, SUBDIFF_DEFAULT[key]))
    return w.write()


def _subdiff(ci, levels, default):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        col = C[COURSES[ci][0]]
        x0, x1 = 12, 72
        plate(cv, x0, 30, x1, 238, C["bg2"], shadow=3)
        pemblem(cv, 42, 58, 18, ci)
        # a segmented level meter: filled share of the column
        frac = (i + 1) / max(1, len(levels))
        top, bot = 86, 196
        cv.rect(x0 + 12, top, x1 - 12, bot, INK)
        cv.rect(x0 + 14, top + 2, x1 - 14, bot - 2, C["bg3"])
        fy = int(bot - 2 - (bot - top - 4) * frac)
        cv.rect(x0 + 14, fy, x1 - 14, bot - 2, col)
        for yy in range(top + 14, bot - 2, 14):
            cv.rect(x0 + 14, yy, x1 - 14, yy + 2, INK)
        cv.text(42, 218, str(levels[i]), 24, INK, weight=900)
        if i == default:
            plate(cv, 6, 2, 78, 26, C["clear"], shadow=0, px=2)
            cv.text(42, 15, "いつもの", 12, INK, weight=900, max_w=62)
        return cv.result()
    return draw


# ------------------------------------------------------------------ dan_transition
def build_dan_transition(G, lang):
    w = SubsetWriter(G, SCREEN, "dan_transition")

    def bgstrip(i, n, ww, hh):
        cv = Canvas(ww, hh, ss=1)
        cv.rect(0, 0, ww, hh, mix(PAPER, C["dan"], 0.10))
        pixdither(cv, 0, hh - 16, ww, hh, mix(PAPER, C["dan"], 0.18), 4)
        return cv.result()
    w.put("background", bgstrip)

    def don(i, n, ww, hh):
        """The character walking into the dan hall: Momo, seen as she heads off."""
        im = blank(ww, hh)
        im.alpha_composite(mascot.sized(mascot.MAIN, "gogo", 352), (24, 264))
        return im
    w.put("don", don)

    def emblem(i, n, ww, hh):
        cv = Canvas(ww, hh)
        pdisc(cv, 236, 236, 230, 8, INK)
        pdisc(cv, 236, 236, 222, 8, C["dan"])
        pdisc(cv, 236, 236, 190, 8, PAPER)
        cv.rect(236 - 70, 236 - 70, 236 + 70, 236 + 70, INK)
        cv.rect(236 - 62, 236 - 62, 236 + 62, 236 + 62, C["dan"])
        cv.rect(236 - 38, 236 - 38, 236 + 38, 236 + 38, INK)
        cv.rect(236 - 30, 236 - 30, 236 + 30, 236 + 30, PAPER)
        return cv.result()
    w.put("emblem", emblem)
    w.put("flash", lambda i, n, ww, hh: Image.new("RGBA", (ww, hh), PAPER))
    return w.write()


def build(G, lang):
    n = 0
    for f in (build_modifier, build_neiro, build_leaderboard, build_diff_sort, build_ai_battle, build_dan_transition):
        n += f(G, lang)
    return n
