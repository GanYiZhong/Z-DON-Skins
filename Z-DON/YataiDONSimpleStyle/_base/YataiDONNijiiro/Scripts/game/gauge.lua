-- This skin's gauge: the parent's script with render() replaced. The parent's render() is laid
-- out for its 87-cell flash gauge; this skin's 50 x 21 px grid fades each new cell in:
--  * fade_in: the fading sprite is the new cell itself, so it sits on cell
--    length-1 (at length it left a dark gap cell before it)
--  * the clear mark sits gauge_clear_mark_offset cells (skin_config: 1, the cell edge) before
--    the exact clear fraction, not the parent's 87/60
-- The dan gauge is drawn as the cabinet's tamashii_gauge (see draw_dan below).
-- Everything else is the parent's file, loaded from its own copy.

-- the parent skin's copy of a script: the second match on package.path (the first is this file)
local function load_parent(name)
    local seen = false
    for tmpl in package.path:gmatch("[^;]+") do
        local chunk = loadfile((tmpl:gsub("%?", name)))
        if chunk then
            if seen then return chunk end
            seen = true
        end
    end
end

assert(load_parent("game/gauge"), "game/gauge: the parent skin has no gauge script")()

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local parent_new = Gauge.new
function Gauge.new(is_2p, dan, string_diff, opts)
    local self = parent_new(is_2p, dan, string_diff, opts)
    self.clear_mark_offset = 1
    self.fade_in = true
    if dan then
        local screen = (opts and opts.screen) or "game"
        local p = (opts and opts.player_str and (opts.player_str .. "_")) or (is_2p and "2p_" or "1p_")
        local function t(name) return tex.get_texture(screen .. "/gauge_dan/" .. name) end
        self.cab = {
            track_red  = t("track_red"),
            lamp       = t(p .. "lamp"),
            lamp_clear = t("lamp_clear"),
            fade_clear = t("bar_fade_clear"),
        }
    end
    return self
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
    -- the parent's art: the clear mark at the exact fraction minus 87/60 cells (x 897/967/1037 on
    -- easy/normal/hard), not on a cell edge
    local cpx = clear_points * units / max_points - (self.clear_mark_offset or units / 60)

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
        -- flash: the glow rides the leading edge of the fill; fade-in: the sprite is the new
        -- cell itself (the fill stops one cell short until it lands)
        local fx = (fade_in and length - 1 or length) * bw
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

-- The dan gauge as the cabinet's tamashii_gauge draws it: the gold track (border), the red
-- track (track_red, gauge_bg) up to the threshold, the lit cells as one lamp stretched 21 px
-- per cell (lamp_clear, yellow, once the gauge reaches the threshold), the glow on a newly lit
-- cell, the cell separators at the cabinet's 103/255, then 魂: grey, white once cleared, and
-- in flames at full. The threshold comes from the dan exam (background dan_info sets
-- g_dan_gauge_border, in cells); without it, or without the cabinet pieces, the parent draws.
local CAB_CELL      = 21
local CAB_TRACK     = 20.88      -- gauge_bg: 160 px x 0.1305 per cell
local CAB_SEPARATOR = 103 / 255
local parent_draw_dan = Gauge.draw_dan

-- The cabinet draws the gauge over the lane; the engine draws the lane after it, so its top
-- edge (y 276, 184 px x 1.5) hides the cells' last rows. The gauge leaves a redraw for the
-- dan background's draw_fore (g_dan_gauge_redraw), which repeats it clipped to that strip.
local function draw_cab(self, border, points, previous_points, max_points, is_rainbow,
                        anim_active, anim_alpha, rainbow_fade, rainbow_frac, fire_frame)
    local cab = self.cab
    local function layer(t, x, x2, fade, frame, scale, center)
        if t then
            tex.draw_texture(t, { x = x, x2 = x2, fade = fade, frame = frame, scale = scale, center = center })
        end
    end

    local length, solid, alpha, show_up = self:cells(points, previous_points, max_points, anim_active, anim_alpha)
    local clear = length >= border

    layer(self.border)
    if border > 0 then layer(cab.track_red, nil, CAB_TRACK * border - 160) end
    if solid > 0 then layer(clear and cab.lamp_clear or cab.lamp, nil, CAB_CELL * solid - 8) end

    if is_rainbow and rainbow_fade >= 0 then
        local frame_a = math.floor(rainbow_frac) % 8
        local frame_b = (frame_a + 1) % 8
        local f = rainbow_frac - math.floor(rainbow_frac)
        layer(self.rainbow, nil, nil, rainbow_fade, frame_a)
        layer(self.rainbow, nil, nil, rainbow_fade * f, frame_b)
    end

    if show_up and length > 0 then
        layer(clear and cab.fade_clear or self.bar_fade, (length - 1) * CAB_CELL, nil, alpha)
    end

    layer(self.overlay, nil, nil, CAB_SEPARATOR)

    if is_rainbow then
        layer(self.fire, nil, nil, nil, fire_frame, 0.75, true)
        layer(self.tamashii)
        if fire_frame == 0 or fire_frame == 1 or fire_frame == 4 or fire_frame == 5 then
            layer(self.tamashii_overlay, nil, nil, 0.5)
        end
    elseif clear then
        layer(self.tamashii)
    else
        layer(self.tamashii_dark)
    end
end

function Gauge:draw_dan(points, previous_points, max_points, is_rainbow,
                        anim_active, anim_alpha, rainbow_fade, rainbow_frac, fire_frame)
    local cab = self.cab
    local border = _G.g_dan_gauge_border
    if not (cab and cab.track_red and cab.lamp and cab.lamp_clear and border) then
        _G.g_dan_gauge_redraw = nil
        return parent_draw_dan(self, points, previous_points, max_points, is_rainbow,
                               anim_active, anim_alpha, rainbow_fade, rainbow_frac, fire_frame)
    end
    draw_cab(self, border, points, previous_points, max_points, is_rainbow,
             anim_active, anim_alpha, rainbow_fade, rainbow_frac, fire_frame)
    _G.g_dan_gauge_redraw = function()
        draw_cab(self, border, points, previous_points, max_points, is_rainbow,
                 anim_active, anim_alpha, rainbow_fade, rainbow_frac, fire_frame)
    end
end

-- AI battle layout (skin_config zdon_ai_nj_gauge x = 1): the cabinet's enso_ai ai_tamashii_gauge, a short 50-cell
-- gauge in the top right (housing from x 965, gold clear box at 1630-1810, 魂 at 1851), 1P only. Art: game/gauge_ai
-- (cut 1:1 from the movie's atlas by its quad records), geometry from the movie's placements (sprite origin 1440,254):
-- red fill 16 px base stretched from x 974 (656 / 572 / 488 px at the clear cell 40 / 35 / 30 on hard / normal / easy),
-- gold cap + body after it up to x 1810, cell separators (ticks) at alpha 77/256, white 魂, rainbow when full.
local AI_ORG_X = 1440
local AI_TIERS = {
    [0] = { name = "easy",   cp = 30, red = 488, gold = 332 },
    [1] = { name = "normal", cp = 35, red = 572, gold = 248 },
    [2] = { name = "hard",   cp = 40, red = 656, gold = 164 },
}
local AI_CELLS = 50
local AI_CLEAR_DX, AI_CLEAR_DY, AI_CLEAR_S = 3, 14, 0.75

local ai_mod
local function ai_gauge_on(self)
    if self.dan then return false end
    local g = tex.get_skin_config("zdon_ai_nj_gauge")
    if not g or (g.x or 0) == 0 then return false end
    if not (tex.current_screen() or ""):find("GAME") then return false end
    if ai_mod == nil then
        local ok, m = pcall(require, "global.ai_battle")
        ai_mod = ok and m or false
    end
    return ai_mod and ai_mod.active() or false
end

local parent_draw = Gauge.draw
function Gauge:draw(y, points, previous_points, max_points, clear_points, is_clear, is_rainbow,
                    anim_active, anim_alpha, rainbow_fade, rainbow_frac, fire_frame)
    if ai_gauge_on(self) then
        if self.is_2p then return end      -- the AI's own gauge is not shown
        local a = self.ai_art
        if not a then
            local function t(n) return tex.get_texture("game/gauge_ai/" .. n) end
            a = { fill = t("fill"), cap = t("cap"), body = t("body"), soul = t("soul") }
            for _, tier in pairs(AI_TIERS) do
                a["housing_" .. tier.name] = t("housing_" .. tier.name)
                a["ticks_" .. tier.name] = t("ticks_" .. tier.name)
                a["rainbow_" .. tier.name] = t("rainbow_" .. tier.name)
            end
            a.ok = a.fill and a.cap and a.body and a.soul and a.housing_hard
            self.ai_art = a
        end
        if a.ok then
            local at = self.art_tier or 2
            local tier = AI_TIERS[at] or AI_TIERS[2]
            local function layer(t, x, x2, fade, frame)
                if t then tex.draw_texture(t, { x = x, y = y, x2 = x2, fade = fade, frame = frame }) end
            end
            local n = clamp(math.floor((points or 0) * AI_CELLS / math.max(1, max_points or 1)), 0, AI_CELLS)
            layer(a["housing_" .. tier.name])
            if is_rainbow and rainbow_fade >= 0 then
                local fa = math.floor(rainbow_frac) % 8
                local f = rainbow_frac - math.floor(rainbow_frac)
                layer(a["rainbow_" .. tier.name], nil, nil, rainbow_fade, fa)
                layer(a["rainbow_" .. tier.name], nil, nil, rainbow_fade * f, (fa + 1) % 8)
            else
                local red = tier.red * math.min(n, tier.cp) / tier.cp
                if red >= 1 then layer(a.fill, nil, red - 16) end
                if is_clear or n >= tier.cp then
                    local gx = AI_ORG_X + tier.red - 466
                    layer(a.cap, gx)
                    local body = tier.gold * math.max(0, n - tier.cp) / (AI_CELLS - tier.cp)
                    if body >= 1 then layer(a.body, gx + 16, body - 16) end
                end
            end
            layer(a["ticks_" .. tier.name], nil, nil, 77 / 256)
            -- the flame on 魂 (the normal gauge's, shifted to the AI gauge's 魂 centre)
            local ob = self.blit
            self.blit = function(s, t, m, x, yy, ...) return ob(s, t, m, (x or 0) + 17, yy, ...) end
            self:draw_fire(y + 8, 0, is_rainbow, fire_frame)
            self.blit = ob
            layer(a.soul)
            -- the "クリア" label (the normal gauge's official art, scaled to the cabinet's 18 px text field) over the first gold cell
            local lx = AI_CLEAR_DX + (AI_ORG_X + tier.red - 466) + 2 - (1350 + 105 * at)
            self:blit(is_clear and self.clear or self.clear_dark, nil, lx, y + AI_CLEAR_DY, nil, nil, nil, at, AI_CLEAR_S)
            return
        end
    end
    return parent_draw(self, y, points, previous_points, max_points, clear_points, is_clear, is_rainbow,
                       anim_active, anim_alpha, rainbow_fade, rainbow_frac, fire_frame)
end
