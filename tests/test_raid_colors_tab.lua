-- The raid window's Colors tab (Raid/Options/Colors.lua): the unit frames'
-- class and pet colours, the same values; a colour greys while its
-- switch is off.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RO, C = ns.RaidOptions, ns.Config

RO.Open(nil, "colors")
local function row(key)
    for _, r in ipairs(RO.page.rows) do if r.key == key then return r end end
end
H.checkTrue("the switch", row("classColorsCustom"))
H.checkTrue("a class", row("classColorWARLOCK"))
H.checkTrue("a pet", row("petColorIncubus"))
H.check("on General", RO.view, "general")
H.check("greyed while off", row("classColorWARLOCK").enabledState, false)

C.Set("general", "classColorsCustom", true)
H.check("active once on", row("classColorWARLOCK").enabledState, true)
H.check("pets still greyed", row("petColorImp").enabledState, false)

