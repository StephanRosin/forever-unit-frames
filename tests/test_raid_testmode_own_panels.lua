-- Test mode in the own panels (Raid/TestMode.lua): the pretend raid fills
-- an own panel's blocks exactly as the real ones would, and leaves the
-- main panel's moved blocks; per size, while the panel is shown.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1, isPlayer = true }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RC, Cell, Test = ns.RaidConfig, ns.RaidCell, ns.RaidTestMode
local P = ns.RaidOwnPanels.panels.panel2

local function shown(list)
    local n = 0
    for _, b in ipairs(list or {}) do if b:IsShown() then n = n + 1 end end
    return n
end

ns.RaidOptions.Open(10)
Test.Set(true)
H.check("off: no pretend cells", shown(P.fakes), 0)

-- The healers of the pretend raid, shown again.
RC.Set("r10", "panel2Show", true)
RC.Set("r10", "panel2GroupBy", "ROLE")
RC.Set("r10", "panel2Blocks", "HEALER")
H.check("four healers", shown(P.fakes), 4)
H.check("the main panel keeps its ten", shown(Cell.fakes), 10)
local first = P.fakes[1]
H.check("named as a pretend cell", first:GetName(), "ForeverUnitFramesRaidPanel2Test1")
H.check("a healer", first.sample.assignedRole, "HEALER")
H.check("the first healer of the raid", first.sample.class, "PRIEST")
local _, rel = first:GetPoint(1)
H.check("at the panel", rel, P.anchor)
H.check("its header hidden", P.headers[1]:IsShown(), false)
H.checkTrue("the panel shown", P.panel:IsShown())
H.check("the main panel's cells", first:GetWidth(), 96)
H.checkTrue("listed for the elements", (function()
    for _, b in ipairs(Cell.panelFakes) do if b == first then return true end end
end)())

-- Group 2 moved: five in the panel, five left in the main panel.
RC.Set("r10", "panel2GroupBy", "GROUP")
RC.Set("r10", "panel2Blocks", "2")
H.check("group 2's five", shown(P.fakes), 5)
H.check("the main panel's other five", shown(Cell.fakes), 5)
H.check("from group 2", P.fakes[1].sample.subgroup, 2)

-- Another size in the window: its own panels (none).
ns.RaidOptions.SelectSize(40)
H.check("40: none", shown(P.fakes), 0)
H.check("40: the main panel's forty", shown(Cell.fakes), 40)
ns.RaidOptions.SelectSize(10)
H.check("10 again", shown(P.fakes), 5)

-- Off: every pretend cell goes, the header comes back.
Test.Set(false)
H.check("off: gone", shown(P.fakes), 0)
H.check("off: no sample left", P.fakes[1].sample, nil)
H.checkTrue("off: header back", P.headers[1]:IsShown())
H.check("no error", #M.errors, 0)
