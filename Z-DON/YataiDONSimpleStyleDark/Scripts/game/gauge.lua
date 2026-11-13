-- YataiDONSimpleStyle v2 gauge: Nijiiro's render() (50 cells of 21 px, fade-in cells) with
--  * the cell dividers (overlay) drawn at full opacity on the game screen (they are the 8-bit cell
--    grid, not a sheen; other screens keep the parent's 0.15 cap)
--  * the soul fire drawn at scale 1 (pixel art never scales): pops in over 3 frames (1U steps)
--  * the rainbow drawn from one frame (6 flat blocks; no cross-fade between frames)
-- This skin's gauge: the parent's script with render() replaced. The parent's render() is laid
-- out for its 87-cell flash gauge; this skin's 50 x 21 px grid fades each new cell in:
--  * fade_in: the fading sprite is the new cell itself, so it sits on cell
--    length-1 (at length it left a dark gap cell before it)
--  * the clear mark sits gauge_clear_mark_offset cells (skin_config: 1, the cell edge) before
--    the exact clear fraction, not the parent's 87/60
-- The dan gauge is drawn as the cabinet's tamashii_gauge (see draw_dan below).
-- Everything else is the parent's file, loaded from its own copy.

-- SimpleStyle: this file replaces Nijiiro's gauge.lua (which itself extends PyTaikoGreen's). The
-- base Gauge class is PyTaikoGreen's script: load it by path (the second match on package.path would
-- be Nijiiro's copy, which would load itself again).
local function load_parent(name)
    for tmpl in package.path:gmatch("[^;]+") do
        if tmpl:find("PyTaikoGreen", 1, true) then
            local chunk = loadfile((tmpl:gsub("%?", name)))
            if chunk then return chunk end
        end
    end
end

local function load_own_base(name)   -- SimpleStyle standalone: this skin's copy of the base
    for tmpl in package.path:gmatch("[^;]+") do
        local chunk = loadfile((tmpl:gsub("%?", name)))
        if chunk then return chunk end
    end
end
assert(load_own_base("game/gauge_base"), "game/gauge: no gauge_base script")()

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- SimpleStyle dynamic text: the soul ring's word (魂 / Soul / 魂 / 혼) and the clear-zone label
-- (クリア / Clear / 通关 / 클리어) are engine text in the player's language (ss/strings.py soul / clear),
-- drawn over the wordless gauge/tamashii* and the empty gauge/clear_* rects (game screen only; the
-- result screen's scaled gauge draws its own art).
local UI = require("global.ss_ui")
local P, U = UI.P, UI.U
local SOUL_IN = 54           -- inside the soul ring's 2U inner ring (ring r 12 cells)

local function soul_text(lit)
    for _, size in ipairs({ 36, 24, 18 }) do
        local t = UI.text_key("soul", size, lit and "ink" or { color = P.text2 })
        if t and (t.width - 2 * UI.text_pad(t)) <= SOUL_IN or size == 18 then return t end
    end
end

-- the soul ring's centre: the frame centre on the U grid (ss/v2_game.py soul: gfit(w / 2))
local function soul_at(info, k, y, lit)
    if not info or not info.x or not info.x[k] then return end
    UI.draw_text(soul_text(lit), info.x[k] + UI.grid(info.width / 2), (y or 0) + info.y[k] + UI.grid(info.height / 2), "c")
end

-- the clear label at the zone start (clear_ja rect k = zone line + 3, gauge top - 2): owner 10-29 "no
-- grid cells", so no chip / box any more: the word alone in the zone's upper strip (gauge-local rows
-- 12..45), 2U right of the threshold line. Lit (cleared) = ink, on the gold zone fill; dark = text2 on
-- the empty zone.
local function clear_at(info, k, y, lit)
    if not info or not info.x or not info.x[k] then return end
    local x0, y0 = info.x[k], (y or 0) + info.y[k]
    local t = UI.text_key("clear", 18, lit and "ink" or { color = P.text2 })
    UI.draw_text(t, x0 - 3 + 3 * U, y0 + 2 + 28, "l")
end

-- The full (rainbow) gauge's shine: a paper staircase streak (2U + 1U columns, slanted 1U per 2 rows)
-- that sweeps the 50 cells left to right at a constant 6U (18 px) per 16.7 ms frame (59 frames, ~1 s),
-- then rests ~1 s. Rainbow frame-local geometry (ss/v2_game.py f_g_rainbow: gauge-local - (11, 5)):
-- cells x 7..1057, track rows 40..73, the clear zone rows 7..73 from x 7 + 21 * zone cell.
-- 2P draws the gauge mirrored vertically (rows flip in the 78-px frame).
local GL_X0, GL_X1, GL_H = 7, 1057, 78
local GL_TRACK, GL_ZONE = { 40, 73 }, { 7, 73 }
local GL_ZONE_CELL = { [0] = 29, 34, 39 }
local GL_STEP, GL_FRAME, GL_CYCLE = 6 * U, 16.67, 120
local GL_TIERS = { [0] = "easy", "normal", "hard" }

function Gauge:glint(y, mirror, idx)
    local f = math.floor(tex.get_current_ms() / GL_FRAME) % GL_CYCLE
    local hx = GL_X0 + f * GL_STEP              -- the streak's head (frame-local x)
    if hx - 12 * U > GL_X1 then return end
    local info = self.ss_rb_info
    if info == nil then
        info = tex.get_texture_info("gauge", "rainbow_" .. GL_TIERS[self.art_tier or 2]) or false
        self.ss_rb_info = info
    end
    if not info or not info.x or not info.x[idx + 1] then return end
    local ox, oy = info.x[idx + 1], (y or 0) + info.y[idx + 1]
    local zx = GL_X0 + 21 * GL_ZONE_CELL[self.art_tier or 2]
    for _, col in ipairs({ { 0, 2 * U }, { -4 * U, U } }) do
        local x0 = hx + col[1]
        for x = x0, x0 + col[2] - U, U do
            -- staircase: the column leans right as it rises (1U per 2 rows of 1U)
            local rows = (x >= zx) and GL_ZONE or GL_TRACK
            for ry = rows[1], rows[2] - U, U do
                local lean = math.floor((rows[2] - ry) / (2 * U)) * U
                local xx = x + lean
                if xx >= GL_X0 and xx + U <= GL_X1 and (xx >= zx or rows == GL_TRACK) then
                    local yy = mirror and (GL_H - ry - U) or ry
                    UI.rect(ox + xx, oy + yy, U, U, P.paper)
                end
            end
        end
    end
end

local parent_new = Gauge.new
function Gauge.new(is_2p, dan, string_diff, opts)
    local self = parent_new(is_2p, dan, string_diff, opts)
    self.clear_mark_offset = 1
    self.fade_in = true
    self.ss_screen = (opts and opts.screen) or "game"
    if self.ss_screen == "game" and not self.scale then
        self.ss_soul = tex.get_texture_info(dan and "gauge_dan" or "gauge", "tamashii")
        self.ss_clear = (not dan) and tex.get_texture_info("gauge", "clear_ja") or nil
    end
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
        self:blit(self.rainbow, mirror, nil, y, nil, rainbow_fade >= 0.5 and 1 or 0, 0, idx)
        if rainbow_fade >= 0.5 and self.ss_screen == "game" and not self.scale then
            self:glint(y, mirror, idx)
        end
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

    self:blit(self.overlay, mirror, nil, y, nil, self.ss_screen == "game" and 1.0 or 0.15, nil, idx, nil, nil, true)
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
    clear_at(self.ss_clear, label + 1, y, is_clear)
    soul_at(self.ss_soul, idx + 1, y, is_clear)
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
        layer(self.fire, nil, nil, nil, fire_frame)   -- SimpleStyle: pixel fire at scale 1
        layer(self.tamashii)
        if fire_frame == 0 or fire_frame == 1 or fire_frame == 4 or fire_frame == 5 then
            layer(self.tamashii_overlay, nil, nil, 0.5)
        end
    elseif clear then
        layer(self.tamashii)
    else
        layer(self.tamashii_dark)
    end
    soul_at(self.ss_soul, 1, 0, is_rainbow or clear)
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

-- the soul fire at scale 1: rises in over 3 frames (1U per frame) and drops out the same way
local FIRE_STEP = 16.67
function Gauge:draw_fire(y, idx, is_rainbow, fire_frame)
    local now = tex.get_current_ms()
    if is_rainbow and not self.fire_on then self.fire_on, self.fire_t0 = true, now
    elseif not is_rainbow and self.fire_on then self.fire_on, self.fire_t1 = false, now end
    local drop
    if is_rainbow then
        drop = math.max(0, 3 - math.floor((now - self.fire_t0) / FIRE_STEP))
    elseif self.fire_t1 and now - self.fire_t1 < 3 * FIRE_STEP then
        drop = 1 + math.floor((now - self.fire_t1) / FIRE_STEP)
    else
        return
    end
    self:blit(self.fire, nil, nil, y + drop * 3, nil, 1.0, fire_frame, idx)
end
