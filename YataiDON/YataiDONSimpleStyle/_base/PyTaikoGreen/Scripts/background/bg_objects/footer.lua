local Footer = {}
Footer.__index = Footer

-- mirrors (optional): one entry per texture.json index of the footer key, true draws that
-- copy mirrored horizontally (e.g. { false, true } for a left base and its mirrored right)
function Footer.new(path, index, mirrors)
    local self = setmetatable({}, Footer)
    self.path = path or "background"
    self.index = (index ~= nil) and index or math.random(0, 2)
    self.mirrors = mirrors
    if self.index ~= -1 then
        tex.load_folder(self.path, "footer")
    end
    return self
end

function Footer:draw()
    if self.index == -1 then return end
    local id = tex.get_texture(self.path .. "/" .. "footer" .. "/" .. tostring(self.index))
    if not self.mirrors then
        tex.draw_texture(id)
        return
    end
    for i, mirror in ipairs(self.mirrors) do
        tex.draw_texture(id, { index = i - 1, mirror = mirror and "horizontal" or nil })
    end
end

function Footer:destroy()
    if self.index == -1 then return end
    tex.unload_folder(self.path, "footer")
end

return Footer
