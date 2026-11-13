"""Shared Lua-facing textures and the generated Lua definitions file Scripts/global/ss_def.lua.

  Graphics/global/ss_ui        digits_s/m/l/xl (tabular pixel digits, 18/24/36/48 logical), burst (the 4-frame sparkle burst),
                               hint_drum (the hint pill drum, 2 states), wipe (checker-dither wipe rows)
  Graphics/global/ss_course    the course identity (ss/course.py): glyph_s/glyph_l, chip, zenryo, crown_s/crown_m,
                               rank_s/rank_l
  Graphics/ss_mascot/k<k>_<name>   one sprite (momo, hoshi, robo, <char>_<outfit>): every EXPR frame at sprite
                               scale k (3 / 6 / 9; frame folders: sampled whole, so pixels stay crisp at draw
                               scale 1). Loaded when the Lua first asks for it (UI.TM), not with a screen
All PNGs are PHYSICAL (x density); texture.json positions are physical too, ss_def.lua is LOGICAL."""
from __future__ import annotations

import os


from . import chrome, course, deco, mascot, pixel, style
from .atlas import OwnSubset
from .style import K_ALLOWED, MASCOT_K, P, Canvas, font

LANG = "ja"

# tabular digits + the few symbols the info panel needs; every glyph sits in a fixed cell
CHARS = "0123456789+-.%:/"
DIGIT_SIZES = {"s": 18, "m": 24, "l": 36, "xl": 48}
LABEL_SIZE = 18

LABELS = {
    "ja": {"good": "良", "ok": "可", "bad": "不可", "roll": "連打", "maxcombo": "最大コンボ", "acc": "精度",
           "bpm": "BPM", "time": "経過", "offset": "平均タイミング", "early": "早", "late": "遅",
           "level": "★", "course0": "かんたん", "course1": "ふつう", "course2": "むずかしい", "course3": "おに",
           "course4": "おに(裏)", "ms": "ms", "gauge": "魂ゲージ", "combo": "コンボ", "score": "スコア",
           # hint pill labels (UI.hint)
           "h_select": "えらぶ", "h_decide": "決定", "h_back": "もどる", "h_option": "オプション",
           "h_change": "かえる", "h_start": "スタート"},
    "en": {"good": "GOOD", "ok": "OK", "bad": "BAD", "roll": "ROLL", "maxcombo": "MAX COMBO", "acc": "ACCURACY",
           "bpm": "BPM", "time": "TIME", "offset": "AVG TIMING", "early": "EARLY", "late": "LATE",
           "level": "★", "course0": "EASY", "course1": "NORMAL", "course2": "HARD", "course3": "ONI",
           "course4": "URA ONI", "ms": "ms", "gauge": "SOUL", "combo": "COMBO", "score": "SCORE",
           "h_select": "SELECT", "h_decide": "DECIDE", "h_back": "BACK", "h_option": "OPTIONS",
           "h_change": "CHANGE", "h_start": "START"},
}


def _fp(size):
    """Logical size of one font pixel."""
    return style.phys_font_px(size) / 12 / style.D


def _adv(ch, size):
    return font(size).getlength(ch) / style.D


def _cell(size):
    """(w, h) LOGICAL of a digit cell: the widest glyph advance, the font's 16-row line."""
    fp = _fp(size)
    w = max(_adv(c, size) for c in CHARS)
    return int(round(w)), int(round(16 * fp))


def digit_frames(size):
    cw, ch = _cell(size)
    out = []
    for c in CHARS:
        cv = Canvas(cw, ch)
        a = _adv(c, size)
        cv.text((cw - a) / 2, ch / 2, c, size, (255, 255, 255, 255), anchor="lm")
        out.append(cv.result())
    return out


def label_frames(lang):
    keys = list(LABELS[lang].keys())
    cv0 = Canvas(1, 1)
    widths = [int(-(-cv0.text_width(LABELS[lang][k], LABEL_SIZE) // 1)) + 2 for k in keys]
    W = max(widths)
    H = int(round(16 * _fp(LABEL_SIZE)))
    ims = []
    for k in keys:
        cv = Canvas(W, H)
        cv.text(1, H / 2, LABELS[lang][k], LABEL_SIZE, (255, 255, 255, 255), anchor="lm")
        ims.append(cv.result())
    return keys, widths, ims, H


def hint_drum_frames():
    """The hint pill drum: frame 0 = "don" (face lit), 1 = "ka" (rim lit). 8x8 cells at k=3."""
    out = []
    for st in ("don", "ka"):
        cv = Canvas(chrome.HINT_ICON, chrome.HINT_ICON)
        chrome.hint_drum(cv, 0, 0, st)
        out.append(cv.result())
    return out


WIPE_W = 1920


def wipe_masks():
    """Ordered-dither rows for UI.wipe: one 1920 x 2U strip per (level 25/50/75 %, row parity),
    frame = (level - 1) * 2 + parity. Lua stacks 180 of them (a full-screen mask per level would cost
    ~100 MB of VRAM). White, tinted in Lua. Same masks as v2_meta's ss_meta/wipe (promoted)."""
    bayer = [[0, 2], [3, 1]]
    out = []
    cell = 2 * style.U
    for thr in (1, 2, 3):
        for par in (0, 1):
            cv = Canvas(WIPE_W, cell)
            for x in range(0, WIPE_W, cell):
                if bayer[par][(x // cell) % 2] < thr:
                    cv.rect(x, 0, x + cell, cell, style.C["paper"])
            out.append(cv.result())
    return out


CROWN_FRAMES = [("none", None)] + [("clear", i) for i in range(5)] + [("fc", None), ("dfc", None)]
RANK_SIZES = {"s": (11, 36), "l": (21, 48)}
CROWN_CELLS = {"s": style.U, "m": 2 * style.U}
GLYPH_CELLS = {"s": style.U, "l": 2 * style.U}


def _wordless(w, draw):
    cv = Canvas(w, chrome.CHIP_H)
    draw(cv)
    return cv.result()


def build_course(out_graphics, lang):
    o = OwnSubset(out_graphics, "global", "ss_course")
    for n, cell in GLYPH_CELLS.items():
        o.add("glyph_" + n, [course.glyph_image(i, cell) for i in range(5)], layout="dir")
    # no words baked (SCREEN_GUIDE_V2 §11): the chips are chrome only; UI.course.chip / UI.course.zenryo draw
    # the course name / 全良 as engine text in the player's language
    o.add("chip", [_wordless(course.CHIP_W, lambda cv, i=i: course.chip(cv, 0, 0, None, i, text=""))
                   for i in range(5)], layout="dir")
    o.add("zenryo", [_wordless(course.ZENRYO_W, lambda cv: chrome.chip(cv, 0, 0, course.ZENRYO_W, None, None,
                                                                         accent=style.C["clear"]))])
    for n, cell in CROWN_CELLS.items():
        o.add("crown_" + n, [course.crown_image(k, c, cell) for k, c in CROWN_FRAMES], layout="dir")
    for n, (r, size) in RANK_SIZES.items():
        o.add("rank_" + n, [course.rank_badge(t, r, size) for t in range(len(course.RANKS))], layout="dir")
    return o.write()


def lua_rgb(hexs):
    h = hexs.lstrip("#")
    return "{ %d, %d, %d }" % (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def write_def(scripts_dir, main_char, lang):
    keys, widths, _, lh = label_frames(lang)
    L = ["-- GENERATED by D:/YataiDON_agents/simplestyle (ss/ui.py): palette, grid, glyph metrics, labels,",
         "-- mascot geometry. All numbers are LOGICAL px (1920x1080). Do not edit by hand; rerun build.py.",
         "local D = {}",
         f"D.DENSITY = {style.D}   -- physical px per logical px of this skin's textures",
         f"D.U = {style.U}         -- chrome unit (logical)",
         "D.P = {"]
    for k, v in P.items():
        L.append(f"    {k} = {lua_rgb(v)},")
    L.append("}")
    L.append(f'D.CHARS = "{CHARS}"')
    L.append("D.DIGIT = {")
    for k, s in DIGIT_SIZES.items():
        cw, ch = _cell(s)
        adv = ", ".join(f'["{c}"] = {_adv(c, s):g}' for c in CHARS)
        L.append(f"    {k} = {{ w = {cw}, h = {ch}, size = {s}, adv = {{ {adv} }} }},")
    L.append("}")
    L.append("D.LABEL = {")
    for i, (k, w) in enumerate(zip(keys, widths)):
        L.append(f'    {k} = {{ frame = {i}, w = {w} }},')
    L.append("}")
    L.append(f"D.LABEL_H = {lh}")
    L.append(f"D.BURST = {{ frames = 4, ms = {deco.BURST_MS}, size = {7 * 2 * style.U} }}")
    C_ = chrome
    L.append(f"D.HINT = {{ h = {C_.HINT_H}, pad = {C_.HINT_PAD}, icon = {C_.HINT_ICON}, gap = {C_.HINT_GAP}, "
             f"sep = {C_.HINT_SEP}, cx = {C_.HINT_CX}, x1 = {C_.HINT_X1}, y1 = {C_.HINT_Y1}, size = {C_.HINT_LABEL} }}")
    L.append(f"D.WIPE = {{ cell = {2 * style.U}, w = {WIPE_W} }}")
    L.append(f"D.SCREEN_SCALE = {1920 / 1280:g}   -- engine screen_scale (width / 1280): it scales text outlines")
    L.append(f"D.TEXT_OUTLINE = {style.U * 1280 / 1920:g}   -- engine outline units for a 1U ink ring")
    L.append(f"D.BUBBLE = {{ pad = {C_.BUBBLE_PAD}, max_w = {C_.BUBBLE_MAX_W}, h = {26 * style.U}, "
             f"tail = {{ {', '.join(str(v) for v in C_.TAIL_STEPS)} }}, tail_h = {C_.BUBBLE_TAIL_H} }}")
    L.append("D.TEXT_ENGINE = { " + ", ".join(f"[{k}] = {v}" for k, v in style.ENGINE_TEXT.items()) +
             " }   -- text role size -> engine font size (em = 0.75 x engine size)")
    cw_s, ch_s = course.crown_size(CROWN_CELLS["s"])
    cw_m, ch_m = course.crown_size(CROWN_CELLS["m"])
    L.append("D.COURSE = {")
    L.append("    keys = { " + ", ".join(f'"{k}"' for k in course.KEYS) + " },   -- engine course 0..4 = keys[1..5]")
    L.append("    names = { " + ", ".join(f'"{course.name(i, lang)}"' for i in range(5)) + " },")
    L.append("    glyph = { " + ", ".join(f"{n} = {course.glyph_size(c)}" for n, c in GLYPH_CELLS.items()) + " },")
    L.append(f"    chip = {{ w = {course.CHIP_W}, h = {chrome.CHIP_H} }},")
    L.append(f"    zenryo = {{ w = {course.ZENRYO_W}, h = {chrome.CHIP_H} }},   -- the 全良 chip (gold): min width, grows with the text")
    L.append(f"    crown = {{ s = {{ w = {cw_s}, h = {ch_s} }}, m = {{ w = {cw_m}, h = {ch_m} }} }},")
    L.append("    crown_frame = { none = 0, clear = 1, fc = 6, dfc = 7 },   -- clear: 1 + course")
    L.append("    rank = { " + ", ".join(f"{n} = {course.rank_size(r)}" for n, (r, _) in RANK_SIZES.items()) + " },")
    L.append("    rank_kanji = { " + ", ".join(f'"{k}"' for k, _ in course.RANKS) + " },   -- tier 0..6")
    L.append("}")
    L.append("D.MASCOT = {")
    L.append(f'    main = "{main_char}", buddy = "{mascot.BUDDY if main_char == mascot.MAIN else mascot.MAIN}",')
    L.append(f"    cells = {pixel.N},")
    L.append("    k = { " + ", ".join(f"{n} = {k}" for n, k in MASCOT_K.items()) + " },")
    L.append("    k_baked = { " + ", ".join(str(k) for k in K_ALLOWED) + " },")
    L.append("    foot = { " + ", ".join(f"{c} = {r}" for c, r in pixel.FOOT.items()) + " },")
    L.append("    expr = { " + ", ".join(f"{e} = {i}" for i, e in enumerate(pixel.EXPR)) + " },")
    L.append("    outfits = { " + ", ".join(f'"{o}"' for o in pixel.OUTFITS["momo"]) + " },   -- outfit 1.. (0 = plain)")
    L.append("}")
    L.append("return D")
    os.makedirs(os.path.join(scripts_dir, "global"), exist_ok=True)
    with open(os.path.join(scripts_dir, "global", "ss_def.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L) + "\n")


def build(out_graphics, main_char="momo", lang="ja"):
    ui = OwnSubset(out_graphics, "global", "ss_ui")
    for k, s in DIGIT_SIZES.items():
        ui.add("digits_" + k, digit_frames(s))
    # the old baked label strip (global/ss_ui/labels) is gone: UI.label draws every key as engine text in the
    # player's language (ss/strings.py); D.LABEL keeps the ja widths for layouts that reserve room
    ui.add("burst", deco.sparkle_frames())
    ui.add("hint_drum", hint_drum_frames(), layout="dir")
    ui.add("wipe", wipe_masks(), layout="dir")
    n = ui.write()
    n += build_course(out_graphics, lang)
    # one folder per sprite and scale (Graphics/ss_mascot/k<k>_<name>/<name>): no screen loads the ss_mascot
    # folders, the Lua asks for the one it draws (UI.TM) and the engine loads it then, so only the shown
    # characters / outfits are in memory (every outfit at every scale was ~200 MB as RGBA)
    sprites = [(ch, None) for ch in (mascot.MAIN, mascot.BUDDY, "robo")]     # robo: the AI battle's opponent
    sprites += [(ch, o) for ch in (mascot.MAIN, mascot.BUDDY) for o in pixel.OUTFITS[ch]]  # <char>_<outfit id>
    for k in K_ALLOWED:
        for ch, o in sprites:
            name = ch if o is None else f"{ch}_{o}"
            m = OwnSubset(out_graphics, "ss_mascot", f"k{k}_{name}")
            m.add(name, [mascot.sprite(ch, e, k, outfit=o) for e in pixel.EXPR], layout="dir")
            n += m.write()
    return n
