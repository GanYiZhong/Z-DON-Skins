local DonBG1 = require("background/bg_objects/donbg/1")
local DonBG2 = require("background/bg_objects/donbg/2")
local DonBG3 = require("background/bg_objects/donbg/3")
local DonBG4 = require("background/bg_objects/donbg/4")
local DonBG5 = require("background/bg_objects/donbg/5")
local DonBG6 = require("background/bg_objects/donbg/6")

local DonBGBase = require("background/bg_objects/donbg/base")

local DonBG = {}

-- a collab pack's band, replayed from its exported movie (bg_data/donbg_anim/<name>.lua)
function DonBG.create_named(player_num, path, name)
    return DonBGBase.new(nil, player_num, path, name)
end

function DonBG.create(player_num, path, index)
    index = index or math.random(1, 6)
    local map = { DonBG1, DonBG2, DonBG3, DonBG4, DonBG5, DonBG6 }
    local selected = map[index]
    return selected.new(index, player_num, path)
end

return DonBG
