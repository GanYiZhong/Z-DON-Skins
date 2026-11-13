-- No webcam (webcam_number -1, or it would not open): the scan fails like collabo_smart's failed_end (sprite 146).
-- The shutter drops over the camera window, the rest of the screen dims, the notes box pops up, then black.
CameraFailed = {}
CameraFailed.__index = CameraFailed

local S = tex.get_screen_scale()
local DIR = "campaign/camera_failed"
local F = 1000 / 60
local END_F = 586
-- everything but the camera window (330, 60.3)-(950, 522.9) dims
local DIM = { { 0, 0, 330, 720 }, { 950, 0, 330, 720 }, { 330, 0, 620, 60.3 }, { 330, 522.9, 620, 197.1 } }
local CUES = { { 0, "smart_se_shutterdown" }, { 39, "smart_se_shutterclose" }, { 39, "smart_vo_failed" } }

local function play(name)
    if audio.has_sound(name) then audio.play_sound(name, name:find("_vo_") and "voice" or "sound") end
end

local function ramp(f, at, len) return math.max(0, math.min(1, (f - at) / len)) end
local function ease_in(u) return u * u end
local function ease_out(u) return u * (2 - u) end

-- shutter offset from its rest: falls in 40 f, bounces 30 px and lands again
local function shutter_dy(f)
    if f < 40 then return -488 * (1 - ease_in(f / 40)) end
    if f < 47 then return -10.6 - 29.4 * ease_out(ramp(f, 41, 6)) end
    if f < 51 then return -37.5 * (1 - ease_in(ramp(f, 48, 3))) end
    return 0
end

function CameraFailed.new(now)
    local self = setmetatable({}, CameraFailed)
    self.tex = {}
    for _, key in ipairs({ "shutter", "failed_text", "failed_don", "notes" }) do
        self.tex[key] = tex.get_texture(DIR .. "/" .. key)
    end
    self.box = tex.get_texture("campaign/smart_scan/keep_box")
    self.t0, self.now, self.cue_f = now, now, -1
    return self
end

function CameraFailed:frames() return (self.now - self.t0) / F end

function CameraFailed:update(now)
    self.now = now
    local f = self:frames()
    for _, cue in ipairs(CUES) do
        if cue[1] > self.cue_f and cue[1] <= f then play(cue[2]) end
    end
    self.cue_f = f
end

function CameraFailed:is_done() return self:frames() >= END_F end

-- inside the camera window: draw before the holed background
function CameraFailed:draw_window()
    local f, tx = self:frames(), self.tex
    tex.draw_texture(tx.shutter, { y = shutter_dy(f) * S })
    local fade = ramp(f, 40, 19)
    tex.draw_texture(tx.failed_text, { fade = fade })
    tex.draw_texture(tx.failed_don, { fade = fade })
end

-- over the whole scene
function CameraFailed:draw_overlay()
    local f = self:frames()
    local dim = math.floor(255 * 0.641 * ramp(f, 40, 20))
    for _, r in ipairs(DIM) do tex.draw_rect(r[1] * S, r[2] * S, r[3] * S, r[4] * S, 0, 0, 0, dim) end
    if f >= 120 then
        local fade = ease_in(ramp(f, 120, 5))
        tex.draw_texture(self.box, { y = -43 * S, fade = fade }) -- the keep box, 43 px higher
        tex.draw_texture(self.tex.notes, { fade = fade })
    end
    if f >= 526 then
        tex.draw_rect(0, 0, tex.get_screen_width(), tex.get_screen_height(), 0, 0, 0, 255 * ramp(f, 526, 60))
    end
end
