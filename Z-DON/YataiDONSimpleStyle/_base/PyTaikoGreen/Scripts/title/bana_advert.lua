BanaAdvertisement = {}
BanaAdvertisement.__index = BanaAdvertisement

function BanaAdvertisement.new()
    local self = setmetatable({}, BanaAdvertisement)

    self.current_state = "bana_options"
    self.fade_in = tex.get_animation(15, "title")
    self.fade_in:start()

    self.resize_1 = tex.get_animation(16, "title")
    self.resize_2 = tex.get_animation(16, "title")

    self.bana_rotate = tex.get_animation(17, "title")
    self.bana_move = tex.get_animation(18, "title")
    self.touch_fade = tex.get_animation(19, "title")
    self.touch_move_up = tex.get_animation(20, "title")
    self.touch_move_down = tex.get_animation(22, "title")
    self.touch_resize = tex.get_animation(21, "title")
    self.touch_fade_out = tex.get_animation(23, "title")

    self.donchan_move = tex.get_animation(24, "title")

    self.get_text_scale_down = tex.get_animation(25, "title")
    self.get_text_scale_up = tex.get_animation(26, "title")
    self.get_text_scale_down_2 = tex.get_animation(27, "title")
    self.get_text_fade_in = tex.get_animation(28, "title")
    self.get_chara_bounce_up = tex.get_animation(29, "title")
    self.get_chara_bounce_down = tex.get_animation(30, "title")
    self.get_chara_1_bounce_up = tex.get_animation(29, "title")
    self.get_chara_1_bounce_down = tex.get_animation(30, "title")
    self.get_fade_out = tex.get_animation(31, "title")

    self.gleam_grow = tex.get_animation(38, "title")
    self.dress_don = tex.get_animation(39, "title")
    self.dress_chars = tex.get_animation(40, "title")
    self.dress_title_up = tex.get_animation(41, "title")
    self.dress_title_down = tex.get_animation(42, "title")
    self.dress_title_fade = tex.get_animation(43, "title")
    self.sparkle_fade = tex.get_animation(44, "title")
    self.sparkle_scale = tex.get_animation(45, "title")

    self.t_background = tex.get_texture("title/camera/bana_advert_background")
    self.t_outline = tex.get_texture("title/camera/bana_advert_outline")
    self.t_outline_info = tex.get_texture_info("camera", "bana_advert_outline")
    self.t_reader = tex.get_texture("title/camera/reader")
    self.t_tap = tex.get_texture("title/camera/tap")
    self.t_touch = tex.get_texture("title/camera/touch")
    self.t_touch_gleam = tex.get_texture("title/camera/touch_gleam")
    self.t_card_or_phone_bg = tex.get_texture("title/camera/card_or_phone_bg")
    self.t_card_or_phone_card = tex.get_texture("title/camera/card_or_phone_card")
    self.t_card_or_phone_phone = tex.get_texture("title/camera/card_or_phone_phone")
    self.t_banapassport = tex.get_texture("title/camera/banapassport")
    self.t_or = tex.get_texture("title/camera/or")
    self.t_chara_0 = tex.get_texture("title/camera/chara_0")
    self.t_osaifukeitai = tex.get_texture("title/camera/osaifukeitai")
    self.t_rewards_donchan = tex.get_texture("title/camera/rewards_donchan")
    self.t_rewards = tex.get_texture("title/camera/rewards")
    self.t_rewards_info = tex.get_texture_info("camera", "rewards")
    self.t_rewards_top_text = tex.get_texture("title/camera/rewards_top_text")
    self.t_rewards_bottom_text = tex.get_texture("title/camera/rewards_bottom_text")
    self.t_get_text = tex.get_texture("title/camera/get_text")
    self.t_get_chara_0 = tex.get_texture("title/camera/get_chara_0")
    self.t_get_chara_1 = tex.get_texture("title/camera/get_chara_1")
    self.t_dress_card = tex.get_texture("title/camera/dress_up_card")
    self.t_dress_don = tex.get_texture("title/camera/dress_up_don")
    self.t_dress_title = tex.get_texture("title/camera/dress_up_title")
    self.t_dress_sparkle = tex.get_texture("title/camera/dress_up_sparkle")
    self.t_dress_chars = {}
    for i = 0, 4 do
        self.t_dress_chars[i] = tex.get_texture("title/camera/dress_up_" .. i)
    end

    self.steps_cursor = 0
    self.loop_counter = 0
    self.timer = 0
    self.rewards_ms = 0
    self.rewards_last_ms = nil
    self.chara_0_timer = nil

    return self
end

-- The four reward icons orbit a ring of four slots, one slot at a time: the near-side hops
-- ease out, the far-side ones ease in. Icons trail each other by a quarter of a lap.
local REWARD_SEGMENTS = { { 433, true }, { 817, false }, { 383, true }, { 833, false } }
local REWARD_LAP = 2466
local REWARD_TRAIL = 617
local REWARD_START = 267

local function ring_position(ms)
    ms = ms % REWARD_LAP
    for slot, seg in ipairs(REWARD_SEGMENTS) do
        if ms < seg[1] then
            local t = ms / seg[1]
            return (slot - 1) + (seg[2] and t * (2 - t) or t * t)
        end
        ms = ms - seg[1]
    end
    return 0
end

local DRESS_UP_MS = 2950
local CARD_PHONE_MS = 3000
local REWARDS_MS = 3000
local GET_BLANK_MS = 1000
local TAP_BLANK_MS = 150
local CHARA_HALF_BOUNCE_MS = 333

-- { start offset, apex offset } of each dress-up character, relative to its rest y
local DRESS_UP_CHARS = { { 233, -43 }, { 237, -39 }, { 121, -31 }, { 83, -48 }, { 29, -61 } }
local DRESS_UP_RISE = 0.77
local DON_RISE = 0.645

function BanaAdvertisement:update(current_ms)
    self.fade_in:update(current_ms)
    self.resize_1:update(current_ms)
    self.resize_2:update(current_ms)

    self.bana_rotate:update(current_ms)
    self.bana_move:update(current_ms)
    self.touch_fade:update(current_ms)
    self.touch_move_up:update(current_ms)
    self.touch_move_down:update(current_ms)
    self.touch_resize:update(current_ms)
    self.touch_fade_out:update(current_ms)
    self.gleam_grow:update(current_ms)

    self.donchan_move:update(current_ms)

    self.dress_don:update(current_ms)
    self.dress_chars:update(current_ms)
    self.dress_title_up:update(current_ms)
    self.dress_title_down:update(current_ms)
    self.dress_title_fade:update(current_ms)
    self.sparkle_fade:update(current_ms)
    self.sparkle_scale:update(current_ms)

    self.get_text_scale_down:update(current_ms)
    self.get_text_scale_up:update(current_ms)
    self.get_text_scale_down_2:update(current_ms)
    self.get_text_fade_in:update(current_ms)
    self.get_chara_bounce_up:update(current_ms)
    self.get_chara_bounce_down:update(current_ms)
    self.get_chara_1_bounce_up:update(current_ms)
    self.get_chara_1_bounce_down:update(current_ms)
    self.get_fade_out:update(current_ms)

    if self.current_state == "rewards" then
        if self.rewards_last_ms then
            self.rewards_ms = self.rewards_ms + (current_ms - self.rewards_last_ms)
        end
        self.rewards_last_ms = current_ms
    end

    local sc = self.steps_cursor
    if sc == 0 then
        if self.fade_in.is_finished then
            self.resize_1:start()
            self.steps_cursor = 1
        end
    elseif sc == 1 then
        if self.resize_1.is_finished then
            self.resize_2:start()
            self.steps_cursor = 2
        end
    elseif sc == 2 then
        if self.resize_2.is_finished then
            self.resize_1:start()
            self.steps_cursor = 3
        end
    elseif sc == 3 then
        if self.resize_1.is_finished then
            self.resize_2:start()
            self.steps_cursor = 4
        end
    elseif sc == 4 then
        if self.resize_2.is_finished then
            self.timer = current_ms
            self.steps_cursor = 5
        end
    elseif sc == 5 then
        if current_ms - self.timer >= 300 then
            self.current_state = "tap_to_reader"
            self.steps_cursor = 6
            self.bana_rotate:start()
            self.bana_move:start()
        end
    elseif sc == 6 then
        if self.bana_rotate.is_finished then
            self.touch_fade:start()
            self.touch_move_up:start()
            self.touch_move_down:start()
            self.touch_resize:start()
            self.gleam_grow:start()
            self.steps_cursor = 7
        end
    elseif sc == 7 then
        if self.touch_move_down.is_finished then
            self.timer = current_ms
            self.steps_cursor = 8
        end
    elseif sc == 8 then
        if current_ms - self.timer >= 250 then
            self.touch_fade_out:start()
            self.steps_cursor = 9
        end
    elseif sc == 9 then
        if self.touch_fade_out.is_finished then
            self.timer = current_ms
            self.steps_cursor = 16
        end
    elseif sc == 16 then
        if current_ms - self.timer >= TAP_BLANK_MS then
            self.bana_rotate:start()
            self.bana_move:start()
            self.touch_fade:reset()
            self.touch_move_up:reset()
            self.touch_move_down:reset()
            self.touch_resize:reset()
            self.touch_fade_out:reset()
            self.gleam_grow:reset()
            self.steps_cursor = 10
        end
    elseif sc == 10 then
        if self.bana_rotate.is_finished then
            self.touch_fade:start()
            self.touch_move_up:start()
            self.touch_move_down:start()
            self.touch_resize:start()
            self.gleam_grow:start()
            self.steps_cursor = 11
        end
    elseif sc == 11 then
        if self.touch_move_down.is_finished then
            self.timer = current_ms
            self.steps_cursor = 12
        end
    elseif sc == 12 then
        -- hold, fade out and the blank beat of the second tap
        if current_ms - self.timer >= 250 + 167 + TAP_BLANK_MS then
            self.current_state = "rewards"
            self.steps_cursor = 13
            self.timer = current_ms
            self.rewards_ms = 0
            self.rewards_last_ms = nil
            self.donchan_move:start()
        end
    elseif sc == 13 then
        if current_ms - self.timer >= REWARDS_MS then
            self.current_state = "dress_up"
            self.steps_cursor = 17
            self.timer = current_ms
            self.dress_don:start()
            self.dress_chars:start()
            self.dress_title_up:start()
            self.dress_title_down:start()
            self.dress_title_fade:start()
        elseif self.donchan_move.is_finished then
            self.donchan_move:restart()
        end
    elseif sc == 17 then
        if current_ms - self.timer >= DRESS_UP_MS then
            self.current_state = "card_or_phone"
            self.steps_cursor = 14
            self.timer = current_ms
            self.resize_1:start()
            self.resize_2:reset()
        end
    elseif sc == 14 then
        if current_ms - self.timer >= CARD_PHONE_MS then
            self.current_state = "get"
            self.get_text_scale_down:start()
            self.get_text_scale_up:start()
            self.get_text_scale_down_2:start()
            self.get_text_fade_in:start()
            self.get_chara_1_bounce_up:start()
            self.get_fade_out:start()
            self.get_chara_bounce_up:reset()
            self.get_chara_bounce_down:reset()
            self.get_chara_1_bounce_down:reset()
            self.chara_0_timer = current_ms
            self.steps_cursor = 15
        end
        if self.resize_1.is_finished then
            self.resize_2:start()
            self.resize_1:reset()
        end
        if self.resize_2.is_finished then
            self.resize_1:start()
            self.resize_2:reset()
        end
    elseif sc == 15 then
        if self.get_fade_out.is_finished then
            self.current_state = "blank"
            self.timer = current_ms
            self.steps_cursor = 18
        end
        -- the two characters bounce in antiphase: chara 1 leads, chara 0 joins half a bounce later
        if self.get_chara_1_bounce_up.is_finished and not self.get_chara_1_bounce_down.is_started then
            self.get_chara_1_bounce_down:start()
        elseif self.get_chara_1_bounce_down.is_finished then
            self.get_chara_1_bounce_down:reset()
            self.get_chara_1_bounce_up:reset()
            self.get_chara_1_bounce_up:start()
        end

        if self.chara_0_timer and current_ms - self.chara_0_timer >= CHARA_HALF_BOUNCE_MS then
            self.get_chara_bounce_up:start()
            self.chara_0_timer = nil
        end
        if self.get_chara_bounce_up.is_finished and not self.get_chara_bounce_down.is_started then
            self.get_chara_bounce_down:start()
        elseif self.get_chara_bounce_down.is_finished then
            self.get_chara_bounce_down:reset()
            self.get_chara_bounce_up:reset()
            self.get_chara_bounce_up:start()
        end
    elseif sc == 18 then
        if current_ms - self.timer >= GET_BLANK_MS then
            self.current_state = "bana_options"
            self.fade_in:start()
            self.steps_cursor = 0
        end
    end
end

-- Rise from below past the rest position and settle back: ease out up, ease in down.
local function pop(progress, start, apex)
    local t = progress / 1000
    if t < DRESS_UP_RISE then
        local u = t / DRESS_UP_RISE
        local e = u * (2 - u)
        return start + (apex - start) * e, e
    end
    local u = (t - DRESS_UP_RISE) / (1 - DRESS_UP_RISE)
    return apex * (1 - u * u), 1
end

function BanaAdvertisement:draw(x, y)
    tex.draw_texture(self.t_background, { x = x, y = y })

    local ox, oy = tex.get_draw_offset()
    local sx = self.t_outline_info.x[1] + ox + x
    local sy = self.t_outline_info.y[1] + oy + y
    local sw = self.t_outline_info.x2[1] * 2
    local sh = self.t_outline_info.y2[1] - 13 * tex.get_screen_scale()
    tex.begin_scissor(sx, sy, sw, sh)

    if self.current_state == "tap_to_reader" then
        tex.draw_texture(self.t_reader, { x = x, y = y })
        local fade = self.touch_fade_out.is_started and self.touch_fade_out.attribute or self.touch_fade.attribute
        -- the phone swings in about the point it is held by, so texture.json x, y is that pivot
        tex.draw_texture(self.t_tap, {
            x = x + self.bana_move.attribute, y = y + self.bana_move.attribute * 0.713,
            rotation = self.bana_rotate.attribute, origin = { 64, 88 }, fade = self.touch_fade_out.attribute,
        })
        tex.draw_texture(self.t_touch, {
            x = x, y = y + self.touch_move_up.attribute + self.touch_move_down.attribute,
            scale = self.touch_resize.attribute, center = true, fade = fade,
        })
        -- the gleam stays up until the next pass starts
        if self.touch_fade.is_started then
            tex.draw_texture(self.t_touch_gleam, { x = x, y = y, y2 = self.gleam_grow.attribute })
        end

    elseif self.current_state == "card_or_phone" then
        tex.draw_texture(self.t_card_or_phone_bg, { x = x, y = y })
        tex.draw_texture(self.t_card_or_phone_card, { scale = self.resize_1.attribute, center = true, x = x, y = y })
        tex.draw_texture(self.t_card_or_phone_phone, { scale = self.resize_2.attribute, center = true, x = x, y = y })

    elseif self.current_state == "bana_options" then
        tex.draw_texture(self.t_banapassport, { scale = self.resize_1.attribute, center = true, x = x, y = y, fade = self.fade_in.attribute })
        tex.draw_texture(self.t_or, { x = x, y = y, fade = self.fade_in.attribute })
        tex.draw_texture(self.t_chara_0, { x = x, y = y, fade = self.fade_in.attribute })
        tex.draw_texture(self.t_osaifukeitai, { scale = self.resize_2.attribute, center = true, x = x, y = y, fade = self.fade_in.attribute })

    elseif self.current_state == "rewards" then
        tex.draw_texture(self.t_rewards_donchan, { x = x, y = y + self.donchan_move.attribute })

        local base_x = self.t_rewards_info.x[1]
        local base_y = self.t_rewards_info.y[1]
        for i = 0, 3 do
            local pos = ring_position(self.rewards_ms + i * REWARD_TRAIL - REWARD_START)
            local slot_from = math.floor(pos) % 4
            local slot_to = (slot_from + 1) % 4
            local t = pos - math.floor(pos)
            local dx = (1.0 - t) * self.t_rewards_info.x[slot_from + 1] + t * self.t_rewards_info.x[slot_to + 1] - base_x
            local dy = (1.0 - t) * self.t_rewards_info.y[slot_from + 1] + t * self.t_rewards_info.y[slot_to + 1] - base_y
            tex.draw_texture(self.t_rewards, { frame = i, x = x + dx, y = y + dy, index = 0 })
        end

        tex.draw_texture(self.t_rewards_top_text, { x = x, y = y })
        tex.draw_texture(self.t_rewards_bottom_text, { x = x, y = y })

    elseif self.current_state == "dress_up" then
        tex.draw_texture(self.t_dress_card, { x = x, y = y })
        for i = 0, 4 do
            local offset, alpha = pop(self.dress_chars.attribute, DRESS_UP_CHARS[i + 1][1], DRESS_UP_CHARS[i + 1][2])
            tex.draw_texture(self.t_dress_chars[i], { x = x, y = y + offset, fade = alpha })
        end

        local title_scale = self.dress_title_up.is_finished and self.dress_title_down.attribute or self.dress_title_up.attribute
        tex.draw_texture(self.t_dress_title, {
            scale = title_scale, center = true, x = x, y = y, fade = self.dress_title_fade.attribute,
        })

        -- the big don drops in smaller and grows past full size before it settles
        local t = self.dress_don.attribute / 1000
        local don_offset, don_alpha, don_scale
        if t < DON_RISE then
            local u = t / DON_RISE
            local e = u * (2 - u)
            don_offset, don_alpha, don_scale = 171 - 196 * e, e, 0.5 + 0.6 * e
        else
            local u = (t - DON_RISE) / (1 - DON_RISE)
            don_offset, don_alpha, don_scale = -25 * (1 - u * u), 1, 1.1 - 0.1 * u * u
        end
        tex.draw_texture(self.t_dress_don, {
            scale = don_scale, center = true, x = x, y = y + don_offset, fade = don_alpha,
        })

        -- sparkles pulse out of step: three fade up as the other two fade away
        local fade = self.sparkle_fade.attribute
        local grow = self.sparkle_scale.attribute
        for i = 0, 4 do
            local mine = i < 3
            local params = {
                index = i, x = x, y = y, center = true,
                scale = mine and grow or (2.5 - grow), fade = mine and fade or (1 - fade),
            }
            -- Lumen stacks two copies of the sparkle
            tex.draw_texture(self.t_dress_sparkle, params)
            tex.draw_texture(self.t_dress_sparkle, params)
        end

    elseif self.current_state == "get" then
        local get_text_scale
        if self.get_text_scale_up.is_finished then
            get_text_scale = self.get_text_scale_down_2.attribute
        elseif self.get_text_scale_down.is_finished then
            get_text_scale = self.get_text_scale_up.attribute
        else
            get_text_scale = self.get_text_scale_down.attribute
        end
        tex.draw_texture(self.t_get_text, {
            scale = get_text_scale, center = true, x = x, y = y,
            fade = math.min(self.get_text_fade_in.attribute, self.get_fade_out.attribute),
        })
        tex.draw_texture(self.t_get_chara_0, {
            x = x, y = y + self.get_chara_bounce_up.attribute + self.get_chara_bounce_down.attribute,
            fade = self.get_fade_out.attribute,
        })
        tex.draw_texture(self.t_get_chara_1, {
            x = x, y = y + self.get_chara_1_bounce_up.attribute + self.get_chara_1_bounce_down.attribute,
            fade = self.get_fade_out.attribute,
        })
    end

    tex.end_scissor()

    tex.draw_texture(self.t_outline, { x = x, y = y, index = 0 })
    tex.draw_texture(self.t_outline, { mirror = "horizontal", x = x, y = y, index = 1 })
end
