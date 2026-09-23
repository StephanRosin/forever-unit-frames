local ns = H.LoadAddon()

H.check("known font", ns.Media.Font("Arial Narrow"), "Fonts\\ARIALN.TTF")
H.check("unknown font falls back", ns.Media.Font("Nope"), "Fonts\\FRIZQT__.TTF")
H.check("bar texture", ns.Media.StatusBar("Flat"), "Interface\\Buttons\\WHITE8X8")
H.check("font list sorted", ns.Media.List("font")[1], "Arial Narrow")

local L = ns.Layout
local h, g, p = L.Bars(48, 75, 25, true)
H.check("75/25 health", h, 36); H.check("75/25 gap", g, 0); H.check("75/25 power", p, 12)
h, g, p = L.Bars(48, 70, 20, true)
H.check("70/20 gap", g, 5); H.check("sum", h + g + p, 48)
h, g, p = L.Bars(48, 90, 30, true)
H.check("over 100 clamps power", h + g + p, 48); H.check("over 100 no gap", g, 0)
h, g, p = L.Bars(48, 60, 25, false)
H.check("no power: health fills", h, 48); H.check("no power: zero power", p, 0)
h, g, p = L.Bars(10, 75, 25, true)
H.checkTrue("tiny frame keeps 1px power", p >= 1)
