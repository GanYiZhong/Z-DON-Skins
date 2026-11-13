"""List everything the engine could still resolve from PyTaikoGreen when the active skin is
YataiDONSimpleStyle (chain: ours -> YataiDONNijiiro -> PyTaikoGreen). Mirrors the Z-DON lookups:
animation.json (whole file, nearest first), settings_template.json, text_config.json (keys merged),
Scripts (index by stem, top level + one subfolder; require() by module path), Sounds (per screen
folder by stem, plus don/ka/global), Fonts/Videos/Models (resolve_skin_path), textures (per
screen/subset, names merged)."""
import json, os, sys
SK = "D:/GitHubRepos/Z-DON/build/bin/Skins"
OURS = sys.argv[1] if len(sys.argv) > 1 else "D:/YataiDON_agents/simplestyle/out/YataiDONSimpleStyle"
NIJ, GRN = SK + "/YataiDONNijiiro", SK + "/PyTaikoGreen"
NEAR = [OURS, NIJ]

def ex(p): return os.path.exists(p)
def anyn(rel): return any(ex(os.path.join(r, rel)) for r in NEAR)
out = {}
def add(cat, x): out.setdefault(cat, []).append(x)

G = GRN + "/Graphics"
for scr in sorted(os.listdir(G)):
    if os.path.isfile(os.path.join(G, scr, "animation.json")) and not anyn(f"Graphics/{scr}/animation.json"):
        add("animation.json", scr)
    sd = os.path.join(G, scr)
    if not os.path.isdir(sd): continue
    for sub in sorted(os.listdir(sd)):
        tj = os.path.join(sd, sub, "texture.json")
        if not os.path.isfile(tj): continue
        names = set(json.load(open(tj, encoding="utf-8")).keys())
        names = {n for n in names if ex(os.path.join(sd, sub, n)) or ex(os.path.join(sd, sub, n + ".png"))}
        for r in NEAR:
            rd = os.path.join(r, "Graphics", scr, sub)
            if os.path.isfile(os.path.join(rd, "texture.json")):
                c = json.load(open(os.path.join(rd, "texture.json"), encoding="utf-8"))
                names -= {n for n in c if ex(os.path.join(rd, n)) or ex(os.path.join(rd, n + ".png"))}
        if names:
            add("textures", f"{scr}/{sub}: {len(names)} " + ",".join(sorted(names)[:12]))
if ex(G + "/settings_template.json") and not anyn("Graphics/settings_template.json"):
    add("settings_template", "Graphics/settings_template.json")
# text_config keys
def tkeys(root):
    k = set()
    for f in (root + "/text_config.json", root + "/Graphics/skin_config.json"):
        if ex(f):
            try: k |= set(json.load(open(f, encoding="utf-8")).keys())
            except Exception: pass
    return k
miss = set(json.load(open(GRN + "/text_config.json", encoding="utf-8"))) - tkeys(OURS) - tkeys(NIJ)
if miss: add("text_config keys", f"{len(miss)}: " + ",".join(sorted(miss)))
# scripts
def stems(root):
    s = set(); d = root + "/Scripts"
    if not os.path.isdir(d): return s
    for e in os.listdir(d):
        p = os.path.join(d, e)
        if os.path.isdir(p):
            for f in os.listdir(p):
                if f.endswith(".lua"): s.add(f[:-4])
        elif e.endswith(".lua"): s.add(e[:-4])
    return s
near_st = stems(OURS) | stems(NIJ)
for st in sorted(stems(GRN) - near_st): add("script stems", st)
for root, _, fs in os.walk(GRN + "/Scripts"):
    for f in fs:
        rel = os.path.relpath(os.path.join(root, f), GRN).replace("\\", "/")
        if f.endswith(".lua") and not anyn(rel): add("script files", rel)
# sounds: (folder, stem)
def snd(root):
    s = set(); d = root + "/Sounds"
    for r, _, fs in os.walk(d):
        for f in fs:
            rel = os.path.relpath(os.path.join(r, f), d).replace("\\", "/")
            s.add(os.path.splitext(rel)[0])
    return s
for x in sorted(snd(GRN) - snd(OURS) - snd(NIJ)): add("sounds", x)
for cat in ("Fonts", "Videos", "Models"):
    d = GRN + "/" + cat
    for r, _, fs in os.walk(d):
        for f in fs:
            rel = os.path.relpath(os.path.join(r, f), GRN).replace("\\", "/")
            if not anyn(rel): add(cat, rel)
for k, v in out.items():
    print(f"== {k} ({len(v)})")
    for x in v[:400]: print("  ", x)
