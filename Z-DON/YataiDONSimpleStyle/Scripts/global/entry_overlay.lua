-- SimpleStyle v2 (meta): entry top-right status row (段位道場 / 1プレイ 4曲 / IC card tiles), Nijiiro's
-- layout. The textures are chrome only: the words are engine text in the player's language
-- (SCREEN_GUIDE_V2 §11), positions from ss/v2_meta.py build_overlay (frame-local).
local UI = require("global.ss_ui")
local SSM = require("global.ss_meta")

EntryOverlay = {}
EntryOverlay.__index = EntryOverlay

local function origin(name)
    local info = tex.get_texture_info("overlay", name)
    return (info and info.x and info.x[1]) or 0, (info and info.y and info.y[1]) or 0
end

function EntryOverlay.new(online)
    local self = setmetatable({}, EntryOverlay)
    self.online        = online
    self.stage_plate   = tex.get_texture("global/overlay/banapass_or")
    self.card_chip     = tex.get_texture("global/overlay/banapass_card")
    self.dani_chip     = tex.get_texture("global/overlay/banapass_no")
    self.or_x, self.or_y = origin("banapass_or")
    self.card_x, self.card_y = origin("banapass_card")
    self.no_x, self.no_y = origin("banapass_no")
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
    if is_title then return end
    -- text24: the dojo tile is our own 168 x 78 plate (the old 124 x 66 tile is blank), right edge kept
    local dojo = SSM.T("dojo_plate")
    local dx, dy = self.no_x - 44, self.no_y
    -- 1プレイ 4曲 on the 237 x 60 plate, 段位道場 over the dojo tile's chip, OK on a connected card tile
    UI.draw_text(SSM.fit_key("per_play", 225, { 24 }), self.or_x + 118, self.or_y + 30, "c")
    if dojo then tex.draw_texture(dojo, { x = dx, y = dy }) end
    UI.draw_text(SSM.fit_key("dan_dojo", 156, { 24 }), dx + 82, dy + 19, "c")
    -- the rank chip (no rank offline: なし) and the card chip (OK, or オフ when not connected)
    UI.draw_text(SSM.fit_key("dan_none", 114, { 24 }), dx + 82, dy + 54.5, "c")
    UI.draw_text(SSM.fit_key(frame == 1 and "card_ok" or "status_off", 63, { 24 }),
                 self.card_x + 49, self.card_y + 76, "c")
end
