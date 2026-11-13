require("title/attract_camera")
require("title/camera_cloud")
require("title/bana_advert")

AttractScene = {}
AttractScene.__index = AttractScene

function AttractScene.new()
    local self = setmetatable({}, AttractScene)
    self.attract_camera = AttractCamera.new()
    self.camera_cloud = CameraCloud.new()
    self.bana_advert_1 = BanaAdvertisement.new()
    self.bana_advert_2 = BanaAdvertisement.new()
    return self
end

function AttractScene:update(current_ms)
    self.attract_camera:update(current_ms)
    self.camera_cloud:update(current_ms)
    self.bana_advert_1:update(current_ms)
    self.bana_advert_2:update(current_ms)
end

function AttractScene:draw()
    self.attract_camera:draw()
    self.camera_cloud:draw()
    self.bana_advert_1:draw(34, 157)
    self.bana_advert_2:draw(1011, 157)
end

function AttractScene:is_finished()
    return self.attract_camera:is_finished()
end

function AttractScene:close()
    self.attract_camera:close()
end
