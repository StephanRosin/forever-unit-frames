-- The raid target marker on raid cells: the unit frames' element
-- (Elements/RaidMarker.lua) with the raid profile's switch, point and
-- icon size (Raid/Cell.lua), just inside the cell; test mode's pretend
-- members carry their own.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Cell = ns.RaidConfig, ns.RaidHeader, ns.RaidCell
M.units.player = { name = "Me", class = "MAGE", className = "Mage", isPlayer = true, level = 60,
    health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1, unit = { raidTarget = 8 } },
    { name = "Bob", class = "MAGE", subgroup = 1 } })
M.RunTimers()

H.check("inset left", table.concat({ Cell.Inset("TOPLEFT") }, ","), "1,-1")
H.check("inset right", table.concat({ Cell.Inset("RIGHT") }, ","), "-1,0")
H.check("inset bottom", table.concat({ Cell.Inset("BOTTOM") }, ","), "0,1")
H.check("inset centre", table.concat({ Cell.Inset("CENTER") }, ","), "0,0")

local cell = Header.headers[1]:GetAttribute("child1")
local r = cell.raidMarker
H.checkTrue("shown", r.icon:IsShown())
H.check("skull", r.icon._spriteCell[1], 8)
H.check("the 10 profile's icon size", r.holder:GetWidth(), 14)
local p, rel, relPoint, x, y = r.holder:GetPoint(1)
H.checkTrue("at the right, inside", p == "RIGHT" and rel == cell and relPoint == "RIGHT" and x == -1 and y == 0)
H.check("Bob: none", Header.headers[1]:GetAttribute("child2").raidMarker.icon:IsShown(), false)

M.units.raid2.raidTarget = 1
M.raidTargetsSecret = true
M.FireEvent("RAID_TARGET_UPDATE")
local bob = Header.headers[1]:GetAttribute("child2").raidMarker.icon
H.checkTrue("a secret index shows", bob:IsShown())
H.check("passed on secret", bob._spriteSecret, true)
M.raidTargetsSecret = false

RC.Set("r10", "raidMarkerPoint", "TOPLEFT")
p, rel, relPoint, x, y = r.holder:GetPoint(1)
H.checkTrue("moved to the top left", p == "TOPLEFT" and relPoint == "TOPLEFT" and x == 1 and y == -1)
RC.Set("r10", "iconSize", 18)
H.check("bigger", r.holder:GetWidth(), 18)
RC.Set("r10", "raidMarker", false)
H.check("off", r.holder:IsShown(), false)
H.check("off: icon hidden", r.icon:IsShown(), false)
RC.ResetScope("r10")
H.checkTrue("on again", r.icon:IsShown())

-- Test mode: the pretend members' own markers.
H.check("member 1: skull", ns.RaidTestMode.Members(10)[1].marker, 8)
ns.TestMode.Set(true)
local f1, f2 = Cell.fakes[1], Cell.fakes[2]
H.checkTrue("pretend: skull shown", f1.raidMarker.icon:IsShown())
H.check("pretend: skull", f1.raidMarker.icon._spriteCell[1], 8)
H.check("pretend member 2: none", f2.raidMarker.icon:IsShown(), false)
H.check("pretend member 6: star", Cell.fakes[6].raidMarker.icon._spriteCell[1], 1)
ns.TestMode.Set(false)
H.check("no errors", #M.errors, 0)
