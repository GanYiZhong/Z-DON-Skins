#!/bin/bash
# usage: tools/mk_testdir_v2.sh <name> [skin]   -> D:/YataiDON_agents/test_ss_<name>
# A private hidden-test install for the v2 (Nijiiro-based, texture density) skin.
#   - exe + DLLs are COPIED from $EXE_SRC (default: Z-DON build/bin, which has screen.texture_density);
#     copies, so an engine rebuild never swaps the binary under a running capture. Re-run with
#     REFRESH_EXE=1 to take a newer engine build.
#   - config.toml / scores.db / Songs come from test_ss (Songs as a junction).
#   - Skins/: junctions for YataiDONNijiiro + PyTaikoGreen (the ancestors) and our built skin.
# skin: YataiDONSimpleStyle (default), YataiDONNijiiro (reference) or PyTaikoGreen.
# Then: T=/d/YataiDON_agents/test_ss_<name> ./run_cap.sh <outdir> <scenario>
set -eu
NAME=$1; SKIN=${2:-YataiDONSimpleStyle}
SRC=/d/YataiDON_agents/test_ss
EXE_SRC=${EXE_SRC:-/d/GitHubRepos/Z-DON/build/bin}
SKINS=/d/GitHubRepos/Z-DON/build/bin/Skins
T=/d/YataiDON_agents/test_ss_$NAME
mkdir -p "$T/Skins"
if [ ! -f "$T/YataiDON.exe" ] || [ "${REFRESH_EXE:-0}" = 1 ]; then
  cp -f "$EXE_SRC"/YataiDON.exe "$T/"
  for f in "$EXE_SRC"/*.dll; do [ -e "$f" ] && cp -f "$f" "$T/"; done
  [ -d "$EXE_SRC/shader" ] && cp -r "$EXE_SRC/shader" "$T/" || cp -r "$SRC/shader" "$T/" 2>/dev/null || true
fi
[ -f "$T/scores.db" ] || cp "$SRC/scores.db" "$T/scores.db"
sed -e "s/^skin = .*/skin = '$SKIN'/" -e "s/^language = .*/language = 'ja'/" "$SRC/config.toml" > "$T/config.toml"   # captures are always Japanese
junction() { [ -e "$1" ] || powershell -NoProfile -Command "New-Item -ItemType Junction -Path '$(cygpath -w "$1")' -Target '$(cygpath -w "$2")' | Out-Null"; }
junction "$T/Songs" "$SRC/Songs"
junction "$T/Skins/YataiDONNijiiro" "$SKINS/YataiDONNijiiro"
[ "${WITH_GREEN:-0}" = 1 ] && junction "$T/Skins/PyTaikoGreen" "$SKINS/PyTaikoGreen"   # not needed since Z-DON 13f41b7 (missing parent ends the chain)
junction "$T/Skins/YataiDONSimpleStyle" /d/YataiDON_agents/simplestyle/out/YataiDONSimpleStyle
echo "$T ($SKIN, exe from $EXE_SRC)"
