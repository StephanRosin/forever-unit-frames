local ns = H.LoadAddon()
local C = ns.Config

local changes = {}
ns.Listen("CONFIG_CHANGED", function(scope, key) changes[#changes + 1] = (scope or "*") .. "." .. (key or "*") end)

C.Use({})
H.check("default width player", C.Get("player", "width"), 220)
H.check("default fontSize via general", C.Get("target", "fontSize"), 12)

H.checkTrue("set general font size", C.Set("general", "fontSize", 14))
H.check("target inherits general", C.Get("target", "fontSize"), 14)
H.checkTrue("override on target", C.Set("target", "fontSize", 10))
H.check("target override wins", C.Get("target", "fontSize"), 10)
H.check("player still inherits", C.Get("player", "fontSize"), 14)

-- Setting a value equal to its fallback removes the override.
C.Set("target", "fontSize", 14)
H.check("override removed", C.IsOverridden("target", "fontSize"), false)
C.Set("player", "width", 220)
H.check("default value not stored", C.Profile().player.width, nil)

H.check("invalid value rejected", C.Set("player", "fontOutline", "BOLD"), false)
H.check("frame-only key rejected on general", C.Set("general", "width", 100), false)
H.check("general-applicable ok", C.Set("general", "healthColorMode", "GRADIENT"), true)

-- Colors are copied, not shared.
local col = { 1, 0, 0, 1 }
C.Set("general", "healthColor", col)
col[1] = 0
H.check("color copied", C.Get("player", "healthColor")[1], 1)

H.check("change events fired", changes[1], "general.fontSize")

C.Set("player", "width", 300)
C.ResetScope("player")
H.check("reset scope", C.Get("player", "width"), 220)
C.ResetAll()
H.check("reset all", C.Get("target", "healthColorMode"), "CLASS")
H.check("last event is reset all", changes[#changes], "*.*")
