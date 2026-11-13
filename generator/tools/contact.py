import sys, os
from PIL import Image, ImageDraw
d, out = sys.argv[1], sys.argv[2]
cols = int(sys.argv[3]) if len(sys.argv) > 3 else 4
fs = sorted([f for f in os.listdir(d) if f.endswith('.png')], key=lambda s: int(s.split('.')[0]) if s.split('.')[0].isdigit() else 0)
tw, th = 480, 270
rows = (len(fs) + cols - 1) // cols
s = Image.new('RGB', (cols * tw, rows * (th + 16)), (0, 0, 0)); dr = ImageDraw.Draw(s)
for i, f in enumerate(fs):
    im = Image.open(os.path.join(d, f)).convert('RGB').resize((tw, th))
    x, y = (i % cols) * tw, (i // cols) * (th + 16)
    s.paste(im, (x, y + 16)); dr.text((x + 4, y + 2), f, fill=(255, 255, 0))
s.save(out)
