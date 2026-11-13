-- Blizzard's totem flyout opens above our frames (Core/Blizzard.lua).
local M = H.M
local ns = H.LoadAddon()
local bar = CreateFrame("Frame", "MultiCastActionBarFrame", UIParent)
local flyout = CreateFrame("Frame", "MultiCastFlyoutFrame", bar)
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
H.check("one strata above the unit frames", flyout:GetFrameStrata(), "HIGH")
H.check("no errors", #M.errors, 0)
