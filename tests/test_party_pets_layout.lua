-- Party pets: own width, spacing, and the BESIDE layout (each pet a child
-- of its member's button, like the party targets). Aura border thickness.
local M = H.M
local ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, S = ns.Config, ns.Settings
local P, Pets = ns.Party, ns.PartyPets
local pets = Pets.header
M.units.player = { name = "Me", level = 60, health = 5, healthMax = 10 }

-- Settings -----------------------------------------------------------------------
for key, code in pairs({ partyPetLayout = "PL", partyPetSide = "PB", partyPetWidth = "PW", partyPetGap = "PG",
    auraBorderSize = "AW" }) do
    H.check("code of " .. key, S.Get(key).code, code)
end
H.check("list by default", C.Get("party", "partyPetLayout"), "LIST")
H.check("members' width by default", C.Get("party", "partyPetWidth"), 0)
H.check("gap 2 by default", C.Get("party", "partyPetGap"), 2)

-- Width and gap in the list ------------------------------------------------------
C.Set("party", "partyShowPets", true)
H.check("pet as wide as a member", ns.Single.Size("partypet"), ns.Single.Size("party"))
C.Set("party", "partyPetWidth", 90)
H.check("own width", ns.Single.Size("partypet"), 90)
C.Set("party", "partyPetGap", 6)
H.check("gap between pets (rings 1 each)", pets:GetAttribute("yOffset"), -(6 + 1 + 1))
-- In a row, narrower pets still start under their owners.
C.Set("party", "partyOrientation", "HORIZONTAL")
local memberW = ns.Single.Size("party")
H.check("row: step = member width + spacing", 90 + pets:GetAttribute("xOffset"), memberW + P.Spacing())
C.Set("party", "partyOrientation", "VERTICAL")
C.Set("party", "partyPetGap", 2)

-- BESIDE ---------------------------------------------------------------------------
M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
M.units.party2 = { name = "Bob", health = 5, healthMax = 10 }
M.units.partypet2 = { name = "Wolf", health = 3, healthMax = 4 }
M.SetGroup({ "party1", "party2" })
local m1, m2 = P.header:GetAttribute("child1"), P.header:GetAttribute("child2")
local b1, b2 = m1.petButton, m2.petButton
H.checkTrue("every member has a pet child", b1 and b2)
H.check("its unit: the member's pet", b2.unit, "partypet2")
H.check("unit suffix for the secure side", b2:GetAttribute("unitsuffix"), "pet")
H.check("player's pet maps to pet", Pets.PetUnit("player"), "pet")
H.check("list: no unit watch", b2._unitWatch, nil)

C.Set("party", "partyPetLayout", "BESIDE")
H.check("beside: the list header hides", pets:IsShown(), false)
H.checkTrue("beside: unit watch on", b2._unitWatch)
local point, rel, relPoint, x, y = b2:GetPoint(1)
H.check("right of the owner", point .. ">" .. relPoint, "TOPLEFT>TOPRIGHT")
H.check("on its owner", rel, m2)
-- Ring, gap 2, ring.
H.check("ring to ring", x, 1 + 2 + 1)
H.check("top edges level", y, 0)
H.check("own width beside", b2:GetWidth(), 90)
C.Set("party", "partyPetSide", "LEFT")
point, rel, relPoint, x = b2:GetPoint(1)
H.check("left of the owner", point .. ">" .. relPoint, "TOPRIGHT>TOPLEFT")
H.check("left: negative", x, -(1 + 2 + 1))
C.Set("party", "partyPetsX", 5)
C.Set("party", "partyPetsY", -3)
_, _, _, x, y = b2:GetPoint(1)
H.check("offset X moves it", x, -(1 + 2 + 1) + 5)
H.check("offset Y moves it", y, -3)
C.Set("party", "partyPetsX", 0)
C.Set("party", "partyPetsY", 0)
C.Set("party", "partyPetSide", "RIGHT")
-- Pets off: no watch.
C.Set("party", "partyShowPets", false)
H.check("pets off: no watch", b2._unitWatch, nil)
H.check("pets off: hidden", b2:IsShown(), false)
C.Set("party", "partyShowPets", true)

-- Test mode: pretend pets beside the pretend members.
M.SetGroup({})
ns.TestMode.Set(true)
local fake, member = Pets.fakes[1], P.fakes[1]
point, rel, relPoint = fake:GetPoint(1)
H.check("test: beside its pretend member", rel, member)
H.check("test: right of it", relPoint, "TOPRIGHT")
H.check("test: live children not watched", b2._unitWatch, nil)
ns.TestMode.Set(false)
C.Set("party", "partyPetLayout", "LIST")
H.check("list again: header back", pets:IsShown() or not ns.Party.header:IsShown(), true)

-- Aura border thickness ------------------------------------------------------------
M.units.target = { name = "Foe", health = 5, healthMax = 10 }
local button = ns.AuraButton.Create(UIParent, false)
ns.AuraButton.Style(button, "target", 20, true)
local _, _, _, inset = button.icon:GetPoint(1)
H.check("1 pixel by default", inset, 1)
C.Set("general", "auraBorderSize", 3)
ns.AuraButton.Style(button, "target", 20, true)
_, _, _, inset = button.icon:GetPoint(1)
H.check("3 pixels", inset, 3)
C.Set("general", "auraBorder", false)
ns.AuraButton.Style(button, "target", 20, true)
_, _, _, inset = button.icon:GetPoint(1)
H.check("border off: no inset", inset, 0)
