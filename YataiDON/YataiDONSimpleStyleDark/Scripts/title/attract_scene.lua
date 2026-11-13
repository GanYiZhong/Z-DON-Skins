-- YataiDONSimpleStyle v2: the title attract show (replaces Nijiiro's stub; our Videos folders are
-- empty, so the engine runs WARNING -> this scene -> WARNING ...). Festival stage, the block-pixel
-- YATAI DON logo with a 2-frame shine every 4 s, Momo (left) and Hoshi (right) drumming one taiko,
-- drumming it. Hoshi's bubble shows every 8 s. The start prompt is the engine's own text (no second one).
-- Smooth-loop rules (reports/fix1029_title.md): the engine never builds this object itself any more;
-- warning_screen.lua owns one instance and plays WARNING -> this show -> WARNING ... inside ONE Lua object,
-- because the engine's own WARNING <-> ATTRACT hand-off draws 2 black frames (title.cpp scene_manager
-- passes through the empty video states). Each drummer holds its last drum frame (drum_l / drum_r swap on
-- every hit) instead of popping between the 3/4 "turn" view (no sticks) and the front drum frames.
-- All coordinates are logical 1920x1080 (ss/v2_front.py: TITLE_DECK, the logo position).
local UI = require("global.ss_ui")
local PromptChips = require("title.prompt_chips")
local FX = require("title.front_fx")

AttractScene = {}
AttractScene.__index = AttractScene

local DURATION  = 25600          -- 8 loops of the 16-step pattern
local STEP_MS   = 200            -- 8th notes at 150 BPM
local MOMO_PAT  = "x.x.x.x.x.x.xxx."
local HOSHI_PAT = "..x...x...x.x.x."
local DECK      = 846            -- the stage deck top (feet)
local MOMO_CX, HOSHI_CX = 726, 1194
local DRUM_CX, DRUM_FACE_Y = 960, 684
local BUBBLE_TIP_X, BUBBLE_TIP_Y = 1356, 642   -- the tail tip, just right of Hoshi's head
local BUBBLE_TAIL_L = 36                        -- the tail sits 12U from the bubble's left edge
local SHINE_EVERY, SHINE_MS = 4000, 50          -- 50 ms = 3 refreshes at 60 Hz, 6 at 120 (66 gave 4/3/4)
-- polish: the logo letters (title/ss_front/logo_l, frame 3 k + shine) drop in one by one at the start of
-- the show, then a wave runs through them once per 4 s cycle (offset from the shine). All motion is
-- whole-U offsets on a 50 ms cadence.
local LOGO_CELL = 18
local LOGO_COLS = { 0, 6, 12, 18, 24, 32, 38, 44 }
local DROP_T0, DROP_STAGGER = 100, 50          -- letter k starts at DROP_T0 + k * 50 ms
local DROP = { -120, -60, -18, 0, -9, 0 }      -- y offset per 50 ms step (a drop and one small bounce)
local WAVE_AT, WAVE_STAGGER, WAVE_MS, WAVE_DY = 2000, 50, 100, -9
local LOGO_IN = DROP_T0 + 7 * DROP_STAGGER + #DROP * 50   -- 850: the shine waits until all have landed
-- when the last letter lands, both drummers cheer (400 ms) and a burst pops at each end of the logo
local CHEER_MS = 400
local LAND_BURSTS = { { 480, 117 }, { 1443, 117 } }
-- the clouds (positions at clock 0; they drift right with the clock): same set as the warning screen
AttractScene.CLOUDS = { { 96, 54, "M" }, { 1656, 330, "S" }, { 600, 384, "S" }, { 1122, 24, "S" } }
-- the note pops: Momo's dons jump off the drum's left rim, Hoshi's kas off its right rim
local POP_L, POP_R, POP_Y = 924, 996, 672

-- the frame a drummer shows: the drum frame of its last hit, held until the next hit (sticks always in
-- hand, one arm swap per hit, front view like the drum frames themselves)
local function drum_expr(side)
    return side == 1 and "drum_l" or "drum_r"
end
AttractScene.drum_expr = drum_expr

function AttractScene.new()
    local self = setmetatable({}, AttractScene)
    UI.reset()
    self.t0 = tex.get_current_ms()
    self.now = self.t0
    self.t_stage  = tex.get_texture("title/ss_front/stage")
    self.t_logo   = tex.get_texture("title/ss_front/logo_l")
    self.clouds = FX.Clouds.new("title", AttractScene.CLOUDS)
    self.pops = FX.Pops.new("title")
    self.momo  = UI.Mascot.new({ char = "momo", role = "scene", beat = false })
    self.hoshi = UI.Mascot.new({ char = "hoshi", role = "scene", beat = false })
    self.momo_side, self.hoshi_side = 0, 1   -- they start on opposite hands
    self:restart(self.t0)
    return self
end

-- start the show over at ms (warning_screen.lua calls this each loop; nothing is reloaded)
function AttractScene:restart(ms)
    self.t0 = ms
    self.now = ms
    self.step = -1
    self.burst_t = -100000
    if self.pops then self.pops:clear() end
end

function AttractScene:update(current_ms)
    self.now = current_ms
    local t = current_ms - self.t0
    local step = math.floor(t / STEP_MS)
    if step ~= self.step then
        self.step = step
        local i = step % 16 + 1
        local quiet = t >= LOGO_IN and t < LOGO_IN + CHEER_MS     -- the landing cheer: no hits
        local m = MOMO_PAT:sub(i, i) == "x" and not quiet
        local h = HOSHI_PAT:sub(i, i) == "x" and not quiet
        self.momo:update(current_ms)
        self.hoshi:update(current_ms)
        if m then
            self.momo_side = 1 - self.momo_side
            self.pops:emit(0, POP_L, POP_Y, -1, current_ms)
        end
        if h then
            self.hoshi_side = 1 - self.hoshi_side
            self.pops:emit(1, POP_R, POP_Y, 1, current_ms)
        end
        if m and h then self.burst_t = current_ms end     -- a big hit: the event burst on the face
    end
    self.momo:update(current_ms)
    self.hoshi:update(current_ms)
end

-- the logo: letter k's y offset now (nil = not in yet)
local function letter_dy(t, k)
    local d = t - (DROP_T0 + k * DROP_STAGGER)
    if d < 0 then return nil end
    local f = math.floor(d / 50) + 1
    if f <= #DROP then return DROP[f] end
    if t >= LOGO_IN then
        local w = (t % SHINE_EVERY) - WAVE_AT - k * WAVE_STAGGER
        if w >= 0 and w < WAVE_MS then return WAVE_DY end
    end
    return 0
end

function AttractScene:draw_logo(t)
    if not self.t_logo then return end
    local f = 0
    if t >= LOGO_IN then
        local s = t % SHINE_EVERY
        if s < SHINE_MS then f = 1 elseif s < 2 * SHINE_MS then f = 2 end
    end
    for k, col in ipairs(LOGO_COLS) do
        local dy = letter_dy(t, k - 1)
        if dy then
            tex.draw_texture(self.t_logo, { frame = (k - 1) * 3 + f, x = col * LOGO_CELL, y = dy })
        end
    end
end

function AttractScene:draw()
    tex.draw_texture(self.t_stage)
    self.clouds:draw(self.now)
    PromptChips.draw(self.now)
    local t = self.now - self.t0
    self:draw_logo(t)
    local cheer = t >= LOGO_IN and t < LOGO_IN + CHEER_MS
    self.momo:draw(MOMO_CX, DECK, { expr = cheer and "cheer" or drum_expr(self.momo_side) })
    self.hoshi:draw(HOSHI_CX, DECK, { expr = cheer and "cheer" or drum_expr(self.hoshi_side) })
    for _, b in ipairs(LAND_BURSTS) do UI.burst(b[1], b[2], t - LOGO_IN) end
    UI.burst(DRUM_CX, DRUM_FACE_Y, self.now - self.burst_t)
    self.pops:draw(self.now)
    -- Hoshi's line: 2.8 s of every 8 s; the tail tip sits right of his head
    local b = t % 8000
    if b >= 2000 and b < 4800 then
        local w = UI.bubble_width("title_invite", 36)
        UI.bubble("title_invite", BUBBLE_TIP_X, BUBBLE_TIP_Y, { cx = BUBBLE_TIP_X - BUBBLE_TAIL_L + w / 2 })
    end
end

function AttractScene:is_finished()
    return self.now - self.t0 >= DURATION
end

function AttractScene:close() end

return AttractScene
