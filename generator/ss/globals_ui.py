"""Module "globals_ui": Graphics/global/* that is not ss_ui / ss_mascot (those belong to core).

Light 8-bit pass: Green's layout, frame sizes and Lua are kept; every texture is redrawn as a pixbox UI
(ink border, notched corners, hard shadow, whole-pixel steps, no blur, no gradients):
  timer (digit window), nameplate (plate, notched badge chips, dan chips, pixel sparkles),
  indicator (footer drum hint on an ink strip), overlay (card / camera / allnet glyphs, touch drum),
  practice_timer (pixel disc + cell gauge), rainbow_transition (checker dissolve + Momo/Hoshi),
  result_transition (pixel shutters), network_msg (pixel slats, spinning pixel drum).
Parent Lua patches only recolour text/tints (nameplate text, practice-timer disc tints)."""
from __future__ import annotations

import math

from PIL import Image

from . import mascot
from .atlas import SubsetWriter
from .style import C, Canvas, alpha, blank, hue, mix, pixbox, pixdither

NAME = "globals_ui"
OWNS = [
    "Graphics/global/timer", "Graphics/global/nameplate", "Graphics/global/indicator",
    "Graphics/global/overlay", "Graphics/global/practice_timer", "Graphics/global/rainbow_transition",
    "Graphics/global/result_transition", "Graphics/global/network_msg",
    "Scripts/global/nameplate.lua", "Scripts/global/transition.lua", "Scripts/global/practice_timer.lua", "Scripts/global/indicator.lua",
]
SCREEN = "global"
MASCOT = "A"
LANG = "ja"


def configure(ctx):
    global MASCOT, LANG
    MASCOT = ctx.mascot
    LANG = ctx.lang


INDICATOR_CENTRE = """    self.don_offset_x    = SKIN.indicator_don_offset.x
    if state == Indicator.State.SELECT then
        local full = tex.skin_text(TEXT_KEYS[state]) or ""
        local a, b = full:match("^(.-)%s%s+"), full:match("%s%s+(.-)$")
        if a and b then
            local fs = math.floor(26 * tex.get_screen_scale())
            local ta = text.create_raw_text(a, fs, { 255, 255, 255, 255 }, { 0, 0, 0, 0 }, false, 0, 3)
            local tb = text.create_raw_text(b, fs, { 255, 255, 255, 255 }, { 0, 0, 0, 0 }, false, 0, 3)
            local gap = self.select_text.width - ta.width - tb.width
            self.don_offset_x = self.text_offset_x + 24 + ta.width + gap / 2 - 88
            self.face_offset_x = self.don_offset_x
        end
    end
"""

LUA_PATCHES = {
    # footer hint "<a>   <b>": the parent's font has wide spaces and tight spacing (-5); ours does not, so the
    # right-hand drum would sit on top of <b>. Natural spacing, and the drum is centred in the gap (any language).
    # The text stays white: the footer hint now sits on an ink strip.
    "global/indicator.lua": [
        ("{ 255, 255, 255, 255 }, { 0, 0, 0, 0 }, false, 0, -5)",
         "{ 255, 255, 255, 255 }, { 0, 0, 0, 0 }, false, 0, 3)"),
        ("    self.don_offset_x    = SKIN.indicator_don_offset.x\n", INDICATOR_CENTRE),
        # the right-hand blue arrow sits on the first glyph of the hint: push the hint 24 px right (strip widened to match)
        ("    self.select_text:draw({ x = x, y = text_y, fade = fade })",
         "    self.select_text:draw({ x = x + (self.state == Indicator.State.SELECT and 24 or 0), y = text_y, fade = fade })"),
    ],
    # light plate: name = ink with a white outline (name panel is paper); title = ink on the pale title bar
    "global/nameplate.lua": [
        ("text.create_raw_text(name,  math.floor(22 * s),  { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 3)",
         "text.create_raw_text(name,  math.floor(22 * s),  { 58, 38, 51, 255 }, { 255, 255, 255, 255 }, false, 3)"),
        ("""    local name_max   = frame_top_w - self.padding - offset - dan_offset
    local name_width = math.min(self.name_text.width, name_max)
    local name_x     = x + offset + dan_offset + (outline_w - offset - dan_offset) / 2.0 - name_width / 2
    local name_y     = y + outline_h / 2.0 + self.name_offset""",
         """    -- the name must sit inside the paper panel, right of the badge (and dan emblem): squeeze it to fit
    local s          = tex.get_screen_scale()
    local left       = (self.player_num ~= PLAYER_NUM_ALL and 66 * s or 8 * s) + dan_offset
    local right      = outline_w - 10 * s
    local name_max   = right - left
    local name_width = math.min(self.name_text.width, name_max)
    local name_x     = x + left + name_max / 2.0 - name_width / 2
    local name_y     = y + outline_h / 2.0 + self.name_offset"""),
        ("text.create_raw_text(title, math.floor(20 * s), { 0, 0, 0, 255 },       { 0, 0, 0, 0 },   false, 0)",
         "text.create_raw_text(title, math.floor(20 * s), { 58, 38, 51, 255 },     { 0, 0, 0, 0 },   false, 0)"),
    ],
    # Momo stands ON the title band (her feet sank ~10 px into its top edge): lift her 18 px
    "global/transition.lua": [
        ("{ y = center_y(self) - 1270 })", "{ y = center_y(self) - 1288 })"),
    ],
    # the disc is tinted by the Lua (multiplied): the texture is white, so the tint is the final colour
    "global/practice_timer.lua": [
        ("local GREEN        = { 0, 255, 0, 255 }", "local GREEN        = { 123, 211, 137, 255 }"),
        ("local RED          = { 255, 51, 51, 255 }", "local RED          = { 255, 90, 78, 255 }"),
    ],
}


# ================================================================== helpers
INK, PAPER = C["ink"], C["paper"]


def clear(cv, x0, y0, x1, y1):
    """Erase (make transparent) a rectangle, unlike rect() which paints."""
    cv.d.rectangle([x0 * cv.ss, y0 * cv.ss, x1 * cv.ss - 1, y1 * cv.ss - 1], fill=(0, 0, 0, 0))


def pixell(cv, cx, cy, rx, ry, col, px=3):
    """Ellipse made of px-high horizontal bands (a pixel disc when rx == ry)."""
    y = -ry
    while y < ry:
        yc = y + px / 2
        t = 1 - (yc / ry) ** 2
        if t > 0:
            hw = rx * math.sqrt(t)
            hw = max(px / 2, round(hw / px) * px) if rx >= px else hw
            cv.rect(cx - hw, cy + y, cx + hw, cy + y + px, col)
        y += px


def pixdisc(cv, cx, cy, r, col, px=3):
    pixell(cv, cx, cy, r, r, col, px)


def star4(cv, cx, cy, r, col, ink=None, px=3):
    """Pixel 4-point sparkle: tapered cross built from px-thick bars; optional ink outline."""
    def arms(rr, c, grow=0):
        d = 0
        while d < rr:
            thick = max(px, round(((rr - d) / rr) * px * 2.4 / px) * px) / 2 + grow
            cv.rect(cx + d - px / 2, cy - thick, cx + d + px / 2, cy + thick, c)
            cv.rect(cx - d - px / 2, cy - thick, cx - d + px / 2, cy + thick, c)
            cv.rect(cx - thick, cy + d - px / 2, cx + thick, cy + d + px / 2, c)
            cv.rect(cx - thick, cy - d - px / 2, cx + thick, cy - d + px / 2, c)
            d += px
    if ink:
        arms(r + px, ink, grow=px / 2)
    arms(r, col)


# ================================================================== timer (digit window)
def timer_disc(red):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        outer = C["don"] if red else PAPER
        pixbox(cv, 6, 6, w - 8, h - 8, fill=outer, border=INK, shadow=4, px=6)
        # recessed digit window
        inner = mix(PAPER, C["don"], 0.22) if red else C["bg0"]
        pixbox(cv, 14, 22, w - 16, h - 24, fill=inner, border=INK, shadow=0, px=3, notch=False)   # wide: 3 digits at the 44 px pitch must clear the border
        # pixel rivets on the frame
        for (x, y) in ((10, 10), (w - 18, 10), (10, h - 18), (w - 18, h - 18)):
            cv.rect(x, y, x + 4, y + 4, INK)
        return cv.result()
    return draw


def timer_counter(i, n, w, h):
    cv = Canvas(w, h)
    cv.text(w / 2, h / 2 + 2, str(i), 60, INK, weight=900, stroke=2, stroke_fill=INK)
    return cv.result()


def timer_highlight(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 6, 6, w - 6, h - 6, fill=C["roll"], border=C["roll"], shadow=0, px=6)
    return cv.result()


def build_timer(ctx):
    w = SubsetWriter(ctx.G, SCREEN, "timer")
    w.put("bg", timer_disc(False))
    w.put("bg_red", timer_disc(True))
    w.put("counter_black", timer_counter)
    w.put("counter_white", timer_counter)      # ink digits on both windows (white is only for p1/p2/ura fills)
    w.put("highlight", timer_highlight)
    return w.write()


# ================================================================== nameplate
# pale title bars (ink title text): don / ka / tower / ura / gold
TITLE_COL = [mix(PAPER, C["don"], 0.45), mix(PAPER, C["ka"], 0.45), mix(PAPER, C["tower"], 0.55),
             mix(PAPER, C["ura"], 0.45), C["clear"]]


def plate_bar(col):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        pixbox(cv, 0, 0, w - 4, h + 12, fill=col, border=INK, shadow=0, px=3)
        # pixel highlight row
        cv.rect(6, 4, w - 10, 6, alpha(PAPER, 150))
        return cv.result()
    return draw


def plate_bar_rainbow(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 0, 0, w - 4, h + 12, fill=INK, border=INK, shadow=0, px=3)
    seg = 8
    nseg = (w - 12) // seg
    for k in range(nseg):
        col = hue(((k / nseg) * 0.9 + i / n) % 1.0, 0.5, 1.0)
        cv.rect(3 + k * seg, 3, 3 + (k + 1) * seg, h, col)
    return cv.result()


def plate_outline(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 0, 0, w - 4, h - 4, fill=PAPER, border=INK, shadow=4, px=3)
    # the title bar texture shows through the top half
    clear(cv, 3, 3, w - 7, 30)
    cv.rect(0, 29, w - 4, 32, INK)               # divider between title bar and name panel
    return cv.result()


def plate_badge(col, label):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        pixbox(cv, 2, 2, w - 4, h - 4, fill=col, border=INK, shadow=3, px=6)
        cv.text((w - 3) / 2 + 1, h / 2 + 0, label, 24, PAPER, weight=900, tracking=-1,
                stroke=1.5, stroke_fill=INK)
        return cv.result()
    return draw


def plate_ai(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 0, 0, w - 4, h - 4, fill=C["mint"], border=INK, shadow=4, px=3)
    cv.rect(6, 6, w - 10, 9, alpha(PAPER, 200))
    cv.text((w - 4) / 2, h / 2 - 1, "AIどん", 36, INK, weight=900)
    return cv.result()


def plate_dan_bg(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 2, 1, 114, 31, fill=PAPER, border=INK, shadow=2, px=3)
    return cv.result()


DAN_NAMES = ["初級", "十級", "九級", "八級", "七級", "六級", "五級", "四級", "三級", "二級", "一級",
             "初段", "二段", "三段", "四段", "五段", "六段", "七段", "八段", "九段", "十段",
             "玄人", "名人", "超人", "達人"]


def plate_dan(col):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        cv.text(w / 2, h / 2 + 1, DAN_NAMES[i], 24, col, weight=900, tracking=1)
        return cv.result()
    return draw


def plate_shimmer(i, n, w, h):
    # stepped parallelogram sweep (whole-pixel stair edge)
    cv = Canvas(w, h)
    for k, y in enumerate(range(24, 44, 4)):
        x = 54 - k * 4
        cv.rect(x - 22, y, x - 8, y + 4, alpha(PAPER, 235))
    return cv.result()


def plate_sparkle(col):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        r = [30, 15, 10][i]
        star4(cv, w // 2, h // 2, r, col, ink=INK, px=3 if i == 0 else 2)
        return cv.result()
    return draw


def build_nameplate(ctx):
    w = SubsetWriter(ctx.G, SCREEN, "nameplate")
    w.put("shadow", lambda i, n, ww, hh: blank(ww, hh))          # the outline carries its own hard shadow
    w.put("outline", plate_outline)
    w.put("frame_top", lambda i, n, ww, hh: plate_bar(TITLE_COL[i])(i, n, ww, hh))
    w.put("frame_top_rainbow", plate_bar_rainbow)
    w.put("1p", plate_badge(C["p1"], "1P"))
    w.put("2p", plate_badge(C["p2"], "2P"))
    w.put("ai", plate_ai)
    w.put("dan_emblem_bg", plate_dan_bg)
    w.put("dan_emblem", plate_dan(INK))
    w.put("dan_emblem_gold", plate_dan(C["gold_t"]))
    w.put("shimmer", plate_shimmer)
    w.put("sparkle", plate_sparkle(PAPER))
    w.put("sparkle_gold", plate_sparkle(C["clear"]))
    return w.write()


# ================================================================== indicator (footer drum hint)
def ind_background(i, n, w, h):
    # ink strip behind the (white) hint text, notched like every other 8-bit window
    cv = Canvas(w, h)
    pixbox(cv, 30, 4, 484, 44, fill=INK, border=INK, shadow=0, px=3)
    cv.rect(36, 8, 478, 10, alpha(PAPER, 50))
    return cv.result()


def ind_face(i, n, w, h):
    cv = Canvas(w, h)
    pixdisc(cv, 28, 28, 23, PAPER, px=3)
    pixdisc(cv, 28, 28, 21, INK, px=3)
    pixdisc(cv, 28, 28, 18, C["bg3"], px=3)
    return cv.result()


def ind_don(i, n, w, h):
    cv = Canvas(w, h)
    pixdisc(cv, 28, 28, 15, INK, px=3)
    pixdisc(cv, 28, 28, 12, C["don"], px=3)
    return cv.result()


def ind_kat(i, n, w, h):
    # the left rim of a drum (the engine mirrors it for the right rim): a blue stair on the face edge
    cv = Canvas(w, h)
    for k, (x0, y0, y1) in enumerate(((10, 21, 37), (13, 15, 41), (16, 12, 44))):
        cv.rect(x0, y0, x0 + 3, y1, C["ka"])
    return cv.result()


def ind_arrow(i, n, w, h):
    # left-pointing stair triangle, gold with an ink edge (it sits on the ink strip)
    cv = Canvas(w, h)
    for k in range(5):
        x = 5 + k * 3
        cv.rect(x, 12 - 2 - k * 2, x + 3, 12 + 2 + k * 2, C["clear"])
    return cv.result()


def build_indicator(ctx):
    w = SubsetWriter(ctx.G, SCREEN, "indicator")
    w.put("background", ind_background)
    w.put("drum_face", ind_face)
    w.put("drum_don", ind_don)
    w.put("drum_kat", ind_kat)
    w.put("blue_arrow", ind_arrow)
    return w.write()


# ================================================================== overlay
def ov_fill(i, on=None):
    return C["bg3"] if i == 0 else (on or C["don"])


def ov_card(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 4, 12, 56, 48, fill=ov_fill(i), border=INK, shadow=3, px=3)
    cv.rect(7, 22, 53, 28, INK)                              # magnetic stripe
    pixbox(cv, 12, 34, 26, 42, fill=PAPER, border=INK, shadow=0, px=2, notch=False)
    return cv.result()


def ov_phone(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 18, 4, 46, 58, fill=ov_fill(i), border=INK, shadow=3, px=3)
    cv.rect(22, 10, 42, 42, PAPER)
    cv.rect(22, 10, 42, 42, PAPER)
    cv.rect(29, 47, 35, 53, INK)
    return cv.result()


def ov_or(i, n, w, h):
    cv = Canvas(w, h)
    cv.text(w / 2, 36 if i else 40, "or", 24, INK, weight=800)
    if i:
        cv.text(w / 2, 62, "タッチ", 12, C["gold_t"], weight=800)
    return cv.result()


def ov_camera(i, n, w, h):
    cv = Canvas(w, h)
    col = ov_fill(i, C["ka"])
    pixbox(cv, 26, 14, 48, 26, fill=col, border=INK, shadow=0, px=3)
    pixbox(cv, 8, 20, 70, 60, fill=col, border=INK, shadow=3, px=3)
    pixdisc(cv, 39, 40, 14, INK, px=3)
    pixdisc(cv, 39, 40, 11, PAPER, px=3)
    pixdisc(cv, 39, 40, 6, col if i else C["mute"], px=3)
    return cv.result()


def ov_no(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 6, 6, 72, 72, fill=PAPER, border=C["don"], shadow=0, px=6)
    for k in range(0, 36, 6):
        x = 21 + k
        y = 57 - k - 6
        cv.rect(x - 3, y - 3, x + 9, y + 9, C["don"])
    return cv.result()


def ov_allnet(i, n, w, h):
    cv = Canvas(w, h)
    col = [C["mute"], C["roll"], C["normal"]][i]
    pixbox(cv, 1, 1, 36, 36, fill=PAPER, border=INK, shadow=3, px=3)
    for k, hh in enumerate((8, 14, 20)):             # signal bars
        x = 8 + k * 8
        cv.rect(x, 31 - hh, x + 6, 31, INK)
        cv.rect(x + 1, 32 - hh, x + 5, 30, col)
    if i == 0:                                       # X over it
        for k in range(0, 18, 3):
            cv.rect(11 + k, 12 + k, 14 + k, 15 + k, C["don"])
            cv.rect(26 - k, 12 + k, 29 - k, 15 + k, C["don"])
    elif i == 1:                                     # "!" badge
        pixbox(cv, 26, 0, 40, 14, fill=C["roll"], border=INK, shadow=0, px=2)
        cv.rect(31, 3, 35, 9, INK)
        cv.rect(31, 10, 35, 12, INK)
    return cv.result()


def ov_touch_drum(i, n, w, h):
    cv = Canvas(w, h)
    cx, cy, r = w / 2, h + 60, 400
    cv.circle(cx, cy, r, fill=INK)
    cv.ring(cx, cy, r - 6, r - 18, PAPER)
    cv.circle(cx, cy, r - 120, fill=C["bg3"])
    cv.ring(cx, cy, r - 120, r - 130, INK)
    return cv.result()


def build_overlay(ctx):
    w = SubsetWriter(ctx.G, SCREEN, "overlay")
    w.put("camera", ov_camera)
    w.put("banapass_card", ov_card)
    w.put("banapass_osaifu_keitai", ov_phone)
    w.put("banapass_or", ov_or)
    w.put("banapass_no", ov_no)
    w.put("allnet_indicator", ov_allnet)
    w.put("touch_drum", ov_touch_drum)
    return w.write()


# ================================================================== practice timer
CELL = 4


def pt_disc(i, n, w, h):
    # white pixel disc: the Lua multiplies it by the palette green / coral
    cv = Canvas(w, h)
    pixdisc(cv, w / 2, h / 2, 72, PAPER, px=CELL)
    return cv.result()


def pt_gauge(i, n, w, h):
    """Frame i: elapsed part (clockwise from 12 o'clock) as a track of whole pixels, hub, ink rim."""
    cv = Canvas(w, h)
    c = w / 2
    frac = 1 - i / (n - 1)                       # frame 0 = time is up, last frame = full time
    r_out, r_in = 72, 56
    s = CELL
    for gy in range(0, h, s):
        for gx in range(0, w, s):
            dx, dy = gx + s / 2 - c, gy + s / 2 - c
            r = math.hypot(dx, dy)
            if r > r_out + 5:
                continue
            if r > r_out:                       # ink rim
                cv.rect(gx, gy, gx + s, gy + s, INK)
                continue
            if r < r_in:
                continue
            ang = (math.degrees(math.atan2(dy, dx)) + 90) % 360
            if frac >= 0.999 or ang <= 360 * frac:
                cv.rect(gx, gy, gx + s, gy + s, C["bg3"])
    pixdisc(cv, c, c, r_in + 3, INK, px=s)
    pixdisc(cv, c, c, r_in, PAPER, px=s)
    cv.rect(c - 2, c - r_out - 4, c + 2, c - r_in + 2, INK)    # 12 o'clock tick
    return cv.result()


def pt_digit(i, n, w, h):
    cv = Canvas(w, h)
    cv.text(w / 2, h / 2 + 2, str(i), 48, INK, weight=800, stroke=2, stroke_fill=INK)
    return cv.result()


def pt_text(s, size, col=None):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        cv.text(w / 2, h / 2 + 1, s, size, col or INK, weight=800, max_w=w - 8, stroke=2, stroke_fill=PAPER)
        return cv.result()
    return draw


def pt_mode(i, n, w, h):
    cv = Canvas(w, h)
    # ends left of the gauge ring (the ring's left edge at the label's bottom is x = 1135)
    pixbox(cv, 6, 6, 156, h - 9, fill=C["clear"], border=INK, shadow=3, px=3)
    cv.text(81, h / 2, "特訓モード", 24, INK, weight=900, max_w=130)
    return cv.result()


def pt_banner(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 12, 12, w - 20, h - 20, fill=PAPER, border=INK, shadow=8, px=6)
    cv.rect(18, 18, w - 26, 60, C["sky"])
    pixdither(cv, 18, 60, w - 26, 72, C["sky"], cell=6)
    cv.rect(18, 60, w - 26, 66, C["sky"])
    cv.text(w / 2, 150, "特訓おわり", 72, INK, weight=900, stroke=5, stroke_fill=C["clear"])
    cv.text(w / 2, 262, "時間になりました", 36, INK, weight=800)
    cv.text(w / 2, 330, "最後に1曲、特訓の成果をためしてみよう", 36, C["text2"], weight=700, max_w=820)
    cv.im.alpha_composite(mascot.sized(mascot.MAIN, "clear", 120).resize((120 * 4, 120 * 4), Image.NEAREST),
                          (int((w / 2 - 190) * 4), int(335 * 4)))
    cv.im.alpha_composite(mascot.sized(mascot.BUDDY, "good", 120).resize((120 * 4, 120 * 4), Image.NEAREST),
                          (int((w / 2 + 70) * 4), int(335 * 4)))
    return cv.result()


def pt_fade(i, n, w, h):
    cv = Canvas(w, h)
    cv.rect(0, 0, w, h, C["bg0"])
    return cv.result()


def build_practice(ctx):
    w = SubsetWriter(ctx.G, SCREEN, "practice_timer")
    w.put("disc", pt_disc)
    w.put("gauge", pt_gauge)
    # the readout sits inside the paper hub (r 56 around 1192,115): "あと" on top, digits below, unit at their right
    w.put("digits", pt_digit, entry={"x": 1170, "y": 84})
    w.put("unit_minute", pt_text("分", 24), entry={"x": 1207, "y": 115})
    w.put("unit_second", pt_text("秒", 24), entry={"x": 1207, "y": 115})
    w.put("remaining", pt_text("あと", 24), entry={"x": 1162, "y": 60})
    w.put("mode_label", pt_mode, entry={"x": 966, "y": 20})
    w.put("banner", pt_banner)
    w.put("fade", pt_fade)
    return w.write()


# ================================================================== song transition (rainbow_transition)
STRIPE = [C["don"], C["roll"], C["normal"], C["ka"], C["oni"], C["ura"]]


def stripe(cv, y0, y1, w):
    """Ink-bordered colour blocks, 6 hues, whole-pixel."""
    cv.rect(0, y0, w, y1, INK)
    seg = w / len(STRIPE)
    for k, col in enumerate(STRIPE):
        cv.rect(round(k * seg) + 2, y0 + 3, round((k + 1) * seg) - 2, y1 - 3, col)


def checker_edge(cv, y0, y1, w, a, b):
    """Dissolve band: two-colour checker, 12 px cells in rows of 6."""
    cell = 6
    for gy, y in enumerate(range(y0, y1, cell)):
        for gx in range(0, w, cell * 2):
            x = gx + (gy % 2) * cell
            cv.rect(x, y, min(x + cell, w), min(y + cell, y1), b)


def tr_top(i, n, w, h):
    cv = Canvas(w, h)
    cv.rect(0, 0, w, h, C["sky"])
    checker_edge(cv, h - 18, h, w, C["sky"], PAPER)
    cv.rect(0, 0, w, 12, INK)
    stripe(cv, 0, 12, w)
    return cv.result()


def tr_bottom(i, n, w, h):
    cv = Canvas(w, h)
    cv.rect(0, 0, w, h, C["sky"])
    checker_edge(cv, 0, 18, w, C["sky"], PAPER)
    stripe(cv, h - 12, h, w)
    return cv.result()


def tr_bg(i, n, w, h):
    cv = Canvas(w, h)
    cv.rect(0, 0, w, h, C["sky"])
    # sparse pixel clouds and stars on the panel
    for (x, y) in ((140, 90), (880, 150), (520, 60), (1020, 420), (260, 500)):
        if x < w - 80 and y < h - 30:
            cv.rect(x, y + 12, x + 66, y + 24, PAPER)
            cv.rect(x + 12, y, x + 42, y + 12, PAPER)
            cv.rect(x + 36, y + 6, x + 54, y + 12, PAPER)
    return cv.result()


def tr_text_bg(i, n, w, h):
    # the engine stretches this 264x96 art to 792x192 (x3, y2): draw at the stretched size on a 6 px grid
    # and shrink with NEAREST so every pixel stays square after the stretch
    cv = Canvas(792, 192, ss=1)
    pixbox(cv, 0, 24, 786, 168, fill=PAPER, border=INK, shadow=6, px=6)
    cv.rect(12, 30, 780, 42, C["clear"])
    cv.rect(12, 150, 780, 156, C["bg3"])
    return cv.result().resize((w, h), Image.NEAREST)


def tr_note(col):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        c = w / 2
        r = 84
        cv.circle(c, c, r + 3, fill=INK)
        cv.circle(c, c, r, fill=PAPER)
        cv.circle(c, c, r - 13, fill=col)
        return cv.result()
    return draw


def tr_center(i, n, w, h):
    # Momo above the song-title band (band: screen y 264..456, texture top rests at screen y ~20)
    out = blank(w, h)
    m = mascot.sized(mascot.MAIN, "good", 300)
    out.alpha_composite(m, (568 - 150, 0))
    return out


def build_transition(ctx):
    w = SubsetWriter(ctx.G, SCREEN, "rainbow_transition")
    w.put("rainbow_bg_top", tr_top)
    w.put("rainbow_bg_bottom", tr_bottom)
    w.put("rainbow_bg", tr_bg)
    w.put("text_bg", tr_text_bg)
    w.put("chara_left", tr_note(C["ka"]))
    w.put("chara_right", tr_note(C["don"]))
    w.put("chara_center", tr_center)
    return w.write()


# ================================================================== result transition
def shutter(accent):
    base = mix(PAPER, accent, 0.22)

    def draw(i, n, w, h):
        cv = Canvas(w, h, ss=1)
        cv.rect(0, 0, w, h, base)
        # pixel dot column
        for y in range(24, h - 12, 48):
            cv.rect(w // 2 - 3, y, w // 2 + 3, y + 6, alpha(accent, 150))
        cv.rect(0, 0, 3, h, INK)
        cv.rect(w - 3, 0, w, h, INK)
        # accent blocks top and bottom
        for y0, y1 in ((0, 9), (h - 9, h)):
            cv.rect(0, y0, w, y1, INK)
            for x in range(3, w - 3, 12):
                cv.rect(x, y0 + 3, min(x + 6, w - 3), y1 - 3, accent)
        return cv.result()
    return draw


def shutter_footer(accent):
    def draw(i, n, w, h):
        cv = Canvas(w, h, ss=1)
        cv.rect(0, 0, w, h, accent)
        cv.rect(0, 0, w, 3, INK)
        cv.rect(0, h - 9, w, h, INK)
        for x in range(0, w, 12):
            cv.rect(x, h - 6, x + 6, h - 3, accent)
        cv.rect(0, 3, w, 6, alpha(PAPER, 110))
        return cv.result()
    return draw


def build_result_transition(ctx):
    w = SubsetWriter(ctx.G, SCREEN, "result_transition")
    for pfx, col in (("1p", C["p1"]), ("2p", C["p2"]), ("4p", C["text2"])):
        w.put(f"{pfx}_shutter", shutter(col))
        w.put(f"{pfx}_shutter_footer", shutter_footer(col))
    return w.write()


# ================================================================== network message
NET_COL = [C["ka"], C["normal"], C["don"], C["roll"]]


def net_bar(i, n, w, h):
    cv = Canvas(w, h, ss=1)
    base = NET_COL[i]
    cv.rect(0, 0, w, h, mix(PAPER, base, 0.28))
    # tileable stair-step slats (period = the 64 px tile)
    for r, y in enumerate(range(6, h - 6, 3)):
        off = (r * 3) % 64
        for x0 in (off - 64, off, off + 64):
            if -16 < x0 < w:
                cv.rect(x0, y, x0 + 12, y + 3, alpha(base, 110))
    cv.rect(0, 0, w, 6, INK)
    cv.rect(0, h - 6, w, h, INK)
    cv.rect(0, 6, w, 9, base)
    cv.rect(0, h - 9, w, h - 6, base)
    return cv.result()


def net_dot(i, n, w, h):
    # a spinning drum: frames 0-3 coral face narrowing, 4 edge, 5-8 blue face widening
    cv = Canvas(w, h)
    c = w / 2
    ang = i / (n - 1) * math.pi
    k = abs(math.cos(ang))
    face = C["don"] if i < 4 else C["ka"]
    if i == 4:
        cv.rect(c - 3, 3, c + 3, h - 3, INK)
        return cv.result()
    rx = max(3, 15 * k)
    pixell(cv, c, c, rx + 3, 18, INK, px=3)
    pixell(cv, c, c, rx, 15, PAPER, px=3)
    pixell(cv, c, c, rx * 0.72, 11, face, px=3)
    return cv.result()


def net_dim(i, n, w, h):
    cv = Canvas(w, h, ss=1)
    cv.rect(0, 0, w, h, alpha(C["bg0"], 170))
    return cv.result()


def build_network(ctx):
    w = SubsetWriter(ctx.G, SCREEN, "network_msg")
    w.put("dim", net_dim)
    w.put("bar", net_bar)
    w.put("dot", net_dot)
    return w.write()


# ================================================================== module entry
def build(ctx):
    n = 0
    for f in (build_timer, build_nameplate, build_indicator, build_overlay, build_practice,
              build_transition, build_result_transition, build_network):
        n += f(ctx)
    return n
