-- YataiDON's own AI battle (AIGameScreen, AIBattleOverlay) on this skin's cabinet stage. The drawing stays in
-- global/ai_battle.lua; this turns the engine's calls into the table that file reads (AIB.up, what Z-DON's
-- tex.ai_battle() returns). Engines with tex.ai_battle never load the overlay.
require("game/gauge")
local EnsoSkip = require("background/bg_objects/enso_skip")

local function A() return require("global.ai_battle") end

local FRAME_MS = 1000 / 60
local S = tex.get_screen_scale()
local END_HOLD_F = 195      -- the end cut-in's 3250 ms (global/ai_battle.lua END_HOLD), for its sounds

AIBattleOverlay = {}
AIBattleOverlay.__index = AIBattleOverlay

function AIBattleOverlay.new()
    local self = setmetatable({}, AIBattleOverlay)
    self:reset()
    return self
end

function AIBattleOverlay:reset()
    self.played = {}
    self.start_ms = nil
    self.event = nil
    self.final = nil
    self.section_ok = {}
    self.skip = EnsoSkip.new()
    A().up_begin()
end

function AIBattleOverlay:cue(name, preset, frame, at, tag)
    local key = name .. (tag or "")
    if frame >= (at or 0) and not self.played[key] then
        self.played[key] = true
        name = "ai_battle_" .. name
        if audio.has_sound(name) then audio.play_sound(name, preset) end
    end
end

function AIBattleOverlay:set_section_result(section, won)
    A().up_section(section, won)
    if not A().up.skipped then self.event = { won = won, section = section } end
end

-- the skip (the engine reads the AI's unplayed lane); a skipped match goes to the result without the end cut-ins
function AIBattleOverlay:handle_skip(count, total, skipped)
    if skipped then A().up.skipped = true end
    self.skip:handle({ count = count, total = total, remaining = total - count, skipped = skipped })
end

function AIBattleOverlay:set_match_result(won, full_combo)
    A().up_finish(won, full_combo)
    self.final = { won = won, full_combo = full_combo }
end

function AIBattleOverlay:draw_back(ms, territory)
    local event, final = self.event, self.final
    if event and not event.start then event.start = ms end
    if final and not final.start then final.start = ms end
    self.skip:update(ms)
    -- the opening's sounds wait for the loading card, as the floor's opening does
    A().up_territory(territory)
    A().draw_game_bg()
    local since = A().up_ready_age(ms) / FRAME_MS
    self:cue("se_enter", "sound", since)
    self:cue("vo_begin", "voice", since, 45)
    if event then
        local f = (ms - event.start) / FRAME_MS
        if not final then
            self:cue(event.won and "vo_section_win" or "vo_section_lose", "voice", f, 0, event.section)
        end
        self:cue(event.won and "se_section_win" or "se_section_lose", "sound", f, 10, event.section)
    end
end

-- where the engine stands the two 3D Dons: human at (border - 101) * S, AI at (border + 50) * S
function AIBattleOverlay:border_x(_)
    local x = A().up_clash_x()
    if not x then return -2000 end   -- not on the stage yet
    return (x - 110) / S + 101
end

function AIBattleOverlay:draw_clash(ms, _, angry)
    A().up_angry(angry)
    A().up_flames(ms)
end

function AIBattleOverlay:draw_front(_, section, section_count, progress)
    A().up_progress(section, section_count, progress)
    if section == section_count - 1 and not self.final then
        local up, won, lost = A().up, 0, 0
        for i = 1, section do
            local w = up.sections[i] and up.sections[i].winner
            if w == 0 then won = won + 1 elseif w == 1 then lost = lost + 1 end
        end
        self:cue(won > lost and "vo_reach_win" or (won < lost and "vo_reach_lose" or "vo_reach_draw"), "voice", 0)
    end
end

-- both boards come after the lanes: the plates, section icons and timer lie over them, as on Z-DON
function AIBattleOverlay:draw_scoreboard(is_ai, good, ok, bad, drumroll)
    local up = A().up
    if is_ai then
        up.judge_ai = { good, ok, bad, drumroll }
        A().draw_game()
    else
        up.judge_p = { good, ok, bad, drumroll }
        self.section_ok[up.section] = ok
        local total = 0
        for _, v in pairs(self.section_ok) do total = total + v end
        up.total_ok = total
    end
end

function AIBattleOverlay:draw_finale(ms)
    local final = self.final
    if final and final.start and not A().up.skipped and not final.cued and (ms - final.start) / FRAME_MS >= END_HOLD_F then
        -- the match's end: the cabinet's one cue, with the cut-in (as on Z-DON; no clear / full combo sounds)
        final.cued = true
        local kind = final.won and "song_win" or "song_lose"
        if audio.has_sound("ai_" .. kind) then audio.play_sound("ai_" .. kind, "sound") end
        if audio.has_sound("aivoice_" .. kind) then audio.play_sound("aivoice_" .. kind, "voice") end
    end
    A().draw_game_fore()
    self.skip:draw()
end

AIGauge = setmetatable({}, { __index = Gauge })
AIGauge.__index = AIGauge

function AIGauge.new(is_2p, dan, string_diff)
    return setmetatable(Gauge.new(is_2p, dan, string_diff), AIGauge)
end