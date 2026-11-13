local SKIN_S = tex.get_screen_scale()
local SKIN = {
    result_score_margin = { x = 23 * SKIN_S },
}
ResultPlayer = {}
ResultPlayer.__index = ResultPlayer

function ResultPlayer.new(player_num, is_2p, has_2p,
                          gauge_length, difficulty, selected_difficulty,
                          crown_type, score_diff, score_method,
                          mod_display, mod_inverse, mod_random, mod_speed)
    local self = setmetatable({}, ResultPlayer)

    self.player_num          = player_num
    local timing = tex.timing_offset(player_num)
    if timing then
        self.timing_text = text.create_raw_text(timing, 20, {255, 255, 255, 255}, {0, 0, 0, 255}, false, 3.0)
    end
    self.is_2p               = is_2p
    self.has_2p              = has_2p
    self.gauge_length        = gauge_length
    self.difficulty          = difficulty
    self.selected_difficulty = selected_difficulty
    self.crown_type          = crown_type
    self.score_diff          = score_diff
    self.score_method        = score_method
    self.mod_display         = mod_display
    self.mod_inverse         = mod_inverse
    self.mod_random          = mod_random
    self.mod_speed           = mod_speed

    local ART   = { [0] = 0, [1] = 1, [2] = 1, [3] = 2 }
    local NORMA = { [0] = 6000, [1] = 7000, [2] = 7000, [3] = 8000 }
    local d     = math.min(math.max(difficulty, 0), 3)
    self.art_index = ART[d]
    if gauge_length == 87 then
        self.gauge_state = 2
    elseif gauge_length / 87.0 * 10000.0 >= NORMA[d] - 0.5 then
        self.gauge_state = 1
    else
        self.gauge_state = 0
    end

    if self.art_index >= 2 then
        self.diff_str = "_hard"
    elseif self.art_index >= 1 then
        self.diff_str = "_normal"
    else
        self.diff_str = "_easy"
    end

    local p                           = tostring(player_num) .. "p"
    self.player_str                   = p

    self.score                        = ""
    self.good                         = ""
    self.ok                           = ""
    self.bad                          = ""
    self.max_combo                    = ""
    self.total_drumroll               = ""
    self.fade_in_finished_flag        = false

    self.gauge_started                = false
    self.score_delay                  = nil
    self.fade_in_started              = false
    -- Z-DON AI battle: the cabinet's AI result counts every row up at the same time (footage uWAL-I14RFU / Tl7g8XXXvAM)
    self.count_up_parallel            = require("global.ai_battle").active()
    -- Green AI result timeline (round 19, 60 fps feed Tl7g8XXXvAM, frames from the end of black): skin key
    -- zdon_ai_result_tl { x = gauge fade-in delay ms, y = crown lead ms, width = score row delay ms }; absent = normal
    local tl = self.count_up_parallel and tex.get_skin_config("zdon_ai_result_tl") or nil
    self.ai_tl = (tl and (tl.x or 0) + (tl.y or 0) + (tl.width or 0) > 0) and tl or nil
    if self.ai_tl then self.count_up_row_delay_ms = { score = self.ai_tl.width or 0 } end
    self.rainbow_start_ms             = -1.0
    self.rainbow_frac                 = 0.0

    -- Sub-objects
    self.bottom_chars                 = BottomCharacters.new()
    self.crown_obj                    = nil
    self.crown_msg_obj                = nil
    self.basin_obj                    = nil
    self.high_score_obj               = nil

    -- Animations owned by ResultPlayer
    self.fade_in_bottom               = tex.get_animation(1, "result")
    self.gauge_fade_in                = tex.get_animation(17, "result")
    self.tamashii_fire                = tex.get_animation(20, "result")

    self.t_grad_clear                 = tex.get_texture("result/background/gradient_clear")
    self.t_grad_fail                  = tex.get_texture("result/background/gradient_fail")

    self.t_overlay                    = tex.get_texture("result/score/overlay")
    self.t_difficulty                 = tex.get_texture("result/score/difficulty")
    self.t_judge_good                 = tex.get_texture("result/score/judge_good")
    self.t_judge_ok                   = tex.get_texture("result/score/judge_ok")
    self.t_judge_bad                  = tex.get_texture("result/score/judge_bad")
    self.t_judge_num                  = tex.get_texture("result/score/judge_num")
    self.t_max_combo                  = tex.get_texture("result/score/max_combo")
    self.t_drumroll                   = tex.get_texture("result/score/drumroll")
    self.t_score_lbl                  = tex.get_texture("result/score/score")
    self.t_score_shinuchi_lbl         = tex.get_texture("result/score/score_shinuchi")
    self.t_score_num                  = tex.get_texture("result/score/score_num")

    self.t_mod_doron                  = tex.get_texture("result/score/mod_doron")
    self.t_mod_abekobe                = tex.get_texture("result/score/mod_abekobe")
    self.t_mod_kimagure               = tex.get_texture("result/score/mod_kimagure")
    self.t_mod_detarame               = tex.get_texture("result/score/mod_detarame")
    self.t_mod_yonbai                 = tex.get_texture("result/score/mod_yonbai")
    self.t_mod_sanbai                 = tex.get_texture("result/score/mod_sanbai")
    self.t_mod_baisaku                = tex.get_texture("result/score/mod_baisaku")

    self.gauge = Gauge.new(is_2p, false, self.diff_str,
        { screen = "result", player_str = p, scale = 10.0 / 11.0, footer = true, no_border = true })

    self.sc_score_info_margin         = 22 * tex.get_screen_scale()
    local rs                          = SKIN.result_score_margin
    self.sc_result_score_margin       = rs and rs.x or 0
    self.sc_result_2p_offset          = -288 * tex.get_screen_scale()

    return self
end

local function voice(self, name)   -- Z-DON AI battle: the AI's half of the result is silent
    if self.is_2p and tex.ai_active and tex.ai_active() then return end
    audio.play_sound(name, "voice")
end

function ResultPlayer:update(current_ms, fade_in_finished,
                             score, good, ok, bad, max_combo, total_drumroll)
    self.fade_in_finished_flag = fade_in_finished
    self.score                 = score
    self.good                  = good
    self.ok                    = ok
    self.bad                   = bad
    self.max_combo             = max_combo
    self.total_drumroll        = total_drumroll

    if fade_in_finished and not self.gauge_started then
        self.gauge_started = true
        self.gauge_base_ms = current_ms
        if not self.ai_tl then
            self.gauge_fade_in:start()
            self.tamashii_fire:start()
        end
        self.bottom_chars:start()
    end
    -- the cabinet shows the gauge 1.7 s after the black (feed frame 103); the count-up / crown keep the old chain
    if self.ai_tl and self.gauge_started and not self.gauge_fade_in.is_started
        and current_ms >= self.gauge_base_ms + (self.ai_tl.x or 0) then
        -- round 20: the feed fades the gauge in over ~6 frames (border darkness 10..90 %), the engine animation is 22
        local gf = tex.get_skin_config("zdon_ai_gauge_fade_ms")
        if gf and (gf.x or 0) > 0 then self.gauge_fade_in.duration = gf.x end
        self.gauge_fade_in:start()
        self.tamashii_fire:start()
    end

    if self.gauge_started then
        if self.gauge_state == 2 then
            if self.rainbow_start_ms < 0 then self.rainbow_start_ms = current_ms end
            self.rainbow_frac = math.fmod((current_ms - self.rainbow_start_ms) / 75.0, 8.0)
        end
        self.tamashii_fire:update(current_ms)
        self.gauge_fade_in:update(current_ms)
        if self.ai_tl then
            if self.score_delay == nil and current_ms >= self.gauge_base_ms + 366 then
                self.score_delay = current_ms + 1883
            end
        elseif self.gauge_fade_in.is_finished and self.score_delay == nil then
            self.score_delay = current_ms + 1883
        end
    end

    if self.score_delay ~= nil and current_ms > self.score_delay and not self.fade_in_started then
        self.fade_in_started = true
        self.fade_in_bottom:start()
    end
    self.fade_in_bottom:update(current_ms)

    if self.fade_in_started then
        self.bottom_chars:update(current_ms, self.gauge_state)
    end

    local chars_done = self.bottom_chars:is_finished()
    if self.ai_tl and self.gauge_started and current_ms >= self.gauge_base_ms + 366 + 1883 - (self.ai_tl.y or 0) then
        chars_done = true   -- the crown comes in on its own clock, not behind the score count-up
    end
    if chars_done then

        if self.ranking and ResultRanking then
            self.ranking_obj = ResultRanking.new(self.ranking, self.selected_difficulty, self.is_2p)
            self.ranking = nil
        end
        if self.gauge_state >= 1 and not self.crown_obj then
            self.crown_obj = ResultCrown.new(self.crown_type, self.is_2p)
            if self.crown_type == 1 or self.crown_type == 2 then
                voice(self, "full_combo_voice_" .. tostring(self.player_num) .. "p")
            end
        elseif self.gauge_state == 0 and not self.crown_msg_obj then
            local frame = (self.gauge_length < 87.0 / 2.0) and 0 or 1
            self.crown_msg_obj = ResultCrownMessage.new(frame, self.is_2p)
            if frame == 0 then
                if ResultBasin then self.basin_obj = ResultBasin.new(self.is_2p) end
                voice(self, "max_fail_voice_" .. tostring(self.player_num) .. "p")
            else
                voice(self, "fail_voice_" .. tostring(self.player_num) .. "p")
            end
        end
    end

    if self.crown_obj then
        self.crown_obj:update(current_ms)
        if self.crown_obj:is_settled() and not self.crown_msg_obj then
            local frame = (self.gauge_state == 2) and 3 or 2
            self.crown_msg_obj = ResultCrownMessage.new(frame, self.is_2p)
            if frame == 2 then
                voice(self, "clear_voice_" .. tostring(self.player_num) .. "p")
            else
                voice(self, "max_clear_voice_" .. tostring(self.player_num) .. "p")
            end
        end
    end

    if self.crown_msg_obj then
        self.crown_msg_obj:update(current_ms)
    end
    if self.ranking_obj then self.ranking_obj:update(current_ms) end
    if self.basin_obj then
        self.basin_obj:update(current_ms)
        self.chara_miss_loop = self.basin_obj.landed   -- read by ResultPlayer::update (C++)
    end

    if not self.high_score_obj and self.score_diff > 0 and self.good ~= "" then
        self.high_score_obj = HighScoreIndicator.new(self.score_diff, self.is_2p)
    end
    if self.high_score_obj then
        self.high_score_obj:update(current_ms)
    end
end

function ResultPlayer:draw()
    -- Z-DON AI battle: the AI half is Green's AI result (sections, emblem, rank), not a board
    if self.is_2p and require("global.ai_battle").active() then
        require("global.ai_battle").draw_result()
        return
    end
    local p_idx = self.is_2p and 1 or 0

    if self.fade_in_started and not self.hide_stage then
        local fade_val = math.min(0.4, self.fade_in_bottom.attribute)
        if self.is_2p then
            if self.gauge_state == 0 then
                if self.t_grad_fail then tex.draw_texture(self.t_grad_fail, { fade = fade_val }) end
            else
                if self.t_grad_clear then tex.draw_texture(self.t_grad_clear, { fade = fade_val }) end
            end
        else
            local y = (self.sc_result_2p_offset ~= 0) and (self.has_2p and 1.0 or 0.0) or 0.0
            if self.gauge_state == 0 then
                -- Green AI battle: a lost battle's result keeps the cyan page (direct feed uWAL-I14RFU 13 s), no grey fail gradient
                if self.t_grad_fail and not require("global.ai_battle").active() then tex.draw_texture(self.t_grad_fail, { y = y, fade = fade_val }) end
            else
                if self.t_grad_clear then tex.draw_texture(self.t_grad_clear, { y = y, fade = fade_val }) end
            end
        end
    end

    if self.t_overlay then tex.draw_texture(self.t_overlay, { color = { 255, 255, 255, 192 }, index = p_idx }) end
    if self.t_difficulty then tex.draw_texture(self.t_difficulty, { frame = self.selected_difficulty, index = p_idx }) end

    if not self.has_2p and not self.hide_stage then self.bottom_chars:draw() end

    if self.t_judge_good then tex.draw_texture(self.t_judge_good, { index = p_idx }) end
    if self.t_judge_ok then tex.draw_texture(self.t_judge_ok, { index = p_idx }) end
    if self.t_judge_bad then tex.draw_texture(self.t_judge_bad, { index = p_idx }) end
    if self.t_max_combo then tex.draw_texture(self.t_max_combo, { index = p_idx }) end
    if self.t_drumroll then tex.draw_texture(self.t_drumroll, { index = p_idx }) end

    self:draw_score_info()
    self:draw_total_score()

    if self.crown_obj then self.crown_obj:draw() end
    -- the cabinet's AI battle result has no clear / fail speech bubble over the Don (Tl7g8XXXvAM 4:38-4:52)
    if self.crown_msg_obj and not require("global.ai_battle").active() then self.crown_msg_obj:draw() end

    self:draw_modifiers()

    if self.high_score_obj then self.high_score_obj:draw() end
end

function ResultPlayer:draw_front()
    if self.is_2p and require("global.ai_battle").active() then return end   -- Z-DON AI battle
    if self.ranking_obj then self.ranking_obj:draw() end
    if self.basin_obj then self.basin_obj:draw() end
end

-- Song number, title and subtitle across the top of the screen. info = { title, subtitle, number };
-- subtitle is "" when the chart hides it.
local WHITE, BLACK, RED = { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, { 255, 0, 0, 255 }

local function cached_text(self, slot, str, size, color, thickness)
    local key = str .. "\0" .. size
    local entry = self._song_info_texts[slot]
    if not entry or entry.key ~= key then
        entry = { key = key, text = text.create_raw_text(str, size, WHITE, color, false, thickness) }
        self._song_info_texts[slot] = entry
    end
    return entry.text
end

function ResultPlayer:draw_song_info(info)
    self._song_info_texts = self._song_info_texts or {}
    local s = tex.get_screen_scale()
    local NUM_X, NUM_Y = 232 * s, 15 * s
    local TITLE_X, TITLE_Y, TITLE_W, TITLE_FONT = 1252 * s, 35 * s, 0, math.floor(40 * s)
    local SUB_Y, SUB_FONT = 73 * s, math.floor(22 * s)

    -- "Song {0}": outlined red on the last song of a limited session
    local num_cfg = tex.get_skin_config("song_num") or { font_size = 0, outline = -1 }
    local fmt = tex.skin_text("song_num")
    if fmt == "" then fmt = "{0}" end
    local limit = tex.song_limit()
    -- strict audit: the AI battle's result counted the battle itself twice (direct feed Tl7g8XXXvAM: first battle reads 1)
    local number = info.number
    if tex.ai_active and tex.ai_active() and number > 1 and tex.get_skin_config("zdon_green_strict") then number = number - 1 end
    local fs = num_cfg.font_size
    if tex.ai_active and tex.ai_active() and tex.get_skin_config("zdon_green_strict") then
        -- strict green8: feed t=288 "1曲目" is 108 px wide from x 250 (normal result: 98 px from 240)
        NUM_X = 242 * s
        NUM_Y = 8 * s   -- round 14: edge match vs feed f190: ours was 7 px low
        if fs > 0 then fs = fs * 1.1 end
    end
    local num = cached_text(self, "number", fmt:gsub("{0}", tostring(number)), fs,
                            (limit > 0 and limit == number) and RED or BLACK,
                            num_cfg.outline >= 0 and num_cfg.outline or 5.0)
    num:draw({ x = NUM_X, y = NUM_Y, fade = 1.0 })

    local title = cached_text(self, "title", info.title, TITLE_FONT, BLACK, 5)
    local title_x = TITLE_W > 0 and TITLE_X + (TITLE_W - title.width) / 2 or TITLE_X - title.width
    title:draw({ x = title_x, y = TITLE_Y - title.height / 2, fade = 1.0 })
    if info.subtitle ~= "" then
        local sub = cached_text(self, "subtitle", info.subtitle, SUB_FONT, BLACK, 5)
        local sub_x = TITLE_W > 0 and TITLE_X + (TITLE_W - sub.width) / 2 or TITLE_X - sub.width
        sub:draw({ x = sub_x, y = SUB_Y - sub.height / 2, fade = 1.0 })
    end
end

function ResultPlayer:draw_gauge()
    if self.is_2p and require("global.ai_battle").active() then return end   -- Z-DON AI battle
    if not self.gauge_started then return end
    local clear_points = ({ 6000, 7000, 8000 })[self.art_index + 1]   -- easy / normal+hard / oni norma
    -- gauge_length is 0-87; the epsilon keeps a whole cell from flooring one short
    local points = self.gauge_length / 87.0 * 10000.0 + 1e-6
    -- Z-DON AI result (Green strict audit, direct feed Tl7g8XXXvAM): the cabinet's AI result gauge is 0.900x and 3 px
    -- left of the normal result's 10/11x (clear notch +8 / left edge +3 before). Green skin key zdon_ai_result_gauge
    -- x = dx, width = scale; Nijiiro sets width 0
    local ag = tex.get_skin_config("zdon_ai_result_gauge")
    local ai = ag and (ag.width or 0) > 0 and require("global.ai_battle").active()
    if ai then
        local gc = tex.get_skin_config("zdon_ai_result_gauge_clear") or {}
        local ss = tex.get_screen_scale()
        self.gauge.scale, self.gauge.dx = ag.width, (ag.x or 0) * ss
        -- clear notch (cp_adj, in cells) + label slide left by x px; the soul sits y px from the normal result's
        self.gauge.dx_clear, self.gauge.dx_soul = (gc.x or 0) * ss, (gc.y or 0) * ss
        self.gauge.cp_adj = (gc.x or 0) * ss / (8 * ag.width)
    end
    self.gauge:draw_result(self.is_2p and 1 or 0, self.gauge_fade_in.attribute, points, 10000, clear_points,
        self.gauge_state >= 1, self.gauge_state == 2, self.rainbow_frac, math.floor(self.tamashii_fire.attribute))
    if ai then self.gauge.scale, self.gauge.dx, self.gauge.cp_adj = 10.0 / 11.0, nil, nil end
end

function ResultPlayer:draw_score_info()
    local scores = { self.good, self.ok, self.bad, self.max_combo, self.total_drumroll }
    local p_idx  = self.is_2p and 1 or 0
    for j, s in ipairs(scores) do
        if s ~= "" and self.t_judge_num then
            local n   = math.floor(tonumber(s) or 0)
            local str = tostring(n)
            for i = 1, #str do
                local d = tonumber(string.sub(str, #str - i + 1, #str - i + 1)) or 0
                tex.draw_texture(self.t_judge_num, {
                    frame = d,
                    x     = -((i - 1) * self.sc_score_info_margin),
                    index = (j - 1) + p_idx * 5,
                })
            end
        end
    end
end

function ResultPlayer:draw_total_score()
    if not self.fade_in_finished_flag then return end
    local p_idx = self.is_2p and 1 or 0
    if self.timing_text then
        local info = tex.get_texture_info("score", "score_shinuchi_" .. tex.language())
                  or tex.get_texture_info("score", "score_shinuchi_ja")
        if info then
            self.timing_text:draw({ x = info.x[p_idx + 1], y = info.y[p_idx + 1] })
        end
    end
    if self.score_method then
        if self.t_score_shinuchi_lbl then tex.draw_texture(self.t_score_shinuchi_lbl, { index = p_idx }) end
    else
        if self.t_score_lbl then tex.draw_texture(self.t_score_lbl, { index = p_idx }) end
    end
    if self.score ~= "" and self.t_score_num then
        local n   = math.floor(tonumber(self.score) or 0)
        local str = tostring(n)
        for i = 1, #str do
            local d = tonumber(string.sub(str, #str - i + 1, #str - i + 1)) or 0
            tex.draw_texture(self.t_score_num, {
                frame = d,
                x     = -((i - 1) * self.sc_result_score_margin),
                index = p_idx,
            })
        end
    end
end

function ResultPlayer:draw_modifiers()
    local p_idx = self.is_2p and 1 or 0
    if self.mod_display and self.t_mod_doron then tex.draw_texture(self.t_mod_doron, { index = p_idx }) end
    if self.mod_inverse and self.t_mod_abekobe then tex.draw_texture(self.t_mod_abekobe, { index = p_idx }) end
    if self.mod_random == 1 and self.t_mod_kimagure then
        tex.draw_texture(self.t_mod_kimagure, { index = p_idx })
    elseif self.mod_random == 2 and self.t_mod_detarame then
        tex.draw_texture(self.t_mod_detarame, { index = p_idx })
    end
    if self.mod_speed >= 40 and self.t_mod_yonbai then
        tex.draw_texture(self.t_mod_yonbai, { index = p_idx })
    elseif self.mod_speed >= 30 and self.t_mod_sanbai then
        tex.draw_texture(self.t_mod_sanbai, { index = p_idx })
    elseif self.mod_speed > 10 and self.t_mod_baisaku then
        tex.draw_texture(self.t_mod_baisaku, { index = p_idx })
    end
end

-- Z-DON AI battle: the AI half has no character or nameplate (the engine asks for their place)
function ResultPlayer:chara_pos()
    if self.is_2p and require("global.ai_battle").active() then return { -4000, -4000, 0.01 } end
    -- strict round 12 (edge / colour-blob measurement on feed f190, state-matched costume 27 + puchi 77): the feed's Don is
    -- 1.15x ours (green face 90x98 vs 77x86 px) with its face centre at (173, 225) (ours (188, 210)); the puchi is 1.17x and
    -- its centre (51, 225) (engine default offset (-90, -120) from the Don origin)
    if not self.is_2p and require("global.ai_battle").active() and tex.get_skin_config("zdon_green_strict") then
        local s = tex.get_screen_scale()
        return { 129 * s, 328 * s, 1.15, 12, 17, 1.17 }
    end
    return nil
end

function ResultPlayer:nameplate_pos()
    if self.is_2p and require("global.ai_battle").active() then return { -4000, -4000, 0 } end
    -- strict green8: the AI result's 1P plate sits at (258, 91) in the direct feed Tl7g8XXXvAM t=288 (normal result 265, 80)
    if not self.is_2p and require("global.ai_battle").active() and tex.get_skin_config("zdon_green_strict") then
        local s = tex.get_screen_scale()
        return { 258 * s, 91 * s, 1 }
    end
    return nil
end
