> **v2 note:** `pixbox`/`pixbar`/`pixdither`, `mascot.sized(concept, expr, size)` and the Green geometry rules below are
> replaced by `ss/chrome.py`, `ss/deco.py` and `mascot.sized(char, expr, k)`; see `SCREEN_GUIDE_V2.md`. Palette roles and
> contrast rules still hold.

# SimpleStyle: light 8-bit direction (2026-10-28)

The user switched the skin from flat dark to a **light theme with an 8-bit game look**.
The concept is in `mockups/light8bit_v1.png` (gameplay + song select) and
`mockups/pixel_mascots_v1.png` (mascots). Match that mockup's feel.
This file overrides the dark-theme rules in STYLE_GUIDE.md wherever they conflict.

## Already done by core (do not redo or edit)
- `ss/style.py` palette `P`/`C` is now light. Roles:
  - `bg0` cream screen, `bg1` white panel, `bg2` lane/raised, `bg3` chips/grooves, `line` hairline.
  - `text` = ink, `text2`, `mute`.
  - New keys: `ink` (outlines/shadows), `paper` (white), `sky`, `pink`, `mint`.
  - Text-strength accents: `gold_t`, `blue_t`, `red_t`.
- Contrast check (`ss/tokens.py`) passes. Two rules follow from it:
  - **Gold (`clear`/`roll`/`kusu`) is a FILL only.** It always sits inside an ink outline; gold text uses `gold_t`.
  - White text goes only on saturated fills (`p1`, `p2`, `ura`), and only bold/large.
- New helpers in `ss/style.py`:
  - `pixbox(cv, x0,y0,x1,y1, fill, border, shadow=4, px=3, notch=True)`: 8-bit window with an ink border, notched corners and a hard ink drop shadow.
  - `pixbar(cv, x0,y0,x1,y1, frac, fill, groove, segs)`: segmented meter.
  - `pixdither(...)`: checker band.
- **Mascots** are now pixel art: `M` = Momo (pink rabbit, the main character, `mascot.MAIN`) and `H` = Hoshi (husky in a grey hoodie, the buddy, `mascot.BUDDY`).
  - Use `mascot.sized(concept, expr, size)`. It scales by whole pixels and puts the feet on the bottom edge.
  - **Never** `compose(...).resize(..., LANCZOS)` a pixel mascot (it blurs). Never rotate or squash them; 8-bit motion = hop by whole sprite pixels, or swap expression frames.
  - Expressions: idle, blink, good, combo, sad, gogo, clear, fail.
  - Raw grids are in `ss/pixel.py`: `pixel.sprite("momo"|"hoshi", expr, frame, scale)`. Frame 1 = 1 px squash pose.
  - The Lua `UI.Mascot` already hops instead of squashing (`D.MASCOT.pixel`).
- Notes (`ss/game.py` note_disk, roll body) already use the ink outline + white rim.

## Rules for every screen
1. **Notes and the lane stay flat** (user decision): smooth anti-aliased discs and a flat lane. Only their colours follow the light palette. Everything else is 8-bit.
2. **8-bit UI**:
   - Every window, card, pill, header and button is a `pixbox` (ink border, notched corners, hard shadow, no blur, no soft glow, no gradients).
   - Meters are `pixbar`.
   - Selection/focus = a thicker ink border plus a gold fill or a blinking `▶` cursor. No glow.
   - Rounded "capsules" become notched rectangles.
   - Small icons are pixel glyphs (draw them with `pixel.Grid` or rect grids). No smooth vector icons except notes.
   - Snap coordinates to whole pixels (multiples of 2 or 3 look best at 1280×720).
3. **Colour roles were inverted.**
   - In the dark theme `bg0` doubled as "dark ink on a bright fill". That now gives cream-on-accent.
   - Go through every `C["bg0"]`, `C["text"]` and `OUTLINE` in your module and choose the role explicitly:
     - `C["ink"]` for outlines, shadows, and ink text on bright fills.
     - `C["paper"]` for white highlights and rims.
     - `C["bg0"]` only where you really mean the cream screen background.
   - Same for `text2`/`mute`, which are now dark-on-light.
4. **Backgrounds**: cream `bg0`. A light `sky` band with pixel clouds at the top of a screen is the house look. Sparse 8-bit decoration (pixel clouds, stars, checker strips) is fine. Keep it calm: no busy patterns behind text.
5. **Text**:
   - There is no pixel font yet (one may come later).
   - Baked text uses Noto Sans JP bold as before, ink on paper. Short Latin labels may be drawn as pixel glyphs if you like.
   - Engine-drawn text (song titles etc.) keeps its engine colours. Where `skin_config` sets text/outline colours, set them for a light background (ink fill + white outline, or white fill + ink outline).
6. **Originality**: nothing may imitate Green's art or composition. The retry_game / game_over screens (festival stalls, lanterns, moon, striped curtain) must be redrawn as our own simple 8-bit scenes, e.g. Momo and Hoshi with pixel windows.
7. Keep Green's layouts and frame geometry (texture.json sizes and offsets), as before.

## Workflow
- Read `SCREEN_GUIDE.md` for the module contract, captures and test installs.
- Make your own test install with `tools/mk_testdir.sh <name>`.
- Rebuild only your module: `python build.py --only <module>`.
- Capture with `T=/d/YataiDON_agents/test_ss_<name> ./run_cap.sh ...`. Before running the game, check `tasklist | grep -i yataidon`; the user may be playing (only hidden test runs, volume ~0).
- Do not edit `ss/style.py`, `ss/tokens.py`, `ss/pixel.py`, `ss/mascot.py`, `ss/ui.py`, `ss/core.py`, `lua/core/**`, or other modules' files. If you need a shared helper or a new contrast pair, define it locally in your module and list it in your report under "promote to core".
- `python build.py --only <module>` must pass (the contrast check runs every build).

## Round 2 (polish), 2026-10-28
- `ss/pixel.py` sprites are now 34x34 cells (the 32x32 design plus a 1-cell margin), so outlines never clip. `mascot.sized()`, the `ss_mascot` frames and the Lua hop already follow this. If you paste `pixel.sprite()` yourself, its size is 34*k.
- The user reported that the characters look cut apart. Every mascot must:
  - stand on something: a ground strip, the top edge of a window, or a floor line, with its feet ON that line;
  - be fully visible: never straddle a band boundary, never sit half over the footer or the engine's bottom bar (the free-play text and nameplate area, roughly y > 640, belong to the engine), and never be covered by an engine popup or engine text.
- Polish pass:
  - inspect every captured frame at FULL resolution: crop and zoom; don't rely on contact sheets
  - fix clipping, overlaps, misalignment, text touching borders, off-grid / blurry pixel art, unbalanced or empty areas
  - keep everything consistent with the other screens (same window style, shadow size, header plate style)
