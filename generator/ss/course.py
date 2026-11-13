"""One course identity (core): the course glyphs, the course chip, the crown and the score-rank badge.
Every screen that shows a course, a crown or a rank uses these (song select, result, dan select, dan
result, game), in Python (baked) or through the baked `global/ss_course` subset + `UI.course.*` in Lua.

  KEYS                  ("easy", "normal", "hard", "oni", "ura"): engine course index 0..4
  name(course, lang)    かんたん / ふつう / むずかしい / おに / おに(裏)
  GLYPH, GLYPH_PAL      8x8 pixel glyphs (paper body, ink features, gold for ura's eyes / normal's dot)
  glyph(cv, cx, cy, course, cell=U)              glyph + 1-cell ink outline, centred (10 cells square)
  chip(cv, x0, y0, x1, course, text=None)        the course chip: chrome.chip edge style (bg3 + 1U
                                                 course edge + 18 px ink name)
  plate(cv, x0, y0, x1, course, text=None)       chrome.plate in the course colour with the glyph in its
                                                 icon cell (result / dan result headers)
  plate_icon(course)                             the icon callback for your own chrome.plate(...)
  crown(cv, x, y, kind, course=None, cell=U)     kind "none" | "clear" (course colour) | "fc" (gold, paper
                                                 jewels) | "dfc" (all-good / 全良: gold, ink jewels; pair
                                                 it with zenryo_chip, bible 2.3: no rainbow on a crown)
  zenryo_chip(cv, x0, y0, x1=None)               the 全良 chip: gold fill, 1U ink border, 18 px ink 全良
                                                 (ZENRYO_W wide, CHIP_H tall)
  RANKS, rank_badge(tier, r_cells=11, size=36)   score rank 0..6 = 粋 粋 粋 雅 雅 雅 極 (Nijiiro's
                                                 score_rank frames): pixel disc in the tier colour
  RAINBOW6                                       the one rainbow (course hues + gold), 6 blocks

Bible rules: rainbow only as 6 quantised blocks, and only on the soul gauge's full state and the 極 rank
ring (never on a crown); crowns are drawn only when earned ("none" = nothing); every coloured mark has
an ink outline."""
from __future__ import annotations

import math

from . import chrome, deco, style
from .style import C, U, Canvas

INK = C["ink"]
PAPER = C["paper"]

KEYS = ("easy", "normal", "hard", "oni", "ura")
NAMES = {"ja": ("かんたん", "ふつう", "むずかしい", "おに", "おに(裏)"),
         "en": ("Easy", "Normal", "Hard", "Oni", "Ura Oni")}
# the soul gauge's 6 blocks (course hues + gold); the one rainbow of the skin
RAINBOW6 = (C["oni"], C["easy"], C["clear"], C["normal"], C["hard"], C["ura"])

GLYPH = {   # 8x8 cells: P paper body, K ink feature, G gold
    "easy": ["PP....PP", "PPP..PPP", ".PPPPPP.", "...PP...", "...PP...", "...PP...", "..PPPP..", "........"],
    "normal": ["...PP...", ".PPPPPP.", ".PPGGPP.", "PPPGGPPP", ".PPPPPP.", "...PP...", "..PPPP..", "........"],
    "hard": ["...PP...", "..PPPP..", "..PPPP..", ".PPKKPP.", ".PKPPKP.", "PPPPPPPP", "PPPPPPPP", "........"],
    "oni": ["P......P", "PP....PP", ".PPPPPP.", "PPPPPPPP", "PKKPPKKP", "PPPPPPPP", "PPKKKKPP", ".PPPPPP."],
    "ura": ["P......P", "PP....PP", ".PPPPPP.", "PPPPPPPP", "PGGPPGGP", "PPPPPPPP", "PPKKKKPP", ".PPPPPP."],
}
GLYPH_PAL = {"P": PAPER, "K": INK, "G": C["clear"]}

CROWN = ["X...X...X", "XX.XXX.XX", "XXXXXXXXX", "XJXXJXXJX", "XXXXXXXXX"]
CROWN_KINDS = ("none", "clear", "fc", "dfc")
ZENRYO = {"ja": "全良", "en": "All Good"}

# score-rank tiers (Nijiiro score_rank frame order): (kanji, fill token or None = 極)
RANKS = (("粋", "paper"), ("粋", "wood"), ("粋", "bg3"), ("雅", "clear"), ("雅", "oni"), ("雅", "ura"), ("極", None))


def key(course) -> str:
    """Course index 0..4 or key -> key."""
    return KEYS[course] if isinstance(course, int) else course


def colour(course):
    return C[key(course)]


def name(course, lang="ja") -> str:
    return NAMES.get(lang, NAMES["ja"])[KEYS.index(key(course))]


# ---------------------------------------------------------------- glyph
def glyph_size(cell=U) -> int:
    """Logical size of a glyph with its outline (10 cells square)."""
    return 10 * cell


def glyph(cv, cx, cy, course, cell=U):
    """The course glyph centred on (cx, cy): 8x8 cells + a 1-cell ink outline (10 cells = 30 logical at
    cell U, 60 at 2U)."""
    rows = GLYPH[key(course)]
    s = 8 * cell
    deco.cells(cv, style.snap(cx - s / 2), style.snap(cy - s / 2), rows, GLYPH_PAL, cell, outline=INK)


def glyph_image(course, cell=U):
    s = glyph_size(cell)
    cv = Canvas(s, s)
    glyph(cv, s / 2, s / 2, course, cell)
    return cv.result()


# ---------------------------------------------------------------- chip and plate
CHIP_W = 42 * U       # 126: fits むずかしい / おに(裏) at 18 px


def chip(cv, x0, y0, x1=None, course=0, text=None, size=18, lang="ja"):
    """The course chip: chrome.chip edge style (bg3 fill, 1U ink border, 1U course-colour left edge),
    18 px ink course name. x1 defaults to x0 + CHIP_W. Returns the chrome Box."""
    x1 = x0 + CHIP_W if x1 is None else x1
    return chrome.chip(cv, x0, y0, x1, None, name(course, lang) if text is None else text,
                       accent=colour(course), edge=True, size=size)


def chip_image(course, lang="ja"):
    cv = Canvas(CHIP_W, chrome.CHIP_H)
    chip(cv, 0, 0, None, course, lang=lang)
    return cv.result()


def plate_icon(course):
    """Icon callback for chrome.plate(..., icon=...): the course glyph centred in the icon cell."""
    def draw(cv, box):
        glyph(cv, (box.ix0 + box.ix1) / 2, (box.iy0 + box.iy1) / 2, course, U)
    return draw


def plate(cv, x0, y0, x1, course, text=None, lang="ja", size=36):
    """A header plate in the course colour with the course glyph in its icon cell (fixes the blank
    course cell): chrome.plate + plate_icon. Height chrome.PLATE_H."""
    return chrome.plate(cv, x0, y0, x1, y0 + chrome.PLATE_H, name(course, lang) if text is None else text,
                        accent=colour(course), size=size, icon=plate_icon(course))


# ---------------------------------------------------------------- crown
def crown_size(cell=U):
    """(w, h) logical of a crown including its 1-cell outline: 11 x 7 cells."""
    return (len(CROWN[0]) + 2) * cell, (len(CROWN) + 2) * cell


def crown(cv, x, y, kind, course=None, cell=U):
    """Crown with its top-left OUTLINE corner at (x, y). kind: "none" (draws nothing: crowns are only
    drawn when earned), "clear" (course colour; paper when course is None), "fc" (gold, paper jewels),
    "dfc" / all-good / 全良 (gold, ink jewels; show zenryo_chip with it where there is room). Bible 2.3:
    the rainbow is the gauge's and the 極 ring's only, never a crown's. Also accepts 0..3."""
    if isinstance(kind, int):
        kind = CROWN_KINDS[kind]
    if kind == "none":
        return
    ox, oy = style.snap(x) + cell, style.snap(y) + cell
    if kind == "dfc":
        deco.cells(cv, ox, oy, CROWN, {"X": C["clear"], "J": INK}, cell, outline=INK)
        return
    fill = C["clear"] if kind == "fc" else (PAPER if course is None else colour(course))
    deco.cells(cv, ox, oy, CROWN, {"X": fill, "J": PAPER}, cell, outline=INK)


def crown_image(kind, course=None, cell=U, w=None, h=None):
    cw, ch = crown_size(cell)
    w, h = w or cw, h or ch
    cv = Canvas(w, h)
    crown(cv, style.snap((w - cw) / 2), style.snap((h - ch) / 2), kind, course, cell)
    return cv.result()


ZENRYO_W = 24 * U     # 72: 全良 at 18 px + padding (en "All Good": 42U)


def zenryo_w(lang="ja"):
    return ZENRYO_W if lang == "ja" else 42 * U


def zenryo_chip(cv, x0, y0, x1=None, lang="ja", size=18):
    """The 全良 chip that goes with the all-good crown: chrome.chip in gold (1U ink border, no shadow)
    with 18 px ink text, CHIP_H tall. x1 defaults to x0 + zenryo_w(lang). Returns the chrome Box."""
    x1 = x0 + zenryo_w(lang) if x1 is None else x1
    return chrome.chip(cv, x0, y0, x1, None, ZENRYO.get(lang, ZENRYO["ja"]), accent=C["clear"], size=size)


def zenryo_image(lang="ja"):
    cv = Canvas(zenryo_w(lang), chrome.CHIP_H)
    zenryo_chip(cv, 0, 0, None, lang)
    return cv.result()


# ---------------------------------------------------------------- score-rank badge
def rank_size(r_cells=11):
    return 2 * (r_cells + 1) * U + U


def rank_paste(cv, tier, cx, cy, r_cells=11, size=36):
    """Score-rank badge centred on (cx, cy): a pixel disc (r_cells cells of U + 1-cell ink ring) in the
    tier colour with a paper / bg3 inner ring and the kanji; 極 = paper disc with the 6-block rainbow ring."""
    s, tok = RANKS[tier]
    R = r_cells + 1
    x0, y0 = style.snap(cx - R * U), style.snap(cy - R * U)
    if tok is None:
        deco.pixdisc(cv, x0 + R * U, y0 + R * U, r_cells, PAPER, ring_w=1)
        ring = {(x + 1, y + 1) for x, y in deco.disc_cells(r_cells)} - \
               {(x + 3, y + 3) for x, y in deco.disc_cells(r_cells - 2)}
        for x, y in ring:
            ang = (math.atan2(y - R + .5, x - R + .5) + math.pi) / (2 * math.pi)
            cv.rect(x0 + x * U, y0 + y * U, x0 + (x + 1) * U, y0 + (y + 1) * U, RAINBOW6[int(ang * 6) % 6])
    else:
        deco.pixdisc(cv, x0 + R * U, y0 + R * U, r_cells, C[tok], ring_w=1,
                     inner_ring=(PAPER, 1) if tok != "paper" else (C["bg3"], 1))
    c = (x0 + R * U, y0 + R * U)
    if tok == "ura":
        cv.text(c[0], c[1], s, size, PAPER, outline=U)
    else:
        cv.text(c[0], c[1], s, size, INK)


def rank_badge(tier, r_cells=11, size=36):
    """PHYSICAL image of a rank badge (rank_size(r_cells) logical square). r_cells 11 / size 36 = HUD and
    song select; 21 / 48 = result."""
    W = rank_size(r_cells)
    cv = Canvas(W, W)
    R = r_cells + 1
    rank_paste(cv, tier, R * U, R * U, r_cells, size)
    return cv.result()
