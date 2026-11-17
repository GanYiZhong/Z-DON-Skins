require("entry/mac_popup")

CampaignMenu = {}
CampaignMenu.__index = CampaignMenu

local S = tex.get_screen_scale()
local FADE_MS = 250
local WAIT_MS = 1500
local SELECT_MS = 30000
local SLIDE_MS = 150
local OUT_MS, IN_MS = 167, 150
local ARROW_MS, ARROW_DX, ARROW_GAP = 1000, 30 * S, 600 * S
-- small panel left edge by slot offset; the centre slot sits under the big panel
local SLOT_X = { [-2] = -338, [-1] = 17, [0] = 482, [1] = 947, [2] = 1302 }
local SLOT_STEP, SLOT_Y = 355, 262 * S
local LEFT, RIGHT, DECIDE = 1, 2, 3

local function clamp01(v) return math.max(0.0, math.min(1.0, v)) end

local F = 1000 / 60
local HINT_K, HINT_Y, HINT_FONT = 0.85, 620, 28
local DRUM_R_DX, ARROW_R_DX = 329.8, 122.4
local WHITE, BLACK = { 255, 255, 255, 255 }, { 0, 0, 0, 255 }

local WORDS = {
    { tex = "rim", f = 0, d = 1.28, lift = 6.75 },
    { text = "campaign_hint_by", x = 545.65, f = 0, d = 1.091, lift = 2.15 },
    { text = "campaign_hint_select", x = 616.2, f = 66, d = 1.214, lift = 5.1 },
    { tex = "face", f = 181, d = 1.28, lift = 6.75 },
    { text = "campaign_hint_by", x = 834.65, f = 181, d = 1.091, lift = 2.15 },
    { text = "campaign_hint_decide", x = 883.1, f = 246, d = 1.214, lift = 5.1 },
}

local RIM_GLOW_L = { { 0, 0 }, { 20, 1 }, { 40, 0 }, { 65, 0 }, { 65, 1 }, { 180, 1 }, { 185, 0 },
                     { 361, 0 }, { 390, 1 }, { 420, 0 } }
local RIM_GLOW_R = { { 0, 0 }, { 20, 1 }, { 40, 0 }, { 361, 0 }, { 390, 1 }, { 420, 0 },
                     { 425, 0 }, { 425, 1 }, { 540, 1 }, { 545, 0 } }
local RIM_STICK_L = { { 65, 0 }, { 65, 1 }, { 180, 1 }, { 185, 0 } }
local RIM_STICK_R = { { 425, 0 }, { 425, 1 }, { 540, 1 }, { 545, 0 } }
local ARROW_L = { { 65, 0 }, { 65, 1 }, { 125, 0 }, { 125, 1 }, { 180, 1 }, { 185, 0 } }
local ARROW_R = { { 425, 0 }, { 425, 1 }, { 485, 0 }, { 485, 1 }, { 540, 1 }, { 545, 0 } }
local FACE_DOT = { { 181, 0 }, { 210, 1 }, { 240, 0 }, { 245, 0 }, { 245, 1 }, { 355, 1 }, { 360, 0 } }
local FACE_STICK = { { 245, 0 }, { 245, 1 }, { 355, 1 }, { 360, 0 } }

local function env(f, keys)
    if f < keys[1][1] then return keys[1][2] end
    for i = 2, #keys do
        local a, b = keys[i - 1], keys[i]
        if f < b[1] then return a[2] + (b[2] - a[2]) * (f - a[1]) / (b[1] - a[1]) end
    end
    return keys[#keys][2]
end

-- 19 frames up, 20 down: {y stretch, lift}
local function bounce(f, w)
    local u = f - w.f
    if u < 0 or u >= 40 then return 1, 0 end
    local p = u < 20 and u / 19 or (40 - u) / 20
    return 1 + (w.d - 1) * p, w.lift * HINT_K * p
end

local function slot_x(offset)
    local lo = math.floor(offset)
    local function at(k)
        if k < -2 then return SLOT_X[-2] + (k + 2) * SLOT_STEP end
        if k > 2 then return SLOT_X[2] + (k - 2) * SLOT_STEP end
        return SLOT_X[k]
    end
    return (at(lo) + (at(lo + 1) - at(lo)) * (offset - lo)) * S
end

function CampaignMenu.new(ids, opts)
    opts = opts or {}
    for _, id in ipairs(ids) do
        if id == "mac" and not opts.dir then return MacPopup.new() end
    end
    local self = setmetatable({}, CampaignMenu)
    self.ids = opts.dir and {} or { "skip" }
    for _, id in ipairs(ids) do self.ids[#self.ids + 1] = id end
    local dir = opts.dir or "entry/campaign"
    self.small, self.main = {}, {}
    for _, id in ipairs(self.ids) do
        self.small[id] = tex.get_texture(dir .. "/" .. id .. "_small")
        self.main[id] = tex.get_texture(dir .. "/" .. id .. "_main")
    end
    self.arrow = tex.get_texture(dir .. "/arrow")
    self.hint = {}
    for _, k in ipairs({ "bar", "rim", "face", "drum", "rim_glow", "rim_stick", "arrow", "face_dot", "face_stick" }) do
        self.hint[k] = tex.get_texture(dir .. "/hint_" .. k)
    end
    self.hint_text = {}
    for _, w in ipairs(WORDS) do
        if w.text and not self.hint_text[w.text] then
            local str = tex.skin_text(w.text)
            self.hint_text[w.text] = str ~= "" and
                text.create_raw_text(str, math.floor(HINT_FONT * S), WHITE, BLACK, false, 5, 2.0) or false
        end
    end
    self.current = 1
    self.t0 = tex.get_current_ms()
    self.now = self.t0
    self.turn = nil
    self.decided = nil
    self.voices = opts.voices or {}
    local sound = opts.sound or "campaign_entry"
    if audio.has_sound(sound) then audio.play_sound(sound, "sound") end
    return self
end

function CampaignMenu:update(current_ms)
    self.now = current_ms
    if not self.decided and current_ms - self.t0 >= WAIT_MS + SELECT_MS then
        self:decide()
    end
    local turn = self.turn
    if turn and not turn.voiced and current_ms - turn.t0 >= OUT_MS then
        turn.voiced = true
        local voice = self.voices[self.ids[self.current]]
        if voice and audio.has_sound(voice) then audio.play_sound(voice, "voice") end
    end
    if self.turn and current_ms - self.turn.t0 >= OUT_MS + IN_MS then
        self.turn = nil
    end
end

function CampaignMenu:decide()
    self.decided = self.now
end

function CampaignMenu:input(action)
    if self.decided or self.turn or self.now - self.t0 < WAIT_MS then
        return false
    end
    if action == DECIDE then
        self:decide()
        return true
    end
    local dir = action == RIGHT and 1 or -1
    self.turn = { dir = dir, t0 = self.now, from = self.current }
    self.current = (self.current - 1 + dir) % #self.ids + 1
    return true
end

function CampaignMenu:is_done()
    return self.decided ~= nil and self.now - self.decided >= FADE_MS
end

function CampaignMenu:get_choice()
    return self.ids[self.current]
end

function CampaignMenu:draw_hint(fade)
    local h = self.hint
    local t = self.now - self.t0
    local wf, df = (t / F) % 360, (t / F) % 720
    tex.draw_texture(h.bar, { fade = fade })
    for _, w in ipairs(WORDS) do
        local st, lift = bounce(wf, w)
        if w.tex then
            local hgt = 48 * HINT_K * S
            tex.draw_texture(h[w.tex], { y = -hgt * (st - 1) / 2 - lift * S, y2 = hgt * (st - 1), fade = fade })
        elseif self.hint_text[w.text] then
            local tx = self.hint_text[w.text]
            local sc = math.min(1, 122.4 * S / tx.width)
            local wd, hgt = tx.width * sc, tx.height * sc * st
            tx:draw({ x = w.x * S - wd / 2, y = HINT_Y * S - hgt / 2 - lift * S,
                      x2 = wd - tx.width, y2 = hgt - tx.height, fade = fade })
        end
    end
    local dr, ar = DRUM_R_DX * S, ARROW_R_DX * S
    tex.draw_texture(h.drum, { fade = fade })
    tex.draw_texture(h.drum, { x = dr, fade = fade })
    tex.draw_texture(h.rim_glow, { fade = fade * env(df, RIM_GLOW_L) })
    tex.draw_texture(h.rim_glow, { mirror = "horizontal", fade = fade * env(df, RIM_GLOW_R) })
    tex.draw_texture(h.rim_stick, { fade = fade * env(df, RIM_STICK_L) })
    tex.draw_texture(h.rim_stick, { mirror = "horizontal", fade = fade * env(df, RIM_STICK_R) })
    tex.draw_texture(h.arrow, { fade = fade * env(df, ARROW_L) })
    tex.draw_texture(h.arrow, { x = ar, mirror = "horizontal", fade = fade * env(df, ARROW_R) })
    tex.draw_texture(h.face_dot, { fade = fade * env(wf, FACE_DOT) })
    tex.draw_texture(h.face_stick, { fade = fade * env(wf, FACE_STICK) })
end

function CampaignMenu:draw()
    local fade = clamp01((self.now - self.t0) / FADE_MS)
    if self.decided then fade = 1 - clamp01((self.now - self.decided) / FADE_MS) end
    local n = #self.ids

    -- mid-turn every slot is still `dir` slots short of where it lands
    local shift = 0
    if self.turn then shift = self.turn.dir * (1 - clamp01((self.now - self.turn.t0) / SLIDE_MS)) end
    for k = -3, 3 do
        local offset = k + shift
        if offset > -3 and offset < 3 then
            local id = self.ids[(self.current - 1 + k) % n + 1]
            tex.draw_texture(self.small[id], { x = slot_x(offset), y = SLOT_Y,
                                               fade = fade * clamp01(math.abs(offset)) })
        end
    end

    local id, main_fade = self.ids[self.current], 1
    if self.turn then
        local el = self.now - self.turn.t0
        if el < OUT_MS then
            id, main_fade = self.ids[self.turn.from], 1 - el / OUT_MS
        else
            main_fade = clamp01((el - OUT_MS) / IN_MS)
        end
    end
    tex.draw_texture(self.main[id], { fade = fade * main_fade })

    local el = self.now - self.t0 - WAIT_MS
    if el >= 0 and not self.decided then
        local u = (el % ARROW_MS) / ARROW_MS
        tex.draw_texture(self.arrow, { x = -ARROW_DX * u, fade = fade * (1 - u) })
        tex.draw_texture(self.arrow, { x = ARROW_GAP + ARROW_DX * u, fade = fade * (1 - u), mirror = "horizontal" })
    end
    self:draw_hint(fade)
end
