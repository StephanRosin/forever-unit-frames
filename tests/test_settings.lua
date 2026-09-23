local ns = H.LoadAddon()
local S = ns.Settings

-- Codes are unique and well-formed.
local seen = {}
for _, def in ipairs(S.All()) do
    H.checkTrue("code format " .. def.key, def.code:match("^%u%u?$"))
    H.check("code unique " .. def.code, seen[def.code], nil)
    seen[def.code] = true
    H.checkTrue("label for " .. def.key, ns.L["SETTING_" .. def.key] ~= "SETTING_" .. def.key)
end

H.check("ByCode", S.ByCode("W").key, "width")
H.check("per-frame default player", S.Default(S.Get("x"), "player"), -300)
H.check("per-frame default target", S.Default(S.Get("x"), "target"), 300)
H.check("plain default", S.Default(S.Get("fontSize"), "general"), 12)

H.check("clamp high", S.Validate(S.Get("width"), 9999), 600)
H.check("clamp low", S.Validate(S.Get("width"), 1), 40)
H.check("int rounds", S.Validate(S.Get("width"), 200.6), 201)
H.check("enum ok", S.Validate(S.Get("fontOutline"), "THICKOUTLINE"), "THICKOUTLINE")
H.check("enum bad", S.Validate(S.Get("fontOutline"), "BOLD"), nil)
H.check("bool ok", S.Validate(S.Get("enabled"), false), false)
H.check("bool bad", S.Validate(S.Get("enabled"), 1), nil)
H.check("color bad", S.Validate(S.Get("healthColor"), { 2, 0, 0, 1 }), nil)
H.check("color ok", S.Validate(S.Get("healthColor"), { 1, 0, 0, 1 })[1], 1)

H.checkTrue("width applies to player", S.AppliesTo(S.Get("width"), "player"))
H.check("width not general", S.AppliesTo(S.Get("width"), "general"), false)
H.checkTrue("fontSize inherits to frames", S.AppliesTo(S.Get("fontSize"), "target"))
