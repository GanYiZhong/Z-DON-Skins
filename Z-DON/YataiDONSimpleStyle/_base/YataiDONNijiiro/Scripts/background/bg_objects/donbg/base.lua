-- YataiDON-HSS override of PyTaikoGreen/background/bg_objects/donbg/base.lua.
-- The cabinet band is a 1920x276 stage whose children slide left and wrap; the
-- default pack is DATA-driven layer lists, collab paths use the parent tiler.
local ok, DATA = pcall(require, "background/bg_data/donbg")
if not ok or type(DATA) ~= "table" then DATA = {} end
-- per-element replay of the cabinet movie when bg_data/donbg_anim/a_NN_Mp.lua is
-- exported for this band; otherwise the layer lists.
local ok_anim, DonBGAnim = pcall(require, "background/bg_objects/donbg/anim_player")
if not ok_anim or type(DonBGAnim) ~= "table" then DonBGAnim = nil end

local DonBGBase = {}
DonBGBase.__index = DonBGBase

-- anim_name: a collab pack's band ("b_001_1p"), replayed from its exported movie only
function DonBGBase.new(index, player_num, path, anim_name)
    local self = setmetatable({}, DonBGBase)

    self.path = path
    self.anim = nil
    if anim_name and DonBGAnim then
        self.name = anim_name
        self.named = true
        self.use_layers = true
        self.anim = DonBGAnim.new(nil, player_num, path, anim_name)
    else
        self.name = string.format("%d_%d", index - 1, player_num)
        tex.load_folder(path, string.format("donbg/%s", self.name))
        self.bg_texture = tex.get_texture_info(self.name, "background")

        -- DATA describes only the DEFAULT pack; collab paths get the parent tiler
        self.use_layers = (path == "background")
        if self.use_layers and DonBGAnim then
            self.anim = DonBGAnim.new(index, player_num, path)
        end
    end
    if not self.use_layers then
        -- parent contract: constant scroll, one bg-width per 3000 ms loop
        local w = self.bg_texture and self.bg_texture.x2[1] or 0
        self.move = anim.move(3000, { total_distance = -w, loop = true })
        self.move:start()
    end

    self.is_clear = false
    self.clear_fade = tex.get_animation(1, "background")
    -- exit is a reverse fade of the same length the bg_fever wipe uses
    self.exit_fade = nil

    self.elapsed = 0
    self.last_ms = nil

    -- nil = missing (id 0 is a valid texture id); a named band has no plate folder
    if not self.named then
        self._id_bg = tex.get_texture(self.path .. "/" .. self.name .. "/background")
    end

    local d = DATA[self.name]
    self.states = {}
    if d then
        for _, st in ipairs({ "normal", "fever" }) do
            local out = {}
            for _, l in ipairs(d[st] or {}) do
                local id = tex.get_texture(self.path .. "/" .. self.name .. "/" .. l.tex)
                if id then
                    local period = l.period or 0
                    table.insert(out, {
                        id = id, frame = l.frame, index = l.index,
                        period = period, vx = l.vx or 0,
                        bob = l.bob, bob_frames = l.bob_frames,
                        -- enough copies to cover 1920 px whatever the phase
                        n = (period > 0) and (math.ceil(1920 / period) + 1) or 0,
                    })
                end
            end
            self.states[st] = out
        end
    end
    if not self.states.normal or #self.states.normal == 0 then
        self.states = { normal = {} }
        if self._id_bg then
            self.states.normal[1] = { id = self._id_bg, frame = 0, index = 0,
                                      period = 0, vx = 0, n = 0 }
        end
    end

    return self
end

local EXIT_MS = 29000 / 60

-- miss streak: the band is multiplied towards black (colour of draw_texture), eased in/out
local DARK_MIN, DARK_FADE_MS = 0.65, 300

function DonBGBase:set_dark(on)
    self.dark_target = on and 1 or 0
end

function DonBGBase:update_dark(current_time_ms)
    local dt = current_time_ms - (self.dark_last_ms or current_time_ms)
    self.dark_last_ms = current_time_ms
    local d, target = self.dark or 0, self.dark_target or 0
    local step = dt / DARK_FADE_MS
    self.dark = d + math.max(-step, math.min(step, target - d))
end

function DonBGBase:dark_color()
    if not self.dark or self.dark <= 0 then return nil end
    local v = math.floor(255 * (1 - (1 - DARK_MIN) * self.dark))
    return { v, v, v, 255 }
end

function DonBGBase:set_clear(is_clear)
    if is_clear and not self.is_clear then
        self.is_clear = true
        self.clear_fade:start()
        self.exit_fade = nil
    end
    if not is_clear and self.is_clear then
        self.is_clear = false
        -- reverse-play instead of the old instant reset
        local from = self.clear_fade.attribute or 1.0
        self.exit_fade = anim.fade(EXIT_MS, {
            initial_opacity = from,
            final_opacity = 0.0,
            loop = false
        })
        self.exit_fade:start()
        self.clear_fade:reset()
    end
end

function DonBGBase:update(current_time_ms)
    self:update_dark(current_time_ms)
    -- same wall-clock accumulator bg_fever uses; guard drops the load-time gap
    if self.last_ms then
        local dt = current_time_ms - self.last_ms
        if dt > 0 and dt < 500 then self.elapsed = self.elapsed + dt end
    end
    self.last_ms = current_time_ms
    if self.move then self.move:update(current_time_ms) end
    if self.anim then self.anim:update(current_time_ms) end
    self.clear_fade:update(current_time_ms)
    if self.exit_fade then
        self.exit_fade:update(current_time_ms)
        if self.exit_fade.is_finished then self.exit_fade = nil end
    end
end

-- A layer may also carry a y triangle (bob), amplitude/period in cabinet frames.
local function bob_offset(l, elapsed)
    if not l.bob or not l.bob_frames or l.bob_frames <= 0 then return 0 end
    local half = l.bob_frames / 2.0
    local t = (elapsed / (1000.0 / 60.0)) % l.bob_frames
    if t < half then return l.bob * (t / half) end
    return l.bob * ((l.bob_frames - t) / half)
end

function DonBGBase:draw_layers(layers, fade, y)
    for _, l in ipairs(layers) do
        local ly = y + bob_offset(l, self.elapsed)
        if l.period > 0 then
            local off = (self.elapsed / 1000.0) * l.vx
            off = off % l.period
            if off > 0 then off = off - l.period end
            for i = 0, l.n do
                tex.draw_texture(l.id, { frame = l.frame, index = l.index,
                                         x = off + i * l.period, y = ly, fade = fade })
            end
        else
            tex.draw_texture(l.id, { frame = l.frame, index = l.index,
                                     y = ly, fade = fade })
        end
    end
end

-- default parent-contract tiler (5 copies at bg width, scrolled by self.move)
function DonBGBase:draw_textures(fade, y, frame)
    if not self._id_bg then return end
    local w = self.bg_texture and self.bg_texture.x2[1] or 0
    if w <= 0 then
        tex.draw_texture(self._id_bg, { frame = frame, fade = fade, y = y })
        return
    end
    local mv = self.move and self.move.attribute or 0
    for i = 0, 4 do
        tex.draw_texture(self._id_bg, {
            frame = frame,
            fade = fade,
            x = (i * w) + mv,
            y = y
        })
    end
end

function DonBGBase:draw_band(y)
    y = y or 0

    -- collab path = parent contract; default pack = DATA-driven layer lists
    if not self.use_layers then
        self:draw_textures(1.0, y, 0)
        if self.is_clear then
            self:draw_textures(self.clear_fade.attribute, y, 1)
        elseif self.exit_fade then
            self:draw_textures(self.exit_fade.attribute, y, 1)
        end
        return
    end

    if self.anim then
        self.anim:draw_state("normal", 1.0, y)
        if self.is_clear then
            self.anim:draw_state("fever", self.clear_fade.attribute, y)
        elseif self.exit_fade then
            self.anim:draw_state("fever", self.exit_fade.attribute, y)
        end
        -- layers shown in both states (collab bands), over the crossfade
        self.anim:draw_state("top", 1.0, y)
        return
    end

    self:draw_layers(self.states.normal or {}, 1.0, y)
    if self.is_clear and self.states.fever then
        self:draw_layers(self.states.fever, self.clear_fade.attribute, y)
    elseif self.exit_fade and self.states.fever then
        self:draw_layers(self.states.fever, self.exit_fade.attribute, y)
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
        local own = p.color
        if own then
            -- a tinted placement keeps its own colour, darkened like the rest
            p.color = { own[1] * c[1] / 255, own[2] * c[2] / 255, own[3] * c[3] / 255, own[4] or 255 }
        else
            p.color = c
        end
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
    if not self.named then tex.unload_folder(self.path, string.format("donbg/%s", self.name)) end
    if self.anim then tex.unload_folder(self.path, self.anim.subset) end
end

return DonBGBase
