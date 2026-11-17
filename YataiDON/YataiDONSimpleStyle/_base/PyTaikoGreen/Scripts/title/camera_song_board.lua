require("title/camera_faces")

local S = tex.get_screen_scale()
local WHITE, BLACK = { 255, 255, 255, 255 }, { 0, 0, 0, 255 }

local START_MS = 4000
local ROULETTE_MS, ROULETTE_STEP_MS = 1000, 33
local FADE_MS = 100
local GREY = 2
local FACE = { cx = 278, cy = 56, s = 0.75 }
local TITLE = { cx = 660, cy = 82, max_w = 560, size = 40 }

-- Hiroba genre folder names -> board frame (J-POP, アニメ, ボカロ, どうよう, バラエティ, クラシック, ゲーム, ナムコ)
local GENRES = {
    { "anime", 1 }, { "vocaloid", 2 }, { "child", 3 }, { "folk", 3 }, { "variety", 4 }, { "classic", 5 },
    { "game", 6 }, { "namco", 7 }, { "pop", 0 },
}

local function genre_frame(name)
    name = (name or ""):lower()
    for _, g in ipairs(GENRES) do
        if name:find(g[1], 1, true) then return g[2] end
    end
    return nil
end

CameraSongBoard = {}
CameraSongBoard.__index = CameraSongBoard

function CameraSongBoard.new(start_ms, set)
    local self = setmetatable({}, CameraSongBoard)
    self.start_ms = start_ms
    self.t_bar = tex.get_texture("title/camera/song_board_bar")
    self.t_tab = tex.get_texture("title/camera/song_board_tab")
    self.t_ring = tex.get_texture("title/camera/osusume_ring")
    self.t_text = tex.get_texture("title/camera/osusume_text")
    tex.load_folder("camera_faces", set)
    local info = tex.get_texture_info(set, "face")
    if info then
        self.face = { id = tex.get_texture("camera_faces/" .. set .. "/face"), w = info.x2[1], h = info.y2[1],
            frame = math.random(0, info.frame_count - 1) }
    end
    return self
end

-- the board waits for the cloud, then rolls through the genres and lands on a random top-10 song
function CameraSongBoard:update(current_ms)
    self.t = current_ms - self.start_ms
    if self.song or self.t < START_MS then return end
    local songs = network.popular_songs()
    if not songs or #songs == 0 then return end
    local song = songs[math.random(1, #songs)]
    self.song = { genre = genre_frame(song.genre), shown_at = self.t }
    self.title = text.create_raw_text(song.title, math.floor(TITLE.size * S), WHITE, BLACK, false, 6)
end

-- the speech cloud gives way to the board
function CameraSongBoard:cloud_alpha()
    if not self.song then return 1 end
    return 1 - math.min(1, (self.t - self.song.shown_at) / FADE_MS)
end

function CameraSongBoard:draw()
    if not self.song then return end
    local t = self.t - self.song.shown_at
    local fade = math.min(1, t / FADE_MS)
    local rolling = t < ROULETTE_MS
    local frame = rolling and math.floor(t / ROULETTE_STEP_MS) % 8 or (self.song.genre or GREY)
    tex.draw_texture(self.t_bar, { frame = frame, fade = fade })
    if rolling or self.song.genre then tex.draw_texture(self.t_tab, { frame = frame, fade = fade }) end
    tex.draw_texture(self.t_ring, { fade = fade })
    tex.draw_texture(self.t_text, { fade = fade })
    if not rolling and self.title then
        local s = math.min(1, TITLE.max_w * S / self.title.width)
        local w, h = self.title.width * s, self.title.height * s
        local a = math.min(1, (t - ROULETTE_MS) / FADE_MS)
        self.title:draw({ x = TITLE.cx * S - w / 2, y = TITLE.cy * S - h / 2,
            x2 = w - self.title.width, y2 = h - self.title.height, fade = a })
    end
end
