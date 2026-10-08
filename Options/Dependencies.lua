local _, ns = ...

-- Which rows of the unit frames' window mean something now
-- (Options/Window.lua greys the others; they stay in place, their values
-- kept): a row whose switch is off, or whose mode leaves it without
-- effect. Each rule names what the code reads: a row greys only where
-- its setting truly does nothing. A parent the page does not have (the
-- General page holds no frame switches) leaves its rows alone. On the
-- General page a row stays active while any frame's own value of the
-- parent makes it mean something there: General's value is inherited,
-- the row still reaches that frame.
local Config = ns.Config
local ACTIVE = ns.Options.ROW_ACTIVE

local function applies(scope, key) return ns.Settings.AppliesTo(ns.Settings.Get(key), scope) end

-- A test of the parents `keys` on one page, widened on General to every
-- frame that has one of them.
local function anywhere(keys, test)
    return function(scope)
        if test(scope) then return true end
        if scope ~= "general" then return false end
        for _, frame in ipairs(ns.Settings.SCOPES) do
            if frame ~= "general" then
                for _, key in ipairs(keys) do
                    if applies(frame, key) then
                        if test(frame) then return true end
                        break
                    end
                end
            end
        end
        return false
    end
end

-- Tests: (scope) -> whether the rows mean something on that page.
local function on(key)
    return anywhere({ key }, function(scope) return not applies(scope, key) or Config.Get(scope, key) == true end)
end
local function is(key, value)
    return anywhere({ key }, function(scope) return not applies(scope, key) or Config.Get(scope, key) == value end)
end
local function isNot(key, value)
    return anywhere({ key }, function(scope) return not applies(scope, key) or Config.Get(scope, key) ~= value end)
end
-- Any of the switches the page has on (none on the page: alone).
local function anyOn(keys)
    return anywhere(keys, function(scope)
        local present = false
        for _, key in ipairs(keys) do
            if applies(scope, key) then
                present = true
                if Config.Get(scope, key) == true then return true end
            end
        end
        return not present
    end)
end

local function auraRows(group, except)
    local keys = {}
    for _, def in ipairs(ns.Settings.All()) do
        local rest = def.key:match("^" .. group .. "(%u%a*)$")
        if rest and rest ~= "Enabled" and not except[rest] then keys[#keys + 1] = def.key end
    end
    return keys
end

-- A group's free own block (Core/Settings.lua: OwnFramePoint .. OwnPerRow),
-- after the given suffixes.
local OWN_PLACE = { "OwnFramePoint", "OwnPoint", "OwnX", "OwnY", "OwnGrowth", "OwnRowGrowth", "OwnPerRow" }
local function ownRows(group, first)
    local keys = {}
    for _, suffix in ipairs(first or {}) do keys[#keys + 1] = group .. suffix end
    for _, suffix in ipairs(OWN_PLACE) do keys[#keys + 1] = group .. suffix end
    return keys
end

-- Yours placed freely (want true) or with the rest (false) on a page:
-- Free counts only where the client did not refuse its own container
-- (Elements/AuraContainers.lua), elsewhere yours stay with the rest.
local function placedFreely(group, want)
    local key = group .. "OwnPlacement"
    return anywhere({ key }, function(scope)
        if not applies(scope, key) then return true end
        local free = Config.Get(scope, key) == "FREE" and not ns.AuraContainers.OwnRefusedOn(scope, group)
        return free == want
    end)
end

local function iconRows(prefix, extra)
    local keys = { prefix .. "Size", prefix .. "FramePoint", prefix .. "Point", prefix .. "X", prefix .. "Y" }
    for _, key in ipairs(extra or {}) do keys[#keys + 1] = key end
    return keys
end

-- { test, rows }: every test of a row must pass.
local RULES = {
    -- Elements/Border.lua: a hidden border has no size (Border.Size 0),
    -- and the gold style paints its own shades.
    { on("borderShow"), { "borderStyle", "borderSize", "borderPadding", "borderColor" } },
    { isNot("borderStyle", "GOLD"), { "borderColor" } },
    { on("shadowEnabled"), { "shadowAlpha", "shadowSize" } },
    { on("titleClassIcon"), { "classIconSize", "classIconX", "classIconY", "classIconRing", "classIconRingColor" } },
    { isNot("classIconRing", 0), { "classIconRingColor" } },
    -- Elements/Health.lua: the fixed colour only for STATIC.
    { is("healthColorMode", "STATIC"), { "healthColor" } },
    { on("absorbEnabled"), { "absorbMode", "absorbColor" } },
    { on("healPrediction"), { "healOverflow", "healBeyond", "healMyColor", "healOtherColor", "powerMatchesHealth" } },
    -- Units/Single.lua: the lane only with heal prediction and overflow.
    { on("healOverflow"), { "powerMatchesHealth" } },
    -- Everything on the power bar goes with it.
    { on("powerEnabled"), { "powerPercent", "powerHideEmpty", "powerCostPrediction", "powerCostColor", "druidMana",
        "druidManaHeight", "textPowerLeft", "textPowerCenter", "textPowerRight" } },
    { on("powerCostPrediction"), { "powerCostColor" } },
    { on("druidMana"), { "druidManaHeight" } },
    { on("powerEnabled"), { "fsrEnabled", "fsrSpark", "fsrSparkDirection", "fsrSparkWidth", "fsrText", "fsrTextPoint",
        "fsrTextTenths", "fsrDim", "fsrDimAlpha" } },
    { on("fsrEnabled"), { "fsrSpark", "fsrSparkDirection", "fsrSparkWidth", "fsrText", "fsrTextPoint",
        "fsrTextTenths", "fsrDim", "fsrDimAlpha" } },
    { on("fsrSpark"), { "fsrSparkDirection", "fsrSparkWidth" } },
    { on("fsrText"), { "fsrTextPoint", "fsrTextTenths" } },
    { on("fsrDim"), { "fsrDimAlpha" } },
    { isNot("portraitMode", "OFF"), { "portraitStyle" } },
    -- Elements/Classification.lua: the ring has a size, the marker a
    -- place; its own point only at a point of the frame.
    { on("eliteMarker"), { "eliteMarkerStyle", "eliteBorderSize", "eliteMarkerFramePoint", "eliteMarkerPoint",
        "eliteMarkerX", "eliteMarkerY", "eliteMarkerSize" } },
    { is("eliteMarkerStyle", "BORDER"), { "eliteBorderSize" } },
    { is("eliteMarkerStyle", "MARKER"), { "eliteMarkerFramePoint", "eliteMarkerPoint", "eliteMarkerX", "eliteMarkerY",
        "eliteMarkerSize" } },
    { isNot("eliteMarkerFramePoint", "AUTO"), { "eliteMarkerPoint" } },
    -- Units/PartyPets.lua: the side only beside the owners. Show when
    -- solo needs no "show player": a solo header lists you anyway.
    { on("partyShowPets"), { "partyPetLayout", "partyPetSide", "partyPetWidth", "partyPetHeight", "partyPetGap",
        "partyPetsX", "partyPetsY", "partyPetAuras", "partyPetAuraSize", "partyPetAuraMax", "partyPetAuraSide",
        "partyPetAuraX", "partyPetAuraY" } },
    { is("partyPetLayout", "BESIDE"), { "partyPetSide" } },
    { on("partyPetAuras"), { "partyPetAuraSize", "partyPetAuraMax", "partyPetAuraSide", "partyPetAuraX",
        "partyPetAuraY" } },
    { on("partyTargets"), { "partyTargetSide", "partyTargetWidth", "partyTargetHeight", "partyTargetX",
        "partyTargetY" } },
    { on("buffsEnabled"), auraRows("buffs", {}) },
    { on("buffsEnabled"), { "weaponEnchants" } },
    { on("debuffsEnabled"), auraRows("debuffs", {}) },
    { on("dispelsEnabled"), auraRows("dispels", {}) },
    { on("buffsHighlightOwn"), ownRows("buffs", { "OwnSize", "OwnSameRow", "OwnPlacement" }) },
    { on("debuffsHighlightOwn"), ownRows("debuffs", { "OwnSize", "OwnSameRow", "OwnPlacement" }) },
    -- Elements/Auras.lua: placed freely, yours share no rows with the rest,
    -- and their own place means something only then.
    { placedFreely("buffs", false), { "buffsOwnSameRow" } },
    { placedFreely("debuffs", false), { "debuffsOwnSameRow" } },
    { placedFreely("buffs", true), ownRows("buffs") },
    { placedFreely("debuffs", true), ownRows("debuffs") },
    -- Elements/AuraButton.lua: without a border its colours are not seen;
    -- the caster border still puts your own buffs first (Elements/Auras.lua).
    { on("auraBorder"), { "auraBorderSize", "buffsOwnBorderColor", "buffsOtherBorderColor" } },
    { on("buffsCasterBorder"), { "buffsOwnBorderColor", "buffsOtherBorderColor" } },
    -- Hiding Blizzard's castbar does not depend on ours.
    { on("castbarEnabled"), { "castbarAlwaysShow", "castbarPosition", "castbarDock", "castbarHeight", "castbarIcon",
        "castbarName", "castbarTime", "castbarX", "castbarY" } },
    { is("castbarPosition", "DETACHED"), { "castbarX", "castbarY" } },
    { on("threatBar"), { "threatBarHeight", "threatBarWarn", "threatBarRole", "threatBarSolo" } },
    { on("combatIcon"), iconRows("combatIcon") },
    { on("pvpIcon"), iconRows("pvpIcon", { "pvpIconNPC" }) },
    { on("raidMarker"), iconRows("raidMarker") },
    { on("petHappiness"), iconRows("petHappiness", { "petHappinessHideHappy" }) },
    { on("comboPoints"), { "comboHideEmpty", "comboShape", "comboSize", "comboSpacing", "comboColor",
        "comboFramePoint", "comboPoint", "comboX", "comboY" } },
    { on("totemsEnabled"), { "totemsSize", "totemsSpacing", "totemsDirection", "totemsFramePoint", "totemsPoint",
        "totemsX", "totemsY" } },
    { anyOn({ "statusCombat", "statusResting" }), iconRows("status") },
    -- The swords: the combat icon's (other frames), the status icon's
    -- (the player's).
    { anyOn({ "combatIcon", "statusCombat" }), { "combatAnimation" } },
    { anyOn({ "groupLeader", "groupReadyCheck", "groupResurrect", "groupRole" }), iconRows("groupIcon") },
    { on("rangeFade"), { "rangeAlpha" } },
    { on("targetHighlight"), { "targetHighlightColor", "targetHighlightSize" } },
    { on("combatFeedback"), { "combatFeedbackPoint", "combatFeedbackX", "combatFeedbackY", "combatFeedbackFont",
        "combatFeedbackSize", "combatFeedbackOutline" } },
    { on("playerFadeOOC"), { "playerFadeAlpha", "playerFadeTarget", "playerFadeGroup", "playerFadePet" } },
    { on("minimapShow"), { "minimapAngle" } },
}

local tests = {}
for _, rule in ipairs(RULES) do
    for _, key in ipairs(rule[2]) do
        assert(ns.Settings.Get(key), "dependency: unknown setting " .. key)
        tests[key] = tests[key] or {}
        table.insert(tests[key], rule[1])
    end
end
for key, list in pairs(tests) do
    local before = ACTIVE[key]
    ACTIVE[key] = function(scope)
        if before and not before(scope) then return false end
        for _, test in ipairs(list) do
            if not test(scope) then return false end
        end
        return true
    end
end
