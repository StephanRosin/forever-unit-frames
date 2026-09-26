local _, ns = ...
local Schema = {}
ns.Schema = Schema

-- The unit's outer border and its shadow: General > Appearance and each
-- frame's Layout tab.
local BORDER_KEYS = { "borderShow", "borderStyle", "borderSize", "borderPadding", "borderColor" }
local SHADOW_KEYS = { "shadowEnabled", "shadowAlpha", "shadowSize" }

Schema.GENERAL = {
    { id = "appearance", sections = {
        -- action: a two-click button under the rows (Options/Window.lua).
        { id = "font", keys = { "fontFace", "fontSize", "fontOutline", "fontShadow", "showSurname" },
            action = "applyFontToFrames" },
        { id = "titleText", keys = { "titleClassIcon", "classIconSize", "classIconX", "classIconY",
            "classIconRing", "classIconRingColor" } },
        { id = "bars", keys = { "barTexture", "backgroundColor" } },
        { id = "border", keys = BORDER_KEYS },
        { id = "shadow", keys = SHADOW_KEYS },
        { id = "shape", keys = { "cornerRadius" } },
        { id = "minimap", keys = { "minimapShow", "minimapAngle" } },
    } },
    { id = "colors", sections = {
        { id = "health", keys = { "healthColorMode", "healthColor" } },
        { id = "absorbs", keys = { "absorbColor" } },
        { id = "healPrediction", keys = { "healMyColor", "healOtherColor" } },
    } },
    { id = "profile", custom = "profile" },
}

Schema.FRAME = {
    { id = "layout", sections = {
        { id = "frame", keys = { "enabled" } },
        { id = "size", keys = { "width", "height" } },
        { id = "barHeights", keys = { "titlePercent", "healthPercent", "powerPercent", "powerEnabled" } },
        { id = "portrait", keys = { "portraitMode", "portraitStyle" } },
        { id = "indicators", keys = { "eliteMarker", "combatFeedback" } },
        { id = "statusIcons", keys = { "statusCombat", "statusResting", "statusSize", "statusFramePoint",
            "statusPoint", "statusX", "statusY" } },
        { id = "border", keys = BORDER_KEYS },
        { id = "shadow", keys = SHADOW_KEYS },
        { id = "group", keys = { "partyOrientation", "partySpacing", "partyShowPlayer", "partyShowSolo" } },
        { id = "pets", keys = { "partyShowPets", "partyPetHeight", "partyPetAuras" } },
        { id = "position", keys = { "x", "y" } },
    } },
    { id = "bars", sections = {
        { id = "health", keys = { "healthColorMode", "healthColor" } },
        { id = "textures", keys = { "barTexture", "backgroundColor" } },
        { id = "absorbs", keys = { "absorbEnabled", "absorbColor" } },
        { id = "healPrediction", keys = { "healPrediction", "healOverflow", "powerMatchesHealth", "healMyColor", "healOtherColor" } },
        { id = "shape", keys = { "cornerRadius" } },
    } },
    { id = "text", sections = {
        { id = "titleText", keys = { "titleText", "titleColorMode", "titleClassIcon", "classIconSize", "classIconX",
            "classIconY", "classIconRing", "classIconRingColor" } },
        { id = "healthText", keys = { "textHealthLeft", "textHealthRight" } },
        { id = "powerText", keys = { "textPowerLeft", "textPowerRight" } },
        { id = "font", keys = { "fontFace", "fontSize", "fontOutline", "fontShadow", "showSurname" } },
    } },
    { id = "auras", sections = {
        { id = "buffs", keys = { "buffsEnabled", "buffsOnlyMine", "buffsShowTime", "buffsAnchor", "buffsFramePoint",
            "buffsPoint", "buffsX", "buffsY", "buffsGrowth", "buffsRowGrowth", "buffsSize", "buffsSpacing",
            "buffsPerRow", "buffsMax", "buffsHighlightOwn", "buffsOwnSize" } },
        { id = "debuffs", keys = { "debuffsEnabled", "debuffsOnlyMine", "debuffsDispellable", "debuffsShowTime",
            "debuffsAnchor", "debuffsFramePoint", "debuffsPoint", "debuffsX", "debuffsY", "debuffsGrowth",
            "debuffsRowGrowth", "debuffsSize", "debuffsSpacing", "debuffsPerRow", "debuffsMax", "debuffsHighlightOwn",
            "debuffsOwnSize" } },
        { id = "totems", keys = { "totemsEnabled", "totemsSize", "totemsSpacing", "totemsFramePoint", "totemsPoint",
            "totemsX", "totemsY" } },
    } },
    { id = "castbar", sections = {
        { id = "castbar", keys = { "castbarEnabled", "castbarAlwaysShow", "hideBlizzardCastbar", "castbarPosition", "castbarDock",
            "castbarHeight" } },
        { id = "castbarContent", keys = { "castbarIcon", "castbarName", "castbarTime" } },
        { id = "castbarDetached", keys = { "castbarX", "castbarY" } },
    } },
}

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
