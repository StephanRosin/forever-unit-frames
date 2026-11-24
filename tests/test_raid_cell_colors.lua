-- The raid cell's heal, shield, missing-health and power colours
-- (Raid/Settings.lua, Raid/Cell.lua): per raid size, defaulting to the
-- unit frames' own defaults (the colours cells always had); the party
-- frame's settings do not count.
local ns = H.LoadAddon()
local RC, C, RS, S = ns.RaidConfig, ns.Config, ns.RaidSettings, ns.Settings
C.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()

local KEYS = { "healMyColor", "healOtherColor", "absorbColor", "healthMissingCustom", "healthMissingColor",
    "powerColorMode", "powerColorMana", "powerColorRage", "powerColorEnergy", "powerColorFocus" }
local function text(v)
    if type(v) == "table" then return table.concat(v, " ") end
    return tostring(v)
end

for _, key in ipairs(KEYS) do
    local unitDefault = text(S.Get(key).default)
    H.check(key .. ": default as before", text(RS.Default(RS.Get(key), "r10")), unitDefault)
    H.check(key .. ": the cell shows it", text(C.Get("raid", key)), unitDefault)
end

-- The party frame's colour does not reach the cells.
C.Set("party", "powerColorMana", { 0, 0, 0, 1 })
H.check("party's mana: not the cell's", text(C.Get("raid", "powerColorMana")), "0.25 0.5 1 1")

-- Set per size: the shown size's value reaches the cell.
RC.Set("r10", "powerColorMana", { 0.1, 0.2, 0.3, 1 })
RC.Set("r10", "healMyColor", { 0.9, 0.1, 0.1, 0.5 })
RC.Set("r10", "powerColorMode", "CLASS")
RC.Set("r10", "healthMissingCustom", true)
H.check("mana per size", text(C.Get("raid", "powerColorMana")), "0.1 0.2 0.3 1")
H.check("own heals per size", text(C.Get("raid", "healMyColor")), "0.9 0.1 0.1 0.5")
H.check("power mode per size", C.Get("raid", "powerColorMode"), "CLASS")
H.check("missing health switch per size", C.Get("raid", "healthMissingCustom"), true)
H.check("another size keeps its own", text(RC.Get("r20", "powerColorMana")), "0.25 0.5 1 1")

-- Test mode: each pretend cell shows its sample's power type and class,
-- not yours (every pretend cell sits on the player, a mage here).
local M = H.M
M.units.player = { name = "Me", class = "MAGE", className = "Mage", isPlayer = true, level = 60,
    health = 100, healthMax = 100, healthMissing = 0, power = 50, powerMax = 100, powerType = 0 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local Cell = ns.RaidCell
RC.Set("r10", "powerStrip", "ALL")
RC.Set("r10", "powerColorMode", "TYPE")
RC.Set("r10", "powerColorRage", { 0.5, 0, 0, 1 })
RC.Set("r10", "powerColorEnergy", { 0, 0.5, 0, 1 })
RC.Set("r10", "powerColorMana", { 0.1, 0.2, 0.3, 1 })
ns.RaidTestMode.Set(true)
local function strip(i)
    local c = Cell.fakes[i].power._color
    return table.concat({ c[1], c[2], c[3] }, " ")
end
H.check("test: warrior's rage", strip(1), "0.5 0 0")
H.check("test: priest's mana", strip(2), "0.1 0.2 0.3")
H.check("test: rogue's energy", strip(4), "0 0.5 0")
RC.Set("r10", "powerColorMode", "CLASS")
local wr, wg, wb = ns.Health.ClassTokenColor("WARRIOR")
H.check("test, by class: the warrior's colour", strip(1), table.concat({ wr, wg, wb }, " "))
local lr, lg, lb = ns.Health.ClassTokenColor("WARLOCK")
H.check("test, by class: the warlock's colour", strip(8), table.concat({ lr, lg, lb }, " "))
ns.RaidTestMode.Set(false)
H.check("the pets' sample: a hunter's pet has focus", ns.RaidTestMode.PanelMembers("pets", 10)[1].powerType, 2)
