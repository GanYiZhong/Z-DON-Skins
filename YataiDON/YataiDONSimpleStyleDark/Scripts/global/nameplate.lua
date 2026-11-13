-- SimpleStyle v2: player plate (coin / band / dan / AI variants) on the bible plate spec.
-- Plate body x 3..402, y 6..90 of the 408x96 frame; the 1P / 2P badge is the plate's accent cell
-- (x 3..87); the title band runs y 9..45 with a 1U ink rule; the dan chip sits at the left of the
-- name row. Names are ink on paper on every plate. Long names step 24 -> 18 px (coin plates 36 -> 24
-- -> 18) and only squeeze as a last resort. One fit size per screen (review R4): plates drawn on the
-- same screen (1P / 2P) register their fitted size in SS_NAMEPLATE_FIT and all draw at the smallest.
local UI = require("global.ss_ui")
local ENGINE_DEFAULT_TITLE = "Donder Debut!"
local DAN_FRAME_COUNT = 25
local TITLE_BG_FRAMES = 5

local INK  = UI.D.P.ink
local SSM = require("global.ss_meta")
-- engine-text words on the plate (ss/v2_meta.py build_nameplate): badge / AI cell centre, the computer
-- label, the dan chip (81 x 33 at 93, 51)
local BADGE_CX, BADGE_CY = 45, 48
local CPU_CX = 244
local DAN_CX, DAN_CY, DAN_W = 134, 69, 75

-- name boxes (sizes below are text ROLE sizes; UI.text creates them at the engine size) {centre_x, centre_y, width}
local NAME_COIN      = { 244, 48, 300 }   -- no title, badge
local NAME_COIN_BARE = { 202, 48, 384 }   -- no title, no badge
local NAME_BAND      = { 244, 68, 300 }
local NAME_BAND_DANI = { 288, 68, 216 }   -- widest case; the real box follows the dan chip (dan_chip_w)
local DAN_X0, DAN_Y0, DAN_H = 93, 51, 33   -- the dan chip (Lua-drawn since text24: it grows with the rank name)
local DAN_MIN_W = 81
local NAME_BAND_BARE = { 202, 68, 384 }
local TITLE_CX, TITLE_CY, TITLE_W = 244, 27, 300
local TITLE_CX_BARE = 202

Nameplate = {}
Nameplate.__index = Nameplate

local PLAYER_NUM_AI  = 5
local PLAYER_NUM_ALL = 0

local function fit_text(str, box_w, sizes, color)
    local t, size
    for _, s in ipairs(sizes) do
        t, size = UI.text(str or "", s, { color = color, outline = false }), s
        if t and t.width ~= nil and t.width <= box_w then return t, s end
    end
    return t, size
end

-- the shared fit size: { [player_num] = { size =, ms =, screen = } }; entries older than 500 ms or from
-- another screen are ignored
SS_NAMEPLATE_FIT = SS_NAMEPLATE_FIT or {}
local function shared_size(own_pn, own_size)
    local now = tex.get_current_ms()
    local scr = tex.current_screen and tex.current_screen() or ""
    SS_NAMEPLATE_FIT[own_pn] = { size = own_size, ms = now, screen = scr }
    local m = own_size
    for _, e in pairs(SS_NAMEPLATE_FIT) do
        local age = now - e.ms
        if e.screen == scr and age >= 0 and age < 500 and e.size < m then m = e.size end
    end
    return m
end

function Nameplate.new(name, title, player_num, dan, is_gold, is_rainbow, title_bg)
    local self = setmetatable({}, Nameplate)
    self.player_num = player_num
    self.ai_title   = title          -- Z-DON AI battle: the AI plate shows its level ("Lv.5")
    self.dan        = dan
    self.is_gold    = is_gold
    self.is_rainbow = is_rainbow
    self.title_bg   = title_bg
    self.has_title = (title ~= nil and title ~= "" and title ~= ENGINE_DEFAULT_TITLE)
    self.shadow            = tex.get_texture("global/nameplate/shadow")
    self.ai                = tex.get_texture("global/nameplate/ai")
    self.outline           = tex.get_texture("global/nameplate/outline")
    self.frame_top         = tex.get_texture("global/nameplate/frame_top")
    self.frame_top_rainbow = tex.get_texture("global/nameplate/frame_top_rainbow")
    self.dan_emblem_bg     = tex.get_texture("global/nameplate/dan_emblem_bg")
    self.dan_emblem        = tex.get_texture("global/nameplate/dan_emblem")
    self.dan_emblem_gold   = tex.get_texture("global/nameplate/dan_emblem_gold")

    local emblem_info = tex.get_texture_info("nameplate", "dan_emblem")
    local reported    = (emblem_info and emblem_info.frame_count) or 0
    local dan_frames  = (reported > 1) and reported or DAN_FRAME_COUNT
    self.has_dan   = (type(dan) == "number" and dan >= 0 and dan < dan_frames)
    self.is_coin   = not self.has_title and not self.has_dan
    self.has_badge = (player_num ~= PLAYER_NUM_ALL and player_num ~= PLAYER_NUM_AI)

    self.rainbow_anim = tex.get_animation(12, "global")

    self.dan_w = DAN_MIN_W
    if self.has_dan then
        local key = SSM.EMBLEM_KEYS[self.dan + 1]
        if key then
            -- text24: 8-glyph en ranks ("10th Dan", "Tatsujin") need more than the old 81 px chip
            self.dan_w = math.max(DAN_MIN_W, math.ceil((UI.label_width(key, 24) + 6 * 3) / 3) * 3)
        end
    end
    local box = self:name_box()
    self.name = name or ""
    self.name_text, self.name_size = fit_text(self.name, box[3], self.is_coin and { 36, 24, 18 } or { 24, 18 }, INK)
    self.title_text = fit_text(title or "", TITLE_W, { 24, 18 }, INK)
    -- text24: 18 renders as 24, so a name that does not fit at 24 would be squeezed hard. A coin plate has
    -- a 84 px high name field: break the name in two 24 px lines (at the space nearest the middle, else
    -- in the middle). A band plate (one 45 px row) drops a leading word first ("Player 0229..." ->
    -- the number) before it squeezes.
    self.name_lines = nil
    if self.name_text and self.name_text.width and self.name_text.width > box[3] and #self.name > 1 then
        if self.is_coin then
            local n, mid = #self.name, math.floor(#self.name / 2)
            local cut
            for d = 0, mid do
                if self.name:sub(mid - d, mid - d) == " " then cut = mid - d break end
                if self.name:sub(mid + d, mid + d) == " " then cut = mid + d break end
            end
            local a = cut and self.name:sub(1, cut - 1) or self.name:sub(1, mid)
            local b = cut and self.name:sub(cut + 1) or self.name:sub(mid + 1)
            self.name_lines = { fit_text(a, box[3], { 24 }, INK), fit_text(b, box[3], { 24 }, INK) }
        else
            local tail = self.name:match("^%S+%s+(.+)$")
            if tail then
                local t2 = fit_text(tail, box[3], { 24 }, INK)
                if t2.width <= box[3] * 1.1 then self.name_text, self.name_size = t2, 24 end
            end
        end
    end

    if self.has_badge then
        self.pnum_tex = tex.get_texture("global/nameplate/" .. tostring(player_num) .. "p")
    end
    return self
end

function Nameplate:name_box()
    if self.is_coin then
        return self.has_badge and NAME_COIN or NAME_COIN_BARE
    end
    if not self.has_badge then return NAME_BAND_BARE end
    if not self.has_dan then return NAME_BAND end
    -- right of the dan chip: 6 px gap to the chip, 3 px to the plate edge (x 399)
    local x0 = DAN_X0 + (self.dan_w or DAN_MIN_W) + 6
    local w = 396 - x0
    return { x0 + w / 2, NAME_BAND_DANI[2], w }
end

-- centred, whole-pixel draw; squeezed only when even 18 px does not fit
local function draw_in_box(t, x, y, cx, cy, box_w, fade)
    if not t or t.width == nil then return end
    local w = math.floor(math.min(t.width, box_w) + 0.5)
    local dx = math.floor(x + cx - w / 2 + 0.5)
    local dy = math.floor(y + cy - t.height / 2 + 0.5)
    t:draw({ x = dx, y = dy, x2 = w - t.width, fade = fade })
end

function Nameplate:update(current_ms)
    self.rainbow_anim:update(current_ms)
end

function Nameplate:draw(x, y, fade)
    fade = UI.solid(fade or 1.0)
    if fade == 0 then return end
    x, y = math.floor(x), math.floor(y)
    if self.player_num == PLAYER_NUM_AI then
        tex.draw_texture(self.ai, { x = x, y = y })
        UI.draw_text(UI.text_key("ai", 48), x + BADGE_CX, y + BADGE_CY, "c")
        if self.ai_title and self.ai_title ~= "" then
            UI.draw_text(UI.text(self.ai_title, 36, "ink"), x + CPU_CX, y + BADGE_CY, "c")
        else
            UI.draw_text(SSM.fit_key("computer", 300, { 24, 18 }), x + CPU_CX, y + BADGE_CY, "c")
        end
        return
    end
    tex.draw_texture(self.shadow, { x = x, y = y, fade = fade })
    if not self.is_coin then
        local frame = (self.player_num == PLAYER_NUM_ALL) and 2 or self.title_bg
        if type(frame) ~= "number" or frame < 0 or frame >= TITLE_BG_FRAMES then frame = 0 end
        if self.is_rainbow then
            -- 6 blocks stepping one block per animation step (no cross-fade)
            local ra = math.floor(self.rainbow_anim.attribute or 0) % 6
            tex.draw_texture(self.frame_top_rainbow, { frame = ra, x = x, y = y, fade = fade })
        else
            tex.draw_texture(self.frame_top, { frame = frame, x = x, y = y, fade = fade })
        end
    end
    tex.draw_texture(self.outline, { x = x, y = y, fade = fade })
    if self.has_dan and not self.is_coin then
        local key = SSM.EMBLEM_KEYS[self.dan + 1]
        if key then
            local P = UI.D.P
            local ix, iy, iw, ih = UI.chrome.chip(x + DAN_X0, y + DAN_Y0, self.dan_w, DAN_H, P.dan or P.gold, false,
                                                  math.floor(fade * 255))
            local st = { color = self.is_gold and P.gold_t or INK, outline = false }
            UI.draw_text(SSM.fit_key(key, iw, { 24 }, st), ix + iw / 2, iy + ih / 2, "c")
        end
    end
    if self.has_badge and self.pnum_tex then
        -- polish_meta: the player colour runs along the bottom of the name field (1P red / 2P blue), so
        -- the plate reads as the player's even where the badge is off-frame (2U on coin plates, 1U under
        -- a title band, where the name row sits lower)
        local pc = (self.player_num == 2) and UI.D.P.p2 or UI.D.P.p1
        local sh = self.is_coin and 2 * UI.U or UI.U
        UI.rect(x + 87, y + 87 - sh, 312, sh, pc)
        tex.draw_texture(self.pnum_tex, { x = x, y = y, fade = fade })
        UI.draw_text(UI.text_key("player_" .. tostring(self.player_num) .. "p", 48, "paper"),
                     x + BADGE_CX, y + BADGE_CY, "c")
    end
    if not self.is_coin and self.has_title then
        draw_in_box(self.title_text, x, y, self.has_badge and TITLE_CX or TITLE_CX_BARE, TITLE_CY, TITLE_W, fade)
    end
    local box = self:name_box()
    local t = self.name_text
    if self.name_size and self.player_num ~= PLAYER_NUM_ALL then
        local s = shared_size(self.player_num, self.name_size)
        if s < self.name_size then t = UI.text(self.name, s, { color = INK, outline = false }) end
    end
    if self.name_lines then
        draw_in_box(self.name_lines[1], x, y, box[1], box[2] - 15, box[3], fade)
        draw_in_box(self.name_lines[2], x, y, box[1], box[2] + 13, box[3], fade)
        return
    end
    draw_in_box(t, x, y, box[1], box[2], box[3], fade)
end
