RewardShop = {}
RewardShop.__index = RewardShop

local S = tex.get_screen_scale()
local DIR = "reward_shop/shop"
local F = 1000 / 60
local WHITE, BLACK = { 255, 255, 255, 255 }, { 0, 0, 0, 255 }
local LEFT, DECIDE = 1, 3

local TIME_MIN, SETUP_AT, ASSEMBLE_LEN, INPUT_WAIT = 162, 55, 16, 60
local BONUS_LEN = { [0] = 0, 62, 93, 134 }  -- BonusMsg stop frame per line count
local COUNT_END_WAIT, FULL_HOLD = 30, 420
local MSG_HOLD, MSG_FADE = 180, 10
local ONBOX_COUNT, SMOKE_SWAP, SMOKE_LEN = 60, 25, 70
local TIMEUP_WAIT = 120
local COMPLETE_DELAY, COMPLETE_LEN = 29, 149

local PANEL_X, PANEL_Y = { 336, 944 }, 338
local ROLL_TIME_X, ROLL_TIME_Y = { 496, 984 }, 530
local ROLL_SHOP_X, ROLL_SHOP_Y = { 505, 925 }, 646
local MEDAL_X, MEDAL_Y = { 430, 850 }, 666
local POINTMSG_Y = 689
local DETAIL_X, DETAIL_Y = { 150, 1130 }, 280
local DON_X, DON_Y = { 140, 1140 }, 590
local COUNTER_DX, BONUS_DX, FALL_DX, MSG_DX = { 44, 166 }, { -52, 69 }, { -80, 80 }, { -72, 72 }
local TILE_X = { 340, 460, 580, 700, 820, 940 }
local TILE_Y = { 208, 338, 502 }
local TILE_FRAME = { [2] = 0, [3] = 1, [4] = 2, [5] = 3 }
local BONUS_ROWS = { -100, -75, -50 }
local FALL_COINS = {
    { 0, 0 }, { 60, 8 }, { -110, 16 }, { -60, 24 }, { 100, 32 }, { 30, 40 }, { -30, 48 },
}
local FLOWERS = {  -- x, y phase, turn speed
    { -110, 0.0, 1.2 }, { -60, 0.6, -0.9 }, { 15, 0.25, 1.0 }, { 95, 0.75, -1.3 }, { 120, 0.1, 0.8 },
    { -125, 0.45, -1.1 }, { 60, 0.9, 1.4 }, { -20, 0.55, -0.7 }, { 75, 0.35, 0.9 }, { -85, 0.15, 1.1 },
}

local function clamp01(v) return math.max(0.0, math.min(1.0, v)) end
local function ramp(t, at, len) return clamp01((t - at) / len) end
local function ease_out(u) return u * (2 - u) end
local function ease_in(u) return u * u end
local function lerp(a, b, u) return a + (b - a) * u end

local function play(name)
    if audio.has_sound(name) then audio.play_sound(name, name:find("vo_") and "voice" or "sound") end
end

function RewardShop.new(data)
    local self = setmetatable({}, RewardShop)
    self.tex = {}
    self.from_time = data.from_time
    self.season = data.season or 0
    self.goods = data.goods
    self.draw_icon, self.buy, self.preview, self.draw_chara = data.draw_icon, data.buy, data.preview, data.draw_chara
    for i, good in ipairs(self.goods) do
        good.name_text = text.create_raw_text(good.name, math.floor(22 * S), WHITE, BLACK, false, 3, 1.0)
        good.cost_text = text.create_raw_text(tostring(good.cost), math.floor(18 * S), WHITE, BLACK, false, 3, 1.0)
        good.cost_big = text.create_raw_text(tostring(good.cost), math.floor(26 * S), WHITE, BLACK, false, 4, 1.0)
        good.index = i
    end
    self.telop_text = text.create_raw_text(tex.skin_text("reward_shop_telop"), math.floor(20 * S), WHITE, BLACK, false, 3, 1.0)
    self.title_tag = text.create_raw_text("称号", math.floor(26 * S), WHITE, BLACK, false, 3, 1.0)
    self.seats = {}
    for seat = 1, 2 do
        local p = data.players[seat]
        local s = {
            seat = seat, joined = p.joined, card = p.card, now = p.now, add = p.add, max = p.max, owned = p.owned,
            shown = p.now, bonus = {}, cursor = 0, x = TILE_X[1], y = TILE_Y[1], onbox = 0,
            balance = p.now + p.add, dialog = nil, smoke = -1, don_f = 0,
        }
        if p.daily then s.bonus[#s.bonus + 1] = "bonus_day" end
        if p.weekly then s.bonus[#s.bonus + 1] = "bonus_week" end
        if p.monthly then s.bonus[#s.bonus + 1] = "bonus_month" end
        s.complete = s.card and self:all_owned(s)
        s.complete_f = s.complete and COMPLETE_LEN or -1
        self.seats[seat] = s
    end
    self.time_up_f = -1
    self.done = false
    self.last_ms = tex.get_current_ms()
    audio.play_sound(self.from_time and "bgm" or "shop_bgm", "music")
    if self.from_time then
        self:enter_time()
    else
        self:enter_shop()
    end
    return self
end

function RewardShop:all_owned(s)
    for i = 1, #self.goods do
        if not s.owned[i] then return false end
    end
    return #self.goods > 0
end

function RewardShop:t(key)
    local t = self.tex[key]
    if not t then
        local id = tex.get_texture(DIR .. "/" .. key)
        local info = tex.get_texture_info(DIR:match("[^/]+$"), key)
        t = { id = id, w = info and info.x2[1] or 0, h = info and info.y2[1] or 0 }
        self.tex[key] = t
    end
    return t
end

-- centred on (cx, cy); sx/sy scale, rot degrees
function RewardShop:mid(key, cx, cy, opts)
    opts = opts or {}
    local t = self:t(key)
    local sx, sy = opts.sx or opts.s or 1, opts.sy or opts.s or 1
    local w, h = t.w * sx, t.h * sy
    local params = { x2 = w - t.w, y2 = h - t.h, fade = opts.fade, frame = opts.frame, blend = opts.blend }
    if opts.rot then
        params.x, params.y = cx * S, cy * S
        params.center, params.rotation, params.origin = true, opts.rot, { w / 2, h / 2 }
    else
        params.x, params.y = cx * S - w / 2, cy * S - h / 2
    end
    tex.draw_texture(t.id, params)
end

function RewardShop:set_state(state)
    self.state, self.f = state, 0
end

function RewardShop:enter_time()
    self:set_state("time")
    self.title, self.title_f = "title_time", 0
    play("vo_timecall")
    self.time_len = TIME_MIN
    for _, s in ipairs(self.seats) do
        if s.card then
            local lines = #s.bonus
            s.count_at = SETUP_AT + BONUS_LEN[lines]
            local total = math.ceil(s.add / 5) + COUNT_END_WAIT
            s.count_end = s.count_at + total
            s.full = s.now + s.add >= s.max and s.add > 0
            s.time_end = s.count_end + (s.full and FULL_HOLD or 0)
            if s.complete then s.time_end = SETUP_AT end
            self.time_len = math.max(self.time_len, s.time_end)
        end
    end
end

function RewardShop:enter_shop()
    self:set_state("shop")
    self.title, self.title_f = "title_shop", 0
    play("vo_shopcall")
    play("se_shopopen")
    for _, s in ipairs(self.seats) do
        if s.card then s.shown = s.balance end
    end
end

function RewardShop:leave()
    self:set_state("leaving")
    audio.stop_sound(self.from_time and "bgm" or "shop_bgm")
end

function RewardShop:update(current_ms)
    local df = (current_ms - self.last_ms) / F
    self.last_ms = current_ms
    self.f = self.f + df
    self.title_f = self.title_f + df
    if self.state == "time" then
        self:update_time(df)
    elseif self.state == "assemble" then
        if self.f >= ASSEMBLE_LEN then self:enter_shop() end
    elseif self.state == "shop" then
        self:update_shop(df)
    elseif self.state == "leaving" and self.f >= 12 then
        self.done = true
    end
    for _, s in ipairs(self.seats) do
        s.don_f = s.don_f + df
    end
end

function RewardShop:update_time(df)
    local f = self.f
    local all_complete, any_card = true, false
    for _, s in ipairs(self.seats) do
        if s.card then
            any_card = true
            all_complete = all_complete and s.complete
            if not s.fell and f >= SETUP_AT and s.add > 0 and not s.complete then
                s.fell = true
                play("se_medalfall")
            end
            if f >= s.count_at and s.shown < s.now + s.add then
                s.shown = math.min(s.now + s.add, s.now + (f - s.count_at) * 5)
                s.tick = (s.tick or 0) + df
                if s.tick >= 8 then
                    s.tick = 0
                    play("se_medalcnt")
                end
            end
            if s.full and not s.full_said and f >= s.count_end then
                s.full_said = true
                play("se_medalmax")
                play("vo_medalmax")
            end
        end
    end
    if f >= self.time_len then
        if not any_card or all_complete then
            self:leave()
        else
            play("se_assemble")
            self:set_state("assemble")
        end
    end
end

function RewardShop:update_shop(df)
    local all_left = true
    for _, s in ipairs(self.seats) do
        if s.card then
            local ax, ay = self:cursor_xy(s.cursor)
            local k = 1 - 0.65 ^ df
            s.x, s.y = lerp(s.x, ax, k), lerp(s.y, ay, k)
            all_left = all_left and s.exited and not s.buying
            if s.dialog and s.dialog.hold then
                s.dialog.f = s.dialog.f + df
                if s.dialog.f >= MSG_HOLD + MSG_FADE then s.dialog = nil end
            end
            if not s.exited then
                local before = s.onbox
                s.onbox = s.onbox + df
                -- the exit tile only needs a change to undo an earlier preview
                if before < ONBOX_COUNT and s.onbox >= ONBOX_COUNT and (self.goods[s.cursor] or s.previewed) then
                    s.smoke = 0
                    s.swapped = false
                end
            end
            if s.smoke >= 0 then
                s.smoke = s.smoke + df
                if not s.swapped and s.smoke >= SMOKE_SWAP then
                    s.swapped = true
                    local good = self.goods[s.cursor]
                    self.preview(s.seat, good and good.type or -1, good and good.id or -1)
                    s.previewed = good ~= nil
                end
                if s.smoke >= SMOKE_LEN then s.smoke = -1 end
            end
            if s.complete_f >= 0 and s.complete_f < COMPLETE_LEN then
                s.complete_f = s.complete_f + df
            end
        end
    end
    if self.time_up_f >= 0 then
        self.time_up_f = self.time_up_f + df
        local busy = false
        for _, s in ipairs(self.seats) do busy = busy or s.buying end
        if self.time_up_f >= TIMEUP_WAIT and not busy then self:leave() end
    elseif all_left then
        self:leave()
    end
end

function RewardShop:cursor_xy(index)
    if index == 0 then return TILE_X[1], TILE_Y[1] end
    local row, col
    if index <= 5 then
        row, col = 1, index + 1
    elseif index <= 11 then
        row, col = 2, index - 5
    else
        row, col = 3, index - 11
    end
    return TILE_X[col], TILE_Y[row]
end

function RewardShop:in_shop()
    return self.state == "shop"
end

function RewardShop:wants_input(seat)
    local s = self.seats[seat]
    return self.state == "shop" and self.f >= INPUT_WAIT and self.time_up_f < 0 and s.card and not s.exited and not s.buying
end

function RewardShop:time_up()
    if self.time_up_f < 0 then
        self.time_up_f = 0
        play("se_timeup")
        for _, s in ipairs(self.seats) do
            if not s.buying then s.dialog = nil end
        end
    end
end

function RewardShop:show_dialog(s, kind, buttons)
    s.dialog = { kind = kind, yes = false, buttons = buttons, hold = not buttons and kind ~= "wait", f = 0 }
end

function RewardShop:input(seat, action)
    local s = self.seats[seat]
    local d = s.dialog
    if action == DECIDE then
        play("don")
        self:decide(s)
        return
    end
    play("kat")
    if d and d.buttons then
        d.yes = action == LEFT
        return
    end
    s.dialog = nil
    local count = #self.goods + 1
    s.cursor = (s.cursor + (action == LEFT and -1 or 1) + count) % count
    s.onbox = 0
end

function RewardShop:decide(s)
    local d = s.dialog
    local good = self.goods[s.cursor]
    if d and d.buttons then
        if not d.yes then
            s.dialog = nil
            play("kat")
        elseif not good then
            s.dialog, s.exited = nil, true
        else
            self:show_dialog(s, "wait", false)
            s.buying = true
            self.buy(s.seat, good.type, good.id)
        end
        return
    end
    if not good then
        self:show_dialog(s, "exit", true)
    elseif s.owned[s.cursor] then
        self:show_dialog(s, "already", false)
        play("se_notice")
    elseif s.balance < good.cost then
        self:show_dialog(s, "shortage", false)
        play("se_notice")
    else
        self:show_dialog(s, "get", true)
        play("vo_getsuruka")
    end
end

function RewardShop:on_buy(seat, status, medals)
    local s = self.seats[seat]
    s.buying = false
    s.dialog = nil
    if status == "ok" then
        s.owned[s.cursor] = true
        s.balance, s.shown = medals, medals
        play("se_casher")
        play("se_get")
        play("vo_getdadon")
        if self:all_owned(s) then
            s.complete, s.complete_f = true, 0
            play("se_complete")
            play("vo_zenbuno")
        end
    elseif status == "already" then
        s.owned[s.cursor] = true
        self:show_dialog(s, "already", false)
        play("se_notice")
    elseif status == "shortage" then
        self:show_dialog(s, "shortage", false)
        play("se_notice")
    else
        play("se_notice")
    end
end

function RewardShop:is_done()
    return self.done
end

-- right-aligned; rightmost digit's centre at x
function RewardShop:draw_roll(s, x, y, scale, fade)
    local str = tostring(math.max(0, math.floor(s.shown)))
    for i = 1, #str do
        local digit = tonumber(str:sub(#str - i + 1, #str - i + 1))
        self:mid("digits_roll", x - (i - 1) * 36 * scale, y, { s = scale, frame = digit, fade = fade })
    end
    local coin_x = x - 190 * scale
    self:mid("coin", coin_x, y, { s = scale, fade = fade })
    local glint = math.floor(self.last_ms / F) % 180
    if glint < 9 then
        self:mid("glint", coin_x, y, { s = scale, frame = math.floor(glint / 3), fade = fade, blend = "additive" })
    end
end

function RewardShop:draw_title()
    local f = self.title_f
    local x
    if f < 16 then
        x = lerp(110, 210, ease_out(ramp(f, 0, 16)))
    else
        x = lerp(210, 200, ramp(f, 16, 4))
    end
    local fade = ramp(f, 0, 16)
    if self.state == "assemble" then fade = 1 - ramp(self.f, 0, 5) end
    if self.state == "leaving" then fade = 1 - ramp(self.f, 0, 5) end
    self:mid(self.title, x, 48, { fade = fade })
end

function RewardShop:draw_don(s)
    if not s.card then return end
    local f = s.don_f
    local dx, dy
    if f < 9 then
        local u = ease_in(ramp(f, 0, 8))
        dx, dy = lerp(-293, -159, u), lerp(-53, -112, u)
    else
        local u = ease_out(ramp(f, 9, 21))
        dx, dy = lerp(-141, 0, u), lerp(-110, 0, u)
    end
    if s.seat == 2 then dx = -dx end
    self.draw_chara(s.seat, (DON_X[s.seat] + dx) * S, (DON_Y + dy) * S)
end

function RewardShop:draw_smoke(s)
    if s.smoke < 0 then return end
    local f = s.smoke
    local x, y = DON_X[s.seat], DON_Y - 150
    if f < 46 then
        local scale = f < 15 and lerp(0.1, 1.2, ease_out(ramp(f, 0, 15))) or lerp(1.2, 1.1, ramp(f, 15, 10))
        self:mid("smoke", x, y, { s = scale, frame = 0 })
    else
        self:mid("smoke", x, y, { s = 1.1, frame = math.min(3, 1 + math.floor((f - 46) / 8)), fade = 1 - ramp(f, 46, 24) })
    end
end

function RewardShop:draw_time_panel(s, fade)
    local px = PANEL_X[s.seat]
    if not s.joined then return end
    self:mid(s.seat == 1 and "time_bg_1p" or "time_bg_2p", px, PANEL_Y, { fade = fade })
    if not s.card then
        for side = -1, 1, 2 do
            local u = (self.f + (side + 1) * 42) % 168 / 168
            local hop = math.abs(math.sin(u * math.pi * 2))
            self:mid("takoyaki", px + side * 100 + 62 * math.sin(u * math.pi * 2), PANEL_Y + 210 - 170 * hop, { fade = fade })
        end
        return
    end
    local f = self.state == "assemble" and SETUP_AT or self.f
    local open = ease_out(ramp(f, 2, 7))
    self:mid("season_daishi", px, PANEL_Y + 110, {
        sx = lerp(0.1, 1, open), sy = lerp(0.8, 1, open), frame = self.season * 2 + s.seat - 1,
        fade = fade * (f >= 2 and 1 or 0),
    })
    if f >= 6 then
        local pop = f < 11 and lerp(2, 0.9, ramp(f, 6, 5)) or lerp(0.9, 1, ramp(f, 11, 2))
        self:mid("season_thema", px, PANEL_Y, { s = pop, frame = 0, fade = fade * ramp(f, 6, 5) })
    end
    if f < SETUP_AT then return end
    local sf = f - SETUP_AT
    local side = s.seat
    if s.complete then
        self:draw_pop("msg_all_got", px + MSG_DX[side], PANEL_Y + 100, sf, fade)
        return
    end
    if s.add > 0 and f < s.count_end then
        for _, coin in ipairs(FALL_COINS) do
            local cf = (sf - coin[2]) % 100
            if sf >= coin[2] and cf < 33 then
                self:mid("coin_spin", px + FALL_DX[side] + coin[1], PANEL_Y + 40 + 140 * (cf / 33),
                    { frame = math.floor(cf / 3) % 4, fade = fade * ramp(cf, 0, 9) })
            end
        end
    end
    -- +100 counter: right-aligned digits, plus sign just left of them
    local cx, cy = px + COUNTER_DX[side], PANEL_Y + 54
    if s.add > 0 then
        for i, digit in ipairs({ 0, 0, 1 }) do
            self:mid("digits_small", cx - (i - 1) * 22, cy, { frame = digit, fade = fade })
        end
        self:mid("plus", cx - 66 - 4, cy, { fade = fade })
    end
    local bx, by = px + BONUS_DX[side], PANEL_Y + 190
    for i, key in ipairs(s.bonus) do
        local at = i == 1 and 30 or i == 2 and 62 or 93
        if sf >= at then
            self:mid(key, bx, by + lerp(i == 1 and -40 or 0, BONUS_ROWS[i], ramp(sf, at, 5)), { fade = fade })
        end
    end
    if s.full and f >= s.count_end then
        self:draw_pop("msg_full", px + MSG_DX[side], PANEL_Y + 100, f - s.count_end, fade)
    end
end

-- scale 0.1 -> 1.2 -> 1 message with a coin
function RewardShop:draw_pop(key, x, y, f, fade)
    local scale = f < 11 and lerp(0.1, 1.2, ramp(f, 0, 11)) or lerp(1.2, 1, ramp(f, 11, 3))
    self:mid(key, x, y, { s = scale, fade = fade })
end

function RewardShop:draw_medal_base(s)
    if not s.card then return end
    local grow = self.state == "assemble" and ramp(self.f, 0, ASSEMBLE_LEN) or 1
    self:mid("season_medal", MEDAL_X[s.seat], MEDAL_Y, { sx = grow, frame = self.season * 2 + s.seat - 1 })
end

function RewardShop:draw_pointmsg(s, f)
    if not s.card then return end
    local fade = ramp(f, 0, 6)
    local x = MEDAL_X[s.seat]
    if s.complete then
        self:mid("pointmsg_allget_shadow", x - 2, POINTMSG_Y - 26, { fade = fade })
        self:mid("pointmsg_allget", x, POINTMSG_Y - 24, { fade = fade })
    elseif s.balance >= s.max and s.max > 0 then
        -- sprite 328's blink: 1 -> 0 -> 1 per 140 frames, then on
        local b = f % 140
        self:mid("pointmsg_full", x - 1, POINTMSG_Y - 4, {
            fade = fade * (b < 11 and 1 - b / 11 or b < 24 and (b - 11) / 13 or 1),
        })
    end
end

function RewardShop:draw_tile(good, x, y, fade)
    local frame = TILE_FRAME[good.type]
    if not frame then -- a title: no icon or label art, so a text tag on the first tile colour
        self:mid("tile", x, y, { frame = 0, fade = fade })
        local tag = self.title_tag
        tag:draw({ x = x * S - tag.width / 2, y = y * S - tag.height / 2, fade = fade })
        return
    end
    self:mid("tile", x, y, { frame = frame, fade = fade })
    self.draw_icon(good.icon, x * S, (y - 6) * S, 80 * S, fade)
    self:mid("label", x, y + 30, { frame = frame, fade = fade })
end

function RewardShop:draw_grid(fade)
    self:mid("chip_cosmetic", 350, 141, { fade = fade })
    self:mid("tile_exit", TILE_X[1], TILE_Y[1], { fade = fade })
    for i, good in ipairs(self.goods) do
        local x, y = self:cursor_xy(i)
        self:draw_tile(good, x, y, fade)
        self:mid("coin", x - 30, y - 61, { s = 0.5, fade = fade })
        good.cost_text:draw({ x = (x - 18) * S, y = (y - 61) * S - good.cost_text.height / 2, fade = fade })
        for _, s in ipairs(self.seats) do
            if s.card and s.owned[i] then
                self:mid(s.seat == 1 and "check_1p" or "check_2p", x, y + 32, { fade = fade })
            end
        end
    end
end

function RewardShop:draw_cursor(s, other, fade)
    if not s.card or s.exited then return end
    local duet = other.card and not other.exited and other.cursor == s.cursor
    local one = s.seat == 1
    local border = one and (duet and "cursor_1p_duet" or "cursor_1p") or (duet and "cursor_2p_duet" or "cursor_2p")
    local glow = duet and (one and "cursor_glow_1p_duet" or "cursor_glow_2p_duet") or "cursor_glow"
    local tag = one and "tag_1p" or "tag_2p"
    local tag_white = one and "tag_1p_white" or "tag_2p_white"
    local g = math.floor(self.last_ms / F) % 120
    local pulse = g < 60 and (g < 30 and g / 30 or (60 - g) / 30) * 0.6 or 0
    local p = math.floor(self.last_ms / F) % 40
    self:mid(border, s.x, s.y, { fade = fade })
    self:mid(glow, s.x, s.y, { fade = fade * pulse })
    self:mid(tag, s.x, s.y - 32, { fade = fade })
    self:mid(tag_white, s.x, s.y - 32, { fade = fade * (p < 25 and p / 25 or (40 - p) / 15) })
end

function RewardShop:draw_detail(s, fade)
    if not s.card or s.exited then return end
    local cx, cy = DETAIL_X[s.seat], DETAIL_Y
    if s.complete then
        self:draw_complete(s, cx, cy, fade)
    end
    local good = self.goods[s.cursor]
    if good and not s.complete then
        self:mid(s.seat == 1 and "panel_1p" or "panel_2p", cx, cy, { fade = fade })
        if TILE_FRAME[good.type] then
            self:mid("label", cx, cy - 84, { frame = TILE_FRAME[good.type], fade = fade })
        end
        local name = good.name_text
        local wide = math.min(1, 270 * S / math.max(name.width, 1))
        name:draw({ x = cx * S - name.width * wide / 2, y = (cy - 54) * S - name.height / 2,
                    x2 = name.width * (wide - 1), fade = fade })
        self:mid("coin", cx - 31, cy - 22, { s = 0.5, fade = fade })
        local cost = good.cost_big
        cost:draw({ x = (cx - 13) * S, y = (cy - 22) * S - cost.height / 2, fade = fade })
        self:draw_tile(good, cx, cy + 46, fade)
        if s.owned[s.cursor] then
            self:mid(s.seat == 1 and "check_1p" or "check_2p", cx, cy + 78, { fade = fade })
        end
    end
    local d = s.dialog
    if not d then return end
    local dy = cy + 46
    local a = fade
    if d.hold and d.f > MSG_HOLD then a = a * (1 - ramp(d.f, MSG_HOLD, MSG_FADE)) end
    self:mid("dialog", cx, dy, { fade = a })
    local key = "msg_" .. d.kind
    self:mid(key, cx, dy + (d.buttons and -26 or 0), { fade = a })
    if d.buttons then
        local ty = dy + 16
        self:mid(d.yes and "yes_on" or "yes_off", cx - 52, ty, { fade = a })
        self:mid(d.yes and "no_off" or "no_on", cx + 52, ty, { fade = a })
        local r = math.floor(self.last_ms / F) % 60
        self:mid("button_ring", cx + (d.yes and -52 or 52), ty, {
            fade = a * lerp(0.3, 1, r < 30 and 1 - r / 30 or (r - 30) / 30),
        })
    end
end

function RewardShop:draw_complete(s, cx, cy, fade)
    local f = s.complete_f - COMPLETE_DELAY
    if f < 0 then return end
    for i, flower in ipairs(FLOWERS) do
        local u = (flower[2] + self.last_ms / 4000) % 1
        local key = i % 2 == 0 and "petal" or "flower"
        self:mid(key, cx + flower[1], cy - 140 + 280 * u, {
            frame = i % (key == "petal" and 6 or 10),
            rot = self.last_ms * 0.1 * flower[3],
            fade = fade * math.min(1, math.min(u, 1 - u) * 6),
        })
    end
    local scale = f < 14 and lerp(0.1, 1.2, ramp(f, 0, 14)) or lerp(1.2, 1, ramp(f, 14, 4))
    self:mid("complete", cx, cy, { s = scale, fade = fade })
end

function RewardShop:draw_shop(f, fade)
    local bg = ease_out(ramp(f, 0, 7))
    self:mid("season_bg", 636, 310, { sx = lerp(0.05, 1, bg), sy = lerp(0.8, 1, bg), frame = self.season, fade = fade })
    if self.season > 0 and f >= 5 then
        local pop = f < 10 and lerp(2, 0.9, ramp(f, 5, 5)) or lerp(0.9, 1, ramp(f, 10, 2))
        self:mid("season_thema", 642, 52, { s = pop, frame = self.season, fade = fade * ramp(f, 5, 5) })
    end
    local grid = fade * ramp(f, 10, 3)
    for _, s in ipairs(self.seats) do
        self:draw_don(s)
        self:draw_smoke(s)
    end
    if grid > 0 then
        self:draw_grid(grid)
        for i, s in ipairs(self.seats) do
            self:draw_cursor(s, self.seats[3 - i], grid)
            self:draw_detail(s, grid)
        end
    end
    if f >= 12 then
        local a = fade
        self:mid("telop", 640, 108, { fade = a })
        local hop = math.floor(self.last_ms / F) % 150
        local h = hop < 5 and hop / 5 or hop < 15 and (15 - hop) / 10 or 0
        self:mid("telop_icon", 272 - 10 * h, 96 - 4 * h, { fade = a })
        self.telop_text:draw({ x = 342 * S, y = 108 * S - self.telop_text.height / 2, fade = a })
    end
end

function RewardShop:draw()
    tex.draw_texture(self:t("bg").id)
    tex.draw_texture(self:t("footer").id, { y = 577 * S })
    local state, f = self.state, self.f
    if state == "time" or state == "assemble" then
        local fade = state == "assemble" and 1 - ramp(f, 0, ASSEMBLE_LEN) or 1
        for _, s in ipairs(self.seats) do
            self:draw_time_panel(s, fade)
            self:draw_don(s)
        end
    end
    if state == "shop" or state == "assemble" or state == "leaving" then
        for _, s in ipairs(self.seats) do
            self:draw_medal_base(s)
        end
    end
    for _, s in ipairs(self.seats) do
        if s.card then
            local u = state == "time" and 0 or state == "assemble" and ramp(f, 0, ASSEMBLE_LEN) or 1
            local x = lerp(ROLL_TIME_X[s.seat], ROLL_SHOP_X[s.seat], u)
            self:draw_roll(s, x, lerp(ROLL_TIME_Y, ROLL_SHOP_Y, u), lerp(1, 0.8, u))
        end
    end
    if state == "shop" or state == "leaving" then
        local fade = state == "leaving" and 1 - ramp(f, 0, 12) or 1
        self:draw_shop(state == "leaving" and 60 or f, fade)
        for _, s in ipairs(self.seats) do
            self:draw_pointmsg(s, state == "leaving" and 60 or f)
        end
    end
    self:draw_title()
end
