-- SimpleStyle v2 (meta): the skin's pixel font and an ink 1U outline. ALL.Net icon overlay, plus the 「M曲」 song-max plate on the GAME screen.
-- Every screen draws this overlay, so it also carries the screen-entry wipe (SSM.screen_wipe: the house
-- sky dither in place of the engine's translucent black screen fade, which skin_config cuts to 1 ms).
local SSM = require("global.ss_meta")
local UI = SSM.UI

AllNetIcon = {}
AllNetIcon.__index = AllNetIcon

function AllNetIcon.new(online)
    local self = setmetatable({}, AllNetIcon)
    self.online    = online
    self.indicator = tex.get_texture("global/overlay/allnet_indicator")
    self.params    = { frame = online and 2 or 0, x = 0, y = 0 }   -- reused every draw, no per-frame table garbage
    return self
end

function AllNetIcon:update(current_ms, online)
    self.online = online
    self.params.frame = online and 2 or 0
end

local SONG_MAX_CX, SONG_MAX_CY = 1814, 122

function AllNetIcon:draw_song_max()
    if not tex.song_limit then return end
    local limit = tex.song_limit()
    if not limit or limit <= 0 then return end
    if self._song_max_n ~= limit then
        self._song_max   = UI.text((tex.skin_text("song_num_max"):gsub("{0}", tostring(limit))), 24, "paper")
        self._song_max_n = limit
    end
    local t = self._song_max
    if not t then return end
    -- id 3 = the genre <-> song-number cross-fade; sharing it keeps both plate halves in step.
    if not self._plate_fade then self._plate_fade = tex.get_animation(3, false) end
    local fade = UI.solid(self._plate_fade and self._plate_fade.attribute or 1.0)
    if fade <= 0 then return end
    UI.draw_text(t, SONG_MAX_CX, SONG_MAX_CY, "c")
end

function AllNetIcon:draw_icon(x, y)
    local p = self.params
    p.x, p.y = x, y
    tex.draw_texture(self.indicator, p)
end

function AllNetIcon:draw(x, y)
    local screen = tex.current_screen and tex.current_screen() or ""
    SSM.screen_wipe()
    if screen == "GAME" or screen == "GAME_DAN" then
        if screen == "GAME" and not (tex.in_transition and tex.in_transition()) then
            self:draw_song_max()
        end
        self:draw_icon(x, y)
        if _G.g_active_enso_skip then _G.g_active_enso_skip:draw() end
        return
    end
    if screen == "LOADING" then
        return
    end
    self:draw_icon(x, y)
end
