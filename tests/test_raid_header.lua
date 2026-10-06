-- The raid panel (Raid/Header.lua): one group header per block with its
-- filter and cell layout, blocks placed by how many cells they hold,
-- titles and borders on plain frames, the active size's profile, nothing
-- protected touched in combat.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Cell = ns.RaidConfig, ns.RaidHeader, ns.RaidCell
ns.Config.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()

local function point(frame)
    local p, rel, relPoint, x, y = frame:GetPoint(1)
    local name = rel == UIParent and "UIParent" or rel == Header.anchor and "anchor"
        or rel == Header.anchor.mover and "mover" or "?"
    return table.concat({ p, name, relPoint, x, y }, " ")
end
local function member(name, class, subgroup, role)
    return { name = name, class = class, subgroup = subgroup, assignedRole = role,
        unit = { health = 100, healthMax = 100, powerType = 0 } }
end
local CLASSES = { "WARRIOR", "PRIEST", "MAGE", "ROGUE", "DRUID" }
-- n members, five to a group, classes in turn.
local function raid(n)
    local list = {}
    for i = 1, n do
        list[i] = member("M" .. string.format("%02d", i), CLASSES[(i - 1) % #CLASSES + 1], math.floor((i - 1) / 5) + 1,
            i == 1 and "TANK" or "NONE")
    end
    return list
end

-- Solo: the headers of the 10-player profile, empty; the panel hidden.
Header.Create()
H.check("anchor name", Header.anchor:GetName(), "ForeverUnitFramesRaid")
H.check("anchor follows its mover", point(Header.anchor), "TOPLEFT mover TOPLEFT 0 0")
H.check("mover at the profile's top-left corner", point(Header.anchor.mover), "TOPLEFT UIParent CENTER -600 150")
H.check("two group blocks at 10", #Header.blocks, 2)
local h1, h2 = Header.headers[1], Header.headers[2]
H.check("header name", h1:GetName(), "ForeverUnitFramesRaidBlock1")
H.check("header template", h1._template, "SecureGroupHeaderTemplate")
H.check("cell template", h1:GetAttribute("template"), "ForeverUnitFramesRaidButtonTemplate")
H.check("no snippet", h1:GetAttribute("initialConfigFunction"), nil)
H.check("shows in a raid", h1:GetAttribute("showRaid"), true)
H.check("not in a party by default", h1:GetAttribute("showParty"), false)
H.check("group filter 1", h1:GetAttribute("groupFilter"), "1")
H.check("group filter 2", h2:GetAttribute("groupFilter"), "2")
H.check("cells down", h1:GetAttribute("point"), "TOP")
H.check("cell spacing", h1:GetAttribute("yOffset"), -2)
H.check("five per column", h1:GetAttribute("unitsPerColumn"), 5)
H.check("sorted by raid order", h1:GetAttribute("sortMethod"), "INDEX")
H.checkTrue("headers shown", h1:IsShown() and h2:IsShown())
H.check("panel hidden solo", Header.panel:IsShown(), false)

-- A raid of 7: 10-player profile, groups 1 and 2.
M.SetRaidRoster(raid(7))
M.RunTimers()
H.check("size", Cell.Size(), 10)
H.checkTrue("panel shown in a raid", Header.panel:IsShown())
H.check("group 1 cells", Header.Count(1), 5)
H.check("group 2 cells", Header.Count(2), 2)
local c1 = h1:GetAttribute("child1")
H.check("cell unit", c1.unit, "raid1")
H.check("cell size", c1:GetWidth() .. "x" .. c1:GetHeight(), "96x44")
H.check("block 1 at the corner", point(h1), "TOPLEFT anchor TOPLEFT 0 0")
H.check("block 2 beside it", point(h2), "TOPLEFT anchor TOPLEFT 102 0")
H.check("panel width", Header.panel:GetWidth(), 198)
H.check("panel height: room for a full group", Header.panel:GetHeight(), 5 * 44 + 4 * 2)
H.checkTrue("panel border", Header.panel.border and Header.panel.border[1]:IsShown())
H.check("panel border gold", ns.Config.Get(Header.PANEL_SCOPE, "borderStyle"), "GOLD")
H.check("block border off", Header.decor[1].border[1]:IsShown(), false)
H.check("no titles", Header.decor[1].title:IsShown(), false)

-- 15 members: the 20-player profile, groups 1-4; group 4 is empty and
-- takes no room, its header waits below the panel.
M.SetRaidRoster(raid(15))
M.RunTimers()
H.check("size 20", Cell.Size(), 20)
H.check("four blocks", #Header.blocks, 4)
H.check("cells of the 20 profile", Header.headers[1]:GetAttribute("child1"):GetWidth(), 88)
H.check("group 3 beside group 2", point(Header.headers[3]), "TOPLEFT anchor TOPLEFT 188 0")
H.check("empty group 4 parked below", point(Header.headers[4]), "TOPLEFT anchor TOPLEFT 0 -214")
H.check("empty block's frame hidden", Header.decor[4]:IsShown(), false)
H.check("panel: three blocks", Header.panel:GetWidth(), 3 * 88 + 2 * 6)
RC.Set("r20", "hideEmpty", false)
H.check("empty group shown: room for five", point(Header.headers[4]), "TOPLEFT anchor TOPLEFT 282 0")

-- By class: one block per class, packed; titles from the class names.
RC.Set("r20", "hideEmpty", true)
RC.Set("r20", "groupBy", "CLASS")
RC.Set("r20", "blockTitles", true)
M.RunTimers()
H.check("nine class blocks", #Header.blocks, 9)
H.check("warrior filter", Header.headers[1]:GetAttribute("groupFilter"), "1,2,3,4,WARRIOR")
H.check("strict", Header.headers[1]:GetAttribute("strictFiltering"), true)
H.check("warriors", Header.Count(1), 3)
H.check("paladins", Header.Count(2), 0)
H.check("warriors first, below their title", point(Header.headers[1]), "TOPLEFT anchor TOPLEFT 0 -14")
H.check("priests next (no paladins)", point(Header.headers[3]), "TOPLEFT anchor TOPLEFT 94 -14")
H.check("title", Header.decor[1].title:GetText(), "Warrior")
H.checkTrue("title shown", Header.decor[1].title:IsShown())
H.check("block height with title", Header.decor[1]:GetHeight(), 14 + 3 * 40 + 2 * 2)
-- Back to groups: the class filter is cleared.
RC.Set("r20", "groupBy", "GROUP")
H.check("filter back to a group", Header.headers[1]:GetAttribute("groupFilter"), "1")
H.check("strict cleared", Header.headers[1]:GetAttribute("strictFiltering"), nil)
H.check("unused headers hidden", Header.headers[9]:IsShown(), false)
RC.Set("r20", "blockTitles", false)

-- Borders: a block's ring between the blocks, a cell's between the cells.
RC.Set("r20", "blockBorder", true)
H.checkTrue("block border", Header.decor[1].border[1]:IsShown())
H.check("block border widens the gap", point(Header.headers[2]), "TOPLEFT anchor TOPLEFT 100 0")
RC.Set("r20", "blockBorder", false)
RC.Set("r20", "cellBorder", true)
H.check("cell border: cells further apart", Header.headers[1]:GetAttribute("yOffset"), -4)
H.check("cell border: cells inside the block", point(Header.headers[1]), "TOPLEFT anchor TOPLEFT 1 -1")
ns.Config.Set("general", "borderSize", 2)
H.check("unit-frame border size counts", Header.headers[1]:GetAttribute("yOffset"), -6)
ns.Config.Set("general", "borderSize", 1)
RC.Set("r20", "cellBorder", false)

-- Rows instead of columns.
RC.Set("r20", "cellGrowth", "RIGHT")
H.check("rows: point", Header.headers[1]:GetAttribute("point"), "LEFT")
H.check("rows: blocks stacked by width", point(Header.headers[2]), "TOPLEFT anchor TOPLEFT " .. (5 * 88 + 4 * 2 + 6) .. " 0")
RC.Set("r20", "cellGrowth", "DOWN")

-- Another size's profile changes nothing now.
local updates = M.headerUpdates
RC.Set("r40", "cellWidth", 60)
H.check("other size: no relayout", M.headerUpdates, updates)

-- Combat: settings wait; a joining member is placed by the header.
M.combat = true
RC.Set("r20", "cellSpacing", 5)
H.check("combat: spacing waits", Header.headers[1]:GetAttribute("yOffset"), -2)
local list = raid(15)
list[16] = member("M16", "MAGE", 4, "NONE")
M.SetRaidRoster(list)
H.check("combat: joiner gets a cell", Header.Count(4), 1)
H.check("combat: nothing blocked", #M.blocked, 0)
M.SetCombat(false)
H.check("after combat: spacing", Header.headers[1]:GetAttribute("yOffset"), -5)
H.check("after combat: group 4 placed", point(Header.headers[4]), "TOPLEFT anchor TOPLEFT 282 0")
RC.Set("r20", "cellSpacing", 2)

-- Raid frames off: headers and panel hidden.
RC.Set("general", "enabled", false)
H.check("off: headers hidden", Header.headers[1]:IsShown(), false)
H.check("off: panel hidden", Header.panel:IsShown(), false)
RC.Set("general", "enabled", true)
H.checkTrue("on again", Header.headers[1]:IsShown() and Header.panel:IsShown())

-- A party: shown only with the raid view in party on.
M.SetRaidRoster({})
M.units.player = { name = "Me", class = "MAGE", isPlayer = true }
M.units.party1 = { name = "Ann", class = "PRIEST", isPlayer = true }
M.SetGroup({ "party1" })
M.RunTimers()
H.check("party: panel hidden", Header.panel:IsShown(), false)
H.check("party: no cells", Header.Count(1), 0)
RC.Set("general", "showInParty", true)
M.RunTimers()
H.checkTrue("raid view in party: panel", Header.panel:IsShown())
H.check("raid view in party: you and your party", Header.Count(1), 2)
H.check("raid view in party: header attribute", Header.headers[1]:GetAttribute("showParty"), true)

-- Two empty groups: each parked header waits at a spot of its own below
-- the panel, so members joining both in combat do not overlap.
RC.Set("general", "showInParty", false)
M.SetGroup({})
RC.Set("general", "sizeMode", "20")
M.SetRaidRoster(raid(8))
M.RunTimers()
H.check("parked: four blocks", #Header.blocks, 4)
H.check("parked: group 3 below the panel", point(Header.headers[3]), "TOPLEFT anchor TOPLEFT 0 -214")
H.check("parked: group 4 beside it", point(Header.headers[4]), "TOPLEFT anchor TOPLEFT 94 -214")
M.combat = true
local list8 = raid(8)
list8[9] = member("J1", "MAGE", 3, "NONE")
list8[10] = member("J2", "MAGE", 4, "NONE")
M.SetRaidRoster(list8)
local j1, j2 = Header.headers[3]:GetAttribute("child1"), Header.headers[4]:GetAttribute("child1")
H.checkTrue("parked: both joiners shown", j1.unit ~= nil and j2.unit ~= nil)
H.checkTrue("parked: joiners apart", point(Header.headers[3]) ~= point(Header.headers[4]))
H.check("parked: nothing blocked", #M.blocked, 0)
M.SetCombat(false)
M.RunTimers()
H.check("after combat: group 3 placed", point(Header.headers[3]), "TOPLEFT anchor TOPLEFT 188 0")
H.check("after combat: group 4 placed", point(Header.headers[4]), "TOPLEFT anchor TOPLEFT 282 0")
RC.Set("general", "sizeMode", "AUTO")
