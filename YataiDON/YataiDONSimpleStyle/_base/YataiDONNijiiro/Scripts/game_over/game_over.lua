-- Game-over scene (ported 1:1 from src/scenes/game_over.cpp); the copyright tail is optional.
GameOver = {}
GameOver.__index = GameOver

function GameOver.new(overlay)
    local self = setmetatable({}, GameOver)
    self.ad_played = false
    self.voice_played = false
    self.finished = false
    self.over_result = tex.get_skin_config("zdon_end_over_result") ~= nil

    self.curtain_pull_out = tex.get_animation(1, "game_over")
    self.curtain_pull_in = tex.get_animation(2, "game_over")
    self.kitsune_texture_change = tex.get_animation(3, "game_over")
    self.kitsune_texture_change:start()
    self.text_bounce_down = tex.get_animation(4, "game_over")
    self.text_bounce_up = tex.get_animation(5, "game_over")
    self.text_bounce_down_2 = tex.get_animation(6, "game_over")
    self.fade_out = tex.get_animation(7, "game_over")

    local ok8, copyright_fade = pcall(tex.get_animation, 8, "game_over")
    local ok9, copyright_hold = pcall(tex.get_animation, 9, "game_over")
    local t_copyright = tex.get_texture("game_over/global/copyright")
    self.has_copyright = ok8 and ok9 and (t_copyright ~= nil)
    self.copyright_fade = self.has_copyright and copyright_fade or nil
    self.copyright_hold = self.has_copyright and copyright_hold or nil
    self.t_copyright = self.has_copyright and t_copyright or nil

    local ok10, blackout_cue = pcall(tex.get_animation, 10, "game_over")
    self.blackout_cue = ok10 and blackout_cue or nil

    -- The arcade has no ad phase here (GameOver.nulm + the result/common_result Lua never load one): the curtain
    -- is pulled over the result screen right away (direct feed rQDV7i9IdeY, 0vjiSUv61i4 t=976 s).
    self.t0 = nil

    self.t_bana_ad = (not overlay) and tex.get_texture("game_over/logged_out/bana_ad") or nil
    self.t_mascots = tex.get_texture("game_over/global/mascots")   -- arcade end_curtain_mc shape 35: pig / chicks / kid in soap bubbles
    self.t_kitsune = tex.get_texture("game_over/global/kitsune")
    self.t_curtain_side = tex.get_texture("game_over/global/curtain_side")
    self.t_curtain = tex.get_texture("game_over/global/curtain")
    self.curtain_info = tex.get_texture_info("global", "curtain")
    self.t_game_over_text = tex.get_texture("game_over/global/game_over_text_" .. tex.language())

    return self
end

function GameOver:update(current_ms)
    if not self.ad_played then
        self.ad_played = true
        self.t0 = current_ms
        audio.play_sound("curtain", "sound")
        self.curtain_pull_out:start()
        self.curtain_pull_in:start()
        self.text_bounce_down:start()
        self.text_bounce_up:start()
        self.text_bounce_down_2:start()
        audio.play_sound("jingle", "music")
        if self.blackout_cue then self.blackout_cue:start() end
    end

    -- the voice follows the curtain sound by 0.59 s (waveform alignment of the skin's own files in the direct
    -- feeds rQDV7i9IdeY: curtain 1.601 s, voice 2.193 s; YKjsle7VBCI: curtain + bana_ad 564.160, voice 564.752)
    if self.t0 and current_ms - self.t0 >= 590 and not self.voice_played then
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

    self.curtain_pull_out:update(current_ms)
    self.curtain_pull_in:update(current_ms)
    self.kitsune_texture_change:update(current_ms)
    self.text_bounce_down:update(current_ms)
    self.text_bounce_up:update(current_ms)
    self.text_bounce_down_2:update(current_ms)
    self.fade_out:update(current_ms)

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
            if self.copyright_hold.is_finished then
                self.finished = true
            end
        end
    end
end

-- arcade end_curtain_mc: the strip fades in over frames 90-114 (1433 ms after the curtain starts, 400 ms long)
function GameOver:mascot_fade(current_ms)
    if not self.t0 then return 0 end
    local f = (current_ms - self.t0 - 1433.33) / 400.0
    if f < 0 then return 0 end
    if f > 1 then return 1 end
    return f
end

function GameOver:is_finished()
    return self.finished
end

function GameOver:draw()
    -- the arcade pulls the curtain over the frozen result board (skin_config zdon_end_over_result: the engine
    -- holds the result's last frame, no fade); without it the red backdrop
    if not (self.over_result and tex.draw_frozen_screen()) then
        if self.t_bana_ad then tex.draw_texture(self.t_bana_ad) end
    end
    tex.draw_texture(self.t_kitsune, {
        frame = math.floor(self.kitsune_texture_change.attribute), x = self.curtain_pull_out.attribute,
    })
    tex.draw_texture(self.t_curtain_side, { x = self.curtain_pull_out.attribute + self.curtain_pull_in.attribute })
    for i = 0, 3 do
        tex.draw_texture(self.t_curtain, {
            x = i * self.curtain_info.width + self.curtain_pull_out.attribute + self.curtain_pull_in.attribute,
        })
    end
    if self.t_mascots then
        local fa = self:mascot_fade(tex.get_current_ms())
        if fa > 0 then tex.draw_texture(self.t_mascots, { fade = fa }) end
    end
    -- parked at the drop's start y (-214); shown from the first frame of the drop (1433 ms after the curtain starts)
    if self.t0 and tex.get_current_ms() - self.t0 >= 1433.33 then
        tex.draw_texture(self.t_game_over_text, {
            y = self.text_bounce_down.attribute + self.text_bounce_up.attribute + self.text_bounce_down_2.attribute,
        })
    end
    tex.draw_rect(0, 0, tex.get_screen_width(), tex.get_screen_height(), 33, 29, 30, math.floor(self.fade_out.attribute * 255))
    if self.has_copyright then
        tex.draw_texture(self.t_copyright, { fade = self.copyright_fade.attribute })
    end
end
