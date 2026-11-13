-- This skin's note arc: the parent's script with the flight and the big-note sparks redone as
-- the cabinet's (onp_jump):
--  * the note flies from the judge circle to 魂 in 30 frames on the cabinet's path, here a
--    cubic Bezier fitted to it (within 6 px), P1 arcing up and P2 down, each with its own fit;
--    it then waits at 魂 until the engine's flight (31 frames) ends
--  * a big note leaves 9 sparks (hit_effect/firework, the cabinet's 13-frame spark on black),
--    the first at frame 5 and then every 3 frames, each centred where the note was about 2
--    frames before, at full size, added onto the scene
-- The balloon keeps the parent's flight and rainbow (the cabinet's balloon has its own path).
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

assert(load_parent("game/note_arc"), "game/note_arc: the parent skin has no note_arc script")()

local FRAME_MS = 16.67
local FLIGHT_MS = 30 * FRAME_MS
-- control points as offsets from the start (c1) and from the end (c2)
local CONTROL = {
    [1] = { c1x = 196.8, c1y = -474.8, c2x = -300.4, c2y = -419.3 },
    [2] = { c1x = 178.5, c1y = 486.4, c2x = -314.9, c2y = 414.3 },
}
-- sparks: spawn frames, and where each sits on the 30-frame flight (frames)
local SPARK_COUNT = 9
local SPARK_SPAWN, SPARK_SPAWN_STEP = 5, 3
local SPARK_AT, SPARK_AT_STEP = 2.58, 3.085

local parent_new = NoteArc.new
-- per note texture type: the textures are fixed, a hit only needs the numbers
local spark_offsets = {}
function NoteArc.new(note_tex_type, big, is_balloon, player_num, start_x, start_y)
    local self = parent_new(note_tex_type, big, is_balloon, player_num, start_x, start_y)
    local c = CONTROL[self.p2 and 2 or 1]
    self.c1x, self.c1y = self.sx + c.c1x, self.sy + c.c1y
    self.c2x, self.c2y = self.ex + c.c2x, self.ey + c.c2y

    -- a spark is centred on the note: both textures' own offsets and sizes
    if self.t_firework then
        local off = spark_offsets[note_tex_type]
        if off == nil then
            local note = tex.get_texture_info("notes", tostring(note_tex_type))
            local spark = tex.get_texture_info("hit_effect", "firework")
            off = (note and spark) and {
                note.x[1] - spark.x[1] + (note.x2[1] - spark.x2[1]) / 2,
                note.y[1] - spark.y[1] + (note.y2[1] - spark.y2[1]) / 2,
            } or false
            spark_offsets[note_tex_type] = off
        end
        if off then self.spark_dx, self.spark_dy = off[1], off[2] end
    end
    return self
end

local parent_point = NoteArc.point
local parent_draw = NoteArc.draw

-- the cabinet's flight, progress 0..1 over its 30 frames
function NoteArc:point(progress)
    if self.is_balloon then return parent_point(self, progress) end
    local t = math.max(0, math.min(1, progress))
    local u = 1 - t
    local b0, b1, b2, b3 = u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t
    return b0 * self.sx + b1 * self.c1x + b2 * self.c2x + b3 * self.ex,
           b0 * self.sy + b1 * self.c1y + b2 * self.c2y + b3 * self.ey
end

function NoteArc:draw_fireworks(y, elapsed_ms)
    if not self.spark_dx then return end
    for i = 0, SPARK_COUNT - 1 do
        local age_ms = elapsed_ms - (SPARK_SPAWN + SPARK_SPAWN_STEP * i) * FRAME_MS
        local frame = math.floor(age_ms / FRAME_MS)
        if age_ms >= 0 and frame < self.firework_frames then
            local fx, fy = self:point((SPARK_AT + SPARK_AT_STEP * i) * FRAME_MS / FLIGHT_MS)
            tex.draw_texture(self.t_firework, {
                frame = frame, center = true,
                x = fx + self.spark_dx, y = y + fy + self.spark_dy,
            })
        end
    end
end

function NoteArc:draw(y, elapsed_ms, duration_ms)
    if self.is_balloon then return parent_draw(self, y, elapsed_ms, duration_ms) end
    if self.big and self.t_firework and self.firework_frames > 0 then
        self:draw_fireworks(y, elapsed_ms)
    end
    if elapsed_ms < duration_ms then
        local x_i, y_i = self:point(elapsed_ms / FLIGHT_MS)
        tex.draw_texture(self.t_note, { x = x_i, y = y + y_i })
    end
end

return NoteArc
