-- Leader, assistant, master looter and ready check on raid cells: the
-- unit frames' group icons (Elements/GroupIcons.lua), each at its own
-- point from the raid profile (Raid/Cell.lua: frame.iconPoint); the
-- master looter in our own art. Unit frames keep their row and show no
-- master looter.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Cell, GroupIcons = ns.RaidConfig, ns.RaidHeader, ns.RaidCell, ns.GroupIcons
M.units.player = { name = "Me", class = "MAGE", className = "Mage", isPlayer = true, level = 60,
    health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.lootMethod, M.masterLooterRaidID = Enum.LootMethod.Masterlooter, 2
M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1, unit = { leader = true } },
    { name = "Bob", class = "MAGE", subgroup = 1, unit = { assistant = true } },
    { name = "Cid", class = "ROGUE", subgroup = 1 } })
M.RunTimers()

local function cell(i) return Header.headers[1]:GetAttribute("child" .. i) end
local ann, bob, cid = cell(1).groupIcons, cell(2).groupIcons, cell(3).groupIcons
H.checkTrue("cells have group icons", ann)
H.check("icon point: leader", table.concat({ Cell.IconPoint(cell(1), "leader") }, ","), "TOPLEFT,1,-1")
H.check("icon point: unknown", Cell.IconPoint(cell(1), "rez"), nil)

-- Leader and assistant, at the top left, the profile's icon size.
H.checkTrue("leader shown", ann.leader:IsShown())
H.check("crown", ann.leader._atlas, GroupIcons.LEADER.leader.atlas)
local p, rel, relPoint, x, y = ann.leader:GetPoint(1)
H.checkTrue("top left, inside", p == "TOPLEFT" and rel == cell(1) and relPoint == "TOPLEFT" and x == 1 and y == -1)
H.check("icon size", ann.leader:GetWidth(), 14)
H.check("holder over the cell", ann.holder._allPoints, cell(1))
H.checkTrue("assistant shown", bob.leader:IsShown())
H.check("assistant icon", bob.leader._texture, GroupIcons.LEADER.assistant.file)
H.check("Cid: neither", cid.leader:IsShown(), false)

-- The master looter: raid index 2.
H.checkTrue("Bob loots", bob.looter:IsShown())
H.check("our art", bob.looter._texture, "Interface\\AddOns\\ForeverUnitFrames\\Media\\MasterLooter.tga")
p, rel, relPoint, x, y = bob.looter:GetPoint(1)
H.checkTrue("top right, inside", p == "TOPRIGHT" and relPoint == "TOPRIGHT" and x == -1 and y == -1)
H.check("Ann does not", ann.looter:IsShown(), false)
M.lootMethod = Enum.LootMethod.Group
M.FireEvent("PARTY_LOOT_METHOD_CHANGED")
H.check("group loot: no looter", bob.looter:IsShown(), false)
M.lootMethod = Enum.LootMethod.Masterlooter
M.FireEvent("PARTY_LOOT_METHOD_CHANGED")
H.checkTrue("master loot again", bob.looter:IsShown())

-- A ready check, in the centre.
M.units.raid1.readyCheck = "ready"
M.units.raid3.readyCheck = "waiting"
M.FireEvent("READY_CHECK")
H.check("ready", ann.ready._atlas, GroupIcons.READY.ready)
p, rel, relPoint, x, y = ann.ready:GetPoint(1)
H.checkTrue("centred", p == "CENTER" and relPoint == "CENTER" and x == 0 and y == 0)
H.check("waiting", cid.ready._atlas, GroupIcons.READY.waiting)
H.check("no resurrection icon on cells", ann.rez:IsShown(), false)

-- Switches and points of the profile.
RC.Set("r10", "leaderIcon", false)
H.check("leader off", ann.leader:IsShown(), false)
RC.Set("r10", "looterIcon", false)
H.check("looter off", bob.looter:IsShown(), false)
RC.Set("r10", "readyCheckIconPoint", "BOTTOM")
p, rel, relPoint, x, y = ann.ready:GetPoint(1)
H.checkTrue("ready check moved", p == "BOTTOM" and relPoint == "BOTTOM" and x == 0 and y == 1)
RC.Set("r10", "iconSize", 20)
H.check("bigger", ann.ready:GetWidth(), 20)
RC.ResetScope("r10")
H.checkTrue("reset: leader back", ann.leader:IsShown())

-- Secret answers show nothing.
M.groupSecret = true
M.FireEvent("PARTY_LEADER_CHANGED")
H.check("secret: no leader", ann.leader:IsShown(), false)
M.groupSecret = false

-- Unit frames: their row as before, never a looter.
H.check("player frame: no looter icon", ns.Frames.player.groupIcons.looter, nil)
H.check("player frame: its own row", ns.Frames.player.groupIcons.holder._allPoints, nil)

-- Test mode: the pretend members' icons.
ns.RaidTestMode.Set(true)
local f1, f2, f4 = Cell.fakes[1].groupIcons, Cell.fakes[2].groupIcons, Cell.fakes[4].groupIcons
H.checkTrue("pretend: you lead", f1.leader:IsShown())
H.checkTrue("pretend: you loot", f1.looter:IsShown())
H.check("pretend: member 2 assists", f2.leader._texture, GroupIcons.LEADER.assistant.file)
H.check("pretend: member 4 not ready", f4.ready._atlas, GroupIcons.READY.notready)
H.check("pretend: member 3 nothing", Cell.fakes[3].groupIcons.ready:IsShown(), false)
ns.RaidTestMode.Set(false)
H.check("no errors", #M.errors, 0)
