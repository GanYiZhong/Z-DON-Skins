-- YataiDONSimpleStyle v2: the combo counter on the drum face.
-- The engine's Combo (combo.h) calls update every frame with the player's combo; this draws it.
-- Digits: block pixel digits (combo/counter*), ink below 50, paper with an ink outline from 50, gold
-- with an ink outline from 100 (4+ digits: the 1U-cell set). A hit pops the number 2U up, then 1U, then rest (one frame each, no stretching). From 100
-- the drum face gets a 1U gold inner ring (drawn here, on the U grid). Every 50 the number flashes
-- gold for 4 frames and the portrait reacts (game/ss_play.lua). The word under the digits is engine
-- text in the player's language (ss/strings.py combo_word).

local UI = require("global.ss_ui")
local Play = require("game/ss_play")
local P = UI.P
local U = UI.U

Combo = {}
Combo.__index = Combo

local MARGIN = 52            -- digit pitch (cells are 64 wide, block digits 42)
local FACE_CX, FACE_CY = 400, 102   -- drum face centre (lane-relative), r 78 + 1U ink ring
local POP_MS = 16.67
-- the combo word's centre (lane-relative): combo/combo_ja's rect (x 320, y 136, 160 x 40)
local LABEL_CX, LABEL_CY = 400, 156

-- the drum face's gold ring at 100+: a 1U ring just inside the ink ring, as U cells
local RING = nil
local function ring_cells()
    if RING then return RING end
    RING = {}
    local r = 26            -- face radius in cells (78 / 3)
    local inner = r - 1
    for yy = 0, 2 * r - 1 do
        for xx = 0, 2 * r - 1 do
            local dx, dy = xx + 0.5 - r, yy + 0.5 - r
            local d2 = dx * dx + dy * dy
            if d2 <= r * r and d2 > inner * inner then RING[#RING + 1] = { xx - r, yy - r } end
        end
    end
    return RING
end

function Combo.new(combo, current_ms)
    local self = setmetatable({}, Combo)
    self.combo = combo
    self.hit_t = -1e9
    self.flash_t = -1e9
    self.player = nil
    self.t_counter      = tex.get_texture("combo/counter")
    self.t_counter_gold = tex.get_texture("combo/counter_gold")
    self.t_counter_100  = tex.get_texture("combo/counter_100")
    local li = tex.get_texture_info("combo", "combo_ja")
    if li and li.x and li.x[1] then LABEL_CX, LABEL_CY = li.x[1] + li.width / 2, li.y[1] + li.height / 2 end
    self.t_small = {
        ink = tex.get_texture("game/ss_combo/small_ink"),
        paper = tex.get_texture("game/ss_combo/small_paper"),
        gold = tex.get_texture("game/ss_combo/small_gold"),
    }
    return self
end

function Combo:update(ms, combo)
    self.ms = ms
    if combo ~= self.combo then
        if combo > self.combo then
            self.hit_t = ms
            if combo >= 50 and combo % 50 == 0 then self.flash_t = ms end
        end
        self.combo = combo
        self.changed = true
    end
end

function Combo:draw(y)
    -- the score counter of the same player draws just before this (draw_overlays order)
    local n = Play.current or 1
    if self.changed then
        Play.combo(n, self.combo)
        self.changed = false
    end
    if self.combo < 3 then return end
    local ms = self.ms or tex.get_current_ms()
    local gold = self.combo >= 100 or (ms - self.flash_t < 4 * 16.67)
    local silver = self.combo >= 50 and not gold

    if self.combo >= 100 then
        local cx, cy = FACE_CX, y + FACE_CY
        for _, c in ipairs(ring_cells()) do
            UI.rect(cx + c[1] * U, cy + c[2] * U, U, U, P.clear)
        end
    end

    local digits = gold and self.t_counter_gold or (silver and self.t_counter_100 or self.t_counter)
    local str = tostring(self.combo)
    -- the hit pop: 2U up on the hit frame, 1U the next, then rest (a constant 1U step per 16.7 ms)
    local pf = math.floor((ms - self.hit_t) / POP_MS)
    local pop = (pf == 0 and 2 * U) or (pf == 1 and U) or 0
    -- the word under the digits (コンボ / Combo / 连击 / 콤보): run-time text, 18 px, ink (gold_t from 100),
    -- centred in the combo_ja rect (the texture itself is empty)
    UI.draw_text(UI.text_key("combo_word", 18, { color = gold and P.gold_t or P.ink }),
                 LABEL_CX, y + LABEL_CY - 6, "c")
    -- keep the number inside the face minus 2U (paper radius 72): 2-3 digits at pitch 36 (neighbouring
    -- 1-cell ink outlines touch: the number reads as one word), 4+ digits in the 1U-cell set at pitch 18
    local n = #str
    if n <= 3 then
        local m = (n == 1) and MARGIN or 36
        local x0 = -((n - 1) * m + 42) / 2 - 4
        for i = 1, n do
            tex.draw_texture(digits, { frame = str:byte(i) - 48, x = x0 + (i - 1) * m, y = y - pop })
        end
    else
        local t = self.t_small[gold and "gold" or (silver and "paper" or "ink")]
        if t then
            local p = 18
            local left = FACE_CX - ((n - 1) * p + 21) / 2 - 3
            for i = 1, n do
                tex.draw_texture(t, { frame = str:byte(i) - 48, x = UI.grid(left) + (i - 1) * p,
                                      y = y + 81 - pop })
            end
        end
    end
end
