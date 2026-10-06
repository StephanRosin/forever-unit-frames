-- The ways between the unit frames' options window and the raid one: a
-- button in each window's footer, at the same place (third from the left;
-- tests/test_options_footers.lua). (The raid frames' own minimap button and addon compartment
-- entry: tests/test_raid_minimap_button.lua.)
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local O, RO = ns.Options, ns.RaidOptions

local function click(button, mouseButton) button:GetScript("OnClick")(button, mouseButton) end

-- From the unit frames' window, in its footer.
O.Open()
H.check("raid button", O.raidButton.text:GetText(), "Raid frames…")
H.check("in the footer", O.raidButton:GetParent(), O.unlockButton:GetParent())
H.checkTrue("not in the navigation", O.raidButton:GetParent() ~= O.navButtons.general:GetParent())
click(O.raidButton)
H.check("unit window closed", O.IsOpen(), false)
H.checkTrue("raid window open", RO.IsOpen())

-- And back.
H.check("unit button", RO.unitButton.text:GetText(), "Unit frames…")
click(RO.unitButton)
H.check("raid window closed", RO.IsOpen(), false)
H.checkTrue("unit window open", O.IsOpen())
O.Close()

-- The unit frames' minimap button stays theirs: Shift does not lead to
-- the raid window (the raid frames have a button of their own).
M.shiftDown = true
click(ns.MinimapButton.button, "LeftButton")
H.checkTrue("shift-click: still the unit window", O.IsOpen())
H.check("not the raid window", RO.IsOpen(), false)
O.Close()
ForeverUnitFrames_OnAddonCompartmentClick("ForeverUnitFrames", "LeftButton")
H.checkTrue("compartment shift-click: still the unit window", O.IsOpen())
H.check("compartment: not the raid window", RO.IsOpen(), false)
O.Close()
M.shiftDown = false

-- In combat the way across works too; the raid window opens locked.
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
O.Open()
click(O.raidButton)
H.checkTrue("combat: opens", RO.IsOpen())
H.checkTrue("combat: locked", RO.combatNotice:IsShown())
RO.Close()
M.SetCombat(false)
H.check("nothing blocked", #M.blocked, 0)
