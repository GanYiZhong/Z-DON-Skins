local TAB = { ja = "ごほうびをゲットするには", en = "Getting rewards" }
local RED = { 230, 60, 10, 255 }
local MAROON = { 100, 25, 0, 255 }
local WHITE = { 255, 255, 255, 255 }
local INK = { 32, 32, 32, 255 }

return {
    kind = "intro",
    pages = {
        {
            panel = "rules_card_blue", sparkles = { 639.95, 374.25 },
            title = { ja = "バトルごほうびの説明", en = "About Battle Rewards" },
        },
        {
            panel = "rules_card_blue", sparkles = { 639.95, 374.25 }, loop = { 84, 123 },
            items = {
                { key = "stones_chest_open", at = 0 },
                { key = "stones_rays_a", at = 0, wave = 0 },
                { key = "stones_rays_b", at = 0, wave = 0.5 },
                { at = 35, x = 640, y = 294, size = 58, color = RED, outline = MAROON, thickness = 6,
                    text = { ja = "ごほうびをゲットすると", en = "Get rewards to unlock" } },
                { at = 82, x = 640, y = 381, size = 58, color = RED, outline = MAROON, thickness = 6,
                    text = { ja = "つかえる必殺技がふえる!", en = "more special moves!" } },
            },
        },
        {
            panel = "stones_panel_1", tab = TAB, tab_span = { 148, 476, 107 }, loop = { 119, 155 },
            items = {
                { at = 39, x = 640, y = 173, size = 32, color = INK, outline = WHITE, thickness = 4, width = 960,
                    text = { ja = "<c=#ffc800>必殺技</c>をうつと、<c=#ffc800>宝箱</c>が出ることがある!",
                        en = "<c=#ffc800>Special moves</c> can drop <c=#ffc800>treasure chests</c>!" } },
                { key = "stones_battle_shot", at = 39 },
                { key = "stones_chest_glow", at = 75 },
                { key = "stones_chest_ring", at = 75, to = 118 },
                { key = "stones_chest_ring", at = 135 },
                { key = "stones_lucky", at = 118, x = 949, y = 375, style = "light",
                    text = { ja = "出たら\nラッキー!", en = "Lucky\nfind!" } },
            },
        },
        {
            panel = "stones_panel_2", tab = TAB, tab_span = { 248, 576, 107 }, loop = { 95, 132 },
            items = {
                { at = 35, x = 640, y = 205, size = 32, color = INK, outline = WHITE, thickness = 4, width = 900,
                    icon = { "stones_gem", 0.55 },
                    text = { ja = "宝箱から<c=#b45adc>まほう石</c>が出てくる!",
                        en = "Chests hold <c=#b45adc>magic stones</c>!" } },
                { key = "stones_result_card", at = 35, to = 78 },
                { key = "stones_result_card", at = 79, fade = 4, dim = 0.551 },
                { key = "stones_gem_panel", at = 82 },
                { key = "stones_gem_ring", at = 82, to = 94 },
                { key = "stones_gem_ring", at = 111 },
                { pop = true, at = 82 },
            },
        },
        {
            panel = "stones_panel_3", tab = TAB, tab_span = { 343, 670, 107 }, loop = { 134, 171 },
            items = {
                { key = "stones_band", at = 35 },
                { at = 35, x = 640, y = 277, size = 46, color = RED, outline = WHITE, thickness = 5, width = 860,
                    icon = { "stones_gem", 1 },
                    text = { ja = "<c=#b45adc>まほう石</c>をためて、ごほうびゲット!",
                        en = "Save up <c=#b45adc>magic stones</c> for rewards!" } },
                { key = "stones_menu_shot", at = 113, fade = 6 },
                { key = "stones_counter", at = 121 },
                { key = "stones_counter_ring", at = 121, to = 133 },
                { key = "stones_counter_ring", at = 150 },
                { key = "stones_bubble_howmuch", at = 121, x = 727, y = 436,
                    text = { ja = "どれだけ\nためればいいか\nわかるよ!", en = "Shows how\nmany more\nyou need!" } },
            },
        },
    },
}
