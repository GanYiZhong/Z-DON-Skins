-- YataiDON-HSS override of PyTaikoGreen/background/bg_objects/footer.lua:
-- parent's Footer:draw() passes a possibly-nil texture id straight to draw_texture;
-- same logic, nil-safe.
local Footer = {}
Footer.__index = Footer

function Footer.new(path, index)
    local self = setmetatable({}, Footer)
    self.path = path or "background"
    self.index = (index ~= nil) and index or math.random(0, 2)
    if self.index ~= -1 then
        tex.load_folder(self.path, "footer")
        self.texture_path = self.path .. "/footer/" .. tostring(self.index)
    end
    return self
end

function Footer:draw()
    if self.index == -1 then return end
    local id = tex.get_texture(self.texture_path)
    if id then tex.draw_texture(id) end
end

function Footer:destroy()
    if self.index == -1 then return end
    tex.unload_folder(self.path, "footer")
end

return Footer
