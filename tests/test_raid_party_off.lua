-- The raid view in party off (the default): building the raid panel at
-- login leaves the party block as it was styled before.
local M = H.M
local ns = H.LoadAddon()
local Party = ns.Party
_G.ForeverUnitFramesDB = {}
M.units.player = { name = "Me", class = "MAGE", isPlayer = true, health = 1, healthMax = 1 }

local styleAll, restyled = Party.StyleAll, 0
Party.StyleAll = function()
    if ns.RaidHeader.anchor then restyled = restyled + 1 end
    return styleAll()
end
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
Party.StyleAll = styleAll
H.checkTrue("login: raid panel built", ns.RaidHeader.anchor ~= nil)
H.check("login: party block not restyled", restyled, 0)
H.check("login: party rule", M.drivers[Party.header], Party.RAID_DRIVER)
