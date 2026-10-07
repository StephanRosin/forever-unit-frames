-- The unit frames' window greys a row while its switch is off or its mode
-- leaves it without effect (Options/Dependencies.lua); it never hides one.
-- Table-driven: per case a page, the parent with a value that greys the
-- rows and one that wakes them, the rows, and what else must be set.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local O, C = ns.Options, ns.Config

local function tabOf(scope, key)
    for _, tab in ipairs(ns.Schema.Tabs(scope)) do
        for _, section in ipairs(tab.sections or {}) do
            for _, k in ipairs(section.keys) do
                if k == key then return tab.id end
            end
        end
    end
end

local function rowFor(key)
    for _, row in ipairs(O.rows) do
        if row.key == key then return row end
    end
end

local CASES = {
    { "general", "borderShow", false, true, { "borderStyle", "borderSize", "borderPadding", "borderColor" } },
    { "player", "borderStyle", "GOLD", "FLAT", { "borderColor" } },
    { "general", "shadowEnabled", false, true, { "shadowAlpha", "shadowSize" } },
    { "general", "titleClassIcon", false, true, { "classIconSize", "classIconX", "classIconY", "classIconRing",
        "classIconRingColor" } },
    { "general", "classIconRing", 0, 2, { "classIconRingColor" } },
    { "general", "healthColorMode", "CLASS", "STATIC", { "healthColor" } },
    { "player", "healthColorMode", "GRADIENT", "STATIC", { "healthColor" } },
    { "player", "absorbEnabled", false, true, { "absorbMode", "absorbColor" } },
    { "player", "healPrediction", false, true, { "healOverflow", "healBeyond", "healMyColor", "healOtherColor",
        "powerMatchesHealth" }, { healOverflow = true } },
    { "player", "healOverflow", false, true, { "powerMatchesHealth" } },
    { "player", "powerEnabled", false, true, { "powerPercent", "powerCostPrediction", "powerCostColor",
        "druidMana", "druidManaHeight", "textPowerLeft", "textPowerCenter", "textPowerRight" },
        { powerCostPrediction = true, druidMana = true } },
    { "target", "powerEnabled", false, true, { "powerHideEmpty" } },
    { "player", "powerCostPrediction", false, true, { "powerCostColor" } },
    { "player", "druidMana", false, true, { "druidManaHeight" } },
    { "player", "portraitMode", "OFF", "LEFT", { "portraitStyle" } },
    { "target", "eliteMarker", false, true, { "eliteMarkerStyle", "eliteMarkerFramePoint", "eliteMarkerPoint",
        "eliteMarkerX", "eliteMarkerY" }, { eliteMarkerStyle = "MARKER", eliteMarkerFramePoint = "TOP" } },
    { "target", "eliteMarkerStyle", "BORDER", "MARKER", { "eliteMarkerFramePoint", "eliteMarkerPoint",
        "eliteMarkerX", "eliteMarkerY" }, { eliteMarkerFramePoint = "TOP" } },
    { "target", "eliteMarkerStyle", "MARKER", "BORDER", { "eliteBorderSize" } },
    { "target", "eliteMarkerFramePoint", "AUTO", "TOP", { "eliteMarkerPoint" }, { eliteMarkerStyle = "MARKER" } },
    { "party", "partyShowPets", false, true, { "partyPetLayout", "partyPetSide", "partyPetWidth", "partyPetHeight",
        "partyPetGap", "partyPetsX", "partyPetsY", "partyPetAuras", "partyPetAuraSize", "partyPetAuraMax",
        "partyPetAuraSide", "partyPetAuraX", "partyPetAuraY" }, { partyPetLayout = "BESIDE", partyPetAuras = true } },
    { "party", "partyPetLayout", "LIST", "BESIDE", { "partyPetSide" }, { partyShowPets = true } },
    { "party", "partyPetAuras", false, true, { "partyPetAuraSize", "partyPetAuraMax", "partyPetAuraSide",
        "partyPetAuraX", "partyPetAuraY" }, { partyShowPets = true } },
    { "party", "partyTargets", false, true, { "partyTargetSide", "partyTargetWidth", "partyTargetHeight",
        "partyTargetX", "partyTargetY" } },
    { "player", "buffsEnabled", false, true, { "weaponEnchants", "buffsOnlyMine", "buffsHideTracking",
        "buffsHidePermanent", "buffsHideLonger", "buffsShowTime", "buffsAnchor", "buffsFramePoint", "buffsPoint",
        "buffsX", "buffsY", "buffsGrowth", "buffsRowGrowth", "buffsSize", "buffsSpacing", "buffsPerRow", "buffsMax",
        "buffsHighlightOwn", "buffsOwnSize", "buffsOwnSameRow", "buffsCasterBorder", "buffsOwnBorderColor",
        "buffsOtherBorderColor" }, { buffsHighlightOwn = true, buffsCasterBorder = true } },
    { "target", "debuffsEnabled", false, true, { "debuffsOnlyMine", "debuffsDispellable", "debuffsHidePermanent",
        "debuffsShowTime", "debuffsAnchor", "debuffsFramePoint", "debuffsPoint", "debuffsX", "debuffsY",
        "debuffsGrowth", "debuffsRowGrowth", "debuffsSize", "debuffsSpacing", "debuffsPerRow", "debuffsMax",
        "debuffsHighlightOwn", "debuffsOwnSize", "debuffsOwnSameRow" }, { debuffsHighlightOwn = true } },
    { "party", "dispelsEnabled", false, true, { "dispelsShowTime", "dispelsAnchor", "dispelsFramePoint",
        "dispelsPoint", "dispelsX", "dispelsY", "dispelsGrowth", "dispelsRowGrowth", "dispelsSize", "dispelsSpacing",
        "dispelsPerRow", "dispelsMax" } },
    { "target", "buffsHighlightOwn", false, true, { "buffsOwnSize", "buffsOwnSameRow" }, { buffsEnabled = true } },
    { "target", "debuffsHighlightOwn", false, true, { "debuffsOwnSize", "debuffsOwnSameRow" },
        { debuffsEnabled = true } },
    { "target", "buffsCasterBorder", false, true, { "buffsOwnBorderColor", "buffsOtherBorderColor" },
        { buffsEnabled = true } },
    { "target", "auraBorder", false, true, { "auraBorderSize", "buffsCasterBorder", "buffsOwnBorderColor",
        "buffsOtherBorderColor" }, { buffsEnabled = true, buffsCasterBorder = true } },
    { "general", "auraBorder", false, true, { "auraBorderSize" } },
    { "target", "castbarEnabled", false, true, { "castbarAlwaysShow", "castbarPosition", "castbarHeight",
        "castbarIcon", "castbarName", "castbarTime", "castbarX", "castbarY" }, { castbarPosition = "DETACHED" } },
    { "party", "castbarEnabled", false, true, { "castbarDock" } },
    { "target", "castbarPosition", "BELOW", "DETACHED", { "castbarX", "castbarY" } },
    { "player", "threatBar", false, true, { "threatBarHeight", "threatBarWarn", "threatBarRole", "threatBarSolo" } },
    { "target", "combatIcon", false, true, { "combatIconSize", "combatIconFramePoint", "combatIconPoint",
        "combatIconX", "combatIconY", "combatAnimation" } },
    { "target", "pvpIcon", false, true, { "pvpIconNPC", "pvpIconSize", "pvpIconFramePoint", "pvpIconPoint",
        "pvpIconX", "pvpIconY" } },
    { "player", "raidMarker", false, true, { "raidMarkerSize", "raidMarkerFramePoint", "raidMarkerPoint",
        "raidMarkerX", "raidMarkerY" } },
    { "pet", "petHappiness", false, true, { "petHappinessHideHappy", "petHappinessSize", "petHappinessFramePoint",
        "petHappinessPoint", "petHappinessX", "petHappinessY" } },
    { "target", "comboPoints", false, true, { "comboHideEmpty", "comboShape", "comboSize", "comboSpacing",
        "comboColor", "comboFramePoint", "comboPoint", "comboX", "comboY" } },
    { "player", "totemsEnabled", false, true, { "totemsSize", "totemsSpacing", "totemsDirection",
        "totemsFramePoint", "totemsPoint", "totemsX", "totemsY" } },
    { "player", "statusCombat", false, true, { "statusSize", "statusFramePoint", "statusPoint", "statusX",
        "statusY", "combatAnimation" }, { statusResting = false } },
    { "player", "statusResting", false, true, { "statusSize", "statusX" }, { statusCombat = false } },
    { "party", "groupLeader", false, true, { "groupIconSize", "groupIconFramePoint", "groupIconPoint",
        "groupIconX", "groupIconY" }, { groupReadyCheck = false, groupResurrect = false, groupRole = false } },
    { "party", "groupRole", false, true, { "groupIconSize", "groupIconY" },
        { groupLeader = false, groupReadyCheck = false, groupResurrect = false } },
    { "party", "rangeFade", false, true, { "rangeAlpha" } },
    { "party", "targetHighlight", false, true, { "targetHighlightColor", "targetHighlightSize" } },
    { "player", "playerFadeOOC", false, true, { "playerFadeAlpha", "playerFadeTarget", "playerFadePet" } },
    { "general", "minimapShow", false, true, { "minimapAngle" } },
}

O.Open()
for _, case in ipairs(CASES) do
    local scope, parent, off, wake, rows, with = case[1], case[2], case[3], case[4], case[5], case[6] or {}
    for key, value in pairs(with) do C.Set(scope, key, value) end
    O.Select(scope)
    local label = scope .. " " .. parent .. " "
    for _, key in ipairs(rows) do
        O.SelectTab(tabOf(scope, key))
        C.Set(scope, parent, wake)
        H.check(label .. "wakes " .. key, rowFor(key) and rowFor(key).enabledState, true)
        C.Set(scope, parent, off)
        H.check(label .. "greys " .. key, rowFor(key) and rowFor(key).enabledState, false)
        H.checkTrue(label .. "keeps the row " .. key, rowFor(key) and rowFor(key):IsShown())
    end
    C.ResetScope(scope)
end

-- Rows that stay: a solo party header lists you without "show player";
-- hiding Blizzard's castbar does not need ours; the General page has no
-- frame switches.
local function stays(label, scope, parent, value, key)
    O.Select(scope)
    O.SelectTab(tabOf(scope, key))
    C.Set(scope, parent, value)
    H.check(label, rowFor(key).enabledState, true)
    C.ResetScope(scope)
end
stays("show when solo: without show player", "party", "partyShowPlayer", false, "partyShowSolo")
stays("hide Blizzard's castbar: ours off", "player", "castbarEnabled", false, "hideBlizzardCastbar")
stays("general: the absorbs' place", "general", "healthColorMode", "CLASS", "absorbMode")
stays("general: the range opacity", "general", "minimapShow", true, "rangeAlpha")
stays("general: the heal colours", "general", "healthColorMode", "CLASS", "healMyColor")
stays("general: the combat swords", "general", "healthColorMode", "CLASS", "combatAnimation")

-- In combat everything locks; afterwards a greyed row stays grey.
O.Select("player")
O.SelectTab("layout")
C.Set("player", "portraitMode", "OFF")
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("combat: locked", rowFor("width").enabledState, false)
M.SetCombat(false)
H.check("after combat: usable", rowFor("width").enabledState, true)
H.check("after combat: still grey", rowFor("portraitStyle").enabledState, false)
H.check("no error", #M.errors, 0)
