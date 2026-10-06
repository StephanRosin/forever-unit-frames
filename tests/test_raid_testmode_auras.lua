-- Raid test mode's debuffs and corner indicators (Raid/CellAuras.lua,
-- Raid/Indicators.lua): pretend cells have no aura container, so each
-- draws its pretend member's sample with plain frames, following the
-- raid profile like the live cells.
local M = H.M
local ns = H.LoadAddon()
local RC, Cell, Test, CellAuras = ns.RaidConfig, ns.RaidCell, ns.RaidTestMode, ns.RaidAuras
M.units.player = { name = "Me", class = "MAGE", className = "Mage", isPlayer = true, level = 60,
    health = 100, healthMax = 100, healthMissing = 0, power = 50, powerMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()

-- The pretend members' debuffs.
local members = Test.Members(20)
H.check("member 2: magic and a curse", table.concat(members[2].debuffs, ","), "1,2")
H.check("member 12 like member 2", table.concat(members[12].debuffs, ","), "1,2")
H.check("member 1: none", #members[1].debuffs, 0)
local centre, rest = CellAuras.SampleDebuffs(members[9])
H.check("centre: the first with a type", centre.dispel, "Disease")
H.check("the rest", #rest, 2)

ns.TestMode.Set(true)
local f1, f2, f3, f9 = Cell.fakes[1], Cell.fakes[2], Cell.fakes[3], Cell.fakes[9]
local s2 = f2.raidAuras.samples
H.check("no container", f2.raidAuras.container, nil)
H.checkTrue("centre icon shown", s2.icon:IsShown())
H.check("centre: magic", s2.icon.border._color[3], 1.0)
H.check("centre: the 10 profile's size", s2.icon:GetWidth(), 20)
local p, rel = s2.icon:GetPoint(1)
H.checkTrue("centre of the health bar", p == "CENTER" and rel == f2.health)
H.check("member 1: no icon", f1.raidAuras.samples.icon:IsShown(), false)
H.check("tint off by default", s2.tint:IsShown(), false)
H.check("row off by default", s2.row[1]:IsShown(), false)
H.check("no indicators without spells", s2.indicators[1]:IsShown(), false)
local onFakes = 0
for _, container in ipairs(M.auraContainers) do
    if container:GetParent().pretend then onFakes = onFakes + 1 end
end
H.check("no container on any pretend cell", onFakes, 0)

-- Settings show at once.
RC.Set("r10", "dispelTint", true)
H.checkTrue("tint shown", s2.tint:IsShown())
H.check("tint: magic, light", s2.tint.texture._color[4], CellAuras.TINT_ALPHA)
RC.Set("r10", "debuffRow", true)
H.checkTrue("row: the magic one", s2.row[1]:IsShown())
H.check("row: every debuff, the centre's too", s2.row[1].border._color[3], 1.0)
H.checkTrue("row: the curse", s2.row[2]:IsShown())
H.check("row: no more", s2.row[3]:IsShown(), false)
H.check("row: the 10 profile's size", s2.row[1]:GetWidth(), 14)
local s9 = f9.raidAuras.samples
local shown9 = 0
for i = 1, 3 do shown9 = shown9 + (s9.row[i]:IsShown() and 1 or 0) end
H.check("member 9: three in the row", shown9, 3)
RC.Set("r10", "debuffCount", 1)
H.check("count 1: one", s9.row[2]:IsShown(), false)
RC.Set("r10", "dispelIcon", false)
H.check("no centre icon", s2.icon:IsShown(), false)
H.checkTrue("the row stays", s2.row[1]:IsShown())
H.check("row starts with the magic one", s2.row[1].border._color[3], 1.0)
RC.ResetScope("r10")

-- Indicators with spells: on the living.
RC.Set("r10", "indicatorTopLeftSpells", "139")
local ind = f1.raidAuras.samples.indicators[1]
H.checkTrue("top left shown", ind:IsShown())
H.check("green", ind.color._color[2], 0.9)
H.check("size", ind:GetWidth(), 8)
p, rel = ind:GetPoint(1)
H.checkTrue("in the corner", p == "TOPLEFT" and rel == f1)
H.checkTrue("swipe running", ind.cooldown._cooldown ~= nil)
H.check("dead member: none", f3.raidAuras.samples.indicators[1]:IsShown(), false)
RC.Set("r10", "indicatorTopLeftTime", "NUMBER")
H.check("number", ind.time:GetText(), "12")
H.check("no other position", f1.raidAuras.samples.indicators[2]:IsShown(), false)
RC.ResetScope("r10")
H.check("reset: gone", ind:IsShown(), false)

-- Test mode off: everything hidden.
RC.Set("r10", "debuffRow", true)
ns.TestMode.Set(false)
H.check("off: icon hidden", s2.icon:IsShown(), false)
H.check("off: row hidden", s2.row[1]:IsShown(), false)
H.check("off: sample gone", f2.raidAuras.previewing, nil)
H.check("no errors", #M.errors, 0)
