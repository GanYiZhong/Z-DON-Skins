import os, sys
from PIL import Image, ImageDraw
G = os.environ.get("SHEET_ROOT", r"D:/GitHubRepos/Z-DON/build/bin/Skins/PyTaikoGreen/Graphics")
sub, out = sys.argv[1], sys.argv[2]
maxw = int(sys.argv[3]) if len(sys.argv) > 3 else 1600
d = os.path.join(G, sub)
files = []
for root, _, fs in os.walk(d):
    for f in sorted(fs):
        if f.endswith('.png'): files.append(os.path.join(root, f))
files = files[:80]
ims = []
for f in files:
    im = Image.open(f).convert("RGBA")
    s = min(1.0, 380 / max(im.size))
    im = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))))
    ims.append((os.path.relpath(f, d), im))
x = y = rowh = 0; pos = []
for n, im in ims:
    w, h = max(im.width, 120), im.height + 14
    if x + w > maxw: x = 0; y += rowh + 6; rowh = 0
    pos.append((x, y)); x += w + 6; rowh = max(rowh, h)
H = y + rowh
sheet = Image.new("RGBA", (maxw, H), (90, 90, 110, 255))
dr = ImageDraw.Draw(sheet)
for (n, im), (x, y) in zip(ims, pos):
    chk = Image.new("RGBA", im.size, (60, 60, 70, 255)); chk.alpha_composite(im)
    sheet.paste(chk, (x, y + 14)); dr.text((x, y), n[:22], fill=(255, 255, 0, 255))
sheet.convert("RGB").save(out)
print(len(files), sheet.size)
