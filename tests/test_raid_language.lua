-- A language switch redraws the raid cells (Raid/Header.lua): a status
-- word in a cell's second line follows the new language.
local M = H.M
local ns = H.LoadAddon()
local Header = ns.RaidHeader
M.units.player = { name = "Me", class = "WARRIOR", className = "Warrior", isPlayer = true, level = 60,
    health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.SetRaidRoster({ { name = "Tank", class = "WARRIOR", subgroup = 1, unit = { dead = true } },
    { name = "Ann", class = "PRIEST", subgroup = 1 } })
M.RunTimers()
local cell = Header.headers[1]:GetAttribute("child1")
H.check("dead in English", cell.texts.healthRight:GetText(), "Dead")

ns.Config.Set("general", "language", "deDE")
M.RunTimers()
H.check("dead in German after the switch", cell.texts.healthRight:GetText(), "Tot")

-- In combat the redraw waits for combat to end.
M.SetCombat(true)
ns.Config.Set("general", "language", "frFR")
M.RunTimers()
H.check("in combat: not yet", cell.texts.healthRight:GetText(), "Tot")
M.SetCombat(false)
M.RunTimers()
H.check("after combat: French", cell.texts.healthRight:GetText(), ns.Locales.frFR.STATUS_DEAD)
ns.Config.Set("general", "language", "enUS")
H.check("no errors", #M.errors, 0)
