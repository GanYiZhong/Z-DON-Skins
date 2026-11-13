"""Light 8-bit direction: concept mockups (gameplay + song select), drawn at 640x360 and
scaled x2 with NEAREST so every 'pixel' is 2x2 on the 1280x720 screen.
Text uses Noto Sans JP rendered without anti-aliasing as a stand-in for a real pixel font."""
from __future__ import annotations

from PIL import Image, ImageDraw, ImageFont

from . import pixel
from .style import FONT_VF

INK = "#3A2633"
PAL8 = {
    "bg": "#FFF6E5", "bg2": "#F5E7CC", "sky": "#BFE6F7", "panel": "#FFFFFF", "lane": "#FDFBF6",
    "don": "#F0503C", "don_d": "#B8352A", "ka": "#3C9BE6", "ka_d": "#2A6FAE",
    "gold": "#FFC83D", "gold_d": "#D8961E", "green": "#5BBE6A", "pink": "#F7A8BE",
    "mint": "#D9EBCB", "grey": "#8B929E", "mute": "#7A6870",
}
W, H = 640, 360


def _font(size):
    f = ImageFont.truetype(FONT_VF, size)
    try:
        f.set_variation_by_axes([800])
    except Exception:
        pass
    return f


class P8:
    def __init__(self):
        self.im = Image.new("RGBA", (W, H), PAL8["bg"])
        self.d = ImageDraw.Draw(self.im)
        self.d.fontmode = "1"

    def box(self, x0, y0, x1, y1, fill="panel", shadow=True, border=INK):
        if shadow:
            self.d.rectangle([x0 + 2, y0 + 2, x1 + 2, y1 + 2], fill=INK)
        self.d.rectangle([x0, y0, x1, y1], fill=PAL8.get(fill, fill), outline=border)
        # notched corners
        for x, y in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
            self.d.point((x, y), fill=PAL8["bg"])

    def text(self, x, y, s, size=8, col=INK, anchor="la"):
        self.d.text((x, y), s, font=_font(size), fill=PAL8.get(col, col), anchor=anchor)

    def note(self, cx, cy, r, kind):
        c, cd = (PAL8["don"], PAL8["don_d"]) if kind == "don" else (PAL8["ka"], PAL8["ka_d"])
        self.d.ellipse([cx - r - 2, cy - r - 2, cx + r + 2, cy + r + 2], fill=INK)
        self.d.ellipse([cx - r, cy - r, cx + r, cy + r], fill="#FFFFFF")
        rr = r - 3
        self.d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=c)
        self.d.rectangle([cx - rr // 2, cy + rr // 3, cx + rr // 2, cy + rr // 2], fill=cd)
        self.d.point((cx - rr // 2, cy - rr // 2), fill="#FFFFFF")
        self.d.point((cx - rr // 2 + 1, cy - rr // 2), fill="#FFFFFF")

    def sprite(self, char, expr, x, y, scale=2, frame=0):
        self.im.alpha_composite(pixel.sprite(char, expr, frame, scale), (x, y))

    def bar(self, x, y, w, h, frac, col, segs=0):
        self.d.rectangle([x, y, x + w, y + h], fill=PAL8["bg2"], outline=INK)
        fw = int((w - 2) * frac)
        if fw > 0:
            self.d.rectangle([x + 1, y + 1, x + fw, y + h - 1], fill=PAL8.get(col, col))
            self.d.line([x + 1, y + 1, x + fw, y + 1], fill="#FFFFFF")
        if segs:
            for i in range(1, segs):
                sx = x + i * w // segs
                self.d.line([sx, y + 1, sx, y + h - 1], fill=INK)

    def out(self):
        return self.im.resize((W * 2, H * 2), Image.NEAREST)


def _sky(p, y1):
    p.d.rectangle([0, 0, W, y1], fill=PAL8["sky"])
    for cx, cy in ((80, 14), (300, 22), (520, 10)):
        for dx, dy, r in ((0, 0, 8), (10, -4, 10), (22, 0, 8)):
            p.d.ellipse([cx + dx - r, cy + dy - r // 2, cx + dx + r, cy + dy + r], fill="#FFFFFF")
    # pixel ground stripe
    for x in range(0, W, 8):
        p.d.rectangle([x, y1 - 2, x + 3, y1], fill="#9CD3EA")


def gameplay():
    p = P8()
    _sky(p, 60)
    # header: song title (Green layout: title top right)
    p.box(380, 6, 632, 26)
    p.text(624, 16, "サンプルソング", 11, anchor="rm")
    p.text(388, 16, "おに ★10", 8, "don", anchor="lm")
    # player box + gauge (Green: gauge above lane, right side)
    p.box(4, 66, 84, 142, "pink")
    p.sprite("momo", "good", 12, 72)
    p.text(44, 136, "1P", 8, anchor="mb")
    p.bar(240, 52, 392, 10, 0.68, "don", segs=25)
    p.d.rectangle([240 + int(392 * 0.8), 50, 240 + int(392 * 0.8) + 1, 64], fill=PAL8["gold_d"])
    p.text(238, 57, "魂", 8, "don", anchor="rm")
    # lane
    p.d.rectangle([86, 70, W, 140], fill=INK)
    p.d.rectangle([86, 72, W, 138], fill=PAL8["lane"])
    for x in range(160, W, 48):
        p.d.line([x, 73, x, 137], fill=PAL8["bg2"])
    # judge target
    p.d.rectangle([90, 72, 128, 138], fill=PAL8["bg2"])
    p.d.ellipse([148 - 22, 105 - 22, 148 + 22, 105 + 22], outline=INK, width=2)
    p.d.ellipse([148 - 15, 105 - 15, 148 + 15, 105 + 15], outline=PAL8["grey"], width=1)
    p.text(148, 82, "良", 11, "gold_d", anchor="mm")
    for x, k, r in ((215, "don", 14), (262, "ka", 14), (310, "don", 14), (356, "don", 20),
                    (430, "ka", 14), (478, "don", 14), (560, "ka", 20)):
        p.note(x, 105, r, k)
    # score + combo
    p.text(10, 154, "SCORE", 8, "mute")
    p.text(84, 168, "1,024,560", 11, anchor="rm")
    p.box(102, 146, 150, 170, "gold")
    p.text(126, 158, "128", 12, anchor="mm")
    # lower half: useful info as pixel windows
    p.d.rectangle([0, 186, W, H], fill=PAL8["bg2"])
    for x in range(0, W, 16):
        p.d.rectangle([x, 186, x + 7, 189], fill=PAL8["bg"])
    p.box(10, 198, 300, 280)
    p.text(20, 206, "曲の情報", 8, "mute")
    p.text(20, 222, "BPM 168", 11)
    p.text(120, 222, "4/4", 11, "mute")
    p.text(20, 244, "進行", 8, "mute")
    p.bar(60, 241, 228, 9, 0.42, "green", segs=0)
    p.text(20, 262, "1:12 / 2:51", 8)
    p.box(316, 198, 630, 280)
    p.text(326, 206, "判定", 8, "mute")
    for i, (lab, v, col) in enumerate((("良", "412", "gold_d"), ("可", "18", "mute"), ("不可", "3", "don"),
                                       ("連打", "56", "ka"))):
        x = 326 + i * 76
        p.text(x, 224, lab, 8, col)
        p.text(x, 238, v, 12)
    p.text(326, 262, "タイミング  -4ms 早め", 8)
    p.bar(470, 260, 150, 8, 0.5, "panel")
    p.d.rectangle([540, 258, 543, 270], fill=PAL8["ka"])
    p.d.line([545, 259, 545, 269], fill=INK)
    # dialog strip with the second mascot
    p.box(10, 294, 520, 348, "panel")
    p.text(22, 312, "ホシ「いいね！ その調子！」", 11)
    p.text(22, 334, "▼", 8, "mute")
    p.sprite("hoshi", "combo", 548, 292, 2)
    return p.out()


def song_select():
    p = P8()
    _sky(p, 40)
    p.box(6, 6, 200, 30, "gold")
    p.text(103, 18, "曲をえらぶ", 12, anchor="mm")
    # Green keeps a horizontal row of vertical song boxes; centre one is open
    cols = ["pink", "mint", "sky", "gold", "pink", "mint"]
    xs = [30, 80, 130, 0, 470, 520, 570]
    for i, x in enumerate((30, 80, 130, 470, 520, 570)):
        p.box(x, 60, x + 40, 300, cols[i % len(cols)])
        p.d.rectangle([x + 4, 64, x + 36, 76], fill=INK)
        p.text(x + 20, 82, "ソ\nン\nグ", 10, anchor="ma")
    p.box(186, 52, 454, 308, "panel")
    p.d.rectangle([188, 54, 452, 84], fill=PAL8["sky"])
    p.text(320, 69, "サンプルソング", 13, anchor="mm")
    p.text(320, 94, "サブタイトル", 8, "mute", anchor="mm")
    for i, (lab, col, lv) in enumerate((("かんたん", "gold", 3), ("ふつう", "green", 5), ("むずかしい", "ka", 7),
                                         ("おに", "don", 10))):
        y = 112 + i * 36
        p.box(200, y, 440, y + 28, "panel" if i != 3 else "bg2")
        p.d.rectangle([202, y + 2, 212, y + 26], fill=PAL8[col])
        p.text(220, y + 14, lab, 10, anchor="lm")
        for s in range(10):
            p.d.rectangle([330 + s * 10, y + 10, 336 + s * 10, y + 16], fill=PAL8[col] if s < lv else PAL8["bg2"],
                          outline=INK)
    p.text(320, 290, "BPM 168   2:51", 8, "mute", anchor="mm")
    p.sprite("momo", "idle", 2, 274, 2)
    p.sprite("hoshi", "good", 574, 274, 2)
    p.d.rectangle([0, 340, W, H], fill=INK)
    p.text(320, 350, "カッ：えらぶ    ドン：けってい", 8, "#FFFFFF", anchor="mm")
    return p.out()


def sheet(path):
    a, b = gameplay(), song_select()
    out = Image.new("RGB", (1280, 1440 + 16), "#FFFFFF")
    out.paste(a, (0, 0))
    out.paste(b, (0, 736))
    out.save(path)
