"""The skin's own strings: one table, key -> {ja, en, zh, ko}, emitted into our text_config.json as
`ss_<key>` (v2_standalone.build_text_config merges it; one output file). Lua reads them at run time in
the player's language: `UI.t(key)` (falls back ja -> en, like tex.skin_text), `UI.label(key, size, style)`,
`UI.hint(...)`, `UI.bubble(...)`. zh = Traditional Chinese (Z-DON's zh; upstream YataiDON's zh is Simplified), ko = Korean.

Rules
- Game terms follow the established ones (our text_config.json, Nijiiro's skin_config): 良/可/不可 =
  GOOD/OK/BAD = 良/可/不可 = 양/가/불가; 連打 = Roll / 连打 / 연타; コンボ = Combo / 连击 / 콤보;
  魂ゲージ = Soul Gauge / 魂槽 / 혼 게이지; courses = Easy Normal Hard Oni Ura / 简单 普通 困难 魔王 里魔王 /
  쉬움 보통 어려움 오니 오니(우라).
- Keep strings short enough for the box they live in. `wide=True` marks a string whose en / ko is
  noticeably wider than the ja box it replaces: the converted chrome must size itself to the measured
  text (UI.text_width) instead of the ja width. `note` says why / where.
- Digits and digit fonts stay baked; brand / logo art is a decision item (reports/baked_text_inventory.md).
- A string with "{0}" is a format: UI.t(key):gsub("{0}", n) (or string.format with %s where noted).

Every key is checked by check() (build.py runs it through v2_standalone): all four languages present
and non-empty."""
from __future__ import annotations

PREFIX = "ss_"


def S(ja, en, zh, ko, note=None, wide=False):
    d = {"ja": ja, "en": en, "zh": zh, "ko": ko}
    if note:
        d["_note"] = note
    if wide:
        d["_wide"] = True
    return d


STRINGS: dict[str, dict] = {
    # ---------------------------------------------------------------- hint pill (UI.hint)
    "h_select": S("えらぶ", "Select", "選擇", "선택"),
    "h_decide": S("決定", "Decide", "決定", "결정", wide=True),
    "h_back": S("もどる", "Back", "返回", "뒤로"),
    "h_option": S("オプション", "Options", "選項", "옵션"),
    "h_change": S("かえる", "Change", "更改", "변경"),
    "h_start": S("スタート", "Start", "開始", "시작"),
    "h_esc_back": S("ESC もどる", "ESC Back", "ESC 返回", "ESC 뒤로"),

    # ---------------------------------------------------------------- labels (UI.label; was ss/ui.py LABELS)
    "good": S("良", "GOOD", "良", "양", wide=True, note="one-glyph judge label in ja"),
    "ok": S("可", "OK", "可", "가"),
    "bad": S("不可", "BAD", "不可", "불가"),
    "roll": S("連打", "Roll", "連打", "연타"),
    "maxcombo": S("最大コンボ", "Max Combo", "最大連擊", "최대 콤보", wide=True),
    "acc": S("精度", "Accuracy", "精度", "정확도", wide=True),
    "bpm": S("BPM", "BPM", "BPM", "BPM"),
    "time": S("経過", "Time", "經過", "경과"),
    "offset": S("平均タイミング", "Avg Timing", "平均時機", "평균 타이밍"),
    "early": S("早", "Early", "早", "빠름", wide=True, note="one-glyph label in ja"),
    "late": S("遅", "Late", "晚", "느림", wide=True, note="one-glyph label in ja"),
    "level": S("★", "★", "★", "★"),
    "ms": S("ms", "ms", "ms", "ms"),
    "gauge": S("魂ゲージ", "Soul Gauge", "魂槽", "혼 게이지", wide=True),
    "combo": S("コンボ", "Combo", "連擊", "콤보"),
    "score": S("スコア", "Score", "分數", "점수"),
    "course0": S("かんたん", "Easy", "簡單", "쉬움"),
    "course1": S("ふつう", "Normal", "普通", "보통"),
    "course2": S("むずかしい", "Hard", "困難", "어려움"),
    "course3": S("おに", "Oni", "魔王", "오니"),
    "course4": S("おに(裏)", "Ura Oni", "裏魔王", "오니(우라)"),
    "course_tower": S("タワー", "Tower", "塔", "타워"),
    "course_dan": S("段位", "Dan", "段位", "단위"),

    # ---------------------------------------------------------------- course identity / ranks / crowns
    # score ranks: one-glyph disc badges (75 / 135 px). The glyph is the rank's mark in every Taiko
    # release (en / ko cabinets keep 粋 雅 極), so all languages keep the kanji: DECISION (keep baked).
    "rank_iki": S("粋", "粋", "粋", "粋", note="rank mark; kept as the glyph in every language (decision)"),
    "rank_miyabi": S("雅", "雅", "雅", "雅", note="rank mark; kept as the glyph in every language (decision)"),
    "rank_kiwami": S("極", "極", "極", "極", note="rank mark"),
    "zenryo": S("全良", "All Good", "全良", "올 양", wide=True, note="全良 chip: 72 px in ja, 126 px in en"),
    "full_combo": S("フルコンボ", "Full Combo", "全連擊", "풀 콤보", wide=True),
    "clear": S("クリア", "Clear", "通關", "클리어"),
    "best": S("自己ベスト更新", "New Best!", "重新整理個人最佳", "개인 최고 갱신"),
    "score_shinuchi": S("真打スコア", "Shin-uchi Score", "真打分數", "신우치 점수", wide=True),
    "judge_breakdown": S("判定の内訳", "Judgements", "判定明細", "판정 내역"),
    "player_1p": S("1P", "1P", "1P", "1P"),
    "player_2p": S("2P", "2P", "2P", "2P"),
    "ai": S("AI", "AI", "AI", "AI"),
    "computer": S("コンピュータ", "Computer", "電腦", "컴퓨터"),

    # ---------------------------------------------------------------- front: title / entry / settings / loading
    "title_invite": S("いっしょに たたこう！", "Let's drum together!", "一起來打鼓吧！", "같이 두드리자!", wide=True),
    "warn_title": S("ちゅうい", "Caution", "注意", "주의"),
    "warn_line1": S("まわりの人に あたらないように", "Mind the people around you,", "小心不要碰到周圍的人，",
                    "주변 사람에게 부딪히지 않도록", wide=True),
    "warn_line2": S("すこし はなれて あそんでね。", "keep a little space.", "請保持一點距離。", "조금 떨어져서 놀아 줘."),
    "warn_line3": S("ゆびわや アクセサリーは はずそう。", "Take off rings and accessories.", "請摘下戒指和飾品。",
                    "반지나 액세서리는 빼 두자.", wide=True),
    "warn_line4": S("バチは 太鼓だけを たたいてね。", "Hit only the drum with the sticks.", "鼓棒只能敲太鼓哦。",
                    "북채로는 북만 두드려 줘.", wide=True),
    "entry_player": S("プレイヤー エントリー", "Player Entry", "玩家登入", "플레이어 엔트리"),
    "entry_name": S("なまえを きめよう", "Choose your name", "來取個名字吧", "이름을 정하자", wide=True),
    "entry_start_don": S("ドン！で スタート", "Hit Don! to start", "敲咚！開始", "쿵! 으로 시작", wide=True),
    "settings_title": S("せってい", "Settings", "設定", "설정"),
    "settings_pick": S("こうもくを えらんでね", "Pick an item", "請選擇專案", "항목을 골라 줘"),
    "settings_howto": S("ドンで ひらいて、あたいを かえよう。", "Don opens it; change the value.",
                        "敲咚開啟，更改數值吧。", "쿵으로 열고 값을 바꾸자.", wide=True),
    "loading": S("よみこみちゅう…", "Loading…", "讀取中…", "불러오는 중…"),

    # ---------------------------------------------------------------- game: lane, notes, judgements, branch
    "auto": S("オート", "Auto", "自動", "오토"),
    "note_don": S("ドン", "Don", "咚", "쿵"),
    "note_do": S("ド", "Do", "咚", "쿵", note="small don in a pattern (ドコ)"),
    "note_ko": S("コ", "Ko", "咚", "쿵", note="second small don in a pattern (ドコ)"),
    "note_ka": S("カッ", "Ka", "咔", "딱"),
    "note_ka_small": S("カ", "Ka", "咔", "딱", note="small ka in a pattern"),
    "note_don_big": S("ドン(大)", "DON", "咚(大)", "쿵(대)", note="big note: en uses capitals"),
    "note_ka_big": S("カッ(大)", "KA", "咔(大)", "딱(대)", note="big note: en uses capitals"),
    "note_roll": S("連打", "Roll", "連打", "연타"),
    "note_roll_big": S("連打(大)", "ROLL", "連打(大)", "연타(대)"),
    "note_balloon": S("ふうせん", "Balloon", "氣球", "풍선"),
    "note_kusudama": S("くすだま", "Kusudama", "綵球", "쿠스다마", wide=True),
    "note_tsu": S("っ!!", "!!", "!!", "!!", note="tail of the big-note call (ドン っ!!)"),
    "balloon_left": S("あと", "Left", "還剩", "남은", note="balloon counter label: 'あと N'"),
    "branch_normal": S("普通譜面", "Normal", "普通譜面", "보통 보면"),
    "branch_expert": S("玄人譜面", "Expert", "玄人譜面", "현인 보면"),
    "branch_master": S("達人譜面", "Master", "達人譜面", "달인 보면"),
    "branch_up": S("譜面アップ!", "Level Up!", "譜面升級!", "보면 업!"),
    "branch_down": S("譜面ダウン", "Level Down", "譜面降級", "보면 다운", wide=True),
    "branch_mark": S("分", "Br", "分", "분", note="one-glyph 'has branches' mark on the song box"),
    "ura_mark": S("裏", "Ura", "裏", "우라", wide=True, note="one-glyph ura mark on the song box"),
    "combo_word": S("コンボ", "Combo", "連擊", "콤보", note="under the combo digits"),
    "combo_announce": S("コンボ!", "Combo!", "連擊!", "콤보!"),
    "soul": S("魂", "Soul", "魂", "혼", wide=True, note="gauge end cap glyph"),
    "end_clear": S("クリア!", "Clear!", "通關!", "클리어!"),
    "end_fail": S("クリア失敗", "Failed", "未通關", "클리어 실패"),
    "end_full_combo": S("フルコンボ!", "Full Combo!", "全連擊!", "풀 콤보!", wide=True),
    "end_donderful": S("ぜんぶ良!", "All Good!", "全良!", "올 양!"),
    "mod_inverse": S("逆", "Inv", "反", "반", note="lane modifier icon (あべこべ)"),
    "mod_random": S("乱", "Rnd", "亂", "랜", note="lane modifier icon (でたらめ)"),
    "mod_kimagure": S("気", "Kim", "隨", "기", note="lane modifier icon (きまぐれ)"),
    "mod_hidden": S("隠", "Hid", "隱", "숨", note="lane modifier icon (ドロン)"),
    "mod_inverse_sel": S("反", "Inv", "反", "반", note="song-select modifier icon"),
    "mod_auto_sel": S("自", "Auto", "自", "자", wide=True, note="song-select modifier icon"),
    "mod_doron_sel": S("ド", "Hid", "隱", "숨", note="song-select modifier icon"),
    "opt_inverse": S("あべこべ", "Inverse", "顛倒", "아베코베"),
    "opt_detarame": S("でたらめ", "Detarame", "亂打", "데타라메", wide=True),
    "opt_doron": S("ドロン", "Doron", "隱身", "도론"),
    "opt_kimagure": S("きまぐれ", "Kimagure", "隨意", "기마구레", wide=True),
    "skip": S("演奏スキップ", "Skip Song", "跳過演奏", "연주 스킵"),
    "skip_used": S("演奏スキップをつかいました", "Used Skip Song", "使用了跳過演奏", "연주 스킵을 사용했습니다"),
    "kusudama_hint": S("連打で わろう!", "Roll to break it!", "連打擊破吧!", "연타로 깨자!", wide=True),
    # AI battle
    "ai_win": S("勝", "W", "勝", "승", note="AI battle section mark"),
    "ai_lose": S("負", "L", "負", "패", note="AI battle section mark"),
    # practice (engine C++ textures: per-language variants)
    "pr_menu": S("メニュー", "Menu", "選單", "메뉴"),
    "pr_menu_panel": S("とっくんメニュー", "Practice Menu", "特訓選單", "특훈 메뉴", wide=True),
    "pause_menu": S("メニュー", "Menu", "選單", "메뉴", note="the in-song pause menu (Esc) title; practice keeps pr_menu_panel"),
    "pr_pause": S("一時停止", "Pause", "暫停", "일시정지"),
    "pr_resume": S("さいかい", "Resume", "繼續", "재개"),
    "pr_back": S("もどる", "Back", "後退", "뒤로"),
    "pr_forward": S("すすむ", "Forward", "前進", "앞으로", wide=True),
    "pr_slower": S("おそく", "Slower", "減速", "느리게"),
    "pr_faster": S("はやく", "Faster", "加速", "빠르게"),
    "pr_confirm": S("けってい", "OK", "決定", "결정"),
    "pr_delete": S("けす", "Delete", "刪除", "삭제", wide=True),
    "pr_finish": S("おわる", "Finish", "結束", "끝내기"),
    "pr_bar": S("小節", "Bar", "小節", "마디"),
    "pr_tempo": S("曲テンポ", "Tempo", "歌曲速度", "곡 템포"),
    "pr_times": S("倍", "x", "倍", "배", note="after the speed digits: '1.5倍'"),
    "pr_jump_edit": S("ジャンプポイント へんしゅう中", "Editing jump points", "正在編輯跳躍點", "점프 포인트 편집 중",
                      wide=True),
    "pr_mode": S("特訓", "Practice", "特訓", "특훈", wide=True, note="practice timer chip"),
    "pr_left": S("のこり", "Left", "剩餘", "남은 시간"),
    "pr_min": S("分", "min", "分", "분"),
    "pr_sec": S("秒", "s", "秒", "초"),
    "pr_timeup": S("じかんぎれ！", "Time's up!", "時間到！", "시간 종료!"),

    # ---------------------------------------------------------------- dan (段位道場)
    "dan_dojo": S("段位道場", "Dan-i Dojo", "段位道場", "단위도장", wide=True),
    "dan_all_songs": S("全曲", "All", "全曲", "전곡"),
    "dan_song_1": S("1曲目", "Song 1", "第1首", "1곡째", wide=True),
    "dan_song_2": S("2曲目", "Song 2", "第2首", "2곡째", wide=True),
    "dan_song_3": S("3曲目", "Song 3", "第3首", "3곡째", wide=True),
    "dan_song_n": S("曲目", "Song", "首", "곡째", note="suffix after a song number"),
    "dan_total": S("全体", "Total", "全體", "전체"),
    "dan_failed": S("達成失敗", "Failed", "未達成", "달성 실패"),
    "dan_unreached": S("未到達", "Not reached", "未達到", "미도달", wide=True),
    "dan_ex_gauge": S("魂ゲージ", "Soul Gauge", "魂槽", "혼 게이지", wide=True),
    "dan_ex_good": S("良の数", "GOOD", "良數", "양 수"),
    "dan_ex_ok": S("可の数", "OK", "可數", "가 수"),
    "dan_ex_bad": S("不可の数", "BAD", "不可數", "불가 수"),
    "dan_ex_combo": S("最大コンボ数", "Max Combo", "最大連擊數", "최대 콤보 수"),
    "dan_ex_roll": S("連打数", "Rolls", "連打數", "연타 수"),
    "dan_ex_hit": S("叩けた数", "Hits", "擊中數", "친 수"),
    "dan_ex_score": S("スコア", "Score", "分數", "점수"),
    "dan_less": S("未満", "under", "未滿", "미만"),
    "dan_more": S("以上", "or more", "以上", "이상", wide=True),
    "dan_fmt_less": S("%s 未満", "under %s", "%s 未滿", "%s 미만", note="string.format"),
    "dan_fmt_more": S("%s 以上", "%s or more", "%s 以上", "%s 이상", wide=True, note="string.format"),
    "dan_gold_more": S("金合格 {0}%以上", "Gold: {0}% or more", "金合格 {0}%以上", "금합격 {0}% 이상", wide=True,
                       note="dan select gauge row; {0} = percent"),
    "dan_notes_left": S("のこり音符", "Notes left", "剩餘音符", "남은 음표"),
    "dan_total_notes": S("総ノーツ数", "Total notes", "總音符數", "총 노트 수", wide=True),
    "dan_conditions": S("合格条件", "To pass", "合格條件", "합격 조건"),
    "dan_pass": S("合格", "Pass", "合格", "합격"),
    "dan_pass_gold": S("金合格", "Gold Pass", "金合格", "금합격", wide=True),
    "dan_pass_mark": S("合", "P", "合", "합", note="one-glyph 合格 mark on the dan box"),
    "dan_unplayed": S("未", "–", "未", "미", note="one-glyph 'not played' mark"),
    "dan_hidden_title": S("？？？", "???", "？？？", "???"),
    "dan_song_label": S("曲目", "Song", "曲目", "곡"),
    "dan_confirm": S("この段位に挑戦しますか？", "Take on this dan?", "要挑戰這個段位嗎？", "이 단위에 도전할까요?"),
    "dan_yes": S("挑戦する", "Go!", "挑戰", "도전"),
    "dan_no": S("やめる", "Cancel", "取消", "그만두기", wide=True),
    "dan_congrats": S("おめでとう！", "Congratulations!", "恭喜！", "축하해!", wide=True),
    "dan_promo": S("昇段", "Promoted", "升段", "승단", wide=True),
    "dan_top": S("合格！ さいこうの だんいに とうたつしました！", "Passed! You reached the top dan!",
                 "合格！ 達到了最高段位！", "합격! 최고 단위에 도달했어요!"),
    "dan_nosave": S("今回の挑戦は記録されません", "This attempt will not be recorded", "本次挑戰不會被記錄",
                    "이번 도전은 기록되지 않습니다"),
    # dan ranks (plates 48 px, nameplate emblems 24 px): en is Kyu / Dan words, noticeably wider
    "dan_kyu_10": S("十級", "10th Kyu", "十級", "10급", wide=True),
    "dan_kyu_9": S("九級", "9th Kyu", "九級", "9급", wide=True),
    "dan_kyu_8": S("八級", "8th Kyu", "八級", "8급", wide=True),
    "dan_kyu_7": S("七級", "7th Kyu", "七級", "7급", wide=True),
    "dan_kyu_6": S("六級", "6th Kyu", "六級", "6급", wide=True),
    "dan_kyu_5": S("五級", "5th Kyu", "五級", "5급", wide=True),
    "dan_kyu_4": S("四級", "4th Kyu", "四級", "4급", wide=True),
    "dan_kyu_3": S("三級", "3rd Kyu", "三級", "3급", wide=True),
    "dan_kyu_2": S("二級", "2nd Kyu", "二級", "2급", wide=True),
    "dan_kyu_1": S("一級", "1st Kyu", "一級", "1급", wide=True),
    "dan_shodan": S("初段", "1st Dan", "初段", "초단", wide=True),
    "dan_2": S("二段", "2nd Dan", "二段", "2단", wide=True),
    "dan_3": S("三段", "3rd Dan", "三段", "3단", wide=True),
    "dan_4": S("四段", "4th Dan", "四段", "4단", wide=True),
    "dan_5": S("五段", "5th Dan", "五段", "5단", wide=True),
    "dan_6": S("六段", "6th Dan", "六段", "6단", wide=True),
    "dan_7": S("七段", "7th Dan", "七段", "7단", wide=True),
    "dan_8": S("八段", "8th Dan", "八段", "8단", wide=True),
    "dan_9": S("九段", "9th Dan", "九段", "9단", wide=True),
    "dan_10": S("十段", "10th Dan", "十段", "10단", wide=True),
    "dan_kuroto": S("玄人", "Kuroto", "玄人", "현인", wide=True),
    "dan_meijin": S("名人", "Meijin", "名人", "명인", wide=True),
    "dan_chojin": S("超人", "Chojin", "超人", "초인", wide=True),
    "dan_tatsujin": S("達人", "Tatsujin", "達人", "달인", wide=True),
    "dan_sousaku": S("創作", "Custom", "創作", "창작", wide=True),
    "dan_gaiden": S("外伝", "Gaiden", "外傳", "외전", wide=True),
    "dan_shokyu": S("初級", "Beginner", "初級", "초급", wide=True),

    # ---------------------------------------------------------------- meta: overlays, game over, retry, transitions
    "card_ok": S("OK", "OK", "OK", "OK"),
    "status_off": S("オフ", "Off", "離線", "오프", note="offline card / QR status tile chip"),
    "dan_none": S("なし", "None", "無", "없음", note="段位道場 status chip with no rank (offline)"),
    # Z-DON timing / progress (src/libs/zdon_lua.cpp): play marks and the result timing panel
    "fast": S("はやい", "FAST", "快", "빠름"),
    "slow": S("おそい", "SLOW", "慢", "느림"),
    "res_timing": S("タイミング", "Timing", "打擊時機", "타이밍"),
    "res_avg": S("平均", "Avg", "平均", "평균"),
    "res_spread": S("ばらつき", "Spread", "穩定度", "편차"),
    "res_accuracy": S("精度", "Acc.", "精準度", "정확도"),
    "res_best": S("自己ベスト", "Best", "最佳", "최고"),
    "ds_bpm": S("BPM", "BPM", "BPM", "BPM"),
    "ds_notes": S("ノーツ", "Notes", "音符", "노트"),
    "ds_length": S("長さ", "Length", "時長", "길이"),
    # Z-DON: recent plays, practice loop, AI battle
    "ai_battle": S("AIバトル", "AI battle", "AI對戰", "AI 배틀"),
    "ai_win": S("勝ち", "WIN", "勝利", "승리"),
    "ai_lose": S("負け", "LOSE", "落敗", "패배"),
    "ai_draw": S("引き分け", "DRAW", "平局", "무승부"),
    "outfit_title": S("きせかえ", "Costume", "裝扮", "옷 갈아입기"),
    "chara_momo": S("モモ", "Momo", "桃桃", "모모"),
    "chara_hoshi": S("ホシ", "Hoshi", "小星", "호시"),
    "outfit_plain": S("いつもの", "Usual", "平常", "평소"),
    "outfit_happi": S("はっぴ", "Happi", "法被", "핫피"),
    "outfit_yukata": S("ゆかた", "Yukata", "浴衣", "유카타"),
    "outfit_school": S("せいふく", "Uniform", "制服", "교복"),
    "outfit_chef": S("コック", "Chef", "廚師", "요리사"),
    "outfit_pirate": S("かいぞく", "Pirate", "海盜", "해적"),
    "outfit_winter": S("ふゆ", "Winter", "冬裝", "겨울옷"),
    "outfit_ninja": S("にんじゃ", "Ninja", "忍者", "닌자"),
    "outfit_santa": S("サンタ", "Santa", "聖誕", "산타"),
    "outfit_idol": S("アイドル", "Idol", "偶像", "아이돌"),
    "ds_recent": S("最近のプレイ", "Recent plays", "最近遊玩", "최근 플레이"),
    "pr_loop": S("区間ループ", "Section loop", "區段循環", "구간 반복"),
    "pr_pass": S("%d周目", "Pass %d", "第%d輪", "%d회차"),
    "pr_last": S("前回", "Last pass", "上一輪", "지난 회차"),
    "per_play": S("1プレイ 4曲", "4 songs per play", "每局 4 首", "1플레이 4곡", wide=True),
    "game_hint": S("ゲームのヒント", "Hints", "遊戲提示", "게임의 힌트"),
    "timer_left": S("のこり", "Left", "剩餘", "남은"),
    "go_title": S("おつかれさま！", "Thanks for playing!", "辛苦了！", "수고했어!", wide=True),
    "go_line": S("また あそんでね！", "Come play again!", "下次再來玩哦！", "또 놀러 와!"),
    "go_cheer": S("ドンマイ！", "Don't mind!", "別在意！", "괜찮아!", note="game over: Hoshi cheers Momo up (bubble)"),
    "dot": S("・", "・", "・", "・", note="result transition stepping dots (symbol)"),
    "result_title": S("せいせき はっぴょう", "Results", "成績發表", "성적 발표"),
    "retry_rule": S("{0}回 たたいて ふっかつ！", "Hit {0} times to revive!", "敲 {0} 次就能復活！",
                    "{0}번 두드려 부활!", note="{0} = hit count"),
    "retry_ready": S("よーい…", "Ready…", "預備…", "준비…"),
    "retry_go": S("ドン！", "Don!", "咚！", "쿵!"),
    "retry_ok": S("ふっかつ成功！", "Revived!", "復活成功！", "부활 성공!"),
    "retry_ng": S("ざんねん…", "Too bad…", "可惜…", "아쉽다…"),

    # ---------------------------------------------------------------- result
    "res_bub_0": S("つぎは がんばろう！", "Next time!", "下次加油！", "다음엔 힘내자!"),
    "res_bub_1": S("おしい！ あとすこし！", "So close!", "可惜！ 就差一點！", "아깝다! 조금만 더!"),
    "res_bub_2": S("クリア！ やったね！", "Clear! Nice!", "通關！ 太好了！", "클리어! 해냈다!"),
    "res_bub_3": S("たましい まんたん！", "Soul gauge full!", "魂槽全滿！", "혼 게이지 가득!"),
    "res_bub_4": S("フルコンボ！ すごい！", "Full Combo! Wow!", "全連擊！ 好厲害！", "풀 콤보! 대단해!"),
    "res_bub_5": S("ぜんりょう！ かんぺき！", "All Good! Perfect!", "全良！ 完美！", "올 양! 완벽해!"),

    # ---------------------------------------------------------------- song select
    "sel_song": S("曲をえらぶ", "Select a song", "選擇歌曲", "곡 선택"),
    "sel_course": S("むずかしさをえらぶ", "Select difficulty", "選擇難度", "난이도 선택"),
    "sel_back": S("もどる", "Back", "返回", "뒤로"),
    "sel_options": S("オプション", "Options", "選項", "옵션"),
    "sel_neiro": S("音色", "Sound", "音色", "음색"),
    "sel_points": S("点", "pts", "分", "점"),
    # song select polish: the mascot's lines in the course select (ss_sel.lua M:say)
    "sel_say_pick": S("どれに する？", "Which one?", "選哪個？", "뭘로 할까?"),
    "sel_say_oni": S("ほんきで いくよ！", "Going all out!", "全力以赴！", "전력으로 간다!"),
    "sel_new_song": S("新曲", "NEW", "新曲", "신곡"),
    "sel_new_audio": S("新音源", "New audio", "新音源", "신음원", wide=True),
    "sel_old_audio": S("旧音源", "Old audio", "舊音源", "구음원", wide=True),
    "sel_limited": S("期間限定", "Limited", "期間限定", "기간 한정"),
    "sel_fav_1p": S("1Pのお気に入り", "1P favorite", "1P的收藏", "1P 즐겨찾기"),
    "sel_fav_2p": S("2Pのお気に入り", "2P favorite", "2P的收藏", "2P 즐겨찾기"),

    # ---------------------------------------------------------------- stage: the buddy's speech lines (UI.bubble)
    "say_start_0": S("いくよー！", "Here we go!", "要開始啦！", "간다~!"),
    "say_start_1": S("リズムに のって！", "Feel the rhythm!", "跟上節奏！", "리듬을 타자!"),
    "say_start_2": S("がんばろうね！", "Let's do this!", "加油吧！", "힘내자!"),
    "say_start_3": S("さあ はじめよう！", "Let's begin!", "來，開始吧！", "자, 시작하자!"),
    "say_combo_50_0": S("50コンボ！", "50 combo!", "50連擊！", "50 콤보!"),
    "say_combo_50_1": S("50コンボ！ ナイス！", "50 combo! Nice!", "50連擊！ 漂亮！", "50 콤보! 나이스!"),
    "say_combo_50_2": S("50コンボ たっせい！", "50 combo reached!", "達成50連擊！", "50 콤보 달성!"),
    "say_combo_100_0": S("100コンボ！", "100 combo!", "100連擊！", "100 콤보!"),
    "say_combo_100_1": S("100コンボ！ すごい！", "100 combo! Wow!", "100連擊！ 好厲害！", "100 콤보! 대단해!"),
    "say_combo_100_2": S("100コンボ とっぱ！", "Past 100 combo!", "突破100連擊！", "100 콤보 돌파!"),
    "say_combo_100_3": S("100コンボだ！", "That's 100 combo!", "100連擊了！", "100 콤보다!"),
    "say_combo_200_0": S("200コンボ！", "200 combo!", "200連擊！", "200 콤보!"),
    "say_combo_200_1": S("200コンボ！ そのまま！", "200! Keep it up!", "200連擊！ 保持住！", "200 콤보! 그대로!"),
    "say_combo_200_2": S("200コンボ とっぱ！", "Past 200 combo!", "突破200連擊！", "200 콤보 돌파!"),
    "say_combo_300_0": S("300コンボ！", "300 combo!", "300連擊！", "300 콤보!"),
    "say_combo_300_1": S("300コンボ！ すごすぎ！", "300! Amazing!", "300連擊！ 太強了！", "300 콤보! 굉장해!"),
    "say_combo_300_2": S("300コンボ とっぱ！", "Past 300 combo!", "突破300連擊！", "300 콤보 돌파!"),
    "say_combo_400_0": S("400コンボ！", "400 combo!", "400連擊！", "400 콤보!"),
    "say_combo_400_1": S("400コンボ！ ノってる！", "400! On fire!", "400連擊！ 狀態正好！", "400 콤보! 신났다!"),
    "say_combo_400_2": S("400コンボ とっぱ！", "Past 400 combo!", "突破400連擊！", "400 콤보 돌파!"),
    "say_combo_500_0": S("500コンボ！", "500 combo!", "500連擊！", "500 콤보!"),
    "say_combo_500_1": S("500コンボ！ たつじん！", "500! A true master!", "500連擊！ 達人！", "500 콤보! 달인!"),
    "say_combo_500_2": S("500コンボ とっぱ！", "Past 500 combo!", "突破500連擊！", "500 콤보 돌파!"),
    "say_combo_many_0": S("コンボ つづいてる！", "The combo goes on!", "連擊還在繼續！", "콤보 계속 중!"),
    "say_combo_many_1": S("まだまだ つづく！", "Keep it going!", "還要繼續！", "아직 계속!"),
    "say_combo_many_2": S("コンボ こうしん中！", "Combo climbing!", "連擊重新整理中！", "콤보 갱신 중!"),
    "say_dan_next_0": S("つぎの きょく！", "Next song!", "下一首！", "다음 곡!"),
    "say_dan_next_1": S("その ちょうしで つぎ！", "Keep it up, next!", "保持狀態，下一首！", "그 기세로 다음!"),
    "say_dan_next_2": S("まだまだ いくよ！", "Still going!", "繼續前進！", "아직 더 간다!"),
    "say_donderful_0": S("ぜんぶ 良！ さいこう！", "All GOOD! The best!", "全是良！ 最棒了！", "전부 양! 최고!"),
    "say_donderful_1": S("ドンダフルコンボ！", "Donderful Combo!", "全良連擊！", "동더풀 콤보!"),
    "say_donderful_2": S("パーフェクト！", "Perfect!", "完美！", "퍼펙트!"),
    "say_fail_0": S("おしい！ つぎは いける！", "So close! Next time!", "可惜！ 下次能行！", "아깝다! 다음엔 된다!"),
    "say_fail_1": S("ざんねん…", "Too bad…", "可惜…", "아쉽다…"),
    "say_fail_2": S("もう いっかい やろう！", "Let's try again!", "再來一次吧！", "한 번 더 하자!"),
    "say_full_combo_0": S("フルコンボ！ すごい！", "Full Combo! Wow!", "全連擊！ 好厲害！", "풀 콤보! 대단해!"),
    "say_full_combo_1": S("フルコンボだ！", "Full Combo!", "全連擊了！", "풀 콤보다!"),
    "say_full_combo_2": S("かんぺき フルコンボ！", "A perfect Full Combo!", "完美全連擊！", "완벽한 풀 콤보!"),
    "say_gogo_0": S("ゴーゴータイム！", "GO-GO Time!", "GOGO時間！", "고고 타임!"),
    "say_gogo_1": S("ゴーゴー！ もりあがれ！", "GO-GO! Turn it up!", "GOGO！ 嗨起來！", "고고! 달아올라라!"),
    "say_gogo_2": S("ゴーゴータイムだ！", "It's GO-GO Time!", "GOGO時間到！", "고고 타임이다!"),
    "say_gogo_3": S("ここが みせば！", "Show them now!", "現在是看點！", "여기가 하이라이트!"),
    "say_miss_0": S("ドンマイ！", "Don't mind!", "別在意！", "괜찮아!"),
    "say_miss_1": S("おちついて！", "Stay calm!", "冷靜點！", "침착하게!"),
    "say_miss_2": S("まだまだ いける！", "You've still got it!", "還能行！", "아직 할 수 있어!"),
    "say_miss_3": S("リズムを よく きいて！", "Listen to the beat!", "仔細聽節奏！", "리듬을 잘 들어!"),
    "say_norma_0": S("クリアライン とっぱ！", "Past the clear line!", "突破通關線！", "클리어 라인 돌파!"),
    "say_norma_1": S("ノルマ クリア！", "Norma cleared!", "達成目標！", "노르마 클리어!"),
    "say_norma_2": S("その ちょうし！", "That's it!", "就是這樣！", "그 기세야!"),
    "say_roll_0": S("れんだ れんだー！", "Roll, roll!", "連打連打！", "연타 연타~!"),
    "say_roll_1": S("連打チャンス！", "Roll chance!", "連打機會！", "연타 찬스!"),
    "say_roll_2": S("たたけ たたけー！", "Hit, hit, hit!", "敲啊敲！", "두드려 두드려~!"),
    "say_balloon_0": S("ふうせん わって！", "Pop the balloon!", "打破氣球！", "풍선을 터뜨려!"),
    "say_balloon_1": S("ふうせんだ！", "A balloon!", "是氣球！", "풍선이다!"),
    "say_balloon_2": S("いっきに わろう！", "Pop it in one go!", "一口氣打破！", "단숨에 터뜨리자!"),
    "say_clear_0": S("クリア おめでとう！", "Clear, congrats!", "恭喜通關！", "클리어 축하해!"),
    "say_clear_1": S("やったね！ クリア！", "You did it! Clear!", "太好了！ 通關！", "해냈다! 클리어!"),
    "say_clear_2": S("ナイス えんそう！", "Nice playing!", "演奏得真棒！", "멋진 연주!"),
    # v2_front: the engine start prompt (skin_config hit_taiko_to_start); Lua sizes the sign chips from it
    "title_start": S("太鼓をたたいてスタート！", "HIT THE TAIKO!", "敲打太鼓開始！", "북을 쳐서 시작!"),
    # v2_result: the 不合格 stamp lettering (dan result; baked per language, en in capitals)
    "dan_fail": S("不合格", "Fail", "不合格", "불합격", note="dan result stamp"),
    # v2_song_select: the song count under an open genre folder's title (box_folder.lua)
    "sel_folder_count": S("全{0}曲", "{0} songs", "共{0}首", "전 {0}곡", note="open folder song count"),
    # v2_song_select: the one-menu sort window (diff_sort.lua reads UI.t(<Nijiiro key>): ss_<key> first;
    # Nijiiro's skin_config has no ko for these, so ko fell back to Japanese)
    "sort_window_diff": S("むずかしさ", "Difficulty", "難度", "난이도"),
    "sort_window_star": S("★の数", "Number of ★", "★的個數", "★ 개수", wide=True),
    "sort_window_order": S("表示順", "Sort by", "排序", "정렬"),
    "sort_window_order_0": S("いつもどおり", "Default", "預設", "기본"),
    "sort_window_order_1": S("未クリア優先", "Not cleared first", "未通關優先", "미클리어 우선", wide=True),
    "sort_window_order_2": S("未フルコンボ優先", "No Full Combo first", "未全連優先", "미풀콤보 우선", wide=True),
    "sort_window_order_3": S("未ドンダフルコンボ優先", "No Donderful first", "未全良優先", "미동더풀 우선"),
    "folder_sort_select": S("むずかしさからえらぶ", "Select by difficulty", "按難度選擇", "난이도로 선택"),
    "sort_window_songs": S("曲", "songs", "首", "곡", note="after the song count"),
}

LANGS = ("ja", "en", "zh", "ko")


def check():
    """Every key has all four languages, non-empty. Raises SystemExit (build failure) otherwise."""
    bad = [f"{k}: {l}" for k, v in STRINGS.items() for l in LANGS if not str(v.get(l, "")).strip()]
    if bad:
        raise SystemExit("ss/strings.py: missing translations:\n  " + "\n  ".join(bad))


def text_config():
    """{ss_<key>: {"text": {ja, en, zh, ko}}} for text_config.json (no positions: Lua-only entries)."""
    check()
    return {PREFIX + k: {"text": {l: v[l] for l in LANGS}} for k, v in STRINGS.items()}


def get(key, lang="ja"):
    """Build-time lookup with the engine's fallback (lang -> ja -> en): for baked per-language variants."""
    v = STRINGS[key]
    for l in (lang, "ja", "en"):
        if v.get(l):
            return v[l]
    return ""


def by_ja():
    """ja text -> key (first key wins), for tools/baked_text.py."""
    out = {}
    for k, v in STRINGS.items():
        out.setdefault(v["ja"], k)
    return out
