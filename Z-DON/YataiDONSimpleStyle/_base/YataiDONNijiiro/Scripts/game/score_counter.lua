-- The score on the lane cover, and the "+100 / +300 ..." numbers that pop up before they are added
-- to it. The engine's ScoreCounter (score_counter.h) calls update every frame with the player's
-- score and add_popup whenever points are earned; this owns the animations and draws them.

local SKIN = {
    delay_score_addition = false,   -- the counter catches up when a popup finishes, not at once
    margin = 30,
    pos = { x = 255, y = 277.5 },
    popup_p2_offset = 750,
}

ScoreCounter = {}
ScoreCounter.__index = ScoreCounter

local AIB = require("global.ai_battle")   -- Z-DON AI battle (nothing on other engines / modes)

local MAX_POPUPS = 5   -- add_popup(value, true) drops a popup past this many
local POPUP_COLOR = { { 254, 102, 0 }, { 84, 250, 238 } }   -- by player

local function digit(ch)
    return (ch >= 48 and ch <= 57) and ch - 48 or 0
end

function ScoreCounter.new(is_2p, player_num)
    local self = setmetatable({}, ScoreCounter)
    self.is_2p = is_2p
    self.player_num = player_num
    self.score = 0
    self.stretch = tex.get_animation(4, true)
    self.t_cover = tex.get_texture("lane/lane_score_cover")
    self.t_number = tex.get_texture("lane/score_number")
    self.popups = {}
    return self
end

function ScoreCounter:set_count(score)
    if score ~= self.score then
        self.score = score
        self.stretch:start()
    end
end

function ScoreCounter:add_popup(value, limited)
    if limited and #self.popups >= MAX_POPUPS then return end
    local anim = function(id)
        local a = tex.get_animation(id, true)
        a:start()
        return a
    end
    local str = tostring(math.max(math.floor(value), 0))
    local base = POPUP_COLOR[self.player_num] or POPUP_COLOR[1]
    self.popups[#self.popups + 1] = {
        str = str, base = base, alpha = 255, y_list = {},
        fade_1 = anim(35), move_x = anim(36), fade_2 = anim(37), move_y_pre = anim(38), move_y_fan = anim(39),
    }
end

-- score: the player's current score. With delay_score_addition the counter only catches up
-- once a popup has finished, otherwise it follows at once.
function ScoreCounter:update(ms, score)
    local delay = SKIN.delay_score_addition
    local i = 1
    while i <= #self.popups do
        local p = self.popups[i]
        p.fade_1:update(ms)
        p.move_x:update(ms)
        p.move_y_pre:update(ms)
        p.move_y_fan:update(ms)
        p.fade_2:update(ms)
        local fade = p.fade_1.is_finished and p.fade_2.attribute or p.fade_1.attribute
        p.alpha = 255 * fade
        for k = 1, #p.str do p.y_list[k] = p.move_y_fan.attribute + (k - 1) * 5 end
        if p.fade_2.is_finished then
            table.remove(self.popups, i)
            if delay then self:set_count(score) end
        else
            i = i + 1
        end
    end
    if not delay then self:set_count(score) end
    self.stretch:update(ms)
end

function ScoreCounter:draw(y)
    if self.is_2p and tex.ai_active and AIB.active() then   -- Z-DON AI battle: the AI lane shows its plate and board, no score
        AIB.draw_game()
        return
    end
    if self.is_2p and not self.p2_offset then
        self.p2_offset = tex.get_skin_config("game_score_counter_2p_y_offset").y
    end
    local p2_offset = self.p2_offset or 0
    if self.is_2p then
        tex.draw_texture(self.t_cover, { mirror = "vertical", y = y + p2_offset })
    else
        tex.draw_texture(self.t_cover, { y = y })
    end

    local str = tostring(math.max(self.score, 0))
    local margin, stretch = SKIN.margin, self.stretch.attribute
    local start_x = SKIN.pos.x - #str * margin
    local y_pos = y + SKIN.pos.y + p2_offset
    for i = 1, #str do
        tex.draw_texture(self.t_number, {
            frame = str:byte(i) - 48, x = start_x + (i - 1) * margin, y = y_pos - stretch, y2 = stretch,
        })
    end

    local direction = self.is_2p and -1 or 1
    for _, p in ipairs(self.popups) do
        local x = p.move_x.attribute
        if math.abs(x) >= 1e-6 then
            local px = x - #p.str * margin
            local color = { p.base[1], p.base[2], p.base[3], p.alpha }
            for i = 1, #p.str do
                local y_i = p.move_y_pre.is_finished and p.y_list[i] or p.move_y_pre.attribute
                tex.draw_texture(self.t_number, {
                    color = color, frame = digit(p.str:byte(i)), x = px + (i - 1) * margin,
                    y = y_i * direction + y + (self.is_2p and SKIN.popup_p2_offset or 0),
                })
            end
        end
    end
end
