"""Texture inventory of the ancestor chain: every key Nijiiro + Green would draw for our skin, with
its source, LOGICAL size and whether our built skin already replaces it. This is the screen agents'
checklist for "no Nijiiro/Green art may show through".

    python tools/inventory.py                      all screens, text table
    python tools/inventory.py song_select          one screen (or screen/subset)
    python tools/inventory.py game --todo          only keys our skin does not replace yet
    python tools/inventory.py --json reports/inventory_v2.json   machine-readable, all screens
    python tools/inventory.py --summary            per-subset counts (total / ours / todo)

Columns:
  source  nijiiro | green | nijiiro-pos (Nijiiro lists it, Green's image is drawn at its raw size)
  size    LOGICAL frame size (physical = x density) and frame count
  ref     where the key name shows up in ancestor Lua or the engine source:
          "sub/key" = referenced as subset/key, "name" = the bare name appears, "-" = not found
          (maybe built dynamically, e.g. self.path .. "/" .. name, or unused)
  ours    yes = out/YataiDONSimpleStyle ships <key>.png or <key>/ for that subset
"""
from __future__ import annotations

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, HERE)

from ss import atlas  # noqa: E402

OUT_G = os.path.join(HERE, "out", "YataiDONSimpleStyle", "Graphics")
ENGINE_SRC = r"D:/GitHubRepos/Z-DON/src"


def _corpus():
    texts = []
    roots = [s for _, _, s, _ in atlas.ANCESTORS] + [ENGINE_SRC]
    for r in roots:
        for root, _, files in os.walk(r):
            for f in files:
                if f.endswith((".lua", ".cpp", ".h", ".hpp")):
                    try:
                        with open(os.path.join(root, f), encoding="utf-8", errors="ignore") as fh:
                            texts.append(fh.read())
                    except OSError:
                        pass
    words, paths = set(), set()
    for tok in re.findall(r"[A-Za-z0-9_]+(?:/[A-Za-z0-9_]+)*", "\n".join(texts)):
        parts = tok.split("/")
        words.update(parts)
        for i in range(len(parts) - 1):
            paths.add(parts[i] + "/" + parts[i + 1])
    return words, paths


def _ours(screen, subset, key):
    d = os.path.join(OUT_G, screen, subset)
    return os.path.isfile(os.path.join(d, key + ".png")) or os.path.isdir(os.path.join(d, key))


def rows(sel=None):
    words, paths = _corpus()
    for screen in atlas.screens():
        for subset in atlas.subsets(screen):
            if sel and sel not in (screen, f"{screen}/{subset}"):
                continue
            for key in atlas.subset_keys(screen, subset):
                g = atlas.resolve(screen, subset, key)
                if g is None:
                    continue
                if f"{subset}/{key}" in paths:
                    ref = "sub/key"
                elif key in words:
                    ref = "name"
                else:
                    ref = "-"
                yield {"screen": screen, "subset": subset, "key": key, "source": g.source, "kind": g.kind,
                       "w": g.size[0], "h": g.size[1], "frames": len(g.frames), "ref": ref,
                       "ours": _ours(screen, subset, key)}


def main():
    args = [a for a in sys.argv[1:]]
    js = None
    if "--json" in args:
        i = args.index("--json")
        js = args[i + 1]
        del args[i:i + 2]
    todo = "--todo" in args
    summary = "--summary" in args
    args = [a for a in args if not a.startswith("--")]
    sel = args[0] if args else None
    data = list(rows(sel))
    if js:
        os.makedirs(os.path.dirname(os.path.abspath(js)), exist_ok=True)
        with open(js, "w", encoding="utf-8", newline="\n") as f:
            json.dump(data, f, ensure_ascii=False, indent=1)
        print(f"wrote {js}: {len(data)} keys")
        return
    if summary:
        agg = {}
        for r in data:
            a = agg.setdefault(f"{r['screen']}/{r['subset']}", [0, 0, 0, 0])
            a[0] += 1
            a[1] += r["ours"]
            a[2] += r["source"] == "nijiiro"
            a[3] += r["source"] != "nijiiro"
        print(f"{'subset':42s} {'keys':>5s} {'ours':>5s} {'todo':>5s} {'nij':>5s} {'green':>5s}")
        for k, (n, o, nj, gr) in sorted(agg.items()):
            print(f"{k:42s} {n:5d} {o:5d} {n - o:5d} {nj:5d} {gr:5d}")
        tot = sum(a[0] for a in agg.values())
        ours = sum(a[1] for a in agg.values())
        print(f"{'TOTAL':42s} {tot:5d} {ours:5d} {tot - ours:5d}")
        return
    cur = None
    for r in data:
        if todo and r["ours"]:
            continue
        sub = f"{r['screen']}/{r['subset']}"
        if sub != cur:
            cur = sub
            print(f"== {sub}")
        size = f"{r['w']}x{r['h']}" + (f" x{r['frames']}" if r["frames"] > 1 else "")
        print(f"  {r['key']:34s} {r['source']:12s} {r['kind']:5s} {size:16s} ref={r['ref']:7s} "
              f"ours={'yes' if r['ours'] else 'no'}")


if __name__ == "__main__":
    main()
