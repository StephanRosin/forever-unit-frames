local _, ns = ...

-- 0.23.0 ships a revised look (Core/Preset.lua) for new installs only
-- (decision 77). A unit frame profile saved before keeps the look it had:
-- on load, every value that would change from 0.22.0's shipped look to
-- this one, and that the profile does not set itself, is stored as an
-- override holding 0.22.0's value. Once: SavedVariables then carry
-- presetVersion (Core/Storage.lua), and a profile with it is read as it is.
--
-- Which profiles count as "before":
-- * a SavedVariables profile without presetVersion, or with an older one;
-- * the old macro backup (it predates this version by far).
-- A fresh install has no profile: it gets the revised look.
-- Strings carry no version of the look, only overrides (the codec's
-- version is its format's): an imported string, and a storage provider's,
-- are read against the look of the version reading them. An exported 0.22
-- string imported here may therefore look slightly different where it
-- relied on 0.22.0's shipped values. Accepted: the string keeps what its
-- author set, and an export made from 0.23.0 on carries the kept values.
--
-- Without the shipped look (the tests' plain defaults) nothing changes.
local Upgrade = { VERSION = "0.23.0" }
ns.PresetUpgrade = Upgrade

-- Core/Preset.lua as 0.22.0 shipped it (data; never edit).
local PRESET_0_22 = {
    general = {
        barTexture = "Raid",
        borderStyle = "GOLD",
        classIconSize = 30,
        classIconY = -9,
        combatAnimation = "DUEL",
        fontOutline = "OUTLINE",
        fontShadow = true,
        minimapAngle = 282,
        rangeAlpha = 70,
        rangeFriendlyMode = "YARDS",
        rangeHostileYards = 40,
        shadowAlpha = 16,
        shadowEnabled = true,
        shadowSize = 9,
    },
    player = {
        buffsAnchor = "FRAME",
        buffsEnabled = true,
        buffsHideTracking = true,
        buffsHighlightOwn = true,
        buffsMax = 24,
        buffsOwnSize = 25,
        buffsPerRow = 9,
        buffsSize = 18,
        buffsSpacing = 4,
        buffsY = 3,
        castbarAlwaysShow = true,
        castbarEnabled = true,
        castbarX = -4,
        cornerRadius = 10,
        debuffsAnchor = "CASTBAR",
        debuffsFramePoint = "BOTTOMLEFT",
        debuffsHighlightOwn = true,
        debuffsMax = 24,
        debuffsPoint = "TOPLEFT",
        debuffsSize = 18,
        debuffsX = -1,
        debuffsY = -3,
        healthColorMode = "CLASS",
        healthPercent = 79,
        height = 70,
        portraitMode = "LEFT",
        portraitStyle = "3D",
        powerPercent = 20,
        pvpIcon = true,
        pvpIconSize = 25,
        statusSize = 21,
        statusX = 49,
        statusY = -1,
        textPowerLeft = "CURRENT_MAX",
        textPowerRight = "PERCENT",
        threatBarSolo = true,
        titlePercent = 24,
        width = 300,
        x = -400,
    },
    target = {
        buffsAnchor = "FRAME",
        buffsHideTracking = true,
        buffsHighlightOwn = true,
        buffsMax = 24,
        buffsPerRow = 5,
        buffsSize = 18,
        buffsX = -1,
        buffsY = 3,
        castbarAlwaysShow = true,
        castbarX = 366,
        combatFeedback = true,
        cornerRadius = 10,
        debuffsAnchor = "CASTBAR",
        debuffsFramePoint = "BOTTOMLEFT",
        debuffsMax = 24,
        debuffsPerRow = 12,
        debuffsPoint = "TOPLEFT",
        debuffsRowGrowth = "DOWN",
        debuffsSize = 18,
        debuffsSpacing = 4,
        debuffsY = -4,
        healthColorMode = "CLASS",
        healthPercent = 68,
        height = 70,
        portraitMode = "LEFT",
        portraitStyle = "3D",
        pvpIcon = true,
        textPowerLeft = "CURRENT_MAX",
        textPowerRight = "PERCENT",
        width = 300,
        x = 400,
    },
    targettarget = {
        buffsMax = 9,
        buffsSize = 14,
        debuffsSize = 14,
        healthColorMode = "CLASS",
        showSurname = false,
        x = 536,
        y = -304,
    },
    pet = {
        width = 115,
        x = -624,
        y = -324,
    },
    focus = {
        combatFeedback = true,
        powerPercent = 21,
        x = 520,
        y = 232,
    },
    party = {
        buffsAnchor = "FRAME",
        buffsFramePoint = "TOPLEFT",
        buffsGrowth = "LEFT",
        buffsHidePermanent = true,
        buffsHighlightOwn = true,
        buffsMax = 8,
        buffsOwnSize = 28,
        buffsPoint = "TOPRIGHT",
        buffsSize = 22,
        buffsSpacing = 0,
        buffsX = 0,
        castbarAlwaysShow = true,
        combatFeedback = true,
        cornerRadius = 10,
        debuffsDispellable = true,
        debuffsFramePoint = "BOTTOMLEFT",
        debuffsGrowth = "LEFT",
        debuffsOwnSize = 25,
        debuffsPoint = "TOPRIGHT",
        debuffsSize = 22,
        debuffsX = -3,
        debuffsY = 19,
        healthColorMode = "CLASS",
        healthPercent = 17,
        height = 53,
        partyPetAuras = true,
        partyPetHeight = 23,
        partyShowPets = true,
        partySpacing = 25,
        partyTargetHeight = 22,
        partyTargetY = -28,
        powerPercent = 9,
        showSurname = false,
        textHealthLeft = "CURRENT_MAX",
        textPowerLeft = "CURRENT_MAX",
        textPowerRight = "PERCENT",
        titlePercent = 26,
        width = 200,
        x = -709,
        y = 150,
    },
}
Upgrade.PRESET_0_22 = PRESET_0_22

local function same(a, b)
    if type(a) == "table" and type(b) == "table" then
        for i = 1, 4 do if a[i] ~= b[i] then return false end end
        return true
    end
    return a == b
end

local function copy(v)
    if type(v) == "table" then return { v[1], v[2], v[3], v[4] } end
    return v
end

-- Whether a shipped look is loaded at all.
function Upgrade.Active()
    return ns.Settings.presetApplied == true
end

-- Whether SavedVariables db hold a profile from before the revised look.
function Upgrade.Due(db)
    if not Upgrade.Active() or type(db) ~= "table" then return false end
    local marked = db.presetVersion
    return type(marked) ~= "string" or ns.News.Compare(marked, Upgrade.VERSION) < 0
end

-- Keeps profile p (sanitised, every scope a table) looking as under
-- 0.22.0's shipped look. Returns the number of overrides it stored.
-- General first: a general override is what the frames inherit, and it
-- hides a frame's own shipped default; the frames are compared after.
function Upgrade.Apply(p)
    if not Upgrade.Active() then return 0 end
    local S, Config = ns.Settings, ns.Config
    local old = S.DefaultsUnder(PRESET_0_22)
    local before = {}
    for _, scope in ipairs(S.SCOPES) do
        before[scope] = {}
        for _, def in ipairs(S.All()) do
            if S.AppliesTo(def, scope) then before[scope][def.key] = Config.ValueIn(p, scope, def.key, old) end
        end
    end
    local stored = 0
    for _, scope in ipairs(S.SCOPES) do
        for key, was in pairs(before[scope]) do
            if p[scope][key] == nil and not same(Config.ValueIn(p, scope, key), was) then
                p[scope][key] = copy(was)
                stored = stored + 1
            end
        end
    end
    return stored
end
