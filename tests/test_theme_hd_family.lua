-- HD themes as colours of their base (LibForeverThemes MINOR 9): the theme
-- list has no HD entry, the colour list adds "HD <colour>" after the
-- base's own; base and HD share one set of settings; sets kept apart
-- before are made one once per profile (a customised HD set wins).
local M = H.M
local ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local Themes, Config, O, L = ns.Themes, ns.Config, ns.Options, ns.L
local function copy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = copy(v) end
    return c
end

-- One set for the family: a switch inside it keeps the settings.
Themes.Switch("WOOD")
Config.Set("player", "x", -111)
H.checkTrue("wood -> wood hd", Themes.Switch("WOOD_HD"))
H.check("wood hd: settings kept", Config.Get("player", "x"), -111)
H.check("wood hd: theme", Themes.Current(), "WOOD_HD")
local sets = ns.UnitProfiles.ThemeSets()
H.check("wood hd: no set of its own", sets.WOOD_HD, nil)
H.check("wood hd: wood not stored beside the live one", sets.WOOD, nil)
Themes.Switch("PIXEL")
H.check("pixel: the family's set under wood", sets.WOOD.player.x, -111)
H.check("pixel: none under wood hd", sets.WOOD_HD, nil)
H.check("copy from: wood, no HD", table.concat(Themes.Stored(), " "), "CLASSIC WOOD")
Themes.Switch("WOOD_HD")
H.check("pixel -> wood hd: the shared set", Config.Get("player", "x") .. " " .. Themes.Current(), "-111 WOOD_HD")
H.check("copy from: not the family itself", table.concat(Themes.Stored(), " "), "CLASSIC PIXEL")

-- Glass HD's thinner fill follows a switch inside the family, unless changed.
Themes.Switch("GLASS")
Themes.Switch("GLASS_HD")
H.check("glass hd: its fill", Config.Get("general", "backgroundColor")[4], 0.6)
Themes.Switch("GLASS")
H.check("glass again: its fill", Config.Get("general", "backgroundColor")[4], 0.9)
Config.Set("general", "backgroundColor", { 0, 0, 0, 0.3 })
Themes.Switch("GLASS_HD")
H.check("glass hd: a changed fill stays", Config.Get("general", "backgroundColor")[4], 0.3)

-- The options: theme list without HD, the base shown; colours with HD.
local function rowFor(key)
    for _, row in ipairs(O.rows) do
        if row.key == key then return row end
    end
end
local function values(items)
    local list = {}
    for _, item in ipairs(items) do list[#list + 1] = item.value end
    return table.concat(list, " ")
end
Themes.Switch("WOOD_HD")
O.Open("general")
O.SelectTab("frames")
local themeRow, colorRow = rowFor("theme"), rowFor("themeColor")
H.check("theme list: no HD", values(themeRow.opts.items()):find("_HD"), nil)
H.check("theme list: wood hd shows as wood", themeRow.opts.get(), "WOOD")
local items = colorRow.opts.items()
H.check("colours: wood's own, then HD", #items .. " " .. items[1].text .. " / " .. items[7].text,
    #LibForeverThemes.Colors("WOOD") + #LibForeverThemes.Colors("WOOD_HD") .. " " .. L.THEME_COLOR_WOOD_OAK
        .. " / HD " .. L.THEME_COLOR_WOOD_HD_EBONY)
H.check("colours: wood hd's chosen", colorRow.opts.get(), "WOOD_HD:EBONY")
-- Choosing the base shown keeps HD (it is a colour of it).
themeRow.opts.set("WOOD")
H.check("theme list: wood under wood hd keeps hd", Themes.Current(), "WOOD_HD")
colorRow.opts.set("WOOD:BIRCH")
H.check("colour: a plain one goes back to wood", Themes.Current() .. " " .. Themes.Color(), "WOOD BIRCH")
H.check("colour: settings kept", Config.Get("player", "x"), -111)
colorRow.opts.set("WOOD_HD:EBONY")
H.check("colour: an HD one goes to wood hd", Themes.Current() .. " " .. Themes.Color(), "WOOD_HD EBONY")
Themes.SetColor("OAK", "WOOD")
themeRow.opts.set("PIXEL")
H.check("theme list: another theme still switches", Themes.Current(), "PIXEL")
O.Close()
H.checkTrue("registry: HD ids still taken", _G.ForeverThemes.ForeverUnitFrames.Switch("TECH_HD"))
H.check("registry: tech hd", Themes.Current(), "TECH_HD")

-- Sets kept apart before: made one once. A plain HD set (as seeded) loses.
Themes.Switch("PIXEL")
sets.WOOD.player.x = 210
sets.WOOD_HD = ns.Settings.Sanitise(Themes.Seed("WOOD_HD", sets.CLASSIC))
sets.hdMerged = nil
Themes.Upgrade()
H.check("merge: plain HD set, wood's stays", sets.WOOD.player.x, 210)
H.check("merge: HD set gone", sets.WOOD_HD, nil)
H.check("merge: once", sets.hdMerged, true)
sets.WOOD_HD = copy(sets.WOOD)
sets.WOOD_HD.player.x = 333
Themes.Upgrade()
H.check("merge: not again", sets.WOOD.player.x, 210)
sets.hdMerged = nil
Themes.Upgrade()
H.check("merge: a customised HD set wins", sets.WOOD.player.x, 333)
H.check("merge: no library field left", sets.WOOD.theme, nil)

-- On the HD theme itself: its live settings win when customised …
Themes.Switch("WOOD_HD")
Config.Set("player", "x", 244)
sets.WOOD = copy(Config.Profile())
sets.WOOD.player.x = 199
sets.WOOD.general.theme = "WOOD"
sets.hdMerged = nil
Themes.Upgrade()
H.check("merge: customised live HD stays", Config.Get("player", "x") .. " " .. Themes.Current(), "244 WOOD_HD")
H.check("merge: no stale wood set", sets.WOOD, nil)
-- … and lose to the base's when plain.
Themes.Reset()
sets.WOOD = copy(Config.Profile())
sets.WOOD.player.x = 199
sets.hdMerged = nil
Themes.Upgrade()
H.check("merge: plain live HD takes wood's", Config.Get("player", "x") .. " " .. Themes.Current(), "199 WOOD_HD")
H.check("merge: live, not stored", sets.WOOD, nil)

-- Another profile, loaded later: its sets are made one when it loads.
local P = ns.UnitProfiles
Themes.Switch("PIXEL")
H.checkTrue("profile: saved as alt", P.SaveAs("Alt"))
local altSets = P.ThemeSets()
H.checkTrue("profile: back to default", P.Switch(P.DEFAULT))
altSets.WOOD_HD = copy(altSets.WOOD)
altSets.WOOD_HD.player.x = 377
altSets.hdMerged = nil
H.checkTrue("profile: alt again", P.Switch("Alt"))
H.check("profile: alt merged on load", tostring(altSets.WOOD_HD) .. " " .. altSets.WOOD.player.x, "nil 377")
