-- YataiDONSimpleStyle v2: the dan course song intro (engine DanBetween, dan_between.h: new(),
-- start(title, subtitle, show_subtitle), draw(lane_y, elapsed)). Nijiiro's door timing and geometry,
-- with two changes:
--   * the title / subtitle are UI.text in ink on the paper doors (no #000000 outline, bible 2.5);
--   * start() publishes the song's title as _G.SS_DAN_TITLE: in dan, tex.song_title() is the course
--     name, and score_counter.lua sizes the play screen's title band to the song the engine shows.
-- The engine owns the timing and the door sounds; this draws the frame for `elapsed` ms after the
-- intro began.

local UI = require("global.ss_ui")
DanBetween = {}
DanBetween.__index = DanBetween

-- clip frames (60 fps): the clip starts at F_START, the text fades in at F_TEXT, the doors reopen at
-- F_OPEN and the clip ends at F_END
local FPS, F_START, F_TEXT, F_OPEN, F_END = 60.0, 2.0, 120.0, 201.0, 366.0

local TITLE = { x = 1209, y = 93 }    -- role 36 (engine 48)
local SUB   = { x = 1209, y = 172 }   -- role 18 (engine 24)

function DanBetween.new()
    return setmetatable({}, DanBetween)
end

function DanBetween:start(title, subtitle, show_subtitle)
    _G.SS_DAN_TITLE = title
    self.title_text, self.subtitle_text = nil, nil
    if title ~= "" then
        self.title_text = UI.text(title, 36, "ink")
    end
    if show_subtitle and subtitle ~= "" then
        self.subtitle_text = UI.text(subtitle, 18, "ink")
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
    local door_info = tex.get_texture_info("lane", "dan_between_fusuma")
    local door = tex.get_texture("game/lane/dan_between_fusuma")
    if not door_info or not door then return end

    local mask_x, mask_y, mask_h = 498.0, 12.0, 195.0
    local fill = tex.get_texture_info("lane", "dan_between_fill")
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

    -- the title on the closed doors (drawn after them: ours are opaque paper), only while they are shut
    -- (no text over the notes once they open); snapped, no fade (alpha policy)
    if f < F_OPEN and UI.solid(text_alpha(f)) > 0 then
        UI.draw_text(self.title_text, TITLE.x, TITLE.y + lane_y, "c")
        UI.draw_text(self.subtitle_text, SUB.x, SUB.y + lane_y, "c")
    end
end
