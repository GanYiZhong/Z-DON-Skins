"""Foundation module: skin_config base, fonts, shared UI + mascot textures, generated Lua defs.

OWNS everything shared; the screen modules only add their own subsets/scripts."""
from __future__ import annotations

import json
import os

from . import fonts, style, ui
from .atlas import NIJIIRO_G

NAME = "core"
OWNS = ["Fonts", "Graphics/global/ss_ui", "Graphics/ss_mascot", "Graphics/global/ss_course", "Scripts/global/ss_ui.lua", "Scripts/global/ss_def.lua",
        "Scripts/global/ss_ai.lua"]


def configure(ctx):
    ui.LANG = ctx.lang


def skin_config(ctx):
    """Only the screen block: every other skin_config entry is inherited from Nijiiro (the engine
    scales ancestor entries itself). Values here are LOGICAL."""
    with open(f"{NIJIIRO_G}/skin_config.json", encoding="utf-8") as f:
        nj = json.load(f)
    opts = dict(nj["screen"]["options"])
    opts["disable_chara_3d"] = True     # our 2D mascots replace the 3D character everywhere
    opts["language_variants"] = True    # Z-DON 6aa410e: C++ fixed-name textures pick <name>_<lang> (dynamic-text plan)
    screen = {"parent": "YataiDONNijiiro", "width": 1920, "height": 1080,
              "texture_density": style.D, "options": opts}
    if style.D > 1:
        screen["font_base"] = "font.ttf"   # Z-DON: font_cn / tw / kr are overlays on it (ss/fonts.py)
    from . import pixel
    # Z-DON 2D outfits (objects/entry/zdon_outfit_menu.h): the costume board opens our outfit picker.
    # Outfit number = character x n + outfit (n = plain + pixel.OUTFITS): 0..n-1 Momo, n..2n-1 Hoshi;
    # never picked: 1P Momo, 2P Hoshi (x / y). ss_ui.lua Mascot decodes it.
    n = 1 + len(pixel.OUTFITS["momo"])
    return {"screen": screen, "zdon_outfits": {"width": 2 * n, "x": 0, "y": n}}


def build(ctx):
    fonts.install(os.path.join(ctx.out, "Fonts"), zdon=ctx.density > 1)
    n = ui.build(ctx.G, ctx.main_char, ctx.lang)
    ui.write_def(ctx.scripts, ctx.main_char, ctx.lang)
    return n + len(fonts.FONTS)
