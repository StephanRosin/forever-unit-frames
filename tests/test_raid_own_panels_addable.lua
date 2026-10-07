-- What an own panel may still take (Own.Addable) after an import that
-- names a block in two panels of the same grouping: the block counts as
-- the lower-numbered panel's (as Own.Columns shows it), so the other
-- panel offers it and taking it moves it there.
local ns = H.LoadAddon()
local RC, Own, Raid = ns.RaidConfig, ns.RaidOwnPanels, ns.Raid
ns.Config.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()
ns.RaidHeader.Create()

local function ids(blocks)
    local list = {}
    for i, block in ipairs(blocks) do list[i] = tostring(block.id) end
    return table.concat(list, ",")
end
local function columns(size)
    local parts = {}
    for _, column in ipairs(Own.Columns(size)) do parts[#parts + 1] = column.id .. ":" .. ids(column.blocks) end
    return table.concat(parts, " ")
end

RC.SetKeys("r20", { { "panel2Show", true }, { "panel2GroupBy", "GROUP" }, { "panel2Blocks", "1" },
    { "panel3Show", true }, { "panel3GroupBy", "GROUP" }, { "panel3Blocks", "2,1" } })
H.check("imported twice: panel 2 keeps group 1", columns(20), "main:3,4 panel2:1 panel3:2")
H.check("panel 3 offers group 1", ids(Own.Addable(20, Raid.OwnPanel("panel3"))), "1,3,4")
H.check("panel 2 offers what it has not", ids(Own.Addable(20, Raid.OwnPanel("panel2"))), "2,3,4")
Own.Place(20, "GROUP", "1", "panel3")
H.check("taken: group 1 in panel 3", columns(20), "main:3,4 panel2: panel3:1,2")
H.check("panel 2 lets it go", RC.Get("r20", "panel2Blocks"), "")
-- Without a duplicate nothing changes: a panel never offers its own.
H.check("panel 3 offers the rest", ids(Own.Addable(20, Raid.OwnPanel("panel3"))), "3,4")
