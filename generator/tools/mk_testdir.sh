#!/bin/bash
# usage: tools/mk_testdir.sh <name> [skin]   -> D:/YataiDON_agents/test_ss_<name>
# A private hidden-test install (own config.toml / scores.db / latest.log) so parallel agents
# never share one. Exe + DLLs are hardlinked from test_ss, Songs and Skins are junctions.
# skin: YataiDONSimpleStyle (default) or PyTaikoGreen (for comparison captures).
set -eu
NAME=$1; SKIN=${2:-YataiDONSimpleStyle}
SRC=/d/YataiDON_agents/test_ss
T=/d/YataiDON_agents/test_ss_$NAME
mkdir -p "$T/Skins"
for f in "$SRC"/*.exe "$SRC"/*.dll; do ln -f "$f" "$T/$(basename "$f")" 2>/dev/null || cp "$f" "$T/"; done
cp -r "$SRC/shader" "$T/" 2>/dev/null || true
[ -f "$T/scores.db" ] || cp "$SRC/scores.db" "$T/scores.db"
sed "s/^skin = .*/skin = '$SKIN'/" "$SRC/config.toml" > "$T/config.toml"
junction() { [ -e "$1" ] || powershell -NoProfile -Command "New-Item -ItemType Junction -Path '$(cygpath -w "$1")' -Target '$(cygpath -w "$2")' | Out-Null"; }
junction "$T/Songs" "$SRC/Songs"
junction "$T/Skins/PyTaikoGreen" /d/GitHubRepos/Z-DON/build/bin/Skins/PyTaikoGreen
junction "$T/Skins/YataiDONSimpleStyle" /d/YataiDON_agents/simplestyle/out/YataiDONSimpleStyle
echo "$T ($SKIN)"
