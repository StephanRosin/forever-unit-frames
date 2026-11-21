-- The party targets' and pets' health bar texts are the party's settings
-- (partyTargetText*, partyPetText*): by default as before (targets: name and
-- percent; pets: the name, on the right the party's own right text).
local ns = H.LoadAddon()
local C = ns.Config
C.Use({})
local T, P = ns.PartyTargets.KEY, ns.PartyPets.KEY

H.check("target left: name", C.Get(T, "textHealthLeft"), "NAME")
H.check("target right: percent", C.Get(T, "textHealthRight"), "PERCENT")
H.check("pet left: name", C.Get(P, "textHealthLeft"), "NAME")
C.Set("party", "textHealthRight", "DEFICIT")
H.check("pet right: the party's", C.Get(P, "textHealthRight"), "DEFICIT")

C.Set("party", "partyTargetTextLeft", "NAME_LEVEL")
C.Set("party", "partyTargetTextRight", "CURRENT")
H.check("target left set", C.Get(T, "textHealthLeft"), "NAME_LEVEL")
H.check("target right set", C.Get(T, "textHealthRight"), "CURRENT")
C.Set("party", "partyPetTextLeft", "NONE")
C.Set("party", "partyPetTextRight", "PERCENT")
H.check("pet left set", C.Get(P, "textHealthLeft"), "NONE")
H.check("pet right: its own", C.Get(P, "textHealthRight"), "PERCENT")
C.Set("party", "partyPetTextRight", "PARTY")
H.check("pet right: the party's again", C.Get(P, "textHealthRight"), "DEFICIT")
