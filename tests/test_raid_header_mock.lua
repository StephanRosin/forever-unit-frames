-- The mock's group header against the client's SecureGroupHeaders.lua:
-- raid filters, grouping, sorting, columns and the header's own size, as
-- the raid blocks (Raid/Header.lua) use them.
local M = H.M
H.LoadAddon()

local function header(attributes)
    local h = CreateFrame("Frame", "TestRaidHeader" .. #M.frames, UIParent, "SecureGroupHeaderTemplate")
    h:SetAttribute("_ignore", "attributeChanges")
    h:SetAttribute("template", "SecureUnitButtonTemplate")
    for name, value in pairs(attributes) do h:SetAttribute(name, value) end
    h:SetAttribute("_ignore", nil)
    h:Show()
    return h
end

local function units(h)
    local list, i = {}, 1
    while h:GetAttribute("child" .. i) do
        local unit = h:GetAttribute("child" .. i):GetAttribute("unit")
        if unit then list[#list + 1] = unit end
        i = i + 1
    end
    return table.concat(list, ",")
end

M.SetRaidRoster({
    { name = "Tank", class = "WARRIOR", subgroup = 1, assignedRole = "TANK", role = "MAINTANK" },
    { name = "Mage", class = "MAGE", subgroup = 2, assignedRole = "DAMAGER" },
    { name = "Ann", class = "PRIEST", subgroup = 1, assignedRole = "HEALER" },
    { name = "Zed", class = "WARRIOR", subgroup = 3, assignedRole = "DAMAGER" },
    { name = "Bob", class = "ROGUE", subgroup = 2 },
})
H.check("roster: raid members", GetNumGroupMembers(), 5)
H.check("roster: raid unit data", UnitName("raid4"), "Zed")
local name, _, subgroup, _, _, class, _, _, _, role, _, assigned = GetRaidRosterInfo(1)
H.check("roster info: name", name, "Tank")
H.check("roster info: subgroup", subgroup, 1)
H.check("roster info: class token", class, "WARRIOR")
H.check("roster info: role", role, "MAINTANK")
H.check("roster info: assigned role", assigned, "TANK")
H.check("roster info: unassigned is NONE", select(12, GetRaidRosterInfo(5)), "NONE")
H.checkTrue("a raid is a group", IsInGroup())

-- Not shown in a raid without showRaid.
H.check("no showRaid: nobody", units(header({})), "")
-- Groups.
H.check("group 1", units(header({ showRaid = true, groupFilter = "1" })), "raid1,raid3")
H.check("groups 2,3", units(header({ showRaid = true, groupFilter = "2,3" })), "raid2,raid4,raid5")
-- A class, limited to groups (strict: group and class must both match).
H.check("class, strict", units(header({ showRaid = true, groupFilter = "1,2,WARRIOR", strictFiltering = true })),
    "raid1")
H.check("class, loose matches group or class",
    units(header({ showRaid = true, groupFilter = "2,WARRIOR" })), "raid1,raid2,raid4,raid5")
-- A role among the groups and every class (strict).
local all = "1,2,3,4,5,6,7,8," .. table.concat(CLASS_SORT_ORDER, ",")
H.check("role, strict", units(header({ showRaid = true, groupFilter = all, roleFilter = "DAMAGER,NONE",
    strictFiltering = true })), "raid2,raid4,raid5")
H.check("role, strict, groups limit", units(header({ showRaid = true, groupFilter = "1,2," .. table.concat(CLASS_SORT_ORDER, ","),
    roleFilter = "DAMAGER,NONE", strictFiltering = true })), "raid2,raid5")
-- Sorting: by name; grouped by raid group, then index.
H.check("by name", units(header({ showRaid = true, sortMethod = "NAME" })), "raid3,raid5,raid2,raid1,raid4")
H.check("grouped by group", units(header({ showRaid = true, groupBy = "GROUP", groupingOrder = "1,2,3,4,5,6,7,8" })),
    "raid1,raid3,raid2,raid5,raid4")
-- The grouping order as the client builds it (doubleFillTable): group
-- numbers collide with the positions stored as strings.
H.check("grouping order 3,1,2: the client's 2,3,1",
    units(header({ showRaid = true, groupBy = "GROUP", groupingOrder = "3,1,2" })), "raid2,raid5,raid4,raid1,raid3")
local ok, err = pcall(header, { showRaid = true, groupBy = "GROUP", groupingOrder = "3,1" })
H.checkTrue("grouping order 3,1 raises: number against string",
    not ok and tostring(err):find("attempt to compare number with string", 1, true))
ok, err = pcall(header, { showRaid = true, groupBy = "GROUP" })
H.checkTrue("groupBy without groupingOrder raises", not ok and tostring(err):find("groupingOrder", 1, true))

-- Columns: 5 units, 2 per column, columns to the right.
local h = header({ showRaid = true, point = "TOP", yOffset = -2, unitsPerColumn = 2, maxColumns = 3,
    columnSpacing = 4, columnAnchorPoint = "LEFT" })
local c1, c2, c3 = h:GetAttribute("child1"), h:GetAttribute("child2"), h:GetAttribute("child3")
for i = 1, 5 do h:GetAttribute("child" .. i):SetSize(80, 38) end
h:Hide()
h:Show()
local p, rel, relPoint, x, y = c2:GetPoint(1)
H.checkTrue("column: second below the first", p == "TOP" and rel == c1 and relPoint == "BOTTOM" and x == 0 and y == -2)
p, rel, relPoint, x, y = c3:GetPoint(1)
H.checkTrue("column: third starts a new column", p == "LEFT" and rel == c1 and relPoint == "RIGHT" and x == 4 and y == 0)
H.check("column: first on the header's top", select(3, c1:GetPoint(1)), "TOP")
H.check("column: first on the header's left too", select(3, c1:GetPoint(2)), "LEFT")
H.check("header width: 3 columns", h:GetWidth(), 3 * 80 + 2 * 4)
H.check("header height: 2 rows", h:GetHeight(), 2 * 38 + 2)
-- maxColumns caps what is shown.
h:SetAttribute("maxColumns", 2)
H.check("max columns: 4 shown", units(h), "raid1,raid2,raid3,raid4")
-- Rows growing right.
local r = header({ showRaid = true, point = "LEFT", xOffset = 3, unitsPerColumn = 3, maxColumns = 2,
    columnSpacing = 5, columnAnchorPoint = "TOP" })
for i = 1, 5 do r:GetAttribute("child" .. i):SetSize(80, 38) end
r:Hide()
r:Show()
p, rel, relPoint, x, y = r:GetAttribute("child4"):GetPoint(1)
H.checkTrue("row: fourth starts a new row below", p == "TOP" and rel == r:GetAttribute("child1")
    and relPoint == "BOTTOM" and x == 0 and y == -5)
H.check("row header width", r:GetWidth(), 3 * 80 + 2 * 3)
H.check("row header height", r:GetHeight(), 2 * 38 + 5)

-- An empty header keeps one button and a sliver of size.
local e = header({ showRaid = true, groupFilter = "8", minWidth = 0.1, minHeight = 0.1 })
H.checkTrue("empty: one button made", e:GetAttribute("child1"))
H.check("empty: button hidden", e:GetAttribute("child1"):IsShown(), false)
H.check("empty: width", e:GetWidth(), 0.1)

-- A party with showParty: the player first (slot 1), then the members.
M.SetRaidRoster({})
H.check("left the raid", IsInRaid(), false)
M.units.player = { name = "Me", class = "MAGE", isPlayer = true }
M.units.party1 = { name = "Ann", class = "PRIEST", isPlayer = true, role = "HEALER" }
M.SetGroup({ "party1" })
local party = header({ showRaid = true, showParty = true, showPlayer = true, groupFilter = "1,MAGE",
    strictFiltering = true })
H.check("party: by class, strict", units(party), "player")
H.check("party: no showParty, nobody", units(header({ showRaid = true })), "")

-- Snippets are refused: they do not run on this client.
local s = CreateFrame("Frame", "TestSnippetHeader", UIParent, "SecureGroupHeaderTemplate")
s:SetAttribute("initialConfigFunction", "self:SetWidth(10)")
H.checkError("snippet", function() s:Show() end)
