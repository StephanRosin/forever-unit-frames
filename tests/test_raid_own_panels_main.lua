-- The main panel and the own panels (Raid/Header.lua, Raid/OwnPanels.lua):
-- a block an own panel takes in the main panel's grouping leaves the
-- main panel (moved); one of another grouping shows its players again.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Own = ns.RaidConfig, ns.RaidHeader, ns.RaidOwnPanels
ns.Config.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()
Header.Create()

local function member(name, subgroup, class, role)
    return { name = name, class = class, subgroup = subgroup, assignedRole = role }
end
M.SetRaidRoster({ member("A", 1, "WARRIOR", "TANK"), member("B", 1, "PRIEST", "HEALER"), member("C", 2, "MAGE"),
    member("D", 2, "PRIEST", "HEALER") })
M.RunTimers()
local function tokens(P)
    local list = {}
    for i, block in ipairs(P.blocks) do list[i] = tostring(block.id) end
    return table.concat(list, ",")
end
H.check("by default every group in the main panel", tokens(Header), "1,2")
H.check("taken: none", next(Own.Taken(10, "GROUP")), nil)

-- Group 2 to panel 2: it leaves the main panel.
local P = Own.panels.panel2
RC.Set("r10", "panel2Show", true)
RC.Set("r10", "panel2Blocks", "2")
M.RunTimers()
H.check("main: group 1 only", tokens(Header), "1")
H.check("panel 2: group 2", tokens(P), "2")
H.check("taken", Own.Taken(10, "GROUP")["2"], true)
H.check("its header hidden", Header.headers[2]:IsShown(), false)
H.check("the main panel holds one group", Header.Count(1), 2)
H.check("panel 2 the other", P.Count(1), 2)
H.check("the main panel's room: one group", Header.width, 96)

-- A panel that is not shown takes nothing.
RC.Set("r10", "panel2Show", false)
M.RunTimers()
H.check("hidden: both groups back", tokens(Header), "1,2")
RC.Set("r10", "panel2Show", true)

-- Another grouping: the healers show again; the groups stay.
RC.Set("r10", "panel2GroupBy", "ROLE")
RC.Set("r10", "panel2Blocks", "HEALER")
M.RunTimers()
H.check("role panel: groups stay", tokens(Header), "1,2")
H.check("role panel: healers", P.Count(1), 2)
H.check("players shown twice", Header.Count(1) + Header.Count(2), 4)

-- The main panel by class: a class block moves.
RC.Set("r10", "groupBy", "CLASS")
RC.Set("r10", "panel2GroupBy", "CLASS")
RC.Set("r10", "panel2Blocks", "PRIEST")
M.RunTimers()
H.check("no priest block in the main panel", tokens(Header):find("PRIEST", 1, true), nil)
H.check("the warrior's still there", tokens(Header):sub(1, 7), "WARRIOR")
H.check("priests in panel 2", P.Count(1), 2)

-- Two panels of the main grouping each move theirs.
RC.Set("r10", "groupBy", "GROUP")
RC.Set("r10", "panel2GroupBy", "GROUP")
RC.Set("r10", "panel2Blocks", "1")
RC.Set("r10", "panel3Show", true)
RC.Set("r10", "panel3Blocks", "2")
M.RunTimers()
H.check("main panel empty", tokens(Header), "")
H.check("main: no room", Header.width, 0)
H.check("panel 3: group 2", tokens(Own.panels.panel3), "2")

-- An import that puts a block into two panels of the same grouping: the
-- lower-numbered panel keeps it, the other passes it over.
RC.Set("r10", "panel3Blocks", "2,1")
M.RunTimers()
H.check("twice: panel 2 keeps group 1", tokens(P), "1")
H.check("twice: panel 3 passes it over", tokens(Own.panels.panel3), "2")
H.check("twice: one column each", (function()
    local parts = {}
    for _, column in ipairs(Own.Columns(10)) do parts[#parts + 1] = #column.blocks end
    return table.concat(parts, ",")
end)(), "0,1,1")
H.check("twice: the main panel still empty", tokens(Header), "")
RC.Set("r10", "panel2Show", false)
M.RunTimers()
H.check("panel 2 hidden: panel 3 has both", tokens(Own.panels.panel3), "1,2")
RC.Set("r10", "panel2Show", true)
RC.Set("r10", "panel3Blocks", "2")
M.RunTimers()

-- Per size: 20 keeps every group.
RC.Set("general", "sizeMode", "20")
M.RunTimers()
H.check("20: every group", tokens(Header), "1,2,3,4")
RC.Set("general", "sizeMode", "AUTO")
M.RunTimers()
H.check("10 again", tokens(Header), "")

-- A panel's blocks for the size asked, not the one shown.
RC.Set("r20", "panel4Show", true)
RC.Set("r20", "panel4Blocks", "3")
H.check("20's blocks while 10 shows", tokens({ blocks = Own.panels.panel4.spec.blocks(20) }), "3")
H.check("10's: none", #Own.panels.panel4.spec.blocks(10), 0)
H.check("no error", #M.errors, 0)
H.check("nothing blocked", #M.blocked, 0)
