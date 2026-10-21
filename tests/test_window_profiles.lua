-- The Profiles page (Options/Window.lua): the named unit frame profiles,
-- and what General lost to it.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local O, L = ns.Options, ns.L
local function click(button) button:GetScript("OnClick")(button) end

local ids = {}
for _, tab in ipairs(ns.Schema.Tabs("general")) do ids[#ids + 1] = tab.id end
H.check("general tabs", table.concat(ids, ","), "frames,clickCast,appearance,bars,status")
local frames = ns.Schema.Tabs("general")[1]
H.check("minimap last in Frames", frames.sections[#frames.sections].id, "minimap")

H.checkTrue("nav entry", O.Open and (function() O.Open("profiles"); return O.navButtons.profiles end)())
H.check("scope", O.currentScope, "profiles")
H.check("its tab", O.currentTab, "profiles")
H.checkTrue("export moved here", O.exportArea and O.exportArea:IsVisible())
H.checkTrue("frame footer hidden", not O.copyRow:IsShown())
H.check("Default shown localised", O.profilePicker.button.text:GetText(), L.PROFILE_DEFAULT)
H.check("Default cannot be renamed", O.profileRenameButton._enabled, false)
H.check("Default cannot be deleted", O.profileDeleteButton._enabled, false)

O.profileName:SetText("Healer")
click(O.profileSaveButton)
H.check("saved and active", ns.UnitProfiles.Active(), "Healer")
H.check("picker shows it", O.profilePicker.button.text:GetText(), "Healer")
H.check("name box emptied", O.profileName:GetText(), "")
H.check("saved message", O.profileMessage:GetText(), L.PROFILE_SAVED:format("Healer"))
H.check("rename allowed now", O.profileRenameButton._enabled, true)
H.check("delete allowed now", O.profileDeleteButton._enabled, true)
O.profileName:SetText("healer")
click(O.profileSaveButton)
H.check("taken: message", O.profileMessage:GetText(), L.PROFILE_NAME_TAKEN)

O.profileName:SetText("Tank")
click(O.profileRenameButton)
H.check("renamed", ns.UnitProfiles.Active(), "Tank")

-- Combat: the profile events must not enable what the lock disabled.
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("rename locked in combat", O.profileRenameButton._enabled, false)
ns.Fire("UNIT_PROFILES_CHANGED")
H.check("still locked after a refresh", O.profileDeleteButton._enabled, false)
M.SetCombat(false)
H.check("unlocked after combat", O.profileDeleteButton._enabled, true)

click(O.profileDeleteButton)
H.check("armed only", ns.UnitProfiles.Active(), "Tank")
click(O.profileDeleteButton)
H.check("deleted", ns.UnitProfiles.Active(), "Default")
H.check("default shown again", O.profilePicker.button.text:GetText(), L.PROFILE_DEFAULT)
H.check("delete locked on Default", O.profileDeleteButton._enabled, false)
