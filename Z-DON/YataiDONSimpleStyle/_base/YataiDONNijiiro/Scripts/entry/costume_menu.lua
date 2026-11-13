-- "きせかえをえらぼう！" costume picker (5 fixed slots, moving cursor, scrolling window).

local anim = require("anim/sampler")

CostumeMenu = {}
CostumeMenu.__index = CostumeMenu

local CX, CY       = 498, 540      -- costume_1p_instance root placement
local SIDE_OFF_2P  = 924           -- costume_2p_instance - costume_1p_instance
local PITCH        = 100           -- icon_instance pitch
local PITCH_CPP    = 80            -- C++ CostumeMenu::draw uses ITEM_W = 80 in costume_select_mode
local PILL_Y       = CY + 220      -- 760
local ARROW_DX     = 277
local SLOTS        = 5             -- icon_instance_1..5
-- arcade text_title box (100..898, 142..268), font 54, left aligned, vertically centred
local TITLE_X, TITLE_Y, TITLE_SIZE = 100, 205, 54
local GUIDE_X, GUIDE_Y = CX, CY + 337   -- (498,877)
-- control_guide_s s_menfuchi_kp: select pill at -133, decide pill at +40, text +78 right of each pill
local GUIDE_SEL_DX, GUIDE_DEC_DX, GUIDE_TEXT_DY, GUIDE_SIZE = -133 + 78, 40 + 78, 0, 24

local CURSOR_ANIM = anim.safe("anim/costume_cursor")
local ARROW_ANIM  = anim.safe("anim/costume_arrow")
local BOARD_ANIM  = anim.safe("anim/costume_board")
local CURSOR_LOOP_F = 60           -- `decide` starts at 60; the loop is 0..59
local ARROW_F0, ARROW_LOOP_F = 5, 15
local BOARD_F0, BOARD_F1 = 5, 15

__hss_costume_panel = __hss_costume_panel or {}
-- shared with player.lua (which draws the panel under the Don); missing entry = fully opaque
__hss_costume_fade = __hss_costume_fade or {}
-- costume-change smoke timestamp (drawn by player.lua over the Don)
__hss_costume_smoke = __hss_costume_smoke or {}

-- do not reorder: selected_index walks this exact order
local ITEM_KEYS = {
    "costume", "default", "head_body",
    "preset_1", "preset_2", "preset_3", "random_item",
}

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function CostumeMenu.new(is_2p, text_str, title_x, title_y)
    local self = setmetatable({}, CostumeMenu)
    self.is_2p = is_2p
    self.side  = is_2p and 1 or 0
    self.off   = is_2p and SIDE_OFF_2P or 0
    local suffix = is_2p and "2p" or "1p"

    self.panel       = tex.get_texture("entry/costume_select/box_center_" .. suffix)  -- drawn by player.lua
    self.pill        = tex.get_texture("entry/costume_select/box_top_1p")      -- icon-row pill
    self.guide       = tex.get_texture("entry/costume_select/box_bottom_1p")   -- えらぶ/決定 drum hint
    self.item_box    = tex.get_texture("entry/costume_select/item_box_" .. suffix)
    self.item_box_hl = tex.get_texture("entry/costume_select/item_box_highlighted")
    self.blue_arrow  = tex.get_texture("entry/costume_select/blue_arrow")
    self.th_info     = tex.get_texture_info("costume_select", "text_highlight_" .. suffix)

    self.items = {}
    for _, key in ipairs(ITEM_KEYS) do
        local id   = tex.get_texture("entry/costume_select/" .. key)
        local info = tex.get_texture_info("costume_select", key)
        self.items[#self.items + 1] = {
            id     = id,
            width  = info and info.x2[1] or 84,
            height = info and info.y2[1] or 84,
        }
    end

    self.ib_info  = tex.get_texture_info("costume_select", "item_box_" .. suffix)
    self.hl_info  = tex.get_texture_info("costume_select", "item_box_highlighted")
    self.arr_info = tex.get_texture_info("costume_select", "blue_arrow")

    -- font 54 white, outline 6 (thickness x1.5 on screen)
    self.title_text = text.create_raw_text(text_str, TITLE_SIZE, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 4, 2.0)
    -- guide words from skin_config (guide_select_label / guide_decide_label)
    self.guide_sel = text.create_raw_text(tex.skin_text("guide_select_label"), GUIDE_SIZE, { 30, 30, 30, 255 }, { 30, 30, 30, 255 }, false, 0, 1.0)
    self.guide_dec = text.create_raw_text(tex.skin_text("guide_decide_label"), GUIDE_SIZE, { 30, 30, 30, 255 }, { 30, 30, 30, 255 }, false, 0, 1.0)

    self.costume_select_mode = false
    -- 0-based cursor and scroll offset
    self.cursor = 0
    self.offset = 0
    self.prev_index = nil
    self.now_ms = tex.get_current_ms()
    self.open_ms = self.now_ms
    __hss_costume_panel[self.side] = self.now_ms
    __hss_costume_fade[self.side] = 0
    return self
end

-- top-left of the menu panel (1P left, 2P right)
function CostumeMenu:position()
    return { self.is_2p and 924 or 0, 0 }
end

function CostumeMenu:update(current_ms)
    self.now_ms = current_ms
    -- keep the panel flag alive while this menu exists (player.lua draws the panel under the Don)
    __hss_costume_panel[self.side] = current_ms

    -- costume-change smoke (see the __hss_costume_smoke note above)
    local hit = audio.is_sound_playing("don") or audio.is_sound_playing("kat")
    if self.costume_select_mode then
        if not self.was_select_mode then
            -- entering the icon picker rebuilds the Chara3D straight away (chara_index = -1)
            __hss_costume_smoke[self.side] = current_ms
        elseif hit and not self.hit_prev then
            __hss_costume_smoke[self.side] = current_ms
        end
    end
    self.was_select_mode = self.costume_select_mode
    self.hit_prev = hit
end

-- board fade-in (alpha only)
function CostumeMenu:board_fade()
    local f = BOARD_F0 + (self.now_ms - self.open_ms) * 0.06
    if f >= BOARD_F1 then return 1.0 end
    local _, a = BOARD_ANIM:at("board_instance", f)
    if a == nil then return 1.0 end
    return a
end

-- icons sit still, cursor moves; the window scrolls only at an end (a wrap snaps to that end)
function CostumeMenu:track_cursor(selected_index, n)
    local max_offset = math.max(0, n - SLOTS)
    local prev = self.prev_index
    if prev == nil then
        self.offset = clamp(selected_index - 2, 0, max_offset)
    elseif selected_index == prev then
        -- nothing moved
    elseif selected_index == (prev + 1) % n then
        if prev == n - 1 then                       -- wrapped last -> first
            self.offset = 0
        elseif selected_index > self.offset + SLOTS - 1 then
            self.offset = self.offset + 1
        end
    elseif selected_index == (prev - 1 + n) % n then
        if prev == 0 then                           -- wrapped first -> last
            self.offset = max_offset
        elseif selected_index < self.offset then
            self.offset = self.offset - 1
        end
    else                                            -- unexpected jump: re-centre
        self.offset = clamp(selected_index - 2, 0, max_offset)
    end
    self.offset = clamp(self.offset, 0, max_offset)
    self.cursor = clamp(selected_index - self.offset, 0, SLOTS - 1)
    self.offset = selected_index - self.cursor      -- keep offset+cursor == selected_index
    self.prev_index = selected_index
end

-- centre of slot i (0..4) in screen px
function CostumeMenu:slot_center(i)
    if self.costume_select_mode then
        -- match the C++ icon row: base = item_box x + engine x, ITEM_W = 80
        local base = self.ib_info.x[1] + self.engine_x
        return base + i * PITCH_CPP + PITCH_CPP / 2, self.ib_info.y[1] + self.engine_y + PITCH_CPP / 2
    end
    return CX + self.off + (i - 2) * PITCH, PILL_Y
end

-- preset_seq bumps whenever a preset row dresses the Don; its edges fire the change smoke
function CostumeMenu:draw_bg(x, y, selected_index, costume_select_mode, preset_seq)
    if preset_seq and preset_seq ~= self.preset_seq then
        if self.preset_seq ~= nil then
            __hss_costume_smoke[self.side] = tex.get_current_ms()
        end
        self.preset_seq = preset_seq
    end
    self.costume_select_mode = costume_select_mode
    self.engine_x, self.engine_y = x, y
    self.now_ms = tex.get_current_ms()
    __hss_costume_panel[self.side] = self.now_ms

    local fade = self:board_fade()
    __hss_costume_fade[self.side] = fade

    local n = #self.items
    if costume_select_mode then
        -- C++ draws a wrapping window centred on the icon, so the ring sits mid-row
        self.cursor, self.offset, self.prev_index = 2, 0, nil
    else
        self:track_cursor(selected_index, n)
    end

    -- the panel itself is drawn by player.lua (under the Don)
    tex.draw_texture(self.pill, { x = self.off, fade = fade })

    local hw  = self.ib_info.x2[1] / 2
    local hlw = self.hl_info.x2[1] / 2
    -- free-running 60-frame pulse; only the yellow rim breathes
    local pulse = CURSOR_ANIM:at("#15@1", (self.now_ms * 0.06) % CURSOR_LOOP_F) or 1.0
    for i = 0, SLOTS - 1 do
        local cx, cy = self:slot_center(i)
        tex.draw_texture(self.item_box, { x = cx - hw - self.ib_info.x[1], y = cy - hw - self.ib_info.y[1], fade = fade })
        if i == self.cursor then
            tex.draw_texture(self.item_box_hl, {
                x = cx - hlw - self.hl_info.x[1], y = cy - hlw - self.hl_info.y[1],
                fade = fade * pulse,
            })
        end
    end

    if not costume_select_mode then
        for i = 0, SLOTS - 1 do
            local item = self.items[self.offset + i + 1]
            if item and item.id then
                local cx, cy = self:slot_center(i)
                tex.draw_texture(item.id, { x = cx - item.width / 2, y = cy - item.height / 2, fade = fade })
            end
        end
    end
end

function CostumeMenu:draw_fg(x, y, name)
    local fade = __hss_costume_fade[self.side] or 1.0
    -- looping outward drift, alpha 1 (not a fade pulse)
    local drift = ARROW_ANIM:at("#38@0", ARROW_F0 + (self.now_ms * 0.06) % ARROW_LOOP_F) or 0.0
    -- hide an arrow when there is nothing further that way
    local index = self.offset + self.cursor
    local show_l = self.costume_select_mode or index > 0
    local show_r = self.costume_select_mode or index < #self.items - 1
    -- texture.json already puts the arrow at the right end (CX+277); x below is the delta
    if show_r then
        tex.draw_texture(self.blue_arrow, { x = self.off + drift, fade = fade })
    end
    if show_l then
        tex.draw_texture(self.blue_arrow, { mirror = "horizontal", x = self.off - 2 * ARROW_DX - drift, fade = fade })
    end

    -- title, top-left inside the panel
    self.title_text:draw({ x = TITLE_X + self.off, y = TITLE_Y - self.title_text.height / 2, fade = fade })

    -- えらぶ / 決定 drum hint under the panel
    tex.draw_texture(self.guide, { x = self.off, fade = fade })
    local gx, gy = GUIDE_X + self.off, GUIDE_Y + GUIDE_TEXT_DY
    self.guide_sel:draw({ x = gx + GUIDE_SEL_DX - self.guide_sel.width / 2, y = gy - self.guide_sel.height / 2, fade = fade })
    self.guide_dec:draw({ x = gx + GUIDE_DEC_DX - self.guide_dec.width / 2, y = gy - self.guide_dec.height / 2, fade = fade })

    -- name banner for the cursor's icon (costume/head/body pick only)
    if self.th_info then
        local banner_cx, banner_cy = self.th_info.x[1] + x, self.th_info.y[1] + y
        if name then
            if self.name_str ~= name then
                self.name_str  = name
                self.name_text = text.create_raw_text(name, 32, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false)
            end
            self.name_text:draw({ x = banner_cx - self.name_text.width / 2, y = banner_cy - self.name_text.height / 2, fade = fade })
        else
            self.name_str, self.name_text = nil, nil
        end
    end
end
