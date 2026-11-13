"""SimpleStyle v2: the play screen (Graphics/game/**, Scripts/game/**), on Nijiiro's layout at 4K.

Everything on the enso screen except the background scene (Graphics/background, Scripts/background):
lane, flat notes, hit circle, judgements, hit effects, combo, score + add-score popup, soul gauge,
GOGO, balloon, kusudama, drumroll counter, branch plates, song info, skip, ending banners, rank HUD /
result plates, the dan HUD, the AI battle pieces, practice, and the player portrait (Momo 1P / Hoshi
2P, k=6 in a panel above / below the lane, reacting to hits, combo, misses, GOGO and the ending).

Units: LOGICAL in (1920x1080), PHYSICAL out (x style.D). Notes, roll bodies, the lane and the hit
circle are smooth (Canvas ss=SS, put(..., smooth=True)); everything else is crisp pixel chrome on U.

Own Lua lives in lua/game/game/** (the brief's lua/game/**) and is copied by build() into
Scripts/game/** (build.py's copy_lua would look in lua/v2_game, which does not exist; lua/game also
holds the v1 background script, which belongs to the background agent and must not be shipped here).
"""
from __future__ import annotations

import json
import math
import os
import shutil
from contextlib import contextmanager

from . import chrome, course, deco, mascot, strings, style
from .atlas import NIJIIRO_G, OwnSubset, SubsetWriter, phys_xy, resolve, to_phys_entry
from .style import C, COURSES, U, Canvas, blank_l, snap

NAME = "v2_game"
OWNS = ["Graphics/game", "Scripts/game"]

SCREEN = "game"
INK, PAPER = C["ink"], C["paper"]
N_INK, N_RIM = C["n_ink"], C["n_rim"]   # notes: the same in both themes
SS = style.SS

# ------------------------------------------------------------------ lane geometry (lane-local, logical)
# Nijiiro's lane is 264 tall (lane y = 276 on screen for 1P): note band 12..207, moji strip 213..252.
LANE_H = 264
ROW_TOP_INK = (0, 6)
ROW_RIM = (6, 12)
ROW_NOTE = (12, 204)
ROW_SEAM = (204, 207)
ROW_MID_INK = (207, 213)
ROW_MOJI = (213, 252)
ROW_BOT_INK = (252, 258)
NOTE_CY = 110               # hit circle centre (lane_hit_circle 510,2 + 108)
JUDGE_X = 618               # hit circle centre x (screen)

COURSE_KEYS = ["easy", "normal", "hard", "oni", "ura", "tower", "dan"]
RAINBOW6 = list(course.RAINBOW6)   # the one rainbow (course hues + gold), core


def gfit(v):
    """floor to the U grid"""
    return int(v // U * U)


def put_custom(sw, key, ims, entry=None):
    """Like SubsetWriter.put, but our own frame SIZE (physical images `ims`): for keys whose size the
    engine reads as a layout value (digit advance = frame width) or that are stretched to x2/y2.
    entry: LOGICAL texture.json value (dict or list of dicts); default = the ancestor's position.
    (promote to core: SubsetWriter.put(..., size=))"""
    g = sw.geo(key)
    if entry is not None:
        e = [phys_xy(x) for x in entry] if isinstance(entry, list) else phys_xy(entry)
    else:
        e = to_phys_entry(g.entry, g.scale)
    if len(ims) == 1:
        sw.out[key] = ("file", ims[0])
    else:
        names = g.names if (g.kind == "dir" and len(g.names) == len(ims)) else [f"{i}.png" for i in range(len(ims))]
        sw.out[key] = ("dir", list(zip(names, ims)))
    sw.keys[key] = e
    sw.mode[key] = "crisp"


def put_tiny(sw, key):
    """1x1U transparent: the engine still finds the key, nothing shows, no VRAM."""
    put_custom(sw, key, [blank_l(U, U)])


# ------------------------------------------------------------------ per-language baked variants
# C++ fixed-name textures (judge marks, practice cards, bubbles, plates, notes/moji ...) and textures
# a parent (Nijiiro) Lua draws: the base `<key>` stays Japanese; `<key>_en/_zh/_ko` carry the other
# languages (strings.get). The engine picks `<key>_<lang>` (skin option language_variants, Z-DON
# 6aa410e; Lua tex.get_texture always does). Each language is drawn with its own Fusion Pixel variant,
# the file the engine uses for that language's run-time text (en = the ja variant, ss/fonts.py).
VAR_LANGS = ("en", "zh", "ko")
LANG_FONT = {"ja": "ja", "en": "ja", "zh": "zh_tw", "ko": "ko"}  # Z-DON: zh is Traditional Chinese


@contextmanager
def lang_font(lang):
    """Canvas.text / text_width use `lang`'s Fusion Pixel variant inside the block."""
    old = style.FONT_PIXEL
    style.FONT_PIXEL = os.path.join(os.path.dirname(old), f"fusion-pixel-12px-proportional-{LANG_FONT[lang]}.ttf")
    style.font_phys.cache_clear()
    try:
        yield
    finally:
        style.FONT_PIXEL = old
        style.font_phys.cache_clear()


def tr(key, lang):
    return strings.get(key, lang)


def fit(s, size, max_w):
    """The largest role size <= size whose advance fits max_w (never below 18)."""
    for t in (48, 36, 24, 18):
        if t <= size and Canvas(1, 1).text_width(s, t) <= max_w:
            return t
    return 18


def put_lang(sw, key, factory, entry=None, entries=None, langs=VAR_LANGS, smooth=False, lua=False):
    """`key` = factory("ja") at the ancestor's geometry, plus `<key>_<lang>` = factory(lang) with the
    same frames and entry (entries[lang]: a LOGICAL entry of its own, e.g. a per-language x).
    lua=True (a Lua script draws the key): also `<key>_ja`, since tex.get_texture tries `_ja`, `_en`,
    base for ja and would otherwise show the English one."""
    with lang_font("ja"):
        sw.put(key, factory("ja"), entry=entry, smooth=smooth)
    if lua:
        sw.out[key + "_ja"], sw.keys[key + "_ja"], sw.mode[key + "_ja"] = sw.out[key], sw.keys[key], sw.mode[key]
    g = sw.geo(key)
    kind, data = sw.out[key]
    for lang in langs:
        draw = factory(lang)
        with lang_font(lang):
            ims = [draw(i, len(g.frames), w, h) for i, (w, h) in enumerate(g.frames)]
        name = f"{key}_{lang}"
        if kind == "file":
            sw.out[name] = ("file", ims[0])
        else:
            sw.out[name] = ("dir", [(f, im) for (f, _), im in zip(data, ims)])
        e = (entries or {}).get(lang)
        if e is not None:
            sw.keys[name] = [phys_xy(x) for x in e] if isinstance(e, list) else phys_xy(e)
        else:
            sw.keys[name] = sw.keys[key]
        sw.mode[name] = sw.mode[key]


def put_lang_as(sw, src, name, draw, lang):
    """A key no ancestor ships (`name`, e.g. auto_icon_ko): `src`'s geometry and entry (src must be
    put already), drawn by draw(i, n, w, h) in `lang`'s font."""
    g = sw.geo(src)
    with lang_font(lang):
        ims = [draw(i, len(g.frames), w, h) for i, (w, h) in enumerate(g.frames)]
    kind, data = sw.out[src]
    sw.out[name] = ("file", ims[0]) if kind == "file" else ("dir", [(f, im) for (f, _), im in zip(data, ims)])
    sw.keys[name] = sw.keys[src]
    sw.mode[name] = sw.mode[src]


def put_custom_lang(sw, key, make, entries):
    """put_custom for every language: make(lang) -> [PHYSICAL images]; entries[lang] (LOGICAL)."""
    for lang in ("ja",) + VAR_LANGS:
        with lang_font(lang):
            ims = make(lang)
        name = key if lang == "ja" else f"{key}_{lang}"
        e = entries[lang]
        sw.out[name] = ("file", ims[0]) if len(ims) == 1 else ("dir", [(f"{i}.png", im) for i, im in enumerate(ims)])
        sw.keys[name] = [phys_xy(x) for x in e] if isinstance(e, list) else phys_xy(e)
        sw.mode[name] = "crisp"


# ================================================================== notes (smooth, flat)
ROLL_INK = 2 * U    # roll head / body / tail: 2U ink rim (the engine's heat tint multiplies the whole roll red
                    # and erases the paper rim; a wide dark edge survives it, review r4 G7)


def note_disk(cv, cx, cy, r, fill, rim=None, ink=3):
    """The SimpleStyle note: 3 px ink outline (rolls: ROLL_INK), paper rim, flat face (smooth canvas)."""
    cv.circle(cx, cy, r + ink, fill=N_INK)
    cv.circle(cx, cy, r, fill=rim or N_RIM)
    cv.circle(cx, cy, r - max(6, r * 0.16), fill=fill)


NOTE_C = 96          # centre inside a 192x192 frame
R_SMALL, R_BIG = 51, 77


def f_note(color, big=False, ink=3):
    def draw(i, n, w, h):
        cv = Canvas(w, h, ss=SS)
        note_disk(cv, NOTE_C, NOTE_C, R_BIG if big else R_SMALL, color, ink=ink)
        return cv.result()
    return draw


def f_roll_body(i, n, w, h):
    big = i == 1
    r = R_BIG if big else R_SMALL
    rw = max(6, r * 0.16)
    cv = Canvas(w, h, ss=SS)
    cv.rect(-2, NOTE_C - r - ROLL_INK, w + 2, NOTE_C + r + ROLL_INK, N_INK)
    cv.rect(-2, NOTE_C - r, w + 2, NOTE_C + r, N_RIM)
    cv.rect(-2, NOTE_C - r + rw, w + 2, NOTE_C + r - rw, C["roll"])
    return cv.result()


def f_roll_tail(big):
    def draw(i, n, w, h):
        cv = Canvas(w, h, ss=SS)
        r = R_BIG if big else R_SMALL
        cv.circle(0, NOTE_C, r + ROLL_INK, fill=N_INK)
        cv.circle(0, NOTE_C, r, fill=N_RIM)
        cv.circle(0, NOTE_C, r - max(6, r * 0.16), fill=C["roll"])
        cv.rect(-r - ROLL_INK - 1, 0, 0, h, (0, 0, 0, 0))   # left half belongs to the body
        return cv.result()
    return draw


def f_balloon_head(i, n, w, h):
    # Nijiiro's head sits right of the frame centre (bbox 61..192): centre x 115, string to the edge
    cx = 115
    cv = Canvas(w, h, ss=SS)
    cv.rect(cx, NOTE_C - 6, w + 1, NOTE_C + 6, N_INK)
    cv.rect(cx, NOTE_C - 3, w + 1, NOTE_C + 3, C["wood2"])
    note_disk(cv, cx, NOTE_C, R_SMALL, C["balloon"])
    return cv.result()


def f_balloon_tail(i, n, w, h):
    """notes/10: the string and the balloon itself (Nijiiro bbox 0..137 x 55..140)."""
    cv = Canvas(w, h, ss=SS)
    bx, br = 96, 39
    cv.rect(-1, NOTE_C - 6, bx - br + 6, NOTE_C + 6, N_INK)
    cv.rect(-1, NOTE_C - 3, bx - br + 6, NOTE_C + 3, C["wood2"])
    cv.poly([(bx - br - 12, NOTE_C - 12), (bx - br + 4, NOTE_C), (bx - br - 12, NOTE_C + 12)], N_INK)
    cv.circle(bx, NOTE_C, br + 3, fill=N_INK)
    cv.circle(bx, NOTE_C, br, fill=C["balloon"])
    cv.circle(bx + 12, NOTE_C - 14, 8, fill=N_RIM)
    return cv.result()


def f_kusudama_note(i, n, w, h):
    cv = Canvas(w, h, ss=SS)
    note_disk(cv, NOTE_C, NOTE_C, R_BIG, C["kusu"])
    r = R_BIG - max(6, R_BIG * 0.16)
    cv.pieslice(NOTE_C, NOTE_C, r, 180, 360, C["don"])
    cv.rect(NOTE_C - r, NOTE_C - 4, NOTE_C + r, NOTE_C + 4, N_INK)
    cv.circle(NOTE_C, NOTE_C, 13, fill=N_INK)
    cv.circle(NOTE_C, NOTE_C, 7, fill=C["kusu"])
    return cv.result()


def f_barline(i, n, w, h):
    cv = Canvas(w, h, ss=SS)
    col = C["line"] if i == 0 else C["clear"]
    cv.rect(4.5, 2, 7.5, h - 3, col)
    return cv.result()


MOJI = ["note_don", "note_do", "note_ko", "note_ka", "note_ka_small", "note_don_big", "note_ka_big", "note_roll",
        "note_roll_big", "note_balloon", "note_tsu", "note_kusudama"]   # notes/moji frames (ss/strings.py keys)


def f_moji(lang):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        s = tr(MOJI[i], lang)
        size = fit(s, 36, w - 12 * U)       # role 36 (was 24): readable at play distance
        tw = cv.text_width(s, size)
        if i >= MOJI_BACKED:
            # roll / balloon / kusudama heads and tails: a strip-colour backing keeps the leader line
            # (moji_drumroll_mid, drawn under them) off the letters
            x0, x1 = gfit(w / 2 - tw / 2 - U), gfit(w / 2 + tw / 2 + 2 * U)
            cv.rect(x0, 6, x1, h - 6, C["lane2"])
        cv.text(w / 2, h / 2, s, size, INK)
        # plain ink letters (owner 10-29: no outline / box): the transparent texels carry the
        # neighbouring colour, so the engine's filtering at a moving sub-pixel x never darkens or
        # rings the edges (no box lines at the backing edge, no dark halo on the glyphs)
        return bleed(cv.result(), C["lane2"] if i >= MOJI_BACKED else INK)
    return draw


MOJI_BACKED = MOJI.index("note_roll")


def bleed(im, rgb):
    """Set the RGB of every fully transparent pixel to rgb (alpha stays 0)."""
    from PIL import Image
    r, g, b, a = im.split()
    fill = Image.new("RGBA", im.size, (rgb[0], rgb[1], rgb[2], 0))
    mask = a.point(lambda v: 255 if v else 0)
    fill.paste(im, (0, 0), mask)
    return fill


def f_moji_mid(i, n, w, h):
    cv = Canvas(w, h)
    cv.rect(0, h // 2 - 3, w, h // 2, INK)
    return cv.result()


def build_notes(G):
    sw = SubsetWriter(G, SCREEN, "notes")
    smooth = dict(smooth=True)
    sw.put("0", f_barline, **smooth)
    sw.put("1", f_note(C["don"]), **smooth)
    sw.put("2", f_note(C["ka"]), **smooth)
    sw.put("3", f_note(C["don"], True), **smooth)
    sw.put("4", f_note(C["ka"], True), **smooth)
    sw.put("5", f_note(C["roll"], ink=ROLL_INK), **smooth)
    sw.put("6", f_note(C["roll"], True, ink=ROLL_INK), **smooth)
    sw.put("7", f_balloon_head, **smooth)
    sw.put("8", f_roll_body, **smooth)
    sw.put("9", f_kusudama_note, **smooth)
    sw.put("10", f_balloon_tail, **smooth)
    sw.put("drumroll_tail", f_roll_tail(False), **smooth)
    sw.put("drumroll_big_tail", f_roll_tail(True), **smooth)
    put_lang(sw, "moji", f_moji)
    sw.put("moji_drumroll_mid", f_moji_mid)
    sw.put("moji_drumroll_mid_big", f_moji_mid)
    return sw.write()


# ================================================================== lane
def lane_rows(cv, x0, x1, note_fill=None):
    cv.rect(x0, ROW_TOP_INK[0], x1, ROW_TOP_INK[1], INK)
    cv.rect(x0, ROW_RIM[0], x1, ROW_RIM[1], PAPER)
    # owner 10-29: a grey lane like the arcade (Nijiiro): grey note band, light grey moji strip
    cv.rect(x0, ROW_NOTE[0], x1, ROW_SEAM[1], note_fill or C["lane"])
    cv.rect(x0, ROW_MID_INK[0], x1, ROW_MID_INK[1], INK)
    cv.rect(x0, ROW_MOJI[0], x1, ROW_MOJI[1], C["lane2"])
    cv.rect(x0, ROW_BOT_INK[0], x1, ROW_BOT_INK[1], INK)


def f_lane_bg(i, n, w, h):
    cv = Canvas(w, h)
    lane_rows(cv, 0, w)
    return cv.result()


def f_lane_cover(accent, label=None):
    """The player box left of the lane (498x264): paper, ink frame continuing the lane's rows, a 1U
    player-colour band under the top ink (where the lane has its paper rim)."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        cv.rect(0, 0, w, ROW_BOT_INK[1], PAPER)
        cv.rect(0, ROW_TOP_INK[0], w, ROW_TOP_INK[1], INK)
        cv.rect(0, ROW_RIM[0], w - 6, ROW_RIM[1], accent)
        cv.rect(0, ROW_BOT_INK[0], w, ROW_BOT_INK[1], INK)
        cv.rect(w - 6, 0, w, ROW_BOT_INK[1], INK)
        # quiet bg2 floor under the drum and nameplate (no pattern)
        cv.rect(0, ROW_MID_INK[1], w - 6, ROW_BOT_INK[0], C["bg2"])
        cv.rect(0, ROW_MID_INK[0], w - 6, ROW_MID_INK[1], C["line"])
        return cv.result()
    return draw


def f_score_cover(accent):
    def draw(i, n, w, h):
        # 304x52 at (0, 12): the score panel docked on the cover's left edge
        cv = Canvas(w, h)
        b = chrome.panel(cv, 0, 0, 297, 48, fill=C["bg2"])
        cv.rect(b.ix0, b.iy0, b.ix0 + 2 * U, b.iy1, accent)
        return cv.result()
    return draw


def f_hit_circle(i, n, w, h):
    # 216x216 at (510, 2): the target, centre (108, 108): a small-note ring and a faint big-note ring
    cv = Canvas(w, h, ss=SS)
    c = 108
    # on the grey band: a lighter grey big-note disc, the small-note ring in lane2 (ink edged)
    cv.circle(c, c, R_BIG + 3, fill=INK)
    cv.circle(c, c, R_BIG, fill=C["lane_hi"])
    cv.circle(c, c, R_SMALL + 6, fill=INK)
    cv.circle(c, c, R_SMALL + 3, fill=C["lane2"])
    cv.circle(c, c, R_SMALL - 6, fill=INK)
    cv.circle(c, c, R_SMALL - 9, fill=C["lane"])
    return cv.result()


def f_flat(color):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        cv.rect(0, 0, w, h, color)
        return cv.result()
    return draw


LANE_FLASH_H = ROW_NOTE[1] - ROW_NOTE[0] + 3      # 195: the engine stretches the effect over the note band


def lane_flash_frames():
    """lane_hit_effect (drawn at 496,12 stretched to 1424x195; our animation 0 shows it solid for 83 ms,
    then gone): only the note band's edge rows light, so the lane itself stays bg2 in a dense run.
    frame 0 don / 1 ka: the outer 1U rows; frame 2 (good / ok, drawn on top): the next 1U rows, gold."""
    out = []
    for i in range(3):
        cv = Canvas(1424, LANE_FLASH_H)
        if i == 2:   # owner: no gold judgement lines on the lane's top / bottom edge
            out.append(cv.result())
            continue
        col = [C["don"], C["ka"]][i]
        a = 0
        cv.rect(0, a, 1424, a + U, col)
        cv.rect(0, ROW_SEAM[0] - ROW_NOTE[0] - U - a, 1424, ROW_SEAM[0] - ROW_NOTE[0] - a, col)
        out.append(cv.result())
    return out


# drum (276x304 at 262,-18): face centre (138, 122) frame-local, r 78; combo digits sit on it
DRUM_CX, DRUM_CY = 138, 120
DRUM_R = 26          # cells of U -> 78 logical
DRUM_RIM = 4         # rim band width (cells): the ka zone; the skin inside it is the don zone


def drum_base(cv):
    # barrel: wood body below the face, ink outline
    cx, cy = DRUM_CX, DRUM_CY
    deco.pixdisc(cv, cx, cy + 27, DRUM_R, C["wood"], ring_w=1)
    cv.rect(cx - 81, cy, cx + 81, cy + 27, C["wood"])
    cv.rect(cx - 81, cy, cx - 78, cy + 27, INK)
    cv.rect(cx + 78, cy, cx + 81, cy + 27, INK)
    # rivets: 1U ink dots on the barrel band
    for k in range(-4, 5):
        x = gfit(cx + k * 18)
        cv.rect(x, cy + 36, x + U, cy + 39, C["wood2"])
    # face: a bg3 rim band (DRUM_RIM cells) around the paper drum skin, split by a 1U line ring
    deco.pixdisc(cv, cx, cy, DRUM_R, PAPER, ring_w=1, inner_ring=(C["bg3"], DRUM_RIM))
    deco.pixdisc(cv, cx, cy, DRUM_R - DRUM_RIM, PAPER, ring=C["line"], ring_w=0, inner_ring=(C["line"], 1))


def f_drum(i, n, w, h):
    cv = Canvas(w, h)
    drum_base(cv)
    return cv.result()


def f_drum_hit(kind, side):
    """The arcade / Nijiiro reading: don lights the drum SKIN (the paper face inside the rim) red,
    ka lights the RIM blue (the bg3 rim band, plus a 2U glow ring outside the drum's ink ring with a
    1U ink outer edge). One half per side; the ink rings stay ink."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        cx, cy = DRUM_CX, DRUM_CY
        R = DRUM_R + 4                    # grid radius: the ka ring reaches 3 cells outside the face
        x0, y0 = cx - R * U, cy - R * U

        def disc(r):
            o = R - r
            return {(x + o, y + o) for x, y in deco.disc_cells(r)}
        if kind == "don":
            lit = {c: C["don"] for c in disc(DRUM_R - DRUM_RIM)}
        else:
            lit = {c: INK for c in disc(DRUM_R + 4) - disc(DRUM_R + 3)}
            lit.update({c: C["ka"] for c in disc(DRUM_R + 3) - disc(DRUM_R + 1)})
            lit.update({c: C["ka"] for c in disc(DRUM_R) - disc(DRUM_R - DRUM_RIM)})
        for (x, y), col in lit.items():
            if (x < R) != (side == "l"):
                continue
            cv.rect(x0 + x * U, y0 + y * U, x0 + (x + 1) * U, y0 + (y + 1) * U, col)
        return cv.result()
    return draw


def f_course_badge(lang):
    """lane_difficulty (132x96 at 29,70), frame = course 0..6: the one course chip (core course.chip:
    bg3, 1U course edge, 18 px ink name): no oni-pink block on the play screen (accent budget).
    Tower / dan: the same chip in their accent."""
    def draw(i, n, w, h):
        key, _, _ = COURSES[min(i, len(COURSES) - 1)]
        s = tr(f"course{i}" if i < 5 else ("course_tower" if i == 5 else "course_dan"), lang)
        cv = Canvas(w, h)
        if i < 5:
            course.chip(cv, 3, 27, None, i, text=s)
        else:
            chrome.chip(cv, 3, 27, 3 + course.CHIP_W, None, s, accent=C[key], edge=True)
        return cv.result()
    return draw


def f_score_digits(i, n, w, h):
    # score_number 56x64 x10 (my score_counter.lua draws UI.num instead; kept for other callers)
    cv = Canvas(w, h)
    cv.text(w / 2, h / 2, str(i), 48, INK)
    return cv.result()


def f_mod(label, accent=None):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        x1, y1 = gfit(w), gfit(h)
        b = chrome.frame(cv, 0, 0, x1, y1, accent or C["bg3"], shadow=0, notch=U)
        cv.text(b.cx, b.cy, label, 18, INK)
        return cv.result()
    return draw


def f_mod_key(key):
    """The lane modifier marks (隠 逆 乱 気): one word per language (strings mod_*)."""
    return lambda lang: f_mod(tr(key, lang))


def f_auto(lang):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        x1, y1 = gfit(w) - U, gfit(h) - U
        b = chrome.frame(cv, 0, 0, x1, y1, C["bg3"], shadow=U, notch=U)
        cv.rect(b.ix0, b.iy0, b.ix0 + 4 * U, b.iy1, C["clear"])
        s = tr("auto", lang)
        cv.text((b.ix0 + 4 * U + b.ix1) / 2, b.cy, s, fit(s, 24, b.ix1 - b.ix0 - 8 * U), INK)
        return cv.result()
    return draw


def f_timer_bar(i, n, w, h):
    cv = Canvas(w, h)
    chrome.pixbar(cv, 0, 6, gfit(w), 33, 1.0, C["clear"])
    return cv.result()


def f_ai_lane_bg(i, n, w, h):
    cv = Canvas(w, h)
    lane_rows(cv, 0, w)
    return cv.result()


def f_fusuma(i, n, w, h):
    # dan_between_fusuma 720x208: one sliding door between dan songs, paper panel + lattice
    cv = Canvas(w, h)
    x1, y1 = gfit(w) - U, gfit(h) - U
    b = chrome.frame(cv, 0, 0, x1, y1, C["bg2"], shadow=U, notch=0)
    for k in range(1, 4):
        x = gfit(b.ix0 + (b.ix1 - b.ix0) * k / 4)
        cv.rect(x, b.iy0, x + U, b.iy1, C["line"])
    y = gfit((b.iy0 + b.iy1) / 2)
    cv.rect(b.ix0, y, b.ix1, y + U, C["line"])
    cv.rect(b.ix0, b.iy0, b.ix1, b.iy0 + 2 * U, C["dan"])
    return cv.result()


SPEED_MODS = ["1_1", "1_2", "1_3", "1_4", "1_5", "1_6", "1_7", "1_8", "1_9", "2", "2_5", "3", "3_5", "4"]


def build_lane(G):
    sw = SubsetWriter(G, SCREEN, "lane")
    sw.put("lane_background", f_lane_bg)
    sw.put("ai_lane_background", f_ai_lane_bg)
    put_custom(sw, "lane_hit_effect", lane_flash_frames(), entry={"x": 496, "y": 12, "x2": 1424, "y2": LANE_FLASH_H})
    sw.put("lane_hit_circle", f_hit_circle, smooth=True)
    sw.put("dan_between_fill", f_flat(C["bg2"]))
    sw.put("dan_between_fusuma", f_fusuma)
    sw.put("1p_lane_cover", f_lane_cover(C["p1"]))
    sw.put("2p_lane_cover", f_lane_cover(C["p2"]))
    sw.put("dan_lane_cover", f_lane_cover(C["dan"]))
    sw.put("ai_lane_cover", f_lane_cover(C["p2"]))
    sw.put("lane_score_cover", f_score_cover(C["p1"]))
    sw.put("drum", f_drum)
    for k in ("don", "kat"):
        for s in ("l", "r"):
            sw.put(f"drum_{k}_{s}", f_drum_hit("don" if k == "don" else "ka", s))
    put_lang(sw, "lane_difficulty", f_course_badge)
    sw.put("score_number", f_score_digits)
    sw.put_blank("1p_icon")
    sw.put_blank("2p_icon")
    sw.put_blank("mod_shinuchi")
    for k, key in (("mod_doron", "mod_hidden"), ("mod_abekobe", "mod_inverse"), ("mod_detarame", "mod_random"),
                   ("mod_kimagure", "mod_kimagure")):
        put_lang(sw, k, f_mod_key(key))
    for s in SPEED_MODS:
        sw.put(f"mod_speed_x{s}", f_mod(s.replace("_", ".")))
    # C++ asks for lane/auto_icon_<language> (player.cpp): one per language, Nijiiro's ja / en geometry
    for lang in ("ja", "en"):
        with lang_font(lang):
            sw.put(f"auto_icon_{lang}", f_auto(lang))
    for lang in ("zh", "ko"):
        put_lang_as(sw, "auto_icon_ja", f"auto_icon_{lang}", f_auto(lang), lang)
    sw.put("mod_baisaku", f_mod("×2"))
    sw.put("mod_sanbai", f_mod("×3"))
    sw.put("mod_yonbai", f_mod("×4"))
    sw.put("timer", f_timer_bar)
    return sw.write()


# ================================================================== judgements + hit effects
JUDGE = {"good": C["clear"], "ok": PAPER, "bad": C["bad"]}   # strings good / ok / bad


def f_judge(kind):
    def factory(lang):
        def draw(i, n, w, h):
            s = tr(kind, lang)
            cv = Canvas(w, h)
            cv.text(w / 2, h / 2, s, fit(s, 48, w - 4 * U), JUDGE[kind], outline=U)
            return cv.result()
        return draw
    return factory


def ring_cells(cv, cx, cy, r, w, col, cell=U):
    """A pixel ring (outer radius r cells, w cells wide) centred on (cx, cy)."""
    x0, y0 = snap(cx - r * cell), snap(cy - r * cell)
    core = {(x + w, y + w) for x, y in deco.disc_cells(r - w)} if r > w else set()
    for x, y in deco.disc_cells(r):
        if (x, y) not in core:
            cv.rect(x0 + x * cell, y0 + y * cell, x0 + (x + 1) * cell, y0 + (y + 1) * cell, col)


def inked_ring(cv, cx, cy, r, w, col):
    ring_cells(cv, cx, cy, r + 1, w + 2, INK)
    ring_cells(cv, cx, cy, r, w, col)


def f_hit_flash(col, r, hi=None):
    """hit_effect_* (216x216, centred on the hit circle, drawn UNDER the notes): the impact flash, a
    filled pixel disc (ink ring, 1-cell highlight ring just inside) the size of the note (small r 19 /
    big r 28 cells). Our animation 77 shows it solid for 67 ms (4 frames), then it is gone."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        deco.pixdisc(cv, w / 2, h / 2, r, col, inner_ring=(hi or PAPER, 1) if hi is not False else None)
        # Nijiiro's outer ring of short rays, baked in here so the engine draws it UNDER the notes
        # (owner: notes above the rays); same colour as the disc, still (nothing grows)
        for a in RAY_ANG:
            _ray(cv, w / 2, h / 2, a, min(r + 5, 29), min(r + 10, 33), col)   # big: 29..33 inside the 216 frame
        return cv.result()
    return draw


# ---- the hit burst (Lua, game/ss_hit): frame-swapped pixel explosion over the notes, drawn by
# game/score_counter.lua on every scored hit. 4 frames x 33.3 ms (2 display frames each); the ring
# grows a constant 6 cells (18 px) per frame and thins 4 -> 3 -> 1 (paper) -> gone; 7 rays (0 / 45 /
# 90 deg, none straight up into the judgement mark) move out 6 cells per frame for 2 frames, then break
# into 2-cell shards at 38 / 40 cells. Everything stays inside 40 cells (120 px) of the centre, so the
# left edge stops at x 498, right of the HUD box (lane x 496).
BURST_CELLS = 96             # canvas 96 x 96 cells = 288 logical
BURST_SIZE = BURST_CELLS * U


def _stamp(cv, cx, cy, gx, gy, size, col, ink=True):
    """a size x size cell block at cell offset (gx, gy) from the centre, with a 1-cell ink ring."""
    x0, y0 = snap(cx + gx * U), snap(cy + gy * U)
    if ink:
        cv.rect(x0 - U, y0 - U, x0 + (size + 1) * U, y0 + (size + 1) * U, INK)
    if col is not None:
        cv.rect(x0, y0, x0 + size * U, y0 + size * U, col)


def _ray(cv, cx, cy, ang, r0, r1, col, size=2):
    pts = []
    for t in range(r0, r1 + 1):
        pts.append((round(math.cos(ang) * t - size / 2), round(math.sin(ang) * t - size / 2)))
    for gx, gy in pts:
        _stamp(cv, cx, cy, gx, gy, size, None)
    for gx, gy in pts:
        _stamp(cv, cx, cy, gx, gy, size, col, ink=False)


# 0 / 45 / 90 deg only (clean pixel lines); no ray straight up, where the judgement mark sits
RAY_ANG = [k * math.pi / 4 for k in range(8) if k != 6]


def burst_frames(col, col2=None):
    """the 4 hit frames (PHYSICAL images, BURST_SIZE square, centre = hit circle), after Nijiiro's
    outer_* ring: a STILL ring of short rays just outside the hit circle (nothing grows or flies over
    the notes), one colour from first to last frame (owner: 良 gold throughout, 可 paper throughout).
    Frames 0-2 rays r 25..30 cells, frame 3 only the tips (the ring goes out). col2 is unused."""
    out = []
    c = BURST_SIZE / 2
    for f in range(4):
        cv = Canvas(BURST_SIZE, BURST_SIZE)
        for a in RAY_ANG:
            if f < 3:
                _ray(cv, c, c, a, 25, 30, col)
            else:
                _stamp(cv, c, c, round(math.cos(a) * 30 - 1), round(math.sin(a) * 30 - 1), 2, col)
        out.append(cv.result())
    return out


def spark_frames():
    """drumroll / balloon hit: 3 frames x 33.3 ms, 4 paper + gold shards (3 / 3 / 2 cells) flying out 5 cells per frame."""
    out = []
    c = BURST_SIZE / 2
    for f in range(3):
        cv = Canvas(BURST_SIZE, BURST_SIZE)
        sz = 3 if f < 2 else 2
        for k in range(4):
            a = -math.pi / 4 + k * math.pi / 2 + (math.pi / 8 if k % 2 else 0)
            t = 24 + 5 * f
            _stamp(cv, c, c, round(math.cos(a) * t - sz / 2), round(math.sin(a) * t - sz / 2), sz,
                   C["clear"] if k % 2 == 0 else PAPER)
        out.append(cv.result())
    return out


def f_outer(col, r0, step):
    """outer_* (336x336 x4): a ring growing by `step` cells per frame, thinning out."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        r = r0 + i * step
        wd = max(1, 3 - i)
        inked_ring(cv, w / 2, h / 2, r, wd, col)
        # four corner sparks on the last two frames (pixel squares, not static: one-shot)
        if i >= 2:
            for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
                d = gfit((r + 4) * U * 0.72)
                x, y = gfit(w / 2 + dx * d), gfit(h / 2 + dy * d)
                cv.rect(x - U, y - U, x + 2 * U, y + 2 * U, INK)
                cv.rect(x, y, x + U, y + U, col)
        return cv.result()
    return draw


def f_burst_frames(nframes, r_max, col):
    """A pixel burst over n frames: 8 squares flying out, then the sparkle-burst shape fading."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        t = (i + 1) / n
        d = r_max * (0.25 + 0.75 * t)
        sz = 3 * U if t < 0.5 else (2 * U if t < 0.8 else U)
        for k in range(8):
            a = k * math.pi / 4
            x, y = gfit(w / 2 + math.cos(a) * d), gfit(h / 2 + math.sin(a) * d)
            cv.rect(x - U, y - U, x + sz + U, y + sz + U, INK)
            cv.rect(x, y, x + sz, y + sz, col if k % 2 == 0 else PAPER)
        if i < 4:
            deco.sparkle_burst(cv, w / 2, h / 2, i)
        return cv.result()
    return draw


def build_hit_effect(G):
    sw = SubsetWriter(G, SCREEN, "hit_effect")
    for k in ("ok", "bad"):
        put_lang(sw, f"judge_{k}", f_judge(k))
    # 良: 4 frames for the engine's texture_change 30, all the same gold mark (owner: one colour from start
    # to end, no paper flash frame)
    g = sw.geo("judge_good")
    jw, jh = g.frames[0]
    ent = {"x": g.entry["x"] if isinstance(g.entry, dict) else g.entry[0]["x"],
           "y": g.entry["y"] if isinstance(g.entry, dict) else g.entry[0]["y"]}

    def judge_good(lang):
        s_ = tr("good", lang)
        ims = []
        for i in range(4):
            cv = Canvas(jw, jh)
            cv.text(jw / 2, jh / 2, s_, fit(s_, 48, jw - 4 * U), C["clear"], outline=U)
            ims.append(cv.result())
        return ims
    put_custom_lang(sw, "judge_good", judge_good, {l: ent for l in ("ja",) + VAR_LANGS})
    sw.put("hit_effect_good", f_hit_flash(C["clear"], 19, hi=False))
    sw.put("hit_effect_ok", f_hit_flash(PAPER, 19, hi=False))
    sw.put("hit_effect_good_big", f_hit_flash(C["clear"], 28, hi=False))
    sw.put("hit_effect_ok_big", f_hit_flash(PAPER, 28, hi=False))
    # outer_* and outer_effect_* are drawn ADDITIVE and scaled by the engine: on the light theme that is
    # a white smear and blurred pixels, so they stay empty (the ring flash above is the hit)
    for k in ("outer_good", "outer_ok", "outer_good_big", "outer_ok_big"):
        sw.put_blank(k)
    sw.put("firework", f_burst_frames(13, 100, C["clear"]))
    sw.put("explosion", f_burst_frames(23, 120, C["clear"]))
    sw.put_blank("outer_effect_ok")
    sw.put_blank("outer_effect_good")
    n = sw.write()
    # the Lua hit burst (game/score_counter.lua): centred on the hit circle by the script
    own = OwnSubset(G, SCREEN, "ss_hit")
    own.add("good", burst_frames(C["clear"], PAPER))
    own.add("ok", burst_frames(PAPER, C["line"]))
    own.add("roll", spark_frames())
    return n + own.write()


# ================================================================== soul gauge
# 1200x84 frame at (720, -72) lane-relative. Local (frame) layout, all on U:
#   cells: x 18 + 21k (50 cells of 7U), track rows 45..78, clear zone rows 12..78
#   soul ring at the right end (tamashii 88x88 at 1790,-74 = local 1070..1158, -2..86)
GX0, GCELL, GN = 18, 21, 50
G_TRACK = (45, 78)
G_ZONE = (12, 78)
CLEAR_CELL = {"easy": 29, "normal": 34, "hard": 39}   # first cell of the clear zone (Nijiiro's art)


def zone_x(tier):
    return GX0 + CLEAR_CELL[tier] * GCELL


def gauge_outline(cv, tier):
    """the stepped gauge silhouette (track + taller clear zone): 1U ink frame + 1U shadow."""
    zx = zone_x(tier)
    x1 = GX0 + GN * GCELL
    for off in (U, 0):
        cv.rect(GX0 - U + off, G_TRACK[0] - U + off, x1 + U + off, G_TRACK[1] + U + off, INK)
        cv.rect(zx - U + off, G_ZONE[0] - U + off, x1 + U + off, G_ZONE[1] + U + off, INK)


def f_g_border(tier):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        gauge_outline(cv, tier)
        zx = zone_x(tier)
        x1 = GX0 + GN * GCELL
        cv.rect(GX0, G_TRACK[0], x1, G_TRACK[1], (0, 0, 0, 0))
        cv.rect(zx, G_ZONE[0], x1, G_ZONE[1], (0, 0, 0, 0))
        return cv.result()
    return draw


def f_g_unfilled(tier):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        zx = zone_x(tier)
        x1 = GX0 + GN * GCELL
        gauge_outline(cv, tier)
        cv.rect(GX0, G_TRACK[0], x1, G_TRACK[1], C["bg3"])
        cv.rect(zx, G_ZONE[0], x1, G_ZONE[1], C["bg2"])
        cv.rect(zx, G_TRACK[0], x1, G_TRACK[1], C["bg3"])
        cv.rect(zx, G_ZONE[0], x1, G_ZONE[0] + U, C["clear"])      # the clear zone's gold top edge
        return cv.result()
    return draw


def f_g_overlay(tier):
    """owner 10-29 "no grid cells": the gauge reads as one continuous bar. No per-cell dividers and no
    split inside the clear zone; the only mark left is the 1U ink clear-threshold line where the zone
    starts (the silhouette's step, carried down through the track). gauge.lua draws it at full opacity."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        zx = zone_x(tier)
        cv.rect(zx, G_ZONE[0], zx + U, G_TRACK[1], INK)
        return cv.result()
    return draw


RB_BOUNDS = [0, 8, 16, 25, 33, 41, 50]


def rainbow_blocks(cv, x0, zx, rows_track, rows_zone):
    """6 flat blocks (course hues + gold) on cell boundaries over the track and the zone."""
    for b in range(6):
        xa, xz = x0 + RB_BOUNDS[b] * GCELL, x0 + RB_BOUNDS[b + 1] * GCELL
        cv.rect(xa, rows_track[0], xz, rows_track[1], RAINBOW6[b])
        za = max(xa, zx)
        if za < xz:
            cv.rect(za, rows_zone[0], xz, rows_zone[1], RAINBOW6[b])


def f_g_rainbow(tier):
    # 1057x78 x8 at (731,-67): frame-local = gauge-local - (13, 5); every frame identical (no sweep)
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        dx, dy = 731 - 720, -67 + 72
        rainbow_blocks(cv, GX0 - dx, zone_x(tier) - dx, (G_TRACK[0] - dy, G_TRACK[1] - dy),
                       (G_ZONE[0] - dy, G_ZONE[1] - dy))
        return cv.result()
    return draw


def f_cell(color):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        cv.rect(0, 0, w, h, color)
        return cv.result()
    return draw


def f_clear_mark(i, n, w, h):
    # bar_clear_transition 24x72 at (738,-63): gauge-local rows 9..81 -> the zone's first cell, gold
    cv = Canvas(w, h)
    cv.rect(0, G_ZONE[0] - 9, GCELL, G_ZONE[1] - 9, C["clear"])
    return cv.result()


SOUL_R = 12   # cells of U


def soul(cv, cx, cy, lit=True, flash=False):
    if flash:
        ring_cells(cv, cx, cy, SOUL_R + 1, 3, PAPER)
        return
    deco.pixdisc(cv, cx, cy, SOUL_R, PAPER if lit else C["bg3"], ring_w=1,
                 inner_ring=(C["clear"] if lit else C["line"], 2))
    # the word (魂 / Soul / 혼) is run-time text: game/gauge.lua (ss_soul_text)


def f_soul(lit=True, flash=False):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        soul(cv, gfit(w / 2), gfit(h / 2), lit, flash)
        return cv.result()
    return draw


FLAME = [
    ["....O.......", "...OO....O..", "...OYO..OO..", "..OYYO.OYO..", "..OYYOOYYO..", ".OYYWYOYYYO.",
     ".OYWWYYYWYO.", "OYYWWWYWWYYO", "OYWWWWWWWWYO", "OYWWWWWWWWYO", "OYYWWWWWWYYO", ".OYYWWWWYYO.",
     "..OOYYYYOO..", "....OOOO...."],
    ["........O...", "..O....OO...", "..OO..OYO...", "..OYO.OYYO..", "..OYYOOYYO..", ".OYYYOYWYYO.",
     ".OYWYYYWWYO.", "OYYWWYWWWYYO", "OYWWWWWWWWYO", "OYWWWWWWWWYO", "OYYWWWWWWYYO", ".OYYWWWWYYO.",
     "..OOYYYYOO..", "....OOOO...."],
]


def f_soul_fire(i, n, w, h):
    """tamashii_fire 320x320 x8: a pixel flame behind / above the soul ring, two shapes swapped every
    2 frames and lifted 1 cell on odd frames (frame-based flicker, drawn at scale 1)."""
    cv = Canvas(w, h)
    rows = FLAME[(i // 2) % 2]
    cell = 2 * U
    cx, base = 117, 192     # soul centre x in this frame (1834 - 1717); flame foot behind the ring top
    lift = cell if i % 2 else 0
    fw, fh = 12 * cell, 14 * cell
    deco.cells(cv, gfit(cx - fw / 2), gfit(base - fh) - lift, rows,
               {"O": C["gogo"], "Y": C["clear"], "W": PAPER}, cell, outline=INK)
    return cv.result()


def f_g_hit(i, n, w, h):
    """gauge/hit_effect x3, the note landing on the soul ring: frames 0-1 are drawn untinted at scale 1
    (animation 2, retimed to 50 ms each): 0 = a gold ring with 8 paper petals, 1 = the ring opened out
    to a paper ring with 8 gold shards (a constant 5-cell step). The engine scales, rotates and tints
    frame 2 red / cyan, so it stays empty."""
    cv = Canvas(w, h)
    c = (w / 2, h / 2)
    lim = int(min(w, h) / 2 / U) - 2
    if i < 2:
        r = min(20 + 5 * i, lim - 6)
        inked_ring(cv, c[0], c[1], r, 3 - 2 * i, C["clear"] if i == 0 else PAPER)
        t = min(r + 4, lim - 2)
        for k in range(8):
            a = k * math.pi / 4 + (math.pi / 8 if i else 0)
            sz = 2
            _stamp(cv, c[0], c[1], round(math.cos(a) * t - sz / 2), round(math.sin(a) * t - sz / 2), sz,
                   PAPER if i == 0 else C["clear"])
    return cv.result()


def build_gauge(G):
    sw = SubsetWriter(G, SCREEN, "gauge")
    for tier in ("easy", "normal", "hard"):
        sw.put(f"border_{tier}", f_g_border(tier))
        sw.put(f"1p_unfilled_{tier}", f_g_unfilled(tier))
        sw.put(f"2p_unfilled_{tier}", f_g_unfilled(tier))
        sw.put(f"overlay_{tier}", f_g_overlay(tier))
        sw.put(f"rainbow_{tier}", f_g_rainbow(tier))
    sw.put("bar_clear_transition", f_clear_mark)
    sw.put("bar_clear_top", f_cell(C["clear"]))
    sw.put("bar_clear_bottom", f_cell(C["clear"]))
    sw.put("1p_bar", f_cell(C["p1"]))
    sw.put("2p_bar", f_cell(C["p2"]))
    for k in ("bar_clear_transition_fade", "bar_clear_fade", "1p_bar_fade", "2p_bar_fade"):
        sw.put(k, f_cell(PAPER))
    sw.put("tamashii", f_soul(True))
    sw.put("tamashii_dark", f_soul(False))
    sw.put("tamashii_overlay", f_soul(True, flash=True))
    sw.put("tamashii_fire", f_soul_fire)
    sw.put("hit_effect", f_g_hit)
    sw.put_blank("hit_effect_circle")   # tinted by the engine; Nijiiro ships it empty too
    sw.put_blank("hit_effect_circle_big")
    # the clear label (lit: a gold chip sized to the word; dark: text2 word) is run-time text drawn by
    # game/gauge.lua at these keys' positions: the textures stay (positions), empty
    for k in ("clear_ja", "clear_dark_ja", "clear_en", "clear_dark_en"):
        sw.put_blank(k)
    return sw.write()


# ================================================================== combo
def digit_img(d, w, h, fill, outline=True, cell=2 * U):
    cv = Canvas(w, h)
    tw = deco.pixtext_width(d, cell, outline)
    th = (7 + (2 if outline else 0)) * cell
    deco.pixtext(cv, gfit((w - tw) / 2), gfit((h - th) / 2), d, cell, fill=fill,
                 outline=INK if outline else None, shadow=U if outline else 0)
    return cv.result()


def f_combo_digits(fill, outline):
    return lambda i, n, w, h: digit_img(str(i), w, h, fill, outline)


ANN_X = 264                  # announce_bg moved left so its tail reaches the portrait
ANN_BODY = (36, 36, 420, 144)  # bubble body inside the 560x240 frame
ANN_TAIL_Y = 99


def f_announce_bg(i, n, w, h):
    """announce_bg: a speech bubble (dialog chrome without a title) whose 3-step tail points left at
    the portrait mascot's mouth."""
    cv = Canvas(w, h)
    x0, y0, x1, y1 = ANN_BODY
    ty = ANN_TAIL_Y
    steps = [(x0 - 3 * U, 4 * U), (x0 - 6 * U, 2 * U), (x0 - 9 * U, 0)]   # (left x, half height)
    for off in (2 * U, 0):
        for xa, hh in steps:
            cv.rect(xa + off, ty - hh - U + off, xa + 3 * U + off, ty + hh + 2 * U + off, INK)
    chrome.frame(cv, x0, y0, x1, y1, PAPER, border=2 * U, shadow=2 * U, notch=U)
    for xa, hh in steps:
        cv.rect(xa + U, ty - hh, x0 + 2 * U, ty + hh + U, PAPER) if hh else None
    return cv.result()


def f_announce_digit(i, n, w, h):
    return digit_img(str(i), w, h, C["clear"], True, cell=3 * U)


def build_combo(G):
    sw = SubsetWriter(G, SCREEN, "combo")
    sw.put_blank("gleam")
    sw.put("counter", f_combo_digits(INK, False))
    sw.put("counter_100", f_combo_digits(PAPER, True))
    sw.put("counter_gold", f_combo_digits(C["clear"], True))
    for k in ("announce_bg_1p", "announce_bg_2p"):
        sw.put(k, f_announce_bg, entry={"x": ANN_X, "y": -264})
    sw.put("announce_number", lambda i, n, w, h: digit_img(str(i + 1), w, h, C["clear"], True, 3 * U))
    sw.put_blank("announce_add")
    # the words (コンボ under the digits, コンボ! in the announce bubble) are run-time text in the
    # player's language: game/combo.lua / combo_announce.lua draw them at these keys' rects
    for lang in ("ja", "en"):
        sw.put_blank(f"combo_{lang}")
        sw.put_blank(f"combo_100_{lang}")
    sw.put_blank("announce_text")
    sw.put("announce_digit_1p", f_announce_digit)
    sw.put("announce_digit_2p", f_announce_digit)
    n = sw.write()
    # 4+ digit combos: 1U-cell block digits (30x36 frames, glyph 21 wide) so 1000+ stays on the face;
    # combo.lua draws them (pitch 18: neighbouring ink outlines share one cell)
    own = OwnSubset(G, SCREEN, "ss_combo")
    for name, fill, outline in (("ink", INK, False), ("paper", PAPER, True), ("gold", C["clear"], True)):
        own.add("small_" + name, [digit_img(str(d), 10 * U, 12 * U, fill, outline, cell=U)
                                  for d in range(10)])
    return n + own.write()


# ================================================================== branch, song info, gogo
BRANCH = {"normal": ("branch_normal", "br_normal"), "expert": ("branch_expert", "br_expert"),
          "master": ("branch_master", "br_master")}


def f_branch_bg(key):
    """expert_bg / master_bg 16x200 at lane y 7 (stretched over the lane; the engine draws it at
    min(0.5, 1 - transition fade)): owner 10-29, like the arcade / Nijiiro the whole note band takes
    the branch colour (玄人 blue, 達人 pink) at half strength over the grey, and cross-fades on a branch
    change. A flat fill of the branch token over the note band rows (lane 12..207); the paper rim and
    the ink rows stay as they are."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        cv.rect(0, ROW_NOTE[0] - 7, w, ROW_SEAM[1] - 7, C[key])
        return cv.result()
    return draw


def f_branch_plate(kind):
    def factory(lang):
        def draw(i, n, w, h):
            skey, key = BRANCH[kind]
            s = tr(skey, lang)
            cv = Canvas(w, h)
            x1 = gfit(w) - 3 * U
            # a bg3 chip on the grey note band (the notes pass over it)
            b = chrome.frame(cv, 3 * U, 18, x1, 18 + 15 * U, C["bg3"], shadow=0, notch=0)
            cv.rect(b.ix0, b.iy0, b.ix0 + 2 * U, b.iy1, C[key])
            cv.text((b.ix0 + 2 * U + b.ix1) / 2, b.cy, s, fit(s, 24, b.ix1 - b.ix0 - 6 * U), INK)
            return cv.result()
        return draw
    return factory


def f_level(up):
    def factory(lang):
        def draw(i, n, w, h):
            cv = Canvas(w, h)
            s = tr("branch_up" if up else "branch_down", lang)
            b = chrome.panel(cv, 6, 12, gfit(w) - 6, 12 + 18 * U, fill=C["clear"] if up else C["bg3"])
            cv.text(b.cx, b.cy, s, fit(s, 36, b.ix1 - b.ix0 - 12), INK)
            return cv.result()
        return draw
    return factory


def build_branch(G):
    sw = SubsetWriter(G, SCREEN, "branch")
    sw.put("expert_bg", f_branch_bg("br_expert"))
    sw.put("master_bg", f_branch_bg("br_master"))
    for k in ("normal", "expert", "master"):
        put_lang(sw, k, f_branch_plate(k))
    put_lang(sw, "level_up", f_level(True))
    put_lang(sw, "level_down", f_level(False))
    return sw.write()


GENRE_BOX = (1599, 99, 264, 33)   # genre plate fill (logical x, y, w, h): under the title band, same right edge


def build_song_info(G):
    """song_info/genre (owner 10-29: the genre plate is back, as in Nijiiro). The engine draws it through
    its colortransform shader (song_info.cpp), which maps GENRE_PLATE_TEMPLATE_COLOR (60,103,0) exactly to
    the song's genre colour, then centres the genre name (white engine text, from the song data) on it.
    So the texture is a flat fill of that template colour (token genre_tpl): on screen it is the genre
    colour, flat. Its ink frame + hard shadow (which the shader would recolour) are drawn by
    score_counter.lua under it, from this key's rect. Title band right edge 1866, plate below it.
    The song-number cross-fade stays off (animation 3), so song_num_plate never shows."""
    sw = SubsetWriter(G, SCREEN, "song_info")
    x, y, w, h = GENRE_BOX
    cv = Canvas(w, h)
    cv.rect(0, 0, w, h, C["genre_tpl"])
    put_custom(sw, "genre", [cv.result()], entry={"x": x, "y": y})
    put_tiny(sw, "song_num_plate")
    return sw.write()


def flame_cells(cv, cx, foot, shape, cell, lift=0):
    rows = FLAME[shape % 2]
    fw, fh = 12 * cell, 14 * cell
    deco.cells(cv, gfit(cx - fw / 2), gfit(foot - fh) - lift, rows,
               {"O": C["gogo"], "Y": C["clear"], "W": PAPER}, cell, outline=INK)


FIRE_R0 = 27          # cells of U: the ring of fire starts just outside the hit circle's big-note ring
FIRE_ENTRY = {"x": JUDGE_X - 220, "y": NOTE_CY - 220}   # frame centre = hit-circle centre (lane-relative)


def fire_ring_cells(i):
    """{(cx, cy): colour} of the GOGO fire around the hit circle, frame i of 8 (owner 10-29: like the
    arcade / Nijiiro fireball): a burning ring hugging the circle (12 small tongues that step round and
    change height) plus a big plume of 3 tongues streaming up-right off the lane, flickering by frame.
    Gold core, gogo-orange outside, 1-cell ink outline. The ring keeps the target itself visible."""
    import math as _m
    plume = [(296, (16, 22, 18)), (318, (27, 21, 30)), (340, (15, 20, 12))]   # (angle, heights per phase)
    reach = FIRE_R0 + 3 + 32
    shape = {}
    for y in range(-reach, reach):
        for x in range(-reach, reach):
            d = _m.hypot(x + .5, y + .5)
            if d < FIRE_R0 or d > reach:
                continue
            ang = _m.degrees(_m.atan2(y + .5, x + .5)) % 360
            extra = 0.0
            for k in range(12):
                c = (k * 30 + (i % 2) * 15 + (i // 2) * 7) % 360
                dist = min(abs(ang - c), 360 - abs(ang - c))
                hgt = (1, 3, 2)[(k + i) % 3]
                extra = max(extra, hgt * max(0.0, 1 - dist / 11))
            for k, (c, hs) in enumerate(plume):
                c = c + (3 if (i + k) % 2 else -3)
                dist = min(abs(ang - c), 360 - abs(ang - c))
                hgt = hs[(i + k) % 3]
                extra = max(extra, hgt * max(0.0, 1 - dist / 15) ** 1.6)
            top = FIRE_R0 + 3 + round(extra)
            if d < top:
                core = FIRE_R0 + 1 + 0.45 * (top - FIRE_R0 - 1)
                shape[(x, y)] = C["clear"] if d < core else C["gogo"]
    out = dict(shape)
    for (x, y) in shape:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in shape and _m.hypot(q[0] + .5, q[1] + .5) >= FIRE_R0 - 1:
                out[q] = INK
    return out


def f_gogo_fire(i, n, w, h):
    """gogo_time/fire 440x440 x8 (our animation 24 keeps it at scale 1, game_gogo_fire_fade 1: solid),
    centred on the hit circle: the pixel fireball (ring + up-right plume), flickering by frame."""
    cv = Canvas(w, h)
    c = w // 2
    for (x, y), col in fire_ring_cells(i).items():
        cv.rect(c + x * U, c + y * U, c + (x + 1) * U, c + (y + 1) * U, col)
    return cv.result()


def f_gogo_explosion(i, n, w, h):
    """gogo_time/explosion 392x762 x30 (GOGO start, in the slots under the lane): a pixel rocket rises
    (frames 0-13), bursts (14-17, the big sparkle burst), then its sparks fall and go out."""
    cv = Canvas(w, h)
    cx = gfit(w / 2)
    top, bottom = 150, h - 30
    if i < 14:
        y = gfit(bottom - (bottom - top) * (i + 1) / 14)
        cv.rect(cx - 2 * U, y - U, cx + 3 * U, y + 4 * U, INK)
        cv.rect(cx - U, y, cx + 2 * U, y + 3 * U, C["clear"])
        for k in range(1, 4):
            ty = y + 3 * U + k * 6 * U
            if ty < bottom:
                sz = 2 * U if k == 1 else U
                cv.rect(cx, ty, cx + sz, ty + sz, C["gogo"] if k == 1 else C["clear"])
    elif i < 18:
        deco.sparkle_burst(cv, cx, top, i - 14, cell=4 * U)
    else:
        t = i - 18
        for k in range(8):
            a = k * math.pi / 4
            d = 60 + t * 9
            x = gfit(cx + math.cos(a) * d)
            y = gfit(top + math.sin(a) * d + t * t * 1.5)
            sz = 2 * U if t < 6 else U
            if y < h - 12:
                cv.rect(x - U, y - U, x + sz + U, y + sz + U, INK)
                cv.rect(x, y, x + sz, y + sz, RAINBOW6[k % 6] if t < 8 else PAPER)
    return cv.result()


def build_gogo(G):
    sw = SubsetWriter(G, SCREEN, "gogo_time")
    sw.put("fire", f_gogo_fire, entry=FIRE_ENTRY)
    # owner 10-29: the GOGO lane glows like the arcade. The engine draws lane_effect over the note band
    # (stretched to 1424x195, grown in by animation 76) at a fixed 0.5 alpha: a flat don-red fill, so
    # the grey band reads a warm red during GOGO (the one intentional half-alpha blend on this screen)
    sw.put("lane_effect", f_flat(C["don"]))
    sw.put("explosion", f_gogo_explosion)
    return sw.write()


# ================================================================== balloon, drumroll
def f_counter_digits(cell=3 * U, fill=PAPER):
    return lambda i, n, w, h: digit_img(str(i), w, h, fill, True, cell=cell)


def tail_down(cv, tx, y1):
    """3-step bubble tail (3U steps) under a dialog-weight bubble whose bottom edge is y1."""
    for off in (2 * U, 0):
        for k, ww in enumerate((6 * U, 4 * U, 2 * U)):
            yy = y1 - 2 * U + k * 3 * U
            cv.rect(tx - ww // 2 + off, yy + off, tx + ww // 2 + off, yy + 3 * U + off, INK)


def tail_down_fill(cv, tx, y1):
    for k, ww in enumerate((6 * U, 4 * U)):
        yy = y1 - 2 * U + k * 3 * U
        cv.rect(tx - ww // 2 + U, yy - (2 * U if k == 0 else 0), tx + ww // 2 - U, yy + 3 * U, PAPER)


def f_balloon_bubble(lang):
    """balloon/bubble 280x256 at (589,-253): a speech bubble over the hit circle holding the count,
    'あと' (balloon_left) on top; tail down at the hit circle (x 618 -> frame 29)."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        tail_down(cv, 33, 192)
        b = chrome.frame(cv, 15, 24, 255, 192, PAPER, border=2 * U, shadow=2 * U, notch=U)
        tail_down_fill(cv, 33, 192)
        s = tr("balloon_left", lang)
        cv.text(b.cx, b.iy0 + 18, s, fit(s, 24, b.ix1 - b.ix0 - 8 * U), C["text2"])
        return cv.result()
    return draw


def f_balloon_pop(i, n, w, h):
    """balloon/pop 384x360 x8 at (645,-81): frames 0-6 the balloon inflating (knot at the left edge,
    y 180), frame 7 the pop (a ring of flying squares around the burst)."""
    cv = Canvas(w, h)
    cy = 180
    if i < 7:
        r = [10, 13, 16, 19, 25, 30, 36][i]          # radius in cells of U
        cx = 24 + 3 + r * U
        cv.rect(0, cy - 2 * U, 15, cy + 2 * U, INK)
        cv.rect(0, cy - U, 15, cy + U, C["wood2"])
        cv.rect(12, cy - 4 * U, 27, cy + 4 * U, INK)
        cv.rect(15, cy - 3 * U, 24, cy + 3 * U, C["balloon"])
        deco.pixdisc(cv, cx, cy, r, C["balloon"], ring_w=1)
        hx, hy = gfit(cx + r * U * 0.3), gfit(cy - r * U * 0.55)
        cv.rect(hx, hy, hx + 3 * U, hy + 3 * U, PAPER)
        cv.rect(hx + 3 * U, hy + 3 * U, hx + 4 * U, hy + 4 * U, PAPER)
    else:
        for k in range(12):
            a = k * math.pi / 6
            x, y = gfit(192 + math.cos(a) * 130), gfit(cy + math.sin(a) * 130)
            cv.rect(x - U, y - U, x + 4 * U, y + 4 * U, INK)
            cv.rect(x, y, x + 3 * U, y + 3 * U, C["balloon"] if k % 2 else PAPER)
        deco.sparkle_burst(cv, 192, cy, 2, cell=4 * U)
    return cv.result()


def f_drumroll_bubble(lang):
    """drumroll_counter/bubble 464x272 at (296,-271): bubble over the drum (tail down at x 400 ->
    frame 104) with '連打' (roll, gold_t, 24) under the count."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        tail_down(cv, 105, 216)
        b = chrome.frame(cv, 66, 36, 399, 216, PAPER, border=2 * U, shadow=2 * U, notch=U)
        tail_down_fill(cv, 105, 216)
        s = tr("roll", lang)
        cv.text(b.cx, b.iy1 - 18, s, fit(s, 24, b.ix1 - b.ix0 - 8 * U), C["gold_t"])
        return cv.result()
    return draw


def build_balloon(G):
    sw = SubsetWriter(G, SCREEN, "balloon")
    put_lang(sw, "bubble", f_balloon_bubble)
    sw.put("pop", f_balloon_pop)
    sw.put("counter", f_counter_digits(2 * U, INK))
    sw.put_blank("rainbow")          # the bible keeps rainbows on the soul gauge only
    sw.put("explosion", f_burst_frames(13, 140, C["balloon"]))
    n = sw.write()
    sw = SubsetWriter(G, SCREEN, "drumroll_counter")
    put_lang(sw, "bubble", f_drumroll_bubble)
    sw.put("counter", f_counter_digits(3 * U, C["clear"]))
    return n + sw.write()


# ================================================================== skip, judge counter
def f_skip_panel(lang):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        chrome.dialog(cv, 18, 18, 984, 504, title=tr("skip", lang))
        return cv.result()
    return draw


def f_skip_number(i, n, w, h):
    return digit_img(str(i), w, h, C["clear"], True, cell=6 * U)


def f_skip_text(lang):
    """skip/text_<lang> (Nijiiro's enso_skip.lua asks for skip/text: tex.get_texture picks the
    language): the dialog sized to the line."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        s = tr("skip_used", lang)
        size = fit(s, 48, w - 30 * U)
        tw = cv.text_width(s, size)
        pw = gfit(tw + 24 * U)
        x0 = gfit((w - pw) / 2)
        b = chrome.dialog(cv, x0, 72, x0 + pw, 72 + 42 * U)
        cv.text(b.cx, b.cy, s, size, INK)
        return cv.result()
    return draw


def build_skip(G):
    sw = SubsetWriter(G, SCREEN, "skip")
    put_lang(sw, "panel", f_skip_panel, lua=True)      # Lua (enso_skip.lua) resolves panel_<lang>
    sw.put("number", f_skip_number)
    sw.put("dim", f_flat(INK))
    for lang in ("ja", "en", "zh"):
        with lang_font(lang):
            sw.put(f"text_{lang}", f_skip_text(lang))
    put_lang_as(sw, "text_ja", "text_ko", f_skip_text("ko"), "ko")
    return sw.write()


def text_digit(d, w, h, size=36, col=INK):
    cv = Canvas(w, h)
    cv.text(w / 2, h / 2, d, size, col)
    return cv.result()


def build_judge_counter(G):
    """Our judge_counter.lua (Scripts/game) draws the practice stats panel from chrome + UI.num / UI.label;
    Green's keys are never drawn: 1U blanks."""
    sw = SubsetWriter(G, SCREEN, "judge_counter")
    for k in ("bg", "judgments", "drumrolls", "total_percent", "percent", "counter"):
        put_tiny(sw, k)
    return sw.write()


# ================================================================== kusudama (own subset + kusudama_counter.lua)
KUSU_R = 30     # ball radius in cells of U (180 logical across)


def kusu_ball(stage, half=None):
    """The kusudama ball: gold top / don-red bottom, ink seam; the seam opens one cell wider per stage.
    half='l' / 'r' draws one opened half (for the pop)."""
    R = KUSU_R + 1
    W = 2 * R * U
    cv = Canvas(W + 2 * U, W + 12 * U)
    cx, cy = R * U + U, R * U + 12 * U
    x0, y0 = cx - R * U, cy - R * U
    inner = {(x + 1, y + 1) for x, y in deco.disc_cells(KUSU_R)}
    gap = min(stage, 5)
    for x, y in deco.disc_cells(R):
        if half == "l" and x >= R:
            continue
        if half == "r" and x < R:
            continue
        if (x, y) in inner:
            col = C["kusu"] if y < R else C["don"]
            if half is None and abs(x + 0.5 - R) <= gap * 0.5 and gap:
                col = INK
            if y in (R - 1,) and x % 4 in (0, 1):
                col = PAPER          # a dotted paper band at the equator
        else:
            col = INK
        cv.rect(x0 + x * U, y0 + y * U, x0 + (x + 1) * U, y0 + (y + 1) * U, col)
    if half is None:
        # the cord loop on top and the knot
        cv.rect(cx - 3 * U, y0 - 9 * U, cx + 3 * U, y0 + U, INK)
        cv.rect(cx - 2 * U, y0 - 8 * U, cx + 2 * U, y0, C["don"])
        cv.rect(cx - U, y0 - 12 * U, cx + U, y0 - 8 * U, INK)
    return cv.result()


def build_kusudama(G):
    own = OwnSubset(G, SCREEN, "ss_kusudama")
    own.add("ball", [kusu_ball(k) for k in range(6)])
    own.add("half_l", [kusu_ball(0, "l")])
    own.add("half_r", [kusu_ball(0, "r")])
    # the hint under the ball (連打で わろう!) is a dialog sized to the run-time text: kusudama_counter.lua
    own.add("digits", [digit_img(str(i), 21 * U, 30 * U, C["clear"], True, cell=3 * U) for i in range(10)])
    own.add("burst", deco.sparkle_frames(3 * U))
    n = own.write()
    # Nijiiro / Green kusudama keys are no longer referenced (our kusudama_counter.lua draws the above);
    # the small ones are replaced so nothing of theirs can show
    sw = SubsetWriter(G, SCREEN, "kusudama")
    from .atlas import subset_keys
    for k in subset_keys(SCREEN, "kusudama"):
        if k not in ("renda", "counter") and resolve(SCREEN, "kusudama", k):
            put_tiny(sw, k)      # Nijiiro's ball frames, Green's glow / lines / vignette / mascots
    sw.put("renda", lambda i, n_, w_, h_: blank_l(w_, h_))
    sw.put("counter", lambda i, n_, w_, h_: digit_img(str(i), w_, h_, C["clear"], True, cell=3 * U))
    return n + sw.write()


# ================================================================== practice (game_practice.cpp, re-placed for 1920)
# Green's practice keys keep their names; every one gets our size and position (entry overrides) for
# Nijiiro's 1920 layout. game_practice.cpp reads layout from the textures themselves:
#   * bar_count / bar_divider / dot / bar_count_bar advance = their frame width (so frames are sized
#     to the glyph advance: no letter-spacing), digits sit at progress_bar_bg.y + (bar h - frame h) / 2
#   * d1 at song_tempo right - 4, d2 at dot right - 4, the bar numbers right after bar_label
#   * cards / drums are drawn by index (0 = the player's station, 1 = the other), cards scaled about
#     their centre by the press animations
# Lower-right band (x 500-1920, y 573-1080; the stage is bare in practice): two drum stations standing
# on a stand at the ground line 1029, everything >= 48 px from the screen edges.
PR_BAR_Y, PR_BAR_H = 546, 30          # progress bar row (Green 364 x1.5; under the lane bottom 540)
PR_GROUND = 1029                      # the stations' feet
PR_STATIONS = (880, 1540)             # drum centre x per index
PR_FACE_R = 50                        # face radius in cells of U (150)
PR_DRUM_W, PR_DRUM_H = 330, 432       # drum frame; centre x at frame 165
PR_FACE_CY = 162                      # face centre inside the drum frame
PR_DRUM_Y = PR_GROUND - PR_DRUM_H + 3  # 600: the stand's feet end on the ground line
PR_CARD_W, PR_CARD_H = 120, 126       # button cards
PR_DIGIT_W, PR_DIGIT_H = 12, 30       # 24 px digits: advance 12


def text_box(s, size, panel=True, fill=None):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        if panel:
            b = chrome.panel(cv, 0, 0, gfit(w) - U, gfit(h) - U, fill=fill)
            cx, cy = b.cx, b.cy
        else:
            cx, cy = w / 2, h / 2
        cv.text(cx, cy, s, size if cv.text_width(s, size) < w - 12 else 18, INK)
        return cv.result()
    return draw


def pr_drum(kind=None, side=None):
    """A practice drum seen from the front: pixel face (U cells) on a wood barrel on a low stand;
    lit = the skin inside the rim band (don) or the rim band inside the ink, on its side (ka)."""
    cv = Canvas(PR_DRUM_W, PR_DRUM_H)
    cx, cy, r = PR_DRUM_W // 2, PR_FACE_CY, PR_FACE_R
    if kind is None:
        foot = PR_DRUM_H - 3
        # stand: two splayed wood2 legs (ink outlined) + a crossbar, feet on the frame bottom
        legs = []
        for sx in (-1, 1):
            for k in range(9):
                x = cx + sx * (60 + 6 * k) - (9 if sx < 0 else 0)
                legs.append((x, foot - 90 + 10 * k))
        for x, y0 in legs:
            cv.rect(x - 3, y0 - 3, x + 12, y0 + 13, INK)
        for x, y0 in legs:
            cv.rect(x, y0, x + 9, y0 + 10, C["wood2"])
        cv.rect(cx - 96, foot - 33, cx + 96, foot - 18, INK)
        cv.rect(cx - 93, foot - 30, cx + 93, foot - 21, C["wood2"])
        # barrel: the face disc shifted down, wood, rivets
        bh = 20 * U
        deco.pixdisc(cv, cx, cy + bh, r, C["wood"], ring_w=1)
        cv.rect(cx - (r + 1) * U, cy, cx + (r + 1) * U, cy + bh, C["wood"])
        cv.rect(cx - (r + 1) * U, cy, cx - r * U, cy + bh, INK)
        cv.rect(cx + r * U, cy, cx + (r + 1) * U, cy + bh, INK)
        for k in range(-7, 8):
            x = gfit(cx + k * 18)
            cv.rect(x, cy + bh + 3 * U, x + U, cy + bh + 4 * U, C["wood2"])
        deco.pixdisc(cv, cx, cy, r, PAPER, ring_w=1, inner_ring=(C["bg3"], 3))
        return cv.result()
    R = r + 5
    x0, y0 = cx - R * U, cy - R * U

    def disc(rr):
        o = R - rr
        return {(x + o, y + o) for x, y in deco.disc_cells(rr)}
    if kind == "don":
        lit = {c: C["don"] for c in disc(r - 3)}  # the drum skin inside the rim band: the don zone
    else:
        # the face's rim band inside its ink outline (between it and the skin), on the hit side: a ring
        # outside the ink (as on the small play drum) floated off the barrel of this large drum
        lit = {c: C["ka"] for c in disc(r) - disc(r - 3)}
    for (x, y), col in lit.items():
        if kind != "don" and (x < R) != (side == "l"):
            continue
        cv.rect(x0 + x * U, y0 + y * U, x0 + (x + 1) * U, y0 + (y + 1) * U, col)
    return cv.result()


def pr_card(label, icon):
    """A practice button card: bg2 button, 18 px label, the drum part to hit (don disc / ka ring)."""
    cv = Canvas(PR_CARD_W + U, PR_CARD_H + U)
    b = chrome.button(cv, 0, 0, PR_CARD_W, PR_CARD_H, None)
    cv.text(b.cx, b.iy0 + 7 * U, label, 18, INK)
    cv.rect(b.ix0, b.iy0 + 14 * U, b.ix1, b.iy0 + 15 * U, C["line"])
    if icon == "don":
        deco.pixdisc(cv, b.cx, b.iy0 + 27 * U, 9, C["don"], ring_w=1, inner_ring=(PAPER, 1))
    else:
        deco.pixdisc(cv, b.cx, b.iy0 + 27 * U, 9, PAPER, ring_w=1, inner_ring=(C["ka"], 3))
    return cv.result()


def pr_text(s, w, h=PR_DIGIT_H, size=24):
    cv = Canvas(w, h)
    cv.text(w / 2, h / 2, s, size, INK)
    return cv.result()


def pr_chip(s, accent, pad=2 * U):
    """A header chip (edge style, 18 px label) with `pad` transparent px on its right (the engine
    starts the following digit 4 px into the previous texture)."""
    tw = Canvas(1, 1).text_width(s, 18)
    cw = gfit(tw + 8 * U)
    cv = Canvas(cw + pad, PR_BAR_H)
    chrome.chip(cv, 0, 0, cw, None, s, accent=accent, edge=True)
    return cv.result(), cw + pad


def pr_marker(rows, pal):
    cv = Canvas(8 * U, 9 * U)
    deco.cells(cv, U, U, rows, pal, U, outline=INK)
    return cv.result()


FLAME_S = ["..O...", ".OYO..", ".OYYO.", "OYWYO.", "OYWWYO", "OYWWYO", ".OOOO."]
ARROW_S = ["YYYYYY", "YYYYYY", ".YYYY.", ".YYYY.", "..YY..", "..YY..", "......"]


def build_practice(G):
    sw = SubsetWriter(G, SCREEN, "practice")
    sw.put("progress_bar", f_flat(C["p1"]))
    sw.put("progress_bar_bg", f_flat(C["bg3"]))
    # markers stand on the bar row, centred on their time (the engine adds the bar offset to x)
    put_custom(sw, "gogo_marker", [pr_marker(FLAME_S, {"O": C["gogo"], "Y": C["clear"], "W": PAPER})],
               entry={"x": 501 - 12, "y": PR_BAR_Y})
    put_custom(sw, "jump_point_progress", [pr_marker(ARROW_S, {"Y": C["clear"]})],
               entry={"x": 501 - 12, "y": PR_BAR_Y})

    def arrow(i, n, w, h):
        cv = Canvas(w, h)
        rows = ["..XXXX..", "..XXXX..", "..XXXX..", "XXXXXXXX", ".XXXXXX.", "..XXXX..", "...XX..."]
        cell = gfit(min(w, h) / 10)
        deco.cells(cv, gfit(w / 2 - 4 * cell), gfit(h / 2 - 3.5 * cell), rows, {"X": C["clear"]}, cell, outline=INK)
        return cv.result()
    sw.put("jump_point_arrow", arrow)

    # the two drum stations
    st = [{"x": cx - PR_DRUM_W // 2, "y": PR_DRUM_Y} for cx in PR_STATIONS]
    put_custom(sw, "large_drum", [pr_drum()], entry=st)
    put_custom(sw, "large_drum_don", [pr_drum("don")], entry=st)
    put_custom(sw, "large_drum_kat_l", [pr_drum("ka", "l")], entry=st)
    put_custom(sw, "large_drum_kat_r", [pr_drum("ka", "r")], entry=st)
    # 演奏中 / the pause icon are drawn by C++ at a fixed 0.5 alpha (alpha policy: blank); the cards
    # (一時停止 <-> さいかい) already say which state the session is in
    put_tiny(sw, "playing")
    put_tiny(sw, "paused")

    # cards: don cards on the face (index = station), ka cards beside the rim (index = 2 * station + l/r)
    face_y = PR_DRUM_Y + PR_FACE_CY
    don_pos = [{"x": cx - PR_CARD_W // 2, "y": face_y - 33} for cx in PR_STATIONS]
    ka_pos = []
    for cx in PR_STATIONS:
        rim = PR_FACE_R * U + U
        ka_pos.append({"x": cx - rim - PR_CARD_W + 27, "y": face_y - PR_CARD_H - 15})
        ka_pos.append({"x": cx + rim - 27, "y": face_y - PR_CARD_H - 15})
    for k, skey, icon in (("pause_don", "pr_pause", "don"), ("resume_don", "pr_resume", "don"),
                          ("menu_don", "pr_menu", "don"), ("confirm", "pr_confirm", "don"),
                          ("finish", "pr_finish", "don"), ("delete", "pr_delete", "don"),
                          ("pause_kat", "pr_pause", "ka"),
                          ("speed_l_kat", "pr_slower", "ka"), ("speed_r_kat", "pr_faster", "ka"),
                          ("skip_l_kat", "pr_back", "ka"), ("skip_r_kat", "pr_forward", "ka")):
        pos = ka_pos if k.endswith("_kat") else don_pos
        put_custom_lang(sw, k, lambda lang, skey=skey, icon=icon: [pr_card(tr(skey, lang), icon)],
                        {lang: pos for lang in ("ja",) + VAR_LANGS})

    # header row on the progress bar's line: [曲テンポ] 1.0倍 [小節] 5/102, 2U clear after each chip
    # (the engine starts the tempo digit 4 px inside song_tempo, the bar count right at bar_label's edge).
    # The chips are sized to their word, so every language has its own x for the pieces after them
    # (the engine reads each piece's own rect: song_tempo_<lang>, dot_<lang>, multiplier_<lang> ...).
    hdr = {}
    for lang in ("ja",) + VAR_LANGS:
        with lang_font(lang):
            tempo, tw = pr_chip(tr("pr_tempo", lang), C["clear"], pad=2 * U + 4)
            d1_x = 6 + tw - 4
            dot_w = 8 + 4
            mul_x = d1_x + PR_DIGIT_W + dot_w - 4 + PR_DIGIT_W
            ms = tr("pr_times", lang)
            mul_w = -(-int(Canvas(1, 1).text_width(ms, 24)) // U) * U     # 倍 = 24; x = 12
            bar, _ = pr_chip(tr("pr_bar", lang), C["p1"], pad=2 * U)
            hdr[lang] = {"tempo": tempo, "d1_x": d1_x, "mul_x": mul_x, "mul": pr_text(ms, mul_w),
                         "bar": bar, "bar_x": gfit(mul_x + mul_w + 4 * U), "dot_w": dot_w}

    def row(name, field, x):
        put_custom_lang(sw, name, lambda lang: [hdr[lang][field]] if field else [pr_text(".", hdr[lang]["dot_w"])],
                        {lang: {"x": x(hdr[lang]), "y": PR_BAR_Y} for lang in hdr})
    row("song_tempo", "tempo", lambda h: 6)
    row("dot", None, lambda h: h["d1_x"] + PR_DIGIT_W)
    row("multiplier", "mul", lambda h: h["mul_x"])
    row("bar_label", "bar", lambda h: h["bar_x"])
    put_custom(sw, "bar_count", [pr_text(str(d), PR_DIGIT_W) for d in range(10)], entry={"x": 0, "y": 0})
    put_custom(sw, "bar_divider", [pr_text("/", PR_DIGIT_W)], entry={"x": 0, "y": 0})
    # bar numbers over the paused scrobble's bar lines: 18 px, advance 9
    put_custom(sw, "bar_count_bar", [pr_text(str(d), 9, 27, 18) for d in range(10)], entry={"x": 0, "y": 85})

    def menu_panel(key):
        def factory(lang):
            def draw(i, n, w, h):
                cv = Canvas(w, h)
                chrome.dialog(cv, 9, 9, gfit(w) - 9, gfit(h) - 9, title=tr(key, lang))
                return cv.result()
            return draw
        return factory
    # menu_panel = the in-song pause menu (C++ pause_menu.cpp, Esc): "メニュー / Menu / 菜单 / 메뉴"
    # (owner 10-29). menu_panel_practice = the same dialog titled "とっくんメニュー" for practice mode
    # only: practice_menu.lua asks for it (ss/v2_standalone.py SCRIPT_SUBS). _ja too for the Lua lookup.
    put_lang(sw, "menu_panel", menu_panel("pause_menu"), lua=True)
    for lang in ("ja",) + VAR_LANGS:
        put_lang_as(sw, "menu_panel", f"menu_panel_practice_{lang}", menu_panel("pr_menu_panel")(lang), lang)
    put_lang_as(sw, "menu_panel", "menu_panel_practice", menu_panel("pr_menu_panel")("ja"), "ja")

    def menu_bar(sel):
        def draw(i, n, w, h):
            cv = Canvas(w, h)
            chrome.button(cv, 0, 0, gfit(w) - U, gfit(h) - U, None, state="focused" if sel else "normal")
            return cv.result()
        return draw
    sw.put("menu_bar", menu_bar(False))
    sw.put("menu_bar_selected", menu_bar(True))
    sw.put("menu_button", menu_bar(False))
    sw.put("menu_button_selected", menu_bar(True))
    sw.put("menu_toggle", menu_bar(False))
    put_lang(sw, "menu_auto_label", lambda lang: text_box(tr("auto", lang), 36, fill=C["bg2"]), lua=True)

    def editing(lang):
        def draw(i, n, w, h):
            cv = Canvas(w, h)
            b = chrome.dialog(cv, 6, 6, gfit(w) - 9, gfit(h) - 9)
            s = tr("pr_jump_edit", lang)
            cv.text(b.cx, b.cy, s, fit(s, 36, b.ix1 - b.ix0 - 12 * U), INK)
            return cv.result()
        return draw
    put_lang(sw, "jump_point_editing", editing)
    return sw.write()


# ================================================================== AI battle (PyTaikoGreen geometry x1.5; AI_GAME only)
def build_ai(G):
    sw = SubsetWriter(G, SCREEN, "gauge_ai")
    TR, ZN = (57, 90), (24, 90)

    def unfilled(i, n, w, h):
        cv = Canvas(w, h)
        cv.rect(12 - U + U, TR[0] - U + U, 1056 + 2 * U, TR[1] + 2 * U, INK)
        cv.rect(12 - U, TR[0] - U, 1056 + U, TR[1] + U, INK)
        cv.rect(12, TR[0], 1056, TR[1], C["bg3"])
        return cv.result()
    for d in ("hard", "normal", "easy"):
        sw.put(f"1p_unfilled_{d}", unfilled)
        sw.put(f"2p_unfilled_{d}", unfilled)
        sw.put_blank(f"overlay_{d}")

        def rb(i, n, w, h):
            cv = Canvas(w, h)
            bw = (1056 - 12) // 6
            for k in range(6):
                cv.rect(12 + k * bw, TR[0], 12 + (k + 1) * bw if k < 5 else 1056, TR[1], RAINBOW6[k])
            return cv.result()
        sw.put(f"rainbow_{d}", rb)
    # Z-DON has no AI-battle scene: these keys are never drawn; kept wordless
    sw.put("clear", lambda i, n, w, h: _chip_img(w, h, None, C["clear"]))
    sw.put_blank("clear_dark")
    sw.put("bar_clear_transition", f_dg_rows(C["clear"], 6, 72))
    sw.put("bar_clear_top", f_cell(C["clear"]))
    sw.put("bar_clear_bottom", f_cell(C["clear"]))
    sw.put("1p_bar", f_cell(C["p1"]))
    sw.put("2p_bar", f_cell(C["p2"]))
    for k in ("bar_clear_transition_fade", "bar_clear_fade", "1p_bar_fade", "2p_bar_fade"):
        sw.put_blank(k)
    sw.put("tamashii", f_soul(True))
    sw.put("tamashii_dark", f_soul(False))
    sw.put("tamashii_overlay", f_soul(True, flash=True))
    sw.put("tamashii_fire", f_fire_at(192, 252))
    sw.put_blank("footer")
    n = sw.write()

    sw = SubsetWriter(G, SCREEN, "ai_battle")
    for k in ("bg_upper", "bg_outline_upper", "bg_lower", "lower_triangles_1", "lower_triangles_2"):
        sw.put_blank(k)

    def tile(col):
        def draw(i, n_, w, h):
            cv = Canvas(w, h)
            chrome.frame(cv, 3 * U, 3 * U, gfit(w) - 3 * U, gfit(h) - 3 * U, col, shadow=0, notch=U)
            return cv.result()
        return draw
    sw.put("red_tile_lower", tile(C["p1"]))
    sw.put("blue_tile_lower", tile(C["p2"]))
    sw.put("highlight_tile_lower", tile(C["clear"]))
    sw.put("red_tile_upper", tile(C["p1"]))
    sw.put("blue_tile_upper", tile(C["p2"]))
    sw.put("highlight_tile_upper", tile(C["clear"]))

    def board(accent):
        def draw(i, n_, w, h):
            cv = Canvas(w, h)
            b = chrome.panel(cv, 0, 0, gfit(w) - U, gfit(h) - U)
            cv.rect(b.ix0, b.iy0, b.ix0 + 2 * U, b.iy1, accent)
            rh = (b.iy1 - b.iy0) / 4
            for k in range(1, 4):      # four rows (good / ok / bad / roll), wordless (never drawn)
                y = gfit(b.iy0 + rh * k)
                cv.rect(b.ix0 + 4 * U, y, b.ix1 - 2 * U, y + U, C["line"])
            return cv.result()
        return draw
    sw.put("scoreboard", board(C["p1"]))
    sw.put("scoreboard_ai", board(C["p2"]))
    sw.put("scoreboard_num", lambda i, n_, w, h: text_digit(str(i), w, h, 24))

    def pbar(i, n_, w, h):
        cv = Canvas(w, h)
        chrome.pixbar(cv, 0, 12, gfit(w), 12 + 12 * U, 0.0, C["clear"])
        return cv.result()
    sw.put("progress_bar", pbar)
    sw.put("section_text", lambda i, n_, w, h: text_digit(f"{i + 1}", w, h, 24))

    DIA = ["...X...", "..XXX..", ".XXXXX.", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..."]

    def dia(col, mark=None):
        def draw(i, n_, w, h):
            cv = Canvas(w, h)
            cell = gfit(min(w, h) / 9)
            deco.cells(cv, gfit((w - 7 * cell) / 2), gfit((h - 7 * cell) / 2), DIA, {"X": col}, cell, outline=INK)
            if mark:
                cv.text(w / 2, h / 2, mark, 18, INK)
            return cv.result()
        return draw

    def sections(i, n_, w, h):
        cv = Canvas(w, h)
        cell = U * 2
        for k in range(5):
            x = gfit(12 + k * 31 * 1.5 * 0.66)
            deco.cells(cv, x, 24 + (k % 2) * 15, DIA, {"X": C["bg3"]}, cell, outline=INK)
        return cv.result()
    sw.put("sections", sections)
    sw.put("section_highlight_green", dia(C["grass"]))
    sw.put("section_highlight_white", dia(PAPER))
    sw.put("section_win", dia(C["clear"]))
    sw.put("section_lose", dia(C["bg3"]))
    return n + sw.write()


def _chip_img(w, h, s, accent):
    cv = Canvas(w, h)
    chrome.chip(cv, 0, gfit((h - 27) / 2), gfit(w), None, s, accent=accent)
    return cv.result()


# ================================================================== dan HUD
# Our dan_game_draw.lua draws the exam rows from rect chrome + the textures below (game/ss_dan, our
# own subset) in a compact layout that ends at y 852 (the stage module's dan strip + bubble live
# under it). Nijiiro's dan_info keys are no longer referenced except the two the background's dan_info
# module draws (gauge_border_plate / gauge_border_cell), which are replaced here.
# rank_<i> plates (engine dan_rank index; the rank words are strings.py keys, drawn by dan_game_draw.lua:
# keep its RANK_KEYS in this order): 五級 四級 三級 二級 一級 初段 二段 ... 十段 玄人 名人 超人 達人 創作 外伝
# 初級 十級 九級 八級 七級 六級
DAN_RANKS = ["dan_kyu_5", "dan_kyu_4", "dan_kyu_3", "dan_kyu_2", "dan_kyu_1", "dan_shodan", "dan_2", "dan_3",
             "dan_4", "dan_5", "dan_6", "dan_7", "dan_8", "dan_9", "dan_10", "dan_kuroto", "dan_meijin",
             "dan_chojin", "dan_tatsujin", "dan_sousaku", "dan_gaiden", "dan_shokyu", "dan_kyu_10", "dan_kyu_9",
             "dan_kyu_8", "dan_kyu_7", "dan_kyu_6"]


def dan_tier(i):
    if i <= 4 or i >= 21:
        return "wood"
    if i <= 9:
        return "hard"
    if i <= 14:
        return "don"
    if i <= 17:
        return "bg3"
    if i == 18:
        return "clear"
    return "wood2" if i == 19 else "grass2"


FRAME_TIER = ["wood", "wood", "hard", "don", "bg3", "clear", "grass2"]
DAN_PLATE = (270, 162)


def text_img(s, size, col=INK, pad=U, outline=0):
    cv0 = Canvas(1, 1)
    w = gfit(cv0.text_width(s, size) + 2 * pad + 2 * outline + U) + U
    h = gfit(size * 1.5) + 2 * outline
    cv = Canvas(w, h)
    cv.text(pad + outline, h / 2, s, size, col, anchor="lm", outline=outline)
    return cv.result()


def dan_plate(tier):
    """The dan exam header plate: the bible's dan accent (gold cap) on every rank; the tier colour (kyu
    wood, dan red, ...) only as the rank chip's 2U edge under the cap. Words are run-time text
    (dan_game_draw.lua): 段位道場 (24, ink) centred in the cap at plate (135, 24), the rank (48, ink) or
    the course title centred in the chip at (138, 103.5)."""
    w, h = DAN_PLATE
    cv = Canvas(w + U, h + U)
    b = chrome.panel(cv, 0, 0, w, h, fill=PAPER)
    cv.rect(b.ix0, b.iy0, b.ix1, b.iy0 + 14 * U, C["dan"])
    cv.rect(b.ix0, b.iy0 + 14 * U, b.ix1, b.iy0 + 15 * U, INK)
    x0, y0, x1, y1 = b.ix0 + 6 * U, b.iy0 + 18 * U, b.ix1 - 6 * U, b.iy1 - 3 * U
    r = chrome.frame(cv, x0, y0, x1, y1, C["bg3"], border=U, shadow=0, notch=0)
    cv.rect(r.ix0, r.iy0, r.ix0 + 2 * U, r.iy1, C[tier])
    return cv.result()


def build_dan(G):
    # exam labels, 以上 / 未満, のこり音符, the 達成失敗 stamp, the song badges and the plate words are
    # run-time text (dan_game_draw.lua); only the plates (no words) and the % sign stay baked
    own = OwnSubset(G, SCREEN, "ss_dan")
    own.add("pct", [text_img("%", 24)])
    for i in range(len(DAN_RANKS)):
        own.add(f"rank_{i}", [dan_plate(dan_tier(i))])
    for i, t in enumerate(FRAME_TIER):
        own.add(f"frame_{i}", [dan_plate(t)])
    n = own.write()

    sw = SubsetWriter(G, SCREEN, "dan_info")
    def plate(i, n_, w, h):
        # gauge_border_plate 602x76 (drawn at px-9, py-9; body 586x60), an arrow stepping down onto the
        # threshold at body x 562. The captions AND their ink chips are run-time, sized to the words in the
        # player's language: Scripts/background/bg_objects/dan_info.lua (one file in the stage module's
        # folder, owned by game: review r4 G3').
        cv = Canvas(w, h)
        chrome.panel(cv, 9, 9, 9 + 576, 9 + 54, fill=C["bg2"])
        for k, ww in enumerate((4 * U, 2 * U)):
            cv.rect(9 + 562 - ww // 2, 9 + 54 + k * U - U, 9 + 562 + ww // 2, 9 + 54 + (k + 1) * U - U, INK)
        return cv.result()
    sw.put("gauge_border_plate", plate)

    def cell(i, n_, w, h):
        # gauge_border_cell 28x61: its inside at (7, 7) lands on the threshold cell: ink frame, paper core
        cv = Canvas(w, h)
        cv.rect(4, 4, 25, 58, INK)
        cv.rect(7, 7, 22, 55, PAPER)
        return cv.result()
    sw.put("gauge_border_cell", cell)
    from .atlas import subset_keys
    for k in subset_keys(SCREEN, "dan_info"):
        if k not in sw.keys and resolve(SCREEN, "dan_info", k):
            put_tiny(sw, k)      # Nijiiro's dan HUD art: our dan_game_draw.lua uses game/ss_dan
    return n + sw.write()


DG_TRACK = (47, 80)     # dan gauge cell rows inside the 1200x88 border frame at (720, 202)


def f_dg_border(i, n, w, h):
    cv = Canvas(w, h)
    x1 = GX0 + GN * GCELL
    cv.rect(GX0 - U + U, DG_TRACK[0] - U + U, x1 + U + U, DG_TRACK[1] + U + U, INK)
    cv.rect(GX0 - U, DG_TRACK[0] - U, x1 + U, DG_TRACK[1] + U, INK)
    cv.rect(GX0, DG_TRACK[0], x1, DG_TRACK[1], C["bg2"])
    cv.rect(GX0, DG_TRACK[0], x1, DG_TRACK[0] + U, C["clear"])
    return cv.result()


def f_dg_rows(col, y0, y1, edge=None):
    """frames placed at y 242 (rows 7..40 = screen 249..282, the track) filled flat."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        cv.rect(0, y0, w, y1, col)
        if edge is not None:
            cv.rect(0, y0, w, y0 + U, edge)
        return cv.result()
    return draw


def f_dg_overlay(i, n, w, h):
    cv = Canvas(w, h)
    for k in range(1, GN):
        x = GX0 + k * GCELL
        cv.rect(x, 7, x + U, 40, INK)
    return cv.result()


def f_dg_rainbow(i, n, w, h):
    cv = Canvas(w, h)
    for b in range(6):
        xa, xz = GX0 + RB_BOUNDS[b] * GCELL, GX0 + RB_BOUNDS[b + 1] * GCELL
        cv.rect(xa, 7, xz, 40, RAINBOW6[b])
    return cv.result()


def f_fire_at(cx, base):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        flame_cells(cv, cx, base, i // 2, 2 * U, lift=(2 * U if i % 2 else 0))
        return cv.result()
    return draw


def build_gauge_dan(G):
    sw = SubsetWriter(G, SCREEN, "gauge_dan")
    sw.put("border", f_dg_border)
    sw.put("1p_unfilled", f_dg_border)
    sw.put("2p_unfilled", f_dg_border)
    sw.put("overlay", f_dg_overlay)
    sw.put("rainbow", f_dg_rainbow)
    sw.put("1p_bar", f_cell(C["p1"]))
    sw.put("2p_bar", f_cell(C["p2"]))
    for k in ("1p_bar_fade", "2p_bar_fade", "bar_fade_clear"):
        sw.put(k, f_dg_rows(PAPER, 8, 41))
    sw.put("tamashii", f_soul(True))
    sw.put("tamashii_dark", f_soul(False))
    sw.put("tamashii_overlay", f_soul(True, flash=True))
    sw.put("tamashii_fire", f_fire_at(1834 - 1698, 246 - 34 - 36))
    sw.put("track_red", f_dg_rows(C["bg3"], 7, 40, edge=C["p1"]))
    sw.put("1p_lamp", f_dg_rows(C["p1"], 7, 40))
    sw.put("2p_lamp", f_dg_rows(C["p2"], 7, 40))
    sw.put("lamp_clear", f_dg_rows(C["clear"], 7, 40))
    sw.put("hit_effect", f_g_hit)
    sw.put_blank("hit_effect_circle")
    sw.put_blank("hit_effect_circle_big")
    return sw.write()


# ================================================================== clips: ending banners, rank badges
# The background script (stage module) replays game/ending_anim/<name>.lua clips with the shapes in
# Graphics/game/<name>_anim/s<id> (Nijiiro's clip_player / ending / rank_badge / result_player).
# We regenerate every clip with our own frames and shapes: each shape is ours and is drawn at
# scale 1 (sx = sy = 1, no rotation, alpha 1), so pixel art stays whole; motion is frame-stepped
# integer offsets. Shape ids reuse the ids Nijiiro's clip used (so those keys are ours); Nijiiro's
# other shapes of a subset are never referenced again.
ANIM_DIR = "Scripts/game/ending_anim"
CLIP_HDR = ("-- GENERATED by ss/v2_game.py (YataiDONSimpleStyle) -- do not hand-edit.\n"
            "-- frames[f+1] = {{shape, tx, ty, sx, sy, rot_deg, alpha}, ...}; after the last frame the player\n"
            "-- continues from frames[loop_at+1].  shapes[c] = {w, h, ox, oy} (logical; ox/oy = origin).\n")


class Clip:
    def __init__(self, name, subset, stage, ids, frac=(0, 0)):
        self.name, self.subset, self.stage = name, subset, stage
        self.frac = frac      # fractional part of the clip's placement (ending: y 109.5): origins absorb it
        self.free = list(ids)
        self.extra = 900
        self.shapes = {}      # id -> (phys image, ox, oy)
        self.variants = {}    # id -> {lang: phys image (same size)}: s<id>_<lang> (Lua picks the language)
        self.frames = []

    def shape(self, im, ox=None, oy=None, sid=None):
        """register a PHYSICAL image; origin (logical) defaults to its centre. Returns the id."""
        if sid is None:
            if self.free:
                sid = self.free.pop(0)
            else:
                sid = self.extra
                self.extra += 1
        elif sid in self.free:
            self.free.remove(sid)
        w, h = im.width // style.D, im.height // style.D
        ox = gfit(w / 2) if ox is None else ox
        oy = gfit(h / 2) if oy is None else oy
        self.shapes[sid] = (im, ox + self.frac[0], oy + self.frac[1])
        return sid

    def frame(self, rows):
        self.frames.append(rows)

    def write(self, ctx, loop_at=None):
        own = OwnSubset(ctx.G, SCREEN, self.subset)
        for sid, (im, _, _) in self.shapes.items():
            own.add(f"s{sid}", [im])
            for lang, vim in self.variants.get(sid, {}).items():
                assert vim.size == im.size, (self.name, sid, lang)
                own.add(f"s{sid}_{lang}", [vim])
        # every ancestor shape our clip does not use: a 1U blank, so no Nijiiro art can show from any path
        from .atlas import subset_keys
        for k in subset_keys(SCREEN, self.subset):
            if k not in own.keys:
                own.add(k, [blank_l(U, U)])
        n = own.write()
        L = [CLIP_HDR, "return {", f"  nframes = {len(self.frames)},",
             f"  loop_at = {len(self.frames) - 1 if loop_at is None else loop_at},",
             f"  stage = {{{self.stage[0]}, {self.stage[1]}}},", "  shapes = {"]
        for sid in sorted(self.shapes):
            im, ox, oy = self.shapes[sid]
            L.append(f"    [{sid}] = {{{im.width // style.D}, {im.height // style.D}, {ox:g}, {oy:g}}},")
        L.append("  },")
        L.append("  frames = {")
        for rows in self.frames:
            L.append("    {" + ",".join("{%d,%g,%g,1,1,0,1}" % (s, x, y) for s, x, y in rows) + "},")
        L.append("  },")
        L.append("}")
        d = os.path.join(ctx.out, ANIM_DIR)
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, self.name + ".lua"), "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(L) + "\n")
        return n + 1


def nj_ids(name):
    import re
    from .atlas import ancestor_script
    p = ancestor_script(f"game/ending_anim/{name}.lua")
    with open(p, encoding="utf-8") as f:
        return sorted({int(x) for x in re.findall(r"\[(\d+)\] = \{", f.read())})


def burst_images(cell=2 * U):
    return deco.sparkle_frames(cell)


DROP = [(-3 * U), (-2 * U), (-U), U, 0]        # 3-frame drop, 1U settle, rest (bible 2.7)


def banner(text, fill, size=48, rainbow=False, w=None):
    """An ending banner: a panel (gold / bg3 / ...) with 48 px ink text; rainbow=True adds the 6-block
    rainbow as a top and bottom strip inside the border (full combo)."""
    tw = Canvas(1, 1).text_width(text, size)
    W = w or gfit(tw + 24 * U)
    H = 30 * U
    cv = Canvas(W + U, H + U)
    b = chrome.panel(cv, 0, 0, W, H, fill=fill)
    if rainbow:
        bw = (b.ix1 - b.ix0) / 6
        for k in range(6):
            xa, xb = gfit(b.ix0 + k * bw), (gfit(b.ix0 + (k + 1) * bw) if k < 5 else b.ix1)
            cv.rect(xa, b.iy0, xb, b.iy0 + 2 * U, RAINBOW6[k])
            cv.rect(xa, b.iy1 - 2 * U, xb, b.iy1, RAINBOW6[k])
        cv.rect(b.ix0, b.iy0 + 2 * U, b.ix1, b.iy0 + 3 * U, INK)
        cv.rect(b.ix0, b.iy1 - 3 * U, b.ix1, b.iy1 - 2 * U, INK)
    cv.text(b.cx, b.cy, text, size, INK)
    return cv.result()


def pad_x(im, left, total_w):
    """`im` (PHYSICAL) on a transparent canvas total_w LOGICAL wide, `left` LOGICAL px in."""
    out = style.blank(style.px(total_w), im.height)
    out.alpha_composite(im, (style.px(left), 0))
    return out


def ending_clip(ctx, name, key, fill, rainbow=False, bursts=True, sad=False):
    """The banner word is baked per language (the clip player is Nijiiro's Lua: s<id>_<lang>, tex.get_texture
    picks the player's). Each language's plate is sized to its own word; all variants share one canvas
    (the widest plate, centred) so the clip's origins hold, and the corner sparkles of each language
    sit on its own plate's corners (left / right sparkle shapes, shifted inside a padded canvas)."""
    c = Clip(name, name + "_anim", (1920, 264), nj_ids(name), frac=(0, 0.5))
    langs = ("ja",) + VAR_LANGS
    W = {}
    for lang in langs:
        with lang_font(lang):
            tw = Canvas(1, 1).text_width(tr(key, lang), 48)
        W[lang] = -(-int(tw + 24 * U) // (2 * U)) * (2 * U)      # even U count: the plate centres on U
    wmax = max(W.values())
    plates = {}
    for lang in langs:
        with lang_font(lang):
            im = banner(tr(key, lang), fill, rainbow=rainbow, w=W[lang])
        plates[lang] = pad_x(im, (wmax - W[lang]) // 2, wmax + U)
    plate = c.shape(plates["ja"])
    c.variants[plate] = {lang: plates[lang] for lang in langs}
    bw = wmax + U
    bh = c.shapes[plate][0].height // style.D
    sp, sp_l, sp_r = [], [], []
    if bursts:
        dmax = max((wmax - W[lang]) // 2 for lang in langs)
        for im in burst_images():
            w0 = im.width // style.D
            for side, lst in ((1, sp_l), (-1, sp_r)):   # left corners move right (inward), right ones left
                v = {lang: pad_x(im, dmax + side * (wmax - W[lang]) // 2, w0 + 2 * dmax) for lang in langs}
                sid = c.shape(v["ja"])
                c.variants[sid] = v
                lst.append(sid)
        sp = [sp_l, sp_r, sp_r, sp_l]
    # the plate's origin is its centre; clip (0, 0) = lane centre right of the hit circle (1209, lane+109.5)
    for f in range(240):
        rows = []
        if sad:   # slow sag: 6 frames per step down, settles 2U low
            dy = min(2 * U, (f // 6) * U) - 3 * U if f < 30 else -U
            dy = [-3 * U, -2 * U, -U, 0, U, 2 * U][min(5, f // 6)] if f < 36 else 2 * U
            rows.append((plate, 0, dy))
        else:
            dy = DROP[f] if f < len(DROP) else 0
            rows.append((plate, 0, dy))
            if sp:
                for k, (bx, by, t0) in enumerate(((-bw / 2 + 6, -bh / 2 + 6, 4), (bw / 2 - 6, bh / 2 - 6, 12),
                                                   (bw / 2 - 6, -bh / 2 + 6, 20), (-bw / 2 + 6, bh / 2 - 6, 28))):
                    t = (f - t0) // 4
                    if 0 <= t < 4:
                        rows.append((sp[k][t], gfit(bx), gfit(by)))
        c.frame(rows)
    return c.write(ctx)


def rank_clips(ctx):
    n = 0
    # HUD badge (rank_badge.lua: clip at (152, lane-118) for 1P / (152, lane+646) for 2P, plates 36..48
    # via shape_map from 36): docked on the portrait panel's top-right corner, pops in, bursts, holds.
    for name, nfr in (("rank_hud", 162), ("rank_hud_in", 30), ("rank_hud_out", 17)):
        c = Clip(name, name + "_anim", (498, 264), [])
        ids = [36, 38, 40, 42, 44, 46, 48]
        for k, sid in enumerate(ids):
            c.shape(course.rank_badge(k, 11, 36), sid=sid)
        sp = [c.shape(im) for im in burst_images()]
        tx, ty = 246 - 152, -108
        for f in range(nfr):
            dy = DROP[f] if f < len(DROP) else 0
            rows = [(36, tx, ty + dy)] if name != "rank_hud_out" else [(36, tx, ty + min(f, 3) * U)]
            t = (f - 4) // 4
            if name == "rank_hud" and 0 <= t < 4:
                rows.append((sp[t], tx + 27, ty - 27))
            c.frame(rows)
        n += c.write(ctx)
    # result screen badge (result_player.lua: rank 1-6 map plate 74/76 -> 74..86; 極 = kiwami clip, 86)
    for name in ("rank_result", "rank_result_kiwami"):
        c = Clip(name, name + "_anim", (1920, 1080), [])
        ids = [74, 76, 78, 80, 82, 84, 86]
        for k, sid in enumerate(ids):
            if name == "rank_result" or k == 6:
                c.shape(course.rank_badge(k, 21, 48), sid=sid)
        sp = [c.shape(im, sid=s) for im, s in zip(burst_images(3 * U), (36, 46, 89 if name == "rank_result" else 124,
                                                                         91 if name == "rank_result" else 126))]
        base = 74 if name == "rank_result" else 86
        for f in range(120):
            dy = DROP[f] if f < len(DROP) else 0
            rows = [(base if f < 3 else (76 if name == "rank_result" else 86), 0, dy)]
            for k, (bx, by, t0) in enumerate(((-48, -48, 4), (48, 42, 10))):
                t = (f - t0) // 4
                if 0 <= t < 4:
                    rows.append((sp[t], bx, by))
            c.frame(rows)
        n += c.write(ctx)
    return n


def build_clips(ctx):
    n = 0
    # the Green-era ending keys (ending_anim/*, ending_donderful/*) are read by PyTaikoGreen's
    # clear/fc/fail scripts, which ours replace (game/ss_ending.lua draws the clips): blank them so no
    # parent art can show from any path
    for sub in ("ending_anim", "ending_donderful"):
        from .atlas import subset_keys
        sw = SubsetWriter(ctx.G, SCREEN, sub)
        for k in subset_keys(SCREEN, sub):
            sw.put_blank(k)
        n += sw.write()
    n += ending_clip(ctx, "ending_clear", "end_clear", C["clear"])
    n += ending_clip(ctx, "ending_fullcombo", "end_full_combo", C["clear"], rainbow=True)
    n += ending_clip(ctx, "ending_donderful", "end_donderful", PAPER, rainbow=True)
    n += ending_clip(ctx, "ending_fail", "end_fail", C["bg3"], bursts=False, sad=True)
    n += rank_clips(ctx)
    return n


# ================================================================== module entry
LUA_SRC = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lua", "game", "game")


def copy_own_lua(ctx):
    """lua/game/game/** -> Scripts/game/** (see the module docstring)."""
    n = 0
    dst_root = os.path.join(ctx.scripts, "game")
    for root, _, files in os.walk(LUA_SRC):
        for f in files:
            rel = os.path.relpath(os.path.join(root, f), LUA_SRC)
            dst = os.path.join(dst_root, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(os.path.join(root, f), dst)
            n += 1
    return n


def build_animations(ctx):
    """Our own Graphics/game/animation.json: Nijiiro's file (it replaces the whole inherited file, so it
    is copied at build time and stays in sync) with the engine fades / scales that break the alpha
    and integer-scale rules changed. LOGICAL numbers (own file)."""
    with open(f"{NIJIIRO_G}/{SCREEN}/animation.json", encoding="utf-8") as f:
        anim = json.load(f)
    patch = {
        # lane flash: solid for 83 ms, then gone (was 0.3 -> 0 over 150 ms: a peach wash in dense play)
        0: {"initial_opacity": 1.0, "final_opacity": 0.0, "duration": 1, "delay": 83,
            "comment": "lane hit effect: solid 83 ms then off (SimpleStyle alpha policy)"},
        # drum hit: the lit ring shows 67 ms, then is gone (no translucent half-lit drum)
        1: {"duration": 1, "comment": "drum hit effect: hard off (SimpleStyle alpha policy)"},
        # song info: the title always shows; no genre / song-number cross-fade
        3: {"initial_opacity": 0.0, "final_opacity": 0.0, "duration": 1, "delay": 0, "loop": False,
            "reverse_delay": None, "comment": "song info: title fixed, no cross-fade (SimpleStyle)"},
        # drumroll bubble: hard off when the roll is over
        8: {"duration": 1, "comment": "drumroll counter: hard off (SimpleStyle alpha policy)"},
        # GOGO fire: drawn at scale 1 (Nijiiro pops 3.47 -> 1.35: non-integer scale on pixel art)
        24: {"initial_size": 1.0, "final_size": 1.0,
             "comment": "gogo fire: scale 1 (SimpleStyle integer scale)"},
        # polish 10-29: hit feedback in steps (alpha policy) on a steady 16.7 ms grid
        # gauge landing: frame 0 / 1 for 50 ms each, then the (empty, engine-tinted) frame 2
        2: {"duration": 116.67, "textures": [[0, 50, 0], [50, 100, 1], [100, 116.67, 2]],
            "comment": "gauge hit effect: 2 pixel burst frames, 50 ms each (SimpleStyle)"},
        # the note parked on the soul ring: shown 300 ms, then hard off (was an 83 ms alpha fade)
        33: {"duration": 1, "delay": 300.0, "comment": "gauge hit: hard off at 300 ms (SimpleStyle alpha policy)"},
        # judgement mark: on at once, held 300 ms, off at once (was 0.5 -> 1 -> 0)
        28: {"initial_opacity": 1.0, "final_opacity": 0.0, "duration": 1, "delay": 300, "reverse_delay": None,
             "comment": "judgment text: solid 300 ms, hard in / out (SimpleStyle alpha policy)"},
        # the mark pops up 1U (3 px) per frame for 3 frames, then holds
        29: {"duration": 50, "total_distance": -9, "start_position": 21,
             "comment": "judgment move: rises 9 px over 3 frames to Nijiiro's rest (+12), 1U per 16.7 ms"},
        # 良: gold from the first frame (the 4 frames are identical; no paper flash)
        30: {"duration": 183.3, "textures": [[0, 50, 0], [50, 100, 1], [100, 150, 2], [150, 183.3, 3]],
             "comment": "judgment frames: gold throughout (SimpleStyle)"},
        # the impact flash under the notes: solid 67 ms (4 frames), then off
        77: {"initial_opacity": 1.0, "final_opacity": 0.0, "duration": 1, "delay": 66.7,
             "comment": "hit flash: solid 67 ms then off (SimpleStyle alpha policy)"},
    }
    seen = set()
    for a in anim:
        p = patch.get(a.get("id"))
        if p:
            for k, v in p.items():
                if v is None:
                    a.pop(k, None)
                else:
                    a[k] = v
            seen.add(a["id"])
    missing = set(patch) - seen
    if missing:
        raise SystemExit(f"v2_game: Nijiiro game/animation.json lacks ids {sorted(missing)}")
    d = os.path.join(ctx.G, SCREEN)
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, "animation.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(anim, f, ensure_ascii=False, indent=1)
        f.write("\n")
    return 1


def build(ctx):
    G = ctx.G
    n = 0
    for fn in BUILDERS:
        n += fn(G)
    n += build_clips(ctx)
    n += build_animations(ctx)
    n += copy_own_lua(ctx)
    return n


BUILDERS = [build_notes, build_lane, build_hit_effect, build_gauge, build_combo, build_branch, build_song_info,
            build_gogo, build_balloon, build_skip, build_judge_counter, build_dan, build_gauge_dan,
            build_kusudama, build_practice, build_ai]


TITLE_RIGHT, TITLE_CY, TITLE_MAX = 1854, 54, 840
NAMEPLATE_X = 2 * U       # in-game nameplate left edge (Nijiiro: -44)   # engine title: right edge, centre y, max width


def skin_config(ctx):
    """Engine text on the play screen. Sizes are ENGINE sizes (role 36 title = engine 48, role 18 =
    engine 24: style.ENGINE_TEXT). The C++ title / song number have a fixed #000000 outline, so their
    outline is 0 and the title sits on our ink band (score_counter.lua), right-aligned, squeezed to
    TITLE_MAX at most (no clipping at the screen edge). Nijiiro's centring is off (width 0)."""
    return {
        "game_song_info": {"x": TITLE_RIGHT, "y": TITLE_CY, "font_size": style.ENGINE_TEXT[36], "outline": 0},
        "game_song_info_max_width": {"width": TITLE_MAX},
        "game_song_info_center": {"x": 0, "y": 0, "width": 0},
        "game_song_info_subtitle": {"y": 132, "font_size": style.ENGINE_TEXT[18], "outline": 0},
        "song_num_game": {"x": 1674, "y": 122, "outline": 0.0},
        "game_gogo_fire_fade": {"x": 1.0},
        # owner 10-29: the in-game nameplate's 1P / 2P badge was cut off at the left edge (Nijiiro's
        # x -44 suits its own art, not our 408 px plate whose badge cell starts at x 3): 2U in from the edge
        "nameplate": {"game_p1": [NAMEPLATE_X, 161], "game_p2": [NAMEPLATE_X, 7]},
        # the in-song pause menu (C++ pause_menu.cpp): its panel (practice/menu_panel) carries the title
        # (strings pause_menu: メニュー / Menu / 菜单 / 메뉴), so the engine's own white / #000000-outlined
        # "一時停止中" line under it is blanked (a space: an empty text would fall back to the built-in one)
        "pause_menu_title": {"text": {"ja": " ", "en": " ", "zh": " ", "ko": " "}},
    }
