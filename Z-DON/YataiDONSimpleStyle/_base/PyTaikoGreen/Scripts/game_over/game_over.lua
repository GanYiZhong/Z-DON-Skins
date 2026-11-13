-- Ported 1:1 from src/scenes/game_over.cpp (pure visual/audio, no input).
-- The "copyright" tail (animation ids 8/9) and its blackout cue (id 10) are
-- optional per skin, same as the original tex.has_animation/has_texture guard.
GameOver = {}
GameOver.__index = GameOver

function GameOver.new(overlay)
    local self = setmetatable({}, GameOver)
    self.ad_played = false
    self.voice_played = false
    self.finished = false

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

    -- overlay: drawn over the screen that ended the credit, no ad first
    if not overlay then audio.play_sound("bana_ad", "music") end

    self.t_bana_ad = (not overlay) and tex.get_texture("game_over/logged_out/bana_ad") or nil
    self.t_kitsune = tex.get_texture("game_over/global/kitsune")
    self.t_curtain_side = tex.get_texture("game_over/global/curtain_side")
    self.t_curtain = tex.get_texture("game_over/global/curtain")
    self.curtain_info = tex.get_texture_info("global", "curtain")
    self.t_game_over_text = tex.get_texture("game_over/global/game_over_text_" .. tex.language())

    return self
end

function GameOver:update(current_ms)
    if not audio.is_sound_playing("bana_ad") and not self.ad_played then
        self.ad_played = true
        audio.play_sound("curtain", "sound")
        self.curtain_pull_out:start()
        self.curtain_pull_in:start()
        self.text_bounce_down:start()
        self.text_bounce_up:start()
        self.text_bounce_down_2:start()
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

function GameOver:is_finished()
    return self.finished
end

function GameOver:draw()
    if self.t_bana_ad then tex.draw_texture(self.t_bana_ad) end
    tex.draw_texture(self.t_kitsune, {
        frame = math.floor(self.kitsune_texture_change.attribute), x = self.curtain_pull_out.attribute,
    })
    tex.draw_texture(self.t_curtain_side, { x = self.curtain_pull_out.attribute + self.curtain_pull_in.attribute })
    for i = 0, 3 do
        tex.draw_texture(self.t_curtain, {
            x = i * self.curtain_info.width + self.curtain_pull_out.attribute + self.curtain_pull_in.attribute,
        })
    end
    tex.draw_texture(self.t_game_over_text, {
        y = self.text_bounce_down.attribute + self.text_bounce_up.attribute + self.text_bounce_down_2.attribute,
    })
    tex.draw_rect(0, 0, tex.get_screen_width(), tex.get_screen_height(), 33, 29, 30, math.floor(self.fade_out.attribute * 255))
    if self.has_copyright then
        tex.draw_texture(self.t_copyright, { fade = self.copyright_fade.attribute })
    end
end
