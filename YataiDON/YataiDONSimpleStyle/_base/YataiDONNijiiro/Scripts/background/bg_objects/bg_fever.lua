-- YataiDON-HSS override of PyTaikoGreen/background/bg_objects/bg_fever.lua.
-- The gogo/clear backdrop is a static plate plus scrolling strips, wiped in/out
-- over a fixed-length fade; falls back to the plate only when data is missing.
local ok, DATA = pcall(require, "background/bg_data/bg_fever")
if not ok or type(DATA) ~= "table" then DATA = {} end
-- per-element replay of the cabinet movie when bg_data/bg_anim/bg_fever_N.lua
-- has been exported; the layer lists above stay as the fallback.
local ok_anim, BGAnim = pcall(require, "background/bg_objects/bg_anim")
if not ok_anim or type(BGAnim) ~= "table" then BGAnim = nil end

local ArcadeBGFever = {}
ArcadeBGFever.__index = ArcadeBGFever

local TRANSITION_MS = 29000 / 60   -- normal<->fever wipe length

-- name: a collab pack's clear backdrop ("b_001_f"), replayed from its exported movie only
function ArcadeBGFever.new(index, path, name)
    local self = setmetatable({}, ArcadeBGFever)
    self.name = name or ("bg_fever_" .. index)
    self.named = name ~= nil
    self.path = path or "background"
    if not self.named then tex.load_folder(self.path, "bg_fever/" .. self.name) end

    self.transitioned = false
    self.started = false
    self.elapsed = 0
    self.last_ms = nil

    self.fade = anim.fade(TRANSITION_MS, {
        initial_opacity = 0.0,
        final_opacity = 1.0,
        loop = false
    })

    self.anim = nil
    if BGAnim and (self.named or (path or "background") == "background") then
        self.anim = BGAnim.new(self.name, path)
    end

    self.layers = {}
    local d = DATA[self.name]
    if d and d.layers then
        for _, l in ipairs(d.layers) do
            local id = tex.get_texture(self.path .. "/" .. self.name .. "/" .. l.tex)
            if id then
                local period = l.period or 0
                table.insert(self.layers, {
                    id = id,
                    period = period,
                    vx = l.vx or 0,
                    -- enough copies to cover 1920 px whatever the phase
                    n = (period > 0) and (math.ceil(1920 / period) + 1) or 0
                })
            end
        end
    end
    if #self.layers == 0 and not self.named then
        -- fail soft: draw the one name every slot ships
        local id = tex.get_texture(self.path .. "/" .. self.name .. "/background")
        if id then table.insert(self.layers, {id = id, period = 0, vx = 0, n = 0}) end
    end

    return self
end

function ArcadeBGFever:start()
    if self.started then return end
    self.started = true
    self.transitioned = false
    -- `normal_fever`: wipe in from wherever the (possibly mid-exit) fade sits
    local from = self.fade and self.fade.attribute or 0.0
    self.fade = anim.fade(TRANSITION_MS, {
        initial_opacity = from,
        final_opacity = 1.0,
        loop = false
    })
    self.fade:start()
end

-- Falling edge (`fever_normal`); re-arms start() for the next clear.
function ArcadeBGFever:stop()
    if not self.started then return end
    self.started = false
    self.transitioned = false
    local from = self.fade and self.fade.attribute or 1.0
    self.fade = anim.fade(TRANSITION_MS, {
        initial_opacity = from,
        final_opacity = 0.0,
        loop = false
    })
    self.fade:start()
end

-- True while anything of this backdrop is on screen (entering, steady, or exiting).
function ArcadeBGFever:is_visible()
    if self.started then return true end
    return (self.fade.attribute or 0) > 0.001 and not self.fade.is_finished
end

function ArcadeBGFever:update(current_time_ms)
    if self.last_ms then
        local dt = current_time_ms - self.last_ms
        if dt > 0 and dt < 500 then self.elapsed = self.elapsed + dt end
    end
    self.last_ms = current_time_ms
    if self.anim then self.anim:update(current_time_ms) end

    if not self.transitioned then
        self.fade:update(current_time_ms)
        if self.started and self.fade.is_finished then self.transitioned = true end
    end
end

function ArcadeBGFever:draw()
    local fade = self.transitioned and 1.0 or self.fade.attribute
    if self.anim then
        self.anim:draw(fade)
        return
    end

    -- back to front, in the cabinet's own depth order (load-bearing)
    for _, l in ipairs(self.layers) do
        if l.period > 0 then
            local off = (self.elapsed / 1000.0) * l.vx
            off = off % l.period
            if off > 0 then off = off - l.period end
            for i = 0, l.n do
                tex.draw_texture(l.id, { x = off + i * l.period, fade = fade })
            end
        else
            tex.draw_texture(l.id, { fade = fade })
        end
    end
end

function ArcadeBGFever:destroy()
    if not self.named then tex.unload_folder(self.path, "bg_fever/" .. self.name) end
    if self.anim then self.anim:destroy() end
end

local BGFever = {}
BGFever.Base = ArcadeBGFever
BGFever.Arcade = ArcadeBGFever

function BGFever.create(index, path)
    return ArcadeBGFever.new(index, path)
end

-- a collab pack's clear backdrop
function BGFever.create_named(name, path)
    return ArcadeBGFever.new(nil, path, name)
end

return BGFever
