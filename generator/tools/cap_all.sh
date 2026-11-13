#!/bin/bash
# usage: tools/cap_all.sh <outroot> [T=testdir] [scenario ...]   (default: every scenario)
# e.g. T=/d/YataiDON_agents/test_ss_green tools/cap_all.sh caps/green
R=$1; shift
S=${*:-"title entry song_select diff_select dan_select settings practice_select practice dense roll result"}
for k in $S; do /d/YataiDON_agents/simplestyle/run_cap.sh "$R/$k" "$k" | head -3; done
for k in $S; do [ -d "$R/$k" ] && python /d/YataiDON_agents/simplestyle/tools/contact.py "$R/$k" "$R/$k.png" 3; done
