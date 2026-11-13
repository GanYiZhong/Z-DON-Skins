local SKIN_S = tex.get_screen_scale()
local SKIN = {
    entry_chara_offset_l = { x = 330 * SKIN_S, y = 895 * SKIN_S },
    entry_chara_offset_r = { x = 330 * SKIN_S, y = 895 * SKIN_S },
}
-- Entry player: Don stands on the street (no big drum), 1P ~x220 / 2P mirrored.
EntryPlayer = {}
EntryPlayer.__index = EntryPlayer

function EntryPlayer.new(side)
    local self = setmetatable({}, EntryPlayer)
    -- fold the side-select cursor (0=1P, 2=2P) to 0/1
    self.side = (side == 0) and 0 or 1

    local chara_offset_r  = SKIN.entry_chara_offset_r
    self.chara_y_base = chara_offset_r.y

    if side == 0 then
        self.drum        = tex.get_texture("entry/side_select/red_drum")
        self.drum_offset = 0
        local chara_l    = SKIN.entry_chara_offset_l
        self.chara_x_offset = chara_l.x
    else
        self.drum        = tex.get_texture("entry/side_select/blue_drum")
        self.drum_offset = 960
        self.chara_x_offset = chara_offset_r.x
    end

    self.cloud = tex.get_texture("entry/side_select/cloud")

    self.drum_move_1          = tex.get_animation(2, "entry")
    self.drum_move_3          = tex.get_animation(4, "entry")
    self.cloud_resize         = tex.get_animation(5, "entry")
    self.cloud_resize_loop    = tex.get_animation(6, "entry")
    self.cloud_texture_change = tex.get_animation(7, "entry")
    self.cloud_fade           = tex.get_animation(8, "entry")
    self.nameplate_fadein     = tex.get_animation(12, "entry")

    return self
end

-- hold_cloud: login still loading; the cloud keeps puffing/looping until finish_cloud()
-- { nameplate x, y, indicator x, y } for this side
function EntryPlayer:nameplate_indicator_pos()
    if self.side == 0 then return { 14, 910, 0, 0 } end
    return { 1494, 910, 0, 0 }
end

function EntryPlayer:start_animations(hold_cloud)
    self.drum_move_1:start()
    self.drum_move_3:start()
    self.cloud_resize:start()
    self.cloud_resize_loop:start()
    if not hold_cloud then self:finish_cloud() end
    self.nameplate_fadein:start()
end

function EntryPlayer:update(current_ms)
    self.drum_move_1:update(current_ms)
    self.drum_move_3:update(current_ms)
    self.cloud_resize:update(current_ms)
    self.cloud_texture_change:update(current_ms)
    self.cloud_fade:update(current_ms)
    self.cloud_resize_loop:update(current_ms)
    self.nameplate_fadein:update(current_ms)
end

-- Arcade placement (1080p px)
local DON_ANCHOR_DY, DON_ANCHOR_DX = 130, -5
local BOUNCE_END = -510   -- parent animation.json entry 2 (-340), x1.5
local DON_CX = { [0] = 220, [1] = 1920 - 220 }
local DON_CY = 780
local COS_CX = { [0] = 498, [1] = 498 + 924 }
local COS_CY = 548
-- Don scale inside the costume panel
local COS_DON_SCALE = 0.8
__hss_costume_panel = __hss_costume_panel or {}
-- board fade-in shared from costume_menu.lua; missing entry = fully opaque
__hss_costume_fade = __hss_costume_fade or {}
__hss_costume_smoke = __hss_costume_smoke or {}

local SMOKE_F        = 1000 / 60
local SMOKE_LAST_F   = 32
local SMOKE_CX       = { [0] = 498, [1] = 498 + 924 }
local SMOKE_CY       = 482 + (548 - 480)   -- arcade smoke y + (our panel Don centre - arcade's)
local SMOKE_WOBBLE   = { 1.10, 1.13, 1.15, 1.18, 1.21, 1.18, 1.15, 1.13, 1.10 }

local ok_anim, anim = pcall(require, "anim/sampler")
if not ok_anim then anim = nil end
local SMOKE_CLIP  = anim and anim.safe("anim/costume_smoke") or nil
local SMOKE_LEAVES = { { "#2@0", 0 }, { "#4@0", 1 }, { "#6@0", 2 }, { "#8@0", 3 } }

-- returns frame index, scale, dy, alpha (or nil when no smoke is running)
local function smoke_state(f)
    if f < 0 or f > SMOKE_LAST_F then return nil end
    if SMOKE_CLIP and SMOKE_CLIP.tracks then
        local fi = math.floor(f)
        for i = 1, #SMOKE_LEAVES do
            local name, tex_frame = SMOKE_LEAVES[i][1], SMOKE_LEAVES[i][2]
            local rows = SMOKE_CLIP.tracks[name]
            if rows and #rows > 0 and fi >= rows[1][1] and fi <= rows[#rows][1] then
                -- fields = {ty, sx, a}
                local dy, sc, a = SMOKE_CLIP:at(name, f)
                if dy ~= nil then return tex_frame, sc, dy, a end
            end
        end
        -- fall through to the hand table only if no leaf claimed the frame
    end
    if f <= 6  then return 0, 0.10 + 0.1666667 * f, 0, f / 6 end
    if f <= 15 then return 0, SMOKE_WOBBLE[f - 6] or 1.10, 0, 1 end
    if f <= 20 then return 1, 1.10, -2.5 * (f - 16), 1 end
    if f <= 26 then return 2, 1.10, -10, 1 end
    return 3, 1.10, -20 - 2 * (f - 27), 1 - (f - 27) / 5
end

local function costume_open(side)
    local t = __hss_costume_panel[side]
    return t ~= nil and (tex.get_current_ms() - t) < 100
end

function EntryPlayer:draw_drum_back()
    local move_y = self.drum_move_1.attribute
    local cx, cy = DON_CX[self.side] or DON_CX[0], DON_CY
    if costume_open(self.side) then
        cx, cy = COS_CX[self.side] or COS_CX[0], COS_CY
        if not self.cos_panel then
            self.cos_panel = tex.get_texture("entry/costume_select/box_center_" .. (self.side == 0 and "1p" or "2p"))
        end
        tex.draw_texture(self.cos_panel, { fade = __hss_costume_fade[self.side] or 1.0 })
        move_y = 0
    else
        move_y = move_y - BOUNCE_END   -- the bounce ends at BOUNCE_END; the centre lands on DON_CY
    end
    self.don_cx, self.don_cy = cx, cy + move_y
    local don_scale = costume_open(self.side) and COS_DON_SCALE or 1.0
    return { cx + DON_ANCHOR_DX, cy + move_y + DON_ANCHOR_DY, don_scale }
end

-- entry smoke: the parent's 4-frame cloud, centred on Don
function EntryPlayer:draw_drum_front()
    -- costume-change smoke wins while it runs
    local t0 = __hss_costume_smoke[self.side]
    if t0 and costume_open(self.side) then
        local f = (tex.get_current_ms() - t0) / SMOKE_F
        local frame, sc, dy, a = smoke_state(f)
        if frame then
            if not self.cloud_info then self.cloud_info = tex.get_texture_info("side_select", "cloud") end
            local ci = self.cloud_info
            local cx = SMOKE_CX[self.side] or SMOKE_CX[0]
            local cy = SMOKE_CY + dy
            tex.draw_texture(self.cloud, {
                frame  = frame,
                scale  = sc * 1.5,
                center = true,
                x      = cx - ci.x[1] - ci.x2[1] / 2,
                y      = cy - ci.y[1] - ci.y2[1] / 2,
                fade   = a,
            })
            return
        end
    end

    local scale = self.cloud_resize.attribute
    if self.cloud_resize.is_finished then
        scale = math.max(1.0, self.cloud_resize_loop.attribute)
    end
    if not self.cloud_info then
        self.cloud_info = tex.get_texture_info("side_select", "cloud")
    end
    local ci = self.cloud_info
    local cx = (self.don_cx or DON_CX[0])
    local cy = (self.don_cy or DON_CY) + 14
    tex.draw_texture(self.cloud, {
        frame  = math.floor(self.cloud_texture_change.attribute),
        scale  = scale,
        center = true,
        x      = cx - ci.x[1] - ci.x2[1] / 2,
        y      = cy - ci.y[1] - ci.y2[1] / 2,
        fade   = self.cloud_fade.attribute,
    })
end

function EntryPlayer:is_cloud_finished()
    return self.cloud_texture_change.is_finished
end

function EntryPlayer:get_nameplate_fade()
    return self.nameplate_fadein.attribute
end

-- let the cloud shrink away: texture change + fade out
function EntryPlayer:finish_cloud()
    self.cloud_texture_change:start()
    self.cloud_fade:start()
end
