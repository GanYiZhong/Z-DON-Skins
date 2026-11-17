CameraCloud = {}
CameraCloud.__index = CameraCloud

function CameraCloud.new()
    local self = setmetatable({}, CameraCloud)

    self.fade_in = tex.get_animation(32, "title")
    self.fade_in:start()
    self.text_fade = tex.get_animation(33, "title")
    self.text_fade:start()
    self.move_up = tex.get_animation(34, "title")
    self.move_up:start()
    self.breathing = tex.get_animation(35, "title")
    self.breathing:start()

    self.t_cloud = tex.get_texture("title/camera/camera_cloud")
    self.t_cloud_text_1 = tex.get_texture("title/camera/camera_cloud_text_1")
    self.t_cloud_text_2 = tex.get_texture("title/camera/camera_cloud_text_2")

    return self
end

function CameraCloud:update(current_ms)
    self.fade_in:update(current_ms)
    self.text_fade:update(current_ms)
    self.move_up:update(current_ms)
    self.breathing:update(current_ms)
end

function CameraCloud:draw(alpha)
    alpha = alpha or 1
    if alpha <= 0 then return end
    tex.draw_texture(self.t_cloud, {
        scale = self.breathing.attribute, center = true, y = self.move_up.attribute, fade = alpha,
    })
    tex.draw_texture(self.t_cloud_text_1, {
        scale = self.breathing.attribute, center = true, y = self.move_up.attribute,
        fade = alpha * math.min(self.fade_in.attribute, 1 - self.text_fade.attribute),
    })
    tex.draw_texture(self.t_cloud_text_2, {
        scale = self.breathing.attribute, center = true, y = self.move_up.attribute,
        fade = alpha * math.min(self.fade_in.attribute, self.text_fade.attribute),
    })
end
