-- The debuff row of raid cells (Raid/CellAuras.lua): an aura group of the
-- cell's container along the bottom of the health bar, made when first
-- switched on, showing the debuffs the centre icon does not.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, CellAuras = ns.RaidConfig, ns.RaidHeader, ns.RaidAuras
M.units.player = { name = "Me", class = "PRIEST", isPlayer = true, health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1 } })
M.RunTimers()

local cell = Header.headers[1]:GetAttribute("child1")
local c = cell.raidAuras.container
H.check("off by default: no group", #c._groupOrder, 0)

RC.Set("r10", "debuffRow", true)
local group = c._groups[CellAuras.ROW_GROUP]
H.checkTrue("on: a group", group)
H.check("the rest of the debuffs", group.filter, "HARMFUL|!RAID")
H.check("three", group.max, 3)
H.check("icons of the 10 profile", group.layout.elementWidth, 14)
H.check("a pixel apart", group.layout.elementSpacing, 1)
H.check("enabled", group.enabled, true)
H.check("flow: a row", c._flow.axis, AnchorUtil.FlowLayoutAxis.Horizontal)
H.check("flow: from the bottom left", c._flow.anchor, "BOTTOMLEFT")
H.check("flow: rightwards, then up", c._flow.horizontal .. "," .. c._flow.vertical, "1,1")
local p, rel, relPoint, x, y = c:GetPoint(1)
H.checkTrue("on the health bar's bottom left", p == "BOTTOMLEFT" and rel == cell.health and relPoint == "BOTTOMLEFT")
H.check("a pixel in", x .. "," .. y, "1,1")
H.check("a batch of buttons", #cell.raidAuras.row, M.AURA_BATCH)
local b = cell.raidAuras.row[1]
H.check("button size", b:GetWidth(), 14)
H.check("icon registered", b._icon, b.icon)
H.check("border by dispel type", b._dispelTextures[1].texture, b.border)
H.check("the centre icon stays", c._slots.dispel.enabled, true)

-- Filters follow the centre icon.
RC.Set("r10", "dispelFilter", "ALL")
H.check("all dispellable in the centre: the rest", group.filter, "HARMFUL|!DISPELLABLE")
RC.Set("r10", "dispelIcon", false)
H.check("no centre icon: every debuff", group.filter, "HARMFUL")
RC.Set("r10", "dispelIcon", true)
RC.Set("r10", "dispelFilter", "MINE")

-- Count and size.
RC.Set("r10", "debuffCount", 5)
H.check("five", group.max, 5)
RC.Set("r10", "debuffSize", 18)
H.check("layout resized", group.layout.elementWidth, 18)
H.check("buttons resized", b:GetWidth(), 18)

-- The 40-player profile has its own.
RC.Set("general", "sizeMode", "40")
H.check("40: off there", group.enabled, false)
RC.Set("r40", "debuffRow", true)
H.check("40: on", group.enabled, true)
H.check("40: its size", group.layout.elementWidth, 12)
H.check("40: its count", group.max, 3)
RC.Set("general", "sizeMode", "AUTO")

-- Off again: the group stays, disabled.
RC.Set("r10", "debuffRow", false)
H.check("off: disabled", group.enabled, false)
H.check("still one group", #c._groupOrder, 1)
H.check("no errors", #M.errors, 0)
