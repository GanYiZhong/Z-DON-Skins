# SimpleStyle v2: guide for screen agents

Read first: `NIJIIRO4K_PLAN.md` (binding), `reports/art_direction_review.md` §2 (the art bible) and your
screen's §3 items, `LIGHT8_GUIDE.md` (palette roles, contrast rules). Then this file. Core report:
`reports/core_v2.md`.

v2 = parent **YataiDONNijiiro** (1920x1080, which inherits PyTaikoGreen), **texture density 2** (4K).
Use Nijiiro's layouts, Lua and options for everything. The old Green-based modules in `ss/` (game.py,
song_select.py, front.py, ...) are reference only (drawing ideas, not geometry); they are not registered
and will not run against the v2 core. A copy of the v1 generator is in `cache/snap_green_l8/`.

## 1. Units: logical in, physical out
| thing | unit |
|---|---|
| everything you pass to `Canvas`, `chrome.*`, `deco.*`, `mascot.*` | **logical** px (1920x1080 space) |
| `SubsetWriter` draw callback `draw(i, n, w, h)` | gets **logical** w, h; must return a **physical** image (`Canvas(w, h).result()` does that) |
| PNGs written to `out/` | **physical** (logical x `style.D`, D = 2) |
| our `texture.json` x / y / x2 / y2 / crop | **physical** (atlas.py converts; you pass logical `entry=`) |
| `skin_config.json`, `animation.json` | **logical** (never multiply) |
| Lua (`ss_ui.lua`, every script) | **logical**; `tex.get_texture_info` reports logical sizes |

The engine loads this skin's textures at 1/D, renders into a 3840x2160 target with camera zoom D, and
keeps Nijiiro / Green textures at their usual scale (Nijiiro x1, Green x1.5). `--density 1` builds a
plain 1080p skin for engines without the feature (same code, D = 1).

## 2. The grid (bible 2.1 translated)
- **U = 3 logical (6 phys)**: every chrome coordinate, width, border, shadow, notch, gap is a multiple of U.
  Chrome helpers snap to U; run `SS_DEBUG=1 python build.py --only <you>` to make off-grid values raise.
- **Mascot k** (logical px per sprite px): `style.MASCOT_K = {"tiny": 3, "menu": 6, "portrait": 6, "scene": 9}`
  = 6 / 12 / 18 phys. Sprites are 34x34 cells, so 102 / 204 / 306 logical tall. Nothing else.
  Scene screens (title, entry, result, game over): k=9 both characters on the same ground row.
  Menus and the gameplay portrait: k=6. Tiny icons / crowds: k=3.
  **Pick the k by ROLE, never by number**: Lua `UI.Mascot.new({ role = "scene" })` (`UI.K` =
  `{tiny=3, menu=6, portrait=6, scene=9}`), Python `mascot.paste(cv, char, expr, "scene", cx, foot)`.
  A raw `k =` still works but logs `[ss_ui] warning: ... raw k=` once per value (`UI.warn_once` writes through
  `tex.log`, so it lands in `latest.log` as `[info] : [lua] [ss_ui] warning: ...`; Lua `print` does NOT reach
  the log; run_cap.sh greps `[ss_ui]`). The bible's 1280 numbers
  are already translated in this table (bible "menu k=3" = logical menu 6, bible "scene k=6" = 9): never
  re-derive a k from the bible.
  The game stage: 1P Momo `scene`, Hoshi `menu`; 2P / dan bands: both `menu`. Song / diff / dan select,
  settings: `menu`. Gameplay portrait: `portrait`.
- **Text**: Fusion Pixel at **18 / 24 / 36 / 48 logical** only (36/48/72/96 phys: every font pixel is
  3/4/6/8 whole phys px). Roles (`chrome.TEXT`): 18 labels, hints, chips; 24 body; 36 titles, plate text,
  values; 48 screen-level numbers and stamps. Other sizes warn (raise with SS_DEBUG=1).
  **Engine text uses the 4/3 size**: the engine scales the font so ascent+descent = its font size, so its
  em is 0.75 x the size (measured in-engine, `caps/corefix/title2`). Role 18/24/36/48 = engine
  **24/32/48/64** (`style.ENGINE_TEXT`, Lua `D.TEXT_ENGINE`); only those render with whole font pixels and
  match baked text. `UI.text(s, 18)` does the mapping for you; `skin_config` `font_size` values and raw
  `text.create_*` sizes must use the engine column (an engine 18 / 36 renders at 2.25 / 4.5 phys px per font
  px: uneven pixels).
- **Crisp vs smooth**: `Canvas(w, h)` is crisp (ss=1, drawn 1-bit on the physical grid). Only flat notes,
  roll bodies and the lane use `Canvas(w, h, ss=style.SS)` (supersampled + LANCZOS) and must be written
  with `put(..., smooth=True)` / `add(..., smooth=True)` so the palette scan skips them.
  Chrome and `Canvas.text` refuse a smooth canvas.

## 3. Module contract
```python
NAME = "song_select"                    # --only name; add it to build.py MODULES
OWNS = ["Graphics/song_select/box", "Scripts/song_select/..."]   # wiped + rebuilt by --only
LUA_PATCHES = {"song_select/x.lua": [(old, new), ...]}   # copied from the NEAREST ancestor (Nijiiro first)
def configure(ctx): ...                 # optional
def build(ctx) -> int: ...              # write files, return a count
def skin_config(ctx) -> dict: ...       # optional LOGICAL fragment, deep-merged (Nijiiro's entries are inherited)
```
`ctx`: `G` (out/Graphics), `scripts`, `out`, `lang`, `main_char` ("momo"), `density`, `base` ("nijiiro"),
`nijiiro_g`, `green_g`, `cache`, `here`. Own Lua goes in `lua/<NAME>/<Scripts-relative path>`.
Never write outside your OWNS. Shared helpers belong to core: list them in your report under
"promote to core" (define locally meanwhile).

`ss/smoke.py` (game/lane, game/ai_battle, game/score_counter.lua) only proves the pipeline. **The game
agent takes those paths over and removes `smoke` from MODULES.**

## 4. Replacing ancestor textures: `ss/atlas.py`
```python
from ss.atlas import SubsetWriter, resolve, ref_bbox
from ss.style import Canvas, C, U
from ss import chrome

w = SubsetWriter(ctx.G, "song_select", "box")
g = w.geo("box_bg")          # Geo: source nijiiro|green|nijiiro-pos, frames [(w,h) logical], kind, entry
w.put("box_bg", lambda i, n, ww, hh: chrome.image(ww, hh, chrome.panel))
w.put("cursor", draw, entry={"x": 600, "y": 120})   # optional LOGICAL entry override
w.put_blank("sparkle_overlay")                     # ancestor art with no place in the style
w.write()
```
- Resolution mirrors the engine: nearest ancestor that ships `<key>.png` or `<key>/` wins; its numbers are
  scaled by its scale (Nijiiro 1, Green 1.5) and truncated (`int(v*scale)`), exactly like texture.cpp.
  `nijiiro-pos` = Nijiiro lists the key without an image, so Green's picture is drawn at its RAW size.
- Output layout: one frame -> `<key>.png`; several frames (crop strips, frame folders) -> a `<key>/`
  frame folder (each frame sampled whole: the engine's 1 px crop inset never blurs pixel art). Pass
  `layout="crops"` only if a script reads crop rects itself. "file" overrides are never written (the
  engine would not skip the ancestor's copy).
- `ref_bbox(screen, subset, key, frame)` = LOGICAL alpha bbox of the ancestor's art in its frame, for
  placement only. Never copy ancestor pixels or text images.
- `OwnSubset(ctx.G, screen, subset).add(key, [physical frames], x=logical, y=logical)` for subsets only
  our Lua draws.

## 5. Inventory: the "nothing shows through" checklist
```
python tools/inventory.py --summary            per-subset keys / ours / todo
python tools/inventory.py song_select --todo   keys of your screen we do not replace yet
python tools/inventory.py game/lane            one subset, every key: source, logical size, ref, ours
python tools/inventory.py --json reports/inventory_v2.json
```
`ref` tells whether the key name appears in ancestor Lua or the engine source (`sub/key`, `name`, `-`).
`-` keys may be unused or built dynamically (`self.path .. "/" .. name`): check the Lua before skipping.
Every key that is actually drawn on your screen must end up `ours=yes` (a replacement or `put_blank`).
Then `python tools/verify_geometry.py` checks every shipped key's physical size and positions.

## 6. Core kit APIs
### Canvas (`ss/style.py`)
`Canvas(w, h, bg=None, ss=1)`; `.rect(x0,y0,x1,y1,c)` (x1/y1 exclusive), `.paste(phys_img, x, y)`,
`.text(x, y, s, size, fill, anchor="mm", outline=0, outline_fill=None, max_w=None)` (anchor = PIL-like
`l|m|r` + `t|m|b|s`; `outline` logical, a square 1-bit ring, 1U = 3), `.text_width(s, size)` (logical),
`.result()` -> physical image. Smooth path also has circle/ring/rrect/poly/line/arc/pieslice.
Palette `C[token]` / `P` (hex). New in v2: `cloud2 grass grass2 wood wood2` (scene).
`style.px(v)` logical -> phys, `style.snap(v)`, `style.blank_l(w, h)` (transparent frame).

### Chrome (`ss/chrome.py`, bible 2.2)
| call | spec (logical) |
|---|---|
| `dialog(cv, x0,y0,x1,y1, title=None)` | 2U border, 2U shadow, 1U notch, paper; title band 16U gold + 1U rule, 36 px title |
| `panel(cv, ..., fill=None, plate_text=None, plate_accent=None)` | 1U / 1U / 1U; optional plate docked on the top-left corner |
| `plate(cv, ..., text, accent, size=36, icon=None)` | 18U (54) tall; 18U accent icon cell + 1U divider; ink text |
| `button(cv, ..., text, state="normal"|"focused"|"pressed")` | bg2; focused 2U border + gold; pressed: no shadow, +1U |
| `chip(cv, x0, y0, x1, y1=None, text, accent, edge=False)` | 9U (27) tall, 1U border, no shadow/notch; edge=True: bg3 + 1U accent left edge |
| `pixbar(cv, ..., frac, fill, groove=None, segs=0)` | 1U ink frame, fill snapped to U, 1U dividers on U columns |
| `bubble(cv, ..., tail_x, tail_dir="down", text, size=36, tail="small")` | dialog without title + a tail; width `bubble_width(text)` <= 540. `tail="steps"`: the readable 3-step tail (18U / 12U / 6U steps, 3U tall, 2U ink sides; `chrome.bubble_tail`, promoted from v2_front) that sits `BUBBLE_TAIL_H` = 13U (39) past the box edge: use it for every 36 px bubble (invite, entry, stage). `tail="small"` (default, old 6U/4U/2U tail overlapping the box edge) only in tight frames; `tail=None` none. `bubble_image(text, tail_x=None, size=36, h=78)` = a whole steps bubble as an image (`bw + 2U` x `h + 39`) |
| `cursor(cv, x, cy)` | the ▶ (5x9 cells, ink ring, gold) |
| `frame(...)` | the primitive behind all of them |
| `image(w, h, fn, ...)` | a whole-frame chrome image for a SubsetWriter callback |
Every call returns a `Box` (outer + inner content rect, `.cx/.cy`). Coordinates are the OUTER border
edge; the shadow falls outside (leave room down-right). Example:
```python
cv = Canvas(w, h)
b = chrome.panel(cv, 0, 0, 450, 270, plate_text="リザルト", plate_accent=C["p1"])
chrome.chip(cv, b.ix0 + 6 * U, b.iy0 + 6 * U, b.ix0 + 54 * U, None, "良", accent=C["clear"], edge=True)
```
Lua mirror for dynamic sizes: `UI.frame`, `UI.chrome.dialog/panel/button/chip`, `UI.pixbar`, `UI.notched`.

### Deco (`ss/deco.py`, bible 2.4)
`cloud(cv, x, y, "S"|"M")` (only in the sky band, 2-3 per screen), `sky(cv, x0, y0, x1, y1)` (sky + the 2-row
horizon checker), `horizon_dither`, `ground(cv, x0, y, x1, y1)` (characters stand on `y`),
`taiko(cv, cx, foot)` and `lanterns(cv, x0, x1, y, n)` (the festival props: scene screens only, on the
ground / horizon line), `sparkle_burst(cv, cx, cy, frame)` / `sparkle_frames()` (events only, never static;
in Lua `UI.burst(cx, cy, ms_since_event)`), `pixdisc(cv, cx, cy, r, fill, inner_ring=(C["clear"], 1))`,
`pixtext(cv, x, y, "GAME OVER", cell=2*U, fill=C["don"], shadow=U)` (5x7 block letters),
`cells(cv, x, y, rows, pal, cell, outline=C["ink"])` for your own small pixel icons (8x8 cells at k=3).

### Mascots (`ss/mascot.py`, `ss/pixel.py`)
Frames (`pixel.EXPR`): `idle idle1 blink blink_half good combo sad gogo clear fail drum_l drum_r cheer turn sit_fail`
(`turn` faces right; mirror for left). Momo = main / 1P, Hoshi = buddy / 2P.
- Baked: `mascot.sprite(char, expr, k, mirror=False)` (physical), `mascot.sized(char, expr, k, w, h)`
  (centred on a tile, ground row on the bottom edge), `mascot.paste(cv, char, expr, k, cx, foot)`.
  `k` is a role name (`"tiny" | "menu" | "portrait" | "scene"`, preferred) or a raw k; `mascot.k_of(role)`.
  The ground row is `pixel.FOOT[char]` (momo 33, hoshi 34): use paste/sized, never compute it yourself.
- Lua:
```lua
local UI = require("global.ss_ui")
-- in new(): UI.reset()
self.momo = UI.Mascot.new({ role = "menu" })
self.hoshi = UI.Mascot.new({ char = "hoshi", role = "menu", beat = false })
-- every frame:
self.momo:update(ms, bpm, beat0_ms)          -- bpm/beat0 only for the beat hop
self.momo:draw(cx, ground_y)                 -- integer scale (baked k), floored position
-- draw opts: expr, role (one-off size), still, mirror, fade (snapped by UI.solid: shown or hidden)
-- events (bible 2.6): react("hit"|"don"|"ka") drum_l/r alternate, react("combo") cheer,
-- react("miss") sad, react("gogo")/react("gogo_end"), react("clear"), react("fail") sit_fail,
-- menus: react("move") 1-px hop, react("decide") cheer + hop, react("turn", -1|0|1), react("reset")
```
Built in: 2-frame breathe (500 ms), randomised blink (half-lid 60 ms, closed 60 ms, every 3000-4200 ms,
never together), beat hop exactly 1 sprite px for 100 ms (2 on the GOGO downbeat), no squash, no
rotation. Textures: `global/ss_mascot_k3|k6|k9/{momo,hoshi}`: every one of the 15 frames is baked for
both characters at every k (90 PNGs), so any role / frame combination draws at scale 1.
`sit_fail` is the seated pose (head 3 rows lower, paws on the knees, soles forward): it reads at k=9.
Momo's `sad` / `fail` / `sit_fail` keep her TALL ears, laid back ~40 deg outward (never the round sideways
ear pair: that read as a bear). The ears are her silhouette in every frame; Hoshi's round hood ears are his.

### Hint pill (`UI.hint`, `chrome.hint`): one style, one place
An ink bar 12U (36) tall (bible 8U at 1280), notched, 1U ink shadow; per item `[drum 24] 2U [18 px paper
label]`, 6U between items, 4U padding. The drum is the one 8x8-cell k=3 sprite with 2 states:
`"don"` = face lit red, `"ka"` = rim lit blue (`global/ss_ui/hint_drum` frames 0 / 1).
**Position rule: bottom-centre footer** (fix1029; this replaces the old bottom-right rule). The bar is
centred on `D.HINT.cx = 960` (the screen centre) with its bottom edge on `D.HINT.y1 = 1020`: above the
bottom band where the engine prints the credit line (y ~1046) and the network icon (1868..1908, 1028..1068),
12 px above the usual ground line 1032, and between the 1P / 2P nameplates (x 14..420 / 1494..1900), so it is
the same spot with one or two players. Keep that zone (about x 780..1140, y 981..1023: the widest pill, settings'
three items, is ~330 wide) free of mascots, boards and plates on every screen that shows a hint; a screen with
a different ground passes `y1` (or `cx`), nothing else. `x1` still anchors the right edge, for old callers only.
```lua
UI.hint({ { "ka", "h_select" }, { "don", "h_decide" } })               -- えらぶ / 決定 / Select / Decide ...
UI.hint({ { "don", "h_decide" }, { nil, "h_esc_back" } }, { vis = a })  -- string KEYS (ss/strings.py)
-- labels: string keys (h_select h_decide h_back h_option h_change h_start h_esc_back, or any ss/strings.py
-- key), drawn as engine text 18 px paper in the PLAYER'S language (UI.t); the bar sizes itself to the
-- measured labels. A label that is not a key is drawn as written. opts: cx (centre, default 960), y1
-- (bottom edge, default 1020), x1 (legacy right anchor), vis (alpha, snapped). Returns x, y, w, h of the
-- bar. UI.hint_width(items) to reserve space.
```
**One pill per screen.** `UI.hint` keeps its last draw per anchor: a second draw at the same anchor in the
same frame logs `[ss_ui] warning: UI.hint drawn twice at (cx=960,1020) in one frame on <screen>: [..] then [..]`
once. A baked pill (`chrome.hint`) plus a Lua pill is not caught by the guard: never do both on one screen.
Python (screens that are fully baked, e.g. the engine-drawn settings footer; baked = one language, so
prefer the Lua pill; see §11):
`chrome.hint(cv, [("ka", "えらぶ"), ("don", "決定"), (None, "ESC もどる")], cx=chrome.HINT_CX, y1=chrome.HINT_Y1)`,
`chrome.hint_width(items)`, `chrome.hint_drum(cv, x, y, "don"|"ka")`.

### Course identity (`ss/course.py`, `UI.course`)
One rendering of a course, a crown and a score rank on every screen. Course = engine index 0..4 or
`"easy" | "normal" | "hard" | "oni" | "ura"`.
| thing | Python | Lua (baked `global/ss_course`) |
|---|---|---|
| glyph (8x8 cells + ink outline) | `course.glyph(cv, cx, cy, c, cell=U)` (30) / `cell=2*U` (60); `glyph_image` | `UI.course.glyph(c, cx, cy, "s"\|"l")` |
| course chip (edge style: bg3, 1U course edge, 18 px ink name, 126x27) | `course.chip(cv, x0, y0, None, c)`; `chip_image` | `UI.course.chip(c, x, y)` |
| course plate (course-colour icon cell WITH the glyph) | `course.plate(cv, x0, y0, x1, c)`, or `chrome.plate(..., icon=course.plate_icon(c))` | (bake it) |
| crown: `none` (nothing), `clear` (course colour), `fc` (gold, paper jewels), `dfc` / all-good / 全良 (gold, ink jewels) | `course.crown(cv, x, y, kind, c, cell=U)`; `crown_image(kind, c, cell)`; `crown_size(cell)` | `UI.course.crown(kind, c, cx, cy, "s"\|"m")` (33x21 / 66x42); kind may be 0..3 |
| 全良 chip (gold fill, 1U ink border, 18 px ink 全良; 72x27, en 126x27): goes with the `dfc` crown wherever there is room | `course.zenryo_chip(cv, x0, y0)`; `zenryo_image()`; `ZENRYO_W` / `zenryo_w(lang)` | `UI.course.zenryo(x, y)` (top-left; returns w, h; `D.COURSE.zenryo`) |
| score rank tier 0..6 = 粋 粋 粋 雅 雅 雅 極 (Nijiiro score_rank frames) | `course.rank_badge(tier, r_cells=11, size=36)` (75) / `(tier, 21, 48)` (135); `rank_paste(cv, ...)` | `UI.course.rank(tier, cx, cy, "s"\|"l")` |
**Bible 2.3 (round 3): the rainbow is never on a crown.** It appears in exactly two places: the soul gauge's
full state and the 極 rank ring. All-good is told apart from full combo by the ink jewels and the 全良 chip.
Also `course.KEYS`, `course.name(c, lang)`, `course.colour(c)`, `course.RAINBOW6` (the one rainbow, = the
soul gauge's 6 blocks), `UI.course.color(c)`, `UI.course.name(c)`, `D.COURSE` (sizes, frame map).
The result rank language is the select screen's 粋/雅/極 (no C..SSS letters anywhere).

### Alpha policy (core rule)
**Pixel textures are drawn at alpha 1 or not at all.** A half-alpha pixel is a blend, i.e. an off-palette
colour on screen (the critic's course-select fade, settings arrows, dan cursor, option markers, GOGO fire,
dan dim). Fades become steps:
- `UI.solid(a)` -> 1 or 0 (threshold 0.5; `a` in 0..1, or 0..255 when > 1). Use it on every `fade =` and
  every colour alpha you hand to `tex.draw_texture` / `t:draw`. `UI.tex(t, params)` does it for you (and
  skips the draw at 0). `Mascot:draw` and `UI.hint` / `UI.draw_text` already snap.
- Screen-level fades / dims: `UI.wipe(level, color, y0, y1)` (checker dither, level 0..4; texture
  `global/ss_ui/wipe`), timed with `UI.wipe_in(t, step)` / `UI.wipe_out(t, step)` (1, 2, 3 then solid; 50 ms
  per step), or `UI.dither(a)` to turn an engine fade value into a level. Never a translucent full-screen rect.
- Window opens: `UI.open_rect(x, y, w, h, since_ms)` (3 frames, 33 / 66 / 100 % height, 50 ms each).
- `UI.rect(..., a)` / `UI.frame{a=}` with a < 255 is only for non-pixel overlays you can defend in the report.
**Patching engine / Nijiiro alphas** (LUA_PATCHES on the ancestor script):
1. Lua-side fades: wrap the value, `fade = x` -> `fade = UI.solid(x)` (add `local UI = require("global.ss_ui")`
   at the top of the patched file). For clip / sampler alphas (`get(..., "a")`, `.attribute`) snap the
   value the same way before it reaches `draw_texture`.
2. A fade that is the whole screen (dims, cross-fades between screens): replace it with `UI.wipe(UI.dither(a), ...)`.
3. C++-drawn fades with no Lua hook (e.g. the settings `blue_arrow`): bake the texture so any alpha still
   reads (solid paler token art), or blank it (`put_blank`) and draw your own from Lua at alpha 1.
4. Text: `t:draw{ fade = UI.solid(a) }`.

### Engine text (`UI.text`): ink outline, never #000000
```lua
local t = UI.text("合格", 36, "paper")   -- paper + 1U ink outline (on saturated fills, sky, scene)
UI.draw_text(t, cx, cy, "c", vis)        -- whole px, y = centre, align l|c|r, vis snapped
UI.text(s, 24)            -- "ink" (default): ink, no outline (on paper / cream / chips)
UI.text(s, 18, "on_ink")  -- paper, no outline (on ink bars)
UI.text(s, 24, { color = D.P.gold_t, outline = false })
```
Sizes are ROLE sizes 18 / 24 / 36 / 48 (the same numbers as baked text; others warn once); UI.text creates
them at the engine size 24 / 32 / 48 / 64 so they match baked text pixel for pixel. Cached per string /
size / style. The outline colour is
always `D.P.ink` and the thickness always explicit (`create_raw_text` defaults to 5 px when omitted).
Never call `text.create_raw_text(..., {0,0,0,255}, ...)` or `text.create_text` with a black outline
yourself. C++-drawn text whose outline colour is fixed black (game song title / subtitle, `song_info.cpp`):
set its skin_config `"outline": 0` and put a paper `chip` / `plate` behind it.

### Digits and labels (Lua)
`UI.num(str, x, y_center, "s"|"m"|"l"|"xl", color, a, align)` (18/24/36/48, tabular; digits stay baked).
`UI.label(key, x, y_center, color, a, align)` (18 px, tinted `color`): now engine text in the player's
language when `ss/strings.py` has the key (the old `ss/ui.py LABELS` keys all do); the baked frame is the
fallback. `UI.label(key, role_size, style)` (third argument not a number) returns the text object instead.
See §11.

## 7. Palette scan and contrast
Every build scans every PNG it wrote: a visible pixel whose RGB is not a palette token (or a mascot
sprite colour) fails the build. Smooth files are skipped. Fix the colour, or ask core for a token.
`python -m ss.tokens --scan <dir>` scans any folder. The contrast table (`ss/tokens.py CONTRAST_PAIRS`)
still runs first; add a row for every new text pair.
Translucent fills: avoid `alpha(...)` on crisp art (the PNG pixel would be a palette colour at partial
alpha, i.e. a blend on screen); use solid palette colours or a dither. The same holds at draw time: see
the alpha policy (§6).

## 8. Build, install, capture
```
python build.py --only core,<you>          # --density 2 default; --mockups redraws mockups/v2_*.png
python tools/verify_geometry.py
tools/mk_testdir_v2.sh <name>              # test_ss_<name>: engine copied from Z-DON build/bin (has texture_density)
T=/d/YataiDON_agents/test_ss_<name> ./run_cap.sh caps/<you>/<scenario> <scenario>
```
- `REFRESH_EXE=1 tools/mk_testdir_v2.sh <name>` takes a newer engine build. Reference: `test_ss_nj`
  (Nijiiro at 1080p) with the same scenario; `tools/mk_testdir_v2.sh <name>_nj YataiDONNijiiro`.
- Dumps are 3840x2160 at density 2. Inspect at full resolution (crop + zoom), not only contact sheets.
- `run_cap.sh` refuses to start while `tasklist | grep -i yataidon` shows anything: it may be the user's
  game or another agent's capture. Wait; never kill it. Hidden runs only, no OS input.
- Scenarios, keys and logs: see `SCREEN_GUIDE.md` (unchanged).
  Round 3 review harness: `roll` = `C:/zdtest/charts/longroll/longroll.tja` (Oni; real long rolls, the
  counter climbs); `result_reveal` = the result reveal every 100 ms (frames 6800..7600 step 5);
  `danplay` / `danresult` default to the PASSING course `danc/pass` (三段 -> 合格 under auto; `danc/gold` 名人
  -> 金合格; `danc/1` 五級 fails), from `$T/Songs/danc` or else `test_ss_v2result/Songs/danc`; `DAN=` overrides.

## 9. Rules from the bible (checklist before you report)
- one grid: chrome on U, mascots at k 3/6/9, text 18/24/36/48; nothing LANCZOS-scaled except notes/lane
- one chrome system (`chrome.*`): no module-local windows, clouds, sparkles, discs or pixel fonts
- max 3 accents per screen (2.3 table); rainbow only as 6 blocks on the soul gauge full state and the 極
  rank ring; never on the result crown (全良 = gold crown + 全良 chip)
- no static sparkles; clouds only in the sky band; props only on the ground line of scene screens
- mascots stand on something, fully visible, next to what they act on; never corner filler; never
  floating-scaled in Lua
- baked text: ink on paper, or paper on a saturated fill with a 1U ink outline; engine text gets an ink
  1U outline via skin_config
- original art only; no Nijiiro / Green pixels or text images; no AI image generation
- notes and lane stay flat (smooth) with the ink outline + paper rim
- mascot k by role (`role =`), no raw k; one hint pill (`UI.hint`, bottom-centre footer); one course
  identity (`course.*` / `UI.course.*`); pixel art at alpha 1 or not at all; engine text via `UI.text`
- Don't touch Z-DON source, other skins, or the user's config; never `cd` into `out/` or `Skins/`

## 10. Migration checklist for modules (core v2 fix, `reports/core_v2_fix.md`)
Core keeps your local copies building; migrate in your next pass and delete the local copy in the same
change. Grep your files for each left-hand pattern.
| find in your module | replace with |
|---|---|
| `UI.Mascot.new({ ... k = N ... })`, `k = D.MASCOT.k.*`, `opts.k` | `role = "tiny" \| "menu" \| "portrait" \| "scene"` (see §2 for which). Fixes: song select 3 -> menu, stage 1P Momo scene / Hoshi menu, 2P / dan both menu |
| `mascot.paste(cv, ch, e, 6, ...)` | `mascot.paste(cv, ch, e, "menu", ...)` |
| own hint pills / drum icons (`guide_panel.lua` PILL_*, `ss_meta/drum`, v2_song_select `guide_pill` / `drum_icon`, the v2_front settings footer pill) | `UI.hint(items)` (Lua) or `chrome.hint(cv, items)` (baked), bottom-centre footer |
| `COURSE_GLYPH`, `GLYPH_PAL`, local `crown()` / `CROWN`, `RANKS` + `rank_badge()`, `medal()` + `RANK_TEXT`, `COURSE_JA`, course chips / plates | `course.glyph / chip / plate / plate_icon / crown / rank_badge`, `course.name`, `course.RAINBOW6`; Lua `UI.course.*` |
| `fade = <expr>` on pixel textures, `{r,g,b,a<255}` colours on sprites, `UI.rect(..., a)` dims | `UI.solid(<expr>)` / `UI.tex(t, p)`; dims and screen fades -> `UI.wipe` + `UI.wipe_in/out`; opens -> `UI.open_rect` |
| `SSM.wipe`, `SSM.level_in/out`, `SSM.open_rect` (meta) | `UI.wipe`, `UI.wipe_in/out`, `UI.open_rect` (same semantics; texture `global/ss_ui/wipe`) |
| `text.create_raw_text(s, n, c, {0,0,0,255}, ...)`, `SSM.text`, local text caches | `UI.text(s, n, style)` + `UI.draw_text(t, x, y, align, vis)` |
| a text size outside 18/24/36/48 (`38 * S`, `20 * S`, `16 * S`, `26 * S` ...) | the role size (§2) via `UI.text` |
| `skin_config` `font_size` 18 / 24 / 36 / 48 (and Nijiiro's inherited 22 / 26 / 32 ...) | the engine size 24 / 32 / 48 / 64 for that role (`style.ENGINE_TEXT[role]`) |

Per module (from `reports/v2_review.md` §3):
- **v2_meta**: rewrite `Scripts/global/guide_panel.lua` as a thin wrapper:
  `GuidePanel:draw(loop, x, y, fade)` -> `UI.hint(loop == ALL and {{"ka","h_select"},{"don","h_decide"}} or
  {{"don","h_decide"}}, { vis = fade })` (Nijiiro's callers pass 0, 0; ignore x / y), drop `ss_meta/drum` and
  `PILL_*`. Move `M.wipe / level_in / level_out / open_rect` callers to `UI.*`, delete the `ss_meta/wipe` masks.
  Dan select Momo: `role = "menu"`. Use `UI.wipe` for the dan-result dim; `UI.solid` on `dan_cursor` /
  `dan_arrow` clip alphas; dan select course chips: `course.chip` (no 鬼 kanji chip).
- **v2_front**: settings footer: `chrome.hint(cv, [("ka", "えらぶ"), ("don", "決定"), (None, "ESC もどる")])` at
  the footer rule (delete the local pill + disc drums); entry / title: `role = "scene"`, warning screen
  `role = "menu"`; settings arrows per the alpha policy (C++ fade: bake solid or blank).
- **v2_song_select**: course select paper pill: `put_tiny` `diff_tower` / `star_select_text`, remove the
  Lua label draws (LUA_PATCHES) and call `UI.hint({{"ka","h_select"},{"don","h_decide"}})` from `ss_sel.lua`
  while the course select is open; mascots `role = "menu"` standing clear of the hint zone; replace local
  `COURSE_GLYPH` / `crown` / `RANKS` / `rank_badge` with `course.*`; patch the board / 1P marker / option
  focus alphas with `UI.solid` (and the 3-frame open with `UI.open_rect`).
- **v2_result**: course plate -> `course.plate(...)` (glyph in the icon cell); medal C..SSS -> `course.rank_badge(tier, 21, 48)`;
  crowns -> `course.crown`; mascots `role = "scene"`.
- **v2_game**: `rank_badge` / `RANKS` / `RAINBOW6` -> `course.rank_badge` / `course.RANKS` / `course.RAINBOW6`;
  portrait `role = "portrait"`; course chip -> `course.chip`; song title per the engine-text rule; GOGO
  fire / lane flash per the alpha policy; text sizes `38 * S` etc. -> 18/24/36/48.
- **v2_stage**: 1P Momo `role = "scene"`, Hoshi `role = "menu"`; 2P / dan both `role = "menu"`.

## 11. Dynamic text (every fixed word in the player's language)
Rule: **no words baked into a PNG** unless the texture is brand art or the engine leaves no other way.
Text is drawn at run time as engine text (Fusion Pixel, rasterised at the physical size, crisp at 4K) in
the player's language: `ja`, `en`, `zh` (Simplified), `ko`. Digits / digit fonts stay baked (`UI.num`).
Core report: `reports/core_dynamic_text.md`. Checklist per module: `reports/baked_text_inventory.md`
(regenerate with `python tools/baked_text.py` after every migration pass; your rows should disappear).

### Strings: `ss/strings.py`
One table, `key -> {ja, en, zh, ko}`, written into our `text_config.json` as `ss_<key>` (merged by
`v2_standalone.build_text_config`: one output file). The build fails on a missing language
(`strings.check()`). Add your strings there (never a Lua table of translations, never `if lang == "ja"`).
Game terms: 良/可/不可 = GOOD/OK/BAD = 良/可/不可 = 양/가/불가; 連打 = Roll / 连打 / 연타; コンボ = Combo /
连击 / 콤보; 魂ゲージ = Soul Gauge / 魂槽 / 혼 게이지; courses Easy Normal Hard Oni Ura / 简单 普通 困难 魔王
里魔王 / 쉬움 보통 어려움 오니 오니(우라). `wide=True` marks strings whose en / ko are much wider than the ja
box: size that chrome from the measured text. Formats use `{0}`: `UI.t("retry_rule", n)`.
Python build-time lookup (per-language baked variants only): `strings.get(key, lang)`.

### Lua API (`global.ss_ui`)
| call | what |
|---|---|
| `UI.t(key, ...)` | the string in the player's language (`ss_<key>`, then the bare engine / Nijiiro key), fallback ja -> en; `{0}`.. replaced by the extra args; nil if unknown |
| `UI.lang()` | `tex.language()` |
| `UI.text_key(key, size, style, ...)` | cached OutlinedText of `UI.t(key)` (missing key: draws the key, warns once) |
| `UI.label(key, size, style)` | same as `text_key` (third argument not a number) |
| `UI.label(key, x, y, color, a, align)` | draw form (18 px, tinted); returns the width |
| `UI.text(s, size, style)` | raw string (unchanged): `"ink"` (on paper / chips), `"paper"` (paper + 1U ink outline: on saturated fills, sky, scene), `"on_ink"` (paper on ink bars), or `{ color = D.P.<token>, outline = bool }` |
| `UI.draw_text(t, x, y_center, align, vis)` | whole px, vis snapped; returns the box width |
| `UI.text_width(s, size, style)` / `UI.label_width(key, size, style)` | ink advance width = Python `Canvas.text_width` (the box is this + 2 x `UI.text_pad(t)`): size chrome from it |
| `UI.hint(items, opts)` | the hint pill, labels are string keys (reference implementation, §6) |
| `UI.bubble(s_or_key, tip_x, tip_y, opts)` | speech bubble sized to the measured text, 3-step tail tip at the speaker's mouth; `opts.dir "down"\|"up"`, `cx`, `size` (36; drops to 24 above 540 px), `h`, `vis`, `args`; returns the box; `UI.bubble_width(s, size)` |
| `UI.course.name(c)` | the course name via `UI.t("course"..i)` |
Text objects are cached per (string, size, colour, outline): calling these every frame allocates nothing
after the first frame (a language change creates the new strings once).
Sizes are role sizes 18 / 24 / 36 / 48 only (engine 24 / 32 / 48 / 64, whole font pixels). Colours are
palette tokens; the outline is always ink, exactly 1U (`D.TEXT_OUTLINE` = 2 engine units: the engine
multiplies by screen_scale 1.5).

### Migration per case (see the `drawn by` column of the inventory)
1. **LUA (our script draws the texture)**: draw the chrome without words (keep the plate / chip / panel),
   then the text with `UI.label` / `UI.text_key` at run time; size the chrome from `UI.label_width` when
   the string is `wide`. Delete the `cv.text(...)` from the generator in the same change.
   - Whole-texture text (stamps, banners, dialogs): `put_blank` / drop the key, draw chrome with
     `UI.frame` / `UI.chrome.*` and the text with `UI.text_key`.
   - Speech lines (Hoshi `say_*`, result `res_bub_*`, title invite): replace the baked bubble frames with
     `UI.bubble("say_combo_100_1", mouth_x, mouth_y)`.
   - Hint pills: `UI.hint` with keys only (done in core; `guide_panel.lua` uses `h_esc_back`).
   - Alternative when run-time drawing is impractical (animation clip frames): bake `<key>_ja/_en/_zh/_ko`
     (`strings.get(key, lang)`); every Lua `tex.get_texture` tries `<key>_<lang>`, `_ja`, `_en`, `<key>`.
     Always ship `_ja` too (for ja the order is `_ja`, `_en`, base).
2. **ENGINE+LANG (C++ asks for `<prefix>_<lang>`, e.g. `lane/auto_icon_`)**: bake one variant per language
   with `strings.get(key, lang)`. Never put Japanese into an `_en` / `_ko` variant (the inventory flags
   them as WRONG: `combo_en`, `auto_icon_en`, `skip/text_en|zh`).
3. **ENGINE (C++ draws a fixed name: notes/moji, judge_*, branch/*, practice/*, balloon / roll bubbles,
   kidou/warning, settings background, confirm_box, loading_dan/plaque)**: the engine does NOT look up
   `_<lang>` variants for these names. In order of preference:
   a. language-neutral art (icon, symbol, colour) where the meaning survives without a word;
   b. `put_blank` the texture and draw the word from Lua where a Lua hook runs on that screen;
   c. keep it baked in Japanese (the game's own terms) and list it in your report as an open item: an
      engine change (texture_fallback trying `<name>_<lang>` first) would make variants work; ask core.
4. **Lua literals** (`UI.text("おつかれさま！", 36)`): replace with `UI.text_key("go_title", 36)`.
5. **DECISION** (YATAI DON wordmark, GAME OVER block letters, 粋 / 雅 / 極 rank marks, the name-entry kana
   table): keep baked unless the owner decides otherwise.
Then `python build.py --only core,<you>`, `python tools/baked_text.py`, and capture your screen in two
languages: `T=/d/YataiDON_agents/test_ss_lang_ja` and `test_ss_lang_ko` (also `_en`, `_zh`).
