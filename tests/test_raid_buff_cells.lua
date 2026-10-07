-- The missing-buff icon on the cells (Raid/BuffCells.lua): off by default;
-- on, a cell whose member misses a watched buff shows that buff's icon at
-- the chosen point, at the profile's icon size. Changed out of combat
-- only; in combat it keeps its last state.
local M = H.M
local ns = H.LoadAddon()
local RC, Cell, Cells, Watch = ns.RaidConfig, ns.RaidCell, ns.RaidBuffCells, ns.RaidBuffWatch
ns.Config.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()
ns.RaidHeader.Create()
M.units.player = { name = "Me", class = "PRIEST", className = "Priest", isPlayer = true, auras = {} }
M.known[1243] = true

local fort = { name = "Power Word: Fortitude", spellId = 1243, isHelpful = true, expirationTime = M.now + 1700 }
M.SetRaidRoster({
    { name = "A", class = "MAGE", subgroup = 1, unit = { auras = { fort } } },
    { name = "B", class = "MAGE", subgroup = 1, unit = { auras = {} } },
})
M.RunTimers()
M.Tick(1)
local function cellOf(unit)
    for _, b in ipairs(Cell.buttons) do if b.unit == unit then return b end end
end
local a, b = cellOf("raid1"), cellOf("raid2")
H.checkTrue("cells", a and b)
local function shown(cell) return cell.buffIcon ~= nil and cell.buffIcon.icon:IsShown() end
H.check("off by default: nothing", shown(b), false)

RC.Set("general", "buffCellIcon", true)
M.Tick(1)
H.check("B misses fortitude: icon", shown(b), true)
H.check("A has it: none", shown(a), false)
H.check("the buff's icon", b.buffIcon.icon._texture, 100000 + 1243)
local p, rel, relPoint, x, y = b.buffIcon.icon:GetPoint(1)
H.check("at its point, just inside", table.concat({ p, tostring(rel == b), relPoint, x, y }, " "),
    "BOTTOMLEFT true BOTTOMLEFT 1 1")
H.check("the profile's icon size", b.buffIcon.icon:GetWidth(), Cell.Get("iconSize"))
H.check("above the bars", b.buffIcon:GetFrameLevel() > b:GetFrameLevel(), true)
RC.Set("general", "buffCellIconPoint", "TOPRIGHT")
p = b.buffIcon.icon:GetPoint(1)
H.check("moved", p, "TOPRIGHT")

-- In combat: kept as it was; after combat it follows.
M.FireEvent("PLAYER_REGEN_DISABLED")
M.SetCombat(true)
M.units.raid2.auras = { fort }
M.FireEvent("UNIT_AURA", "raid2")
M.Tick(1)
RC.Set("general", "buffCellIconPoint", "TOPLEFT")
H.check("combat: kept", shown(b), true)
H.check("combat: not moved", (b.buffIcon.icon:GetPoint(1)), "TOPRIGHT")
M.SetCombat(false)
M.Tick(1)
H.check("after combat: gone", shown(b), false)

-- Unknown (secret auras): no icon, never a guess.
M.units.raid2.auras = {}
M.aurasSecret = true
Watch.Scan()
H.check("unknown: none", shown(b), false)
M.aurasSecret = false
Watch.Scan()
H.check("known again", shown(b), true)
-- Switched off: gone.
RC.Set("general", "buffCellIcon", false)
H.check("off: gone", shown(b), false)
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
