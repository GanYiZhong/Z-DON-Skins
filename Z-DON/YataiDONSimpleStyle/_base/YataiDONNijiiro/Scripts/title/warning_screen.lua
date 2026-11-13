local WarningX = {}
WarningX.__index = WarningX

function WarningX.new()
    local self = setmetatable({}, WarningX)
    self.resize = tex.get_animation(0, "title")
    self.resize:start()
    self.fade_in = tex.get_animation(1, "title")
    self.fade_in:start()
    self.fade_in_2 = tex.get_animation(2, "title")
    self.fade_in_2:start()
    self.sound_played = false

    self.t_x_lightred = tex.get_texture("title/warning/x_lightred")
    self.t_x_red = tex.get_texture("title/warning/x_red")
    return self
end

function WarningX:update(current_ms)
    self.resize:update(current_ms)
    self.fade_in:update(current_ms)
    self.fade_in_2:update(current_ms)

    if self.resize.attribute > 1 and not self.sound_played then
        audio.play_sound("error", "attract_mode")
        self.sound_played = true
    end
end

function WarningX:draw_bg()
    tex.draw_texture(self.t_x_lightred, { fade = self.fade_in_2.attribute })
end

function WarningX:draw_fg()
    tex.draw_texture(self.t_x_red, { scale = self.resize.attribute, center = true, fade = self.fade_in.attribute })
end

function WarningX:is_finished()
    return self.resize.is_finished and self.fade_in.is_finished and self.fade_in_2.is_finished
end

local WarningBachiHit = {}
WarningBachiHit.__index = WarningBachiHit

function WarningBachiHit.new()
    local self = setmetatable({}, WarningBachiHit)
    self.resize = tex.get_animation(3, "title")
    self.fade_in = tex.get_animation(4, "title")
    self.sound_played = false

    self.t_bachi_hit = tex.get_texture("title/warning/bachi_hit")
    self.t_bachi = tex.get_texture("title/warning/bachi")
    return self
end

function WarningBachiHit:update(current_ms)
    if not self.sound_played then
        audio.play_sound("bachi_hit", "attract_mode")
        self.sound_played = true
        self.fade_in:start()
        self.resize:start()
    end
    self.resize:update(current_ms)
    self.fade_in:update(current_ms)
end

function WarningBachiHit:draw()
    tex.draw_texture(self.t_bachi_hit, { scale = self.resize.attribute, center = true, fade = self.fade_in.attribute })
    if self.resize.attribute > 0 and self.sound_played then
        tex.draw_texture(self.t_bachi)
    end
end

function WarningBachiHit:is_finished()
    return self.fade_in.is_finished and self.sound_played and self.resize.is_finished
end

local WarningCharacters = {}
WarningCharacters.__index = WarningCharacters

function WarningCharacters.new()
    local self = setmetatable({}, WarningCharacters)
    self.shadow_fade = tex.get_animation(5, "title")
    self.chara_0_frame = tex.get_animation(7, "title")
    self.chara_1_frame = tex.get_animation(6, "title")
    self.chara_0_frame:start()
    self.chara_1_frame:start()
    self.saved_frame = 0

    self.t_chara_0 = tex.get_texture("title/warning/chara_0")
    self.t_chara_1 = tex.get_texture("title/warning/chara_1")
    return self
end

function WarningCharacters:update(current_ms)
    self.shadow_fade:update(current_ms)
    self.chara_1_frame:update(current_ms)
    self.chara_0_frame:update(current_ms)

    if self.chara_1_frame.attribute ~= self.saved_frame then
        self.saved_frame = math.floor(self.chara_1_frame.attribute)
        if not self.shadow_fade.is_started then
            self.shadow_fade:start()
        else
            self.shadow_fade:restart()
        end
    end
end

function WarningCharacters:draw(fade, fade_2, y_pos)
    tex.draw_texture(self.t_chara_0, { frame = math.floor(self.chara_0_frame.attribute), y = y_pos, fade = fade })

    if -1 < self.chara_1_frame.attribute - 1 and self.chara_1_frame.attribute - 1 < 7 then
        tex.draw_texture(self.t_chara_1, {
            frame = math.floor(self.chara_1_frame.attribute) - 1, y = y_pos, fade = self.shadow_fade.attribute,
        })
    end
    tex.draw_texture(self.t_chara_1, { frame = math.floor(self.chara_1_frame.attribute), y = y_pos, fade = fade })
end

function WarningCharacters:is_finished()
    return self.chara_1_frame.is_finished
end

local Board = {}
Board.__index = Board

function Board.new()
    local self = setmetatable({}, Board)
    self.move_down = tex.get_animation(10, "title")
    self.move_down:start()
    self.move_up = tex.get_animation(11, "title")
    self.move_up:start()
    self.move_center = tex.get_animation(12, "title")
    self.move_center:start()
    self.y_pos = 0

    self.t_warning_box = tex.get_texture("title/warning/warning_box")
    return self
end

function Board:update(current_ms)
    self.move_down:update(current_ms)
    self.move_up:update(current_ms)
    self.move_center:update(current_ms)
    if self.move_up.is_finished then
        self.y_pos = self.move_center.attribute
    elseif self.move_down.is_finished then
        self.y_pos = self.move_up.attribute
    else
        self.y_pos = self.move_down.attribute
    end
end

function Board:draw()
    tex.draw_texture(self.t_warning_box, { y = self.y_pos })
end

WarningScreen = {}
WarningScreen.__index = WarningScreen

function WarningScreen.new(current_ms)
    local self = setmetatable({}, WarningScreen)
    self.start_ms = current_ms

    self.fade_in = tex.get_animation(8, "title")
    self.fade_out = tex.get_animation(9, "title")
    self.fade_in:start()

    self.board = Board.new()
    self.warning_x = WarningX.new()
    self.warning_bachi_hit = WarningBachiHit.new()
    self.characters = WarningCharacters.new()

    self.t_warning_background = tex.get_texture("title/warning/background")
    self.t_movie_background = tex.get_texture("title/movie/background")

    return self
end

function WarningScreen:update(current_ms)
    self.board:update(current_ms)
    self.fade_in:update(current_ms)
    self.fade_out:update(current_ms)
    local delay = 533.33
    local elapsed_time = current_ms - self.start_ms
    self.warning_x:update(current_ms)
    self.characters:update(current_ms)

    if self.characters:is_finished() then
        self.warning_bachi_hit:update(current_ms)
    else
        self.fade_out:start()
        if delay <= elapsed_time and not audio.is_sound_playing("bachi_swipe") then
            audio.play_sound("warning_voiceover", "attract_mode")
            audio.play_sound("bachi_swipe", "attract_mode")
        end
    end
end

function WarningScreen:is_finished()
    return self.fade_out.is_finished
end

function WarningScreen:draw()
    tex.draw_texture(self.t_warning_background)
    self.board:draw()
    self.warning_x:draw_bg()
    -- chara texture.json y is absolute stage px; follow only the board's slide around its rest y (154)
    self.characters:draw(self.fade_in.attribute, math.min(self.fade_in.attribute, 0.75), self.board.y_pos - 154)
    self.warning_x:draw_fg()
    self.warning_bachi_hit:draw()

    tex.draw_texture(self.t_movie_background, { fade = self.fade_out.attribute })
end
