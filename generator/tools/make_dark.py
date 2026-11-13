"""Assemble YataiDONSimpleStyleDark from three trees:

    L  = out/light_ref                  a light build of this generator  (python build.py; copy to out/light_ref)
    D  = out/YataiDONSimpleStyleDark    a dark build                      (python build.py --theme dark)
    I  = the installed YataiDONSimpleStyle (it may carry hand fixes made after the generator last ran)

Rules:
  * Graphics/: the whole of I's Graphics (the engine loads an ancestor skin's textures at density 1, so a
    density-2 skin cannot inherit textures from SimpleStyle), with every file that the dark build changed
    (D != L) replaced: binary files only where I == L (else reported as drift), text files 3-way merged
    (git merge-file I L D).
  * Scripts/, text_config.json: all of I's (a parent script's require() resolves in the parent's folder
    first, so it would never see the dark ss_def.lua), with the files the dark build changed merged the
    same way, then the literal ink / white text colours of the hand-written scripts recoloured.
  * Fonts/: copied from I (the engine does not look for the skin font in the parent).
  * Sounds/, Videos/: inherited (not written).
  * Graphics/skin_config.json: merged, then screen.parent = "YataiDONSimpleStyle".

    python tools/make_dark.py <installed SimpleStyle> <output folder>
"""
from __future__ import annotations

import filecmp
import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = os.path.join(HERE, "out", "light_ref")
D = os.path.join(HERE, "out", "YataiDONSimpleStyleDark")
TEXT_EXT = (".lua", ".json", ".txt", ".md")
# generated files the installed skin never edits by hand (it only lags the generator's new palette tokens)
TAKE_DARK = {"Scripts/global/ss_def.lua"}


def files(root, sub=""):
    out = set()
    base = os.path.join(root, sub)
    for r, _, fs in os.walk(base):
        for f in fs:
            out.add(os.path.relpath(os.path.join(r, f), root).replace("\\", "/"))
    return out


def same(a, b):
    return os.path.isfile(a) and os.path.isfile(b) and filecmp.cmp(a, b, shallow=False)


def merge3(i, l, d):
    """git merge-file -p I L D: I's edits plus the light->dark change. Returns (text, conflicts)."""
    with tempfile.TemporaryDirectory() as t:
        paths = []
        for n, src in (("i", i), ("l", l), ("d", d)):
            p = os.path.join(t, n)
            shutil.copyfile(src, p)
            paths.append(p)
        r = subprocess.run(["git", "merge-file", "-p", *paths], capture_output=True)
        return r.stdout, r.returncode


# Hand-written scripts of the installed skin colour text with literal ink / white tables. In the dark theme:
# ink text -> light ink; a white or ink OUTLINE -> the dark shade; secondary text -> light text2; the cream
# scrim -> night. Order matters (pairs before singles).
INK, LIGHT, SHADE, WHITE = "{ 58, 38, 51, 255 }", "{ 238, 230, 242, 255 }", "{ 11, 9, 16, 255 }", "{ 255, 255, 255, 255 }"
ON_ACC = "{ 36, 28, 44, 255 }"
LUA_RECOLOR = [
    # box_song.lua: course names on the course-coloured strips stay dark (on_acc)
    (f"or text.create_text(key, {INK}, {{ 255, 255, 255, 0 }}, false, 0, 1.0)",
     f"or text.create_text(key, {ON_ACC}, {{ 255, 255, 255, 0 }}, false, 0, 1.0)"),
    (f"lbl = text.create_text(key, {INK}, {{ 255, 255, 255, 0 }}, false, 0, 1.0)",
     f"lbl = text.create_text(key, {ON_ACC}, {{ 255, 255, 255, 0 }}, false, 0, 1.0)"),
    (f"{INK}, {INK}", f"{LIGHT}, {LIGHT}"),
    (f"{WHITE}, {INK}", f"{WHITE}, {SHADE}"),
    (INK + ",\n                                 " + WHITE, LIGHT + ",\n                                 " + SHADE),
    (f"{INK}, {WHITE}", f"{LIGHT}, {SHADE}"),
    (INK, LIGHT),
    ("{ 106, 88, 98, 255 }", "{ 210, 199, 218, 255 }"),
    ("{ 58, 38, 51, alpha }", "{ 11, 9, 16, alpha }"),
    ("local OPT_SCRIM         = { 255, 246, 229, 170 }", "local OPT_SCRIM         = { 27, 23, 36, 170 }"),
    ("402, 13, 255, 255, 255, 255)", "402, 13, 44, 38, 56, 255)"),
    ("lb.y2[1], 58, 38, 51, 127)", "lb.y2[1], 238, 230, 242, 127)"),
    # gold fills under ink text become the deep amber `focus` (light text reads on it)
    ("{ fill = D.P.clear, border = 2 * U, a = a }", "{ fill = D.P.focus, border = 2 * U, a = a }"),
    ("BAND_H, D.P.clear)", "BAND_H, D.P.focus)"),
    ("BAND_H, P.clear)", "BAND_H, P.focus)"),
    ("UI.chrome.chip(x, y, w, h, D.P.clear, false)", "UI.chrome.chip(x, y, w, h, D.P.focus, false)"),
    # ss_ui.lua: white ("paper" / "on_ink") text stays white, its outline dark; the hint bar is dark
    ('local STYLES = { ink = { "ink", false }, paper = { "paper", true }, on_ink = { "paper", false } }',
     'local STYLES = { ink = { "ink", false }, paper = { "n_rim", true }, on_ink = { "n_rim", false },\n'
     '                 on_acc = { "on_acc", false } }'),
    ("UI.rgba(col), UI.rgba(D.P.ink), false, th, 0)", "UI.rgba(col), UI.rgba(D.P.shade), false, th, 0)"),
    ("UI.frame(x, y, w, HD.h, { fill = D.P.ink })", "UI.frame(x, y, w, HD.h, { fill = D.P.hint_bg })"),
    ("UI.label(it[2], cx, cy, D.P.paper)", "UI.label(it[2], cx, cy, D.P.n_rim)"),
    # result: labels on gold / accent chips take the dark on_acc text (bg3 / edge chips keep light ink)
    ('UI.draw_text(UI.text_key(key, 18, style or "ink"), ix + iw / 2, iy + ih / 2, "c")',
     'UI.draw_text(UI.text_key(key, 18, style or ((accent and not edge and accent ~= P.bg3 and accent ~= P.paper)\n'
     '                                              and "on_acc" or "ink")), ix + iw / 2, iy + ih / 2, "c")'),
    ('local t = UI.text_key("best", 18, "ink")', 'local t = UI.text_key("best", 18, "on_acc")'),
    ('UI.num("+" .. tostring(self.score_diff), 72 + o + bw - 6, 294 + W.CH / 2, "s", P.ink, 255, "r")',
     'UI.num("+" .. tostring(self.score_diff), 72 + o + bw - 6, 294 + W.CH / 2, "s", P.on_acc, 255, "r")'),
    ('P.clear, "ink"', 'P.clear, "on_acc"'),
    # score_counter.lua: the song title band (white engine text) is a dark plate with a light border
    ("{ fill = P.ink, border = U, shadow = U, border_c = P.ink })", "{ fill = P.hint_bg, border = U, shadow = U, border_c = P.ink })"),
]
# the practice menu's WHITE, BLACK pair stays white text with a dark outline (rule 2)


def recolor_lua(I, O, report):
    for f in sorted(files(I, "Scripts")):
        if not f.endswith(".lua"):
            continue
        o = os.path.join(O, f)
        src = o if os.path.isfile(o) else os.path.join(I, f)
        with open(src, encoding="utf-8", newline="") as fh:
            s = fh.read()
        t = s
        for a, b in LUA_RECOLOR:
            t = t.replace(a, b)
        if t != s:
            os.makedirs(os.path.dirname(o), exist_ok=True)
            with open(o, "w", encoding="utf-8", newline="") as fh:
                fh.write(t)
            report["recolored"].append(f)


def main():
    I, O = sys.argv[1], sys.argv[2]
    if os.path.exists(O):
        shutil.rmtree(O)
    os.makedirs(O)
    shutil.copytree(os.path.join(I, "Graphics"), os.path.join(O, "Graphics"))
    # the engine reads screen.font_base from the skin's own Fonts/ (no parent fallback): ship them
    shutil.copytree(os.path.join(I, "Fonts"), os.path.join(O, "Fonts"))
    # a script in the parent's folder require()s modules from the parent's folder first (script.cpp
    # skin_require), so the dark ss_def.lua only reaches the scripts that live in this skin: ship them all
    shutil.copytree(os.path.join(I, "Scripts"), os.path.join(O, "Scripts"))
    shutil.copyfile(os.path.join(I, "text_config.json"), os.path.join(O, "text_config.json"))
    readme = os.path.join(HERE, "README_dark.md")
    if os.path.isfile(readme):
        shutil.copyfile(readme, os.path.join(O, "README.md"))
    report = {"dark": 0, "merged": 0, "conflict": [], "drift": [], "gone": [], "recolored": []}

    changed = sorted(f for f in files(D) if not same(os.path.join(D, f), os.path.join(L, f))
                     and f.split("/")[0] in ("Graphics", "Scripts", "text_config.json"))
    for f in changed:
        d, l, i, o = (os.path.join(x, f) for x in (D, L, I, O))
        os.makedirs(os.path.dirname(o), exist_ok=True)
        if not os.path.isfile(i):
            if os.path.isfile(l):
                report["gone"].append(f)          # the installed skin dropped it
            else:
                shutil.copyfile(d, o)             # new in the dark build
                report["dark"] += 1
            continue
        if same(i, l) or not os.path.isfile(l) or f in TAKE_DARK:
            shutil.copyfile(d, o)
            report["dark"] += 1
        elif f.endswith(TEXT_EXT):
            text, rc = merge3(i, l, d)
            with open(o, "wb") as fh:
                fh.write(text)
            report["merged"] += 1
            if rc:
                report["conflict"].append(f)
        else:
            report["drift"].append(f)            # I != L and binary: needs a look

    recolor_lua(I, O, report)

    cfg_p = os.path.join(O, "Graphics", "skin_config.json")
    with open(cfg_p, encoding="utf-8") as fh:
        cfg = json.load(fh)
    cfg["screen"]["parent"] = "YataiDONSimpleStyle"
    with open(cfg_p, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(cfg, fh, ensure_ascii=False, indent=2)
        fh.write("\n")

    print(f"{len(changed)} files changed by the dark theme: {report['dark']} taken, {report['merged']} merged")
    for k in ("conflict", "drift", "gone", "recolored"):
        print(f"{k}: {len(report[k])}")
        for f in report[k]:
            print("   ", f)


if __name__ == "__main__":
    main()
