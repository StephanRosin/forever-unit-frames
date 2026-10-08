-- The pets panel (Raid/SpecialPanels.lua): the pet header lists the pets
-- of the size's groups that exist, in combat too, in raid cells of a
-- height of their own (the derived scope raidpet); the cells run the
-- raid cell's parts like any other.
local M = H.M
local ns = H.LoadAddon()
local RC, RS, Cell = ns.RaidConfig, ns.RaidSettings, ns.RaidCell
ns.Config.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()

local CODES = { petsShow = "OS", petsTitle = "OT", petsPerLine = "OL", petsGrowth = "OG", petsX = "OX", petsY = "OY",
    petsCellHeight = "OH" }
for key, code in pairs(CODES) do H.check(key .. " code", RS.Get(key) and RS.Get(key).code, code) end
H.check("off", RC.Get("r10", "petsShow"), false)
H.check("cell height", RC.Get("r40", "petsCellHeight"), 24)
H.check("eight to a row", RC.Get("r40", "petsPerLine") .. RC.Get("r40", "petsGrowth"), "8RIGHT")
H.check("below the main panel", RC.Get("r40", "petsX") .. "," .. RC.Get("r40", "petsY"), "-600,-100")
H.check("its settings", table.concat(ns.Raid.PANELS[5].keys, ","),
    "petsShow,petsTitle,petsPerLine,petsGrowth,petsCellHeight,petsX,petsY")
H.check("the cell height's words", ns.RaidSchema.Label("petsCellHeight"), "Cell height")

-- The pets' cells: a raid cell, its own height.
H.check("pet cell width", ns.Config.Get(Cell.PET_KEY, "width"), 96)
H.check("pet cell height", ns.Config.Get(Cell.PET_KEY, "height"), 24)
H.check("the rest a raid cell's", ns.Config.Get(Cell.PET_KEY, "valueFontSize"), ns.Config.Get(Cell.KEY, "valueFontSize"))
H.checkTrue("a cell", Cell.Is({ key = Cell.PET_KEY }) and Cell.Is({ key = Cell.KEY }))
H.check("not a party frame", Cell.Is({ key = "party" }), false)

ns.RaidHeader.Create()
local P = ns.RaidSpecialPanels.panels.pets
local h = P.headers[1]
H.check("anchor", P.anchor:GetName(), "ForeverUnitFramesRaidPets")
H.check("the pet header", h._template, "SecureGroupPetHeaderTemplate")
H.check("its cells' scope", h.cellKey, Cell.PET_KEY)
H.check("the size's groups", h:GetAttribute("groupFilter"), "1,2")
H.check("off: hidden", h:IsShown(), false)

local function member(name, class, subgroup)
    return { name = name, class = class, subgroup = subgroup, unit = { health = 100, healthMax = 100, powerType = 0 } }
end
M.units.raidpet1 = { name = "Wolf", health = 50, healthMax = 100 }
M.units.raidpet3 = { name = "Imp", health = 80, healthMax = 100 }
M.SetRaidRoster({ member("Hunter", "HUNTER", 1), member("Priest", "PRIEST", 1), member("Lock", "WARLOCK", 2) })
RC.Set("r10", "petsShow", true)
M.RunTimers()
H.checkTrue("on: shown", P.panel:IsShown() and h:IsShown())
H.check("two pets", P.Count(1), 2)
local wolf = h:GetAttribute("child1")
H.check("the hunter's wolf", wolf.unit, "raidpet1")
H.check("the warlock's imp", h:GetAttribute("child2").unit, "raidpet3")
H.check("a pet's cell", wolf.key, Cell.PET_KEY)
H.check("its size", wolf:GetWidth() .. "x" .. wolf:GetHeight(), "96x24")
H.check("the main panel's cells unchanged", ns.RaidHeader.headers[1]:GetAttribute("child1"):GetHeight(), 44)
H.check("the panel", P.width .. "x" .. P.height, (2 * 96 + 2) .. "x" .. (14 + 24))
H.check("title", P.decor[1].title:GetText(), "Pets")
H.checkTrue("the raid cell's parts", wolf.raidAuras and wolf.raidStates and wolf.raidRole)
-- Listed with the cells (more pet cells are made ahead of time, so not
-- necessarily among the last).
local listed = false
for _, b in ipairs(Cell.buttons) do listed = listed or b == wolf end
H.check("listed with the cells", listed, true)
-- Ahead of time: the pets there are and one for each member without a
-- pet out (3 members, 2 pets), each cell without a pet idle.
H.checkTrue("pet cells made ahead", h:GetAttribute("child3") ~= nil and h:GetAttribute("child4") == nil)
H.check("an idle pet cell", h:GetAttribute("child3").raidAuras.container:GetUnit(), "none")

-- Its height, per size.
RC.Set("r10", "petsCellHeight", 30)
H.check("taller", wolf:GetHeight(), 30)
H.check("the panel follows", P.height, 14 + 30)

-- A pet summoned in combat: the header shows it, the panel is tidied
-- after combat.
M.combat = true
M.units.raidpet2 = { name = "Shadowfiend", health = 100, healthMax = 100 }
M.FireEvent("UNIT_PET", "raid2")
H.check("combat: three pets", P.Count(1), 3)
H.check("combat: nothing blocked", #M.blocked, 0)
M.SetCombat(false)
M.RunTimers()
H.check("after combat: room for three", P.width, 3 * 96 + 2 * 2)

-- A group the size does not show: its pets neither.
M.SetRaidRoster({ member("Hunter", "HUNTER", 1), member("Priest", "PRIEST", 1), member("Lock", "WARLOCK", 2),
    member("Far", "HUNTER", 4) })
M.units.raidpet4 = { name = "Cat", health = 100, healthMax = 100 }
RC.Set("general", "sizeMode", "10")
M.RunTimers()
H.check("group 4 at 10: its pet not listed", P.Count(1), 3)
RC.Set("general", "sizeMode", "AUTO")

-- A party with the raid view: your pet and your members'.
M.SetRaidRoster({})
M.units.player = { name = "Me", class = "HUNTER", isPlayer = true }
M.units.pet = { name = "Cat", health = 100, healthMax = 100 }
M.units.party1 = { name = "Ann", class = "WARLOCK", isPlayer = true }
M.units.partypet1 = { name = "Imp", health = 100, healthMax = 100 }
M.SetGroup({ "party1" })
RC.Set("general", "showInParty", true)
M.RunTimers()
H.check("party: your pet first", h:GetAttribute("child1").unit, "pet")
H.check("party: your member's", h:GetAttribute("child2").unit, "partypet1")
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
