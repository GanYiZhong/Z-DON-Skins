local SKIN_S = tex.get_screen_scale()
local SKIN = {
    score_info_counter_margin = { x = 24 * SKIN_S, width = 14 * SKIN_S },
}

ScoreHistory = {}
ScoreHistory.__index = ScoreHistory

local DIFF_URA = 4
local SWAP_MS = 5000
local RANK_FADE_MS = 167
local RANK_ROW_DY = 72
local RANK_DIGITS, RANK_PITCH = 7, 15
local RANK_NAME_X, RANK_NAME_Y, RANK_NAME_W = 92, 211, 150

function ScoreHistory.new(available, is_shinuchi, current_ms)
    local self = setmetatable({}, ScoreHistory)

    self.available   = available
    self.is_shinuchi = is_shinuchi
    self.last_ms     = current_ms
    self.curr_index  = #available > 0 and ((1 % #available) + 1) or 0

    local s = tex.get_screen_scale()
    local margin = SKIN.score_info_counter_margin
    self.offset_y = 50 * s
    self.margin_w = margin and margin.width or 0
    self.margin_x = margin and margin.x or 0

    local title_cfg = { x = 76 * s, y = 275 * s, width = 134 * s, height = 27 * s }
    self.title_pos = title_cfg
    self.title = nil
    local label = tex.skin_text("leaderboard_title")
    if label ~= "" then
        local font_size = title_cfg.height
        while font_size > 8 do
            local t = text.create_raw_text(label, font_size, { 0, 0, 0, 255 }, { 0, 0, 0, 0 }, false, 0, 2.0)
            if t.width <= title_cfg.width then
                self.title = t
                break
            end
            font_size = font_size - 1
        end
        if not self.title then
            self.title = text.create_raw_text(label, 8, { 0, 0, 0, 255 }, { 0, 0, 0, 0 }, false, 0, 2.0)
        end
    end

    self.t_background_2 = tex.get_texture("song_select/leaderboard/background_2")
    self.t_shinuchi     = tex.get_texture("song_select/leaderboard/shinuchi")
    self.t_shinuchi_ura = tex.get_texture("song_select/leaderboard/shinuchi_ura")
    self.t_pts          = tex.get_texture("song_select/leaderboard/pts")
    self.t_normal       = tex.get_texture("song_select/leaderboard/normal")
    self.t_difficulty   = tex.get_texture("song_select/leaderboard/difficulty")
    self.t_judge_good   = tex.get_texture("song_select/leaderboard/judge_good")
    self.t_judge_ok     = tex.get_texture("song_select/leaderboard/judge_ok")
    self.t_judge_bad    = tex.get_texture("song_select/leaderboard/judge_bad")
    self.t_judge_drumroll = tex.get_texture("song_select/leaderboard/judge_drumroll")
    self.t_counter      = tex.get_texture("song_select/leaderboard/counter")
    self.t_judge_num    = tex.get_texture("song_select/leaderboard/judge_num")

    self.t_board        = tex.get_texture("song_select/leaderboard/board")
    self.t_rank_shadow  = tex.get_texture("song_select/leaderboard/rank_shadow")
    self.t_rank_digits  = tex.get_texture("song_select/leaderboard/rank_digits")
    self.t_rank_unit    = tex.get_texture("song_select/leaderboard/rank_unit")
    self.rank_rows = {}
    self.show_ranking = false
    self.swap_ms = current_ms

    return self
end

function ScoreHistory:set_ranking(ranking, current_ms)
    if not self.t_board then return end
    local s = tex.get_screen_scale()
    self.rank_diff = ranking.diff
    for i = 1, 3 do
        local e = ranking.entries[i]
        if e then
            self.rank_rows[i] = {
                score = tostring(math.floor(e.score)),
                name  = text.create_raw_text(e.name, math.floor(18 * s), { 0, 0, 0, 255 }, { 0, 0, 0, 0 }, false, 0),
            }
        end
    end
    self.show_ranking = #self.rank_rows > 0
    self.swap_ms = current_ms
end

function ScoreHistory:update(current_ms)
    self.now = current_ms
    -- no personal best to swap to: the ranking board stays
    if #self.rank_rows > 0 and #self.available > 0 and current_ms >= self.swap_ms + SWAP_MS then
        self.swap_ms = current_ms
        self.show_ranking = not self.show_ranking
    end
    if #self.available == 0 then return end
    if current_ms >= self.last_ms + 1000.0 then
        self.last_ms = current_ms
        self.curr_index = (self.curr_index % #self.available) + 1
    end
end

function ScoreHistory:draw_ranking()
    local s = tex.get_screen_scale()
    local fade = math.min(1, ((self.now or self.swap_ms) - self.swap_ms) / RANK_FADE_MS)
    if self.t_rank_shadow then tex.draw_texture(self.t_rank_shadow, { fade = fade }) end
    tex.draw_texture(self.t_board, { frame = self.rank_diff, fade = fade })
    for i, row in pairs(self.rank_rows) do
        local dy = (i - 1) * RANK_ROW_DY * s
        local str = row.score
        if self.t_rank_digits then
            for k = 1, #str do
                tex.draw_texture(self.t_rank_digits, {
                    frame = tonumber(str:sub(k, k)) or 0, x = (RANK_DIGITS - #str + k - 1) * RANK_PITCH * s, y = dy, fade = fade,
                })
            end
        end
        if self.t_rank_unit then tex.draw_texture(self.t_rank_unit, { y = dy, fade = fade }) end
        local w = math.min(row.name.width, RANK_NAME_W * s)
        row.name:draw({ x = RANK_NAME_X * s, y = RANK_NAME_Y * s + dy, x2 = w - row.name.width, fade = fade })
    end
end

function ScoreHistory:draw(open_ms)
    if open_ms < 3000 then return end
    if self.show_ranking then return self:draw_ranking() end
    if #self.available == 0 then return end

    local entry = self.available[self.curr_index]
    local diff  = entry.diff

    if self.t_background_2 then tex.draw_texture(self.t_background_2) end
    if self.title then self.title:draw({ x = self.title_pos.x, y = self.title_pos.y }) end

    if self.is_shinuchi then
        if diff == DIFF_URA then
            if self.t_shinuchi_ura then tex.draw_texture(self.t_shinuchi_ura, { index = 1 }) end
        else
            if self.t_shinuchi then tex.draw_texture(self.t_shinuchi, { index = 1 }) end
        end
        if self.t_pts then tex.draw_texture(self.t_pts, { color = { 255, 255, 255, 255 }, index = 1 }) end
    else
        if self.t_normal then tex.draw_texture(self.t_normal, { index = 1 }) end
        if self.t_pts then tex.draw_texture(self.t_pts, { color = { 0, 0, 0, 255 }, index = 1 }) end
    end

    if self.t_difficulty then tex.draw_texture(self.t_difficulty, { frame = diff, index = 1 }) end

    for i = 0, 3 do
        if self.t_normal then
            tex.draw_texture(self.t_normal, { y = self.offset_y + i * self.offset_y, index = 1 })
        end
    end

    if self.t_judge_good then tex.draw_texture(self.t_judge_good) end
    if self.t_judge_ok then tex.draw_texture(self.t_judge_ok) end
    if self.t_judge_bad then tex.draw_texture(self.t_judge_bad) end
    if self.t_judge_drumroll then tex.draw_texture(self.t_judge_drumroll) end

    local values = { entry.score, entry.good, entry.ok, entry.bad, entry.drumroll }
    local score_color = self.is_shinuchi and { 255, 255, 255, 255 } or { 0, 0, 0, 255 }

    for j = 1, 5 do
        local counter = tostring(values[j])
        local len = #counter
        if j == 1 then
            for i = 1, len do
                local digit = tonumber(string.sub(counter, i, i)) or 0
                local x = -((len * self.margin_w) / 2.0) + ((i - 1) * self.margin_w)
                if self.t_counter then
                    tex.draw_texture(self.t_counter, { color = score_color, frame = digit, x = x, index = 1 })
                end
            end
        else
            for i = 1, len do
                local digit = tonumber(string.sub(counter, i, i)) or 0
                local x = -(len - i + 1) * self.margin_x
                local y = (j - 1) * self.offset_y
                if self.t_judge_num then
                    tex.draw_texture(self.t_judge_num, { frame = digit, x = x, y = y })
                end
            end
        end
    end
end
