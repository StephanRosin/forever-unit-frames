-- The Profiles page (Options/Window.lua): the named unit frame profiles,
-- and what General lost to it.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local O, L = ns.Options, ns.L
local function click(button) button:GetScript("OnClick")(button) end
-- As in the client: ClearFocus fires OnEditFocusLost, which commits the text.
local function clientFocus(box)
    local clear = box.ClearFocus
    function box:ClearFocus() local had = self._focus; clear(self); if had then self:GetScript("OnEditFocusLost")(self) end end
end

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
clientFocus(O.profileName)

local function typeName(text) M.Type(O.profileName, text) end
local function say() return O.profileMessage:GetText() end
typeName("   ")
click(O.profileSaveButton)
H.check("empty: message", say(), L.PROFILE_NAME_EMPTY)
typeName(("x"):rep(41))
click(O.profileSaveButton)
H.check("too long: message", say(), L.PROFILE_NAME_TOO_LONG:format(40))
typeName("X")
click(O.profileRenameButton)
H.check("Rename on Default: message", say(), L.PROFILE_DEFAULT_FIXED)
M.LeaveBox(O.profileName)
O.profileName:SetText("")

typeName("Healer")
click(O.profileSaveButton)
H.check("saved and active", ns.UnitProfiles.Active(), "Healer")
H.check("picker shows it", O.profilePicker.button.text:GetText(), "Healer")
H.check("name box emptied", O.profileName:GetText(), "")
H.check("saved message", O.profileMessage:GetText(), L.PROFILE_SAVED:format("Healer"))
H.check("rename allowed now", O.profileRenameButton._enabled, true)
H.check("delete allowed now", O.profileDeleteButton._enabled, true)
typeName("healer")
click(O.profileSaveButton)
H.check("taken: message", O.profileMessage:GetText(), L.PROFILE_NAME_TAKEN)

typeName("Tank")
M.PressEnter(O.profileName)
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

-- Switching through the picker's own set; it disarms Delete.
ns.UnitProfiles.SaveAs("A"); ns.UnitProfiles.SaveAs("B")
click(O.profileDeleteButton)   -- armed on B
O.profilePicker.opts.set("A")
H.check("picker: switched", ns.UnitProfiles.Active(), "A")
H.check("picker: message", say(), L.PROFILE_SWITCHED:format("A"))
click(O.profileDeleteButton)
H.checkTrue("picker: one click deletes nothing", ForeverUnitFramesDB.profiles.A and ForeverUnitFramesDB.profiles.B)
click(O.profileDeleteButton)
H.check("picker: second click deletes A", ForeverUnitFramesDB.profiles.A, nil)

-- An armed Delete stays armed (red) across CONFIG_CHANGED refreshes.
ns.UnitProfiles.SaveAs("C")
click(O.profileDeleteButton)
local armedText = O.profileDeleteButton.text:GetText()
ns.Fire("CONFIG_CHANGED")
H.check("armed text kept", O.profileDeleteButton.text:GetText(), armedText)
