local SKIN_S = tex.get_screen_scale()
local SKIN = {
    entry_chara_offset_l = { x = 330 * SKIN_S, y = 895 * SKIN_S },
    entry_chara_offset_r = { x = 330 * SKIN_S, y = 895 * SKIN_S },
}
EntryPlayer = {}
EntryPlayer.__index = EntryPlayer

function EntryPlayer.new(side)
    local self = setmetatable({}, EntryPlayer)
    self.side = side

    local chara_offset_r  = SKIN.entry_chara_offset_r
    self.chara_y_base = chara_offset_r.y

    if side == 0 then
        self.drum        = tex.get_texture("entry/side_select/red_drum")
        self.drum_offset = 0
        local chara_l    = SKIN.entry_chara_offset_l
        self.chara_x_offset = chara_l.x
    else
        self.drum        = tex.get_texture("entry/side_select/blue_drum")
        self.drum_offset = 640 * tex.get_screen_scale()
        self.chara_x_offset = chara_offset_r.x
    end

    self.cloud = tex.get_texture("entry/side_select/cloud")

    self.drum_move_y          = tex.get_animation(2, "entry")
    self.drum_move_x          = tex.get_animation(4, "entry")
    self.cloud_resize         = tex.get_animation(5, "entry")
    self.cloud_resize_loop    = tex.get_animation(6, "entry")
    self.cloud_texture_change = tex.get_animation(7, "entry")
    self.cloud_fade           = tex.get_animation(8, "entry")
    self.cloud_lift           = tex.get_animation(19, "entry")
    self.nameplate_fadein     = tex.get_animation(12, "entry")

    return self
end

-- { nameplate x, y, indicator x, y } for this side
function EntryPlayer:nameplate_indicator_pos()
    local s = tex.get_screen_scale()
    if self.side == 0 then return { 30 * s, 640 * s, 16 * s, 575 * s } end
    return { 950 * s, 640 * s, 776 * s, 575 * s }
end

-- hold_cloud: login still loading; the cloud keeps puffing/looping until finish_cloud()
function EntryPlayer:start_animations(hold_cloud)
    self.drum_move_y:start()
    self.drum_move_x:start()
    self.cloud_resize:start()
    self.cloud_loop_started = false
    if not hold_cloud then self:finish_cloud() end
    self.nameplate_fadein:start()
end

function EntryPlayer:update(current_ms)
    self.drum_move_y:update(current_ms)
    self.drum_move_x:update(current_ms)
    self.cloud_resize:update(current_ms)
    self.cloud_texture_change:update(current_ms)
    self.cloud_fade:update(current_ms)
    self.cloud_lift:update(current_ms)
    if self.cloud_resize.is_finished and not self.cloud_loop_started then
        self.cloud_loop_started = true
        self.cloud_resize_loop:start()
    end
    self.cloud_resize_loop:update(current_ms)
    self.nameplate_fadein:update(current_ms)
end

function EntryPlayer:draw_drum_back()
    local move_x = self.drum_move_x.attribute
    local move_y = self.drum_move_y.attribute

    if self.side ~= 0 then move_x = -move_x end

    tex.draw_texture(self.drum, { x = move_x, y = move_y })

    local chara_x = move_x + self.drum_offset + self.chara_x_offset
    local chara_y = self.chara_y_base + move_y
    return { chara_x, chara_y }
end

function EntryPlayer:draw_drum_front()
    local move_x = self.drum_move_x.attribute
    local move_y = self.drum_move_y.attribute
    if self.side ~= 0 then move_x = -move_x end

    local scale = self.cloud_resize.attribute
    if self.cloud_resize.is_finished then
        scale = self.cloud_resize_loop.attribute
    end

    tex.draw_texture(self.cloud, {
        frame  = math.floor(self.cloud_texture_change.attribute),
        scale  = scale,
        center = true,
        x      = move_x + self.drum_offset,
        y      = move_y + self.cloud_lift.attribute,
        fade   = self.cloud_fade.attribute,
    })
end

function EntryPlayer:is_cloud_finished()
    return self.cloud_texture_change.is_finished
end

function EntryPlayer:get_nameplate_fade()
    return self.nameplate_fadein.attribute
end

function EntryPlayer:finish_cloud()
    self.cloud_texture_change:start()
    self.cloud_fade:start()
    self.cloud_lift:start()
end
