> **v2 (2026-10-29): the module contract, units, grid and core APIs changed. Read `SCREEN_GUIDE_V2.md` first;**
> this file is kept for the capture scenarios, keys and log notes only.

# SimpleStyle: how to add or restyle a screen

This guide is for agents working on one screen of YataiDONSimpleStyle, possibly in parallel with others.
Read these first:
- `STYLE_GUIDE.md`: the direction, tokens, spacing, motion and typography rules.
- `mockups/mascot_concepts.png`: the mascot.

## Layout
```
D:/YataiDON_agents/simplestyle/
  build.py            module registry (MODULES), --only, contrast check, skin_config assembly
  ss/style.py         palette P (primitive tokens), Canvas (4x supersampled PIL drawing), fonts
  ss/tokens.py        semantic + component tokens, CONTRAST_PAIRS, the contrast check
  ss/atlas.py         SubsetWriter (replace Green keys 1:1), OwnSubset (new subsets for our Lua)
  ss/mascot.py        the mascot (Tick = concept A); compose(concept, expr) -> 256x256 RGBA
  ss/ui.py            shared Lua-facing textures (global/ss_ui digits+labels, global/ss_mascot) + ss_def.lua
  ss/core.py          module "core": fonts, ss_ui/ss_mascot, skin_config base
  ss/game.py          module "game": Graphics/game, background.lua, patched score_counter.lua
  ss/song_select.py   module "song_select"
  ss/<screen>.py      one module per screen (add yours here)
  lua/<module>/...    our own Lua, mirrored into Scripts/ (e.g. lua/game/background/background.lua)
  run_cap.sh          hidden capture of one scenario      tools/cap_all.sh   several + contact sheets
  tools/mk_testdir.sh private test install                tools/contact.py   contact sheet of a folder
out/YataiDONSimpleStyle   the built skin (test installs have a junction to it)
```

## Module contract (`ss/<name>.py`)
```python
NAME = "result"                                   # also the --only name; add it to build.py MODULES
OWNS = ["Graphics/result", "Scripts/result"]      # paths under out/ that this module wipes + rebuilds
LUA_PATCHES = {"result/result_player.lua": [(old, new), ...]}   # optional, see below
def configure(ctx): ...                           # optional: read ctx.lang / ctx.mascot into globals
def build(ctx) -> int: ...                        # write files, return a count
def skin_config(ctx) -> dict: ...                 # optional fragment, deep-merged into skin_config.json
```
- **`ctx` fields:**
  - `ctx.G` = out/Graphics, `ctx.scripts` = out/Scripts, `ctx.out`
  - `ctx.lang` ("ja" default | "en"), `ctx.mascot` ("A" | "B" | "C")
  - `ctx.green_g` (Green Graphics), `ctx.green_scripts`, `ctx.cache`, `ctx.here`
- **Own only your screen.** Never write outside your `OWNS`. A shared texture or helper belongs in `ss/style.py` / `ss/ui.py` / `ss/mascot.py`, and those are owned by `core`. If another agent may be editing them, write a note instead of editing.
- **Your own Lua** goes in `lua/<NAME>/<Scripts-relative path>`. It is copied after `build()` runs.
- **`LUA_PATCHES`:** copies the parent script and applies exact string replacements. The build fails if a target is missing.
  - Use this for small changes, such as removing Green art or recording state.
  - Keep Green's Lua and layout. Rewrite Lua only when Green-specific art cannot be removed otherwise.
- **Building:**
  - `python build.py --only <yours>` rebuilds only your owned paths, plus `Graphics/skin_config.json`, which is always regenerated from all fragments.
  - A full `python build.py` wipes and rebuilds everything. Do not run it while others are working.
  - `--mockups` also redraws `mockups/*.png`.
- **The contrast check runs on every build.** Add a `CONTRAST_PAIRS` row in `ss/tokens.py` for every new foreground/background text pair you introduce. Use semantic token names, and add component tokens to `COMPONENT`. Thresholds: text 4.5, large 3.0, ui 3.0.

## Replacing Green textures
- **`SubsetWriter(ctx.G, screen, subset)`** reads only the geometry of Green's `texture.json`: canvas size, crops, frame folders.
  - `w.put(key, draw)` writes your frame(s) with the same size and layout. `draw(i, n, w, h)` returns an RGBA image of exactly (w, h).
  - `w.put_blank(key)` blanks a key, for Green art that has no place in the style.
  - `w.write()` writes a child `texture.json` containing just your keys. The engine merges per key and everything else falls back to Green.
  - To change an entry (x/y), pass `entry=`.
- **Text images** are drawn with `Canvas.text()` (Noto Sans JP; `max_w=` shrinks to fit).
  - The base key (`foo.png`) is Japanese. Where Green has `foo_en.png`, also write the `_en` key in English. The engine looks for `_<lang>`, then `_ja`, then `_en`.
  - Other languages (zh/ko/…) fall back to these. Text that Green draws from `skin_config.json` text entries uses our fonts automatically.
- **Look before you draw.** Run `python tools/sheet.py <screen>/<subset> out.png` (a Green subset contact sheet), then read Green's Lua for that screen. A texture can be used as a mask, tinted (`color`) or scaled by the Lua.
- **Never copy pixels or text images from Green or any game.** `ref_bbox` (where Green's shape sits in its frame) is allowed for placement only.
- **No AI image generation.** Everything is drawn by code.

## Mascot on other screens
- **In Lua:**
  ```lua
  local UI = require("global.ss_ui")
  local m = UI.Mascot.new()
  ```
  - Every frame, call `m:update(ms, bpm)`, then `m:draw(cx, foot_y, scale, {expr=..., still=..., fade=...})`.
  - `expr` is one of: `idle blink good combo sad gogo clear fail`.
  - Textures are `global/ss_mascot/{body,part}` (8 frames each), loaded on demand.
  - After a screen change, call `UI.reset()` in the screen's `new()`: texture handles are per screen.
- **As a static texture** (when Green's Lua draws a fixed texture and you don't want to touch the Lua): use `mascot.compose("A", expr)` (256×256), scaled into the frame with `Canvas`.
- **Where Green shows a character:**
  - 3D Don (title attract, entry drum, dan select, result, dan result): already disabled by `disable_chara_3d`. Put the mascot where the character stood, if a Lua hook exists there.
  - 2D chara textures (result `bottom_characters`, game over, entry, …): replace them with mascot frames or blank them.

## Shared Lua helpers (`Scripts/global/ss_ui.lua`)
- **Colours:** `UI.P.<token>` is an RGB triple from the palette; `UI.rgba(c, a)`, `UI.mix(a, b, t)`.
- **Shapes:** `UI.rect`, `UI.rrect(x, y, w, h, radius_px, c, a, line_w, line_c)`, `UI.circle`, `UI.ring`.
- **Tabular digits:** `UI.num(str, x, y_center, "s"|"m"|"l", color, alpha, "l"|"r"|"c")` returns the width.
- **Labels:** `UI.label(key, x, y_center, color, alpha, align, scale)`. Keys are defined in `ss/ui.py` `LABELS`; add yours there (owned by core: coordinate).
- **Dynamic text:** `text.create_raw_text(str, size, rgba, outline_rgba, vertical, thickness, spacing)` returns an object with `:draw{ x, y, scale }`, `.width` and `.height`. Create it once, not every frame.

## Capturing a screen (hidden, deterministic, no OS input)
- **Check first.** Run `tasklist | grep -i yataidon`. If anything is running, wait: it may be the user's game. `run_cap.sh` refuses to start in that case.
- **Run a scenario:** `./run_cap.sh <outdir> <scenario> [VAR=value ...]`. What it does:
  - `YATAIDON_TEST=1`: the window is never shown.
  - `YATAIDON_FIXED_STEP_MS=20`: hook times are **frame numbers**.
  - `YATAIDON_DUMP_FRAMES`: dumps PNGs.
  - `YATAIDON_JUMP_SCREEN`: jumps into menus the CLI cannot start.
  - `YATAIDON_FAKE_KEYS="<frame>:<raylib key>"`: key presses through the game's own input queue.
  - The game quits after the last dumped frame. The log is copied to `<outdir>/latest.log`, and `[error]`/`[warning]` lines are printed.
- **Keys** (test config, 1P):
  - J=74 / F=70: don (confirm)
  - K=75: right ka (next)
  - D=68: left ka (previous)
  - ESC=256, ENTER=257, F1=290 (restart), SPACE=32 (pause)
- **Scenarios** (defaults in `run_cap.sh`; override with `FRAMES=`, `KEYS=`, `DIFF=`):

  | scenario | how | notes |
  |---|---|---|
  | `title` | cold start, frames 20..1500 | warning, attract video, logo, notice, news |
  | `entry` | `JUMP=entry;10` | add `KEYS` (J) to get past the first prompt |
  | `song_select` | `JUMP=song_select;10`, K K J K D | opens inside `Songs/test` (2 songs); frame 290+ = difficulty select |
  | `diff_select` | J at 150, then K×5, D | the cursor starts on 戻る; never confirm a course (that starts the song) |
  | `dan_select` | `JUMP=dan_select;10` | **no dan courses in the test songs**: the screen is empty (see below) |
  | `settings` | `JUMP=settings;10`, K K J | |
  | `practice_select` | `JUMP=practice_select;10` | song select in practice mode |
  | `practice` | CLI `dense.tja 3 --practice` | the practice play screen |
  | `dense` / `roll` | CLI chart `--auto` | gameplay; the dense chart has branches, GOGO and an FC ending |
  | `result` | roll chart `--auto`, frames 7600–8600 | the single-player result screen |

- **Not yet scripted:**
  - **2P play / 2P result:** needs entry with the 2P join key, or `SONG_SELECT_2P`.
  - **Dan play / dan result:** needs a dan course. Make a private test dir (below) and add a dan folder to *its own* Songs copy. Do not edit the shared `test_ss/Songs`. The format is in Z-DON `src/objects/song_select/file_navigator` (DanBox) and Green's songs.
  - **Game over, retry:** game over appears when the song limit is reached (`[limits] song_limit` in the test config).
  - **Loading:** the first frames of a cold start.
  - **AI battle:** `AI_SELECT` / `AI_GAME`; no jump hook yet.
- **Parallel work:** give every agent its own install: `tools/mk_testdir.sh <name> [YataiDONSimpleStyle|PyTaikoGreen]`. Then run `T=/d/YataiDON_agents/test_ss_<name> ./run_cap.sh ...`. All installs share the built skin through a junction, so rebuild with `--only <yours>` only.
- **Comparing with Green:** use `T=/d/YataiDON_agents/test_ss_green` (skin = PyTaikoGreen) with the same scenario and frames, and put both side by side.
  - Reference captures from 2026-10-28 are in `caps/green/<scenario>/` (title, entry, dan_select, settings, practice_select, practice, result).
  - Look for leftover Green art: anything orange/red/patterned, Don-chan, Green fonts in text images.
- **Contact sheet:** `python tools/contact.py <dir> <out.png> [cols]`, or `tools/cap_all.sh <outroot> <scenarios...>`.
- **Logs:**
  - Skin problems show up as `No textures loaded for …`, `Texture … not found`, `Error … lua`, `draw_texture: null texture`, `Lua patch target not found` (build).
  - Known, not ours: `No textures loaded for game/ending_donderful` (Green does the same), `Sounds for screen loading not found`, `Music stream preview not found`, `RtAudio`.

## Rules (from the user; non-negotiable)
- **Don't touch other skins** or the user's Z-DON `build/bin` config.toml / scores.db. Use only the test installs under `D:/YataiDON_agents/test_ss*`.
- **Never disturb the user:** hidden test windows only, no synthetic OS input, no window focusing. Run builds with `nice -n 19 -j 8`. Check `tasklist` before every run.
- **Everything is drawn by code:** no copied art or text images, no AI image generation.
- **No engine commits** unless a real bug blocks you. Report it instead.
- **Never `cd` into `out/` or any `Skins/` folder.** OMC hooks create `.omc/`, which the engine then loads as a texture folder. Use absolute paths.
- **Don't publish, push, create repos, or add `.skin-repo`.**
- **Don't stall:** skip, note it, and go on. Report what is done, what is left, and the engine limits per screen.
