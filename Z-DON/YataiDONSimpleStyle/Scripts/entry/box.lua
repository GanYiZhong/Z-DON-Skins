-- YataiDONSimpleStyle v2: entry mode boards. One dialog above the stage holds every mode as a button
-- (left column) and the selected mode's description (right column). Selection = the focused gold
-- button + a blinking ▶ (400 ms on / off) that nudges 1U in the move direction for 66 ms; decide =
-- the pressed button. The window opens in 3 frames. The C++ BoxManager owns input; this only draws.
-- No Nijiiro board art is used (entry/mode_select keys are blanked). Logical 1920x1080 coordinates.
local UI = require("global.ss_ui")

EntryBox = {}
EntryBox.__index = EntryBox

__ss_boxes = __ss_boxes or {}
__ss_mode = __ss_mode or {}

local U = UI.U
local INK, MUTE = UI.P.ink, UI.P.mute
local DLG = { 570, 294, 780, 240 }
local BTN_X, BTN_W, BTN_H, GAP = 615, 309, 48, 9
local DESC_X, DESC_W = 954, 381
local TITLE_SIZE, DESC_SIZE = 36, 24
local DESC_LINE = 36

local COMMENTS = {
    entry_game     = { "entry_game_comment_1", "entry_game_comment_2" },
    entry_practice = { "entry_practice_comment_1", "entry_practice_comment_2" },
    entry_costume  = { "entry_costume_comment_1", "entry_costume_comment_2" },
    entry_dan      = { "mode_dan_comment_1", "mode_dan_comment_2", "mode_dan_comment_3" },
    entry_settings = { "entry_settings_comment_1", "entry_settings_comment_2" },
    entry_ai_battle = { "entry_ai_battle_comment_1", "entry_ai_battle_comment_2" },
    entry_record = { "entry_record_comment_1", "entry_record_comment_2" },
}


local function skin_text(key)
    local ok, s = pcall(function() return tex.skin_text(key) end)
    if ok and type(s) == "string" then return s end
    return nil
end

function EntryBox.new(text_str, font_size, mode_key)
    local self = setmetatable({}, EntryBox)
    if __hss_entry_reset then
        __ss_boxes = {}
        __ss_mode = { sel = nil, sel_t = 0, dir = 0, open_t = nil, decided = false }
        __hss_entry_reset = false
    end
    __ss_boxes[#__ss_boxes + 1] = self
    self.index = #__ss_boxes
    self.title = UI.text(text_str, TITLE_SIZE)
    self.title_off = UI.text(text_str, TITLE_SIZE, { color = MUTE, outline = false })
    self.desc = {}
    for _, key in ipairs(COMMENTS[mode_key or ""] or {}) do
        local s = skin_text(key)
        if s and s ~= "" then self.desc[#self.desc + 1] = UI.text(s, DESC_SIZE) end
    end
    return self
end

-- the window: DLG, grown about its centre when the buttons need more height (6-7 boards with the AI battle and recording)
local function dlg(n)
    local need = n * BTN_H + (n - 1) * GAP + 14 * U
    if need <= DLG[4] then return DLG[2], DLG[4] end
    local h = math.ceil(need / U) * U
    return UI.grid(DLG[2] + DLG[4] / 2 - h / 2), h
end

local function button_y(i, n)
    local dy, dh = dlg(n)
    local total = n * BTN_H + (n - 1) * GAP
    local top = dy + math.floor((dh - total) / 2 / U) * U
    return top + (i - 1) * (BTN_H + GAP)
end

-- Box::draw(x, left_x, right_x, is_selected, move_finished, open_attr, fade, y_pos, has_prev, has_next, disabled)
function EntryBox:draw(x, left_x, right_x, is_selected, move_finished, open_attr, fade, y_pos, has_prev, has_next,
                       disabled)
    local now = tex.get_current_ms()
    local m = __ss_mode
    local n = #__ss_boxes
    __hss_entry_guide = { ms = now, phase = "mode", count = n }
    fade = fade or 1.0
    -- alpha policy: the engine's decide fade is snapped (the window holds, then is gone)
    if UI.solid(fade) == 0 then return end
    local a = 255
    local dy, dh = dlg(n)

    if self.index == 1 then
        if m.open_t == nil then m.open_t = now end
        local t = now - m.open_t
        if t < 100 then      -- window open: 33 % -> 66 % (then 100 % with the contents)
            local h = UI.grid(dh * (t < 50 and 1 / 3 or 2 / 3))
            UI.chrome.dialog(DLG[1], UI.grid(dy + (dh - h) / 2), DLG[3], h, a)
            m.opening = true
            return
        end
        m.opening = false
        UI.chrome.dialog(DLG[1], dy, DLG[3], dh, a)
        UI.rect(DESC_X - 6 * U, dy + 9 * U, U, dh - 18 * U, UI.P.line, a)
    end
    if m.opening then return end

    if is_selected and m.sel ~= self.index then
        if m.sel ~= nil then
            m.dir = (self.index > m.sel) and 1 or -1
            if SS_ENTRY and SS_ENTRY.momo then SS_ENTRY.momo:react("move") end
        end
        m.sel, m.sel_t = self.index, now
    end

    local by = button_y(self.index, n)
    local decided = is_selected and fade < 0.999
    if decided and not m.decided then
        m.decided = true
        if SS_ENTRY and SS_ENTRY.momo then SS_ENTRY.momo:react("decide") end
        if SS_ENTRY and SS_ENTRY.hoshi then SS_ENTRY.hoshi:react("decide") end
    end
    local state = "normal"
    if decided then state = "pressed" elseif is_selected then state = "focused" end
    local ix, iy, iw, ih
    if disabled then
        ix, iy, iw, ih = UI.frame(BTN_X, by, BTN_W, BTN_H, { fill = UI.P.bg3, a = a })
    else
        ix, iy, iw, ih = UI.chrome.button(BTN_X, by, BTN_W, BTN_H, state, a)
    end
    local t = disabled and self.title_off or self.title
    UI.draw_text(t, ix + iw / 2, iy + ih / 2, "c")

    if is_selected then
        -- ▶: blinks 400/400 ms; nudges 1U in the move direction for 66 ms after a move
        local since = now - m.sel_t
        if UI.blink_on(since, 400) and SS_ENTRY and SS_ENTRY.cursor then
            local ny = (since < 66) and m.dir * U or 0
            tex.draw_texture(SS_ENTRY.cursor, { x = BTN_X - 8 * U, y = UI.grid(by + BTN_H / 2 - 16) + ny })
        end
        -- description column, vertically centred
        local k = #self.desc
        local y0 = dy + dh / 2 - (k * DESC_LINE) / 2
        for i, d in ipairs(self.desc) do
            UI.draw_text(d, DESC_X, y0 + (i - 1) * DESC_LINE + DESC_LINE / 2, "l")
        end
    end
end
