"""Inventory of text BAKED into textures: every string the generator draws into a PNG (Canvas.text,
deco.pixtext, and every chrome / course helper built on them), per module, with the generator call
site, the texture key it lands in, and who draws that texture at run time:

    LUA     our own subset (OwnSubset) or a key our built Scripts / Nijiiro's Lua reference
            -> convert: draw it with UI.t / UI.label / UI.hint / UI.bubble at run time
    ENGINE  the key is a "subset/key" literal in the Z-DON C++ source (texture.cpp draws it)
            -> ship per-language variants <key>_ja / _en / _zh / _ko (engine language_variants)
    BOTH    referenced by C++ and Lua: check which path draws it on your screen
    ?       no reference found (dynamic name, or unused): check the Lua before converting

Digits and digit fonts (strings of 0-9 + - . % : / x) are excluded: they stay baked. Brand / logo art
(pixtext block letters, the wordmark) is listed as a DECISION item.

    python tools/baked_text.py                        build into a scratch dir, write
                                                      reports/baked_text_inventory.md (+ .json)
    python tools/baked_text.py --only v2_result       one module (core always runs first)
    python tools/baked_text.py --out <dir>            scratch output dir (default cache/baked_text_out)

The build runs exactly like build.py (same modules, density 2) but into the scratch folder, so
out/YataiDONSimpleStyle is never touched."""
from __future__ import annotations

import argparse
import importlib
import json
import os
import re
import shutil
import sys
import traceback

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, HERE)

from ss import style, deco  # noqa: E402  (patched before any module imports them by name)

ENGINE_SRC = r"D:/GitHubRepos/Z-DON/src"
DIGITS = re.compile(r"^[\s0-9+\-.,%:/xX×★]*$")
HELPER_FILES = {"style.py", "chrome.py", "deco.py", "atlas.py"}

EVENTS: list[dict] = []          # every baked string
STATE = {"module": None, "G": None}


def _site():
    """(site, via): the generator line that owns the string and the helper that drew it."""
    st = traceback.extract_stack()[:-2]
    via = None
    for fr in reversed(st):
        b = os.path.basename(fr.filename)
        if os.path.dirname(os.path.abspath(fr.filename)) != os.path.join(HERE, "ss"):
            continue
        if b in HELPER_FILES or b == "course.py":
            via = via or f"{b[:-3]}.{fr.name}"
            continue
        break
    # the first frame in a screen module (v2_*.py) wins; else the first non-helper ss frame
    mod_fr = next((f for f in reversed(st) if os.path.basename(f.filename).startswith("v2_")), None)
    if mod_fr is None:
        mod_fr = next((f for f in reversed(st) if os.path.dirname(os.path.abspath(f.filename)) ==
                       os.path.join(HERE, "ss") and os.path.basename(f.filename) not in HELPER_FILES), None)
    if mod_fr is None:
        return "?", via
    return f"ss/{os.path.basename(mod_fr.filename)}:{mod_fr.lineno}", via


def _tag(im, ids):
    if ids:
        cur = im.__dict__.get("_sst")
        if cur is None:
            im._sst = set(ids)
        else:
            cur.update(ids)


def _record(cv, s, size, kind):
    s = str(s)
    if not s.strip() or DIGITS.match(s):
        return
    site, via = _site()
    ev = {"id": len(EVENTS), "s": s, "size": size, "kind": kind, "site": site, "via": via,
          "module": STATE["module"], "keys": set()}
    EVENTS.append(ev)
    _tag(cv.im, {ev["id"]})


def _patch():
    """Tag the canvas IMAGE with every string drawn on it; PIL ops carry the tags along (copy, crop,
    resize, transpose, convert -> the result; paste / alpha_composite -> the destination); a tagged image
    saved under Graphics/<screen>/<subset>/<key>(.png|/<frame>.png) attributes its strings to that key."""
    from PIL import Image
    I = Image.Image
    for name in ("copy", "crop", "resize", "transpose", "convert", "rotate", "transform"):
        orig = getattr(I, name)

        def f(self, *a, __o=orig, **k):
            r = __o(self, *a, **k)
            ids = self.__dict__.get("_sst")
            if ids and isinstance(r, I):
                _tag(r, ids)
            return r
        setattr(I, name, f)
    for name in ("paste", "alpha_composite"):
        orig = getattr(I, name)

        def g(self, im, *a, __o=orig, **k):
            if isinstance(im, I):
                _tag(self, im.__dict__.get("_sst"))
            return __o(self, im, *a, **k)
        setattr(I, name, g)
    o_ac = Image.alpha_composite

    def ac(a, b):
        r = o_ac(a, b)
        _tag(r, a.__dict__.get("_sst"))
        _tag(r, b.__dict__.get("_sst"))
        return r
    Image.alpha_composite = ac
    o_save = I.save

    def save(self, fp, *a, **k):
        ids = self.__dict__.get("_sst")
        if ids and isinstance(fp, (str, os.PathLike)):
            tag = _key_of(str(fp))
            if tag:
                for e in ids:
                    EVENTS[e]["keys"].add(tag)
        return o_save(self, fp, *a, **k)
    I.save = save

    C = style.Canvas
    o_text = C.text

    def text(self, x, y, s, size, *a, **k):
        _record(self, s, size, "text")
        return o_text(self, x, y, s, size, *a, **k)
    C.text = text

    o_pix = deco.pixtext

    def pixtext(cv, x, y, s, *a, **k):
        _record(cv, s, "pix", "pixtext")
        return o_pix(cv, x, y, s, *a, **k)
    deco.pixtext = pixtext


def _key_of(path):
    """Graphics/<screen>/<subset>/<key>.png or .../<key>/<frame>.png -> (kind, screen, subset, key)"""
    p = os.path.abspath(path).replace("\\", "/")
    g = STATE.get("G")
    if not g or not p.startswith(g + "/"):
        return None
    parts = p[len(g) + 1:].split("/")
    if len(parts) == 3:
        scr, sub, f = parts
        return ("tex", scr, sub, os.path.splitext(f)[0])
    if len(parts) >= 4:
        return ("tex", parts[0], parts[1], parts[2])
    return ("tex", parts[0], "-", os.path.splitext(parts[-1])[0])


# ---------------------------------------------------------------- who draws a texture
def _read_tree(root, exts):
    out = {}
    for r, _, fs in os.walk(root):
        for f in fs:
            if f.endswith(exts):
                p = os.path.join(r, f)
                try:
                    with open(p, encoding="utf-8", errors="ignore") as fh:
                        out[os.path.relpath(p, root).replace("\\", "/")] = fh.read()
                except OSError:
                    pass
    return out


class Refs:
    def __init__(self, scripts_dir):
        from ss import atlas
        self.cpp = _read_tree(ENGINE_SRC, (".cpp", ".h", ".hpp"))
        self.cpp_lits = set(re.findall(r'"([A-Za-z0-9_]+/[A-Za-z0-9_/]*)"', "\n".join(self.cpp.values())))
        lua = _read_tree(scripts_dir, (".lua",))
        nj = atlas.ANCESTORS[0][2]   # Nijiiro's Scripts dir (nearest ancestor)
        if os.path.isdir(nj):
            for rel, s in _read_tree(nj, (".lua",)).items():
                lua.setdefault(rel, s)    # our copy of a stem replaces Nijiiro's
        self.lua = lua

    def cpp_ref(self, subset, key):
        full = f"{subset}/{key}"
        if full in self.cpp_lits or any(l.endswith("/" + full) for l in self.cpp_lits):
            return full
        for l in self.cpp_lits:   # "subset/prefix_" + n
            tail = l.split("/", 1)[1] if l.startswith(subset + "/") else None
            if tail and len(tail) >= 3 and tail.endswith(("_", "/")) and key.startswith(tail):
                return l + "*"
        return None

    def _order(self, screen):
        """the screen's own scripts first, then global/, then the rest"""
        def rank(rel):
            return 0 if rel.startswith(screen + "/") else (1 if rel.startswith("global/") else 2)
        return sorted(self.lua.items(), key=lambda kv: (rank(kv[0]), kv[0]))

    def lua_ref(self, subset, key, screen=""):
        """a Lua file that draws <screen>/<subset>/<key>: the screen's own scripts (and global/) by
        "subset/key" or by the bare key next to the subset name; any script by "screen/subset/key"."""
        full = f"{subset}/{key}"
        lit = re.compile(r"""["']%s["']""" % re.escape(key))
        for rel, s in self._order(screen):
            if f"{screen}/{full}" in s:
                return rel
        mine = [(rel, s) for rel, s in self._order(screen) if rel.startswith((screen + "/", "global/"))]
        for rel, s in mine:
            if full in s:
                return rel
        for rel, s in mine:
            if subset in s and lit.search(s):
                return rel
        return None

    def lua_subset(self, subset, screen):
        """a script of the same screen (or global/) that names the subset: keys built at run time"""
        for rel, s in self._order(screen):   # "game/skip/" .. name from any screen's script
            if f'"{screen}/{subset}/"' in s or f"'{screen}/{subset}/'" in s:
                return rel
        if subset == "global":
            return None
        pat = re.compile(r"""["'/]%s["'/]""" % re.escape(subset))
        for rel, s in self._order(screen):
            if (rel.startswith(screen + "/") or rel.startswith("global/")) and pat.search(s):
                return rel
        return None


LANGS = ("ja", "en", "zh", "ko", "tw", "cn", "kr")
SUBSET_NOTES = {
    "ai_battle": "no AI-battle scene in Z-DON (src/scenes): never drawn; leave baked or put_blank",
    "gauge_ai": "no AI-battle scene in Z-DON (src/scenes): never drawn; leave baked or put_blank",
}


def base_key(key):
    """<name>_<lang> -> (<name>, lang): the engine looks the base up through language_variants."""
    for l in LANGS:
        if key.endswith("_" + l) and len(key) > len(l) + 1:
            return key[: -len(l) - 1], l
    return key, None


def classify(refs, tag):
    """-> (class, ref). Our own subsets (no ancestor ships that subset) are drawn by our Lua."""
    from ss import atlas
    _, screen, subset, key = tag[:4]
    k0, _ = base_key(key)
    c = refs.cpp_ref(subset, key) or refs.cpp_ref(subset, k0)
    l = refs.lua_ref(subset, key, screen) or (refs.lua_ref(subset, k0, screen) if k0 != key else None)
    own = all(atlas.anc_json(g, screen, subset) is None for _, g, _, _ in atlas.ANCESTORS)
    if own and not c:
        return "LUA", l or f"own subset {screen}/{subset}"
    if c and l:
        return "BOTH", f"C++ {c}; Lua {l}"
    if c:
        if c.endswith("_*"):   # the C++ builds "<prefix>_" + language: _<lang> variants resolve
            return "ENGINE+LANG", f"C++ {c} (language hook)"
        return "ENGINE", f"C++ {c} (no language hook)"
    if l:
        return "LUA", l
    # no key-level hit: the subset name alone (keys built at run time, e.g. anim frame folders s36..s48)
    if subset.endswith("_anim"):   # Nijiiro clip folders: game/clip_player.lua builds "<name>_anim" at run time
        return "LUA", "clip folder (game/clip_player.lua; ss_ending.lua / bg_objects/rank_badge.lua)"
    if subset in SUBSET_NOTES:
        return "?", SUBSET_NOTES[subset]
    ls = refs.lua_subset(subset, screen)
    if ls:
        return "LUA", f"{ls} (subset only, dynamic key)"
    cs = None if subset == "global" else next((x for x in refs.cpp_lits if x.startswith(subset + "/")), None)
    if cs:
        return "?", f"C++ draws other keys of the subset ({cs}); this key: no reference"
    return "?", "-"


# ---------------------------------------------------------------- run the build into a scratch dir
def run(out_dir, only):
    _patch()
    import build
    from ss import atlas
    style.set_density(2)
    ctx = build.Ctx("ja", "momo", 2, "nijiiro")
    ctx.out = out_dir
    ctx.G = os.path.join(out_dir, "Graphics")
    ctx.scripts = os.path.join(out_dir, "Scripts")
    if os.path.isdir(out_dir):
        shutil.rmtree(out_dir)
    os.makedirs(out_dir)
    STATE["G"] = os.path.abspath(ctx.G).replace("\\", "/")
    mods = [importlib.import_module("ss." + n) for n in build.MODULES]
    for m in mods:
        if hasattr(m, "configure"):
            m.configure(ctx)
    sel = [m for m in mods if not only or m.NAME in only or m.NAME in ("core", "v2_standalone")]
    for m in sel:
        STATE["module"] = m.NAME
        m.build(ctx)
        build.copy_lua(ctx, m)
        build.patch_parent_lua(ctx, getattr(m, "LUA_PATCHES", {}))
    atlas.WRITTEN.clear()
    return ctx


LOGO_HINT = re.compile(r"^(YATAI|GAME OVER|SIMPLE|DON|TAIKO)", re.I)


RANK_GLYPHS = {"粋", "雅", "極"}   # the score-rank marks: kept as glyphs in every Taiko release

# brand / logo art that is not drawn through Canvas.text (so the tracer cannot see it), listed by hand
DECISION_EXTRA = [
    ("YATAI DON wordmark", "ss/v2_front.py:110 draw_logo (block-pixel cells)", "title / loading / entry art",
     "brand: keep baked in every language (recommended)"),
    ("GAME OVER", "ss/v2_meta.py (deco.pixtext)", "global/ss_meta/game_over",
     "5x7 block letters read as a logo; keep, or swap for UI.label('go_title') per language"),
    ("粋 / 雅 / 極 rank marks", "ss/course.py rank_badge, ss/v2_game.py rank_*_anim", "ss_course/rank_*, rank clip folders",
     "kept as glyphs in every language (en / ko cabinets do the same); strings.py rank_* hold them"),
    ("name-entry kana table", "lua/front/entry/name_entry.lua", "(engine text)",
     "the characters a player types, not UI text: keep"),
]


def is_decision(ev):
    s = ev["s"].strip()
    return ev["kind"] == "pixtext" or bool(LOGO_HINT.match(s)) or s in RANK_GLYPHS


def collect(refs):
    rows, unshipped = {}, {}
    for ev in EVENTS:
        if not ev["keys"]:
            unshipped.setdefault((ev["module"], ev["s"]), set()).add(ev["site"])
            continue
        for tag in ev["keys"]:
            k = (ev["module"], ev["s"], tag[:4])
            r = rows.get(k)
            if r is None:
                cls, why = classify(refs, tag)
                r = rows[k] = {"module": ev["module"], "s": ev["s"], "size": ev["size"],
                               "key": "/".join(tag[1:4]), "lang": base_key(tag[3])[1], "class": cls, "ref": why,
                               "sites": set(), "via": set(), "decision": is_decision(ev), "frames": 0}
            r["sites"].add(ev["site"])
            if ev["via"]:
                r["via"].add(ev["via"])
            r["frames"] += 1
    return sorted(rows.values(), key=lambda r: (r["module"], r["key"], r["s"])), unshipped


JA_RE = re.compile(r"[\u3040-\u30ff\u4e00-\u9fff]")
KANA_RE = re.compile(r"[\u3040-\u30ff]")
LIT_RE = re.compile(r"""(["'])((?:(?!\1).)*[\u3040-\u30ff\u4e00-\u9fff](?:(?!\1).)*)\1""")
# Lua files whose Japanese literals are not display text to translate
LUA_SKIP = {
    "global/ss_def.lua": "generated from ss/ui.py + ss/course.py (course names / rank kanji; UI.course.name now uses UI.t)",
    "entry/name_entry.lua": "the kana input table of the name picker (characters to type, not UI text): DECISION, keep",
    "song_select/file_navigator/box_folder.lua": "Nijiiro folder-name match keys (compared with box titles), not drawn",
}


def lua_literals(scripts_dir):
    """Japanese string literals in the BUILT Scripts (non-comment code): engine text already, but hard-coded
    in Japanese. -> rows {file, line, s, skey, skip}."""
    rev = _string_keys()
    out = []
    for rel, src in sorted(_read_tree(scripts_dir, (".lua",)).items()):
        for i, line in enumerate(src.splitlines(), 1):
            code = line.split("--", 1)[0]
            for m in LIT_RE.finditer(code):
                lit = m.group(2)
                key = rev.get(lit) or rev.get(lit.strip()) or rev.get(lit.lower())
                out.append({"file": rel, "line": i, "s": lit, "skey": key or "", "skip": LUA_SKIP.get(rel, "")})
    return out


def _string_keys():
    try:
        from ss import strings
    except ImportError:
        return {}
    rev = {}
    for k, v in strings.STRINGS.items():
        for t in {v["ja"], v["en"], v["en"].lower()}:
            if k not in rev.setdefault(t, []):
                rev[t].append(k)
    for t, k in ALIASES.items():
        rev.setdefault(t, []).append(k)
    return {t: " / ".join(ks) for t, ks in rev.items()}


# baked / literal fragments that belong to a format string or an en spelling variant
ALIASES = {"Sounds": "sel_neiro", "%以上": "dan_gold_more", "金合格 ": "dan_gold_more",
           "回 たたいて ふっかつ！": "retry_rule"}


def write_report(rows, unshipped, md_path, json_path, lits=()):
    rev = _string_keys()
    mods = []
    for r in rows:
        if r["module"] not in mods:
            mods.append(r["module"])
    for r in rows:
        r["skey"] = rev.get(r["s"]) or rev.get(r["s"].lower(), "")
        r["wrong_lang"] = ((r["lang"] in ("en", "ko") and bool(JA_RE.search(r["s"]))) or
                           (r["lang"] == "zh" and bool(KANA_RE.search(r["s"]))))
    L = ["# Baked text inventory", "",
         "Generated by `python tools/baked_text.py` (traces every `Canvas.text` / `deco.pixtext` call of a",
         "density-2 build into a scratch dir and follows the image through PIL to the PNG it is saved as).",
         "One row per (module, string, texture key). Digits / digit fonts excluded (they stay baked).", "",
         "- **LUA**: our Lua (or Nijiiro's Lua we ship / can patch) draws the texture: convert to `UI.t` /",
         "  `UI.label` / `UI.hint` / `UI.bubble` at run time and drop the text from the PNG.",
         "- **ENGINE+LANG**: Z-DON C++ draws it and asks for `<prefix>_<language>` (e.g. `lane/auto_icon_` + lang):",
         "  ship `<key>_ja/_en/_zh/_ko` variants (texture.cpp `language_variants`: `_<lang>` -> `_ja` -> `_en` -> base).",
         "- **ENGINE**: Z-DON C++ draws it by a FIXED name (`subset/key` literal): the engine resolves `_<lang>`",
         "  variants only for names that already end in `_<lang>`, so variants are NOT picked up here. Options:",
         "  language-neutral art (no words), blank it + draw from Lua where a hook exists, or an engine change",
         "  (texture_fallback trying `<name>_<lang>` first). See reports/core_dynamic_text.md.",
         "- Lua lookups (`tex.get_texture`) try `<key>_<lang>`, `_ja`, `_en`, then `<key>` for EVERY name",
         "  (script.cpp resolve_lua_texture), so a LUA texture can also ship per-language variants unchanged.",
         "- **BOTH**: referenced by both C++ and Lua: check which path draws it on screen.",
         "- **?**: no reference found (dynamic name or unused): read the Lua before converting.",
         "- **DECISION**: logo / brand / block-letter art: keep baked or localise, owner decides.",
         "- `lang`: the key is already a `_<lang>` variant; **WRONG** = an en/ko variant that carries Japanese.",
         "- `strings.py`: the ss/strings.py key holding the ja/en/zh/ko text for this string.", "",
         "## Counts", "", "| module | rows | LUA | ENGINE (no lang hook) | ENGINE+LANG | BOTH | ? | DECISION | unique strings |",
         "|---|---|---|---|---|---|---|---|---|"]
    tot = {"rows": 0, "LUA": 0, "ENGINE": 0, "ENGINE+LANG": 0, "BOTH": 0, "?": 0, "D": 0}
    for m in mods:
        rs = [r for r in rows if r["module"] == m]
        c = {k: sum(1 for r in rs if r["class"] == k and not r["decision"]) for k in ("LUA", "ENGINE", "ENGINE+LANG", "BOTH", "?")}
        d = sum(1 for r in rs if r["decision"])
        L.append(f"| {m} | {len(rs)} | {c['LUA']} | {c['ENGINE']} | {c['ENGINE+LANG']} | {c['BOTH']} | {c['?']} | {d} | "
                 f"{len({r['s'] for r in rs})} |")
        tot["rows"] += len(rs)
        for k in ("LUA", "ENGINE", "ENGINE+LANG", "BOTH", "?"):
            tot[k] += c[k]
        tot["D"] += d
    L.append(f"| **all** | {tot['rows']} | {tot['LUA']} | {tot['ENGINE']} | {tot['ENGINE+LANG']} | {tot['BOTH']} | {tot['?']} | "
             f"{tot['D']} | {len({r['s'] for r in rows})} |")
    miss = sorted({r["s"] for r in rows if not r["skey"] and not r["decision"]})
    L += ["", f"Strings without a strings.py entry: {len(miss)}" + (": " + ", ".join(miss) if miss else ""), ""]
    for m in mods:
        L += ["", f"## {m}", "", "| | string | strings.py | size | texture key | lang | drawn by | ref | generator site | via |",
              "|---|---|---|---|---|---|---|---|---|---|"]
        for r in (x for x in rows if x["module"] == m):
            cls = "DECISION (" + r["class"] + ")" if r["decision"] else r["class"]
            s_ = r["s"].replace("|", "\\|").replace("\n", " / ")
            lang = (r["lang"] or "") + (" WRONG" if r["wrong_lang"] else "")
            L.append(f"| [ ] | {s_} | {r['skey']} | {r['size']} | `{r['key']}` | {lang} | {cls} | {r['ref']} | "
                     f"{', '.join(sorted(r['sites']))} | {', '.join(sorted(r['via']))} |")
    act = [x for x in lits if not x["skip"]]
    L += ["", "## Lua literals (already engine text, hard-coded Japanese): route through UI.t / UI.text_key", "",
          f"{len(act)} literals to convert ({sum(1 for x in act if x['skey'])} have a strings.py key); "
          f"{len(lits) - len(act)} skipped (see reason).", "",
          "| | built Scripts file:line | string | strings.py | note |", "|---|---|---|---|---|"]
    for x in lits:
        if x["skip"] and any(y["file"] == x["file"] and y["skip"] for y in lits[:lits.index(x)]):
            continue   # one row per skipped file
        s_ = x["s"].replace("|", "\\|")
        L.append(f"| {'-' if x['skip'] else '[ ]'} | {x['file']}:{x['line']} | {s_ if not x['skip'] else '(file)'} | "
                 f"{x['skey']} | {x['skip']} |")
    L += ["", "## Decision items (logo / brand / glyph marks)", "",
          "| item | source | where | recommendation |", "|---|---|---|---|"]
    L += [f"| {a} | {b} | {c} | {d} |" for a, b, c, d in DECISION_EXTRA]
    if unshipped:
        L += ["", "## Drawn but never saved (measurement / mockup canvases: not shipped, no action)", "",
              "| module | string | site |", "|---|---|---|"]
        for (m, s_), sites in sorted(unshipped.items(), key=lambda kv: (str(kv[0][0]), kv[0][1])):
            L.append(f"| {m} | {s_.replace(chr(10), ' / ')} | {', '.join(sorted(sites))} |")
    with open(md_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L) + "\n")
    with open(json_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump([{**r, "sites": sorted(r["sites"]), "via": sorted(r["via"])} for r in rows], f,
                  ensure_ascii=False, indent=1)
    return tot


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--out", default=os.path.join(HERE, "cache", "baked_text_out"))
    ap.add_argument("--md", default=os.path.join(HERE, "reports", "baked_text_inventory.md"))
    a = ap.parse_args()
    only = [x.strip() for x in a.only.split(",") if x.strip()]
    ctx = run(a.out, only)
    refs = Refs(ctx.scripts)
    rows, unshipped = collect(refs)
    lits = lua_literals(ctx.scripts)
    tot = write_report(rows, unshipped, a.md, os.path.splitext(a.md)[0] + ".json", lits)
    print(f"{tot['rows']} rows: LUA {tot['LUA']}, ENGINE {tot['ENGINE']}, ENGINE+LANG {tot['ENGINE+LANG']}, "
          f"BOTH {tot['BOTH']}, ? {tot['?']}, "
          f"DECISION {tot['D']} -> {a.md}")


if __name__ == "__main__":
    main()
