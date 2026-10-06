-- The damage block of the role grouping (Raid/Layout.lua) holds damage
-- and the members without a role; sorted by role it shows damage first,
-- as test mode does (Raid/TestMode.lua), and a role test mode does not
-- know ranks with those without one.
local ns = H.LoadAddon()
local Layout, Test = ns.RaidLayout, ns.RaidTestMode

local blocks = Layout.Blocks("ROLE", 10, "ROLE")
H.check("tank block: one role", blocks[1].filter.groupBy, nil)
H.check("healer block: one role", blocks[2].filter.groupBy, nil)
H.check("damage block: damage and no role", blocks[3].filter.roleFilter, "DAMAGER,NONE")
H.check("damage block: by role", blocks[3].filter.groupBy, "ASSIGNEDROLE")
H.check("damage block: damage first", blocks[3].filter.groupingOrder, Layout.ROLE_ORDER)
H.check("unsorted: none", Layout.Blocks("ROLE", 10, "INDEX")[3].filter.groupBy, nil)

local function member(name, role)
    return { name = name, class = "MAGE", subgroup = 1, assignedRole = role }
end
local members = { member("A", "NONE"), member("B", "DAMAGER"), member("C", "NONE"), member("D", "DAMAGER") }
local names = {}
for i, entry in ipairs(Test.Distribute(blocks, members, 10, "ROLE")[3]) do names[i] = entry.member.name end
H.check("damage, then no role", table.concat(names, ","), "B,D,A,C")

members[2] = member("B", "SOMETHING")
local ok, lists = pcall(Test.Distribute, Layout.Blocks("GROUP", 10, "ROLE"), members, 10, "ROLE")
H.check("an unknown role does not break the order", ok, true)
names = {}
for i, entry in ipairs(ok and lists[1] or {}) do names[i] = entry.member.name end
H.check("ranked with no role", table.concat(names, ","), "D,A,B,C")
