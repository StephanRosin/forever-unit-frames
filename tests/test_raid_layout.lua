-- Raid layout (Raid/Layout.lua): the blocks of each grouping for a raid
-- size with their header filters, block titles from Blizzard's own
-- strings, header attributes for the cell growth, and where cells and
-- blocks go. Pure numbers; the mock's header checks the filters.
local M = H.M
local ns = H.LoadAddon()
local L = ns.RaidLayout

H.check("groups of 10", table.concat(L.Groups(10), ","), "1,2")
H.check("groups of 20", table.concat(L.Groups(20), ","), "1,2,3,4")
H.check("groups of 40", table.concat(L.Groups(40), ","), "1,2,3,4,5,6,7,8")

local function ids(blocks)
    local list = {}
    for _, b in ipairs(blocks) do list[#list + 1] = tostring(b.id) end
    return table.concat(list, ",")
end
H.check("group blocks at 20", ids(L.Blocks("GROUP", 20)), "1,2,3,4")
H.check("class blocks in Blizzard's class order", ids(L.Blocks("CLASS", 40)),
    "WARRIOR,PALADIN,PRIEST,SHAMAN,DRUID,ROGUE,MAGE,WARLOCK,HUNTER")
H.check("role blocks", ids(L.Blocks("ROLE", 10)), "TANK,HEALER,DAMAGER")
H.check("one block", ids(L.Blocks("NONE", 10)), "ALL")
H.check("group blocks hold five", L.Blocks("GROUP", 40)[1].capacity, 5)
H.check("class blocks grow", L.Blocks("CLASS", 40)[1].capacity, nil)

-- Filters, as the group headers take them.
local g2 = L.Blocks("GROUP", 20)[2].filter
H.check("group filter", g2.groupFilter, "2")
H.check("group: not strict", g2.strictFiltering, nil)
local mage = L.Blocks("CLASS", 10)[7].filter
H.check("class filter: the size's groups and the class", mage.groupFilter, "1,2,MAGE")
H.check("class filter: strict", mage.strictFiltering, true)
local dps = L.Blocks("ROLE", 20)[3].filter
H.check("role filter: groups and every class", dps.groupFilter, "1,2,3,4," .. table.concat(CLASS_SORT_ORDER, ","))
H.check("role filter: damage takes the unassigned", dps.roleFilter, "DAMAGER,NONE")
H.check("role filter: strict", dps.strictFiltering, true)
H.check("tank filter", L.Blocks("ROLE", 20)[1].filter.roleFilter, "TANK")
local all = L.Blocks("NONE", 40)[1].filter
H.check("one block: every group of the size", all.groupFilter, "1,2,3,4,5,6,7,8")
H.check("one block: ordered by group", all.groupBy, "GROUP")
H.check("one block: group order", all.groupingOrder, "1,2,3,4,5,6,7,8")
H.check("filter keys", table.concat(L.FILTER_KEYS, ","), "groupFilter,roleFilter,strictFiltering,groupBy,groupingOrder")

-- Who belongs to a block (test mode's pretend members), as the filters.
local function member(subgroup, class, role) return { subgroup = subgroup, class = class, assignedRole = role } end
H.checkTrue("group match", L.Matches(L.Blocks("GROUP", 10)[2], member(2, "MAGE", "DAMAGER"), 10))
H.check("class in a group beyond the size", L.Matches(L.Blocks("CLASS", 10)[7], member(3, "MAGE", "NONE"), 10), false)
H.checkTrue("unassigned counts as damage", L.Matches(L.Blocks("ROLE", 10)[3], member(1, "MAGE", "NONE"), 10))
H.check("healer is no damage", L.Matches(L.Blocks("ROLE", 10)[3], member(1, "PRIEST", "HEALER"), 10), false)
H.checkTrue("everyone of the size", L.Matches(L.Blocks("NONE", 20)[1], member(4, "PRIEST", "HEALER"), 20))

-- Titles: Blizzard's own strings, the token when the client has none.
LOCALIZED_CLASS_NAMES_MALE.WARRIOR = nil
_G.TANK = nil
H.check("group title", L.Title(L.Blocks("GROUP", 10)[2]), "Group 2")
H.check("class title", L.Title(L.Blocks("CLASS", 10)[7]), "Mage")
H.check("class title without a name", L.Title(L.Blocks("CLASS", 10)[1]), "WARRIOR")
H.check("role title", L.Title(L.Blocks("ROLE", 10)[2]), "Healer")
H.check("role title without a name", L.Title(L.Blocks("ROLE", 10)[1]), "TANK")
H.check("one block title", L.Title(L.Blocks("NONE", 10)[1]), "Raid")

-- Geometry. Cells 80 x 38, 2 apart; a cell border reaching 1 out adds
-- 2 to the gap and insets the cells by 1.
local s = { cellWidth = 80, cellHeight = 38, cellGap = 2, cellsPerLine = 5, cellGrowth = "DOWN",
    blockGap = 6, blocksPerLine = 8, blockDirection = "HORIZONTAL", inset = 0, titleHeight = 0 }
local a = L.HeaderAttributes(s, 40)
H.check("down: point", a.point, "TOP")
H.check("down: y offset", a.yOffset, -2)
H.check("down: x offset", a.xOffset, 0)
H.check("down: per column", a.unitsPerColumn, 5)
H.check("down: enough columns for the size", a.maxColumns, 8)
H.check("down: new columns to the right", a.columnAnchorPoint, "LEFT")
H.check("down: column spacing", a.columnSpacing, 2)
local x, y = L.CellOffset(s, 7)
H.check("cell 7: second column", x, 82)
H.check("cell 7: second row", y, -40)
local w, h = L.BlockSize(s, 5)
H.check("full group: width", w, 80)
H.check("full group: height", h, 5 * 38 + 4 * 2)
w, h = L.BlockSize(s, 7)
H.check("seven: two columns", w, 162)
H.check("seven: five rows", h, 198)

local r = { cellWidth = 80, cellHeight = 38, cellGap = 2, cellsPerLine = 4, cellGrowth = "RIGHT",
    blockGap = 6, blocksPerLine = 2, blockDirection = "VERTICAL", inset = 1, titleHeight = 14 }
a = L.HeaderAttributes(r, 10)
H.check("right: point", a.point, "LEFT")
H.check("right: x offset", a.xOffset, 2)
H.check("right: y offset", a.yOffset, 0)
H.check("right: new rows below", a.columnAnchorPoint, "TOP")
H.check("right: rows for the size", a.maxColumns, 3)
x, y = L.CellOffset(r, 6)
H.check("right cell 6: x", x, 82)
H.check("right cell 6: y", y, -40)
w, h = L.BlockSize(r, 6)
H.check("right block width: four, border inset", w, 4 * 80 + 3 * 2 + 2)
H.check("right block height: two rows, title, inset", h, 2 * 38 + 2 + 2 + 14)
x, y = L.HeaderOffset(r)
H.check("header inside its block: x", x, 1)
H.check("header inside its block: y", y, -15)

-- Room: groups keep room for five; others for who is there; empty blocks
-- take none when hidden, one cell otherwise.
local group, class = L.Blocks("GROUP", 10)[1], L.Blocks("CLASS", 10)[1]
H.check("group room", L.Room(group, 2, true), 5)
H.check("empty group hidden", L.Room(group, 0, true), nil)
H.check("empty group shown", L.Room(group, 0, false), 5)
H.check("class room", L.Room(class, 3, true), 3)
H.check("empty class hidden", L.Room(class, 0, true), nil)
H.check("empty class shown", L.Room(class, 0, false), 1)

-- Arranging blocks: in a row, wrapping after blocksPerLine; dropped
-- blocks leave no gap.
local sizes = { { 80, 198 }, false, { 80, 120 }, { 162, 80 } }
local pos, pw, ph = L.Arrange({ blockGap = 6, blocksPerLine = 2, blockDirection = "HORIZONTAL" }, sizes)
H.check("first block", pos[1].x .. "," .. pos[1].y, "0,0")
H.check("dropped block", pos[2], nil)
H.check("second shown block beside", pos[3].x .. "," .. pos[3].y, "86,0")
H.check("third wraps under the tallest", pos[4].x .. "," .. pos[4].y, "0,-204")
H.check("panel width", pw, 166)
H.check("panel height", ph, 284)
pos, pw, ph = L.Arrange({ blockGap = 6, blocksPerLine = 2, blockDirection = "VERTICAL" }, sizes)
H.check("vertical: second below", pos[3].x .. "," .. pos[3].y, "0,-204")
H.check("vertical: wraps right of the widest", pos[4].x .. "," .. pos[4].y, "86,0")
H.check("vertical panel width", pw, 248)
H.check("vertical panel height", ph, 324)
pos, pw, ph = L.Arrange({ blockGap = 6, blocksPerLine = 2, blockDirection = "VERTICAL" }, { false })
H.check("nothing to show", pw .. "," .. ph, "0,0")
