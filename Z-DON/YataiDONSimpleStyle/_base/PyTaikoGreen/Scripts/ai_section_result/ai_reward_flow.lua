AIRewardFlow = {}
AIRewardFlow.__index = AIRewardFlow

local S = tex.get_screen_scale()
local FRAME_MS = 1000 / 60
local DIR = "ai_reward"
local KATSU, DON = 1, 2
local RANK_MAX, ASSIGNED_RANK = 11, 10
local ALL_REWARDS_WINS = 9999

local INIT_WAIT = 20
local RANK_COUNT_WAIT, TITLE_WAIT, PANEL_FADE, PLAYER_WAIT = 60, 150, 20, 1200
local REWARD_WAIT, NEXT_WAIT, HINT_WAIT, LONG_WAIT = 120, 120, 120, 1800

local CONDITION_BACK = { [0] = 0, 0, 0, 1, 1, 2, 2, 3, 3, 3 }
local KIND_TEXT = { song = "ai_reward_song", head = "ai_reward_head", body = "ai_reward_body", title = "ai_reward_title" }

local function clamp01(v) return math.max(0, math.min(1, v)) end
local function ramp(t, at, len) return clamp01((t - at) / len) end
local function lerp(a, b, u) return a + (b - a) * u end

local function play(name)
    if audio.has_sound(name) then audio.play_sound(name, name:find("^vo_") and "voice" or "sound") end
end
local function play_bgm(name)
    if audio.has_sound(name) then audio.play_sound(name, "music") end
end

function AIRewardFlow.new(p)
    local self = setmetatable({}, AIRewardFlow)
    self.ids, self.sizes = {}, {}
    self.p = p
    self.stages = {}
    if p.rank_after > p.rank_before then table.insert(self.stages, "rankup") end
    if p.reward_kind ~= "" then table.insert(self.stages, "reward") end
    local has_goal = p.rank_after < RANK_MAX or p.next_reward_wins >= 0
    if #self.stages == 0 and has_goal then table.insert(self.stages, "remind") end
    self.stage_index = 0
    if #self.stages > 0 then
        tex.load_folder("ai_section_result", DIR)
        audio.stop_sound("ai_bgm")
    end
    if p.reward_name ~= "" then
        self.reward_name = text.create_raw_text(p.reward_name, 38, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 5, 2)
        self.reward_kind = text.create_text(KIND_TEXT[p.reward_kind], { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 5, 2)
    end
    if p.next_reward_name ~= "" then
        self.next_name = text.create_raw_text(p.next_reward_name, 24, { 0, 0, 0, 255 }, { 255, 255, 255, 255 }, false, 3, 2)
    end
    self:next_stage(0)
    return self
end

function AIRewardFlow:next_stage(ms)
    self.stage_index = self.stage_index + 1
    self.stage = self.stages[self.stage_index]
    self.start_ms = ms
    self.f = 0
    self.played = {}
    self.phase = "reveal"
    self.phase_at = 0
    self.waiting_since = nil
    if self.bgm then audio.stop_sound(self.bgm) end
    self.bgm = self.stage and self.stage .. "_bgm"
    if self.bgm then play_bgm(self.bgm) end
    if self.stage == "reward" and self.p.reward_kind ~= "" then
        play(math.random() < 0.5 and "vo_reward_congra1" or "vo_reward_congra2")
    end
end

function AIRewardFlow:once(key, at)
    if not self.played[key] and self.f >= at then
        self.played[key] = true
        return true
    end
    return false
end

function AIRewardFlow:set_phase(phase)
    self.phase = phase
    self.phase_at = self.f
end

function AIRewardFlow:update(ms)
    if not self.stage then return end
    self.now_ms = ms
    if self.start_ms == 0 then self.start_ms = ms end
    self.f = (ms - self.start_ms) / FRAME_MS
    if self.stage == "rankup" then self:update_rankup() elseif self.stage == "reward" then self:update_reward() end
    self:update_wait(ms)
end

function AIRewardFlow:update_rankup()
    local p, shine_at = self.p, INIT_WAIT + RANK_COUNT_WAIT
    if self:once("shine", shine_at) then
        play("se_rankup_shine")
        play("vo_rankup_odd")
        if p.rank_after >= RANK_MAX then play("fanfare") end
    end
    if self.phase == "reveal" and self.f >= shine_at + TITLE_WAIT then
        if p.rank_after == ASSIGNED_RANK then play("vo_rankup_congra1") end
        if p.rank_after == RANK_MAX then play("vo_rankup_congra2") end
        self:set_phase("title")
    end
end

function AIRewardFlow:update_reward()
    if self:once("get", INIT_WAIT + REWARD_WAIT) then
        play(self.p.wins_after >= ALL_REWARDS_WINS and "vo_reward_complete" or "vo_reward_get")
    end
    if self.phase == "reveal" and self.f >= INIT_WAIT + REWARD_WAIT + NEXT_WAIT + HINT_WAIT then self:set_phase("wait") end
end

function AIRewardFlow:update_wait(ms)
    if self.stage == "remind" and self.phase == "reveal" and self.f >= INIT_WAIT + HINT_WAIT then self:set_phase("wait") end
    local limit = self.stage == "rankup" and PLAYER_WAIT or LONG_WAIT
    if self.phase ~= "reveal" and self.f >= self.phase_at + limit then self:advance(ms) end
end

function AIRewardFlow:advance(ms)
    if self.stage == "rankup" and self.phase == "title" then
        if self.p.rank_after < RANK_MAX then play("vo_rankup_next") end
        self:set_phase("next")
        return
    end
    self:next_stage(ms)
end

function AIRewardFlow:input(action)
    if not self.stage or self.f < INIT_WAIT then return false end
    if self.phase == "reveal" then
        if action ~= DON then return false end
        if self.stage == "rankup" then
            self.f = INIT_WAIT + RANK_COUNT_WAIT + TITLE_WAIT
            self.played.shine = true
        elseif self.stage == "reward" then
            self.f = INIT_WAIT + REWARD_WAIT + NEXT_WAIT + HINT_WAIT
            self.played.get = true
        else
            self.f = INIT_WAIT + HINT_WAIT
        end
        self.start_ms = self.now_ms and self.now_ms - self.f * FRAME_MS or self.start_ms
        return true
    end
    local wanted = self.stage == "rankup" and self.phase == "title" and KATSU or DON
    if action ~= wanted then return false end
    self:advance(self.now_ms or self.start_ms)
    return true
end

function AIRewardFlow:is_done()
    return self.stage == nil
end

function AIRewardFlow:put(key, cx, cy, o)
    o = o or {}
    local id = self.ids[key]
    if id == nil then
        id = tex.get_texture("ai_section_result/" .. DIR .. "/" .. key)
        self.ids[key] = id
        self.sizes[key] = tex.get_texture_info(DIR, key)
    end
    local info = self.sizes[key]
    if not info then return end
    local sx, sy = o.sx or o.s or 1, o.sy or o.s or 1
    local w, h = info.width * S, info.height * S
    tex.draw_texture(id, {
        x = cx * S, y = cy * S,
        x2 = w * (sx - 1), y2 = h * (sy - 1),
        origin = { w * sx * 0.5, h * sy * 0.5 },
        rotation = o.rot or 0,
        fade = o.fade or 1,
        frame = o.frame or 0,
        mirror = o.mirror,
        blend = o.add and "additive" or nil,
    })
end

function AIRewardFlow:at(key, x, y, o)
    local info = self.sizes[key]
    if info == nil then
        self:put(key, -9999, -9999, { fade = 0 })
        info = self.sizes[key]
    end
    if not info then return end
    self:put(key, x + info.width * 0.5, y + info.height * 0.5, o)
end

function AIRewardFlow:digits(key, value, cx, cy, step, o, glow)
    local str = tostring(math.max(0, math.floor(value)))
    local x = cx - (#str - 1) * step * 0.5
    for i = 1, #str do
        local d = str:byte(i) - 48
        if glow then
            local a = o and o.fade or 1
            self:put(glow, x, cy, { frame = d, fade = a })
        end
        self:put(key, x, cy, { frame = d, fade = o and o.fade or 1, s = o and o.s })
        x = x + step
    end
end

function AIRewardFlow:draw_window(t)
    local y_s = t < 2 and lerp(0.013, 0.194, ramp(t, 0, 2)) or t < 9 and lerp(0.375, 1.461, ramp(t, 2, 7)) or t < 11 and lerp(1.231, 1, ramp(t, 9, 2)) or 1
    local x_s = t < 2 and lerp(0.073, 0.189, ramp(t, 0, 2)) or t < 9 and lerp(0.305, 1, ramp(t, 2, 7)) or 1
    local a = t < 9 and ramp(t, 0, 8) or 1
    local swing = (t % 240) / 120
    local border = swing < 1 and swing or 2 - swing
    self:put("window_border_a", 640, 330, { sx = x_s, sy = y_s, fade = a * (1 - border) })
    self:put("window_border_b", 640, 330, { sx = x_s, sy = y_s, fade = a * border })
    self:put("window_body", 640, 330, { sx = x_s, sy = y_s, fade = a })
end

function AIRewardFlow:draw_makina(t, x, y)
    local f = t % 500
    local frame, dx = 0, 0
    if (f >= 66 and f < 73) or (f >= 127 and f < 134) then frame = 1 end
    if f >= 184 then frame, dx = 2, 3 end
    if f >= 274 then frame = 3 end
    if f >= 499 then frame = 4 end
    self:at("makina", x + dx, y, { frame = frame })
end

function AIRewardFlow:draw_ai_don(t, x, y)
    local f = t % 250
    local dy = 0
    if f >= 88 and f < 115 then
        dy = f < 101 and lerp(-10, -132, ramp(f, 88, 12)) or lerp(-122, 0, ramp(f, 101, 13))
    end
    self:at("ai_don", x, y + dy)
end

function AIRewardFlow:draw_burst(cx, cy, t)
    if t < 0 then return end
    local pulse = 0.725 + 0.362 * math.abs(((t + 60) % 120) / 60 - 1)
    self:put("burst_glow", cx, cy, { s = pulse, fade = ramp(t, 0, 12) * (t > 13 and 0.5 + 0.5 * math.abs(((t - 13) % 120) / 60 - 1) or 1) })
    self:put("burst_circle", cx, cy, { s = lerp(2, 1, math.abs(((t - 12) % 120) / 60 - 1)), fade = t >= 12 and 1 or 0 })
    if t >= 7 then
        self:put("burst_rays", cx, cy, { s = 0.85, rot = t * 3, add = true, fade = 0.3 * ramp(t, 7, 6) })
        self:put("burst_rays_thin", cx, cy, { s = 0.85, rot = -t * 2, fade = 0.5 * ramp(t, 7, 6) })
    end
    for k, key in ipairs({ "triangle_yellow_small", "triangle_yellow", "triangle_purple", "triangle_pink", "triangle_white" }) do
        local u = ((t - 11 + k * 3) % 121) / 34
        if u < 1 then
            local a = k * 72 * math.pi / 180
            self:put(key, cx + math.cos(a) * 170 * u, cy + math.sin(a) * 170 * u, { rot = t * 8, fade = 1 - u })
        end
    end
    local s = (t % 120) / 60
    if s < 1 then self:put("sparkle", cx + 100, cy - 90, { fade = math.sin(math.pi * s) }) end
end

function AIRewardFlow:draw_don_hint(x, y, t)
    local a = ramp(t, 0, 15)
    local c = t % 120
    local pulse = a * (c < 60 and 1 - math.abs(c / 30 - 1) or 0)
    self:at("don_hint_glow", x + 47, y, { fade = a * 0.4 })
    self:at("hint_glow", x, y - 10, { fade = pulse })
    self:at("hint_end", x + 87, y + 12, { fade = a })
    self:at("drum", x + 16, y + 6, { fade = a })
    self:at("drum_center", x + 16, y + 6, { fade = pulse })
end

function AIRewardFlow:draw_katsu_hint(t)
    local a = ramp(t, 0, 15)
    local c = t % 120
    local rim = a * (c < 60 and 1 - math.abs(c / 30 - 1) or 0)
    local arrow = c < 60 and a * (1 - c / 60) or 0
    self:at("hint_page", 865, 611, { fade = a })
    self:put("katsu_drum", 733, 620, { fade = a })
    self:put("katsu_rim", 721, 620, { fade = rim })
    self:put("katsu_rim", 745, 620, { fade = rim, mirror = "horizontal" })
    self:put("katsu_arrow", 760 + 7 * (c < 60 and c / 60 or 1), 620, { fade = arrow, mirror = "horizontal" })
    self:put("katsu_arrow", 706 - 7 * (c < 60 and c / 60 or 1), 620, { fade = arrow })
end

function AIRewardFlow:draw_rank_number(rank, t, shine)
    local cx, cy = 742, 218
    if rank >= RANK_MAX then
        self:put("rank_ten_plus_glow", 787, 211, { fade = 0.5 + 0.5 * math.abs((t % 40) / 20 - 1) })
        self:put("rank_ten_plus", 787, 211)
        return
    end
    local str = tostring(rank)
    local x = cx - (#str - 1) * 50
    for i = 1, #str do
        local d = str:byte(i) - 48
        if shine and t < 20 then self:put("rank_digit_glow", x, cy, { frame = d, fade = 1 - t / 20 }) end
        self:put("rank_digit", x, cy, { frame = d })
        x = x + 100
    end
end

function AIRewardFlow:draw_next_rank(rank, a)
    if rank >= RANK_MAX then
        self:put("strongest_glow", 640, 438, { fade = a * (0.5 + 0.5 * math.abs((self.f % 60) / 30 - 1)) })
        self:put("strongest_panel", 640, 438, { fade = a })
        self:put("strongest_text", 640, 438, { fade = a })
        return
    end
    self:at("next_panel", 300, 291.2, { fade = a })
    if rank >= ASSIGNED_RANK then
        self:at("next_max_text", 364, 320.2, { fade = a })
        self:at("point_text", 795, 320.2, { fade = a })
        self:digits("digits_next", self.p.next_rank_after_tokens - self.p.tokens_after, 724, 352, 42, { fade = a })
        self:at("assigned_condition", 351.3, 378.3, { fade = a })
    else
        self:at("next_rank_text", 364, 320.2, { fade = a })
        self:digits("digits_next", self.p.next_rank_after_tokens - self.p.tokens_after, 701, 352, 50, { fade = a })
        self:at("condition_back", 351.3, 378.3, { frame = CONDITION_BACK[rank], fade = a })
        self:at("condition_strip", 353.3, 395.3, { frame = rank, fade = a })
    end
    self:at("condition_note", 312.3, 494.3, { fade = a })
end

function AIRewardFlow:draw_rankup()
    local p, t = self.p, self.f
    self:draw_window(t)
    local shine_at = INIT_WAIT + RANK_COUNT_WAIT
    local after = t >= shine_at
    self:draw_burst(742, 211, t - shine_at)
    self:at("rank_label", 379, 160)
    self:draw_rank_number(after and p.rank_after or p.rank_before, t - shine_at, after)
    if self.phase == "title" or self.phase == "next" then
        local since = t - self.phase_at
        local a = self.phase == "title" and ramp(since, 0, PANEL_FADE) or 1 - ramp(since, 0, PANEL_FADE)
        if a > 0 then
            self:at("title_box", 316, 320, { fade = a })
            self:at("rank_title", 316, 396, { frame = p.rank_after - 1, fade = a })
        end
        if self.phase == "title" and since >= PANEL_FADE then self:draw_katsu_hint(since - PANEL_FADE) end
    end
    if self.phase == "next" then
        local since = t - self.phase_at
        self:draw_next_rank(p.rank_after, ramp(since, PANEL_FADE, PANEL_FADE))
        if since >= 2 * PANEL_FADE then self:draw_don_hint(734, 582, since - 2 * PANEL_FADE) end
    end
    self:draw_makina(t, 952.3, 249.9)
    self:draw_ai_don(t, 33.4, 464)
end

function AIRewardFlow:draw_reward()
    local p, t = self.p, self.f
    self:draw_window(t)
    self:draw_burst(617, 204, t - 12)
    if t >= 16 then
        self:at("total_text", 339, 181)
        self:at("win_text", 750, 171)
        self:at("achieved_text", 827, 181)
        if p.wins_after >= 1000 then
            self:digits("wins_four", p.wins_after, 612, 215, 70)
        else
            self:digits("wins_three", p.wins_after, 612, 215, 97)
        end
    end
    local panel_at = INIT_WAIT + REWARD_WAIT
    if t >= panel_at then
        local a = ramp(t, panel_at, PANEL_FADE)
        self:at("reward_box", 288, 266, { fade = a })
        if self.reward_name then
            local fade = ramp(t, panel_at, 10)
            self.reward_kind:draw({ x = (640 - self.reward_kind.width / (2 * S)) * S, y = 340 * S, fade = fade })
            self.reward_name:draw({ x = (640 - self.reward_name.width / (2 * S)) * S, y = 375 * S, fade = fade })
        end
    end
    local next_at = panel_at + NEXT_WAIT
    if t >= next_at then
        local a = ramp(t, next_at, PANEL_FADE)
        if p.all_rewards or p.next_reward_wins < 0 then
            self:at("all_rewards_bar", 299, 441.25, { fade = a })
        else
            self:at("next_reward_bar", 301, 450.2, { fade = a })
            if self.next_name then
                self.next_name:draw({ x = (610 - self.next_name.width / (2 * S)) * S, y = (490 - self.next_name.height / (2 * S)) * S, fade = a })
            end
            self:at("win_text_small", 933, 468.2, { fade = a })
            self:digits("digits_need", p.next_reward_wins - p.wins_after, 905, 490, 32, { fade = a }, "digits_need_glow")
        end
    end
    if self.phase == "wait" then self:draw_don_hint(745, 587, t - self.phase_at) end
    self:draw_makina(t, 952.3, 249.9)
    self:draw_ai_don(t, 45, 465.5)
end

function AIRewardFlow:draw_goal_rank(x, y, a)
    local p = self.p
    self:at("goal_panel", x, y, { fade = a })
    self:at("goal_rank_text", x, y + 62, { fade = a })
    self:at("rank_title_small", x + 212, y + 152, { frame = p.rank_after, fade = a })
    self:digits("digits_goal", p.next_rank_after_tokens - p.tokens_after, x + 432, y + 103, 50, { fade = a })
end

function AIRewardFlow:draw_goal_wins(x, y, a)
    local p = self.p
    self:at("goal_panel", x, y, { fade = a })
    self:at("goal_wins_text", x, y + 62, { fade = a })
    if self.next_name then
        self.next_name:draw({ x = (x + 376 - self.next_name.width / (2 * S)) * S, y = (y + 170 - self.next_name.height / (2 * S)) * S, fade = a })
    end
    self:digits("digits_goal", p.next_reward_wins - p.wins_after, x + 539, y + 103, 50, { fade = a })
end

function AIRewardFlow:draw_remind()
    local p, t = self.p, self.f
    self:at("next_goal_text", 8, 18)
    local a = ramp(t, INIT_WAIT, PANEL_FADE)
    local has_rank = p.rank_after < RANK_MAX
    local has_wins = p.next_reward_wins >= 0
    if has_rank and has_wins then
        self:draw_goal_rank(198, 104, a)
        self:draw_goal_wins(292, 342, a)
    elseif has_rank then
        self:draw_goal_rank(264, 224, a)
    else
        self:draw_goal_wins(264, 224, a)
    end
    if self.phase == "wait" then
        local h = t - self.phase_at
        local fade = ramp(h, 0, 15)
        self:at("remind_hint_end", 1093.1, 31.1, { fade = fade })
        self:at("remind_drum", 1036, 26, { fade = fade })
        local c = h % 120
        self:at("remind_drum_center", 1036, 26, { fade = fade * (c < 60 and 1 - math.abs(c / 30 - 1) or 0) })
    end
    self:draw_makina(t, 952.3, 249.9)
    self:draw_ai_don(t, 45, 473.1)
end

function AIRewardFlow:draw()
    if self.stage == "rankup" then self:draw_rankup()
    elseif self.stage == "reward" then self:draw_reward()
    elseif self.stage == "remind" then self:draw_remind() end
end
