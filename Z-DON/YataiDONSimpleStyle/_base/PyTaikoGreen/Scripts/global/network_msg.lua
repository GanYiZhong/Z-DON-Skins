NetworkMsg = {}
NetworkMsg.__index = NetworkMsg

NetworkMsg.LABELS = {
    clear_reading = { bar = 0, dots = 315 },
    clear_reading_ok = { bar = 1 },
    error_reading_ng = { bar = 2 },
    error_data_ban = { bar = 2 },
    error_disconnect = { bar = 2 },
    error_assign_limit = { bar = 2 },
    error_cannot_assign = { bar = 2 },
    notice_pickup_card = { bar = 3 },
    clear_reading_maybe = { bar = 0, dots = 335 },
    error_lost_card = { bar = 2 },
    error_userdata = { bar = 2 },
    error_already_gasha = { bar = 2 },
    error_not_play = { bar = 2 },
    error_touch_again = { bar = 2 },
    error_close_shop = { bar = 2 },
    error_offline_gasha = { bar = 2 },
    error_card_gasha = { bar = 2 },
    error_end_gasha = { bar = 2 },
    error_bnid = { bar = 2 },
    error_shop_already = { bar = 2 },
    error_shop_failed = { bar = 2 },
    error_shop_shortage = { bar = 2 },
    shop_get_OK = { bar = 1 },
    error_offline_shop = { bar = 2 },
}

local BAR_CENTER = 312   -- bar top 232 + 80
local BIG, SMALL = 30, 20
local BIG_H, SMALL_H = 36, 28
local DOT_PITCH = 40
local FRAME_MS = 1000 / 60
local TILE_W = 64
local SCROLL_PX_PER_MS = TILE_W / (121 * FRAME_MS)
local FADE_MS = 150
local DOT_START = 10
local DOT_LOOP = 149
local DOT_WAITING = 5

local function dot_frame(t)
    t = t % DOT_LOOP
    if t < 60 then return 0 end
    if t < 76 then return math.min(8, 1 + math.floor((t - 60) / 2)) end
    if t < 135 then return 8 end
    return 7 - math.floor((t - 135) / 2)
end

function NetworkMsg.new()
    local self = setmetatable({}, NetworkMsg)
    self.dim = tex.get_texture("global/network_msg/dim")
    self.bar = tex.get_texture("global/network_msg/bar")
    self.dot = tex.get_texture("global/network_msg/dot")
    self.label = nil
    self.cache = {}
    self.start_ms = 0
    self.now = 0
    self.fade = 0
    self.visible = false
    return self
end

local function build(key)
    local lines = {}
    for line in (tex.skin_text("network_msg_" .. key) .. "\n"):gmatch("(.-)\n") do
        local small = line:sub(1, 1) == "~"
        if small then line = line:sub(2) end
        lines[#lines + 1] = {
            text = text.create_raw_text(line, small and SMALL or BIG, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, false, 5, 2.0),
            h = small and SMALL_H or BIG_H,
        }
    end
    return lines
end

function NetworkMsg:show(label)
    if not NetworkMsg.LABELS[label] then return end
    if self.label ~= label then self.start_ms = self.now end
    self.label = label
    self.visible = true
    if not self.cache[label] then self.cache[label] = build(label) end
end

function NetworkMsg:hide() self.visible = false end

function NetworkMsg:update(current_ms)
    local dt = math.max(0, current_ms - self.now)
    self.now = current_ms
    local step = dt / FADE_MS
    if self.visible then
        self.fade = math.min(1, self.fade + step)
    else
        self.fade = math.max(0, self.fade - step)
        if self.fade == 0 then self.label = nil end
    end
end

function NetworkMsg:draw()
    if not self.label then return end
    local info = NetworkMsg.LABELS[self.label]
    local lines = self.cache[self.label]
    local fade = self.fade

    tex.draw_texture(self.dim, { fade = 0.5 * fade })
    local phase = (self.now * SCROLL_PX_PER_MS) % TILE_W
    for k = 0, 21 do
        tex.draw_texture(self.bar, { frame = info.bar, x = k * TILE_W - phase, fade = fade })
    end

    local y
    if info.dots then
        y = 272 - BIG_H / 2   -- title sits above the dots, not centred on the bar
    else
        local total = 0
        for _, l in ipairs(lines) do total = total + l.h end
        y = BAR_CENTER - total / 2
    end
    for _, l in ipairs(lines) do
        l.text:draw({ x = 640 - l.text.width / 2, y = y + (l.h - l.text.height) / 2, fade = fade })
        y = y + l.h
        if info.dots then y = 310 - SMALL_H / 2 end
    end

    if info.dots then
        local f = math.floor((self.now - self.start_ms) / FRAME_MS)
        for i = 0, 5 do
            local t = f - i * DOT_START
            tex.draw_texture(self.dot, { frame = t < 0 and DOT_WAITING or dot_frame(t), x = i * DOT_PITCH, y = info.dots - 315, fade = fade })
        end
    end
end
