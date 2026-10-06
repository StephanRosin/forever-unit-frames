local _, ns = ...

-- The cells' right-click menu: the cell opens Blizzard's unit menu
-- (togglemenu: RAID_PLAYER for a raid member, PARTY for a party member,
-- SELF for you, SecureTemplates.lua), and we add to it through
-- Menu.ModifyMenu (Blizzard_Menu/Menu.lua): add to or remove from
-- favourites, mark or unmark as my tank. The menu system was made for
-- addons to add elements without tainting Blizzard's
-- (11_0_0_MenuImplementationGuide.lua, "Taint"): Blizzard's entries keep
-- their own handlers, ours only change our lists (plain data,
-- Raid/Lists.lua) and never call a protected function. Only menus opened
-- from one of our cells (contextData.ownerFrame; not a pretend one) get
-- the entries, for a player whose name can be read, and each only while
-- its panel is switched on for the size shown. Out of combat the panel
-- follows at once, in combat after combat (the chat says so).
local RaidMenu = {}
ns.RaidMenu = RaidMenu

local Cell, Lists, L = ns.RaidCell, ns.RaidLists, ns.L

RaidMenu.TAGS = { "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_PARTY", "MENU_UNIT_SELF" }
-- In the menu's order: the list, its panel's switch, the words.
RaidMenu.ENTRIES = {
    { list = "favourites", add = "RAID_MENU_FAVOURITE_ADD", remove = "RAID_MENU_FAVOURITE_REMOVE" },
    { list = "myTanks", add = "RAID_MENU_TANK_ADD", remove = "RAID_MENU_TANK_REMOVE" },
}

local function shown(id)
    return ns.RaidConfig.Get(ns.Raid.Scope(Cell.Size()), id .. "Show") == true
end

local function ours(frame)
    return type(frame) == "table" and Cell.Is(frame) and not frame.pretend
end

local function toggle(id, name)
    if not Lists.Toggle(id, name) then
        ns.Print(L.RAID_LIST_FULL)
    elseif InCombatLockdown() then
        ns.Print(L.RAID_LIST_AFTER_COMBAT)
    end
end

-- Menu.ModifyMenu's callback: our entries at the end of the menu.
function RaidMenu.Modify(_, root, contextData)
    if not (contextData and ours(contextData.ownerFrame)) then return end
    local name = Lists.UnitName(contextData.unit)
    if not name then return end
    local entries = {}
    for _, entry in ipairs(RaidMenu.ENTRIES) do
        if shown(entry.list) then entries[#entries + 1] = entry end
    end
    if #entries == 0 then return end
    root:CreateDivider()
    root:CreateTitle(L.ADDON_NAME)
    for _, entry in ipairs(entries) do
        local text = Lists.Has(entry.list, name) and L[entry.remove] or L[entry.add]
        root:CreateButton(text, function() toggle(entry.list, name) end)
    end
end

if Menu and Menu.ModifyMenu then
    for _, tag in ipairs(RaidMenu.TAGS) do Menu.ModifyMenu(tag, RaidMenu.Modify) end
end
