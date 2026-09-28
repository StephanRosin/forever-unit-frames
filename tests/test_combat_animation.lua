-- Combat icon animation (Elements/CombatAnimation.lua): BURST springs the
-- icon in and flashes once as it appears, PULSE breathes while shown, OFF
-- keeps it still. The player's icon and everyone else's.
local M = H.M
local ns = H.LoadAddon()
local S, C, A = ns.Settings, ns.Config, ns.CombatAnimation
C.Use({})
M.units.player = { name = "Me", class = "MAGE", className = "Mage", isPlayer = true, health = 1, healthMax = 1 }
M.units.target = { name = "Ogre", hostile = true, health = 5, healthMax = 10 }
ns.Single.CreateAll()
local p, t = ns.Frames.player, ns.Frames.target

local def = S.Get("combatAnimation")
H.check("code", def.code, "EA")
H.check("duel by default", C.Get("target", "combatAnimation"), "DUEL")
H.check("duel on every frame by default", C.Get("party", "combatAnimation"), "DUEL")
C.Set("general", "combatAnimation", "BURST")
H.checkTrue("on the player", S.AppliesTo(def, "player"))
H.check("not on the pet (no combat icon)", S.AppliesTo(def, "pet"), false)
H.checkTrue("set in General", S.AppliesTo(def, "general"))

-- The player's icon -------------------------------------------------------------------
local a = p.statusIcons.combatAnim
local scale = a.burst._anims[1]
H.check("springs in from bigger", scale._scaleFrom[1], A.BURST_SCALE)
H.check("the flash is additive", a.flash._blend, "ADD")
M.FireEvent("PLAYER_REGEN_DISABLED")
H.checkTrue("combat starts: burst", a.burst:IsPlaying())
H.checkTrue("and a flash", a.shine:IsPlaying())
H.check("no pulse", a.pulse:IsPlaying(), false)
a.burst:Stop(); a.shine:Stop()
ns.StatusIcons.Refresh(p)
H.check("still in combat: no second burst", a.burst:IsPlaying(), false)
M.FireEvent("PLAYER_REGEN_ENABLED")
H.check("combat over: still", a.burst:IsPlaying(), false)
H.check("flash gone", a.flash:GetAlpha(), 0)

C.Set("player", "combatAnimation", "PULSE")
M.FireEvent("PLAYER_REGEN_DISABLED")
H.checkTrue("pulse while shown", a.pulse:IsPlaying())
H.check("pulse bounces", a.pulse._looping, "BOUNCE")
H.check("no burst with pulse", a.burst:IsPlaying(), false)
M.FireEvent("PLAYER_REGEN_ENABLED")
H.check("pulse stops with the icon", a.pulse:IsPlaying(), false)
-- Duel: our flipbook sheet instead of the still atlas, looping while shown.
C.Set("player", "combatAnimation", "DUEL")
H.check("duel: our sheet", p.statusIcons.combat._texture, A.DUEL_TEXTURE)
M.FireEvent("PLAYER_REGEN_DISABLED")
H.checkTrue("duel: loops while in combat", a.duel:IsPlaying())
H.check("duel loops", a.duel._looping, "REPEAT")
H.check("duel: 16 frames", a.duel._anims[1]._frames, 16)
H.check("duel: no burst", a.burst:IsPlaying(), false)
M.FireEvent("PLAYER_REGEN_ENABLED")
H.check("duel: stops out of combat", a.duel:IsPlaying(), false)
C.Set("player", "combatAnimation", "BURST")
H.check("back to Blizzard's art", p.statusIcons.combat._atlas, ns.StatusIcons.COMBAT_ATLAS)
C.Set("player", "combatAnimation", "OFF")
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("off: no burst", a.burst:IsPlaying(), false)
H.check("off: no pulse", a.pulse:IsPlaying(), false)
M.FireEvent("PLAYER_REGEN_ENABLED")

-- Someone else's ------------------------------------------------------------------------
C.Set("target", "combatIcon", true)
local ta = t.unitIcons.combatIcon.anim
M.units.target.inCombat = true
M.FireEvent("UNIT_FLAGS", "target")
H.checkTrue("target pulls: burst", ta.burst:IsPlaying())
ta.burst:Stop()
M.FireEvent("UNIT_FLAGS", "target")
H.check("no repeat while it fights", ta.burst:IsPlaying(), false)
M.units.target.inCombat = false
M.FireEvent("UNIT_FLAGS", "target")
M.units.target.inCombat = true
M.FireEvent("UNIT_FLAGS", "target")
H.checkTrue("the next fight bursts again", ta.burst:IsPlaying())
-- General setting reaches every frame.
C.Set("general", "combatAnimation", "PULSE")
M.FireEvent("UNIT_FLAGS", "target")
H.checkTrue("General: pulse on the target", ta.pulse:IsPlaying())
C.Set("target", "combatIcon", false)
H.check("icon off: animation stops", ta.pulse:IsPlaying(), false)

-- Options: with the combat icon; in General too.
local function sectionOf(scope)
    for _, tab in ipairs(ns.Schema.Tabs(scope)) do
        for _, sec in ipairs(tab.sections or {}) do
            for _, k in ipairs(sec.keys) do if k == "combatAnimation" then return tab.id .. ":" .. sec.id end end
        end
    end
end
H.check("target: combat icon section", sectionOf("target"), "status:combatIcon")
H.check("general: status tab", sectionOf("general"), "status:combatIcon")
