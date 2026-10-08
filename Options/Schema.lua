local _, ns = ...
local Schema = {}
ns.Schema = Schema

-- The unit's outer border and its shadow: General > Appearance and each
-- frame's Layout tab.
-- The border section holds the corners too ("Border and corners").
local BORDER_KEYS = { "borderShow", "borderStyle", "borderSize", "borderPadding", "borderColor", "cornerRadius" }
local SHADOW_KEYS = { "shadowEnabled", "shadowAlpha", "shadowSize" }

-- Structured like a frame's page: the switches, the look, the bars, the
-- status, then the profile.
Schema.GENERAL = {
    -- The master switch (Core/Settings.lua: unitFrames), then one switch
    -- per frame (section.frames): the same "enabled" as on each frame's
    -- Layout tab (Options/Window.lua builds them).
    { id = "frames", sections = {
        { id = "frames", keys = { "unitFrames" }, frames = true },
        -- Click-casting (decision 76): the switch and, on General, a
        -- button to the bindings in the raid window.
        { id = "clickCast", keys = { "clickCast" }, editBindings = true },
    } },
    { id = "appearance", sections = {
        -- action: a two-click button under the rows (Options/Window.lua).
        { id = "font", keys = { "fontFace", "fontSize", "valueFontSize", "fontOutline", "fontShadow" },
            action = "applyFontToFrames" },
        -- How the texts read (not the font): also each frame's Text tab.
        { id = "display", keys = { "infoClassColor", "textCompact", "showSurname" } },
        { id = "titleText", keys = { "awayBadge", "titleClassIcon", "classIconSize", "classIconX", "classIconY",
            "classIconRing", "classIconRingColor" } },
        { id = "auraIcons", keys = { "auraBorder", "auraBorderSize" } },
        -- The spells hidden on every frame and raid cell.
        { id = "auraBlock", keys = { "auraBlockAccount" } },
        { id = "border", keys = BORDER_KEYS },
        { id = "shadow", keys = SHADOW_KEYS },
    } },
    -- The bars as on a frame's Bars tab: health colours, textures, the
    -- shield beside its colour, heals, power colours.
    { id = "bars", sections = {
        { id = "health", keys = { "healthColorMode", "healthColor", "reactionFriendlyColor", "reactionNeutralColor",
            "reactionHostileColor" } },
        { id = "textures", keys = { "barTexture", "backgroundColor", "titleBackground" } },
        { id = "absorbs", keys = { "absorbMode", "absorbColor" } },
        { id = "healPrediction", keys = { "healMyColor", "healOtherColor" } },
        { id = "powerColors", keys = { "powerColorMana", "powerColorRage", "powerColorFocus", "powerColorEnergy" } },
    } },
    -- The combat swords, the target highlight's colour; how range fading
    -- measures and how strongly it fades; the switches
    -- (and opacity overrides) are per frame (Status > Range on each page).
    { id = "status", sections = {
        { id = "combatIcon", keys = { "combatAnimation" } },
        -- The party's highlight colour, where its switch is (Status >
        -- Highlights).
        { id = "highlights", keys = { "targetHighlightColor" } },
        { id = "range", keys = { "rangeAlpha", "rangeFriendlyMode", "rangeFriendlySpell", "rangeFriendlyYards",
            "rangeHostileMode", "rangeHostileSpell", "rangeHostileYards" } },
    } },
    -- Export, import, reset (Options/Window.lua), then the minimap button.
    { id = "profile", custom = "profile", sections = {
        { id = "minimap", keys = { "minimapShow", "minimapAngle" } },
    } },
}

Schema.FRAME = {
    { id = "layout", sections = {
        { id = "frame", keys = { "enabled" } },
        { id = "size", keys = { "width", "height" } },
        { id = "position", keys = { "x", "y" } },
        { id = "barHeights", keys = { "titlePercent", "healthPercent", "powerPercent", "powerEnabled", "powerHideEmpty" } },
        { id = "portrait", keys = { "portraitMode", "portraitStyle" } },
        { id = "border", keys = BORDER_KEYS },
        { id = "shadow", keys = SHADOW_KEYS },
        -- General's switch, overridable here (decision 76).
        { id = "clickCast", keys = { "clickCast" } },
    } },
    -- The party's arrangement and what hangs beside its members.
    -- The note: the raid window's click-casting may act on the party too.
    { id = "group", note = "partyClickCast", sections = {
        { id = "group", keys = { "partyOrientation", "partySpacing", "partyShowPlayer", "partyShowSolo", "partyHideInRaid" } },
        { id = "pets", keys = { "partyShowPets", "partyPetLayout", "partyPetSide", "partyPetWidth", "partyPetHeight",
            "partyPetGap", "partyPetsX", "partyPetsY" } },
        { id = "petAuras", keys = { "partyPetAuras", "partyPetAuraSize", "partyPetAuraMax", "partyPetAuraSide",
            "partyPetAuraX", "partyPetAuraY" } },
        { id = "partyTargets", keys = { "partyTargets", "partyTargetSide", "partyTargetWidth", "partyTargetHeight",
            "partyTargetX", "partyTargetY" } },
    } },
    { id = "bars", sections = {
        { id = "health", keys = { "healthColorMode", "healthColor", "reactionFriendlyColor", "reactionNeutralColor",
            "reactionHostileColor", "tapDenied" } },
        { id = "textures", keys = { "barTexture", "backgroundColor", "titleBackground" } },
        { id = "absorbs", keys = { "absorbEnabled", "absorbMode", "absorbColor" } },
        { id = "healPrediction", keys = { "healPrediction", "healOverflow", "healBeyond", "powerMatchesHealth", "healMyColor", "healOtherColor" } },
        { id = "powerColors", keys = { "powerColorMana", "powerColorRage", "powerColorFocus", "powerColorEnergy" } },
        { id = "powerCost", keys = { "powerCostPrediction", "powerCostColor" } },
        { id = "druidMana", keys = { "druidMana", "druidManaHeight" } },
        { id = "fiveSecondRule", keys = { "fsrEnabled", "fsrSpark", "fsrSparkDirection", "fsrSparkWidth", "fsrSparkColor", "fsrText",
            "fsrTextPoint", "fsrTextTenths", "fsrDim", "fsrDimAlpha" } },
    } },
    -- The note: what "Info" shows, said once for every text.
    { id = "text", note = "texts", sections = {
        { id = "titleText", keys = { "titleText", "titleTextCenter", "titleTextRight", "titleColorMode", "awayBadge", "titleClassIcon", "classIconSize",
            "classIconX", "classIconY", "classIconRing", "classIconRingColor" } },
        { id = "healthText", keys = { "textHealthLeft", "textHealthCenter", "textHealthRight" } },
        { id = "powerText", keys = { "textPowerLeft", "textPowerCenter", "textPowerRight" } },
        -- The damage and heal numbers shown inside the frame.
        { id = "combatFeedback", keys = { "combatFeedback", "combatFeedbackPoint", "combatFeedbackX",
            "combatFeedbackY", "combatFeedbackFont", "combatFeedbackSize", "combatFeedbackOutline" } },
        -- How the texts read, on every bar: colours, level colour, compact
        -- values, the secondary name.
        { id = "display", keys = { "levelColorMode", "barNameColorMode", "infoClassColor", "textCompact",
            "showSurname" } },
        { id = "font", keys = { "fontFace", "fontSize", "valueFontSize", "fontOutline", "fontShadow" } },
    } },
    { id = "auras", sections = {
        { id = "auraIcons", keys = { "auraBorder", "auraBorderSize" } },
        { id = "buffs", keys = { "buffsEnabled", "weaponEnchants", "buffsOnlyMine", "buffsHideTracking", "buffsHidePermanent", "buffsHideLonger", "buffsShowTime", "buffsAnchor", "buffsFramePoint",
            "buffsPoint", "buffsX", "buffsY", "buffsGrowth", "buffsRowGrowth", "buffsSize", "buffsSpacing",
            "buffsPerRow", "buffsMax", "buffsHighlightOwn", "buffsOwnSize", "buffsOwnSameRow",
            "buffsOwnPlacement", "buffsOwnFramePoint", "buffsOwnPoint", "buffsOwnX", "buffsOwnY", "buffsOwnGrowth",
            "buffsOwnRowGrowth", "buffsOwnPerRow", "buffsCasterBorder", "buffsOwnBorderColor",
            "buffsOtherBorderColor" } },
        { id = "debuffs", keys = { "debuffsEnabled", "debuffsOnlyMine", "debuffsDispellable", "debuffsHidePermanent", "debuffsShowTime",
            "debuffsAnchor", "debuffsFramePoint", "debuffsPoint", "debuffsX", "debuffsY", "debuffsGrowth",
            "debuffsRowGrowth", "debuffsSize", "debuffsSpacing", "debuffsPerRow", "debuffsMax", "debuffsHighlightOwn",
            "debuffsOwnSize", "debuffsOwnSameRow", "debuffsOwnPlacement", "debuffsOwnFramePoint", "debuffsOwnPoint",
            "debuffsOwnX", "debuffsOwnY", "debuffsOwnGrowth", "debuffsOwnRowGrowth", "debuffsOwnPerRow" } },
        { id = "dispels", keys = { "dispelsEnabled", "dispelsShowTime", "dispelsAnchor", "dispelsFramePoint",
            "dispelsPoint", "dispelsX", "dispelsY", "dispelsGrowth", "dispelsRowGrowth", "dispelsSize",
            "dispelsSpacing", "dispelsPerRow", "dispelsMax" } },
        -- The spells this frame hides (with the account's list).
        { id = "auraBlock", keys = { "auraBlock" } },
        { id = "totems", keys = { "totemsEnabled", "totemsSize", "totemsSpacing", "totemsDirection", "totemsFramePoint", "totemsPoint",
            "totemsX", "totemsY" } },
    } },
    -- What the unit is doing or what state it is in, drawn on the frame.
    -- The note: how a point on the frame and an own point place things.
    -- The swords' animation (section.with): on the player's page with its
    -- status icon's combat switch, on the others' with the combat icon.
    { id = "status", note = "points", sections = {
        { id = "statusIcons", keys = { "statusCombat", "combatAnimation", "statusResting", "statusSize",
            "statusFramePoint", "statusPoint", "statusX", "statusY" }, with = { combatAnimation = "statusCombat" } },
        { id = "combatIcon", keys = { "combatIcon", "combatAnimation", "combatIconSize", "combatIconFramePoint", "combatIconPoint",
            "combatIconX", "combatIconY" }, with = { combatAnimation = "combatIcon" } },
        { id = "pvpIcon", keys = { "pvpIcon", "pvpIconNPC", "pvpIconSize", "pvpIconFramePoint", "pvpIconPoint", "pvpIconX",
            "pvpIconY" } },
        { id = "raidMarker", keys = { "raidMarker", "raidMarkerSize", "raidMarkerFramePoint", "raidMarkerPoint",
            "raidMarkerX", "raidMarkerY" } },
        { id = "eliteMarker", keys = { "eliteMarker", "eliteMarkerStyle", "eliteBorderSize", "eliteMarkerFramePoint",
            "eliteMarkerPoint", "eliteMarkerX", "eliteMarkerY", "eliteMarkerSize" } },
        { id = "petHappiness", keys = { "petHappiness", "petHappinessHideHappy", "petHappinessSize",
            "petHappinessFramePoint", "petHappinessPoint", "petHappinessX", "petHappinessY" } },
        { id = "groupIcons", keys = { "groupLeader", "groupReadyCheck", "groupResurrect", "groupRole", "groupIconSize",
            "groupIconFramePoint", "groupIconPoint", "groupIconX", "groupIconY" } },
        { id = "comboPoints", keys = { "comboPoints", "comboHideEmpty", "comboShape", "comboSize", "comboSpacing", "comboColor",
            "comboFramePoint", "comboPoint", "comboX", "comboY" } },
        -- What lights the frame up: threat, the party's target, a debuff
        -- you can dispel.
        { id = "highlights", keys = { "threatGlow", "targetHighlight", "targetHighlightColor", "targetHighlightSize",
            "dispelHighlight" } },
        -- Fading comes last: how the frame behaves, not what it shows.
        { id = "range", keys = { "rangeFade", "rangeAlpha" } },
        { id = "outOfCombat", keys = { "playerFadeOOC", "playerFadeAlpha", "playerFadeTarget", "playerFadeGroup",
            "playerFadePet" } },
    } },
    { id = "castbar", sections = {
        { id = "castbar", keys = { "castbarEnabled", "castbarAlwaysShow", "hideBlizzardCastbar", "castbarPosition", "castbarDock",
            "castbarHeight" } },
        { id = "castbarContent", keys = { "castbarIcon", "castbarName", "castbarTime" } },
        { id = "castbarDetached", keys = { "castbarX", "castbarY" } },
        { id = "threatBar", keys = { "threatBar", "threatBarHeight", "threatBarWarn", "threatBarRole",
            "threatBarSolo" } },
    } },
}

-- The keys of a section that a page shows: those that apply to it; a key
-- in section.with only where its named key applies too.
function Schema.SectionKeys(section, scope)
    local keys = {}
    for _, key in ipairs(section.keys) do
        local with = section.with and section.with[key]
        if ns.Settings.AppliesTo(ns.Settings.Get(key), scope)
            and (not with or ns.Settings.AppliesTo(ns.Settings.Get(with), scope)) then
            keys[#keys + 1] = key
        end
    end
    return keys
end

local function applicable(tab, scope)
    if tab.custom then return scope == "general" end
    for _, sec in ipairs(tab.sections) do
        for _, key in ipairs(sec.keys) do
            if ns.Settings.AppliesTo(ns.Settings.Get(key), scope) then return true end
        end
    end
    return false
end

function Schema.Tabs(scope)
    local source = scope == "general" and Schema.GENERAL or Schema.FRAME
    local tabs = {}
    for _, tab in ipairs(source) do
        if applicable(tab, scope) then tabs[#tabs + 1] = tab end
    end
    return tabs
end

function Schema.EnumText(def, value)
    local specific = "ENUM_" .. def.key .. "_" .. value
    if ns.L[specific] ~= specific then return ns.L[specific] end
    return ns.L["ENUM_" .. value]
end
