local TAB = { ja = "ボスバトルのルール", en = "Boss Battle Rules" }
local BLACK = { 0, 0, 0, 255 }

return {
    kind = "intro",
    pages = {
        {
            panel = "rules_card_blue", sparkles = { 639.95, 374.25 },
            title = { ja = "ボスバトルのルール", en = "Boss Battle Rules" },
        },
        {
            panel = "rules_panel_blue", loop = { 77, 118 }, tab = TAB,
            header = { ja = "ボスにはライフがある!", en = "Bosses have life!" },
            items = {
                { key = "boss_play_shot", at = 35 },
                { key = "boss_life", at = 36 },
                { key = "boss_life_ring", at = 36, to = 99 },
                { key = "boss_bubble_hit", at = 36, x = 313, y = 311,
                    text = { ja = "音符をたたくと\nライフをへらせる!", en = "Hit notes to\nlower its life!" } },
                { key = "boss_burst", at = 74, x = 312, y = 492, style = "light",
                    text = { ja = "ライフを0にすると\nボスをたおせる!", en = "Bring it to 0\nto defeat the boss!" } },
            },
        },
        {
            panel = "rules_panel_blue", tab = TAB,
            header = { ja = "1回ではたおせないかも!?", en = "Can't win in one go!?" },
            items = {
                { at = 39, x = 460, y = 268, size = 34, width = 560,
                    text = { ja = "1回の演奏でライフを0にできなくても", en = "Even if one song can't empty its life," } },
                { at = 75, x = 460, y = 320, size = 46, color = { 255, 225, 40, 255 }, outline = BLACK,
                    thickness = 5, width = 580,
                    text = { ja = "1度へらしたライフは、そのまま!", en = "the damage you dealt stays!" } },
                { key = "boss_retry", at = 118, x = 518, y = 492,
                    text = { ja = "たおせるまで何度でも\nチャレンジできるよ!", en = "Try again as many\ntimes as it takes!" } },
            },
        },
        {
            panel = "rules_panel_blue", tab = TAB,
            header = { ja = "ボスをたおして次のステージへ!", en = "Beat the boss to reach the next stage!" },
            items = {
                { key = "boss_bubble_amitie", at = 41, fade = 8, x = 387, y = 336,
                    text = { ja = "ボスをたおすと\n次のステージがあそべるよ!", en = "Beat the boss to\nplay the next stage!" } },
                { key = "boss_bubble_don", at = 96, fade = 8, x = 940, y = 334,
                    text = { ja = "どんなステージか\nたのしみだドン", en = "Can't wait to see\nthe next stage, Don!" } },
            },
        },
    },
}
