local Boss = {}
Boss.__index = Boss

local S = tex.get_screen_scale()
local FRAME_MS = 1000 / 60
local WHITE = { 255, 255, 255, 255 }
local BLACK = { 0, 0, 0, 255 }
local DECIDE = 3
local STAGES = require("game/enso_stages")
local HEADLINE = { ja = "ボスがあらわれた!", en = "A boss appears!" }
local HEADLINE_FILL, HEADLINE_GLOW = { 235, 170, 250, 255 }, { 170, 50, 100, 255 }
local GUARD = { ja = "をまもるもの", en = "Guardian of the" }
local GUARD_FILL = { 245, 240, 200, 255 }
local NAME_X, NAME_Y, SUB_X, SUB_Y, EMBLEM_X, EMBLEM_Y = 367, 333, 143, 439, 241, 468
-- the title group starts here; the player can finish once it has settled
local TITLE_AT, HOLD_AT = 187, 257
local PULSES = { 45, 55, 65, 75 }
-- the three title lines: rest centre, x-scale, y-scale, entry frame, frames to slide, slide-from x, from scale
local LINES = {
    { 534, 403, 0.603, 0.714, 51, 10, 363, 0.052, 0.714 },
    { 466, 395, 0.776, 1, 57, 10, 251, 0.052, 0.429 },
    { 575, 470, 0.603, 1, 62, 5, 729, 0.086, 1 },
}

local function clamp01(v) return math.max(0, math.min(1, v)) end
local function lerp(a, b, u) return a + (b - a) * clamp01(u) end
local function ease_out(u) u = clamp01(u) return 1 - (1 - u) * (1 - u) end
-- 0 -> 1 -> 0 over `period` frames
local function tri(f, period) local u = f % period / period return 1 - math.abs(2 * u - 1) end

-- draws the in-game boss rigs (enso_stages.lua) from Graphics/game, shifted onto the intro's spot
local Rig = {}
Rig.__index = Rig

function Rig:spr(key, x, y, o)
    o = o or {}
    local folder = key:sub(1, 6) == "stage_" and "battle_stage" or "enso_battle"
    local id = self.story:id("game/" .. folder .. "/" .. key)
    local w, h = self.story:size(folder, key)
    w, h = w * S, h * S
    local sx, sy = o.sx or o.s or 1, o.sy or o.s or 1
    tex.draw_texture(id, {
        x = (x + self.dx) * S, y = (y + self.dy) * S,
        x2 = w * (sx - 1), y2 = h * (sy - 1),
        origin = { w * sx * (o.ax or 0.5), h * sy * (o.ay or 0.5) },
        rotation = o.rot or 0,
        fade = (o.fade or 1) * self.fade,
        blend = o.add and "additive" or nil,
    })
end

-- entries: offset from the rest spot, vertical squash and fade at frame f, or nil while hidden
local ENTRY = {}

-- falls in from the upper right, hops back up and lands
function ENTRY.drop(f)
    if f < 120 then return nil end
    if f <= 138 then
        local u = (f - 120) / 18
        return lerp(86, -48, u), lerp(-257, 0, u), 1, u
    elseif f <= 150 then
        local u = (f - 139) / 11
        return lerp(-47, -32, u), lerp(-4, -48, u), 1, 1
    end
    local u = clamp01((f - 151) / 19) ^ 2
    return lerp(-29, 0, u), lerp(-47, 0, u), 1, 1
end

-- drops straight down left of its spot, bounces, then slides right to make room for the title
function ENTRY.slam(f)
    if f < 115 then return nil end
    local dx, dy, sy = -313, 0, 1
    if f <= 134 then
        local u = (f - 115) / 19
        dx, dy, sy = dx + lerp(35, 0, u), lerp(-728, -8, u), lerp(1, 0.95, u)
    elseif f <= 147 then
        dy = lerp(-21, -179, (f - 135) / 12)
    elseif f <= 154 then
        local u = (f - 148) / 6
        dy, sy = lerp(-153, 0, u), lerp(0.994, 0.927, u)
    elseif f <= 163 then
        sy = ({ 0.952, 1, 1, 0.976, 0.927, 0.927, 0.952, 1, 1 })[math.floor(f) - 154]
    elseif f >= 178 then
        dx = -313 + lerp(30, 313, ease_out((f - 178) / 147))
    end
    return dx, dy, sy, 1
end

-- Maou springs up in front of his throne, stretching on the way up and squashing as he lands
function ENTRY.maou(f)
    if f < 189 then return nil end
    if f <= 198 then
        local u = (f - 189) / 9
        return 0, lerp(18, -59, u), lerp(0.908, 1.383, u), u
    elseif f <= 205 then
        local u = (f - 199) / 6
        return 0, lerp(-59, 15, u), lerp(1.383, 0.949, u), 1
    end
    local u = (f - 206) / 4
    return 0, lerp(12, 0, u), lerp(0.959, 1, u), 1
end

local SETTLE = { drop = 170, slam = 164, dragon = 184, maou = 211 }
-- Maou's plate (logo and name) fades in here over a glow that swells and fades every 160 frames
local PLATE_AT, PLATE_X, PLATE_NAME_Y = 240, 641, 598
local QUAKE_FROM, QUAKE_TO, QUAKE_STEP = 140, 202, 12

-- the largest text up to `size` that fits `width`, with a glow copy behind it
local function fit(story, str, size, width, fill, glow, thickness, glow_thickness)
    local t
    repeat
        t = story.text(str, size, fill, BLACK, thickness)
        size = size - 2
    until t.width <= width * S or size < 30
    return t, story.text(str, size + 2, glow, glow, glow_thickness)
end

function Boss.new(story, scene)
    local self = setmetatable({}, Boss)
    self.story, self.scene = story, scene
    self.def = STAGES[scene.stage].boss
    self.rig = setmetatable({ story = story, dx = 0, dy = 0, fade = 1 }, Rig)
    local pick = story.pick
    local headline = pick(scene.headline or HEADLINE)
    self.headline = story.text(headline, 76, HEADLINE_FILL, BLACK, 5)
    self.headline_glow = story.text(headline, 76, HEADLINE_GLOW, HEADLINE_GLOW, 12)
    if scene.plate then
        self.name = story.text(pick(scene.name), 54, WHITE, { 80, 20, 150, 255 }, 6)
    elseif scene.entry == "dragon" then
        self.badge = story.text(pick({ ja = "ステージ10", en = "Stage 10" }), 22, WHITE, BLACK, 3)
        self.final, self.final_glow = fit(story, pick({ ja = "最終決戦", en = "Final Battle" }), 72, 300, WHITE,
            WHITE, 6, 14)
        self.name, self.glow = fit(story, pick(scene.name), 104, 300, WHITE, WHITE, 7, 16)
    else
        self.name, self.glow = fit(story, pick(scene.name), 92, 560, scene.fill, scene.glow, 5, 16)
        local stage, guard = tex.skin_text("battle_stage_" .. scene.stage), pick(GUARD)
        local parts = tex.language() == "ja" and { { stage, true }, { guard } } or { { guard }, { stage, true } }
        self.sub = {}
        for _, p in ipairs(parts) do
            local fill = p[2] and scene.sub_fill or GUARD_FILL
            self.sub[#self.sub + 1] = {
                text = story.text(p[1], p[2] and 46 or 38, fill, BLACK, 4),
                glow = p[2] and story.text(p[1], 46, scene.glow, scene.glow, 12),
                shine = p[2] and story.text(p[1], 46, WHITE, BLACK, 4),
            }
        end
    end
    self.hint = story.text(tex.skin_text("battle_story_end"), 20, WHITE)
    local fall, land = scene.fall or 120, scene.land or 138
    if scene.entry == "maou" then
        self.sounds = { { QUAKE_FROM, "se_maou_quake" }, { 189, "se_maou_appear" } }
    elseif scene.entry == "dragon" then
        self.sounds = { { 140, "se_dragon_appear" }, { TITLE_AT, "se_boss_title" },
            { TITLE_AT, "vo_lastboss_amt", "voice" }, { TITLE_AT + 40, "se_boss_subtitle" } }
    else
        self.sounds = { { fall, "se_boss_fall" }, { land, "se_boss_land" }, { TITLE_AT, "se_boss_title" },
            { TITLE_AT, "vo_boss_amt", "voice" }, { TITLE_AT + 53, "se_boss_subtitle" } }
    end
    self.hold = scene.hold or HOLD_AT
    self.ended, self.sounded = false, 0
    story:music("boss")
    return self
end

function Boss:update(f)
    for i = self.sounded + 1, #self.sounds do
        if f < self.sounds[i][1] then break end
        self.story.sound(self.sounds[i][2], self.sounds[i][3])
        self.sounded = i
    end
end

function Boss:input(action, f)
    if action == DECIDE and f >= self.hold then
        self.ended = true
        audio.play_sound("don", "sound")
    end
end

function Boss:done()
    return self.ended
end

local function draw_at(t, cx, cy, o)
    o = o or {}
    t:draw({ x = cx * S - t.width / 2, y = cy * S - t.height / 2, scale = o.s, center = o.s and true or nil,
        fade = o.fade })
end

function Boss:draw_backdrops(f)
    local sc, st = self.scene, self.story
    if sc.throne then
        -- the throne room shakes as Maou stamps behind it
        local s = 1
        if f >= QUAKE_FROM and f <= QUAKE_TO then s = 1 + 0.055 * (1 - (f - QUAKE_FROM) % QUAKE_STEP / QUAKE_STEP) end
        st:put(sc.throne, 640, 360, { at = true, s = s, fade = clamp01(f / 40) })
        return
    end
    st:backdrop(sc.from)
    if sc.to ~= sc.from and f >= 77 then
        tex.draw_texture(st:id("game/battle_stage/" .. sc.to), { fade = clamp01((f - 77) / 37) })
    end
    if sc.scenery then
        local k, x, y = sc.scenery[1], sc.scenery[2], sc.scenery[3]
        local u = clamp01((f - 138) / 6)
        self.rig.dx, self.rig.dy, self.rig.fade = 0, 0, clamp01((f - 77) / 37)
        if f >= 77 then self.rig:spr(k, x + (f >= 138 and 21 * (1 - u) or 0), y - (f >= 138 and 20 * (1 - u) or 0)) end
    end
    if sc.vignette and f >= 115 then
        st:put("boss_vignette", 320, 180, { s = 2, fade = lerp(0.4, 0.75, (f - 115) / 461) })
    end
end

function Boss:draw_aura(f)
    local a = self.scene.aura
    if not a or f < a.at then return end
    local t = f - a.at
    local fade = t <= 60 and a.peak * t / 60 or a.peak * (0.5 + 0.5 * math.cos(2 * math.pi * (t - 60) / 120))
    self.story:put(a[1], a[2], a[3], { at = true, s = a.s or 1, add = a.add, fade = fade })
end

function Boss:draw_boss(f)
    local sc, rig = self.scene, self.rig
    local idle = math.max(0, f - SETTLE[sc.entry]) * FRAME_MS
    local p = { t = 1e9, idle = idle, dx = 0, dy = 0, sy = 1 }
    rig.dx, rig.dy, rig.fade = sc.rest[1], sc.rest[2], 1
    if sc.entry == "dragon" then
        if f < 139 then return end
        if f < 159 then
            self.story:put("boss_dragon_shadow", 854, 360, { at = true, fade = (f - 139) / 20 })
        elseif f < 184 then
            rig:spr("boss_dragon_king", 857, 359)
        else
            self.def.draw(rig, p)
        end
        return
    end
    local dx, dy, sy, fade = ENTRY[sc.entry](f)
    if not dx then return end
    rig.dx, rig.dy, rig.fade = rig.dx + dx, rig.dy + dy, fade
    p.sy = sy
    self.def.draw(rig, p)
end

-- purple flames rising in front of the Dragon King
function Boss:draw_flames(f)
    if f < 109 then return end
    for i, x in ipairs({ 330, 990 }) do
        for k = 0, 1 do
            local u = ((f - 109) / 120 + k / 2 + i / 4) % 1
            self.story:put("boss_dragon_flames", x, 760 - 480 * u,
                { at = true, add = true, fade = 1 - u, mirror = (i + k) % 2 == 0 })
        end
    end
end

function Boss:draw_lines(f)
    local st = self.story
    if f >= 31 and f <= 114 then
        local s, fade = 1, 0.7
        if f <= 38 then
            local u = (f - 31) / 7
            s, fade = lerp(1.328, 1, u), u
        elseif f <= 44 then
            fade = lerp(1, 0.8, (f - 39) / 5)
        elseif f >= 100 then
            local u = (f - 100) / 14
            s, fade = lerp(1.172, 1, u), lerp(1, 0, u)
        else
            for _, p in ipairs(PULSES) do
                if f >= p and f <= p + 4 then s, fade = 1.25, 1 end
            end
        end
        st:put("boss_lines", 0, 0, { s = s, fade = fade })
    end
end

function Boss:draw_headline(f)
    if f > 114 then return end
    local s, fade = 1, 1
    if f <= 19 then
        s, fade = lerp(2.308, 1, f / 19), f / 19
    elseif f <= 24 then
        s = lerp(1.046, 1.231, (f - 20) / 4)
    elseif f <= 37 then
        s = lerp(1.209, 1.011, (f - 25) / 12)
    elseif f >= 106 then
        local u = (f - 106) / 8
        s, fade = lerp(1.077, 1.364, u), 1 - u
    end
    draw_at(self.headline_glow, 640, 360, { s = s, fade = fade * 0.8 })
    draw_at(self.headline, 640, 360, { s = s, fade = fade })
    if f >= 19 and f <= 31 then
        local echo = f <= 24 and lerp(1, 1.231, (f - 19) / 5) or lerp(1.209, 1.077, (f - 25) / 6)
        draw_at(self.headline, 640, 360, { s = echo, fade = 0.5 })
    end
end

function Boss:draw_title_lines(t)
    local st, alpha = self.story, self.scene.line_alpha or 0.45
    for _, l in ipairs(LINES) do
        if t >= l[5] then
            local u = (t - l[5]) / l[6]
            local x, sx, sy = lerp(l[7], l[1], u), lerp(l[8], l[3], u), lerp(l[9], l[4], u)
            local fade = alpha * clamp01(u)
            st:put("boss_title_band", x, l[2], { at = true, sx = sx, sy = sy, fade = fade * tri(t - l[5], 102),
                add = true })
            st:put("boss_title_line", x, l[2], { at = true, sx = sx, sy = sy, fade = fade, add = true })
        end
    end
end

function Boss:draw_plate(f)
    local t = f - PLATE_AT
    if t < 0 then return end
    local fade = clamp01(t / 20)
    if t >= 20 then
        local g = (t - 20) % 160
        local glow = g < 80 and g / 80 or 1 - (g - 80) / 80
        self.story:put(self.scene.plate .. "_glow", 0, 0, { fade = glow })
    end
    self.story:put(self.scene.plate, 0, 0, { fade = fade })
    draw_at(self.name, PLATE_X, PLATE_NAME_Y, { fade = fade })
end

function Boss:draw_title(f)
    if self.scene.plate then return self:draw_plate(f) end
    local t = f - TITLE_AT
    if t < 0 then return end
    if self.scene.entry == "dragon" then return self:draw_final_title(t) end
    self:draw_title_lines(t)
    local sc = self.scene
    local streak = t <= 15 and 12 * (1 - math.abs(t - 6) / 9) or 0
    local glow = (t <= 10 and t / 10 or 1) * (0.8 + 0.15 * math.cos(2 * math.pi * t / 60))
    draw_at(self.glow, NAME_X + streak, NAME_Y, { fade = glow })
    draw_at(self.name, NAME_X, NAME_Y, { fade = clamp01((t - 13) / 10) })
    if t < 40 then return end
    local fade = clamp01((t - 40) / 13)
    local ex, ey = 1, 1
    if t >= 54 and t <= 58 then
        local u = (t - 54) / 4
        ex, ey = lerp(1, 1.167, u), lerp(1, 1.296, u)
    elseif t > 58 and t <= 69 then
        local u = (t - 59) / 10
        ex, ey = lerp(1.151, 1, u), lerp(1.269, 1, u)
    end
    self.story:put(sc.emblem, EMBLEM_X, EMBLEM_Y, { at = true, sx = ex, sy = ey, fade = fade * (t >= 70 and 0.9 or 1) })
    local x = SUB_X
    for _, p in ipairs(self.sub) do
        local w, cx = p.text.width / S, 0
        cx = x + w / 2
        if p.glow then
            local bump = t >= 53 and t <= 58 and lerp(1, 1.09, (t - 53) / 5)
                or t > 58 and t <= 69 and lerp(1.08, 1, (t - 59) / 10) or nil
            draw_at(p.glow, cx, SUB_Y, { fade = fade * (t <= 160 and 1 or lerp(1, 0.18, (t - 160) / 50)) * 0.8 })
            draw_at(p.text, cx, SUB_Y, { s = bump, fade = fade })
            if t >= 60 and t <= 366 then draw_at(p.shine, cx, SUB_Y, { fade = 0.6 * tri(t - 60, 102) }) end
        else
            draw_at(p.text, cx, SUB_Y, { fade = fade })
        end
        x = x + w + 10
    end
end

function Boss:draw_final_title(t)
    local fade = clamp01((t - 13) / 10)
    local cx, y = 265, 259
    local bw, bh = 140, 32
    local back = { 20, 20, 24, 255 * fade }
    local line = { 230, 230, 230, 255 * fade }
    tex.draw_rounded_rect((cx - bw / 2) * S, (y - bh / 2) * S, bw * S, bh * S, 1, back, 3 * S, line)
    draw_at(self.badge, cx, y, { fade = fade })
    local glow = fade * (0.35 + 0.15 * math.cos(2 * math.pi * t / 120))
    draw_at(self.final_glow, cx, 350, { fade = glow })
    draw_at(self.final, cx, 350, { fade = fade })
    draw_at(self.glow, cx, 466, { fade = glow })
    draw_at(self.name, cx, 466, { fade = fade })
end

function Boss:draw(f)
    self:draw_backdrops(f)
    self:draw_aura(f)
    self:draw_boss(f)
    if self.scene.entry == "dragon" then self:draw_flames(f) end
    self:draw_lines(f)
    self:draw_title(f)
    self:draw_headline(f)
    if f >= self.hold then self.story:draw_hint(self.hint) end
end

return Boss
