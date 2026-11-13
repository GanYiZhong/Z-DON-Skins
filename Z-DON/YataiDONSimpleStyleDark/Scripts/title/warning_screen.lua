-- YataiDONSimpleStyle v2: the warning screen as one dialog (ちゅうい). The window opens in 3 frames
-- (height 33 % -> 66 % -> 100 %, 50 ms each), Momo drums the small taiko on the dialog's floor line
-- while the notice is read, and the window closes in 2 frames. Replaces Nijiiro's warning board
-- (no Nijiiro / Green art is loaded). Coordinates: logical 1920x1080 (ss/v2_front.py WARN_*).
-- This object is also the whole title loop: WARNING (6.5 s) -> the attract show (attract_scene.lua, 25.6 s)
-- -> WARNING ..., and is_finished() is never true. The engine's own hand-off (title.cpp scene_manager:
-- WARNING -> ATTRACT_VIDEO -> ATTRACT_CAMERA, and ATTRACT_CAMERA -> OP_VIDEO -> WARNING) draws nothing for
-- the 2 frames it spends in the empty video states, i.e. a black flash at every switch. The show is built
-- here up front, so the switch also loads nothing.
local UI = require("global.ss_ui")
local PromptChips = require("title.prompt_chips")
local Attract = require("title.attract_scene")
local FX = require("title.front_fx")

WarningScreen = {}
WarningScreen.__index = WarningScreen

local X0, Y0, X1, Y1 = 249, 168, 1671, 834     -- dialog outer edge
local FLOOR = 648                              -- the floor line inside the dialog
local MOMO_CX = 408
local DURATION = 6500
local OPEN_F, CLOSE_F = 50, 50
-- the words, in the player's language (ss/strings.py): the title centred on the gold band, the lines
-- left-aligned in the text column (ink from x 795, centres 84 apart; 870 px of room)
local TITLE_CX, TITLE_CY = 960, 198
local LINE_X, LINE_Y0, LINE_PITCH = 795, 400, 84
local LINES = { "warn_line4", "warn_line1", "warn_line2", "warn_line3" }
-- polish: once the window is open the lines come in one by one (100 ms apart, title first), so the eye
-- reads them in order; Momo's hits pop a don note off the small taiko's left rim
local LINE_T0, LINE_STAGGER = 150, 100
local POP_X, POP_Y = 540, 522

function WarningScreen.new(current_ms)
    local self = setmetatable({}, WarningScreen)
    UI.reset()
    self.attract = Attract.new()         -- (resets UI's cache too; nothing is cached yet)
    self.in_attract = false
    self.start_ms = current_ms
    self.now = current_ms
    self.t_bg = tex.get_texture("title/ss_front/warn_bg")
    self.t_dialog = tex.get_texture("title/ss_front/warn_dialog")
    self.momo = UI.Mascot.new({ char = "momo", role = "menu", beat = false })
    self.clouds = FX.Clouds.new("title", Attract.CLOUDS)
    self.pops = FX.Pops.new("title")
    self.side = 0
    self.last_hit = -1
    return self
end

function WarningScreen:update(current_ms)
    self.now = current_ms
    if self.in_attract then
        self.attract:update(current_ms)
        if self.attract:is_finished() then         -- back to the warning on the same frame
            self.in_attract = false
            self.start_ms = current_ms
            self.side, self.last_hit = 0, -1
        else
            return
        end
    end
    local t = current_ms - self.start_ms
    if t >= DURATION then                           -- on to the show on the same frame
        self.in_attract = true
        self.attract:restart(current_ms)
        self.attract:update(current_ms)
        return
    end
    self.momo:update(current_ms)
    -- a hit every 400 ms once the window is open, resting every 4th beat; Momo holds the drum frame of
    -- her last hit (one arm swap per hit; no pop to the stick-less 3/4 view in between)
    if t > 600 and t < DURATION - 400 then
        local n = math.floor((t - 600) / 400)
        if n ~= self.last_hit then
            self.last_hit = n
            if n % 4 ~= 3 then
                self.side = 1 - self.side
                self.pops:emit(0, POP_X, POP_Y, 1, current_ms)
            end
        end
    end
end

function WarningScreen:is_finished()
    return false
end

-- the dialog shell at a fraction of its height (window open / close frames)
local function shell(frac)
    local h = math.floor((Y1 - Y0) * frac / UI.U) * UI.U
    local y = UI.grid((Y0 + Y1) / 2 - h / 2)
    UI.chrome.dialog(X0, y, X1 - X0, h)
end

function WarningScreen:draw()
    if self.in_attract then return self.attract:draw() end
    tex.draw_texture(self.t_bg)
    self.clouds:draw(self.now)
    PromptChips.draw(self.now)    -- the engine prints its start prompt over this screen too
    local t = self.now - self.start_ms
    local left = DURATION - t
    if t < OPEN_F then shell(1 / 3)
    elseif t < 2 * OPEN_F then shell(2 / 3)
    elseif left < CLOSE_F then shell(1 / 3)
    elseif left < 2 * CLOSE_F then shell(2 / 3)
    else
        tex.draw_texture(self.t_dialog)
        UI.draw_text(UI.text_key("warn_title", 36, "ink"), TITLE_CX, TITLE_CY, "c")
        for i, key in ipairs(LINES) do
            if t >= LINE_T0 + (i - 1) * LINE_STAGGER then
                local tt = UI.text_key(key, 36, "ink")
                UI.draw_text(tt, LINE_X - UI.text_pad(tt), LINE_Y0 + (i - 1) * LINE_PITCH, "l")
            end
        end
        self.momo:draw(MOMO_CX, FLOOR, { expr = Attract.drum_expr(self.side) })
        if left >= 2 * CLOSE_F then self.pops:draw(self.now) end
    end
end
