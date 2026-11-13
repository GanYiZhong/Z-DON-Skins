-- YataiDONSimpleStyle v2 standalone: base of Scripts/game/note_arc.lua, copied at build time (ss/v2_standalone.py)
local SKIN_S = tex.get_screen_scale()
local SKIN = {
    note_arc_start_x_offset = { x = 350 * SKIN_S },
    note_arc_curve_height = { height = 425 * SKIN_S },
    note_arc_balloon_p2_y = { y = 435 * SKIN_S },
}
NoteArc = {}
NoteArc.__index = NoteArc

local ARC_POINTS = 100
local FRAME_MS = 16.67

local function trunc(v) return v < 0 and math.ceil(v) or math.floor(v) end

function NoteArc.new(note_tex_type, big, is_balloon, player_num, start_x, start_y)
    local self = setmetatable({}, NoteArc)
    self.big = big
    self.is_balloon = is_balloon
    self.p2 = player_num == 2

    local curve_height = SKIN.note_arc_curve_height.height
    local sx = start_x + SKIN.note_arc_start_x_offset.x
    local sy = start_y + tex.get_skin_config("game_notes").y
    local hit = tex.get_skin_config("game_gauge_hit_effect_note")
    local ex, ey = hit.x, hit.y
    if self.p2 then ey = ey + hit.height end

    self.sx, self.sy, self.ex, self.ey = sx, sy, ex, ey
    self.cx = (sx + ex) / 2
    if self.p2 then
        self.cy = math.max(sy, ey) + curve_height   -- arc downward
    else
        self.cy = math.min(sy, ey) - curve_height   -- arc upward
    end

    self.t_note = tex.get_texture("game/notes/" .. note_tex_type)
    self.note_width = tex.get_texture_info("notes", tostring(note_tex_type)).width
    self.t_firework = big and tex.get_texture("game/hit_effect/firework") or nil
    self.firework_frames = self.t_firework and tex.get_texture_info("hit_effect", "firework").frame_count or 0
    self.t_rainbow = tex.get_texture("game/balloon/rainbow")
    if self.t_rainbow then
        self.rainbow_info = tex.get_texture_info("balloon", "rainbow")
    end
    return self
end

-- bezier sampled at the same 100 steps the C++ cache used, truncated to whole pixels
function NoteArc:point(progress)
    local t = math.min(math.floor(progress * ARC_POINTS), ARC_POINTS) / ARC_POINTS
    local ti = 1 - t
    return trunc(ti * ti * self.sx + 2 * ti * t * self.cx + t * t * self.ex),
           trunc(ti * ti * self.sy + 2 * ti * t * self.cy + t * t * self.ey)
end

function NoteArc:draw_rainbow(y, raw_progress)
    local w, h = self.rainbow_info.width, self.rainbow_info.height
    local trail_start = math.max(0, raw_progress - 0.5)
    local trail_end = math.min(raw_progress, 1)
    if trail_end <= trail_start then return end

    local crop_start = math.floor(trail_start * w + 0.5)
    local crop_w = math.floor(trail_end * w + 0.5) - crop_start
    if crop_w <= 0 then return end

    local y_pos = self.p2 and SKIN.note_arc_balloon_p2_y.y or 0
    tex.draw_texture(self.t_rainbow, {
        x = crop_start, y = y + y_pos, x2 = -w + crop_w,
        src = { x = crop_start, y = 0, width = crop_w, height = self.p2 and -h or h },
    })
end

function NoteArc:draw_fireworks(y, elapsed_ms, duration_ms)
    local half = self.note_width * 0.6 / 2
    for i = 0, 8 do
        local spawn_ms = (3 + 3 * i) * FRAME_MS
        local age_ms = elapsed_ms - spawn_ms
        local frame = math.floor(age_ms / FRAME_MS)
        if age_ms >= 0 and frame < self.firework_frames then
            local fx, fy = self:point(math.min(spawn_ms / duration_ms, 1))
            tex.draw_texture(self.t_firework, { frame = frame, scale = 0.8, x = fx - half, y = y + fy - half })
        end
    end
end

function NoteArc:draw(y, elapsed_ms, duration_ms)
    local progress = math.min(1, elapsed_ms / duration_ms)
    local x_i, y_i = self:point(progress)

    if self.is_balloon then
        if not self.t_rainbow then
            if progress < 1 then tex.draw_texture(self.t_note, { x = x_i, y = y + y_i }) end
            return
        end
        self:draw_rainbow(y, elapsed_ms / duration_ms)
    elseif self.big and self.t_firework and self.firework_frames > 0 then
        self:draw_fireworks(y, elapsed_ms, duration_ms)
    end

    if progress < 1 then
        tex.draw_texture(self.t_note, { x = x_i, y = y + y_i })
    end
end

return NoteArc
