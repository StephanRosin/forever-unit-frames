-- The shipped look (Core/Preset.lua) on top of the plain defaults.
local ns = H.LoadShipped()
local C, S = ns.Config, ns.Settings
C.Use({})

-- General values become the base for every frame.
H.check("gold border", C.Get("general", "borderStyle"), "GOLD")
H.check("frames inherit it", C.Get("focus", "borderStyle"), "GOLD")
H.check("shadow on", C.Get("target", "shadowEnabled"), true)
-- Frame values are that frame's own default.
H.check("target width", C.Get("target", "width"), 300)
H.check("player castbar on", C.Get("player", "castbarEnabled"), true)
H.check("castbar kept in the frame", C.Get("target", "castbarAlwaysShow"), true)
H.check("party width", C.Get("party", "width"), 195)
-- An inherited setting with a frame default: the frame's, until the
-- general page sets a value for all.
H.check("party: first name only", C.Get("party", "showSurname"), false)
H.check("target: surname", C.Get("target", "showSurname"), true)
C.Set("general", "showSurname", true)
H.check("general value wins over a frame default", C.Get("party", "showSurname"), true)
C.Set("general", "showSurname", false)
H.check("general off", C.Get("target", "showSurname"), false)

-- A value equal to the shipped default is not stored.
local p = {}
C.Use(p)
C.Set("target", "width", 300)
H.check("default not stored", p.target.width, nil)

-- Every preset entry is a valid, applicable value.
H.checkTrue("defaults valid", S.Validate(S.Get("buffsMax"), C.Get("player", "buffsMax")) == 24)

-- Tests elsewhere run against the plain defaults.
local plain = H.LoadAddon()
plain.Config.Use({})
H.check("plain target width", plain.Config.Get("target", "width"), 220)
