-- "Edit Frame" in Blizzard's unit menu (Options/FrameMenu.lua): a right
-- click on one of our frames opens the unit menu; the entry ends it and
-- opens our options on that frame's page.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1, isPlayer = true }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local Options, FM = ns.Options, ns.FrameMenu

for _, tag in ipairs({ "MENU_UNIT_SELF", "MENU_UNIT_TARGET", "MENU_UNIT_PET", "MENU_UNIT_PARTY", "MENU_UNIT_FOCUS" }) do
    local found = false
    for _, cb in ipairs(M.menuMods[tag] or {}) do found = found or cb == FM.Modify end
    H.checkTrue("registered: " .. tag, found)
end

local function last(menu)
    local e = menu.elements[#menu.elements]
    return e and e.text
end

-- The player frame: your menu, the entry last, without a title of ours.
H.check("a right click opens the unit menu", M.SecureClick(ns.Frames.player, "RightButton"), "togglemenu")
H.check("your menu", M.menu.tag, "MENU_UNIT_SELF")
H.check("only the entry", #M.menu.elements, 1)
H.check("Edit Frame last", last(M.menu), "Edit Frame")
M.ClickMenu(M.menu.elements[1])
H.checkTrue("options open", Options.IsOpen())
H.check("on the player's page", Options.currentScope, "player")

-- In a group: above Blizzard's entries for leaving, below the others.
PARTY_LEAVE, INSTANCE_PARTY_LEAVE = "Leave Group", "Leave Instance Group"
M.unitMenuEntries = { SELF = { "Set Focus", "Leave Group" } }
M.SecureClick(ns.Frames.player, "RightButton")
H.check("in a group: after the other entries", M.menu.elements[2].text, "Edit Frame")
H.check("in a group: Leave Group stays last", last(M.menu), "Leave Group")
M.unitMenuEntries = { SELF = { "Leave Instance Group", "Leave Group" } }
M.SecureClick(ns.Frames.player, "RightButton")
H.check("above the first entry for leaving", M.menu.elements[1].text, "Edit Frame")
M.unitMenuEntries = nil
PARTY_LEAVE, INSTANCE_PARTY_LEAVE = nil, nil

-- A target that is not a player: the target menu, the target's page.
M.units.target = { name = "Boar", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_TARGET_CHANGED")
M.SecureClick(ns.Frames.target, "RightButton")
H.check("the target menu", M.menu.tag, "MENU_UNIT_TARGET")
M.ClickMenu(M.menu.elements[#M.menu.elements])
H.check("on the target's page", Options.currentScope, "target")

-- A secret identity (dungeons): Blizzard's menu stays as it is, an entry of
-- ours would break its layout.
C_Secrets.ShouldUnitIdentityBeSecret = function(unit) return unit == "target" end
M.SecureClick(ns.Frames.target, "RightButton")
H.check("secret target: the menu opens", M.menu.tag, "MENU_UNIT_TARGET")
H.check("secret target: nothing of ours in it", #M.menu.elements, 0)
M.SecureClick(ns.Frames.player, "RightButton")
H.check("a readable unit keeps the entry", last(M.menu), "Edit Frame")
C_Secrets.ShouldUnitIdentityBeSecret = function() error("not available") end
M.SecureClick(ns.Frames.player, "RightButton")
H.check("unknown counts as secret", #M.menu.elements, 0)
C_Secrets.ShouldUnitIdentityBeSecret = nil

-- The gamepad UI: an entry of ours taints the menu for the controller.
_G.InputUtil = { IsGamepadUIEnabled = function() return true end }
M.SecureClick(ns.Frames.player, "RightButton")
H.check("gamepad: nothing of ours in it", #M.menu.elements, 0)
_G.InputUtil = nil

-- Test mode: frames show you, so they get your menu, each its own page.
ns.TestMode.Set(true)
M.RunTimers()
M.SecureClick(ns.Frames.targettarget, "RightButton")
H.check("test mode: your menu", M.menu.tag, "MENU_UNIT_SELF")
M.ClickMenu(M.menu.elements[#M.menu.elements])
H.check("test mode: the target of target's page", Options.currentScope, "targettarget")
ns.TestMode.Set(false)
M.RunTimers()

-- Party pets and targets: the party page's Group tab; raid cells: the
-- raid options.
FM.Edit({ key = ns.Party.PET_KEY })
H.check("party pets: party page", Options.currentScope, "party")
H.check("party pets: Group tab", Options.currentTab, "group")
FM.Edit({ key = ns.PartyTargets.KEY })
H.check("party targets: party page", Options.currentScope, "party")
FM.Edit({ key = ns.RaidCell.KEY })
H.checkTrue("raid cells: raid options", ns.RaidOptions.IsOpen())

-- Not ours: nothing added.
local root = M.OpenUnitMenu("SELF", { ownerFrame = UIParent, unit = "player" })
H.check("another frame's menu", #root.elements, 0)
root = M.OpenUnitMenu("SELF", { unit = "player" })
H.check("no owner", #root.elements, 0)
H.check("no error", #M.errors, 0)
