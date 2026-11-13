local Timing = require("background/bg_objects/timing")
local chain_moves, sum, Loop, pose_at = Timing.chain_moves_lua, Timing.sum, Timing.Loop, Timing.pose_at
local move = Timing.move_lua

-- DonBGBase: the don band behind the lane. A stack of layers, each a texture
-- tiled across the band (frame 0 normally, frame 1 for the clear set, which fades in over the
-- normal set and back out over `fade` beats). Ambient, in ms. spec (optional): fade, layers =
-- list of { key, ... } drawn in order:
--   ms, dx, dy: drift dx, dy px every ms, looping (dx defaults to one tile left; no ms = still)
--   tile: x spacing of the copies (default the texture width); x: phase of the first copy
--   y: offset on top of texture.json, for one texture drawn as several rows
--   period, bob, squash, pulse: a loop of { ms, distance, ease } moves for the y offset, the
--     height taken off the top (feet stay planted) and the opacity in thousandths
--   clear_only: drawn only in the clear set (with frame 0); a one-frame layer is drawn in both
--   alpha, blend: the layer's opacity (default 1) and blend mode (e.g. "additive")
--   rotation: degrees clockwise about the texture's centre (texture.json x, y stay the top-left)
--   blink: a looping pose table in ms (Timing.steps): the layer shows its pose's frame, and is
--     hidden while no pose (or a `hide` one) is on
-- dark (optional): { min, ms }, the miss-streak colour and fade time (default 0.65, 300)
-- A band with its own grey art keeps it as frame 2 and calls set_miss instead of set_dark.
-- Without a spec the band is its background scrolling one tile every 3s.

local LEGACY = { layers = { { key = "background", ms = 3000 } } }
local DEFAULT_FADE = 0.25 -- beats
local DEFAULT_BEAT = 600  -- ms, until update() is given the bpm
local DARK_MIN, DARK_FADE_MS = 0.65, 300 -- miss streak colour and fade

DonBGBase = {}
DonBGBase.__index = DonBGBase

local function period(layer)
    if layer.period then return layer.period end
    local total = 0
    for _, m in ipairs(layer.bob or {}) do total = total + m[1] end
    return total
end

function DonBGBase.new(index, player_num, path, spec)
    local self = setmetatable({}, DonBGBase)

    self.name = string.format("%d_%d", index - 1, player_num)
    self.path = path
    tex.load_folder(path, string.format("donbg/%s", self.name))
    self.bg_texture = tex.get_texture_info(self.name, "background")

    -- kept for subclasses that draw their own layers
    self.move = move(3000, {
        total_distance = -self.bg_texture.width,
        loop = true
    })
    self.move:start()

    spec = spec or LEGACY
    self.fade_beats = spec.fade or DEFAULT_FADE
    self.beat       = DEFAULT_BEAT
    self.is_clear   = false
    self.clear      = 0
    self.miss       = 0
    self.dark_min   = spec.dark and spec.dark.min or DARK_MIN
    self.dark_ms    = spec.dark and spec.dark.ms or DARK_FADE_MS

    self._id_bg = tex.get_texture(self.path .. "/" .. self.name .. "/" .. "background") or 0

    local scale = tex.get_screen_scale()
    self.layers = {}
    for _, l in ipairs(spec.layers) do
        local info  = tex.get_texture_info(self.name, l.key) or {}
        local tile  = math.floor((l.tile or info.width or 0) * scale)
        local layer = {
            l    = l,
            _id  = tex.get_texture(self.path .. "/" .. self.name .. "/" .. l.key) or 0,
            tile   = tile,
            x      = math.floor((l.x or 0) * scale),
            y      = math.floor((l.y or 0) * scale),
            frames = info.frame_count or 1,
        }
        if l.rotation then
            layer.origin = { (info.width or 0) * scale / 2, (info.height or 0) * scale / 2 }
        end
        if l.ms then
            layer.drift_x = move(l.ms, { total_distance = l.dx and math.floor(l.dx * scale) or -tile, loop = true })
            layer.drift_x:start()
            if l.dy then
                layer.drift_y = move(l.ms, { total_distance = math.floor(l.dy * scale), loop = true })
                layer.drift_y:start()
            end
        end
        if l.bob or l.squash or l.pulse then
            layer.loop = Loop.new(period(l), function()
                return {
                    bob    = chain_moves(l.bob or {}, 1, scale),
                    squash = chain_moves(l.squash or {}, 1, scale),
                    pulse  = chain_moves(l.pulse or {}, 1, 1),
                }
            end)
        end
        table.insert(self.layers, layer)
    end

    return self
end

-- miss streak: the band is multiplied towards black (colour of draw_texture), eased in/out
function DonBGBase:set_dark(on)
    self.dark_target = on and 1 or 0
end

function DonBGBase:update_dark(current_time_ms)
    local dt = current_time_ms - (self.dark_last_ms or current_time_ms)
    self.dark_last_ms = current_time_ms
    local d, target = self.dark or 0, self.dark_target or 0
    local step = dt / self.dark_ms
    self.dark = d + math.max(-step, math.min(step, target - d))
end

function DonBGBase:dark_color()
    if not self.dark or self.dark <= 0 then return nil end
    local v = math.floor(255 * (1 - (1 - self.dark_min) * self.dark))
    return { v, v, v, 255 }
end

-- miss streak with a grey set (frame 2): fades in over the normal set like the clear set,
-- only while not cleared
function DonBGBase:set_miss(on)
    self.miss_on = on
end

-- fades the clear set in, or back out, from wherever the fade is
function DonBGBase:set_clear(is_clear)
    if is_clear == self.is_clear then return end
    self.is_clear   = is_clear
    self.clear_fade = anim.fade(self.fade_beats * self.beat, {
        initial_opacity = self.clear,
        final_opacity   = is_clear and 1 or 0,
    })
    self.clear_fade:start()
end

function DonBGBase:update(current_time_ms, bpm)
    if bpm then self.beat = 60000 / bpm end
    local dt = current_time_ms - (self.now or current_time_ms)
    self.now = current_time_ms
    local target = (self.miss_on and not self.is_clear) and 1 or 0
    local step   = dt / (self.fade_beats * self.beat)
    self.miss    = self.miss + math.max(-step, math.min(step, target - self.miss))
    self:update_dark(current_time_ms)
    self.move:update(current_time_ms)
    if self.clear_fade then
        self.clear_fade:update(current_time_ms)
        self.clear = self.clear_fade.attribute
    end
    for _, layer in ipairs(self.layers) do
        if layer.drift_x then layer.drift_x:update(current_time_ms) end
        if layer.drift_y then layer.drift_y:update(current_time_ms) end
        if layer.loop then layer.loop:update(current_time_ms) end
    end
end

local function loop_sum(layer, key)
    local anims = layer.loop and layer.loop.anims
    return anims and sum(anims[key]) or 0
end

local NO_ORIGIN = { 0, 0 }

function DonBGBase:draw_textures(fade, y, frame)
    local screen_width = tex.get_screen_width()
    for _, layer in ipairs(self.layers) do
        local l = layer.l
        local blink = l.blink and pose_at(l.blink, (self.now or 0) % l.blink.length)
        if (not l.clear_only or frame == 1) and (not l.blink or blink) then
            local tile   = layer.tile
            local x      = layer.x + (layer.drift_x and layer.drift_x.attribute or 0)
            x            = tile > 0 and (x % tile) - 2 * tile or x
            local squash = loop_sum(layer, "squash")
            local f      = fade * (l.alpha or 1) * (1 + loop_sum(layer, "pulse") / 1000)
            local ly     = y + layer.y + (layer.drift_y and layer.drift_y.attribute or 0) + loop_sum(layer, "bob") + squash
            local o      = layer.origin or NO_ORIGIN
            local P      = layer._p
            if not P then P = {}; layer._p = P end   -- per layer, refilled below: no table per tile per frame
            repeat
                P.frame    = blink and blink.frame or l.clear_only and 0 or math.min(frame, layer.frames - 1)
                P.fade     = f
                P.x        = x + o[1]
                P.y        = ly + o[2]
                P.y2       = l.squash and -squash or nil
                P.rotation = l.rotation
                P.origin   = layer.origin
                P.blend    = l.blend
                P.color    = nil   -- draw_dark's wrapper sets it per call
                tex.draw_texture(layer._id, P)
                x = x + tile
            until tile <= 0 or x >= screen_width
        end
    end
end

function DonBGBase:draw_band(y)
    y = y or 0
    self:draw_textures(1.0, y, 0)
    if self.miss > 0 then self:draw_textures(self.miss, y, 2) end
    if self.clear > 0 then
        self:draw_textures(self.clear, y, 1)
    end
end

-- Draws the band through `inner`, multiplying every texture it draws by the miss-streak
-- darkness. Subclasses draw with their own tex.draw_texture calls, so wrap that once here.
function DonBGBase:draw_dark(inner, y)
    local c = self:dark_color()
    if not c then return inner(self, y) end
    local orig = tex.draw_texture
    tex.draw_texture = function(id, p)
        p = p or {}
        p.color = c
        return orig(id, p)
    end
    local ok, err = pcall(inner, self, y)
    tex.draw_texture = orig
    if not ok then error(err, 0) end
end

function DonBGBase:draw(y)
    self:draw_dark(DonBGBase.draw_band, y or 0)
end

function DonBGBase:destroy()
    tex.unload_folder(self.path, string.format("donbg/%s", self.name))
end

return DonBGBase
