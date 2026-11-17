local Stage = {}
Stage.__index = Stage

local S = tex.get_screen_scale()
local WHITE = { 255, 255, 255, 255 }
local BLACK = { 0, 0, 0, 255 }
local DECIDE = 3
local LOOP_AT, LOOP_LEN = 250, 81
local HEADLINE = { ja = "あたらしいステージにすすもう!", en = "On to a new stage!" }
local HEADLINE_FILL, HEADLINE_LINE = { 236, 247, 175, 255 }, { 40, 90, 0, 255 }
local BADGE_X, BADGE_W, BADGE_H, NAME_DY = 108, 152, 47, 80
local BADGE_BACK = { 20, 18, 10, 255 }
-- speed lines pulse bigger on these frame groups
local PULSES = { 39, 47, 55, 63 }

local function clamp01(v) return math.max(0, math.min(1, v)) end
local function lerp(a, b, u) return a + (b - a) * clamp01(u) end

local function pulsing(f)
    for _, p in ipairs(PULSES) do
        if f >= p and f <= p + 3 then return true end
    end
    return false
end

function Stage.new(story, scene)
    local self = setmetatable({}, Stage)
    self.story, self.scene = story, scene
    local n = scene.stage
    self.headline = story.text(story.pick(HEADLINE), 68, HEADLINE_FILL, HEADLINE_LINE, 6)
    self.halo = story.text(story.pick(HEADLINE), 68, WHITE, WHITE, 12)
    local badge = story.pick({ ja = "ステージ" .. n, en = "Stage " .. n })
    self.badge = story.text(badge, 26, scene.accent, BLACK, 3)
    local size, name = 72, tex.skin_text("battle_stage_" .. n)
    repeat
        self.name = story.text(name, size, scene.fill, scene.line, 6)
        size = size - 1
    until self.name.width <= 640 * S or size < 20
    self.hint = story.text(tex.skin_text("battle_story_end"), 20, WHITE)
    self.ended, self.sounded = false, 0
    story:music(scene.bgm or "main")
    return self
end

function Stage:frame(f)
    if f < LOOP_AT then return f end
    return LOOP_AT + (f - LOOP_AT) % LOOP_LEN
end

local SOUNDS = { { 200, "ambience" }, { 222, "vo_stage_amt", "voice" }, { 237, "se_stage_enemies" } }

function Stage:update(f)
    for i = self.sounded + 1, #SOUNDS do
        if f < SOUNDS[i][1] then break end
        local s = SOUNDS[i][2]
        self.story.sound(s == "ambience" and self.scene.ambience or s, SOUNDS[i][3])
        self.sounded = i
    end
end

function Stage:input(action, f)
    if action == DECIDE and f >= LOOP_AT then
        self.ended = true
        audio.play_sound("don", "sound")
    end
end

function Stage:done()
    return self.ended
end

function Stage:draw_lines(f)
    local st = self.story
    local white, green, s = 0, 0, 1
    if f <= 35 then
        white, green = lerp(0, 0.5, f / 35), lerp(0, 0.523, f / 34)
    elseif f <= 66 then
        white, green = 0.5, 0.5
        if pulsing(f) then s = 1.406 end
    elseif f <= 155 then
        white, green = lerp(0.551, 0.121, (f - 67) / 88), lerp(0.398, 0.09, (f - 67) / 88)
    elseif f <= 177 then
        local u = (f - 156) / 21
        white, green, s = lerp(0.117, 0, u), lerp(0.086, 0, u), lerp(1.018, 1.406, u)
    end
    if white > 0 then st:put("stage_lines_white", 0, 0, { fade = white, s = s }) end
    if green > 0 then st:put("stage_lines_green", 0, 0, { fade = green, s = 2 * s }) end
end

local function draw_scaled(t, cx, cy, s, fade)
    t:draw({ x = cx * S - t.width / 2, y = cy * S - t.height / 2, scale = s, center = true, fade = fade })
end

function Stage:draw_headline(f)
    if f < 23 or f > 165 then return end
    local s, fade, halo
    if f <= 31 then
        local u = (f - 23) / 8
        s, fade, halo = lerp(0.909, 1.364, u), lerp(0, 0.73, u), lerp(0, 1, u)
    elseif f <= 35 then
        local u = (f - 32) / 3
        s, fade, halo = lerp(1.273, 1, u), lerp(0.8, 1, u), lerp(0.93, 0.7, u)
    elseif f <= 155 then
        s, fade = 1, 1
        halo = f <= 95 and lerp(0.695, 0.398, 1 - (1 - (f - 36) / 59) ^ 2) or lerp(0.41, 1, (f - 96) / 59)
    else
        local u = (f - 156) / 9
        s, fade, halo = lerp(1.036, 1.364, u), lerp(0.9, 0, u), lerp(0.9, 0, u)
    end
    draw_scaled(self.halo, 640, 360, s, halo * 0.6)
    draw_scaled(self.headline, 640, 360, s, fade)
end

function Stage:draw_title(f)
    local sc, st = self.scene, self.story
    local fade = clamp01((f - 222) / 15)
    if sc.glow and f >= LOOP_AT then
        local u = f <= 290 and (f - 250) / 40 or 1 - (f - 291) / 39
        st:put(sc.glow, 0, 0, { sy = lerp(1, 1.667, u), fade = lerp(0, 0.25, u) })
    end
    local y = sc.title_y
    local back = { BADGE_BACK[1], BADGE_BACK[2], BADGE_BACK[3], 255 * fade }
    local line = { sc.accent[1], sc.accent[2], sc.accent[3], 255 * fade }
    tex.draw_rounded_rect(BADGE_X * S, (y - BADGE_H / 2) * S, BADGE_W * S, BADGE_H * S, 1, back, 3 * S, line)
    local b = self.badge
    b:draw({ x = (BADGE_X + BADGE_W / 2) * S - b.width / 2, y = y * S - b.height / 2, fade = fade })
    self.name:draw({ x = (BADGE_X + 4) * S, y = (y + NAME_DY) * S - self.name.height / 2, fade = fade })
end

-- enemies jump in from below, squashed, and bob each loop
function Stage:draw_enemies(f)
    local sc, st = self.scene, self.story
    if f < 222 then return end
    st:put(sc.key .. "_shadows", 0, 0, { fade = lerp(0, sc.shadow, (f - 239) / 8) })
    local dy, sy, fade = 0, 1, 1
    if f <= 237 then
        local u = (f - 222) / 15
        dy, sy, fade = lerp(105.4, -63.6, u), lerp(0.083, 1.055, u), u
    elseif f <= 246 then
        local u = (f - 238) / 8
        dy, sy = lerp(-55.55, 9, u), lerp(1.042, 0.938, u)
    elseif f <= 250 then
        local u = (f - 247) / 3
        dy, sy = lerp(6.8, 0, u), lerp(0.953, 1, u)
    elseif f >= 287 and f <= 300 then
        local u = f <= 290 and (f - 287) / 3 or 1 - (f - 291) / 9
        dy, sy = lerp(0, 2, u), lerp(1, 0.986, u)
    end
    st:put(sc.key .. "_enemies", 0, dy, { sy = sy, fade = fade })
end

function Stage:draw(f)
    local sc, st = self.scene, self.story
    local lf = self:frame(f)
    if lf <= 188 then st:backdrop(sc.from) end
    if lf >= 172 then
        tex.draw_texture(st:id("game/battle_stage/" .. sc.to), { fade = clamp01((lf - 172) / 16) })
    end
    if sc.haze and lf >= 200 then
        st:put(sc.haze, 0, 0, { s = 1.778, fade = clamp01((lf - 200) / 47) })
    end
    self:draw_lines(lf)
    self:draw_enemies(lf)
    if lf >= 222 then self:draw_title(lf) end
    self:draw_headline(lf)
    if f >= LOOP_AT then st:draw_hint(self.hint) end
end

return Stage
