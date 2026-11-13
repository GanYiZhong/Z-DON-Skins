require("campaign/mac_photo")
require("campaign/smart_scan")
require("campaign/kinotake")

CampaignEvent = {}

function CampaignEvent.new(id, seats)
    if id == "mac" then return MacPhoto.new() end
    if id == "kinotake" then return Kinotake.new(seats) end
    return SmartScan.new(id)
end
