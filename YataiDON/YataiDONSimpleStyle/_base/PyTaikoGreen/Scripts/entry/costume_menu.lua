CostumeMenu = {}
CostumeMenu.__index = CostumeMenu

local ITEM_W = 80.0

local ITEM_KEYS = {
    "costume", "default", "head_body",
    "preset_1", "preset_2", "preset_3", "random_item",
}

local BUBBLE = {
    [0] = { kind = "example", first = 6, count = 4, ms = 483 },
    [2] = { kind = "example", first = 0, count = 6, ms = 317 },
    [3] = { kind = "ad", first = 2, count = 2 },
    [4] = { kind = "ad", first = 0, count = 2 },
    [5] = { kind = "ad", first = 0, count = 2 },
    [6] = { kind = "random" },
}
local AD_MS, AD_FADE_IN, AD_FADE_OUT = 2000, 167, 150

-- cloud puff, 1000 ms loop: {end_ms, scale at end}, linear between
local PUFF = { { 200, 1.03 }, { 217, 1.03 }, { 417, 1.0 }, { 434, 1.0 }, { 634, 1.02 }, { 651, 1.02 }, { 834, 1.0 }, { 1000, 1.0 } }
local PUFF_MS = 1000

-- Lumen intro (ms): box slides in from the side, holds small, grows to full height, then the
-- contents fade in; input unlocks when that ends.
local SLIDE_FROM, SLIDE_START, SLIDE_MS = 551, 33, 317
local GROW_START, GROW_MS, GROW_DELTA, CAPTION_DROP = 850, 150, 100, 61.2
local CONTENT_START, CONTENT_FADE_MS = 1350, 167
local SCROLL_MS = 67   -- item carousel glide

local function clamp01(v) return math.max(0.0, math.min(1.0, v)) end

local F = 1000 / 60
local BONUS_MS = 360 * F
-- burst scale pop {frame, scale}, linear between
local BURST_POP = { { 0, 0 }, { 14, 1 }, { 22, 0.95 }, { 29, 1 } }
-- second sparkle relative to the rest one; they pulse 1 <-> 1.5 over 60 f, half a cycle apart
local SPARKLE_DX, SPARKLE_DY, SPARKLE_DROP = 362.05, -60, 62

local function keyed(f, keys)
    if f <= keys[1][1] then return keys[1][2] end
    for i = 2, #keys do
        local a, b = keys[i - 1], keys[i]
        if f < b[1] then return a[2] + (b[2] - a[2]) * (f - a[1]) / (b[1] - a[1]) end
    end
    return keys[#keys][2]
end

local function puff_scale(t)
    local prev_t, prev_s = 0, 1.0
    for _, k in ipairs(PUFF) do
        if t <= k[1] then return prev_s + (k[2] - prev_s) * (t - prev_t) / (k[1] - prev_t) end
        prev_t, prev_s = k[1], k[2]
    end
    return 1.0
end

-- title caption per pick stage (0 none, 1 head, 2 body); stage 0 while picking = suit
local STAGE_KEY = { [1] = "entry_costume_text_head", [2] = "entry_costume_text_body" }

function CostumeMenu.new(is_2p, text_str, title_x, title_y, collabo_bonus)
    local self = setmetatable({}, CostumeMenu)
    self.is_2p = is_2p
    if collabo_bonus then
        self.bonus = {
            burst   = tex.get_texture("entry/costume_select/collabo_burst"),
            card    = tex.get_texture("entry/costume_select/collabo_card"),
            sparkle = tex.get_texture("entry/costume_select/collabo_sparkle"),
            player  = is_2p and 2 or 1,
        }
    end

    local suffix = is_2p and "2p" or "1p"

    -- Box frame
    self.box_top_left  = tex.get_texture("entry/costume_select/box_top_left_"     .. suffix)
    self.box_top_right = tex.get_texture("entry/costume_select/box_top_right_"    .. suffix)
    self.box_bot_left  = tex.get_texture("entry/costume_select/box_bottom_left_"  .. suffix)
    self.box_bot_right = tex.get_texture("entry/costume_select/box_bottom_right_" .. suffix)
    self.box_top       = tex.get_texture("entry/costume_select/box_top_"          .. suffix)
    self.box_bottom    = tex.get_texture("entry/costume_select/box_bottom_"       .. suffix)
    self.box_left      = tex.get_texture("entry/costume_select/box_left_"         .. suffix)
    self.box_right     = tex.get_texture("entry/costume_select/box_right_"        .. suffix)
    self.box_center    = tex.get_texture("entry/costume_select/box_center_"       .. suffix)
    self.item_box      = tex.get_texture("entry/costume_select/item_box_"         .. suffix)
    self.item_box_hl   = tex.get_texture("entry/costume_select/item_box_highlighted")
    self.blue_arrow    = tex.get_texture("entry/costume_select/blue_arrow")
    self.text_hl       = tex.get_texture("entry/costume_select/text_highlight_"   .. suffix)
    self.cloud         = tex.get_texture("entry/costume_select/cloud")
    self.examples      = tex.get_texture("entry/costume_select/costume_example")
    self.ads           = tex.get_texture("entry/costume_select/hiroba_ad")
    self.random_art    = tex.get_texture("entry/costume_select/random")

    -- Menu items
    self.items = {}
    for _, key in ipairs(ITEM_KEYS) do
        local id   = tex.get_texture("entry/costume_select/" .. key)
        local info = tex.get_texture_info("costume_select", key)
        self.items[#self.items + 1] = {
            id     = id,
            width  = info and info.width  or ITEM_W,
            height = info and info.height or ITEM_W,
        }
    end

    -- Positioning info
    self.ib_info  = tex.get_texture_info("costume_select", "item_box_1p")
    self.hl_info  = tex.get_texture_info("costume_select", "item_box_highlighted")
    self.arr_info = tex.get_texture_info("costume_select", "blue_arrow")
    self.bc_info  = tex.get_texture_info("costume_select", "box_center_" .. suffix)
    self.th_info  = tex.get_texture_info("costume_select", "text_highlight_" .. suffix)

    -- Animations
    self.blue_arrow_fade = tex.get_animation(13, "entry")
    self.blue_arrow_move = tex.get_animation(14, "entry")
    self.blue_arrow_fade:start()
    self.blue_arrow_move:start()
    self.intro_t = 0

    -- Title text
    local font_size = tex.get_skin_config("entry_costume_text").font_size
    self.font_size      = font_size
    self.title_cache    = {}
    self.title_cache[""] = text.create_raw_text(text_str, font_size, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 5, 2.0)
    self.title_x_offset = title_x
    self.title_y_offset = title_y

    return self
end

-- top-left of the menu panel (1P left, 2P right)
function CostumeMenu:position()
    local s = tex.get_screen_scale()
    if self.is_2p then return { 666.5 * s, 98 * s } end
    return { 98 * s, 98 * s }
end

function CostumeMenu:is_ready()
    return self.intro_t >= CONTENT_START + CONTENT_FADE_MS
end

function CostumeMenu:update(current_ms)
    self.blue_arrow_fade:update(current_ms)
    self.blue_arrow_move:update(current_ms)
end

function CostumeMenu:draw_bg(x, y, selected_index, costume_select_mode, _preset_seq, pick_stage)
    -- draw_fg runs right after and needs the highlighted item for the bubble
    if self.bubble_sel ~= selected_index then
        local n = #self.items
        if self.bubble_sel then
            local step = (selected_index - self.bubble_sel) % n
            self.scroll_dir = step == 1 and 1 or (step == n - 1 and -1 or 0)
            self.scroll_t0  = tex.get_current_ms()
        end
        self.bubble_sel = selected_index
        self.bubble_t0  = tex.get_current_ms()
    end
    self.picking = costume_select_mode
    self.pick_stage = pick_stage

    -- intro state, shared with draw_fg
    self.intro_t0 = self.intro_t0 or tex.get_current_ms() + (self.bonus and BONUS_MS or 0)
    local t = tex.get_current_ms() - self.intro_t0
    self.intro_t = t
    if t < 0 then return end
    local slide = 1.0 - clamp01((t - SLIDE_START) / SLIDE_MS)
    self.slide_x = (self.is_2p and 1 or -1) * SLIDE_FROM * slide
    x = x + self.slide_x
    local grow = clamp01((t - GROW_START) / GROW_MS)
    self.grow = grow
    self.content_a = clamp01((t - CONTENT_START) / CONTENT_FADE_MS)
    local half = GROW_DELTA * (1 - grow) / 2   -- each edge moves in by this much while small

    local a = { x = x, y = y + half }
    local b = { x = x, y = y - half }
    local c = { x = x, y = y + half, y2 = -2 * half }
    tex.draw_texture(self.box_top_left,  a)
    tex.draw_texture(self.box_top_right, a)
    tex.draw_texture(self.box_bot_left,  b)
    tex.draw_texture(self.box_bot_right, b)
    tex.draw_texture(self.box_top,       a)
    tex.draw_texture(self.box_bottom,    b)
    tex.draw_texture(self.box_left,      c)
    tex.draw_texture(self.box_right,     c)
    tex.draw_texture(self.box_center,    c)

    local fa = self.content_a
    if fa <= 0 then return end
    tex.draw_texture(self.item_box,    { x = x + ITEM_W * 0, y = y, fade = fa })
    tex.draw_texture(self.item_box,    { x = x + ITEM_W * 1, y = y, fade = fa })
    tex.draw_texture(self.item_box_hl, { x = x + ITEM_W * 2, y = y, fade = fa })
    tex.draw_texture(self.item_box,    { x = x + ITEM_W * 3, y = y, fade = fa })
    tex.draw_texture(self.item_box,    { x = x + ITEM_W * 4, y = y, fade = fa })

    if not costume_select_mode then
        local base_x = self.ib_info.x[1] + x
        local base_y = self.ib_info.y[1] + y
        local n = #self.items
        -- icons glide one slot toward the centre after a selection change
        local glide = 0
        if self.scroll_t0 then
            glide = self.scroll_dir * ITEM_W * (1 - clamp01((tex.get_current_ms() - self.scroll_t0) / SCROLL_MS))
        end
        for i = 0, 4 do
            local idx = ((selected_index - 2 + i) % n) + 1
            local item = self.items[idx]
            if item and item.id then
                local ix = base_x + glide + i * ITEM_W + (ITEM_W - item.width)  / 2
                local iy = base_y               + (ITEM_W - item.height) / 2
                tex.draw_texture(item.id, { x = ix, y = iy, fade = fa })
            end
        end
    end
end

function CostumeMenu:draw_bubble(x, y, fa)
    local show = BUBBLE[self.bubble_sel]
    if self.picking or not show then return end
    local t = tex.get_current_ms() - self.bubble_t0

    tex.draw_texture(self.cloud, { x = x, y = y, scale = puff_scale(t % PUFF_MS), center = true, fade = fa })

    if show.kind == "example" then
        local frame = show.first + math.floor(t / show.ms) % show.count
        tex.draw_texture(self.examples, { x = x, y = y, frame = frame, fade = fa })
    elseif show.kind == "random" then
        tex.draw_texture(self.random_art, { x = x, y = y, fade = fa })
    else
        local slot = math.floor(t / AD_MS) % show.count
        local lt = t % AD_MS
        local fade = math.min(1.0, lt / AD_FADE_IN, (AD_MS - lt) / AD_FADE_OUT)
        tex.draw_texture(self.ads, { x = x, y = y, frame = show.first + slot, fade = fade * fa })
    end
end

function CostumeMenu:draw_bonus(x, y)
    local b = self.bonus
    local f = (tex.get_current_ms() - self.intro_t0 + BONUS_MS) / F
    if f >= 360 then
        self.bonus = nil
        return
    end
    if not b.popped then
        b.popped = true
        if audio.has_sound("mario_popup") then audio.play_sound("mario_popup", "sound", false, b.player) end
    end
    if f >= 120 and not b.got then
        b.got = true
        if audio.has_sound("campaign_entry") then audio.play_sound("campaign_entry", "sound", false, b.player) end
        if audio.has_sound("mario_get_vo") then audio.play_sound("mario_get_vo", "voice", false, b.player) end
    end
    local S = tex.get_screen_scale()
    if f < 120 then
        tex.draw_texture(b.burst, { x = x, y = y, center = true, scale = keyed(f, BURST_POP),
                                    fade = 1 - clamp01((f - 101) / 19) })
        return
    end
    local fade = math.min(clamp01((f - 120) / 20), 1 - clamp01((f - 341) / 19))
    tex.draw_texture(b.card, { x = x, y = y, fade = fade })
    if f < 139 then return end
    local drop = f >= 340 and SPARKLE_DROP * S or 0
    local u = ((f - 139) % 60) / 30   -- 0..2: grow + fade in, then shrink + fade out
    local p = u < 1 and u or 2 - u
    local spark_fade = f >= 340 and 1 - clamp01((f - 340) / 19) or 1
    local spots = {
        { 0, 0, 1 - p },
        { SPARKLE_DX * S, SPARKLE_DY * S, p },
    }
    for _, s in ipairs(spots) do
        -- the Lumen shape stacks the sparkle twice
        for _ = 1, 2 do
            tex.draw_texture(b.sparkle, { x = x + s[1], y = y + s[2] + drop, center = true, scale = 1 + 0.5 * s[3],
                                          fade = s[3] * spark_fade })
        end
    end
end

function CostumeMenu:draw_fg(x, y, name)
    if self.bonus then self:draw_bonus(x, y) end
    if self.intro_t < 0 then return end
    x = x + self.slide_x
    local fa = self.content_a
    local hl  = self.hl_info
    local arr = self.arr_info
    local hl_left  = hl.x[1] + x + ITEM_W * 2
    local hl_right = hl_left + hl.width
    local arr_y    = hl.y[1] + y + (hl.height - arr.height) / 2
    local move_val = self.blue_arrow_move.attribute
    local fade_val = self.blue_arrow_fade.attribute

    tex.draw_texture(self.blue_arrow, { mirror = "horizontal", x = hl_right + move_val,                    y = arr_y, fade = fade_val * fa })
    tex.draw_texture(self.blue_arrow, {                        x = hl_left - arr.width - move_val, y = arr_y, fade = fade_val * fa })

    if self.text_hl and self.th_info then
        local th = self.th_info
        tex.draw_texture(self.text_hl, { x = x - th.width / 2, y = y - th.height / 2, fade = fa })
        if name then
            if self.name_str ~= name then
                self.name_str  = name
                self.name_text = text.create_raw_text(name, 32, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false)
            end
            local banner_cx, banner_cy = th.x[1] + x, th.y[1] + y
            self.name_text:draw({ x = banner_cx - self.name_text.width / 2, y = banner_cy - self.name_text.height / 2 })
        else
            self.name_str, self.name_text = nil, nil
        end
    end

    local key = ""
    if self.picking then key = STAGE_KEY[self.pick_stage] or "entry_costume_text_suit" end
    local title = self.title_cache[key]
    if not title then
        title = text.create_raw_text(tex.skin_text(key), self.font_size, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 5, 2.0)
        self.title_cache[key] = title
    end

    local bc = self.bc_info
    local bc_width = (bc.x2 and bc.x2[1]) or bc.width
    local cx = bc.x[1] + x + bc_width / 2 - title.width / 2
    title:draw({ x = cx + self.title_x_offset, y = y + self.title_y_offset + CAPTION_DROP * (1 - self.grow) })

    if fa > 0 then self:draw_bubble(x, y, fa) end
end
