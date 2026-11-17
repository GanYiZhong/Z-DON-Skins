-- Arcade best_score_mc bar with a live-rendered "New Top Score!" caption.
HighScoreIndicator = {}
HighScoreIndicator.__index = HighScoreIndicator

-- `border` is already in 1080p stage px, so create_text wants border / screen_scale.
local function outline(border) return border / tex.get_screen_scale() end

local TEXT_CX_REL = 154.4
local TEXT_CY_REL = 31.6
local BAR_BASE_X  = { [0] = 64, [1] = 1020 }  -- texture.json high_score frame 0 (1P) / 1 (2P)
local BAR_BASE_Y  = 266

function HighScoreIndicator.new(score_diff, is_2p)
    local self = setmetatable({}, HighScoreIndicator)
    self.start_ms = nil
    self.y_offset = 24
    self.fade_val = 0
    self.score_diff = score_diff
    self.is_2p      = is_2p
    self.t_label = tex.get_texture("result/score/high_score")
    self.t_num   = tex.get_texture("result/score/high_score_num")
    self.sc_margin = 14
    self.text = text.create_text("result_topscore_text", { 255, 255, 255, 255 }, { 70, 35, 10, 255 },
        false, outline(4.0), 0)
    return self
end

local ha_ok, hs_anim = pcall(require, "anim/sampler")
if not ha_ok then hs_anim = { safe = function()
    -- sampler.lua itself is missing: hand back the same NULL clip shape it would
    local n = {}
    n.at = function() return nil end; n.get = function() return nil end
    n.label = function() return nil end; n.has = function() return false end
    n.first = function() return 0 end;  n.last = function() return 0 end
    return n
end } end
local BS       = hs_anim.safe("anim/best_score")
local BS_START = BS:label("start") or 5
local BS_END   = math.max(BS_START, BS:last())

function HighScoreIndicator:update(current_ms)
    if not self.start_ms then self.start_ms = current_ms end
    local f = BS_START + (current_ms - self.start_ms) * 0.06
    if f > BS_END then f = BS_END end
    self.y_offset = BS:get("#196@0", f, "ty") or 0
    self.fade_val = BS:get("#196@0", f, "a") or 1
end

function HighScoreIndicator:draw()
    local p_idx = self.is_2p and 1 or 0
    local y    = self.y_offset
    local fade = self.fade_val
    if self.t_label then tex.draw_texture(self.t_label, { y = y, fade = fade, index = p_idx }) end
    -- Live caption, centred on the arcade's ink-centre target.
    if self.text then
        local cx = BAR_BASE_X[p_idx] + TEXT_CX_REL
        local cy = BAR_BASE_Y + TEXT_CY_REL + y
        self.text:draw({
            x = math.floor(cx - self.text.width / 2 + 0.5),
            y = math.floor(cy - self.text.height / 2 + 0.5),
            fade = fade,
        })
    end
    if self.t_num and self.score_diff > 0 then
        local str = tostring(self.score_diff)
        for i = 1, #str do
            local d = tonumber(string.sub(str, #str - i + 1, #str - i + 1)) or 0
            tex.draw_texture(self.t_num, { frame = d, x = -((i - 1) * self.sc_margin), y = y, fade = fade, index = p_idx })
        end
    end
end
