-- The cost of the spell being cast, faded over the end of the player's
-- power bar (Elements/PowerCost.lua), as Blizzard's player frame shows it.
-- Asked for on CurseForge.
local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
local C, S = ns.Config, ns.Settings
M.units.player = { name = "Me", level = 60, class = "MAGE", className = "Mage", isPlayer = true,
    health = 1, healthMax = 1, power = 800, powerMax = 1000, powerType = 0 }
-- Spell costs: Frostbolt 120 mana; a rage spell; a spell with two costs.
local COSTS = {
    [116] = { { type = 0, name = "MANA", cost = 120, minCost = 120 } },
    [78] = { { type = 1, name = "RAGE", cost = 15, minCost = 15 } },
    [999] = { { type = 3, name = "ENERGY", cost = 40 }, { type = 0, name = "MANA", cost = 50 } },
    [5] = { { type = 0, name = "MANA", cost = 0 } },
}
C_Spell.GetSpellPowerCost = function(id)
    if M.IsSecret(id) then id = M.Reveal(id) end
    return COSTS[id]
end
ns.Single.CreateAll()
local f = ns.Frames.player
local pc = f.powerCost

-- Settings ---------------------------------------------------------------------
H.check("code", S.Get("powerCostPrediction").code, "PC")
H.check("colour code", S.Get("powerCostColor").code, "PQ")
H.check("on by default, as Blizzard's", C.Get("player", "powerCostPrediction"), true)
for _, scope in ipairs({ "target", "targettarget", "pet", "focus", "party" }) do
    H.check("player only: " .. scope, S.AppliesTo(S.Get("powerCostPrediction"), scope), false)
    H.check("never built on " .. scope, ns.Frames[scope] and ns.Frames[scope].powerCost, nil)
end
H.checkTrue("label", ns.L.SETTING_powerCostPrediction ~= "SETTING_powerCostPrediction")

-- Layout -----------------------------------------------------------------------
local bar = pc.bar
H.checkTrue("fills from the right", bar._reverse)
H.checkTrue("clipped to the power bar", pc.clip._clips)
H.check("its right edge at the end of the fill", select(2, bar:GetPoint(1)), f.power:GetStatusBarTexture())
H.check("as wide as the power bar", bar:GetWidth(), f.powerWidth)
H.checkTrue("above the fill", pc.clip:GetFrameLevel() > f.power:GetFrameLevel())
H.checkTrue("below the power texts", pc.clip:GetFrameLevel() < f.powerTextLayer:GetFrameLevel())
H.check("hidden while nothing is cast", pc.clip:IsShown(), false)

-- Casting ----------------------------------------------------------------------
M.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 116)
H.checkTrue("cast: shown", pc.clip:IsShown())
H.check("the cost", bar:GetValue(), 120)
H.check("on the power bar's scale", select(2, bar:GetMinMaxValues()), 1000)
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Instant-2", 2139)
H.checkTrue("an instant spell during the cast: still shown", pc.clip:IsShown())
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 116)
H.check("cast done: hidden", pc.clip:IsShown(), false)

for _, ending in ipairs({ "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
    M.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-3", 116)
    M.FireEvent(ending, "player", "Cast-3", 116)
    H.check(ending .. ": hidden", pc.clip:IsShown(), false)
end

M.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-4", 78)
H.check("no cost in mana: nothing", pc.clip:IsShown(), false)
M.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-5", 999)
H.check("two costs: the mana one", bar:GetValue(), 50)
M.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-6", 5)
H.check("free spell: nothing", pc.clip:IsShown(), false)
M.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-7", 12345)
H.check("unknown spell: nothing", pc.clip:IsShown(), false)

-- Secret payload (spell casts can be restricted): the ID goes to the client
-- as it is, the end of a cast with a secret GUID always clears.
M.FireEvent("UNIT_SPELLCAST_START", "player", M.Secret("Cast-8"), M.Secret(116))
H.check("secret spell ID: cost found", bar:GetValue(), 120)
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", M.Secret("Other"), M.Secret(2139))
H.check("secret GUID: cleared", pc.clip:IsShown(), false)

-- A secret cost goes to the bar untouched.
COSTS[116][1].cost = M.Secret(120)
M.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-9", 116)
H.check("secret cost passed on", bar:GetValue(), COSTS[116][1].cost)
COSTS[116][1].cost = 120
M.FireEvent("UNIT_DISPLAYPOWER", "player")
H.check("power type changed: hidden", pc.clip:IsShown(), false)

-- Off, colour --------------------------------------------------------------------
C.Set("player", "powerCostPrediction", false)
M.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-10", 116)
H.check("off: nothing", pc.clip:IsShown(), false)
C.Set("player", "powerCostPrediction", true)
C.Set("player", "powerCostColor", { 1, 0, 0, 0.5 })
H.check("colour", bar._color[1] .. bar._color[2] .. bar._color[4], "100.5")

-- Test mode ------------------------------------------------------------------------
ns.TestMode.Set(true)
H.checkTrue("test: a sample cost", pc.clip:IsShown())
H.check("test: a fifth of the bar", bar:GetValue(), ns.PowerCost.SAMPLE)
ns.TestMode.Set(false)
H.check("test over: hidden", pc.clip:IsShown(), false)
