-- Test mode in the special panels (Raid/TestMode.lua): pretend main
-- tanks, main assists, your tanks and favourites, in their panels' order,
-- and pretend pets in pet cells, each panel while it is switched on; the
-- main panel's pretend raid as before. Off again, every pretend cell goes.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1, isPlayer = true }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RC, Cell, Test, Special = ns.RaidConfig, ns.RaidCell, ns.RaidTestMode, ns.RaidSpecialPanels
local P = Special.panels

H.check("pretend main tanks", table.concat(Test.PANELS.mainTanks, ","), "1,10")
local pets = Test.PanelMembers("pets", 10)
H.check("a pet per hunter and warlock", #pets, 2)
H.check("the hunter's", pets[1].name, "Wolf")
H.check("the warlock's", pets[2].name .. pets[2].class, "ImpWARLOCK")
H.check("40: eight pets", #Test.PanelMembers("pets", 40), 8)
H.check("your tanks, last first", Test.PanelMembers("myTanks", 10)[1].class, "WARRIOR")

local function shown(list)
    local n = 0
    for _, b in ipairs(list or {}) do if b:IsShown() then n = n + 1 end end
    return n
end

-- Solo, the raid window's test mode: the main tanks panel (on by
-- default) shows two.
ns.RaidOptions.Open(10)
Test.Set(true)
H.check("the main panel's ten", shown(Cell.fakes), 10)
H.check("two main tanks", shown(P.mainTanks.fakes), 2)
H.check("their header hidden", P.mainTanks.headers[1]:IsShown(), false)
H.checkTrue("the panel shown", P.mainTanks.panel:IsShown())
H.check("room for two", P.mainTanks.width, 2 * 96 + 2)
local first = P.mainTanks.fakes[1]
H.check("named as a pretend cell", first:GetName(), "ForeverUnitFramesRaidMainTanksTest1")
H.check("the first tank", first.sample.assignedRole .. first.sample.subgroup, "TANK1")
local _, rel = first:GetPoint(1)
H.check("at the panel", rel, P.mainTanks.anchor)
H.check("listed for the elements", Cell.panelFakes[1], first)
H.check("main assists off: none", shown(P.mainAssists.fakes), 0)

-- Switched on, each shows its own.
RC.Set("r10", "mainAssistsShow", true)
H.check("a main assist", shown(P.mainAssists.fakes), 1)
H.check("the paladin", P.mainAssists.fakes[1].sample.class, "PALADIN")
RC.Set("r10", "myTanksShow", true)
H.check("your tanks", shown(P.myTanks.fakes), 2)
H.check("in their order", P.myTanks.fakes[1].sample.assignedRole .. P.myTanks.fakes[1].sample.subgroup, "DAMAGER2")
RC.Set("r10", "favouritesShow", true)
H.check("your favourites", P.favourites.fakes[1].sample.class .. "," .. P.favourites.fakes[2].sample.class,
    "PRIEST,DRUID")
RC.Set("r10", "petsShow", true)
H.check("two pets", shown(P.pets.fakes), 2)
local wolf = P.pets.fakes[1]
H.check("a pet's cell", wolf.key, Cell.PET_KEY)
H.check("its height", wolf:GetHeight(), 24)
H.check("its name", wolf.texts.healthLeft:GetText(), "Wolf")
RC.Set("r10", "petsShow", false)
H.check("pets off: gone", shown(P.pets.fakes), 0)

-- Another size in the raid window: its pretend raid.
ns.RaidOptions.SelectSize(40)
H.check("40: the main panel's forty", shown(Cell.fakes), 40)
H.check("40: still two main tanks", shown(P.mainTanks.fakes), 2)
ns.RaidOptions.SelectSize(10)

-- Off: every pretend cell goes; the headers come back.
Test.Set(false)
H.check("off: main panel's gone", shown(Cell.fakes), 0)
H.check("off: special ones gone", shown(Cell.panelFakes), 0)
H.check("off: no sample left", P.mainTanks.fakes[1].sample, nil)
H.checkTrue("off: header back", P.mainTanks.headers[1]:IsShown())
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
