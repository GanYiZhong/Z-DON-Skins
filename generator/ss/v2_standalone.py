"""v2 standalone: nothing of PyTaikoGreen is used at run time ("不要再用green").

The chain is ours -> YataiDONNijiiro -> PyTaikoGreen and the engine insists that
Skins/PyTaikoGreen/Graphics/skin_config.json exists, but every file it would otherwise still resolve
from Green (tools/green_fallthrough.py lists them) is provided here:

  * animation.json of background / dan_result / entry / global / retry_game: the nearest ancestor's
    file (Nijiiro preferred; today only Green has them), with the numbers the engine scales for an
    ancestor (total_distance, start_position, waypoint values) pre-scaled the same way, so the
    timing and motion are unchanged;
  * Graphics/settings_template.json: the ancestor's option schema (no visuals; the one option the
    engine skips, network/access_code, is left out);
  * Scripts the engine loads by name or requires and only Green has (practice_menu, result_basin,
    result_retry_message, ura_switch, sort_window, player_ui): copied, with Green's
    black / crimson draw colours swapped for our ink;
  * text_config.json: our own strings for every key only Green defined (ja / en / zh / ko);
  * the Green-only skin_config entries (pinned here at logical size), so the stub's values are unused;
  * Sounds: original chiptune SFX from ss/v2_sound.py for every Green-only sound name, plus a
    Sounds/loading ambience (the loading screen asks for that folder);
  * Fonts/debug_ui.ttf + debug_code.ttf: our pixel font (the debug overlay loads these names).

Shaders are read from the exe folder (shader/), and Models only with 3D characters (disabled), so
neither comes from a skin. Run last: it writes into folders other modules own."""
from __future__ import annotations

import json
import os
import shutil

from . import v2_sound
from .atlas import ANCESTORS, ancestor_script

NAME = "v2_standalone"

ANIM_SCREENS = ["background", "dan_result", "entry", "global", "retry_game"]
SCRIPTS = ["game/practice_menu.lua", "result/result_basin.lua",
           "result/result_retry_message.lua", "song_select/ura_switch.lua", "song_select/sort_window.lua",
           "song_select/player_ui.lua"]
# Scripts that extend their parent's copy by loading it BY PATH (not by name), so the name lookup never
# shows them: our game/gauge.lua (lua/game/game/gauge.lua: "the PyTaikoGreen copy") and Nijiiro's
# game/note_arc.lua ("the second match on package.path" = Green's). The base each extends is shipped
# as <name>_base.lua; ours / a copy of Nijiiro's then load that instead.
BASES = {"game/gauge_base.lua": "game/gauge.lua", "game/note_arc_base.lua": "game/note_arc.lua"}
OWN_BASE_LOADER = """local function load_own_base(name)   -- SimpleStyle standalone: this skin's copy of the base
    for tmpl in package.path:gmatch("[^;]+") do
        local chunk = loadfile((tmpl:gsub("%?", name)))
        if chunk then return chunk end
    end
end
"""
EXTENDERS = {   # rel -> (source: "own" = our built file | "nijiiro", old line, new line)
    "game/gauge.lua": ("own", 'assert(load_parent("game/gauge"), "game/gauge: the parent skin has no gauge script")()',
                       'assert(load_own_base("game/gauge_base"), "game/gauge: no gauge_base script")()'),
    "game/note_arc.lua": ("nijiiro",
                          'assert(load_parent("game/note_arc"), "game/note_arc: the parent skin has no note_arc script")()',
                          'assert(load_own_base("game/note_arc_base"), "game/note_arc: no note_arc_base script")()'),
}
OWNS = ([f"Graphics/{s}/animation.json" for s in ANIM_SCREENS] +
        [f"Scripts/{r}" for r in BASES] + ["Scripts/game/note_arc.lua"] +
        ["Graphics/settings_template.json", "text_config.json", "Sounds",
         "Fonts/debug_ui.ttf", "Fonts/debug_code.ttf"] +
        [f"Scripts/{r}" for r in SCRIPTS])

INK = "58, 38, 51"    # style P["ink"] #3A2633

# exact (old, new) swaps per copied script: Green's black outlines / crimson frame -> our ink
SCRIPT_SUBS = {
    "game/practice_menu.lua": [("BLACK = { 255, 255, 255, 255 }, { 0, 0, 0, 255 }",
                                "BLACK = { 255, 255, 255, 255 }, { %s, 255 }" % INK),
                               # v2_game (10-29): practice keeps its "とっくんメニュー" panel; the plain
                               # practice/menu_panel ("メニュー") is the in-song pause menu (C++)
                               ('sprite("menu_panel")', 'sprite("menu_panel_practice")')],
    "song_select/player_ui.lua": [("{ 119, 26, 45, alpha }", "{ %s, alpha }" % INK),
                                  ("{ 0, 0, 0, 255 }, { 0, 0, 0, 0 }", "{ %s, 255 }, { 0, 0, 0, 0 }" % INK),
                                  ("{ 255, 255, 255, 255 }, { 0, 0, 0, 255 }",
                                   "{ 255, 255, 255, 255 }, { %s, 255 }" % INK)],
    "song_select/sort_window.lua": [("lb.y2[1], 0, 0, 0, 127)", "lb.y2[1], %s, 127)" % INK)],
}


def _write_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)
        f.write("\n")


def _nearest(rel):
    """(path, scale into our logical space) of the nearest ancestor's Graphics/<rel>"""
    for _, gdir, _, scale in ANCESTORS:
        p = os.path.join(gdir, rel)
        if os.path.isfile(p):
            return p, scale
    raise SystemExit(f"v2_standalone: no ancestor has Graphics/{rel}")


def _scaled(v, s):
    # TextureWrapper::read_screen_animations: ints -> static_cast<int>(v * scale), doubles -> v * scale
    if isinstance(v, bool) or not isinstance(v, (int, float)):
        return v
    return int(v * s) if isinstance(v, int) else v * s


def build_animations(ctx):
    for scr in ANIM_SCREENS:
        src, s = _nearest(f"{scr}/animation.json")
        with open(src, encoding="utf-8") as f:
            anims = json.load(f)
        if isinstance(anims, list) and s != 1.0:
            for a in anims:
                for k in ("total_distance", "start_position"):
                    if k in a and not isinstance(a[k], dict):
                        a[k] = _scaled(a[k], s)
                for wp in a.get("waypoints", []) if isinstance(a.get("waypoints"), list) else []:
                    if isinstance(wp, dict) and "value" in wp:
                        wp["value"] = _scaled(wp["value"], s)
        _write_json(os.path.join(ctx.G, scr, "animation.json"), anims)
    return len(ANIM_SCREENS)


def build_settings_template(ctx):
    src, _ = _nearest("settings_template.json")
    with open(src, encoding="utf-8") as f:
        t = json.load(f)
    for sec in t.values():
        if isinstance(sec, dict) and isinstance(sec.get("options"), dict):
            for k in [k for k, o in sec["options"].items() if isinstance(o, dict) and o.get("path") == "network/access_code"]:
                del sec["options"][k]
    # Z-DON options (src/libs/config.cpp general.zdon_*), after the judge counter; upstream engines do not
    # read these keys, so the rows only change Z-DON's play / result screens
    opts = t.get("general", {}).get("options")
    if isinstance(opts, dict) and "judge_counter" in opts:
        on_off = opts["judge_counter"]["values"]
        extra = {
            "zdon_hit_timing": {
                "path": "general/zdon_hit_timing",
                "name": {"en": "Hit Timing", "ja": "タイミング表示", "zh": "打擊時機顯示", "ko": "타이밍 표시"},
                "description": {
                    "en": "Shows FAST / SLOW under the hit circle and a timing graph on the result screen.",
                    "ja": "判定枠の下に はやい / おそい を、リザルトにタイミングのグラフを表示します。",
                    "zh": "在判定圈下方顯示快 / 慢，並在結算畫面顯示時機分佈圖。",
                    "ko": "판정 원 아래에 빠름 / 느림을, 결과 화면에 타이밍 그래프를 표시합니다."},
                "type": "bool", "values": on_off},
            "zdon_hit_timing_show": {
                "path": "general/zdon_hit_timing_show",
                "name": {"en": "FAST / SLOW Marks", "ja": "はやい / おそい の表示", "zh": "快 / 慢 提示",
                         "ko": "빠름 / 느림 표시"},
                "description": {
                    "en": "Which hits get a FAST / SLOW mark.",
                    "ja": "はやい / おそい を表示する打撃を選びます。",
                    "zh": "選擇哪些打擊要顯示快 / 慢。",
                    "ko": "빠름 / 느림을 표시할 타격을 고릅니다."},
                "type": "string",
                "values": {
                    "half": {"en": "Off by half the GOOD window", "ja": "良の幅の半分以上ずれたとき",
                             "zh": "偏差超過良判定的一半", "ko": "양 판정 폭의 절반 이상 어긋날 때"},
                    "ok": {"en": "Only OK and BAD", "ja": "可・不可のときだけ", "zh": "只在可、不可時",
                           "ko": "가·불가일 때만"},
                    "all": {"en": "Every hit", "ja": "すべての打撃", "zh": "每一下", "ko": "모든 타격"}}},
            "show_timing_offset": {
                "path": "general/show_timing_offset",
                "name": {"en": "Average Timing", "ja": "平均タイミング表示", "zh": "平均時機顯示",
                         "ko": "평균 타이밍 표시"},
                "description": {
                    "en": "Shows your average early / late offset in ms during play and on the result screen.",
                    "ja": "プレイ中とリザルトで平均のずれ（ms）を表示します。",
                    "zh": "在遊戲中和結算畫面顯示平均偏差（毫秒）。",
                    "ko": "플레이 중과 결과 화면에 평균 어긋남(ms)을 표시합니다."},
                "type": "bool", "values": on_off},
            "zdon_sort_filter": {
                "path": "general/zdon_sort_filter",
                "name": {"en": "Difficulty Folder Filter", "ja": "難易度フォルダの絞り込み",
                         "zh": "難度資料夾篩選", "ko": "난이도 폴더 필터"},
                "description": {
                    "en": "Not cleared / not full combo / not donderful lists only those songs (off: they come first).",
                    "ja": "未クリア・未フルコンボ・未全良を選ぶと、その曲だけを表示します（オフ：先頭に並べる）。",
                    "zh": "選擇未通關、未全連、未全良時只列出這些歌（關閉：排在前面）。",
                    "ko": "미클리어·미풀콤보·미전량을 고르면 그 곡만 표시합니다 (끄면: 앞에 정렬)."},
                "type": "bool", "values": on_off},
            "zdon_practice_loop": {
                "path": "general/zdon_practice_loop",
                "name": {"en": "Practice Section Loop", "ja": "練習の区間ループ", "zh": "練習區段循環",
                         "ko": "연습 구간 반복"},
                "description": {
                    "en": "Resume at a jump mark to loop up to the next mark, with each pass's judgements.",
                    "ja": "ジャンプ地点から再開すると次の地点までをループし、毎周の判定を表示します。",
                    "zh": "從跳躍點繼續時，會循環到下一個跳躍點，並顯示每一輪的判定。",
                    "ko": "점프 지점에서 재개하면 다음 지점까지 반복하고 매 회차 판정을 표시합니다."},
                "type": "bool", "values": on_off},
            "zdon_ai_level": {
                "path": "general/zdon_ai_level",
                "name": {"en": "AI Level", "ja": "AI のレベル", "zh": "AI 等級", "ko": "AI 레벨"},
                "description": {
                    "en": "The AI battle opponent, 1 (gentle) to 10 (sharp). Goes up 1 when you win, down 1 when you lose.",
                    "ja": "AIバトルの相手の強さ（1〜10）。勝つと 1 上がり、負けると 1 下がります。",
                    "zh": "AI 對戰對手的強度（1～10）。獲勝升 1 級，落敗降 1 級。",
                    "ko": "AI 배틀 상대의 강함(1~10). 이기면 1 오르고, 지면 1 내려갑니다."},
                "type": "int", "values": {str(i): {"en": "Lv." + str(i)} for i in range(1, 11)}},
            "zdon_song_progress": {
                "path": "general/zdon_song_progress",
                "name": {"en": "Song Progress", "ja": "曲の進行バー", "zh": "歌曲進度條", "ko": "곡 진행 바"},
                "description": {
                    "en": "Shows a progress bar under the lane, with the GOGO sections marked.",
                    "ja": "レーンの下に進行バーを表示します（ゴーゴータイムに色付け）。",
                    "zh": "在音符軌道下方顯示進度條，並標出 GOGO 段落。",
                    "ko": "레인 아래에 진행 바를 표시합니다 (고고 타임 표시)."},
                "type": "bool", "values": on_off},
        }
        t["general"]["options"] = {}
        for k, o in opts.items():
            t["general"]["options"][k] = o
            if k == "judge_counter":
                t["general"]["options"].update(extra)
    _write_json(os.path.join(ctx.G, "settings_template.json"), t)
    return 1


def build_scripts(ctx):
    for rel in SCRIPTS:
        src = ancestor_script(rel)
        if src is None:
            raise SystemExit(f"v2_standalone: no ancestor has Scripts/{rel}")
        with open(src, encoding="utf-8") as f:
            s = f.read()
        for a, b in SCRIPT_SUBS.get(rel, []):
            if a not in s:
                raise SystemExit(f"v2_standalone: patch target not found in {src}: {a!r}")
            s = s.replace(a, b)
        dst = os.path.join(ctx.scripts, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, "w", encoding="utf-8", newline="\n") as f:
            f.write("-- YataiDONSimpleStyle v2 standalone: copied from the nearest ancestor at build time "
                    "(ss/v2_standalone.py), colours in our ink\n" + s)
    return len(SCRIPTS)


def build_bases(ctx):
    farthest = ANCESTORS[-1][2]   # the ancestor whose copy the extenders were written against
    for dst_rel, src_rel in BASES.items():
        src = os.path.join(farthest, src_rel)
        dst = os.path.join(ctx.scripts, dst_rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(src, encoding="utf-8") as f:
            body = f.read()
        with open(dst, "w", encoding="utf-8", newline="\n") as f:
            f.write(f"-- YataiDONSimpleStyle v2 standalone: base of Scripts/{src_rel}, copied at build time "
                    "(ss/v2_standalone.py)\n" + body)
    for rel, (where, old, new) in EXTENDERS.items():
        dst = os.path.join(ctx.scripts, rel)
        src = dst if where == "own" else os.path.join(ANCESTORS[0][2], rel)
        with open(src, encoding="utf-8") as f:
            s = f.read()
        if new in s and old not in s:
            continue   # an --only rebuild of this module: our own file is already patched
        if old not in s:
            raise SystemExit(f"v2_standalone: parent loader not found in {src}: {old!r}")
        s = s.replace(old, OWN_BASE_LOADER + new)
        with open(dst, "w", encoding="utf-8", newline="\n") as f:
            f.write(s)
    return len(BASES) + len(EXTENDERS)


# ---------------------------------------------------------------- text_config.json (our own strings)
def _t(ja, en, zh=None, ko=None):
    d = {"ja": ja, "en": en}
    if zh:
        d["zh"] = zh
    if ko:
        d["ko"] = ko
    return {"text": d}


def _at(entry, **pos):
    """positions are LOGICAL (1920x1080), font_size an int"""
    entry.update(pos)
    return entry


TEXT = {
    # control guide (engine Indicator)
    "indicator_text": _at(_t("フチでえらんで       面で決定", "Rim: move           Face: OK",
                             "鼓邊：選擇          鼓面：決定", "테두리: 선택       면: 결정"), x=169.5, font_size=39),
    "indicator_text_skip": _at(_t("面をたたいてスキップ", "Hit the face to skip", "敲鼓面跳過", "면을 쳐서 스킵"),
                               x=232.5, font_size=39),
    "indicator_text_cancel": _at(_t("りょうほうの フチで もどる", "Both rims: back", "敲兩側鼓邊返回", "양쪽 테두리: 돌아가기"),
                                 x=180.0, font_size=39),
    "indicator_text_wait": _at(_t("ちょっと まってね", "One moment...", "請稍等", "잠깐만 기다려 줘"), x=247.5, font_size=39),
    # entry boards (an empty label hides its board, so every one is set)
    "entry_game": _t("演奏ゲーム", "Play", "演奏遊戲", "연주 게임"),
    "entry_practice": _t("特訓モード", "Practice", "特訓模式", "특훈 모드"),
    "entry_settings": _t("ゲーム設定", "Settings", "遊戲設定", "게임 설정"),
    "entry_ai_battle": _t("AIバトル", "AI Battle", "AI對戰", "AI 배틀"),
    "entry_record": _t("録画モード", "Recording", "錄影模式", "녹화 모드"),   # Z-DON recording mode (RECORD_SELECT)
    "entry_record_comment_1": _t("えらんだ曲を 動画に", "Turn a song and course", "把選好的歌曲和難度", "고른 곡과 난이도를"),
    "entry_record_comment_2": _t("書き出せるよ！", "into a video!", "匯出成影片！", "영상으로 저장!"),
    "entry_costume": _t("きせかえ", "Costume", "裝扮", "옷 갈아입기"),
    "entry_game_desc": _t("すきな 曲と むずかしさで\nあそべるよ！", "Pick a song and a course\nand play!",
                          "選喜歡的歌曲和難度\n來演奏吧！", "좋아하는 곡과 난이도로\n플레이!"),
    "entry_dan_desc": _t("段位道場で うでだめし！\n段位を めざそう", "Test your skill in the dan\ncourses!",
                         "在段位道場試試身手，\n衝擊段位吧！", "단위도장에서 실력을\n시험해 보자!"),
    "entry_practice_desc": _t("早送り・巻き戻し・テンポ変更で\nじっくり 特訓できるよ！",
                              "Fast-forward, rewind and\nslow down to practise!",
                              "快進、倒帶、變速，\n慢慢特訓！", "빨리감기·되감기·템포 변경으로\n차근차근 특훈!"),
    "entry_costume_desc": _t("きせかえで\nイメチェンしよう！", "Dress up your\ncharacter!", "換上新裝扮吧！", "옷을 갈아입혀 보자!"),
    "entry_settings_desc": _t("あそびかたや 画面の\nせっていを かえるよ", "Change how the game\nplays and looks",
                              "更改遊戲和畫面設定", "게임과 화면 설정을\n바꿔요"),
    "entry_name_confirm": _t("この なまえで いい？", "Use this name?", "用這個名字嗎？", "이 이름으로 할까?"),
    "entry_name_yes": _t("はい", "Yes", "是", "예"),
    "entry_name_no": _t("いいえ", "No", "否", "아니요"),
    "entry_name_back": _t("もどる", "Back", "返回", "뒤로"),
    "entry_name_done": _t("できた", "Done", "完成", "완료"),
    "entry_name_title": _t("なまえを えらんでね", "Pick a name", "請選擇名字", "이름을 골라 줘"),
    "entry_costume_text_head": _t("あたまを えらんでね", "Pick a head", "選擇頭部", "머리를 골라 줘"),
    "entry_costume_text_body": _t("からだを えらんでね", "Pick a body", "選擇身體", "몸을 골라 줘"),
    "entry_costume_text_suit": _t("きぐるみを えらんでね", "Pick a suit", "選擇玩偶裝", "인형옷을 골라 줘"),
    "entry_1p": _at(_t("左で あそぶ", "Left side", "使用左側", "왼쪽으로"), x=234.0, y=60.0, font_size=39),
    "entry_2p": _at(_t("右で あそぶ", "Right side", "使用右側", "오른쪽으로"), x=148.5, y=60.0, font_size=39),
    "entry_wait": _at(_t("太鼓をたたいてスタート！", "Hit the drum to start!", "敲太鼓開始！", "북을 쳐서 시작!"),
                      x=376.5, y=307.5, font_size=49),
    "entry_question": _at(_t("どっちで あそぶ？", "Which side?", "用哪一側？", "어느 쪽으로 할까?"),
                          x=954.0, y=214.5, font_size=49),
    # song select options (演奏オプション): standard game terms
    "modifier_name_auto": _t("オート", "Auto", "自動", "오토"),
    "modifier_name_speed": _t("はやさ", "Speed", "速度", "속도"),
    "modifier_name_display": _t("ドロン", "Display", "隱身", "도론"),
    "modifier_name_inverse": _t("あべこべ", "Inverse", "顛倒", "아베코베"),
    "modifier_name_random": _t("ランダム", "Random", "隨機", "랜덤"),
    "modifier_text_true": _t("する", "On", "開", "켬"),
    "modifier_text_false": _t("しない", "Off", "關", "끔"),
    "modifier_text_kimagure": _t("きまぐれ", "Kimagure", "隨意", "기마구레"),
    "modifier_text_detarame": _t("でたらめ", "Detarame", "亂打", "데타라메"),
    "leaderboard_title": _t("じこベスト", "My Best", "個人最佳", "개인 최고"),
    "box_back_text": _at(_t("もどる", "Back", "返回", "뒤로"), x=70.5, y=259.5, font_size=60),
    "diff_tower_easy": _t("かんたん", "Easy", "簡單", "쉬움"),
    "diff_tower_normal": _t("ふつう", "Normal", "普通", "보통"),
    "diff_tower_hard": _t("むずかしい", "Hard", "困難", "어려움"),
    "diff_tower_oni": _t("おに", "Oni", "魔王", "오니"),
    "diff_tower_ura": _t("おに", "Ura", "裏魔王", "우라"),
    # dan exams
    "dan_exam_label_gauge": _t("魂ゲージ", "Soul Gauge", "魂槽", "혼 게이지"),
    "dan_exam_label_judgeperfect": _t("良の数", "Good", "良數", "양 수"),
    "dan_exam_label_judgegood": _t("可の数", "OK", "可數", "가 수"),
    "dan_exam_label_judgebad": _t("不可の数", "Bad", "不可數", "불가 수"),
    "dan_exam_label_combo": _t("コンボ数", "Combo", "連擊數", "콤보 수"),
    "dan_exam_label_renda": _t("連打数", "Drumroll", "連打數", "연타 수"),
    "dan_exam_label_hit": _t("たたけた数", "Hits", "擊中數", "친 수"),
    "dan_exam_label_score": _t("スコア", "Score", "分數", "점수"),
    "dan_game_total_notes_text": _at(_t("のこり音符", "Notes left", "剩餘音符", "남은 음표"),
                                     x=222.0, y=748.5, width=276.0, font_size=54, outline=4.0),
    "dan_exam_text_more": _t("%s 以上", "%s or more", "%s 以上", "%s 이상"),
    # practice menu
    "practice_menu_end_game": _t("ゲームをおわる", "Quit", "結束遊戲", "게임 종료"),
    "practice_menu_another_song": _t("ほかの曲にする", "Another song", "換一首歌", "다른 곡"),
    "practice_menu_restart": _t("さいしょから", "From the top", "從頭開始", "처음부터"),
    "practice_menu_auto_play": _t("オート演奏", "Auto play", "自動演奏", "오토 연주"),
    "practice_menu_jump_to_mark": _t("ジャンプポイントへ", "Go to mark", "跳到標記", "마크로 이동"),
    "practice_menu_set_mark": _t("ジャンプポイントをおく", "Set mark", "設定標記", "마크 설정"),
    "practice_menu_close": _t("メニューをとじる", "Close", "關閉選單", "메뉴 닫기"),
    "practice_menu_confirm_end": _t("特訓モードを おわる？", "Leave practice?", "結束特訓嗎？", "특훈을 끝낼까?"),
    "practice_menu_confirm_another": _t("ほかの曲に する？", "Pick another song?", "換一首歌嗎？", "다른 곡으로 할까?"),
    "practice_menu_confirm_restart": _t("さいしょから 演奏する？", "Start over?", "從頭演奏嗎？", "처음부터 할까?"),
    "practice_menu_confirm_auto": _t("オート演奏を せっていするよ", "Set auto play", "設定自動演奏", "오토 연주 설정"),
    "practice_menu_yes": _t("はい", "Yes", "是", "예"),
    "practice_menu_no": _t("いいえ", "No", "否", "아니요"),
    "practice_menu_auto_on": _t("ON", "ON", "ON", "ON"),
    "practice_menu_auto_off": _t("OFF", "OFF", "OFF", "OFF"),
    # card / network messages (arcade builds)
    "network_msg_clear_reading": _t("通信中…", "Connecting..."),
    "network_msg_clear_reading_ok": _t("よみこみ せいこう！\nカードの とりわすれに 気をつけてね",
                                       "Read OK!\nRemember to take your card."),
    "network_msg_error_reading_ng": _t("よみこみに しっぱいしました\nカードの とりわすれに 気をつけてね",
                                       "Read failed.\nRemember to take your card."),
    "network_msg_error_data_ban": _t("このデータは つかえません\nカードサイトに おといあわせください",
                                     "This data cannot be used.\nPlease contact the card site."),
    "network_msg_error_disconnect": _t("オフラインのため カードは つかえません\nカードを おとりください",
                                       "Offline: cards cannot be used.\nPlease take your card."),
    "network_msg_error_assign_limit": _t("これいじょう タッチできません\nカードを おとりください",
                                         "No more cards can be added.\nPlease take your card."),
    "network_msg_error_cannot_assign": _t("このデータは もう よみこんでいます\nカードを おとりください",
                                          "This data is already loaded.\nPlease take your card."),
    "network_msg_notice_pickup_card": _t("カードの とりわすれに 注意！", "Don't forget your card!"),
    "network_msg_clear_reading_maybe": _t("通信中…\n~通信状態によっては プレイデータの更新が おくれることがあります",
                                          "Connecting...\n~Play data may update late on a slow connection."),
    "network_msg_error_lost_card": _t("しっかり タッチしてね", "Please hold the card still."),
    "network_msg_error_userdata": _t("プレイデータを うけとれませんでした\nオフラインモードに きりかえます",
                                     "Could not load play data.\nSwitching to offline mode."),
    "network_msg_error_already_gasha": _t("ガシャは きょう もう まわしたよ\n~※ガシャは 1日1回です",
                                          "You already spun today.\n~*One spin per day."),
    "network_msg_error_not_play": _t("まだ 一度も あそんでいないよ\n~※あたらしいカードは 一度あそんでから つかえます",
                                     "Play a game first.\n~*New cards need one play first."),
    "network_msg_error_touch_again": _t("もう一度 しっかり タッチしてね", "Please touch the card again."),
    "network_msg_error_close_shop": _t("まもなく 閉店時間です\n閉店後は ガシャが できません",
                                       "Closing time is near.\nThe gacha closes with the shop."),
    "network_msg_error_offline_gasha": _t("オフラインのため 大会ガシャは できません\nネットワークを たしかめてください",
                                          "Offline: no event gacha.\nPlease check the network."),
    "network_msg_error_card_gasha": _t("カードが つかえないため 大会ガシャは できません\nカードリーダーを たしかめてください",
                                       "Card unavailable: no event gacha.\nPlease check the card reader."),
    "network_msg_error_end_gasha": _t("大会ガシャは おわりました\n~※もとに もどすには テストモードで 大会ガシャを OFF にしてください",
                                      "The event gacha has ended.\n~*Turn it OFF in test mode to return to normal."),
    "network_msg_error_bnid": _t("このIDは つかえません", "This ID cannot be used."),
    "network_msg_error_shop_already": _t("もう もっているよ\n~ごほうびの じょうたいを 更新しました",
                                         "You already have this.\n~Rewards updated."),
    "network_msg_error_shop_failed": _t("通信に しっぱいしました\n~ごほうびを もらえていないかもしれません\n~サイトで たしかめてください",
                                        "Connection failed.\n~The reward may be missing.\n~Please check online."),
    "network_msg_error_shop_shortage": _t("メダルが たりません\n~メダルの数を 更新しました",
                                          "Not enough medals.\n~Medal count updated."),
    "network_msg_shop_get_OK": _t("ごほうびを ゲット！\n~きせかえは 次のプレイから つかえるよ",
                                  "Reward get!\n~New costumes are usable from your next play."),
    "network_msg_error_offline_shop": _t("通信エラーが おきました\n~ショップを とじて オフラインモードに きりかえます",
                                         "Connection error.\n~Closing the shop and going offline."),
}

# zh (Traditional) / ko for the card / network messages (Green had none, so these were blank in zh / ko)
NETWORK_ZH_KO = {
    "network_msg_clear_reading": ("通訊中…", "통신 중…"),
    "network_msg_clear_reading_ok": ("讀取成功！\n別忘了取回卡片哦", "읽기 성공!\n카드를 잊지 말고 챙겨 가세요"),
    "network_msg_error_reading_ng": ("讀取失敗\n別忘了取回卡片哦", "읽기에 실패했습니다\n카드를 잊지 말고 챙겨 가세요"),
    "network_msg_error_data_ban": ("此資料無法使用\n請聯絡卡片網站", "이 데이터는 사용할 수 없습니다\n카드 사이트에 문의해 주세요"),
    "network_msg_error_disconnect": ("離線中，無法使用卡片\n請取回卡片", "오프라인이라 카드를 쓸 수 없습니다\n카드를 빼 주세요"),
    "network_msg_error_assign_limit": ("無法再新增卡片\n請取回卡片", "더 이상 터치할 수 없습니다\n카드를 빼 주세요"),
    "network_msg_error_cannot_assign": ("此資料已經讀取過了\n請取回卡片", "이 데이터는 이미 읽었습니다\n카드를 빼 주세요"),
    "network_msg_notice_pickup_card": ("別忘了取回卡片！", "카드를 잊지 마세요!"),
    "network_msg_clear_reading_maybe": ("通訊中…\n~網路狀況不佳時，遊玩資料可能延遲更新",
                                        "통신 중…\n~통신 상태에 따라 플레이 데이터 갱신이 늦어질 수 있습니다"),
    "network_msg_error_lost_card": ("請好好貼住卡片", "카드를 확실히 대 주세요"),
    "network_msg_error_userdata": ("無法取得遊玩資料\n切換為離線模式", "플레이 데이터를 받지 못했습니다\n오프라인 모드로 전환합니다"),
    "network_msg_error_already_gasha": ("今天已經抽過扭蛋了\n~※扭蛋每天一次", "오늘은 이미 뽑기를 했어요\n~※뽑기는 하루 1회입니다"),
    "network_msg_error_not_play": ("還沒有玩過一次哦\n~※新卡片需要先遊玩一次才能使用",
                                   "아직 한 번도 플레이하지 않았어요\n~※새 카드는 한 번 플레이한 뒤 쓸 수 있습니다"),
    "network_msg_error_touch_again": ("請再好好貼一次卡片", "한 번 더 카드를 확실히 대 주세요"),
    "network_msg_error_close_shop": ("即將到達打烊時間\n打烊後無法抽扭蛋", "곧 폐점 시간입니다\n폐점 후에는 뽑기를 할 수 없습니다"),
    "network_msg_error_offline_gasha": ("離線中，無法進行大會扭蛋\n請檢查網路",
                                        "오프라인이라 대회 뽑기를 할 수 없습니다\n네트워크를 확인해 주세요"),
    "network_msg_error_card_gasha": ("卡片無法使用，無法進行大會扭蛋\n請檢查讀卡器",
                                     "카드를 쓸 수 없어 대회 뽑기를 할 수 없습니다\n카드 리더를 확인해 주세요"),
    "network_msg_error_end_gasha": ("大會扭蛋已結束\n~※要恢復原狀，請在測試模式中將大會扭蛋設為 OFF",
                                    "대회 뽑기가 끝났습니다\n~※원래대로 돌리려면 테스트 모드에서 대회 뽑기를 OFF로 해 주세요"),
    "network_msg_error_bnid": ("此ID無法使用", "이 ID는 사용할 수 없습니다"),
    "network_msg_error_shop_already": ("已經擁有了哦\n~已更新獎勵狀態", "이미 가지고 있어요\n~보상 상태를 갱신했습니다"),
    "network_msg_error_shop_failed": ("通訊失敗\n~可能沒有拿到獎勵\n~請在網站上確認",
                                      "통신에 실패했습니다\n~보상을 받지 못했을 수 있습니다\n~사이트에서 확인해 주세요"),
    "network_msg_error_shop_shortage": ("獎牌不足\n~已更新獎牌數量", "메달이 부족합니다\n~메달 수를 갱신했습니다"),
    "network_msg_shop_get_OK": ("獲得獎勵！\n~換裝從下次遊玩開始可以使用哦", "보상 획득!\n~옷 갈아입기는 다음 플레이부터 쓸 수 있어요"),
    "network_msg_error_offline_shop": ("發生通訊錯誤\n~關閉商店並切換為離線模式",
                                       "통신 오류가 발생했습니다\n~상점을 닫고 오프라인 모드로 전환합니다"),
}
for _k, (_zh, _ko) in NETWORK_ZH_KO.items():
    TEXT[_k]["text"].setdefault("zh", _zh)
    TEXT[_k]["text"].setdefault("ko", _ko)


def build_text_config(ctx):
    """Our text_config.json. Nijiiro keeps its texts in its skin_config (the engine reads them under
    ours); only the keys no nearer skin defines are written, so ours take precedence by construction.
    The skin's own Lua strings (ss/strings.py, keys `ss_*`, read by UI.t) are merged in: one output file."""
    from . import strings
    own = strings.text_config()
    clash = sorted(set(own) & set(TEXT))
    if clash:
        raise SystemExit(f"text_config: ss/strings.py keys clash with v2_standalone TEXT: {clash}")
    _write_json(os.path.join(ctx.out, "text_config.json"), {**TEXT, **own})
    return 1


def build_fonts(ctx):
    if ctx.density > 1:
        return 0   # Z-DON: the debug menu falls back to Fonts/font.ttf (debug_menu.h): no 2 x 7 MB copies
    src = os.path.join(ctx.out, "Fonts", "font.ttf")
    for n in ("debug_ui.ttf", "debug_code.ttf"):
        shutil.copy2(src, os.path.join(ctx.out, "Fonts", n))
    return 2


# Green-only skin_config entries (Green 1280x720 values x1.5 = what the engine used under us), pinned so
# the stub's numbers never matter. font_size: static_cast<int>(v * 1.5).
# Keys a screen module sets itself are NOT pinned here: this module merges last, so a pin would overwrite
# the module's value (game_song_info / _subtitle -> v2_game's title band, song_select_box_name ->
# v2_song_select). Our skin_config defines them, so the stub's numbers are never read for them either.
GREEN_ONLY_CONFIG = {
    "entry_box_text": {"font_size": 75},
    "entry_box_spacing": {"x": 120.0},
    "song_select_box_bg": {"width": 48.0},
    "transition_offset": {"y": 1224.0},
    "game_practice_progress_bar_width": {"width": 1335.0},
    "game_drumroll_width_offset": {"width": -70.5},
    "game_balloon_offset": {"x": 18.0},
    "game_balloon_pop_shake": {"x": 1.5},
    "game_song_timer": {"x": 28.5, "y": 264.0, "width": 402.0, "height": 10.5},
    "game_gauge_2p_offset": {"y": 342.0},
    "game_score_counter_2p_y_offset": {"y": 195.0},
    "game_combo_announce_p2_y_offset": {"y": 564.0},
    "song_select_genre_bg_boundary": {"x": 663.0, "width": 1252.5},
    "game_branch_indicator_y_offset": {"y": 72.0},
    "game_p2_y": {"y": 540.0},
    "game_gogo_explosion_tilt": {"x": 9.0},
    "chara_3d": {"scale": 650.0, "rot_x": 181.25, "rot_y": 27.5, "rot_z": 0,
                 "game_p2": [240.0, 558.0], "game_balloon": [630.0, 180.0]},
    "screen": {"options": {"crop_result_screenshot": True, "loading_countdown": False}},
}


def skin_config(ctx):
    return json.loads(json.dumps(GREEN_ONLY_CONFIG))


def build(ctx):
    n = build_animations(ctx)
    n += build_settings_template(ctx)
    n += build_scripts(ctx)
    n += build_bases(ctx)
    n += build_text_config(ctx)
    n += build_fonts(ctx)
    n += v2_sound.write_all(os.path.join(ctx.out, "Sounds"))
    return n
