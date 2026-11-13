local DonBGBase       = require("background/bg_objects/donbg/base")
local BGNormal        = require("background/bg_objects/bg_normal")
local Footer          = require("background/bg_objects/footer")
local Dancer          = require("background/bg_objects/dancer")
local RendaController = require("background/bg_objects/renda")
local ChibiController = require("background/bg_objects/chibi")
local BaseChibi       = require("background/bg_objects/chibi/base")
local Timing          = require("background/bg_objects/timing")

local chain_moves, sum, pose_at = Timing.chain_moves, Timing.sum, Timing.pose_at

-- Monster Hunter 3G and Portable 3rd: the two ensos share every part's motion; only the art,
-- a few lengths and the fever differ. Each collab file gives a spec (see background below).

-- Don band: the crest pattern scrolling one tile left every `scroll` ms. The clear set swaps
-- in the bright tiles with the crest emblem riding on them, an additive copy of the emblem
-- glowing up and back down (`pulse`: { ms, thousandths } moves). Ambient, in ms.
local GLOW_BASE = 0.148

local function donbg_spec(d)
    local period = 0
    for _, m in ipairs(d.pulse) do period = period + m[1] end
    return { layers = {
        { key = "background", ms = d.scroll },
        { key = "overlay", ms = d.scroll, clear_only = true },
        { key = "overlay", ms = d.scroll, clear_only = true, blend = "additive", alpha = GLOW_BASE,
          period = period, pulse = d.pulse },
    } }
end

-- Clear background: the panel drops in from above over the village, bounces once and
-- settles, with a strip of props scrolling left along it. Losing the clear stops the strip
-- and drops the panel out the bottom. Drop and fall in beats (gmt's), scroll in ms.
-- spec: tile, phase (the panel's tiles), strip = { tile, x } (one strip tile a 5.3 s scroll)
local DROP       = { from = -378, beats = 1.225, bounce = 40, bounce_beats = 0.275 }
local FALL       = { to = 408, beats = 0.975 }
local STRIP_MS   = 5333

local BGFever   = {}
BGFever.__index = BGFever

function BGFever.new(path, bpm, spec)
    local self = setmetatable({}, BGFever)
    self.path  = path
    self.name  = "bg_fever_0"
    self.spec  = spec
    tex.load_folder(path, "bg_fever/" .. self.name)
    local function id(key) return tex.get_texture(path .. "/" .. self.name .. "/" .. key) or 0 end
    self._id_bg    = id("background")
    self._id_strip = id("strip")
    self.beat      = 60000 / bpm
    self.offset    = 0
    self.moves     = {}
    self.shown     = false
    self.scroll    = anim.move(STRIP_MS, { total_distance = -math.floor(spec.strip.tile * tex.get_screen_scale()), loop = true })
    self.scroll:start()
    return self
end

function BGFever:y() return self.offset + sum(self.moves) end

-- drops in from wherever it is (from above when hidden)
function BGFever:start()
    local scale  = tex.get_screen_scale()
    self.offset  = self.shown and self:y() or DROP.from * scale
    self.shown   = true
    self.leaving = false
    self.moves   = chain_moves({
        { DROP.beats, -self.offset / scale, "in" },
        { DROP.bounce_beats, -DROP.bounce, "out" },
        { DROP.bounce_beats, DROP.bounce, "in" },
    }, self.beat, scale)
end

-- falls out the bottom from wherever it is
function BGFever:stop()
    if not self.shown then return end
    local scale  = tex.get_screen_scale()
    self.offset  = self:y()
    self.leaving = true
    self.moves   = chain_moves({ { FALL.beats, FALL.to - self.offset / scale } }, self.beat, scale)
end

function BGFever:update(current_time_ms, bpm)
    if bpm then self.beat = 60000 / bpm end
    for _, m in ipairs(self.moves) do m:update(current_time_ms) end
    if not self.leaving then self.scroll:update(current_time_ms) end
    if self.leaving and (not self.moves[1] or self.moves[1].is_finished) then
        self.shown, self.leaving, self.moves, self.offset = false, false, {}, 0
    end
end

function BGFever:draw()
    if not self.shown then return end
    local scale, spec = tex.get_screen_scale(), self.spec
    local y = self:y()
    local x = spec.phase
    repeat
        tex.draw_texture(self._id_bg, { x = x * scale, y = y })
        x = x + spec.tile
    until x >= 1280
    for k = -1, 1 do
        tex.draw_texture(self._id_strip, { x = (spec.strip.x + k * spec.strip.tile) * scale + self.scroll.attribute, y = y })
    end
end

function BGFever:destroy() tex.unload_folder(self.path, "bg_fever/" .. self.name) end

-- Fever: a monster crossing the stage on a loop of `loop` beats, starting `delay` beats after
-- the rainbow; losing it fades everything out over `fade` beats (back in from wherever it is
-- if the rainbow returns first). The collab's class gives the folder's keys and
-- draw_loop(t, alpha), t in beats into the loop. Timed in beats.
local Fever   = {}
Fever.__index = Fever

-- cls: the collab's fever class (keys, loop, delay, fade_beats, draw_loop)
function Fever.new(cls, path, bpm)
    local self = setmetatable({}, cls)
    self.path  = path
    self.name  = "fever_0"
    tex.load_folder(path, "fever/" .. self.name)
    self.ids   = {}
    for _, key in ipairs(cls.keys) do
        self.ids[key] = { id = tex.get_texture(path .. "/" .. self.name .. "/" .. key) or 0,
                          info = tex.get_texture_info(self.name, key) }
    end
    self.beat  = 60000 / bpm
    self.alpha = 0
    return self
end

-- a fever class for spec = { keys, loop, delay, fade_beats }; give it draw_loop
function Fever.define(spec)
    local cls = setmetatable(spec, { __index = Fever })
    cls.__index = cls
    return cls
end

function Fever:start()
    if self.alpha > 0 then
        self.fade = anim.fade(self.fade_beats * self.beat, { initial_opacity = self.alpha, final_opacity = 1 })
        self.fade:start()
    else
        self.restart = true
    end
end

function Fever:stop()
    self.fade = anim.fade(self.fade_beats * self.beat, { initial_opacity = self.alpha, final_opacity = 0 })
    self.fade:start()
end

function Fever:update(current_time_ms, bpm)
    if bpm then self.beat = 60000 / bpm end
    self.now = current_time_ms
    if self.restart then
        self.restart, self.fade = nil, nil
        self.t0, self.alpha = current_time_ms + self.delay * self.beat, 1
    end
    if self.fade then
        self.fade:update(current_time_ms)
        self.alpha = self.fade.attribute
    end
end

-- draws `key` with its centre at x, y (screen px, unscaled), posed by p (pose_at's fields)
function Fever:draw_part(key, p, x, y)
    local t, s = self.ids[key], tex.get_screen_scale()
    local w, h = t.info.width, t.info.height
    local W, H = w * p.sx, h * p.sy
    tex.draw_texture(t.id, {
        frame  = p.frame,
        x      = x * s,
        y      = y * s,
        x2     = W - w,
        y2     = H - h,
        origin = { W / 2, H / 2 },
        mirror = p.mirror and "horizontal" or nil,
        fade   = p.alpha * self.alpha,
    })
end

function Fever:draw()
    if not self.t0 or self.alpha <= 0 or self.now < self.t0 then return end
    self:draw_loop(((self.now - self.t0) / self.beat) % self.loop, self.alpha)
end

function Fever:destroy() tex.unload_folder(self.path, "fever/" .. self.name) end

-- Dancers
-- Timed in beats. Each hunter jumps up from below, drops onto the stage and readies the
-- weapon (frames 1-4), then loops an 8-beat routine of three quick frames and a held pose a
-- beat, and leaves with a jump that drops away below. All five share it; only the art and
-- the stage height differ. Poses pivot about the feet (bottom-left).
local function hunter(height)
    return {
        origin = { 0, height },
        enter  = {
            beats = 2, key = "loop",
            { 0,     0, 0, 338, to = { 0, -117, "out" } }, -- jumps up from below
            { 1,     0, 0, -117, to = { 0, 0, "in" } },
            { 1.4,   0, 0, 0 },
            { 1.425, 1 }, { 1.525, 2 }, { 1.625, 3 }, { 1.725, 4 },
        },
        dance  = Timing.steps(
            { { 5, 0.6, x = 0, y = 0 } },
            { { 6, 0.125 }, { 7, 0.125 }, { 8, 0.125 }, { 9, 0.625 } },
            { { 8, 0.125 }, { 7, 0.125 }, { 6, 0.125 }, { 5, 0.625 } },
            { { 6, 0.125 }, { 7, 0.125 }, { 8, 0.125 }, { 9, 0.625 } },
            { { 8, 0.125 }, { 10, 0.125 }, { 11, 0.125 }, { 12, 0.625 } },
            { { 11, 0.125 }, { 10, 0.125 }, { 13, 0.125 }, { 14, 0.625 } },
            { { 13, 0.125 }, { 10, 0.125 }, { 11, 0.125 }, { 12, 0.625 } },
            { { 11, 0.125 }, { 10, 0.125 }, { 13, 0.125 }, { 14, 0.625 } },
            { { 13, 0.125 }, { 10, 0.125 }, { 11, 0.075 }, { 6, 0.05 } }),
        leave  = {
            beats = 1.5, key = "loop",
            { 0,    15, 0, 0, to = { 0, -88 } },             -- jumps
            { 0.15, 16, to = { 0, -118 } },
            { 0.5,  16, to = { 0, 277, "in" } },             -- and drops away
        },
    }
end

local DANCER_DRAW_ORDER = { 5, 1, 4, 2, 3 } -- outer pairs first, the centre on top
-- dancer index by join order: joins fill the centre, left, right, far-left, far-right slots
local DANCER_JOIN_ORDER = { 4, 1, 0, 3, 2 }
local MAX_DANCERS       = 5

-- Chibis for good hits: one of four Poogies hops in and runs across, each beat three steps
-- on its feet and a hop
local CHIBI_POSES = {
    { 0, 1, 0, 0 }, { 0.1, 2, 0, 0 }, { 0.2, 3, 0, 0 },
    { 0.3, 4, 0, -15 }, { 0.4, 0, 0, -20 }, { 0.5, 0, 0, -15 },
    { 0.6, 5, 0, -17 }, { 0.7, 5, 0, -11 }, { 0.8, 5, 0, -7 },
    { 0.9, 6, 0, 0 },
}
local CHIBIS = {}
for k = 1, 4 do
    CHIBIS[k] = { key = tostring(k), run = { y = 1 }, period = 1, poses = CHIBI_POSES }
end

-- Drumroll: two cuts of meat (raw or well-done) a hit, on the default renda_a_03 flight up
-- and to the right
local RENDA = { ms = { 2000 }, dx = 1560, dy = -1648, x_range = 500, y_range = 20, per_hit = 2 }

-- Background

local Mh3Background = {}
Mh3Background.__index = Mh3Background

function Mh3Background:init(player_num, bpm)
    local spec, path    = self.spec, self.path
    self.donbg          = DonBGBase.new(1, player_num, path, spec.donbg)
    self.bg_normal      = BGNormal.Base.new(0, path)
    self.bg_fever       = BGFever.new(path, bpm, spec.bg_fever)
    self.footer         = Footer.new(path, 0)
    self.fever          = Fever.new(spec.fever, path, bpm)
    self.dancer         = Dancer.BaseDancerGroup.new(0, bpm, MAX_DANCERS, path, spec.dancers)
    local by_index = {}
    for _, d in ipairs(self.dancer.dancers) do by_index[d.index] = d end
    for i, index in ipairs(DANCER_JOIN_ORDER) do self.dancer.dancers[i] = by_index[index] end
    self.renda          = RendaController.new(path, 0, RENDA)
    self.chibi          = ChibiController.new(bpm, path, 1)
    self.is_clear       = false
    self.is_rainbow     = false
    self.last_milestone = 1
end

function Mh3Background:update(current_ms, bpm)
    self.donbg:update(current_ms, bpm)
    self.bg_fever:update(current_ms, bpm)
    self.fever:update(current_ms, bpm)
    self.dancer:update(current_ms, bpm)
    self.renda:update(current_ms)
    self.chibi:update(current_ms, bpm)
end

function Mh3Background:add_chibi(player_num)
    BaseChibi.add(self.chibi, CHIBIS[math.random(#CHIBIS)], self.path, player_num)
end

function Mh3Background:handle_good(player_num) self:add_chibi(player_num) end

function Mh3Background:handle_ok(player_num) self:add_chibi(player_num) end

function Mh3Background:handle_bad(player_num) self.chibi:add_chibi(player_num, true) end

function Mh3Background:handle_drumroll(player_num) self.renda:add_renda() end

function Mh3Background:handle_balloon(player_num) self.renda:add_renda() end

function Mh3Background:handle_gauge(player_num, progress, is_clear, is_rainbow)
    self.donbg:set_clear(is_clear)
    if is_clear and not self.is_clear then self.bg_fever:start() end
    if not is_clear and self.is_clear then self.bg_fever:stop() end
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

function Mh3Background:draw_back()
    self.bg_normal:draw()
    self.bg_fever:draw()
    self.footer:draw()
    self.donbg:draw()
    self.renda:draw()
    self.dancer:draw_slots(self.spec.centers, DANCER_DRAW_ORDER)
    self.fever:draw()
    self.chibi:draw()
end

function Mh3Background:draw_fore() end

function Mh3Background:destroy()
    self.donbg:destroy()
    self.bg_normal:destroy()
    self.bg_fever:destroy()
    self.fever:destroy()
    self.dancer:destroy()
    self.footer:destroy()
    self.renda:destroy()
    self.chibi:destroy()
end

-- spec: donbg = { scroll, pulse }, bg_fever = { tile, phase, strip = { tile, x } },
-- heights = { [dancer index] = image height }, centers = slot x's left to right,
-- fever = a class from Fever.define
local function background(path, spec)
    spec.donbg = donbg_spec(spec.donbg)
    local hunters = {}
    for i, h in pairs(spec.heights) do hunters[i] = hunter(h) end
    spec.dancers = Dancer.define(hunters)
    local cls = setmetatable({ path = path, spec = spec }, { __index = Mh3Background })
    cls.__index = cls
    cls.new = function(player_num, bpm)
        local self = setmetatable({}, cls)
        self:init(player_num, bpm)
        return self
    end
    return cls
end

return { background = background, Fever = Fever }
