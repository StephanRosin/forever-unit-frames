-- Favourites (Raid/Lists.lua, Raid/SpecialPanels.lua): a second list of
-- your own, beside my tanks and independent of it; a player on both shows
-- in both panels and in their group.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RC, RS, Lists = ns.RaidConfig, ns.RaidSettings, ns.RaidLists
local P, T = ns.RaidSpecialPanels.panels.favourites, ns.RaidSpecialPanels.panels.myTanks

local list = RS.Get("favouriteNames")
H.check("list code", list.code, "GN")
H.check("list per character", RS.AppliesTo(list, "general"), true)
local CODES = { favouritesShow = "GS", favouritesTitle = "GT", favouritesPerLine = "GL", favouritesGrowth = "GG",
    favouritesX = "GX", favouritesY = "GY" }
for key, code in pairs(CODES) do H.check(key .. " code", RS.Get(key) and RS.Get(key).code, code) end
H.check("off", RC.Get("r20", "favouritesShow"), false)
H.check("beside my tanks", RC.Get("r20", "favouritesX") .. "," .. RC.Get("r20", "favouritesY"), "240,150")
H.check("the fourth panel", ns.Raid.PANELS[4].id, "favourites")
H.check("its list", Lists.KEYS.favourites, "favouriteNames")

Lists.Add("favourites", "Bob")
Lists.Add("myTanks", "Cid")
H.check("its own list", RC.Get("general", "favouriteNames"), "Bob")
H.check("my tanks apart", RC.Get("general", "myTankNames"), "Cid")
Lists.Add("favourites", "Cid")

local function member(name, subgroup)
    return { name = name, class = "PRIEST", subgroup = subgroup, unit = { health = 100, healthMax = 100, powerType = 0 } }
end
M.SetRaidRoster({ member("Ann", 1), member("Bob", 1), member("Cid", 2) })
RC.Set("r10", "favouritesShow", true)
RC.Set("r10", "myTanksShow", true)
M.RunTimers()
local h = P.headers[1]
H.check("anchor", P.anchor:GetName(), "ForeverUnitFramesRaidFavourites")
H.check("the list", h:GetAttribute("nameList"), "Bob,Cid")
H.check("in the list's order", h:GetAttribute("sortMethod"), "NAMELIST")
H.check("its players", P.Count(1), 2)
H.check("Cid in my tanks too", T.Count(1), 1)
H.check("and in his group", ns.RaidHeader.Count(2), 1)
H.check("title", P.decor[1].title:GetText(), "Favorites")
Lists.Remove("favourites", "Bob")
M.RunTimers()
H.check("removed", P.Count(1), 1)
H.check("my tanks kept", T.Count(1), 1)

local tab = ns.RaidSchema.TABS[3]
H.check("its section", tab.sections[4].id, "favourites")
H.check("its list first", tab.sections[4].keys[1], "favouriteNames")
H.check("the list's words", ns.RaidSchema.Label("favouriteNames"), "Names")
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
