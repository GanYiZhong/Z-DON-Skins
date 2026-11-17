local TAB = { ja = "バトルパワーの説明", en = "About Battle Power" }

return {
    kind = "intro",
    pages = {
        {
            panel = "rules_card_blue", sparkles = { 639.95, 374.25 },
            title = { ja = "バトルパワーの説明", en = "About Battle Power" },
        },
        {
            panel = "rules_panel_blue", loop = { 84, 123 }, tab = TAB,
            header = { ja = "バトルパワーとは", en = "What is Battle Power?" },
            items = {
                { key = "power_hud_shot", at = 34 },
                { key = "power_meter", at = 35 },
                { key = "power_meter_ring", at = 35, to = 83 },
                { key = "power_meter_ring", at = 100 },
                { key = "power_bubble_strength", at = 35, x = 292, y = 228,
                    text = { ja = "「つよさ」を\nすうちにしたもの", en = "Your strength\nas a number" } },
                { key = "power_burst", at = 82, x = 380, y = 509, style = "light",
                    text = { ja = "すうちがたかいほど\nつよい!", en = "The higher it is,\nthe stronger you are!" } },
            },
        },
        {
            panel = "rules_panel_blue", tab = TAB,
            header = { ja = "バトルパワーをあげるポイント", en = "How to raise Battle Power" },
            items = {
                { key = "power_bond", at = 35, x = 396, y = 338,
                    text = { ja = "絆レベルをあげる!", en = "Raise your bond level!" } },
                { key = "power_play_shot", at = 83 },
                { key = "power_bubble_play", at = 83, x = 914, y = 538,
                    text = { ja = "うまく演奏する!", en = "Play well!" } },
            },
        },
        {
            panel = "rules_panel_blue", loop = { 95, 132 }, tab = TAB,
            header = { ja = "バトルパワーのきろく", en = "Battle Power records" },
            items = {
                { key = "power_result_card", at = 35 },
                { key = "power_result_ring", at = 35, to = 94 },
                { key = "power_result_ring", at = 111 },
                { key = "power_bubble_measure", at = 35, x = 264, y = 277,
                    text = { ja = "演奏するたび\nバトルパワーをはかるよ", en = "Your Battle Power is\nmeasured every song" } },
                { key = "rules_arrow", at = 82, dx = 28, fade = 5, slide = -26 },
                { key = "power_best_card", at = 90 },
                { key = "power_best_ring", at = 92, to = 94 },
                { key = "power_best_ring", at = 111 },
                { key = "power_bubble_record", at = 94, x = 1058, y = 429,
                    text = { ja = "まえよりつよいと\nきろくされる!", en = "Beat your best\nto save it!" } },
            },
        },
    },
}
