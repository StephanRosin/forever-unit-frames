-- What raid cells never get, live or pretend: the unit-frame elements
-- that belong to other frames build nothing on them, and those every
-- frame builds stay hidden under the cell's fixed settings
-- (Raid/Cell.lua). Their own auras, icons and lines are tested elsewhere.
local M = H.M
local ns = H.LoadAddon()
local Header, Cell = ns.RaidHeader, ns.RaidCell
M.units.player = { name = "Me", class = "SHAMAN", className = "Shaman", isPlayer = true, level = 60,
    health = 100, healthMax = 100, powerType = 0, power = 10, powerMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.SetRaidRoster({ { name = "Ann", class = "DRUID", subgroup = 1,
    unit = { threat = 3, combat = true, pvp = true, incomingRez = true, powerType = 0, power = 10, powerMax = 100 } } })
M.RunTimers()
ns.RaidTestMode.Set(true)

local NEVER = { "castbar", "dispel", "targetHighlight", "threatBar", "combo", "totems", "statusIcons",
    "petHappiness", "unitIcons", "eliteLayer", "powerCost", "druidMana" }
local live = Header.headers[1]:GetAttribute("child1")
for label, cell in pairs({ live = live, pretend = Cell.fakes[1] }) do
    for _, field in ipairs(NEVER) do
        H.check(label .. ": no " .. field, cell[field], nil)
    end
    H.check(label .. ": no unit-frame aura containers", next(cell.auraContainers or {}), nil)
    H.check(label .. ": threat glow hidden", cell.threat.frame:IsShown(), false)
    H.check(label .. ": threat glow (block) hidden", cell.threat.block:IsShown(), false)
    H.check(label .. ": no class icon", cell.classIcon:IsShown() or cell.classRing:IsShown(), false)
    H.check(label .. ": no portrait", cell.portrait2D:IsShown() or cell.portrait3D:IsShown(), false)
    H.check(label .. ": no title row", cell.title:IsShown(), false)
    H.check(label .. ": no resurrection icon", cell.groupIcons.rez:IsShown(), false)
    H.check(label .. ": not a single frame", ns.Frames[cell.key], nil)
end
ns.RaidTestMode.Set(false)
-- Live: no combat numbers either.
M.FireEvent("UNIT_COMBAT", "raid1", "WOUND", nil, 500, 1)
H.check("live: no combat numbers", live.feedback:IsShown(), false)
H.check("no errors", #M.errors, 0)
