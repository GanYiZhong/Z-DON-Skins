ScoreHistory = {}
ScoreHistory.__index = ScoreHistory

local S = 0.95
local DIGIT_O = 40
local PANEL_CX, PANEL_CY = 186.5, 621.0
local BEST_RIGHT, BEST_Y, BEST_STEP = 282.0, 631.0, 19.0
local ICON_X, ICON_Y = 80.0, 630.0
local TITLE_CX, TITLE_CY = 185.0, 604.5
local DIFF_ONI, DIFF_URA = 3, 4
local URA_SWAP_MS = 1500
local SHOW_DELAY_MS = 0

local T = {}
local function tx(name)
    local t = T[name]
    if t == nil then
        local id = tex.get_texture("player_board/" .. name)
        local info = id and tex.get_texture_info("player_board", name)
        t = id and { t = id, w = info and info.width or 0, h = info and info.height or 0 } or false
        T[name] = t
    end
    return t or nil
end

local function put(name, cx, cy, frame)
    local t = tx(name)
    if not t then return end
    tex.draw_texture(t.t, { x = cx - t.w / 2, y = cy - t.h / 2, center = true, scale = S, frame = frame })
end

local title

function ScoreHistory.new(available, is_shinuchi, current_ms)
    local self = setmetatable({}, ScoreHistory)
    self.t0 = current_ms
    self.now = current_ms
    self.best = {}
    for _, e in ipairs(available) do self.best[e.diff] = e.score end
    self.has_ura = self.best[DIFF_URA] ~= nil
    return self
end

function ScoreHistory:update(current_ms)
    self.now = current_ms
end

function ScoreHistory:draw(open_ms)
    if open_ms < SHOW_DELAY_MS then return end
    if tex.get_skin_config("player_board_on") == nil or tex.current_screen() ~= "SONG_SELECT" then return end
    local ura = self.has_ura and (math.floor((self.now - self.t0) / URA_SWAP_MS) % 2 == 1)
    put("best_panel", PANEL_CX, PANEL_CY)
    put("best_icon", ICON_X, ICON_Y, ura and 4 or 3)
    if title == nil then
        local s = tex.skin_text("pboard_best")
        title = (s and s ~= "") and text.create_raw_text(s, 18, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false,
                                                         3.0 / tex.get_screen_scale(), 1.0) or false
    end
    if title then
        title:draw({ x = math.floor(TITLE_CX - title.width / 2 + 0.5), y = math.floor(TITLE_CY - title.height / 2 + 0.5) })
    end
    local s = tostring(math.max(0, math.min(99999999, self.best[ura and DIFF_URA or DIFF_ONI] or 0)))
    local sd = tx("sdigit")
    if not sd then return end
    for i = 1, #s do
        tex.draw_texture(sd.t, { x = BEST_RIGHT - BEST_STEP * (i - 1) - DIGIT_O, y = BEST_Y - DIGIT_O, center = true,
                                 scale = S, frame = s:byte(#s - i + 1) - 48 })
    end
end

return ScoreHistory
