-- YataiDONSimpleStyle v2: result / dan result backdrop (our own textures only).
--   1P (player_num 1/2): sky with drifting clouds, lantern string, the festival stage floor + taiko
--   2P (3): sky band + floor under the two boards     DAN (4): the dan result backdrop
ResultBackground = {}
ResultBackground.__index = ResultBackground

local U = 3

function ResultBackground.new(player_num, width)
    local self = setmetatable({}, ResultBackground)
    self.player_num = player_num
    self.t0 = tex.get_current_ms()
    if player_num == 4 then
        self.t_bg = tex.get_texture("dan_result/ss/bg")
    elseif player_num == 3 then
        self.t_bg = tex.get_texture("result/ss/bg_2p")
    else
        self.t_bg = tex.get_texture("result/ss/bg_1p")
        self.t_cm = tex.get_texture("result/ss/cloud_m")
        self.t_cs = tex.get_texture("result/ss/cloud_s")
    end
    return self
end

-- clouds drift 1U every 500 ms (bible 2.4) and wrap behind the board
local function cloud(t, x0, y, w, drift)
    if not t then return end
    local span = 1920 + w
    local x = (x0 + drift + w) % span - w
    tex.draw_texture(t, { x = x, y = y })
end

function ResultBackground:draw()
    if self.t_bg then tex.draw_texture(self.t_bg, {}) end
    if self.t_cm then
        local drift = math.floor((tex.get_current_ms() - self.t0) / 500) * U
        cloud(self.t_cm, 1290, 219, 162, drift)
        cloud(self.t_cs, 1650, 327, 108, drift)
    end
end
