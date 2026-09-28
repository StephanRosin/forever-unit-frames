-- Combo points on the target frame (Elements/ComboPoints.lua): Blizzard's
-- ComboFrame is concealed with its TargetFrame, so the addon draws them.
-- The count may be secret: each pip is a status bar from i - 1 to i that
-- takes the count as it is.
local M = H.M
local ns = H.LoadAddon()
local S, C, L = ns.Settings, ns.Config, ns.L
C.Use({})
M.units.player = { name = "Rogue", level = 60, class = "ROGUE", className = "Rogue", isPlayer = true,
    health = 1, healthMax = 1, comboMax = 5 }
M.units.target = { name = "Ogre", hostile = true, health = 5, healthMax = 10 }
ns.Single.CreateAll()
local t = ns.Frames.target
local c = t.combo

-- Settings -----------------------------------------------------------------------
for key, code in pairs({ comboPoints = "XE", comboHideEmpty = "XH", comboShape = "XR", comboSize = "XS", comboSpacing = "XD",
    comboColor = "XC", comboFramePoint = "XF", comboPoint = "XO", comboX = "XX", comboY = "XY" }) do
    local def = S.Get(key)
    H.check("code of " .. key, def.code, code)
    H.checkTrue(key .. " on the target", S.AppliesTo(def, "target"))
    H.check(key .. " not on the player", S.AppliesTo(def, "player"), false)
    H.checkTrue(key .. " labelled", L["SETTING_" .. key] ~= "SETTING_" .. key)
end
H.check("on by default", C.Get("target", "comboPoints"), true)
H.checkTrue("only the target frame builds it", c and not ns.Frames.player.combo)

-- Layout -------------------------------------------------------------------------
H.check("five pips for five points", c.count, 5)
H.checkTrue("pip 5 shown", c.pips[5]:IsShown())
H.check("pip 6 hidden", c.pips[6]:IsShown(), false)
local size, spacing = C.Get("target", "comboSize"), C.Get("target", "comboSpacing")
H.check("row width", c.holder:GetWidth(), 5 * size + 4 * spacing)
local point, rel, relPoint = c.holder:GetPoint(1)
H.check("below the block, right-aligned", point .. ">" .. relPoint, "TOPRIGHT>BOTTOMRIGHT")
H.check("hangs from the unit's block", rel, t.unitBox or t)
local lo, hi = c.pips[3]:GetMinMaxValues()
H.check("pip 3 runs from 2 to 3", lo .. "-" .. hi, "2-3")

-- Counts -------------------------------------------------------------------------
M.comboPoints = 0
M.FireEvent("UNIT_POWER_FREQUENT", "player")
H.check("none: hidden", c.holder:IsShown(), false)
M.comboPoints = 3
M.FireEvent("UNIT_POWER_FREQUENT", "player")
H.checkTrue("three: shown", c.holder:IsShown())
H.check("the value reaches every pip", c.pips[1]:GetValue(), 3)
H.check("pip 5 gets it too (empty there)", c.pips[5]:GetValue(), 3)
C.Set("target", "comboHideEmpty", false)
M.comboPoints = 0
M.FireEvent("UNIT_POWER_FREQUENT", "player")
H.checkTrue("keep empty row: shown", c.holder:IsShown())
C.Set("target", "comboHideEmpty", true)
-- Secret: never compared, the row stays up and the pips take it as it is.
M.comboPoints = M.Secret(2)
M.FireEvent("UNIT_POWER_FREQUENT", "player")
H.checkTrue("secret: shown", c.holder:IsShown())
H.check("secret passed on", c.pips[2]:GetValue(), M.comboPoints)
-- Other units' power events change nothing.
M.comboPoints = 0
M.FireEvent("UNIT_POWER_FREQUENT", "target")
H.checkTrue("target's own power event ignored", c.holder:IsShown())
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("a new target without points: hidden", c.holder:IsShown(), false)
-- Switched off.
M.comboPoints = 4
C.Set("target", "comboPoints", false)
H.check("off: hidden", c.holder:IsShown(), false)
C.Set("target", "comboPoints", true)
H.checkTrue("on again", c.holder:IsShown())

-- A bigger maximum (talents): more pips.
M.units.player.comboMax = 6
M.FireEvent("UNIT_MAXPOWER", "player")
H.check("six pips", c.count, 6)
H.checkTrue("pip 6 shown", c.pips[6]:IsShown())
-- Unknown maximum (secret or 0): five.
M.units.player.comboMax = 0
M.FireEvent("UNIT_MAXPOWER", "player")
H.check("unknown maximum: five", c.count, 5)

-- Colour and size.
C.Set("target", "comboColor", { 1, 0, 0, 1 })
H.check("pip colour", c.pips[1]._color[2], 0)
C.Set("target", "comboSize", 14)
H.check("pip size", c.pips[1]:GetWidth(), 14)

-- Round pips: the circular mask on fill and background, and off again.
H.check("square by default", C.Get("target", "comboShape"), "SQUARE")
H.check("square: no mask", c.pips[1].bg:GetNumMaskTextures(), 0)
C.Set("target", "comboShape", "ROUND")
H.check("round: background masked", c.pips[1].bg:GetNumMaskTextures(), 1)
H.check("round: fill masked", c.pips[1]:GetStatusBarTexture():GetNumMaskTextures(), 1)
C.Set("target", "comboSize", 12)
H.check("restyled: still one mask", c.pips[1].bg:GetNumMaskTextures(), 1)
C.Set("target", "comboShape", "SQUARE")
H.check("square again: mask off", c.pips[1].bg:GetNumMaskTextures(), 0)

-- Test mode: three of five.
ns.TestMode.Set(true)
H.checkTrue("test: shown", c.holder:IsShown())
H.check("test: sample", c.pips[1]:GetValue(), ns.ComboPoints.SAMPLE)
ns.TestMode.Set(false)

-- Options: on the target's Status tab.
local found
for _, tab in ipairs(ns.Schema.Tabs("target")) do
    for _, sec in ipairs(tab.sections or {}) do
        if sec.id == "comboPoints" then found = tab.id end
    end
end
H.check("section on the status tab", found, "status")
