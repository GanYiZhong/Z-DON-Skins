-- SimpleStyle v2 (meta): game over, a scene screen (bible 2.6). The house scene with the festival taiko
-- on the grass (game_over/logged_out/bana_ad); Momo (sit_fail, scene k) sits on the grass beside the
-- taiko with a 2-frame sway, Hoshi (scene k) stands on her other side turned to her. When the jingle
-- starts a dialog opens above them (3-frame window open) with the gold title band (16U, 1U ink rule,
-- 36 px ink おつかれさま！), the GAME OVER block letters (3U cells, the logo grid) dropping ONE BY ONE
-- (50 ms apart, 3 frames each + a 1U settle), and また あそんでね！. While the ad audio plays (before the
-- jingle) Hoshi cheers Momo up in a speech bubble (ドンマイ！) and Momo sways from the start. The end is
-- the house shutter wipe (SSM.shutter, the same as every screen change). Audio / timing as Nijiiro's.
-- (polish_meta)
local SSM = require("global.ss_meta")
local UI = SSM.UI
local D = UI.D
local U = D.U

GameOver = {}
GameOver.__index = GameOver

local DX, DY, DW, DH = 510, 300, 900, 330        -- dialog (ends y 630, above the cast's heads ~735)
local BAND_H = 16 * U                             -- the gold title band (chrome.dialog's title band)
local LETTERS_Y = DY + 2 * U + BAND_H + U + 33
local LINE_Y = DY + DH - 60
local GROUND = 1032                               -- the scene's grass line (ss/v2_meta.py bana_ad)
local MOMO_X, HOSHI_X = 900, 630                  -- the taiko stands at x 1170 (baked in bana_ad)
local BUBBLE_TIP_Y = 732                          -- above Hoshi's head (scene k: head top ~726)
local N_LETTERS = 9                               -- "GAME OVER" (ss_meta/go_letters frames)

function GameOver.new()
    local self = setmetatable({}, GameOver)
    self.ad_played = false
    self.voice_played = false
    self.finished = false
    self.open_ms = nil
    self.now = 0
    self.t0 = nil
    self.out_ms = nil

    self.text_bounce_down = tex.get_animation(4, "game_over")
    self.fade_out = tex.get_animation(7, "game_over")
    local ok8, copyright_fade = pcall(tex.get_animation, 8, "game_over")
    local ok9, copyright_hold = pcall(tex.get_animation, 9, "game_over")
    self.has_copyright = ok8 and ok9
    self.copyright_fade = self.has_copyright and copyright_fade or nil
    self.copyright_hold = self.has_copyright and copyright_hold or nil
    local ok10, blackout_cue = pcall(tex.get_animation, 10, "game_over")
    self.blackout_cue = ok10 and blackout_cue or nil

    audio.play_sound("bana_ad", "music")
    self.t_bg = tex.get_texture("game_over/logged_out/bana_ad")
    UI.reset()
    self.momo = UI.Mascot.new({ role = "scene", beat = false })
    self.momo:react("fail")
    self.hoshi = UI.Mascot.new({ role = "scene", beat = false, buddy = true })
    self.hoshi:react("turn", 1)
    self.title = UI.text_key("go_title", 36)
    self.line = UI.text_key("go_line", 36)
    return self
end

function GameOver:update(current_ms)
    self.now = current_ms
    if not self.t0 then self.t0 = current_ms end
    self.momo:update(current_ms)
    self.hoshi:update(current_ms)
    if not audio.is_sound_playing("bana_ad") and not self.ad_played then
        self.ad_played = true
        self.open_ms = current_ms
        audio.play_sound("curtain", "sound")
        self.text_bounce_down:start()
        audio.play_sound("jingle", "music")
        if self.blackout_cue then self.blackout_cue:start() end
    end
    if self.text_bounce_down.attribute > 0 and not self.voice_played then
        self.voice_played = true
        audio.play_sound("voice", "voice")
    end
    if self.blackout_cue then
        self.blackout_cue:update(current_ms)
        if self.blackout_cue.is_finished and not self.fade_out.is_started then
            self.fade_out:start()
        end
    elseif not audio.is_sound_playing("jingle") and self.voice_played and not self.fade_out.is_started then
        self.fade_out:start()
    end
    self.text_bounce_down:update(current_ms)
    self.fade_out:update(current_ms)
    if self.fade_out.is_started and not self.out_ms then self.out_ms = current_ms end
    if self.fade_out.is_finished then
        if not self.has_copyright then
            self.finished = true
            return
        end
        if not self.copyright_fade.is_started then self.copyright_fade:start() end
        self.copyright_fade:update(current_ms)
        if self.copyright_fade.is_finished then
            if not self.copyright_hold.is_started then self.copyright_hold:start() end
            self.copyright_hold:update(current_ms)
            if self.copyright_hold.is_finished then self.finished = true end
        end
    end
end

function GameOver:is_finished()
    return self.finished
end

-- letters drop: 3 frames (50 ms each) from above, then a 1U settle (down 1U for 50 ms, back)
local function letters_dy(e)
    if e < 0 then return nil end
    local f = math.floor(e / 50)
    if f == 0 then return -96 elseif f == 1 then return -48 elseif f == 2 then return 0
    elseif f == 3 then return U end
    return 0
end

function GameOver:draw()
    if self.t_bg then tex.draw_texture(self.t_bg) end
    -- the cast on the grass: Momo sitting beside the taiko (swaying one sprite px every 500 ms once the
    -- jingle starts), Hoshi turned to her
    local sway = 0
    if self.t0 and math.floor((self.now - self.t0) / 500) % 2 == 1 then sway = D.MASCOT.k.scene end
    self.hoshi:draw(HOSHI_X, GROUND, { still = true })
    self.momo:draw(MOMO_X + sway, GROUND, { still = true })
    -- before the jingle: Hoshi's bubble (from 400 ms in), tail on his mouth
    if not self.open_ms and self.t0 and self.now - self.t0 >= 400 then
        UI.bubble("go_cheer", HOSHI_X + 30, BUBBLE_TIP_Y)
    end
    if self.open_ms then
        local e = self.now - self.open_ms
        local x, y, w, h, full = UI.open_rect(DX, DY, DW, DH, e)
        if x then
            local ix, iy, iw = UI.chrome.dialog(x, y, w, h)
            if full then
                UI.rect(ix, iy, iw, BAND_H, D.P.clear)
                UI.rect(ix, iy + BAND_H, iw, U, D.P.ink)
                UI.draw_text(self.title, 960, iy + BAND_H / 2, "c")
                local tb = self.text_bounce_down.is_started and (self.now - self.open_ms - 150) or -1
                local t = SSM.T("go_letters")
                if t and tb >= 0 then
                    local info = tex.get_texture_info("ss_meta", "go_letters")
                    local lw = (info and info.width) or 498
                    local lx = math.floor(960 - lw / 2)
                    for k = 0, N_LETTERS - 1 do        -- one letter every 50 ms, left to right
                        local dy = letters_dy(tb - k * 50)
                        if dy then tex.draw_texture(t, { frame = k, x = lx, y = LETTERS_Y + dy }) end
                    end
                end
                UI.draw_text(self.line, 960, LINE_Y, "c")
            end
        end
    end
    -- the end: the house shutters close (the next screen's entry wipe rolls them up again)
    if self.out_ms then SSM.shutter(self.now - self.out_ms, "in") end
end
