-- A class with nothing to watch (a warrior) in a group: the scan reads no
-- roster and fires nothing while it stays that way.
local M = H.M
local ns = H.LoadAddon()
local Watch = ns.RaidBuffWatch
ns.Config.Use({})
ns.RaidProfiles.Attach({})
M.units.player = { name = "Tester", class = "WARRIOR", className = "Warrior", isPlayer = true }
M.SetRaidRoster({
    { name = "A", class = "MAGE", subgroup = 1, unit = { auras = {} } },
    { name = "B", class = "PRIEST", subgroup = 1, unit = { auras = {} } },
})
H.check("nothing watched", #Watch.Watched(), 0)
local reads, fired = 0, 0
local realMembers = Watch.Members
Watch.Members = function(...) reads = reads + 1; return realMembers(...) end
ns.Listen("RAID_BUFFS_CHANGED", function() fired = fired + 1 end)
Watch.Scan()
Watch.Scan()
H.check("no roster read", reads, 0)
H.check("no event", fired, 0)
H.check("still scanned", Watch.armed, true)
Watch.Members = realMembers
