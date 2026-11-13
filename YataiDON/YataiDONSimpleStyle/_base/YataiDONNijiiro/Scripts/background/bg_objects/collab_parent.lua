-- A collab backdrop taken from the parent skin (its art and its script), with this skin's
-- collab behaviour on top: the dance_b_* dancer-count model and no drumroll burst on balloons.
-- The parent's script is loaded from its own file, so its requires resolve to the parent's
-- background objects, which its art is laid out for.
local DancerModel = require("background/bg_objects/collab_dancer_model")

-- the parent skin's copy of a script: the second match on package.path (the first is this skin's)
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

-- stands in for the dancers while the parent's handle_gauge runs, so its own count is inert
local NO_DANCERS = {
    add_dancer = function() end, remove_dancer = function() end,
    leave_dancer = function() end, set_count = function() end,
}

local CollabParent = {}

-- name: module name ("background/bg_collabs/animal"); max_dancers: the troupe size when the
-- engine's collab table gives none
function CollabParent.extend(name, max_dancers)
    local chunk = assert(load_parent(name), name .. ": the parent skin has no such script")
    local Class = chunk(name)
    local base_new, base_gauge = Class.new, Class.handle_gauge

    function Class.new(player_num, bpm, path, max)
        local self = base_new(player_num, bpm, path, max)
        self.dancer_model = DancerModel.new(max or max_dancers)
        return self
    end

    function Class:handle_gauge(player_num, progress, is_clear, is_rainbow, clear_progress)
        local dancers = self.dancer
        self.dancer = NO_DANCERS
        base_gauge(self, player_num, progress, is_clear, is_rainbow, clear_progress)
        self.dancer = dancers
        if dancers then self.dancer_model:apply(dancers, progress, is_clear, clear_progress) end
    end

    function Class:handle_balloon(player_num) end

    return Class
end

return CollabParent
