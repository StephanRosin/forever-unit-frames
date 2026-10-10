-- Another raid size with its own power strip height and debuff border:
-- switched in combat, strip and ring keep their look until combat ends,
-- then follow the new size's profile.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Pixel = ns.RaidConfig, ns.RaidHeader, ns.Pixel
M.units.player = { name = "Me", class = "PRIEST", isPlayer = true, health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
RC.Set("general", "sizeMode", "10")
M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1, assignedRole = "HEALER",
    unit = { health = 60, healthMax = 100, powerType = 0 } } })
M.RunTimers()
local cell = Header.headers[1]:GetAttribute("child1")
local c = cell.raidAuras.container

RC.Set("r10", "dispelBorder", true)
RC.Set("r10", "cellCornerRadius", 0)
RC.Set("r20", "powerStripHeight", 30)
RC.Set("r20", "dispelBorder", true)
RC.Set("r20", "dispelBorderSize", 4)
RC.Set("r20", "cellCornerRadius", 0)
local slot = c._slots.border
local top = ns.Border.InnerRingPieces(slot.frame.ring)[1]
local function stripShare()
    return rawget(cell.power, "_h") / (rawget(cell.power, "_h") + rawget(cell.health, "_h"))
end
local before, ring = stripShare(), rawget(top, "_h")
H.check("10: the default border", ring, Pixel.Snap(2, nil, 1))
H.checkTrue("10: a tenth for the strip", before < 0.15)

M.combat = true
RC.Set("general", "sizeMode", "20")
M.RunTimers()
H.check("combat: strip kept", stripShare(), before)
H.check("combat: ring kept", rawget(top, "_h"), ring)
M.SetCombat(false)
M.RunTimers()
H.check("after combat: 20's ring", rawget(top, "_h"), Pixel.Snap(4, nil, 1))
H.check("after combat: border on", slot.enabled, true)
H.checkTrue("after combat: 20's strip", stripShare() > 0.25)

-- Back out of combat, a size with the border off.
RC.Set("r20", "dispelBorder", false)
H.check("20 without border", slot.enabled, false)
RC.Set("general", "sizeMode", "10")
M.RunTimers()
H.check("10 again: border on", slot.enabled, true)
H.check("10 again: its ring", rawget(top, "_h"), Pixel.Snap(2, nil, 1))
H.checkTrue("10 again: its strip", stripShare() < 0.15)
H.check("nothing blocked", #M.blocked, 0)
H.check("no errors", #M.errors, 0)
