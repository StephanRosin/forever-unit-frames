-- The raid view in a party (raid profile: showInParty): a 5-player group
-- shows in the raid panel and the party frames hide (Units/Party.lua's
-- visibility driver); with it off, or the raid frames off, the party
-- frames behave as before.
local M = H.M
local ns = H.LoadAddon()
local RC, Party = ns.RaidConfig, ns.Party
_G.ForeverUnitFramesDB = { raid = { ["Tester-Testrealm"] = { general = { showInParty = true } } } }
M.units.player = { name = "Me", class = "MAGE", isPlayer = true, health = 1, healthMax = 1 }
M.units.party1 = { name = "Ann", class = "PRIEST", isPlayer = true, health = 1, healthMax = 1 }

-- Before the raid profile is attached the party block does not ask it;
-- building the raid panel at login restyles the party block.
local styleAll, restyled = Party.StyleAll, 0
Party.StyleAll = function()
    if ns.RaidHeader.anchor then restyled = restyled + 1 end
    return styleAll()
end
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
Party.StyleAll = styleAll
local header = Party.header
H.checkTrue("login: raid panel restyles the party block", restyled > 0)
H.check("login: party hides in any group", M.drivers[header], "[group] hide; show")
H.checkTrue("solo: party header shown", header:IsShown())
M.SetGroup({ "party1" })
M.RunTimers()
H.check("party: party frames hidden", header:IsShown(), false)
H.checkTrue("party: raid panel shown", ns.RaidHeader.panel:IsShown())
H.check("party: you and your party in the panel", ns.RaidHeader.Count(1), 2)
M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1 } })
H.check("raid: party frames hidden", header:IsShown(), false)
M.SetRaidRoster({})

-- Off: the unit frames' own rule again.
RC.Set("general", "showInParty", false)
H.check("off: hidden in raids only", M.drivers[header], Party.RAID_DRIVER)
H.checkTrue("off: party frames in a party", header:IsShown())
H.check("off: panel hidden in a party", ns.RaidHeader.panel:IsShown(), false)

-- Party frames kept in raids: only the party view hides them.
ns.Config.Set("party", "partyHideInRaid", false)
H.check("kept in raids, no raid view: no driver", M.drivers[header], nil)
RC.Set("general", "showInParty", true)
H.check("kept in raids, raid view: driver", M.drivers[header], "[group:raid] show; [group] hide; show")
H.check("kept in raids: hidden in a party", header:IsShown(), false)
M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1 } })
H.checkTrue("kept in raids: shown in a raid", header:IsShown())
M.SetRaidRoster({})
ns.Config.Set("party", "partyHideInRaid", true)

-- Raid frames off: the party view is off with them.
RC.Set("general", "enabled", false)
H.check("raid frames off: party rule", M.drivers[header], Party.RAID_DRIVER)
H.checkTrue("raid frames off: party frames shown", header:IsShown())
RC.Set("general", "enabled", true)
H.check("raid frames on: party view again", M.drivers[header], "[group] hide; show")

-- In combat the drivers wait (they are protected).
M.combat = true
RC.Set("general", "showInParty", false)
H.check("combat: unchanged", M.drivers[header], "[group] hide; show")
M.SetCombat(false)
H.check("after combat: changed", M.drivers[header], Party.RAID_DRIVER)
