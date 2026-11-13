SongInfo = {}
SongInfo.__index = SongInfo

local WHITE, BLACK, RED, BLANK = { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, { 255, 0, 0, 255 }, { 0, 0, 0, 0 }
local GENRE_PLATE_COLOR = { 60, 103, 0 }   -- the plate texture's colour, replaced by the genre's

local function outline_of(cfg)
    return cfg.outline >= 0 and cfg.outline or 5.0
end

function SongInfo.new(title, _, number, genre_label, genre_color)
    local self = setmetatable({}, SongInfo)
    self.fade = tex.get_animation(3)
    self.genre_color = genre_color

    self.title_cfg = tex.get_skin_config("game_song_info")
    self.center_cfg = tex.get_skin_config("game_song_info_center")
    self.title = text.create_raw_text(title, self.title_cfg.font_size, WHITE, BLACK, false, outline_of(self.title_cfg))

    self.num_cfg = tex.get_skin_config("song_num_game")
    local fmt = tex.skin_text("song_num")
    if fmt == "" then fmt = "{0}" end
    local limit = tex.song_limit()
    self.number = text.create_raw_text((fmt:gsub("{0}", tostring(number))), tex.get_skin_config("song_num").font_size,
                                       WHITE, (limit > 0 and limit == number) and RED or BLACK, false,
                                       outline_of(self.num_cfg))

    self.genre = tex.get_texture("song_info/genre")
    self.genre_info = tex.get_texture_info("song_info", "genre")
    self.plate = tex.get_texture("song_info/song_num_plate")
    self.genre_text = text.create_raw_text(genre_label, 18 * tex.get_screen_scale(), WHITE, BLANK, false, 3, 1)
    return self
end

function SongInfo:update(current_ms)
    self.fade:update(current_ms)
end

function SongInfo:draw(dx, dy)
    local fade = self.fade.attribute
    local title_w = self.title.width
    local title_x = self.title_cfg.x + dx - title_w
    if title_w <= self.center_cfg.width then
        title_x = self.center_cfg.x + dx - title_w / 2
    end
    self.title:draw({ x = title_x, y = self.title_cfg.y + dy - self.title.height / 2, fade = 1 - fade })

    local info = self.genre_info
    tex.begin_recolor(GENRE_PLATE_COLOR, self.genre_color)
    tex.draw_texture(self.genre, { x = dx, y = dy, fade = 1 - fade })
    tex.end_recolor()
    self.genre_text:draw({ x = info.x[1] + dx + info.width / 2 - self.genre_text.width / 2,
                           y = info.y[1] + dy + info.height / 2 - self.genre_text.height / 2,
                           fade = 1 - fade })

    tex.draw_texture(self.plate, { x = dx, y = dy, fade = fade })
    self.number:draw({ x = self.num_cfg.x + dx - self.number.width / 2,
                       y = self.num_cfg.y + dy - self.number.height / 2, fade = fade })
end
