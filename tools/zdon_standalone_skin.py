"""Make a skin standalone: one folder that needs no other skin installed.

    python tools/zdon_standalone_skin.py <Skins dir> <skin name> <out dir> [--drop PyTaikoGreen] ...

The skin is copied to <out dir>/<skin name>, and each skin of its parent chain into
<out dir>/<skin name>/_base/<ancestor>, with the "parent" in every skin_config.json pointing at the nested copy
("<skin name>/_base/<ancestor>"; the engine takes the parent as a path under Skins/). So the engine still resolves
files exactly as before (same chain, same merging and scaling), and the skin list shows only the top folder.

Of each ancestor only what a nearer skin in the chain doesn't already provide is copied, mirroring the engine's
lookups (src/libs/gfx/texture.cpp, audio.cpp, text.cpp, filesystem.cpp resolve_skin_path):
  * Graphics: skin_config.json always (its entries are merged); a texture folder (one with texture.json) when it
    has a texture name no nearer skin has a picture for; any other file when no nearer skin has the same path;
  * Sounds: a file when no nearer skin has the same folder and stem (sounds are claimed by name, nearest first);
  * Scripts and text_config.json: all of them (scripts load their parent's copy by path, keys are merged);
  * Videos: when no nearer skin has the file's folder (the engine plays the nearest skin's folder, even empty);
  * everything else (Fonts, Models, ...): when no nearer skin has the same path;
  * minus --exclude globs (ancestor-relative paths, e.g. art a skin's own scripts never load).
A dropped ancestor (--drop) ends the chain there: the skin must not need it (YataiDONSimpleStyle's build ships
everything it used from PyTaikoGreen). Updater bookkeeping (checksums.sha256, .skin-repo, .extracted, tools/) is
left out.
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import os
import shutil
from pathlib import Path

SKIP_TOP = {"checksums.sha256", ".skin-repo", ".extracted", "tools", "_base"}


def read_json(p: Path):
    return json.loads(p.read_text(encoding="utf-8-sig"))


def parent_of(skin: Path) -> str | None:
    cfg = skin / "Graphics" / "skin_config.json"
    if not cfg.is_file():
        return None
    p = read_json(cfg).get("screen", {}).get("parent")
    return p if isinstance(p, str) and p else None


def set_parent(cfg_path: Path, parent: str | None) -> None:
    cfg = read_json(cfg_path)
    screen = cfg.setdefault("screen", {})
    if parent:
        screen["parent"] = parent
    else:
        screen.pop("parent", None)
    cfg_path.write_text(json.dumps(cfg, ensure_ascii=False, indent=4) + "\n", encoding="utf-8", newline="\n")


def files_under(root: Path) -> list[str]:
    out = []
    for dirpath, dirnames, filenames in os.walk(root):
        rel_dir = Path(dirpath).relative_to(root)
        if rel_dir == Path("."):
            dirnames[:] = [d for d in dirnames if d not in SKIP_TOP]
            filenames = [f for f in filenames if f not in SKIP_TOP]
        for f in filenames:
            out.append((rel_dir / f).as_posix())
    return sorted(out)


def texture_names(folder: Path) -> set[str]:
    """Names in folder/texture.json that have a picture there (a png, or a folder of frames)."""
    tj = folder / "texture.json"
    if not tj.is_file():
        return set()
    try:
        names = read_json(tj).keys()
    except (ValueError, AttributeError):
        return set()
    return {n for n in names if (folder / n).exists() or (folder / f"{n}.png").exists()}


class TexturePlan:
    """Which files of an ancestor's texture folder the engine can still load: the pictures of the names no nearer
    skin has a picture for (load_folder skips the rest), the atlases their "file" points at, and anything the
    folder's texture.json doesn't name (kept, since something else may read it)."""

    def __init__(self, needed: set[str], skipped: set[str], files: set[str]):
        self.needed, self.skipped, self.files = needed, skipped, files

    def keeps(self, item: str) -> bool:
        if item in self.files:
            return True
        name = item[:-4] if item.endswith(".png") else item
        if name in self.needed:
            return True
        return name not in self.skipped


def texture_plan(folder: Path, nearer_folders: list[Path]) -> TexturePlan | None:
    """None when every texture the folder has is provided nearer (the folder isn't needed at all)."""
    try:
        entries = read_json(folder / "texture.json")
    except (ValueError, OSError):
        return TexturePlan(set(), set(), set())   # unreadable: the engine loads it all, so keep it all
    own = texture_names(folder)
    provided = set()
    for n in nearer_folders:
        provided |= texture_names(n)
    needed = own - provided
    if not needed:
        return None
    files = set()
    for name in needed:
        v = entries.get(name) if isinstance(entries, dict) else None
        for e in (v if isinstance(v, list) else [v]):
            if isinstance(e, dict) and isinstance(e.get("file"), str):
                files.add(e["file"])
    return TexturePlan(needed, own & provided, files)


def needed(ancestor: Path, nearer: list[Path], excludes: list[str]) -> list[str]:
    keep = []
    tex_dirs: dict[str, TexturePlan | None] = {}
    for rel in files_under(ancestor):
        if any(fnmatch.fnmatchcase(rel, pat) for pat in excludes):
            continue
        parts = rel.split("/")
        top = parts[0]
        if top == "Videos" and any((n / Path(rel).parent).is_dir() for n in nearer):
            continue
        if top == "Scripts" or rel == "text_config.json" or rel == "Graphics/skin_config.json":
            keep.append(rel)
            continue
        if top == "Graphics":
            p = Path(rel).parent
            if (ancestor / p / "texture.json").is_file():
                folder, item = p, Path(rel).name
            elif (ancestor / p.parent / "texture.json").is_file() and p.parent != p:
                folder, item = p.parent, p.name      # a frame of a texture that is a folder of frames
            else:
                folder = None
            if folder is not None:
                key = folder.as_posix()
                if key not in tex_dirs:
                    tex_dirs[key] = texture_plan(ancestor / folder, [n / folder for n in nearer])
                plan = tex_dirs[key]
                if plan is not None and (item == "texture.json" or plan.keeps(item)):
                    keep.append(rel)
                continue
        if top == "Sounds":
            p = Path(rel)
            stem_glob = p.stem
            shadowed = any((n / p.parent).is_dir() and any(q.stem == stem_glob for q in (n / p.parent).iterdir()
                                                            if q.is_file())
                           for n in nearer)
            if not shadowed:
                keep.append(rel)
            continue
        if not any((n / rel).exists() for n in nearer):
            keep.append(rel)
    return keep


def copy_files(src: Path, dst: Path, rels: list[str]) -> int:
    size = 0
    for rel in rels:
        target = dst / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src / rel, target)
        size += target.stat().st_size
    return size


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("skins", type=Path, help="the Skins folder the skin and its parents are in")
    ap.add_argument("name", help="the skin to make standalone")
    ap.add_argument("out", type=Path, help="output folder (gets <name>/)")
    ap.add_argument("--drop", action="append", default=[], help="ancestor to leave out (ends the chain there)")
    ap.add_argument("--keep-parent", action="store_true",
                    help="copy only the skin, its parent left as is (a child of another bundled skin)")
    ap.add_argument("--exclude", action="append", default=[],
                    help="glob of ancestor files to leave out, relative to the ancestor (fnmatch: * crosses /)")
    args = ap.parse_args()

    skin = args.skins / args.name
    chain = [skin]
    while not args.keep_parent and (p := parent_of(chain[-1])) and p not in args.drop and len(chain) < 8:
        if not (args.skins / p / "Graphics" / "skin_config.json").is_file():
            raise SystemExit(f"{chain[-1].name}: parent {p} isn't installed in {args.skins}")
        chain.append(args.skins / p)

    out = args.out / args.name
    if out.exists():
        shutil.rmtree(out)
    total = copy_files(skin, out, files_under(skin))
    print(f"{args.name}: {total / 1e6:.1f} MB")
    for i, anc in enumerate(chain[1:], 1):
        rels = needed(anc, chain[:i], args.exclude)
        size = copy_files(anc, out / "_base" / anc.name, rels)
        total += size
        print(f"  _base/{anc.name}: {len(rels)} files, {size / 1e6:.1f} MB")
    if args.keep_parent:
        print(f"{out}: {total / 1e6:.1f} MB, parent {parent_of(skin)} as before")
        return
    # point every parent at the nested copy; the last one has none
    homes = [out] + [out / "_base" / a.name for a in chain[1:]]
    for i, home in enumerate(homes):
        nxt = f"{args.name}/_base/{chain[i + 1].name}" if i + 1 < len(chain) else None
        set_parent(home / "Graphics" / "skin_config.json", nxt)
    print(f"{out}: {total / 1e6:.1f} MB in all")


if __name__ == "__main__":
    main()
