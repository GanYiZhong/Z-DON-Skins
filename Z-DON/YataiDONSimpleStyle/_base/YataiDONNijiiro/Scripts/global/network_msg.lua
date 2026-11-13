-- Network message (common/banapass_load.nulm sprite 47): a panel per state at the screen centre over a
-- half-dark screen. States: loading (green, five flipping Don coins), success (yellow, hopping character),
-- error (grey, takoyaki), attention (purple). Text is the skin's network_msg_<label>: the first line is the
-- title (c6, 64 px), the rest the note under it (c5, 32 px).
NetworkMsg = {}
NetworkMsg.__index = NetworkMsg

local STATE_OF = {
    clear_reading = "loading", clear_reading_maybe = "loading",
    clear_reading_ok = "success", shop_get_OK = "success",
    notice_pickup_card = "attention",
}
local function state_of(label)
    if STATE_OF[label] then return STATE_OF[label] end
    if label:sub(1, 6) == "error_" then return "error" end
    return nil
end

local CX, CY = 960, 538
local PANEL_W, PANEL_H, PANEL_DY = 1456, 496, -5
local TITLE_CY = CY - 124.25 - 4.75             -- c6 box y -52.75..43.25 under sprite 7's y -124.25
local NOTE_TOP, NOTE_H = CY + 30.25 - 52.75, 200 -- c5 box
local TEXT_W = 1280
local IN_MS, OUT_MS = 117, 117                  -- sprite 8/18/24/46 `in` f9-16, `out` f32-38
local FRAME_MS = 1000 / 60
local COIN_Y, COIN_PITCH = CY + 78, 120         -- sprite 43 at y 78, coins at -240..240
local COIN_LOOP = 76                            -- each coin flips over 14 frames, right after the one on its left

local function clamp01(v) return math.max(0, math.min(1, v)) end

function NetworkMsg.new()
    local self = setmetatable({}, NetworkMsg)
    local function t(name) return tex.get_texture("global/network_msg/" .. name) end
    self.panel = { loading = t("panel_loading"), success = t("panel_success"), error = t("panel_error"),
                   attention = t("panel_attention") }
    self.coin    = t("coin")
    self.success = t("success_chara")
    self.error   = t("error_chara")
    self.sweat   = { t("sweat_1"), t("sweat_2") }
    self.cache   = {}
    self.label   = nil
    self.visible = false
    self.now, self.start_ms, self.hide_ms = 0, 0, 0
    return self
end

local function build(label)
    local title, notes = nil, {}
    for line in (tex.skin_text("network_msg_" .. label) .. "\n"):gmatch("(.-)\n") do
        line = line:gsub("^~", "")
        if line ~= "" then
            if not title then
                title = text.create_raw_text(line, 64, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 8, 0)
            else
                notes[#notes + 1] = text.create_raw_text(line, 32, { 0, 0, 0, 255 }, { 255, 255, 255, 255 }, false, 4, 0)
            end
        end
    end
    return { title = title, notes = notes }
end

function NetworkMsg:show(label)
    if not state_of(label) then return end
    if self.label ~= label or not self.visible then self.start_ms = self.now end
    self.label = label
    self.visible = true
    if not self.cache[label] then self.cache[label] = build(label) end
end

function NetworkMsg:hide()
    if self.visible then self.hide_ms = self.now end
    self.visible = false
end

function NetworkMsg:update(current_ms)
    self.now = current_ms
    if not self.visible and self.label and current_ms - self.hide_ms >= OUT_MS then self.label = nil end
end

-- text squeezed to TEXT_W, centred on (cx, cy)
local function put_text(t, cx, cy, fade)
    local w = math.min(t.width, TEXT_W)
    t:draw({ x = cx - w / 2, y = cy - t.height / 2, x2 = w - t.width, fade = fade })
end

function NetworkMsg:draw_coins(fade)
    local f = math.floor((self.now - self.start_ms) / FRAME_MS) % COIN_LOOP
    for i = 0, 4 do
        local k = f - i * 14 - 2                       -- coin i (from the left) flips frames 2+14i .. 15+14i
        local frame = (k >= 0 and k < 14) and (1 + math.floor(k / 2)) or 0
        tex.draw_texture(self.coin, { frame = frame, x = CX + (i - 2) * COIN_PITCH - 56, y = COIN_Y - 56, fade = fade })
    end
end

-- sprite 23: two hops a loop (f10-23, f34-47), 150 px up, ease-out rise and ease-in fall
function NetworkMsg:draw_success(fade)
    local f = ((self.now - self.start_ms) / FRAME_MS) % 75
    local dy = 0
    for _, s in ipairs({ 10, 34 }) do
        local u = f - s
        if u >= 0 and u < 6 then dy = -150 * (1 - (1 - u / 6) ^ 2)
        elseif u >= 6 and u < 14 then dy = -150 * (1 - ((u - 6) / 8) ^ 2) end
    end
    tex.draw_texture(self.success, { x = CX - 668 - 16 - 104, y = CY + 155 + 78 - 166 + dy, fade = fade })
end

-- sprite 17: the takoyaki sags at f14-23, sweat drops pop out at f15 and f19
function NetworkMsg:draw_error(fade)
    local f = ((self.now - self.start_ms) / FRAME_MS) % 75
    local sag = (f >= 14 and f < 24) and 4 * math.sin(math.pi * (f - 14) / 10) or 0
    local x, y = CX + 710, CY + 170
    tex.draw_texture(self.error, { x = x - 192, y = y - 80 + sag, fade = fade })
    if f >= 15 and f < 40 then tex.draw_texture(self.sweat[1], { x = x - 90, y = y - 79, fade = fade }) end
    if f >= 19 and f < 44 then tex.draw_texture(self.sweat[2], { x = x - 67, y = y - 93, fade = fade }) end
end

function NetworkMsg:draw()
    if not self.label then return end
    local state = state_of(self.label)
    local fade, grow
    if self.visible then
        local t = self.now - self.start_ms
        fade, grow = clamp01(t / IN_MS), 0.06 + 0.94 * clamp01(t / IN_MS)
    else
        fade, grow = 1 - clamp01((self.now - self.hide_ms) / OUT_MS), 1
    end
    if fade <= 0 then return end

    tex.draw_rect(0, 0, tex.get_screen_width(), tex.get_screen_height(), 0, 0, 0, math.floor(127 * fade))
    local h = PANEL_H * grow
    tex.draw_texture(self.panel[state], { x = CX - PANEL_W / 2, y = CY + PANEL_DY - h / 2, y2 = h - PANEL_H, fade = fade })

    local lines = self.cache[self.label]
    if lines.title then put_text(lines.title, CX, TITLE_CY, fade) end
    if state == "loading" then
        self:draw_coins(fade)
    else
        local total = 0
        for _, n in ipairs(lines.notes) do total = total + n.height end
        local y = NOTE_TOP + (NOTE_H - total) / 2
        for _, n in ipairs(lines.notes) do
            put_text(n, CX, y + n.height / 2, fade)
            y = y + n.height
        end
        if state == "success" then self:draw_success(fade)
        elseif state == "error" then self:draw_error(fade) end
    end
end
