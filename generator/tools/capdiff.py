"""Compare two capture trees frame by frame: python tools/capdiff.py caps/v2final caps/nogreen"""
import os, sys
from PIL import Image, ImageChops
a, b = sys.argv[1], sys.argv[2]
for s in sorted(os.listdir(a)):
    da, db = os.path.join(a, s), os.path.join(b, s)
    if not os.path.isdir(da):
        continue
    if not os.path.isdir(db):
        print(f"{s}: missing in {b}"); continue
    out = []
    for f in sorted(os.listdir(da), key=lambda x: (len(x), x)):
        if not f.endswith(".png"):
            continue
        pb = os.path.join(db, f)
        if not os.path.exists(pb):
            out.append(f"{f[:-4]}:MISSING"); continue
        ia = Image.open(os.path.join(da, f)).convert("RGB"); ib = Image.open(pb).convert("RGB")
        if ia.size != ib.size:
            out.append(f"{f[:-4]}:size"); continue
        d = ImageChops.difference(ia, ib).convert("L").point(lambda v: 255 if v > 24 else 0)
        n = sum(d.histogram()[255:])
        pct = 100.0 * n / (ia.size[0] * ia.size[1])
        out.append(f"{f[:-4]}:{pct:.2f}%" + (f"@{d.getbbox()}" if pct > 0.05 else ""))
    print(f"{s}: " + "  ".join(out))
