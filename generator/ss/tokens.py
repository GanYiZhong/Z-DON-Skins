"""Design tokens in three layers and the automated contrast check.

  primitive  (style.P: raw colours, named by what they are)
  semantic   (what a colour means: surface, on-surface, accent, course, judge, note)
  component  (where it is used: info panel label, song-select box title, ...)

`check()` computes the WCAG 2.x contrast ratio of every foreground/background pair the skin
actually draws (CONTRAST_PAIRS) and fails the build below the threshold of its kind:
  text  >= 4.5 : normal text (< 24 px regular / < 18.7 px bold)
  large >= 3.0 : large text (>= 24 px, or >= 18.7 px bold)
  ui    >= 3.0 : meaningful non-text UI (notes vs lane, gauge fill vs groove, focus rings, icons)
Run `python -m ss.tokens` (from the generator folder) for the table; build.py runs it every time
and rewrites the token tables in STYLE_GUIDE.md between the tokens markers.
"""
from __future__ import annotations

import os
import sys

from .style import P

SEMANTIC = {
    # surfaces, darkest first
    "surface.base": "bg0",
    "surface.panel": "bg1",
    "surface.raised": "bg2",
    "surface.chip": "bg3",
    "border.subtle": "line",
    # text / icons on surfaces
    "on-surface.primary": "text",
    "on-surface.secondary": "text2",
    "on-surface.muted": "mute",          # large text and decoration only
    "on-accent": "on_acc",                # ink text on a bright accent fill
    "on-dark": "paper",                  # white text on a saturated / ink fill
    "border.ink": "ink",                 # 8-bit outlines + hard shadows
    "surface.paper": "paper",
    "note.rim": "n_rim",
    # accents
    "accent.p1": "p1",
    "accent.p2": "p2",
    "accent.gold": "clear",
    "accent.gogo": "gogo",
    "text.gold": "gold_t",              # gold as TEXT (accent.gold is for fills with an ink outline)
    "text.blue": "blue_t",
    "text.red": "red_t",
    # courses
    "course.easy": "easy", "course.normal": "normal", "course.hard": "hard", "course.oni": "oni",
    "course.ura": "ura", "course.tower": "tower", "course.dan": "dan",
    # judgements
    "judge.good": "good", "judge.ok": "ok", "judge.bad": "bad",
    # notes
    "note.don": "don", "note.ka": "ka", "note.roll": "roll", "note.balloon": "balloon",
    # branches
    "branch.normal": "br_normal", "branch.expert": "br_expert", "branch.master": "br_master",
    # play lane (grey, owner 10-29)
    "surface.lane": "lane", "surface.lane.moji": "lane2",
}

COMPONENT = {
    "screen.bg": "surface.base",
    "band.bg": "surface.panel",
    "lane.bg": "surface.raised",
    "info-panel.bg": "surface.panel",
    "info-panel.label": "on-surface.secondary",
    "info-panel.value": "on-surface.primary",
    "info-panel.label.good": "judge.good",
    "info-panel.label.roll": "note.roll",
    "info-panel.rule": "border.subtle",
    "info-panel.bar.track": "surface.chip",
    "info-panel.bar.fill": "judge.good",
    "score.digits": "on-surface.primary",
    "combo.digits": "on-surface.primary",
    "combo.digits.100": "accent.gold",
    "judge.text.good": "judge.good",
    "judge.text.ok": "judge.ok",
    "judge.text.bad": "judge.bad",
    "player-badge.bg.1p": "accent.p1",
    "player-badge.bg.2p": "accent.p2",
    "player-badge.text": "on-accent",
    "gauge.fill.1p": "accent.p1",
    "gauge.fill.2p": "accent.p2",
    "gauge.clear": "accent.gold",
    "gauge.groove": "surface.base",
    "box.bg": "surface.panel",
    "box.title": "on-surface.primary",
    "box.subtitle": "on-surface.secondary",
    "box.focus": "accent.gold",
    "header.bg": "surface.panel",
    "header.title": "on-surface.primary",
    "footer.hint": "on-surface.secondary",
    "result.score": "on-surface.primary",
}

# (foreground semantic, background semantic, kind, where)
CONTRAST_PAIRS = [
    ("on-surface.primary", "surface.base", "text", "titles / values on the screen background"),
    ("on-surface.primary", "surface.panel", "text", "panel values, box titles"),
    ("on-surface.primary", "surface.raised", "text", "text on the lane / raised cards"),
    ("on-surface.primary", "surface.chip", "text", "chip labels"),
    ("on-surface.secondary", "surface.base", "text", "secondary text on the background"),
    ("on-surface.secondary", "surface.panel", "text", "info-panel labels, subtitles"),
    ("on-surface.secondary", "surface.raised", "text", "secondary text on raised cards"),
    ("on-surface.secondary", "surface.chip", "text", "secondary text on chips"),
    ("on-surface.muted", "surface.panel", "large", "large de-emphasised text (never small)"),
    ("judge.good", "surface.panel", "text", "良 label in the info panel"),
    ("text.gold", "surface.panel", "text", "連打 label in the info panel"),
    ("judge.good", "surface.raised", "large", "良 judgement over the lane"),
    ("judge.ok", "surface.raised", "large", "可 judgement over the lane"),
    ("judge.bad", "surface.raised", "large", "不可 judgement over the lane"),
    ("text.gold", "surface.panel", "text", "combo 100+ digits, ★ level, gold highlights"),
    ("on-dark", "accent.p1", "large", "1P badge text (bold)"),
    ("on-dark", "accent.p2", "large", "2P badge text (bold)"),
    ("on-accent", "accent.gold", "text", "dark text on gold chips (combo 100+ label chip)"),
    ("border.ink", "surface.paper", "text", "combo label on its white chip"),
    ("on-accent", "course.easy", "text", "dark text on course chips"),
    ("on-accent", "course.normal", "text", "dark text on course chips"),
    ("on-accent", "course.hard", "text", "dark text on course chips"),
    ("on-accent", "course.oni", "text", "dark text on course chips"),
    ("on-dark", "course.ura", "large", "white text on the ura chip"),
    ("note.don", "surface.raised", "ui", "don notes vs the lane"),
    ("note.ka", "surface.raised", "ui", "ka notes vs the lane"),
    ("accent.p1", "surface.base", "ui", "gauge fill vs groove"),
    ("accent.p2", "surface.base", "ui", "gauge fill vs groove (2P)"),
    ("border.ink", "surface.panel", "ui", "focus: gold fill always inside an ink outline"),
    ("border.subtle", "surface.base", "deco", "hairlines are decoration (no threshold)"),
    ("border.ink", "surface.base", "ui", "8-bit window outlines vs the screen"),
    ("border.ink", "surface.raised", "ui", "note / roll / balloon ink outline vs the lane"),
    ("border.ink", "surface.panel", "ui", "course dots, chips: every coloured mark has an ink outline"),
    # globals_ui (timer, nameplate, practice timer)
    ("border.ink", "surface.paper", "large", "timer digits on the white disc"),
    ("on-accent", "note.don", "large", "timer digits on the coral (<10 s) disc"),
    ("on-accent", "course.tower", "text", "nameplate title on the bronze bar"),
    ("on-dark", "course.ura", "large", "nameplate title on the ura bar (bold)"),
    ("text.gold", "surface.chip", "large", "practice mode chip"),
    # result / dan result
    ("judge.good", "surface.chip", "text", "result: 良 chip"),
    ("judge.ok", "surface.chip", "text", "result: 可 chip"),
    ("judge.bad", "surface.chip", "large", "result: 不可 chip, fail message"),
    ("text.gold", "surface.chip", "text", "result: 真打 chip, new-record badge, clear message"),
    ("text.blue", "surface.chip", "large", "result: almost-clear message"),
    ("on-accent", "course.dan", "text", "dan result: header pill"),
    ("on-accent", "note.balloon", "large", "result: revive burst text"),
    ("text.gold", "surface.base", "large", "dan result: pass stamp"),
    # core v2 fix: hint pill, course identity, rank badges, engine text helper (UI.text)
    ("on-dark", "border.ink", "text", "hint pill: 18 px paper labels on the ink bar (UI.hint)"),
    ("note.don", "border.ink", "ui", "hint drum: lit face on the ink bar"),
    ("note.ka", "border.ink", "ui", "hint drum: lit rim on the ink bar"),
    ("border.ink", "surface.chip", "text", "course chip: 18 px ink name on bg3 (course.chip)"),
    ("on-accent", "course.tower", "large", "rank badge iki (wood disc)"),
    ("on-accent", "accent.gold", "large", "rank badge miyabi (gold disc)"),
    ("on-dark", "border.ink", "large", "rank badge kiwami kanji / UI.text on_ink"),
    ("text.gold", "surface.raised", "text", "front: two-player bubble heading"),
    ("text.red", "surface.base", "text", "front: LIVE tag on the attract frame"),
    ("on-surface.primary", "surface.panel", "text", "front: settings description (engine draws black) on the white card"),
    # core dynamic text (UI.t / UI.label / UI.bubble: engine text in the player's language)
    ("on-surface.primary", "surface.panel", "text", "UI.bubble: 36 / 24 px ink text on the paper bubble"),
    ("on-surface.primary", "surface.chip", "text", "UI.label(key, 18, \"ink\") on chips"),
    # dan (dan select / retry game / game over)
    ("text.gold", "surface.base", "text", "dan: retry success text, game over line 2"),
    ("text.blue", "surface.base", "text", "dan: retry failure text"),
    ("on-surface.primary", "surface.base", "large", "dan: retry digits and ready text with a base outline"),
    # game: the grey lane (owner 10-29)
    ("note.rim", "surface.lane", "ui", "note paper rim vs the grey note band"),
    ("border.subtle", "surface.lane", "ui", "bar lines on the grey note band"),
    ("on-surface.primary", "surface.lane.moji", "text", "moji: 24 px ink note names on the grey strip"),
    ("on-surface.primary", "surface.chip", "text", "branch plate: ink name on bg3 over the grey band"),
]
THRESHOLD = {"text": 4.5, "large": 3.0, "ui": 3.0, "deco": 0.0}


def rgb(name_or_hex):
    h = P.get(name_or_hex, name_or_hex).lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def sem(s):
    return SEMANTIC[s]


def luminance(c):
    def ch(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (ch(v) for v in c)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def ratio(fg, bg):
    a, b = luminance(fg), luminance(bg)
    hi, lo = max(a, b), min(a, b)
    return (hi + 0.05) / (lo + 0.05)


def results():
    out = []
    for fg, bg, kind, where in CONTRAST_PAIRS:
        r = ratio(rgb(sem(fg)), rgb(sem(bg)))
        out.append((fg, bg, kind, where, r, r >= THRESHOLD[kind]))
    return out


def check(fail=True, verbose=True):
    bad = [x for x in results() if not x[5]]
    if verbose:
        for fg, bg, kind, where, r, ok in results():
            print(f"{'ok ' if ok else 'LOW'} {r:5.2f} ({kind:5} >= {THRESHOLD[kind]}) {fg} on {bg}  - {where}")
    if bad:
        msg = "contrast check failed:\n" + "\n".join(
            f"  {fg} on {bg}: {r:.2f} < {THRESHOLD[k]} ({where})" for fg, bg, k, where, r, _ in bad)
        if fail:
            raise SystemExit(msg)
        print(msg)
    return not bad


def markdown():
    L = ["### Primitive tokens (`ss/style.py` P, mirrored to Lua as `global/ss_def.lua` D.P)", "",
         "| token | hex |", "|---|---|"]
    L += [f"| `{k}` | `{v}` |" for k, v in P.items()]
    L += ["", "### Semantic tokens", "", "| semantic | primitive | hex |", "|---|---|---|"]
    L += [f"| `{k}` | `{v}` | `{P[v]}` |" for k, v in SEMANTIC.items()]
    L += ["", "### Component tokens", "", "| component | semantic | hex |", "|---|---|---|"]
    L += [f"| `{k}` | `{v}` | `{P[SEMANTIC[v]]}` |" for k, v in COMPONENT.items()]
    L += ["", "### Contrast check (generated; build fails below threshold)", "",
          "| foreground | background | kind | ratio | min | used for |", "|---|---|---|---|---|---|"]
    for fg, bg, kind, where, r, ok in results():
        L.append(f"| `{fg}` | `{bg}` | {kind} | {r:.2f}{'' if ok else ' **LOW**'} | {THRESHOLD[kind]} | {where} |")
    return "\n".join(L)


BEGIN, END = "<!-- tokens:begin -->", "<!-- tokens:end -->"


def update_style_guide(path):
    with open(path, encoding="utf-8") as f:
        s = f.read()
    block = BEGIN + "\n" + markdown() + "\n" + END
    if BEGIN in s and END in s:
        s = s[:s.index(BEGIN)] + block + s[s.index(END) + len(END):]
    else:
        s = s.rstrip() + "\n\n## Design tokens\n\n" + block + "\n"
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(s)


# ---------------------------------------------------------------- off-palette scan (bible 2.3)
def allowed_colours():
    """Every RGB a crisp PNG may contain: the palette P plus the mascot sprite palette."""
    from . import pixel
    out = {tuple(int(v.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)) for v in P.values()}
    out |= {c[:3] for c in pixel.PAL.values()}
    return out


def scan_png(path, allowed=None):
    """(count, example) of visible pixels whose RGB is not a palette colour."""
    import numpy as np
    from PIL import Image
    allowed = allowed or allowed_colours()
    with Image.open(path) as im:
        a = np.asarray(im.convert("RGBA"))
    px = a[a[..., 3] > 0][:, :3].astype(np.uint32)
    if not len(px):
        return 0, None
    packed = (px[:, 0] << 16) | (px[:, 1] << 8) | px[:, 2]
    vals, counts = np.unique(packed, return_counts=True)
    ok = np.array([((r << 16) | (g << 8) | b) for r, g, b in allowed], dtype=np.uint32)
    bad = ~np.isin(vals, ok)
    if not bad.any():
        return 0, None
    v = int(vals[bad][0])
    return int(counts[bad].sum()), "#%06X" % v


def scan_palette(written):
    """written: {png path: "crisp" | "smooth"} (atlas.WRITTEN). Smooth (anti-aliased note / lane)
    files are skipped. Returns [(path, count, example)] of offenders."""
    allowed = allowed_colours()
    out = []
    for path, mode in sorted(written.items()):
        if mode != "crisp" or not path.endswith(".png"):
            continue
        n, ex = scan_png(path, allowed)
        if n:
            out.append((path, n, ex))
    return out


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "--scan":
        # python -m ss.tokens --scan <dir>: scan every PNG under a folder (no smooth exemptions)
        allowed = allowed_colours()
        bad = 0
        for root, _, files in os.walk(sys.argv[2]):
            for f in files:
                if f.endswith(".png"):
                    n, ex = scan_png(os.path.join(root, f), allowed)
                    if n:
                        bad += 1
                        print(f"{os.path.join(root, f)}: {n} off-palette px, e.g. {ex}")
        print(f"{bad} file(s) with off-palette pixels")
        sys.exit(1 if bad else 0)
    ok = check(fail=False, verbose=True)
    sys.exit(0 if ok else 1)
