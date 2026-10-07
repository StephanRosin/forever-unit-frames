-- The role icon on raid cells (Raid/CellRole.lua): tank and healer by
-- default, damage when asked, at its point; secret roles show nothing.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Cell, Role = ns.RaidConfig, ns.RaidHeader, ns.RaidCell, ns.RaidRole
M.units.player = { name = "Me", class = "MAGE", className = "Mage", isPlayer = true, level = 60,
    health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.SetRaidRoster({ { name = "Tank", class = "WARRIOR", subgroup = 1, assignedRole = "TANK" },
    { name = "Ann", class = "PRIEST", subgroup = 1, assignedRole = "HEALER" },
    { name = "Bob", class = "MAGE", subgroup = 1, assignedRole = "DAMAGER" },
    { name = "Cid", class = "ROGUE", subgroup = 1 } })
M.RunTimers()

local function role(i) return Header.headers[1]:GetAttribute("child" .. i).raidRole end
local tank, ann, bob, cid = role(1), role(2), role(3), role(4)
H.checkTrue("tank shown", tank.icon:IsShown())
H.check("tank icon", tank.icon._atlas, Role.ATLAS.TANK)
H.check("healer icon", ann.icon._atlas, Role.ATLAS.HEALER)
H.check("damage: not by default", bob.icon:IsShown(), false)
H.check("no role: none", cid.icon:IsShown(), false)
local p, rel, relPoint, x, y = tank.icon:GetPoint(1)
H.checkTrue("left, inside", p == "LEFT" and relPoint == "LEFT" and x == 1 and y == 0)
H.check("size", tank.icon:GetWidth(), 14)
H.check("above the cell's auras", tank.holder:GetFrameLevel(),
    Header.headers[1]:GetAttribute("child1"):GetFrameLevel() + Role.LEVELS)

RC.Set("r10", "roleIconDamager", true)
H.check("damage shown", bob.icon._atlas, Role.ATLAS.DAMAGER)
RC.Set("r10", "roleIconPoint", "BOTTOMLEFT")
p, rel, relPoint, x, y = tank.icon:GetPoint(1)
H.checkTrue("moved", p == "BOTTOMLEFT" and x == 1 and y == 1)
RC.Set("r10", "roleIcon", false)
H.check("off", tank.icon:IsShown(), false)
RC.ResetScope("r10")
H.checkTrue("on again", tank.icon:IsShown())

-- Roles change: the icons follow; secret ones show nothing.
M.units.raid4.role = "HEALER"
M.FireEvent("PLAYER_ROLES_ASSIGNED")
H.check("new healer", cid.icon._atlas, Role.ATLAS.HEALER)
M.units.raid1.role = M.Secret("TANK")
M.FireEvent("PLAYER_ROLES_ASSIGNED")
H.check("secret role: none", tank.icon:IsShown(), false)

-- Unit frames: none.
H.check("player frame: none", ns.Frames.player.raidRole, nil)

-- Test mode: the pretend members' roles.
ns.RaidTestMode.Set(true)
H.check("pretend tank", Cell.fakes[1].raidRole.icon._atlas, Role.ATLAS.TANK)
H.checkTrue("pretend healer", Cell.fakes[2].raidRole.icon:IsShown())
H.check("pretend damage: hidden", Cell.fakes[3].raidRole.icon:IsShown(), false)
ns.RaidTestMode.Set(false)
H.check("no errors", #M.errors, 0)
