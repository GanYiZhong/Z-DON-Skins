-- YataiDONSimpleStyle v2: the ending banner object behind ClearAnimation / FCAnimation / FailAnimation
-- (engine EndingAnimation). It plays the sound, tells the portrait (game/ss_play.lua), and draws the
-- same generated clip the background's Ending object uses (game/ending_anim/ending_<kind>.lua), at
-- the same place: so the look is identical whichever side draws it (the engine calls this draw only
-- when the background script has no draw_ending).

local UI = require("global.ss_ui")
local Play = require("game/ss_play")

local M = {}
M.__index = M

local FRAME_MS = 1000.0 / 60.0
local STAGE_Y = 276
local CLIP_X, CLIP_Y = 1209, 109.5
local CLIPS = { donderful = "ending_donderful", full_combo = "ending_fullcombo",
                clear = "ending_clear", fail = "ending_fail" }

function M.new(kind, is_2p, sound)
    local self = setmetatable({}, M)
    local name = CLIPS[kind]
    local ok, data = pcall(require, "game/ending_anim/" .. name)
    self.data = (ok and type(data) == "table" and data.frames) and data or nil
    self.subset = name .. "_anim"
    tex.load_folder("game", self.subset)
    self.ids = {}
    self.t0 = nil
    self.y = STAGE_Y
    if is_2p then
        local p2 = tex.get_skin_config("game_p2_y")
        self.y = STAGE_Y + ((p2 and p2.y) and (p2.y - 184 * tex.get_screen_scale()) or 0)
    end
    Play.ending(is_2p and 2 or 1, kind)
    if sound then audio.play_sound(sound, "sound") end
    return self
end

function M:id_of(shape)
    local id = self.ids[shape]
    if id == nil then
        id = tex.get_texture("game/" .. self.subset .. "/s" .. shape) or false
        self.ids[shape] = id
    end
    return id or nil
end

function M:update(current_ms)
    self.now = current_ms
    if not self.t0 then self.t0 = current_ms end
    if self.voice and not self.voice_played and current_ms - self.t0 >= 1000 then
        self.voice_played = true
        audio.play_sound(self.voice, "voice")
    end
end

function M:draw()
    local d = self.data
    if not d or not self.t0 then return end
    local f = math.floor(((self.now or self.t0) - self.t0) / FRAME_MS)
    if f >= d.nframes then
        local span = d.nframes - d.loop_at
        f = (span > 0) and (d.loop_at + (f - d.loop_at) % span) or (d.nframes - 1)
    end
    local rows = d.frames[f + 1]
    if not rows then return end
    for i = 1, #rows do
        local r = rows[i]
        local s = d.shapes[r[1]]
        local id = s and self:id_of(r[1])
        if id then
            tex.draw_texture(id, { x = CLIP_X + r[2] - s[3], y = self.y + CLIP_Y + r[3] - s[4], fade = UI.solid(r[7]) })
        end
    end
end

return M
