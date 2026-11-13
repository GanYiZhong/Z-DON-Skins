-- Arcade crown fly-in and crown_loop shine, sampled from result/result crown_mc.
ResultCrown = {}
ResultCrown.__index = ResultCrown

local FRAME_MS = 1000 / 60          -- one arcade frame in ms

local cr_ok, crown_anim = pcall(require, "anim/sampler")
if not cr_ok then crown_anim = { safe = function()
    -- sampler.lua itself is missing: hand back the same NULL clip shape it would
    local n = {}
    n.at = function() return nil end; n.get = function() return nil end
    n.label = function() return nil end; n.has = function() return false end
    n.first = function() return 0 end;  n.last = function() return 0 end
    return n
end } end
local CROWN = crown_anim.safe("anim/crown_mc")
local CROWN_START_F = CROWN:label("start") or 5     -- t = 0 is this arcade frame
local CROWN_END_F   = CROWN:label("end")   or 120

local GL_SHINE = { 0, 1, 2 } -- gleam frames of the crown_loop sweep
local GL_BURST, GL_STARS = 3, 4

local CLOOP = crown_anim.safe("anim/crown_loop")
local CLOOP_LEN = CLOOP:last() - CLOOP:first() + 1        -- 180
local CLOOP_LEAVES = { { "#65@1", 1 }, { "#67@1", 2 }, { "#69@1", 3 } }  -- -> GL_SHINE idx
-- GL_SHINE index visible at loop-frame k, or nil during the idle stretch / missing table
local function crown_loop_shine(k)
    if not CLOOP.tracks then return nil, false end
    local ki = math.floor(k)
    for i = 1, #CLOOP_LEAVES do
        local rows = CLOOP.tracks[CLOOP_LEAVES[i][1]]
        if rows and #rows > 0 and ki >= rows[1][1] and ki <= rows[#rows][1] then
            return CLOOP_LEAVES[i][2], true
        end
    end
    return nil, true          -- table present, idle frame
end

local function clamp01(v)
    if v <= 0 then return 0 end
    if v >= 1 then return 1 end
    return v
end

local function lerp(a, b, p) return a + (b - a) * p end

function ResultCrown.new(crown_type, is_2p, has_2p)
    local self = setmetatable({}, ResultCrown)

    self.is_2p        = is_2p
    self.p_idx        = is_2p and 1 or 0
    self.t0           = tex.get_current_ms()
    self.now          = self.t0
    self.sound_played = false

    local crown_names = { [0] = "crown_clear", [1] = "crown_fc", [2] = "crown_dfc" }
    self.t_crown      = tex.get_texture("result/crown/" .. (crown_names[crown_type] or "crown_clear"))
    self.t_crown_fade = tex.get_texture("result/crown/crown_fade")
    self.t_gleam      = tex.get_texture("result/crown/gleam")
    -- crown_loop shine: each crown colour has its own three sweep frames, pieces of that crown's
    -- art crossed by a diagonal light band
    local shine_names = { [0] = "shine_clear", [1] = "shine_fc", [2] = "shine_dfc" }
    self.t_shine      = tex.get_texture("result/crown/" .. (shine_names[crown_type] or "shine_clear"))

    local colours = { [0] = "silver", [1] = "gold", [2] = "rainbow" }
    local seat    = has_2p and (is_2p and "_r" or "_l") or "_c"
    self.sound_name = "crown_" .. (colours[crown_type] or "silver") .. seat

    return self
end

function ResultCrown:update(current_ms)
    self.now = current_ms
    if not self.sound_played and (current_ms - self.t0) / FRAME_MS >= 0 then
        if not (self.is_2p and tex.ai_active and tex.ai_active()) then audio.play_sound(self.sound_name or "crown", "sound") end
        self.sound_played = true
    end
end

-- result_player.lua gates the 「クリア」 bubble on this: the crown has landed at scale 1.0.
function ResultCrown:is_settled()
    return (self.now - self.t0) / FRAME_MS >= 17
end

function ResultCrown:draw()
    local t = (self.now - self.t0) / FRAME_MS
    if t < 0 then return end
    local idx = self.p_idx

    local f = CROWN_START_F + t          -- absolute arcade frame on sprite 73

    local c_scale = CROWN:get("crown", f, "sx") or 1.0
    local c_alpha = CROWN:get("crown", f, "a")  or 1.0
    if self.t_crown then
        tex.draw_texture(self.t_crown, { scale = c_scale, center = true, index = idx, fade = c_alpha })
    end

    if self.t_crown_fade and t >= 13 and t <= 42 then
        local s = CROWN:get("crown_effect", f, "sx") or 1.0
        local a = CROWN:get("crown_effect", f, "a")  or 0.0
        if a > 0.001 then
            tex.draw_texture(self.t_crown_fade, { scale = s, center = true, index = idx, fade = a })
        end
    end

    if not self.t_gleam then return end

    -- radial burst: two equal copies, drawn twice for the doubled coverage
    if t >= 13 and t <= 49 then
        local a  = CROWN:get("#38@1", f, "a")  or 0.0
        local s1 = CROWN:get("#38@1", f, "sx") or 0.1
        local s0 = CROWN:get("#38@0", f, "sx") or 0.1
        if a > 0.001 then
            -- the cabinet places both burst copies with the add blend mode
            tex.draw_texture(self.t_gleam, { frame = GL_BURST, scale = s1, center = true, index = idx, fade = a, blend = "additive" })
            tex.draw_texture(self.t_gleam, { frame = GL_BURST, scale = s0, center = true, index = idx, fade = a, blend = "additive" })
        end
    end

    -- drifting star cluster
    if t >= 17 and t <= 119 then
        local s  = CROWN:get("#50@4", f, "sx") or 0.5
        local ox = CROWN:get("#50@4", f, "tx") or 30.2
        local oy = CROWN:get("#50@4", f, "ty") or -2.2
        local a  = CROWN:get("#50@4", f, "a")  or 1.0
        tex.draw_texture(self.t_gleam,
            { frame = GL_STARS, scale = s, center = true, index = idx, x = ox, y = oy, fade = clamp01(a) })
    end

    -- crown_loop shine sweep (180-frame loop from "end")
    if f >= CROWN_END_F - 5 then
        local k = (f - (CROWN_END_F - 5)) % (CLOOP_LEN > 1 and CLOOP_LEN or 180)
        local shine, have_table = crown_loop_shine(k)
        if not self.t_shine then return end
        if shine then
            tex.draw_texture(self.t_shine,
                { frame = GL_SHINE[shine], center = true, index = idx })
        elseif not have_table and k < 9 then
            tex.draw_texture(self.t_shine,
                { frame = GL_SHINE[math.floor(k / 3) + 1], center = true, index = idx })
        end
    end
end
