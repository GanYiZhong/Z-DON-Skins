-- YataiDONSimpleStyle v2: gameplay background = the festival stage (art bible 2.4).
-- Replaces Nijiiro's Scripts/background system (donbg / bg_normal / fever / dancers / footer /
-- renda / chibi / collab packs): none of its art folders are ever loaded. Only
-- Graphics/background/ss_stage (ss/v2_stage.py) and the global mascot / burst textures are drawn.
--
-- Kept engine interface (objects/game/background.cpp): new, update, handle_good/ok/bad,
-- handle_drumroll, handle_balloon, handle_kusudama, handle_balloon_end, handle_gauge, handle_gogo,
-- handle_miss_streak, handle_song_end, handle_score, handle_ending, draw_ending, handle_dan,
-- handle_skip, draw_back, draw_gauge, draw_fore, destroy.
-- HUD-side hooks stay wired to Nijiiro's modules (they draw game/ textures, the game agent's):
-- enso_skip (game/skip), rank_badge + ending (game/ending_anim), dan_info (game/dan_info) and the
-- dan gauge redraw (_G.g_dan_gauge_redraw, set by the gauge script).
--
-- Layout (logical 1920x1080): sky everywhere; HUD lane band 276-540 (2P: 276-870).
--   1P GAME: lower half = stage (floor 948), Momo (role scene, k=9) drums at the taiko, Hoshi (role
--     menu, k=6) + bubble (UI.bubble: run-time text in the player's language). GOGO: a flame band behind the cast (on the horizon, between the posts).
--   2P: bottom band = the same stage further away (deck on ground 1047, posts, lantern rope 873):
--     Momo (menu) at the 1P drum, Hoshi (menu) at the 2P drum.
--   DAN: the same band with one drum: Hoshi (menu) + bubble left, Momo (menu) drums.
--   GAME_PRACTICE / AI_GAME: bare (sky + clouds); the practice HUD (v2_game) owns the screen.
-- Motion: clouds drift 1U per 500 ms; mascots per the core Mascot; GOGO flames toggle 200 ms; during
-- GOGO the drummers keep drumming on every half beat.
-- stagelux (10-29): the sky is a stepped ordered-dither gradient (S.SKY segments: solid bands + UI.wipe
-- checker rows) in 4 states: day / clear (warm horizon) / dusk (GOGO) / fail (pale). A state change
-- sweeps in band by band from the top, each band through wipe levels 1-2-3-solid (50 ms each, bands
-- 40 ms apart); clouds / scenery switch their variant when the sweep reaches them. Two cloud layers
-- step exactly 1 physical px every 100 ms (near) / 200 ms (far). The distant town on the horizon lights
-- its lanterns with the soul gauge (Nijiiro's dancer-count rule: progress / clear line, all at clear)
-- and its windows at dusk. Fireworks (rise 3 + burst 8 frames, 100 ms each, frame swaps only): one
-- every 450 ms during GOGO, one every 1500 ms at a full (rainbow) gauge, a salvo of 5 at a cleared end.

local UI = require("global.ss_ui")
local S = require("background/ss_stage_data")
local EnsoSkip = require("background/bg_objects/enso_skip")
local Ending = require("background/bg_objects/ending")
local RankBadge = require("background/bg_objects/rank_badge")
local DanInfo = require("background/bg_objects/dan_info")

local P = UI.P
local U = UI.U
local SUB = "ss_stage"
local BUBBLE_MS = 2400

Background = {}
Background.__index = Background

local function T(self, key)
    local t = self.tx[key]
    if t == nil then
        t = tex.get_texture("background/" .. SUB .. "/" .. key) or false
        self.tx[key] = t
    end
    return t or nil
end

local function draw_at(t, x, y, frame)
    if t then tex.draw_texture(t, { x = x, y = y, frame = frame or 0 }) end
end

local function new_player()
    return { combo = 0, clear = false, gogo = false, streak = false, ending = nil,
             last_roll = -1e9, clear_ms = nil, progress = 0, clear_line = nil, rainbow = false }
end

-- stagelux timing (ms): sky sweep, fireworks
local SWEEP_MS = 40
local FW_GOGO_MS, FW_MAX_MS, FW_SALVO, FW_SALVO_MS = 450, 1500, 5, 250
local FW_LIFE = 11                       -- frames: rise 3 + burst 8
local CLEAR_DEFAULT = 69 / 87            -- Nijiiro: hard / oni clear line (gauge max 87)
local CLEAR_STARTS = { 52, 60, 69 }

function Background.new(player_num, bpm, scene_preset)
    local self = setmetatable({}, Background)
    UI.reset()
    tex.load_folder("background", SUB)
    self.tx = {}
    self.player_num = player_num
    self.is_2p = (player_num == 3)
    self.is_dan = (scene_preset == "DAN")
    self.screen = tex.current_screen and tex.current_screen() or "GAME"
    -- AI battle: the engine draws a second lane in the lower half; practice: v2_game's practice HUD
    -- owns the screen. Both keep only the sky + clouds.
    self.bare = (self.screen == "AI_GAME" or self.screen == "GAME_PRACTICE")
    self.bpm = (bpm and bpm > 0) and bpm or 120
    self.ms = 0
    self.p = { [1] = new_player(), [2] = new_player() }
    self.layout = self.is_2p and "2p" or (self.is_dan and "dan" or "1p")
    -- mascot k by role (SCREEN_GUIDE_V2 2): 1P Momo scene / Hoshi menu; 2P and dan band both menu
    if self.layout == "1p" then
        self.momo = UI.Mascot.new({ char = "momo", role = "scene" })
        self.hoshi = UI.Mascot.new({ char = "hoshi", role = "menu", beat = false })
        self.hoshi:react("turn", -1)          -- faces Momo (left)
    else
        self.momo = UI.Mascot.new({ char = "momo", role = "menu" })
        self.hoshi = UI.Mascot.new({ char = self.is_2p and require("global.ss_ai").p2_char() or "hoshi",
                                     role = "menu", beat = self.is_2p })
        if not self.is_2p then self.hoshi:react("turn", 1) end   -- dan: stands left of Momo, faces her
    end
    self.gogo_beat = {}
    self.talk = (self.layout ~= "2p") and not self.bare
    self.say_key, self.say_until, self.say_prio = nil, -1, 0
    self.pending_start = self.talk
    self.dan_song = nil
    self.dan_failed = false
    self.burst_at = nil
    -- stagelux
    self.sky_key = self.layout == "1p" and "1p" or "2p"
    self.sky_state, self.sky_prev, self.sky_t = "day", nil, 0
    self.fw = {}
    self.fw_n, self.fw_next = 0, nil

    self.enso_skip = EnsoSkip.new()
    _G.g_active_enso_skip = self.enso_skip
    if self.is_dan then self.dan_info = DanInfo.new() end
    return self
end

-- ---------------------------------------------------------------- Hoshi's lines
-- prio: song end 5 > norma / gogo 4 > combo 3 > miss 2 > roll / balloon / start 1
function Background:say(state, prio)
    if not self.talk then return end
    local keys = S.LINES[state]
    if not keys then return end
    if self.ms < self.say_until and prio < self.say_prio then return end
    self.say_key = keys[math.random(1, #keys)]
    self.say_until = self.ms + BUBBLE_MS
    self.say_prio = prio
end

local function combo_state(n)
    for _, s in ipairs(S.COMBO_STEPS) do
        if n == s then return "combo_" .. s end
    end
    if n > S.COMBO_STEPS[#S.COMBO_STEPS] and n % 100 == 0 then return "combo_many" end
    return nil
end

-- the drummer of a player: 1P Momo; in 2P the 2P side is Hoshi's
function Background:drummer(pn)
    if self.is_2p and pn == 2 then return self.hoshi end
    return self.momo
end

function Background:hit(pn)
    local p = self.p[pn] or self.p[1]
    local m = self:drummer(pn)
    if p.ending then return end
    -- a cheer (combo milestone) is not cut short by the next hits
    if m.flash_expr == "cheer" and self.ms < m.flash_until then return end
    m:react("hit")
end

function Background:good(pn)
    local p = self.p[pn] or self.p[1]
    p.combo = p.combo + 1
    local st = combo_state(p.combo)
    if st then
        self:drummer(pn):react("combo")
        if self.talk then
            self.hoshi:react("combo")
            self:say(st, 3)
        elseif self.is_2p then
            -- 2P: the other character cheers along
            local other = (pn == 2) and self.momo or self.hoshi
            if other.flash_expr ~= "cheer" or self.ms >= other.flash_until then other:react("combo") end
        end
    else
        self:hit(pn)
    end
end

function Background:handle_good(pn) self:good(pn) end
function Background:handle_ok(pn) self:good(pn) end

function Background:handle_bad(pn)
    local p = self.p[pn] or self.p[1]
    p.combo = 0
end

function Background:handle_drumroll(pn)
    local p = self.p[pn] or self.p[1]
    self:hit(pn)
    if self.ms - p.last_roll > 1500 then self:say("roll", 1) end
    p.last_roll = self.ms
end

function Background:handle_balloon(pn, remaining)
    local p = self.p[pn] or self.p[1]
    self:hit(pn)
    if self.ms - p.last_roll > 1500 then self:say("balloon", 1) end
    p.last_roll = self.ms
end

function Background:handle_kusudama(pn) self:handle_balloon(pn) end
function Background:handle_balloon_end(pn) end

function Background:handle_miss_streak(pn, on)
    local p = self.p[pn] or self.p[1]
    p.streak = on and true or false
    if on then
        self:drummer(pn):react("miss")
        if self.talk then
            self.hoshi:flash("sad", 800)
            self:say("miss", 2)
        end
    end
end

function Background:handle_gogo(pn, on)
    local p = self.p[pn] or self.p[1]
    if on and not p.gogo then
        if self.talk then
            self.hoshi:flash("gogo", 800)
            self:say("gogo", 4)
        end
    end
    p.gogo = on and true or false
end

function Background:handle_gauge(pn, progress, is_clear, is_rainbow, clear_progress, flash)
    local p = self.p[pn]
    if not p then return end
    p.progress = progress or 0
    p.rainbow = is_rainbow and true or false
    -- the clear line, as Nijiiro's handle_dancer_count finds it
    if clear_progress and clear_progress > 0 then
        p.clear_line = clear_progress
    elseif is_clear and not p.clear_line then
        for _, cs in ipairs(CLEAR_STARTS) do
            if p.progress < cs / 87 + 0.0005 then p.clear_line = cs / 87; break end
        end
        p.clear_line = p.clear_line or CLEAR_DEFAULT
    end
    if is_clear and not p.clear then
        p.clear_ms = self.ms
        if self:lantern_frame(false) == 0 then self.burst_at = self.ms end   -- the lanterns light now
        if self.talk then self:say("norma", 4) end
    end
    p.clear = is_clear and true or false
end

function Background:set_ending(pn, kind)
    local p = self.p[pn] or self.p[1]
    if p.ending then return end
    p.ending = kind
    local m = self:drummer(pn)
    if kind == "fail" then
        m:react("fail")
        if self.talk then self.hoshi:set_mood("sad") end
    else
        m:react("clear")
        if self.talk then self.hoshi:react("turn", 0); self.hoshi:set_mood("clear") end
        self.burst_at = self.ms
        if not self.bare then
            for i = 0, FW_SALVO - 1 do self:launch(self.ms + i * FW_SALVO_MS) end
        end
    end
    if self.talk then self:say(kind, 5) end
end

function Background:handle_song_end(pn, good, ok, bad, total)
    if self.is_dan then return end            -- dan: songs chain; handle_ending decides
    local p = self.p[pn] or self.p[1]
    local kind
    if not p.clear then kind = "fail"
    elseif bad == 0 then kind = (ok == 0) and "donderful" or "full_combo"
    else kind = "clear" end
    self:set_ending(pn, kind)
end

function Background:handle_ending(pn, kind)
    self:set_ending(pn, kind)
    self.endings = self.endings or {}
    if Ending.available(kind) then
        self.endings[pn] = Ending.new(kind, pn, "game")
    end
end

function Background:draw_ending(pn)
    local e = self.endings and self.endings[pn]
    if e then e:draw(tex.get_current_ms()) end
end

function Background:handle_score(pn, score)
    if not RankBadge.available() then return end
    self.rank_badges = self.rank_badges or {}
    local b = self.rank_badges[pn]
    if not b then
        b = RankBadge.new(pn, "game")
        self.rank_badges[pn] = b
    end
    b:set_score(score, tex.get_current_ms())
end

function Background:handle_skip(pn, state)
    self.enso_skip:handle(state)
end

-- 段位道場: exam state every frame (dan_info draws the gauge threshold plate); a new song gets a
-- line, a failed exam makes Momo sad
function Background:handle_dan(pn, state)
    if self.dan_info then self.dan_info:handle(state) end
    if not state then return end
    if self.dan_song and state.song_index and state.song_index ~= self.dan_song then
        self:say("dan_next", 4)
    end
    self.dan_song = state.song_index
    local failed = false
    if state.exams then
        for _, e in ipairs(state.exams) do if e.failed then failed = true end end
    end
    if failed and not self.dan_failed then
        self.momo:set_mood("sad")
        self:say("miss", 2)
    end
    self.dan_failed = failed
end

-- ---------------------------------------------------------------- update / draw
function Background:update(current_ms, bpm)
    self.ms = current_ms
    if bpm and bpm > 0 then self.bpm = bpm end
    self.enso_skip:update(current_ms)
    if self.pending_start then
        self.pending_start = false
        self:say("start", 1)
    end
    -- persistent moods: song end > miss streak. GOGO is no mood for a drummer: it keeps drumming
    -- (drum_l / drum_r on every half beat, plus the hits); a non-drumming Hoshi (1P) shows gogo.
    local half = 30000 / self.bpm
    for pn, m in pairs({ [1] = self.momo, [2] = self.hoshi }) do
        local p = self.p[pn]
        local own = (pn == 1) or self.is_2p
        if own and not p.ending then
            local mood = nil
            if p.streak then mood = "sad"
            elseif pn == 1 and self.dan_failed then mood = "sad" end
            m:set_mood(mood)
            if p.gogo and not p.streak then
                local n = math.floor(current_ms / half)
                if n ~= self.gogo_beat[pn] then
                    self.gogo_beat[pn] = n
                    if m.flash_expr ~= "cheer" or current_ms >= m.flash_until then
                        m.ms = current_ms
                        m:react("hit")
                    end
                end
            end
        end
    end
    if self.talk and not self.p[1].ending and not self.p[1].streak then
        self.hoshi:set_mood(self.p[1].gogo and "gogo" or nil)
    end
    self.momo:update(current_ms, self.bpm, 0)
    self.hoshi:update(current_ms, self.bpm, 0)
    self:update_sky(current_ms)
end

-- ---------------------------------------------------------------- stagelux: sky state, fireworks
function Background:players()
    return self.is_2p and 2 or 1
end

function Background:is_failed()
    return (self.p[1].ending == "fail") and (not self.is_2p or self.p[2].ending == "fail")
end

function Background:target_sky()
    if self:is_failed() then return "fail" end
    local clear = false
    for pn = 1, self:players() do
        local p = self.p[pn]
        if p.gogo and not p.ending then return "dusk" end
        if p.clear or (p.ending and p.ending ~= "fail") then clear = true end
    end
    return clear and "clear" or "day"
end

function Background:launch(t0)
    local slots = S.FW_SLOTS[self.sky_key]
    local n = self.fw_n
    self.fw_n = n + 1
    local s = slots[n % #slots + 1]
    -- a small deterministic jitter (whole 3U steps) so a slot never repeats the same spot
    local dx = ((n * 7) % 5 - 2) * 4 * U
    local dy = ((n * 5) % 3 - 1) * 3 * U
    -- dusk: all 3 variants; on the light (day / warm) sky only the red and orange ones read (gold on glow
    -- is too faint)
    local v = (self.sky_state == "dusk") and (n % S.FW_VARIANTS) or (2 - n % 2)
    self.fw[#self.fw + 1] = { t0 = t0, x = s[1] + dx, y = s[2] + dy, v = v }
end

function Background:update_sky(ms)
    local want = self:target_sky()
    if want ~= self.sky_state then
        self.sky_prev, self.sky_state, self.sky_t = self.sky_state, want, ms
    end
    if self.sky_prev and ms - self.sky_t > (#S.SKY[self.sky_key][self.sky_state] + 4) * SWEEP_MS + 200 then
        self.sky_prev = nil
    end
    -- fireworks: GOGO (any player, not ended) > full gauge; none in bare / dan layouts' exam-less states
    local period = nil
    if not self.bare then
        for pn = 1, self:players() do
            local p = self.p[pn]
            if not p.ending then
                if p.gogo then period = FW_GOGO_MS
                elseif p.rainbow and period == nil then period = FW_MAX_MS end
            end
        end
    end
    if period then
        if self.fw_next == nil or self.fw_next > ms + period then self.fw_next = ms end
        if ms >= self.fw_next then
            self:launch(ms)
            self.fw_next = math.max(self.fw_next + period, ms + math.floor(period / 2))
        end
    else
        self.fw_next = nil
    end
    local live = {}
    for _, f in ipairs(self.fw) do
        if ms - f.t0 < FW_LIFE * S.FW_MS then live[#live + 1] = f end
    end
    self.fw = live
end

-- the sky segment list of a state; draw one segment at full strength
local function draw_seg(g)
    UI.rect(0, g[1], S.W, g[2] - g[1], g[3])
    if g[4] then UI.wipe(g[5], g[4], g[1], g[2]) end
end

-- wipe level (0..4) of segment k of the incoming sky: bands sweep in from the top
function Background:seg_level(k)
    if not self.sky_prev then return 4 end
    return UI.wipe_in(self.ms - self.sky_t - (k - 1) * SWEEP_MS, 50)
end

-- has the incoming state reached row y (its band is at least half dithered in)?
function Background:reached(y)
    if not self.sky_prev then return true end
    local segs = S.SKY[self.sky_key][self.sky_state]
    for k, g in ipairs(segs) do
        if y >= g[1] and y < g[2] then return self:seg_level(k) >= 2 end
    end
    return self:seg_level(#segs) >= 2
end

-- the state that shows at row y (old or new while the sweep runs)
function Background:state_at(y)
    if self:reached(y) then return self.sky_state end
    return self.sky_prev
end

function Background:draw_sky()
    local set = S.SKY[self.sky_key]
    local function base(state)
        local segs = set[state]
        UI.rect(0, 0, S.W, S.H, segs[#segs][3])
        for _, g in ipairs(segs) do draw_seg(g) end
    end
    if not self.sky_prev then
        base(self.sky_state)
        return
    end
    base(self.sky_prev)
    for k, g in ipairs(set[self.sky_state]) do
        local lv = self:seg_level(k)
        if lv >= 4 then draw_seg(g)
        elseif lv > 0 then UI.wipe(lv, g[3], g[1], g[2]) end
    end
    -- below the last segment (the screen bottom, under the stage) follows the last band
    local segs = set[self.sky_state]
    if self:seg_level(#segs) >= 4 then
        local last = segs[#segs]
        UI.rect(0, last[2], S.W, S.H - last[2], last[3])
    end
end

function Background:draw_fireworks()
    local fms = S.FW_MS
    for _, f in ipairs(self.fw) do
        local fr = math.floor((self.ms - f.t0) / fms)
        if fr >= 0 and fr < 3 then
            draw_at(T(self, "fw_rise"), f.x, f.y + S.FW_CELL, fr)
        elseif fr >= 3 and fr < FW_LIFE then
            draw_at(T(self, "fw_" .. f.v), f.x - S.FW_R, f.y - S.FW_R, fr - 3)
        end
    end
end

-- scenery variant: 0 day / clear, 1 dusk, 2 fail
local SCENE_FRAME = { day = 0, clear = 0, dusk = 1, fail = 2 }

-- lit town lanterns (0..S.LIGHT_STEPS): the soul gauge's way to the clear line; all once cleared
function Background:town_lights()
    if self:is_failed() then return 0 end
    local n = 0
    for pn = 1, self:players() do
        local p = self.p[pn]
        local k
        if p.clear or (p.ending and p.ending ~= "fail") then k = S.LIGHT_STEPS
        else k = math.floor(S.LIGHT_STEPS * p.progress / (p.clear_line or CLEAR_DEFAULT)) end
        n = math.max(n, math.min(S.LIGHT_STEPS, k))
    end
    return n
end

function Background:draw_scenery(ground_y)
    local y = ground_y - S.SCN_H
    local st = self:state_at(ground_y - S.SCN_H // 2)
    local fr = SCENE_FRAME[st]
    draw_at(T(self, "mount"), 0, y, fr)
    draw_at(T(self, "town"), 0, y, fr)
    if st == "dusk" then draw_at(T(self, "town_win"), 0, y) end
    local n = self:town_lights()
    if n > 0 then draw_at(T(self, "town_lights"), 0, y, n) end
end

function Background:any(field)
    if self.is_2p then return self.p[1][field] or self.p[2][field] end
    return self.p[1][field]
end

-- clouds drift left exactly 1 physical px (half a logical px) every `ms_per_px` ms and wrap. x is kept
-- in physical units so every step is the same whole pixel (constant cadence, no 2-step jumps).
local function drift_x(x, w, ms, ms_per_px)
    local off = math.floor(ms / ms_per_px)
    local span2 = 2 * (S.W + w)
    return ((2 * x - off) % span2 + span2) % span2 / 2 - w
end

function Background:draw_clouds(list)
    for _, c in ipairs(list) do
        local t = T(self, c[1] == "S" and "cloud_s" or "cloud_m")
        local w = (c[1] == "S") and 108 or 162
        local fr = (self:state_at(c[3]) == "dusk") and 1 or 0
        draw_at(t, drift_x(c[2], w, self.ms, S.CLOUD_NEAR_MS), c[3], fr)
    end
end

function Background:draw_far_clouds()
    local t = T(self, "cloud_far")
    for _, c in ipairs(S.CLOUDS_FAR) do
        local fr = (self:state_at(c[2]) == "dusk") and 1 or 0
        draw_at(t, drift_x(c[1], S.CLOUD_FAR_W, self.ms, S.CLOUD_FAR_MS), c[2], fr)
    end
end

-- lanterns: 0 off / 1 lit (a player's gauge over the norma line, or cleared) / 2 dark (failed)
function Background:lantern_frame(fail)
    if fail then return 2 end
    for pn = 1, (self.is_2p and 2 or 1) do
        local p = self.p[pn]
        if p.clear or (p.ending and p.ending ~= "fail") then return 1 end
    end
    return 0
end

-- Hoshi's line (string key say_<state>_<i>, ss/strings.py) in the player's language: UI.bubble sized to
-- the measured text, the box growing right from x0, the 3-step tail tip at Hoshi (tip = { x, y })
function Background:draw_bubble(x0, tip)
    local w = UI.bubble_width(self.say_key)
    UI.bubble(self.say_key, tip[1], tip[2], { h = S.BUBBLE_H, cx = x0 + w / 2 })
end

function Background:draw_back()
    local fail = self:is_failed()
    self:draw_sky()
    self:draw_far_clouds()
    if not self.bare then self:draw_fireworks() end
    self:draw_clouds(S.CLOUDS)
    if self.bare then return end

    if self.layout == "1p" then
        self:draw_scenery(S.HORIZON_Y)
        local hz = self:state_at(S.HORIZON_Y - 1)
        draw_at(T(self, "horizon"), 0, S.HORIZON_Y, (hz == "clear" or hz == "dusk") and 1 or 0)
        draw_at(T(self, "stage"), 0, S.POST_TOP)
        -- GOGO: the flame band sits on the horizon between the posts, behind the cast
        if self.p[1].gogo and not self.p[1].ending then
            draw_at(T(self, "flame"), S.FLAME_X, S.FLAME_Y, UI.COMFORT and 0 or math.floor(self.ms / 200) % 2)
        end
        local lt = T(self, "lantern")
        for _, l in ipairs(S.LANTERNS) do draw_at(lt, l[1], l[2], self:lantern_frame(fail)) end
        self.momo:draw(S.MOMO_CX, S.FLOOR_Y)
        self.hoshi:draw(S.HOSHI_CX, S.FLOOR_Y)
        if self.burst_at then
            local live = false
            for i, l in ipairs(S.LANTERNS) do
                -- one burst per lantern, left to right, 66 ms apart
                if UI.burst(l[1] + S.LANTERN_W / 2, l[2] + S.LANTERN_H / 2, self.ms - self.burst_at - (i - 1) * 66) then
                    live = true
                end
            end
            if not live then self.burst_at = nil end
        end
        if self.say_key and self.ms < self.say_until then self:draw_bubble(S.BUBBLE_X, S.BUBBLE_TIP) end
    else
        self:draw_clouds(S.CLOUDS_2P)
        self:draw_scenery(S.G2_Y)
        draw_at(T(self, self.is_2p and "stage_2p" or "stage_dan"), 0, S.STAGE2_Y)
        local lt = T(self, "lantern_s")
        for _, l in ipairs(S.LANTERNS2) do draw_at(lt, l[1], l[2], self:lantern_frame(fail)) end
        local mx = self.is_2p and S.P2_MOMO_CX or S.DAN_MOMO_CX
        self.momo:draw(mx, S.G2_Y)
        self.hoshi:draw(self.is_2p and S.P2_HOSHI_CX or S.DAN_HOSHI_CX, S.G2_Y)
        if self.burst_at then
            local live = false
            for i, l in ipairs(S.LANTERNS2) do
                if UI.burst(l[1] + S.LANTERN2_W / 2, l[2] + S.LANTERN2_H / 2, self.ms - self.burst_at - (i - 1) * 66) then
                    live = true
                end
            end
            if not live then self.burst_at = nil end
        end
        if self.talk and self.say_key and self.ms < self.say_until then
            self:draw_bubble(S.DAN_BUBBLE_X, S.DAN_BUBBLE_TIP)
        end
    end
end

-- dan: the condition plate is drawn in the gauge's own layer (Nijiiro dan_info)
function Background:draw_gauge(pn)
    if self.dan_info then self.dan_info:draw() end
end

local LANE_TOP, GAUGE_BOTTOM = 276, 288
function Background:draw_fore()
    if self.is_dan then
        local redraw = _G.g_dan_gauge_redraw
        if redraw then
            tex.begin_scissor(0, LANE_TOP, tex.get_screen_width(), GAUGE_BOTTOM - LANE_TOP)
            local ok, err = pcall(redraw)
            tex.end_scissor()
            if not ok then error(err, 0) end
        end
        self.dan_info:draw_marker()
    end
    if self.rank_badges then
        local now = tex.get_current_ms()
        for _, b in pairs(self.rank_badges) do b:draw(now) end
    end
end

function Background:destroy()
    if _G.g_active_enso_skip == self.enso_skip then _G.g_active_enso_skip = nil end
    if self.endings then
        for _, e in pairs(self.endings) do e:destroy() end
        self.endings = nil
    end
    if self.rank_badges then
        for _, b in pairs(self.rank_badges) do b:destroy() end
        self.rank_badges = nil
    end
    tex.unload_folder("background", SUB)
end
