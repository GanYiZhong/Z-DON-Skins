AllNetIcon = {}
AllNetIcon.__index = AllNetIcon

function AllNetIcon.new(online)
    local self = setmetatable({}, AllNetIcon)
    self.online    = online
    self.outdated  = false
    self.indicator = tex.get_texture("global/overlay/allnet_indicator")
    self.params    = { frame = 0, x = 0, y = 0 }   -- reused every draw, no per-frame table garbage
    self:set_frame()
    return self
end

function AllNetIcon:set_frame()
    self.params.frame = self.outdated and 1 or (self.online and 2 or 0)
end

function AllNetIcon:update(current_ms, online, outdated)
    if self.online ~= online or self.outdated ~= outdated then
        self.online   = online
        self.outdated = outdated
        self:set_frame()
    end
end

function AllNetIcon:draw(x, y)
    local p = self.params
    p.x, p.y = x, y
    tex.draw_texture(self.indicator, p)
end
