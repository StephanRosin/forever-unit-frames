local _, ns = ...
local L = ns.Locales.enUS
L.SETTING_healHotEnabled = "Predict my HoTs (estimated)"
L.SETTING_healHotColor = "HoT prediction colour"
L.HINT_healHotEnabled = "Estimates healing remaining from your own Rejuvenation, Regrowth, Lifebloom, Wild Growth, Renew and Riptide. Starts after direct heals. Requires readable spell tooltips and a known recipient; cannot predict other players' HoTs or read secret combat aura amounts. English tooltip formats supported."
L.HINT_healHotColor = "A separate segment after all direct incoming heals. HoT values are approximate and cannot account for dispels or changing tick effects in restricted combat."

L.SETTING_healHotCalibration = "Learn my HoT strength after combat (experimental)"
L.HINT_healHotCalibration = "Optional. Compares scheduled pure-HoT ticks with the Blizzard Healing Done meter after combat. Needs two consistent fights; skips mixed direct/HoT spells. Effective healing, overheal and critical ticks can distort samples. Defaults off. Use /fuf hotdebug for diagnostics."
