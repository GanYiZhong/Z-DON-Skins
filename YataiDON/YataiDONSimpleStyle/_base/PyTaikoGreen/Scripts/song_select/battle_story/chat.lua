local Chat = {}
Chat.__index = Chat

local S = tex.get_screen_scale()
local WHITE = { 255, 255, 255, 255 }
local BLACK = { 0, 0, 0, 255 }
local INK = { 32, 32, 32, 255 }
local LEFT, RIGHT, DECIDE = 1, 2, 3

-- frames: the route waits, the marker moves to the talk's node, the talk window fades in and stays empty a moment
local WAIT, MOVE, OPEN, HUSH = 60, 75, 26, 30
local SKIP_WAIT, FORCED_SKIP = 30, 1200
local LINE_SIZE, LINE_SIZE_LATIN, LINE_GAP = 30, 26, 40
-- the "continued at bond level" card on a talk's last line
local NEXT_AT, NEXT_FADE = 100, 50

local STAGES = {
    [1] = { bg = "stage_plains", path = "route_path", marker = "route_marker", top = true, barrier = true },
    [3] = { bg = "stage_rocky", path = "route_path", marker = "route_marker", top = true, barrier = true },
    [5] = { bg = "stage_seaside", path = "route_path", marker = "route_marker", top = true, barrier = true },
    [7] = { bg = "stage_volcano", path = "route_path", marker = "route_marker", top = true, barrier = true },
    [9] = { bg = "stage_lands_end", path = "route_path_final", marker = "route_marker_final" },
}

-- route nodes 0..5 (0 = off the left edge): marker centre x, streak centre x and width scale, title centre x
local ROUTE_Y = 569
local MARKER_X = { [0] = -165, 191.5, 373.5, 550.5, 732.5, 904.4 }
local STREAK_X = { [0] = -418.5, -228.5, 6.5, 174.5, 238.5, 284.5 }
local STREAK_SX = { [0] = 1, 1, 1, 1, 1.246, 1.627 }
local STREAK_Y = 625.3
local RING_X = { 198.4, 380.4, 561.4, 738.4, 919.4 }
local RING_Y = 593.5
local SPARKLES = { { 74.6, -51.7, 0.867 }, { -48.4, -94.7, 0.867 }, { 47.6, -81.3, 0.667 }, { -87.4, -59.9, 0.667 },
    { 15.6, -65.7, 1 } }
local TITLE_X = { 199.4, 380.1, 560.8, 741.5, 922.4 }
local TITLE_Y, TITLE_WIDTH = 660, 172
local CURSOR_X, CURSOR_STEP, CURSOR_Y = 205.7, 180.4, 483.4
local SEAL_X, SEAL_Y = 1108, 557
local AMITIE_CLIP = 466
local SECOND_HALF_HOP = 26

-- right-hand cast (Amitie's place). Poses rise from behind the floor by `hop` px when they come on
local AMITIE = {
    none = {},
    bust = { key = "amitie_bust" },
    bust_worried = { key = "amitie_bust_worried" },
    mic = { key = "amitie_mic" },
    smile = { key = "amitie_smile", hop = 84 },
    worried = { key = "amitie_worried", hop = 84 },
    joy = { key = "amitie_joy", hop = 114 },
    think = { key = "amitie_think", hop = 78 },
    spin = { key = "amitie_spin", hop = 113 },
    sword = { key = "amitie_sword", hop = 35 },
    lakis = { key = "lakis", hop = 36 },
    katsu = { key = "katsu", hop = 11 },
    katsu_caught = { key = "katsu_caught", hop = 10 },
    katsu_blast = { blast = { "katsu_blast_1", "katsu_blast_2", "katsu_blast_3", "katsu_blast_4", "katsu_blast_5" } },
    scylla = { key = "scylla", float = 18 },
    dragon_shadow = { key = "dragon_shadow", float = 6 },
    phoenix = { key = "phoenix", float = 10 },
    phoenix_shadow = { key = "phoenix_shadow", float = 10 },
}
-- left-hand cast (Don's place)
local DON = {
    none = {},
    normal = { key = "don_normal" },
    hop = { key = "don_normal", motion = "hop" },
    angry = { key = "don_angry", motion = "shake" },
    cheer = { key = "don_cheer", motion = "jump" },
    shock = { key = "don_shock", motion = "shake" },
    katsu = { key = "katsu", dx = -890, mirror = true },
}
-- text centre per bubble; `_r` variants are mirrored (tail on Amitie's side) and moved by dx, dy
local BUBBLES = {
    none = {},
    don = { key = "bubble_don", x = 640, y = 272 },
    don_r = { key = "bubble_don", mirror = true, dx = 1, x = 640, y = 272 },
    amitie = { key = "bubble_amitie", x = 639, y = 272 },
    shout = { key = "bubble_shout", x = 642, y = 252 },
    shout_r = { key = "bubble_shout", mirror = true, dx = 49, dy = 16, x = 650, y = 270 },
    shout_amitie = { key = "bubble_shout_amitie", x = 639, y = 270 },
    cloud = { key = "bubble_cloud", x = 591, y = 265 },
    cloud_r = { key = "bubble_cloud", mirror = true, dx = 48, dy = 9, x = 660, y = 272 },
    cloud_big = { key = "bubble_cloud_big", x = 621, y = 251 },
    cloud_big_r = { key = "bubble_cloud_big", mirror = true, dx = 17, dy = 21, x = 640, y = 272 },
    think = { key = "bubble_think", x = 628, y = 272 },
    spike = { key = "bubble_spike", x = 631, y = 272 },
    spike_yellow = { key = "bubble_spike_yellow", x = 631, y = 272 },
    cloud_yellow = { key = "bubble_cloud_yellow", x = 635, y = 272 },
    wide = { key = "bubble_wide", x = 639, y = 272 },
    wide_r = { key = "bubble_wide", mirror = true, dx = 32, x = 639, y = 272 },
    burst = { key = "bubble_burst", x = 615, y = 272 },
    burst_r = { key = "bubble_burst", mirror = true, x = 615, y = 272 },
    burst_big = { key = "bubble_burst_big", x = 609, y = 264 },
    burst_big_r = { key = "bubble_burst_big", mirror = true, x = 609, y = 264 },
    arrow = { key = "bubble_arrow", x = 658, y = 272 },
    arrow_r = { key = "bubble_arrow", mirror = true, dx = -28, x = 639, y = 272 },
    box = { key = "bubble_box", x = 639, y = 272 },
    box_r = { key = "bubble_box", mirror = true, x = 639, y = 272 },
}
-- the epilogue's talk sits further left
local EPILOGUE_BUBBLE_DX, EPILOGUE_AMITIE_DX = -85, -59
local ENDING_SPARKLES = { { 807, 257 }, { 308, 430 }, { 930, 436 }, { 413, 263 }, { 145, 115 } }

local function clamp01(v) return math.max(0, math.min(1, v)) end
local function lerp(a, b, u) return a + (b - a) * clamp01(u) end
local function triangle(f, period) return 1 - math.abs(2 * (f % period) / period - 1) end

-- { from, to, y-scale from, to, y from, to } in frames
local DON_HOP = {
    { 0, 3, 1, 0.988, 0, 2 }, { 4, 6, 0.992, 1, 1.3, 0 }, { 7, 16, 1, 1, -7.8, -78 }, { 17, 27, 1, 1, -70.9, 0 },
    { 28, 30, 0.996, 0.988, 0.65, 2 }, { 31, 33, 0.992, 1, 1.3, 0 },
}
local DON_JUMP = { { 0, 9, 1, 1, 0, -95 }, { 10, 18, 1, 1, -85.5, -9.5 } }
-- { frame, x, y }
local DON_SHAKE = { { 0, 0, 0 }, { 4, 10, -9 }, { 5, 5, -5 }, { 9, -16, 8 }, { 10, -16, 4 }, { 14, -19, -13 },
    { 15, -14, -9 }, { 18, 0, 0 } }
-- katsu_blast pieces fly apart: { dx, dy per frame, spin per frame }
local BLAST = { { -6, -9, -4 }, { 7, -11, 5 }, { -9, -3, -7 }, { 10, -5, 6 }, { 2, -13, 3 } }

local function track(rows, f)
    for _, r in ipairs(rows) do
        if f <= r[2] then
            local u = r[2] > r[1] and (f - r[1]) / (r[2] - r[1]) or 1
            return lerp(r[3], r[4], u), lerp(r[5], r[6], u)
        end
    end
    return 1, 0
end

local function shake(f)
    for i = 2, #DON_SHAKE do
        local a, b = DON_SHAKE[i - 1], DON_SHAKE[i]
        if f <= b[1] then
            local u = (f - a[1]) / math.max(1, b[1] - a[1])
            return lerp(a[2], b[2], u), lerp(a[3], b[3], u)
        end
    end
    return 0, 0
end

local function hop(height, f)
    if f < 11 then return -height * f / 11 end
    return -height * math.max(0, 1 - (f - 11) / 11)
end

local function rows_of(story, str, size, color, outline, thickness)
    local rows = {}
    for row in (str .. "\n"):gmatch("(.-)\n") do
        rows[#rows + 1] = story.text(row, size, color, outline, thickness)
    end
    return rows
end

local function draw_rows(rows, cx, cy, gap, fade)
    local width = 0
    for _, r in ipairs(rows) do width = math.max(width, r.width) end
    local top = cy * S - (#rows - 1) * gap * S / 2
    for i, r in ipairs(rows) do
        r:draw({ x = cx * S - width / 2, y = top + (i - 1) * gap * S - r.height / 2, fade = fade })
    end
end

function Chat.new(story, scene)
    local self = setmetatable({}, Chat)
    self.story, self.scene = story, scene
    self.stage = STAGES[scene.stage] or STAGES[1]
    self.latin = tex.language() ~= "ja" and tex.language() ~= "zh"
    self.titles = {}
    if not scene.epilogue then
        for n = 1, 5 do
            local ok, other = pcall(require, "song_select/battle_story/chat_" .. scene.stage .. "_" .. n)
            local str = ok and type(other) == "table" and other.title and story.pick(other.title)
                or scene.stage .. "-" .. n
            local size = 18
            repeat
                self.titles[n] = story.text(str, size, WHITE, BLACK, 3)
                size = size - 1
            until self.titles[n].width <= TITLE_WIDTH * S or size < 10
        end
    end
    self:make_labels()
    self.barrier = story.text(tex.skin_text("battle_story_barrier"), 18, WHITE, BLACK, 3)
    self.hint_next = story.text(tex.skin_text("battle_story_next"), 22, WHITE, BLACK, 3)
    self.hint_end = story.text(tex.skin_text("battle_story_end"), 22, WHITE, BLACK, 3)
    if scene.next_bond and story:is_last() then
        local str = tex.skin_text("battle_story_next_bond"):gsub("{bond}", tostring(scene.next_bond))
        self.next_bond = story.text(str, 26, WHITE, BLACK, 4)
    end
    self.lines = {}
    for i, line in ipairs(scene.lines) do
        local str = story.pick(line.text)
        if line.card == "the_end" then
            self.lines[i] = rows_of(story, str, 72, WHITE, { 60, 60, 60, 255 }, 4)
        elseif line.card == "ending" then
            self.lines[i] = rows_of(story, str, self.latin and 30 or 34, WHITE, { 20, 40, 110, 255 }, 4)
        else
            self.lines[i] = rows_of(story, str, self.latin and LINE_SIZE_LATIN or LINE_SIZE, INK)
        end
    end
    self.phrase = 0
    self.talk_at = scene.epilogue and 0 or WAIT + MOVE + OPEN
    self.ended = false
    self.played = {}
    story:music(scene.bgm or "main")
    return self
end

-- the stage banner (stages 1 and 3) or the part pill ("Stage 5-1 First Half", "Epilogue")
function Chat:make_labels()
    local story, scene = self.story, self.scene
    if scene.epilogue then
        self.pill = story.text(tex.skin_text("battle_story_epilogue"), 24, WHITE)
    elseif scene.half == "final" then
        self.pill = story.text(tex.skin_text("battle_story_final"), 24, WHITE)
    elseif scene.stage >= 5 then
        local half = scene.half and tex.skin_text("battle_story_" .. scene.half .. "_half") or ""
        self.pill = story.text(tex.skin_text("battle_story_stage") .. " " .. scene.stage .. "-" .. scene.node ..
            (half ~= "" and "  " .. half or ""), 24, WHITE)
    else
        self.stage_label = story.text(tex.skin_text("battle_story_stage"), 18, WHITE)
        self.stage_number = story.text(tostring(scene.stage), 30, WHITE)
        self.stage_name = story.text(tex.skin_text("battle_stage_" .. scene.stage), 28, { 226, 255, 64, 255 },
            { 40, 110, 20, 255 }, 3)
    end
end

-- the line shown: who wears which pose, and when each pose came on (motions replay when a pose changes)
function Chat:show(n, f)
    local line = self.scene.lines[n]
    local prev = self.cast or {}
    local cast = { amitie = line.amitie or prev.amitie or "bust", don = line.don or prev.don or "normal" }
    cast.amitie_at = (cast.amitie ~= prev.amitie or line.amitie_again) and f or prev.amitie_at
    local don_set = line.don and (line.don ~= prev.don or line.don == "hop")
    cast.don_at = (don_set or line.don_again) and f or prev.don_at
    cast.fade = line.fade or (cast.amitie == prev.amitie and prev.fade) or 1
    self.cast = cast
    self.phrase, self.phrase_at = n, f
    if line.bgm then self.story:music(line.bgm) end
    local se = type(line.se) == "table" and line.se or { line.se }
    for _, name in ipairs(se) do self.story.sound("se_" .. name) end
end

function Chat:update(f)
    local m = f - WAIT
    if not self.scene.epilogue then
        for i, at in ipairs({ 0, 24, 40 }) do
            if m >= at and not self.played[i] then
                self.played[i] = true
                self.story.sound("se_route" .. i)
            end
        end
    end
    if self.phrase == 0 and f >= self.talk_at + HUSH then self:show(1, f) end
    if self.phrase > 0 and f - self.phrase_at >= FORCED_SKIP then self:advance(f) end
    if self.next_bond and self:last() and not self.next_played and f - self.phrase_at >= NEXT_AT then
        self.next_played = true
        self.story.sound("se_nextlevel")
    end
end

function Chat:last()
    return self.phrase == #self.scene.lines
end

function Chat:advance(f)
    if self.phrase < #self.scene.lines then
        self:show(self.phrase + 1, f)
    else
        self.ended = true
        audio.play_sound("don", "sound")
    end
end

function Chat:input(action, f)
    if self.phrase == 0 or f - self.phrase_at < SKIP_WAIT then return end
    local last = self:last()
    if (last and action == DECIDE) or (not last and (action == LEFT or action == RIGHT)) then self:advance(f) end
end

function Chat:done()
    return self.ended
end

function Chat:draw_banner()
    if self.pill then
        local w = math.max(220 * S, self.pill.width + 48 * S)
        tex.draw_rounded_rect(36 * S, 32 * S, w, 56 * S, 1, { 30, 30, 30, 255 }, 4 * S, WHITE)
        self.pill:draw({ x = 36 * S + (w - self.pill.width) / 2, y = 60 * S - self.pill.height / 2 })
        return
    end
    for i = 0, 31 do
        tex.draw_rect(i * 20 * S, 36 * S, 20 * S, 54 * S, 255, 255, 255, 110 * (1 - i / 32))
    end
    tex.draw_rounded_rect(59 * S, 46 * S, 156 * S, 39 * S, 1, { 30, 30, 30, 255 }, 3 * S, WHITE)
    local lw, nw = self.stage_label.width, self.stage_number.width
    local x = 137 * S - (lw + nw + 6 * S) / 2
    self.stage_label:draw({ x = x, y = 65.5 * S - self.stage_label.height / 2 })
    self.stage_number:draw({ x = x + lw + 6 * S, y = 65.5 * S - self.stage_number.height / 2 })
    self.stage_name:draw({ x = 236 * S, y = 66 * S - self.stage_name.height / 2 })
end

function Chat:draw_route(f)
    local st, node, stage = self.story, self.scene.node, self.stage
    local second = self.scene.half == "second"
    local m = f - WAIT
    st:put(stage.path, 0, 0)
    local u = (m < 0 and not second) and 0 or (second and 1 or lerp(0, 1, (m / 17) ^ 2))
    if node > 1 or m >= 0 or second then
        st:put("route_streak", lerp(STREAK_X[node - 1], STREAK_X[node], u), STREAK_Y,
            { at = true, sx = lerp(STREAK_SX[node - 1], STREAK_SX[node], u) })
    end
    st:put("route_islands_" .. self.scene.stage, 0, 0)
    if second then
        self:draw_ring(node, f + 60)
    elseif m >= 24 then
        self:draw_ring(node, m - 24)
    end
    if stage.top then st:put("route_islands_top_" .. self.scene.stage, 0, 0) end
    local sf = f % 120
    local rise = sf < 60
    local q = (sf % 60) / 60
    st:put("route_seal_aura", SEAL_X, rise and lerp(734, 589, q) or lerp(589, 520, q),
        { at = true, sx = 0.971, sy = rise and lerp(0.164, 0.67, q) or lerp(0.66, 0.14, q),
            fade = 0.6 * (rise and q or 1 - q) })
    st:put("route_seal", SEAL_X, SEAL_Y - 9 * triangle(f, 60), { at = true })
    if stage.barrier then
        self.barrier:draw({ x = SEAL_X * S - self.barrier.width / 2, y = 661 * S - self.barrier.height / 2 })
    end
    for n = 1, 5 do
        local t = self.titles[n]
        t:draw({ x = TITLE_X[n] * S - t.width / 2, y = TITLE_Y * S - t.height / 2 })
    end
    self:draw_marker(node, m, second)
    if f >= WAIT + MOVE then self:draw_cursor(node, f - WAIT - MOVE) end
end

function Chat:draw_ring(node, r)
    local st = self.story
    local x = RING_X[node]
    local pulse = r < 12 and 1 + 0.162 * triangle(r, 24) or 1 + 0.087 * triangle(r - 12, 60)
    local p = (r % 60) / 60
    local up = p < 0.5
    st:put("route_pillar", x, up and lerp(683, 570, p * 2) or lerp(570, 527, p * 2 - 1),
        { at = true, sy = up and lerp(0.4, 1, p * 2) or lerp(1, 0.393, p * 2 - 1), fade = up and p * 2 or 2 - p * 2 })
    st:put("route_ring", x, RING_Y, { at = true, s = pulse })
    local tw = triangle(r, 60)
    for _, s in ipairs(SPARKLES) do
        st:put("route_sparkle", x + s[1], RING_Y + s[2], { at = true, s = s[3], fade = 1 - tw })
    end
end

-- a first half (or whole talk) moves the marker in from the last node; a second half hops it in place
function Chat:draw_marker(node, m, second)
    local x, lift, squash = second and MARKER_X[node] or MARKER_X[node - 1], 0, 1
    if m >= 40 then
        local h = m - 40
        if not second then x = lerp(MARKER_X[node - 1], MARKER_X[node], h / 28) end
        if h < 28 then
            lift = (second and SECOND_HALF_HOP or node == 1 and 60 or 36) * math.sin(math.pi * h / 28)
        elseif h < 34 then
            squash = 1 - 0.048 * triangle(h - 28, 6)
        end
    end
    self.story:put(self.stage.marker, x, ROUTE_Y + 84 - lift, { at = true, ay = 1, sy = squash })
end

function Chat:draw_cursor(node, c)
    local fade, y = 1, CURSOR_Y
    if c < 5 then
        fade, y = 0.86 * c / 5, 513.4 - 3 * c / 5
    elseif c < 15 then
        fade, y = lerp(0.875, 1, (c - 5) / 10), lerp(510.4, CURSOR_Y, (c - 5) / 10)
    else
        fade = 1 - 0.41 * triangle(c - 15, 90)
    end
    self.story:put("route_cursor", CURSOR_X + CURSOR_STEP * (node - 1), y, { at = true, fade = fade })
end

function Chat:draw_right(f)
    local st, cast = self.story, self.cast
    local pose = AMITIE[cast.amitie] or AMITIE.none
    local af = f - cast.amitie_at
    local dx = self.scene.epilogue and EPILOGUE_AMITIE_DX or 0
    tex.begin_scissor(640 * S, 0, 640 * S, AMITIE_CLIP * S)
    if pose.blast then
        for i, key in ipairs(pose.blast) do
            local v = BLAST[i]
            local t = math.min(af, 40)
            st:put(key, v[1] * t, v[2] * t + 0.35 * t * t, { fade = clamp01(1 - (af - 20) / 20) })
        end
    elseif pose.key then
        local dy = pose.hop and hop(pose.hop, af) or 0
        if pose.float then dy = pose.float * math.sin(af * math.pi / 60) end
        st:put(pose.key, dx, dy, { fade = cast.fade })
    end
    tex.end_scissor()
end

function Chat:draw_left(f)
    local don = DON[self.cast.don] or DON.none
    if not don.key then return end
    local df = f - self.cast.don_at
    local dx, dy, sy = don.dx or 0, 0, 1
    if don.motion == "hop" then
        sy, dy = track(DON_HOP, df)
    elseif don.motion == "jump" then
        sy, dy = track(DON_JUMP, df)
    elseif don.motion == "shake" then
        local sx, sdy = shake(df)
        dx, dy = dx + sx, sdy
    end
    self.story:put(don.key, dx, dy, { ay = 1, sy = sy, mirror = don.mirror })
end

function Chat:draw_card(line, f)
    local st = self.story
    local fade = clamp01((f - self.phrase_at) / 15)
    local rows = self.lines[self.phrase]
    if line.card == "the_end" then
        draw_rows(rows, 650, 270, 80, fade)
        return
    end
    st:put("ending_art", 0, 0, { fade = fade })
    st:put("ending_panel", 0, 0, { fade = fade })
    for i, s in ipairs(ENDING_SPARKLES) do
        local tw = triangle(f + i * 13, 50)
        st:put("ending_sparkle", s[1] + 33, s[2] + 38, { at = true, s = 0.6 + 0.6 * tw, fade = fade * tw })
    end
    draw_rows(rows, 654, 512, 46, fade)
end

function Chat:draw_talk(f)
    local st = self.story
    local fade = self.scene.epilogue and 1 or clamp01((f - WAIT - MOVE) / OPEN)
    if fade <= 0 then return end
    st:put("talk_band", 0, 0, { fade = fade })
    if self.phrase == 0 then return end
    local line = self.scene.lines[self.phrase]
    if line.card then
        self:draw_card(line, f)
        self:draw_hint(f)
        return
    end
    st:put("talk_floor", 0, 0)
    self:draw_right(f)
    self:draw_left(f)
    if line.fx == "harpies" then st:put("harpies", 0, 8 * math.sin((f - self.phrase_at) * math.pi / 30)) end
    local bubble = BUBBLES[line.bubble] or BUBBLES.don
    local bdx = self.scene.epilogue and EPILOGUE_BUBBLE_DX or 0
    if bubble.key then
        st:put(bubble.key, (bubble.dx or 0) + bdx, bubble.dy or 0, { mirror = bubble.mirror })
        draw_rows(self.lines[self.phrase], bubble.x + bdx, bubble.y, LINE_GAP)
    end
    self:draw_next_bond(f)
    self:draw_hint(f)
end

function Chat:draw_next_bond(f)
    if not (self.next_bond and self:last()) then return end
    local fade = clamp01((f - self.phrase_at - NEXT_AT) / NEXT_FADE)
    if fade <= 0 then return end
    local t = self.next_bond
    local w, h = t.width + 60 * S, 56 * S
    local x, y = 640 * S - w / 2, 373 * S - h / 2
    tex.draw_rounded_rect(x, y, w, h, 1, { 40, 40, 40, math.floor(200 * fade) }, 3 * S,
        { 255, 255, 255, math.floor(255 * fade) })
    t:draw({ x = 640 * S - t.width / 2, y = 373 * S - t.height / 2, fade = fade })
end

function Chat:draw_hint(f)
    local last = self:last()
    local wait = last and 9 or 45
    local fade = clamp01((f - self.phrase_at - wait) / 15)
    if fade <= 0 then return end
    local t = last and self.hint_end or self.hint_next
    self.story:put(last and "hint_face" or "hint_rim", 0, 0, { fade = fade })
    t:draw({ x = 1157 * S - t.width, y = 70 * S - t.height / 2, fade = fade })
end

function Chat:draw(f)
    self.story:backdrop(self.stage.bg)
    self:draw_banner()
    if not self.scene.epilogue then self:draw_route(f) end
    self:draw_talk(f)
end

return Chat
