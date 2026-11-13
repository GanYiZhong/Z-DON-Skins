"""Window chrome: the bible's five variants (2.2) on the U grid, plus pixbar and the speech bubble.

Every function draws on a CRISP Canvas (ss=1) in LOGICAL px; every coordinate must be a multiple of
U = 3 (snapped; SS_DEBUG=1 raises). Boxes are given by their OUTER border edge (x0, y0, x1, y1),
x1/y1 exclusive; the hard shadow falls OUTSIDE, down-right, so leave `shadow` px free there.

Spec at 1920x1080 logical (bible numbers translated: borders/shadows/notches keep their U counts,
heights and text scale x1.5 and snap to U, text by role 18 label / 24 body / 36 title / 48 stamp):

| variant  | border      | shadow | notch | fill                       | text                    |
|----------|-------------|--------|-------|----------------------------|-------------------------|
| dialog   | 2U ink      | 2U     | 1U    | paper; title band 16U gold + 1U ink rule | 36 title, 24/36 body inset 4U |
| panel    | 1U ink      | 1U     | 1U    | paper (or bg2)             | -, plate docked top-left |
| plate    | 1U ink      | 1U     | 1U    | paper + 18U accent icon cell | 36 tall 18U, ink text  |
| button   | 1U / focus 2U + gold | 1U, pressed 0 (+1U shift) | 1U | bg2 | 36             |
| chip     | 1U ink      | 0      | 0     | accent, or bg3 + 1U accent left edge | 18, 9U tall    |

Each draw function returns a Box with the inner content rect (inside the border) so callers place
text and icons without re-deriving the border widths.
"""
from __future__ import annotations

from dataclasses import dataclass


from .style import C, U, Canvas, snap

INK = C["ink"]
PAPER = C["paper"]

DIALOG_TITLE_H = 16 * U      # 48
PLATE_H = 18 * U             # 54
PLATE_ICON_W = 18 * U        # 54
CHIP_H = 10 * U              # 30 (owner 10-30: 24 px labels need 1U air, MIN_TEXT)
BUBBLE_MAX_W = 180 * U       # 540 (bible 360 px at 1280)
BUBBLE_PAD = 8 * U
TEXT = {"label": 18, "body": 24, "title": 36, "stamp": 48}


@dataclass
class Box:
    x0: int
    y0: int
    x1: int
    y1: int
    ix0: int    # inner (content) rect, inside the border
    iy0: int
    ix1: int
    iy1: int

    @property
    def cx(self):
        return (self.ix0 + self.ix1) / 2

    @property
    def cy(self):
        return (self.iy0 + self.iy1) / 2


def _crisp(cv: Canvas):
    if not cv.crisp:
        raise ValueError("chrome draws on a crisp canvas only (Canvas(..., ss=1))")


def _g(*v):
    return [snap(x) for x in v]


def notched(cv, x0, y0, x1, y1, col, notch):
    """A filled rectangle with its four corner squares (notch x notch) left out."""
    if notch:
        cv.rect(x0 + notch, y0, x1 - notch, y1, col)
        cv.rect(x0, y0 + notch, x1, y1 - notch, col)
    else:
        cv.rect(x0, y0, x1, y1, col)


def frame(cv, x0, y0, x1, y1, fill=None, border=U, shadow=U, notch=U, border_col=None, shadow_col=None) -> Box:
    """The one primitive behind every variant: hard shadow, notched ink border, flat fill."""
    _crisp(cv)
    x0, y0, x1, y1, border, shadow, notch = _g(x0, y0, x1, y1, border, shadow, notch)
    bc = border_col or INK
    if shadow:
        notched(cv, x0 + shadow, y0 + shadow, x1 + shadow, y1 + shadow, shadow_col or C["shade"], notch)
    notched(cv, x0, y0, x1, y1, bc, notch)
    if fill is not None:
        cv.rect(x0 + border, y0 + border, x1 - border, y1 - border, fill)
    else:   # border only: punch the inside back to transparent
        cv.rect(x0 + border, y0 + border, x1 - border, y1 - border, (0, 0, 0, 0))
    return Box(x0, y0, x1, y1, x0 + border, y0 + border, x1 - border, y1 - border)


# ---------------------------------------------------------------- the five variants
def dialog(cv, x0, y0, x1, y1, title=None, fill=None, title_fill=None) -> Box:
    """Modal window (retry, game over, popups). With a title: 16U gold band, 1U ink rule, 36 px ink
    title centred. The returned inner rect starts below the rule; inset body text by 4U."""
    b = frame(cv, x0, y0, x1, y1, fill or PAPER, border=2 * U, shadow=2 * U, notch=U)
    if title is not None:
        ty1 = b.iy0 + DIALOG_TITLE_H
        cv.rect(b.ix0, b.iy0, b.ix1, ty1, title_fill or C["focus"])
        cv.rect(b.ix0, ty1, b.ix1, ty1 + U, INK)
        cv.text(b.cx, (b.iy0 + ty1) / 2, title, TEXT["title"], INK if title_fill is None else C["on_acc"])
        b.iy0 = ty1 + U
    return b


def panel(cv, x0, y0, x1, y1, fill=None, plate_text=None, plate_accent=None, plate_w=None) -> Box:
    """Card: result, info, lists, timer. plate_text docks a `plate` on the top-left corner, overlapping
    the border by 1U: its top-left corner sits 1U up-left of the panel's (content starts below it)."""
    b = frame(cv, x0, y0, x1, y1, fill or PAPER, border=U, shadow=U, notch=U)
    if plate_text is not None:
        pw = plate_w or plate_width(plate_text)
        p = plate(cv, x0 - U, y0 - U, x0 - U + pw, y0 - U + PLATE_H, plate_text, plate_accent)
        b.iy0 = max(b.iy0, p.y1 + U)
    return b


def plate_width(text, size=36):
    w = PLATE_ICON_W + U + 3 * U + Canvas(1, 1).text_width(text, size) + 4 * U + U
    return int(-(-w // U) * U)


def plate(cv, x0, y0, x1, y1, text=None, accent=None, size=36, icon=None) -> Box:
    """Header / section label: paper text area with an accent icon cell (PLATE_ICON_W) on the left,
    1U ink divider. icon(cv, box_of_cell) may draw a glyph into the cell. Height is PLATE_H (18U)."""
    b = frame(cv, x0, y0, x1, y1, PAPER, border=U, shadow=U, notch=U)
    cx1 = b.ix0 + PLATE_ICON_W - U
    cv.rect(b.ix0, b.iy0, cx1, b.iy1, accent or C["p1"])
    cv.rect(cx1, b.iy0, cx1 + U, b.iy1, INK)
    if icon:
        icon(cv, Box(b.ix0, b.iy0, cx1, b.iy1, b.ix0, b.iy0, cx1, b.iy1))
    if text:
        cv.text(cx1 + U + 3 * U, b.cy, text, size, INK, anchor="lm")
    return Box(x0, y0, x1, y1, cx1 + U, b.iy0, b.ix1, b.iy1)


def button(cv, x0, y0, x1, y1, text=None, state="normal", size=36, fill=None) -> Box:
    """Menu item / はい・いいえ / settings row. state: normal | focused | pressed.
    focused = 2U ink border + gold fill (+ draw a ▶ cursor with cursor()); pressed = no shadow and
    the whole button (content included) shifted +1U down-right."""
    if state == "pressed":
        b = frame(cv, x0 + U, y0 + U, x1 + U, y1 + U, fill or C["bg2"], border=U, shadow=0, notch=U)
    elif state == "focused":
        b = frame(cv, x0, y0, x1, y1, C["focus"], border=2 * U, shadow=U, notch=U)
    else:
        b = frame(cv, x0, y0, x1, y1, fill or C["bg2"], border=U, shadow=U, notch=U)
    if text:
        cv.text(b.cx, b.cy, text, size, INK)
    return b


def chip(cv, x0, y0, x1, y1=None, text=None, accent=None, edge=False, size=18, text_col=None) -> Box:
    """Tag / judge chip / level / 真打 / 1曲目. Height defaults to CHIP_H (10U). edge=False: accent fill
    with ink text; edge=True: bg3 fill with a 1U accent left edge (judge chips)."""
    y1 = y0 + CHIP_H if y1 is None else y1
    if edge:
        b = frame(cv, x0, y0, x1, y1, C["bg3"], border=U, shadow=0, notch=0)
        cv.rect(b.ix0, b.iy0, b.ix0 + U, b.iy1, accent or C["clear"])
        b.ix0 += U
    else:
        b = frame(cv, x0, y0, x1, y1, accent or C["bg3"], border=U, shadow=0, notch=0)
    if text:
        cv.text(b.cx, b.cy, text, size, text_col or (C["on_acc"] if accent and not edge else INK))
    return b


# ---------------------------------------------------------------- meters, bubble, cursor
def pixbar(cv, x0, y0, x1, y1, frac, fill, groove=None, segs=0) -> Box:
    """Segmented meter: 1U ink frame, groove, flat fill. The fill width snaps down to whole U and the
    segment dividers (1U ink) sit on whole U columns."""
    _crisp(cv)
    x0, y0, x1, y1 = _g(x0, y0, x1, y1)
    cv.rect(x0, y0, x1, y1, INK)
    ix0, iy0, ix1, iy1 = x0 + U, y0 + U, x1 - U, y1 - U
    cv.rect(ix0, iy0, ix1, iy1, groove or C["bg3"])
    fw = int((ix1 - ix0) * max(0.0, min(1.0, frac)) // U * U)
    if fw > 0:
        cv.rect(ix0, iy0, ix0 + fw, iy1, fill)
    for i in range(1, segs):
        sx = ix0 + int(round((ix1 - ix0) * i / segs / U)) * U
        cv.rect(sx, iy0, sx + U, iy1, INK)
    return Box(x0, y0, x1, y1, ix0, iy0, ix1, iy1)


TAIL_STEPS = (18 * U, 12 * U, 6 * U)   # outer widths of the "steps" tail (each 3U tall, 3U shoulders)
BUBBLE_TAIL_H = 13 * U                 # the "steps" tail below (or above) the box: 2U neck + 3 x 3U + 2U shadow


def bubble_tail(cv, tx, y1, off=0, col=None, up=False):
    """The readable 3-step tail (promoted from v2_front): a box whose bottom border edge is y1 (top edge
    when up=True), axis tx. A 2U neck through the box's 2U hard shadow, then three steps 18U / 12U / 6U
    wide and 3U tall, 2U ink sides with paper inside; the last step is the solid ink tip. The paper runs
    up through the box's border, so the tail opens into the bubble. col: draw only the outer shape in col,
    shifted by off (the shadow pass). Extends BUBBLE_TAIL_H (with the shadow) past the box edge."""
    def r(xa, ya, xb, yb, c, o=0):
        if up:
            ya, yb = 2 * y1 - yb, 2 * y1 - ya
        cv.rect(xa + o, ya + o, xb + o, yb + o, c)
    top = y1 + 2 * U
    w0 = TAIL_STEPS[0]
    r(tx - w0 // 2, y1, tx + w0 // 2, top, col or INK, off)
    for i, w in enumerate(TAIL_STEPS):
        ya = top + i * 3 * U
        r(tx - w // 2, ya, tx + w // 2, ya + 3 * U, col or INK, off)
    if col is not None:
        return
    for i, w in enumerate(TAIL_STEPS[:-1]):
        iw = w - 4 * U
        ya = (y1 - 2 * U) if i == 0 else top + i * 3 * U
        r(tx - iw // 2, ya, tx + iw // 2, top + (i + 1) * 3 * U, PAPER)


def bubble(cv, x0, y0, x1, y1, tail_x, tail_dir="down", text=None, size=36, tail="small") -> Box:
    """Speech bubble: a dialog without a title band (2U border, 2U shadow) and a tail on the bottom
    (tail_dir="down") or top edge, its tip at tail_x pointing at the speaker's mouth row.
    tail: "steps" = the readable 3-step tail (bubble_tail: 18U / 12U / 6U, BUBBLE_TAIL_H past the box;
    use it whenever the bubble is 36 px text or larger), "small" = the compact 6U / 4U / 2U tail that
    overlaps the box edge (small bubbles in tight frames), None = no tail.
    Width rule: text + 2 x BUBBLE_PAD, at most BUBBLE_MAX_W."""
    if x1 - x0 > BUBBLE_MAX_W:
        raise ValueError(f"bubble wider than {BUBBLE_MAX_W}")
    tx = snap(tail_x)
    if tail in (None, "none") or tail == "steps":
        edge = y1 if tail_dir == "down" else y0
        if tail == "steps":
            bubble_tail(cv, tx, edge, off=2 * U, col=INK, up=tail_dir != "down")
        b = frame(cv, x0, y0, x1, y1, PAPER, border=2 * U, shadow=2 * U, notch=U)
        if tail == "steps":
            bubble_tail(cv, tx, edge, up=tail_dir != "down")
        if text:
            cv.text(b.cx, b.cy, text, size, INK)
        return b
    s = 3 * U
    # tail shadow, then the tail itself (ink outline, paper inside), stepping toward the speaker
    for pass_, off in (("shadow", 2 * U), ("body", 0)):
        for i in range(3):
            w = (3 - i) * 2 * U         # 6U, 4U, 2U wide steps
            if tail_dir == "down":
                yy = y1 - 2 * U + i * s
                rect = (tx - w // 2 + off, yy + off, tx + w // 2 + off, yy + s + off)
            else:
                yy = y0 + 2 * U - (i + 1) * s
                rect = (tx - w // 2 + off, yy + off, tx + w // 2 + off, yy + s + off)
            cv.rect(*rect, INK)
        if pass_ == "shadow":
            b = frame(cv, x0, y0, x1, y1, PAPER, border=2 * U, shadow=2 * U, notch=U)
    for i in range(3):   # paper inside the tail, 1U ink on each side
        w = (3 - i) * 2 * U - 2 * U
        if w <= 0:
            continue
        if tail_dir == "down":
            yy = y1 - 2 * U + i * s
            cv.rect(tx - w // 2, yy, tx + w // 2, yy + s - (U if i == 2 else 0), PAPER)
        else:
            yy = y0 + 2 * U - (i + 1) * s
            cv.rect(tx - w // 2, yy + (U if i == 2 else 0), tx + w // 2, yy + s, PAPER)
    if text:
        cv.text(b.cx, b.cy, text, size, INK)
    return b


def bubble_width(text, size=36):
    w = Canvas(1, 1).text_width(text, size) + 2 * BUBBLE_PAD + 4 * U
    return min(BUBBLE_MAX_W, int(-(-w // U) * U))


def bubble_image(text, tail_x=None, size=36, h=26 * U, tail="steps", tail_dir="down"):
    """A whole bubble as a PHYSICAL image: bubble_width(text) x h box (+2U shadow) with its tail
    (default the 3-step tail) at tail_x from the box's left edge (default the centre). The image is
    h + BUBBLE_TAIL_H tall for "steps" (the box at the top for "down", at the bottom for "up")."""
    bw = bubble_width(text, size)
    th = BUBBLE_TAIL_H if tail == "steps" else 2 * U
    cv = Canvas(bw + 2 * U, h + th)
    y0 = 0 if tail_dir == "down" or tail != "steps" else BUBBLE_TAIL_H - 2 * U
    tx = snap(bw // 2 if tail_x is None else tail_x)
    bubble(cv, 0, y0, bw, y0 + h, tx, tail_dir, text, size, tail=tail)
    return cv.result()


CURSOR_ROWS = ["X....", "XX...", "XXX..", "XXXX.", "XXXXX", "XXXX.", "XXX..", "XX...", "X...."]


def cursor(cv, x, cy, cell=U, fill=None):
    """▶ cursor: 5x9 cells (default 1U), ink outline 1 cell, gold fill. x = left edge, cy = centre."""
    from . import deco
    top = int((cy - 4.5 * cell) // U * U)
    deco.cells(cv, x, top, CURSOR_ROWS, {"X": fill or C["clear"]}, cell, outline=INK)


# ---------------------------------------------------------------- image helpers for SubsetWriter
def fit(w, h, shadow):
    """Largest grid box (x1, y1) that fits a w x h LOGICAL frame with its shadow."""
    return int((w - shadow) // U * U), int((h - shadow) // U * U)


def image(w, h, fn, *args, **kw):
    """Run a chrome fn on a fresh crisp canvas of a LOGICAL w x h frame, box at (0, 0) filling the
    frame minus the shadow; returns the PHYSICAL image. fn in (dialog, panel, plate, button, chip)."""
    cv = Canvas(w, h)
    sh = {dialog: 2 * U, panel: U, plate: U, button: U, chip: 0}.get(fn, U)
    x1, y1 = fit(w, h, sh)
    fn(cv, 0, 0, x1, y1, *args, **kw)
    return cv.result()


# ---------------------------------------------------------------- the hint pill (bible 2.2 + globals P1)
# ONE control hint on every screen: an ink bar 12U (36) tall (bible 8U at 1280 x1.5), notched, 1U ink
# shadow; items = [drum icon] 2U [18 px paper label], 6U between items, 4U padding. The drum icon is the
# one 8x8-cell sprite at k=3 (24 logical) with 2 states: "don" (face lit red) and "ka" (rim lit blue).
# Position rule (fix1029): bottom-CENTRE footer, centred on HINT_CX (the screen centre), bottom edge HINT_Y1
# (above the bottom band where the engine prints the credit line and the network icon, y >= 1028; 12 px
# above the usual ground line 1032). It sits between the 1P / 2P nameplates (x 14..420 / 1494..1900).
# Lua: UI.hint(items) draws the same thing from the baked global/ss_ui textures.
HINT_H = 14 * U          # 42 (owner 10-30: the label is 24 now, MIN_TEXT)
HINT_PAD = 4 * U
HINT_ICON = 8 * U        # 24: 8 cells at k=3
HINT_GAP = 2 * U         # icon -> label
HINT_SEP = 6 * U         # between items
HINT_CX, HINT_Y1 = 960, 1020
HINT_X1 = 1860           # legacy right anchor (only when a caller passes x1 explicitly)
HINT_LABEL = 18
HINT_DRUM = ["..KKKK..",
             ".KRRRRK.",
             "KRFFFFRK",
             "KRFFFFRK",
             "KRFFFFRK",
             "KRFFFFRK",
             ".KRRRRK.",
             "..KKKK.."]


def hint_drum(cv, x, y, state="don"):
    """The hint drum (8x8 cells at k=3 = 24 logical) with its top-left at (x, y). state "don": face lit
    (don red), rim wood; "ka": rim lit (ka blue), face paper."""
    from . import deco
    pal = {"K": INK, "R": C["ka"] if state == "ka" else C["wood"], "F": C["don"] if state == "don" else PAPER}
    deco.cells(cv, x, y, HINT_DRUM, pal, U)


def hint_width(items, size=HINT_LABEL):
    """Logical width of the pill for items [(icon "don"|"ka"|None, text), ...]."""
    cv = Canvas(1, 1)
    w = 2 * HINT_PAD
    for i, (icon, text) in enumerate(items):
        if i:
            w += HINT_SEP
        if icon:
            w += HINT_ICON + HINT_GAP
        w += cv.text_width(text, size)
    return int(-(-w // U) * U)


def hint(cv, items, cx=HINT_CX, y1=HINT_Y1, size=HINT_LABEL, x1=None) -> Box:
    """The hint pill centred on cx with its bottom edge on y1 (shadow outside); x1 (optional) anchors the
    right edge instead. items as hint_width. Bake it only where the screen is fully baked; screens with
    Lua should call UI.hint instead."""
    w = hint_width(items, size)
    x0 = snap(x1 - w) if x1 is not None else snap(cx - w / 2)
    y0 = snap(y1 - HINT_H)
    b = frame(cv, x0, y0, x0 + w, y0 + HINT_H, C["hint_bg"], border=U, shadow=U, notch=U)
    cx = x0 + HINT_PAD
    cy = y0 + HINT_H / 2
    for i, (icon, text) in enumerate(items):
        if i:
            cx += HINT_SEP
        if icon:
            hint_drum(cv, snap(cx), snap(cy - HINT_ICON / 2), icon)
            cx += HINT_ICON + HINT_GAP
        cv.text(cx, cy, text, size, C["n_rim"], anchor="lm")
        cx += cv.text_width(text, size)
    return b
