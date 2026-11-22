-- Own class colours and pet colours by kind (CurseForge wish): off, as
-- before (Blizzard's class colours, pets in the reaction colour); on,
-- every class colour reader takes the player's.
local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
local C, Health = ns.Config, ns.Health
M.units.player = { name = "Me", class = "WARLOCK", isPlayer = true, health = 9, healthMax = 10 }
M.units.pet = { name = "Pet", health = 9, healthMax = 10, playerControlled = true, family = 16 }
local PURPLE = { 0.3, 0.1, 0.5, 1 }

-- Off: Blizzard's.
H.check("off: Blizzard's", select(3, Health.ClassTokenColor("WARLOCK")), RAID_CLASS_COLORS.WARLOCK.b)
H.check("starts at Blizzard's colour", C.Get("general", "classColorWARLOCK")[3], RAID_CLASS_COLORS.WARLOCK.b)
H.check("off: pets have none", Health.PetColor("pet"), nil)
H.check("off: a pet keeps the reaction colour", select(2, Health.UnitColor("pet", "CLASS", "pet")),
    Health.ReactionColor("pet", "pet")[2])

-- On: the player's, for a unit and a bare token (texts, raid names).
C.Set("general", "classColorsCustom", true)
C.Set("general", "classColorWARLOCK", PURPLE)
H.check("on: a player", select(3, Health.ClassColor("player")), 0.5)
H.check("on: by token", Health.ClassTokenColor("WARLOCK"), 0.3)
H.check("unknown class: nothing", Health.ClassTokenColor("MONK"), nil)

-- Pets by family ID.
C.Set("general", "petColorsCustom", true)
H.check("voidwalker", select(3, Health.PetColor("pet")), C.Get("general", "petColorVoidwalker")[3])
M.units.pet.family = 23
H.check("imp", Health.PetColor("pet"), C.Get("general", "petColorImp")[1])
M.units.pet.family = 1
H.check("a beast: the hunter pet's", Health.PetColor("pet"), C.Get("general", "petColorHunter")[1])
H.check("in the health colour", Health.UnitColor("pet", "CLASS", "pet"), C.Get("general", "petColorHunter")[1])
M.units.pet.family = 29
H.check("felguard", Health.PetColor("pet"), C.Get("general", "petColorFelguard")[1])
M.units.pet.family = 302
H.check("incubus: its own", Health.PetColor("pet"), C.Get("general", "petColorIncubus")[1])
M.units.pet.family = 101
H.check("voidlord: the voidwalker's", Health.PetColor("pet"), C.Get("general", "petColorVoidwalker")[1])
M.units.pet.family = nil
H.check("no family: none", Health.PetColor("pet"), nil)
M.units.target = { name = "Wolf", health = 1, healthMax = 1, family = 1 }
H.check("a wild beast is no pet", Health.PetColor("target"), nil)

-- A frame takes a changed colour at once.
ns.Single.CreateAll()
local p = ns.Frames.player
C.Set("player", "healthColorMode", "CLASS")
C.Set("general", "classColorWARLOCK", { 0.2, 0.2, 0.2, 1 })
H.check("the bar at once", p.health._color[1], 0.2)
