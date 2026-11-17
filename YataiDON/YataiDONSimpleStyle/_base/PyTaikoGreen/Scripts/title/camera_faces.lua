local SMOKE_FRAME_MS = 70
local COSTUME_AT_MS, COSTUME_FADE_MS = 140, 100
local SMOKE_SCALE = 2.2  -- smoke width over face width
local COSTUME_SCALE = 3.1 -- costume image width over face width (the drum is ~42% of the 256 px image)
local FOLLOW_MS = 100
local LOST_MS, LOST_FADE_MS = 500, 150
local MATCH = 0.6 -- a detection belongs to a face whose centre is within this many face widths

-- kisekae smoke, then a costume face that follows each detected face in the camera viewport
CameraFaces = {}
CameraFaces.__index = CameraFaces

function CameraFaces.new(viewport, set)
    local self = setmetatable({}, CameraFaces)
    self.viewport = viewport
    self.tracks = {}
    self.t_smoke = tex.get_texture("title/camera/face_smoke")
    local smoke = tex.get_texture_info("camera", "face_smoke")
    self.smoke_w = smoke and smoke.x2[1] or 0
    tex.load_folder("camera_faces", set)
    local info = tex.get_texture_info(set, "face")
    if info then
        self.face = { id = tex.get_texture("camera_faces/" .. set .. "/face"), w = info.x2[1], count = info.frame_count }
    end
    camera.detect_faces(true)
    return self
end

-- one of the 12 costume face sets (nut cameraKao<N>), picked per attract and shared with the song board
function CameraFaces.random_set()
    return "m" .. math.random(0, 11)
end

local function centre(b) return b.x + b.w / 2, b.y + b.h / 2 end

function CameraFaces:update(ms)
    local dt = self.ms and ms - self.ms or 0
    self.ms = ms
    for _, f in ipairs(camera.faces()) do
        local fx, fy = centre(f)
        local best, best_d
        for _, t in ipairs(self.tracks) do
            local tx, ty = centre(t.target)
            local d = math.sqrt((fx - tx) ^ 2 + (fy - ty) ^ 2)
            if d < MATCH * t.target.w and (not best_d or d < best_d) then best, best_d = t, d end
        end
        if best then
            best.target, best.seen = f, ms
        elseif self.face then
            self.tracks[#self.tracks + 1] = { target = f, box = { x = f.x, y = f.y, w = f.w, h = f.h },
                born = ms, seen = ms, frame = math.random(0, self.face.count - 1) }
        end
    end
    local k = math.min(1, dt / FOLLOW_MS)
    for i = #self.tracks, 1, -1 do
        local t = self.tracks[i]
        if ms - t.seen > LOST_MS + LOST_FADE_MS then
            table.remove(self.tracks, i)
        else
            for _, key in ipairs({ "x", "y", "w", "h" }) do t.box[key] = t.box[key] + (t.target[key] - t.box[key]) * k end
        end
    end
end

local function draw_scaled(id, frame, size, cx, cy, w, fade)
    tex.draw_texture(id, { frame = frame, x = cx - w / 2, y = cy - w / 2, x2 = w - size, y2 = w - size, fade = fade })
end

function CameraFaces:draw()
    local vp = self.viewport
    for _, t in ipairs(self.tracks) do
        local cx = vp.x + (t.box.x + t.box.w / 2) * vp.width
        local cy = vp.y + (t.box.y + t.box.h / 2) * vp.height
        local fw = t.box.w * vp.width
        local age = self.ms - t.born
        local lost = math.max(0, self.ms - t.seen - LOST_MS)
        local fade = 1 - math.min(1, lost / LOST_FADE_MS)
        if age >= COSTUME_AT_MS then
            local a = math.min(1, (age - COSTUME_AT_MS) / COSTUME_FADE_MS) * fade
            draw_scaled(self.face.id, t.frame, self.face.w, cx, cy, fw * COSTUME_SCALE, a)
        end
        local smoke = math.floor(age / SMOKE_FRAME_MS)
        if smoke < 5 and self.smoke_w > 0 then
            draw_scaled(self.t_smoke, smoke, self.smoke_w, cx, cy, fw * SMOKE_SCALE, 1)
        end
    end
end
