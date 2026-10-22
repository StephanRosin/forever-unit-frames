local _, ns = ...

-- "Edit Frame" in Blizzard's unit menu, opened by a right click on one of
-- our frames (togglemenu): opens our options on that frame's page. It is
-- appended, so it ends Blizzard's last section, "Other Options"
-- (UnitPopupMenus.lua), without a title of its own. Added
-- through Menu.ModifyMenu like the raid cells' entries (Raid/Menu.lua,
-- which adds it for the cells itself); it only opens our own window, so
-- Blizzard's entries stay untainted. Test mode's frames show the player,
-- so they get the player's menu and the entry too.
local FrameMenu = {}
ns.FrameMenu = FrameMenu

local L = ns.L

-- Every menu togglemenu opens (SECURE_ACTIONS.togglemenu,
-- SecureTemplates.lua) but the raid cells' (Raid/Menu.lua).
FrameMenu.TAGS = { "MENU_UNIT_SELF", "MENU_UNIT_TARGET", "MENU_UNIT_PET", "MENU_UNIT_PARTY", "MENU_UNIT_FOCUS",
    "MENU_UNIT_PLAYER", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_BOSS", "MENU_UNIT_VEHICLE", "MENU_UNIT_OTHERPET",
    "MENU_UNIT_OTHERBATTLEPET", "MENU_UNIT_ARENAENEMY" }

-- Party pets and targets are set up on the party page's Group tab.
local GROUP_PARTS = { [ns.Party.PET_KEY] = true, [ns.PartyTargets.KEY] = true }

-- Opens the options where frame's settings are.
function FrameMenu.Edit(frame)
    if ns.RaidCell.Is(frame) then
        ns.RaidOptions.Open(ns.RaidCell.Size())
    elseif GROUP_PARTS[frame.key] then
        ns.Options.Open(ns.Party.KEY, "group")
    else
        ns.Options.Open(frame.key)
    end
end

function FrameMenu.AddEdit(root, frame)
    root:CreateButton(L.MENU_EDIT_FRAME, function() FrameMenu.Edit(frame) end)
end

local function ours(frame)
    if type(frame) ~= "table" or ns.RaidCell.Is(frame) then return false end
    if GROUP_PARTS[frame.key] then return true end
    for _, def in ipairs(ns.Units.List) do
        if def.key == frame.key then return true end
    end
    return false
end

function FrameMenu.Modify(_, root, contextData)
    local frame = contextData and contextData.ownerFrame
    if ours(frame) then FrameMenu.AddEdit(root, frame) end
end

if Menu and Menu.ModifyMenu then
    for _, tag in ipairs(FrameMenu.TAGS) do Menu.ModifyMenu(tag, FrameMenu.Modify) end
end
