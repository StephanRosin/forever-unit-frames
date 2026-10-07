-- Arranging the own panels of a size (Raid/OwnPanels.lua), what the raid
-- window's Arrangement tab does: the columns of a size (the main panel,
-- then each shown own panel, with their blocks), moving a block, adding
-- and removing a panel, changing a panel's grouping. Each acts on the
-- size given, not the one shown.
local M = H.M
local ns = H.LoadAddon()
local RC, Own = ns.RaidConfig, ns.RaidOwnPanels
ns.Config.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()
ns.RaidHeader.Create()

local function describe(columns)
    local parts = {}
    for _, column in ipairs(columns) do
        local tokens = {}
        for i, block in ipairs(column.blocks) do tokens[i] = tostring(block.id) end
        parts[#parts + 1] = column.id .. "(" .. column.groupBy .. "):" .. table.concat(tokens, ",")
    end
    return table.concat(parts, " ")
end
local function events(fn)
    local n = 0
    ns.Listen("RAID_CONFIG_CHANGED", function() n = n + 1 end)
    local before = n
    fn()
    return n - before
end

H.check("20: the main panel alone", describe(Own.Columns(20)), "main(GROUP):1,2,3,4")

-- Adding: the first free slot is shown.
local slot = Own.Add(20)
H.check("panel 2 added", slot.id, "panel2")
H.check("shown at 20", RC.Get("r20", "panel2Show"), true)
H.check("not at 10", RC.Get("r10", "panel2Show"), false)
H.check("an empty column", describe(Own.Columns(20)), "main(GROUP):1,2,3,4 panel2(GROUP):")
H.check("then panel 3", Own.Add(20).id, "panel3")

-- Moving: out of the main panel, between panels, back.
Own.Place(20, "GROUP", "3", "panel2")
H.check("group 3 to panel 2", describe(Own.Columns(20)), "main(GROUP):1,2,4 panel2(GROUP):3 panel3(GROUP):")
Own.Place(20, "GROUP", "1", "panel2")
H.check("appended", RC.Get("r20", "panel2Blocks"), "3,1")
H.check("panel to panel: one change", events(function() Own.Place(20, "GROUP", "3", "panel3") end), 1)
H.check("from panel to panel", describe(Own.Columns(20)), "main(GROUP):2,4 panel2(GROUP):1 panel3(GROUP):3")
Own.Place(20, "GROUP", "1", "main")
H.check("back to the main panel", describe(Own.Columns(20)), "main(GROUP):1,2,4 panel2(GROUP): panel3(GROUP):3")
Own.Place(20, "GROUP", "3", "panel3")
H.check("already there: unchanged", RC.Get("r20", "panel3Blocks"), "3")

-- Another grouping: its blocks show again; taken out, they are nowhere.
Own.SetGrouping(20, ns.Raid.OwnPanel("panel2"), "ROLE")
H.check("grouping set", RC.Get("r20", "panel2GroupBy"), "ROLE")
Own.Place(20, "ROLE", "HEALER", "panel2")
Own.Place(20, "ROLE", "TANK", "panel2")
H.check("roles in panel 2, in role order", describe(Own.Columns(20)), "main(GROUP):1,2,4 panel2(ROLE):TANK,HEALER panel3(GROUP):3")
Own.Place(20, "ROLE", "HEALER", nil)
H.check("taken out", RC.Get("r20", "panel2Blocks"), "TANK")
H.check("what panel 2 may still take", (function()
    local list = {}
    for i, block in ipairs(Own.Addable(20, ns.Raid.OwnPanel("panel2"))) do list[i] = block.id end
    return table.concat(list, ",")
end)(), "HEALER,DAMAGER")
-- A new grouping starts without blocks; the same one keeps them.
Own.SetGrouping(20, ns.Raid.OwnPanel("panel2"), "ROLE")
H.check("same grouping: blocks kept", RC.Get("r20", "panel2Blocks"), "TANK")
H.check("new grouping: one change", events(function()
    Own.SetGrouping(20, ns.Raid.OwnPanel("panel2"), "CLASS")
end), 1)
H.check("new grouping: set", RC.Get("r20", "panel2GroupBy"), "CLASS")
H.check("new grouping: no blocks", RC.Get("r20", "panel2Blocks"), "")
-- Several settings at once: all or none, one change.
H.check("refused: nothing set", RC.SetKeys("r20", { { "panel2Title", "A" }, { "panel2GroupBy", "NOPE" } }), false)
H.check("refused: title untouched", RC.Get("r20", "panel2Title"), "")
-- Its blocks in the main panel's order: the size's class order, not as
-- stored.
RC.Set("r20", "panel2Blocks", "PRIEST,DRUID,MAGE")
RC.Set("r20", "classOrder", "MAGE,DRUID")
H.check("in the class order", describe(Own.Columns(20)):match("panel2%(CLASS%):(%S*)"), "MAGE,DRUID,PRIEST")
RC.Set("r20", "classOrder", "")
H.check("in Blizzard's order", describe(Own.Columns(20)):match("panel2%(CLASS%):(%S*)"), "PRIEST,DRUID,MAGE")
RC.Set("r20", "panel2Blocks", "")

-- Removing: the slot back to its defaults in one change; the main panel
-- gets its blocks back.
RC.Set("r20", "panel3Title", "Groups")
H.check("one change", events(function() Own.Remove(20, ns.Raid.OwnPanel("panel3")) end), 1)
H.check("hidden", RC.Get("r20", "panel3Show"), false)
H.check("its blocks gone", RC.Get("r20", "panel3Blocks"), "")
H.check("its title gone", RC.Get("r20", "panel3Title"), "")
H.check("group 3 back", describe(Own.Columns(20)), "main(GROUP):1,2,3,4 panel2(CLASS):")
H.check("its slot free again", Own.Add(20).id, "panel3")

-- At most nine.
for _ = 1, 7 do Own.Add(20) end
H.check("ten panels", #Own.Columns(20), 10)
H.check("no tenth own panel", Own.Add(20), nil)

-- The edited size only: 10 is untouched, the panels shown at 10 too.
H.check("10 untouched", describe(Own.Columns(10)), "main(GROUP):1,2")
H.check("no error", #M.errors, 0)
