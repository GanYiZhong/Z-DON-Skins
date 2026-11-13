#!/bin/bash
# usage: caps.sh <lang> <scenario...>
cd /d/YataiDON_agents/simplestyle
T=/d/YataiDON_agents/test_ss_ss
L=$1; shift
sed -i "s/^language = .*/language = '$L'/" $T/config.toml
for s in "$@"; do
  T=$T TT=1 tools/wait_cap.sh caps/t24_ss/${L}_$s $s
done
