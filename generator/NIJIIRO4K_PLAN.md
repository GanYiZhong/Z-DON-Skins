# SimpleStyle v2: Nijiiro base, 4K, art bible (2026-10-29)

The user's goal: **make it more complete, more like a real game, and less vibe-coded; make it a 4K skin; use Nijiiro's configuration for everything; stop using Green.**

Binding inputs:
- `reports/art_direction_review.md`: the art bible (§2) and punch list (§3). Translate its numbers to the grid below.
- `LIGHT8_GUIDE.md`: palette roles, contrast rules, mascots. Still valid except where this file overrides it.
- User decisions that still hold:
  - light theme, 8-bit look, **notes and lane stay flat**
  - mascots Momo (1P/main) and Hoshi (buddy/2P), the user's own plush toys
  - Fusion Pixel font (OFL)
  - fixed text in Japanese
  - original art only (nothing copied, nothing imitating Nijiiro's or Green's art)

## Why not a plain 3840x2160 child
Probe result: `caps/probe/probe_cmp.png`. A child skin at width 3840 with parent YataiDONNijiiro makes the engine scale Nijiiro's textures and positions ×2. Nijiiro's Lua, though, hard-codes 1920-space numbers, so backgrounds, song select and score positions break. Layouts must stay in Nijiiro's logical 1920x1080 space.

## Architecture
- **Skin**: `parent: "YataiDONNijiiro"` (Nijiiro itself inherits PyTaikoGreen). It ships every texture that is actually drawn, so no Nijiiro or Green art shows through.
  - `screen.width/height` = **1920 x 1080 (logical)**.
  - `screen.options`: Nijiiro's options, plus `disable_chara_3d: true`. Nijiiro sets `disable_retry_game: true`, so its flow has no retry screen.
- **Texture density** is a new Z-DON engine feature: `screen.texture_density = 2`.
  - Every PNG of THIS skin is authored at 2x (physical px). Its texture.json numbers (x, y, x2, y2, crop) are physical px too.
  - The engine loads this skin's own textures with scale 1/density, so geometry ends up in logical units. `get_texture_info` reports logical sizes.
  - Ancestor textures keep their usual scaling.
  - The engine renders into a (1920·d)x(1080·d) target with a camera zoom of d, so Lua and engine coordinates stay logical. Text is rasterised at physical size.
  - Frame dumps (YATAIDON_DUMP_FRAMES) are 3840x2160.
  - Upstream YataiDON does not have this feature. The generator therefore keeps a `--density 1` build (1080p) for engines without it. **Density 2 is the main target.**
- **Generator** (`build.py --density 2` default):
  - Design coordinates are **logical 1920x1080**. `Canvas` outputs physical px (×density).
  - Geometry is read from the nearest ancestor that defines a key: Nijiiro first (scale 1), then Green (×1.5).
  - LUA_PATCHES copy the script from the nearest ancestor that has it (Nijiiro first).
- **Grid** (physical px at 4K / logical px):
  - chrome unit **U = 6 phys = 3 logical**: every chrome coordinate, border, shadow and notch is a multiple of U
  - mascot sprite pixel **k ∈ {6, 12, 18} phys** (sprite heights 34·k): menu/portrait k=12, scene k=18, tiny k=6
  - text in Fusion Pixel 12px at **18 / 24 / 36 / 48 logical** (36/48/72/96 phys; every font pixel is a whole number of physical px)
  - pixel chrome is drawn at SS=1 on the physical grid, never LANCZOS-downscaled; SS + LANCZOS only for flat notes, roll bodies and the lane
- Test installs:
  - `test_ss_nj` is Nijiiro at 1080p, the reference
  - `test_ss_4k` uses the probe skin
  - new installs need junctions for both `Skins/YataiDONNijiiro` and `Skins/PyTaikoGreen`
- The previous generator state is saved in `cache/snap_green_l8/` (Green-based light 8-bit) for reference: drawing code, pixel mascots and palette are reusable.

## Phases
1. **Engine** (Z-DON): `texture_density`, done by one agent.
   **Core** (generator): Nijiiro/ancestor plumbing, density, grid, `chrome.*`, `deco.*`, new mascot frames, Lua Mascot, off-palette scan. Done by one agent in parallel.
2. **Screens**, one agent each, on Nijiiro's layouts:
   - game: lane, HUD, background stage, dan / 2P
   - song select: Nijiiro horizontal wheel, diff, modifiers, neiro
   - result and dan result
   - entry, title, settings, loading
   - dan select, game over, globals (timer, nameplate, transition, indicator)
3. **Integration**: full capture at 4K, critic re-review, fix pass.
