-- The power strip's height (Raid/Settings.lua powerStripHeight): a
-- percentage of the cell's height per size; the health bar takes the
-- rest. The default is the fixed share cells had before.
local M = H.M
local ns = H.LoadAddon()
local RC, Cell, RS = ns.RaidConfig, ns.RaidCell, ns.RaidSettings

local def = RS.Get("powerStripHeight")
H.checkTrue("setting exists", def)
H.check("per size", def.scope, "frame")
H.check("a layout setting", def.class, "layout")
H.check("range", def.type .. " " .. def.min .. "-" .. def.max, "int 5-40")
for _, size in ipairs(ns.Raid.SIZES) do
    H.check("default " .. size .. ": today's share", RS.Default(def, ns.Raid.Scope(size)), 10)
end

ns.Config.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()
local C = ns.Config
H.check("power share by default", C.Get("raid", "powerPercent"), 10)
H.check("health share by default", C.Get("raid", "healthPercent"), 90)
RC.Set("r10", "powerStripHeight", 25)
H.check("power share follows", C.Get("raid", "powerPercent"), 25)
H.check("health takes the rest", C.Get("raid", "healthPercent"), 75)
H.check("pets' cells too", C.Get("raidpet", "powerPercent"), 25)
RC.ResetScope("r10")

-- A real cell: the strip's height on the bar.
local header = CreateFrame("Frame", "TestRaidPowerHeight", UIParent, "SecureGroupHeaderTemplate")
header:SetAttribute("template", Cell.TEMPLATE)
header:SetAttribute("showRaid", true)
M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1, assignedRole = "HEALER",
    unit = { health = 60, healthMax = 100, powerType = 0 } } })
header:Show()
local ann = header:GetAttribute("child1")
local height = C.Get("raid", "height")
local function strip() return ann.power:GetHeight() end
H.checkTrue("strip shows", ann.power:IsShown())
H.check("default strip: a tenth", strip(), ns.Pixel.Snap(math.floor(height * 10 / 100), nil, 1))
RC.Set("r10", "powerStripHeight", 40)
Cell.Style(ann)
H.check("40 %: the strip", strip(), ns.Pixel.Snap(math.floor(height * 40 / 100), nil, 1))
H.check("40 %: health takes the rest", ann.health:GetHeight() + strip(), height)
RC.ResetScope("r10")

-- The window greys the height while the strip is off.
local active = ns.RaidOptions.ROW_ACTIVE.powerStripHeight
local edited = ns.Raid.Scope(ns.RaidOptions.Size())
H.checkTrue("height row active with a strip", active())
RC.Set(edited, "powerStrip", "OFF")
H.check("height row greyed without a strip", active(), false)
RC.ResetScope(edited)
