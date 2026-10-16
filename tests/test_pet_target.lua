-- The pet's target frame: a single frame like the target of target, off
-- by default, with a castbar and the pet's threat on its target; the pet
-- frame gets a castbar of its own (off by default).
local M = H.M

local function boot()
    local ns = H.LoadAddon()
    M.units.player = { name = "Me", class = "HUNTER", className = "HUNTER", isPlayer = true, health = 1, healthMax = 1 }
    M.units.pet = { name = "Wolf", health = 5, healthMax = 10 }
    _G.ForeverUnitFramesDB = nil
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    return ns
end

do
    local ns = boot()
    local S, C = ns.Settings, ns.Config
    local frame = ns.Frames.pettarget
    H.checkTrue("frame made", frame)
    H.check("unit", frame.unit, "pettarget")
    H.check("off by default", S.Default(S.Get("enabled"), "pettarget"), false)
    H.check("other frames stay on", S.Default(S.Get("enabled"), "pet"), true)
    H.check("off: not watched", frame._unitWatch, nil)
    H.checkTrue("named", ns.L.FRAME_pettarget ~= "FRAME_pettarget")
    H.checkTrue("castbar on the pet's target", frame.castbar)
    H.checkTrue("castbar on the pet", ns.Frames.pet.castbar)
    H.check("pet castbar off by default", C.Get("pet", "castbarEnabled"), false)
    H.check("pet's target castbar on by default", C.Get("pettarget", "castbarEnabled"), true)
    H.checkTrue("pet castbar can be detached", S.AppliesTo(S.Get("castbarPosition"), "pet"))
    H.check("threat bar on by default", C.Get("pettarget", "threatBar"), true)
    H.check("no solo switch there", S.AppliesTo(S.Get("threatBarSolo"), "pettarget"), false)
    H.check("no threat bar on the pet frame", S.AppliesTo(S.Get("threatBar"), "pet"), false)

    C.Set("pettarget", "enabled", true)
    H.checkTrue("on: watched", frame._unitWatch)
    H.checkTrue("on: threat row", frame.threatBar:IsShown())
    -- The pet picks a target: the frame follows on UNIT_TARGET of the pet.
    M.units.pettarget = { name = "Boar", hostile = true, health = 3, healthMax = 4, detailed = {} }
    M.FireEvent("UNIT_TARGET", "pet")
    H.check("health of the pet's target", frame.health:GetValue(), 3)
    -- And on the timer (no unit events for "pettarget"), while the unit watch shows it.
    frame:Show()
    M.units.pettarget.health = 2
    M.Tick(0.25)
    H.check("polled", frame.health:GetValue(), 2)
end

-- The pet's threat, read as a tank's.
do
    local ns = boot()
    local T = ns.ThreatBar
    M.units.pettarget = { name = "Boar", hostile = true, health = 1, healthMax = 1, detailed = {} }
    local d = M.units.pettarget.detailed
    d.pet = { true, 3, 100, 100, 3000 }
    H.check("not your target: nothing (the client hides it)", T.EvaluatePet(), nil)
    -- Your target too: asked as "target", where the client answers.
    M.units.target = M.units.pettarget
    d.pet = nil
    H.check("no threat yet: nothing", T.EvaluatePet(), nil)
    d.pet = { true, 3, 100, 100, 3000 }
    d.player = { false, 1, 40, 36, 1200 }
    local shown = T.EvaluatePet()
    H.check("pet holds it: green", shown.color, "green")
    H.check("pet's threat", shown.left, "3.0k")
    H.check("lead over me", shown.right, "+1.8k Me")
    d.player = { false, 1, 90, 85, 2700 }
    H.check("I come close: yellow", T.EvaluatePet().color, "yellow")
    d.pet = { false, 1, 70, 65, 2000 }
    d.player = { true, 3, 100, 100, 3100 }
    shown = T.EvaluatePet()
    H.check("lost: red", shown.color, "red")
    H.check("gap to the holder", shown.right, "-1.1k Me")
    -- Hidden numbers: only the pet's status, as a tank's colour.
    d.pet = { M.Secret(true), 3, 100, 100, 3000 }
    M.units.pettarget.threatOf = { pet = 3 }
    H.check("secret: status colour", T.EvaluatePet().color, "green")
    M.units.pettarget.hostile = false
    H.check("not hostile: nothing", T.EvaluatePet(), nil)
end

-- The pet's role: a Voidwalker tanks everywhere, a hunter's pet outside
-- dungeons and raids; the rest do damage. The setting overrides.
do
    local ns = boot()
    local T, C = ns.ThreatBar, ns.Config
    local function petID(id) M.units.pet.guid = "Pet-0-1-1-1-" .. id .. "-0000000001" end
    petID(416)
    H.check("hunter's pet: tank", T.PetRole(), "tank")
    M.instanceType = "party"
    H.check("hunter's pet in a dungeon: damage", T.PetRole(), "dps")
    petID(1860)
    H.check("Voidwalker in a dungeon: tank", T.PetRole(), "tank")
    M.instanceType = nil
    M.units.player.class = "WARLOCK"
    petID(416)
    H.check("Imp: damage", T.PetRole(), "dps")
    C.Set("pettarget", "threatBarRole", "TANK")
    H.check("setting wins", T.PetRole(), "tank")
    C.Set("pettarget", "threatBarRole", "AUTO")
    -- As damage: the pet holding aggro is the bad case.
    M.units.pettarget = { name = "Boar", hostile = true, health = 1, healthMax = 1, detailed = {} }
    M.units.target = M.units.pettarget
    local d = M.units.pettarget.detailed
    d.pet = { true, 3, 100, 100, 3000 }
    H.check("Imp with aggro: red", T.EvaluatePet().color, "red")
    d.pet = { false, 1, 40, 36, 1200 }
    d.player = { true, 3, 100, 100, 3000 }
    local shown = T.EvaluatePet()
    H.check("Imp without aggro: green", shown.color, "green")
    H.check("Imp: its share", shown.left, "40%")
end

