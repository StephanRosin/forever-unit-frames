-- The raid window's class order field (Raid/Options/Window.lua) only
-- means something while the edited size groups by class: otherwise it is
-- locked and dimmed, and its hint says so, with an example of class names
-- in the window's language. It follows "Group by" at once.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RO, RC = ns.RaidOptions, ns.RaidConfig

local function rowFor(key)
    for _, row in ipairs(RO.rows) do if row.key == key then return row end end
end
local function on() local row = rowFor("classOrder"); return row.edit:IsEnabled() and row:GetAlpha() == 1 end

RO.Open(10, "layout")
H.check("group by group: locked", on(), false)
H.check("hint", rowFor("classOrder").hintText:GetText(), "Only with Group by: Class; e.g. Warrior, Priest, Paladin, Druid")
H.checkTrue("the other rows stay usable", rowFor("sortBy").button:IsEnabled())

-- Picked in the window's dropdown: at once.
local groupBy = rowFor("groupBy")
groupBy.button:GetScript("OnClick")(groupBy.button)
for _, r in ipairs(ns.Widgets.list.rows) do
    if r.item and r.item.value == "CLASS" then r:GetScript("OnClick")(r) end
end
H.check("picked: stored", RC.Get("r10", "groupBy"), "CLASS")
H.checkTrue("group by class: usable", on())
RC.Set("r10", "groupBy", "ROLE")
H.check("group by role: locked again", on(), false)

-- Each size its own.
RC.Set("r20", "groupBy", "CLASS")
RO.SelectSize(20)
H.checkTrue("20 groups by class: usable", on())
RO.SelectSize(10)
H.check("10 does not: locked", on(), false)

-- Combat locks it either way; after combat it follows Group by again.
RC.Set("r10", "groupBy", "CLASS")
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("combat: locked", on(), false)
M.SetCombat(false)
H.checkTrue("after combat: usable", on())
RC.Set("r10", "groupBy", "GROUP")
H.check("back to groups: locked", on(), false)

-- The hint in every language.
for code, text in pairs({
    deDE = "Nur mit Gruppieren nach: Klasse; z. B. Krieger, Priester, Paladin, Druide",
    esES = "Solo con Agrupar por: Clase; p. ej. Guerrero, Sacerdote, Paladín, Druida",
    frFR = "Actif si Regrouper par : Classe ; ex. Guerrier, Prêtre, Paladin, Druide" }) do
    H.check(code .. ": hint", ns.Locales[code].RAID_HINT_classOrder, text)
end
ns.Config.Set("general", "language", "deDE")
RO.SelectTab("layout")
H.check("rebuilt in German: still locked", on(), false)
ns.Config.Set("general", "language", "AUTO")
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
