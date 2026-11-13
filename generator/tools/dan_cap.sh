#!/bin/bash
# usage: T=<testdir> tools/dan_cap.sh <outdir> "<frames>" "<keys>" <engine args...>   (dan-module helper: retry / game over)
set -u
T=${T:?}; OUT=$(realpath -m "$1"); FR=$2; KEYS=$3; shift 3
if tasklist 2>/dev/null | grep -qi "yataidon"; then echo "yataidon running"; exit 2; fi
rm -rf "$OUT"; mkdir -p "$OUT"; cd "$T"
env YATAIDON_TEST=1 YATAIDON_FIXED_STEP_MS=20 YATAIDON_DUMP_FRAMES="$(cygpath -w "$OUT");$FR" YATAIDON_FAKE_KEYS="$KEYS" timeout 900 ./YataiDON.exe "$@" >/dev/null 2>&1
echo "exit $?"; cp latest.log "$OUT/latest.log"
grep -E "\[(error|warning)\]" "$OUT/latest.log" | grep -v RtAudio | head
