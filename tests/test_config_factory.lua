-- ns.NewConfig (Core/Config.lua): one profile per registry, its own change
-- event, its own list of keys a copy leaves alone, and copying from a
-- profile that is not the one in use.
local ns = H.LoadAddon()

local R = ns.NewRegistry({ "general", "a", "b" }, { general = "g", a = "a", b = "b" })
R.Define({ key = "mode", code = "M", scope = "general", type = "bool", default = false })
R.Define({ key = "font", code = "F", scope = "inherit", type = "int", min = 1, max = 30, default = 12 })
R.Define({ key = "width", code = "W", scope = "frame", type = "int", min = 1, max = 500, default = { a = 80, _ = 60 } })
R.Define({ key = "x", code = "X", scope = "frame", type = "int", min = -99, max = 99, default = 0 })

local events = {}
ns.Listen("TEST_CONFIG_CHANGED", function(scope, key) events[#events + 1] = tostring(scope) .. ":" .. tostring(key) end)
local unitEvents = 0
ns.Listen("CONFIG_CHANGED", function() unitEvents = unitEvents + 1 end)

local C = ns.NewConfig(R, "TEST_CONFIG_CHANGED", {})
C.Use({})
H.checkTrue("scopes made", type(C.Profile().a) == "table" and type(C.Profile().b) == "table")
H.check("frame default", C.Get("a", "width"), 80)
H.check("base default", C.Get("b", "width"), 60)
H.checkTrue("set", C.Set("a", "width", 120))
H.check("own event", events[#events], "a:width")
H.check("unit-frame event untouched", unitEvents, 0)
C.Set("general", "font", 14)
H.check("inherits general", C.Get("b", "font"), 14)

-- Nothing is left out of a copy when notCopied is empty: x travels too.
C.Set("a", "x", 7)
C.CopyScope("a", "b")
H.check("copy: width", C.Get("b", "width"), 120)
H.check("copy: x copied", C.Get("b", "x"), 7)
H.check("copy: event", events[#events], "b:nil")

-- Copy from another profile (another character, a decoded import): its
-- own general counts for inherited settings, ours does not.
local other = { general = { font = 20 }, a = { width = 200 }, b = {} }
C.CopyScopeFrom(other, "a", "b")
H.check("from other: width", C.Get("b", "width"), 200)
H.check("from other: inherited value of the source", C.Get("b", "font"), 20)
H.check("from other: source default x", C.Get("b", "x"), 0)
H.check("from other: stored as override only", C.Profile().b.x, nil)
H.check("from other: source untouched", other.b.width, nil)
C.CopyScopeFrom({ general = {} }, "a", "b")
H.check("source without that scope: nothing", C.Get("b", "width"), 200)
C.CopyScopeFrom(other, "a", "nope")
H.check("unknown target scope: nothing", C.Profile().nope, nil)

-- Two configs keep two profiles.
local D = ns.NewConfig(R, "TEST_CONFIG_CHANGED", {})
D.Use({})
H.check("second config: own profile", D.Get("a", "width"), 80)
H.check("first config unchanged", C.Get("a", "width"), 120)

-- The unit frames keep their rules: position and enabled are not copied.
local UF = ns.Config
UF.Use({})
UF.Set("player", "x", 33)
UF.Set("player", "width", 250)
UF.CopyScope("player", "target")
H.check("unit frames: width copied", UF.Get("target", "width"), 250)
H.check("unit frames: x not copied", UF.Get("target", "x"), 300)
H.checkTrue("unit frames: event", unitEvents > 0)
