local TAB = { ja = "イベントの説明", en = "About the event" }
local RED = { 225, 30, 40, 255 }
local ORANGE = { 240, 90, 0, 255 }
local WHITE = { 255, 255, 255, 255 }
local INK = { 32, 32, 32, 255 }
local KEY = "#ff8c00"

local function burst(at, x, y, size, text)
    return { at = at, x = x, y = y, size = size, color = RED, outline = WHITE, thickness = 5, gap = size + 4,
        text = text }
end

return {
    kind = "intro",
    pages = {
        {
            panel = "rules_card_blue", sparkles = { 640, 374.3 },
            items = {
                { key = "event_logo", at = 0 },
                { at = 0, x = 636, y = 530, size = 44, color = ORANGE, outline = WHITE, thickness = 6, width = 900,
                    text = { ja = "から、ラルコとマオウがやってきた!", en = "Rulco and Maou are here!" } },
                { key = "event_burst", at = 0 },
                { at = 0, x = 311, y = 162, size = 58, color = ORANGE, outline = WHITE, thickness = 6, gap = 66,
                    text = { ja = "スペシャル\nイベント!", en = "Special\nevent!" } },
            },
        },
        {
            panel = "event_panel_1", tab = TAB, tab_span = { 272, 476, 107 }, loop = { 119, 155 },
            items = {
                { at = 39, x = 639, y = 198, size = 34, color = INK, outline = WHITE, thickness = 4, width = 900,
                    text = { ja = "イベント中、<c=" .. KEY .. ">必殺技</c>をうつと、",
                        en = "During the event, <c=" .. KEY .. ">special moves</c> can drop" } },
                { at = 39, x = 639, y = 259, size = 40, color = INK, outline = WHITE, thickness = 4, width = 900,
                    text = { ja = "<c=" .. KEY .. ">ふしぎ玉</c>が入った<c=" .. KEY .. ">宝箱</c>が出ることがある!",
                        en = "<c=" .. KEY .. ">treasure chests</c> holding <c=" .. KEY .. ">mysterious orbs</c>!" } },
                { key = "event_battle_shot", at = 39 },
                { key = "event_chest_glow", at = 75 },
                { key = "event_chest_ring", at = 75, to = 118 },
                { key = "event_chest_ring", at = 135 },
                { key = "event_lucky", at = 118, x = 930, y = 394, style = "light",
                    text = { ja = "出たら\nラッキー!", en = "Lucky\nfind!" } },
            },
        },
        {
            panel = "event_panel_2", tab = TAB, tab_span = { 372, 578, 107 }, loop = { 119, 155 },
            items = {
                { key = "event_rulco", at = 39 },
                burst(39, 455, 341, 34, { ja = "ラルコの必殺技\nゲット!", en = "Get Rulco's\nspecial move!" }),
                { at = 39, x = 316, y = 238, size = 44, color = INK, outline = WHITE, thickness = 5, gap = 52,
                    text = { ja = "<c=" .. KEY .. ">ふしぎ玉</c>を\n100個あつめて",
                        en = "Collect 100\n<c=" .. KEY .. ">mysterious orbs</c>" } },
                { key = "event_maou", at = 89 },
                { at = 89, x = 955, y = 299, size = 20, color = INK, outline = WHITE, thickness = 3,
                    text = { ja = "楽曲", en = "Song" } },
                burst(89, 955, 354, 32, { ja = "マオウのショウタイム\nゲット♪", en = "Get Maou's\nShowtime!" }),
                { at = 89, x = 842, y = 238, size = 44, color = INK, outline = WHITE, thickness = 5, gap = 52,
                    text = { ja = "さらに<c=" .. KEY .. ">ふしぎ玉</c>を\n100個あつめて",
                        en = "Then collect\n100 more <c=" .. KEY .. ">orbs</c>" } },
            },
        },
        {
            panel = "event_panel_3", tab = TAB, tab_span = { 467, 669, 107 }, loop = { 115, 152 },
            sound = { 103, "se_popup" },
            items = {
                { key = "event_band", at = 35 },
                { at = 35, x = 640, y = 210, size = 38, color = ORANGE, outline = WHITE, thickness = 5, width = 900,
                    text = { ja = "イベント中に、ふしぎ玉をあつめよう!", en = "Collect mysterious orbs during the event!" } },
                { key = "event_select_shot", at = 35 },
                { key = "event_counter", at = 35 },
                { key = "event_counter_ring", at = 35, to = 53 },
                { key = "event_counter_ring", at = 75, to = 93 },
                { key = "event_counter_ring", at = 132 },
                { key = "event_bubble_count", at = 35, x = 748, y = 348, size = 28, color = INK, gap = 34,
                    text = { ja = "あつめた数は\nここでチェック!", en = "Check how many\nyou have here!" } },
            },
        },
    },
}
