local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
ns.Single.CreateAll()
local p, t = ns.Frames.player, ns.Frames.target

-- Each frame listens through its own listener, registered for its unit only.
H.checkTrue("player has a listener", p.eventListener)
H.check("registered for player only", p.eventListener._events.UNIT_HEALTH[1], "player")
H.check("one unit per registration", #p.eventListener._events.UNIT_HEALTH, 1)
H.check("target registered for target", t.eventListener._events.UNIT_HEALTH[1], "target")

M.units.player = { name = "Me", health = 5, healthMax = 10 }
M.units.target = { name = "Foe", health = 7, healthMax = 10 }
M.FireEvent("UNIT_HEALTH", "target")
H.check("target updated", t.health:GetValue(), 7)
H.check("player untouched by target event", p.health:GetValue(), nil)
M.FireEvent("UNIT_HEALTH", "nameplate3")
H.check("nameplate event reaches nobody", p.health:GetValue(), nil)
M.FireEvent("UNIT_HEALTH", "player")
H.check("player updated", p.health:GetValue(), 5)

-- Extra event arguments reach the element (castbars need the castGUID).
-- An element registered before the frames are built is indexed too.
local seen
ns = H.LoadAddon()
ns.RegisterElement({ name = "Probe", unitEvents = { "UNIT_PROBE" },
    Build = function() end, Style = function() end,
    Update = function(_, event, unit, extra) seen = { event, unit, extra } end })
ns.Config.Use({})
ns.Single.CreateAll()
M.units.player = { name = "Me" }
M.FireEvent("UNIT_PROBE", "player", "guid-1")
H.check("event name passed", seen and seen[1], "UNIT_PROBE")
H.check("unit passed", seen and seen[2], "player")
H.check("extra argument passed", seen and seen[3], "guid-1")

-- No update for a unit that does not exist.
seen = nil
M.units.player = nil
M.FireEvent("UNIT_PROBE", "player", "guid-2")
H.check("missing unit: no update", seen, nil)

-- SetUnit re-registers for the new unit.
M.units.player = { name = "Me" }
M.units.party1 = { name = "Friend" }
local f = ns.Frames.target
ns.Single.SetUnit(f, "party1")
H.check("attribute follows", f:GetAttribute("unit"), "party1")
H.check("field follows", f.unit, "party1")
H.check("events follow", f.eventListener._events.UNIT_HEALTH[1], "party1")
seen = nil
M.FireEvent("UNIT_PROBE", "target", "x")
H.check("old unit no longer delivered", seen, nil)
ns.Single.SetUnit(f, "target")

-- Test mode rebinds to the player and back.
ns.TestMode.Set(true)
H.check("test mode: target frame listens to player", f.eventListener._events.UNIT_HEALTH[1], "player")
ns.TestMode.Set(false)
H.check("test mode off: back to target", f.eventListener._events.UNIT_HEALTH[1], "target")

-- Health colours not covered before -----------------------------------------
ns = H.LoadAddon()
ns.Config.Use({})
ns.Single.CreateAll()
f = ns.Frames.target

ns.Config.Set("target", "healthColorMode", "GRADIENT")
M.units.target = { health = 3, healthMax = 10, healthPercent = M.Secret(0.3) }
M.FireEvent("UNIT_HEALTH", "target")
H.check("gradient: colour from the curve r", f.health._color[1], 1)
H.check("gradient: colour from the curve b", f.health._color[3], 1)

ns.Config.Set("target", "healthColorMode", "STATIC")
ns.Config.Set("target", "healthColor", { 0.1, 0.2, 0.3, 1 })
M.FireEvent("UNIT_HEALTH", "target")
H.check("static: r", f.health._color[1], 0.1)
H.check("static: g", f.health._color[2], 0.2)
H.check("static: b", f.health._color[3], 0.3)

ns.Config.Set("target", "healthColorMode", "REACTION")
M.units.target = { health = 3, healthMax = 10, reaction = 4 }
M.FireEvent("UNIT_HEALTH", "target")
H.check("readable reaction 4: neutral", f.health._color[1], 0.9)
M.units.target.reaction = 5
M.FireEvent("UNIT_HEALTH", "target")
H.check("readable reaction 5: friendly", f.health._color[1], 0.2)
M.units.target.reaction = 2
M.FireEvent("UNIT_HEALTH", "target")
H.check("readable reaction 2: hostile", f.health._color[1], 0.85)

-- UNIT_CONNECTION refreshes the bar (a member going offline or back).
M.units.target = { health = 9, healthMax = 10 }
M.FireEvent("UNIT_CONNECTION", "target", false)
H.check("connection event refreshes health", f.health:GetValue(), 9)
