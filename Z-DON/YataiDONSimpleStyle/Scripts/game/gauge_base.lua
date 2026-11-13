-- YataiDONSimpleStyle v2 standalone: base of Scripts/game/gauge.lua, copied at build time (ss/v2_standalone.py)
Gauge = {}
Gauge.__index = Gauge

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- Port of Gauge::draw / Gauge::draw_dan. C++ keeps the points logic and hands the
-- numbers over every frame; this only decides what gets drawn where.
-- opts (all optional): screen ("game" default / "result"), player_str ("1p"/"2p"), scale,
-- footer (draw gauge/footer), no_border. The result screen reuses the HUD draw through these.
function Gauge.new(is_2p, dan, string_diff, opts)
    local self = setmetatable({}, Gauge)
    opts = opts or {}
    self.dan = dan
    self.scale = opts.scale
    self.no_border = opts.no_border
    self.base_fade = 1.0
    self.pool = {}
    self.fade_in = false   -- a skin whose cells fade in sets this after Gauge.new
    local screen = opts.screen or "game"

    local cells = tex.get_skin_config("game_gauge_cells")
    self.bar_units = (cells and cells.x and cells.x > 0) and math.floor(cells.x + 0.5) or 87

    local p = opts.player_str and (opts.player_str .. "_") or (is_2p and "2p_" or "1p_")
    local function t(name) return tex.get_texture(screen .. "/" .. name) end

    if dan then
        self.bar         = t("gauge_dan/" .. p .. "bar")
        self.bar_fade    = t("gauge_dan/" .. p .. "bar_fade")
        self.border      = t("gauge_dan/border")
        self.unfilled    = t("gauge_dan/" .. p .. "unfilled")
        self.rainbow     = t("gauge_dan/rainbow")
        self.overlay     = t("gauge_dan/overlay")
        self.fire        = t("gauge_dan/tamashii_fire")
        self.tamashii    = t("gauge_dan/tamashii")
        self.tamashii_overlay = t("gauge_dan/tamashii_overlay")
        self.tamashii_dark    = t("gauge_dan/tamashii_dark")
        self.bar_width = tex.get_texture_info("gauge_dan", p .. "bar").width
    else
        self.border      = t("gauge/border" .. string_diff)
        self.unfilled    = t("gauge/" .. p .. "unfilled" .. string_diff)
        self.bar         = t("gauge/" .. p .. "bar")
        self.clear_transition      = t("gauge/bar_clear_transition")
        self.clear_top             = t("gauge/bar_clear_top")
        self.clear_bottom          = t("gauge/bar_clear_bottom")
        self.rainbow     = t("gauge/rainbow" .. string_diff)
        self.clear_transition_fade = t("gauge/bar_clear_transition_fade")
        self.clear_fade  = t("gauge/bar_clear_fade")
        self.bar_fade    = t("gauge/" .. p .. "bar_fade")
        self.overlay     = t("gauge/overlay" .. string_diff)
        self.fire        = t("gauge/tamashii_fire")
        self.tamashii    = t("gauge/tamashii")
        self.tamashii_overlay = t("gauge/tamashii_overlay")
        self.tamashii_dark    = t("gauge/tamashii_dark")
        -- language variants (clear_ja ...) are resolved by tex.get_texture
        self.clear      = t("gauge/clear")
        self.clear_dark = t("gauge/clear_dark")
        self.bar_width = (tex.get_texture_info("gauge", p .. "bar") or {}).width or 0
        if opts.footer then self.footer = t("gauge/footer") end
        self.art_tier = (string_diff == "_easy") and 0 or (string_diff == "_normal") and 1 or 2
    end
    return self
end

-- cell bookkeeping shared by both gauges: how many cells are solid, and the alpha of the
-- sprite on the cell that was just filled (nil when there is none to show).
function Gauge:cells(points, previous_points, max_points, anim_active, anim_alpha)
    local units = self.bar_units
    local length = math.floor(points * units / max_points)
    local previous = math.floor(previous_points * units / max_points)
    local fade_in = self.fade_in
    local pending = length <= units and length > previous and anim_active
    local solid = (fade_in and pending) and length - 1 or length
    local alpha = fade_in and 1.0 - anim_alpha or anim_alpha
    local show_up
    if fade_in then show_up = pending else show_up = length <= units and length > previous end
    return length, solid, alpha, show_up, pending, fade_in
end

-- one param table per texture, refilled every draw: a fresh table per layer per frame was the
-- gauge's GC pressure. Every field is rewritten each time, so nothing carries over.
local function fill(pool, t, mirror, x, y, x2, fade, frame, index, scale, center)
    local p = pool[t]
    if not p then p = {}; pool[t] = p end
    p.mirror, p.x, p.y, p.x2, p.fade, p.frame, p.index, p.scale, p.center =
        mirror, x, y, x2, fade, frame, index, scale, center
    return p
end

-- every draw goes through here so the result screen's scale / fade-in apply uniformly
function Gauge:blit(t, mirror, x, y, x2, fade, frame, index, scale, center, cap)
    local p = fill(self.pool, t, mirror, x, y, x2, fade, frame, index, scale, center)
    if self.scale then
        -- draw_texture scales the texture but not x / x2, and cell offsets are in bar-texture
        -- pixels, so they have to follow the scale or the fill outgrows the scaled groove
        p.scale = (p.scale or 1.0) * self.scale
        if p.x then p.x = p.x * self.scale end
        if p.x2 then p.x2 = p.x2 * self.scale end
    end
    if cap then p.fade = math.min(p.fade, self.base_fade)   -- overlays: cap, not multiply
    elseif self.base_fade ~= 1.0 then p.fade = (p.fade or 1.0) * self.base_fade end
    tex.draw_texture(t, p)
end

function Gauge:draw(y, points, previous_points, max_points, clear_points,
                    is_clear, is_rainbow, anim_active, anim_alpha, rainbow_fade, rainbow_frac, fire_frame)
    if self.dan then
        return self:draw_dan(points, previous_points, max_points, is_rainbow,
                             anim_active, anim_alpha, rainbow_fade, rainbow_frac, fire_frame)
    end
    local mirrored = y > tex.get_screen_height() / 2
    self:render(y, mirrored and "vertical" or nil, mirrored and 1 or 0, points, previous_points, max_points,
                clear_points, is_clear, is_rainbow, anim_active, anim_alpha, rainbow_fade, rainbow_frac, fire_frame)
end

-- result screen: no lane offset, no mirroring, no gauge-up cell animation. base_fade is the
-- screen's gauge fade-in; idx picks the 1p/2p layout.
function Gauge:draw_result(idx, base_fade, points, max_points, clear_points,
                           is_clear, is_rainbow, rainbow_frac, fire_frame)
    self.base_fade = base_fade
    self:render(0, nil, idx, points, points, max_points, clear_points,
                is_clear, is_rainbow, false, 0.0, 1.0, rainbow_frac, fire_frame)
end

-- tamashii fire pops in when the gauge goes rainbow and shrinks away when it ends (Lumen
-- gage_fire: 167 ms each, two 83 ms legs; poses are {centre x, centre y, scale, alpha} and
-- the rest pose is the one texture.json describes)
local FIRE_REST = { 1257.3, -55.8, 0.7, 1 }
local FIRE_IN   = { { 1229.85, -25.55, 0.14, 0 }, { 1260.75, -59.6, 0.767, 1 }, FIRE_REST }
local FIRE_OUT  = { { 1259.75, -58.5, 0.75, 1 }, { 1264.15, -63.35, 0.84, 1 }, { 1226.45, -21.8, 0.07, 1 } }
local FIRE_LEG  = 83

local function fire_pose(keys, t)
    local leg = math.min(math.floor(t / FIRE_LEG), 1)
    local u = clamp(t / FIRE_LEG - leg, 0, 1)
    u = leg == 0 and 1 - (1 - u) * (1 - u) or u * u   -- decelerate in, accelerate out
    local a, b = keys[leg + 1], keys[leg + 2]
    return a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u,
           a[3] + (b[3] - a[3]) * u, a[4] + (b[4] - a[4]) * u
end

function Gauge:draw_fire(y, idx, is_rainbow, fire_frame)
    local now = tex.get_current_ms()
    if is_rainbow and not self.fire_on then self.fire_on, self.fire_t0 = true, now
    elseif not is_rainbow and self.fire_on then self.fire_on, self.fire_t1 = false, now end
    local cx, cy, s, a
    if is_rainbow then
        local t = now - self.fire_t0
        cx, cy, s, a = table.unpack(t < FIRE_LEG * 2 and { fire_pose(FIRE_IN, t) } or FIRE_REST)
    elseif self.fire_t1 and now - self.fire_t1 < FIRE_LEG * 2 then
        cx, cy, s, a = fire_pose(FIRE_OUT, now - self.fire_t1)
    else
        return
    end
    self:blit(self.fire, nil, cx - FIRE_REST[1], y + cy - FIRE_REST[2], nil, a, fire_frame, idx, s, true)
end

function Gauge:render(y, mirror, idx, points, previous_points, max_points, clear_points,
                      is_clear, is_rainbow, anim_active, anim_alpha, rainbow_fade, rainbow_frac, fire_frame)
    -- blit(t, mirror, x, y, x2, fade, frame, index, scale, center, cap)
    if not self.no_border then self:blit(self.border, mirror, nil, y, nil, nil, nil, idx) end
    self:blit(self.unfilled, mirror, nil, y, nil, nil, nil, idx)

    local units, bw = self.bar_units, self.bar_width
    local length, solid, alpha, show_up, pending, fade_in =
        self:cells(points, previous_points, max_points, anim_active, anim_alpha)
    local clear_point = clamp(clear_points * units // max_points, 1, units)
    -- Lumen puts the clear mark at the exact fraction minus 87/60 cells (x 897/967/1037 on
    -- easy/normal/hard), not on a cell edge
    local cpx = clear_points * units / max_points - units / 60

    if solid > 0 then
        self:blit(self.bar, nil, nil, y,
            math.min(solid, cpx) * bw - bw, nil, nil, idx)
    end

    -- first gold cell lights exactly when the gauge is cleared (not by a cell-count test:
    -- on 87 cells 8000 -> 69.6 would light it a cell early/late vs. the clear state)
    if is_clear and not (fade_in and pending and length == clear_point) then
        self:blit(self.clear_transition, mirror, cpx * bw, y, nil, nil, nil, idx)
    end

    -- gold zone: cells clear_point .. solid-1, one cell wide piece so stretch is (n-1)*bw
    local gold_x = (cpx + 1) * bw
    if solid * bw >= gold_x + bw then
        local gold_x2 = solid * bw - gold_x - bw
        self:blit(self.clear_top, mirror, gold_x, y, gold_x2, nil, nil, idx)
        self:blit(self.clear_bottom, nil, gold_x, y, gold_x2, nil, nil, idx)
    end

    if is_rainbow and rainbow_fade >= 0 then
        local frame_a = math.floor(rainbow_frac) % 8
        local frame_b = (frame_a + 1) % 8
        local f = rainbow_frac - math.floor(rainbow_frac)
        self:blit(self.rainbow, mirror, nil, y, nil, rainbow_fade, frame_a, idx)
        self:blit(self.rainbow, mirror, nil, y, nil, rainbow_fade * f, frame_b, idx)
    end

    if show_up then
        -- sprite sits on the cell that was just filled (length-1)
        local fx = length * bw   -- glow rides the leading edge of the fill
        if length == clear_point then
            self:blit(self.clear_transition_fade, mirror, cpx * bw, y, nil, alpha, nil, idx)
        elseif length > clear_point then
            self:blit(self.clear_fade, nil, fx, y, nil, alpha, nil, idx)
        else
            self:blit(self.bar_fade, nil, fx, y, nil, alpha, nil, idx)
        end
    end

    self:blit(self.overlay, mirror, nil, y, nil, 0.15, nil, idx, nil, nil, true)
    if self.footer then self:blit(self.footer, nil, nil, y, nil, nil, nil, idx) end

    self:draw_fire(y, idx, is_rainbow, fire_frame)

    local label = self.art_tier + idx * 3
    if is_clear then
        self:blit(self.clear, nil, nil, y, nil, nil, nil, label)
        self:blit(self.tamashii, nil, nil, y, nil, nil, nil, idx)
        if is_rainbow and (fire_frame == 0 or fire_frame == 1 or fire_frame == 4 or fire_frame == 5) then
            self:blit(self.tamashii_overlay, nil, nil, y, nil, 0.5, nil, idx, nil, nil, true)
        end
    else
        self:blit(self.clear_dark, nil, nil, y, nil, nil, nil, label)
        self:blit(self.tamashii_dark, nil, nil, y, nil, nil, nil, idx)
    end
end

-- dan gauge sits at absolute positions from its texture.json: no lane offset, no mirroring
-- dan layers: no lane offset / mirroring / base fade, so straight to draw_texture
local function dan_layer(self, t, x, x2, fade, frame, scale, center)
    tex.draw_texture(t, fill(self.pool, t, nil, x, nil, x2, fade, frame, nil, scale, center))
end

function Gauge:draw_dan(points, previous_points, max_points, is_rainbow,
                        anim_active, anim_alpha, rainbow_fade, rainbow_frac, fire_frame)
    dan_layer(self, self.border)
    dan_layer(self, self.unfilled)

    local bw = self.bar_width
    local length, solid, alpha, show_up = self:cells(points, previous_points, max_points, anim_active, anim_alpha)

    if solid > 0 then dan_layer(self, self.bar, nil, solid * bw - bw) end

    if is_rainbow and rainbow_fade >= 0 then
        local frame_a = math.floor(rainbow_frac) % 8
        local frame_b = (frame_a + 1) % 8
        local f = rainbow_frac - math.floor(rainbow_frac)
        dan_layer(self, self.rainbow, nil, nil, rainbow_fade, frame_a)
        dan_layer(self, self.rainbow, nil, nil, rainbow_fade * f, frame_b)
    end

    if show_up and length > 0 then
        dan_layer(self, self.bar_fade, (length - 1) * bw, nil, alpha)
    end

    dan_layer(self, self.overlay, nil, nil, 0.15)

    if is_rainbow then
        dan_layer(self, self.fire, nil, nil, nil, fire_frame, 0.75, true)
        dan_layer(self, self.tamashii)
        if fire_frame == 0 or fire_frame == 1 or fire_frame == 4 or fire_frame == 5 then
            dan_layer(self, self.tamashii_overlay, nil, nil, 0.5)
        end
    else
        dan_layer(self, self.tamashii_dark)
    end
end
