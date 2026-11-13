-- Entry top-right status row: 段位道場 / 1プレイ4曲 / IC Card chips.
EntryOverlay = {}
EntryOverlay.__index = EntryOverlay

function EntryOverlay.new(online)
    local self = setmetatable({}, EntryOverlay)
    self.online        = online
    self.stage_plate   = tex.get_texture("global/overlay/banapass_or")
    self.card_chip     = tex.get_texture("global/overlay/banapass_card")
    self.dani_chip     = tex.get_texture("global/overlay/banapass_no")
    return self
end

function EntryOverlay:update(current_ms, online)
    self.online = online
end

function EntryOverlay:draw(is_title)
    local x = is_title and -4000 or 0
    local y = 0
    local frame = self.online and 1 or 0
    tex.draw_texture(self.stage_plate, { frame = frame, x = x, y = y })
    tex.draw_texture(self.card_chip,   { frame = frame, x = x, y = y })
    tex.draw_texture(self.dani_chip,   { x = x, y = y })
end
