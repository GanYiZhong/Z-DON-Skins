"""reports/globals_ui_sheet.png: REAL captures (cropped) + MOCKUP composites of parts no scenario shows."""
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, HERE)
from ss.style import C, Canvas, font  # noqa: E402

G = HERE + "/out/YataiDONSimpleStyle/Graphics/global"
CAP = HERE + "/caps/globals_ui"
BG = (18, 21, 28)
W = 1280


def tex(sub, name, frame=None, tile=None):
    im = Image.open(f"{G}/{sub}/{name}.png").convert("RGBA")
    return im


def crop_frame(im, i, w, h, cols):
    x, y = (i % cols) * w, (i // cols) * h
    return im.crop((x, y, x + w, y + h))


def plate(frame, name, title, pnum="1p", dan=None, gold=False, ai=False):
    cv = Image.new("RGBA", (300, 80), (0, 0, 0, 0))
    if ai:
        cv.alpha_composite(tex("nameplate", "ai"), (10, 8))
        return cv
    fr = tex("nameplate", "frame_top")
    cv.alpha_composite(crop_frame(fr, frame, 272, 32, 1), (10, 8))
    cv.alpha_composite(tex("nameplate", "outline"), (10, 8))
    d = ImageDraw.Draw(cv)
    off = 32
    if dan is not None:
        cv.alpha_composite(tex("nameplate", "dan_emblem_bg"), (10 + 11, 8 + 27))
        e = tex("nameplate", "dan_emblem_gold" if gold else "dan_emblem")
        cv.alpha_composite(crop_frame(e, dan, 64, 32, 2), (10 + 62, 8 + 30))
        off = 96
    cv.alpha_composite(tex("nameplate", pnum), (10, 8))
    f = font(15, 800)
    d.text((10 + 136 + (off - 32) / 2, 8 + 16), title, font=f, fill=BG + (255,), anchor="mm")
    f2 = font(19, 800)
    d.text((10 + 136 + (off - 32) / 2 + 16, 8 + 47), name, font=f2, fill=(241, 243, 248, 255), anchor="mm")
    return cv


def label(d, x, y, s, real):
    d.text((x, y), ("REAL  " if real else "MOCKUP  ") + s, font=font(15, 700), fill=(255, 194, 61) if real else (169, 177, 195))


def main():
    tiles = []  # (img, label, real)
    ld = lambda p: Image.open(f"{CAP}/{p}").convert("RGB")
    tiles.append((ld("song_select/190.png"), "song select: timer, nameplate, footer drum hint", True))
    tiles.append((ld("transition/500.png"), "song transition: Tick + title band", True))
    tiles.append((ld("result3/7050.png"), "result transition shutters (1P)", True))
    tiles.append((ld("entry/40.png"), "entry overlay icons + timer", True))
    pr = ld("practice/300.png")
    tiles.append((pr, "practice timer (game bg is the game module's)", True))
    tiles.append((ld("title/300.png"), "title: card/camera icons", True))

    # mockups
    mk = Image.new("RGB", (W, 500), BG)
    d = ImageDraw.Draw(mk)
    x = 20
    variants = [(0, "Player", "Donder Debut!", "1p", None, False), (1, "ずんだ", "ふつうのどんだー", "2p", None, False),
                (2, "なまえ", "ブロンズ", "1p", 5, False), (3, "プラチナ", "Platinum", "1p", 17, True),
                (4, "ゴールド", "Gold title", "1p", 22, True)]
    for k, (fr, nm, ti, pn, dan, gold) in enumerate(variants):
        im = plate(fr, nm, ti, pn, dan, gold)
        mk.paste(im, (x + (k % 3) * 310, 28 + (k // 3) * 84), im)
    ai = plate(0, "", "", ai=True)
    mk.paste(ai, (x + 2 * 310, 28 + 84), ai)
    # timer discs
    for k, nm in enumerate(["bg", "bg_red"]):
        b = tex("timer", nm)
        mk.paste(b, (x + k * 170, 200), b)
        ctr = tex("timer", "counter_black" if k == 0 else "counter_white")
        for j, dg in enumerate("42" if k == 0 else "7"):
            c = crop_frame(ctr, int(dg), 48, 64, 10)
            mk.paste(c, (x + k * 170 + 80 - (len("42" if k == 0 else "7") * 44) // 2 + j * 44 - 2, 200 + 48), c)
    # network bars and spinner
    for k in range(4):
        b = Image.open(f"{G}/network_msg/bar/{k}.png").convert("RGBA")
        mk.paste(b, (400 + k * 70, 190), b)
    for k in range(9):
        b = Image.open(f"{G}/network_msg/dot/{k}.png").convert("RGBA")
        mk.paste(b, (400 + k * 40, 350), b)
    # overlay icons
    ox = 20
    for name, n in (("camera", 2), ("banapass_card", 2), ("banapass_osaifu_keitai", 2), ("banapass_or", 2), ("allnet_indicator", 3)):
        for i in range(n):
            im = Image.open(f"{G}/overlay/{name}/{i}.png").convert("RGBA")
            mk.paste(im, (ox, 400), im)
            ox += im.width + 8
    b = tex("overlay", "banapass_no")
    mk.paste(b, (ox, 400), b)
    # indicator parts
    ix = 830
    iy = 230
    bgp = tex("indicator", "background")
    mk.paste(bgp, (ix - 30, iy + 4), bgp)
    for name, dx in (("drum_face", 0), ("drum_don", 0)):
        im = tex("indicator", name)
        mk.paste(im, (ix + 60, iy), im)
    for dx, mir in ((64, False), (88, True)):
        im = tex("indicator", "drum_kat")
        if mir:
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        mk.paste(im, (ix + dx, iy), im)
    d.text((20, 6), "MOCKUP  nameplate variants (bronze/silver/platinum+dan/gold+dan gold/AI), timer discs, network bars, overlay icons, drum parts",
           font=font(15, 700), fill=(169, 177, 195))
    tiles.append((mk, None, False))

    cols = 2
    cw = 640
    rows = []
    cells = []
    for im, lab, real in tiles:
        if lab is None:
            cells.append((im.resize((W, im.height)), None, real))
        else:
            cells.append((im.resize((cw, int(im.height * cw / im.width))), lab, real))
    H = 40
    pos = []
    y = H
    i = 0
    items = [c for c in cells if c[1] is not None]
    for k in range(0, len(items), 2):
        row = items[k:k + 2]
        h = max(c[0].height for c in row) + 24
        pos.append((row, y, h))
        y += h
    mock = [c for c in cells if c[1] is None][0]
    total = y + mock[0].height + 8
    sheet = Image.new("RGB", (W, total), (10, 12, 16))
    d = ImageDraw.Draw(sheet)
    d.text((10, 10), "globals_ui contact sheet (YataiDONSimpleStyle)", font=font(18, 800), fill=(241, 243, 248))
    for row, yy, h in pos:
        for j, (im, lab, real) in enumerate(row):
            sheet.paste(im, (j * cw, yy + 22))
            label(d, j * cw + 8, yy + 3, lab, real)
    sheet.paste(mock[0], (0, y + 8))
    out = HERE + "/reports/globals_ui_sheet.png"
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.save(out)
    print(out, sheet.size)


main()
