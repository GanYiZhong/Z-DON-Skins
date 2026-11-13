local INTRO = {
    -- depth 1
    { {24, 26, "drum", 0, false, 640, -160, 1, 1, 640, -101.35, 1, 1},
      {27, 29, "drum", 0, false, 640, -74.1, 1, 1, 640, -23.8, 1, 1},
      {30, 32, "drum", 0, false, 640, -0.8, 1, 1, 640, 41.1, 1, 1},
      {33, 35, "drum", 0, false, 640, 60, 1, 1, 640, 93.5, 1, 1},
      {36, 38, "drum", 0, false, 640, 108.15, 1, 1, 640, 133.3, 1, 1},
      {39, 41, "drum", 0, false, 640, 143.8, 1, 1, 640, 160.55, 1, 1},
      {42, 44, "drum", 0, false, 640, 166.8, 1, 1, 640, 175.2, 1, 1},
      {45, 48, "drum", 0, false, 640, 177.3, 1, 1, 640, 176.4, 1, 1},
      {49, 51, "drum", 0, false, 640, 174.4, 1, 1, 640, 168, 1, 1},
      {52, 149, "drum", 0, false, 640, 168, 1, 1, 640, 168, 1, 1} },
    -- depth 2
    { {24, 25, "stick", 0, true, -80, 155, 1, 1, -25.35, 155, 1, 1},
      {26, 27, "stick", 0, true, 26.75, 155, 1, 1, 76.3, 155, 1, 1},
      {28, 29, "stick", 0, true, 123.3, 155, 1, 1, 167.8, 155, 1, 1},
      {30, 31, "stick", 0, true, 209.7, 155, 1, 1, 249.1, 155, 1, 1},
      {32, 33, "stick", 0, true, 285.95, 155, 1, 1, 320.25, 155, 1, 1},
      {34, 35, "stick", 0, true, 352.05, 155, 1, 1, 381.25, 155, 1, 1},
      {36, 37, "stick", 0, true, 407.95, 155, 1, 1, 432.1, 155, 1, 1},
      {38, 39, "stick", 0, true, 453.7, 155, 1, 1, 472.75, 155, 1, 1},
      {40, 41, "stick", 0, true, 489.25, 155, 1, 1, 503.25, 155, 1, 1},
      {42, 43, "stick", 0, true, 514.65, 155, 1, 1, 523.55, 155, 1, 1},
      {44, 45, "stick", 0, true, 529.9, 155, 1, 1, 533.75, 155, 1, 1},
      {46, 49, "stick", 0, true, 535, 155, 1, 1, 531.4, 155, 1, 1},
      {50, 51, "stick", 0, true, 528.6, 155, 1, 1, 525, 155, 1, 1},
      {52, 149, "stick", 0, true, 525, 155, 1, 1, 525, 155, 1, 1} },
    -- depth 3
    { {24, 25, "stick", 0, false, 1350, 155, 1, 1, 1295.35, 155, 1, 1},
      {26, 27, "stick", 0, false, 1243.25, 155, 1, 1, 1193.7, 155, 1, 1},
      {28, 29, "stick", 0, false, 1146.7, 155, 1, 1, 1102.2, 155, 1, 1},
      {30, 31, "stick", 0, false, 1060.3, 155, 1, 1, 1020.9, 155, 1, 1},
      {32, 33, "stick", 0, false, 984.05, 155, 1, 1, 949.75, 155, 1, 1},
      {34, 35, "stick", 0, false, 917.95, 155, 1, 1, 888.75, 155, 1, 1},
      {36, 37, "stick", 0, false, 862.05, 155, 1, 1, 837.95, 155, 1, 1},
      {38, 39, "stick", 0, false, 816.3, 155, 1, 1, 797.25, 155, 1, 1},
      {40, 41, "stick", 0, false, 780.75, 155, 1, 1, 766.75, 155, 1, 1},
      {42, 43, "stick", 0, false, 755.35, 155, 1, 1, 746.45, 155, 1, 1},
      {44, 45, "stick", 0, false, 740.1, 155, 1, 1, 736.25, 155, 1, 1},
      {46, 49, "stick", 0, false, 735, 155, 1, 1, 738.6, 155, 1, 1},
      {50, 51, "stick", 0, false, 741.4, 155, 1, 1, 745, 155, 1, 1},
      {52, 149, "stick", 0, false, 745, 155, 1, 1, 745, 155, 1, 1} },
}
local SCENE_2 = {
    -- depth 0
    { {0, 399, "drum", 0, false, 640, 168, 1, 1, 640, 168, 1, 1} },
    -- depth 1
    { {0, 292, "stick", 0, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {293, 295, "stick", 1, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {296, 298, "stick", 2, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {299, 379, "drum_don", 0, false, 640, 168, 1, 1, 640, 168, 1, 1},
      {380, 382, "drum_don", 0, false, 640, 168, 1, 0.75, 640, 168, 1, 0.25} },
    -- depth 2
    { {299, 399, "stick", 0, false, 745, 155, 1, 1, 745, 155, 1, 1} },
    -- depth 3
    { {0, 399, "stick", 0, true, 525, 155, 1, 1, 525, 155, 1, 1} },
}
local SCENE_3 = {
    -- depth 1
    { {0, 51, "drum", 0, false, 640, 168, 1, 1, 640, 168, 1, 1},
      {52, 56, "drum", 1, false, 640, 168, 1, 1, 640, 168, 1, 1},
      {57, 61, "drum", 2, false, 640, 168, 1, 1, 640, 168, 1, 1},
      {62, 124, "drum", 3, false, 640, 168, 1, 1, 640, 168, 1, 1},
      {125, 128, "drum", 3, false, 640, 168, 0.972, 1, 640, 168, 0.951, 1},
      {129, 134, "drum", 3, false, 640, 168, 0.956, 1, 640, 168, 1, 1},
      {135, 148, "drum", 3, false, 640, 168, 1, 1, 640, 168, 1, 1},
      {149, 152, "drum", 3, false, 640, 168, 0.972, 1, 640, 168, 0.951, 1},
      {153, 158, "drum", 3, false, 640, 168, 0.956, 1, 640, 168, 1, 1},
      {159, 173, "drum", 3, false, 640, 168, 1, 1, 640, 168, 1, 1},
      {174, 177, "drum", 3, false, 640, 168, 0.972, 1, 640, 168, 0.951, 1},
      {178, 183, "drum", 3, false, 640, 168, 0.956, 1, 640, 168, 1, 1},
      {184, 296, "drum", 3, false, 640, 168, 1, 1, 640, 168, 1, 1},
      {297, 301, "drum", 2, false, 640, 168, 1, 1, 640, 168, 1, 1},
      {302, 306, "drum", 1, false, 640, 168, 1, 1, 640, 168, 1, 1},
      {307, 359, "drum", 0, false, 640, 168, 1, 1, 640, 168, 1, 1} },
    -- depth 2
    { {0, 1, "stick", 0, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {2, 3, "stick", 1, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {4, 25, "stick", 2, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {26, 31, "stick", 2, false, 752.4, 155, 1, 1, 785.3, 155, 1, 1},
      {32, 37, "stick", 2, false, 791.05, 155, 1, 1, 815.5, 155, 1, 1},
      {38, 43, "stick", 2, false, 819.6, 155, 1, 1, 835.65, 155, 1, 1},
      {44, 49, "stick", 2, false, 838.05, 155, 1, 1, 845.75, 155, 1, 1},
      {50, 64, "stick", 2, false, 846.45, 155, 1, 1, 846.45, 155, 1, 1},
      {65, 70, "stick", 2, false, 845.75, 155, 1, 1, 838.05, 155, 1, 1},
      {71, 76, "stick", 2, false, 835.65, 155, 1, 1, 819.6, 155, 1, 1},
      {77, 82, "stick", 2, false, 815.5, 155, 1, 1, 791.05, 155, 1, 1},
      {83, 88, "stick", 2, false, 785.3, 155, 1, 1, 752.4, 155, 1, 1},
      {89, 119, "stick", 2, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {120, 122, "stick", 1, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {124, 127, "burst", 0, false, 695, 96, 0.1, 1, 695, 96, 0.8, 1},
      {128, 132, "burst", 0, false, 695, 96, 0.833, 0.832, 695, 96, 0.967, 0.168},
      {173, 176, "burst", 0, false, 695, 96, 0.1, 1, 695, 96, 0.8, 1},
      {177, 181, "burst", 0, false, 695, 96, 0.833, 0.832, 695, 96, 0.967, 0.168} },
    -- depth 3
    { {0, 1, "stick", 0, true, 525, 155, 1, 1, 525, 155, 1, 1},
      {2, 3, "stick", 1, true, 525, 155, 1, 1, 525, 155, 1, 1},
      {123, 125, "stick", 0, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {126, 128, "stick", 1, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {148, 151, "burst", 0, false, 578, 96, 0.1, 1, 578, 96, 0.8, 1},
      {152, 156, "burst", 0, false, 578, 96, 0.833, 0.832, 578, 96, 0.967, 0.168} },
    -- depth 4
    { {129, 168, "stick", 2, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {169, 171, "stick", 1, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {172, 174, "stick", 0, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {175, 177, "stick", 1, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {178, 270, "stick", 2, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {271, 276, "stick", 2, false, 752.4, 155, 1, 1, 785.3, 155, 1, 1},
      {277, 282, "stick", 2, false, 791.05, 155, 1, 1, 815.5, 155, 1, 1},
      {283, 288, "stick", 2, false, 819.6, 155, 1, 1, 835.65, 155, 1, 1},
      {289, 294, "stick", 2, false, 838.05, 155, 1, 1, 845.75, 155, 1, 1},
      {295, 309, "stick", 2, false, 846.45, 155, 1, 1, 846.4, 155, 1, 1},
      {310, 315, "stick", 2, false, 845.65, 155, 1, 1, 837.35, 155, 1, 1},
      {316, 321, "stick", 2, false, 834.8, 155, 1, 1, 817.45, 155, 1, 1},
      {322, 327, "stick", 2, false, 813.05, 155, 1, 1, 786.65, 155, 1, 1},
      {328, 333, "stick", 2, false, 780.45, 155, 1, 1, 745, 155, 1, 1},
      {334, 336, "stick", 2, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {337, 338, "stick", 1, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {339, 359, "stick", 0, false, 745, 155, 1, 1, 745, 155, 1, 1} },
    -- depth 5
    { {4, 25, "stick", 2, true, 525, 155, 1, 1, 525, 155, 1, 1},
      {26, 31, "stick", 2, true, 517.75, 155, 1, 1, 485.5, 155, 1, 1},
      {32, 37, "stick", 2, true, 479.85, 155, 1, 1, 455.85, 155, 1, 1},
      {38, 43, "stick", 2, true, 451.9, 155, 1, 1, 436.1, 155, 1, 1},
      {44, 49, "stick", 2, true, 433.8, 155, 1, 1, 426.25, 155, 1, 1},
      {50, 64, "stick", 2, true, 425.55, 155, 1, 1, 425.55, 155, 1, 1},
      {65, 70, "stick", 2, true, 426.25, 155, 1, 1, 433.8, 155, 1, 1},
      {71, 76, "stick", 2, true, 436.1, 155, 1, 1, 451.9, 155, 1, 1},
      {77, 82, "stick", 2, true, 455.85, 155, 1, 1, 479.85, 155, 1, 1},
      {83, 88, "stick", 2, true, 485.5, 155, 1, 1, 517.75, 155, 1, 1},
      {89, 143, "stick", 2, true, 525, 155, 1, 1, 525, 155, 1, 1},
      {144, 146, "stick", 1, true, 525, 155, 1, 1, 525, 155, 1, 1},
      {147, 149, "stick", 0, true, 525, 155, 1, 1, 525, 155, 1, 1},
      {150, 152, "stick", 1, true, 525, 155, 1, 1, 525, 155, 1, 1},
      {153, 270, "stick", 2, true, 525, 155, 1, 1, 525, 155, 1, 1},
      {271, 276, "stick", 2, true, 517.75, 155, 1, 1, 485.5, 155, 1, 1},
      {277, 282, "stick", 2, true, 479.85, 155, 1, 1, 455.85, 155, 1, 1},
      {283, 288, "stick", 2, true, 451.9, 155, 1, 1, 436.1, 155, 1, 1},
      {289, 294, "stick", 2, true, 433.8, 155, 1, 1, 426.25, 155, 1, 1},
      {295, 309, "stick", 2, true, 425.55, 155, 1, 1, 425.6, 155, 1, 1},
      {310, 315, "stick", 2, true, 426.35, 155, 1, 1, 434.45, 155, 1, 1},
      {316, 321, "stick", 2, true, 437, 155, 1, 1, 454, 155, 1, 1},
      {322, 327, "stick", 2, true, 458.3, 155, 1, 1, 484.15, 155, 1, 1},
      {328, 333, "stick", 2, true, 490.25, 155, 1, 1, 525, 155, 1, 1},
      {334, 336, "stick", 2, true, 525, 155, 1, 1, 525, 155, 1, 1},
      {337, 338, "stick", 1, true, 525, 155, 1, 1, 525, 155, 1, 1},
      {339, 359, "stick", 0, true, 525, 155, 1, 1, 525, 155, 1, 1} },
    -- depth 6
    { {190, 193, "cross", 0, false, 640, 134, 1.4, 1, 640, 134, 1.145, 1},
      {194, 197, "cross", 0, false, 640, 134, 1.08, 1, 640, 134, 0.945, 1},
      {198, 200, "cross", 0, false, 640, 134, 0.92, 1, 640, 134, 0.9, 1},
      {201, 203, "cross", 0, false, 640, 134, 0.906, 1, 640, 134, 0.956, 1},
      {204, 256, "cross", 0, false, 640, 134, 1, 1, 640, 134, 1, 1},
      {257, 266, "cross", 0, false, 640, 134, 1, 0.91, 640, 134, 1, 0.09} },
}
local SCENE_4 = {
    -- depth 0
    { {0, 299, "drum", 0, false, 640, 168, 1, 1, 640, 168, 1, 1},
      {300, 304, "drum", 0, false, 640, 172, 1, 1, 640, 166, 1, 1},
      {305, 306, "drum", 0, false, 640, 168, 1, 1, 640, 170, 1, 1},
      {307, 319, "drum", 0, false, 640, 169, 1, 1, 640, 168, 1, 1} },
    -- depth 1
    { {0, 319, "drum", 0, false, 640, 168, 1, 1, 640, 168, 1, 1} },
    -- depth 2
    { {175, 185, "drum_don", 0, false, 640, 168, 1, 1, 640, 168, 1, 1},
      {186, 191, "drum_don", 0, false, 640, 168, 1, 0.855, 640, 168, 1, 0.145},
      {205, 215, "drum_don", 0, false, 640, 168, 1, 1, 640, 168, 1, 1},
      {216, 221, "drum_don", 0, false, 640, 168, 1, 0.855, 640, 168, 1, 0.145},
      {300, 305, "drum_don", 0, false, 640, 168, 1, 1, 640, 168, 1, 1},
      {306, 314, "drum_don", 0, false, 640, 168, 1, 0.898, 640, 168, 1, 0.102} },
    -- depth 3
    { {0, 293, "stick", 0, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {294, 296, "stick", 1, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {297, 299, "stick", 2, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {300, 302, "stick", 0, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {303, 304, "stick", 1, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {305, 319, "stick", 0, false, 745, 155, 1, 1, 745, 155, 1, 1} },
    -- depth 4
    { {0, 319, "stick", 0, true, 525, 155, 1, 1, 525, 155, 1, 1} },
}
local SCENE_5 = {
    -- depth 0
    { {0, 248, "drum", 0, false, 640, 168, 1, 1, 640, 168, 1, 1},
      {249, 255, "drum", 0, false, 640, 171.9, 1, 1, 640, 191.1, 1, 1},
      {256, 262, "drum", 0, false, 640, 193.6, 1, 1, 640, 204.4, 1, 1},
      {263, 269, "drum", 0, false, 640, 205.5, 1, 1, 640, 208, 1, 1},
      {270, 298, "drum", 0, false, 640, 208, 1, 1, 640, 208, 1, 1},
      {299, 303, "drum", 0, false, 640, 212, 1, 1, 640, 206, 1, 1},
      {304, 305, "drum", 0, false, 640, 208, 1, 1, 640, 210, 1, 1},
      {306, 387, "drum", 0, false, 640, 209, 1, 1, 640, 208, 1, 1},
      {388, 394, "drum", 0, false, 640, 204.1, 1, 1, 640, 184.9, 1, 1},
      {395, 401, "drum", 0, false, 640, 182.4, 1, 1, 640, 171.6, 1, 1},
      {402, 408, "drum", 0, false, 640, 170.5, 1, 1, 640, 168, 1, 1},
      {409, 429, "drum", 0, false, 640, 168, 1, 1, 640, 168, 1, 1} },
    -- depth 1
    { {175, 185, "drum_kat", 0, false, 640, 166, 1, 1, 640, 166, 1, 1},
      {186, 191, "drum_kat", 0, false, 640, 166, 1, 0.855, 640, 166, 1, 0.145},
      {205, 215, "drum_kat", 0, false, 640, 166, 1, 1, 640, 166, 1, 1},
      {216, 221, "drum_kat", 0, false, 640, 166, 1, 0.855, 640, 166, 1, 0.145},
      {290, 292, "stick", 1, false, 735, 185, 1, 1, 735, 185, 1, 1},
      {293, 295, "stick", 2, false, 703, 164, 1, 1, 703, 164, 1, 1},
      {296, 298, "stick", 3, false, 708, 125, 1, 1, 708, 125, 1, 1},
      {299, 304, "drum_kat", 0, false, 640, 208, 1, 1, 640, 208, 1, 1},
      {305, 313, "drum_kat", 0, false, 640, 208, 1, 0.898, 640, 208, 1, 0.102},
      {383, 385, "stick", 4, false, 717, 177, 1, 1, 717, 177, 1, 1},
      {386, 387, "stick", 0, false, 745, 195, 1, 1, 745, 195, 1, 1},
      {388, 394, "stick", 0, false, 745, 191.1, 1, 1, 745, 171.9, 1, 1},
      {395, 401, "stick", 0, false, 745, 169.4, 1, 1, 745, 158.6, 1, 1},
      {402, 408, "stick", 0, false, 745, 157.5, 1, 1, 745, 155, 1, 1},
      {409, 429, "stick", 0, false, 745, 155, 1, 1, 745, 155, 1, 1} },
    -- depth 2
    { {0, 248, "stick", 0, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {249, 255, "stick", 0, false, 745, 158.9, 1, 1, 745, 178.1, 1, 1},
      {256, 262, "stick", 0, false, 745, 180.6, 1, 1, 745, 191.4, 1, 1},
      {263, 269, "stick", 0, false, 745, 192.5, 1, 1, 745, 195, 1, 1},
      {270, 289, "stick", 0, false, 745, 195, 1, 1, 745, 195, 1, 1},
      {299, 301, "stick", 4, true, 718, 121, 1, 1, 718, 121, 1, 1},
      {302, 379, "stick", 5, true, 718, 121, 1, 1, 718, 121, 1, 1},
      {380, 382, "stick", 5, false, 705, 121, 1, 1, 705, 121, 1, 1} },
    -- depth 3
    { {0, 248, "stick", 0, true, 525, 155, 1, 1, 525, 155, 1, 1},
      {249, 255, "stick", 0, true, 525, 158.9, 1, 1, 525, 178.1, 1, 1},
      {256, 262, "stick", 0, true, 525, 180.6, 1, 1, 525, 191.4, 1, 1},
      {263, 269, "stick", 0, true, 525, 192.5, 1, 1, 525, 195, 1, 1},
      {270, 387, "stick", 0, true, 525, 195, 1, 1, 525, 195, 1, 1},
      {388, 394, "stick", 0, true, 525, 191.1, 1, 1, 525, 171.9, 1, 1},
      {395, 401, "stick", 0, true, 525, 169.4, 1, 1, 525, 158.6, 1, 1},
      {402, 408, "stick", 0, true, 525, 157.5, 1, 1, 525, 155, 1, 1},
      {409, 429, "stick", 0, true, 525, 155, 1, 1, 525, 155, 1, 1} },
}
local HIT_DON = {
    { {0, 8, "drum", 0, false, 640, 168, 1, 1, 640, 168, 1, 1},
      {9, 13, "drum", 0, false, 640, 172, 1, 1, 640, 166, 1, 1},
      {14, 15, "drum", 0, false, 640, 168, 1, 1, 640, 170, 1, 1},
      {16, 28, "drum", 0, false, 640, 169, 1, 1, 640, 168, 1, 1} },
    { {9, 14, "drum_don", 0, false, 640, 168, 1, 1, 640, 168, 1, 1},
      {15, 23, "drum_don", 0, false, 640, 168, 1, 0.898, 640, 168, 1, 0.102} },
    { {0, 2, "stick", 0, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {3, 5, "stick", 1, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {6, 8, "stick", 2, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {9, 11, "stick", 0, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {12, 13, "stick", 1, false, 745, 155, 1, 1, 745, 155, 1, 1},
      {14, 28, "stick", 0, false, 745, 155, 1, 1, 745, 155, 1, 1} },
    { {0, 2, "stick", 0, true, 525, 155, 1, 1, 525, 155, 1, 1},
      {3, 5, "stick", 1, true, 525, 155, 1, 1, 525, 155, 1, 1},
      {6, 8, "stick", 2, true, 525, 155, 1, 1, 525, 155, 1, 1},
      {9, 11, "stick", 0, true, 525, 155, 1, 1, 525, 155, 1, 1},
      {12, 13, "stick", 1, true, 525, 155, 1, 1, 525, 155, 1, 1},
      {14, 28, "stick", 0, true, 525, 155, 1, 1, 525, 155, 1, 1} },
}
local HIT_KAT = {
    { {0, 8, "drum", 0, false, 640, 168, 1, 1, 640, 168, 1, 1},
      {9, 13, "drum", 0, false, 640, 172, 1, 1, 640, 166, 1, 1},
      {14, 15, "drum", 0, false, 640, 168, 1, 1, 640, 170, 1, 1},
      {16, 28, "drum", 0, false, 640, 169, 1, 1, 640, 168, 1, 1} },
    { {9, 14, "drum_kat", 0, false, 640, 168, 1, 1, 640, 168, 1, 1},
      {15, 23, "drum_kat", 0, false, 640, 168, 1, 0.898, 640, 168, 1, 0.102} },
    { {0, 2, "stick", 1, false, 735, 140, 1, 1, 735, 140, 1, 1},
      {3, 5, "stick", 2, false, 703, 119, 1, 1, 703, 119, 1, 1},
      {6, 8, "stick", 3, false, 708, 80, 1, 1, 708, 80, 1, 1},
      {9, 11, "stick", 4, true, 718, 76, 1, 1, 718, 76, 1, 1},
      {12, 28, "stick", 5, true, 718, 76, 1, 1, 718, 76, 1, 1} },
    { {0, 2, "stick", 1, true, 525, 140, 1, 1, 525, 140, 1, 1},
      {3, 5, "stick", 2, true, 557, 119, 1, 1, 557, 119, 1, 1},
      {6, 8, "stick", 3, true, 552, 80, 1, 1, 552, 80, 1, 1},
      {9, 11, "stick", 4, false, 542, 76, 1, 1, 542, 76, 1, 1},
      {12, 28, "stick", 5, false, 542, 76, 1, 1, 542, 76, 1, 1} },
}
local BUBBLE = {
    -- depth 1
    { {154, 155, "bubble", 0, false, 896, 390.05, 1, 0.211, 896, 379.5, 1, 0.395},
      {156, 157, "bubble", 0, false, 896, 370.35, 1, 0.555, 896, 362.6, 1, 0.691},
      {158, 159, "bubble", 0, false, 896, 356.25, 1, 0.801, 896, 351.35, 1, 0.891},
      {160, 161, "bubble", 0, false, 896, 347.8, 1, 0.949, 896, 345.7, 1, 0.988},
      {162, 165, "bubble", 0, false, 896, 345, 1, 1, 896, 348.75, 1, 1},
      {166, 168, "bubble", 0, false, 896, 351.65, 1, 1, 896, 360, 1, 1},
      {169, 171, "bubble", 0, false, 896, 361.35, 1, 1, 896, 364, 1, 1},
      {172, 175, "bubble", 0, false, 896, 362.65, 1, 1, 896, 360, 1, 1},
      {176, 268, "bubble", 0, false, 896, 360, 1, 1, 896, 360, 1, 1},
      {269, 276, "bubble", 0, false, 896, 360, 1, 0.891, 896, 360, 1, 0.109} },
    -- depth 2
    { {184, 188, "bubble_flash", 0, false, 896, 360, 1, 1, 896, 360, 1, 1},
      {194, 198, "bubble_flash", 0, false, 896, 360, 1, 1, 896, 360, 1, 1},
      {204, 208, "bubble_flash", 0, false, 896, 360, 1, 1, 896, 360, 1, 1},
      {214, 218, "bubble_flash", 0, false, 896, 360, 1, 1, 896, 360, 1, 1} },
    -- depth 3
    { {154, 155, "bubble_text", 0, false, 896, 390.05, 1, 0.211, 896, 379.5, 1, 0.395},
      {156, 157, "bubble_text", 0, false, 896, 370.35, 1, 0.555, 896, 362.6, 1, 0.691},
      {158, 159, "bubble_text", 0, false, 896, 356.25, 1, 0.801, 896, 351.35, 1, 0.891},
      {160, 161, "bubble_text", 0, false, 896, 347.8, 1, 0.949, 896, 345.7, 1, 0.988},
      {162, 165, "bubble_text", 0, false, 896, 345, 1, 1, 896, 348.75, 1, 1},
      {166, 168, "bubble_text", 0, false, 896, 351.65, 1, 1, 896, 360, 1, 1},
      {169, 171, "bubble_text", 0, false, 896, 361.35, 1, 1, 896, 364, 1, 1},
      {172, 175, "bubble_text", 0, false, 896, 362.65, 1, 1, 896, 360, 1, 1},
      {176, 268, "bubble_text", 0, false, 896, 360, 1, 1, 896, 360, 1, 1},
      {269, 276, "bubble_text", 0, false, 896, 360, 1, 0.891, 896, 360, 1, 0.109} },
}

local FRAME_MS = 1000.0 / 60.0

local SCENES = {
    { start = 0,    len = 150,  drum = INTRO },
    { start = 150,  len = 240,  box = 0, text = 0 },
    { start = 390,  len = 440,  box = 0, text = 1, drum = SCENE_2 },
    { start = 830,  len = 360,  box = 0, text = 2, drum = SCENE_3 },
    { start = 1190, len = 380,  box = 1, text = 3, drum = SCENE_4 },
    { start = 1570, len = 430,  box = 2, text = 4, drum = SCENE_5 },
    { start = 2000, len = 360,  box = 1, text = 5 },
    { start = 2360, len = 440,  box = 3, text = 6 },
    { start = 2800, len = 1001, box = 3, text = 7 },
    { start = 3801, len = 520,  box = 0, text = 8 },
    { start = 4321, len = 520,  box = 0, text = 9, bubble = true },
}
local END_FRAME = 4841

local GAUGE = { {750, 1}, {1489, 2}, {1869, 3}, {2299, 4}, {4000, 5}, {4121, 6} }
for i, f in ipairs({ 20, 33, 45, 56, 66, 75, 83, 90, 96, 101, 105, 109, 113, 117, 121, 125, 129, 133, 137, 141,
                     145, 149, 153 }) do
    GAUGE[#GAUGE + 1] = { 4321 + f, 6 + i }
end
for i = 0, 19 do
    GAUGE[#GAUGE + 1] = { 4321 + 279 + i * 4, 30 + i }
end
GAUGE[#GAUGE + 1] = { 4321 + 359, 50 }

local SOUNDS = {}
for i, sc in ipairs(SCENES) do
    SOUNDS[#SOUNDS + 1] = { sc.start, "tutorial_voice_" .. i, "voice" }
end
for _, f in ipairs({ 830 + 124, 830 + 148, 830 + 173 }) do
    SOUNDS[#SOUNDS + 1] = { f, "tutorial_sidebody", "sound" }
end
SOUNDS[#SOUNDS + 1] = { 2800 + 380, "tutorial_balloon", "sound" }
SOUNDS[#SOUNDS + 1] = { 4321 + 153, "tutorial_clear", "sound" }
SOUNDS[#SOUNDS + 1] = { 4321 + 359, "tutorial_burn", "sound" }
table.sort(SOUNDS, function(a, b) return a[1] < b[1] end)

-- Skip counter
local SKIP_HITS = 5
local SKIP_ICON_X = { 920.75, 997, 1073, 1149, 1225 } -- centres
local SKIP_ICON_Y = 123
local SKIP_POP_FRAMES = 12

local SKIP_BOB = { {54, 63, 0, -20, "out"}, {64, 72, -20, 0, "in"}, {73, 78, 0, -10, "out"},
                   {79, 83, -10, 0, "in"}, {84, 86, 0, -2, "out"}, {87, 89, -2, 0, "in"} }

local HIT_START = 6
local HIT_FRAMES = 29

local function ease(p, e)
    if e == "in" then return p * p end
    if e == "out" then return p * (2 - p) end
    return p
end

TutorialOverlay = {}
TutorialOverlay.__index = TutorialOverlay

function TutorialOverlay.new()
    local self = setmetatable({}, TutorialOverlay)
    self.tex = {}
    self.half = {}
    for _, name in ipairs({ "title", "skip_text", "skip_icon", "drum", "drum_don", "drum_kat", "stick", "burst",
                            "cross", "bubble", "bubble_text", "bubble_flash", "caption_box", "icon_don", "icon_kat",
                            "icon_big_don", "icon_big_kat", "icon_roll", "icon_balloon", "icon_kusudama" }) do
        self.tex[name] = tex.get_texture("game/tutorial/" .. name)
        local info = tex.get_texture_info("tutorial", name)
        self.half[name] = info and { info.x2[1] / 2, info.y2[1] / 2 } or { 0, 0 }
    end
    self.last = { don = nil, kat = nil, any = nil, l = nil, r = nil } -- latest hit: {kind, ms}
    self.captions = {} -- built layouts per caption index
    self.rim_count = 0
    self.rim_ms = {}
    return self
end

local function play(name, preset)
    if audio.has_sound(name) then
        audio.play_sound(name, preset)
    end
end

function TutorialOverlay:update(ms)
    local frame = ms / FRAME_MS
    if self.sound_frame == nil or frame < self.sound_frame then
        self.next_sound = 1
        self.bgm_started = false
    end
    self.sound_frame = frame
    if not self.bgm_started and frame >= 0 then
        self.bgm_started = true
        play("tutorial_bgm", "music")
    end
    while SOUNDS[self.next_sound] and frame >= SOUNDS[self.next_sound][1] do
        local snd = SOUNDS[self.next_sound]
        if frame - snd[1] < 30 then
            play(snd[2], snd[3])
        end
        self.next_sound = self.next_sound + 1
    end
end

function TutorialOverlay:hit(kind, side, ms)
    local h = { kind = kind, ms = ms }
    self.last[kind] = h
    self.last.any = h
    self.last[side] = h
end

function TutorialOverlay:gauge(ms)
    local f, cells = ms / FRAME_MS, 0
    for _, g in ipairs(GAUGE) do
        if f >= g[1] then cells = g[2] else break end
    end
    return cells / 50
end

function TutorialOverlay:is_finished(ms)
    return ms / FRAME_MS >= END_FRAME
end

function TutorialOverlay:put(name, frame, cx, cy, scale, alpha, mirror)
    local h = self.half[name]
    tex.draw_texture(self.tex[name], {
        frame = frame,
        x = cx - h[1],
        y = cy - h[2],
        scale = scale,
        center = true,
        fade = alpha,
        mirror = mirror and "horizontal" or nil,
    })
end

function TutorialOverlay:draw_track(track, f)
    for _, r in ipairs(track) do

        if f >= r[1] and f < r[2] + 1 then
            local p = r[2] > r[1] and math.min((f - r[1]) / (r[2] - r[1]), 1) or 0
            local function lerp(a, b) return a + (b - a) * p end
            self:put(r[3], r[4], lerp(r[6], r[10]), lerp(r[7], r[11]), lerp(r[8], r[12]), lerp(r[9], r[13]), r[5])
            return
        end
    end
end

function TutorialOverlay:draw_tracks(tracks, f)
    local last = 0
    for _, t in ipairs(tracks) do
        last = math.max(last, t[#t][2])
    end
    f = math.min(f, last)
    for _, t in ipairs(tracks) do
        self:draw_track(t, f)
    end
end

function TutorialOverlay:hit_frame(h, ms)
    if not h then return nil end
    local f = HIT_START + (ms - h.ms) / FRAME_MS
    if f >= HIT_FRAMES then return nil end
    return f
end


function TutorialOverlay:draw_reactive_drum(ms)
    local f = self:hit_frame(self.last.any, ms)
    if f then
        self:draw_track((self.last.any.kind == "kat" and HIT_KAT or HIT_DON)[1], f)
    else
        self:put("drum", 0, 640, 168, 1, 1, false)
    end
    for _, kind in ipairs({ "don", "kat" }) do
        local fk = self:hit_frame(self.last[kind], ms)
        if fk then
            self:draw_track((kind == "kat" and HIT_KAT or HIT_DON)[2], fk)
        end
    end
    for i, side in ipairs({ "r", "l" }) do
        local fs = self:hit_frame(self.last[side], ms)
        if fs then
            self:draw_track((self.last[side].kind == "kat" and HIT_KAT or HIT_DON)[2 + i], fs)
        elseif side == "r" then
            self:put("stick", 0, 745, 155, 1, 1, false)
        else
            self:put("stick", 0, 525, 155, 1, 1, true)
        end
    end
end

local CAPTION_FONT = 38
local CAPTION_LEFT, CAPTION_RIGHT, CAPTION_MID = 46, 650, 348
local CAPTION_ROWS = { { 96 }, { 58, 128 }, { 43, 95, 147 } }
local CAPTION_ICON_GAP = 4

function TutorialOverlay:caption(i)
    local c = self.captions[i]
    if c then return c end
    c = {}
    local str = tex.skin_text("tutorial_caption_" .. i)
    for line in (str .. "\n"):gmatch("(.-)\n") do
        local l = { parts = {}, width = 0 }
        local pos = 1
        while pos <= #line do
            local a, b, name = line:find("{([%w_]+)}", pos)
            local chunk = line:sub(pos, (a or #line + 1) - 1)
            if #chunk > 0 then
                local t = text.create_raw_text(chunk, CAPTION_FONT, { 0, 0, 0, 255 }, { 255, 255, 255, 0 }, false, 4, 2.0)
                l.parts[#l.parts + 1] = { text = t, w = t.width }
                l.width = l.width + t.width
            end
            if not a then break end
            local key = "icon_" .. name
            if self.tex[key] then
                local w = self.half[key][1] * 2 + CAPTION_ICON_GAP * 2
                l.parts[#l.parts + 1] = { icon = key, w = w }
                l.width = l.width + w
            end
            pos = b + 1
        end
        c[#c + 1] = l
    end
    self.captions[i] = c
    return c
end

function TutorialOverlay:draw_caption_text(i, x0, y0)
    local lines = self:caption(i)
    local rows = CAPTION_ROWS[math.min(#lines, #CAPTION_ROWS)]
    local avail = CAPTION_RIGHT - CAPTION_LEFT
    for k, l in ipairs(lines) do
        if k > #rows then break end
        local s = math.min(1, avail / math.max(l.width, 1)) -- long translations shrink to fit
        local w = l.width * s
        local x
        if #lines == 1 then
            x = CAPTION_MID - w / 2
        else
            x = CAPTION_LEFT + (avail - w) * (k - 1) / (#lines - 1)
        end
        local cy = y0 + rows[k]
        x = x0 + x
        for _, part in ipairs(l.parts) do
            if part.text then
                part.text:draw({ x = x, y = cy - part.text.height * s / 2, scale = s })
            else
                self:put(part.icon, 0, x + part.w * s / 2, cy, s, 1, false)
            end
            x = x + part.w * s
        end
    end
end

function TutorialOverlay:draw_caption(scene, f)
    if not scene.box then return end
    local cx
    if f < 20 then
        cx = 1640 - 1000 * ease(f / 19, "out")
    elseif f >= scene.len - 20 then
        cx = 640 - 1000 * ease((f - (scene.len - 20)) / 19, "in")
    else
        cx = 640
    end
    tex.draw_texture(self.tex.caption_box, { frame = scene.box, x = cx - 640 })
    self:draw_caption_text(scene.text + 1, 288 + 4 + cx - 640, 457 + 4)
end

local function slide_in(f, f0, from, over, n1, n2)
    if not f then return 0 end
    if f < f0 then return nil end
    if f < f0 + n1 then return from + (over - from) * ease((f - f0) / n1, "out") end
    if f < f0 + n1 + n2 then return over * (1 - ease((f - f0 - n1) / n2, "in")) end
    return 0
end

function TutorialOverlay:draw_skip(ms, rim_count, intro_f)
    while self.rim_count < rim_count do
        self.rim_count = self.rim_count + 1
        self.rim_ms[self.rim_count] = ms
    end
    local f = (ms / FRAME_MS - SCENES[2].start) % 90
    local y = 0
    for _, b in ipairs(intro_f and {} or SKIP_BOB) do
        if f >= b[1] and f <= b[2] + 1 then
            y = b[3] + (b[4] - b[3]) * ease(math.min((f - b[1]) / (b[2] + 1 - b[1]), 1), b[5])
        end
    end
    local text_dx = slide_in(intro_f, 14, 462, -14, 20, 5)
    if text_dx then
        tex.draw_texture(self.tex.skip_text, { x = text_dx, y = y })
    end
    for i = 1, SKIP_HITS do
        local scale = 1
        if i <= self.rim_count then
            local pf = (ms - self.rim_ms[i]) / FRAME_MS
            if pf >= SKIP_POP_FRAMES then
                scale = nil
            elseif pf >= 7 then
                scale = 1.348 + (0.1 - 1.348) * ease((pf - 7) / 5, "in")
            elseif pf >= 2 then
                scale = 1.144 + (1.4 - 1.144) * ease((pf - 2) / 5, "out")
            end
        end
        if scale then
            local dx = slide_in(intro_f, 28 + i, 423, -10, 18, 7)
            if dx then
                self:put("skip_icon", 0, SKIP_ICON_X[i] + dx, SKIP_ICON_Y, scale, 1, false)
            end
        end
    end
end

function TutorialOverlay:scene_at(ms)
    local frame = ms / FRAME_MS
    local scene, f
    for _, s in ipairs(SCENES) do
        if frame >= s.start then scene, f = s, frame - s.start end
    end
    return scene, f
end

function TutorialOverlay:draw_back(ms)
    local scene, f = self:scene_at(ms)
    if not scene then return end
    if scene.drum then
        self:draw_tracks(scene.drum, math.floor(f))
    else
        self:draw_reactive_drum(ms)
    end
end

function TutorialOverlay:draw(ms, rim_count)
    local scene, f = self:scene_at(ms)
    if not scene then return end
    local intro_f = scene == SCENES[1] and f or nil
    local title_dx = slide_in(intro_f, 14, -378, 10, 20, 5)
    if title_dx then
        tex.draw_texture(self.tex.title, { x = title_dx })
    end
    self:draw_skip(ms, rim_count, intro_f)
    if intro_f then return end
    if scene.bubble then
        for _, t in ipairs(BUBBLE) do
            self:draw_track(t, math.floor(f))
        end
    end
    self:draw_caption(scene, f)
end
