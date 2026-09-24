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
H.check("party width", C.Get("party", "width"), 192)
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

-- Every media name in the preset is built in (no other addon needed).
H.checkTrue("preset texture built in", ns.Media.StatusBar(C.Get("general", "barTexture")) == "Interface\\RaidFrame\\Raid-Bar-Hp-Fill")

-- The pet frame sits left of the player frame, not on it.
local function box(scope)
    local w, h = C.Get(scope, "width"), C.Get(scope, "height")
    local x, y = C.Get(scope, "x"), C.Get(scope, "y")
    return x - w / 2, x + w / 2, y - h / 2, y + h / 2
end
local pl, pr = box("player")
local el, er, eb, et = box("pet")
local _, _, plb, plt = box("player")
H.checkTrue("pet left of the player", er < pl)
H.check("pet top on the player's top", et, plt)

-- Damage and heal numbers on target and focus too.
H.check("numbers on the target", C.Get("target", "combatFeedback"), true)
H.check("numbers on the focus", C.Get("focus", "combatFeedback"), true)
H.check("numbers on the player", C.Get("player", "combatFeedback"), true)

-- The overheal lane is on, so a shield on a unit at full health shows.
for _, scope in ipairs({ "player", "target", "targettarget", "focus", "party", "pet" }) do
    H.check("overheal lane on: " .. scope, C.Get(scope, "healOverflow"), true)
end
