Nameplate = {}
Nameplate.__index = Nameplate

local PLAYER_NUM_AI  = 5
local PLAYER_NUM_ALL = 0

local BG_PLATINUM = 3
local BG_GOLD     = 4

local ORIGIN_X, ORIGIN_Y = 136.95, 15.0
local LOOP_MS = 2000
local FRAME_MS = 1000 / 60
local HALF = 35 -- shimmer and sparkle art are 70x70

-- One shimmer sweep per loop: grow in, glide across the title, shrink away
local SHIMMER_Y = 15.85
local SHIMMER = {
    { 0, 13.3, 0.4, 0 }, { 100, 44.3, 1, 1 }, { 400, 224.3, 1, 1 }, { 500, 254.8, 0.2, 0 },
}

-- Small sparkles pop in and shrink away: { start frame, x, y, frame index in sparkle folder }
local SPARKS = {
    { 40, -56.65, 9.35, 1 },   { 42, -93.65, -10.65, 2 }, { 45, -76.65, -11.65, 1 },
    { 47, -3.65, 13.35, 2 },   { 55, -63.65, 13.35, 2 },  { 56, -17.65, -16.65, 1 },
    { 58, -107.65, 11.35, 1 }, { 60, 48.35, -8.65, 2 },   { 68, 78.35, 13.35, 1 },
    { 68, 96.35, -6.65, 2 },   { 70, 28.35, 11.35, 1 },   { 73, 56.35, 13.35, 2 },
    { 82, 66.35, 9.35, 2 },    { 83, 19.35, 12.35, 1 },   { 85, 79.35, -7.65, 1 },
    { 87, -73.65, -8.65, 2 },  { 97, 126.35, -0.65, 2 },  { 100, 104.35, 11.35, 1 },
    { 102, 46.35, 13.35, 2 },  { 104, 4.35, -8.65, 1 },
}
local STAR_X, STAR_Y = ORIGIN_X + 99.85, ORIGIN_Y - 10.15

-- dan_emblem_bg art is padded to the plate width; its visible chip ends this far in
local DAN_BG_END = 114
-- outline art is padded past its right border; the border's inner edge at name height
local NAME_AREA_END = 258

local function lerp(a, b, u) return a + (b - a) * u end

local TEAMS = { [0] = "kinoko", [1] = "takenoko" }
local TEAM_X, TEAM_Y = -6, -21

function Nameplate.new(name, title, player_num, dan, is_gold, is_rainbow, title_bg, team)
    local self = setmetatable({}, Nameplate)

    self.player_num  = player_num
    self.dan         = dan
    self.is_gold     = is_gold
    self.is_rainbow  = is_rainbow
    self.title_bg    = title_bg

    self.shadow             = tex.get_texture("global/nameplate/shadow")
    self.ai                 = tex.get_texture("global/nameplate/ai")
    self.outline            = tex.get_texture("global/nameplate/outline")
    self.frame_top          = tex.get_texture("global/nameplate/frame_top")
    self.frame_top_rainbow  = tex.get_texture("global/nameplate/frame_top_rainbow")
    self.dan_emblem_bg      = tex.get_texture("global/nameplate/dan_emblem_bg")
    self.dan_emblem         = tex.get_texture("global/nameplate/dan_emblem")
    self.dan_emblem_gold    = tex.get_texture("global/nameplate/dan_emblem_gold")
    self.shimmer            = tex.get_texture("global/nameplate/shimmer")
    if title_bg == BG_GOLD then
        self.sparkle = tex.get_texture("global/nameplate/sparkle_gold")
    else
        self.sparkle = tex.get_texture("global/nameplate/sparkle")
    end
    self.shiny = not is_rainbow and player_num ~= PLAYER_NUM_ALL and player_num ~= PLAYER_NUM_AI
        and (title_bg == BG_GOLD or title_bg == BG_PLATINUM)

    self.rainbow_anim = tex.get_animation(12, "global")

    local s = tex.get_screen_scale()
    self.name_text  = text.create_raw_text(name,  math.floor(22 * s),  { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 3)
    self.title_text = text.create_raw_text(title, math.floor(20 * s), { 0, 0, 0, 255 },       { 0, 0, 0, 0 },   false, 0)

    self.padding      = 25 * s
    self.name_offset  = -2 * s
    self.title_offset = 2 * s

    self.outline_info    = tex.get_texture_info("nameplate", "outline")
    self.frame_top_info  = tex.get_texture_info("nameplate", "frame_top")
    self.emblem_info     = tex.get_texture_info("nameplate", "dan_emblem")
    self.dan_bg_info     = tex.get_texture_info("nameplate", "dan_emblem_bg")

    if player_num ~= PLAYER_NUM_ALL and player_num ~= PLAYER_NUM_AI then
        local pnum_key = tostring(player_num) .. "p"
        self.pnum_tex  = tex.get_texture("global/nameplate/" .. pnum_key)
        self.pnum_info = tex.get_texture_info("nameplate", pnum_key)
        -- Kinotake Battle: the team's frame top and art replace the title colour and player badge
        if TEAMS[team] then
            self.team_top = tex.get_texture("global/nameplate/frame_top_" .. TEAMS[team])
            self.team_art = tex.get_texture("global/nameplate/" .. TEAMS[team])
        end
    end

    return self
end

function Nameplate:update(current_ms)
    self.rainbow_anim:update(current_ms)
    self.t0 = self.t0 or current_ms
    self.now = current_ms - self.t0
end

function Nameplate:draw_shimmer(x, y, fade)
    local t = self.now % LOOP_MS
    if t >= SHIMMER[#SHIMMER][1] then return end
    for i = 2, #SHIMMER do
        local a, b = SHIMMER[i - 1], SHIMMER[i]
        if t < b[1] then
            local u = (t - a[1]) / (b[1] - a[1])
            local s = lerp(a[3], b[3], u)
            tex.draw_texture(self.shimmer, {
                x = x + lerp(a[2], b[2], u) - HALF, y = y + SHIMMER_Y - HALF,
                scale = s, center = true, fade = fade * lerp(a[4], b[4], u),
            })
            return
        end
    end
end

function Nameplate:draw_sparkles(x, y, fade)
    local fr = (self.now % LOOP_MS) / FRAME_MS

    if fr >= 22 and fr < 39 then
        local s, rot, alpha = 1, 0, 1
        if fr < 28 then
            local u = (fr - 22) / 6
            local e = 1 - (1 - u) * (1 - u)
            s, rot = lerp(0.543, 1, e), -360 * e
        elseif fr < 31 then
            s = lerp(1, 1.371, (fr - 28) / 3)
        else
            local u = (fr - 31) / 8
            s, alpha = lerp(1.371, 1, u), 1 - u
        end
        tex.draw_texture(self.sparkle, {
            frame = 0, x = x + STAR_X - HALF + HALF * s, y = y + STAR_Y - HALF + HALF * s, -- origin shifts dest rect, add it back
            scale = s, center = true, origin = { HALF * s, HALF * s }, rotation = rot,
            fade = fade * alpha,
        })
    end

    for _, p in ipairs(SPARKS) do
        local lf = fr - p[1]
        if lf >= 0 and lf < 9 then
            local s
            if p[4] == 1 then s = lf < 5 and 1 or lerp(0.886, 0.543, (lf - 5) / 3)
            else s = lf < 4 and 1 or lerp(0.87, 0.35, (lf - 4) / 4) end
            tex.draw_texture(self.sparkle, {
                frame = p[4], x = x + ORIGIN_X + p[2] - HALF, y = y + ORIGIN_Y + p[3] - HALF,
                scale = s, center = true, fade = fade,
            })
        end
    end
end

function Nameplate:draw(x, y, fade)
    if tex.zdon_ai_select() then
        local ndx, ndy = require("global.ai_battle").sel_off("nameplate")
        x, y = x + ndx, y + ndy
    end
    fade = fade or 1.0

    tex.draw_texture(self.shadow, { x = x, y = y, fade = math.min(0.5, fade) })

    if self.player_num == PLAYER_NUM_AI then
        tex.draw_texture(self.ai, { x = x, y = y })
        return
    end

    local frame = (self.player_num == PLAYER_NUM_ALL) and 2 or self.title_bg
    if self.is_rainbow then
        local ra = self.rainbow_anim.attribute
        if ra > 0 and ra < 6 then
            tex.draw_texture(self.frame_top_rainbow, { frame = math.floor(ra) - 1, x = x, y = y, fade = fade })
        end
        tex.draw_texture(self.frame_top_rainbow, { frame = math.floor(ra), x = x, y = y, fade = fade })
    elseif self.team_top then
        tex.draw_texture(self.team_top, { x = x, y = y, fade = fade })
    else
        tex.draw_texture(self.frame_top, { frame = frame, x = x, y = y, fade = fade })
    end

    if self.now and self.shiny and not self.is_rainbow then self:draw_shimmer(x, y, fade) end
    tex.draw_texture(self.outline, { x = x, y = y, fade = fade })
    if self.now and self.shiny then self:draw_sparkles(x, y, fade) end

    local dan_offset = 0
    -- a plate without a player badge (the entry screen) shows no dan
    if self.dan ~= -1 and self.pnum_tex then
        tex.draw_texture(self.dan_emblem_bg, { x = x, y = y, fade = fade })
        if self.is_gold then
            tex.draw_texture(self.dan_emblem_gold, { frame = self.dan, x = x, y = y, fade = fade })
        else
            tex.draw_texture(self.dan_emblem, { frame = self.dan, x = x, y = y, fade = fade })
        end
        dan_offset = self.emblem_info.width
    end

    local offset = 0
    if self.player_num ~= PLAYER_NUM_ALL then
        if self.team_art then
            tex.draw_texture(self.team_art, { x = x + TEAM_X, y = y + TEAM_Y, fade = fade })
        else
            tex.draw_texture(self.pnum_tex, { x = x, y = y, fade = fade })
        end
        offset = self.pnum_info.width / 2.0
    end

    local outline_w   = self.outline_info.width
    local frame_top_w = self.frame_top_info.width
    local frame_top_h = self.frame_top_info.height
    local outline_h   = self.outline_info.height

    -- the name is centred right of the badge, or between the dan background's end and the plate end
    local left, right = offset, outline_w
    if dan_offset > 0 then
        local s = tex.get_screen_scale()
        left  = math.max(offset, self.dan_bg_info.x[1] + DAN_BG_END * s)
        right = NAME_AREA_END * s
    end
    -- a plate drawn partly off the left edge (the game lane's, x < 0) keeps its text on the visible part
    local vis = math.max(0, -x)
    local name_max   = frame_top_w - self.padding - math.max(left, vis)
    local name_width = math.min(self.name_text.width, name_max)
    local name_x     = x + (left + right) / 2.0 - name_width / 2
    name_x           = math.max(name_x, x + vis + self.padding / 4)
    local name_y     = y + outline_h / 2.0 + self.name_offset
    self.name_text:draw({ x = name_x, y = name_y, x2 = name_width - self.name_text.width, fade = fade })

    local title_max   = frame_top_w - self.padding - math.max(offset, vis)
    local title_width = math.min(self.title_text.width, title_max)
    local title_x     = x + offset + (frame_top_w - offset) / 2.0 - title_width / 2
    title_x           = math.max(title_x, x + vis + self.padding / 4)
    local title_y     = y + frame_top_h / 2.0 - self.title_text.height / 2 + self.title_offset
    self.title_text:draw({ x = title_x, y = title_y, x2 = title_width - self.title_text.width, fade = fade })
end
