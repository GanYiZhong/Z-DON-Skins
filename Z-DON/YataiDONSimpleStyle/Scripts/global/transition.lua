-- SimpleStyle v2: song-loading transition. The house shutter wipe (SSM.shutter, polish_meta): 16 sky /
-- cloud2 shutters drop over the song select in 3 hard steps per column (3 column groups, left to right,
-- 50 ms cadence), then roll up over the scene. The scene is the house horizon with the lantern string;
-- the engine's title sits on a paper band (window open, 3 frames); the hint panel below; Momo and Hoshi
-- (k=9) stand on the grass facing it and hop on a steady 2-step bob while the song loads. The second half
-- (after loading) drops the shutters over the scene and rolls them up over the game.
local SSM = require("global.ss_meta")
local UI = SSM.UI
local D = UI.D

SongTransition = {}
SongTransition.__index = SongTransition

local FADE_DELAY, FADE_MS, FADE_OUT_MS = 266.0, 266.0, 133.0
local SCENE_MS = FADE_DELAY + FADE_MS
local RISE_MS, RISE_DIST = 266.0, 1224
local STEP = 50
-- the dan course intro (engine-drawn dan_loading/loading_dan: night scene + rank plaque) runs while this
-- transition is unfinished; GAME_DAN builds it with an empty title. Hold it, then slide it away.
local DAN_MS = 2500

local BAND_X, BAND_Y = 180, 297            -- title at y 382, subtitle at 462 once risen
local HINT_X, HINT_Y = 480, 597
local GROUND = 1032

local function clamp(v, a, b) if v < a then return a elseif v > b then return b else return v end end

function SongTransition.new(title, subtitle, is_second)
    local self = setmetatable({}, SongTransition)
    self.is_second = is_second and true or false
    self.dan = self.is_second and (title == nil or title == "")
    self.t0, self.t = nil, 0
    self.info = 0
    self.info_ms = nil
    UI.reset()
    self.momo = UI.Mascot.new({ role = "scene", beat = false })
    self.hoshi = UI.Mascot.new({ char = D.MASCOT.buddy, role = "scene", beat = false })
    self.momo:react("turn", 1)
    self.hoshi:react("turn", -1)
    self.hint1 = UI.text(tex.skin_text("transition_hint_line1"), 24)
    self.hint2 = UI.text(tex.skin_text("transition_hint_line2"), 24)
    self.skip_text = UI.text(tex.skin_text("skip_badge_text"), 24)
    self.skip_on = nil
    return self
end

function SongTransition:skip_armed()
    if self.skip_on == nil then
        self.skip_on = (tex.skip_enabled ~= nil) and tex.skip_enabled() or false
    end
    return self.skip_on
end

function SongTransition:state()
    local t = self.t or 0
    local rise = RISE_DIST * clamp(t / RISE_MS, 0, 1) ^ 3
    if self.dan then
        local up = RISE_DIST * clamp((t - (DAN_MS - RISE_MS)) / RISE_MS, 0, 1) ^ 3
        return { rainbow_up = up, fade_out = 1.0, finished = t >= DAN_MS }
    end
    if self.is_second then
        return { rainbow_up = rise, fade_out = clamp(1.0 - t / FADE_OUT_MS, 0, 1),
                 finished = t >= 2 * SSM.SHUTTER_MS }
    end
    return { rainbow_up = rise, fade = clamp((t - FADE_DELAY) / FADE_MS, 0, 1),
             finished = t >= SCENE_MS }
end

function SongTransition:start() self.t0 = nil end

function SongTransition:update(current_ms, rainbow_up, song_info_fade)
    if not self.t0 then self.t0 = current_ms end
    self.t = current_ms - self.t0
    self.momo:update(current_ms)
    self.hoshi:update(current_ms)
    if self.is_second then
        self.info = clamp(1.0 - self.t / FADE_OUT_MS, 0, 1)
    else
        self.info = clamp(song_info_fade or ((self.t - FADE_DELAY) / FADE_MS), 0, 1)
        if self.info > 0 and not self.info_ms then self.info_ms = current_ms end
    end
end

local function draw_line(t, cx, cy) UI.draw_text(t, cx, cy, "c") end

function SongTransition:draw_scene(open_ms)
    local scene = SSM.T("scene")
    if scene then tex.draw_texture(scene, { x = 0, y = 0 }) end
    -- the title band opens in 3 frames
    if open_ms then
        local x, y, w, h, full = UI.open_rect(BAND_X, BAND_Y, 1554, 222, open_ms)
        if x then
            if full then
                local band = SSM.T("band")
                if band then tex.draw_texture(band, { x = BAND_X, y = BAND_Y }) end
            else
                UI.chrome.dialog(x, y, w, h)
            end
        end
    end
    local hint = SSM.T("hint")
    if hint then
        tex.draw_texture(hint, { x = HINT_X, y = HINT_Y })
        SSM.plate(HINT_X, HINT_Y, "game_hint", D.P.clear)   -- the ゲームのヒント plate, sized to the word
        draw_line(self.hint1, HINT_X + 477, HINT_Y + 108)
        draw_line(self.hint2, HINT_X + 477, HINT_Y + 159)
    end
    -- a steady 2-step bob (1 sprite px every 250 ms, opposite phase): the cast waits for the song
    local k = D.MASCOT.k.scene
    local up = math.floor(tex.get_current_ms() / 250) % 2 == 1
    self.momo:draw(330, GROUND - (up and k or 0))
    self.hoshi:draw(1590, GROUND - (up and 0 or k))
    if self:skip_armed() then
        local ix, iy, iw, ih = UI.chrome.chip(36, 36, 246, 39, D.P.clear, false)
        draw_line(self.skip_text, ix + iw / 2, iy + ih / 2)
    end
end

function SongTransition:draw_bg(total_offset, rainbow_up, mini_up, chara_down)
    local t = self.t or 0
    local SH = SSM.SHUTTER_MS
    if self.is_second then
        -- the shutters drop over the loading scene, then roll up over the game
        if t < SH then
            self:draw_scene(1000)
            SSM.shutter(t, "in")
        else
            SSM.shutter(t - SH, "out")
        end
        return
    end
    if t < SH then
        SSM.shutter(t, "in")
        return
    end
    self:draw_scene(self.info_ms and (tex.get_current_ms() - self.info_ms) or nil)
    SSM.shutter(t - SH, "out")
end
