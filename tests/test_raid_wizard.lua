-- The raid frames' setup wizard (Raid/Wizard.lua): opens once by itself
-- for a character with an untouched raid profile when the raid window
-- opens after the login loading screen; any time from the Profiles page's
-- button. Steps: role template, look, raid sizes, click-casting
-- suggestions, summary; Apply sets all of it as one change.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
M.known[2061], M.known[139], M.known[527] = true, true, true
_G.ForeverUnitFramesDB = { raid = { ["Other-Testrealm"] = { r10 = { cellWidth = 120 } } } }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RO, RC, L, T, W = ns.RaidOptions, ns.RaidConfig, ns.L, ns.RaidTemplates, ns.RaidWizard
local key = ns.RaidProfiles.CharKey()

local function click(button) button:GetScript("OnClick")(button) end
local list
local function pick(row, text)
    click(row.button)
    for _, r in ipairs(list.rows) do
        if r:IsShown() and r.text:GetText() == text then return click(r) end
    end
    error("no item " .. text)
end

-- Before the loading screen is gone: not by itself.
RO.Open(20)
list = ns.Widgets.list
H.check("not before the loading screen", W.IsOpen(), false)
H.check("nothing remembered", ForeverUnitFramesDB.raidWizardSeen and ForeverUnitFramesDB.raidWizardSeen[key], nil)
RO.Close()
M.FireEvent("LOADING_SCREEN_DISABLED")

-- Untouched: opens with the raid window, once.
H.checkTrue("untouched", W.Untouched())
RO.Open(20)
H.check("opened by itself", W.IsOpen(), true)
H.check("remembered", ForeverUnitFramesDB.raidWizardSeen[key], true)
H.check("named", W.frame:GetName(), "ForeverUnitFramesRaidWizard")
H.checkTrue("ESC closes it", (function()
    for _, n in ipairs(UISpecialFrames) do if n == "ForeverUnitFramesRaidWizard" then return true end end
end)())
W.Close()
RO.Close()
RO.Open(20, "profiles")
H.check("only once", W.IsOpen(), false)

-- Step 1: the suggested role.
click(ns.RaidTemplatesPage.wizardButton)
H.check("the Profiles page's button opens it", W.IsOpen(), true)
H.check("first step", W.step, 1)
H.check("heading", W.frame.heading:GetText(), L.RAID_WIZARD_STEP:format(1, 5, L.RAID_WIZARD_STEP_role))
H.check("suggested role", W.rolePicker.button.text:GetText(), "Role: Healer")
H.check("the text names the role alone", W.texts.role:GetText(), L.RAID_WIZARD_TEXT_role:format("Healer"))
H.check("no back on the first step", W.backButton:IsEnabled(), false)
H.check("no apply before the summary", W.applyButton:IsShown(), false)
-- Step 2: the look.
click(W.nextButton)
H.check("look: kept by default", W.lookPicker.button.text:GetText(), L.RAID_WIZARD_KEEP)
pick(W.lookPicker, "Look: Flat")
-- Step 3: the sizes.
click(W.nextButton)
H.check("sizes: this size", W.sizePicker.button.text:GetText(), L.RAID_TEMPLATE_THIS_SIZE:format("20 players"))
-- Step 4: click-casting suggestions for the spells the book knows.
click(W.nextButton)
H.check("three suggestions", W.clickRows[3]:IsShown() and not W.clickRows[4]:IsShown(), true)
H.check("a suggestion's slot", W.clickRows[1].label:GetText(), "Left button, Shift-click")
H.check("its spell", W.clickRows[1].spell:GetText(), "Cast a spell: Flash Heal")
-- Nothing rebinds unless ticked: every suggestion starts unticked.
for i = 1, 3 do H.check("unticked at first " .. i, W.clickRows[i].box:GetChecked(), false) end
click(W.clickRows[1].box)
click(W.clickRows[3].box)
H.check("ticked", W.clickRows[1].box:GetChecked(), true)
-- Back and forth keeps the choices.
click(W.backButton)
click(W.nextButton)
H.check("still ticked", W.clickRows[3].box:GetChecked(), true)
H.check("still unticked", W.clickRows[2].box:GetChecked(), false)
-- Step 5: the summary names each binding's slot; nothing set yet.
click(W.nextButton)
H.check("summary", W.summary:GetText(), table.concat({
    L.RAID_WIZARD_SUMMARY_TEMPLATE:format("Role: Healer", "20 players"),
    L.RAID_WIZARD_SUMMARY_TEMPLATE:format("Look: Flat", "20 players"),
    L.RAID_WIZARD_SUMMARY_CLICKS:format(2),
    L.RAID_WIZARD_SUMMARY_CLICK:format("Left button, Shift-click", "Cast a spell: Flash Heal"),
    L.RAID_WIZARD_SUMMARY_CLICK:format("Right button, Ctrl-click", "Cast a spell: Dispel Magic") }, "\n"))
H.check("nothing set before Apply", RC.Get("r20", "cellCornerRadius"), 3)
H.check("no binding before Apply", RC.Get("general", "click1Shift"), "")
-- In combat Apply is off.
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("apply off in combat", W.applyButton:IsEnabled(), false)
H.check("and does nothing", W.Apply(), false)
M.combat = false
M.FireEvent("PLAYER_REGEN_ENABLED")
H.check("apply again", W.applyButton:IsEnabled(), true)
click(W.applyButton)
H.check("closed", W.IsOpen(), false)
H.check("role applied", RC.Get("r20", "secondLine"), "DEFICIT")
H.check("role: wider", RC.Get("r20", "cellWidth"), 104)
H.check("look applied", RC.Get("r20", "cellCornerRadius"), 0)
H.check("other sizes untouched", RC.Get("r10", "cellCornerRadius"), 4)
H.check("ticked binding", RC.Get("general", "click1Shift"), "spell:Flash Heal")
H.check("unticked binding left", RC.Get("general", "click1Ctrl"), "")
H.check("ticked dispel", RC.Get("general", "click2Ctrl"), "spell:Dispel Magic")
H.check("left click still targets", RC.Get("general", "click1"), "target")
-- One change: the Templates section's Undo takes all of it back.
local P = ns.RaidTemplatesPage
H.check("undo offered in the Templates section", P.undoButton:IsEnabled(), true)
click(P.undoButton)
H.check("undone by the button", T.CanUndo(), false)
H.check("role undone", RC.Get("r20", "cellWidth"), 88)
H.check("look undone", RC.Get("r20", "cellCornerRadius"), 3)
H.check("binding undone", RC.Get("general", "click1Shift"), "")

-- All sizes, no role, no look: only bindings (none for keep).
click(ns.RaidTemplatesPage.wizardButton)
pick(W.rolePicker, L.RAID_WIZARD_KEEP)
click(W.nextButton)
click(W.nextButton)
pick(W.sizePicker, "All sizes")
click(W.nextButton)
H.check("no suggestions without a role", W.clickRows[1]:IsShown(), false)
H.check("says so", W.texts.clicks:GetText(), L.RAID_WIZARD_TEXT_NO_CLICKS)
click(W.nextButton)
H.check("nothing to change", W.summary:GetText(), L.RAID_WIZARD_SUMMARY_NOTHING)
-- Applied anyway: no word of an Undo (there is nothing to take back).
local said = #M.chat
click(W.applyButton)
H.check("nothing chosen: closed", W.IsOpen(), false)
H.check("nothing chosen: one line", #M.chat, said + 1)
H.check("nothing chosen: no undo promised", M.chat[#M.chat]:find(L.RAID_WIZARD_DONE, 1, true), nil)
H.checkTrue("nothing chosen: says so", M.chat[#M.chat]:find(L.RAID_WIZARD_SUMMARY_NOTHING, 1, true))
W.Close()
RO.Close()

-- A character who changed anything: never by itself.
local ns2 = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
_G.ForeverUnitFramesDB = { raid = { [key] = { r10 = { cellWidth = 120 } } } }
M.FireEvent("PLAYER_LOGIN")
M.FireEvent("LOADING_SCREEN_DISABLED")
M.RunTimers()
ns2.RaidOptions.Open(10)
H.check("changed profile: not by itself", ns2.RaidWizard.IsOpen(), false)
H.check("not remembered either", ForeverUnitFramesDB.raidWizardSeen, nil)
ns2.RaidOptions.Close()

-- The Profiles page's wizard button is locked in combat.
local ns3 = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
_G.ForeverUnitFramesDB = {}
M.FireEvent("PLAYER_LOGIN")
M.FireEvent("LOADING_SCREEN_DISABLED")
M.RunTimers()
local W3, RO3 = ns3.RaidWizard, ns3.RaidOptions
ForeverUnitFramesDB.raidWizardSeen = { [key] = true }
RO3.Open(10, "profiles")
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("wizard button locked in combat", ns3.RaidTemplatesPage.wizardButton:IsEnabled(), false)
M.combat = false
M.FireEvent("PLAYER_REGEN_ENABLED")
H.check("wizard button again", ns3.RaidTemplatesPage.wizardButton:IsEnabled(), true)
RO3.Close()
ForeverUnitFramesDB.raidWizardSeen = nil

-- With UIParent hidden (the interface hidden) it does not open, and is
-- not remembered as seen: it opens the next time.
UIParent:Hide()
RO3.Open(10)
H.check("UIParent hidden: not opened", W3.IsOpen(), false)
H.check("UIParent hidden: not remembered", ForeverUnitFramesDB.raidWizardSeen and ForeverUnitFramesDB.raidWizardSeen[key], nil)
RO3.Close()
UIParent:Show()

-- In combat after a /reload (no PLAYER_REGEN_DISABLED seen): not by
-- itself, and Apply is off when opened by hand.
local ns4 = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
_G.ForeverUnitFramesDB = {}
M.FireEvent("PLAYER_LOGIN")
M.FireEvent("LOADING_SCREEN_DISABLED")
M.RunTimers()
local W4 = ns4.RaidWizard
M.combat = true
ns4.RaidOptions.Open(10)
H.check("combat after a reload: not by itself", W4.IsOpen(), false)
H.check("combat after a reload: not remembered", ForeverUnitFramesDB.raidWizardSeen and ForeverUnitFramesDB.raidWizardSeen[key], nil)
W4.Open()
for _ = 2, #W4.STEPS do click(W4.nextButton) end
H.check("combat after a reload: apply off", W4.applyButton:IsEnabled(), false)
W4.Close()
ns4.RaidOptions.Close()
M.combat = false

-- A template the version refuses: Apply says so, sets nothing, stays open.
local ns5 = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
_G.ForeverUnitFramesDB = {}
M.FireEvent("PLAYER_LOGIN")
M.FireEvent("LOADING_SCREEN_DISABLED")
M.RunTimers()
local W5, T5 = ns5.RaidWizard, ns5.RaidTemplates
T5.Get("healer").values.noSuchKey = 1
W5.Open()
for _ = 2, #W5.STEPS do click(W5.nextButton) end
click(W5.applyButton)
H.check("refused: says so", W5.message:GetText(), L.RAID_TEMPLATE_REFUSED)
H.check("refused: still open", W5.IsOpen(), true)
H.check("refused: nothing set", ns5.RaidConfig.Get("r10", "cellWidth"), 96)
H.check("refused: no undo", T5.CanUndo(), false)
T5.Get("healer").values.noSuchKey = nil
W5.Close()
H.check("no error", #M.errors, 0)
