#!/bin/bash
# Assemble the Dark skin (tools/make_dark.py) and install it into Z-DON build/bin/Skins (run from anywhere)
set -eu
G=/d/ClaudeWorks/TaikoSimulator/simplestyle_gen
SK=/d/ClaudeWorks/TaikoSimulator/Z-DON/build/bin/Skins
cd "$G"
python tools/make_dark.py "$SK/YataiDONSimpleStyle" out/stage_dark | grep -v "^    "
rm -rf "$SK/YataiDONSimpleStyleDark"
cp -r out/stage_dark "$SK/YataiDONSimpleStyleDark"
du -sh "$SK/YataiDONSimpleStyleDark"
