-- The cells' right-click menu (Raid/Menu.lua): Blizzard's unit menu,
-- opened by the cell's togglemenu, gets our entries through
-- Menu.ModifyMenu: favourites and my tanks, each while its panel is on;
-- only from our cells, only for a name that can be read. In combat the
-- list changes at once and the panel after combat.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1, isPlayer = true }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RC, Lists, Header, Special = ns.RaidConfig, ns.RaidLists, ns.RaidHeader, ns.RaidSpecialPanels

for _, tag in ipairs({ "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_PARTY", "MENU_UNIT_SELF" }) do
    H.check("registered: " .. tag, M.menuMods[tag] and M.menuMods[tag][1], ns.RaidMenu.Modify)
end
H.check("not on pets' menus", M.menuMods.MENU_UNIT_OTHERPET, nil)

local function member(name, subgroup)
    return { name = name, class = "WARRIOR", subgroup = subgroup, unit = { health = 100, healthMax = 100, powerType = 1 } }
end
M.SetRaidRoster({ member("Me", 1), member("Bob", 1), member("Cid", 2) })
M.units.player = M.units.raid1
M.RunTimers()
local function cell(unit)
    for _, h in ipairs(Header.headers) do
        for _, b in ipairs(ns.RaidCell.buttons) do
            if b.unit == unit and b:IsVisible() and b:GetParent() == h then return b end
        end
    end
end
local function texts(menu)
    local list = {}
    for _, e in ipairs(menu.elements) do list[#list + 1] = e.kind == "divider" and "-" or e.text end
    return table.concat(list, "|")
end
local function button(menu, text)
    for _, e in ipairs(menu.elements) do if e.text == text then return e end end
end

-- Both panels off: no entries.
local bob = cell("raid2")
H.check("a right click opens the unit menu", M.SecureClick(bob, "RightButton"), "togglemenu")
H.check("a raid member's menu", M.menu.tag, "MENU_UNIT_RAID_PLAYER")
H.check("the cell owns it", M.menu.contextData.ownerFrame, bob)
H.check("panels off: nothing added", texts(M.menu), "")

-- Favourites on: add and remove.
RC.Set("r10", "favouritesShow", true)
M.SecureClick(bob, "RightButton")
H.check("favourites", texts(M.menu), "-|Forever Unit Frames|Add to favorites")
M.ClickMenu(button(M.menu, "Add to favorites"))
H.check("added", RC.Get("general", "favouriteNames"), "Bob")
M.RunTimers()
H.check("the panel follows at once", Special.panels.favourites.Count(1), 1)
M.SecureClick(bob, "RightButton")
H.check("on the list: remove", texts(M.menu), "-|Forever Unit Frames|Remove from favorites")
M.ClickMenu(button(M.menu, "Remove from favorites"))
H.check("removed", RC.Get("general", "favouriteNames"), "")

-- My tanks on as well: favourites first.
RC.Set("r10", "myTanksShow", true)
M.SecureClick(bob, "RightButton")
H.check("both", texts(M.menu), "-|Forever Unit Frames|Add to favorites|Mark as my tank")
M.ClickMenu(button(M.menu, "Mark as my tank"))
H.check("my tank", RC.Get("general", "myTankNames"), "Bob")
H.check("not a favourite", RC.Get("general", "favouriteNames"), "")
M.SecureClick(bob, "RightButton")
H.check("unmark", button(M.menu, "Unmark as my tank") ~= nil, true)

-- Your own cell: your menu.
M.SecureClick(cell("raid1"), "RightButton")
H.check("your menu", M.menu.tag, "MENU_UNIT_SELF")
M.ClickMenu(button(M.menu, "Add to favorites"))
H.check("yourself", RC.Get("general", "favouriteNames"), "Me")

-- In combat: the list at once, the panel after combat.
local chat = #M.chat
M.combat = true
M.SecureClick(cell("raid3"), "RightButton")
M.ClickMenu(button(M.menu, "Add to favorites"))
H.check("combat: stored", RC.Get("general", "favouriteNames"), "Me, Cid")
H.checkTrue("combat: the chat says when", M.chat[chat + 1] and M.chat[chat + 1]:find("follows after combat", 1, true))
H.check("combat: the header waits", Special.panels.favourites.headers[1]:GetAttribute("nameList"), "Me")
H.check("combat: nothing blocked", #M.blocked, 0)
M.SetCombat(false)
M.RunTimers()
H.check("after combat", Special.panels.favourites.headers[1]:GetAttribute("nameList"), "Me,Cid")

-- A full list says so.
local long = {}
for i = 1, 31 do long[i] = "Name" .. string.char(64 + (i - 1) % 26 + 1) .. string.char(97 + math.floor((i - 1) / 26)) end
RC.Set("general", "myTankNames", table.concat(long, ", "))
chat = #M.chat
M.SecureClick(cell("raid3"), "RightButton")
M.ClickMenu(button(M.menu, "Mark as my tank"))
H.checkTrue("full: the chat says so", M.chat[chat + 1] and M.chat[chat + 1]:find("The list is full", 1, true))
RC.Set("general", "myTankNames", "")

-- Not ours, pretend, or a name that cannot be read: nothing added.
local root = M.OpenUnitMenu("RAID_PLAYER", { ownerFrame = UIParent, unit = "raid2" })
H.check("another frame's menu", texts(root), "")
root = M.OpenUnitMenu("RAID_PLAYER", { unit = "raid2" })
H.check("no owner", texts(root), "")
M.units.raid2.name = M.Secret("Bob")
M.raid[2].name = M.units.raid2.name
root = M.OpenUnitMenu("RAID_PLAYER", { ownerFrame = bob, unit = "raid2" })
H.check("a secret name", texts(root), "")
H.check("the name of a unit", Lists.UnitName("raid3"), "Cid")
H.check("a secret name is none", Lists.UnitName("raid2"), nil)
H.check("no unit", Lists.UnitName(nil), nil)
M.raid[2].name, M.units.raid2.name = "Bob", "Bob"
ns.RaidTestMode.Set(true)
local fake = ns.RaidCell.fakes[1]
root = M.OpenUnitMenu("SELF", { ownerFrame = fake, unit = "player" })
H.check("a pretend cell", texts(root), "")
ns.RaidTestMode.Set(false)

-- A party with the raid view: the name as the header compares it.
M.SetRaidRoster({})
M.units.player = { name = "Me", class = "MAGE", isPlayer = true }
M.units.party1 = { name = "Lea", surname = "Stone", class = "PRIEST", isPlayer = true }
M.SetGroup({ "party1" })
RC.Set("general", "showInParty", true)
M.RunTimers()
local lea
for _, b in ipairs(ns.RaidCell.buttons) do if b.unit == "party1" and b:GetParent() == Header.headers[1] then lea = b end end
M.SecureClick(lea, "RightButton")
H.check("a party member's menu", M.menu.tag, "MENU_UNIT_PARTY")
M.ClickMenu(button(M.menu, "Add to favorites"))
H.check("her name with its second part", RC.Get("general", "favouriteNames"), "Me, Cid, Lea-Stone")
M.RunTimers()
H.check("the panel shows her after you", Special.panels.favourites.headers[1]:GetAttribute("child2").unit, "party1")
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
