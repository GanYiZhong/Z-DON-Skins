#!/bin/bash
# usage: T=<testdir> tools/cap_custom.sh <outdir> "<frames>" <exe args...>   (waits for other YataiDON processes)
OUT=$(realpath -m "$1"); FR=$2; shift 2
for i in $(seq 1 60); do tasklist 2>/dev/null | grep -qi yataidon || break; sleep 10; done
rm -rf "$OUT"; mkdir -p "$OUT"; cd "$T"; OUTW=$(cygpath -w "$OUT")
env YATAIDON_TEST=1 YATAIDON_FIXED_STEP_MS=20 YATAIDON_DUMP_FRAMES="$OUTW;$FR" YATAIDON_JUMP_SCREEN="${JUMP:-}" \
  YATAIDON_FAKE_KEYS="${KEYS:-}" ${EXTRA:-} timeout 600 ./YataiDON.exe "$@" >/dev/null 2>&1
cp latest.log "$OUT/latest.log"; grep -E "\[(error|warning)\]" "$OUT/latest.log" | grep -v "RtAudio" | head -20
