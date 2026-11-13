"""cmp_trees.py A B: list files only in A, only in B, and differing (by bytes)."""
import filecmp, os, sys
a, b = sys.argv[1], sys.argv[2]
def files(r):
    out = set()
    for root, _, fs in os.walk(r):
        for f in fs:
            out.add(os.path.relpath(os.path.join(root, f), r).replace("\\", "/"))
    return out
fa, fb = files(a), files(b)
diff = sorted(f for f in fa & fb if not filecmp.cmp(os.path.join(a, f), os.path.join(b, f), shallow=False))
for name, s in (("only A", sorted(fa - fb)), ("only B", sorted(fb - fa)), ("differ", diff)):
    print(f"== {name}: {len(s)}")
    for f in s[:int(os.environ.get("N", "40"))]:
        print("  ", f)
