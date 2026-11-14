local _, ns = ...
local Schema = {}
ns.Schema = Schema

-- The unit's outer border and its shadow: General > Appearance and each
-- frame's Layout tab.
-- The border section holds the corners too ("Border and corners").
local BORDER_KEYS = { "borderShow", "borderStyle", "borderSize", "borderPadding", "borderColor", "cornerRadius" }
local SHADOW_KEYS = { "shadowEnabled", "shadowAlpha", "shadowSize" }

-- Structured like a frame's page: the switches, the look, the bars, the
-- status.
Schema.GENERAL = {
    -- The master switch (Core/Settings.lua: unitFrames), then one switch
    -- per frame (section.frames): the same "enabled" as on each frame's
    -- Layout tab (Options/Window.lua builds them); the addon's own minimap
    -- button.
    { id = "frames", sections = {
        { id = "frames", keys = { "unitFrames" }, frames = true,
            actions = { "positionsFromBlizzard", "positionsUndo" } },
        { id = "minimap", keys = { "minimapShow", "minimapAngle" } },
    } },
    -- The click-casting editor, the raid window's own (Raid/Options/
    -- ClickCast.lua builds both; the bindings belong to the character, as
    -- there). note: the raid tab's. Its section: the unit frames' switch
    -- (decision 76), on top of the editor (Options/Window.lua puts it there).
    { id = "clickCast", custom = "clickCast", note = "clickCast", sections = {
        { id = "clickCast", keys = { "clickCast" } },
    } },
    { id = "appearance", sections = {
        -- actions: two-click buttons under the rows (Options/Window.lua).
        { id = "font", keys = { "fontFace", "fontSize", "valueFontSize", "fontOutline", "fontShadow" },
            actions = { "applyFontToFrames" } },
        -- How the texts read (not the font): also each frame's Text tab.
        { id = "display", keys = { "infoClassColor", "textCompact", "showSurname" } },
        { id = "titleText", keys = { "awayBadge", "titleClassIcon", "classIconSize", "classIconX", "classIconY",
            "classIconRing", "classIconRingColor" }, placement = { "classIconX", "classIconY" } },
        { id = "border", keys = BORDER_KEYS },
        { id = "shadow", keys = SHADOW_KEYS },
        -- How see-through the frames are, and how much range fading takes
        -- off (how it measures: Status > Range).
        { id = "visibility", keys = { "frameAlpha", "rangeAlpha" } },
    } },
    -- The aura icons' border and the spells hidden on every frame and raid
    -- cell.
    { id = "auras", sections = {
        { id = "auraIcons", keys = { "auraBorder", "auraBorderSize", "auraTimeX", "auraTimeY" } },
        { id = "auraBlock", keys = { "auraBlockAccount" } },
    } },
    -- The bars as on a frame's Bars tab: health colours, textures, the
    -- shield beside its colour, heals, power colours.
    { id = "bars", sections = {
        { id = "health", keys = { "healthColorMode", "healthColor", "reactionFriendlyColor", "reactionNeutralColor",
            "reactionHostileColor" } },
        { id = "textures", keys = { "barTexture", "backgroundColor", "titleBackground" } },
        { id = "absorbs", keys = { "absorbMode", "absorbColor" } },
        { id = "healPrediction", keys = { "healMyColor", "healOtherColor" } },
        { id = "powerColors", keys = { "powerColorMode", "powerColorMana", "powerColorRage", "powerColorFocus", "powerColorEnergy" } },
    } },
    -- The combat swords, the target highlight's colour; how range fading
    -- measures (its opacity: Appearance > Visibility; the switches are per
    -- frame, Layout > Visibility on each page).
    { id = "status", sections = {
        { id = "combatIcon", keys = { "combatAnimation" } },
        -- The party's highlight colour, where its switch is (Status >
        -- Highlights).
        { id = "highlights", keys = { "targetHighlightColor" } },
        { id = "range", keys = { "rangeFriendlyMode", "rangeFriendlySpell", "rangeFriendlyYards",
            "rangeHostileMode", "rangeHostileSpell", "rangeHostileYards" } },
    } },
}

-- The navigation's last entry: the named profiles, export, import, reset
-- (Options/Window.lua builds the page).
Schema.PROFILES = {
    { id = "profiles", custom = "profiles", sections = {} },
}

Schema.FRAME = {
    { id = "layout", sections = {
        { id = "frame", keys = { "enabled", "playerHideInGroup", "hideBlizzardFrame" } },
        { id = "size", keys = { "width", "height" } },
        { id = "position", keys = { "x", "y", "bossSpacing" } },
        { id = "barHeights", keys = { "titlePercent", "healthPercent", "powerPercent", "powerEnabled", "powerHideEmpty" } },
        { id = "portrait", keys = { "portraitMode", "portraitStyle", "portraitHeight", "portraitZoom", "portraitOffsetY" } },
        { id = "border", keys = BORDER_KEYS },
        { id = "shadow", keys = SHADOW_KEYS },
        -- Everything about how see-through the frame is: its opacity, then
        -- range fading and (player) fading out of combat, a share of it.
        { id = "visibility", keys = { "frameAlpha", "rangeFade", "rangeAlpha", "playerFadeOOC", "playerFadeAlpha",
            "playerFadeTarget", "playerFadeHurt", "playerFadeGroup", "playerFadePet" } },
        -- General's switch, overridable here (decision 76).
        { id = "clickCast", keys = { "clickCast" } },
    } },
    -- The party's arrangement and what hangs beside its members.
    -- The note: the raid window's click-casting may act on the party too.
    { id = "group", note = "partyClickCast", sections = {
        { id = "group", keys = { "partyOrientation", "partyGrowReverse", "partySortRole", "partySpacing", "partyShowPlayer", "partyShowSolo", "partyHideInRaid" } },
        { id = "pets", keys = { "partyShowPets", "partyPetLayout", "partyPetSide", "partyPetWidth", "partyPetHeight",
            "partyPetGap", "partyPetsX", "partyPetsY" } },
        { id = "petAuras", keys = { "partyPetAuras", "partyPetAuraSize", "partyPetAuraMax", "partyPetAuraSide",
            "partyPetAuraX", "partyPetAuraY" } },
        { id = "partyTargets", keys = { "partyTargets", "partyTargetSide", "partyTargetWidth", "partyTargetHeight",
            "partyTargetX", "partyTargetY" } },
        -- The raid window's settings (Raid/Settings.lua), the same values:
        -- Options/Window.lua builds their rows with that window's.
        { id = "partyBuffs", keys = {}, raidKeys = { "buffKey", "buffSolo", "buffWatchShow" } },
    } },
    { id = "bars", sections = {
        { id = "health", keys = { "healthColorMode", "healthColor", "reactionFriendlyColor", "reactionNeutralColor",
            "reactionHostileColor", "tapDenied" } },
        { id = "textures", keys = { "barTexture", "backgroundColor", "titleBackground" } },
        { id = "absorbs", keys = { "absorbEnabled", "absorbMode", "absorbColor" } },
        { id = "healPrediction", keys = { "healPrediction", "healOverflow", "healBeyond", "powerMatchesHealth", "healMyColor", "healOtherColor" } },
        { id = "powerColors", keys = { "powerColorMode", "powerColorMana", "powerColorRage", "powerColorFocus", "powerColorEnergy" } },
        { id = "powerCost", keys = { "powerCostPrediction", "powerCostColor" } },
        { id = "druidMana", keys = { "druidMana", "druidManaHeight" } },
        { id = "fiveSecondRule", keys = { "fsrEnabled", "fsrSpark", "fsrSparkDirection", "fsrSparkWidth", "fsrSparkColor", "fsrText",
            "fsrTextPoint", "fsrTextTenths", "fsrDim", "fsrDimAlpha" } },
    } },
    -- The note: what "Info" shows, said once for every text. The font
    -- first: the sizes of every text below.
    { id = "text", note = "texts", sections = {
        { id = "font", keys = { "fontFace", "fontSize", "valueFontSize", "fontOutline", "fontShadow" } },
        { id = "titleText", keys = { "titleText", "titleTextCenter", "titleTextRight", "titleColorMode", "awayBadge", "titleClassIcon", "classIconSize",
            "classIconX", "classIconY", "classIconRing", "classIconRingColor" }, placement = { "classIconX", "classIconY" } },
        { id = "healthText", keys = { "textHealthLeft", "textHealthCenter", "textHealthRight" } },
        { id = "powerText", keys = { "textPowerLeft", "textPowerCenter", "textPowerRight" } },
        { id = "footerText", keys = { "footerHeight", "footerTextLeft", "footerTextCenter", "footerTextRight" } },
        -- The damage and heal numbers shown inside the frame.
        { id = "combatFeedback", keys = { "combatFeedback", "combatFeedbackPoint", "combatFeedbackX",
            "combatFeedbackY", "combatFeedbackFont", "combatFeedbackSize", "combatFeedbackOutline" },
            placement = { "combatFeedbackPoint", "combatFeedbackX", "combatFeedbackY" } },
        -- How the texts read, on every bar: colours, level colour, compact
        -- values, the secondary name.
        { id = "display", keys = { "levelColorMode", "barNameColorMode", "infoClassColor", "textCompact",
            "showSurname" } },
    } },
    -- Buffs and debuffs: what shows first, then a block for your own.
    { id = "auras", sections = {
        { id = "auraIcons", keys = { "auraBorder", "auraBorderSize", "auraTimeX", "auraTimeY" } },
        { id = "buffs", keys = { "buffsEnabled", "hideBlizzardAuras", "weaponEnchants", "buffsOnlyMine", "buffsHideTracking", "buffsHidePermanent", "buffsHideLonger", "buffsShowTime", "buffsAnchor", "buffsFramePoint",
            "buffsPoint", "buffsX", "buffsY", "buffsGrowth", "buffsRowGrowth", "buffsSize", "buffsSpacing", "buffsRowGap",
            "buffsPerRow", "buffsMax" },
            placement = { "buffsAnchor", "buffsFramePoint", "buffsPoint", "buffsX", "buffsY", "buffsGrowth", "buffsRowGrowth" } },
        { id = "buffsOwn", keys = { "buffsHighlightOwn", "buffsOwnSize", "buffsOwnSameRow",
            "buffsOwnPlacement", "buffsOwnFramePoint", "buffsOwnPoint", "buffsOwnX", "buffsOwnY", "buffsOwnGrowth",
            "buffsOwnRowGrowth", "buffsOwnPerRow", "buffsCasterBorder", "buffsOwnBorderColor",
            "buffsOtherBorderColor" },
            placement = { "buffsOwnFramePoint", "buffsOwnPoint", "buffsOwnX", "buffsOwnY",
                "buffsOwnGrowth", "buffsOwnRowGrowth" } },
        { id = "debuffs", keys = { "debuffsEnabled", "debuffsOnlyMine", "debuffsDispellable", "debuffsHidePermanent", "debuffsShowTime",
            "debuffsAnchor", "debuffsFramePoint", "debuffsPoint", "debuffsX", "debuffsY", "debuffsGrowth",
            "debuffsRowGrowth", "debuffsSize", "debuffsSpacing", "debuffsRowGap", "debuffsPerRow", "debuffsMax" },
            placement = { "debuffsAnchor", "debuffsFramePoint", "debuffsPoint", "debuffsX", "debuffsY", "debuffsGrowth",
                "debuffsRowGrowth" } },
        { id = "debuffsOwn", keys = { "debuffsHighlightOwn",
            "debuffsOwnSize", "debuffsOwnSameRow", "debuffsOwnPlacement", "debuffsOwnFramePoint", "debuffsOwnPoint",
            "debuffsOwnX", "debuffsOwnY", "debuffsOwnGrowth", "debuffsOwnRowGrowth", "debuffsOwnPerRow" },
            placement = { "debuffsOwnFramePoint", "debuffsOwnPoint", "debuffsOwnX", "debuffsOwnY",
                "debuffsOwnGrowth", "debuffsOwnRowGrowth" } },
        { id = "dispels", keys = { "dispelsEnabled", "dispelsShowTime", "dispelsAnchor", "dispelsFramePoint",
            "dispelsPoint", "dispelsX", "dispelsY", "dispelsGrowth", "dispelsRowGrowth", "dispelsSize",
            "dispelsSpacing", "dispelsRowGap", "dispelsPerRow", "dispelsMax" },
            placement = { "dispelsAnchor", "dispelsFramePoint", "dispelsPoint", "dispelsX", "dispelsY", "dispelsGrowth",
                "dispelsRowGrowth" } },
        -- The spells this frame hides (with the account's list).
        { id = "auraBlock", keys = { "auraBlock" } },
        { id = "totems", keys = { "totemsEnabled", "totemsSize", "totemsSpacing", "totemsDirection", "totemsFramePoint", "totemsPoint",
            "totemsX", "totemsY" }, placement = { "totemsDirection", "totemsFramePoint", "totemsPoint", "totemsX", "totemsY" } },
    } },
    -- What the unit is doing or what state it is in, drawn on the frame.
    -- The note: how a point on the frame and an own point place things.
    -- The swords' animation (section.with): on the player's page with its
    -- status icon's combat switch, on the others' with the combat icon.
    -- placement: the rows folded under "Position" (Options/Window.lua).
    { id = "status", note = "points", sections = {
        { id = "statusIcons", keys = { "statusCombat", "combatAnimation", "statusResting", "statusSize",
            "statusFramePoint", "statusPoint", "statusX", "statusY" }, with = { combatAnimation = "statusCombat" },
            placement = { "statusFramePoint", "statusPoint", "statusX", "statusY" } },
        { id = "combatIcon", keys = { "combatIcon", "combatAnimation", "combatIconSize", "combatIconFramePoint", "combatIconPoint",
            "combatIconX", "combatIconY" }, with = { combatAnimation = "combatIcon" },
            placement = { "combatIconFramePoint", "combatIconPoint", "combatIconX", "combatIconY" } },
        { id = "pvpIcon", keys = { "pvpIcon", "pvpTimer", "pvpIconNPC", "pvpIconSize", "pvpIconFramePoint", "pvpIconPoint", "pvpIconX",
            "pvpIconY" }, placement = { "pvpIconFramePoint", "pvpIconPoint", "pvpIconX", "pvpIconY" } },
        { id = "raidMarker", keys = { "raidMarker", "raidMarkerSize", "raidMarkerFramePoint", "raidMarkerPoint",
            "raidMarkerX", "raidMarkerY" }, placement = { "raidMarkerFramePoint", "raidMarkerPoint", "raidMarkerX", "raidMarkerY" } },
        { id = "eliteMarker", keys = { "eliteMarker", "eliteMarkerStyle", "eliteBorderSize", "eliteMarkerFramePoint",
            "eliteMarkerPoint", "eliteMarkerX", "eliteMarkerY", "eliteMarkerSize" },
            placement = { "eliteMarkerFramePoint", "eliteMarkerPoint", "eliteMarkerX", "eliteMarkerY" } },
        { id = "petHappiness", keys = { "petHappiness", "petHappinessHideHappy", "petHappinessSize",
            "petHappinessFramePoint", "petHappinessPoint", "petHappinessX", "petHappinessY" },
            placement = { "petHappinessFramePoint", "petHappinessPoint", "petHappinessX", "petHappinessY" } },
        { id = "groupIcons", keys = { "groupLeader", "groupReadyCheck", "groupResurrect", "groupSummon", "groupPhase", "groupRole",
            "groupIconSize",
            "groupIconFramePoint", "groupIconPoint", "groupIconX", "groupIconY" },
            placement = { "groupIconFramePoint", "groupIconPoint", "groupIconX", "groupIconY" } },
        { id = "comboPoints", keys = { "comboPoints", "comboHideEmpty", "comboShape", "comboSize", "comboSpacing", "comboColor",
            "comboFramePoint", "comboPoint", "comboX", "comboY" },
            placement = { "comboFramePoint", "comboPoint", "comboX", "comboY" } },
        -- Threat together: the glow on the frame and (player, pet's target)
        -- the bar below it.
        { id = "threat", keys = { "threatGlow", "threatBar", "threatBarHeight", "threatBarWarn", "threatBarRole",
            "threatBarSolo" } },
        -- What lights the frame up: the party's target, a debuff you can
        -- dispel, the mouse.
        { id = "highlights", keys = { "targetHighlight", "targetHighlightColor", "targetHighlightSize",
            "dispelHighlight", "dispelPulse", "hoverHighlight" } },
    } },
    { id = "castbar", sections = {
        { id = "castbar", keys = { "castbarEnabled", "castbarAlwaysShow", "hideBlizzardCastbar", "castbarPosition", "castbarDock",
            "castbarHeight" } },
        { id = "castbarContent", keys = { "castbarIcon", "castbarName", "castbarTime", "castbarInterrupt", "castbarLatency", "castbarLatencyPoint",
            "castbarLatencyX" } },
        { id = "castbarDetached", keys = { "castbarX", "castbarY" } },
    } },
    -- Blocks of their own with a mover, the player only (their keys apply
    -- nowhere else, so the tab shows on the player's page only).
    { id = "extras", sections = {
        -- The low mana warning (Elements/ManaWarning.lua), the player only.
        { id = "manaWarn", keys = { "manaWarn", "manaWarnBelow", "manaWarnGroupOnly", "manaWarnOutOfCombat", "manaWarnShow", "manaWarnIcon",
            "manaWarnSize", "manaWarnFontSize", "manaWarnColor", "manaWarnPulse", "manaWarnFade", "manaWarnFadeTime", "manaWarnChat", "manaWarnClick", "manaWarnClickKey",
            "manaWarnClickWhat", "manaWarnX",
            "manaWarnY" },
            placement = { "manaWarnX", "manaWarnY" } },
        -- The shield watch (Elements/ShieldWatch.lua), the player only: the
        -- shields' icons and the amount left; last, as it is long.
        { id = "shields", keys = { "shieldsEnabled", "shieldsPriest", "shieldsMage", "shieldsWarlock", "shieldsItems",
            "shieldsExtra", "shieldsHideInBuffs", "shieldsSize", "shieldsSpacing", "shieldsGrowth",
            "shieldsAnchor", "shieldsX", "shieldsY", "shieldsFramePoint", "shieldsPoint", "shieldsFrameX",
            "shieldsFrameY", "shieldsTotal", "shieldsTotalPoint", "shieldsTotalX",
            "shieldsTotalY", "shieldsTotalFont", "shieldsTotalSize", "shieldsTotalOutline", "shieldsTotalColor",
            "shieldsSwipe", "shieldsTime", "shieldsTimePoint", "shieldsTimeX", "shieldsTimeY", "shieldsTimeFont",
            "shieldsTimeSize", "shieldsTimeOutline", "shieldsTimeColor", "shieldsBar", "shieldsBarStyle", "shieldsBarWidth",
            "shieldsBarHeight", "shieldsBarAnchor", "shieldsBarX", "shieldsBarY", "shieldsBarFreeX", "shieldsBarFreeY",
            "shieldsBarColorMode", "shieldsBarColor" },
            placement = { "shieldsGrowth", "shieldsAnchor", "shieldsX", "shieldsY", "shieldsFramePoint", "shieldsPoint",
                "shieldsFrameX", "shieldsFrameY", "shieldsTotalPoint", "shieldsTotalX", "shieldsTotalY",
                "shieldsTimePoint", "shieldsTimeX", "shieldsTimeY", "shieldsBarAnchor", "shieldsBarX", "shieldsBarY",
                "shieldsBarFreeX", "shieldsBarFreeY" } },
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
    if tab.custom then return true end
    for _, sec in ipairs(tab.sections) do
        for _, key in ipairs(sec.keys) do
            if ns.Settings.AppliesTo(ns.Settings.Get(key), scope) then return true end
        end
    end
    return false
end

function Schema.Tabs(scope)
    local source = scope == "general" and Schema.GENERAL or scope == "profiles" and Schema.PROFILES or Schema.FRAME
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
