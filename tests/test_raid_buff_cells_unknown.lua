-- The missing-buff icon (Raid/BuffCells.lua) of a cell whose member the
-- client gives no plain GUID: in combat, once the roster changed (the
-- last state may name another member by that unit), it hides rather than
-- keep a state that may belong to someone else.
local M = H.M
local ns = H.LoadAddon()
local RC, Cell = ns.RaidConfig, ns.RaidCell
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
RC.Set("general", "buffCellIcon", true)
M.Tick(1)
local function cellOf(unit)
    for _, b in ipairs(Cell.buttons) do if b.unit == unit then return b end end
end
local function shown(cell) return cell.buffIcon ~= nil and cell.buffIcon.icon:IsShown() end
H.check("no GUIDs: B misses it (by unit)", shown(cellOf("raid2")), true)
H.check("A has it", shown(cellOf("raid1")), false)

-- In combat the roster changes: raid2 is A now, raid1 B; no GUID says who.
M.FireEvent("PLAYER_REGEN_DISABLED")
M.SetCombat(true)
M.SetRaidRoster({
    { name = "B", class = "MAGE", subgroup = 1, unit = { auras = {} } },
    { name = "A", class = "MAGE", subgroup = 1, unit = { auras = { fort } } },
})
M.Tick(1)
H.check("combat, unknown: raid2's icon hides", shown(cellOf("raid2")), false)
H.check("combat, unknown: raid1 shows none", shown(cellOf("raid1")), false)
H.check("combat: nothing blocked", #M.blocked, 0)
-- After combat a new scan knows again.
M.SetCombat(false)
M.Tick(1)
M.RunTimers()
M.Tick(1)
H.check("after combat: B's cell shows it", shown(cellOf("raid1")), true)
H.check("after combat: A's none", shown(cellOf("raid2")), false)
H.check("no error", #M.errors, 0)
