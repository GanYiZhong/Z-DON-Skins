local SKIN_S = tex.get_screen_scale()
local SKIN = {
    entry_box_text_offset = { y = 20 * SKIN_S },
    entry_box_highlight_offset = { x = -15 * SKIN_S },
}
EntryBox = {}
EntryBox.__index = EntryBox

local DESC_COLOR   = { 0, 0, 0, 255 }
local DESC_NO_LINE = { 0, 0, 0, 0 }

local function build_description(mode_key)
    if not mode_key or mode_key == "" then return nil end
    local raw = tex.skin_text(mode_key .. "_desc")
    if raw == "" then return nil end
    local s      = tex.get_screen_scale()
    local cfg    = { x = 4 * s, y = 21 * s, width = 40 * s, height = 380 * s, font_size = math.floor(30 * s) }   -- width = column pitch
    local latin  = { width = 128 * s, font_size = math.floor(24 * s) }
    local is_cjk = text.language_is_cjk(tex.language())
    local size   = is_cjk and cfg.font_size or latin.font_size
    local lines  = {}
    for line in raw:gmatch("[^\n]+") do
        local content = line
        if not is_cjk then
            content = text.word_wrap(line, size, 2.0, latin.width)
        end
        lines[#lines + 1] = text.create_raw_text(content, size, DESC_COLOR, DESC_NO_LINE, is_cjk, 0, 2.0, 1.0)
    end
    return { lines = lines, is_cjk = is_cjk, cfg = cfg }
end

local MODE_BADGES = {
    entry_practice = { "one_player" },
    -- strict audit (round 3, direct feed Tl7g8XXXvAM t=4): the cabinet marks the AI battle as new and one player;
    -- the costume board carries no badge
    entry_ai_battle = { "one_player", "new" },
}

-- Greyed-out board
local GREY_FILL, GREY_OUTLINE = { 156, 155, 156, 255 }, { 76, 76, 76, 255 }

function EntryBox.new(text_str, font_size, mode_key)
    local self = setmetatable({}, EntryBox)

    self.text          = text.create_raw_text(text_str, font_size, { 255, 255, 255, 255 }, { 109, 68, 24, 255 }, true, 5)
    self.text_selected = text.create_raw_text(text_str, font_size, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, true, 5)

    self.box       = tex.get_texture("entry/mode_select/box")
    self.hl_center = tex.get_texture("entry/mode_select/box_highlight_center")
    self.hl_left   = tex.get_texture("entry/mode_select/box_highlight_left")
    self.hl_right  = tex.get_texture("entry/mode_select/box_highlight_right")
    self.arrow     = tex.get_texture("entry/mode_select/arrow")
    self.flash     = tex.get_texture("entry/mode_select/flash")
    self.star      = tex.get_texture("entry/mode_select/star")
    self.desc      = build_description(mode_key)

    self.text_grey = text.create_raw_text(text_str, font_size, GREY_FILL, GREY_OUTLINE, true, 5)
    self.box_grey       = tex.get_texture("entry/mode_select/box_grey")
    self.hl_grey_center = tex.get_texture("entry/mode_select/box_highlight_grey_center")
    self.hl_grey_left   = tex.get_texture("entry/mode_select/box_highlight_grey_left")
    self.hl_grey_right  = tex.get_texture("entry/mode_select/box_highlight_grey_right")

    self.badges = {}
    for _, name in ipairs(MODE_BADGES[mode_key] or {}) do
        self.badges[#self.badges + 1] = {
            name = name,
            tex  = tex.get_texture("entry/mode_select/badge_" .. name),
            info = tex.get_texture_info("mode_select", "badge_" .. name),
        }
        -- the tag is baked into the title art in Lumen, so it has a grey twin for disabled boards
        if name == "one_player" then
            self.badges[#self.badges].tex_grey = tex.get_texture("entry/mode_select/badge_one_player_grey")
            self.tag_height = self.badges[#self.badges].info.height
        end
    end

    local box_info     = tex.get_texture_info("mode_select", "box")
    local hl_left_info = tex.get_texture_info("mode_select", "box_highlight_left")
    local hl_offset    = SKIN.entry_box_highlight_offset
    local text_offset  = SKIN.entry_box_text_offset

    self.y             = box_info.y[1]
    self.box_width     = box_info.width
    self.box_height    = box_info.height
    self.hl_left_width = hl_left_info.width
    self.hl_right_width = tex.get_texture_info("mode_select", "box_highlight_right").width
    self.arrow_info    = tex.get_texture_info("mode_select", "arrow")
    self.hl_offset_x   = hl_offset.x
    self.text_y_offset = text_offset.y

    return self
end

local ARROW_MS, ARROW_TRAVEL = 1000, 25
local ARROW_LEFT_GAP, ARROW_RIGHT_GAP = 7, 8  -- arrow centre past the highlight's edge

local HOVER_FLASH_MS = 400
local DECIDE_FLASH = {
    { 83, 1.0, 0.0 }, { 33, 0.0, 1.0 }, { 67, 0.75, 0.0 }, { 33, 0.0, 1.0 }, { 67, 0.75, 0.0 },
}
local DECIDE_FLASH_MS, DECIDE_FADE_MS = 283, 160   -- animation.json id 9 lasts their sum

local function decide_flash(t)
    for _, seg in ipairs(DECIDE_FLASH) do
        if t < seg[1] then return seg[2] + (seg[3] - seg[2]) * (t / seg[1]) end
        t = t - seg[1]
    end
    return 0
end

local FLASH_W, FLASH_H, FLASH_CAP = 224, 412, 6

function EntryBox:draw_flash(left_x, right_x, y, alpha)
    if alpha <= 0 then return end
    local width = right_x + self.hl_right_width - left_x
    local function piece(src_x, src_w, x, w)
        tex.draw_texture(self.flash, {
            src = { x = src_x, y = 0, width = src_w, height = FLASH_H },
            x = x, y = y, x2 = w - FLASH_W, fade = alpha,
        })
    end
    piece(0, FLASH_CAP, left_x, FLASH_CAP)
    piece(FLASH_CAP, FLASH_W - 2 * FLASH_CAP, left_x + FLASH_CAP, width - 2 * FLASH_CAP)
    piece(FLASH_W - FLASH_CAP, FLASH_CAP, left_x + width - FLASH_CAP, FLASH_CAP)
end

function EntryBox:draw_arrows(left_x, right_x, fade, has_prev, has_next)
    local p      = (tex.get_current_ms() % ARROW_MS) / ARROW_MS
    local alpha  = (1 - p) * fade
    local info   = self.arrow_info
    local top    = self.y + self.box_height / 2 - info.height / 2
    if has_prev then
        local cx = left_x - ARROW_LEFT_GAP - ARROW_TRAVEL * p
        tex.draw_texture(self.arrow, { x = cx - info.width / 2, y = top, fade = alpha })
    end
    if has_next then
        local cx = right_x + self.hl_right_width + ARROW_RIGHT_GAP + ARROW_TRAVEL * p
        tex.draw_texture(self.arrow, { x = cx - info.width / 2, y = top, fade = alpha, mirror = "horizontal" })
    end
end

function EntryBox:draw_description(x, open_attr, fade)
    local d = self.desc
    if not d then return end
    local cfg    = d.cfg
    local alpha  = fade * math.min(1.0, open_attr / 54)
    local centre = x + self.box_width / 2
    if d.is_cjk then
        -- the tallest column sets one squash for all, so characters match across columns
        local tallest = 0
        for _, t in ipairs(d.lines) do tallest = math.max(tallest, t.height) end
        local scale = math.min(1.0, cfg.height / tallest)
        for i, t in ipairs(d.lines) do
            local cx = centre + cfg.x - cfg.width * (i - 1)
            t:draw({ x = cx - t.width / 2, y = self.y + cfg.y, y2 = t.height * (scale - 1), fade = alpha })
        end
    else
        local total = 0
        for _, t in ipairs(d.lines) do total = total + t.height end
        local scale = total > cfg.height and (cfg.height / total) or 1.0
        local y = self.y + cfg.y
        for _, t in ipairs(d.lines) do
            local h = t.height * scale
            t:draw({ x = centre + cfg.x - cfg.width - t.width / 2, y = y, y2 = h - t.height, fade = alpha })
            y = y + h
        end
    end
end

local TAG_Y = 357                          -- one_player tag, centred under the title
local NEW_X, NEW_Y = 6, -65                -- new bubble over the idle board
local TWO_PLAYER_GAP, TWO_PLAYER_Y = 202, -25  -- two_player bubble: left of the opened highlight

-- Sparkles around the two_player bubble. Each colour loops its own keyframes (frames at 60 fps):
-- {from, to, scale0, scale1, alpha0, alpha1}; gaps between segments are hidden.
local STAR_SEQ = {
    [0] = { period = 73, { 0, 30, 1, 1.1, 1, 0 }, { 49, 68, 0.2, 1, 1, 1 }, { 68, 73, 1, 1, 1, 1 } },
    [1] = { period = 70, { 0, 17, 0.2, 1, 1, 1 }, { 17, 23, 1, 1, 1, 1 }, { 23, 51, 1.004, 1.1, 0.965, 0 } },
    [2] = { period = 50, { 0, 26, 1, 0.2, 1, 1 }, { 26, 50, 0.233, 1, 1, 1 } },
    [3] = { period = 70, { 18, 42, 0.2, 1, 1, 1 }, { 42, 48, 1, 1, 1, 1 }, { 48, 70, 1.005, 1.1, 0.953, 0 } },
    [4] = { period = 60, { 0, 15, 0.614, 1, 1, 1 }, { 15, 46, 1, 0.2, 1, 1 }, { 46, 60, 0.228, 0.586, 1, 1 } },
}
-- {colour, centre x, centre y relative to the bubble's top-left, base scale}
local STARS = {
    { 0, 45.4, 335.3, 1.0 }, { 1, 174.4, 62.4, 1.0 }, { 2, 153.5, 45.5, 0.6 }, { 3, 76.4, 357.3, 0.7 },
    { 4, 49.4, 307.3, 0.7 }, { 4, 185.8, 91.0, 0.7 }, { 3, 185.4, 119.4, 0.7 }, { 2, 37.4, 283.5, 0.6 },
}
local STAR_SIZE = 40

local function star_state(seq, now)
    local f = (now * 0.06) % seq.period
    for _, k in ipairs(seq) do
        if f >= k[1] and f < k[2] then
            local p = (f - k[1]) / (k[2] - k[1])
            return k[3] + (k[4] - k[3]) * p, k[5] + (k[6] - k[5]) * p
        end
    end
end

function EntryBox:draw_badge(x, left_x, y, title_cx, highlighted, open_attr, fade, disabled)
    for _, badge in ipairs(self.badges) do
        if badge.name == "one_player" then
            tex.draw_texture(disabled and badge.tex_grey or badge.tex, { x = title_cx - badge.info.width / 2, y = y + TAG_Y, fade = fade })
        elseif badge.name == "new" and not highlighted then
            tex.draw_texture(badge.tex, { x = x + NEW_X, y = y + NEW_Y, fade = fade })
        elseif badge.name == "two_player" and highlighted then
            local bx, by = left_x - TWO_PLAYER_GAP, y + TWO_PLAYER_Y
            local bubble_fade = fade * math.min(1.0, open_attr / 54)
            tex.draw_texture(badge.tex, { x = bx, y = by, fade = bubble_fade })
            local now = tex.get_current_ms()
            for _, star in ipairs(STARS) do
                local scale, alpha = star_state(STAR_SEQ[star[1]], now)
                if scale then
                    tex.draw_texture(self.star, {
                        x = bx + star[2] - STAR_SIZE / 2, y = by + star[3] - STAR_SIZE / 2,
                        frame = star[1], scale = scale * star[4], center = true, fade = alpha * bubble_fade,
                    })
                end
            end
        end
    end
end

function EntryBox:draw(x, left_x, right_x, is_selected, move_finished, open_attr, fade, _y_pos, has_prev, has_next,
                       disabled)
    local y = self.y
    local now = tex.get_current_ms()

    -- animation 9 runs once a board is chosen: blink the chosen one, then fade everything
    local decided_flash = nil
    if fade < 1 then
        local t = (1 - fade) * (DECIDE_FLASH_MS + DECIDE_FADE_MS)
        decided_flash = decide_flash(t)
        fade = t < DECIDE_FLASH_MS and 1.0 or (DECIDE_FLASH_MS + DECIDE_FADE_MS - t) / DECIDE_FADE_MS
    end

    local highlighted = is_selected and move_finished
    if highlighted and not self.hl_since then self.hl_since = now end
    if not highlighted then self.hl_since = nil end

    if highlighted then
        tex.draw_texture(disabled and self.hl_grey_center or self.hl_center, {
            x    = left_x + self.hl_left_width,
            y    = y,
            x2   = right_x - left_x + self.hl_offset_x,
            fade = fade,
        })
        tex.draw_texture(disabled and self.hl_grey_left or self.hl_left,   { x = left_x,  y = y, fade = fade })
        tex.draw_texture(disabled and self.hl_grey_right or self.hl_right, { x = right_x, y = y, fade = fade })
        if decided_flash then
            self:draw_flash(left_x, right_x, y, decided_flash * fade)
        else
            self:draw_flash(left_x, right_x, y, (1 - (now - self.hl_since) / HOVER_FLASH_MS) * fade)
        end
        self:draw_arrows(left_x, right_x, fade, has_prev, has_next)
        self:draw_description(x, open_attr, fade)
    else
        if disabled then
            -- the grey art has no y of its own in texture.json: place it at the board's row
            tex.draw_texture(self.box_grey, { x = x, y = y, fade = fade })
        else
            tex.draw_texture(self.box, { x = x, fade = fade })
        end
    end

    local label = (is_selected and move_finished) and self.text_selected or self.text
    if disabled then label = self.text_grey end
    local text_x = x + self.box_width / 2 - label.width / 2
    if is_selected then
        text_x = text_x + open_attr
    end
    -- long titles squash to fit the board, same margin top and bottom; width stays
    local max_h = self.box_height - 2 * self.text_y_offset - (self.tag_height or 0)
    label:draw({ x = text_x, y = y + self.text_y_offset, y2 = math.min(0, max_h - label.height), fade = fade })
    self:draw_badge(x, left_x, y, text_x + label.width / 2, highlighted, open_attr, fade, disabled)
end
