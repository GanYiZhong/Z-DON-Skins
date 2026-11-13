-- Dan course song intro: the fusuma (sliding doors) close over the lane, the song title and
-- subtitle fade in on them, then the doors open on the first chart.
-- The engine owns the timing and the door sounds (DanBetween in dan_between.h); this draws the frame
-- for `elapsed` ms after the intro began.

DanBetween = {}
DanBetween.__index = DanBetween

-- clip frames (60 fps): the clip starts at F_START, the text fades in at F_TEXT, the doors reopen at
-- F_OPEN and the clip ends at F_END
local FPS, F_START, F_TEXT, F_OPEN, F_END = 60.0, 2.0, 120.0, 201.0, 366.0

local TITLE = { x = 1209, y = 93, font_size = 54, outline = 4.0 }
local SUB   = { x = 1209, y = 172, font_size = 30, outline = 3.0 }

local WHITE, BLACK = { 255, 255, 255, 255 }, { 0, 0, 0, 255 }

function DanBetween.new()
    return setmetatable({}, DanBetween)
end

function DanBetween:start(title, subtitle, show_subtitle)
    self.title_text, self.subtitle_text = nil, nil
    if title ~= "" then
        self.title_text = text.create_raw_text(title, TITLE.font_size > 0 and TITLE.font_size or 54,
            WHITE, BLACK, false, TITLE.outline)
    end
    if show_subtitle and subtitle ~= "" then
        self.subtitle_text = text.create_raw_text(subtitle, SUB.font_size > 0 and SUB.font_size or 30,
            WHITE, BLACK, false, SUB.outline)
    end
end

local function lerp(a, b, t) return a + (b - a) * t end

-- door position (fraction of the 480-wide half) at clip frame f
local function door_tx(f)
    local px
    if f <= 2.0 then px = 714.0
    elseif f < 3.0 then px = lerp(714.0, 588.2, f - 2.0)
    elseif f < 19.0 then
        local k = (f - 3.0) / 16.0
        px = lerp(588.2, 291.4, 1.0 - (math.exp(-3.0 * k) - math.exp(-3.0)) / (1.0 - math.exp(-3.0)))
    elseif f < 51.0 then px = lerp(291.4, 272.5, (f - 19.0) / 32.0)
    elseif f < 64.0 then px = lerp(272.5, 240.0, (f - 51.0) / 13.0)
    elseif f <= F_OPEN then px = 240.0
    elseif f < F_OPEN + 15.0 then
        local k = (f - F_OPEN) / 15.0
        px = lerp(240.0, 714.0, k * (2.0 - k))
    else px = 714.0 end
    return px / 480.0
end

local function text_alpha(f)
    if f < F_TEXT then return 0.0 end
    if f < 337.0 then return 1.0 end
    return math.max(0.0, math.min(1.0, (365.0 - f) / 28.0))
end

function DanBetween:draw(lane_y, elapsed)
    local f = F_START + elapsed * FPS / 1000.0
    if f >= F_END then return end
    if self.door == nil then
        self.door = tex.get_texture("game/lane/dan_between_fusuma") or false
        self.door_info = tex.get_texture_info("lane", "dan_between_fusuma") or false
        self.fill_info = tex.get_texture_info("lane", "dan_between_fill") or false
    end
    local door_info, door = self.door_info, self.door
    if not door_info or not door then return end

    local a = text_alpha(f)
    if a > 0.0 then
        if self.title_text then
            self.title_text:draw({ x = TITLE.x - self.title_text.width / 2.0,
                                   y = TITLE.y - self.title_text.height / 2.0 + lane_y, fade = a })
        end
        if self.subtitle_text then
            self.subtitle_text:draw({ x = SUB.x - self.subtitle_text.width / 2.0,
                                      y = SUB.y - self.subtitle_text.height / 2.0 + lane_y, fade = a })
        end
    end

    local mask_x, mask_y, mask_h = 498.0, 12.0, 195.0
    local fill = self.fill_info
    if fill then mask_x, mask_y, mask_h = fill.x[1], fill.y[1], fill.y2[1] end

    tex.begin_scissor(mask_x, 0, tex.get_screen_width() - mask_x, tex.get_screen_height())

    local door_y, door_h = door_info.y[1], door_info.y2[1]
    local crop_top = math.max(0.0, mask_y - door_y)
    local crop_h = math.max(0.0, math.min(door_h - crop_top, (mask_y + mask_h) - (door_y + crop_top)))
    local sc = (door_info.height > 0 and door_h > 0) and door_h / door_info.height or 1.0
    local src_top, src_h = crop_top / sc, crop_h / sc

    local tx = door_tx(f) * door_info.x2[1]
    tex.draw_texture(door, { x = tx, y = lane_y + crop_top, y2 = crop_h - door_h,
                             src = { x = 0, y = src_top, width = door_info.width, height = src_h } })
    tex.draw_texture(door, { x = -tx, y = lane_y + crop_top, y2 = crop_h - door_h,
                             src = { x = 0, y = src_top, width = -door_info.width, height = src_h } })

    tex.end_scissor()
end
