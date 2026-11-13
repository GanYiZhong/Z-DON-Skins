"""Build the YataiDONSimpleStyle skin (v2: parent YataiDONNijiiro, 1920x1080 logical, texture density)
into out/YataiDONSimpleStyle.

    python D:/YataiDON_agents/simplestyle/build.py [--only core,smoke,...] [--density 2|1]
                                                   [--base nijiiro] [--lang ja|en] [--mascot M|H]
                                                   [--mockups]

--density 2 (default) is the 4K target: every PNG and texture.json number of this skin is PHYSICAL
(x2) and skin_config gets screen.texture_density = 2 (a Z-DON engine feature). --density 1 builds a
plain 1080p skin for engines without the feature.

The skin is assembled from screen modules (ss/<name>.py, registered in MODULES below). Each
module declares what it OWNS inside the output folder; a build wipes and rebuilds only the owned
paths of the selected modules, so `--only song_select` never touches other screens' output.
Graphics/skin_config.json is always rewritten from every module's fragment (cheap, and keeps it
consistent). See SCREEN_GUIDE.md for the module contract.

The contrast check (ss/tokens.py) runs on every build and fails it below the WCAG thresholds."""
from __future__ import annotations

import argparse
import importlib
import json
import os
import shutil
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

# --theme light|dark must be known before ss.style builds its palette (C), so it is read here
for _i, _a in enumerate(sys.argv):
    if _a == "--theme" and _i + 1 < len(sys.argv):
        os.environ["SS_THEME"] = sys.argv[_i + 1]
    elif _a.startswith("--theme="):
        os.environ["SS_THEME"] = _a.split("=", 1)[1]
THEME = os.environ.get("SS_THEME", "light")

from ss import atlas, style  # noqa: E402

SKIN_NAME = "YataiDONSimpleStyleDark" if THEME == "dark" else "YataiDONSimpleStyle"
OUT = os.path.join(HERE, "out", SKIN_NAME)
CACHE = os.path.join(HERE, "cache")

# build order matters only for modules that read another module's output (none do today).
# v2: only core + the smoke test are registered; the v1 Green-based modules (game, song_select,
# globals_ui, result, dan, front, ...) stay in ss/ for reference only (copy in cache/snap_green_l8).
MODULES = ["core",
           "v2_game",  # game agent: Graphics/game, Scripts/game (took over smoke)
           "v2_stage",  # stage agent: Graphics/background, Scripts/background
           "v2_front",  # front agent: title, entry, settings, loading, Videos, README
           "v2_result",  # result agent: Graphics/result/ss, Graphics/dan_result/ss, Scripts/result
           "v2_meta",  # meta agent: dan select, game over, retry, dan loading, Graphics/global + Scripts/global overlays
           "v2_song_select",  # song select agent: Graphics/song_select, Scripts/song_select (lua/song_select)
           "v2_standalone",  # no PyTaikoGreen at run time: inherited configs/scripts/texts/sounds (keep last)
]


class Ctx:
    def __init__(self, lang, main_char, density, base):
        self.out = OUT
        self.G = os.path.join(OUT, "Graphics")
        self.scripts = os.path.join(OUT, "Scripts")
        self.lang = lang
        self.main_char = main_char          # "momo" | "hoshi": the 1P / main character
        self.density = density              # physical px per logical px
        self.base = base                    # "nijiiro"
        self.cache = CACHE
        self.nijiiro_g = atlas.NIJIIRO_G
        self.green_g = atlas.GREEN_G
        self.here = HERE


def _rm(path):
    if os.path.isdir(path):
        shutil.rmtree(path)
    elif os.path.isfile(path):
        os.remove(path)


def copy_lua(ctx, mod):
    """lua/<module>/** -> Scripts/** (merged)."""
    src = os.path.join(HERE, "lua", mod.NAME)
    if not os.path.isdir(src):
        return 0
    n = 0
    for root, _, files in os.walk(src):
        for f in files:
            rel = os.path.relpath(os.path.join(root, f), src)
            dst = os.path.join(ctx.scripts, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(os.path.join(root, f), dst)
            n += 1
    return n


def patch_parent_lua(ctx, patches):
    """Copy the nearest ancestor's script (Nijiiro, then Green) and apply exact (old, new)
    replacements; fail loudly on a miss, unless the entry is (old, new, "optional") (the old text is
    something to take out that the parent may already have dropped)."""
    for rel, subs in patches.items():
        src = atlas.ancestor_script(rel)
        if src is None:
            raise SystemExit(f"Lua patch: no ancestor has Scripts/{rel}")
        with open(src, encoding="utf-8") as f:
            s = f.read()
        for a, b, *flags in subs:
            if a not in s:
                if "optional" in flags:
                    continue
                if os.environ.get("SS_LUA_STRICT", "") not in ("", "0"):
                    raise SystemExit(f"Lua patch target not found in {src}: {a!r}")
                # the parent moved on since this patch was written; the installed skin's Scripts are the
                # reference (tools/make_dark.py merges against them), so only warn
                print(f"warning: Lua patch target not found in {src}: {a[:60]!r}")
                continue
            s = s.replace(a, b)
        dst = os.path.join(ctx.scripts, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, "w", encoding="utf-8", newline="\n") as f:
            f.write(s)


def deep_merge(a, b):
    for k, v in b.items():
        if isinstance(v, dict) and isinstance(a.get(k), dict):
            deep_merge(a[k], v)
        else:
            a[k] = v
    return a


# zh is Traditional Chinese in Z-DON (upstream YataiDON's zh is Simplified): every zh string of our
# skin_config, ours and the parent's, goes through OpenCC s2twp (Taiwan forms and wording), then ZH_FIX
# (odd wording, and s2twp's computing terms where the UI means everyday words).
ZH_FIX = [("跳略演奏", "跳過演奏"), ("迴圈", "循環"), ("型別", "類型"), ("後臺", "背景"), ("訪問程式碼", "存取碼"),
          ("攝像頭", "攝影機"), ("芝士", "起司"), ("常規", "一般"), ("“", "「"), ("”", "」"),
          ("裡魔王", "裏魔王"), ("魔王(裡)", "魔王(裏)")]


def fix_zh_text(ctx, cfg):
    """Apply s2twp + ZH_FIX to every zh string in our skin_config, and pull in (whole) any parent entry
    whose zh needs a fix but that no module sets: the engine replaces a whole entry per key, so a
    text-only override would zero its x / y / font_size."""
    import opencc
    cc = opencc.OpenCC("s2twp")

    def fixed(s):
        s = cc.convert(s)
        for a, b in ZH_FIX:
            s = s.replace(a, b)
        return s
    with open(os.path.join(ctx.nijiiro_g, "skin_config.json"), encoding="utf-8") as f:
        parent = json.load(f)
    for k, v in parent.items():
        t = v.get("text") if isinstance(v, dict) else None
        if k not in cfg and isinstance(t, dict) and isinstance(t.get("zh"), str) and fixed(t["zh"]) != t["zh"]:
            cfg[k] = json.loads(json.dumps(v))   # Nijiiro is 1920 logical like us: no rescale
    for v in cfg.values():
        t = v.get("text") if isinstance(v, dict) else None
        if isinstance(t, dict) and isinstance(t.get("zh"), str):
            t["zh"] = fixed(t["zh"])


def write_skin_config(ctx, mods):
    cfg = {}
    for m in mods:
        if hasattr(m, "skin_config"):
            deep_merge(cfg, m.skin_config(ctx))
    fix_zh_text(ctx, cfg)
    os.makedirs(ctx.G, exist_ok=True)
    with open(os.path.join(ctx.G, "skin_config.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)
        f.write("\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="", help="comma-separated module names (default: all)")
    ap.add_argument("--lang", default="ja", choices=["ja", "en"],
                    help="language of texts that have no engine language variant")
    ap.add_argument("--mascot", default="M", choices=["M", "H"],
                    help="main (1P) character: M = Momo (default), H = Hoshi; the other is the buddy")
    ap.add_argument("--density", type=int, default=2, choices=[1, 2],
                    help="physical px per logical px of this skin's textures (2 = 4K, 1 = 1080p)")
    ap.add_argument("--base", default="nijiiro", choices=["nijiiro"], help="parent skin (only nijiiro)")
    ap.add_argument("--theme", default="light", choices=["light", "dark"],
                    help="light = YataiDONSimpleStyle; dark = the full art of YataiDONSimpleStyleDark "
                         "(tools/make_dark.py keeps only what differs from the light build)")
    ap.add_argument("--mockups", action="store_true",
                    help="also redraw mockups/v2_chrome.png and mockups/v2_mascot_frames.png")
    a = ap.parse_args()
    style.set_density(a.density)
    ctx = Ctx(a.lang, "momo" if a.mascot == "M" else "hoshi", a.density, a.base)
    t0 = time.time()

    all_mods = [importlib.import_module("ss." + n) for n in MODULES]
    for m in all_mods:
        if hasattr(m, "configure"):
            m.configure(ctx)
    only = [x.strip() for x in a.only.split(",") if x.strip()]
    unknown = [x for x in only if x not in MODULES]
    if unknown:
        raise SystemExit(f"unknown module(s): {unknown}; known: {MODULES}")
    if only and "v2_standalone" not in only:
        only.append("v2_standalone")   # it writes into other modules' folders, which --only wipes
    sel = [m for m in all_mods if not only or m.NAME in only]

    # design-token contrast check first: a failing palette stops the build
    from ss import tokens
    tokens.check(fail=True, verbose=False)
    tokens.update_style_guide(os.path.join(HERE, "STYLE_GUIDE.md"))

    os.makedirs(OUT, exist_ok=True)   # keep the folder itself (the test install has a junction to it)
    if not only:
        for n in os.listdir(OUT):     # full build: start clean
            _rm(os.path.join(OUT, n))
    for m in sel:
        for rel in m.OWNS:
            _rm(os.path.join(OUT, rel))

    report = []
    for m in sel:
        t1 = time.time()
        n = m.build(ctx) or 0
        n_lua = copy_lua(ctx, m)
        patch_parent_lua(ctx, getattr(m, "LUA_PATCHES", {}))
        report.append(f"  {m.NAME}: {n} files, {n_lua} own lua, "
                      f"{len(getattr(m, 'LUA_PATCHES', {}))} patched parent lua ({time.time() - t1:.1f}s)")
    write_skin_config(ctx, all_mods)

    # every PNG this run wrote must use palette colours only (smooth note/lane atlases are skipped)
    bad = tokens.scan_palette(atlas.WRITTEN)
    if bad:
        raise SystemExit("off-palette pixels (fix the colour or add a token to ss/style.py P):\n" +
                         "\n".join(f"  {p}: {n} px, e.g. {c}" for p, n, c in bad[:30]))

    # blocky textures at 1x (Z-DON per-texture "density": 1): after the palette scan, which reads the 2x files
    if a.density == 2 and not os.environ.get("SS_NO_DENSITY_PASS"):   # off: A/B checks
        from ss import density_pass
        t1 = time.time()
        n_dirs, removed = density_pass.dedupe_frames(OUT)
        n_half, saved = density_pass.run(OUT)
        report.append(f"  density pass: {n_dirs} frame folders deduplicated ({removed} files fewer), "
                      f"{n_half} textures stored at 1x, {saved / 1048576:.0f} MB less texture memory "
                      f"({time.time() - t1:.1f}s)")

    if a.mockups:
        from ss import review
        review.write_all(os.path.join(HERE, "mockups"))

    print(f"built {OUT} [{', '.join(m.NAME for m in sel)}] density {a.density} in {time.time() - t0:.1f}s")
    print("\n".join(report))
    print(f"  palette scan: {sum(1 for v in atlas.WRITTEN.values() if v == 'crisp')} crisp PNGs clean, "
          f"{sum(1 for v in atlas.WRITTEN.values() if v == 'smooth')} smooth skipped")


if __name__ == "__main__":
    main()
