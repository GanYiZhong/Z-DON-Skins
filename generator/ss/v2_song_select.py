"""Song select v2 (Graphics/song_select, Scripts/song_select): Nijiiro's horizontal wheel, difficulty
select, option / neiro panels, the one-menu sort window and the dan shutter, redrawn as original light
8-bit art on the U grid (ss/chrome.py). Nijiiro's Lua and geometry are kept; LUA_PATCHES recolour its
text for the light boards, drop the float-scaled / pulsing effects the bible bans (glow pulse, badge
scale, diff-mark stretch, ura switch cells, genre characters) and hook our own script
(lua/song_select/song_select/ss_sel.lua: backdrop clouds, the blinking cursors, the course-select open,
the hint pill, the menu mascots on their nameplates).

Accents on this screen (bible 2.3): the course colours (one system) and gold focus. The genre tint
lives only in the two end bands of a plate (user request: genre-tinted plates).

Intentional geometry deviations (VRAM; tools/verify_geometry.py reports them, see the report):
single-file replacements for multi-frame keys whose frames would all be identical, and 1x1 blanks for
keys our Lua patches never draw (DEVIATIONS)."""
from __future__ import annotations

import os

from PIL import Image, ImageDraw

from . import chrome, course, deco, style
from .atlas import OwnSubset, SubsetWriter, to_phys_entry
from .style import C, U, Canvas, blank_l, font_phys, px

NAME = "v2_song_select"   # build.py --only name; our own Lua lives in lua/song_select (copied in build())
OWNS = ["Graphics/song_select", "Scripts/song_select"]
SCREEN = "song_select"
LANG = "ja"

INK = C["ink"]
PAPER = C["paper"]
COURSE = ["easy", "normal", "hard", "oni", "ura"]
# box frame (engine genre_to_ref_frame) -> palette token of the plate end bands
# 0 default/tutorial, 1 J-POP, 2 anime, 3 game, 4 namco, 5 classical, 6 variety, 7 children,
# 8 vocaloid, 9 recent, 10 dan, 11 event, 12 sort
GENRE = ["sky", "ka", "balloon", "ura", "don", "wood", "grass", "pink", "hard", "mute", "dan", "oni", "line"]
DEVIATIONS: list[str] = []

# Dynamic text (SCREEN_GUIDE_V2 §11): no words are baked on this screen except the 粋/雅/極 rank marks
# (decision rows). Every label, tag, mark and course name is engine text drawn by ss_sel.lua in the
# player's language (ss/strings.py keys); the textures below are the word-free chrome only.
LANGS = ("ja", "en")   # the ancestor's localised key variants we override (Lua get_any: base, _en, _ja)


# ================================================================== local helpers
def put_single(w: SubsetWriter, key, im, why):
    """Write `key` as ONE image whatever the ancestor's frame count (the engine draws a single
    texture for any frame index). Used where every frame would be identical (VRAM)."""
    g = w.geo(key)
    w.out[key] = ("file", im)
    w.keys[key] = to_phys_entry(g.entry, g.scale)
    w.mode[key] = "crisp"
    DEVIATIONS.append(f"{w.screen}/{w.subset}/{key}: single {im.width // style.D}x{im.height // style.D} "
                      f"(ancestor {len(g.frames)} x {g.frames[0][0]}x{g.frames[0][1]}): {why}")


def put_tiny(w: SubsetWriter, key, why="never drawn (Lua patched)"):
    put_single(w, key, blank_l(U, U), why)


def rows_size(rows, cell):
    return len(rows[0]) * cell, len(rows) * cell


def glyph(cv, x, y, rows, pal, cell=U, outline=INK):
    deco.cells(cv, x, y, rows, pal, cell, outline=outline)


# ---------------------------------------------------------------- pixel glyphs (our own designs)
# course glyphs, crowns and rank badges come from ss/course.py (the one course identity)
STAR = ["...X...", "..XXX..", "XXXXXXX", ".XXXXX.", "..XXX..", ".XX.XX.", "XX...XX"]
ARROW_L = ["...X", "..XX", ".XXX", "XXXX", ".XXX", "..XX", "...X"]
DOWN = ["XXXXXXXXX", ".XXXXXXX.", "..XXXXX..", "...XXX...", "....X...."]
ICON_BACK = ["...K...", "..KK...", ".KKKKKK", "KKKKKKK", ".KKKKKK", "..KK...", "...K..."]
ICON_GEAR = ["...K...", ".KKKKK.", ".KK.KK.", "KK...KK", ".KK.KK.", ".KKKKK.", "...K..."]
ICON_NOTE = ["..KKKKK", "..K...K", "..K...K", "..K...K", "KKK.KKK", "KKK.KKK", ".K...K."]


def course_glyph(cv, cx, cy, c, cell):
    course.glyph(cv, cx, cy, c, cell)


# ================================================================== box
BOARD_W, BOARD_H = 960, 352
BX1, BY1 = 957, 348            # board outer edge (1U shadow falls in 957..960 / 348..351)
BAND_L, BAND_R = 81, 876       # left band 3..81 | 1U ink | paper 84..873 | 1U ink | 876..954 band


STUD = [".XX.", "XXXX", "XXXX", ".XX."]
STUD_PITCH = 12 * U            # one stud per 36 px, centred on the plate's centre row (176): any crop keeps the rhythm


def band_studs(cv, left=True):
    """r3 (SS5): a column of paper studs down the end bands, so the bands of the open (focused) plate are
    not empty sky-blue columns. Song plates: right band only (the left band is the crown / rank column);
    folders: both; the back plate: none (its ◀ owns the left band)."""
    for xl in ((36, 909) if left else (909,)):  # band centres 42 / 915, 4-cell stud = 12 px
        for k in range(-4, 5):
            glyph(cv, xl, 170 + k * STUD_PITCH, STUD, {"X": PAPER})


def board(i, kind):
    cv = Canvas(BOARD_W, BOARD_H)
    band = C["bg3"] if kind == "back" else C[GENRE[i]]
    centre = C["bg2"] if kind in ("folder", "folder_open") else PAPER
    b = chrome.frame(cv, 0, 0, BX1, BY1, centre, border=U, shadow=U, notch=U)
    cv.rect(b.ix0, b.iy0, BAND_L, b.iy1, band)
    cv.rect(BAND_L, b.iy0, BAND_L + U, b.iy1, INK)
    cv.rect(BAND_R - U, b.iy0, BAND_R, b.iy1, INK)
    cv.rect(BAND_R, b.iy0, b.ix1, b.iy1, band)
    if kind != "back":
        band_studs(cv, left=(kind != "song"))
    if kind == "folder_open":     # title rule: the title rises to y-94 (frame 82), lines sit below
        cv.rect(BAND_L + U + 9 * U, 129, BAND_R - U - 9 * U, 129 + U, INK)
    if kind == "back":            # a ◀ in the left band, on the centre row so it survives the crop
        rows = ARROW_L
        w, h = rows_size(rows, U)
        glyph(cv, style.snap((3 + BAND_L) / 2 - w / 2), style.snap(176 - h / 2), rows, {"X": C["clear"]})
    return cv.result()


def focus_ring(w, h, ox, oy, bw, bh, notch=U):
    """2U ink + 2U gold ring hugging a box of bw x bh whose top-left sits at (ox, oy) in the frame."""
    cv = Canvas(w, h)
    x0, y0, x1, y1 = ox - 4 * U, oy - 4 * U, ox + bw + 4 * U, oy + bh + 4 * U
    chrome.notched(cv, x0, y0, x1, y1, INK, notch)
    cv.rect(x0 + 2 * U, y0 + 2 * U, x1 - 2 * U, y1 - 2 * U, C["clear"])
    cv.rect(ox, oy, ox + bw, oy + bh, (0, 0, 0, 0))
    return cv.result()


def background_image():
    cv = Canvas(1920, 1080, bg=C["bg0"])
    deco.sky(cv, 0, 0, 1920, 216)
    deco.ground(cv, 0, GROUND_Y, 1920, 1080)
    return cv.result()


GROUND_Y = 1032
# fix1029: the hint pill moved to the bottom centre (y 984..1023). The wheel's lower plates reach y ~1010 at
# x 480..1520, so the backdrop's bottom strip (cream + ground) from FOOTER_Y down is drawn again over the
# wheel (SongSelect:draw_footer: after the navigator, before the nameplates / mascots / panels / pill):
# plates slide behind the floor 3U above the pill instead of under it.
FOOTER_Y = 975


def footer_image():
    full = background_image()
    return full.crop((0, style.px(FOOTER_Y), full.width, full.height))


def build_box(G, lang):
    w = SubsetWriter(G, SCREEN, "box")
    put_single(w, "background", background_image(),
               "static backdrop (sky band + ground); Lua draws it once and drifts the clouds")
    w.put("bar_genre", lambda i, n, ww, hh: board(i, "song"))
    w.put("folder_graphic", lambda i, n, ww, hh: board(i, "folder_open"))
    w.put("bar_genre_back", lambda i, n, ww, hh: board(0, "back"))
    # focus ring: the board sits at (32, 24) inside the 1024x400 frame (Lua draw_glow)
    w.put("bar_genre_overlay", lambda i, n, ww, hh: focus_ring(ww, hh, 32, 24, BX1, BY1))
    put_tiny(w, "box_chara", "genre characters: draw removed (Lua patch)")
    w.put_blank("genre_overlay_large")
    blank_unused(w)
    return w.write()


# ================================================================== yellow_box
def frame_score(i):
    """184x96 course plate on an open song board: course cell (glyph + engine name) | ★ + level."""
    cv = Canvas(184, 96)
    b = chrome.frame(cv, 0, 0, 180, 93, PAPER, border=U, shadow=U, notch=U)
    # text24: the course name (24 px, up to 6 glyphs: むずかしい / 오니(우라)) no longer fits the 99 px cell, so
    # the plate is two bands: icon cell | level on top (3..48), the name on a full-width course-colour strip
    # below (51..90, ink rule between; ss: draw_plates puts the name at the strip centre)
    cv.rect(b.ix0, b.iy0, 99, 48, C[COURSE[i]])
    cv.rect(99, b.iy0, 102, 48, INK)
    cv.rect(b.ix0, 48, b.ix1, 51, INK)
    cv.rect(b.ix0, 51, b.ix1, b.iy1, C[COURSE[i]])
    course_glyph(cv, 54, 27, COURSE[i], U)   # 3 px right of the cell centre: clear of the 30 px 分 chip
    return cv.result()


def level_number(i):
    lv = i % 11 + 1
    cv = Canvas(48, 48)
    if lv <= 10:
        cv.text(24, 24, str(lv), 36, INK)
    else:
        cv.text(24, 24, "10+", 24, INK)
    return cv.result()


def star_img(w, h, fill):
    cv = Canvas(w, h)
    sw, sh = rows_size(STAR, U)
    glyph(cv, style.snap((w - sw) / 2), style.snap((h - sh) / 2), STAR, {"X": fill})
    return cv.result()


def crown_img(w, h, kind, c, cell):
    """course.crown centred in a w x h frame (kind clear | fc | dfc; c None = paper clear crown)."""
    return course.crown_image(kind, c, cell, w, h)


def rank_badge(w, h, tier, r_cells, size):
    """course.rank_badge (the one rank language, disc badges) centred in a w x h frame."""
    cv = Canvas(w, h)
    course.rank_paste(cv, tier, w / 2, h / 2, r_cells, size)
    return cv.result()


# branch / ura marks and the tags (新曲, 新音源, 旧音源, 期間限定, お気に入り): ss_sel.lua draws each chip sized
# to the measured text (SS_SEL:mark / SS_SEL:tag); their textures are blank.
COUNT_H = 18 * U   # the 「N曲目」 chip height (fix1029)
COUNT_Y = 195      # its top edge (fix1029; Nijiiro 234): clear of the 2P readout card (top 263)
COUNT_TEXT_Y = 202  # skin_config song_num y (engine text top) centring 「N曲目」 in the chip


def song_count_back():
    cv = Canvas(280, 72)
    # the engine draws 「N曲目」 white with a black outline (fixed colours): a mid-tone fill under it
    # one mute chip around 「N曲目」 (the old bg3 right cell sat empty whenever no song limit is set);
    # with a limit, ss_sel.lua adds the bg3 「M曲」 cell (ss_sel/count_max) on the right
    # fix1029: 18U (54) tall (was 23U): it sits at y 195..249 between the のこり tile (ends y 183) and the
    # 2P course readout card (top y 263), which now mirrors the 1P card at x 1619..1895
    chrome.frame(cv, 0, 0, 165, COUNT_H, C["mute"], border=U, shadow=U, notch=U)
    return cv.result()


def song_count_max():
    """The 「M曲」 cell docked right of the 「N曲目」 chip (same 280x72 frame, drawn only with a limit)."""
    cv = Canvas(280, 72)
    chrome.frame(cv, 162, 0, 276, COUNT_H, C["bg3"], border=U, shadow=U, notch=U)
    return cv.result()


def build_yellow_box(G, lang):
    w = SubsetWriter(G, SCREEN, "yellow_box")
    for kind in ("clear", "fc", "dfc"):
        w.put(f"crown_{kind}", lambda i, n, ww, hh, k=kind: crown_img(ww, hh, k, i, 2 * U))
    w.put("frame_score", lambda i, n, ww, hh: frame_score(i))
    w.put("level_number", lambda i, n, ww, hh: level_number(i))
    w.put("score_rank", lambda i, n, ww, hh: rank_badge(ww, hh, i // 5, 10, 36))
    w.put("s_crown_outline", lambda i, n, ww, hh: rank_badge(ww, hh, i, 5, 18))
    w.put("star", lambda i, n, ww, hh: star_img(ww, hh, C[COURSE[i]]))
    for k in ("branch_indicator", "branch_indicator_diff", "branch_indicator_ura", "ex_data_new_audio",
              "ex_data_old_audio"):
        w.put_blank(k)
    for lg in LANGS:
        for k in ("ex_data_new_song", "ex_data_limited_time", "favorite_1p", "favorite_2p"):
            w.put_blank(f"{k}_{lg}")
    w.put("song_count_back", lambda i, n, ww, hh: song_count_back())
    # button focus ring behind the 128x128 back / option buttons (button box 0..123 at +20)
    # r3: the buttons are card-tall, so the ring is 168x400 (selector draws it centred on DS_BOARD_Y)
    put_single(w, "s_crown_clear", focus_ring(168, 400, 20, 20, 123, 357),
               "focus ring of the card-tall back / option columns (r3 SS2)")
    put_tiny(w, "s_crown_dfc", "oni<->ura switch cells: draw removed (Lua patch)")
    put_tiny(w, "s_crown_fc", "oni<->ura switch cells: draw removed (Lua patch)")
    blank_unused(w)
    return w.write()


# ================================================================== diff_select
COL_W, COL_H = 200, 360


def column(i):
    cv = Canvas(COL_W, COL_H)
    b = chrome.frame(cv, 0, 0, 198, 357, C[COURSE[i]], border=U, shadow=U, notch=U)
    # paper info card in the lower half: engine course name (y 229), ★ level (246-286), pips (296)
    chrome.frame(cv, 9, 201, 189, 348, PAPER, border=U, shadow=0, notch=U)
    course_glyph(cv, 99, 117, COURSE[i], 9)
    return cv.result()


BACK_X1 = 1224


# r3 (SS2): the board is 60 px shorter and the header 60 px lower in height (title 152 / subtitle 210,
# box_song patch); the marker lane, the cards and the (now card-tall) buttons moved up 60 (box_base DS_*)
DS_SHIFT = 60


def difficulty_back():
    w, h = 1272, 784 - DS_SHIFT
    cv = Canvas(w, h)
    x1, y1 = chrome.fit(w, h, 2 * U)
    # drawn at x 324: the board (shadow included) ends at abs x 1554, clear of the global status tiles
    # (x >= 1570) and of the 1曲目 plate; the oni column's focus ring ends at abs 1514
    x1 = BACK_X1
    chrome.frame(cv, 0, 0, x1, y1, PAPER, border=2 * U, shadow=2 * U, notch=U)
    chrome.frame(cv, 30, 48, x1 - 18, 252 - DS_SHIFT, C["bg2"], border=U, shadow=U, notch=U)   # header (y 152/210)
    return cv.result()


BTN_H = 360   # r3 (SS2): もどる / オプション are card-tall columns (200x360 course cards), drawn at DS_BOARD_Y


def button_tall(icon):
    """128x360 frame: a bg2 column like the course cards (0..123 x 0..357): icon in the top half, a paper
    card in the lower half (same card rows as the course names) for the label ss_sel.lua draws."""
    cv = Canvas(128, BTN_H)
    s = style.snap(128 * 123 / 128)
    b = chrome.button(cv, 0, 0, s, 357)
    gw, gh = rows_size(icon, 3 * U)
    glyph(cv, style.snap(b.cx - gw / 2), style.snap(117 - gh / 2), icon, {"K": INK}, cell=3 * U, outline=None)
    chrome.frame(cv, 9, 201, s - 9, 348, PAPER, border=U, shadow=0, notch=U)
    return cv.result()


def button_img(w, h, icon):
    """The 音色 button (the default player UI's neiro slot; unused with option_neiro_row): icon only."""
    cv = Canvas(w, h)
    s = style.snap(w * 123 / 128)
    b = chrome.button(cv, 0, 0, s, s)
    gw, gh = rows_size(icon, 2 * U)
    glyph(cv, style.snap(b.cx - gw / 2), style.snap(b.cy - gh / 2), icon, {"K": INK}, cell=2 * U, outline=None)
    return cv.result()


def player_balloon(p):
    cv = Canvas(124, 124)
    chrome.frame(cv, 26, 12, 98, 48, C["p1" if p == 1 else "p2"], border=U, shadow=U, notch=U)
    return cv.result()   # "1P" / "2P": ss_sel.lua (SS_SEL:marker_label)


def diff_star(i, w, h):
    cv = Canvas(w, h)
    if i == 0:
        glyph(cv, 6, 6, STAR, {"X": C["clear"]})
    elif i <= 10:
        cv.text(9, 21, str(i), 36, INK, anchor="lm")
    else:
        cv.text(9, 21, "10+", 24, INK, anchor="lm")
    return cv.result()


def pip_groove(w, h):
    cv = Canvas(w, h)
    for k in range(10):
        x0 = 12 + 15 * k
        cv.rect(x0, 6, x0 + 12, 18, INK)
        cv.rect(x0 + U, 9, x0 + 9, 15, C["bg3"])
    return cv.result()


def pip_filled(w, h):
    """Lua tints it with the course colour: the paper core becomes the course colour, the ink edge stays dark."""
    cv = Canvas(w, h)
    cv.rect(5, 6, 17, 18, INK)
    cv.rect(8, 9, 14, 15, PAPER)
    return cv.result()


def course_readout(i):
    """main_diff_mark slot (680x680 centred at (200, 408)): a course card fully on screen at x 24..300."""
    cv = Canvas(680, 680)
    # card at abs y 263..473 (24U above the r1 spot): the inset option panel (top abs 484) never covers it
    b = chrome.frame(cv, 165, 195, 441, 405, PAPER, border=U, shadow=U, notch=U)
    cv.rect(b.ix0, b.iy0, b.ix1, 312, C[COURSE[i]])
    cv.rect(b.ix0, 312, b.ix1, 315, INK)
    course_glyph(cv, b.cx, 255, COURSE[i], 6)
    return cv.result()   # course name: ss_sel.lua (SS_SEL:readout_name, UI.course.name)


def build_diff_select(G, lang):
    w = SubsetWriter(G, SCREEN, "diff_select")
    put_single(w, "difficulty_back", difficulty_back(), "one neutral backboard for every genre")
    w.put("difficulty_bar", lambda i, n, ww, hh: column(i))
    ring = lambda i, n, ww, hh: focus_ring(ww, hh, 24, 24, 198, 357)  # noqa: E731
    w.put("difficulty_select_bar", ring)
    w.put("difficulty_select_bar2", ring)
    w.put("difficulty_crown", lambda i, n, ww, hh: style.blank_l(ww, hh) if i == 0 else
          crown_img(ww, hh, ["clear", "clear", "fc", "dfc"][i], None, U))
    w.put("difficulty_star", lambda i, n, ww, hh: diff_star(i, ww, hh))
    w.put("ura_oni_plate", lambda i, n, ww, hh: pip_groove(ww, hh))
    w.put("disable", lambda i, n, ww, hh: pip_filled(ww, hh))
    for lg in LANGS:
        put_single(w, f"back_{lg}", button_tall(ICON_BACK),
                   "card-tall もどる column (r3 SS2; box_song draws it 128x360 at DS_BOARD_Y)")
        put_single(w, f"option_{lg}", button_tall(ICON_GEAR),
                   "card-tall オプション column (r3 SS2; box_song draws it 128x360 at DS_BOARD_Y)")
        w.put(f"neiro_{lg}", lambda i, n, ww, hh: button_img(ww, hh, ICON_NOTE))
    w.put("1p_balloon", lambda i, n, ww, hh: player_balloon(1))
    w.put("2p_balloon", lambda i, n, ww, hh: player_balloon(2))
    put_tiny(w, "diff_tower", "control-guide loop sheet: never drawn (Lua patch; UI.hint is the one hint pill)")
    w.put("diff_tower_shadow", lambda i, n, ww, hh: course_readout(i))
    w.put_blank("ura_switch")
    blank_unused(w)
    return w.write()


def build_diff_mark_anim(G):
    w = SubsetWriter(G, SCREEN, "diff_mark_anim")
    for i in range(5):
        put_tiny(w, f"mark_{i}", "decide / intro stretch removed (Lua patch: the readout is static)")
        put_tiny(w, f"white_{i}", "decide flash removed (Lua patch)")
    return w.write()


# ================================================================== global
def build_global(G, lang):
    w = SubsetWriter(G, SCREEN, "global")
    for k in ("background_diff", "background_diff_highlight", "bg_diff_text", "bg_diff_text_bg", "song_num_bg"):
        w.put_blank(k)
    # the 曲をえらぶ / むずかしさをえらぶ header plates: loaded by song_select.lua but never drawn (the course
    # select header holds the song title): blank, no baked words
    for key in ("song_select", "difficulty_select"):
        for lg in LANGS:
            w.put_blank(f"{key}_{lg}")
    blank_unused(w)
    return w.write()


# ================================================================== modifier / neiro
def option_top(w, h, band_to=78):
    cv = Canvas(w, h)
    x1, y1 = chrome.fit(w, h, 2 * U)
    b = chrome.frame(cv, 0, 0, x1, y1, PAPER, border=2 * U, shadow=2 * U, notch=U)
    cv.rect(b.ix0, b.iy0, b.ix1, band_to, C["focus"])
    cv.rect(b.ix0, band_to, b.ix1, band_to + U, INK)
    return cv.result()


def player_chip(w, h, p):
    cv = Canvas(w, h)
    chrome.frame(cv, 6, 15, 57, 48, C["p1" if p == 1 else "p2"], border=U, shadow=U, notch=U)
    return cv.result()   # "1P" / "2P": ss_sel.lua (SS_SEL:panel_label)


def row_img(w, h, focused):
    cv = Canvas(w, h)
    if focused:
        chrome.button(cv, 0, 0, 363, 51, state="focused")
    else:
        chrome.button(cv, 0, 0, 363, 51)
    return cv.result()


def value_box(w, h):
    cv = Canvas(w, h)
    chrome.frame(cv, 0, 0, 180, 39, PAPER, border=U, shadow=0, notch=U)
    return cv.result()


def arrow_img(w, h, right=False, cell=U):
    cv = Canvas(w, h)
    rows = [r[::-1] for r in ARROW_L] if right else ARROW_L
    aw, ah = (len(rows[0]) + 2) * cell, (len(rows) + 2) * cell
    glyph(cv, style.snap((w - aw) / 2) + cell, style.snap((h - ah) / 2) + cell, rows, {"X": C["clear"]}, cell)
    return cv.result()


# speed badges (digits) stay baked; the word badges 自 ド 反 気 乱 are drawn by ss_sel.lua (SS_SEL:mod_badge,
# sized to the text): their textures are blank
MOD_ICON = {"mod_baisaku": "2.0", "mod_sanbai": "3.0", "mod_yonbai": "4.0"}
MOD_WORD = ("mod_auto", "mod_doron", "mod_abekobe", "mod_kimagure", "mod_detarame")


def mod_icon(w, h, s):
    cv = Canvas(w, h)
    b = chrome.frame(cv, 3, 3, 36, 36, C["bg3"], border=U, shadow=0, notch=U)
    cv.text(b.cx, b.cy, s, 24 if len(s) == 1 else 18, INK, max_w=b.ix1 - b.ix0)
    return cv.result()


def build_modifier(G):
    w = SubsetWriter(G, SCREEN, "modifier")
    w.put("top", lambda i, n, ww, hh: option_top(ww, hh))
    w.put("1p", lambda i, n, ww, hh: player_chip(ww, hh, 1))
    w.put("2p", lambda i, n, ww, hh: player_chip(ww, hh, 2))
    w.put_blank("bottom")
    w.put_blank("background")
    w.put("mod_bg", lambda i, n, ww, hh: row_img(ww, hh, False))
    w.put("mod_bg_highlight", lambda i, n, ww, hh: row_img(ww, hh, True))
    w.put("mod_box", lambda i, n, ww, hh: value_box(ww, hh))
    w.put("blue_arrow", lambda i, n, ww, hh: arrow_img(ww, hh))
    for k, s in MOD_ICON.items():
        w.put(k, lambda i, n, ww, hh, s=s: mod_icon(ww, hh, s))
    for k in MOD_WORD:
        w.put_blank(k)
    for v in ("1_1", "1_2", "1_3", "1_4", "1_5", "1_6", "1_7", "1_8", "1_9", "2", "2_5", "3", "3_5", "4"):
        label = v.replace("_", ".") if "_" in v else v + ".0"
        w.put(f"mod_speed_x{v}", lambda i, n, ww, hh, s=label: mod_icon(ww, hh, s))
    return w.write()


def digit_img(w, h, s, size, fill=INK):
    """fill=PAPER for glyphs the Lua tints (score_history passes a colour)."""
    cv = Canvas(w, h)
    cv.text(w / 2, h / 2, s, size, fill)
    return cv.result()


def build_neiro(G):
    w = SubsetWriter(G, SCREEN, "neiro")
    w.put("background", lambda i, n, ww, hh: option_top(ww, hh))
    w.put("1p", lambda i, n, ww, hh: player_chip(ww, hh, 1))
    w.put("2p", lambda i, n, ww, hh: player_chip(ww, hh, 2))
    w.put("blue_arrow", lambda i, n, ww, hh: arrow_img(ww, hh))
    w.put_blank("music_note")
    w.put("divisor", lambda i, n, ww, hh: digit_img(ww, hh, "/", 18))
    w.put("counter", lambda i, n, ww, hh: digit_img(ww, hh, str(i), 18))
    return w.write()


# ================================================================== diff_sort (one-menu sort window)
def sort_window(w, h):
    cv = Canvas(w, h)
    x1, y1 = chrome.fit(w, h, 2 * U)
    b = chrome.frame(cv, 0, 0, x1, y1, PAPER, border=2 * U, shadow=2 * U, notch=U)
    cv.rect(b.ix0 + 6 * U, 153, b.ix1 - 6 * U, 156, INK)       # rule under the title / song count
    return cv.result()


def build_diff_sort(G):
    w = SubsetWriter(G, SCREEN, "diff_sort")
    w.put("background", lambda i, n, ww, hh: sort_window(ww, hh))
    w.put("level_box", lambda i, n, ww, hh: _btn(ww, hh, "normal"))
    w.put("box_highlight", lambda i, n, ww, hh: _btn(ww, hh, "focused"))
    w.put_blank("box_outline")
    w.put("arrow", lambda i, n, ww, hh: arrow_img(ww, hh, right=(i == 1), cell=2 * U))
    w.put("diff", lambda i, n, ww, hh: _course_chip(ww, hh, i))
    w.put("stat_num", lambda i, n, ww, hh: digit_img(ww, hh, str(i), 48))
    put_tiny(w, "star_select_text", "control-guide loop sheet: never drawn (Lua patch; UI.hint is the one hint pill)")
    blank_unused(w)
    return w.write()


def _btn(w, h, state):
    cv = Canvas(w, h)
    x1, y1 = chrome.fit(w, h, U)
    chrome.button(cv, 0, 0, x1, y1, state=state)
    return cv.result()


def _course_chip(w, h, i):
    cv = Canvas(w, h)
    b = chrome.frame(cv, 3, 3, 90, 90, C[COURSE[i]], border=U, shadow=U, notch=U)
    course_glyph(cv, b.cx, b.cy, COURSE[i], 2 * U)
    return cv.result()


# ================================================================== dan transition
def kanji_mask(s, cell_phys):
    """A kanji from the 12 px pixel font at a whole multiple (cell_phys phys px per font px), 1-bit."""
    f = font_phys(12 * cell_phys)
    asc, desc = f.getmetrics()
    w = int(f.getlength(s)) + 2
    m = Image.new("L", (w, asc + desc), 0)
    d = ImageDraw.Draw(m)
    d.fontmode = "1"
    d.text((0, 0), s, font=f, fill=255)
    return m.crop(m.getbbox())


def dan_transition_image():
    cv = Canvas(2000, 1080)
    # door panel 1200x1080 (the right door; Lua mirrors it for the left): slatted shutter, seam on x=0
    cv.rect(0, 0, 1200, 1080, C["bg2"])
    for y in range(36, 1080, 36):
        cv.rect(15, y, 1200, y + U, C["line"])
    cv.rect(0, 0, 2 * U, 1080, INK)
    cv.rect(2 * U, 0, 4 * U, 1080, C["dan"])
    cv.rect(4 * U, 0, 5 * U, 1080, INK)
    # kanji stamps 段 位 道 場 in 400x400 cells
    for (cx0, cy0), k in zip(((1200, 0), (1600, 0), (1200, 400), (1600, 400)), "段位道場"):
        b = chrome.frame(cv, cx0 + 33, cy0 + 33, cx0 + 360, cy0 + 360, C["dan"], border=2 * U, shadow=2 * U, notch=U)
        m = kanji_mask(k, px(18) // 1 if style.D == 2 else 18)
        col = Image.new("RGBA", m.size, INK[:3] + (255,))
        col.putalpha(m)
        X = int(round(b.cx * style.D - m.width / 2))
        Y = int(round(b.cy * style.D - m.height / 2))
        X -= X % style.D
        Y -= Y % style.D
        cv.im.alpha_composite(col, (X, Y))
    # (1200, 800, 64, 64) is the scrim source Lua stretches over the screen: left transparent, so the
    # light shutter is never dimmed into an off-palette grey
    return cv.result()


def build_dan_transition(G):
    w = SubsetWriter(G, SCREEN, "dan_transition")
    w.put("background", lambda i, n, ww, hh: dan_transition_image())
    # the C++ DanTransition draws Green's Don / emblem / flash over the shutter whenever animation ids
    # 39-42 exist: 1x1 blanks so no Green art can ever show, whatever animation.json is inherited
    for k in ("don", "emblem", "flash"):
        put_tiny(w, k, "Green's dan-shutter Don / emblem / flash (C++ DanTransition): blank, never shown")
    return w.write()


# ================================================================== leaderboard (score history)
def lb_panel(w, h):
    cv = Canvas(w, h)
    # right edge at abs x 405 (rows end at 394): the wheel's ▶ (abs 420..462) stays clear of it
    b = chrome.frame(cv, 9, 3, 405, style.snap(h - 6), PAPER, border=U, shadow=U, notch=U)
    cv.rect(b.ix0, b.iy0, b.ix1, 93, C["bg2"])            # title row (leaderboard_title, top at y 42)
    cv.rect(b.ix0, 93, b.ix1, 96, INK)
    return cv.result()


def lb_row(w, h, fill):
    cv = Canvas(w, h)
    chrome.frame(cv, 0, 3, style.snap(w - 3), style.snap(h - 3), fill, border=U, shadow=0, notch=U)
    return cv.result()


LB_DY = -210   # the score history sits 70U higher than Green's spot: its panel ends at abs y 707,
               # above Momo standing on the 1P nameplate (head at y 710)


def lb_entry(g, dx0=None):
    """The ancestor's entry in LOGICAL px, lifted by LB_DY (dx0: replace x of every entry)."""
    def one(e):
        o = {}
        for k, v in e.items():
            if k in ("file", "crop"):
                continue
            if k in ("x", "y", "x2", "y2") and isinstance(v, (int, float)):
                v = int(v * g.scale)
                if k == "y":
                    v += LB_DY
                if k == "x" and dx0 is not None:
                    v = dx0
            o[k] = v
        return o
    return [one(e) for e in g.entry] if isinstance(g.entry, list) else one(g.entry)


def build_leaderboard(G):
    w = SubsetWriter(G, SCREEN, "leaderboard")

    def put(key, draw, dx0=None):
        w.put(key, draw, entry=lb_entry(w.geo(key), dx0))
        DEVIATIONS.append(f"song_select/leaderboard/{key}: y lifted {LB_DY} (score history above Momo on the "
                          f"1P nameplate)" + (f", x {dx0}" if dx0 is not None else ""))
    put("background_2", lambda i, n, ww, hh: lb_panel(ww, hh))
    for k in ("normal", "normal_ura"):
        put(k, lambda i, n, ww, hh: lb_row(ww, hh, C["bg2"]))
    for k in ("shinuchi", "shinuchi_ura"):
        put(k, lambda i, n, ww, hh: lb_row(ww, hh, C["clear"]))
    put("pts", lambda i, n, ww, hh: blank_l(ww, hh))   # 点: ss_sel.lua (SS_SEL:lb_labels)
    put("counter", lambda i, n, ww, hh: digit_img(ww, hh, str(i), 36, PAPER))
    put("difficulty", lambda i, n, ww, hh: _course_chip_s(ww, hh, i))
    put("ura", lambda i, n, ww, hh: _course_chip_s(ww, hh, 4))
    # the 良 可 不可 連打 edge chips are drawn by ss_sel.lua (SS_SEL:lb_labels, sized to the text) at
    # these frames' spots + (0, 12): blank frames (Green places judge_drumroll at x -54; ours starts at 0)
    for k in ("judge_good", "judge_ok", "judge_bad"):
        put(k, lambda i, n, ww, hh: blank_l(ww, hh))
    put("judge_drumroll", lambda i, n, ww, hh: blank_l(ww, hh), dx0=0)
    put("judge_num", lambda i, n, ww, hh: digit_img(ww, hh, str(i), 36))
    blank_unused(w)
    return w.write()


def _course_chip_s(w, h, i):
    cv = Canvas(w, h)
    b = chrome.frame(cv, 3, 3, style.snap(w - 6), style.snap(h - 6), C[COURSE[i]], border=U, shadow=U, notch=U)
    course_glyph(cv, b.cx, b.cy, COURSE[i], U)
    return cv.result()


# ================================================================== polish: the moving floor pattern
# The cream between the sky band and the floor strip (y 216..975) was one flat colour: half the screen
# empty on the wheel. Nijiiro scrolls a crest pattern there. Ours: a quiet cream-on-cream pattern (bg3
# blossoms + bg2 dots, no accent) on a 48 x 42 staggered grid, one 192 x 252 tile, three tile rows fill
# 216..972 exactly; ss_sel.lua scrolls it left 1U every 100 ms (steady), the sky / floor stay put.
PATTERN_W, PATTERN_H = 192, 252
PATTERN_Y = 216
BLOSSOM = ["..X..", ".XXX.", "XX.XX", ".XXX.", "..X.."]
PDOT = ["XX", "XX"]


def pattern_tile():
    cv = Canvas(PATTERN_W, PATTERN_H)
    for r in range(6):
        y = r * 42 + 21
        for c in range(4):
            x = c * 48 + (24 if r % 2 else 0) + 24
            if r % 2 == 0:
                glyph(cv, style.snap(x - 6), style.snap(y - 6),
                      BLOSSOM, {"X": C["bg3"]}, outline=None)
            else:
                glyph(cv, style.snap(x - U), style.snap(y - U), PDOT, {"X": C["bg2"]}, outline=None)
    return cv.result()


# ================================================================== our own textures (Lua)
def build_own(G):
    o = OwnSubset(G, SCREEN, "ss_sel")
    cv = Canvas(42, 66)
    chrome.cursor(cv, 2 * U, 33, cell=2 * U)
    o.add("cursor", [cv.result()])
    cv = Canvas(33, 21)
    glyph(cv, U, U, DOWN, {"X": C["clear"]})
    o.add("cursor_down", [cv.result()])
    o.add("count_max", [song_count_max()])
    o.add("footer", [footer_image()])
    o.add("pattern", [pattern_tile()])
    for size, rows in (("S", deco.CLOUD_S), ("M", deco.CLOUD_M)):
        cw, ch = len(rows[0]) * deco.CLOUD_CELL, len(rows) * deco.CLOUD_CELL
        cv = Canvas(cw, ch)
        deco.cloud(cv, 0, 0, size)
        o.add("cloud_" + size.lower(), [cv.result()])
    return o.write()


# ================================================================== r3 (M2): no ancestor art on any path
# Keys our screen never draws but an ancestor still ships (tools/inventory.py song_select --todo). Blanks
# keep the ancestor's geometry (the engine reads box/folder_texture_left|right and yellow_box/yellow_box_right
# widths); AI battle (no AI_SELECT screen is registered in the engine: unreachable) gets 1x1 blanks.
UNUSED = {
    "box": ["back_graphic", "back_icon", "back_icon_highlight", "folder_texture_left", "folder_texture",
            "folder_texture_right", "folder_clip", "folder_top", "folder_top_edge", "folder_background",
            "folder_background_edge", "folder_background_folder", "folder_background_folder_edge",
            "genre_overlay", "diff_overlay", "diff_overlay_large"],
    "yellow_box": ["ex_data_new_song_balloon_en", "ex_data_new_song_balloon_ja", "ex_data_limited_time_balloon_en",
                   "ex_data_limited_time_balloon_ja", "preimage_bg", "difficulty_bar", "difficulty_bar_shadow",
                   "star_ura", "yellow_box_bottom_right", "yellow_box_bottom_left", "yellow_box_top_right",
                   "yellow_box_top_left", "yellow_box_left", "yellow_box_right", "yellow_box_bottom",
                   "yellow_box_top", "yellow_box_center", "shadow_bottom_left", "shadow_bottom_right",
                   "shadow_bottom", "shadow_right", "shadow_top_right"],
    "diff_sort": ["back_en", "back_ja", "back_outline", "box", "box_diff", "box_text", "box_text_highlight",
                  "star_select_prompt", "star_limit", "star_num", "star", "pongos", "small_box",
                  "small_box_outline", "small_box_highlight", "small_box_text", "small_box_text_highlight",
                  "stat_bg_1p", "stat_bg_2p", "stat_overlay", "stat_num_small", "stat_num_star", "stat_diff",
                  "stat_starx", "stat_recommend", "stat_prev"],
    "leaderboard": ["background"],
    "global": ["footer", "arrow"],
    "diff_select": ["1p_outline", "1p_outline_half", "2p_outline", "2p_outline_half", "1p_outline_back",
                    "1p_outline_back_half", "2p_outline_back", "2p_outline_back_half", "1p_balloon_half",
                    "2p_balloon_half"],
}
AI_BATTLE = ["background", "background_overlay", "background_overlay_2", "box_1", "box_2", "bottom_text",
             "subdiff_easy", "subdiff_normal", "subdiff_hard", "subdiff_oni", "subdiff_selector",
             "subdiff_select_text", "box_bg_blur"]


def blank_unused(w: SubsetWriter):
    for key in UNUSED.get(w.subset, ()):
        if key not in w.out:
            w.put_blank(key)


def build_ai_battle(G):
    w = SubsetWriter(G, SCREEN, "ai_battle")
    for key in AI_BATTLE:
        put_tiny(w, key, "AI battle: no AI_SELECT screen in the engine (unreachable); never Green art")
    return w.write()


# ================================================================== module entry points
def configure(ctx):
    global LANG
    LANG = ctx.lang


def build(ctx):
    DEVIATIONS.clear()
    G, lang = ctx.G, ctx.lang
    n = 0
    n += build_box(G, lang)
    n += build_yellow_box(G, lang)
    n += build_diff_select(G, lang)
    n += build_diff_mark_anim(G)
    n += build_global(G, lang)
    n += build_modifier(G)
    n += build_neiro(G)
    n += build_diff_sort(G)
    n += build_dan_transition(G)
    n += build_leaderboard(G)
    n += build_ai_battle(G)
    n += build_own(G)
    n += copy_own_lua(ctx)
    with open(os.path.join(ctx.here, "reports", "v2_song_select_deviations.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(DEVIATIONS) + "\n")
    return n


def copy_own_lua(ctx):
    """lua/song_select/** -> Scripts/** (the module NAME is v2_song_select, so build.py's copy_lua
    would look in lua/v2_song_select)."""
    import shutil
    src = os.path.join(ctx.here, "lua", "song_select")
    n = 0
    for root, _, files in os.walk(src):
        for f in files:
            rel = os.path.relpath(os.path.join(root, f), src)
            dst = os.path.join(ctx.scripts, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(os.path.join(root, f), dst)
            n += 1
    return n


# ---------------------------------------------------------------- skin_config (LOGICAL)
def _nj_entry(key, **kw):
    import json
    from .atlas import NIJIIRO_G
    with open(f"{NIJIIRO_G}/skin_config.json", encoding="utf-8") as f:
        nj = json.load(f)
    e = dict(nj[key])
    e.update(kw)
    return e


def skin_config(ctx):
    E = style.ENGINE_TEXT
    cfg = {
        # Green's song_select_box_name (40 @1280) restated at 1920 logical; the Lua reads font_size
        # font_size = the ENGINE size of the text role (style.ENGINE_TEXT: 18/24/36/48 -> 24/32/48/64)
        "song_select_box_name": {"x": 70, "y": 193, "height": 625, "font_size": E[36]},
        "song_select_box_bpm": _nj_entry("song_select_box_bpm", font_size=E[24]),
        # r3 (SS6): the 「N曲目」 chip moved 4U right, clear of the sort window's right edge (abs 1620)
        "song_num": _nj_entry("song_num", outline=1.5, font_size=E[24], x=1722 + CHIP_DX, y=COUNT_TEXT_Y),
        "song_num_max": _nj_entry("song_num_max", outline=1.5, font_size=E[24]),
        "song_back_label": _nj_entry("song_back_label", font_size=E[48]),
        "modifier_title": _nj_entry("modifier_title", font_size=E[36]),
    }
    for i in range(5):
        cfg[f"course_name_{i}"] = _nj_entry(f"course_name_{i}", font_size=E[24])
        # text24: the plate's course name (Nijiiro 18) is a 24-role text now
        cfg[f"chip_course_name_{i}"] = _nj_entry(f"chip_course_name_{i}", font_size=E[24])
    return cfg


# ================================================================== Lua patches (Nijiiro's scripts)
CHIP_DX = 12   # r3 (SS6): 「N曲目」 chip + engine text, 4U right of Nijiiro's spot
E24 = style.ENGINE_TEXT[24]   # engine size of the 24 role (the minimum); raw engine sizes in the Lua must not be smaller
INKC = "{ 58, 38, 51, 255 }"
TEXT2C = "{ 106, 88, 98, 255 }"
NOOUT = "{ 255, 255, 255, 0 }"
PAPERC = "{ 255, 255, 255, 255 }"

OLD_GUIDE = '    -- control_guide panel (browse only; fades with the header swap)\n    if self._id_guide_panel then\n        local panel_fade = (state == STATE_SONG_SELECTED) and (1 - label_fade) or 1.0\n        if panel_fade > 0 then\n            self._id_guide_panel:draw(GuidePanel.Loop.ALL, 0, 0, panel_fade)\n        end\n    end\n    if state == STATE_SONG_SELECTED then\n        -- course-select drum guide at (960,978)\n        if self._id_guide_s then\n            local frame = math.floor(tex.get_current_ms() / 1000 * 30) % 210\n            local g = self:guide_labels()\n            -- hand the draw to coin_overlay.lua so the pill sits above the credit text\n            local id, fade = self._id_guide_s, label_fade\n            YD_DRAW_ABOVE_CREDIT = function()\n                draw_centered(id, 960, 978, 372, 96, { frame = frame, fade = fade })\n                draw_guide_label(g.select, GUIDE_SELECT_CX, GUIDE_LABEL_CY, fade)\n                draw_guide_label(g.decide, GUIDE_DECIDE_CX, GUIDE_LABEL_CY, fade)\n            end\n        end\n'

LUA_PATCHES = {
    "song_select/song_select.lua": [
        ('    tex.load_folder("song_select", "diff_select")\n',
         '    tex.load_folder("song_select", "diff_select")\n'
         '    tex.load_folder("song_select", "ss_sel")   -- SimpleStyle: own cursors / clouds\n'
         '    self._ss = require("song_select/ss_sel").new()\n'),
        # fix1029: the floor strip over the wheel's lower plates (ss_sel.lua M:draw_footer)
        ("function SongSelect:draw_footer()\nend\n",
         "function SongSelect:draw_footer()\n    if self._ss then self._ss:draw_footer() end   -- SimpleStyle fix1029\nend\n"),
        ("function SongSelect:update(current_ms)\n    self.text_fade_in:update(current_ms)\n",
         "function SongSelect:update(current_ms)\n    self.text_fade_in:update(current_ms)\n"
         "    if self._ss then self._ss:update(current_ms) end\n"),
        ('    local info = tex.get_texture_info("box", "background")\n'
         '    local width = info.width\n'
         '    local move = nav:background_move().attribute % width\n'
         '    local fade_change = nav:background_fade_change().attribute\n'
         '    local last_frame = nav:last_bg_genre_frame()\n'
         '    local curr_frame = nav:bg_genre_frame()\n'
         '    for i = 0, width * 2 - 1, width do\n'
         '        tex.draw_texture(self._id_background, { frame = last_frame, x = i - move })\n'
         '        tex.draw_texture(self._id_background, { frame = curr_frame, x = i - move, fade = 1 - fade_change })\n'
         '    end\n',
         '    self._ss:draw_background()   -- SimpleStyle: static sky + ground, drifting clouds\n'),
        ("    if self._id_song_counter then\n",
         "    -- SimpleStyle: practice select has no 「N曲目」 (session timer), so no empty plate either\n"
         "    if self._id_song_counter and (tex.current_screen and tex.current_screen() or \"\") ~= \"PRACTICE_SELECT\" then\n"),
        # anchored on the first decided-bridge call (Nijiiro's AI battle may draw its select overlay first)
        ("    self:draw_decided_bridge()\n    if dan_transition_ok then",
         "    self:draw_decided_bridge()\n"
         "    if self._ss then self._ss:draw_mascots(state, self._mod_off) end\n"
         "    if dan_transition_ok then"),
        # one hint pill (UI.hint, bottom centre) on the wheel, the course select and the sort window;
        # replaces the global guide panel call and Nijiiro's course-select drum pill
        (OLD_GUIDE,
         "    -- SimpleStyle: one hint pill (UI.hint, bottom centre)\n"
         "    if self._ss then self._ss:draw_hint(state) end\n"
         "    if state == STATE_SONG_SELECTED then\n"),
        ("        tex.draw_texture(self._id_song_counter, { x = 1754 - 140, y = 270 - 36 })\n",
         f"        tex.draw_texture(self._id_song_counter, {{ x = 1754 - 140 + {CHIP_DX}, y = {COUNT_Y} }})   -- fix1029\n"
         f"        if self._ss then self._ss:draw_count_max(1754 - 140 + {CHIP_DX}, {COUNT_Y}) end\n"),
        ("local SONG_MAX_CX = 1824", f"local SONG_MAX_CX = {1824 + CHIP_DX}"),
        # the option panel is inset (x +12 for 1P, -12 for 2P): its title follows
        ("    option_p2 = { x = 1490 },\n}", "    option_p2 = { x = 1466 },\n}"),
        ('text.create_text("modifier_title", { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, outline(4.0), 2.0)',
         f'text.create_text("modifier_title", {INKC}, {NOOUT}, false, 0, 2.0)'),
        ('text.create_text(key, { 40, 40, 40, 255 }, { 0, 0, 0, 0 }, false, 0, 2.0, 1.0, "FOT-Seurat_Pro_B.otf")',
         f'text.create_text(key, {INKC}, {{ 0, 0, 0, 0 }}, false, 0, 2.0, 1.0)'),
        ('sc.font_size or 24, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, outline(3.5), 2.0, 1.0, "FOT-Seurat_Pro_B.otf")',
         f'sc.font_size or 24, {PAPERC}, {INKC}, false, outline(3.0), 2.0, 1.0)'),
    ],
    "song_select/file_navigator/box_base.lua": [
        ("local function title_scale()\n", "local function title_scale()\n    do return 1.0 end   -- SimpleStyle: 18/24/36/48 only\n"),
        ("local function glow_pulse()\n", "local function glow_pulse()\n    do return 1.0 end   -- SimpleStyle: steady focus, the ▶ blinks\n"),
        ("local function draw_glow(glow_id, bx, by, cen_h, fade)\n",
         "local function draw_glow(glow_id, bx, by, cen_h, fade)\n"
         "    fade = ss_snap(fade)\n"
         "    if SS_SEL then SS_SEL:board_cursor(bx, by, fade) end\n"),
        # alpha policy (core): every wheel / course-select texture and title is drawn at alpha 1 or not
        # at all (the wheel's fly-out and the course select's fade-in were translucent pixel art)
        ("local function draw_centered(id, cx, cy, w, h, extra)\n",
         "local function ss_snap(a)   -- SimpleStyle: UI.solid without the require (0.5 threshold)\n"
         "    if a == nil then return nil end\n"
         "    return (a >= 0.5) and 1.0 or 0.0\n"
         "end\n"
         "local function draw_centered(id, cx, cy, w, h, extra)\n"),
        ("    extra.y = cy - h / 2\n    tex.draw_texture(id, extra)\nend",
         "    extra.y = cy - h / 2\n    extra.fade = ss_snap(extra.fade)\n"
         "    if extra.fade == 0 then return end\n    tex.draw_texture(id, extra)\nend"),
        ("    extra.y = cy - h / 2 - base[2]\n    tex.draw_texture(id, extra)\nend",
         "    extra.y = cy - h / 2 - base[2]\n    extra.fade = ss_snap(extra.fade)\n"
         "    if extra.fade == 0 then return end\n    tex.draw_texture(id, extra)\nend"),
        ("                x2 = w - text.width, fade = fade })\n",
         "                x2 = w - text.width, fade = ss_snap(fade) })\n"),
        ("local function draw_board(bar_id, frame, bx, by, cen_h, fade, crop_center, sx)\n",
         "local function draw_board(bar_id, frame, bx, by, cen_h, fade, crop_center, sx)\n"
         "    fade = ss_snap(fade)\n"),
        ("    return box.fade.attribute\n", "    return ss_snap(box.fade.attribute)\n"),
        ("local function leg_event(id)\n    local now = tex.get_current_ms()\n",
         "local function leg_event(id)\n    local now = tex.get_current_ms()\n"
         "    if SS_SEL then SS_SEL:wheel_event(id) end\n"),
        # option title: 7 px up for our 16U band (r1), then with the panel inset (x +12, y -48), centred between
        # the 1P chip and the right edge
        ("MOD_CX = 548, 333.33, 1080, 49, 215", "MOD_CX = 548, 333.33, 1080, -6, 266"),
        # r3 (SS2): the course select is 60 px shorter: marker lane, cards and the card-tall buttons up 60
        ("local DS_BOARD_Y = 583\n", "local DS_BOARD_Y = 523   -- SimpleStyle r3: board 60 shorter\n"),
        ("local DS_BTN_Y   = 462\n", "local DS_BTN_Y   = 523   -- SimpleStyle r3: card-tall buttons\n"),
        ("local DS_CURSOR_Y = 370\n", "local DS_CURSOR_Y = 310\n"),
        # fix1029: the 2P course readout card mirrors the 1P card about the screen centre. The card spans
        # cx-175 .. cx+101 (course_readout): 1P cx 200 -> x 25..301, 2P cx 1794 -> x 1619..1895 (Nijiiro's
        # 1720 put it at 1545..1821, under the board's right edge and the 「N曲目」 chip)
        ("local DS_MARK_X = { [1] = 200, [2] = 1720 }\n",
         "local DS_MARK_X = { [1] = 200, [2] = 1794 }   -- SimpleStyle fix1029: 2P mirrors 1P\n"),
    ],
    "song_select/file_navigator/box_song.lua": [
        # the course select opens with the bible's 3-frame height open (UI.open_rect), not a fade: every
        # alpha the diff select hands out is snapped (0 until the board is fully open, then 1)
        ("    local fade = box.diff_fade_in.attribute\n",
         "    local fade = SS_SEL and SS_SEL:ds_fade(box.diff_fade_in.attribute) or box.diff_fade_in.attribute\n"),
        ("    tex.draw_texture(self._id_backboard, { frame = box:genre_frame(), x = 960 - 636, y = 440 - 392, fade = fade })\n",
         "    if SS_SEL then SS_SEL:draw_backboard(self._id_backboard, box:genre_frame(), 960 - 636, 440 - 392)\n"
         "    else tex.draw_texture(self._id_backboard, { frame = box:genre_frame(), x = 960 - 636, y = 440 - 392, fade = fade }) end\n"),
        # a missing course was a 40 % alpha column (a blend): solid, it simply has no name / level / pips
        ("        local f = info.has_course and fade or math.min(fade, 0.4)\n", "        local f = fade\n"),
        # polish: the course cards cascade in and lift under a cursor (SS_SEL:card_pose): DS_BOARD_Y and fade
        # are shadowed per slot inside both card loops
        ("    for i = 0, 3 do\n        local cx = DS_SLOT_X[i]\n",
         "    for i = 0, 3 do\n        local cx = DS_SLOT_X[i]\n"
         "        local DS_BOARD_Y, fade = DS_BOARD_Y, fade   -- SimpleStyle polish\n"
         "        if SS_SEL then\n"
         "            local dy, vis = SS_SEL:card_pose(i)\n"
         "            DS_BOARD_Y = DS_BOARD_Y + dy\n"
         "            if not vis then fade = 0 end\n"
         "        end\n"),
        ("            if lbl then draw_title(lbl, DS_SLOT_X[i], DS_BOARD_Y + DS_COURSE_NAME_DY, fade) end\n",
         "            local ss_dy, ss_vis = 0, true\n"
         "            if SS_SEL then ss_dy, ss_vis = SS_SEL:card_pose(i) end\n"
         "            if lbl and ss_vis then draw_title(lbl, DS_SLOT_X[i], DS_BOARD_Y + ss_dy + DS_COURSE_NAME_DY, fade) end\n"),
        ("    local scale = 0.75 + 0.25 * p\n", "    local scale = 1.0   -- SimpleStyle: pixel badges never scale\n"),
        ("lbl = text.create_text(key, { 255, 255, 255, 255 }, { 40, 20, 20, 255 }, false, outline(1.5), 1.0)",
         f"lbl = (diff == 4) and text.create_text(key, {PAPERC}, {INKC}, false, outline(3.0), 1.0)\n"
         f"                or text.create_text(key, {INKC}, {NOOUT}, false, 0, 1.0)"),
        ("lbl = text.create_text(key, { 255, 255, 255, 255 }, { 20, 20, 20, 255 }, false, outline(4.5), 1.0)",
         f"lbl = text.create_text(key, {INKC}, {NOOUT}, false, 0, 1.0)"),
        ("text.create_raw_text(str, 24, { 255, 255, 255, 255 }, board_outline(gf), false, outline(3.5), 2.0)",
         f"text.create_raw_text(str, {E24}, {TEXT2C}, {NOOUT}, false, 0, 2.0)"),
        ("{ 255, 255, 255, 255 }, board_outline(gf),\n                                 false, outline(SONG_TITLE_OUTLINE), 2.0)",
         f"{INKC}, {PAPERC},\n                                 false, outline(3.0), 2.0)"),
        ("math.floor(48 * scale + 0.5), { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, outline(7.0), 2.0)",
         f"math.floor(48 * scale + 0.5), {INKC}, {NOOUT}, false, 0, 2.0)"),
        ("math.floor(30 * scale + 0.5), { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, outline(4.0), 2.0)",
         f"math.floor({E24} * scale + 0.5), {TEXT2C}, {NOOUT}, false, 0, 2.0)"),
        ("draw_centered(self._id_dot_star, cx - 67 + k * 15, DS_BOARD_Y + 116, 24, 24, { fade = f })",
         "draw_centered(self._id_dot_star, cx - 67 + k * 15, DS_BOARD_Y + 116, 24, 24,\n"
         "                              { fade = f, color = SS_SEL and SS_SEL.course_rgb(diff) or nil })"),
        ("        if dec and self._id_mark[dec.course] then\n",
         "        if false then   -- SimpleStyle: the readout card is static (no stretch / flash)\n"),
        ("        elseif shown and self._id_mark[d] and (now - intro[p]) / DS_MARK_DECIDE_MS < MARK_INTRO_FRAMES then\n",
         "        elseif false then\n"),
        ("    draw_title(self:header_title(box), 960, 178, fade, DS_TEXT_BOX_W, 0)\n"
         "    draw_title(self:header_subtitle(box), 960, 242, fade, DS_TEXT_BOX_W, 0)\n",
         "    draw_title(self:header_title(box), 960, 152, fade, DS_TEXT_BOX_W, 0)   -- SimpleStyle r3: header 96..240\n"
         "    draw_title(self:header_subtitle(box), 960, 210, fade, DS_TEXT_BOX_W, 0)\n"),
        ("    draw_centered(self._id_btn_back,   DS_SLOT_X[DIFF_BACK],     DS_BTN_Y,   128, 128, { fade = fade })\n"
         "    draw_centered(self._id_btn_option, DS_SLOT_X[DIFF_MODIFIER], DS_BTN_Y,   128, 128, { fade = fade })\n",
         "    -- SimpleStyle r3: card-tall buttons; もどる steps out while the 1P option panel covers it\n"
         "    local ss_back = not (SS_SEL and SS_SEL:panel_open(1))\n"
         "    -- SimpleStyle polish: cascade arrival + focus lift (SS_SEL:card_pose)\n"
         "    local ss_bdy, ss_bvis, ss_ody, ss_ovis = 0, true, 0, true\n"
         "    if SS_SEL then\n"
         "        ss_bdy, ss_bvis = SS_SEL:card_pose(DIFF_BACK)\n"
         "        ss_ody, ss_ovis = SS_SEL:card_pose(DIFF_MODIFIER)\n"
         "    end\n"
         "    if ss_back and ss_bvis then\n"
         "        draw_centered(self._id_btn_back, DS_SLOT_X[DIFF_BACK], DS_BTN_Y + ss_bdy, 128, 360, { fade = fade })\n"
         "    end\n"
         "    if ss_ovis then\n"
         "        draw_centered(self._id_btn_option, DS_SLOT_X[DIFF_MODIFIER], DS_BTN_Y + ss_ody, 128, 360, { fade = fade })\n"
         "    end\n"
         "    if SS_SEL then SS_SEL:button_labels(DS_SLOT_X[DIFF_BACK], DS_SLOT_X[DIFF_MODIFIER], DS_BTN_Y, fade, ss_back) end\n"),
        # text24: the open board's course plates are two bands (frame_score): icon | star + level on top, the 24 px
        # course name on the full-width strip below
        ("        draw_centered(self._id_star, cx + 27, py, 40, 40, { frame = diff, fade = f })\n",
         "        draw_centered(self._id_star, cx + 27, py - 22.5, 40, 40, { frame = diff, fade = f })\n"),
        ("        draw_centered(self._id_level_number, cx + 61, py, 48, 48, { frame = diff * 11 + (lv - 1), fade = f })\n",
         "        draw_centered(self._id_level_number, cx + 61, py - 22.5, 48, 48, { frame = diff * 11 + (lv - 1), fade = f })\n"),
        ("        if name then draw_title(name, cx - 42, py + 30, f) end\n",
         "        if name then draw_title(name, cx - 2, py + 22, f) end\n"),
        # dynamic text (§11): the words on the marks, tags and the readout card are engine text (ss_sel.lua)
        ("            draw_centered(self._id_branch, cx - 69, py - 23, 40, 40, { fade = f })\n",
         "            draw_centered(self._id_branch, cx - 69, py - 23, 40, 40, { fade = f })\n"
         "            if SS_SEL then SS_SEL:mark(\"branch_mark\", cx - 88, py - 36, 30, 24, f) end\n"),
        ("                draw_centered(self._id_branch_diff, cx, DS_BOARD_Y + 144, 40, 40, { fade = f })\n",
         "                draw_centered(self._id_branch_diff, cx, DS_BOARD_Y + 144, 40, 40, { fade = f })\n"
         "                if SS_SEL then SS_SEL:mark(\"branch_mark\", cx, DS_BOARD_Y + 144, 33, 24, f, true) end\n"),
        ("draw_centered(icon, bx - 532, by + 4, 120, 96, { fade = fade * ic })\n",
         "draw_centered(icon, bx - 532, by + 4, 120, 96, { fade = fade * ic })\n"
         "            if SS_SEL and icon == self._id_new_icon then SS_SEL:new_tag(bx, by, fade * ic) end\n"),
        ("        if art then\n            local s = tex.get_screen_scale()\n",
         "        if SS_SEL then SS_SEL:ex_tag(exd, bx, by, cfade) end\n"
         "        if art then\n            local s = tex.get_screen_scale()\n"),
        ("        if fav then tex.draw_texture(fav, { x = bx - 480, y = by - 176, fade = cfade }) end\n",
         "        if fav then tex.draw_texture(fav, { x = bx - 480, y = by - 176, fade = cfade }) end\n"
         "        if SS_SEL then SS_SEL:fav_tag(tex.player_num(), bx, by, cfade) end\n"),
        ("            draw_centered(self._id_diff_mark, DS_MARK_X[p], DS_MARK_Y, 680, 680, { frame = d, fade = fade })\n",
         "            local ss_my = DS_MARK_Y + (SS_SEL and SS_SEL:mark_dy(p) or 0)   -- polish: drop-in on a change\n"
         "            draw_centered(self._id_diff_mark, DS_MARK_X[p], ss_my, 680, 680, { frame = d, fade = fade })\n"
         "            if SS_SEL then SS_SEL:readout_name(d, DS_MARK_X[p], ss_my, fade, box) end\n"),
        ("        if id then\n            local cell = math.min(URA_CELLS - 1",
         "        if false and id then   -- SimpleStyle: no 90-cell switch movie\n            local cell = math.min(URA_CELLS - 1"),
    ],
    "song_select/file_navigator/box_folder.lua": [
        ("local FOLDER_TITLE_SIZE = 54", "local FOLDER_TITLE_SIZE = 48"),
        ("{ 255, 255, 255, 255 },\n                                 board_outline(ff), false, outline(7.5), 2.0)",
         f"{INKC},\n                                 {PAPERC}, false, outline(3.0), 2.0)"),
        ('text.create_raw_text(l, 32, { 255, 255, 255, 255 }, board_outline(frame), false, outline(4.0), 2.0, 1.0, "FOT-Seurat_Pro_B.otf")',
         f"text.create_raw_text(l, {E24}, {TEXT2C}, {NOOUT}, false, 0, 2.0)"),
        # dynamic text: 「全N曲」 in the player's language (ss/strings.py sel_folder_count)
        ('lines[1] = tostring(n) .. " songs"',
         'lines[1] = require("global.ss_ui").t("sel_folder_count", n) or (tostring(n) .. " songs")'),
        ("    if ch_alpha > 0 then\n        local slide = 450.0 - ch_off\n",
         "    if false and ch_alpha > 0 then   -- SimpleStyle: no genre characters\n        local slide = 450.0 - ch_off\n"),
        ("    if not self._id_pattern then return end\n", "    do return end   -- SimpleStyle: no event pattern strip\n"),
    ],
    "song_select/file_navigator/box_back.lua": [
        ("{ 255, 255, 255, 255 }, BOARD_OUTLINE_BACK, false, outline(5.0), 2.0)",
         f"{INKC}, {PAPERC}, false, outline(3.0), 2.0)"),
    ],
    "song_select/selector.lua": [
        ("local function balloon_motion(st, i)\n"
         "    if st == \"in\" then\n"
         "        local u = 1 - (1 - math.min(1, i / 14)) ^ 2\n"
         "        return -50 * (1 - u), u\n"
         "    end\n"
         "    if i < 3 then return 3.35 + 6.65 * i / 2, 1 end\n"
         "    if i < 6 then return 6.65 * (1 - (i - 3) / 2), 1 end\n"
         "    return 0, 1\n"
         "end\n",
         "local function balloon_motion(st, i)\n"
         "    -- SimpleStyle (bible 2.7): no eased drop; a move nudges the marker 1U for 66 ms\n"
         "    if st == \"move\" and i < 4 then return -3, 1 end\n"
         "    return 0, 1\n"
         "end\n"),
        ("                self._mark_decided[p] = { t0 = tex.get_current_ms(), course = diff }\n",
         "                self._mark_decided[p] = { t0 = tex.get_current_ms(), course = diff }\n"
         "                if SS_SEL then SS_SEL:on_decide(p) end\n"),
        ('        bal = { diff = diff, t0 = tex.get_current_ms(), st = "in" }\n',
         '        bal = { diff = diff, t0 = tex.get_current_ms(), st = "in" }\n'
         '        if SS_SEL then SS_SEL:on_diff(p, diff, false) end\n'),
        ('        bal.diff, bal.t0, bal.st = diff, tex.get_current_ms(), "move"\n',
         '        bal.diff, bal.t0, bal.st = diff, tex.get_current_ms(), "move"\n'
         '        if SS_SEL then SS_SEL:on_diff(p, diff, true) end\n'),
        # the 1P/2P marker appears with the board's last open frame, never on a half-open board
        ("    if fade_in < 1.0 then self._bal[p] = nil return end\n",
         "    if fade_in < 1.0 or (SS_SEL and (SS_SEL:ds_open() < 1 or not SS_SEL:cascade_done())) then self._bal[p] = nil return end\n"),
        # polish: the focus ring rides the lifted card / button and flashes for 300 ms on a decide
        ("        if under then draw_centered(frame_id, sx, DS_BOARD_Y, 248, 408, { fade = fade }) end\n",
         "        local ss_dy, ss_on = 0, true\n"
         "        if SS_SEL then ss_dy, ss_on = SS_SEL:ring(p, col) end\n"
         "        if under and ss_on then draw_centered(frame_id, sx, DS_BOARD_Y + ss_dy, 248, 408, { fade = fade }) end\n"),
        ("        if under then draw_centered(self._id_btn_glow, sx, by, 168, 168, { fade = fade }) end\n",
         "        local ss_dy, ss_on = 0, true\n"
         "        if SS_SEL and diff ~= DIFF_NEIRO then ss_dy, ss_on = SS_SEL:ring(p, diff) end\n"
         "        if under and ss_on then draw_centered(self._id_btn_glow, sx, by + ss_dy, 168, 400, { fade = fade }) end   -- r3: tall\n"),
        ("    local fade = (player:neiro_active() or mod_on) and 0.5 or fade_in\n",
         "    local fade = fade_in   -- SimpleStyle: marker / focus ring stay solid while a panel is open\n"),
        ("                            sx + cursor_dx, DS_CURSOR_Y + bal_dy, 124, 124, { fade = fade * bal_a })\n",
         "                            sx + cursor_dx, DS_CURSOR_Y + bal_dy, 124, 124, { fade = fade * bal_a })\n"
         "            if SS_SEL then SS_SEL:column_cursor(sx + cursor_dx, fade * bal_a) end\n"
         "            if SS_SEL then SS_SEL:marker_label(p, sx + cursor_dx, DS_CURSOR_Y + bal_dy, fade * bal_a) end\n"),
    ],
    "song_select/modifier.lua": [
        # Z-DON's Nijiiro redraws its fixed seven-row frame lower for extra rows; our panel is built per row
        # (top + rows + bottom), so it only keeps the lift (mod_lift)
        ("    if n > 7 then\n"
         "        -- Z-DON adds rows (等速): the frame image holds seven; its rows part and foot are drawn again lower\n"
         "        -- (rows start 86 px into the 420 x 538 frame)\n"
         "        local extra = (n - 7) * pitch\n"
         "        tex.draw_texture(ids.top, { x = x, y = offset + extra + 86, y2 = -86,\n"
         "                                    src = { x = 0, y = 86, width = 420, height = 538 - 86 } })\n"
         "    end\n", "", "optional"),  # not in the installed Nijiiro's modifier.lua since 2026-11-01
        # inset the option panel: x +4U (outer edge on x 17 = the 1P nameplate's left edge, so the plate is
        # hidden completely) and 16U up (bottom above y 1020, the footer rule)
        ("    local x     = (p - 1) * ((p2cfg and p2cfg.x) or 1490)\n",
         "    local x     = (p - 1) * ((p2cfg and p2cfg.x) or 1490) + ((p == 1) and 12 or -12)\n"),
        ("    local p     = player:player_num()\n",
         "    offset      = offset - 48   -- SimpleStyle: panel inset (bottom above the footer rule)\n"
         "    local p     = player:player_num()\n"),
        ("modifier_text = { x = 300, y = 1178, font_size = 26 },", f"modifier_text = {{ x = 300, y = 1175, font_size = {E24} }},"),
        ("local OPT_CHANGED       = { 255, 255, 0, 255 }", "local OPT_CHANGED       = { 245, 178, 30, 255 }"),
        ("local OPT_SCRIM         = { 0, 0, 0, 128 }", "local OPT_SCRIM         = { 255, 246, 229, 170 }"),
        ("local OPT_ARROW_NUDGE   = 5", "local OPT_ARROW_NUDGE   = 3"),
        ("local function opt_cursor_alpha(ms)\n", "local function opt_cursor_alpha(ms)\n    do return 1.0 end   -- SimpleStyle: steady focus\n"),
        ("t = text.create_raw_text(s, self._opt_font, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, outline(3.0), 2.0) or false",
         f"t = text.create_raw_text(s, self._opt_font, {INKC}, {NOOUT}, false, 0, 2.0) or false"),
        ("            if ids.row_hl then tex.draw_texture(ids.row_hl, { x = x, y = row_y, color = OPT_GREY }) end\n",
         "            -- SimpleStyle: a greyed row keeps its plate; the scrim below dims it\n"),
        # r3 (SS4): はやさ showed its value twice (the x1.2 icon chip and ◀ 1.2 ▶): the value box is the one readout
        ("        if icon then tex.draw_texture(icon, { x = x, y = row_y }) end\n",
         "        if icon and row.name ~= \"speed\" then tex.draw_texture(icon, { x = x, y = row_y }) end\n"
         "        if icon and row.name ~= \"speed\" and SS_SEL then SS_SEL:mod_badge(row.name, st, x, row_y) end\n"),
        ("    if ids.p[p] then tex.draw_texture(ids.p[p], { x = x, y = offset }) end\n",
         "    if ids.p[p] then tex.draw_texture(ids.p[p], { x = x, y = offset }) end\n"
         "    if SS_SEL then SS_SEL:panel_label(p, x, offset) end   -- SimpleStyle: 1P / 2P as engine text\n"),
        ("local amp = OPT_ARROW_NUDGE * math.max(0, math.min(1, change.fade))",
         "local amp = (change.fade > 0.5) and OPT_ARROW_NUDGE or 0"),
    ],
    "song_select/option_panel.lua": [
        ("local WHITE, BLACK = { 255, 255, 255, 255 }, { 0, 0, 0, 255 }",
         f"local WHITE, BLACK = {INKC}, {NOOUT}   -- SimpleStyle: ink text on the light panels"),
        ("modifier_text = { x = 300, y = 1178, font_size = 26 },", f"modifier_text = {{ x = 300, y = 1175, font_size = {E24} }},"),
        ("neiro_text = { x = 300, y = 1422, font_size = 26 },", f"neiro_text = {{ x = 300, y = 1419, font_size = {E24} }},"),
    ],
    "song_select/diff_sort.lua": [
        # dynamic text: every sort-window word through UI.t (ss/strings.py sort_window_* first: Nijiiro's
        # skin_config has no ko for them; course names fall through to the engine's course_name_N)
        ('local base = require("song_select/file_navigator/box_base")\n',
         'local base = require("song_select/file_navigator/box_base")\nlocal UI = require("global.ss_ui")\n'),
        ("        for i, key in ipairs(k) do out[i] = tex.skin_text(key) end\n",
         "        for i, key in ipairs(k) do out[i] = UI.t(key) or tex.skin_text(key) end\n"),
        ("    return tex.skin_text(k)\n", "    return UI.t(k) or tex.skin_text(k)\n"),
        ("text.create_raw_text(str, size, { 255, 255, 255, 255 },", f"text.create_raw_text(str, size, {INKC},"),
        ("text.create_raw_text(str, fit_size, { 255, 255, 255, 255 },", f"text.create_raw_text(str, fit_size, {INKC},"),
        ("outline or { 0, 0, 0, 255 }", NOOUT),
        (", 42, outline(6.5)", ", 48, 0"),
        ("54, outline(7.5)", "48, 0"),
        ("local SW_FIT_MIN_SIZE = 22", f"local SW_FIT_MIN_SIZE = {E24}"),
        ("            if self._id_sw_glow then\n", "            if false then   -- SimpleStyle: no pulsing glow\n"),
        ("    if self._id_sw_guide then\n", "    if false then   -- SimpleStyle: UI.hint (ss_sel) is the one hint pill\n"),
    ],
    "song_select/score_history.lua": [
        # lifted with the panel (LB_DY), title at role 24 (engine 32: whole font pixels)
        ("y = 275 * s, width", "y = 275 * s - 210, width"),
        ("        local font_size = title_cfg.height\n", f"        local font_size = {E24}\n"),
        # text24: never shrink the title below the role (the loop went down to 8)
        ("        while font_size > 8 do\n", f"        while font_size >= {E24} do\n"),
        ("            self.title = text.create_raw_text(label, 8, { 0, 0, 0, 255 }", f"            self.title = text.create_raw_text(label, {E24}, {{ 0, 0, 0, 255 }}"),
        ("function ScoreHistory:draw()\n    if #self.available == 0 then return end\n",
         "function ScoreHistory:draw()\n    if #self.available == 0 then return end\n"
         "    if SS_SEL and SS_SEL.state == 1 then return end   -- SimpleStyle: not over the course select\n"),
        ("    if self.t_judge_drumroll then tex.draw_texture(self.t_judge_drumroll) end\n",
         "    if self.t_judge_drumroll then tex.draw_texture(self.t_judge_drumroll) end\n"
         "    if SS_SEL then SS_SEL:lb_labels() end   -- SimpleStyle: 良 可 不可 連打 / 点 as engine text\n"),
        ("local score_color = self.is_shinuchi and { 255, 255, 255, 255 } or { 0, 0, 0, 255 }",
         f"local score_color = {INKC}   -- SimpleStyle: ink digits on the bg2 / gold rows"),
        ("tex.draw_texture(self.t_pts, { color = { 255, 255, 255, 255 }, index = 1 })",
         f"tex.draw_texture(self.t_pts, {{ color = {INKC}, index = 1 }})"),
        ("tex.draw_texture(self.t_pts, { color = { 0, 0, 0, 255 }, index = 1 })",
         f"tex.draw_texture(self.t_pts, {{ color = {INKC}, index = 1 }})"),
        ("text.create_raw_text(label, font_size, { 0, 0, 0, 255 }, { 0, 0, 0, 0 }, false, 0, 2.0)",
         f"text.create_raw_text(label, font_size, {INKC}, {{ 0, 0, 0, 0 }}, false, 0, 2.0)"),
    ],
    "song_select/dan_transition.lua": [
        # alpha policy: the doors, stamps and push-in background are drawn at alpha 1 or not at all
        ('local anim = require("anim/sampler")\n',
         'local anim = require("anim/sampler")\nlocal UI = require("global.ss_ui")   -- SimpleStyle: UI.solid\n'),
        ("fade = ba * op,", "fade = UI.solid(ba * op),"),
        ("fade = op })", "fade = UI.solid(op) })"),
        ("x2  = w, y2 = w, fade = a * op,", "x2  = w, y2 = w, fade = UI.solid(a * op),"),
        ("            local w = KANJI * s\n",
         "            local w = KANJI * math.max(1, math.floor(s + 0.5))   -- SimpleStyle: integer stamp scale\n"),
        ("                x   = cx - w * 0.5,\n                y   = cy - w * 0.5,\n",
         "                x   = math.floor(cx - w * 0.5),\n                y   = math.floor(cy - w * 0.5),\n"),
    ],
}
