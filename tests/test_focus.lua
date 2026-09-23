local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
ns.Single.CreateAll()
local focus = ns.Frames.focus
H.checkTrue("focus built", focus)
H.check("focus unit", focus:GetAttribute("unit"), "focus")
H.check("focus width", focus:GetWidth(), 160)
H.check("focus events", focus.eventListener._events.UNIT_HEALTH[1], "focus")

M.units.focus = { name = "Boss", health = 8, healthMax = 10 }
M.FireEvent("PLAYER_FOCUS_CHANGED")
H.check("focus refreshed on PLAYER_FOCUS_CHANGED", focus.health:GetValue(), 8)
M.units.focus.health = 6
M.FireEvent("UNIT_HEALTH", "focus")
H.check("focus unit events", focus.health:GetValue(), 6)

-- /fuf status reports whether the client accepts the focus unit.
M.chat = {}
SlashCmdList.FOREVERUNITFRAMES("status")
H.checkTrue("status: focus available",
    table.concat(M.chat, "\n"):find(ns.L.STATUS_FOCUS:format(ns.L.FOCUS_AVAILABLE), 1, true))

-- A client that rejects the token: no focus frame, and status says so.
ns = H.LoadAddon()
local realExists = UnitExists
_G.UnitExists = function(unit)
    if unit == "focus" then error("Invalid unit token") end
    return realExists(unit)
end
ns.Config.Use({})
ns.Single.CreateAll()
H.check("no focus frame without the unit", ns.Frames.focus, nil)
H.checkTrue("other frames still built", ns.Frames.player)
M.chat = {}
SlashCmdList.FOREVERUNITFRAMES("status")
H.checkTrue("status: focus missing",
    table.concat(M.chat, "\n"):find(ns.L.STATUS_FOCUS:format(ns.L.FOCUS_MISSING), 1, true))
