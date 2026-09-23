local _, ns = ...

-- The look Forever Unit Frames ships with, on top of the plain defaults in
-- Core/Settings.lua: preset[scope][key] = value. Only values that differ
-- from the plain defaults are listed. Saved profiles store differences
-- from these, so changing a value here changes it for everyone who kept
-- the default.
local PRESET = {
    general = {
        -- A stronger blue: the plain pale one vanishes on white or grey
        -- (class colour) health bars.
        absorbColor = { 0.15, 0.45, 1, 0.6 },
        -- Same file as LibSharedMedia's "Blizzard Raid Bar", built in.
        barTexture = "Raid",
        borderStyle = "GOLD",
        classIconY = 0,
        fontOutline = "OUTLINE",
        fontShadow = true,
        shadowAlpha = 13,
        shadowEnabled = true,
    },
    player = {
        buffsAnchor = "FRAME",
        buffsEnabled = true,
        buffsHighlightOwn = true,
        buffsMax = 24,
        buffsOwnSize = 25,
        buffsPerRow = 6,
        buffsSize = 18,
        buffsSpacing = 4,
        buffsY = 3,
        castbarAlwaysShow = true,
        castbarEnabled = true,
        debuffsAnchor = "CASTBAR",
        debuffsFramePoint = "BOTTOMLEFT",
        debuffsHighlightOwn = true,
        debuffsMax = 24,
        debuffsPoint = "TOPLEFT",
        debuffsSize = 18,
        debuffsY = -3,
        healthColorMode = "CLASS",
        healthPercent = 74,
        height = 70,
        portraitMode = "LEFT",
        portraitStyle = "3D",
        textPowerLeft = "CURRENT_MAX",
        textPowerRight = "PERCENT",
        width = 300,
        x = -400,
    },
    target = {
        combatFeedback = true,
        buffsAnchor = "FRAME",
        buffsHighlightOwn = true,
        buffsMax = 24,
        buffsPerRow = 5,
        buffsSize = 18,
        buffsSpacing = 4,
        buffsX = -1,
        castbarAlwaysShow = true,
        castbarX = 366,
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
        healthPercent = 74,
        height = 70,
        portraitMode = "LEFT",
        portraitStyle = "3D",
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
        x = 640,
        y = -256,
    },
    -- Left of the player frame, top edges aligned: the plain default sits
    -- inside the wider shipped player frame.
    pet = {
        x = -622,
        y = -199,
    },
    focus = {
        combatFeedback = true,
        powerPercent = 21,
        x = 575,
        y = 124,
    },
    party = {
        buffsAnchor = "FRAME",
        buffsFramePoint = "RIGHT",
        buffsMax = 8,
        buffsSpacing = 8,
        debuffsDispellable = true,
        healthColorMode = "CLASS",
        height = 65,
        showSurname = false,
        textHealthLeft = "CURRENT_MAX",
        textPowerLeft = "CURRENT_MAX",
        textPowerRight = "PERCENT",
        width = 195,
    },
}

ns.Settings.ApplyPreset(PRESET)
