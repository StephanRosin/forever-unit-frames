-- Numbers the client writes (aura and shield countdowns) follow the font
-- outline setting the same way (Texts.CountdownFlags).
local ns = H.LoadAddon()
local F = ns.Texts.CountdownFlags
H.check("soft: plain outline", F("SOFT"), "OUTLINE")
H.check("none: none", F("NONE"), "")
H.check("thick: as it is", F("THICKOUTLINE"), "THICKOUTLINE")
