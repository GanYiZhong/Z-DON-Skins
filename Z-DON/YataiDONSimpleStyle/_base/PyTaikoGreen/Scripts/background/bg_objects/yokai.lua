local DonBGBase       = require("background/bg_objects/donbg/base")
local Fever           = require("background/bg_objects/fever")
local Footer          = require("background/bg_objects/footer")
local Dancer          = require("background/bg_objects/dancer")
local RendaController = require("background/bg_objects/renda")
local ChibiController = require("background/bg_objects/chibi")
local BaseChibi       = require("background/bg_objects/chibi/base")
local ChibiWave       = require("background/bg_objects/chibi/wave")
local Timing          = require("background/bg_objects/timing")

local chain_moves, sum = Timing.chain_moves, Timing.sum

-- Every Yo-kai Watch enso (yokai, hatsukoi, matsuri, tokoroten, yougota) shares the street, don
-- band, fever, chibi, renda and footer byte for byte: those load from SHARED. Only the dancers
-- differ; each collab file passes its dancer class and folder.
local SHARED      = "background/collab/yokai"
local MAX_DANCERS = 5

-- Renda is renda_a_01's flight with Yo-kai Watch pictures; bad hits get the default tamashii.

-- Don band: purple medal tiles scroll one tile left every 5.33 s under two rows of logos that
-- scroll one 640px pair in the same time. Clearing fades in the yellow tiles, a miss streak
-- (only while not cleared) the grey set. Ambient, in ms.
local DONBG = { layers = {
    { key = "background", ms = 5333 },
    { key = "overlay", ms = 5333, dx = -640, tile = 640, x = 1 },
    { key = "overlay", ms = 5333, dx = -640, tile = 640, x = 321, y = 66 },
} }

-- Stage: the street. Clearing slides it 175px down to show the sky, where fireworks burst
-- once it has settled; losing the clear slides it back up. The slide is in beats, the
-- fireworks ambient (Lumen frames).
local SLIDE = { distance = 175, beats = 1.475 }

-- The fireworks: a 294-frame show of bursts { frame, centre x, centre y, size }, each 16
-- pictures two frames apiece, drawn additive.
local FIREWORK_SIZE, FIREWORK_FRAMES, SHOW_FRAMES = 256, 16, 294
local SHOW = {
    { 0, 316, 472, 0.5 }, { 7, 686, 472, 0.5 }, { 12, 442, 415, 0.4 }, { 15, 1203, 339, 1.12 },
    { 19, 877, 480, 0.4 }, { 65, 1224, 413, 0.6 }, { 68, 948, 510, 0.6 }, { 73, 340, 524, 0.6 },
    { 84, 594, 523, 0.5 }, { 87, 690, 427, 0.6 }, { 90, 82, 363, 0.6 }, { 95, 906, 483, 0.6 },
    { 137, 38, 443, 1.12 }, { 142, 1222, 443, 0.6 }, { 145, 389, 423, 0.3 }, { 148, 50, 427, 0.6 },
    { 153, 282, 511, 0.5 }, { 159, 976, 517, 1.12 }, { 164, 634, 463, 0.8 }, { 170, 692, 499, 0.6 },
    { 175, 405, 434, 0.5 }, { 216, 1060, 463, 1.12 }, { 221, 381, 502, 0.6 }, { 224, 749, 576, 0.6 },
    { 227, 589, 545, 0.5 }, { 232, 1088, 389, 0.5 }, { 238, 1163, 426, 1.12 }, { 243, 870, 438, 0.8 },
    { 246, 367, 500, 1.0 }, { 249, 668, 457, 0.6 }, { 254, 399, 414, 0.3 },
}

local function lumen_frame(ms) return ms * 60 / 1000 end

local YokaiStage   = {}
YokaiStage.__index = YokaiStage

function YokaiStage.new(bpm)
    local self = setmetatable({}, YokaiStage)
    tex.load_folder(SHARED, "bg_normal/bg_0")
    tex.load_folder(SHARED, "bg_fever/bg_fever_0")
    self._id_bg       = tex.get_texture(SHARED .. "/bg_0/background") or 0
    self._id_firework = tex.get_texture(SHARED .. "/bg_fever_0/firework") or 0
    self.beat   = 60000 / bpm
    self.offset = 0
    self.moves  = {}
    self.clear  = false
    return self
end

function YokaiStage:y() return self.offset + sum(self.moves) end

-- slides to the sky (or back to the street) from wherever it is
function YokaiStage:set_clear(is_clear)
    local scale = tex.get_screen_scale()
    self.offset = self:y()
    self.clear, self.show_t0 = is_clear, nil
    local target = is_clear and SLIDE.distance * scale or 0
    self.moves = chain_moves({ { SLIDE.beats, (target - self.offset) / scale } }, self.beat, scale)
end

function YokaiStage:update(current_time_ms, bpm)
    if bpm then self.beat = 60000 / bpm end
    self.now = current_time_ms
    for _, m in ipairs(self.moves) do m:update(current_time_ms) end
    local settled = not self.moves[1] or self.moves[1].is_finished
    if self.clear and settled and not self.show_t0 then self.show_t0 = current_time_ms end
end

function YokaiStage:draw_fireworks()
    local scale = tex.get_screen_scale()
    local f = lumen_frame(self.now - self.show_t0) % SHOW_FRAMES
    for _, b in ipairs(SHOW) do
        local k = math.floor((f - b[1]) / 2)
        if k >= 0 and k < FIREWORK_FRAMES then
            local size = FIREWORK_SIZE * b[4]
            tex.draw_texture(self._id_firework, {
                frame = k,
                x = (b[2] - size / 2) * scale, y = (b[3] - size / 2) * scale,
                x2 = (size - FIREWORK_SIZE) * scale, y2 = (size - FIREWORK_SIZE) * scale,
            })
        end
    end
end

function YokaiStage:draw()
    tex.draw_texture(self._id_bg, { y = self:y() })
    if self.show_t0 then self:draw_fireworks() end
end

function YokaiStage:destroy()
    tex.unload_folder(SHARED, "bg_normal/bg_0")
    tex.unload_folder(SHARED, "bg_fever/bg_fever_0")
end

-- Fever: two yokai crowds (left, right) jump up, bounce 40px a beat and drop away
local FEVER = { rise = 260, peak = 40, bounce = 40, drop = 300 }

-- Dancers jump up from below the stage, land with a squash and dance; removed, they hop up and
-- drop away. Timed in beats; poses are offsets from where each stands. The landing squashes to
-- `sy` (0.94); `dip` moves it down for dancers pivoting above their feet.
local function enter(land, dip, sy)
    sy = sy or 0.94
    return {
        beats = 2, key = "loop",
        { 0.2,   0, 0, 394, to = { 0, -40, "out" } },
        { 0.9,   0, 0, -40, to = { 0, 0, "in" } },
        { 1.375, land, 0, 0, to = { nil, dip or 0, "out", sy = sy } },
        { 1.6,   land, 0, dip or 0, sy = sy, to = { nil, 0, "in", sy = 1 } },
        { 1.85,  land, 0, 0 },
    }
end

local function leave(frame)
    return {
        beats = 1.125, key = "loop",
        { 0,    frame, 0, 0 },
        { 0.2,  frame, 0, 0, to = { 0, -40, "out" } },
        { 0.45, frame, 0, -40, to = { 0, 394, "in" } },
    }
end

-- one pose that squashes (sy < 1) or stretches about the feet: `down` beats to sy, `hold`,
-- `back` beats to 1
local function squash(frame, sy, down, hold, back)
    return { frame, down, to = { nil, nil, "out", sy = sy } }, { frame, hold, sy = sy },
        { frame, back, sy = sy, to = { nil, nil, "in", sy = 1 } }
end

-- Whisper floats: up 10px over a beat, back down over the next
local function bob(beats)
    local poses = { length = beats }
    for i = 0, beats - 1, 2 do
        poses[#poses + 1] = { i, 0, 0, 10, to = { 0, 0 } }
        poses[#poses + 1] = { i + 1, 0, 0, 0, to = { 0, 10 } }
    end
    return poses
end

-- an 8-picture loop a quarter beat each from `first` (Whisper's body and outline)
local function cycle(beats, first, key)
    local poses = { length = beats, key = key }
    for i = 0, beats * 4 - 1 do poses[#poses + 1] = { i * 0.25, first + i % 8, 0, 0 } end
    return poses
end

local DANCER_CENTERS    = { 173, 407, 640, 873, 1107 } -- Whisper, Keita, Jibanyan, Fumika, Komasan
local DANCER_DRAW_ORDER = { 5, 1, 4, 2, 3 }            -- outer pairs first, the centre on top
-- dancer index by join order: joins fill the centre, left, right, far-left, far-right slots
local DANCER_JOIN_ORDER = { 4, 3, 2, 1, 0 }

-- Chibi for good hits: Jibanyan's head fades in growing from half size, then zigzags across,
-- 33px up and down every half beat
local CHIBI = {
    key = "1", start_size = 0.5, fade_in = true,
    hop  = { from = { -424, 13 }, peak = { -199, -24 }, up = 0.5 },
    run  = { x = -199, y = -24, distance = 1130 },
    wave = { first = 33, height = 33, beats = 0.5 },
}

-- Background

local YokaiBackground = {}
YokaiBackground.__index = YokaiBackground

function YokaiBackground:init(player_num, bpm)
    self.donbg          = DonBGBase.new(1, player_num, SHARED, DONBG)
    self.stage          = YokaiStage.new(bpm)
    self.footer         = Footer.new(SHARED, 0)
    self.fever          = Fever.new(bpm, SHARED, FEVER)
    self.dancer         = Dancer.BaseDancerGroup.new(0, bpm, MAX_DANCERS, self.path, self.dancers)
    local by_index = {}
    for _, d in ipairs(self.dancer.dancers) do by_index[d.index] = d end
    for i, index in ipairs(DANCER_JOIN_ORDER) do self.dancer.dancers[i] = by_index[index] end
    self.renda          = RendaController.new(SHARED, 0)
    self.chibi          = ChibiController.new(bpm, SHARED, 1)
    self.is_clear       = false
    self.is_rainbow     = false
    self.last_milestone = 1
end

function YokaiBackground:update(current_ms, bpm)
    self.donbg:update(current_ms, bpm)
    self.stage:update(current_ms, bpm)
    self.fever:update(current_ms, bpm)
    self.dancer:update(current_ms, bpm)
    self.renda:update(current_ms)
    self.chibi:update(current_ms, bpm)
end

function YokaiBackground:add_chibi(player_num)
    BaseChibi.add(self.chibi, CHIBI, SHARED, player_num, ChibiWave)
end

function YokaiBackground:handle_good(player_num) self:add_chibi(player_num) end

function YokaiBackground:handle_ok(player_num) self:add_chibi(player_num) end

function YokaiBackground:handle_bad(player_num) self.chibi:add_chibi(player_num, true) end

function YokaiBackground:handle_drumroll(player_num) self.renda:add_renda() end

function YokaiBackground:handle_balloon(player_num) self.renda:add_renda() end

function YokaiBackground:handle_miss_streak(player_num, on) self.donbg:set_miss(on) end

function YokaiBackground:handle_gauge(player_num, progress, is_clear, is_rainbow)
    self.donbg:set_clear(is_clear)
    if is_clear ~= self.is_clear then self.stage:set_clear(is_clear) end
    if is_rainbow and not self.is_rainbow then self.fever:start() end
    if not is_rainbow and self.is_rainbow then self.fever:stop() end
    self.is_clear   = is_clear
    self.is_rainbow = is_rainbow

    local current_milestone
    if is_clear then
        current_milestone = MAX_DANCERS
    else
        current_milestone = math.min(MAX_DANCERS - 1, math.floor(progress * MAX_DANCERS))
    end
    if current_milestone > self.last_milestone then
        for _ = 1, current_milestone - self.last_milestone do self.dancer:add_dancer() end
        self.last_milestone = current_milestone
    elseif current_milestone < self.last_milestone then
        for _ = 1, self.last_milestone - current_milestone do self.dancer:leave_dancer() end
        self.last_milestone = current_milestone
    end
end

function YokaiBackground:draw_back()
    self.stage:draw()
    self.footer:draw()
    self.donbg:draw()
    self.renda:draw()
    self.dancer:draw_slots(DANCER_CENTERS, DANCER_DRAW_ORDER)
    self.fever:draw()
    self.chibi:draw()
end

function YokaiBackground:draw_fore() end

function YokaiBackground:destroy()
    self.donbg:destroy()
    self.stage:destroy()
    self.fever:destroy()
    self.dancer:destroy()
    self.footer:destroy()
    self.renda:destroy()
    self.chibi:destroy()
end

-- the background class for a collab whose dancers (a Dancer.define class) live in `path`
local function background(path, specs)
    local cls = setmetatable({ path = path, dancers = Dancer.define(specs) }, { __index = YokaiBackground })
    cls.__index = cls
    cls.new = function(player_num, bpm)
        local self = setmetatable({}, cls)
        self:init(player_num, bpm)
        return self
    end
    return cls
end

return {
    background = background,
    enter      = enter,
    leave      = leave,
    squash     = squash,
    bob        = bob,
    cycle      = cycle,
}
