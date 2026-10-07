-- My tanks (Raid/Lists.lua, Raid/SpecialPanels.lua): your own list of
-- names, per character and permanent, shown as a panel of its own in
-- the list's order; a list changed in combat reaches the panel after
-- combat. The list as text in the raid window.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local Raid, RC, RS, Lists = ns.Raid, ns.RaidConfig, ns.RaidSettings, ns.RaidLists
local P = ns.RaidSpecialPanels.panels.myTanks

-- The settings: the list per character, the panel per size.
local list = RS.Get("myTankNames")
H.check("list code", list.code, "ZN")
H.check("list per character", RS.AppliesTo(list, "general"), true)
H.check("list not per size", RS.AppliesTo(list, "r10"), false)
H.check("list empty", RC.Get("general", "myTankNames"), "")
local CODES = { myTanksShow = "ZS", myTanksTitle = "ZT", myTanksPerLine = "ZL", myTanksGrowth = "ZG",
    myTanksX = "ZX", myTanksY = "ZY" }
for key, code in pairs(CODES) do H.check(key .. " code", RS.Get(key) and RS.Get(key).code, code) end
H.check("off", RC.Get("r10", "myTanksShow"), false)
H.check("a column", RC.Get("r10", "myTanksGrowth"), "DOWN")
H.check("right of the main panel", RC.Get("r40", "myTanksX") .. "," .. RC.Get("r40", "myTanksY"), "120,150")
H.check("the list first in its section", table.concat(ns.Raid.PANELS[3].keys, ","),
    "myTankNames,myTanksShow,myTanksTitle,myTanksPerLine,myTanksGrowth,myTanksX,myTanksY")

-- What a list may hold.
local function parsed(text)
    local names, why, word = Raid.ParseNameList(text)
    if not names then return why .. ":" .. word end
    return table.concat(names, "|")
end
H.check("names trimmed", parsed(" Ann ,Bob-Realm,  "), "Ann|Bob-Realm")
H.check("a surname, an apostrophe", parsed("Lea Stone, Lea-Stone, D'arc"), "Lea Stone|Lea-Stone|D'arc")
-- Typed names take WoW's spelling (first letter upper case, the rest of
-- the name lower case); a realm or surname stays as typed.
H.check("WoW's spelling", parsed("bob, ANN, mcKay-Some Realm, lea stone"), "Bob|Ann|Mckay-Some Realm|Lea stone")
H.check("twice, whatever the case", parsed("Ann, ann"), "TWICE:Ann")
H.check("twice: a realm in another case", parsed("Bob-Realm, bob-realm"), "TWICE:Bob-realm")
H.check("letters of any script", parsed("Zoë, Jürgen"), "Zoë|Jürgen")
H.check("empty", parsed(""), "")
H.check("twice", parsed("Ann, Bob, Ann"), "TWICE:Ann")
H.check("a digit", parsed("Ann, R2D2"), "INVALID:R2D2")
H.check("a sign", parsed("Ann; Bob"), "INVALID:Ann; Bob")
H.check("refused when stored", RC.Set("general", "myTankNames", "Ann, Ann"), false)
H.checkTrue("stored", RC.Set("general", "myTankNames", "Ann,Bob"))
RC.Set("general", "myTankNames", "")

-- Changing a list.
H.checkTrue("add", Lists.Add("myTanks", "Ann"))
Lists.Add("myTanks", "Bob-Realm")
H.check("written", RC.Get("general", "myTankNames"), "Ann, Bob-Realm")
H.checkTrue("add again: already there", Lists.Add("myTanks", "Ann"))
H.check("once", RC.Get("general", "myTankNames"), "Ann, Bob-Realm")
H.checkTrue("has", Lists.Has("myTanks", "Bob-Realm"))
H.check("has not", Lists.Has("myTanks", "Bob"), false)
H.checkTrue("has, whatever the case", Lists.Has("myTanks", "bob-realm"))
H.checkTrue("add in another case: already there", Lists.Add("myTanks", "ANN"))
H.check("not twice", RC.Get("general", "myTankNames"), "Ann, Bob-Realm")
H.check("for a header", Lists.Attribute("myTanks"), "Ann,Bob-Realm")
Lists.Toggle("myTanks", "Ann")
H.check("toggled off", RC.Get("general", "myTankNames"), "Bob-Realm")
Lists.Toggle("myTanks", "Ann")
H.check("toggled on, at the end", RC.Get("general", "myTankNames"), "Bob-Realm, Ann")
Lists.Remove("myTanks", "Bob-Realm")
H.check("removed", RC.Get("general", "myTankNames"), "Ann")
local long = {}
for i = 1, 40 do long[i] = "Name" .. string.char(64 + (i - 1) % 26 + 1) .. string.char(97 + math.floor((i - 1) / 26)) end
RC.Set("general", "myTankNames", table.concat(long, ", ", 1, 31))
H.check("full: refused", Lists.Add("myTanks", "Another"), false)
H.check("full: kept", #Lists.Names("myTanks"), 31)
RC.Set("general", "myTankNames", "")
H.check("unknown list", pcall(Lists.Names, "nobody"), false)

-- The panel: your list in its order.
local h = P.headers[1]
H.check("an empty list: nobody", h:GetAttribute("nameList"), "")
H.check("in the list's order", h:GetAttribute("sortMethod"), "NAMELIST")
H.check("no group filter", h:GetAttribute("groupFilter"), nil)
H.check("off: hidden", h:IsShown(), false)
local function member(name, subgroup)
    return { name = name, class = "WARRIOR", subgroup = subgroup, unit = { health = 100, healthMax = 100, powerType = 1 } }
end
M.SetRaidRoster({ member("Ann", 1), member("Bob", 1), member("Cid", 2), member("Dee", 2) })
RC.Set("r10", "myTanksShow", true)
RC.Set("general", "myTankNames", "Dee, Bob")
M.RunTimers()
H.check("the list", h:GetAttribute("nameList"), "Dee,Bob")
H.check("its players, in its order", h:GetAttribute("child1").unit .. "," .. h:GetAttribute("child2").unit,
    "raid4,raid2")
H.check("a column of two", P.width .. "x" .. P.height, "96x" .. (14 + 2 * 44 + 2))
H.check("title", P.decor[1].title:GetText(), "My tanks")
H.check("Bob also in his group", ns.RaidHeader.Count(1), 2)

-- In combat: stored at once, shown after combat.
M.combat = true
Lists.Add("myTanks", "Ann")
H.check("combat: stored", RC.Get("general", "myTankNames"), "Dee, Bob, Ann")
H.check("combat: the header waits", h:GetAttribute("nameList"), "Dee,Bob")
H.check("combat: nothing blocked", #M.blocked, 0)
M.SetCombat(false)
M.RunTimers()
H.check("after combat", h:GetAttribute("nameList"), "Dee,Bob,Ann")
H.check("after combat: three", P.Count(1), 3)

-- The raid window: the list as text, cleaned up; refused with a reason.
local RO = ns.RaidOptions
RO.Open(10, "panels")
local row
for _, r in ipairs(RO.rows) do if r.key == "myTankNames" then row = r end end
H.check("label", row.label:GetText(), "Names")
H.check("hint", row.hintText:GetText(), "Per character: names, comma-separated; Name-Realm for other realms")
H.check("shows the list", row.edit:GetText(), "Dee, Bob, Ann")
M.Type(row.edit, " Cid ,Ann,, ")
M.PressEnter(row.edit)
H.check("typed: cleaned up", RC.Get("general", "myTankNames"), "Cid, Ann")
M.Type(row.edit, "dee, bob")
M.PressEnter(row.edit)
H.check("typed: WoW's spelling", RC.Get("general", "myTankNames"), "Dee, Bob")
H.check("typed: the header finds them", h:GetAttribute("nameList"), "Dee,Bob")
M.Type(row.edit, "Cid, Ann")
M.PressEnter(row.edit)
local chat = #M.chat
M.Type(row.edit, "Cid, Cid")
M.PressEnter(row.edit)
H.check("twice: refused", RC.Get("general", "myTankNames"), "Cid, Ann")
H.checkTrue("twice: says why", M.chat[chat + 1] and M.chat[chat + 1]:find("Name given twice: Cid", 1, true))
M.Type(row.edit, "Cid, 42")
M.PressEnter(row.edit)
H.checkTrue("no name: says why", M.chat[chat + 2] and M.chat[chat + 2]:find("Not a player name: 42", 1, true))
H.check("the box shows the list again", row.edit:GetText(), "Cid, Ann")
RO.Close()
H.check("section title", ns.RaidSchema.SectionTitle("myTanks"), "My tanks")
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
