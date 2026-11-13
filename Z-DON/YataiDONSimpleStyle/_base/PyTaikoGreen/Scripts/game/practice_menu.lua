PracticeMenu = {}
PracticeMenu.__index = PracticeMenu

local S = tex.get_screen_scale()
local SKIN = {
    panel = { y = 48 * S, width = 940 * S, height = 460 * S },
    bar = { gap = 36 * S, width = 92 * S, height = 378 * S },
    label = { y = 16 * S, width = 350 * S, font_size = math.floor(40 * S) },
    dialog_font_size = math.floor(40 * S),
    dialog_title_y = 100 * S,
    dialog_title_auto_y = 56 * S,
    button = { x = 160 * S, y = 240 * S, width = 212 * S, height = 102 * S },
    auto_label = { y = 150 * S, width = 290 * S },
    auto_toggle = { gap = 40 * S, y = 280 * S, width = 240 * S },
    toggle_y = 6 * S,
}

local WHITE, BLACK = { 255, 255, 255, 255 }, { 0, 0, 0, 255 }

local ROWS = {
    "practice_menu_end_game", "practice_menu_another_song", "practice_menu_restart",
    "practice_menu_auto_play", "practice_menu_jump_to_mark", "practice_menu_set_mark",
    "practice_menu_close",
}

local DIALOGS = {
    auto    = { title = "practice_menu_confirm_auto",    left = "practice_menu_auto_on", right = "practice_menu_auto_off" },
    restart = { title = "practice_menu_confirm_restart", left = "practice_menu_yes",     right = "practice_menu_no" },
    another = { title = "practice_menu_confirm_another", left = "practice_menu_yes",     right = "practice_menu_no" },
    ["end"] = { title = "practice_menu_confirm_end",     left = "practice_menu_yes",     right = "practice_menu_no" },
    review_end = { title = "practice_menu_confirm_review_end", left = "practice_menu_yes", right = "practice_menu_no" },
}

local function sprite(name)
    return tex.get_texture("practice/" .. name)
end

function PracticeMenu.new()
    return setmetatable({ lang = nil }, PracticeMenu)
end

-- the texts, rebuilt when the language changes
function PracticeMenu:texts()
    local lang = tex.language()
    if self.lang == lang then return end
    self.lang = lang
    self.rows, self.dialogs = {}, {}

    local base = SKIN.label.font_size > 0 and SKIN.label.font_size or 1
    for i, key in ipairs(ROWS) do
        local label = tex.skin_text(key)
        local _, chars = label:gsub("[^\128-\191]", "")
        local fs, v = base, 1.0
        if chars > 1 then
            v = (SKIN.label.width / fs - 1.0) / (chars - 1)
            if v < 0.7 then
                v = 0.7
                fs = math.max(1, math.floor(SKIN.label.width / (1.0 + (chars - 1) * 0.7)))
            elseif v > 1.0 then
                v = 1.0
            end
        end
        self.rows[i] = text.create_raw_text(label, fs, WHITE, BLACK, true, 5.0 * fs / base, 2.0, v)
    end

    local fs = SKIN.dialog_font_size > 0 and SKIN.dialog_font_size or 1
    for name, d in pairs(DIALOGS) do
        self.dialogs[name] = {
            title = text.create_raw_text(tex.skin_text(d.title), fs, WHITE, BLACK, false),
            left  = text.create_raw_text(tex.skin_text(d.left),  fs, WHITE, BLACK, false),
            right = text.create_raw_text(tex.skin_text(d.right), fs, WHITE, BLACK, false),
        }
    end
end

local function panel_x()
    return (tex.get_screen_width() - SKIN.panel.width) / 2.0
end

-- x of the left and right dialog buttons, and their y
local function dialog_buttons(dialog)
    local px, b = panel_x(), SKIN.button
    if dialog == "auto" then
        local t = SKIN.auto_toggle
        local total = b.width * 2 + t.width + t.gap * 2
        local left = px + (SKIN.panel.width - total) / 2.0
        return left, left + b.width + t.gap + t.width + t.gap, SKIN.panel.y + t.y
    end
    return px + b.x, px + SKIN.panel.width - b.x - b.width, SKIN.panel.y + b.y
end

local function inside(x, y, left, top, w, h)
    return x >= left and x <= left + w and y >= top and y <= top + h
end

-- bar under the pointer (0-based), or the dialog button (0 = left, 1 = right); nil if none
function PracticeMenu:hit_test(x, y, dialog)
    local b = SKIN.button
    if dialog then
        local left, right, row_y = dialog_buttons(dialog)
        if inside(x, y, left, row_y, b.width, b.height) then return 0 end
        if inside(x, y, right, row_y, b.width, b.height) then return 1 end
        return nil
    end
    local n, bar = #ROWS, SKIN.bar
    local pad = (SKIN.panel.width - n * bar.width - (n - 1) * bar.gap) / 2.0
    local top = SKIN.panel.y + (SKIN.panel.height - bar.height) / 2.0
    for i = 0, n - 1 do
        if inside(x, y, panel_x() + pad + i * (bar.width + bar.gap), top, bar.width, bar.height) then
            return i
        end
    end
    return nil
end

function PracticeMenu:draw(index)
    self:texts()
    local n, bar, px = #ROWS, SKIN.bar, panel_x()
    local pad = (SKIN.panel.width - n * bar.width - (n - 1) * bar.gap) / 2.0
    tex.draw_texture(sprite("menu_panel"), { x = px, y = SKIN.panel.y })

    for i = 0, n - 1 do
        local x = px + pad + i * (bar.width + bar.gap)
        local y = SKIN.panel.y + (SKIN.panel.height - bar.height) / 2.0
        tex.draw_texture(sprite(i == index and "menu_bar_selected" or "menu_bar"), { x = x, y = y })
        local label = self.rows[i + 1]
        -- top-aligned like the arcade, not centred
        label:draw({ x = x + (bar.width - label.width) / 2.0, y = y + SKIN.label.y })
    end
end

-- sel: 0 = left button, 1 = right
function PracticeMenu:draw_dialog(dialog, sel)
    self:texts()
    local px, pw, b = panel_x(), SKIN.panel.width, SKIN.button
    local d = self.dialogs[dialog]
    if not d then return end
    tex.draw_texture(sprite("menu_panel"), { x = px, y = SKIN.panel.y })

    -- the auto dialog stacks a label chip and the toggle row below its title, so the title sits
    -- high; the yes/no confirms sit lower
    local title_y = (dialog == "auto") and SKIN.dialog_title_auto_y or SKIN.dialog_title_y
    d.title:draw({ x = px + (pw - d.title.width) / 2.0, y = SKIN.panel.y + title_y })

    local left, right, row_y = dialog_buttons(dialog)
    if dialog == "auto" then
        tex.draw_texture(sprite("menu_auto_label"),
            { x = px + (pw - SKIN.auto_label.width) / 2.0, y = SKIN.panel.y + SKIN.auto_label.y })
        -- the red knob slides toward whichever side is picked
        tex.draw_texture(sprite("menu_toggle"), {
            mirror = sel == 1 and "horizontal" or nil,
            x = left + b.width + SKIN.auto_toggle.gap, y = row_y + SKIN.toggle_y,
        })
    end

    tex.draw_texture(sprite(sel == 0 and "menu_button_selected" or "menu_button"), { x = left, y = row_y })
    tex.draw_texture(sprite(sel == 1 and "menu_button_selected" or "menu_button"), { x = right, y = row_y })
    d.left:draw({ x = left + (b.width - d.left.width) / 2.0, y = row_y + (b.height - d.left.height) / 2.0 })
    d.right:draw({ x = right + (b.width - d.right.width) / 2.0, y = row_y + (b.height - d.right.height) / 2.0 })
end
