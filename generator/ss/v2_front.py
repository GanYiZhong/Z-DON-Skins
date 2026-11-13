"""v2 module `front`: title (warning dialog + the attract show), entry (festival stage, credit rows, mode
boards), settings, loading, the empty Videos folders and the skin README. Light 8-bit, Nijiiro flow.

Title flow with this skin (engine scenes/title.cpp): op_videos and attract_videos are EMPTY folders, so
the engine would go WARNING -> ATTRACT_CAMERA -> WARNING ..., with 2 black frames at each hand-off (it
passes through the empty video states). So warning_screen.lua never finishes: it plays the whole loop
(warning 6.5 s -> its own attract_scene.lua instance 25.6 s -> warning ...) in one object, no black frame.
  * warning_screen.lua: our dialog (ちゅうい) with Momo drumming a small taiko inside it, 6.5 s.
  * attract_scene.lua: the festival stage, the block-pixel YATAI DON logo (2-frame shine every 4 s),
    Momo and Hoshi drumming one taiko (drum_l / drum_r on a 16-step pattern), Hoshi's bubble every 8 s.
    The start prompt is the engine's own hit_taiko_to_start text (sized 36 here); we add none.
Entry (Nijiiro's arcade-credit flow; entry_credit_arcade on): our entry.lua / box.lua / player.lua draw
everything with ss_ui chrome + engine text; the Nijiiro board/credit/costume textures are blanked.
The costume board does not exist with disable_chara_3d (engine BoxManager), so the costume menu is
unreachable: its keys are blanked (tiny) and Nijiiro's costume_menu.lua is left unused.
Settings is engine-drawn (no Lua): we lay it out through texture.json entries; footer is a full-screen
overlay that clips the list to its panel (rows rest whole inside it); the hint pill is meta's UI.hint;
the background holds the right column in list mode with Momo beside the value box, title the option mode.
Loading: kidou/warning is a full-screen overlay with a window over the engine's progress bar.

Everything is drawn here (crisp, palette only, U grid). LOGICAL coordinates (1920x1080) throughout."""
from __future__ import annotations

import json
import os
import shutil

from PIL import Image

from . import chrome, deco, mascot, strings
from .atlas import OwnSubset, SubsetWriter, _save, phys_xy, resolve
from .style import C, ENGINE_TEXT, U, Canvas, blank_l, snap

NAME = "v2_front"
OWNS = ["Graphics/title", "Graphics/entry", "Graphics/settings", "Graphics/loading",
        "Scripts/title", "Scripts/entry", "Videos", "README.md"]

INK = C["ink"]
PAPER = C["paper"]
W, H = 1920, 1080

# ---------------------------------------------------------------- shared layout numbers (also in Lua)
GROUND = 1032                     # the usual ground line (song select, meta scenes): the engine's credit
                                  # line straddles it on every screen (round 3: title / entry / settings too)
TITLE_GROUND = GROUND
TITLE_HORIZON = 456
TITLE_DECK = (30, 1890, 846)      # festival stage deck: x0, x1, top (the cast + taiko stand on top); full
                                  # width, so the start prompt's two sign chips stand on its front
ENTRY_GROUND = GROUND
ENTRY_HORIZON = 228
ENTRY_DECK = (30, 1890, 858)      # spans both join spots (the global invite bubbles' tails)
ENTRY_JOIN_X = (102, 1816)        # tail tips of the 1P / 2P invite bubbles (v2_meta camera: 12+90, 1492+324)
ENTRY_SWAG = 108                  # lantern swag depth below the horizon (frames the stage)
LOGO_CELL = 6 * U            # 18: one letter pixel of the block logo
LOGO_O = 2 * U               # ink outline around the letters
LOGO_SH = 2 * U              # hard shadow
LOGO_X = 513                 # snap((W - logo width 894) / 2): the title logo's left edge


# ================================================================== helpers
def custom(writer_dir, key, im, entry):
    """Ship `key` with an image whose size differs from the ancestor's (an intentional layout change:
    the engine takes the size from the PNG). entry is LOGICAL. Call after SubsetWriter.write()."""
    _save(im, f"{writer_dir}/{key}.png", "crisp")
    p = f"{writer_dir}/texture.json"
    with open(p, encoding="utf-8") as f:
        tj = json.load(f)
    tj[key] = [phys_xy(e) for e in entry] if isinstance(entry, list) else phys_xy(entry)
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        json.dump(tj, f, ensure_ascii=False, indent=2)
        f.write("\n")
    return 1


def tiny_blanks(G, screen, subset, keys):
    """Blank ancestor keys nobody draws with this skin, as 1x1 logical files (a full-size blank would
    still cost VRAM). Positions are kept."""
    d = f"{G}/{screen}/{subset}"
    os.makedirs(d, exist_ok=True)
    p = f"{d}/texture.json"
    tj = {}
    if os.path.isfile(p):
        with open(p, encoding="utf-8") as f:
            tj = json.load(f)
    n = 0
    for k in keys:
        if k in tj:
            continue
        g = resolve(screen, subset, k)
        if g is None:
            continue
        e = g.entry[0] if isinstance(g.entry, list) else g.entry
        e = e if isinstance(e, dict) else {}
        ent = {"x": int(e.get("x", 0) * g.scale), "y": int(e.get("y", 0) * g.scale)}
        _save(blank_l(1, 1), f"{d}/{k}.png", "crisp")
        tj[k] = phys_xy(ent)
        n += 1
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        json.dump(tj, f, ensure_ascii=False, indent=2)
        f.write("\n")
    return n


def all_keys(screen, subset):
    from .atlas import subset_keys
    return list(subset_keys(screen, subset))


def logo_cells(text):
    return deco.pixtext_rows(text)


def draw_logo(cv, x, y, shine=None):
    """Block-pixel YATAI DON: 5x7 letters, LOGO_CELL per pixel, YATAI in don red, DON in gold, 2U ink
    outline + 2U hard shadow. shine = cell column offset of a 2-cell paper diagonal (or None)."""
    words = [("YATAI", C["don"]), ("DON", C["clear"])]
    cs, o, sh = LOGO_CELL, LOGO_O, LOGO_SH
    cells, xx = [], 0
    for wi, (wd, col) in enumerate(words):
        rows = logo_cells(wd)
        for j, r in enumerate(rows):
            for i, ch in enumerate(r):
                if ch == "X":
                    cells.append((xx + i, j, col))
        xx += len(rows[0]) + 3
    for pass_ in ("shadow", "outline", "fill"):
        for i, j, col in cells:
            x0, y0 = x + o + i * cs, y + o + j * cs
            if pass_ == "shadow":
                cv.rect(x0 - o + sh, y0 - o + sh, x0 + cs + o + sh, y0 + cs + o + sh, INK)
            elif pass_ == "outline":
                cv.rect(x0 - o, y0 - o, x0 + cs + o, y0 + cs + o, INK)
            else:
                c = col
                if shine is not None and shine <= i + j < shine + 3:
                    c = PAPER
                cv.rect(x0, y0, x0 + cs, y0 + cs, c)
    return logo_size()


LOGO_COLS = (0, 6, 12, 18, 24, 32, 38, 44)   # first cell column of each letter (YATAI = 5 x 6 - 1, + 3)
LOGO_Y = 120


def logo_letter(col, shine):
    """One letter of the block logo (its own image: outline + shadow fit in the 1-cell gaps, so drawing
    the letters one by one is pixel-identical to draw_logo). col = its first cell column in the word."""
    word = "YATAIDON"
    k = LOGO_COLS.index(col)
    cs, o, sh = LOGO_CELL, LOGO_O, LOGO_SH
    rows = logo_cells(word[k])
    col_c = C["don"] if k < 5 else C["clear"]
    lw, lh = 5 * cs + 2 * o + sh, 7 * cs + 2 * o + sh
    cv = Canvas(lw, lh)
    cells = [(i, j) for j, r in enumerate(rows) for i, ch in enumerate(r) if ch == "X"]
    for pass_ in ("shadow", "outline", "fill"):
        for i, j in cells:
            x0, y0 = o + i * cs, o + j * cs
            if pass_ == "shadow":
                cv.rect(x0 - o + sh, y0 - o + sh, x0 + cs + o + sh, y0 + cs + o + sh, INK)
            elif pass_ == "outline":
                cv.rect(x0 - o, y0 - o, x0 + cs + o, y0 + cs + o, INK)
            else:
                c = PAPER if (shine is not None and shine <= col + i + j < shine + 3) else col_c
                cv.rect(x0, y0, x0 + cs, y0 + cs, c)
    return cv.result()


# the clouds that drift in Lua (front_fx.lua Clouds; title + entry): key -> deco size
FX_CLOUDS = {"cloud_m": "M", "cloud_s": "S"}
POP_R = 5                       # note pop: disc radius in U cells (+ paper rim inside + 1-cell ink ring)


def add_fx(own):
    """The shared front effects (front_fx.lua): the drifting clouds and the note pops (a small don / ka
    note that jumps off the drum on each hit; frame 0 don, 1 ka)."""
    for key, size in FX_CLOUDS.items():
        rows = deco.CLOUD_M if size == "M" else deco.CLOUD_S
        w, h = deco.size_of(rows, deco.CLOUD_CELL)
        cv = Canvas(w, h)
        deco.cloud(cv, 0, 0, size)
        own.add(key, [cv.result()])
    d = 2 * (POP_R + 1) * U
    pops = []
    for col in (C["don"], C["ka"]):
        cv = Canvas(d, d)
        deco.pixdisc(cv, d / 2, d / 2, POP_R, col, inner_ring=(PAPER, 1))
        pops.append(cv.result())
    own.add("pop", pops)


def logo_size():
    n = len(logo_cells("YATAI")[0]) + 3 + len(logo_cells("DON")[0])
    return n * LOGO_CELL + 2 * LOGO_O + LOGO_SH, 7 * LOGO_CELL + 2 * LOGO_O + LOGO_SH


DECK_FRONT = 14 * U                 # 42: the deck's board front (top board + planks); posts below it


def stage_deck(cv, x0, x1, top, ground):
    """The festival stage: a wooden deck on posts. The board front runs from `top` DECK_FRONT down (1U
    ink outline, a 3U wood top board, wood2 planks with ink seams every 24U); below it, to the ground
    line, 6U posts (wood2, 1U ink sides) at both ends and every 96U, with a 1U ink sill under the boards
    (the cream shows between the posts). (local: promote to core deco)"""
    x0, x1, top = snap(x0), snap(x1), snap(top)
    fb = top + DECK_FRONT
    cv.rect(x0, top, x1, fb + U, INK)
    cv.rect(x0 + U, top + U, x1 - U, top + 4 * U, C["wood"])
    cv.rect(x0 + U, top + 4 * U, x1 - U, top + 5 * U, INK)
    cv.rect(x0 + U, top + 5 * U, x1 - U, fb, C["wood2"])
    for xx in range(x0 + 24 * U, x1 - 12 * U, 24 * U):
        cv.rect(xx, top + 5 * U, xx + U, fb, INK)
    pw = 6 * U
    n = max(1, round((x1 - x0 - pw) / (96 * U)))
    n += 1 - n % 2   # odd bay count: no post at the centre, where the hint pill sits (UI.hint, bottom centre)
    for i in range(n + 1):
        px = snap(x0 + 3 * U + (x1 - x0 - pw - 6 * U) * i / n)
        cv.rect(px, fb + U, px + pw, ground, INK)
        cv.rect(px + U, fb + U, px + pw - U, ground, C["wood2"])


def festoon(cv, x0, x1, y, sag, n, cell=3 * U):
    """A drooping lantern rope from (x0, y) to (x1, y), `sag` deep in the middle: a 1U ink rope stepped on
    the U grid (vertical runs filled, so it never breaks), n lanterns hanging from it.
    (local: promote to core deco next to deco.lanterns)"""
    x0, x1, y = snap(x0), snap(x1), snap(y)
    mid, half = (x0 + x1) / 2, (x1 - x0) / 2

    def rope_y(x):
        t = (x - mid) / half
        return snap(y + sag * (1 - t * t))
    prev = None
    for xx in range(x0, x1, U):
        yy = rope_y(xx + U / 2)
        top, bot = yy, yy
        if prev is not None:
            top, bot = min(yy, prev), max(yy, prev)
        cv.rect(xx, top, xx + U, bot + U, INK)
        prev = yy
    w, _ = deco.size_of(deco.LANTERN, cell)
    for i in range(n):
        cx = x0 + (x1 - x0) * (i + 0.5) / n
        deco.cells(cv, snap(cx - w / 2), rope_y(cx) + U, deco.LANTERN, deco.LANTERN_PAL, cell)


def join_spot(cv, cx, top, acc):
    """A marked plank on the deck front (the join spot a 1P / 2P invite bubble points at, its tail tip
    at cx): accent fill between 1U ink sides. Its player tag (18 px paper, ink starting 21U right of the
    plank's left edge: x 138 / 1851, centre y 886.5) is drawn by entry.lua; the tail ends on the plank's
    top rows and must not cover it."""
    x0 = snap(cx - 9 * U)
    x1 = x0 + 30 * U
    fb = top + DECK_FRONT
    cv.rect(x0, top + 5 * U, x1, fb, INK)
    cv.rect(x0 + U, top + 5 * U, x1 - U, fb, acc)


def scene(ground, horizon, clouds=(), lantern_n=0, taiko_cx=None, deck=None, swag=0):
    """Festival scene (bible 2.4): sky band ending in the horizon checker at `horizon`, lantern string
    on the horizon line (or, with swag, two ropes drooping `swag` below it), cream, ground strip from
    `ground`, optional taiko standing on the ground."""
    cv = Canvas(W, H, bg=C["bg0"])
    deco.sky(cv, 0, 0, W, horizon)
    for x, y, s in clouds:
        deco.cloud(cv, x, y, s)
    if lantern_n and swag:
        festoon(cv, 0, W // 2, horizon, swag, lantern_n // 2)
        festoon(cv, W // 2, W, horizon, swag, lantern_n // 2)
    elif lantern_n:
        deco.lanterns(cv, 0, W, horizon, lantern_n, cell=3 * U)
    deco.ground(cv, 0, ground, W, H)
    foot = ground
    if deck:
        stage_deck(cv, deck[0], deck[1], deck[2], ground)
        foot = deck[2]
    if taiko_cx is not None:
        deco.taiko(cv, taiko_cx, foot)
    return cv


# ================================================================== title
def build_title(ctx):
    G = ctx.G
    n = 0
    own = OwnSubset(G, "title", "ss_front")
    # the attract stage (no mascots: Lua draws them)
    # polish: the clouds are drawn (and drift) in Lua (title/front_fx.lua), so the sky band is bare here
    cv = scene(TITLE_GROUND, TITLE_HORIZON, lantern_n=10, taiko_cx=960, deck=TITLE_DECK)
    own.add("stage", [cv.result()])       # the prompt's sign chips: Lua (title/prompt_chips.lua, per language)
    # the logo, one letter per frame group (polish: the letters drop in one by one and wave): frame
    # 3 * k + s = letter k (Y A T A I D O N) with shine state s (plain, shine at 1/3, shine at 2/3). The
    # shine is still the one diagonal over the whole word (global cell columns). Lua places letter k at
    # LOGO_X + LOGO_COLS[k] * LOGO_CELL, y LOGO_Y.
    frames = []
    for col in LOGO_COLS:
        for s in (None, 14, 34):
            frames.append(logo_letter(col, s))
    own.add("logo_l", frames, x=LOGO_X, y=LOGO_Y)
    add_fx(own)
    # the warning dialog (its words are drawn by warning_screen.lua; Hoshi's bubble is UI.bubble)
    own.add("warn_dialog", [warning_dialog()], x=WARN_X0, y=WARN_Y0)
    wcv = scene(TITLE_GROUND, TITLE_HORIZON, lantern_n=10)
    own.add("warn_bg", [wcv.result()])    # the engine prints the prompt here too: Lua draws its chips
    n += own.write()

    # ancestor keys: nothing of Nijiiro's warning / Green's camera + movie art is drawn by our Lua;
    # blank them (tiny) so no ancestor art can ever show.
    for sub in ("warning", "camera", "movie"):
        n += tiny_blanks(G, "title", sub, all_keys("title", sub))
    n += title_animation(G)
    return n


PROMPT_ON_MS, PROMPT_OFF_MS = 1200, 400     # the start prompt's hard blink (75 % duty)
PROMPT_Y = 948                  # skin_config hit_taiko_to_start y (the engine draws it twice, centred on
                                # x = W/4 and 3W/4, white with a fixed 4 px #000000 outline: title.cpp)
# measured on the ja build (3840x2160, prompt y 966): the outlined text's ink box is x 247.5..697 /
# 1207.5..1657, y +10.5..+54 below the entry y. Centres sit 7.75 px left of W/4, 3W/4. The ink box is
# our font's advance width (432 for the ja prompt) + 17.5 (the engine's 4 px outline + bearing).
# The sign chips behind the two prompts are drawn by lua/front/title/prompt_chips.lua (sized from
# UI.text_width(UI.t("title_start"), 36) + 17.5 in the player's language); these numbers are its source.
PROMPT_INK_W, PROMPT_INK_Y0, PROMPT_INK_Y1, PROMPT_CX_OFF = 449.5, 10.5, 54, -7.75


def title_animation(G):
    """Our own title animation.json: Nijiiro's file with two engine fades changed (title.cpp).
    id 14 drives the start prompt (`hit_taiko_to_start`). Nijiiro's ramps 1 -> 0 -> 1 over 2.5 s (on 1 s,
    fading 1 s, off 0.5 s), so many frames show it translucent or not at all. Here it is a hard blink:
    on PROMPT_ON_MS, off PROMPT_OFF_MS (a 1 ms fade = one frame step). id 13 is the screen fade on DON:
    a translucent white full-screen rect; here it stays at 0 (the entry screen opens with its own window
    frames), keeping the 400 ms before the screen change."""
    from .atlas import NIJIIRO_G
    with open(f"{NIJIIRO_G}/title/animation.json", encoding="utf-8") as f:
        anim = json.load(f)
    for a in anim:
        if a.get("id") == 14:
            a.clear()
            a.update({"id": 14, "type": "fade", "duration": 1, "initial_opacity": 1.0, "final_opacity": 0.0,
                      "delay": PROMPT_ON_MS, "reverse_delay": PROMPT_OFF_MS, "loop": True,
                      "comment": "start prompt: hard blink (SimpleStyle)"})
        elif a.get("id") == 13:
            a.update({"duration": 400, "initial_opacity": 0.0, "final_opacity": 0.0,
                      "comment": "screen change on don press: no white fade (SimpleStyle)"})
    d = f"{G}/title"
    os.makedirs(d, exist_ok=True)
    with open(f"{d}/animation.json", "w", encoding="utf-8", newline="\n") as f:
        json.dump(anim, f, ensure_ascii=False, indent=2)
        f.write("\n")
    return 1


# the speech bubbles (Hoshi's attract line, the entry PRESS DON) are UI.bubble at run time (core ss_ui)
WARN_X0, WARN_Y0, WARN_X1, WARN_Y1 = 249, 168, 1671, 834
WARN_FLOOR = 648      # the floor line inside the dialog (Momo + the small taiko stand on it)
# the dialog's words (warning_screen.lua, UI.text_key, 36 px ink): the title centred on the band at
# (960, 198); the lines warn_line4, 1, 2, 3 left-aligned at x 795, centres y 400 + 84 i (870 px room).


def warning_dialog():
    """The dialog shell: gold title band (no word), the demo stage, the divider. Text is Lua."""
    w, h = WARN_X1 - WARN_X0 + 2 * U, WARN_Y1 - WARN_Y0 + 2 * U
    cv = Canvas(w, h)
    b = chrome.dialog(cv, 0, 0, w - 2 * U, h - 2 * U)
    ty1 = b.iy0 + chrome.DIALOG_TITLE_H          # chrome.dialog's title band, drawn without its text
    cv.rect(b.ix0, b.iy0, b.ix1, ty1, C["focus"])
    cv.rect(b.ix0, ty1, b.ix1, ty1 + U, INK)
    b.iy0 = ty1 + U
    # left: the demo stage (floor line + small taiko; Momo is drawn by Lua)
    fx0, fx1 = b.ix0 + 12 * U, b.ix0 + 156 * U
    fy = WARN_FLOOR - WARN_Y0
    cv.rect(fx0, fy, fx1, fy + U, INK)
    deco.taiko(cv, fx0 + 96 * U, fy, cell=2 * U)
    # divider and the text column
    dx = fx1 + 9 * U
    cv.rect(dx, b.iy0 + 12 * U, dx + U, b.iy1 - 12 * U, C["line"])
    return cv.result()


# ================================================================== entry
ENTRY_DIALOG = (570, 294, 1350, 534)


def build_entry(ctx):
    G = ctx.G
    n = 0
    w = SubsetWriter(G, "entry", "background")
    def entry_bg(i, n_, ww, hh):
        cv = scene(ENTRY_GROUND, ENTRY_HORIZON,      # clouds: Lua (front_fx.lua, drifting)
                   lantern_n=10, taiko_cx=960, deck=ENTRY_DECK, swag=ENTRY_SWAG)
        for cx, acc in zip(ENTRY_JOIN_X, (C["p1"], C["p2"])):
            join_spot(cv, cx, ENTRY_DECK[2], acc)
        return cv.result()
    w.put("bg", entry_bg)
    n += w.write()
    n += tiny_blanks(G, "entry", "background", [k for k in all_keys("entry", "background") if k != "bg"])

    own = OwnSubset(G, "entry", "ss_front")      # the PRESS DON bubble is UI.bubble (entry.lua)
    cur = Canvas(7 * U, 11 * U)
    chrome.cursor(cur, U, 5.5 * U)
    own.add("cursor", [cur.result()])
    add_fx(own)
    n += own.write()

    n += build_name_entry(G)     # SubsetWriters first: write() starts its folder clean
    # boards / credit rows / costume menu: drawn by our Lua (or unreachable): tiny blanks
    for sub in ("mode_select", "side_select", "costume_select", "global", "wait"):
        n += tiny_blanks(G, "entry", sub, all_keys("entry", sub))
    return n


def build_name_entry(G):
    """Green's name picker (online card login only): chrome replacements for its keys."""
    w = SubsetWriter(G, "entry", "name_entry")

    def disc(fill, big):
        def draw(i, n, ww, hh):
            cv = Canvas(ww, hh)
            r = (min(ww, hh) // U) // 2 - 2
            deco.pixdisc(cv, ww / 2, hh / 2, r, fill)
            return cv.result()
        return draw
    w.put("plate_red", disc(C["p1"], False))
    w.put("plate_yellow", disc(C["clear"], False))
    w.put("big_red", disc(C["p1"], True))
    w.put("big_yellow", disc(C["clear"], True))

    def ring(i, n, ww, hh):
        cv = Canvas(ww, hh)
        r = (min(ww, hh) // U) // 2 - 2
        deco.pixdisc(cv, ww / 2, hh / 2, r, (0, 0, 0, 0), ring_w=2)
        return cv.result()
    w.put("ring_outline", ring)

    # banner_1p / banner_2p: nothing draws them (our name_entry.lua draws its own 1P / 2P tag): tiny blanks

    def btn(state):
        def draw(i, n, ww, hh):
            cv = Canvas(ww, hh)
            x1, y1 = chrome.fit(ww, hh, U)
            chrome.button(cv, 0, 0, x1 - U, y1 - U, None, state)
            return cv.result()
        return draw
    w.put("button_red", btn("normal"))
    w.put("button_yellow", btn("focused"))

    def outline(i, n, ww, hh):
        cv = Canvas(ww, hh)
        x1, y1 = chrome.fit(ww, hh, 0)
        chrome.frame(cv, 0, 0, x1, y1, None, border=2 * U, shadow=0)
        return cv.result()
    w.put("button_outline", outline)

    def arrow(i, n, ww, hh):
        cv = Canvas(ww, hh)
        chrome.cursor(cv, snap(ww / 2 - 9), hh / 2, 2 * U)
        return cv.result()
    w.put("arrow", arrow)
    n = w.write()
    n += tiny_blanks(G, "entry", "name_entry", ["banner_1p", "banner_2p"])

    # the name picker's window = costume_select nine-slice pieces (stretched along their edge only)
    w = SubsetWriter(G, "entry", "costume_select")
    for suf in ("1p", "2p"):
        for k in ("top_left", "top_right", "bottom_left", "bottom_right", "top", "bottom", "left", "right",
                  "center"):
            key = f"box_{k}_{suf}"
            if resolve("entry", "costume_select", key) is None:
                continue
            w.put(key, nine(k))
    n += w.write()
    # entry/global (name_entry_ja, player_entry_ja / _en, ...): nothing draws them with this skin (no C++
    # or Lua reference); build_entry tiny-blanks the whole subset
    return n


def nine(part):
    """Nine-slice piece of a dialog window (2U ink border, paper), 96x96 logical."""
    def draw(i, n, ww, hh):
        cv = Canvas(ww, hh)
        cv.rect(0, 0, ww, hh, PAPER)
        b = 2 * U
        if "top" in part:
            cv.rect(0, 0, ww, b, INK)
        if "bottom" in part:
            cv.rect(0, hh - b, ww, hh, INK)
        if "left" in part:
            cv.rect(0, 0, b, hh, INK)
        if "right" in part:
            cv.rect(ww - b, 0, ww, hh, INK)
        # notched corners: the corner square outside the border stays empty
        for cx, cy in (("left", "top"), ("right", "top"), ("left", "bottom"), ("right", "bottom")):
            if cx in part and cy in part:
                x0 = 0 if cx == "left" else ww - U
                y0 = 0 if cy == "top" else hh - U
                cv.rect(x0, y0, x0 + U, y0 + U, (0, 0, 0, 0))
        return cv.result()
    return draw


# ================================================================== settings
# Engine geometry (settings_box.cpp, 1280 base x1.5): rows sit at y = -75 + 150 k (+ the box entry
# offset), 150 apart; the option name is centred on the title texture at y = title.y + h / 8; the
# description is printed at (675, 405), 37 px black, single line.
SET_PANEL = (3, 120, 597, 1020)         # the list panel (outer border edge): 6 whole rows (141..996)
SET_GROUND = GROUND
SET_ROW_PITCH = 150
SET_BOX_Y = 48                          # box entry offset: rows rest at 141 + 150 k, whole rows in the window
SET_ROW = (3, 18, 120)                  # button inside the box frame: x0, y0, y1 (+1U shadow)
SET_FADE = 2 * U                        # fade cell: 1 solid + 1 dither row at each window edge
DLG = (699, 63, 1599, 330)              # option dialog (name band + value buttons)
BAND = (705, 69, 1593, 141)             # its title band (24U), the engine centres the name at y 75 + h/2
DESC = (645, 381, 1875, 684)            # description panel (~300 tall); the engine prints the text at (675, 405)
TITLE_FRAME = (630, 0, 1890, 690)       # our "title" texture: dialog + description panel
MOMO_CX = 1788                          # Momo stands on the description panel, beside the value box, facing it
BTN_W, BTN_H = 318, 153                 # option/button_* frame (Green 212x102 x1.5)
BODY_CY = (BAND[3] + U + DLG[3] - 2 * U) // 2
BTN_Y = BODY_CY - BTN_H // 2
CENTER_X = (DLG[0] + DLG[2]) // 2 - BTN_W // 2
BTN_X = [CENTER_X - 180, CENTER_X + 180, CENTER_X]   # bool left, bool right, value
ARROW = 105                                           # blue_arrow frame (Green 70 x1.5)
ARROW_Y = (DLG[1] + DLG[3]) // 2 - ARROW // 2
ARROW_X = [DLG[0] - 12 - ARROW // 2 - 24, DLG[2] + 12 - ARROW // 2 + 24]
SET_KEYS = {"title": "settings_title", "pick": "settings_pick", "desc": "settings_howto"}   # ss/strings.py
LANGS = ("ja", "en", "zh", "ko")


def set_shells(cv, o, lang, band_fill=None, pick=True):
    """The right column: the option dialog (name band + body) and the description panel. o maps screen
    to canvas coordinates. In list mode (pick) the band says せってい and the body / panel carry the
    list-mode prompt; in option mode the engine prints the option name and description over them."""
    t = {k: strings.get(v, lang) for k, v in SET_KEYS.items()}
    d0, d1 = o(DESC[0], DESC[1]), o(DESC[2], DESC[3])
    chrome.panel(cv, d0[0], d0[1], d1[0], d1[1], fill=PAPER)
    a, b = o(DLG[0], DLG[1]), o(DLG[2], DLG[3])
    chrome.frame(cv, a[0], a[1], b[0], b[1], PAPER, border=2 * U, shadow=2 * U)
    ba, bb = o(BAND[0], BAND[1]), o(BAND[2], BAND[3])
    cv.rect(ba[0], ba[1], bb[0], bb[1], band_fill or C["focus"])
    cv.rect(ba[0], bb[1], bb[0], bb[1] + U, INK)
    if pick:
        cv.text((ba[0] + bb[0]) / 2, (ba[1] + bb[1]) / 2, t["title"], 36, INK)
        cv.text((a[0] + b[0]) / 2, (bb[1] + U + b[1] - 2 * U) / 2, t["pick"], 36, INK)
        tx, ty = o(675, 405)
        cv.text(tx, ty + 18, t["desc"], 36, INK, anchor="lm")
    return ba, bb


def settings_bg(lang, words=True):
    """The list-mode background in `lang` (words=False: the shells without the prompt, for the footer)."""
    cv = Canvas(W, H, bg=C["bg0"])
    deco.sky(cv, 0, 0, W, 96)
    deco.cloud(cv, 1170, 6, "S")
    deco.cloud(cv, 1530, 30, "S")
    deco.ground(cv, 0, SET_GROUND, W, H)
    x0, y0, x1, y1 = SET_PANEL
    chrome.panel(cv, x0, y0, x1, y1, fill=C["bg0"])
    # the right column in list mode, and Momo on the description panel beside the value box, facing it
    set_shells(cv, lambda x, y: (x, y), lang, pick=words)
    mascot.paste(cv, "momo", "turn", "menu", MOMO_CX, DESC[1], mirror=True)
    return cv


def settings_overlay(bg_img, lang):
    """The footer texture, full screen, drawn AFTER the list: background pixels everywhere left of the
    list's right edge except the panel interior (so rows never show above or below the panel), one solid
    and one dither row (SET_FADE) at both ends of the interior, and the footer band (ground). Rows rest whole inside the window (SET_BOX_Y), so the fade only ever
    touches a row while it scrolls."""
    x0, y0, x1, y1 = SET_PANEL
    ix0, iy0, ix1, iy1 = x0 + U, y0 + U, x1 - U, y1 - U
    D = bg_img.width // W
    mask = Image.new("L", bg_img.size, 0)
    from PIL import ImageDraw
    md = ImageDraw.Draw(mask)
    md.rectangle((0, 0, (x1 + 2 * U) * D - 1, H * D - 1), fill=255)       # left column
    md.rectangle((0, SET_GROUND * D, W * D - 1, H * D - 1), fill=255)      # footer band
    md.rectangle((ix0 * D, iy0 * D, ix1 * D - 1, iy1 * D - 1), fill=0)    # the panel window
    cell = SET_FADE
    rows_ = ((iy0, None), (iy0 + cell, 1), (iy1 - 2 * cell, 1), (iy1 - cell, None))
    for yy, phase in rows_:
        full = phase is None
        for xx in range(ix0, ix1, cell):
            k = (xx - ix0) // cell
            if full or k % 2 == phase:
                md.rectangle((xx * D, yy * D, min(xx + cell, ix1) * D - 1, (yy + cell) * D - 1), fill=255)
    out = Image.new("RGBA", bg_img.size, (0, 0, 0, 0))
    out.paste(bg_img, (0, 0), mask)
    cv = Canvas(W, H)
    cv.im = out
    cv.d = ImageDraw.Draw(cv.im)
    # no baked hint pill (round 3): the one pill comes from UI.hint via meta's GuidePanel wrapper
    # (per-screen items: ka えらぶ / don 決定 / ESC もどる); a baked one stacked under it (F1).
    return cv.result()


def settings_title(highlight, lang):
    """Option mode: the same shells as the background (so the window does not jump), without the list
    prompt; the band is gold (bible dialog band) and gets a paper ▶ while a value is edited. Transparent everywhere
    else, so the background's Momo shows beside it."""
    fx0, fy0, fx1, fy1 = TITLE_FRAME
    cv = Canvas(fx1 - fx0, fy1 - fy0)
    o = lambda x, y: (x - fx0, y - fy0)       # noqa: E731
    ba, bb = set_shells(cv, o, lang, pick=False)
    if highlight:   # editing: a paper ▶ at the band's left end
        chrome.cursor(cv, ba[0] + 6 * U, (ba[1] + bb[1]) / 2, 2 * U, fill=PAPER)
    return cv.result()


def settings_button(focused):
    def draw(i, n, ww, hh):
        cv = Canvas(ww, hh)
        bw, bh = 300, 90
        x0 = snap((ww - bw) // 2 - U)
        y0 = snap((hh - bh) // 2)
        chrome.button(cv, x0, y0, x0 + bw, y0 + bh, None, "focused" if focused else "normal")
        return cv.result()
    return draw


def settings_animation(G):
    """Our own settings animation.json (it replaces Green's whole file). LOGICAL numbers (own files are
    not scaled). id 0 = the list scroll (Green 100 x1.5 = one row pitch). id 1 / 2 = the ◀ ▶ arrows: Green
    fades them 1 -> 0 and slides them 25 px every second, which draws the pixel arrows translucent and off
    the grid; here they hold at alpha 1 and stay put (alpha policy: pixel art at 1 or not at all)."""
    anim = [
        {"id": 0, "type": "move", "duration": 166, "total_distance": SET_ROW_PITCH, "lock_input": True,
         "comment": "box move (one row pitch)"},
        {"id": 1, "type": "fade", "duration": 1000, "initial_opacity": 1.0, "final_opacity": 1.0, "loop": True,
         "comment": "arrows: solid (no fade)"},
        {"id": 2, "type": "move", "duration": 1000, "total_distance": 0, "loop": True,
         "comment": "arrows: still"},
    ]
    d = f"{G}/settings"
    os.makedirs(d, exist_ok=True)
    with open(f"{d}/animation.json", "w", encoding="utf-8", newline="\n") as f:
        json.dump(anim, f, ensure_ascii=False, indent=2)
        f.write("\n")
    return 1


def build_settings(ctx):
    G = ctx.G
    n = 0
    # background is drawn by the C++ under a fixed name: the base is Japanese and background_<lang> are
    # the variants Z-DON picks with the skin option language_variants (core skin_config)
    bg_img = settings_bg("ja").result()
    w = SubsetWriter(G, "settings", "background")
    w.put("background", lambda i, n_, ww, hh: bg_img)
    w.put_blank("overlay")      # drawn at scale 0.7 by the engine: our description panel lives in `title`

    def arrow(i, n_, ww, hh):
        cv = Canvas(ww, hh)
        rows = [r[::-1] for r in chrome.CURSOR_ROWS]        # ◀ (index 1 is drawn mirrored: ▶)
        deco.cells(cv, snap(ww / 2 - 7 * U), snap(hh / 2 - 13.5 * U + U), rows, {"X": C["clear"]}, 2 * U,
                   outline=INK)
        return cv.result()
    w.put("blue_arrow", arrow, entry=[{"x": ARROW_X[0], "y": ARROW_Y}, {"x": ARROW_X[1], "y": ARROW_Y}])
    n += w.write()
    d = f"{G}/settings/background"
    for lang in LANGS[1:]:
        n += custom(d, f"background_{lang}", settings_bg(lang).result(), {"x": 0, "y": 0})
    # the footer only keeps the left column and the ground band: built from the wordless shells
    n += custom(d, "footer", settings_overlay(settings_bg("ja", words=False).result(), ctx.lang), {"x": 0, "y": 0})
    fx0, fy0, _, _ = TITLE_FRAME
    n += custom(d, "title", settings_title(False, ctx.lang), {"x": fx0, "y": fy0})
    n += custom(d, "title_highlight", settings_title(True, ctx.lang), {"x": fx0, "y": fy0})

    w = SubsetWriter(G, "settings", "box")

    def row(focused):
        def draw(i, n_, ww, hh):
            cv = Canvas(ww, hh)
            x0, y0, y1 = SET_ROW
            x1 = ww - 6
            if focused:
                chrome.button(cv, x0, y0, x1, y1, None, "focused")
                chrome.cursor(cv, x0 + 6 * U, (y0 + y1) / 2, 2 * U, fill=PAPER)
            else:
                chrome.button(cv, x0, y0, x1, y1, None, "normal")
            return cv.result()
        return draw
    w.put("box", row(False), entry={"x": 0, "y": SET_BOX_Y})
    w.put("box_highlight", row(True), entry={"x": 0, "y": SET_BOX_Y})
    n += w.write()

    w = SubsetWriter(G, "settings", "option")
    ent = [{"x": x, "y": BTN_Y} for x in BTN_X]
    w.put("button_off", settings_button(False), entry=ent)
    w.put("button_on", settings_button(True), entry=ent)
    n += w.write()
    n += settings_animation(G)
    return n


# ================================================================== loading
BAR = (552, 846, 816, 36)        # x, y, w, h of the engine's progress bar (skin_config loading_progress_bar)
LOAD_GROUND = 960


def loading_img(lang):
    cv = Canvas(W, H, bg=C["bg0"])
    deco.sky(cv, 0, 0, W, 408)
    deco.cloud(cv, 120, 60, "M")
    deco.cloud(cv, 1650, 300, "S")
    lw, lh = logo_size()
    draw_logo(cv, snap((W - lw) // 2), 150)
    deco.ground(cv, 0, LOAD_GROUND, W, H)
    bx, by, bw, bh = BAR
    # the loading panel around the bar
    p = chrome.panel(cv, bx - 9 * U, by - 24 * U, bx + bw + 9 * U, by + bh + 9 * U, fill=PAPER)
    cv.text(bx, by - 12 * U, strings.get("loading", lang), 24, INK, anchor="lm")
    # the window: transparent where the engine's bar shows, with a 1U ink frame and segment dividers
    cv.rect(bx - U, by - U, bx + bw + U, by + bh + U, INK)
    cv.rect(bx, by, bx + bw, by + bh, (0, 0, 0, 0))
    segs = 17
    for i in range(1, segs):
        sx = bx + (bw * i // segs) // U * U
        cv.rect(sx, by, sx + U, by + bh, INK)
    mascot.paste(cv, "momo", "turn", "scene", 360, LOAD_GROUND)
    mascot.paste(cv, "hoshi", "turn", "scene", 1560, LOAD_GROUND, mirror=True)
    return cv.result()


def build_loading(ctx):
    """kidou/warning is drawn by the C++ under a fixed name: Japanese base + warning_<lang> variants
    (language_variants)."""
    G = ctx.G
    d = f"{G}/loading/kidou"
    os.makedirs(d, exist_ok=True)
    with open(f"{d}/texture.json", "w", encoding="utf-8") as f:
        f.write("{}\n")
    n = custom(d, "warning", loading_img("ja"), {"x": 0, "y": 0})
    for lang in LANGS[1:]:
        n += custom(d, f"warning_{lang}", loading_img(lang), {"x": 0, "y": 0})

    w = SubsetWriter(G, "loading", "skip_badge")

    def badge(i, n_, ww, hh):
        c2 = Canvas(ww, hh)
        x1, y1 = chrome.fit(ww, hh, U)
        y0 = (hh - 27 * U) // 2 // U * U
        b = chrome.panel(c2, 0, y0, x1, y0 + 27 * U, fill=PAPER)
        c2.rect(b.ix0, b.iy0, b.ix0 + 6 * U, b.iy1, C["clear"])
        c2.rect(b.ix0 + 6 * U, b.iy0, b.ix0 + 7 * U, b.iy1, INK)
        return c2.result()
    w.put("badge", badge)
    n += w.write()
    return n


# ================================================================== Lua, videos, README, config
def copy_front_lua(ctx):
    src = os.path.join(ctx.here, "lua", "front")
    n = 0
    for root, _, files in os.walk(src):
        for f in files:
            if not f.endswith(".lua"):
                continue
            rel = os.path.relpath(os.path.join(root, f), src)
            dst = os.path.join(ctx.scripts, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(os.path.join(root, f), dst)
            n += 1
    return n


def write_videos(ctx):
    for d in ("op_videos", "attract_videos"):
        p = os.path.join(ctx.out, "Videos", d)
        os.makedirs(p, exist_ok=True)
        with open(os.path.join(p, ".keep"), "w", encoding="utf-8", newline="\n") as f:
            f.write("")
    return 2


def write_readme(ctx):
    with open(os.path.join(ctx.here, "lua", "front", "README.md"), encoding="utf-8") as f:
        s = f.read()
    with open(os.path.join(ctx.out, "README.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write(s)
    return 1


def skin_config(ctx):
    """Text entries need their "text" block (the engine skips an entry without one), so the
    Nijiiro entries are copied and only re-sized."""
    from .atlas import NIJIIRO_G
    with open(f"{NIJIIRO_G}/skin_config.json", encoding="utf-8") as f:
        nj = json.load(f)
    bx, by, bw, bh = BAR
    cfg = {
        # the engine's white / 4 px black-outline prompt is parked off screen (y -400): the outline
        # clogged the CJK strokes on the paper sign. prompt_chips.lua draws the words in ink with a
        # 1P / 2P tag on each sign, blinking with the same animation 14.
        "hit_taiko_to_start": {"x": 0, "y": -400, "width": 800, "font_size": ENGINE_TEXT[36],
                               "text": {l: strings.get("title_start", l) for l in LANGS}},
        # Z-DON (option_box.cpp): the settings description at the 24 role (engine 32: the pixel font's grid;
        # the engine default 37 blurs it) and wrapped inside the white box (x 648..1876; text from 675)
        "settings_description": {"x": 675, "y": 405, "font_size": ENGINE_TEXT[24], "width": 1173},
        "loading_progress_bar": {"x": bx, "y": by, "width": bw, "height": bh},
        # loading -> title: the engine fades a white full-screen rect in over this many ms (loading.cpp,
        # default 1000: `title/20` was the loading screen under a translucent white). 1 ms = a cut.
        "loading_fade_ms": {"x": 1},
    }
    for k, size in (("entry_credit_1p", 36), ("entry_credit_2p", 36), ("entry_credit_start", 36),
                    ("entry_cancel", 24)):
        e = dict(nj[k])
        e["font_size"] = ENGINE_TEXT[size]        # role size -> engine size (the engine em is 0.75 x size)
        cfg[k] = e
    return cfg


def build(ctx):
    n = build_title(ctx) + build_entry(ctx) + build_settings(ctx) + build_loading(ctx)
    n += copy_front_lua(ctx) + write_videos(ctx) + write_readme(ctx)
    return n
