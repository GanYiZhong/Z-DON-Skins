-- YataiDONSimpleStyle v2: entry screen (Nijiiro's arcade-credit flow, our own drawing).
-- The festival stage (entry/background/bg: sky, lanterns, the deck with the taiko centre stage);
-- Momo (left) and Hoshi (right) stand on the deck facing the taiko. WAITING: the PRESS DON bubble
-- comes out of the drum and the pair take turns on it. SELECT_SIDE: the credit rows (1人プレイ /
-- 2人プレイ) in one dialog above the stage. The mode boards are box.lua; joins are player.lua.
-- The control hint is the one core pill (UI.hint) at the footer rule (bottom centre).
-- No Nijiiro board / credit / street art is drawn. Coordinates: logical 1920x1080 (ss/v2_front.py).
local UI = require("global.ss_ui")
local FX = require("title.front_fx")

Entry = {}
Entry.__index = Entry

local INK = UI.P.ink
local DECK = 858
local MOMO_CX, HOSHI_CX = 600, 1320
local DRUM_CX, DRUM_TOP = 960, 678
local BUBBLE_TIP_Y = DRUM_TOP - 12            -- the PRESS DON bubble's tail tip, just above the drum
-- the join spots' player tags on the deck front (ss/v2_front.py join_spot): ink from x, centre y
local JOIN_TAG = { { "player_1p", 129 }, { "player_2p", 1842 } }
local JOIN_TAG_Y = 886.5
local DLG = { 570, 294, 780, 240 }            -- x, y, w, h (the shared dialog above the stage)
local U = UI.U
-- polish: drifting clouds (front_fx.lua; the sky band 0..228, behind the meta boards), note pops off the
-- drum's rims on each WAITING hit (sideways, under the PRESS DON bubble), and the bubble bobs 1U for
-- 100 ms on each hit
local CLOUDS = { { 444, 45, "M" }, { 1104, 132, "S" }, { 1650, 150, "S" } }
local POP = { { 873, 699, -1 }, { 1047, 699, 1 } }     -- Momo (don, left rim), Hoshi (ka, right rim)

-- shared with box.lua / player.lua (one Lua state per screen)
SS_ENTRY = SS_ENTRY or {}

function Entry.new()
    local self = setmetatable({}, Entry)
    __hss_entry_reset = true
    UI.reset()

    self.side_select_fade = tex.get_animation(0, "entry")

    self.bg = tex.get_texture("entry/background/bg")
    self.clouds = FX.Clouds.new("entry", CLOUDS)
    self.pops = FX.Pops.new("entry")
    self.bob_t = -100000
    self.t_cursor = tex.get_texture("entry/ss_front/cursor")

    self.momo  = UI.Mascot.new({ char = "momo", role = "scene", beat = false })
    self.hoshi = UI.Mascot.new({ char = "hoshi", role = "scene", beat = false })
    self.momo:react("turn", 1)
    self.hoshi:react("turn", -1)
    SS_ENTRY = { momo = self.momo, hoshi = self.hoshi, cursor = self.t_cursor, join = {}, dlg = DLG }

    local c = { INK[1], INK[2], INK[3], 255 }
    self.t_p = { text.create_text("entry_credit_1p", c, c, false, 0, 0),
                 text.create_text("entry_credit_2p", c, c, false, 0, 0) }
    self.t_msg = text.create_text("entry_credit_start", c, c, false, 0, 0)
    self.t_cancel = text.create_text("entry_cancel", c, c, false, 0, 0)
    -- paper on the saturated player fill, 1U ink outline
    self.t_tag = { UI.text_key("player_1p", 24, "paper"), UI.text_key("player_2p", 24, "paper") }
    -- the deck's join-spot tags: 24 px (text24) paper, no outline (on the plank's accent fill)
    self.t_join = {}
    for i, j in ipairs(JOIN_TAG) do
        self.t_join[i] = UI.text_key(j[1], 24, { color = UI.P.paper, outline = false })
    end

    self.cr_arcade = tex.get_option("entry_credit_arcade")
    self.cr_side = 1
    self.cr_t0 = tex.get_current_ms()
    self.decide_t0, self.decide_row, self.pending = nil, nil, nil
    self.seen_frame, self.frame = nil, 0
    self.waiting_hit = -1
    self.any_joined = false
    self.now = tex.get_current_ms()
    return self
end

function Entry:update(current_ms)
    self.now = current_ms
    self.side_select_fade:update(current_ms)
    self.frame = self.frame + 1
    self.momo:update(current_ms)
    self.hoshi:update(current_ms)
end

function Entry:start_side_select()
    self.side_select_fade:start()
    self:restart_credit()
end

function Entry:restart_side_select()
    self.side_select_fade:restart()
    self:restart_credit()
end

function Entry:restart_credit()
    self.cr_t0 = tex.get_current_ms()
    self.cr_side = 1
    self.decide_t0, self.decide_row, self.pending, self.seen_frame = nil, nil, nil, nil
end

function Entry:get_side_select_fade()
    return self.side_select_fade.attribute
end

-- the one hint pill (core), bottom centre; hidden once a player has joined (the nameplates own the footer)
function Entry:draw_control_guide()
    if not self.any_joined then UI.hint({ { "don", "h_decide" } }) end
end

-- ---------------------------------------------------------------- the stage + cast (every state)
function Entry:draw_background()
    tex.draw_texture(self.bg)
    self.clouds:draw(self.now)
    for i, j in ipairs(JOIN_TAG) do
        local t = self.t_join[i]
        UI.draw_text(t, j[2] - UI.text_pad(t), JOIN_TAG_Y, "l")
    end
    self.momo:draw(MOMO_CX, DECK)
    self.hoshi:draw(HOSHI_CX, DECK)
    local j = SS_ENTRY.join or {}
    if j[0] then UI.burst(MOMO_CX, DECK - 240, self.now - j[0]) end
    if j[1] then UI.burst(HOSHI_CX, DECK - 240, self.now - j[1]) end
    self.pops:draw(self.now)
end

function Entry:draw_side_select() end

-- WAITING (arcade credit): the PRESS DON bubble from the drum; the pair take turns on the taiko
function Entry:draw_waiting()
    __hss_entry_guide = { ms = self.now, phase = "wait" }
    local n = math.floor((self.now - self.cr_t0) / 600)
    if n ~= self.waiting_hit then
        self.waiting_hit = n
        local who = (n % 4 == 0) and 1 or ((n % 4 == 2) and 2 or nil)
        if who then
            local m = (who == 1) and self.momo or self.hoshi
            if not (SS_ENTRY.join or {})[who - 1] then   -- a joined player stands ready (player.lua)
                m:react("hit")
                local p = POP[who]
                self.pops:emit(who - 1, p[1], p[2], p[3], self.now)
                self.bob_t = self.now
            end
        end
    end
    local bob = (self.now - self.bob_t < 100) and U or 0
    UI.bubble("entry_start_don", DRUM_CX, BUBBLE_TIP_Y - bob)
    self:draw_control_guide()
end

-- ---------------------------------------------------------------- credit rows (SELECT_SIDE)
local ROW_H = 102
local ROW_Y = { DLG[2] + 24, DLG[2] + 24 + ROW_H }

local function blink(ms) return (math.floor(ms / 400) % 2) == 0 end

function Entry:draw_row(row, state, a)
    local x, y, w, h = DLG[1] + 18, ROW_Y[row], DLG[3] - 42, ROW_H - 12
    local ix, iy, iw, ih = UI.chrome.button(x, y, w, h, state, a)
    -- player cell: p1 / p2 fill with an ink divider and the 1P / 2P tag
    local acc = (row == 1) and UI.P.p1 or UI.P.p2
    UI.rect(ix, iy, 18 * U, ih, acc, a)
    UI.rect(ix + 18 * U, iy, U, ih, INK, a)
    local tag = self.t_tag[row]
    tag:draw({ x = UI.px(ix + 9 * U - tag.width / 2), y = UI.px(iy + ih / 2 - tag.height / 2), fade = UI.solid(a) })
    local lbl = self.t_p[row]
    if lbl then
        lbl:draw({ x = UI.px(ix + 24 * U), y = UI.px(iy + ih / 2 - lbl.height / 2), fade = UI.solid(a) })
    end
    if self.t_msg and (state ~= "normal" or blink(self.now - self.cr_t0)) then
        self.t_msg:draw({ x = UI.px(ix + iw - 6 * U - self.t_msg.width), y = UI.px(iy + ih / 2 - self.t_msg.height / 2),
                          fade = UI.solid(a) })
    end
    if state == "focused" and blink(self.now - self.cr_t0) and SS_ENTRY.cursor then
        tex.draw_texture(SS_ENTRY.cursor, { x = x - 8 * U, y = UI.grid(y + h / 2 - 16) })
    end
end

function Entry:draw_credit(sel, a, pressed_row)
    UI.chrome.dialog(DLG[1], DLG[2], DLG[3], DLG[4], a)
    for row = 1, 2 do
        local st = "normal"
        if pressed_row == row then st = "pressed"
        elseif sel == row then st = "focused" end
        self:draw_row(row, st, a)
    end
end

function Entry:draw_side_select_buttons(side)
    __hss_entry_guide = { ms = self.now, phase = "side" }
    if side ~= self.cr_side then
        if self.cr_side ~= nil then self.momo:react("move") end
        self.cr_side = side
    end
    self.seen_frame = self.frame
    self.decide_t0 = nil
    -- window open: 3 frames, 50 ms each
    local t = self.now - self.cr_t0
    if t < 100 then
        local h = UI.grid(DLG[4] * (t < 50 and 1 / 3 or 2 / 3))
        UI.chrome.dialog(DLG[1], UI.grid(DLG[2] + (DLG[4] - h) / 2), DLG[3], h)
    else
        local sel = nil
        if not self.cr_arcade then sel = (side == 0 and 1) or (side == 2 and 2) or nil end
        self:draw_credit(sel, 255, nil)
        if not self.cr_arcade and self.t_cancel then
            local cx, cy = DLG[1] + DLG[3] / 2, DLG[2] + DLG[4] + 30
            local st = (side == 1) and "focused" or "normal"
            local bw = 78 * U
            UI.chrome.button(UI.grid(cx - bw / 2), UI.grid(cy - 21), bw, 42, st)
            self.t_cancel:draw({ x = UI.px(cx - self.t_cancel.width / 2), y = UI.px(cy - self.t_cancel.height / 2) })
        end
    end
    self:draw_control_guide()
end

function Entry:decide_side_select(side)
    self.pending = (side == 2) and 2 or 1
end

function Entry:draw_footer(p1_joined, p2_joined)
    YD_ENTRY_BOTH_JOINED = (p1_joined == true and p2_joined == true)
    self.any_joined = (p1_joined == true or p2_joined == true)
end

-- after a decide: the chosen row shows pressed for 150 ms, then the window closes in 2 frames
function Entry:draw_player_entry()
    if self.seen_frame ~= nil and self.decide_t0 == nil and self.frame > self.seen_frame then
        self.seen_frame = nil
        local row = self.pending
        if not row and (self.cr_side == 0 or self.cr_side == 2) then row = (self.cr_side == 0) and 1 or 2 end
        self.pending = nil
        if row then self.decide_t0, self.decide_row = self.now, row end
    end
    if not self.decide_t0 then return end
    local t = self.now - self.decide_t0
    if t < 150 then
        self:draw_credit(nil, 255, self.decide_row)
    elseif t < 250 then
        local h = UI.grid(DLG[4] * (t < 200 and 2 / 3 or 1 / 3))
        UI.chrome.dialog(DLG[1], UI.grid(DLG[2] + (DLG[4] - h) / 2), DLG[3], h)
    else
        self.decide_t0 = nil
    end
end
