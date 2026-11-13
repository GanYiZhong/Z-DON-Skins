-- Global credit line / QR chip / 2P invite cloud, drawn on every non-game screen.

CoinOverlay = {}
CoinOverlay.__index = CoinOverlay

local ca_ok, cs_anim = pcall(require, "anim/sampler")
if not ca_ok then cs_anim = { safe = function()
    local n = {}
    n.at = function() return nil end; n.get = function() return nil end
    n.label = function() return nil end; n.has = function() return false end
    n.first = function() return 0 end;  n.last = function() return 0 end
    return n
end } end
local credit_side        = cs_anim.safe("anim/credit_side")
local credit_side_len    = math.max(1, credit_side:last() - credit_side:first() + 1)   -- 180 frames = 3 s
local credit_side_pop_f  = 8

function CoinOverlay.new()
    local self  = setmetatable({}, CoinOverlay)
    self.text   = text.create_text("free_play", { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 3, 5)
    self.config = tex.get_skin_config("free_play")
    self.qr     = tex.get_texture("global/overlay/banapass_osaifu_keitai")  -- QR chip (0 NG / 1 OK)
    self.bubble = tex.get_texture("global/overlay/camera")                   -- 2P cloud bubble
    self.bubble_player = text.create_text("credit_side_player", { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 4, 2)
    self.bubble_msg    = text.create_text("credit_side_msg",    { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 4, 2)
    self.bubble_cfg_p  = tex.get_skin_config("credit_side_player")
    self.bubble_cfg_m  = tex.get_skin_config("credit_side_msg")
    self.blink_t0 = tex.get_current_ms()
    return self
end

function CoinOverlay:update(current_ms) end

local FREE_PLAY_CY = 1046
local BUBBLE_PLAYER_CY = 749
local BUBBLE_MSG_CY    = 802
local BUBBLE_BOX_W = 416   -- cloud art width

-- Centred, whole-pixel-snapped OutlinedText draw clamped to `box_w`.
local function draw_bubble_line(t, cfg, cx, cy, fade)
    if not t or t.width == nil then return end
    local w = math.floor(math.min(t.width, BUBBLE_BOX_W) + 0.5)
    t:draw({ x  = math.floor(cx - w / 2 - cfg.x + 0.5),
             y  = math.floor(cy - t.height / 2 - cfg.y + 0.5),
             x2 = w - t.width,
             fade = fade })
end

local CREDIT_SCREENS = {
    ENTRY = true,
    PRACTICE_SELECT = true, RECORD_SELECT = true,
    TITLE = true, RESULT = true,
    -- DAN_SELECT, SONG_SELECT and AI_SELECT intentionally absent (no credit line there).
}

function CoinOverlay:draw(x, y)
    local screen = tex.current_screen and tex.current_screen() or ""
    -- unknown/blank screen keeps the always-on behaviour
    local show_credit = (screen == "") or (CREDIT_SCREENS[screen] == true)
    if show_credit then
        local text_x = math.floor(tex.get_screen_width() / 2 - self.text.width / 2 - self.config.x + 0.5)
        local text_y = math.floor(FREE_PLAY_CY - self.text.height / 2 - self.config.y + 0.5)
        self.text:draw({ x = text_x, y = text_y })
    end
    if tex.in_transition and tex.in_transition() then return end
    -- per-frame hook for a screen to draw above the credit text
    if YD_DRAW_ABOVE_CREDIT then
        local fn = YD_DRAW_ABOVE_CREDIT
        YD_DRAW_ABOVE_CREDIT = nil
        fn()
    end

    local chip_screens = (screen == "ENTRY" or screen == "SONG_SELECT" or screen == "SONG_SELECT_2P"
        or screen == "PRACTICE_SELECT" or screen == "AI_SELECT" or screen == "RECORD_SELECT"
        or screen == "DAN_SELECT")
    if chip_screens and not (tex.in_transition and tex.in_transition()) then
        tex.draw_texture(self.qr, { frame = 0 })
    end

    local scr = (screen ~= "") and screen or "ENTRY"
    -- the 2P invite (AI_SELECT has none: the AI already holds the 2P side)
    local on_entry_or_select = (scr == "ENTRY" or scr == "SONG_SELECT" or scr == "SONG_SELECT_2P"
        or scr == "PRACTICE_SELECT")
    local pn = tex.player_num()
    local both_joined = (pn == 3) or (scr == "SONG_SELECT_2P")
        or (scr == "ENTRY" and YD_ENTRY_BOTH_JOINED == true)
    local credit_up = (scr == "ENTRY") and YD_ENTRY_CREDIT_MS ~= nil
        and (tex.get_current_ms() - YD_ENTRY_CREDIT_MS) < 100
    local join_window = (scr == "ENTRY") or not tex.songs_played or (tex.songs_played() < 2)
    if on_entry_or_select and join_window and not credit_up and not both_joined and (pn == 1 or pn == 2) then
        local side = (pn == 1) and 0 or 1
        local cx_p = (pn == 1) and self.bubble_cfg_p.x or (tex.get_screen_width() - self.bubble_cfg_p.x)
        local cx_m = (pn == 1) and self.bubble_cfg_m.x or (tex.get_screen_width() - self.bubble_cfg_m.x)
        local elapsed = tex.get_current_ms() - self.blink_t0
        local f   = (elapsed * 0.06) % credit_side_len             -- arcade frame 0..179
        local pop = math.min(1, elapsed * 0.06 / credit_side_pop_f)  -- pop-in on first show
        local fade   = (credit_side:get("#3@0", f, "a") or 0) * pop
        local fade_t = (credit_side:get("credit_all_instance", f, "a") or 0) * pop
        tex.draw_texture(self.bubble, { index = side, fade = fade })
        draw_bubble_line(self.bubble_player, self.bubble_cfg_p, cx_p, BUBBLE_PLAYER_CY, fade_t)
        draw_bubble_line(self.bubble_msg,    self.bubble_cfg_m, cx_m, BUBBLE_MSG_CY,    fade_t)
    end
end
