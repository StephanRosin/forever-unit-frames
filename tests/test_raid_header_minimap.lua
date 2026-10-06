-- The raid minimap button's settings (Raid/MinimapButton.lua) live in the
-- raid profile's General, but moving or hiding the button does not lay
-- the raid panel out anew (Raid/Header.lua); other General settings do.
local M = H.M
local ns = H.LoadAddon()
local RC, Header = ns.RaidConfig, ns.RaidHeader
M.units.player = { name = "Me", class = "WARRIOR", className = "Warrior", isPlayer = true, level = 60,
    health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
H.checkTrue("panel built", Header.anchor)

local real, calls = Header.Refresh, 0
Header.Refresh = function(...)
    calls = calls + 1
    return real(...)
end
RC.Set("general", "minimapAngle", 100)
M.RunTimers()
H.check("button angle: no relayout", calls, 0)
RC.Set("general", "minimapShow", false)
M.RunTimers()
H.check("button hidden: no relayout", calls, 0)
RC.Set("general", "minimapShow", true)
M.RunTimers()
RC.Set("general", "hideBlizzard", not RC.Get("general", "hideBlizzard"))
M.RunTimers()
H.check("another General setting: relayout", calls, 1)
Header.Refresh = real
H.check("no errors", #M.errors, 0)
