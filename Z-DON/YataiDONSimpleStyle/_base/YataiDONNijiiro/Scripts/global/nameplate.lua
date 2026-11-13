-- Player name/title plate (coin / band / dan variants), drawn over the player row.
local ENGINE_DEFAULT_TITLE = "Donder Debut!"
local TEXT_SPACING = 2.0

local DAN_FRAME_COUNT = 25
local TITLE_BG_FRAMES = 5   -- the 5 title backgrounds

-- name boxes, canvas px: {centre_x, centre_y, font}
local NAME_COIN        = { 226, 53,   30 }   -- 1p_coin / 2p_coin
local NAME_COIN_BARE   = { 204, 53,   30 }   -- no badge (PLAYER_NUM_ALL)
local NAME_BAND        = { 226, 67.5, 24 }   -- 1p / 1p_shougou
local NAME_BAND_DANI   = { 261, 67.5, 24 }   -- 1p_dani / 1p_shougou_dani
local NAME_BAND_BARE   = { 204, 67.5, 24 }   -- newentry
local NAME_BOX_W       = 190                 -- every text_name rect is 190 wide
local TITLE_CX, TITLE_CY, TITLE_FONT, TITLE_BOX_W = 226.5, 34.5, 22, 215
local AI_CX, AI_CY, AI_FONT, AI_BOX_W = 240, 47, 34, 200   -- the AI plate's white box (global/nameplate/ai)

Nameplate = {}
Nameplate.__index = Nameplate

local PLAYER_NUM_AI  = 5
local PLAYER_NUM_ALL = 0

function Nameplate.new(name, title, player_num, dan, is_gold, is_rainbow, title_bg)
    local self = setmetatable({}, Nameplate)

    self.player_num  = player_num
    self.dan         = dan
    self.is_gold     = is_gold
    self.is_rainbow  = is_rainbow
    self.title_bg    = title_bg

    -- "Donder Debut!" is the "no title set" default.
    self.has_title = (title ~= nil and title ~= "" and title ~= ENGINE_DEFAULT_TITLE)
    self.shadow             = tex.get_texture("global/nameplate/shadow")
    self.ai                 = tex.get_texture("global/nameplate/ai")
    self.outline            = tex.get_texture("global/nameplate/outline")
    self.frame_top          = tex.get_texture("global/nameplate/frame_top")
    self.frame_top_rainbow  = tex.get_texture("global/nameplate/frame_top_rainbow")
    self.dan_emblem_bg      = tex.get_texture("global/nameplate/dan_emblem_bg")
    self.dan_emblem         = tex.get_texture("global/nameplate/dan_emblem")
    self.dan_emblem_gold    = tex.get_texture("global/nameplate/dan_emblem_gold")

    -- clamp dan to the texture's frame count (fail-soft: a chart boot can hand over dan = 69)
    local emblem_info = tex.get_texture_info("nameplate", "dan_emblem")
    local reported    = (emblem_info and emblem_info.frame_count) or 0
    local dan_frames  = (reported > 1) and reported or DAN_FRAME_COUNT
    self.has_dan   = (type(dan) == "number" and dan >= 0 and dan < dan_frames)
    -- coin plate = no title and no dan
    self.is_coin   = not self.has_title and not self.has_dan
    self.has_badge = (player_num ~= PLAYER_NUM_ALL and player_num ~= PLAYER_NUM_AI)
    if player_num == PLAYER_NUM_AI then
        -- the AI plate's white box: its level (the title, e.g. "Lv.5"), else its name
        local s = (title ~= nil and title ~= "") and title or (name or "")
        self.ai_text = text.create_raw_text(s, AI_FONT, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 3,
                                            TEXT_SPACING)
    end

    self.rainbow_anim = tex.get_animation(12, "global")

    local box = self:name_box()
    -- white fill + black outline; the font is squeezed horizontally to fit the box (x2 below)
    self.name_text  = text.create_raw_text(name or "", box[3], { 255, 255, 255, 255 }, { 0, 0, 0, 255 },
                                           false, 2, TEXT_SPACING)
    self.title_text = text.create_raw_text(title or "", TITLE_FONT, { 0, 0, 0, 255 }, { 0, 0, 0, 0 },
                                           false, 0, TEXT_SPACING)

    if self.has_badge then
        local pnum_key = tostring(player_num) .. "p"
        self.pnum_tex  = tex.get_texture("global/nameplate/" .. pnum_key)
    end

    return self
end

-- which name box this plate uses
function Nameplate:name_box()
    if self.is_coin then
        return self.has_badge and NAME_COIN or NAME_COIN_BARE
    end
    if not self.has_badge then return NAME_BAND_BARE end
    return self.has_dan and NAME_BAND_DANI or NAME_BAND
end

-- one centred, whole-pixel-snapped OutlinedText draw inside a Lumen EditText box.
local function draw_in_box(t, x, y, cx, cy, box_w, fade)
    if not t or t.width == nil then return end
    local w  = math.floor(math.min(t.width, box_w) + 0.5)
    local dx = math.floor(x + cx - (w - TEXT_SPACING) / 2.0 + 0.5)
    local dy = math.floor(y + cy - t.height / 2 + 0.5)
    t:draw({ x = dx, y = dy, x2 = w - t.width, fade = fade })
end

function Nameplate:update(current_ms)
    self.rainbow_anim:update(current_ms)
end

function Nameplate:draw(x, y, fade)
    fade = fade or 1.0

    if self.player_num == PLAYER_NUM_AI then
        tex.draw_texture(self.ai, { x = x, y = y, fade = fade })
        draw_in_box(self.ai_text, x, y, AI_CX, AI_CY, AI_BOX_W, fade)
        return
    end

    -- white plate
    tex.draw_texture(self.shadow, { x = x, y = y, fade = fade })

    if not self.is_coin then
        -- title band + title background; clamp title_bg to a valid frame
        local frame = (self.player_num == PLAYER_NUM_ALL) and 2 or self.title_bg
        if type(frame) ~= "number" or frame < 0 or frame >= TITLE_BG_FRAMES then frame = 0 end
        if self.is_rainbow then
            local ra = self.rainbow_anim.attribute
            if ra > 0 and ra < 6 then
                tex.draw_texture(self.frame_top_rainbow, { frame = math.floor(ra) - 1, x = x, y = y, fade = fade })
            end
            tex.draw_texture(self.frame_top_rainbow, { frame = math.floor(ra), x = x, y = y, fade = fade })
        else
            tex.draw_texture(self.frame_top, { frame = frame, x = x, y = y, fade = fade })
        end
        tex.draw_texture(self.outline, { x = x, y = y, fade = fade })
    end

    -- dan chip (band family only)
    if self.has_dan and not self.is_coin then
        tex.draw_texture(self.dan_emblem_bg, { x = x, y = y, fade = fade })
        local emblem = self.is_gold and self.dan_emblem_gold or self.dan_emblem
        tex.draw_texture(emblem, { frame = self.dan, x = x, y = y, fade = fade })
    end

    -- player-number badge
    if self.has_badge then
        tex.draw_texture(self.pnum_tex, { x = x, y = y, fade = fade })
    end

    -- title text (band family only)
    if not self.is_coin and self.has_title then
        draw_in_box(self.title_text, x, y, TITLE_CX, TITLE_CY, TITLE_BOX_W, fade)
    end

    -- name text
    local box = self:name_box()
    draw_in_box(self.name_text, x, y, box[1], box[2], NAME_BOX_W, fade)
end
