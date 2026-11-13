EntryOverlay = {}
EntryOverlay.__index = EntryOverlay

function EntryOverlay.new(online)
    local self = setmetatable({}, EntryOverlay)
    self.online             = online
    self.banapass_or        = tex.get_texture("global/overlay/banapass_or")
    self.banapass_card      = tex.get_texture("global/overlay/banapass_card")
    self.banapass_osaifu    = tex.get_texture("global/overlay/banapass_osaifu_keitai")
    self.banapass_no        = tex.get_texture("global/overlay/banapass_no")
    self.camera             = tex.get_texture("global/overlay/camera")
    return self
end

function EntryOverlay:update(current_ms, online)
    self.online = online
end

function EntryOverlay:draw(is_title)
    local s = tex.get_screen_scale()
    local x = is_title and 155 * s or 0
    local y = -10 * s
    local frame = self.online and 1 or 0
    tex.draw_texture(self.banapass_or,     { frame = frame, x = x, y = y })
    tex.draw_texture(self.banapass_card,   { frame = frame, x = x, y = y })
    tex.draw_texture(self.banapass_osaifu, { frame = frame, x = x, y = y })
    if not self.online then
        tex.draw_texture(self.banapass_no, { frame = frame, x = x, y = y })
    end
    tex.draw_texture(self.camera, { frame = frame, x = x, y = y })
end
