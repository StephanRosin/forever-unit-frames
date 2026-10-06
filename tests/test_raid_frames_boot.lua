-- The raid frames at login (Core/Boot.lua): built after the raid profile
-- is attached and the size known, out of combat; a login in combat
-- builds them when combat ends.
local M = H.M
local ns = H.LoadAddon()
M.SetRaidRoster({
    { name = "Ann", class = "PRIEST", subgroup = 1, assignedRole = "HEALER" },
    { name = "Bob", class = "WARRIOR", subgroup = 2, assignedRole = "TANK" },
})
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
H.check("nothing before login", ns.RaidHeader.anchor, nil)
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
H.checkTrue("panel built", ns.RaidHeader.anchor)
H.check("size known when built", ns.RaidCell.Size(), 10)
H.check("group 1 cell", ns.RaidHeader.headers[1]:GetAttribute("child1").unit, "raid1")
H.check("group 2 cell", ns.RaidHeader.headers[2]:GetAttribute("child1").unit, "raid2")
H.checkTrue("panel shown in the raid", ns.RaidHeader.panel:IsShown())

-- A /reload in combat: built after combat, nothing blocked.
ns = H.LoadAddon()
M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1 } })
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.combat = true
M.FireEvent("PLAYER_LOGIN")
H.check("combat login: not yet", ns.RaidHeader.anchor, nil)
M.SetCombat(false)
H.checkTrue("combat login: built after combat", ns.RaidHeader.anchor)
H.check("combat login: nothing blocked", #M.blocked, 0)
H.check("combat login: cell", ns.RaidHeader.headers[1]:GetAttribute("child1").unit, "raid1")
