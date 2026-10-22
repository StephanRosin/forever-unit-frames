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

-- A target that is not a player: the target menu, the target's page.
M.units.target = { name = "Boar", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_TARGET_CHANGED")
M.SecureClick(ns.Frames.target, "RightButton")
H.check("the target menu", M.menu.tag, "MENU_UNIT_TARGET")
M.ClickMenu(M.menu.elements[#M.menu.elements])
H.check("on the target's page", Options.currentScope, "target")

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
