-- The hunter pet's happiness on the pet frame (Elements/PetHappiness.lua):
-- settings, Blizzard's art, hunter pets only, the tooltip, test mode.
local M = H.M
local ns = H.LoadAddon()
local S, C = ns.Settings, ns.Config
C.Use({})
M.units.player = { name = "Me", class = "HUNTER", className = "Hunter", isPlayer = true, health = 1, healthMax = 1 }
M.units.pet = { name = "Wolf", health = 5, healthMax = 10 }
M.atlases["UI-PetHappiness"], M.atlases["UI-PetNeutral"], M.atlases["UI-PetMad"] = true, true, true

-- The client's answers: happiness, damage percentage, loyalty rate; and
-- whether the pet is a hunter's.
local happiness, hunterPet = { 3, 125, 1 }, true
_G.C_PetInfo = {
    GetPetHappiness = function() return unpack(happiness) end,
    GetPetFoodTypes = function() return { "Meat", "Fish" } end,
}
_G.HasPetUI = function() return true, hunterPet end
_G.PET_HAPPINESS1, _G.PET_HAPPINESS2, _G.PET_HAPPINESS3 = "Unhappy", "Content", "Happy"
_G.PET_DAMAGE_PERCENTAGE, _G.GAINING_LOYALTY, _G.LOSING_LOYALTY = "Pet is doing %d%% damage", "Gaining loyalty",
    "Losing loyalty"
_G.PET_DIET_TEMPLATE, _G.PET_FOOD_DELIMIT = "Diet: %s", ", "

ns.Single.CreateAll()
local pet = ns.Frames.pet

-- Settings -----------------------------------------------------------------------
local CODES = { petHappiness = "GE", petHappinessHideHappy = "GN", petHappinessSize = "GZ",
    petHappinessFramePoint = "GF", petHappinessPoint = "GO", petHappinessX = "GX", petHappinessY = "GY" }
for key, code in pairs(CODES) do
    H.check("code of " .. key, S.Get(key).code, code)
    H.checkTrue(key .. " labelled", ns.L["SETTING_" .. key] ~= "SETTING_" .. key)
    for _, scope in ipairs({ "player", "target", "targettarget", "focus", "party", "partypet" }) do
        H.check(key .. " not on " .. scope, S.AppliesTo(S.Get(key), scope), false)
    end
end
H.check("on by default, as on Blizzard's pet frame", C.Get("pet", "petHappiness"), true)
H.check("shown while happy by default", C.Get("pet", "petHappinessHideHappy"), false)
H.check("section label", ns.L.SECTION_petHappiness, "Pet happiness")
for _, key in ipairs({ "player", "target", "targettarget", "focus" }) do
    H.check("never built on " .. key, ns.Frames[key].petHappiness, nil)
end

-- Showing ------------------------------------------------------------------------
local ph = pet.petHappiness
M.FireEvent("UNIT_PET", "player")
H.checkTrue("happy hunter pet: shown", ph.holder:IsShown())
H.check("happy art", ph.tex._atlas, "UI-PetHappiness")
happiness = { 1, 75, -1 }
M.FireEvent("UNIT_HAPPINESS", "pet")
H.check("unhappy art after UNIT_HAPPINESS", ph.tex._atlas, "UI-PetMad")
happiness = { 2, 100, 0 }
M.FireEvent("UNIT_HAPPINESS", "pet")
H.check("content art", ph.tex._atlas, "UI-PetNeutral")
local point, _, relPoint = ph.holder:GetPoint(1)
H.check("right of the frame", point .. ">" .. relPoint, "LEFT>RIGHT")
C.Set("pet", "petHappinessSize", 28)
H.check("size", ph.holder:GetWidth(), 28)

-- Only when not happy.
C.Set("pet", "petHappinessHideHappy", true)
H.checkTrue("content: still shown", ph.holder:IsShown())
happiness = { 3, 125, 1 }
M.FireEvent("UNIT_HAPPINESS", "pet")
H.check("happy: hidden", ph.holder:IsShown(), false)
C.Set("pet", "petHappinessHideHappy", false)
H.checkTrue("happy again shown with the option off", ph.holder:IsShown())

-- No happiness: demons and the like, secret or missing answers.
hunterPet = false
M.FireEvent("PET_UI_UPDATE")
H.check("not a hunter pet: hidden", ph.holder:IsShown(), false)
hunterPet = true
happiness = { M.Secret(2), 100, 0 }
M.FireEvent("UNIT_HAPPINESS", "pet")
H.check("secret answer: hidden", ph.holder:IsShown(), false)
happiness = {}
M.FireEvent("UNIT_HAPPINESS", "pet")
H.check("no answer: hidden", ph.holder:IsShown(), false)
happiness = { 2, 100, 0 }
M.FireEvent("UNIT_HAPPINESS", "pet")
H.checkTrue("answer back: shown", ph.holder:IsShown())
C.Set("pet", "petHappiness", false)
H.check("switched off: hidden", ph.holder:IsShown(), false)
C.Set("pet", "petHappiness", true)

-- Older art where the client lacks the atlas.
M.atlases["UI-PetNeutral"] = nil
M.FireEvent("UNIT_HAPPINESS", "pet")
H.check("fallback texture", ph.tex._texture, ns.PetHappiness.TEXTURE)
H.check("its middle cell", ph.tex._texCoord[1], 0.1875)
M.atlases["UI-PetNeutral"] = true

-- Tooltip and clicks ---------------------------------------------------------------
H.check("clicks go through to the unit button", ph.holder._clickEnabled, false)
happiness = { 1, 75, -1 }
M.FireEvent("UNIT_HAPPINESS", "pet")
ph.holder:GetScript("OnEnter")(ph.holder)
H.checkTrue("tooltip shown", GameTooltip._shown and GameTooltip:IsOwned(ph.holder))
H.check("tooltip: the mood", M.tooltipLines[1], "Unhappy")
H.check("tooltip: damage", M.tooltipLines[2], "Pet is doing 75% damage")
H.check("tooltip: loyalty", M.tooltipLines[3], "Losing loyalty")
H.check("tooltip: diet", M.tooltipLines[4], "Diet: Meat, Fish")
ph.holder:GetScript("OnLeave")(ph.holder)
H.check("tooltip gone", GameTooltip._shown, false)

-- Test mode ------------------------------------------------------------------------
hunterPet = false
M.FireEvent("PET_UI_UPDATE")
C.Set("pet", "petHappinessHideHappy", true)
ns.TestMode.Set(true)
H.checkTrue("test: shown without a hunter pet", ph.holder:IsShown())
H.check("test: a content pet (seen with 'only when not happy')", ph.tex._atlas, "UI-PetNeutral")
ns.TestMode.Set(false)
H.check("test over: hidden again", ph.holder:IsShown(), false)

-- Hunters only: another class never shows it, not even in test mode.
hunterPet = true
M.units.player.class, M.units.player.className = "WARLOCK", "Warlock"
happiness = { 1, 75, -1 }
M.FireEvent("UNIT_HAPPINESS", "pet")
H.check("warlock: hidden even with a hunter pet's answer", ph.holder:IsShown(), false)
ns.TestMode.Set(true)
H.check("warlock: no sample in test mode", ph.holder:IsShown(), false)
ns.TestMode.Set(false)
M.units.player.class = M.Secret("HUNTER")
M.FireEvent("UNIT_HAPPINESS", "pet")
H.checkTrue("secret class: the pet check decides", ph.holder:IsShown())
M.units.player.class, M.units.player.className = "HUNTER", "Hunter"

-- Options --------------------------------------------------------------------------
local found
for _, tab in ipairs(ns.Schema.Tabs("pet")) do
    for _, sec in ipairs(tab.sections or {}) do
        if sec.id == "petHappiness" then found = tab.id end
    end
end
H.check("on the pet's status tab", found, "status")
