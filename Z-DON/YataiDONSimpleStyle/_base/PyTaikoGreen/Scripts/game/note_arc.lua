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

local RAINBOW_ARC = { end_x = 812, end_y = -348, control_x = 323, control_y = -364 }
local RAINBOW_X, RAINBOW_Y, RAINBOW_Y_P2 = -119, -433, -77
local RAINBOW_SPARKS = 6
local SYNCHRO_CROUCH_FRAMES, SYNCHRO_FLIGHT_FRAMES = 9, 26
local SYNCHRO_CROUCH_DIP, SYNCHRO_CROUCH_SQUASH = 20, 0.16
local SYNCHRO_ARM_TILT = 45
local SYNCHRO_ARMS_X = { -17, 21 }

local function trunc(v) return v < 0 and math.ceil(v) or math.floor(v) end

function NoteArc.new(note_tex_type, big, is_balloon, player_num, start_x, start_y, rainbow_arc, synchro)
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
    self.rainbow_arc = rainbow_arc
    local rainbow_key = rainbow_arc and "rainbow_angled" or "rainbow"
    self.t_rainbow = tex.get_texture("game/balloon/" .. rainbow_key)
    if self.t_rainbow then
        self.rainbow_info = tex.get_texture_info("balloon", rainbow_key)
    end
    self.rainbow_x, self.rainbow_y = 0, self.p2 and SKIN.note_arc_balloon_p2_y.y or 0
    if rainbow_arc then
        local dir = self.p2 and -1 or 1
        self.ex = sx + RAINBOW_ARC.end_x * SKIN_S
        self.ey = sy + RAINBOW_ARC.end_y * dir * SKIN_S
        self.cx = sx + RAINBOW_ARC.control_x * SKIN_S
        self.cy = sy + RAINBOW_ARC.control_y * dir * SKIN_S
        self.rainbow_x = sx + self.note_width / 2 + RAINBOW_X * SKIN_S
        self.rainbow_y = sy + self.note_width / 2 + (self.p2 and RAINBOW_Y_P2 or RAINBOW_Y) * SKIN_S
        self.t_firework = self.t_firework or tex.get_texture("game/hit_effect/firework")
        self.firework_frames = tex.get_texture_info("hit_effect", "firework").frame_count
        self.firework_size = tex.get_texture_info("hit_effect", "firework").width
        if synchro then
            self.t_arm = tex.get_texture("waiwai_game/effect/synchro_arm_flight")
            self.arm_info = tex.get_texture_info("effect", "synchro_arm_flight")
        end
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

    tex.draw_texture(self.t_rainbow, {
        x = self.rainbow_x + crop_start, y = y + self.rainbow_y, x2 = -w + crop_w,
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

function NoteArc:draw_rainbow_sparks(y, elapsed_ms, duration_ms)
    local delay = self.t_arm and 6 or 0
    local half_note, half = self.note_width / 2, self.firework_size / 2
    for i = 0, RAINBOW_SPARKS - 1 do
        local spawn_ms = (6 + 3 * i) * FRAME_MS
        local age_ms = elapsed_ms - spawn_ms - delay * FRAME_MS
        local frame = math.floor(age_ms / FRAME_MS)
        if age_ms >= 0 and frame < self.firework_frames then
            local fx, fy = self:point((spawn_ms - 3.5 * FRAME_MS) / duration_ms)
            tex.draw_texture(self.t_firework, { frame = frame, x = fx + half_note - half, y = y + fy + half_note - half })
        end
    end
end

function NoteArc:draw_synchro(y, elapsed_ms)
    local frames = elapsed_ms / FRAME_MS
    local flight = (frames - SYNCHRO_CROUCH_FRAMES) / SYNCHRO_FLIGHT_FRAMES
    if flight >= 1 then return end

    local dir = self.p2 and -1 or 1
    local crouch = 0
    local tilt = 0
    local x_i, y_i
    if flight < 0 then
        local out = math.min(frames / 4, 1)
        crouch = frames < 4 and 1 - (1 - out) * (1 - out) or (SYNCHRO_CROUCH_FRAMES - frames) / 5
        x_i, y_i = self.sx, self.sy
    else
        tilt = flight
        local left = 1 - flight
        x_i, y_i = self:point(1 - left * left)
    end

    local half = self.note_width / 2
    local cx, cy = x_i + half, y + y_i + half
    local arm_w, arm_h = self.arm_info.width, self.arm_info.height
    local angle = math.rad(SYNCHRO_ARM_TILT * tilt)
    local mid_x = cx - 23 * SKIN_S * tilt
    local mid_y = cy + dir * (54 - 15 * tilt) * SKIN_S
    for _, x in ipairs(SYNCHRO_ARMS_X) do
        tex.draw_texture(self.t_arm, {
            x = mid_x + x * math.cos(angle) * SKIN_S,
            y = mid_y + dir * x * math.sin(angle) * SKIN_S,
            origin = { arm_w / 2, arm_h / 2 },
            rotation = dir * SYNCHRO_ARM_TILT * tilt,
            mirror = self.p2 and "vertical" or nil,
        })
    end

    local squash = SYNCHRO_CROUCH_SQUASH * crouch * self.note_width
    tex.draw_texture(self.t_note, {
        x = x_i,
        y = y + y_i + squash / 2 + dir * SYNCHRO_CROUCH_DIP * crouch * SKIN_S,
        y2 = -squash,
    })
end

function NoteArc:draw(y, elapsed_ms, duration_ms)
    local progress = math.min(1, elapsed_ms / duration_ms)
    local x_i, y_i = self:point(progress)

    if self.rainbow_arc then
        if self.big then self:draw_rainbow_sparks(y, elapsed_ms, duration_ms) end
        if self.t_arm then
            self:draw_synchro(y, elapsed_ms)
            return
        end
        if self.is_balloon and self.t_rainbow then
            self:draw_rainbow(y, elapsed_ms / duration_ms)
            return
        end
    elseif self.is_balloon then
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
