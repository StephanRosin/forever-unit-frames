local M = H.M
local ns = H.LoadAddon()
local S = ns.Settings

-- Every frame has a scope; the codec prefixes cover them all.
for _, scope in ipairs({ "targettarget", "pet", "focus", "party" }) do
    local found = false
    for _, s in ipairs(S.SCOPES) do if s == scope then found = true end end
    H.checkTrue("scope listed " .. scope, found)
    H.checkTrue("codec prefix " .. scope, S.PREFIX[scope])
end

-- def.only limits a frame setting to some frames.
local partyOnly = { scope = "frame", only = { party = true } }
H.checkTrue("only: applies to party", S.AppliesTo(partyOnly, "party"))
H.check("only: not player", S.AppliesTo(partyOnly, "player"), false)
H.check("only: not general", S.AppliesTo(partyOnly, "general"), false)
H.check("general-only never on frames", S.AppliesTo({ scope = "general" }, "pet"), false)

ns.Config.Use({})
H.check("tot width", ns.Config.Get("targettarget", "width"), 120)
H.check("pet height", ns.Config.Get("pet", "height"), 28)
H.check("tot x", ns.Config.Get("targettarget", "x"), 480)
H.check("pet y", ns.Config.Get("pet", "y"), -272)
H.checkTrue("new scope in profile", ns.Config.Profile().pet)
H.checkTrue("set on new scope", ns.Config.Set("pet", "width", 150))
H.check("codec round trip", ns.Codec.Encode(ns.Config.Profile()), "1;eW150")
H.check("codec decode", ns.Codec.Decode("1;eW150").pet.width, 150)

-- Frames ---------------------------------------------------------------------
ns.Single.CreateAll()
local tot, pet = ns.Frames.targettarget, ns.Frames.pet
H.checkTrue("tot built", tot)
H.checkTrue("pet built", pet)
H.check("tot unit", tot:GetAttribute("unit"), "targettarget")
H.check("pet unit", pet:GetAttribute("unit"), "pet")
H.check("tot secure", tot._template, "SecureUnitButtonTemplate")
H.checkTrue("tot unit watch", tot._unitWatch)
H.check("tot name", tot:GetName(), "ForeverUnitFrames_targettarget")

-- Target of target: refreshed when the target changes its target ...
M.units.targettarget = { name = "Tank", health = 4, healthMax = 10 }
M.FireEvent("UNIT_TARGET", "target")
H.check("tot refreshed on the target's UNIT_TARGET", tot.health:GetValue(), 4)
M.units.targettarget.health = 5
M.FireEvent("UNIT_TARGET", "party2")
H.check("tot ignores other units' UNIT_TARGET", tot.health:GetValue(), 4)
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("tot refreshed on a new target", tot.health:GetValue(), 5)
-- ... and on a timer, since targettarget has no unit events.
M.units.targettarget.health = 6
M.Tick(0.1)
H.check("tot not polled before the interval", tot.health:GetValue(), 5)
M.Tick(0.15)
H.check("tot polled after the interval", tot.health:GetValue(), 6)
tot:Hide()
M.units.targettarget.health = 7
M.Tick(0.25)
H.check("hidden tot not polled", tot.health:GetValue(), 6)
tot:Show()

-- Pet: refreshed when the player's pet changes, with its own unit events.
M.units.pet = { name = "Imp", health = 3, healthMax = 9 }
M.FireEvent("UNIT_PET", "player")
H.check("pet refreshed on UNIT_PET player", pet.health:GetValue(), 3)
M.units.pet.health = 2
M.FireEvent("UNIT_PET", "party1")
H.check("pet ignores a party member's pet", pet.health:GetValue(), 3)
M.FireEvent("UNIT_HEALTH", "pet")
H.check("pet unit events", pet.health:GetValue(), 2)
