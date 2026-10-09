-- The buff watch window's gear: a check per buff of your class; one the
-- spell book does not know is greyed; a click switches it; in combat the
-- gear does nothing.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", className = "Priest", isPlayer = true, auras = {} }
M.known[1243], M.known[976] = true, true   -- Fortitude, Shadow Protection; no Divine Spirit (level < 30)
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RC, Win, L = ns.RaidConfig, ns.RaidBuffWindow, ns.L
M.units.party1 = { name = "Ann", class = "MAGE", isPlayer = true, auras = {}, distance = 10 }
M.SetGroup({ "party1" })
M.Tick(1)
Win.OpenMenu(Win.gear)
local menu = M.menu
H.check("title", menu.elements[1].text, L.RAID_BUFF_WATCH_TITLE)
local function find(text)
    for _, e in ipairs(menu.elements) do if e.text == text then return e end end
end
local fort = find(L.RAID_SETTING_buffFortitude)
H.checkTrue("fortitude listed", fort)
H.check("fortitude on", M.MenuSelected(fort), true)
local spirit = find(L.RAID_SETTING_buffSpirit .. " (" .. L.RAID_BUFF_NOT_LEARNED .. ")")
H.checkTrue("spirit listed, not learned", spirit)
H.check("spirit greyed", spirit.enabled, false)
H.check("no mage buff for a priest", find(L.RAID_SETTING_buffIntellect), nil)
M.ClickMenu(fort)
H.check("click: off", RC.Get("general", "buffFortitude"), false)
M.ClickMenu(fort)
H.check("click: on again", RC.Get("general", "buffFortitude"), true)
-- The gear's click opens it; in combat it does not.
M.menu = nil
Win.gear:GetScript("OnClick")(Win.gear, "LeftButton")
H.checkTrue("gear opens the menu", M.menu)
M.menu = nil
M.SetCombat(true)
Win.gear:GetScript("OnClick")(Win.gear, "LeftButton")
H.check("in combat: no menu", M.menu, nil)
M.SetCombat(false)
