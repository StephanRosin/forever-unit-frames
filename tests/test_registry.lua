-- Settings registries (Core/Registry.lua): each has its own definitions,
-- scopes and code space; the unit-frame settings are one of them.
local ns = H.LoadAddon()

local A = ns.NewRegistry({ "general", "one" }, { general = "g", one = "a" })
local B = ns.NewRegistry({ "general", "two" }, { general = "g", two = "b" })
A.Define({ key = "size", code = "S", scope = "frame", type = "int", min = 1, max = 9, default = 4 })
B.Define({ key = "size", code = "S", scope = "general", type = "bool", default = true })

H.check("same key, own definition A", A.Get("size").type, "int")
H.check("same key, own definition B", B.Get("size").type, "bool")
H.check("same code, own definition", B.ByCode("S").type, "bool")
H.check("A lists only its own", #A.All(), 1)
H.checkError("duplicate code inside one registry", function()
    A.Define({ key = "other", code = "S", scope = "frame", type = "bool", default = false })
end)
H.check("scopes kept", A.SCOPES[2], "one")
H.check("prefix kept", B.PREFIX.two, "b")
H.check("validate clamps", A.Validate(A.Get("size"), 12), 9)
H.checkTrue("frame setting applies to a frame scope", A.AppliesTo(A.Get("size"), "one"))
H.check("frame setting not on general", A.AppliesTo(A.Get("size"), "general"), false)

-- Sanitise keeps known settings on scopes they apply to, validated.
local clean = A.Sanitise({ general = { size = 3 }, one = { size = 40, nope = 1 }, stray = { size = 2 } })
H.check("sanitise: wrong scope dropped", clean.general.size, nil)
H.check("sanitise: clamped", clean.one.size, 9)
H.check("sanitise: unknown key dropped", clean.one.nope, nil)
H.check("sanitise: unknown scope dropped", clean.stray, nil)
H.checkTrue("sanitise: every scope present", type(clean.general) == "table" and type(clean.one) == "table")

-- The unit-frame registry is one of them and unchanged.
local S = ns.Settings
H.check("unit frames: scopes", table.concat(S.SCOPES, ","), "general,player,target,targettarget,pet,focus,party")
H.check("unit frames: party prefix", S.PREFIX.party, "y")
H.check("unit frames: width code", S.Get("width").code, "W")
H.check("unit frames: text max", S.TEXT_MAX, 64)
