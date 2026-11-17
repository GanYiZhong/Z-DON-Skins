BattleStory = {}
BattleStory.__index = BattleStory

local S = tex.get_screen_scale()
local FRAME_MS = 1000 / 60
local BLACK = { 0, 0, 0, 255 }
local FADE_FRAMES = 15
local FONT = "FOT-Seurat_Pro_B.otf"
local SCENES = "song_select/battle_story/"
local PLAYERS = {
    chat = require(SCENES .. "chat"), intro = require(SCENES .. "intro"), stage = require(SCENES .. "stage"),
    boss = require(SCENES .. "boss"), reward = require(SCENES .. "reward"),
}
local MUSIC = { main = "battle_story_bgm", boss = "battle_story_bgm_boss", info2 = "battle_story_bgm_info2",
    info3 = "battle_story_bgm_info3", info4 = "battle_story_bgm_info4", info5 = "battle_story_bgm_info5",
    prologue = "battle_story_bgm_prologue" }

local function load_scene(id)
    local ok, scene = pcall(require, SCENES .. id)
    if ok and type(scene) == "table" and PLAYERS[scene.kind] then return scene end
end

-- ids: the story scenes Hiroba says are due, in order; ones without a scene file are skipped and stay unseen
function BattleStory.new(ids)
    local self = setmetatable({}, BattleStory)
    self.ids, self.sizes = {}, {}
    self.queue, self.watched = {}, {}
    for _, id in ipairs(ids) do
        local scene = load_scene(id)
        if scene then self.queue[#self.queue + 1] = { id = id, scene = scene } end
    end
    if #self.queue > 0 then
        tex.load_folder("song_select", "battle_story")
    end
    self.index = 0
    self.closing = false
    return self
end

function BattleStory:next_scene(ms)
    self.index = self.index + 1
    local entry = self.queue[self.index]
    self.player = entry and PLAYERS[entry.scene.kind].new(self, entry.scene)
    self.scene_ms, self.closing = ms, false
end

function BattleStory:update(ms)
    self.ms = ms
    if self.index == 0 then self:next_scene(ms) end
    if not self.player then return end
    local f = (ms - self.scene_ms) / FRAME_MS
    if self.closing then
        if (ms - self.closing) / FRAME_MS >= FADE_FRAMES then
            self.watched[#self.watched + 1] = self.queue[self.index].id
            self:next_scene(ms)
            if not self.player then self:finish() end
        end
        return
    end
    self.player:update(f)
    if self.player:done() then self.closing = ms end
end

function BattleStory:finish()
    self:music("stop")
    tex.unload_folder("game", "battle_stage")
    tex.unload_folder("game", "enso_battle")
end

function BattleStory:input(action)
    if self.player and not self.closing and self.ms then
        self.player:input(action, (self.ms - self.scene_ms) / FRAME_MS)
    end
end

function BattleStory:draw()
    if not self.player then return end
    self.player:draw((self.ms - self.scene_ms) / FRAME_MS)
    local black = math.max(0, 1 - (self.ms - self.scene_ms) / FRAME_MS / FADE_FRAMES)
    if self.closing then black = math.min(1, (self.ms - self.closing) / FRAME_MS / FADE_FRAMES) end
    if black > 0 then
        tex.draw_rect(0, 0, tex.get_screen_width(), tex.get_screen_height(), 0, 0, 0, 255 * black)
    end
end

-- name: a MUSIC key or "stop"; the playing track keeps going when asked for again
function BattleStory:music(name)
    if name == self.track then return end
    if self.track and self.track ~= "stop" then audio.stop_sound(MUSIC[self.track]) end
    self.track = name
    if MUSIC[name] then audio.play_sound(MUSIC[name], "music", true) end
end

function BattleStory:is_last()
    return self.index == #self.queue
end

function BattleStory:is_done()
    return self.index > 0 and not self.player
end

function BattleStory:played()
    return self.watched
end

-- helpers for the scene players

-- text = { ja = ..., en = ... }; the player's language, then English, then Japanese
function BattleStory.pick(t)
    return t[tex.language()] or t.en or t.ja or ""
end

function BattleStory.text(str, size, color, outline, thickness)
    return text.create_raw_text(str, math.floor(size * S), color, outline or color, false, thickness or 0, 0, 1, FONT)
end

function BattleStory:id(path)
    local id = self.ids[path]
    if id == nil then
        id = tex.get_texture(path)
        self.ids[path] = id
    end
    return id
end

function BattleStory:size(folder, key)
    local path = folder .. "/" .. key
    local info = self.sizes[path]
    if info == nil then
        info = tex.get_texture_info(folder, key) or false
        self.sizes[path] = info
    end
    return info and info.width or 0, info and info.height or 0
end

-- Draws song_select/battle_story/`key`. Without o.at it sits at its texture.json spot moved by (dx, dy); with o.at
-- (dx, dy) is where its anchor goes. o: sx, sy (scale about the anchor ax, ay, fractions of the size), fade, add,
-- mirror (flipped in place).
function BattleStory:put(key, dx, dy, o)
    o = o or {}
    local w, h = self:size("battle_story", key)
    local sx, sy = o.sx or o.s or 1, o.sy or o.s or 1
    local ax, ay = o.ax or 0.5, o.ay or 0.5
    local x, y = dx, dy
    if not o.at then x, y = dx + w * ax, dy + h * ay end
    tex.draw_texture(self:id("song_select/battle_story/" .. key), {
        x = x * S, y = y * S,
        x2 = w * S * (sx - 1), y2 = h * S * (sy - 1),
        origin = { w * S * sx * ax, h * S * sy * ay },
        fade = o.fade or 1,
        blend = o.add and "additive" or nil,
        mirror = o.mirror and "horizontal" or nil,
    })
end

-- the "hit to continue" pill; t: a text of battle_story_end
function BattleStory:draw_hint(t)
    local icon, gap, pad = 40, 8, 10
    local w = (pad + icon + gap + 16) * S + t.width
    local x, y, h = 640 * S - w / 2, 690, 36
    tex.draw_rounded_rect(x, (y - h / 2) * S, w, h * S, 1, BLACK, 0, BLACK)
    self:put("hint_face", x / S + pad + icon / 2, y, { at = true, s = icon / 55 })
    t:draw({ x = x + (pad + icon + gap) * S, y = y * S - t.height / 2 })
end

function BattleStory:backdrop(key)
    tex.draw_texture(self:id("game/battle_stage/" .. key), {})
end

function BattleStory.sound(name, preset)
    name = "battle_story_" .. name
    if audio.has_sound(name) then audio.play_sound(name, preset or "sound") end
end
