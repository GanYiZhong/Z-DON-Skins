AISupportMenu = {}
AISupportMenu.__index = AISupportMenu

local FRAME_MS = 1000 / 60
local S_SCALE = tex.get_screen_scale()
local DIR = "song_select/ai_battle/"
local P2_OFFSET = 836

local BOARD_OFFSETS = { [1] = { 0 }, [4] = { -117, -39, 38, 116 } }
local COURSES = {
    [0] = { board = "subdiff_easy", count = 1 },
    [1] = { board = "subdiff_normal", count = 4 },
    [2] = { board = "subdiff_hard", count = 4 },
    [3] = { board = "subdiff_oni", count = 4 },
}

local SLIDE_IN = { { 0, 0, 0.2 }, { 5, -124, 1 }, { 15, -373, 1 }, { 21, -356, 1 } }
local SLIDE_OUT = { { 0, -356, 1 }, { 15, -89, 1 }, { 20, 0, 0 } }
local GRAY_FRAMES, GRAY_FADE = 30, 0.4
local GLOW_PERIOD, GLOW_LOW = 120, 0.7
local BRANCH_PERIOD = 120

local function slide_at(keys, frame)
    for i = 2, #keys do
        local a, b = keys[i - 1], keys[i]
        if frame <= b[1] then
            local t = math.max(0, (frame - a[1]) / (b[1] - a[1]))
            return a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
        end
    end
    return keys[#keys][2], keys[#keys][3]
end

local function wave(frame, period, from, to)
    local t = 1 - math.abs(2 * (frame % period) / period - 1)
    return from + (to - from) * t
end

function AISupportMenu.new()
    local self = setmetatable({}, AISupportMenu)
    self.ids = {}
    self.shown = false
    self.slide_ms = -math.huge
    self.course = 0
    self.choose_ms = nil
    return self
end

function AISupportMenu:id(key)
    self.ids[key] = self.ids[key] or tex.get_texture(DIR .. key)
    return self.ids[key]
end

function AISupportMenu:set_status(status)
    self.status = status
    self.rank_ids = {}
end

local RANK_DIR = "song_select/ai_rank/"
local RANK_MAX, ASSIGNED_RANK = 11, 10
local TODO_X, TODO_Y = 396, 590
local TODO_BACK = { [0] = 0, 0, 0, 1, 1, 2, 2, 3, 3, 3 }

function AISupportMenu:rank_tex(key, x, y, frame, fade, scale)
    self.rank_ids[key] = self.rank_ids[key] or tex.get_texture(RANK_DIR .. key)
    local o = { x = x * S_SCALE, y = y * S_SCALE, frame = frame or 0, fade = fade or 1 }
    if scale then
        local info = tex.get_texture_info("ai_rank", key)
        o.x2 = info.width * S_SCALE * (scale - 1)
        o.y2 = info.height * S_SCALE * (scale - 1)
    end
    tex.draw_texture(self.rank_ids[key], o)
end

function AISupportMenu:rank_number(key, value, right_x, y, step, scale)
    value = math.max(0, math.floor(value))
    local x = right_x
    repeat
        self:rank_tex(key, x, y, value % 10, 1, scale)
        value = value // 10
        x = x - step
    until value == 0
end

function AISupportMenu:draw_rank_panels(ms)
    local s = self.status
    if not s then return end
    if s.rank >= RANK_MAX then
        self:rank_tex("rank_panel_max", 17, 146)
    else
        self:rank_tex("rank_panel", 17, 139)
        if s.rank >= 10 then
            self:rank_tex("digits_rank", 112.5, 117, 1)
            self:rank_tex("digits_rank", 149.5, 117, s.rank - 10)
        else
            self:rank_tex("digits_rank", 131, 117, s.rank)
        end
        self:rank_number("digits_small", s.next_rank_tokens - s.tokens, 158, 189.2, 16.8, 0.8)
    end
    if s.next_reward_wins >= 0 then
        self:rank_tex("wins_panel", 16, 225)
        self:rank_number("digits_small", s.next_reward_wins - s.wins, 173, 277.2, 16.8, 0.8)
    else
        self:rank_tex("wins_panel_max", 44, 219)
    end
    self:rank_number("digits_wins", s.wins, 198.2, 243.2, 18, 0.8)
end

function AISupportMenu:draw_rank_todo(ms)
    local s = self.status
    if not s then return end
    local pulse = 0.5 + 0.5 * wave(ms / FRAME_MS, 80, 0, 1)
    if s.rank >= RANK_MAX then
        self:rank_tex("todo_glow", TODO_X, TODO_Y, 0, pulse)
        self:rank_tex("todo_strongest", TODO_X, TODO_Y)
        self:rank_tex("todo_sparkle", TODO_X + 438, TODO_Y + 44, 0, wave(ms / FRAME_MS, 60, 0, 1))
    elseif s.rank >= ASSIGNED_RANK then
        self:rank_tex("todo_glow", TODO_X, TODO_Y, 0, pulse)
        self:rank_tex("todo_strip", TODO_X, TODO_Y, 10)
    else
        self:rank_tex("todo_back", TODO_X, TODO_Y, TODO_BACK[s.rank])
        self:rank_tex("todo_strip", TODO_X, TODO_Y, s.rank)
    end
end

function AISupportMenu:draw(ms, course, cursor, choosing, branching, player, tension)
    -- Z-DON (Green): the AI's tension balloon in Z-DON's art and spot (song_select/ai_battle/upai_tension = the
    -- official tension frames, 872,575 = the direct feed Tl7g8XXXvAM). Upstream's cropped "tension" sheet drew nothing
    -- in a zh session. tension = the condition tier 0..4 (0.90..0.99) = メチャワル .. メチャヨイ
    if tension >= 0 then tex.draw_texture(self:id("upai_tension"), { x = 872 * S_SCALE, y = 575 * S_SCALE, frame = tension }) end
    self:draw_rank_panels(ms)
    if course < 0 then self:draw_rank_todo(ms) end

    local keys = self.shown and SLIDE_IN or SLIDE_OUT
    local frame = (ms - self.slide_ms) / FRAME_MS
    if (course >= 0) ~= self.shown and frame >= keys[#keys][1] then
        self.shown = course >= 0
        self.slide_ms = ms
        keys = self.shown and SLIDE_IN or SLIDE_OUT
        frame = 0
    end
    if not self.shown and frame >= keys[#keys][1] then
        return
    end
    if self.shown then
        self.course = course
    end

    local y, fade = slide_at(keys, frame)
    local x = player == 2 and P2_OFFSET or 0
    local function draw(key, params)
        params = params or {}
        params.x, params.y = (params.x or 0) + x, (params.y or 0) + y
        params.fade = (params.fade or 1) * fade
        tex.draw_texture(self:id(key), params)
    end

    if choosing and not self.choose_ms then
        self.choose_ms = ms
    end
    if choosing then
        local gray = math.min(1, (ms - self.choose_ms) / FRAME_MS / GRAY_FRAMES)
        tex.draw_texture(self:id("gray_filter"), { x2 = 1264, y2 = 704, fade = GRAY_FADE * gray })
        draw("box_bg", { fade = wave(ms / FRAME_MS, GLOW_PERIOD, 1, GLOW_LOW) })
        draw("box_bg_blur")
        draw("box_2")
        draw("subdiff_select_text")
        draw(player == 2 and "2p" or "1p")
    else
        draw("box_1")
    end

    local info = COURSES[self.course] or COURSES[3]
    local offsets = BOARD_OFFSETS[info.count]
    local row = info.count == 1 and 1 or 0
    for i = 0, info.count - 1 do
        local board_x = offsets[i + 1]
        if choosing and i == cursor then
            draw("subdiff_selector", { x = board_x, y = row })
        end
        draw(info.board, { frame = i, x = board_x, y = row })
        if branching then
            draw("branch_indicator", { x = board_x, y = row, fade = wave(ms / FRAME_MS, BRANCH_PERIOD, 0, 1) })
        end
    end
    draw("bottom_text")
end
