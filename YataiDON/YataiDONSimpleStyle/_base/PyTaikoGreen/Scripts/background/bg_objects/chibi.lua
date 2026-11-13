local BaseChibi     = require("background/bg_objects/chibi/base")
local ChibiTamashii = require("background/bg_objects/chibi/tamashii")
local SETS          = require("background/bg_objects/chibi/sets")

Chibi = {}

-- The default sets (path "background") play their motion from chibi/sets.lua and every bad
-- hit is the tamashii. Collabs give their good hits a spec with BaseChibi.add; until a collab
-- does, its chibis just hop in and run on frame 0 of one of their keys.
function Chibi.create(index, bpm, bad, is_2p, path)
    path = path or "background"
    local folder = "chibi_" .. index
    if bad then
        return ChibiTamashii.new("background", bpm, is_2p)
    end
    if path == "background" then
        local set  = SETS[index]
        local char = set.chars[math.random(#set.chars)]
        local spec = setmetatable({}, { __index = function(_, k)
            if char[k] ~= nil then return char[k] end
            return set[k]
        end })
        return set.class.new(spec, path, folder, bpm, is_2p)
    end
    local keys = tex.get_texture_keys(folder) or { "0" }
    return BaseChibi.new({ key = keys[math.random(#keys)] }, path, folder, bpm, is_2p)
end

ChibiController = {}
ChibiController.__index = ChibiController

function ChibiController.new(bpm, path, index)
    path = path or "background"
    index = index or math.random(0, 13)
    bpm = bpm or 120

    local self = setmetatable({}, ChibiController)

    self.chibis = {}
    self.index = index
    self.name = "chibi_" .. index
    self.bpm = bpm
    self.path = path

    tex.load_folder(path, "chibi/" .. self.name)
    tex.load_folder("background", "chibi/chibi_bad")

    return self
end

function ChibiController:add_chibi(player_num, bad)
    bad = bad or false
    local is_2p = player_num == 2
    table.insert(self.chibis, Chibi.create(self.index, self.bpm, bad, is_2p, self.path))
end

function ChibiController:update(current_time_ms, bpm)
    if bpm then
        self.bpm = bpm
    end

    for i = #self.chibis, 1, -1 do
        local chibi = self.chibis[i]
        chibi:update(current_time_ms, self.bpm)

        if chibi.done then
            table.remove(self.chibis, i)
        end
    end
end

function ChibiController:draw()
    for _, chibi in ipairs(self.chibis) do
        chibi:draw()
    end
end

function ChibiController:destroy()
    tex.unload_folder(self.path, "chibi/" .. self.name)
    tex.unload_folder("background", "chibi/chibi_bad")
end

return ChibiController
