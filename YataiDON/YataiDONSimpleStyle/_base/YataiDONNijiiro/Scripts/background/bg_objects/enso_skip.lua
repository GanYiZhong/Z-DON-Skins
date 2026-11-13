-- 演奏スキップ — the cabinet's on-screen "hits remaining" cue, driven by the
-- engine's rule and pushed here through Background:handle_skip. Drawn from
-- draw_fore() so it lands in front of the whole lane/HUD.
local anim   = require("anim/sampler")

local EnsoSkip = {}
EnsoSkip.__index = EnsoSkip

-- 1080p skin pixels; the child skin loads texture.json at scale 1.0.
local CARD_CY          = 804          -- root placement of `skip_end` (y)
local NUM_HALF         = 172          -- numeral local half-extent
local TEXT_CY          = 418          -- banner origin after the reveal tween
local TEXT_TOP         = -145         -- lang shape local min y
local TEXT_H           = 288          -- lang shape local height

-- skip_card (sprite 35) labels: wait 0 / in 4 / on 9 / out 24, last frame 29.
local IN_F, ON_HOLD_F, OUT_F, END_F = 4, 23, 24, 29

function EnsoSkip.new()
    local self = setmetatable({}, EnsoSkip)
    self.card_clip  = anim.safe("anim/skip_card")
    self.panel_clip = anim.safe("anim/skip_panel")
    self.count      = 0          -- last count the engine reported
    self.held       = 0          -- kept across the reset fade-out
    self.total      = 10
    self.skipped    = false
    self.phase      = "off"      -- off | in | out
    self.card_f     = IN_F
    self.panel_f    = 0
    self.label      = 0          -- frame of the current count_N label
    self.last_ms    = nil
    self.tex        = {}
    return self
end

local function id(self, name)
    local cached = self.tex[name]
    if cached == nil then
        cached = tex.get_texture("game/skip/" .. name) or false
        self.tex[name] = cached
    end
    return cached or nil
end

-- Engine push, once per frame while the feature is armed.
function EnsoSkip:handle(state)
    if not state then return end
    local count = state.count or 0
    self.total   = state.total or 10
    self.skipped = state.skipped or false

    if count ~= self.count then
        if count > 0 then
            -- gotoAndPlay("count_N"): the panel restarts at that label
            self.phase   = "in"
            self.label   = self.panel_clip:label("count_" .. count) or 0
            self.panel_f = self.label
            if self.count == 0 then self.card_f = IN_F end   -- skip_end "in"
        else
            -- back to 0 = the arcade reset (a hit on the playing drum)
            self.phase  = "out"
            self.card_f = OUT_F
        end
        self.count = count
    end
end

function EnsoSkip:update(current_ms)
    local prev = self.last_ms
    self.last_ms = current_ms
    if not prev then return end
    local df = anim.frames(current_ms - prev)
    if df <= 0 then return end

    if self.phase == "in" then
        self.card_f = math.min(self.card_f + df, ON_HOLD_F)
        -- each count_N segment stops on label+9; count_10 keeps playing through
        -- the dim and the banner reveal and stops there
        local stop = (self.count >= self.total) and (self.label + 25) or (self.label + 9)
        self.panel_f = math.min(self.panel_f + df, stop)
    elseif self.phase == "out" then
        self.card_f = self.card_f + df
        if self.card_f >= END_F then self.phase = "off" end
    end
end

function EnsoSkip:draw()
    if self.phase == "off" then return end

    -- card alpha envelope, straight off sprite 35's own track
    local a = self.card_clip:get("skip_end_panel", self.card_f, "a")
    if a == nil then a = 1 end
    if a <= 0 then return end

    local panel = id(self, "panel")
    if panel then tex.draw_texture(panel, { fade = a }) end

    -- the numeral: before label+9 the OLD glyph is still on the card
    local off     = self.panel_f - self.label
    local live    = (self.count > 0) and self.count or self.held
    local shown   = live
    if live > 1 and off < 9 then shown = live - 1 end
    self.held     = live
    local digit   = (shown > 0) and (self.total - shown) or -1  -- count_N shows (10 - N)
    if digit >= 0 and digit <= 9 then
        -- frame index i of number.png is the digit 9 - i (baked "9".."0")
        local frame = 9 - digit
        local sy, ty = 1, 0
        if live > 1 then
            -- every count_N bounce is the same nine rows; sample #14@1 at label+off
            local bty, bsy = self.panel_clip:get("#14@1", 40 + off, "ty"),
                             self.panel_clip:get("#14@1", 40 + off, "sy")
            if bsy then sy, ty = bsy, bty or 0 end
        end
        local num = id(self, "number")
        if num then
            local h = 2 * NUM_HALF * sy
            tex.draw_texture(num, {
                frame = frame, fade = a,
                x = 0, y = CARD_CY + ty - NUM_HALF * sy - (CARD_CY - NUM_HALF),
                y2 = h - 2 * NUM_HALF,
            })
        end
    end

    -- past this point only the fired skip draws anything
    if not self.skipped then return end

    local dim = id(self, "dim")
    if dim then
        local da = self.panel_clip:get("#32@2", self.panel_f, "a")
        if da and da > 0 then tex.draw_texture(dim, { fade = da }) end
    end

    local banner = id(self, "text")
    if banner then
        local ty, sy, ba = self.panel_clip:get("lang_skip_text", self.panel_f, "ty"),
                           self.panel_clip:get("lang_skip_text", self.panel_f, "sy"),
                           self.panel_clip:get("lang_skip_text", self.panel_f, "a")
        sy = sy or 1
        ba = ba or 1
        if ba > 0 then
            -- texture.json parks the banner at its resting rect; re-anchor on TEXT_CY
            local cy = (ty and (CARD_CY + ty)) or TEXT_CY
            tex.draw_texture(banner, {
                fade = ba,
                y  = (cy + TEXT_TOP * sy) - (TEXT_CY + TEXT_TOP),
                y2 = TEXT_H * sy - TEXT_H,
            })
        end
    end
end

return EnsoSkip
