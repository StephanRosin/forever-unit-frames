-- Sorting by role within a block (Raid/Layout.lua, Raid/Header.lua,
-- Raid/TestMode.lua): tanks, healers, damage, then members without a
-- role, each in raid order; the headers group by the assigned role.
local M = H.M
local ns = H.LoadAddon()
local RC, Layout, Header, Test = ns.RaidConfig, ns.RaidLayout, ns.RaidHeader, ns.RaidTestMode
ns.Config.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()

-- The setting: ROLE appended to the enum.
H.check("sort choices", table.concat(ns.RaidSettings.Get("sortBy").values, ","), "INDEX,NAME,ROLE")
RC.Set("r10", "sortBy", "ROLE")
H.check("stored by index", ns.RaidProfiles.Export(10), "1;aSO3")

-- The blocks: every block but a role block groups by the assigned role.
H.check("role order", Layout.ROLE_ORDER, "TANK,HEALER,DAMAGER,NONE")
local group = Layout.Blocks("GROUP", 10, "ROLE")[1].filter
H.check("group block: by role", group.groupBy, "ASSIGNEDROLE")
H.check("group block: role order", group.groupingOrder, "TANK,HEALER,DAMAGER,NONE")
H.check("group block: still its group", group.groupFilter, "1")
local class = Layout.Blocks("CLASS", 10, "ROLE")[1].filter
H.check("class block: by role", class.groupBy, "ASSIGNEDROLE")
H.check("class block: still strict", class.strictFiltering, true)
local all = Layout.Blocks("NONE", 20, "ROLE")[1].filter
H.check("one block: by role instead of group", all.groupBy, "ASSIGNEDROLE")
H.check("one block: role order", all.groupingOrder, "TANK,HEALER,DAMAGER,NONE")
H.check("one block: still the size's groups", all.groupFilter, "1,2,3,4")
H.check("role block: one role already", Layout.Blocks("ROLE", 10, "ROLE")[1].filter.groupBy, nil)
H.check("raid order: no grouping", Layout.Blocks("GROUP", 10, "INDEX")[1].filter.groupBy, nil)
H.check("no sort given: no grouping", Layout.Blocks("GROUP", 10)[1].filter.groupBy, nil)

-- The headers: a group in raid order of damage, healer, tank, nobody,
-- damage shows tank, healer, damage, damage, nobody.
Header.Create()
M.SetRaidRoster({
    { name = "Dps", class = "MAGE", subgroup = 1, assignedRole = "DAMAGER" },
    { name = "Heal", class = "PRIEST", subgroup = 1, assignedRole = "HEALER" },
    { name = "Tank", class = "WARRIOR", subgroup = 1, assignedRole = "TANK" },
    { name = "Nobody", class = "ROGUE", subgroup = 1 },
    { name = "Dps2", class = "HUNTER", subgroup = 1, assignedRole = "DAMAGER" },
})
M.RunTimers()
local h1 = Header.headers[1]
H.check("header groups by role", h1:GetAttribute("groupBy"), "ASSIGNEDROLE")
H.check("header: within a role, raid order", h1:GetAttribute("sortMethod"), "INDEX")
local order = {}
for i = 1, 5 do order[i] = h1:GetAttribute("child" .. i).unit end
H.check("cells by role", table.concat(order, ","), "raid3,raid2,raid1,raid5,raid4")
RC.Set("r10", "sortBy", "NAME")
H.check("by name: no grouping", h1:GetAttribute("groupBy"), nil)
H.check("by name: header sorts names", h1:GetAttribute("sortMethod"), "NAME")
RC.Set("r10", "sortBy", "INDEX")
H.check("raid order", h1:GetAttribute("sortMethod"), "INDEX")

-- Test mode places its pretend members the same way.
local members = Test.Members(10)
local function indices(list)
    local out = {}
    for i, entry in ipairs(list) do out[i] = entry.index end
    return table.concat(out, ",")
end
local lists = Test.Distribute(Layout.Blocks("GROUP", 10, "ROLE"), members, 10, "ROLE")
H.check("test mode: group 1 by role", indices(lists[1]), "1,2,3,4,5")
H.check("test mode: group 2 by role", indices(lists[2]), "6,7,9,8,10")
lists = Test.Distribute(Layout.Blocks("NONE", 10, "ROLE"), members, 10, "ROLE")
H.check("test mode: one block by role", indices(lists[1]), "1,2,6,7,9,3,4,5,8,10")
lists = Test.Distribute(Layout.Blocks("NONE", 10, "INDEX"), members, 10, "INDEX")
H.check("test mode: one block by group", indices(lists[1]), "1,2,3,4,5,6,7,8,9,10")
lists = Test.Distribute(Layout.Blocks("GROUP", 10, "NAME"), members, 10, "NAME")
H.check("test mode: by name", indices(lists[1]), "5,3,2,4,1")
