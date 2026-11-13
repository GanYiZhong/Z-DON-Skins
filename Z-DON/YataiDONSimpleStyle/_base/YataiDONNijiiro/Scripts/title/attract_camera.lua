local SKIN = {
    attract_camera_viewport = { x = 0, y = 0, width = 0, height = 0 },
}
require("title/attract_chara")

AttractCamera = {}
AttractCamera.__index = AttractCamera

function AttractCamera.new()
    local self = setmetatable({}, AttractCamera)
    self.start_ms = tex.get_current_ms()
    self.finished = false

    camera.open()
    audio.play_sound("camera", "attract_mode")

    self.live_icon_texture_change = tex.get_animation(36, "title")
    self.live_icon_texture_change:start()

    local ok, timer = pcall(tex.get_animation, 37, "title")
    self.scene_timer = ok and timer or nil
    if self.scene_timer then self.scene_timer:start() end

    self.t_background = tex.get_texture("title/camera/background")
    self.t_live_icon = tex.get_texture("title/camera/live_icon")
    self.t_live_text = tex.get_texture("title/camera/live_text")

    self.viewport = SKIN.attract_camera_viewport
    self.chara = AttractChara.new()

    return self
end

function AttractCamera:update(current_ms)
    camera.update()
    self.chara:update(current_ms)
    self.live_icon_texture_change:update(current_ms)
    if self.scene_timer then
        self.scene_timer:update(current_ms)
        self.finished = self.scene_timer.is_finished
    else
        self.finished = (current_ms - self.start_ms >= 30000)
    end
end

function AttractCamera:draw()
    -- the video and costume characters sit under the frame, which has a transparent window
    if self.viewport then
        camera.draw(self.viewport.x, self.viewport.y, self.viewport.width, self.viewport.height)
    end
    self.chara:draw()
    tex.draw_texture(self.t_background)
    tex.draw_texture(self.t_live_icon, { frame = math.floor(self.live_icon_texture_change.attribute) })
    tex.draw_texture(self.t_live_text)
end

function AttractCamera:is_finished()
    return self.finished
end

function AttractCamera:close()
    camera.close()
end
