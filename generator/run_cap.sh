#!/bin/bash
# usage: run_cap.sh <outdir> <scenario> [VAR=value ...]
# Hidden, deterministic capture (YATAIDON_TEST=1: the window is never shown; fixed 20 ms steps,
# so JUMP/FAKE_KEYS/DUMP_FRAMES numbers are FRAME numbers). Keys go through the game's own input
# queue (YATAIDON_FAKE_KEYS), never the OS. Env overrides:
#   T=<test dir>   default D:/YataiDON_agents/test_ss (SimpleStyle); test_ss_green = PyTaikoGreen;
#                  make your own with tools/mk_testdir.sh <name> [skin] when working in parallel
#   FRAMES=...     frame list to dump (comma separated)    KEYS=...  "<frame>:<raylib key>,..."
#   DIFF=0..4      course for the chart scenarios           STEP=ms  fixed step (default 20)
# raylib keys: J=74 F=70 (don: confirm)  K=75 (right ka: next)  D=68 (left ka: previous)
#              ESCAPE=256  ENTER=257  F1=290 (restart)  SPACE=32 (pause)
set -u
T=${T:-/d/YataiDON_agents/test_ss}
OUT=$(realpath -m "$1"); KIND=$2; shift 2
ARGS=(); JUMP=""; DKEYS=""
C=C:/zdtest/charts
DANDIR=${DAN:-$T/Songs/danc/pass}
[ -n "${DAN:-}" ] || [ -f "$DANDIR/dan.json" ] || DANDIR=/d/YataiDON_agents/test_ss_v2result/Songs/danc/pass
case $KIND in
  # enso, single player, autoplay (the result screen follows after ~frame 7900)
  dense)    ARGS=("$C/dense/dense.tja" ${DIFF:-3} --auto)
            DFR="300,900,1500,2100,2700,3300,3900,4500,5100,5700,6300,6900,7500,8100,8700,9300" ;;
  # long rolls (longroll.tja: Oni only; two long rolls, a balloon, GOGO, a long title): the roll
  # counter climbs 10 -> 40+ (roll.tja's rolls are 2 hits each, so its counter stays at 2)
  roll)     ARGS=("$C/longroll/longroll.tja" ${DIFF:-3} --auto)
            DFR="150,250,300,350,400,450,500,550,600,650,700,800,1000,1200,1400,1600" ;;
  result)   ARGS=("$C/roll/roll.tja" ${DIFF:-3} --auto)
            DFR="7600,7700,7800,7900,8000,8200,8400,8600" ;;
  # the staged result reveal, every 100 ms (5 frames) from ~6800 ms before the old result frame set:
  # board opens ~7095, gauge ~7110, score ~7175, rows ~7210, medal ~7235, crown ~7250, bubble ~7270
  result_reveal) ARGS=("$C/roll/roll.tja" ${DIFF:-3} --auto)
            DFR=$(seq -s, 6800 5 7600) ;;
  # 2P: both players on auto (Z-DON --2p; GAME_2P then RESULT_2P); needs both access codes in config
  play2p)   ARGS=("$C/dense/dense.tja" ${DIFF:-3} --2p)
            DFR="300,900,1500,2100,2700,3300,3900,4500,5100,5700,6300,6900,7500" ;;
  # Z-DON AI battle (--ai): 1P on auto against the AI on the 2P lane; ZDON_AI_SEED fixes the AI's draws
  aiplay)   ARGS=("$C/dense/dense.tja" ${DIFF:-3} --ai --auto)
            DFR="300,900,1500,2100,2700,3300,3900,4500,5100,5700,6300,6900,7500" ;;
  # 1P idle (no auto): every section goes to the AI
  ailose)   ARGS=("$C/roll/roll.tja" ${DIFF:-3} --ai)
            DFR="3000,7500,7700,7750,7800,7900" ;;
  airesult) ARGS=("$C/roll/roll.tja" ${DIFF:-3} --ai --auto)
            DFR="7300,7400,7500,7600,7700,7800,8000,8400" ;;
  result2p) ARGS=("$C/roll/roll.tja" ${DIFF:-3} --2p)
            DFR="7300,7400,7500,7600,7700,7800,8000,8400" ;;
  # dan: Z-DON --dan <course> (library loads, then GAME_DAN on auto, then DAN_RESULT). DAN=<course dir>
  # overrides; the default is the PASSING review course danc/pass (三段: gauge 70%, 良 100+, 不可 <10 ->
  # 合格 under auto; danc/gold = 名人 -> 金合格; danc/1 = 五級 fails its 可 exam). Same 3 charts as
  # danc/1, so the frame lists fit all three. Taken from $T/Songs/danc, else from test_ss_v2result.
  danplay)  ARGS=(--dan "$(cygpath -m "$DANDIR")")
            DFR="300,1500,2500,4250,5250,6750,7250,8000,11000,14250,15500,18250,20000,21500,21900" ;;
  danresult) ARGS=(--dan "$(cygpath -m "$DANDIR")")
            DFR="22250,22500,23000,23750,24000,24250,24500,25000,25250" ;;
  practice) ARGS=("$C/dense/dense.tja" ${DIFF:-3} --practice)
            DFR="100,300,600,900,1500" ;;
  # menus (no CLI start: jump there, then drive with fake keys)
  title)    DFR="20,60,120,200,300,450,700,1000,1500" ;;
  entry)    JUMP="entry;10"; DFR="40,80,140,200,300" ;;
  # the name picker (entry NAME_ENTRY). The engine opens it only after an ONLINE login
  # (scenes/entry.cpp finish_login), and fixed-step mode forces the network off, so it needs the
  # harness install: cache/mk_nameentry_harness.sh [1p|2p] -> T=test_ss_nameentry_1p|2p (its entry.lua
  # builds NameEntry ~frame 11 and plays: ring 2, ring 3, commit ぃ, commit あ, できた, confirm, いいえ)
  name_entry) JUMP="entry;10"
            DFR="12,13,14,16,60,148,152,170,172,176,190,200,212,230,240,262,290,302,312,316,332,334,340,352"
            ;;
  song_select) JUMP="song_select;10"
            DKEYS="150:75,200:75,260:74,330:75,400:68"
            DFR="60,140,190,240,290,320,360,420,480" ;;
  diff_select) JUMP="song_select;10"
            DKEYS="150:74,230:75,270:75,310:75,350:75,390:75,430:68"
            DFR="200,250,290,330,370,410,460" ;;
  dan_select) JUMP="dan_select;10"; DKEYS="200:75,240:75"; DFR="100,190,230,280,330,400" ;;
  settings) JUMP="settings;10"; DKEYS="150:75,200:75,250:74"; DFR="60,140,190,240,300" ;;
  practice_select) JUMP="practice_select;10"; DFR="60,140,240" ;;
  # song select agent (v2): the option panel (演奏オプション) from the course select: J opens the
  # course select, K moves to the option button, J opens the panel; K changes a value, J goes down
  ss_options) JUMP="song_select;10"
            DKEYS="150:74,230:75,280:74,340:75,380:74,410:75,440:75,480:74,510:74,540:74,570:75"
            DFR="300,330,360,420,460,500,560,600" ;;
  # fix1029: the option panel opened from the course select and closed again: J on the last row
  # confirms the panel (the engine has no ESC close); 7 J walk the rows, the 7th (~frame 520) closes it.
  # Every 2nd frame from just before the close through the return to the course select
  ss_options_close) JUMP="song_select;10"
            DKEYS="150:74,230:75,280:74,340:74,370:74,400:74,430:74,460:74,490:74,520:74"
            DFR=$(seq -s, 500 2 700) ;;
  # fix1029: SONG_SELECT_2P course select with BOTH players on おに (the readout cards on both sides).
  # 2P joins from the song select (2P don X=88 / C=67, then the entry), course select opens ~1000;
  # 1P K=75 x5 and 2P right ka V=86 x5 move from もどる to おに
  diff_select_2p) JUMP="song_select;10"
            DKEYS="150:88,400:88,450:67,500:88,550:74,600:88,650:74,700:74,750:88,800:74,850:88,900:74,1000:88,1150:75,1160:86,1180:75,1190:86,1210:75,1220:86,1240:75,1250:86,1270:75,1280:86"
            DFR="650,1100,1200,1300,1350,1400" ;;
  # the 音色 row (option_neiro_row: neiro is the panel's last row): six J reach it, K changes it
  ss_neiro) JUMP="song_select;10"
            DKEYS="150:74,230:75,280:74,320:74,345:74,370:74,395:74,420:74,445:74,480:75,520:75"
            DFR="470,500,540,580" ;;
  # wheel folders + the one-menu sort window: needs T=test_ss_ssv2lib (Songs: J-POP / アニメ /
  # ゲーム folders and a #COLLECTION:DIFFICULTY folder); K x3 reaches the sort folder, J opens it
  ss_sort) JUMP="song_select;10"
            DKEYS="150:75,210:75,270:75,330:74,420:75,480:74,540:75"
            DFR="100,200,320,360,460,520,600" ;;
  # the 段位道場 shutter (song select -> dan select): T=test_ss_ssv2lib has a #GENRE:DAN folder; D
  # from J-POP wraps to it (the last box), J starts the transition
  ss_dan) JUMP="song_select;10"
            DKEYS="150:68,260:74"
            DFR="200,270,290,310,330,350,370,390,410,440,480"
            ;;
  # earned crowns / ranks and the score history panel (shows after a board is open 3 s); needs a
  # test install whose scores.db has scores for the test songs (test_ss_ssv2: seeded)
  ss_scores) JUMP="song_select;10"
            DKEYS="150:75,420:74"
            DFR="140,300,330,380,460,500" ;;
  # open a genre folder (J on J-POP) and browse its songs
  ss_folders) JUMP="song_select;10"
            DKEYS="150:74,330:75,400:68"
            DFR="140,200,260,330,380,450" ;;
  *) echo "unknown scenario $KIND"; exit 1 ;;
esac
FRAMES=${FRAMES:-$DFR}
KEYS=${KEYS:-$DKEYS}
# never run while a game is open (it may be the user's)
if tasklist 2>/dev/null | grep -qi "yataidon"; then
  echo "a YataiDON process is running; not starting (check tasklist)"; exit 2
fi
rm -rf "$OUT"; mkdir -p "$OUT"
cd "$T"
OUTW=$(cygpath -w "$OUT")
start=$(date +%s)
env YATAIDON_TEST=1 YATAIDON_FIXED_STEP_MS=${STEP:-20} YATAIDON_DUMP_FRAMES="$OUTW;$FRAMES" YATAIDON_JUMP_SCREEN="$JUMP" \
  YATAIDON_FAKE_KEYS="$KEYS" "$@" timeout 600 ./YataiDON.exe "${ARGS[@]}" >/dev/null 2>&1
echo "$KIND exit $? $(( $(date +%s) - start ))s -> $OUT"
cp latest.log "$OUT/latest.log"
grep -E "\[(error|warning)\]|\[ss_ui\]" "$OUT/latest.log" | grep -v "RtAudio" | head -20
